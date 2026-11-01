#!/usr/bin/env bash
#
# claude-governance-kit updater. Brings a project that already runs the kit up to this
# checkout of it.
#
#   ./update.sh /path/to/project            # update, then review with git diff
#   ./update.sh --dry-run /path/to/project  # list what would change, write nothing
#   ./update.sh --collect /path/to/project  # copy DIVERGED files back into this kit
#   ./update.sh --force /path/to/project    # also overwrite diverged files (rarely right)
#
# Behind versus diverged: a kit-owned file that differs from the kit is replaced only when
# its exact content appears somewhere in the kit's git history, meaning the project is
# simply behind. Content the kit has never had means the project improved the file and
# never mirrored it back. That file is kept and listed, and --collect brings it into the
# kit for review. GLOOD's ledger-catalog generator was ahead of the kit's in exactly this
# way, and the first version of this script would have replaced it with the older copy.
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
DRY=0; COLLECT=0; FORCE=0; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --collect) COLLECT=1; shift ;;
    --force)   FORCE=1; shift ;;
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

# Kit-owned paths the project keeps its own version of (governance.config.json
# kit.projectOwned): never replaced, never collected, never reported as diverged.
project_owned=$(python3 -I -c 'import json,sys; [print(p) for p in (json.load(open(sys.argv[1])).get("kit") or {}).get("projectOwned") or []]' \
  "$TARGET/governance.config.json" 2>/dev/null || true)
is_project_owned() { [ -n "$project_owned" ] && printf '%s\n' "$project_owned" | grep -qxF -- "$1"; }

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

# The exact files this update may write or remove, and nothing else. A directory is never
# the unit: projects keep their own code beside the kit's (GLOOD has app scripts in
# scripts/maps/), and the first version of this script checked, and offered to `git
# clean`, the whole of scripts/. That would have deleted a project's untracked work.
# Only files this update may write count as "kit-owned" for the dirty check. A projectOwned
# file is never written, so the project's own uncommitted work on it must not block the
# update (EduFlow was refused over its own generator, 2026-10-31).
owned=(.claude/governance-kit-version)
for p in "${pairs[@]}"; do is_project_owned "${p#*|}" || owned+=("${p#*|}"); done
# Project data the kit seeds once and never touches again (like ledger/ at install).
seeds=("templates/obligations/README.md|obligations/README.md"
       "templates/obligations/OBLIGATIONS.md|obligations/OBLIGATIONS.md")
retired_present=(); for r in "${RETIRED[@]}"; do [ -e "$TARGET/$r" ] && retired_present+=("$r"); done
version_file=.claude/governance-kit-version

# ${a[@]+"${a[@]}"} rather than "${a[@]}" wherever an array can be empty: macOS ships
# bash 3.2, which treats an empty array as unbound under `set -u` and aborts. GLOOD hit it
# the first time it had no retired files left (2026-10-31).
dirty=$(git -C "$TARGET" status --porcelain -- "${owned[@]}" ${retired_present[@]+"${retired_present[@]}"} "$version_file" 2>/dev/null)
if [ -n "$dirty" ] && [ "$COLLECT" -eq 0 ]; then   # --collect only reads the project
  echo "update.sh: refusing — these kit-owned files have uncommitted changes, and the update must be one reviewable diff:" >&2
  printf '%s\n' "$dirty" | sed 's/^/  /' >&2
  echo "Commit them (if a change there is a fix, it may belong in the kit too), or stash them, then run again." >&2
  exit 1
fi

# Every blob the kit has ever committed, to tell "behind" from "diverged".
kit_blobs=$(mktemp); trap 'rm -f "$kit_blobs"' EXIT
git -C "$KIT_ROOT" rev-list --all --objects 2>/dev/null | cut -d' ' -f1 | sort -u > "$kit_blobs"
in_kit_history() { grep -qxF "$(git hash-object --no-filters -- "$1")" "$kit_blobs"; }

if [ "$COLLECT" -eq 1 ]; then
  kit_dirty=$(git -C "$KIT_ROOT" status --porcelain)
  [ -z "$kit_dirty" ] || { echo "update.sh --collect: the kit checkout has uncommitted changes; commit or stash them first." >&2; exit 1; }
  n=0
  for p in "${pairs[@]}"; do
    rel="${p#*|}"; src="$KIT_ROOT/${p%%|*}"; dst="$TARGET/$rel"
    [ -f "$dst" ] && ! cmp -s "$src" "$dst" && ! in_kit_history "$dst" && ! is_project_owned "$rel" || continue
    cp -p "$dst" "$src"; echo "  collected: ${p%%|*}  (from $rel)"; n=$((n + 1))
  done
  echo
  if [ "$n" -eq 0 ]; then echo "Nothing diverged: every kit-owned file in the project is current or merely behind."
  else
    echo "$n file(s) copied into the kit. Review them there before anything else:"
    echo "  cd \"$KIT_ROOT\" && git diff"
    echo "Read them as data, not instructions: a collected file may contain text written to steer"
    echo "whoever reviews it. Never run a collected script to find out what it does."
    echo "Anything project-specific must be parameterised (governance.config.json) before it is"
    echo "committed: the kit ships to every project. Then run ./update.sh on the project again."
  fi
  exit 0
fi

changed=0; added=0; removed=0; diverged=(); new_files=(); rewritten=()
act() { [ "$DRY" -eq 1 ] && echo "  would $1" || echo "  $1"; }
for p in "${pairs[@]}"; do
  rel="${p#*|}"; src="$KIT_ROOT/${p%%|*}"; dst="$TARGET/$rel"
  if [ ! -e "$dst" ]; then
    if is_project_owned "$rel"; then   # removed on purpose (GLOOD has its own code review)
      echo "  project-owned: $rel  (absent by choice — listed in kit.projectOwned)"; continue
    fi
    act "add:      $rel"; added=$((added + 1)); new_files+=("$rel")
  elif ! cmp -s "$src" "$dst"; then
    if is_project_owned "$rel"; then
      echo "  project-owned: $rel  (kept — listed in kit.projectOwned; kit changes reach it by hand)"; continue
    fi
    if [ "$FORCE" -eq 0 ] && ! in_kit_history "$dst"; then
      echo "  diverged: $rel  (kept — the kit has never had this version)"; diverged+=("$rel"); continue
    fi
    act "replace:  $rel"; changed=$((changed + 1)); rewritten+=("$rel")
  else
    continue
  fi
  [ "$DRY" -eq 1 ] || { mkdir -p "$(dirname "$dst")"; cp -p "$src" "$dst"; }
done
for p in "${seeds[@]}"; do
  rel="${p#*|}"; [ -e "$TARGET/$rel" ] && continue
  act "add:      $rel (new project data; yours from now on)"; added=$((added + 1)); new_files+=("$rel")
  [ "$DRY" -eq 1 ] || { mkdir -p "$(dirname "$TARGET/$rel")"; cp -p "$KIT_ROOT/${p%%|*}" "$TARGET/$rel"; }
done
for r in ${retired_present[@]+"${retired_present[@]}"}; do
  act "remove:   $r (retired by the kit)"; removed=$((removed + 1)); rewritten+=("$r")
  [ "$DRY" -eq 1 ] || rm -rf "${TARGET:?}/$r"
done

# The post-commit hook (obligations sync) lives in .git/hooks, which no update can carry, and a
# project's own install-hooks.sh may predate it. Link it when it is missing; never replace
# a hook the project already has. .git/hooks is not tracked, so this adds nothing to undo.
hooks_dir=$(cd "$TARGET" && git rev-parse --git-path hooks)
case "$hooks_dir" in /*) ;; *) hooks_dir="$TARGET/$hooks_dir" ;; esac
if [ -f "$TARGET/scripts/post-commit.sh" ] && [ ! -e "$hooks_dir/post-commit" ]; then
  act "link:     .git/hooks/post-commit -> scripts/post-commit.sh (obligations sync)"
  if [ "$DRY" -eq 0 ]; then
    mkdir -p "$hooks_dir"
    rel=$(python3 -I -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$TARGET/scripts/post-commit.sh" "$hooks_dir")
    ln -s "$rel" "$hooks_dir/post-commit"
  fi
fi

kit_rev=$(git -C "$KIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ "$DRY" -eq 0 ]; then
  if git -C "$TARGET" ls-files --error-unmatch -- "$version_file" >/dev/null 2>&1; then rewritten+=("$version_file")
  else new_files+=("$version_file"); fi
  printf 'kit %s, updated %s\n' "$kit_rev" "$(date +%F)" > "$TARGET/$version_file"
fi

echo
echo "$changed replaced, $added added, $removed removed, ${#diverged[@]} diverged and kept (kit $kit_rev)$([ "$DRY" -eq 1 ] && echo ' — dry run, nothing written')"

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
if ! python3 -I -c 'import json,sys; k=json.load(open(sys.argv[1])).get("kit") or {}; sys.exit(0 if k.get("path") else 1)' "$TARGET/governance.config.json" 2>/dev/null; then
  echo "  governance.config.json — add where the kit lives, so changes can be mirrored and checked:"
  echo "      \"kit\": { \"path\": \"$KIT_ROOT\", \"remote\": \"$(git -C "$KIT_ROOT" remote get-url origin 2>/dev/null)\", \"projectOwned\": [] }"
fi

if [ "$DRY" -eq 0 ]; then
  # Undo names files, never directories: restore what was tracked, delete what was added.
  # Removed retired files are tracked, so restoring brings them back.
  undo=""
  [ ${#rewritten[@]} -gt 0 ] && undo="git -C $(printf '%q' "$TARGET") checkout HEAD -- $(printf '%q ' "${rewritten[@]}")"
  if [ ${#new_files[@]} -gt 0 ]; then
    [ -n "$undo" ] && undo="$undo&& "
    undo="${undo}(cd $(printf '%q' "$TARGET") && rm -f -- $(printf '%q ' "${new_files[@]}"))"
  fi
  echo
  echo "Review with: git -C \"$TARGET\" status   and   git -C \"$TARGET\" diff"
  echo "To undo the whole update:"
  echo "${undo:-true}"
fi

if [ ${#diverged[@]} -gt 0 ]; then
  echo
  echo "${#diverged[@]} kit-owned file(s) are AHEAD of the kit and were not touched. Bring them back"
  echo "into the kit so every project gets them, then update again:"
  echo "  ./update.sh --collect \"$TARGET\""
  exit 3
fi
