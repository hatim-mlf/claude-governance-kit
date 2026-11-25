#!/usr/bin/env python3
"""Run local lint, then delegate trigger eval to a reviewed skill-creator checkout."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from lint_skill import LintError, lint


def has_runner(path):
    return (path / "scripts/run_eval.py").is_file()


def find_runners(project, account):
    candidates = [
        project / ".claude/skills/skill-creator",
        account / "skills/skill-creator",
        *account.glob("skills/synced/*/skill-creator"),
        *account.glob("plugins/cache/*/*/*/skills/skill-creator"),
    ]
    return sorted({path.resolve() for path in candidates if has_runner(path)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skill_dir", type=Path)
    parser.add_argument("--eval-set", type=Path, required=True)
    parser.add_argument("--eval-project", type=Path, required=True)
    parser.add_argument("--skill-creator", type=Path, help="Explicit path to a reviewed copy")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    try:
        description, status = lint(args.skill_dir, args.release)
    except (LintError, OSError, UnicodeError) as error:
        print(f"FAIL {args.skill_dir.name} — {error}")
        return 1
    print(f"PASS {args.skill_dir.name} — {status}", flush=True)

    account = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")).expanduser()
    if args.skill_creator is None or not has_runner(args.skill_creator):
        candidates = find_runners(args.eval_project, account) if args.skill_creator is None else []
        if candidates:
            print("Trigger eval blocked — review a copy and rerun with --skill-creator DIR.")
            for candidate in candidates:
                print(f"  {candidate}")
        else:
            print("Trigger eval blocked — Anthropic skill-creator is missing (scripts/run_eval.py).")
            print("Install Anthropic's skill-creator plugin or obtain its source, review the scripts,")
            print("then rerun with --skill-creator DIR pointing to the copy containing scripts/run_eval.py.")
        return 2
    if not (args.eval_project / ".claude").is_dir() or not args.eval_set.is_file():
        print("Trigger eval blocked — provide a scratch project with .claude/ and an eval JSON file.")
        return 2
    if not shutil.which("claude"):
        print("Trigger eval blocked — install Claude Code and put claude on PATH.")
        return 2
    provider = args.skill_creator.resolve()
    # Keep evaluation in the scratch project while importing the reviewed Python module.
    launch = (
        "import runpy, sys\n"
        "sys.path.insert(0, sys.argv.pop(1))\n"
        "runpy.run_module('scripts.run_eval', run_name='__main__', alter_sys=True)\n"
    )
    return subprocess.run(
        [sys.executable, "-B", "-I", "-c", launch, str(provider),
         "--eval-set", str(args.eval_set.resolve()), "--skill-path", str(args.skill_dir.resolve()),
         f"--description={description}", "--runs-per-query", "3"],
        cwd=args.eval_project, check=False,
    ).returncode


if __name__ == "__main__":
    sys.exit(main())
