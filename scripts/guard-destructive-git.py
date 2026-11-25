#!/usr/bin/env python3
"""Claude Bash guard: refuse git commands that discard uncommitted work in the shared folder.

Several sessions and their workers can share one working tree. One worker running
`git checkout -- .` wipes every session's unstaged edits; a no-git line in a brief is advice,
not enforcement.

Refused: checkout of paths (`--`, `.`, `-f`), restore of the working tree, reset --hard/--merge/--keep,
clean without a dry run, stash other than list/show, switch -f/--discard-changes. Everything else passes,
including text that only mentions such commands (echo, grep, printf, commit messages).
The owner can still run any of them with the `!` prefix, which does not go through this hook.
This is a guard for recognizable commands, not a shell sandbox.
"""
import json
from pathlib import Path
import re
import shlex
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "\n", "(", ")"}
SHELLS = {"sh", "bash", "zsh"}
# git global options that take a separate value, so the subcommand is found after them.
GLOBAL_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
FALLBACK = re.compile(
    r"(?:^|[;&|(\n])\s*(?:\S*/)?git\b[^;&|\n]*?\b("
    r"checkout\b[^;&|\n]*(?:\s--(?:\s|$)|\s\.(?:\s|$)|\s-f\b|--force)"
    r"|restore\b|reset\s+[^;&|\n]*--(?:hard|merge|keep)|clean\b(?![^;&|\n]*(?:-n\b|--dry-run))"
    r"|stash\b(?!\s+(?:list|show)\b)|switch\b[^;&|\n]*(?:\s-f\b|--force|--discard-changes))")


def segments(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    current = []
    for token in lexer:
        if token in SEPARATORS or (token and all(c in ";&|()\n" for c in token)):
            if current:
                yield current
            current = []
        else:
            current.append(token)
    if current:
        yield current


def git_args(words):
    """Return the arguments after `git` and its global options, or None if not a git command."""
    pos = 0
    while pos < len(words) and ASSIGNMENT.match(words[pos]):
        pos += 1
    if pos >= len(words) or Path(words[pos]).name != "git":
        return None
    pos += 1
    while pos < len(words) and words[pos].startswith("-"):
        pos += 2 if words[pos] in GLOBAL_WITH_VALUE else 1
    return words[pos:]


def discards(args):
    if not args:
        return False
    sub, rest = args[0], args[1:]
    flags = set(rest)
    if sub == "checkout":
        return "--" in rest or "." in rest or "-f" in flags or "--force" in flags
    if sub == "restore":
        staged_only = ("--staged" in flags or "-S" in flags) and not ({"--worktree", "-W"} & flags)
        return not staged_only
    if sub == "reset":
        return bool({"--hard", "--merge", "--keep"} & flags)
    if sub == "clean":
        dry = "--dry-run" in flags or any(f.startswith("-") and not f.startswith("--") and "n" in f for f in rest)
        return not dry
    if sub == "stash":
        return not rest or rest[0] not in ("list", "show")
    if sub == "switch":
        return bool({"-f", "--force", "--discard-changes"} & flags)
    return False


def blocked(command):
    try:
        for words in segments(command):
            if Path(words[0]).name in SHELLS:
                for pos, flag in enumerate(words[1:], start=1):
                    if flag.startswith("-") and not flag.startswith("--") and "c" in flag:
                        if pos + 1 < len(words) and blocked(words[pos + 1]):
                            return True
                        break
            if discards(git_args(words) or []):
                return True
        return False
    except ValueError:
        # Unbalanced quotes (often a heredoc body): scan for git at a command position instead.
        return bool(FALLBACK.search(command))


def main():
    try:
        command = json.load(sys.stdin)["tool_input"]["command"]
    except (ValueError, KeyError, TypeError):
        return 0  # Not a Bash payload this guard understands; the U-14 guard runs separately.
    if isinstance(command, str) and blocked(command):
        print("Refused: this git command would discard uncommitted work in the shared folder "
              "(git checkout -- <paths>, restore, reset --hard, clean, stash, switch -f). Other sessions' "
              "edits live here. Commit or copy what you need instead; the owner can run it with `!`.",
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
