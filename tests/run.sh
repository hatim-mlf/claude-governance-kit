#!/usr/bin/env bash
#
# Run every tests/test_*.sh. Each test file is a plain bash script that exits non-zero
# on failure; nothing here needs more than bash and git, so the suite runs on a clean
# machine — which is the point of having it.
#
#   tests/run.sh                 # all
#   tests/run.sh test_install    # one, by name
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0; fail=0; failed=()

for t in "$TESTS_DIR"/test_*.sh; do
  name=$(basename "$t" .sh)
  [ $# -gt 0 ] && [[ " $* " != *" $name "* ]] && continue
  if out=$(bash "$t" 2>&1); then
    pass=$((pass + 1)); echo "ok    $name"
  else
    fail=$((fail + 1)); failed+=("$name"); echo "FAIL  $name"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
done

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
