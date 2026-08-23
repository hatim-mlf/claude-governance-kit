#!/usr/bin/env bash
#
# claude-governance-kit installer.
#
# Installs the governance system into a target project:
#
#   ./install.sh /path/to/target-project
#
# What it does:
#   1. Asks for (or takes flags for) the project name, short name, and source dir.
#   2. Copies scripts/, .claude/skills/, .claude/rules/ examples, templates, and the
#      dashboard into the target — WITHOUT overwriting files that already exist
#      (an existing CLAUDE.md is yours; the template lands as CLAUDE.governance.md).
#   3. Writes governance.config.json at the target root.
#   4. Creates the ledger/ and reports/ trees and the current ISO week file.
#   5. Installs the git pre-commit hook (symlink, relative).
#   6. Merges the SessionEnd/Stop dashboard-sync hooks into .claude/settings.json
#      when there is one, or writes a fresh one.
#
# What it never does: overwrite your CLAUDE.md, delete anything, or run the
# dashboard generators (that is `npm install && npm run sync`, printed at the end).
#
# Flags:
#   --name "My Project"     display name
#   --short myproject       lowercase id (log file names)
#   --source src            main source directory, relative to the root
#   --yes                   accept defaults, no prompts
#
set -euo pipefail

KIT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

TARGET=""
NAME=""
SHORT=""
SOURCE_DIR=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name)   NAME="$2"; shift 2 ;;
    --short)  SHORT="$2"; shift 2 ;;
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *)  TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || { echo "Usage: ./install.sh [--name N] [--short s] [--source dir] [--yes] /path/to/project" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "No such directory: $TARGET" >&2; exit 1; }
TARGET=$(CDPATH= cd -- "$TARGET" && pwd -P)

if [ ! -d "$TARGET/.git" ]; then
  echo "Note: $TARGET is not a git repository yet. The generators resolve roots from"
  echo ".git, so run 'git init' there before the first sync."
fi

ask() { # ask <variable> <prompt> <default>
  local var="$1" prompt="$2" default="$3" value
  if [ "$ASSUME_YES" -eq 1 ]; then value="$default"
  else printf '%s [%s]: ' "$prompt" "$default" >&2; read -r value; value="${value:-$default}"
  fi
  printf -v "$var" '%s' "$value"
}

base=$(basename "$TARGET")
[ -n "$NAME" ]       || ask NAME "Project display name" "$base"
[ -n "$SHORT" ]      || ask SHORT "Short id (lowercase, for log files)" "$(printf '%s' "$base" | tr 'A-Z ' 'a-z-')"
[ -n "$SOURCE_DIR" ] || ask SOURCE_DIR "Main source directory (relative)" "src"

# copy <src-relative-in-kit> <dst-relative-in-target> — never overwrites
copy_new() {
  local src="$KIT_ROOT/$1" dst="$TARGET/$2"
  if [ -e "$dst" ]; then
    echo "  kept yours:    $2 (template at kit:$1)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "  installed:     $2"
}

echo "Installing claude-governance-kit into $TARGET"

# --- scripts -----------------------------------------------------------------
for s in pre-commit.sh install-hooks.sh check-ledger-entries.sh next-ledger-id.sh dashboard-sync.sh; do
  copy_new "scripts/$s" "scripts/$s"
done
chmod +x "$TARGET"/scripts/*.sh 2>/dev/null || true

# --- skills ------------------------------------------------------------------
for skill_dir in "$KIT_ROOT"/.claude/skills/*/; do
  skill=$(basename "$skill_dir")
  copy_new ".claude/skills/$skill" ".claude/skills/$skill"
done
copy_new ".claude/skills/UPSTREAM.md" ".claude/skills/UPSTREAM.md"

# --- rules -------------------------------------------------------------------
mkdir -p "$TARGET/.claude/rules"
for r in "$KIT_ROOT"/.claude/rules/*.md; do
  copy_new ".claude/rules/$(basename "$r")" ".claude/rules/$(basename "$r")"
done

# --- hooks (settings.json) ----------------------------------------------------
if [ -f "$TARGET/.claude/settings.json" ]; then
  echo "  NOTE: .claude/settings.json exists — merge the SessionEnd/Stop hooks from"
  echo "        $KIT_ROOT/.claude/settings.json by hand (hooks are not auto-merged)."
else
  mkdir -p "$TARGET/.claude"
  cp "$KIT_ROOT/.claude/settings.json" "$TARGET/.claude/settings.json"
  echo "  installed:     .claude/settings.json (SessionEnd + Stop sync hooks)"
fi

# --- templates ----------------------------------------------------------------
# CLAUDE.md is the one file a target project is most likely to already own, and it is
# the one that matters most. Never touch an existing one — land the template beside it
# as CLAUDE.governance.md so the sections can be merged by hand, with both versions
# visible. Silently skipping it (the earlier behaviour) left the operator with nothing
# to merge FROM unless they went back to the kit checkout.
if [ -e "$TARGET/CLAUDE.md" ]; then
  if cmp -s "$KIT_ROOT/templates/CLAUDE.md" "$TARGET/CLAUDE.md"; then
    echo "  kept yours:    CLAUDE.md (already identical to the template)"
  else
    copy_new templates/CLAUDE.md CLAUDE.governance.md
    echo "  NOTE: CLAUDE.md exists and differs — merge the governance sections from"
    echo "        CLAUDE.governance.md into it, then delete that file."
  fi
else
  copy_new templates/CLAUDE.md CLAUDE.md
fi
copy_new templates/CONTEXT.md CONTEXT.md
copy_new templates/MODEL_DELEGATION.md MODEL_DELEGATION.md
copy_new templates/STRUCTURAL_PROBLEMS.md STRUCTURAL_PROBLEMS.md
copy_new templates/FILE_SIZE_REVIEW.md FILE_SIZE_REVIEW.md
copy_new "templates/ledger/README.md" "ledger/README.md"
copy_new "templates/reports/README.md" "reports/README.md"
copy_new "templates/reports/bugs reports/BUG_TRACKER.md" "reports/bugs reports/BUG_TRACKER.md"
# These directories are structural, not incidental: the report classifier reads the
# FOLDER a file sits in to decide its kind — see the long note in
# generate-report-catalog.mjs, which records the misclassification that happened when
# two of them were empty. Git stores files, not directories, so `mkdir` alone means
# they vanish on the target's first commit and nobody sees it until a report lands in
# the wrong place. Each one gets a .gitkeep that says why it is there, so the next
# person to find an "empty" folder does not tidy it away.
for d in reports/bugs reports/errors reports/audits reports/sessions \
         reports/verification prompts docs/roadmap; do
  mkdir -p "$TARGET/$d"
  keep="$TARGET/$d/.gitkeep"
  [ -e "$keep" ] || cat > "$keep" << 'KEEP'
Keeps this directory in git, which stores files and not directories.

The directory is load-bearing: the dashboard's report classifier decides a report's
kind from the folder it sits in, so a missing folder is a misfiled report. Delete this
file once the directory holds something else.
KEEP
done
copy_new "templates/prompts/SESSION_template.md" "prompts/SESSION_template.md"

# --- dashboard ----------------------------------------------------------------
if [ -d "$TARGET/bug-tracker-dashboard" ]; then
  echo "  kept yours:    bug-tracker-dashboard/ (already present)"
else
  mkdir -p "$TARGET/bug-tracker-dashboard"
  # .sync-state.json is this kit checkout's own cache and .DS_Store is Finder noise;
  # copying either hands the target a fingerprint of files it does not have, which
  # makes the first `npm run sync` decide nothing changed and generate nothing.
  rsync -a --exclude node_modules --exclude dist --exclude .sync-state.json \
        --exclude .DS_Store "$KIT_ROOT/dashboard/" "$TARGET/bug-tracker-dashboard/"
  echo "  installed:     bug-tracker-dashboard/"
fi

# --- config -------------------------------------------------------------------
# The schema ships alongside the config: governance.config.json's $schema key is a
# relative path, so without this the editor validation it promises resolves to nothing.
copy_new governance.config.schema.json governance.config.schema.json
if [ -f "$TARGET/governance.config.json" ]; then
  echo "  kept yours:    governance.config.json"
else
  sed -e "s|YOUR PROJECT NAME|$NAME|" \
      -e "s|yourproject|$SHORT|g" \
      -e 's|"path": "src"|"path": "'"$SOURCE_DIR"'"|' \
      "$KIT_ROOT/governance.config.json" > "$TARGET/governance.config.json"
  echo "  installed:     governance.config.json"
fi

# --- this week's ledger file ---------------------------------------------------
week=$(date +%G-W%V)
if [ ! -f "$TARGET/ledger/$week.md" ]; then
  cat > "$TARGET/ledger/$week.md" << EOF
# Ledger — $week

Append-only execution log. Format and rules: \`ledger/README.md\`.
EOF
  echo "  created:       ledger/$week.md"
fi

# --- gitignore -----------------------------------------------------------------
# Without these, the first `git add -A` commits node_modules and the sync cache.
touch "$TARGET/.gitignore"
for line in "node_modules/" "bug-tracker-dashboard/app/dist/" "bug-tracker-dashboard/app/.sync-state.json"; do
  grep -qxF "$line" "$TARGET/.gitignore" || { echo "$line" >> "$TARGET/.gitignore"; echo "  gitignore +=   $line"; }
done

# --- git hooks -----------------------------------------------------------------
if [ -d "$TARGET/.git" ]; then
  (cd "$TARGET" && ./scripts/install-hooks.sh)
fi

cat << EOF

Done. Next steps, in the target project:

  1. Review governance.config.json — sentinels must name files that exist.
  2. If CLAUDE.governance.md was written, merge its sections into your CLAUDE.md
     and delete it.
  3. Generate the dashboard data and run it:
       cd bug-tracker-dashboard/app && npm install && npm run sync && npm run dev
  4. Commit: the pre-commit hook (secrets scan + ledger checks) is live.

EOF
