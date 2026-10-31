#!/usr/bin/env bash
# Pre-commit warns about entries left open in ANY week, including entries with no status.
#
# Pinned by GLOOD's audit: 26 entries open or status-less for more than two days, none
# warned about, because the check read only the current week, and an entry with no
# status line and no closing block was never counted as open at all.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target=$(fresh_install)
cd "$target"
mkdir -p ledger/2000-W01
cat > ledger/2000-W01/2000-01-03.md <<'MD'
## 2000-W01-01 — old open

**Reserved:** 2000-01-03 09:00 +0000

**Status:** 🟡 Open

## 2000-W01-02 — never closed, no status

**Reserved:** 2000-01-03 10:00 +0000

## 2000-W01-03 — closed

**Reserved:** 2000-01-03 11:00 +0000

**Status:** ✅ Closed

### Closed — 2000-01-03 12:00 +0000
MD
git add -A
all=$(./scripts/pre-commit.sh 2>&1 || true)
# Only the open-entries block; other checks legitimately name closed entries.
out=$(awk '/left open/{on=1} on&&/^$/&&seen{exit} on{print; if(/20[0-9][0-9]-W/)seen=1}' <<< "$all")
grep -q "tmp\." <<< "$out" && { echo "$out" >&2; fail "header names the temp file instead of the ledger"; }
grep -q "2000-W01-01" <<< "$out" || { echo "$out" >&2; fail "open entry in an earlier week not reported"; }
grep -q "2000-W01-02" <<< "$out" || { echo "$out" >&2; fail "status-less entry with no closing block not reported"; }
grep -q "2000-W01-03" <<< "$out" && { echo "$out" >&2; fail "closed entry reported as open"; }
ok "open and status-less entries from earlier weeks are reported; closed ones are not"
