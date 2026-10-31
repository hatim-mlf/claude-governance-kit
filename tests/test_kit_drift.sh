#!/usr/bin/env bash
# A commit that changes a kit-owned file beyond the kit is told to mirror it.
#
# Pinned by GLOOD (2026-10-31): 22 kit-owned files had changed there without reaching
# the kit, although a rule required every change to be mirrored. A prose rule depends on
# the session remembering; this check makes the commit remember. Warn-tier. Quiet for a
# file that is merely behind the kit, and for one the project lists in kit.projectOwned.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

kit="$SCRATCH/kit"; git clone -q "$KIT_ROOT" "$kit"
(cd "$KIT_ROOT" && git ls-files -co --exclude-standard -z | tar cf - --null -T -) | (cd "$kit" && tar xf -)
git -C "$kit" add -A && git -C "$kit" -c user.email=t@t -c user.name=t commit -qm "working tree" --allow-empty

target=$(fresh_install); cd "$target"
python3 -I -c 'import json; c=json.load(open("governance.config.json")); assert c["kit"]["path"], "installer did not record kit.path"'
ok "installer records where the kit lives"
python3 -I - "$kit" <<'PY'
import json, sys
c = json.load(open("governance.config.json")); c["kit"]["path"] = sys.argv[1]
json.dump(c, open("governance.config.json", "w"), indent=2)
PY
git add -A && git commit -qm install --no-verify
check() { ./scripts/check-kit-drift.sh > "$SCRATCH/out" 2>&1; }

echo "app" > src/app.ts && git add src/app.ts
check || { cat "$SCRATCH/out" >&2; fail "an app file should not warn"; }
ok "app files are ignored"

echo "# project fix" >> scripts/check-reports.sh && git add scripts/check-reports.sh
check && { cat "$SCRATCH/out" >&2; fail "a kit file changed beyond the kit should warn"; }
grep -q "scripts/check-reports.sh" "$SCRATCH/out" || fail "warning should name the file"
grep -q "projectOwned" "$SCRATCH/out" || fail "warning should offer projectOwned"
ok "a kit file changed beyond the kit warns, naming the file and both remedies"

python3 -I -c 'import json; c=json.load(open("governance.config.json")); c["kit"]["projectOwned"]=["scripts/check-reports.sh"]; json.dump(c,open("governance.config.json","w"),indent=2)'
git add governance.config.json
check || { cat "$SCRATCH/out" >&2; fail "a projectOwned file should not warn"; }
ok "files listed in kit.projectOwned are quiet"

git checkout -q HEAD -- scripts/check-reports.sh governance.config.json
oldest=$(git -C "$kit" log --format=%H -- scripts/pre-commit.sh | tail -1)
git -C "$kit" show "$oldest:scripts/pre-commit.sh" > scripts/pre-commit.sh && git add scripts/pre-commit.sh
check || { cat "$SCRATCH/out" >&2; fail "a file merely behind the kit should not warn"; }
ok "a file merely behind the kit is quiet"
