#!/usr/bin/env bash
# No script aborts on macOS's bash 3.2 because an array was empty.
#
# bash 3.2 (what macOS ships) treats "${a[@]}" of an EMPTY array as unbound under
# `set -u` and exits. update.sh died this way on GLOOD (2026-10-31), the first time it had
# no retired files left. Linux CI runs bash 5, which does not, so nothing caught it.
# Every "${a[@]}" in a `set -u` script must either use ${a[@]+"${a[@]}"} or name an
# array listed below as never empty, with the reason. A new array has to answer that
# question here.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# name   why it is never empty when expanded
NEVER_EMPTY="
pairs            update.sh always lists the kit's scripts
owned            built from pairs
seeds            a fixed list
RETIRED          a fixed list
secret_patterns  a fixed list
debug_patterns   a fixed list
staged           pre-commit exits before this when nothing is staged
findings         check-kit-drift prints it only after checking its length
rewritten        update.sh expands it only inside a length check
new_files        update.sh expands it only inside a length check
dirs             tests/lib.sh: split from PATH, never empty
"
bad=0
for f in "$KIT_ROOT"/scripts/*.sh "$KIT_ROOT"/update.sh "$KIT_ROOT"/install.sh "$KIT_ROOT"/tests/lib.sh; do
  grep -qE '^set -[a-z]*u' "$f" || continue
  while IFS=: read -r n line; do
    for name in $(printf '%s\n' "$line" | grep -oE '"\$\{[A-Za-z_]+\[@\]\}"' | sed -E 's/"\$\{([A-Za-z_]+)\[@\]\}"/\1/'); do
      printf '%s\n' "$line" | grep -qF "\${$name[@]+" && continue
      printf '%s\n' "$NEVER_EMPTY" | grep -qE "^$name " && continue
      echo "  ✗ ${f#"$KIT_ROOT"/}:$n expands \"\${$name[@]}\", which may be empty: use \${$name[@]+\"\${$name[@]}\"} or list it above" >&2
      bad=1
    done
  done < <(grep -n '\[@\]}"' "$f")
done
[ "$bad" -eq 0 ] || fail "an empty array would abort this script on macOS"
ok "every array expansion is safe on bash 3.2"
