#!/usr/bin/env bash
# check-ledger-entries.sh finds the right week, and says so when there is nothing to check.
#
# Pinned:
#   - an empty current-week folder (what a fresh install leaves, and every Monday after
#     the first mkdir) was reported as "no week folder" and failed the check;
#   - the fallback glob matched a retired week FILE (ledger/2026-W01.md) as if it were a
#     week folder;
#   - a repository with no ledger/ at all must still fail loudly — that is a broken root,
#     not a quiet week.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$SCRATCH/repo"
mkdir -p "$repo/scripts" && git -C "$repo" init -q
cp "$KIT_ROOT/scripts/check-ledger-entries.sh" "$repo/scripts/"
check() { (cd "$repo" && ./scripts/check-ledger-entries.sh) > "$SCRATCH/out" 2>&1; }

check && { cat "$SCRATCH/out" >&2; fail "no ledger/ at all should fail"; }
grep -q "DID NOT RUN" "$SCRATCH/out" || fail "no ledger/ should say DID NOT RUN"
ok "missing ledger/ fails loudly"

week=$(date +%G-W%V)
mkdir -p "$repo/ledger/$week"
check || { cat "$SCRATCH/out" >&2; fail "an empty current-week folder should pass"; }
grep -q "DID NOT RUN" "$SCRATCH/out" && fail "an empty week is nothing to check, not a check that did not run"
ok "empty week folder passes and says why"

# A previous week holding an open, stale entry; the current week is empty. The check
# must fall back to the previous week FOLDER, not the leftover week file beside it.
rmdir "$repo/ledger/$week"
mkdir -p "$repo/ledger/2000-W01"
printf '## 2000-W01-01 — old\n\n**Reserved:** 2000-01-03 09:00 +0000\n\n**Status:** 🟡 Open\n' \
  > "$repo/ledger/2000-W01/2000-01-03.md"
printf '# retired week file\n' > "$repo/ledger/2000-W02.md"
check || true
grep -q "2000-W02.md" "$SCRATCH/out" && { cat "$SCRATCH/out" >&2; fail "fallback picked the retired week file"; }
grep -q "2000-W01" "$SCRATCH/out" || { cat "$SCRATCH/out" >&2; fail "fallback did not check the most recent week folder"; }
ok "fallback picks the most recent week folder"
