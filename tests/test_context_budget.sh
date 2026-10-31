#!/usr/bin/env bash
# Always-loaded text stays within its recorded byte ceilings (tests/context-budget.txt).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

measure() {
  if [ "$1" = skill-frontmatter ]; then
    local tot=0 f
    for f in "$KIT_ROOT"/.claude/skills/*/SKILL.md; do
      tot=$((tot + $(awk '/^---/{n++; next} n==1' "$f" | wc -c)))
    done
    echo "$tot"
  else
    wc -c < "$KIT_ROOT/$1" | tr -d ' '
  fi
}

over=0
while read -r name max; do
  case "$name" in ''|'#'*) continue ;; esac
  got=$(measure "$name")
  if [ "$got" -gt "$max" ]; then
    echo "  ✗ $name: $got B over its ceiling of $max B" >&2; over=1
  else
    ok "$name: $got / $max B"
  fi
done < "$KIT_ROOT/tests/context-budget.txt"
[ "$over" -eq 0 ] || fail "raise the ceiling in tests/context-budget.txt with a reason, or cut the growth"
