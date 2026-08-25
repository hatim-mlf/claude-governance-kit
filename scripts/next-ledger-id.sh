#!/usr/bin/env bash
#
# Print the next free ledger id for the current ISO week, and the ids already taken.
#
# WHY THIS EXISTS
#   On 2026-08-22 two sessions reserved `2026-W34-48` nine minutes apart. Neither
#   checked. One entry then lost its heading entirely when the two appends collided,
#   and `git add -A` from one session committed the other's half-written work.
#
#   "Check before reserving" is the rule. This is what makes checking a single command
#   instead of a thing to remember, because a rule that is inconvenient to follow is
#   followed until it is busy. `scripts/check-ledger-entries.sh` catches a duplicate at
#   commit time as the backstop; this stops one being created at all.
#
# WHY IT PRINTS THE TAKEN IDS TOO
#   The next id is the answer, but a session that has been running for hours may have
#   context that disagrees with the file. Seeing the last few real ids makes a stale
#   assumption visible rather than silently overridden.
#
# USAGE
#   scripts/next-ledger-id.sh            # current ISO week
#   scripts/next-ledger-id.sh 2026-W33   # a specific week
#
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "next-ledger-id: not inside a git repository." >&2; exit 1;
}

week="${1:-$(date +%G-W%V)}"
week_dir="${root}/ledger/${week}"

# One folder per ISO week, one file per day inside it. Ids stay week-scoped and
# sequential across the whole week, so a citation resolves without naming a day —
# which is what lets the split happen without breaking every reference.
if [ ! -d "$week_dir" ]; then
  echo "No folder for ${week} yet — create ledger/${week}/$(date +%F).md and start at ${week}-01."
  exit 0
fi

# Ids are read off the file, never counted. A deleted entry leaves a gap, and reusing
# that gap would break every citation pointing at the old occupant — ledger/README.md
# says ids are never reused, so this takes max+1 rather than the first free slot.
taken="$(cat "${week_dir}"/*.md 2>/dev/null | grep -oE "^## ${week}-[0-9]+" | sed "s|^## ${week}-||" | sort -n)"

if [ -z "$taken" ]; then
  echo "${week}-01"
  exit 0
fi

highest="$(printf '%s\n' "$taken" | tail -1)"
next=$(( 10#${highest} + 1 ))

duplicates="$(printf '%s\n' "$taken" | uniq -d)"
if [ -n "$duplicates" ]; then
  echo "WARNING — ${week} already contains duplicate ids:" >&2
  printf '  %s-%s\n' "$week" $duplicates >&2
  echo "  Resolve those before reserving; see ledger/README.md." >&2
fi

printf 'Taken (last 5): %s\n' "$(printf '%s\n' "$taken" | tail -5 | sed "s|^|${week}-|" | tr '\n' ' ')"
printf 'NEXT FREE:      %s-%02d\n' "$week" "$next"
