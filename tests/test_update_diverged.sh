#!/usr/bin/env bash
# update.sh never overwrites a kit-owned file the project has changed beyond the kit.
#
# Pinned by GLOOD (2026-10-31): its generate-ledger-catalog.mjs had week-file path
# mapping the kit never received, and the first update.sh would have replaced it with
# the kit's older copy. A file whose exact content exists somewhere in the kit's history
# is merely behind and is replaced. A file whose content the kit has never seen is
# DIVERGED: it is kept, listed, and `--collect` copies it back into the kit for review.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# A throwaway kit clone, so --collect can write into it.
kit="$SCRATCH/kit"; git clone -q "$KIT_ROOT" "$kit"
# The clone has the last commit; the project below is installed from the working tree.
# Commit the working tree into the clone so the two agree, as they do after a release.
(cd "$KIT_ROOT" && git ls-files -co --exclude-standard -z | tar cf - --null -T -) | (cd "$kit" && tar xf -)
git -C "$kit" add -A
git -C "$kit" -c user.email=t@t -c user.name=t commit -qm "working tree under test" --allow-empty
target=$(fresh_install); cd "$target"
git add -A && git commit -qm install --no-verify

# Behind: an older kit version of a file (present in the kit's history).
old=$(git -C "$kit" log --format=%H -- scripts/pre-commit.sh | tail -1)
behind=0
if [ "$(git -C "$kit" log --format=%H -- scripts/pre-commit.sh | wc -l)" -gt 1 ]; then
  git -C "$kit" show "$old:scripts/pre-commit.sh" > scripts/pre-commit.sh; behind=1
fi
# Diverged: a change the kit has never seen.
echo "// project fix the kit never got" >> scripts/check-reports.sh
git add -A && git commit -qm "older + local" --no-verify

bash "$kit/update.sh" "$target" > "$SCRATCH/u.log" 2>&1 && { cat "$SCRATCH/u.log" >&2; fail "update should exit non-zero when files diverged"; }
grep -q "project fix the kit never got" scripts/check-reports.sh || fail "diverged file was overwritten"
grep -q "diverged.*scripts/check-reports.sh" "$SCRATCH/u.log" || { cat "$SCRATCH/u.log" >&2; fail "diverged file not listed"; }
if [ "$behind" -eq 1 ]; then
  cmp -s scripts/pre-commit.sh "$kit/scripts/pre-commit.sh" || fail "a file that was merely behind was not updated"
fi
ok "diverged files are kept and listed; files that are behind are updated"

bash "$kit/update.sh" --collect "$target" > "$SCRATCH/c.log" 2>&1 || { cat "$SCRATCH/c.log" >&2; fail "--collect failed"; }
grep -q "project fix the kit never got" "$kit/scripts/check-reports.sh" || fail "--collect did not copy the diverged file into the kit"
[ "$(git -C "$kit" status --porcelain)" = " M scripts/check-reports.sh" ] || { git -C "$kit" status --short >&2; fail "--collect touched more than the diverged file"; }
ok "--collect copies exactly the diverged files back into the kit"
