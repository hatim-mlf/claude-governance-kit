#!/usr/bin/env python3
"""Lint one SKILL.md directory. Use --release to require task eval fixtures."""

import argparse
from pathlib import Path
import re
import sys
from urllib.parse import unquote


PORTABLE = set("name description license allowed-tools metadata compatibility".split())
CLAUDE_CODE = set("""
    when_to_use argument-hint arguments disable-model-invocation user-invocable
    disallowed-tools model effort context agent background hooks paths shell
""".split())
MAX_NAME = 64
MAX_DESCRIPTION = 1024
MAX_COMPATIBILITY = 500
BODY_LIMIT = 500  # Exclusive
TOC_THRESHOLD = 100
MIN_EVALS = 3
LINK = re.compile(r"\]\(\s*(<[^>]+>|[^\s)]+)|^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)", re.M)
INLINE_CODE = re.compile(r"`([^`\n]+)`")
WINDOWS_PATH = re.compile(r"(?<![\w\\])(?:[A-Za-z]:)?[\w.~%-]+\\[\w.~%-]+|\\\\[\w.-]+\\")
TOC = re.compile(r"^ {0,3}#{1,6} (?:table of )?(?:contents|toc)[ \t#]*$", re.I | re.M)
HEADING = re.compile(r"^ {0,3}#{1,6} ", re.M)
PLAIN_DESCRIPTION = re.compile(r"description:[ \t]+[^|'\">\[\]{&*!#\s]")
TEXT_REFERENCE = {".md", ".txt"}
NON_CASE_DIRS = {"files", "results", "mocks", "node_modules"}


class LintError(ValueError):
    pass


def frontmatter(root):
    try:
        import yaml
    except ImportError as error:
        raise LintError(
            f"YAML dependency: install PyYAML in a venv with '{sys.executable} -m venv .venv' "
            "and '.venv/bin/python -m pip install PyYAML', then rerun with .venv/bin/python"
        ) from error

    lines = (root / "SKILL.md").read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        raise LintError("frontmatter delimiters: require opening and closing --- lines")
    end = lines.index("---", 1)
    header = lines[1:end]
    raw = "\n".join(header)
    try:
        node = yaml.compose(raw, Loader=yaml.SafeLoader)
        fields = yaml.safe_load(raw)
    except yaml.YAMLError as error:
        mark = getattr(error, "problem_mark", None)
        prefix = header[:mark.line] if mark else []
        while prefix and (prefix[-1][:1].isspace() or not prefix[-1].strip()):
            prefix.pop()
        offending = header[mark.line] if mark and mark.line < len(header) else ""
        if (prefix and PLAIN_DESCRIPTION.match(prefix[-1]) and offending[:1].isspace()
                and re.search(r":[ \t]+|:$", offending)):
            raise LintError(
                f"strict YAML at SKILL.md:{mark.line + 2}: colon separator in a multi-line "
                "plain description; Claude Code can drop the description; use >- or quote it"
            ) from error
        details = getattr(error, "problem", None) or type(error).__name__
        location = f" at SKILL.md:{mark.line + 2}" if mark else ""
        raise LintError(f"strict YAML{location}: {details}") from error
    if not isinstance(fields, dict) or any(not isinstance(key, str) for key in fields):
        raise LintError("frontmatter mapping: require a YAML mapping with string keys")
    keys = [key.value for key, _ in node.value]
    if len(set(keys)) != len(keys) or any(key.tag.endswith(":merge") for key, _ in node.value):
        raise LintError("frontmatter keys: duplicate or merged top-level keys")
    return fields, lines[end + 1:]


def validate_fields(fields):
    unknown = fields.keys() - PORTABLE - CLAUDE_CODE
    if unknown:
        raise LintError(f"frontmatter keys: unknown {', '.join(sorted(unknown))}")
    name = fields.get("name")
    if (not isinstance(name, str) or len(name) > MAX_NAME
            or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)):
        raise LintError(f"name: require 1–{MAX_NAME} lowercase letters/digits with single interior hyphens")
    if "anthropic" in name or "claude" in name:
        raise LintError("name: reserved substring anthropic or claude")

    description = fields.get("description")
    if not isinstance(description, str) or not description.strip():
        raise LintError("description: require non-empty text")
    if len(description) > MAX_DESCRIPTION:
        raise LintError(f"description length: maximum {MAX_DESCRIPTION} characters")
    if "<" in description or ">" in description:
        raise LintError("description angle brackets: remove < and >")
    prose = re.sub(r'''"[^"]*"|“[^”]*”|(?<!\w)'[^'\n]+'(?!\w)|`[^`]*`''', "", description)
    if re.search(r"\b(?:I|[Ww]e|[Mm]y|[Oo]ur|[Mm]e|[Uu]s)\b", prose):
        raise LintError("description voice: write the description in third person")
    compatibility = fields.get("compatibility", "")
    if not isinstance(compatibility, str) or len(compatibility) > MAX_COMPATIBILITY:
        raise LintError(f"compatibility: require text of at most {MAX_COMPATIBILITY} characters")
    return description


def check_body(root, lines):
    if len(lines) >= BODY_LIMIT:
        raise LintError(f"body length: {len(lines)} lines, require fewer than {BODY_LIMIT}")
    body = "\n".join(lines)
    references = set(root.glob("*.md")) - {root / "SKILL.md"}
    references.update(path for path in (root / "references").rglob("*") if path.is_file())
    linked = {root / target for target in INLINE_CODE.findall(body)}
    for match in LINK.finditer(body):
        target = unquote((match[1] or match[2]).strip("<>").split("#", 1)[0])
        if re.match(r"^[a-z][a-z0-9+.-]*://", target, re.I) or not target:
            continue
        if "\\" in target:
            raise LintError("forward-slash paths: backslash in SKILL.md link")
        linked.add(root / target)
    for path in linked:
        if (path.is_relative_to(root) and ".." not in path.relative_to(root).parts
                and path.suffix.lower() in TEXT_REFERENCE and path != root / "SKILL.md"
                and path.is_file()):
            references.add(path)
    documents = [body]
    for path in sorted(references):
        relative = path.relative_to(root)
        if len(relative.parts) > 2:
            raise LintError(f"reference depth: {relative.as_posix()} is nested more than one directory")
        if path not in linked:
            raise LintError(f"reference depth: link directly from SKILL.md to {relative.as_posix()}")
        if path.suffix.lower() not in TEXT_REFERENCE:
            continue
        content = path.read_text(encoding="utf-8")
        if len(content.splitlines()) > TOC_THRESHOLD:
            heading = TOC.search(content)
            following = HEADING.split(content[heading.end():], maxsplit=1)[0] if heading else ""
            if not re.search(r"\]\(#[^)]+\)", following) and not re.search(r"^\[TOC\]$", content, re.M):
                raise LintError(f"reference TOC: {relative.as_posix()} exceeds {TOC_THRESHOLD} lines")
        documents.append(content)
    if any(WINDOWS_PATH.search(document) for document in documents):
        raise LintError("forward-slash paths: use / in SKILL.md and text references")


def count_evals(root):
    def has_content(path):
        return path.is_file() and bool(path.read_text(encoding="utf-8").strip())

    return sum(
        has_content(case / "case.yaml") and has_content(case / "prompt.md")
        and any(has_content(grader) for grader in (case / "graders").glob("*.md"))
        for case in (root / "evals").glob("*") if case.is_dir() and case.name not in NON_CASE_DIRS
    )


def lint(root, release=False):
    fields, lines = frontmatter(root)
    description = validate_fields(fields)
    for path in root.rglob("SKILL.md"):
        dirs = path.relative_to(root).parts[:-1]
        if dirs and dirs[0] != "evals" and not {"node_modules", "__pycache__"}.intersection(dirs):
            raise LintError(f"single SKILL.md: nested file {path.relative_to(root).as_posix()}")
    check_body(root, lines)
    if release:
        count = count_evals(root)
        if count < MIN_EVALS:
            raise LintError(f"eval count: require at least {MIN_EVALS} complete case folders, found {count}")
    extras = sorted(fields.keys() & CLAUDE_CODE)
    status = "release structure valid" if release else "structure valid"
    if extras:
        status += f"; WARN Claude Code-only keys: {', '.join(extras)}"
    return description, status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skill_dir", type=Path)
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    try:
        _, status = lint(args.skill_dir, args.release)
    except (LintError, OSError, UnicodeError) as error:
        print(f"FAIL {args.skill_dir.name} — {error}")
        return 1
    print(f"PASS {args.skill_dir.name} — {status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
