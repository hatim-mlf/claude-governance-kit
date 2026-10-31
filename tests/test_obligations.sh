#!/usr/bin/env bash
# scripts/obligations.sh turns the register and the ledger into one list of what is owed.
#
# Pinned: due dates derived from class when absent; an explicit Due wins; a deadline
# without a Due is a finding, not a silent skip; Done and Dropped are not owed; an open
# ledger entry from an earlier day is owed without anyone writing it down; --next-id
# never reuses an id; --check is what pre-commit runs.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target=$(fresh_install); cd "$target"
[ -f obligations/README.md ] && [ -f obligations/OBLIGATIONS.md ] || fail "install did not create obligations/"
ok "install creates obligations/ like ledger/"

in_days() { python3 -I -c "import datetime,sys; print((datetime.date.today()+datetime.timedelta(days=int(sys.argv[1]))).isoformat())" "$1"; }
cat >> obligations/OBLIGATIONS.md <<MD

## O-1 — Rotate the leaked key

**Class:** security
**Added:** 2000-01-01
**Owner:** operator
**Done when:** old key revoked
**Status:** Open

## O-2 — Renew the developer account

**Class:** deadline
**Added:** $(in_days 0)
**Due:** $(in_days 3)
**Done when:** renewal receipt saved
**Status:** Open

## O-3 — Already handled

**Class:** decision
**Added:** 2000-01-01
**Status:** Done
**Status note:** decided 2000-01-02

## O-4 — Store review window

**Class:** deadline
**Added:** $(in_days 0)
**Status:** Open
MD
mkdir -p ledger/2000-W01
printf '## 2000-W01-01 — left open\n\n**Reserved:** 2000-01-03 09:00 +0000\n\n**Status:** 🟡 Open\n' > ledger/2000-W01/2000-01-03.md

out=$(./scripts/obligations.sh 2>&1) || true
json=obligations/obligations.json
[ -f "$json" ] || { echo "$out" >&2; fail "obligations.json not written"; }
get() { python3 -I -c "import json,sys; d={o['id']:o for o in json.load(open(sys.argv[1]))['obligations']}; o=d.get(sys.argv[2]); print('' if o is None else o.get(sys.argv[3]))" "$json" "$1" "$2"; }

[ "$(get O-1 due)" = "2000-01-03" ] || fail "security due should derive as Added + 2 days, got $(get O-1 due)"
[ "$(get O-1 importance)" = "high" ] || fail "security should default to high importance"
[ "$(get O-2 due)" = "$(in_days 3)" ] || fail "an explicit Due should win"
[ -z "$(get O-3 id)" ] || fail "a Done obligation is not owed"
[ "$(get 2000-W01-01 class)" = "open-entry" ] || fail "an open ledger entry from an earlier day should be owed"
[ "$(get 2000-W01-01 due)" = "2000-01-05" ] || fail "an open entry is due Reserved + 2 days"
ok "due dates derive from class, explicit Due wins, Done is not owed, open entries are owed"

grep -q "O-4" <<< "$out" && grep -qi "deadline.*Due" <<< "$out" || { echo "$out" >&2; fail "a deadline with no Due should be reported"; }
grep -q "overdue" <<< "$out" || { echo "$out" >&2; fail "summary should list what is overdue"; }
grep -q "Rotate the leaked key" <<< "$out" || fail "summary should name overdue items"
ok "summary names overdue items and reports a deadline with no date"

[ "$(./scripts/obligations.sh --next-id)" = "O-5" ] || fail "next id should be O-5"
ok "--next-id continues the sequence"

rm -f "$json"
./scripts/obligations.sh --check > "$SCRATCH/c" 2>&1 && fail "--check should exit 1 when something is overdue"
[ ! -e "$json" ] || fail "--check must only read; it rewrote obligations.json during a commit"
[ "$(wc -l < "$SCRATCH/c")" -le 6 ] || { cat "$SCRATCH/c" >&2; fail "--check should stay short at commit time"; }
ok "--check warns briefly when something is overdue"
