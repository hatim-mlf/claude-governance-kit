#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$SCRATCH/repo"
mkdir -p "$repo/ledger/2026-W34" "$repo/scripts"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
cp "$KIT_ROOT/scripts/next-ledger-id.sh" "$repo/scripts/"
printf '## 2026-W34-07 — Existing\n' > "$repo/ledger/2026-W34/2026-08-20.md"
git -C "$repo" add .
git -C "$repo" commit -qm initial
git -C "$repo" worktree add -qb linked "$SCRATCH/linked"
printf '## 2026-W34-12 — Linked\n' >> "$SCRATCH/linked/ledger/2026-W34/2026-08-20.md"
for n in {1..20}; do
  (cd "$repo" && { bash scripts/next-ledger-id.sh 2026-W34 > "$SCRATCH/id-$n" 2> "$SCRATCH/err-$n"; echo $? > "$SCRATCH/rc-$n"; }) &
done
wait
ids=$(cat "$SCRATCH"/id-*)
if [ "$(printf '%s\n' "$ids" | sort -u | wc -l | tr -d ' ')" != 20 ]; then
  # Say which call failed and why: a bare "not unique" cannot tell a duplicate id from a
  # call that printed nothing (CI, 2026-11-01).
  for n in {1..20}; do
    echo "call $n: exit $(cat "$SCRATCH/rc-$n" 2>/dev/null || echo '?'), out: $(cat "$SCRATCH/id-$n"), err: $(head -c 400 "$SCRATCH/err-$n")" >&2
  done
  echo "claims: $(ls "$repo/.git/ledger-id-claims/2026-W34" | tr '\n' ' ')" >&2
  fail 'concurrent claims were not unique'
fi
printf '%s\n' "$ids" | grep -q 'ALLOCATED: 2026-W34-13' || fail 'linked worktree heading was not used'
(cd "$SCRATCH/linked" && bash scripts/next-ledger-id.sh 2026-W34) | grep -q 'ALLOCATED: 2026-W34-33' || fail 'claims were not shared'
if (cd "$repo" && bash scripts/next-ledger-id.sh 2026-W00 >/dev/null 2>&1); then fail 'invalid week accepted'; fi
printf '## 2026-W34-07 — Duplicate\n' >> "$repo/ledger/2026-W34/2026-08-20.md"
if (cd "$repo" && bash scripts/next-ledger-id.sh 2026-W34 >/dev/null 2>&1); then fail 'duplicate headings accepted'; fi
ok 'allocation is unique across concurrent calls and linked worktrees'
