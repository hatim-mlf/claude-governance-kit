#!/usr/bin/env bash
# install.sh and update.sh ship only files the kit tracks in git, never caches or other
# untracked files that happen to sit in the kit's working tree.
#
# Why: on 2026-11-26 update-all.sh committed a .ruff_cache folder from the kit's
# building-skills/scripts/ into four projects, because update.sh listed skill files with
# `find` on disk instead of asking git which files the kit owns.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

kit_copy="$SCRATCH/kit"; mkdir -p "$kit_copy"
git -C "$KIT_ROOT" ls-files -z | (cd "$KIT_ROOT" && xargs -0 tar cf -) | (cd "$kit_copy" && tar xf -)
git -C "$kit_copy" init -q && git -C "$kit_copy" config user.email t@e && git -C "$kit_copy" config user.name t
git -C "$kit_copy" add -A && git -C "$kit_copy" commit -qm kit --no-verify
junk=(.claude/skills/grilling/__pycache__/x.cpython-313.pyc .claude/skills/grilling/.ruff_cache/CACHEDIR.TAG .claude/skills/grilling/.DS_Store)
for j in "${junk[@]}"; do mkdir -p "$kit_copy/$(dirname "$j")"; echo junk > "$kit_copy/$j"; done
KIT_ROOT="$kit_copy"

target=$(fresh_install)
for j in "${junk[@]}"; do [ -e "$target/$j" ] && fail "install.sh shipped untracked $j"; done
[ -f "$target/.claude/skills/grilling/SKILL.md" ] || fail "install.sh lost a tracked skill file"
ok "install.sh ships tracked skill files only"

cd "$target"; git add -A && git commit -qm install --no-verify
rm -rf .claude/skills/grilling && git commit -qam "skill gone" --no-verify
bash "$KIT_ROOT/update.sh" "$target" > "$SCRATCH/update.log" 2>&1 || { cat "$SCRATCH/update.log" >&2; fail "update.sh failed"; }
for j in "${junk[@]}"; do [ -e "$target/$j" ] && fail "update.sh shipped untracked $j"; done
[ -f "$target/.claude/skills/grilling/SKILL.md" ] || fail "update.sh did not restore a tracked skill file"
ok "update.sh ships tracked skill files only"
