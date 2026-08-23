#!/usr/bin/env bash
#
# Installs the git hooks — claude-governance-kit.
#
# Run once per clone:   ./scripts/install-hooks.sh
#
# .git/hooks is not version controlled, so a hook that lives only there is
# lost on every clone and absent from every backup folder. The hook itself is
# committed under scripts/ and this symlinks it into place, which means
# editing scripts/pre-commit.sh updates the live hook with no reinstall.
#
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Not inside a git repository." >&2
  exit 1
}
cd "$root"

hooks_dir=$(git rev-parse --git-path hooks)
mkdir -p "$hooks_dir"

src="$root/scripts/pre-commit.sh"
dst="$hooks_dir/pre-commit"

[ -f "$src" ] || { echo "Missing $src" >&2; exit 1; }
chmod +x "$src"

# Preserve any pre-existing hook rather than silently destroying it.
if [ -e "$dst" ] && [ ! -L "$dst" ]; then
  backup="$dst.replaced-$(date +%Y%m%d-%H%M%S)"
  mv "$dst" "$backup"
  echo "Existing hook moved to: $backup"
fi

# Link relatively, never absolutely. An absolute target bakes in whatever
# mount point the installer happened to run from, which breaks the moment the
# repo is opened from a different path — a copied backup folder, a different
# machine, or a tool that mounts the tree elsewhere.
rel=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$src" "$hooks_dir" 2>/dev/null || true)
if [ -n "$rel" ]; then
  ln -sf "$rel" "$dst"
else
  ln -sf "$src" "$dst"   # fallback: no python3 available
fi

echo "Installed: pre-commit -> scripts/pre-commit.sh"
echo
echo "  Blocks:  credentials in staged changes"
echo "  Warns:   debug scaffolding marked for removal before release"
echo "  Warns:   stale/open ledger entries, timestamp anomalies"
echo "  Ignores: file size — flagged for review, never blocked"
echo
echo "  Bypass once:  git commit --no-verify"
