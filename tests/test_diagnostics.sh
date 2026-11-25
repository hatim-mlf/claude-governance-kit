#!/usr/bin/env bash
# Every installed project carries a diagnostics state, and the check reads it
# (.claude/rules/diagnostics-channel.md).
#
# Pinned: the rule once lived only in templates/CLAUDE.md, which update.sh never delivers,
# so 0 of 4 existing projects had it, and nothing said whether a project had a channel.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

state() { python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["diagnostics"]["state"])' "$1/governance.config.json"; }
set_block() { python3 -I -c 'import json,sys; p=sys.argv[1]; c=json.load(open(p)); b=json.loads(sys.argv[2]); c.pop("diagnostics",None) if b is None else c.__setitem__("diagnostics",b); open(p,"w").write(json.dumps(c,indent=2))' "$1/governance.config.json" "$2"; }

# 1. A default install (an app) lands in not-yet, with its rows and the starter.
target=$(fresh_install)
[ "$(state "$target")" = "not-yet" ] || fail "default install should be not-yet, got $(state "$target")"
[ -f "$target/docs/roadmap/diagnostics_channel.md" ] || fail "rows not written"
[ -f "$target/diagnostics/contract.json" ] && [ -x "$target/diagnostics/supabase/test.sh" ] || fail "starter not installed"
[ ! -e "$target/diagnostics/ROADMAP.md" ] || fail "rows template left inside diagnostics/"
[ -f "$target/.claude/rules/diagnostics-channel.md" ] || fail "rule not installed"
out=$(cd "$target" && ./scripts/check-diagnostics.sh) || fail "check failed on a fresh install: $out"
[[ "$out" == *"not yet — planned in docs/roadmap/diagnostics_channel.md"* ]] || fail "unexpected: $out"
[ -z "$(cd "$target" && ./scripts/check-diagnostics.sh --quiet)" ] || fail "--quiet printed on a decided state"
ok "default install: not-yet, rows and starter in place, check quiet"

# 2. The check warns, never blocks: no block → exit 1, and a commit still goes through.
set_block "$target" null
(cd "$target" && ./scripts/check-diagnostics.sh > "$SCRATCH/d.log") && fail "missing block passed"
grep -q 'no "diagnostics" block' "$SCRATCH/d.log" || fail "missing block not named"
(cd "$target" && git add -A && git commit -qm init) > "$SCRATCH/commit.log" 2>&1 || { cat "$SCRATCH/commit.log"; fail "commit blocked"; }
grep -q 'no "diagnostics" block' "$SCRATCH/commit.log" || { cat "$SCRATCH/commit.log"; fail "pre-commit did not warn"; }
ok "missing state warns at commit and does not block"

# 3. not-yet needs a row that exists; not-applicable needs a reason.
set_block "$target" '{"state":"not-yet","row":"docs/roadmap/nowhere.md"}'
(cd "$target" && ./scripts/check-diagnostics.sh >/dev/null) && fail "a row that does not exist passed"
set_block "$target" '{"state":"not-applicable"}'
(cd "$target" && ./scripts/check-diagnostics.sh >/dev/null) && fail "not-applicable with no reason passed"
set_block "$target" '{"state":"maybe"}'
(cd "$target" && ./scripts/check-diagnostics.sh >/dev/null) && fail "an unknown state passed"
ok "undecided states are named"

# 4. implemented needs a backend and six parts that exist; one missing part is named.
mkdir -p "$target/srv" "$target/tests"
for f in srv/intake.sql srv/version.txt tests/contract.test srv/reports.txt srv/digest.py srv/coverage.py; do touch "$target/$f"; done
parts='{"intake":"srv/intake.sql","devTag":"srv/version.txt","contractTest":"tests/contract.test","featureReports":"srv/*.txt","reader":"srv/digest.py","coverage":"srv/coverage.py"}'
set_block "$target" "{\"state\":\"implemented\",\"backend\":\"supabase\",\"parts\":$parts}"
out=$(cd "$target" && ./scripts/check-diagnostics.sh) || fail "a complete channel failed: $out"
[[ "$out" == *"implemented (supabase) — 6 of 6"* ]] || fail "unexpected: $out"
rm "$target/srv/digest.py"
out=$(cd "$target" && ./scripts/check-diagnostics.sh) && fail "a lost part passed"
[[ "$out" == *"parts.reader"*"is not a file in this repository"* ]] || fail "lost part not named: $out"
ok "implemented: six parts checked, a lost one named"

# 4b. A part must be a file inside the repository: not absolute, not "..", not a directory.
touch "$target/srv/digest.py"
for bad in '"/etc/hosts"' '"../outside.py"' '"srv"' '"."'; do
  set_block "$target" "{\"state\":\"implemented\",\"backend\":\"supabase\",\"parts\":$(echo "$parts" | sed "s|\"srv/digest.py\"|$bad|")}"
  (cd "$target" && ./scripts/check-diagnostics.sh >/dev/null) && fail "part $bad passed as present"
done
set_block "$target" '{"state":"not-yet","row":"/etc/hosts#x"}'
(cd "$target" && ./scripts/check-diagnostics.sh >/dev/null) && fail "a row outside the repository passed"
set_block "$target" '{"state":"implemented","backend":"supabase","parts":["x"]}'
out=$(cd "$target" && ./scripts/check-diagnostics.sh 2>&1) && fail "parts as a list passed"
[[ "$out" == *"Traceback"* ]] && fail "malformed parts crashed the check: $out"
set_block "$target" '{"state":"not-applicable","reason":5}'
out=$(cd "$target" && ./scripts/check-diagnostics.sh 2>&1) && fail "a numeric reason passed"
[[ "$out" == *"Traceback"* ]] && fail "a numeric reason crashed the check: $out"
ok "paths outside the repository, directories and malformed values are refused, without a traceback"

# 5. A local-only project is not applicable, and gets no starter.
local_target="$SCRATCH/local"; mkdir -p "$local_target/src"; git -C "$local_target" init -q
bash "$KIT_ROOT/install.sh" --yes --runs local "$local_target" > "$SCRATCH/local.log" 2>&1 || { cat "$SCRATCH/local.log"; fail "local install failed"; }
[ "$(state "$local_target")" = "not-applicable" ] || fail "local install should be not-applicable"
[ ! -e "$local_target/diagnostics" ] || fail "local install got a starter"
(cd "$local_target" && ./scripts/check-diagnostics.sh | grep -q "not applicable") || fail "local state not printed"
ok "local-only install: not-applicable with its reason"

# 6. A project's own diagnostics/ is kept whole, including a file named ROADMAP.md.
own="$SCRATCH/own"; mkdir -p "$own/src" "$own/diagnostics"; git -C "$own" init -q
echo mine > "$own/diagnostics/ROADMAP.md"
bash "$KIT_ROOT/install.sh" --yes "$own" > "$SCRATCH/own.log" 2>&1 || { cat "$SCRATCH/own.log"; fail "install failed"; }
[ "$(cat "$own/diagnostics/ROADMAP.md")" = mine ] || fail "install deleted the project's own diagnostics/ROADMAP.md"
ok "an existing diagnostics/ is never touched"

# 6b. Re-installing over a decided state adds no starter and asks nothing.
bash "$KIT_ROOT/install.sh" --yes "$local_target" > "$SCRATCH/re.log" 2>&1 || { cat "$SCRATCH/re.log"; fail "re-install failed"; }
[ ! -e "$local_target/diagnostics" ] && [ ! -e "$local_target/docs/roadmap/diagnostics_channel.md" ] || fail "re-install added a starter to a not-applicable project"
[ "$(state "$local_target")" = "not-applicable" ] || fail "re-install changed the state"
grep -qxF "reports/diagnostics/" "$target/.gitignore" || fail "digest output (users' notes) not gitignored"
ok "re-install keeps a decided state; digest output is gitignored"

# 7. The contract test: a valid event passes, a bad one is named.
cat > "$SCRATCH/ok.json" << 'J'
[{"occurred_at":"2026-11-25T10:00:00Z","install_id":"00000000-0000-0000-0000-000000000001","app_version":"dev-1.0","build":"3","os_version":"26.1","device_model":"x","category":"import","code":"import.failed","context":{"reason":"not_a_zip","count":3}}]
J
sed -e 's/"import.failed"/"Import Failed"/' -e 's/"count":3/"file_name":"ride.gpx"/' -e 's/"build":"3"/"build":null/' "$SCRATCH/ok.json" > "$SCRATCH/bad.json"
python3 -I "$KIT_ROOT/modules/diagnostics/check_events.py" "$SCRATCH/ok.json" > /dev/null || fail "a valid event was refused"
out=$(python3 -I "$KIT_ROOT/modules/diagnostics/check_events.py" "$SCRATCH/bad.json") && fail "a bad event passed"
[[ "$out" == *"code does not match"* && "$out" == *"context key file_name not allowed"* && "$out" == *"build is not a non-empty string"* ]] || fail "unexpected: $out"
ok "check_events.py: valid passes, bad code and key named"

# 8. The Supabase intake's own tests, when PostgreSQL is on this machine.
if command -v initdb >/dev/null && command -v pg_ctl >/dev/null && command -v psql >/dev/null; then
  "$KIT_ROOT/modules/diagnostics/supabase/test.sh" > "$SCRATCH/pg.log" 2>&1 || { tail -5 "$SCRATCH/pg.log"; fail "Supabase intake tests failed"; }
  [ "$(grep -c 'all checks passed' "$SCRATCH/pg.log")" = 2 ] || fail "intake tests did not both pass"
  ok "Supabase intake: both test files pass"
else
  ok "Supabase intake: skipped (no PostgreSQL here)"
fi
