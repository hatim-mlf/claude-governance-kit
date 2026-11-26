#!/usr/bin/env python3
"""Find Anthropic's skill-creator (needed only for task evals and description tuning).

usage: find_skill_creator.py [--skill-creator DIR]
Prints the folder on stdout and exits 0. Exits 3 when none is found, or when several are
found: the copies on one machine have been seen to differ (2026-11-25: three copies, all
different), so this never picks one for you. Choose with --skill-creator or SKILL_CREATOR_DIR.
Lint and trigger scoring (lint_skill.py, score_triggers.py) do not need skill-creator.
"""
from __future__ import annotations

import glob
import os
import sys
from pathlib import Path

NOT_FOUND = 3
MARKER = "scripts/run_eval.py"
SEARCH = [  # relative to $HOME; where Claude Code installs skills and plugins
    ".claude/skills/skill-creator",
    ".claude/skills/synced/*/skill-creator",
    ".claude/plugins/marketplaces/*/plugins/skill-creator/skills/skill-creator",
    ".claude/plugins/cache/*/skill-creator/*/skills/skill-creator",
    ".codex/skills/skill-creator",
    ".agents/skills/skill-creator",
]
HOW_TO_GET = (
    "Install the skill-creator plugin (/plugin, marketplace claude-plugins-official), or copy\n"
    "skills/skill-creator from github.com/anthropics/skills, read its scripts, then run again\n"
    "with --skill-creator DIR or export SKILL_CREATOR_DIR=DIR."
)


def is_creator(path: str) -> bool:
    return bool(path) and (Path(path) / MARKER).is_file()


def candidates(home: str) -> list[str]:
    found: list[str] = []
    for pattern in SEARCH:
        for p in sorted(glob.glob(os.path.join(home, pattern))):
            if is_creator(p) and p not in found:
                found.append(p)
    return found


def main(argv: list[str]) -> int:
    chosen = ""
    if argv[:1] == ["--skill-creator"] and len(argv) == 2:
        chosen = argv[1]
    elif argv:
        print("usage: find_skill_creator.py [--skill-creator DIR]", file=sys.stderr)
        return 2
    chosen = chosen or os.environ.get("SKILL_CREATOR_DIR", "")
    if chosen:
        if is_creator(chosen):
            print(chosen)
            return 0
        print(f"skill-creator not found at {chosen} (no {MARKER}).\n{HOW_TO_GET}", file=sys.stderr)
        return NOT_FOUND
    home = os.path.expanduser("~")
    found = candidates(home)
    if len(found) == 1:
        print(found[0])
        return 0
    if found:
        print(f"{len(found)} copies of skill-creator found; they may differ, so pick one with "
              "--skill-creator DIR or SKILL_CREATOR_DIR:", file=sys.stderr)
        print("\n".join(found), file=sys.stderr)
        return NOT_FOUND
    searched = "\n  ".join(["$SKILL_CREATOR_DIR"] + [f"{home}/{p}" for p in SEARCH])
    print(f"Anthropic's skill-creator is missing (needs {MARKER}); task evals and description "
          f"tuning cannot run. Lint and trigger scoring still work.\nSearched:\n  {searched}\n"
          f"{HOW_TO_GET}", file=sys.stderr)
    return NOT_FOUND


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
