#!/usr/bin/env bash
# update-all.sh updates every governed project in one local run, with no model involved.
#
# The operator has six projects running the kit and no session quota to update them
# (2026-10-31). Pinned: projects are found by --scan; the default is a preview that
# writes nothing; --apply updates and commits ONLY the files update.sh touched (never the
# project's own work); a project with diverged files is skipped and named; it never pushes.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mk() {  # an installed project, then made "older": a stale kit script and no obligations/
  local p="$SCRATCH/docs/$1"; mkdir -p "$p/src"; git -C "$p" init -q
  git -C "$p" config user.email t@t; git -C "$p" config user.name t
  printf 'P\n%s\nsrc\n' "$1" | bash "$KIT_ROOT/install.sh" "$p" >/dev/null 2>&1
  local oldest; oldest=$(git -C "$KIT_ROOT" log --format=%H -- scripts/pre-commit.sh | tail -1)
  git -C "$KIT_ROOT" show "$oldest:scripts/pre-commit.sh" > "$p/scripts/pre-commit.sh"
  rm -rf "$p/obligations"
  git -C "$p" add -A && git -C "$p" commit -qm "older kit" --no-verify
  echo "$p"
}
a=$(mk alpha); b=$(mk beta)
echo "// beta's own fix" >> "$b/scripts/check-reports.sh"; git -C "$b" commit -qam "beta fix" --no-verify
echo "wip" > "$a/src/work-in-progress.ts"      # the project's own uncommitted work
echo "staged" > "$a/src/staged-by-me.ts"; git -C "$a" add src/staged-by-me.ts   # and staged work
mkdir -p "$SCRATCH/docs/not-a-project"

bash "$KIT_ROOT/update-all.sh" --no-pull --scan "$SCRATCH/docs" > "$SCRATCH/dry" 2>&1 || true
grep -q "alpha" "$SCRATCH/dry" && grep -q "beta" "$SCRATCH/dry" || { cat "$SCRATCH/dry" >&2; fail "--scan did not find both projects"; }
grep -q "not-a-project" "$SCRATCH/dry" && fail "a folder without the kit was treated as a project"
[ -d "$a/obligations" ] && fail "preview wrote to a project"
ok "--scan finds governed projects, and the default is a preview"

bash "$KIT_ROOT/update-all.sh" --no-pull --apply --scan "$SCRATCH/docs" > "$SCRATCH/run" 2>&1 || true
[ -f "$a/obligations/OBLIGATIONS.md" ] || { cat "$SCRATCH/run" >&2; fail "alpha was not updated"; }
cmp -s "$a/scripts/pre-commit.sh" "$KIT_ROOT/scripts/pre-commit.sh" || fail "alpha's stale script not replaced"
[ -z "$(git -C "$a" status --porcelain -- scripts .claude obligations)" ] || { git -C "$a" status --short >&2; fail "alpha's update was not committed"; }
git -C "$a" log -1 --format=%s | grep -q "update from claude-governance-kit" || fail "alpha's commit message is wrong"
[ "$(git -C "$a" status --porcelain --untracked-files=all)" = "$(printf 'A  src/staged-by-me.ts\n?? src/work-in-progress.ts')" ] || { git -C "$a" status --short >&2; fail "alpha's own work was touched or committed"; }
git -C "$a" show --name-only --format= HEAD | grep -q "staged-by-me" && fail "the kit commit swept in work the project had staged itself"
ok "--apply updates and commits only the kit's files, leaving the project's own work alone"
# The commit is built from the touched paths alone, never with `git commit`: in EduFlow
# (35.85 GiB of history, thousands of modified files) `git commit` re-read every modified
# file and ran for many minutes, and it would also have swept in the project's own staged work.
grep -qE '^[^#]*git -C "\$p" commit( |$)' "$KIT_ROOT/update-all.sh" && fail "update-all still commits with git commit, which scans the working tree"

grep -q "beta.*diverged" "$SCRATCH/run" || { cat "$SCRATCH/run" >&2; fail "beta's divergence not reported"; }
grep -q "beta's own fix" "$b/scripts/check-reports.sh" || fail "beta's own fix was overwritten"
[ "$(git -C "$b" log -1 --format=%s)" = "beta fix" ] || fail "a diverged project was committed to"
ok "a project with diverged files is skipped and named, untouched"

# It takes the kit straight from GitHub: before updating, it fast-forwards the kit checkout
# from its remote, so the operator never runs a separate pull. It refuses a dirty or
# diverged kit checkout rather than updating projects from something nobody pushed.
# Built from scratch with an explicit main branch: CI checks out a detached merge commit,
# so cloning the kit checkout itself gives a remote with no branch to push to.
remote="$SCRATCH/remote.git"; git init -q --bare "$remote"
(cd "$KIT_ROOT" && git ls-files -co --exclude-standard -z | tar cf - --null -T -) > "$SCRATCH/wt.tar"
pub="$SCRATCH/publisher"; git init -q "$pub"; git -C "$pub" checkout -q -b main
(cd "$pub" && tar xf "$SCRATCH/wt.tar")
git -C "$pub" add -A; git -C "$pub" -c user.email=t@t -c user.name=t commit -qm "working tree"
git -C "$pub" remote add origin "$remote"; git -C "$pub" push -q origin main
git --git-dir="$remote" symbolic-ref HEAD refs/heads/main
stale="$SCRATCH/stale-kit"; git clone -q "$remote" "$stale"
echo "# published later" >> "$pub/README.md"
git -C "$pub" -c user.email=t@t -c user.name=t commit -qam "a later kit release"; git -C "$pub" push -q origin main
bash "$stale/update-all.sh" --scan "$SCRATCH/docs" > "$SCRATCH/pull" 2>&1 || true
[ "$(git -C "$stale" log -1 --format=%s)" = "a later kit release" ] || { cat "$SCRATCH/pull" >&2; fail "the kit was not brought up to date from its remote"; }
grep -q "from GitHub\|from origin" "$SCRATCH/pull" || fail "the pull was not reported"
echo dirty >> "$stale/README.md"
bash "$stale/update-all.sh" --scan "$SCRATCH/docs" > "$SCRATCH/dirty" 2>&1 && fail "a dirty kit checkout should stop the run"
grep -q "uncommitted" "$SCRATCH/dirty" || { cat "$SCRATCH/dirty" >&2; fail "the refusal should say why"; }
ok "the kit is fast-forwarded from its remote first; a dirty kit checkout stops the run"

# The kit checkout must be on its default branch. A review branch such as mirror/eduflow
# holds another project's files; updating from it would spread them to every project. The
# operator's own mirror step left the checkout there for a moment (2026-10-31).
git -C "$stale" checkout -q -- README.md
git -C "$stale" checkout -q -b mirror/someproject
bash "$stale/update-all.sh" --scan "$SCRATCH/docs" > "$SCRATCH/branch" 2>&1 && fail "update-all ran from a review branch"
grep -q "mirror/someproject" "$SCRATCH/branch" && grep -q "main" "$SCRATCH/branch" || { cat "$SCRATCH/branch" >&2; fail "the refusal should name the branch and say to switch to main"; }
ok "update-all refuses to run from a branch other than the kit's default"
