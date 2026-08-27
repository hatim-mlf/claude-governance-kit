#!/bin/sh
# PostToolUse guard — publish a ledger entry the moment it exists, not when the turn ends.
#
# WHY THIS EXISTS (register row U-16 in the project this came from, residual)
#   The `Stop` hook syncs the dashboard after every assistant turn, which sounded like
#   "at most one turn stale" and is not. `Stop` fires once per *user* turn, and the shape
#   of work here is: one user message, reserve an entry, then do the whole job. So exactly
#   one sync runs, at the end — and `ledger/SYNC_LOG.tsv` shows the consequence plainly:
#   entries published as `open` *after* the last commit of the work they described, and
#   others never published open at all, only closed. From the operator's side that is
#   indistinguishable from never having reserved anything.
#   Compaction makes it structural rather than incidental: the continuation of a compacted
#   conversation is a single long turn by construction.
#
#   U-16's recorded fix direction was to add the sync command to `ledger/README.md`'s
#   reserve template. That is discipline, and U-16's own text says discipline does not
#   close this gap — reserve-first is a mid-turn action and the sync was a turn-boundary
#   action. This makes it a file-write action instead, which is what reserving actually is.
#
# WHY IT IS SAFE TO RUN AFTER EVERY TOOL CALL
#   The expensive part is guarded by one `find` over `ledger/*.md` — a few dozen files.
#   Nothing regenerates unless a ledger entry has actually been written since the last
#   time this ran. A hook that costs seconds on every command is a hook that gets removed,
#   which is worse than the gap it closes.
#
# WHY THE STAMP LIVES IN .git/
#   It is per-clone state, not project content, and it must never be committed or the
#   trigger would fire for everyone on checkout. `ledger/SYNC_LOG.tsv` cannot serve as the
#   stamp: it is only rewritten when an entry's status changes, so any other ledger edit
#   would leave it permanently older and the guard would fire on every tool call forever.
#
# Always exits 0. Same reasoning as `dashboard-sync.sh`: a missed sync is recoverable,
# a blocked tool call is not.

set -u

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || exit 0
[ -n "$script_directory" ] || exit 0
repository_root=$(dirname -- "$script_directory")

[ -d "$repository_root/ledger" ] || exit 0
[ -x "$repository_root/scripts/dashboard-sync.sh" ] || exit 0

stamp="$repository_root/.git/glood-ledger-sync-stamp"
if [ ! -f "$stamp" ]; then
    : >"$stamp" 2>/dev/null || exit 0
    exit 0
fi

changed=$(find "$repository_root/ledger" -name '*.md' -newer "$stamp" -print 2>/dev/null | head -n 1)
[ -n "$changed" ] || exit 0

"$repository_root/scripts/dashboard-sync.sh" --turn >/dev/null 2>&1
: >"$stamp" 2>/dev/null || true
exit 0
