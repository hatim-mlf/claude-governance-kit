#!/usr/bin/env bash
#
# A lesson is recorded with the evidence it rests on, or not at all.
#
#   scripts/check-lessons.sh --staged   # lesson rows this commit adds (pre-commit)
#   scripts/check-lessons.sh            # every row in the Lessons table (audit mode)
#
# Taken from harness2 (google-research/harness2, core/library.py): a lesson is stored only
# with a cue, a lesson naming the component it changes, and evidence; each gets a verdict,
# helped | hurt | no observed effect | confounded; and one resting on "confounded" is a
# guess. Without this, a plausible lesson in STRUCTURAL_PROBLEMS.md weighs the same as a
# proven one, and the next session builds on it. Format: the Lessons section of that file.
#
# Warn-tier: exit 1 means findings, printed to stdout. A Lessons table still using the old
# Lesson | Origin | Action header is reported once, only when a row is added to it.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
file="$root/STRUCTURAL_PROBLEMS.md"
[ -f "$file" ] || exit 0
command -v python3 >/dev/null || { echo "Lessons check DID NOT RUN — needs python3."; exit 1; }

added=""
[ "${1:-}" = "--staged" ] && added=$(git -C "$root" diff --cached -U0 --no-color -- STRUCTURAL_PROBLEMS.md | sed -n 's/^+\(|.*\)$/\1/p')
[ "${1:-}" = "--staged" ] && [ -z "$added" ] && exit 0

python3 -I - "$file" "${1:-}" "$added" <<'PY'
import re, sys
path, mode, added = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
m = re.search(r"(?m)^## Lessons\s*$", text)
if not m: sys.exit(0)
section = text[m.end():]
nxt = re.search(r"(?m)^## ", section)
section = section[:nxt.start()] if nxt else section
rows = [l for l in section.splitlines() if l.startswith("|")]
if not rows: sys.exit(0)
header = [c.strip().lower() for c in rows[0].strip().strip("|").split("|")]
want = ["row", "cue", "lesson", "evidence", "verdict"]
targets = [r for r in rows[2:] if re.search(r"\*\*L-\d+\*\*", r)]
if mode == "--staged":
    new = set(added.splitlines())
    targets = [r for r in targets if r in new]
if not targets: sys.exit(0)
out = []
if header[:5] != want:
    print("Lessons table uses the old Lesson | Origin | Action header, so new lessons carry no evidence.")
    print("  Switch it to | Row | Cue | Lesson | Evidence | Verdict | (see the kit's STRUCTURAL_PROBLEMS.md).")
    sys.exit(1)
VERDICTS = ("helped", "hurt", "no observed effect", "confounded")
for r in targets:
    cells = [c.strip() for c in r.strip().strip("|").split("|")]
    cells += [""] * (5 - len(cells))
    lid = re.search(r"L-\d+", cells[0]).group(0)
    cue, lesson, evidence, verdict = cells[1:5]
    if not cue: out.append(f"{lid}: no cue — the situation it applies to")
    if "`" not in lesson: out.append(f"{lid}: the lesson names no `component` (a rule, skill, check, script or CLAUDE.md section)")
    if not evidence: out.append(f"{lid}: no evidence — the incident or measurement it rests on")
    v = verdict.lower()
    if not v.startswith(VERDICTS): out.append(f"{lid}: verdict must start with helped, hurt, no observed effect or confounded")
    elif v.startswith("confounded"): out.append(f"{lid}: rests on confounded evidence, so it is a guess — narrow it to what was shown, or drop it")
if out:
    print(f"Lessons recorded without what they rest on — {len(out)}:")
    for o in out: print(f"  {o}")
    sys.exit(1)
PY
