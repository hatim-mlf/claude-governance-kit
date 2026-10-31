#!/usr/bin/env bash
#
# claude-governance-kit updater. Brings a project that already runs the kit up to this
# checkout of it.
#
#   ./update.sh /path/to/project            # update, then review with git diff
#   ./update.sh --dry-run /path/to/project  # list what would change, write nothing
#
# Why this is separate from install.sh: the installer never overwrites anything, which is
# right for a first install, and it meant fixes never reached the projects already
# running the kit. This one does overwrite, so it only touches files the KIT owns:
#
#   replaced:   scripts/*.sh · the kit's own skills · the kit's governance rule ·
#               the dashboard generators (<dashboard>/scripts/*.mjs)
#   removed:    files the kit has retired (RETIRED below)
#   never:      CLAUDE.md, ledger/, reports/, STRUCTURAL_PROBLEMS.md, your own rules and
#               skills, .claude/settings.json, governance.config.json
#
# Project-owned documents that ship as templates are LISTED for a hand merge, with the
# diff command to run. They carry the project's own content, so copying over them
# would destroy it.
#
# Safety: it refuses to run while any path it would touch has uncommitted changes, so
# the whole update is one git diff. It prints the exact command that undoes it.
set -euo pipefail

KIT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
DRY=0; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -d "$TARGET" ] || { echo "Usage: ./update.sh [--dry-run] /path/to/project" >&2; exit 2; }
TARGET=$(CDPATH= cd -- "$TARGET" && pwd -P)
git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository: $TARGET" >&2; exit 1; }
[ -f "$TARGET/scripts/pre-commit.sh" ] || [ -f "$TARGET/governance.config.json" ] \
  || { echo "No kit installed in $TARGET — run ./install.sh first." >&2; exit 1; }

# Files the kit has retired. A rename or merge adds its old path here, so projects lose
# the old copy instead of loading both.
RETIRED=(
  .claude/rules/governance-changes-reach-the-kit.md   # merged into changing-the-governance-system.md
  .claude/rules/new-material-is-placed-deliberately.md
  .claude/rules/skills-stay-indexed.md
  .claude/skills/grill-me                               # alias of grilling
)

dash=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("dashboard",{}).get("dir",""))' \
  "$TARGET/governance.config.json" 2>/dev/null || true)
[ -n "$dash" ] || dash="bug-tracker-dashboard/app"

# kit path -> project path, for every kit-owned file.
pairs=()
for f in "$KIT_ROOT"/scripts/*.sh; do pairs+=("scripts/$(basename "$f")|scripts/$(basename "$f")"); done
while IFS= read -r f; do
  rel="${f#"$KIT_ROOT"/}"; pairs+=("$rel|$rel")
done < <(find "$KIT_ROOT/.claude/skills" -mindepth 2 -type f | sort)
pairs+=(".claude/rules/changing-the-governance-system.md|.claude/rules/changing-the-governance-system.md")
if [ -d "$TARGET/$dash/scripts" ]; then
  for f in "$KIT_ROOT"/dashboard/app/scripts/*.mjs; do pairs+=("dashboard/app/scripts/$(basename "$f")|$dash/scripts/$(basename "$f")"); done
fi

touch_paths=(scripts .claude/skills .claude/rules .claude/governance-kit-version)
[ -d "$TARGET/$dash/scripts" ] && touch_paths+=("$dash/scripts")

dirty=$(git -C "$TARGET" status --porcelain -- "${touch_paths[@]}")
if [ -n "$dirty" ]; then
  echo "update.sh: refusing — these have uncommitted changes, and the update must be one reviewable diff:" >&2
  printf '%s\n' "$dirty" | sed 's/^/  /' >&2
  echo "Commit or stash them, then run again." >&2
  exit 1
fi

changed=0; added=0; removed=0
act() { [ "$DRY" -eq 1 ] && echo "  would $1" || echo "  $1"; }
for p in "${pairs[@]}"; do
  src="$KIT_ROOT/${p%%|*}"; dst="$TARGET/${p#*|}"
  if [ ! -e "$dst" ]; then
    act "add:      ${p#*|}"; added=$((added + 1))
  elif ! cmp -s "$src" "$dst"; then
    act "replace:  ${p#*|}"; changed=$((changed + 1))
  else
    continue
  fi
  [ "$DRY" -eq 1 ] || { mkdir -p "$(dirname "$dst")"; cp -p "$src" "$dst"; }
done
for r in "${RETIRED[@]}"; do
  [ -e "$TARGET/$r" ] || continue
  act "remove:   $r (retired by the kit)"; removed=$((removed + 1))
  [ "$DRY" -eq 1 ] || rm -rf "${TARGET:?}/$r"
done

kit_rev=$(git -C "$KIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
[ "$DRY" -eq 1 ] || printf 'kit %s, updated %s\n' "$kit_rev" "$(date +%F)" > "$TARGET/.claude/governance-kit-version"

echo
echo "$changed replaced, $added added, $removed removed (kit $kit_rev)$([ "$DRY" -eq 1 ] && echo ' — dry run, nothing written')"

echo
echo "Merge by hand — these are yours, and the kit's template has changed shape:"
merge() {  # project-file kit-template
  [ -f "$TARGET/$1" ] || return 0
  cmp -s "$TARGET/$1" "$KIT_ROOT/$2" && return 0
  echo "  $1"
  echo "      git diff --no-index \"$TARGET/$1\" \"$KIT_ROOT/$2\""
}
merge CLAUDE.md templates/CLAUDE.md
merge ledger/README.md templates/ledger/README.md
merge "reports/bugs reports/BUG_TRACKER.md" "templates/reports/bugs reports/BUG_TRACKER.md"
merge .claude/skills/UPSTREAM.md .claude/skills/UPSTREAM.md
echo "  (For the tracker, only the Status vocabulary section is the kit's; your rows stay.)"

if [ "$DRY" -eq 0 ]; then
  q=$(printf '%q ' "${touch_paths[@]}")
  # checkout aborts entirely if ANY pathspec is not in HEAD (the version file is new on a
  # first update), so it names only tracked paths; clean removes what the update added.
  tracked=(); for p in "${touch_paths[@]}"; do
    [ -n "$(git -C "$TARGET" ls-tree --name-only HEAD -- "$p")" ] && tracked+=("$p")
  done
  qt=$(printf '%q ' "${tracked[@]}")
  echo
  echo "Review with: git -C \"$TARGET\" status   and   git -C \"$TARGET\" diff"
  echo "To undo the whole update:"
  echo "git -C \"$TARGET\" checkout HEAD -- ${qt}&& git -C \"$TARGET\" clean -fdq -- ${q}"
fi
