#!/usr/bin/env bash
# Tests for launch-session.sh, all in --dry-run (no window is opened). Run: bash test_launch-session.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
sut="$here/launch-session.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp" && git init -q .
printf '# Session: x\n\nSuggested model: Sonnet. Normal work.\n' > p.md
printf '# Session: y\n\nNo model line here.\n' > nomodel.md

fails=0
check() { # name, expected exit, grep pattern ('' = none), 'absent' to require no match; then args
  local name="$1" want="$2" pat="$3" mode="$4"; shift 4
  out="$(bash "$sut" "$@" 2>&1)"; got=$?
  ok=1
  [ "$got" -eq "$want" ] || ok=0
  if [ -n "$pat" ]; then
    if [ "$mode" = absent ]; then grep -q -- "$pat" <<<"$out" && ok=0
    else grep -q -- "$pat" <<<"$out" || ok=0; fi
  fi
  if [ "$ok" -eq 1 ]; then echo "ok   $name"; else echo "FAIL $name (exit $got): $out"; fails=$((fails+1)); fi
}

check "no bypass by default"        0 "dangerously-skip-permissions" absent --dry-run p.md demo-session
check "bypass only when asked"      0 "dangerously-skip-permissions" present --dry-run --bypass p.md demo-session
check "remote control named"        0 "--remote-control demo-session" present --dry-run p.md demo-session
check "model from Suggested line"   0 "--model sonnet" present --dry-run p.md demo-session
check "--model overrides"           0 "--model opus" present --dry-run --model opus p.md demo-session
check "prompt path in message"      0 "Run\\\\ the\\\\ session\\\\ prompt\\\\ p.md" present --dry-run p.md demo-session
check "missing prompt refused"      2 "not found" present --dry-run missing.md demo-session
check "unsafe name refused"         2 "session name" present --dry-run p.md 'Bad Name;rm'
check "no model line refused"       2 "Suggested model" present --dry-run nomodel.md demo-session
check "unknown model refused"       2 "unknown model" present --dry-run --model gpt p.md demo-session
check "wrong arg count refused"     2 "" present --dry-run p.md

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
