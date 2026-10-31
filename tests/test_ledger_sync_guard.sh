#!/usr/bin/env bash
# The PostToolUse guard publishes a reservation completely: dashboard AND week index.
#
# Pinned because the kit used to ask for a publish call after every reservation. In
# GLOOD that was one of ~5 ceremony calls per entry (3,254 of 20,486 tool calls, 16%),
# and it was needed only because the hook skipped the week index. With the index rebuilt
# here, a reservation in Claude Code is published by the write itself; the explicit
# publish is kept once, at close, where it verifies the final status.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target=$(fresh_install)
week=$(date +%G-W%V); day=$(date +%F)
cd "$target"
./scripts/ledger-sync-guard.sh   # first call only creates the stamp
sleep 1
printf '## %s-01 — t\n\n**Reserved:** %s\n\n**Status:** 🟡 Open\n' "$week" "$(date +'%Y-%m-%d %H:%M %z')" > "ledger/$week/$day.md"
./scripts/ledger-sync-guard.sh

[ -f "ledger/$week/README.md" ] || fail "guard did not regenerate the week index"
grep -q "$day" "ledger/$week/README.md" || fail "week index does not list today's file"
ok "a reservation write regenerates the week index"
