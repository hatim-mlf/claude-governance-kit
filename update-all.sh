#!/usr/bin/env bash
#
# Update every project that runs this kit, in one local run. No model is involved, so it
# costs no tokens.
#
#   ./update-all.sh --scan ~/Documents            # preview every project found (writes nothing)
#   ./update-all.sh --apply --scan ~/Documents    # update and commit the safe ones
#   ./update-all.sh --apply ~/Documents/a ~/Documents/b
#   ./update-all.sh --no-pull ...               # use this checkout as it is (offline)
#
# The kit comes straight from GitHub: before anything else, this checkout is fast-forwarded
# from its remote, so there is no separate `git pull` to forget. A checkout with
# uncommitted changes, or one that has diverged from its remote, stops the run: projects
# are only ever updated from a kit someone published.
#
# Why: six projects run the kit, and updating each by hand is six rounds of dry run,
# apply, stage and commit, typed into a terminal. Every decision stays with update.sh
# (behind versus diverged, kit.projectOwned, refusing over uncommitted kit files). This
# script only finds the projects, runs update.sh on each, and commits exactly the files
# update.sh reports it touched, never the project's own work.
#
# A project is skipped, and named, when update.sh refuses it (uncommitted kit files) or
# when any kit file there has diverged (run ./update.sh --collect on it). Nothing is ever
# pushed; each project's commit is yours to review and push.
set -uo pipefail

KIT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
APPLY=0; PULL=1; scans=(); projects=()
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --no-pull) PULL=0; shift ;;
    --scan)  scans+=("$2"); shift 2 ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *)  projects+=("$1"); shift ;;
  esac
done

# A governed project: a git repository with the kit's pre-commit script, one or two levels
# below a scanned folder. The kit's own checkout is not a project.
for s in ${scans[@]+"${scans[@]}"}; do
  while IFS= read -r hook; do
    p=$(dirname "$(dirname "$hook")")
    [ -d "$p/.git" ] || continue
    [ "$(cd "$p" && pwd -P)" = "$KIT_ROOT" ] && continue
    projects+=("$p")
  done < <(find "$s" -mindepth 3 -maxdepth 4 -path '*/scripts/pre-commit.sh' -not -path '*/node_modules/*' 2>/dev/null | sort)
done
log=$(mktemp); trap 'rm -f "$log"' EXIT
[ ${#projects[@]} -gt 0 ] || { echo "Usage: ./update-all.sh [--apply] (--scan DIR | PROJECT...)" >&2; exit 2; }

if [ "$PULL" -eq 1 ]; then
  if [ -n "$(git -C "$KIT_ROOT" status --porcelain)" ]; then
    echo "update-all.sh: the kit checkout at $KIT_ROOT has uncommitted changes. Commit or stash them," >&2
    echo "or pass --no-pull to update from it as it is." >&2
    exit 1
  fi
  remote_url=$(git -C "$KIT_ROOT" remote get-url origin 2>/dev/null || echo "its remote")
  if ! git -C "$KIT_ROOT" pull -q --ff-only 2>"$log"; then
    echo "update-all.sh: could not fast-forward the kit from $remote_url:" >&2
    sed 's/^/  /' "$log" >&2
    echo "Fix the kit checkout, or pass --no-pull to update from it as it is." >&2
    exit 1
  fi
  echo "Kit brought up to date from GitHub/origin ($remote_url)."
fi
kit_rev=$(git -C "$KIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

# commit_touched PROJECT MESSAGE PATH...: commit exactly PATH... on top of HEAD.
# Returns 0 when committed, 1 when they already match HEAD, 2 on failure ($commit_error).
commit_rc=0; commit_error=""
commit_touched() {
  local p="$1" msg="$2" old tmp tree new path; shift 2
  old=$(git -C "$p" rev-parse -q --verify HEAD) || { commit_rc=2; commit_error="the project has no commit yet"; return 2; }
  tmp="$(cd "$p" && git rev-parse --absolute-git-dir)/kit-update-index"
  rm -f "$tmp"
  GIT_INDEX_FILE="$tmp" git -C "$p" read-tree HEAD || { commit_rc=2; commit_error="could not read HEAD"; return 2; }
  for path in "$@"; do
    if [ -e "$p/$path" ]; then GIT_INDEX_FILE="$tmp" git -C "$p" add -f -- "$path"
    else GIT_INDEX_FILE="$tmp" git -C "$p" rm -r -q --cached --ignore-unmatch -- "$path"; fi \
      || { rm -f "$tmp"; commit_rc=2; commit_error="could not stage $path"; return 2; }
  done
  tree=$(GIT_INDEX_FILE="$tmp" git -C "$p" write-tree); rm -f "$tmp"
  if [ "$tree" = "$(git -C "$p" rev-parse "HEAD^{tree}")" ]; then commit_rc=1; return 1; fi
  new=$(git -C "$p" commit-tree "$tree" -p "$old" -m "$msg") \
    && git -C "$p" update-ref -m "commit: $msg" HEAD "$new" "$old" \
    || { commit_rc=2; commit_error="git refused the commit"; return 2; }
  # Bring the real index in line for those paths only, leaving anything the project staged.
  # --no-refresh: a plain reset re-checks every file in the working tree afterwards, which is
  # the same slow scan this function exists to avoid. Older git lacks the flag; fall back.
  git -C "$p" reset -q --no-refresh -- "$@" 2>/dev/null || git -C "$p" reset -q -- "$@" 2>/dev/null || true
  commit_rc=0
}

echo "Kit $kit_rev — $([ "$APPLY" -eq 1 ] && echo "updating" || echo "preview, nothing is written; add --apply to update")"
echo
updated=0; current=0; skipped=0

for p in ${projects[@]+"${projects[@]}"}; do
  p=$(cd "$p" && pwd -P); name=$(basename "$p")
  "$KIT_ROOT/update.sh" --dry-run "$p" > "$log" 2>&1; rc=$?
  summary=$(grep -E '^[0-9]+ replaced, ' "$log" | head -1)
  diverged=$(printf '%s' "$summary" | sed -nE 's/.* ([0-9]+) diverged.*/\1/p')
  if [ -z "$summary" ]; then
    echo "  ✗ $name — update.sh refused it:"; sed 's/^/        /' "$log" | head -6; skipped=$((skipped + 1)); continue
  fi
  if [ "${diverged:-0}" -gt 0 ]; then
    echo "  ✗ $name — $diverged diverged kit file(s), skipped. Bring them back first:"
    echo "        $KIT_ROOT/update.sh --collect \"$p\""
    skipped=$((skipped + 1)); continue
  fi
  if printf '%s' "$summary" | grep -qE '^0 replaced, 0 added, 0 removed'; then
    echo "  ✓ $name — already current"; current=$((current + 1)); continue
  fi
  if [ "$APPLY" -eq 0 ]; then
    echo "  · $name — would update: ${summary%% (kit*}"; continue
  fi

  "$KIT_ROOT/update.sh" "$p" > "$log" 2>&1
  # Exactly the paths update.sh reports, plus the version stamp.
  touched=(.claude/governance-kit-version)
  while IFS= read -r path; do touched+=("$path"); done < <(sed -nE 's/^  (add|replace|remove): +([^ ].*)$/\2/p' "$log" | sed -E 's/ +\(.*\)$//')
  # The commit is built from those paths alone, with git's plumbing and a scratch index, never
  # with `git commit`. `git commit` commits the whole index, so it would sweep in work the
  # project had staged itself, and it re-reads every modified file in the working tree: in
  # EduFlow (35.85 GiB of history, thousands of files modified by a verification run) that
  # ran for many minutes. Hooks do not run on this commit: it holds only the kit's files.
  if commit_touched "$p" "governance: update from claude-governance-kit ($kit_rev)" ${touched[@]+"${touched[@]}"}; then
    echo "  ✓ $name — updated and committed: ${summary%% (kit*}"; updated=$((updated + 1))
  elif [ "$commit_rc" -eq 1 ]; then
    echo "  ✓ $name — nothing to commit"; current=$((current + 1))
  else
    echo "  ✗ $name — updated but not committed: $commit_error"
    echo "        the files are written; commit them yourself, or undo with update.sh's printed command"
    skipped=$((skipped + 1))
  fi
done

echo
echo "$updated updated, $current already current, $skipped skipped$([ "$APPLY" -eq 0 ] && echo ' (preview)')"
[ "$APPLY" -eq 1 ] && [ "$updated" -gt 0 ] && echo "Nothing was pushed. Review each project's last commit (git log -1 -p) before pushing it."
echo "Each project may also list templates to merge by hand: run update.sh --dry-run on it to see them."
[ "$skipped" -eq 0 ]
