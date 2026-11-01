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

# A diverged file the project declares as its own is skipped quietly: exit 0, untouched.
git -C "$kit" checkout -q -- . 2>/dev/null || true
python3 -I -c 'import json; c=json.load(open("governance.config.json")); c.setdefault("kit",{})["projectOwned"]=["scripts/check-reports.sh"]; json.dump(c,open("governance.config.json","w"),indent=2)'
git add -A && git commit -qm "declare fork" --no-verify
bash "$kit/update.sh" "$target" > "$SCRATCH/p.log" 2>&1 || { cat "$SCRATCH/p.log" >&2; fail "a projectOwned file should not make the update fail"; }
grep -q "project fix the kit never got" scripts/check-reports.sh || fail "projectOwned file was overwritten"
grep -q "project-owned.*scripts/check-reports.sh" "$SCRATCH/p.log" || { cat "$SCRATCH/p.log" >&2; fail "projectOwned file not reported as skipped"; }
ok "kit.projectOwned files are kept and the update succeeds"

# A kit file the project deliberately does not have stays absent when it is listed in
# kit.projectOwned. GLOOD deletes project-code-review (it has its own) and the update
# kept re-adding it.
rm -rf .claude/skills/project-code-review
python3 -I -c 'import json; c=json.load(open("governance.config.json")); c["kit"]["projectOwned"].append(".claude/skills/project-code-review/SKILL.md"); json.dump(c,open("governance.config.json","w"),indent=2)'
git add -A && git commit -qm "drop project-code-review" --no-verify
bash "$kit/update.sh" "$target" > "$SCRATCH/a.log" 2>&1 || { cat "$SCRATCH/a.log" >&2; fail "update failed"; }
[ ! -e .claude/skills/project-code-review/SKILL.md ] || fail "a projectOwned file the project removed was added back"
grep -q "project-code-review.*absent by choice" "$SCRATCH/a.log" || { cat "$SCRATCH/a.log" >&2; fail "the skipped add was not reported"; }
ok "a projectOwned file the project removed stays removed"

# A project-owned file with uncommitted changes does not block the update: update.sh never
# writes it. EduFlow (2026-10-31) was refused over its own generator, which it was editing.
echo "// work in progress" >> scripts/check-reports.sh      # listed in kit.projectOwned above
bash "$kit/update.sh" --dry-run "$target" > "$SCRATCH/w.log" 2>&1 || { cat "$SCRATCH/w.log" >&2; fail "an uncommitted projectOwned file blocked the update"; }
git checkout -q -- scripts/check-reports.sh
ok "an uncommitted change to a projectOwned file does not block the update"

# A review branch in the kit (mirror/<project>, made by --collect) holds the project's own
# versions. Those must not count as "the kit once shipped this": only the kit's checked-out
# branch is the kit. On 2026-11-01, mirror/eduflow made EduFlow's 15 improved files look
# "behind", and update.sh replaced them with the kit's older versions.
echo "// project's own improvement" >> scripts/check-ledger-entries.sh
git add -A && git commit -qm "project improves a kit file" --no-verify
mainbranch=$(git -C "$kit" rev-parse --abbrev-ref HEAD)
git -C "$kit" checkout -q -b mirror/project
cp scripts/check-ledger-entries.sh "$kit/scripts/check-ledger-entries.sh"
git -C "$kit" -c user.email=t@t -c user.name=t commit -qam "mirror: the project's version"
git -C "$kit" checkout -q "$mainbranch"
bash "$kit/update.sh" "$target" > "$SCRATCH/m.log" 2>&1 || true
grep -q "project's own improvement" scripts/check-ledger-entries.sh || { cat "$SCRATCH/m.log" >&2; fail "a version found only on a kit review branch was treated as the kit's, and overwritten"; }
grep -q "diverged.*scripts/check-ledger-entries.sh" "$SCRATCH/m.log" || { cat "$SCRATCH/m.log" >&2; fail "it should be listed as diverged"; }
ok "a version on a kit review branch is not the kit's: the project's file is kept"
