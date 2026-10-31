#!/usr/bin/env bash
#
# Everything this project owes, with a due date: the obligations register plus what the
# repository already implies. Writes obligations/obligations.json and prints what is
# overdue and what is due this week. Read-only except for that one generated file, and it
# never calls a model, so it costs no tokens.
#
#   scripts/obligations.sh             # regenerate, then summarise
#   scripts/obligations.sh --check     # pre-commit: one short warning if anything is overdue
#   scripts/obligations.sh --next-id   # the next O-<n> id, from the file, never from memory
#
# Why: GLOOD's audit (2026-10-31) found obligations already written down with no date and
# no owner: 26 ledger entries left open for days, and a bug row reading "ROTATION STILL
# OUTSTANDING". A due date that nobody is reminded of is not a deadline. Format and the
# class rules: obligations/README.md. Notion sync: the obligations skill.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Obligations check DID NOT RUN — not inside a git repository."; exit 1; }
mode="${1:-}"
if [ ! -f "$root/obligations/OBLIGATIONS.md" ]; then
  echo "Obligations check DID NOT RUN — no obligations/OBLIGATIONS.md. Run ./update.sh from the governance kit to create it."
  exit 1
fi
command -v python3 >/dev/null || { echo "Obligations check DID NOT RUN — needs python3."; exit 1; }

python3 -I - "$root" "$mode" <<'PY'
import datetime as dt, glob, json, os, re, sys

root, mode = sys.argv[1], sys.argv[2]
today = dt.date.today()
# Days until due, and default importance, by class. obligations/README.md is the spec.
CLASSES = {"security": (2, "high"), "decision": (3, "high"), "deadline": (None, "high"),
           "verification": (7, "normal"), "maintenance": (30, "low"), "open-entry": (2, "normal")}
findings, items = [], []

def date(s):
    m = re.search(r"\d{4}-\d{2}-\d{2}", s or "")
    return dt.date.fromisoformat(m.group(0)) if m else None

# ---- the register
register = open(os.path.join(root, "obligations/OBLIGATIONS.md"), encoding="utf-8").read()
sections = re.split(r"(?m)^## ", register)[1:]
ids = []
for sec in sections:
    head, _, body = sec.partition("\n")
    m = re.match(r"(O-(\d+))\s*[—-]\s*(.*)", head.strip())
    if not m: continue
    oid, n, title = m.group(1), int(m.group(2)), m.group(3).strip()
    ids.append(n)
    field = lambda name: (re.search(rf"(?m)^\*\*{re.escape(name)}:\*\*\s*(.*)$", body) or [None, None])[1]
    status = (field("Status") or "").strip()
    if status not in ("Open", "Done", "Dropped"):
        findings.append(f"{oid}: status must be Open, Done or Dropped (put any explanation on a Status note line)")
        continue
    if status != "Open": continue
    cls = (field("Class") or "").strip().lower()
    if cls not in CLASSES or cls == "open-entry":
        findings.append(f"{oid}: class must be one of security, decision, deadline, verification, maintenance")
        continue
    days, imp = CLASSES[cls]
    added, due = date(field("Added")), date(field("Due"))
    if due is None:
        if days is None:
            findings.append(f"{oid}: a deadline needs a **Due:** date — it has no default"); continue
        if added is None:
            findings.append(f"{oid}: needs **Added:** (or **Due:**) to derive its due date"); continue
        due = added + dt.timedelta(days=days)
    items.append({"id": oid, "title": title, "class": cls,
                  "importance": (field("Importance") or imp).strip().lower(),
                  "due": due.isoformat(), "owner": (field("Owner") or "operator").strip(),
                  "source": (field("Source") or "").strip(), "doneWhen": (field("Done when") or "").strip(),
                  "origin": "register"})

if mode == "--next-id":
    print(f"O-{max(ids, default=0) + 1}"); sys.exit(0)

# ---- derived: ledger entries left open from an earlier day (every week folder)
for f in sorted(glob.glob(os.path.join(root, "ledger/20*-W*/*.md"))):
    if os.path.basename(f) == "README.md": continue
    for sec in re.split(r"(?m)^## (?=\d{4}-W\d{2}-\d+)", open(f, encoding="utf-8", errors="replace").read())[1:]:
        head, _, body = sec.partition("\n")
        m = re.match(r"(\d{4}-W\d{2}-\d+)\s*[—-]?\s*(.*)", head)
        if not m: continue
        closed = re.search(r"(?m)^### Closed", body) or re.search(r"(?m)^\*\*Status:\*\*.*(Closed|Abandoned)", body)
        reserved = date((re.search(r"(?m)^\*\*Reserved:\*\*\s*(.*)$", body) or [None, ""])[1])
        if closed or reserved is None or reserved >= today: continue
        items.append({"id": m.group(1), "title": m.group(2).strip() or "(untitled entry)", "class": "open-entry",
                      "importance": "normal", "due": (reserved + dt.timedelta(days=2)).isoformat(),
                      "owner": "operator", "source": os.path.relpath(f, root),
                      "doneWhen": "the entry has its closing block", "origin": "ledger"})

items.sort(key=lambda o: (o["due"], {"high": 0, "normal": 1, "low": 2}.get(o["importance"], 1), o["id"]))
# No timestamp: the file changes only when what is owed changes, so it can be committed
# like the ledger's generated indexes without a diff on every run.
out = {"project": os.path.basename(root),
       "obligations": items, "findings": findings}
# --check (pre-commit) only reads. Writing here left obligations.json modified after
# every commit, since the hook runs after staging.
if mode != "--check":
    with open(os.path.join(root, "obligations/obligations.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2, ensure_ascii=False); fh.write("\n")

overdue = [o for o in items if dt.date.fromisoformat(o["due"]) < today]
week = [o for o in items if today <= dt.date.fromisoformat(o["due"]) <= today + dt.timedelta(days=7)]
line = lambda o: f"  {o['id']}  {o['due']}  {o['importance']:<6}  {o['class']:<12}  {o['title']}"

if mode == "--check":
    if not overdue and not findings: sys.exit(0)
    print(f"Obligations: {len(overdue)} overdue, {len(findings)} malformed — scripts/obligations.sh lists them")
    for o in overdue[:3]: print(line(o))
    if len(overdue) > 3: print(f"  … and {len(overdue) - 3} more")
    sys.exit(1)

print(f"{len(items)} owed — {len(overdue)} overdue, {len(week)} due within 7 days  (obligations/obligations.json)")
if overdue: print("\noverdue:"); [print(line(o)) for o in overdue]
if week: print("\ndue within 7 days:"); [print(line(o)) for o in week]
if findings: print("\nfix in obligations/OBLIGATIONS.md:"); [print(f"  {f}") for f in findings]
sys.exit(1 if (overdue or findings) else 0)
PY
