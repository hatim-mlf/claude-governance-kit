#!/usr/bin/env bash
#
# check-stale-blockers.sh — warn when an open row is blocked on something already resolved.
#
# Register row U-48. Filed 2026-09-04 after Bug 113 was found already fixed while its row read
# "reported, not diagnosed", and recurred one entry later: Bug 63's verification bar said
# "not met, blocked on U-22" when U-22 had been RESOLVED on 2026-08-22 — the same day that row
# last moved. Thirteen days blocked on nothing, caught only because a session happened to look.
#
# WHAT IT CHECKS
#   For every row in `reports/bugs reports/BUG_TRACKER.md` that is still open and says it is
#   blocked on a `U-NN` register row, warn if that register row is marked RESOLVED.
#
# WHAT IT DOES NOT CHECK
#   The other half of U-48: a fix landing inside another row's commit with no row update.
#   That needs a commit-message convention, not a text scan, and is a separate decision.
#
# TIER
#   Warn, never block. A stale blocker is a reason to look, never a reason to refuse a commit.
#   `CLAUDE.md`: a check that blocks legitimate work gets bypassed until it means nothing.
#
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
tracker="$root/reports/bugs reports/BUG_TRACKER.md"
register="$root/STRUCTURAL_PROBLEMS.md"

[ -f "$tracker" ]  || { echo "check-stale-blockers: BUG_TRACKER.md not found"; exit 0; }
[ -f "$register" ] || { echo "check-stale-blockers: STRUCTURAL_PROBLEMS.md not found"; exit 0; }

python3 - "$tracker" "$register" <<'PY'
import re, sys

tracker_path, register_path = sys.argv[1], sys.argv[2]

# --- which register rows are resolved -------------------------------------------------
# One row per table line beginning `| **U-NN**`. A row counts as resolved when that line
# says RESOLVED. Reopened rows say so on the same line and keep the word, so they are
# checked for a reopen marker first.
resolved = set()
for line in open(register_path, encoding="utf-8").read().split("\n"):
    m = re.match(r"\|\s*\*\*(U-\d+[a-z]?)\*\*", line)
    if not m:
        continue
    if "RESOLVED" in line and "Reopened" not in line:
        resolved.add(m.group(1))

# --- walk the tracker, row by row ------------------------------------------------------
# Only rows that are STILL OPEN may warn. A closed row's narrative is allowed to mention a
# blocker it once had, and Bug 64 does exactly that while being "Fixed, verified" — treating
# that as a finding is how a warn-tier check becomes noise and stops being read.
findings = []
row = status = None
for line in open(tracker_path, encoding="utf-8").read().split("\n"):
    h = re.match(r"^## (Bug \d+)\b", line)
    if h:
        row, status = h.group(1), None
        continue
    if row and status is None and line.startswith("**Status:**"):
        status = line
        continue
    if not row or status is None:
        continue
    if "✅" in status:                      # closed: its history may name old blockers
        continue
    if not re.search(r"blocked (on|by)", line, re.I):
        continue
    for u in re.findall(r"U-\d+[a-z]?", line):
        if u in resolved:
            findings.append((row, u, line.strip()))

if not findings:
    sys.exit(0)

print("Rows blocked on something already resolved")
seen = set()
for row, u, line in findings:
    if (row, u) in seen:
        continue
    seen.add((row, u))
    excerpt = re.sub(r"\s+", " ", line)
    print(f"    {row}: says it is blocked on {u}, which is RESOLVED")
    print(f"      {excerpt[:150]}")
print()
print("    The blocker is gone; the row does not know. Re-read the bar and either meet it")
print("    or say why it still cannot be met.")
print()
print("  Register row U-48. Warn only; nothing is blocked.")
sys.exit(1)
PY
