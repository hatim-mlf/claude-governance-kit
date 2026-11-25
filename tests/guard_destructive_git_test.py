"""The Bash guard refuses git commands that discard uncommitted work (python3 -I <this file>)."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

GUARD = Path(__file__).resolve().parents[1] / "scripts" / "guard-destructive-git.py"

BLOCKED = [
    "git checkout -- .",
    "git -C \"/work/project\" checkout --quiet -- .",
    "git checkout HEAD -- lib/a.dart",
    "git checkout .",
    "git checkout -f main",
    "git restore lib/a.dart",
    "git restore --staged --worktree lib/a.dart",
    "git reset --hard",
    "git reset --hard HEAD~1",
    "git reset --merge",
    "git clean -fd",
    "git clean -xdf",
    "git stash",
    "git stash push -m wip",
    "git stash drop",
    "git switch --discard-changes main",
    "git switch -f main",
    "cd /tmp && git checkout -- .",
    "ls; git reset --hard origin/main",
    "bash -c 'git checkout -- .'",
    "GIT_DIR=x git clean -f",
    "/usr/bin/git restore .",
]

ALLOWED = [
    "git status --short",
    "git diff -- lib/a.dart",
    "git add lib/a.dart",
    "git commit -q -F msg.txt",
    "git log --oneline -5",
    "git show HEAD:lib/a.dart",
    "git checkout -b feature/x",
    "git checkout main",
    "git switch main",
    "git restore --staged lib/a.dart",
    "git reset HEAD lib/a.dart",
    "git reset --soft HEAD~1",
    "git clean -n",
    "git clean --dry-run -d",
    "git stash list",
    "git stash show -p",
    "git fsck --unreachable --no-reflogs",
    "echo 'never run git checkout -- . here'",
    "grep -n 'git reset --hard' reports/errors/x.md",
    "printf '%s\\n' \"git clean -fd is blocked\" > note.txt",
]


def run(command):
    payload = json.dumps({"tool_input": {"command": command}})
    return subprocess.run([sys.executable, "-I", str(GUARD)], input=payload, text=True,
                          capture_output=True, check=False)


class GuardDestructiveGitTest(unittest.TestCase):
    def test_blocks_commands_that_discard_work(self):
        for command in BLOCKED:
            with self.subTest(command=command):
                result = run(command)
                self.assertEqual(result.returncode, 2, command)
                self.assertIn("discard", result.stderr)

    def test_allows_safe_git_and_text_that_mentions_git(self):
        for command in ALLOWED:
            with self.subTest(command=command):
                self.assertEqual(run(command).returncode, 0, command)

    def test_unparseable_command_falls_back_to_command_position_scan(self):
        self.assertEqual(run("echo \"unbalanced; git reset --hard").returncode, 2)
        self.assertEqual(run("echo \"it's fine").returncode, 0)


if __name__ == "__main__":
    unittest.main()
