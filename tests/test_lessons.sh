#!/usr/bin/env bash
# A lesson is recorded only with the evidence it rests on (scripts/check-lessons.sh).
#
# Taken from harness2 (google-research/harness2, core/library.py has_experience): a lesson
# is stored only with its cue, a lesson naming the component it changes, and the evidence;
# each gets a verdict of helped | hurt | no observed effect | confounded; and a lesson
# resting on "confounded" is a guess. Before this, a plausible lesson in
# STRUCTURAL_PROBLEMS.md weighed the same as a proven one. Warn-tier, added rows only.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target=$(fresh_install); cd "$target"
git add -A && git commit -qm install --no-verify
grep -q '| Row | Cue | Lesson | Evidence | Verdict |' STRUCTURAL_PROBLEMS.md || fail "template lacks the evidence columns"
add_row() { python3 -I - "$1" <<'PY'
import sys
p = "STRUCTURAL_PROBLEMS.md"; s = open(p).read()
head = "| Row | Cue | Lesson | Evidence | Verdict |\n|---|---|---|---|---|\n"
assert head in s
open(p, "w").write(s.replace(head, head + sys.argv[1] + "\n", 1))
PY
git add STRUCTURAL_PROBLEMS.md; }
check() { ./scripts/check-lessons.sh --staged > "$SCRATCH/out" 2>&1; }

add_row '| **L-1** | a check that can silently stop running | `pre-commit.sh` says DID NOT RUN when a check is missing | GLOOD: reports check skipped silently for weeks | helped · high: the warning fired on the first commit |'
check || { cat "$SCRATCH/out" >&2; fail "a complete lesson should pass"; }
git commit -qm l1 --no-verify
ok "a complete lesson passes"

add_row '| **L-2** | sessions forget things | write more docs |  | helped · low |'
check && fail "a lesson with no evidence should warn"
grep -q "L-2.*evidence" "$SCRATCH/out" || { cat "$SCRATCH/out" >&2; fail "warning should say evidence is missing"; }
grep -q "L-2.*component" "$SCRATCH/out" || { cat "$SCRATCH/out" >&2; fail "warning should say no component is named"; }
git checkout -q HEAD -- STRUCTURAL_PROBLEMS.md && git reset -q
ok "missing evidence and an unnamed component warn"

add_row '| **L-3** | big edits | split `CLAUDE.md` | one session, three things changed at once | confounded · low |'
check && fail "a confounded lesson should warn"
grep -q "L-3.*guess" "$SCRATCH/out" || { cat "$SCRATCH/out" >&2; fail "a confounded lesson should be called a guess"; }
git checkout -q HEAD -- STRUCTURAL_PROBLEMS.md && git reset -q
ok "a lesson resting on confounded evidence is flagged as a guess"

add_row '| **L-4** | x | `y` | z | maybe |'
check && fail "an unknown verdict should warn"
git checkout -q HEAD -- STRUCTURAL_PROBLEMS.md && git reset -q
ok "the verdict vocabulary is enforced"

# The dashboard reads both formats by column name, not position.
if command -v node >/dev/null; then
  (cd bug-tracker-dashboard/app && node scripts/generate-bug-catalog.mjs) > "$SCRATCH/gen" 2>&1 || { cat "$SCRATCH/gen" >&2; fail "bug catalog generator failed"; }
  grep -q 'says DID NOT RUN when a check is missing' bug-tracker-dashboard/app/src/data/bugCatalog.ts || fail "new-format lesson not in the catalog"
  grep -q 'helped' bug-tracker-dashboard/app/src/data/bugCatalog.ts || fail "the verdict did not reach the catalog"
  ok "the dashboard reads the new lessons format"
fi
