#!/usr/bin/env python3
"""Lint one skill directory. Stdlib only (PyYAML is optional, see below).

usage: lint_skill.py [--ship] SKILL_DIR
exit 0 = PASS (warnings allowed), 1 = FAIL, 2 = bad usage / not a skill dir.
Every FAIL line starts with a rule id, so a log can be grepped by rule.
--ship adds the release-only gate: >= 3 evals (Anthropic checklist).

YAML: a small built-in reader handles the frontmatter subset skills use and
applies the YAML rule that matters here: a plain (unquoted) scalar may not
contain ': '. If PyYAML happens to be installed it is used as a second opinion
only; its absence never changes a result.
"""
import json, re, sys
from pathlib import Path

MAX_NAME, MAX_DESC, MAX_BODY_LINES, TOC_OVER = 64, 1024, 500, 100  # Anthropic limits
STRICT_KEYS = {"name", "description", "license", "allowed-tools", "metadata", "compatibility"}
CC_KEYS = {"when_to_use", "argument-hint", "arguments", "disable-model-invocation",
           "user-invocable", "disallowed-tools", "model", "effort", "context", "agent",
           "background", "hooks", "paths", "shell"}
SKIP_DIRS = {"__pycache__", "node_modules"}
MIN_EVALS = 3


def parse_frontmatter(text):
    """Return (fields, errors, body_lines). fields[key] = (kind, value, nlines)."""
    lines = text.split("\n")
    if lines[0].rstrip() != "---":
        return None, ["FRONTMATTER: file does not start with '---'"], lines
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].rstrip() == "---")
    except StopIteration:
        return None, ["FRONTMATTER: closing '---' not found"], lines
    block, body = lines[1:end], lines[end + 1:]
    fields, errors, key, chunk = {}, [], None, []

    def close():
        if key is None:
            return
        first, rest = chunk[0], chunk[1:]
        s = first.strip()
        cont = [r.strip() for r in rest if r.strip()]
        if s[:1] in "|>" and s:
            fields[key] = ("block", "\n".join(cont) if s[0] == "|" else " ".join(cont), len(chunk))
        elif s[:1] in "\"'":
            joined = " ".join([s] + cont)
            if len(joined) < 2 or joined[-1] != s[0]:
                errors.append(f"YAML-QUOTE: '{key}' has an unclosed quote")
            fields[key] = ("quoted", joined[1:-1], len(chunk))
        elif s == "" and cont:
            fields[key] = ("nested", cont, len(chunk))
        else:
            text_ = " ".join([s] + cont).strip()
            if ": " in text_ or text_.endswith(":"):
                multi = len(chunk) > 1
                errors.append(
                    f"YAML-COLON: '{key}' is an unquoted {'multi-line ' if multi else ''}"
                    f"value containing ': ' (invalid strict YAML; claude.ai upload rejects it)"
                    + ("; Claude Code may list the skill with NO description (seen on 5 kit skills), so it never triggers"
                       if multi and key == "description" else "")
                    + ". Fix: quote it or use '>-'.")
            if text_[:1] in "@`%":
                errors.append(f"YAML-INDICATOR: '{key}' value starts with reserved '{text_[0]}'")
            fields[key] = ("plain", text_, len(chunk))

    for ln in block:
        if "\t" in ln[: len(ln) - len(ln.lstrip())]:
            errors.append("YAML-TAB: tab used for indentation in frontmatter")
        m = re.match(r"^([A-Za-z0-9_-]+):(?:\s+(.*))?$", ln)
        if m and not ln.startswith((" ", "\t")):
            close()
            key, chunk = m.group(1), [m.group(2) or ""]
        elif key is not None:
            chunk.append(ln)
        elif ln.strip() and not ln.lstrip().startswith("#"):
            errors.append(f"YAML-LINE: cannot read frontmatter line: {ln[:40]!r}")
    close()
    return fields, errors, body


def value(fields, key):
    f = fields.get(key)
    return None if f is None else (f[1] if isinstance(f[1], str) else "")


def skill_md_count(root):
    n = 0
    for p in root.rglob("SKILL.md"):
        rel = p.relative_to(root).parts[:-1]
        if any(x in SKIP_DIRS for x in rel) or (rel and rel[0] == "evals"):
            continue
        n += 1
    return n


def check_resources(root, body_text):
    fails, warns = [], []
    refs = set(re.findall(r"\]\(([^)#\s]+\.md)\)", body_text)) | set(
        re.findall(r"`([A-Za-z0-9_./-]+\.md)`", body_text))
    for r in sorted(refs):
        p = (root / r)
        if not p.is_file():
            continue
        depth = len(Path(r).parts) - 1
        if depth > 1:
            warns.append(f"RESOURCE-DEPTH: {r} is nested {depth} folders deep")
        text = p.read_text(errors="replace")
        if len(text.split("\n")) > TOC_OVER and not re.search(
                r"(?im)^#+\s*(table of )?contents|^contents\s*$|(\]\(#[^)]+\)[^\n]*\n){3}", text):
            fails.append(f"RESOURCE-TOC: {r} is over {TOC_OVER} lines and has no table of contents")
        for other in re.findall(r"\]\(([^)#\s]+\.md)\)", text):
            if (root / other).is_file() and other not in (r, "SKILL.md"):
                warns.append(f"RESOURCE-CHAIN: {r} links to {other} (keep references one level deep)")
    return fails, warns


def count_evals(root):
    ej = root / "evals" / "evals.json"
    if ej.is_file():
        try:
            data = json.loads(ej.read_text())
            return len(data.get("evals", data) if isinstance(data, dict) else data)
        except (ValueError, TypeError):
            return 0
    d = root / "evals"
    return sum(1 for c in d.iterdir() if c.is_dir()) if d.is_dir() else 0


def lint(root, ship):
    fails, warns = [], []
    md = root / "SKILL.md"
    if not md.is_file():
        return ["SKILL-MD: no SKILL.md in this folder"], []
    n = skill_md_count(root)
    if n > 1:
        fails.append(f"SKILL-MD-COUNT: {n} SKILL.md files; a skill may hold exactly one")
    text = md.read_text(errors="replace")
    fields, errs, body = parse_frontmatter(text)
    fails += errs
    if fields is None:
        return fails, warns
    try:  # optional second opinion
        import yaml
        if not errs:
            yaml.safe_load("\n".join(text.split("\n")[1:text.split("\n").index("---", 1)]))
    except ImportError:
        pass
    except Exception as e:  # noqa: BLE001 - report whatever PyYAML says
        fails.append(f"YAML-PARSE: PyYAML rejects the frontmatter: {str(e).splitlines()[0]}")

    for k in sorted(set(fields) - STRICT_KEYS):
        if k in CC_KEYS:
            warns.append(f"KEY-CLAUDE-CODE-ONLY: '{k}' is not portable; claude.ai and the Skills API ignore or reject it")
        else:
            fails.append(f"KEY-UNKNOWN: unexpected frontmatter key '{k}'")
    name, desc = value(fields, "name"), value(fields, "description")
    if not name:
        fails.append("NAME-MISSING: 'name' is missing or empty")
    else:
        if len(name) > MAX_NAME:
            fails.append(f"NAME-LENGTH: {len(name)} chars, max {MAX_NAME}")
        if not re.fullmatch(r"[a-z0-9-]+", name) or name[0] == "-" or name[-1] == "-" or "--" in name:
            fails.append(f"NAME-CHARS: '{name}' must be lowercase letters, digits, single hyphens")
        if re.search(r"anthropic|claude", name):
            fails.append("NAME-RESERVED: name may not contain 'anthropic' or 'claude'")
        if name != root.name:
            warns.append(f"NAME-FOLDER: name '{name}' differs from folder '{root.name}'")
    if not desc:
        if "description" in fields:
            fails.append("DESC-EMPTY: description is empty")
        else:
            fails.append("DESC-MISSING: 'description' is missing")
    else:
        if len(desc) > MAX_DESC:
            fails.append(f"DESC-LENGTH: {len(desc)} chars, max {MAX_DESC}")
        if "<" in desc or ">" in desc:
            fails.append("DESC-ANGLE: description contains '<' or '>' (XML-like text)")
        if re.search(r"\b(I can|I will|I help|you can|you should|your)\b", desc, re.I):
            warns.append("DESC-VOICE: use third person (no 'I' / 'you')")
        if not re.search(r"\b(use|when|whenever|on|before|after)\b", desc, re.I):
            warns.append("DESC-WHEN: description should say when to use the skill")
    if len(body) > MAX_BODY_LINES - 1:
        fails.append(f"BODY-LENGTH: {len(body)} body lines, must be under {MAX_BODY_LINES}")
    body_text = "\n".join(body)
    if re.search(r"(?<![\w/])[\w.-]+\\[\w.-]+\.(md|py|sh|json)\b", body_text):
        fails.append("PATH-BACKSLASH: use forward slashes in file paths")
    f2, w2 = check_resources(root, body_text)
    fails += f2
    warns += w2
    for sp in sorted((root / "scripts").glob("*.py")) if (root / "scripts").is_dir() else []:
        if re.search(r"except[^\n]*:\s*\n\s*pass\b", sp.read_text(errors="replace")):
            warns.append(f"SCRIPT-PUNT: {sp.name} swallows an exception with 'pass'")
    if ship and count_evals(root) < MIN_EVALS:
        fails.append(f"EVALS: fewer than {MIN_EVALS} eval cases under evals/")
    return fails, warns


def main(argv):
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
