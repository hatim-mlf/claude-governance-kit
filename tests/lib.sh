# Shared helpers for tests/test_*.sh. Sourced, never executed.

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A scratch directory removed when the test exits.
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "  ✗ $*" >&2; exit 1; }
ok()   { echo "  ✓ $*"; }

# PATH containing every command on the current PATH except the ones named.
# Used to prove the kit does not depend on a tool it never declared.
path_without() {
  local bin="$SCRATCH/restricted-bin" dir cmd
  mkdir -p "$bin"
  IFS=: read -ra dirs <<< "$PATH"
  for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue
    for cmd in "$dir"/*; do
      [ -x "$cmd" ] || continue
      local name; name=$(basename "$cmd")
      [[ " $* " == *" $name "* ]] && continue
      [ -e "$bin/$name" ] || ln -s "$cmd" "$bin/$name"
    done
  done
  echo "$bin"
}

# A fresh git repository with the kit installed into it, non-interactively.
# Prints the target path. Fails the test if the installer exits non-zero.
fresh_install() {
  local target="$SCRATCH/project"
  mkdir -p "$target/src"
  git -C "$target" init -q
  git -C "$target" config user.email test@example.com
  git -C "$target" config user.name test
  printf 'Probe\nprb\nsrc\n' | bash "$KIT_ROOT/install.sh" "$target" > "$SCRATCH/install.log" 2>&1 \
    || { cat "$SCRATCH/install.log" >&2; fail "install.sh exited non-zero"; }
  echo "$target"
}
