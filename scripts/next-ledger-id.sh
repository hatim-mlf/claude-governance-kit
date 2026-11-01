#!/usr/bin/env bash
#
# Allocate (not preview) a week-scoped ledger ID before returning it.
#
# Why: on 2026-08-22 two sessions reserved 2026-W34-48 nine minutes apart; one entry lost
# its heading when the appends collided. Reading the highest id off the files only
# narrowed the window: two sessions that read before either wrote still got the same id.
# EduFlow, which runs several sessions in linked worktrees, replaced the preview with a
# claim. `scripts/check-ledger-entries.sh` remains the commit-time backstop.
#
# Atomic mkdir claims prevent concurrent sessions from receiving the same ID.
# Claims live in Git's common directory so linked worktrees share them. Never
# remove claims: even a caller interrupted before writing Markdown consumed its ID.
# Tracked daily headings remain the execution record and seed fresh clones.
# Usage: scripts/next-ledger-id.sh [YYYY-Www]
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "next-ledger-id: not inside a git repository." >&2; exit 1;
}
week="${1:-$(date +%G-W%V)}"
if [ "$#" -gt 1 ] || [[ ! "$week" =~ ^[0-9]{4}-W(0[1-9]|[1-4][0-9]|5[0-3])$ ]]; then
  echo "Usage: scripts/next-ledger-id.sh [YYYY-Www] (week 01–53)" >&2
  exit 2
fi

common="$(git rev-parse --git-common-dir)"
common="$(cd "$common" && pwd -P)"
claims="$common/ledger-id-claims/$week"
mkdir -p "$claims"
week_dir="$root/ledger/$week"
taken="$(grep -h -oE "^## ${week}-[0-9]+" "$week_dir"/*.md 2>/dev/null | sed "s|^## ${week}-||" | sort -n || true)"
duplicates="$(printf '%s\n' "$taken" | uniq -d)"
if [ -n "$duplicates" ]; then
  echo "next-ledger-id: duplicate ledger IDs in $week; resolve before allocating:" >&2
  printf '%s\n' "$duplicates" >&2
  exit 1
fi

# Seed from every registered worktree, including pre-upgrade headings that have
# no claim yet. NUL-delimited porcelain preserves paths containing spaces.
scan_worktrees() {
  local highest=0 record worktree ids number value
  while IFS= read -r -d '' record; do
    case "$record" in
      'worktree '*)
        worktree="${record#worktree }"
        ids="$(grep -h -oE "^## ${week}-[0-9]+" "$worktree/ledger/$week"/*.md 2>/dev/null | sed "s|^## ${week}-||" | sort -n || true)"
        for number in $ids; do
          value=$((10#$number))
          [ "$value" -le "$highest" ] || highest=$value
        done
        ;;
    esac
  done
  printf '%d' "$highest"
}
highest="$(git worktree list --porcelain -z | scan_worktrees)"
for claim in "$claims"/*; do
  number="${claim##*/}"
  [[ "$number" =~ ^[0-9]+$ ]] || continue
  value=$((10#$number))
  [ "$value" -le "$highest" ] || highest=$value
done

next=$((highest + 1))
while :; do
  printf -v number '%02d' "$next"
  if mkdir "$claims/$number" 2>/dev/null; then
    printf 'ALLOCATED: %s-%s\n' "$week" "$number"
    exit 0
  fi
  if [ ! -d "$claims/$number" ]; then
    echo "next-ledger-id: cannot create claim $claims/$number" >&2
    exit 1
  fi
  next=$((next + 1))
done
