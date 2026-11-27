#!/usr/bin/env python3
"""Lint, query and score the decision register.

usage: decisions.py lint|score [--register FILE]
       decisions.py due EVENT [--register FILE]

The register is Markdown: one `### D-<n> — <title>` section per decision, each holding
`- **Field:** value` lines (format in the skill's references/register-format.md).
Exit codes: 0 ok, 1 the register breaks a rule (lint), 2 bad usage or unreadable file.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field

DEFAULT_REGISTER = "docs/decisions/REGISTER.md"

HEADING = re.compile(r"^### (D-\d+) — (.+)$")
FIELD = re.compile(r"^- \*\*([A-Za-z ]+):\*\*\s*(.*)$")
EVENT = re.compile(r"`([^`]+)`")          # an event is a backticked name: `H1`, `Ride B`
# 1-99 %, then optionally who gave it: "60 % (Claude, at seeding)". 0 and 100 are certainty, not a forecast.
CONFIDENCE = re.compile(r"^(\d{1,2}) ?%(\s|$)")
SUPERSEDED = re.compile(r"^superseded by (D-\d+)$")

KINDS = ("data", "values", "reversible")
DOORS = ("one-way", "two-way")
RESOLVED = ("held", "overturned")
OPEN = ("awaiting check", "awaiting operator")
STATUSES = OPEN + RESOLVED + ("unchecked",)

REQUIRED = ("Date", "Kind", "Door", "Decision", "Status", "Record")
REQUIRED_FOR_DATA = ("Prediction", "Confidence", "Overturn if", "Checked by")


@dataclass(frozen=True)
class Entry:
    id: str
    title: str
    fields: dict = field(default_factory=dict)

    def get(self, name: str) -> str:
        return self.fields.get(name, "").strip()

    def events(self) -> list[str]:
        return [e.strip() for e in EVENT.findall(self.get("Checked by"))]


def parse(text: str) -> list[Entry]:
    """Indented lines (wrapped text, sub-bullets) continue the field above; blank lines are skipped;
    any other line ends the field."""
    entries: list[Entry] = []
    current: tuple[str, str, dict] | None = None
    last: str | None = None
    for line in text.splitlines():
        head = HEADING.match(line)
        if head:
            if current:
                entries.append(Entry(*current))
            current, last = (head.group(1), head.group(2).strip(), {}), None
            continue
        if not current or not line.strip():
            continue
        found = FIELD.match(line)
        if found:
            last = found.group(1).strip()
            current[2][last] = found.group(2)
        elif last and line[0].isspace():
            current[2][last] = f"{current[2][last]} {line.strip()}".strip()
        else:
            last = None
    if current:
        entries.append(Entry(*current))
    return entries


def lint_entry(e: Entry, ids: set[str]) -> list[str]:
    out = [f"{e.id}: missing {name}" for name in REQUIRED if not e.get(name)]
    kind, door, status = e.get("Kind"), e.get("Door"), e.get("Status")
    if kind and kind not in KINDS:
        out.append(f"{e.id}: Kind must be one of {', '.join(KINDS)}")
    if door and door not in DOORS:
        out.append(f"{e.id}: Door must be one-way or two-way")
    sup = SUPERSEDED.match(status)
    if status and status not in STATUSES and not sup:
        out.append(f"{e.id}: Status '{status}' is not one of {', '.join(STATUSES)}, superseded by D-n")
    if sup and sup.group(1) not in ids:
        out.append(f"{e.id}: superseded by {sup.group(1)}, which is not in the register")
    if status in RESOLVED and not e.get("Check"):
        out.append(f"{e.id}: a {status} decision needs its Check line (date, evidence)")
    if door == "one-way" and not e.get("Premortem"):
        out.append(f"{e.id}: a one-way door needs a Premortem")
    if kind == "data":
        out += lint_data(e)
    if kind == "values" and status != "awaiting operator" and not e.get("Principle"):
        out.append(f"{e.id}: a values decision is awaiting operator or carries their Principle (quoted)")
    return out


def lint_data(e: Entry) -> list[str]:
    out = [f"{e.id}: missing {name}" for name in REQUIRED_FOR_DATA if not e.get(name)]
    conf = e.get("Confidence")
    m = CONFIDENCE.match(conf)
    if conf and not (m and 1 <= int(m.group(1)) <= 99):
        out.append(f"{e.id}: Confidence must be 1-99 %, got '{conf}'")
    overturn = e.get("Overturn if")
    if overturn and not re.search(r"\d", overturn):
        out.append(f"{e.id}: Overturn if needs a number, so the check cannot be argued after")
    if e.get("Checked by") and not e.events():
        out.append(f"{e.id}: Checked by names no event (write it in backticks: `H1`)")
    return out


def lint(entries: list[Entry]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for e in entries:
        if e.id in seen:
            out.append(f"{e.id}: duplicate id")
        seen.add(e.id)
    for e in entries:
        out += lint_entry(e, seen)
    return out


def due(entries: list[Entry], event: str) -> list[Entry]:
    """Open entries the event checks: a prediction awaiting it, or a values call whose data question it answers."""
    return [e for e in entries if e.get("Status") in OPEN and event in e.events()]


def score(entries: list[Entry]) -> dict:
    counts: dict[str, int] = {}
    for e in entries:
        key = "superseded" if SUPERSEDED.match(e.get("Status")) else e.get("Status")
        counts[key] = counts.get(key, 0) + 1
    errors = []
    for e in entries:
        m = CONFIDENCE.match(e.get("Confidence"))
        if e.get("Status") in RESOLVED and m:
            outcome = 1.0 if e.get("Status") == "held" else 0.0
            errors.append((int(m.group(1)) / 100 - outcome) ** 2)
    brier = sum(errors) / len(errors) if errors else None
    return {"counts": counts, "brier": brier, "scored": len(errors)}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("command", choices=("lint", "due", "score"))
    ap.add_argument("event", nargs="?")
    ap.add_argument("--register", default=DEFAULT_REGISTER)
    args = ap.parse_args(argv)
    try:
        with open(args.register, encoding="utf-8") as f:
            entries = parse(f.read())
    except OSError as exc:
        print(f"cannot read the register: {exc}", file=sys.stderr)
        return 2
    if args.command == "lint":
        found = lint(entries)
        print("\n".join(found) if found else f"ok: {len(entries)} decisions")
        return 1 if found else 0
    if args.command == "due":
        if not args.event:
            ap.error("due needs an EVENT, for example: due H1")
        hits = due(entries, args.event)
        for e in hits:
            print(f"{e.id} — {e.title}\n  overturn if: {e.get('Overturn if')}")
        if not hits:
            print(f"no decision awaits `{args.event}`")
        return 0
    s = score(entries)
    print(", ".join(f"{k} {v}" for k, v in sorted(s["counts"].items())))
    brier = "none resolved yet" if s["brier"] is None else f"{s['brier']:.3f} over {s['scored']}"
    print(f"Brier score (0 is perfect, 0.25 is a coin toss): {brier}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
