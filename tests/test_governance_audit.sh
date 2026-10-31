#!/usr/bin/env bash
# governance-audit.sh counts correctly, and never prints private text.
#
# Pinned:
#   - usage is counted once per assistant message id; Claude Code repeats the same
#     usage on every line of a multi-block message, and summing lines overcounted ~2.7x;
#   - a closed entry only counts as verified when Verified by names evidence, not
#     "Not verified";
#   - entry titles, bug titles and transcript text never appear in the output.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$SCRATCH/proj"; mkdir -p "$repo/ledger/2026-W01" "$repo/reports/bugs reports" "$repo/scripts"
git -C "$repo" init -q
cp "$KIT_ROOT/scripts/governance-audit.sh" "$repo/scripts/"
cat > "$repo/ledger/2026-W01/2026-01-01.md" <<'MD'
## 2026-W01-01 — SECRET_TITLE_ONE

**Reserved:** 2026-01-01 10:00 +0000

**Status:** ✅ Closed

### Closed — 2026-01-01 12:30 +0000

**Needs attention:** yes, follow-up

**Verified by:** `tests/run.sh` green

## 2026-W01-02 — SECRET_TITLE_TWO

**Reserved:** 2026-01-01 13:00 +0000

**Status:** ✅ Closed

### Closed — 2026-01-01 14:00 +0000

**Verified by:** Not verified — needs a device run
MD
cat > "$repo/reports/bugs reports/BUG_TRACKER.md" <<'MD'
## Bug 1 — SECRET_BUG_TITLE

**Status:** 🟠 Open
MD
t="$SCRATCH/transcripts"; mkdir -p "$t"
# One message (m1) split over two lines with the same usage, then a second message.
cat > "$t/s1.jsonl" <<'JL'
{"type":"user","timestamp":"2026-01-01T10:00:00Z","message":{"content":"SECRET_PROMPT_TEXT"}}
{"type":"assistant","timestamp":"2026-01-01T10:00:01Z","message":{"id":"m1","usage":{"input_tokens":10,"output_tokens":100,"cache_read_input_tokens":1000,"cache_creation_input_tokens":0},"content":[{"type":"text","text":"SECRET_REPLY"}]}}
{"type":"assistant","timestamp":"2026-01-01T10:00:02Z","message":{"id":"m1","usage":{"input_tokens":10,"output_tokens":100,"cache_read_input_tokens":1000,"cache_creation_input_tokens":0},"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"scripts/next-ledger-id.sh"}}]}}
{"type":"assistant","timestamp":"2026-01-01T10:00:03Z","message":{"id":"m2","usage":{"input_tokens":5,"output_tokens":50,"cache_read_input_tokens":2000,"cache_creation_input_tokens":0},"content":[{"type":"tool_use","id":"t2","name":"Read","input":{"file_path":"src/app.swift"}}]}}
JL

out=$(cd "$repo" && HOME="$SCRATCH/home" ./scripts/governance-audit.sh --transcripts "$t")
expect() { grep -qF -- "$1" <<< "$out" || { echo "$out" >&2; fail "missing: $1"; }; }

expect "AUDIT RESULT v1"
expect "entries: 2"
expect "closed with a real Verified by: 1/2 (50%)"
expect "Needs attention: yes: 1"
expect "reserve to close (hours): median 1.8h"
expect "1 bugs; by status: {'Open': 1}"
ok "ledger and tracker counted"

expect "output_tokens per session: median 150"        # 100 + 50, not 100 + 100 + 50
expect "cache_read_input_tokens per session: median 3000"
expect "governance tool calls: 1 (50% of all)"
ok "usage counted once per message id"

grep -q "SECRET_" <<< "$out" && { echo "$out" >&2; fail "private text leaked into the output"; }
ok "no titles or transcript text in the output"
