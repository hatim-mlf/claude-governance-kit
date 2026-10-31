#!/usr/bin/env bash
# check-status-lines.sh keeps the status line machine-readable.
#
# Pinned by GLOOD's audit (2026-10-31): over 100 distinct status strings for 332 bugs and
# 23 ledger entries with no status at all, because the format invited prose after the
# status word. A status line holds one word from the vocabulary and nothing else; the
# explanation goes on a `**Status note:**` line. Warn-tier, and at commit time only the
# lines this commit ADDS are checked — legacy rows are the audit mode's job, or every
# commit in a mature project would print a hundred warnings and none would be read.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$SCRATCH/repo"; mkdir -p "$repo/scripts" "$repo/ledger/2026-W01" "$repo/reports/bugs reports"
git -C "$repo" init -q; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
cp "$KIT_ROOT/scripts/check-status-lines.sh" "$repo/scripts/"
L="$repo/ledger/2026-W01/2026-01-01.md"; T="$repo/reports/bugs reports/BUG_TRACKER.md"
run() { (cd "$repo" && ./scripts/check-status-lines.sh "$@") > "$SCRATCH/out" 2>&1; }

# Legacy drift, committed before the check existed.
printf '## 2026-W01-01 — a\n\n**Status:** ✅ Closed — legacy prose\n' > "$L"
printf '## Bug 1 — b\n\n**Status:** Fixed, verified — fix abc\n' > "$T"
git -C "$repo" add -A && git -C "$repo" commit -qm legacy

# New lines that follow the vocabulary.
printf '\n## 2026-W01-02 — c\n\n**Status:** 🟡 Open\n**Status note:** waiting on the device run\n' >> "$L"
printf '\n## Bug 2 — d\n\n**Status:** 🟢 Fixed, verified\n\n## Bug 3 — e\n\n**Status:** ⚪ Product gap\n' >> "$T"
git -C "$repo" add -A
run --staged || { cat "$SCRATCH/out" >&2; fail "vocabulary lines should pass"; }
ok "vocabulary passes; legacy lines are not re-reported at commit time"

# New drift on both files.
printf '\n## 2026-W01-03 — f\n\n**Status:** ✅ Closed, the build is green\n' >> "$L"
printf '\n## Bug 4 — g\n\n**Status:** Fixed, unverified  ledger 2026-W01-03\n' >> "$T"
git -C "$repo" add -A
run --staged && { cat "$SCRATCH/out" >&2; fail "prose on a new status line should warn"; }
grep -q "2026-01-01.md" "$SCRATCH/out" || fail "warning should name the ledger file"
grep -q "BUG_TRACKER.md" "$SCRATCH/out" || fail "warning should name the tracker"
grep -q "Status note" "$SCRATCH/out" || fail "warning should say where the prose goes"
ok "prose on a new status line warns, naming file and remedy"

run && fail "audit mode should report legacy drift"
grep -q "4 status lines" "$SCRATCH/out" || { cat "$SCRATCH/out" >&2; fail "audit mode should count all 4 non-conforming lines"; }
ok "audit mode counts every non-conforming line"
