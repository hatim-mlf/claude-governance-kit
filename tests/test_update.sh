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
# "Older kit" means content the kit once shipped: the oldest committed version of a
# script, so update.sh sees it as behind (not diverged) and replaces it.
stale=scripts/pre-commit.sh
oldest=$(git -C "$KIT_ROOT" log --format=%H -- "$stale" | tail -1)
git -C "$KIT_ROOT" show "$oldest:$stale" > "$stale"
cmp -s "$stale" "$KIT_ROOT/$stale" && fail "test setup: need a kit history with an older $stale (shallow clone?)"
echo "old rule" > .claude/rules/skills-stay-indexed.md
echo "project rule" > .claude/rules/my-app-invariant.md
echo "project line" >> CLAUDE.md
rm -rf obligations   # a project installed before obligations/ existed
git add -A && git commit -qm "older kit" --no-verify

# The project's own code under scripts/ (GLOOD keeps app scripts in scripts/maps/):
# one committed and then modified, one untracked. Neither is the kit's, so neither may
# block the update, be touched by it, or be removed by its undo.
mkdir -p scripts/maps && echo "v1" > scripts/maps/app.py && git add -A && git commit -qm app --no-verify
echo "v2 wip" >> scripts/maps/app.py
echo "new" > scripts/maps/untracked.py

# Refuses while kit-owned paths have uncommitted changes.
echo "wip" >> scripts/check-reports.sh
bash "$KIT_ROOT/update.sh" "$target" > "$SCRATCH/u.log" 2>&1 && fail "update ran over uncommitted changes in scripts/"
git checkout -q -- scripts/check-reports.sh
ok "refuses while kit-owned paths have uncommitted changes"

bash "$KIT_ROOT/update.sh" "$target" > "$SCRATCH/u.log" 2>&1 || { cat "$SCRATCH/u.log" >&2; fail "update failed"; }
cmp -s "$stale" "$KIT_ROOT/$stale" || fail "stale kit script not replaced"
[ ! -e .claude/rules/skills-stay-indexed.md ] || fail "retired rule not removed"
[ -f .claude/rules/changing-the-governance-system.md ] || fail "current governance rule not installed"
grep -q "project rule" .claude/rules/my-app-invariant.md || fail "project's own rule was touched"
grep -q "project line" CLAUDE.md || fail "CLAUDE.md was touched"
[ -f .claude/governance-kit-version ] || fail "kit version not recorded"
[ -f obligations/OBLIGATIONS.md ] && [ -f obligations/README.md ] || fail "update did not create obligations/ for an older project"
grep -q "CLAUDE.md" "$SCRATCH/u.log" || fail "hand-merge list should name CLAUDE.md"
ok "kit files replaced, retired files removed, project files untouched"

# Undo is one command and leaves the project exactly as before.
grep -q "v2 wip" scripts/maps/app.py && [ -f scripts/maps/untracked.py ] || fail "update touched the project's own scripts"
eval "$(grep -A1 'To undo' "$SCRATCH/u.log" | tail -1)"
grep -q "v2 wip" scripts/maps/app.py || fail "undo reverted the project's own uncommitted work"
[ -f scripts/maps/untracked.py ] || fail "undo deleted the project's own untracked file"
[ "$(git status --porcelain)" = "$(printf ' M scripts/maps/app.py\n?? scripts/maps/untracked.py')" ] \
  || { git status --short >&2; fail "printed undo command did not restore the kit files"; }
ok "the printed undo command restores the project"
