#!/usr/bin/env bash
# The ledger catalog resolves paths that moved after an entry was written.
#
# Both behaviours came from GLOOD's copy of the generator, which was ahead of the kit:
#   - an entry citing the retired week FILE (ledger/2026-W33.md) resolves to the week
#     folder that replaced it. Ledger entries are never edited, so the mapping lives here;
#   - a project can declare its own moves in governance.config.json `pathAliases`
#     (GLOOD moved marketing/ under docs/marketing/), instead of hard-coding them into a
#     generator that ships to every project.
# Directories count as touched, so a cited folder is not silently dropped.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v node >/dev/null || { echo "  - skipped: node not on PATH"; exit 0; }

target=$(fresh_install); cd "$target"
week=$(date +%G-W%V); day=$(date +%F)
mkdir -p docs/marketing/tracker "ledger/2000-W01"
echo x > docs/marketing/tracker/plan.md
echo "# old week" > "ledger/2000-W01/2000-01-03.md"
python3 -I - governance.config.json <<'PY'
import json, sys
p = sys.argv[1]; c = json.load(open(p))
c["pathAliases"] = [{"from": "^marketing/(tracker)(?=/|$)", "to": "docs/marketing/$1"}]
json.dump(c, open(p, "w"), indent=2)
PY
cat > "ledger/$week/$day.md" <<MD
## $week-01 — moved paths

**Reserved:** $day 09:00 +0000

**Expected files:**
- \`marketing/tracker/plan.md\`

**Status:** ✅ Closed

### Closed — $day 10:00 +0000

**Files actually touched:**
Modified: \`marketing/tracker/plan.md\`, \`ledger/2000-W01.md\`, \`docs/marketing/tracker\`

**Verified by:** test
MD
(cd bug-tracker-dashboard/app && node scripts/generate-ledger-catalog.mjs) > "$SCRATCH/gen.log" 2>&1 \
  || { cat "$SCRATCH/gen.log" >&2; fail "generator failed"; }
cat_file=bug-tracker-dashboard/app/src/data/ledgerCatalog.ts
grep -q '"docs/marketing/tracker/plan.md"' "$cat_file" || fail "pathAliases from config not applied"
grep -q '"marketing/tracker/plan.md"' "$cat_file" && fail "old path still listed after its alias"
grep -q '"ledger/2000-W01"' "$cat_file" || fail "retired week-file path not mapped to its folder"
grep -q '"docs/marketing/tracker"' "$cat_file" || fail "a touched directory was dropped"
ok "moved paths, retired week files and directories all resolve"
