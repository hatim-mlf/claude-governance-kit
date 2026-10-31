#!/usr/bin/env bash
# update.sh brings an installed project up to the kit, touching only kit-owned files.
#
# Why it exists: install.sh never overwrites, which is right for a first install and
# meant fixes never reached the six projects already running the kit.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target=$(fresh_install)
cd "$target"
git add -A && git commit -qm install --no-verify

# Simulate a project on an older kit: a stale script, a retired rule, a project's own
# rule and CLAUDE.md edits, which must all survive except the retired rule.
echo "# old" >> scripts/check-reports.sh
echo "old rule" > .claude/rules/skills-stay-indexed.md
echo "project rule" > .claude/rules/my-app-invariant.md
echo "project line" >> CLAUDE.md
git add -A && git commit -qm "older kit" --no-verify

# Refuses while kit-owned paths have uncommitted changes.
echo "wip" >> scripts/pre-commit.sh
bash "$KIT_ROOT/update.sh" "$target" > "$SCRATCH/u.log" 2>&1 && fail "update ran over uncommitted changes in scripts/"
git checkout -q -- scripts/pre-commit.sh
ok "refuses while kit-owned paths have uncommitted changes"

bash "$KIT_ROOT/update.sh" "$target" > "$SCRATCH/u.log" 2>&1 || { cat "$SCRATCH/u.log" >&2; fail "update failed"; }
cmp -s scripts/check-reports.sh "$KIT_ROOT/scripts/check-reports.sh" || fail "stale kit script not replaced"
[ ! -e .claude/rules/skills-stay-indexed.md ] || fail "retired rule not removed"
[ -f .claude/rules/changing-the-governance-system.md ] || fail "current governance rule not installed"
grep -q "project rule" .claude/rules/my-app-invariant.md || fail "project's own rule was touched"
grep -q "project line" CLAUDE.md || fail "CLAUDE.md was touched"
[ -f .claude/governance-kit-version ] || fail "kit version not recorded"
grep -q "CLAUDE.md" "$SCRATCH/u.log" || fail "hand-merge list should name CLAUDE.md"
ok "kit files replaced, retired files removed, project files untouched"

# Undo is one command and leaves the project exactly as before.
eval "$(grep -A1 'To undo' "$SCRATCH/u.log" | tail -1)"
[ -z "$(git status --porcelain)" ] || { git status --short >&2; fail "printed undo command did not restore the project"; }
ok "the printed undo command restores the project"
