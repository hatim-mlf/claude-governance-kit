#!/usr/bin/env python3
"""Lint one skill folder against Anthropic's skill rules and what Claude Code actually loads.

usage: lint_skill.py [--ship] SKILL_DIR
exit 0 = PASS (warnings allowed), 1 = FAIL, 2 = bad usage.
Every line starts with WARN or FAIL and a rule id, so a log can be grepped by rule.
--ship adds the release gate: at least MIN_EVALS eval cases (Anthropic's checklist).

YAML: a built-in reader covers the frontmatter subset skills use and gives the same verdict
with or without PyYAML on every guard in tests/test_building_skills.sh. When PyYAML is
importable it also parses the block strictly; when it is not, one WARN STRICT-YAML-UNVERIFIED
says so. Python 3.9+ and the standard library are enough (the macOS system python3 is 3.9).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Limits from Anthropic's Agent Skills spec and best-practices page.
MAX_NAME, MAX_DESC, MAX_BODY_LINES, TOC_OVER = 64, 1024, 500, 100
MIN_EVALS = 3  # "At least three evaluations created" (Anthropic checklist)
STRICT_KEYS = {"name", "description", "license", "allowed-tools", "metadata", "compatibility"}
CLAUDE_CODE_KEYS = {"when_to_use", "argument-hint", "arguments", "disable-model-invocation",
                    "user-invocable", "disallowed-tools", "model", "effort", "context", "agent",
                    "background", "hooks", "paths", "shell"}
SKIP_DIRS = {"__pycache__", "node_modules"}
NON_STRING = re.compile(  # YAML 1.1 plain scalars that are not strings
    r"(?i)^(true|false|yes|no|on|off|y|n|null|~|[-+]?\d+(\.\d*)?([eE][-+]?\d+)?|"
    r"0x[0-9a-f]+|0o?[0-7]+|[-+]?\.(inf|nan))$")
MD_LINK = re.compile(r"\]\(([^)#\s]+\.md)\)")
MD_TICK = re.compile(r"`([A-Za-z0-9_./-]+\.md)`")
BACKSLASH_PATH = re.compile(r"(?<![\w/])[\w.-]+\\[\w.-]+\.(md|py|sh|json|txt|ya?ml)\b")
TOC = re.compile(r"(?im)^#+\s*(table of )?contents\s*$|^contents:?\s*$|(\]\(#[^)]+\)[^\n]*\n){3}")


# ---------- frontmatter -------------------------------------------------------------------

def decode_double_quoted(s: str) -> str:
    """Apply YAML double-quote escapes, so an escaped '<' is seen as '<'."""
    s = re.sub(r"\\x([0-9a-fA-F]{2})", lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r"\\U([0-9a-fA-F]{8})", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace("\\\\", "\\")


def flow_balanced(text: str) -> bool:
    depth, quote = [], None
    pairs = {"]": "[", "}": "{"}
    for ch in text:
        if quote:
            quote = None if ch == quote else quote
        elif ch in "\"'":
            quote = ch
        elif ch in "[{":
            depth.append(ch)
        elif ch in "]}":
            if not depth or depth.pop() != pairs[ch]:
                return False
    return not depth and quote is None


def read_value(key: str, chunk: list[str], errors: list[str]) -> tuple[str, object]:
    """Classify one key's raw lines. Returns (kind, value); kind 'str' means a usable string."""
    first = chunk[0].strip()
    cont = [r.strip() for r in chunk[1:] if r.strip()]
    if first[:1] in ("|", ">"):
        return "str", ("\n" if first[0] == "|" else " ").join(cont)
    if first[:1] in ("\"", "'"):
        joined = " ".join([first] + cont)
        if len(joined) < 2 or joined[-1] != first[0]:
            errors.append(f"YAML-QUOTE: '{key}' has an unclosed quote")
            return "str", joined[1:]
        inner = joined[1:-1]
        return "str", decode_double_quoted(inner) if first[0] == '"' else inner.replace("''", "'")
    if first == "" and cont:
        return "nested", cont
    text = " ".join([first] + cont).strip()
    if text[:1] in ("[", "{"):
        if not flow_balanced(text):
            errors.append(f"YAML-FLOW: '{key}' opens a flow collection that is never closed")
        return "collection", text
    if ": " in text or text.endswith(":"):
        errors.append(colon_message(key, len(chunk) > 1))
    if text[:1] in ("@", "`", "%", "&", "*", "!"):
        errors.append(f"YAML-INDICATOR: '{key}' value starts with the reserved '{text[0]}'")
    if text == "" or NON_STRING.match(text):
        return "scalar", text
    return "str", text


def colon_message(key: str, multi: bool) -> str:
    msg = (f"YAML-COLON: '{key}' is an unquoted {'multi-line ' if multi else ''}value "
           "containing ': ' (invalid strict YAML; claude.ai and the Skills API reject it)")
    if multi and key == "description":
        msg += ("; Claude Code drops the whole description, so the skill is listed by name only "
                "(measured on 6 kit skills, 2026-11-25)")
    return msg + ". Fix: quote the value or use '>-'."


def parse_frontmatter(text: str) -> tuple[dict | None, list[str], list[str], str]:
    """Return (fields, errors, body_lines, raw_block). fields[key] = (kind, value)."""
    lines = text.split("\n")
    if lines[0].rstrip() != "---":
        return None, ["FRONTMATTER: the file does not start with '---'"], lines, ""
    end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
    if end is None:
        return None, ["FRONTMATTER: the closing '---' is missing"], lines, ""
    block, body = lines[1:end], lines[end + 1:]
    if body and body[-1] == "":
        body = body[:-1]  # the file's final newline is not a body line
    fields: dict = {}
    errors: list[str] = []
    key, chunk = None, []
    for ln in block + ["__END__:"]:
        if "\t" in ln[: len(ln) - len(ln.lstrip())]:
            errors.append("YAML-TAB: a tab is used for indentation in the frontmatter")
        m = re.match(r"^([A-Za-z0-9_-]+):(?:\s+(.*))?$", ln)
        if m and not ln.startswith((" ", "\t")):
            if key is not None:
                if key in fields:
                    errors.append(f"YAML-DUPLICATE: '{key}' appears twice")
                fields[key] = read_value(key, chunk, errors)
            key, chunk = m.group(1), [m.group(2) or ""]
        elif key is not None:
            chunk.append(ln)
        elif ln.strip() and not ln.lstrip().startswith("#"):
            errors.append(f"YAML-LINE: cannot read the frontmatter line {ln[:40]!r}")
    return fields, errors, body, "\n".join(block)


def strict_yaml(raw: str) -> tuple[bool, str]:
    """(verified, error). verified is False when PyYAML is not importable."""
    try:
        import yaml
    except ImportError:
        return False, ""
    try:
        yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        return True, str(exc).splitlines()[0]
    return True, ""


# ---------- checks ------------------------------------------------------------------------

def check_keys(fields: dict) -> tuple[list[str], list[str]]:
    fails, warns = [], []
    for k in sorted(set(fields) - STRICT_KEYS):
        if k in CLAUDE_CODE_KEYS:
            warns.append(f"KEY-CLAUDE-CODE-ONLY: '{k}' works in Claude Code; claude.ai and the "
                         "Skills API reject it")
        else:  # WARN: the Claude Code key list came from a truncated docs page (2026-11-25)
            warns.append(f"KEY-UNKNOWN: '{k}' is neither a portable key nor a known Claude Code "
                         "key; claude.ai and the Skills API reject it")
    return fails, warns


def check_name(fields: dict, folder: str) -> tuple[list[str], list[str]]:
    if "name" not in fields:
        return ["NAME-MISSING: 'name' is missing"], []
    kind, name = fields["name"]
    if kind != "str":
        return [f"NAME-TYPE: name must be a string, got {kind} {str(name)[:30]!r}"], []
    fails = []
    if len(name) > MAX_NAME:
        fails.append(f"NAME-LENGTH: {len(name)} chars, max {MAX_NAME}")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        fails.append(f"NAME-CHARS: '{name}' must be lowercase letters and digits joined by single hyphens")
    if re.search(r"anthropic|claude", name):
        fails.append("NAME-RESERVED: a name may not contain 'anthropic' or 'claude'")
    warns = [] if name == folder else [f"NAME-FOLDER: name '{name}' differs from folder '{folder}'"]
    return fails, warns


def check_description(fields: dict) -> tuple[list[str], list[str]]:
    if "description" not in fields:
        return ["DESC-MISSING: 'description' is missing"], []
    kind, desc = fields["description"]
    if kind != "str":
        return [f"DESC-TYPE: description must be a string, got {kind} {str(desc)[:30]!r}"], []
    if not desc.strip():
        return ["DESC-EMPTY: description is empty"], []
    fails, warns = [], []
    if len(desc) > MAX_DESC:
        fails.append(f"DESC-LENGTH: {len(desc)} chars, max {MAX_DESC}")
    if "<" in desc or ">" in desc:
        fails.append("DESC-ANGLE: description contains '<' or '>' (XML-like text)")
    if re.search(r"\b(I can|I will|I help|you can|you should|your)\b", desc, re.I):
        warns.append("DESC-VOICE: write the description in the third person")
    if not re.search(r"\b(use|when|whenever|on|before|after)\b", desc, re.I):
        warns.append("DESC-WHEN: the description should say when to use the skill")
    return fails, warns


def referenced(text: str) -> set[str]:
    return set(MD_LINK.findall(text)) | set(MD_TICK.findall(text))


def check_resources(root: Path, body: str) -> tuple[list[str], list[str]]:
    fails, warns = [], []
    direct = {(root / r).resolve() for r in referenced(body)
              if (root / r).is_file() and Path(r).name != "SKILL.md"}
    for path in sorted(direct):
        rel = path.relative_to(root)
        text = path.read_text(errors="replace")
        if len(text.split("\n")) > TOC_OVER and not TOC.search(text):
            fails.append(f"RESOURCE-TOC: {rel} is over {TOC_OVER} lines and has no table of contents")
        if BACKSLASH_PATH.search(text):
            fails.append(f"PATH-BACKSLASH: {rel} has a backslash path; use forward slashes")
        for link in referenced(text):
            target = next((p for p in ((path.parent / link).resolve(), (root / link).resolve())
                           if p.is_file()), None)
            if target and target not in direct and target.name != "SKILL.md":
                fails.append(f"RESOURCE-CHAIN: {rel} links to {target.relative_to(root)}, which "
                             "SKILL.md does not link; keep references one level deep")
    refs_dir = root / "references"
    for p in sorted(refs_dir.rglob("*.md")) if refs_dir.is_dir() else []:
        if p.resolve() not in direct:
            warns.append(f"RESOURCE-ORPHAN: {p.relative_to(root)} is not linked from SKILL.md")
    return fails, warns


def count_evals(root: Path) -> int:
    legacy = root / "evals" / "evals.json"
    n = 0
    if legacy.is_file():
        try:
            data = json.loads(legacy.read_text())
        except ValueError:
            data = []  # unreadable evals.json counts as zero cases; the EVALS fail names the gap
        cases_in_file = data.get("evals", []) if isinstance(data, dict) else data
        n += len(cases_in_file) if isinstance(cases_in_file, list) else 0
    cases = root / "evals"
    if cases.is_dir():
        n += sum(1 for c in cases.iterdir() if (c / "prompt.md").is_file())
    return n


def check_scripts(root: Path) -> list[str]:
    scripts = root / "scripts"
    warns = []
    for sp in sorted(scripts.glob("*.py")) if scripts.is_dir() else []:
        if re.search(r"except[^\n]*:\s*\n\s*pass\b", sp.read_text(errors="replace")):
            warns.append(f"SCRIPT-PUNT: {sp.name} swallows an exception with a bare 'pass'")
    return warns


def skill_md_count(root: Path) -> int:
    n = 0
    for p in root.rglob("SKILL.md"):
        parts = p.relative_to(root).parts[:-1]
        if any(x in SKIP_DIRS for x in parts) or (parts and parts[0] == "evals"):
            continue
        n += 1
    return n


def lint(root: Path, ship: bool) -> tuple[list[str], list[str]]:
    md = root / "SKILL.md"
    if not md.is_file():
        return ["SKILL-MD: no SKILL.md in this folder"], []
    fails, warns = [], []
    if skill_md_count(root) > 1:
        fails.append("SKILL-MD-COUNT: more than one SKILL.md; a skill holds exactly one")
    fields, errors, body, raw = parse_frontmatter(md.read_text(errors="replace"))
    fails += errors
    if fields is None:
        return fails, warns
    verified, yaml_error = strict_yaml(raw)
    if not verified:
        warns.append("STRICT-YAML-UNVERIFIED: PyYAML is not installed; the built-in reader ran instead")
    elif yaml_error and not errors:
        fails.append(f"YAML-PARSE: {yaml_error}")
    body_text = "\n".join(body)
    for f, w in (check_keys(fields), check_name(fields, root.name), check_description(fields),
                 check_resources(root, body_text)):
        fails += f
        warns += w
    if len(body) >= MAX_BODY_LINES:
        fails.append(f"BODY-LENGTH: {len(body)} body lines; keep it under {MAX_BODY_LINES}")
    if BACKSLASH_PATH.search(body_text):
        fails.append("PATH-BACKSLASH: SKILL.md has a backslash path; use forward slashes")
    warns += check_scripts(root)
    if ship and count_evals(root) < MIN_EVALS:
        fails.append(f"EVALS: {count_evals(root)} eval cases under evals/; shipping needs {MIN_EVALS}")
    return fails, warns


def main(argv: list[str]) -> int:
    ship = "--ship" in argv
    args = [a for a in argv if a != "--ship"]
    if len(args) != 1 or not Path(args[0]).is_dir():
        print("usage: lint_skill.py [--ship] SKILL_DIR", file=sys.stderr)
        return 2
    fails, warns = lint(Path(args[0]).resolve(), ship)
    for w in warns:
        print(f"WARN {w}")
    for f in fails:
        print(f"FAIL {f}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
