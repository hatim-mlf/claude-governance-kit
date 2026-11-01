#!/usr/bin/env bash
# scripts/obligations-sync.sh mirrors the obligations register to Notion and Apple
# Reminders, automatically and without a model.
#
# Why: the obligations skill's Notion sync ran only inside a Claude session, and the
# operator's quota ran out (2026-10-31), so reminders would stop exactly when sessions
# stop. Pinned against a fake Notion API (tests/fake_notion.py): pages are created once
# and matched by Id, never duplicated; a closed obligation becomes Done; with no key the
# hook skips and never fails a commit; the post-commit hook triggers the sync; --setup
# creates the database; the Apple Reminders script is generated correctly (dry run).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

port=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
python3 -I "$KIT_ROOT/tests/fake_notion.py" "$port" "$SCRATCH/requests.log" & server=$!
trap 'kill $server 2>/dev/null; rm -rf "$SCRATCH"' EXIT
for _ in $(seq 50); do python3 -I -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:$port/_state')" 2>/dev/null && break; sleep 0.1; done
export NOTION_API="http://127.0.0.1:$port" NOTION_SYNC_DELAY=0 OBLIGATIONS_REMINDERS=dryrun HOME="$SCRATCH/home"
mkdir -p "$HOME/.claude"
state() { python3 -I -c "import json,urllib.request; print(json.dumps(json.load(urllib.request.urlopen('$NOTION_API/_state')), sort_keys=True))"; }
creates() { grep -c '"path": "/v1/pages"' "$SCRATCH/requests.log" || true; }

target=$(fresh_install); cd "$target"
cat >> obligations/OBLIGATIONS.md <<'MD'

## O-1 — Rotate the leaked key

**Class:** security
**Added:** 2000-01-01
**Done when:** old key revoked
**Status:** Open

## O-2 — Renew the developer account

**Class:** deadline
**Added:** 2000-01-01
**Due:** 2099-01-15
**Done when:** renewal receipt saved
**Status:** Open
MD

# --setup creates the database and prints its id.
out=$(NOTION_TOKEN=test-key ./scripts/obligations-sync.sh --setup parent-page 2>&1) || { echo "$out" >&2; fail "--setup failed"; }
db=$(printf '%s\n' "$out" | grep -oE 'db-[0-9a-f]{8}' | head -1)
[ -n "$db" ] || { echo "$out" >&2; fail "--setup did not print a database id"; }
grep -q '"Id": {"rich_text"' "$SCRATCH/requests.log" || fail "the database was created without an Id property"
python3 -I -c 'import json,sys; c=json.load(open("governance.config.json")); c["notion"]={"database":sys.argv[1],"reminders":True}; json.dump(c,open("governance.config.json","w"),indent=2)' "$db"
ok "--setup creates the Obligations database"

NOTION_TOKEN=test-key ./scripts/obligations-sync.sh > "$SCRATCH/sync1" 2>&1 || { cat "$SCRATCH/sync1" >&2; fail "first sync failed"; }
s=$(state)
grep -q '"O-1": {"due": "2000-01-03", "name": "Rotate the leaked key", "project": ' <<< "$s" || { echo "$s" >&2; fail "O-1 not created with its derived due date"; }
grep -q '"O-2": {"due": "2099-01-15"' <<< "$s" || { echo "$s" >&2; fail "O-2 not created with its explicit due date"; }
[ "$(creates)" -eq 2 ] || fail "expected 2 pages created, got $(creates)"
ok "the first sync creates one page per obligation"

NOTION_TOKEN=test-key ./scripts/obligations-sync.sh > "$SCRATCH/sync2" 2>&1 || { cat "$SCRATCH/sync2" >&2; fail "second sync failed"; }
[ "$(creates)" -eq 2 ] || fail "the second sync created duplicate pages"
[ "$(grep -c '"method": "PATCH"' "$SCRATCH/requests.log" || true)" -eq 0 ] || fail "the second sync rewrote unchanged pages"
ok "a second sync changes nothing: pages are matched by Id"

python3 -I - <<'PY'
p = "obligations/OBLIGATIONS.md"; s = open(p).read()
i = s.index("## O-1"); j = s.index("**Status:** Open", i)
open(p, "w").write(s[:j] + "**Status:** Done" + s[j + len("**Status:** Open"):])
PY
NOTION_TOKEN=test-key ./scripts/obligations-sync.sh > "$SCRATCH/sync3" 2>&1 || { cat "$SCRATCH/sync3" >&2; fail "third sync failed"; }
grep -q '"O-1": {"due": "2000-01-03", "name": "Rotate the leaked key", "project": "[^"]*", "status": "Done"' <<< "$(state)" || { state >&2; fail "a closed obligation was not marked Done"; }
grep -q 'set completed of r to true' "$SCRATCH/sync3" && grep -q 'O-1' "$SCRATCH/sync3" || { cat "$SCRATCH/sync3" >&2; fail "the closed obligation's reminder was not completed"; }
grep -q 'O-2 — Renew the developer account' "$SCRATCH/sync3" && grep -q 'set year of d to 2099' "$SCRATCH/sync3" || fail "the open obligation's reminder script is wrong"
ok "closing an obligation marks it Done in Notion and completes its reminder"

./scripts/obligations-sync.sh --hook > "$SCRATCH/nokey" 2>&1 || fail "with no key, the hook mode must exit 0"
grep -q "no Notion key" "$HOME"/.claude/*obligations-sync.log || { cat "$HOME"/.claude/*obligations-sync.log >&2 2>/dev/null; fail "with no key, the skip was not logged"; }
./scripts/obligations-sync.sh > /dev/null 2>&1 && fail "with no key, a manual run must fail and say so"
ok "with no key, the hook skips and logs; a manual run fails"

[ -L .git/hooks/post-commit ] || fail "install did not set the post-commit hook"
before=$(wc -l < "$SCRATCH/requests.log")
printf '\n## O-3 — New thing\n\n**Class:** maintenance\n**Added:** 2000-01-01\n**Status:** Open\n' >> obligations/OBLIGATIONS.md
git add -A && NOTION_TOKEN=test-key git commit -qm "obligations: O-3" --no-verify
for _ in $(seq 50); do [ "$(wc -l < "$SCRATCH/requests.log")" -gt "$before" ] && grep -q '"O-3"' <<< "$(state)" && break; sleep 0.2; done
grep -q '"O-3"' <<< "$(state)" || fail "a commit touching obligations/ did not trigger the sync"
ok "a commit touching obligations/ syncs in the background"
