#!/usr/bin/env bash
# A fresh install works with bash and git alone, and the ledger check runs on day one.
#
# Two defects pinned here, both found by installing into an empty repository:
#   - install.sh called rsync, which it never declared; without it the run stopped after
#     the templates — no config, no dashboard, no pre-commit hook.
#   - install.sh created ledger/<week>.md, the retired week-FILE layout, so the first
#     run of check-ledger-entries.sh reported "DID NOT RUN".
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PATH=$(path_without rsync)
command -v rsync >/dev/null && fail "test setup: rsync still on PATH"

target=$(fresh_install)

[ -f "$target/governance.config.json" ]                  || fail "governance.config.json not written"
[ -f "$target/bug-tracker-dashboard/app/package.json" ]  || fail "dashboard not copied"
[ ! -e "$target/bug-tracker-dashboard/app/node_modules" ] || fail "dashboard copy included node_modules"
[ ! -e "$target/bug-tracker-dashboard/app/.sync-state.json" ] || fail "dashboard copy included the kit's sync cache"
[ -L "$target/.git/hooks/pre-commit" ]                   || fail "pre-commit hook not installed"
ok "installed without rsync"
for f in "$KIT_ROOT"/scripts/*.sh; do
  [ -x "$target/scripts/$(basename "$f")" ] || fail "kit script not installed: scripts/$(basename "$f")"
done
ok "every kit script installed and executable"

week=$(date +%G-W%V)
[ ! -e "$target/ledger/$week.md" ] || fail "installer created the retired week file ledger/$week.md"
[ -d "$target/ledger/$week" ]      || fail "installer did not create the week folder ledger/$week/"
ok "ledger uses the week-folder layout"

(cd "$target" && ./scripts/check-ledger-entries.sh > "$SCRATCH/check.log" 2>&1) \
  || { cat "$SCRATCH/check.log"; fail "check-ledger-entries.sh failed on a fresh install"; }
grep -q "DID NOT RUN" "$SCRATCH/check.log" && { cat "$SCRATCH/check.log"; fail "ledger check did not run"; }
ok "ledger check runs on a fresh install"

id=$(cd "$target" && ./scripts/next-ledger-id.sh | grep -oE '[0-9]{4}-W[0-9]{2}-[0-9]+' | tail -1)
[ "$id" = "$week-01" ] || fail "first id should be $week-01, got '$id'"
ok "first ledger id is $id"

# The first commit in a fresh project runs the pre-commit hook against the empty week
# folder. Its own copy of the week lookup must agree with check-ledger-entries.sh.
(cd "$target" && git add -A && git commit -qm init) > "$SCRATCH/commit.log" 2>&1 \
  || { cat "$SCRATCH/commit.log" >&2; fail "first commit was blocked"; }
grep -q "DID NOT RUN" "$SCRATCH/commit.log" && { cat "$SCRATCH/commit.log" >&2; fail "pre-commit ledger check did not run on a fresh install"; }
ok "first commit passes the pre-commit hook cleanly"
