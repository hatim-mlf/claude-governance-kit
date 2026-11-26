#!/usr/bin/env bash
# building-skills: the lint, skill-creator discovery and trigger scorer meet the judge's guards
# (docs/skill-builder/verdict.md, 2026-11-25).
#
# Why: six kit skills were listed by Claude Code with no description (a multi-line plain YAML
# description containing ": "), and nothing checked the label. Each guard below is a fault the
# debate reproduced with a run; the fixtures in tests/fixtures/building-skills/ are frozen.
# "Both modes" = PyYAML importable, and PyYAML blocked (the stock macOS python3 has none).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SK="$KIT_ROOT/.claude/skills/building-skills"
LINT="$SK/scripts/lint_skill.py"
FIND="$SK/scripts/find_skill_creator.py"
SCORE="$SK/scripts/score_triggers.py"
FX="$KIT_ROOT/tests/fixtures/building-skills"
[ -f "$LINT" ] || fail "missing $LINT"

with_yaml() { python3 -I "$LINT" "$@"; }
no_yaml() {
  python3 -I -c 'import runpy, sys; sys.modules["yaml"] = None; sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$LINT" "$@"
}
modes=(no_yaml)
python3 -I -c 'import yaml' 2>/dev/null && modes+=(with_yaml) || echo "  (PyYAML absent: with-yaml mode skipped)"
stock() { /usr/bin/python3 -I "$LINT" "$@"; }   # macOS system python3 (3.9), no PyYAML
[ -x /usr/bin/python3 ] && modes+=(stock)

# expect MODE DIR pass|fail [RULE] -- verdict and, for a fail, the rule id that must be named
expect() {
  local mode=$1 dir=$2 want=$3 rule=${4:-} out rc=0
  out=$("$mode" "$dir" 2>&1) || rc=$?
  if [ "$want" = pass ] && [ $rc -ne 0 ]; then fail "$mode $(basename "$dir"): want PASS, got: $out"; fi
  if [ "$want" = fail ] && [ $rc -ne 1 ]; then fail "$mode $(basename "$dir"): want FAIL, got rc=$rc: $out"; fi
  if [ -n "$rule" ] && ! grep -q "$rule" <<< "$out"; then fail "$mode $(basename "$dir"): want $rule in: $out"; fi
  return 0
}

for m in "${modes[@]}"; do
  # Guard 1: the frozen corpus, 9 must-flag with the right rule, 9 must-pass.
  for s in session-report session-prompt audit-report bug-report error-report swift-xcode-audit; do
    expect "$m" "$FX/corpus/flag/$s" fail "FAIL YAML-COLON"
  done
  expect "$m" "$FX/corpus/flag/deepen-the-task" fail "FAIL YAML-COLON"
  expect "$m" "$FX/corpus/flag/decide-by-debate" fail "FAIL YAML-COLON"
  expect "$m" "$FX/corpus/flag/project-code-review" fail "FAIL DESC-ANGLE"
  for d in "$FX"/corpus/pass/*/; do expect "$m" "$d" pass; done
  # Guards 2-12.
  G="$FX/guards"
  expect "$m" "$G/broken-flow" fail "YAML-FLOW"
  expect "$m" "$G/escaped-angle" fail "DESC-ANGLE"
  expect "$m" "$G/flow-metadata" pass
  expect "$m" "$G/boolean-description" fail "DESC-TYPE"
  expect "$m" "$G/desc-flow-list" fail "DESC-TYPE"
  expect "$m" "$G/name-integer" fail "NAME-TYPE"
  expect "$m" "$G/body-499" pass
  expect "$m" "$G/reference-chain" fail "RESOURCE-CHAIN"
  expect "$m" "$G/backslash-in-reference" fail "PATH-BACKSLASH"
  expect "$m" "$G/regex-example" pass
  expect "$m" "$G/voice-roman-i" pass
  expect "$m" "$G/toc-plain-list" pass
  expect "$m" "$G/orphan-reference" pass
  "$m" "$G/orphan-reference" | grep -q "WARN RESOURCE-ORPHAN" || fail "$m: orphan-reference should warn"
done
ok "guards 1-12: corpus and fixtures, in ${#modes[@]} mode(s)"

# Guard 13: one named WARN when strict YAML could not be verified, none when it could.
[ "$(no_yaml "$FX/guards/no-pyyaml" | grep -c 'WARN STRICT-YAML-UNVERIFIED')" = 1 ] \
  || fail "no PyYAML should print exactly one STRICT-YAML-UNVERIFIED"
if python3 -I -c 'import yaml' 2>/dev/null; then
  with_yaml "$FX/corpus/pass/grilling" | grep -q STRICT-YAML-UNVERIFIED && fail "PyYAML present: no WARN expected"
fi
ok "guard 13: STRICT-YAML-UNVERIFIED only without PyYAML"

# Guard 14: --ship adds the eval gate; the default does not.
expect no_yaml "$FX/corpus/pass/grilling" pass
out=$(no_yaml --ship "$FX/corpus/pass/grilling" 2>&1) && fail "--ship without evals should FAIL"
grep -q "FAIL EVALS" <<< "$out" || fail "--ship should name EVALS: $out"
ok "guard 14: --ship gates on evals"

# Guard 15: skill-creator discovery never auto-picks among several copies.
fake_sc() { mkdir -p "$1/scripts"; : > "$1/scripts/run_eval.py"; }
H="$SCRATCH/home"; mkdir -p "$H"
out=$(HOME="$H" SKILL_CREATOR_DIR= python3 -I "$FIND" 2>&1) && fail "none found should exit 3"
grep -q "skill-creator" <<< "$out" && grep -q "Searched" <<< "$out" && grep -q "SKILL_CREATOR_DIR" <<< "$out" \
  || fail "missing message must name what, where searched, how to get it: $out"
fake_sc "$H/.claude/skills/synced/aaa/skill-creator"
got=$(HOME="$H" SKILL_CREATOR_DIR= python3 -I "$FIND") || fail "one copy should exit 0"
[ "$got" = "$H/.claude/skills/synced/aaa/skill-creator" ] || fail "one copy: printed $got"
fake_sc "$H/.claude/plugins/marketplaces/m/plugins/skill-creator/skills/skill-creator"
rc=0; out=$(HOME="$H" SKILL_CREATOR_DIR= python3 -I "$FIND" 2>&1) || rc=$?
[ $rc -eq 3 ] || fail "two copies should exit 3, got $rc"
[ "$(grep -c '/skill-creator$' <<< "$out")" -ge 2 ] || fail "two copies should both be listed: $out"
fake_sc "$SCRATCH/chosen"
[ "$(HOME="$H" SKILL_CREATOR_DIR="$SCRATCH/chosen" python3 -I "$FIND")" = "$SCRATCH/chosen" ] || fail "env var should win"
[ "$(HOME="$H" python3 -I "$FIND" --skill-creator "$SCRATCH/chosen")" = "$SCRATCH/chosen" ] || fail "flag should win"
ok "guard 15: discovery (flag, env, one, several, none)"

# Guard 16: the not-found message still prints when TMPDIR cannot be written.
ro="$SCRATCH/ro"; mkdir -p "$ro"; chmod 500 "$ro"
out=$(HOME="$SCRATCH/empty" TMPDIR="$ro" SKILL_CREATOR_DIR= python3 -I "$FIND" 2>&1) || true
chmod 700 "$ro"
grep -q "Searched" <<< "$out" || fail "message lost with unwritable TMPDIR: $out"
ok "guard 16: not-found message with unwritable TMPDIR"

# Guard 17: the scorer starts on the stock python3 (3.9 on macOS).
for py in python3 /usr/bin/python3; do
  command -v "$py" >/dev/null || continue
  "$py" -I "$SCORE" --help >/dev/null 2>&1 || fail "$py cannot run score_triggers.py --help"
done
ok "guard 17: score_triggers.py runs on every python3 here"

# Scorer outcomes, with a fake `claude` on PATH: a hit after orienting, a competing skill, no
# skill, an error result, a crash and a hang. Errors and timeouts are never counted as misses
# (a usage limit once turned every run into a "miss"), and runs are confined to read-only tools.
fake="$SCRATCH/fakebin"; mkdir -p "$fake"
cat > "$fake/claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LOG"
q=$2
tool() { printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"%s","input":%s}]}}\n' "$1" "$2"; }
case "$q" in
  *HIT*)   tool Glob '{"pattern":"**"}'; tool Skill '{"skill":"demo"}' ;;
  *OTHER*) tool Skill '{"skill":"other"}' ;;
  *NONE*)  printf '{"type":"result","is_error":false}\n' ;;
  *ERR*)   printf '{"type":"result","is_error":true,"result":"usage limit"}\n'; exit 1 ;;
  *DIE*)   exit 1 ;;
  *HANG*)  sleep 20 ;;
esac
FAKE
chmod +x "$fake/claude"
mkdir -p "$SCRATCH/corpus/demo"; printf -- '---\nname: demo\ndescription: Demo. Use on demo.\n---\n' > "$SCRATCH/corpus/demo/SKILL.md"
cat > "$SCRATCH/q.json" <<'Q'
{"demo": [{"query": "HIT me", "should_trigger": true}, {"query": "OTHER one", "should_trigger": true},
          {"query": "NONE here", "should_trigger": false}, {"query": "ERR out", "should_trigger": true},
          {"query": "DIE now", "should_trigger": true}, {"query": "HANG on", "should_trigger": true}]}
Q
rc=0
FAKE_LOG="$SCRATCH/fake.log" PATH="$fake:$PATH" python3 -I "$SCORE" --corpus "$SCRATCH/corpus" \
  --queries "$SCRATCH/q.json" --runs 1 --workers 6 --timeout 3 --out "$SCRATCH/s.json" > "$SCRATCH/s.txt" 2>&1 || rc=$?
[ $rc -eq 4 ] || { cat "$SCRATCH/s.txt" >&2; fail "errored runs should exit 4, got $rc"; }
python3 -I - "$SCRATCH/s.json" <<'PY' || fail "scorer outcomes wrong: $(cat "$SCRATCH/s.json")"
import json, sys
s = json.load(open(sys.argv[1]))["scores"]["demo"]
rows = {r["query"].split()[0]: r for r in s["rows"]}
assert rows["HIT"]["hits"] == 1 and rows["HIT"]["pass"] is True
assert rows["OTHER"]["instead"] == ["skill:other"] and rows["OTHER"]["pass"] is False
assert rows["NONE"]["pass"] is True
for k in ("ERR", "DIE", "HANG"):
    assert rows[k]["errors"] == 1 and rows[k]["runs"] == 0 and rows[k]["pass"] is None, k
assert s["pos_missed"] == 1 and s["errors"] == 3 and s["inconclusive"] == 3
PY
grep -q -- "--tools Skill,Read,Glob,Grep" "$SCRATCH/fake.log" && grep -q -- "--strict-mcp-config" "$SCRATCH/fake.log" \
  || fail "runs must be confined to read-only tools and no MCP: $(head -1 "$SCRATCH/fake.log")"
ok "scorer: hit after orienting, other skill, no skill; errors and timeouts never count as misses"

# The skill passes its own lint, including the ship gate.
expect no_yaml "$SK" pass
no_yaml --ship "$SK" > "$SCRATCH/self" || { cat "$SCRATCH/self" >&2; fail "building-skills fails its own --ship lint"; }
ok "building-skills passes its own lint with --ship"
