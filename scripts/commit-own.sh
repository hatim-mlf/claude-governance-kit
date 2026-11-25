#!/usr/bin/env bash
set -euo pipefail
# Commit only the given paths, from a private index read from HEAD at commit time, and move HEAD
# only if no other commit landed meanwhile. Several agent sessions share one repository: a commit
# built from an index read before another session's commit silently reverts that commit (seen in
# Project A, 2026-11-10). Usage: scripts/commit-own.sh -F <message-file> -- <path> [<path> ...]

usage() {
  echo "usage: scripts/commit-own.sh -F <message-file> -- <path> [<path> ...]" >&2
  exit 2
}

message_file=""
paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -F)
      [[ $# -ge 2 ]] || usage
      message_file="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      ;;
  esac
done

paths=("$@")   # everything after --
[[ -n "$message_file" ]] || usage
[[ ${#paths[@]} -gt 0 ]] || usage

old_head="$(git rev-parse HEAD)"
tmp_index="$(mktemp "${TMPDIR:-/tmp}/commit-own.XXXXXX")"
trap 'rm -f "$tmp_index"' EXIT

GIT_INDEX_FILE="$tmp_index" git read-tree "$old_head"

for path in ${paths[@]+"${paths[@]}"}; do
  if [[ -e "$path" ]]; then
    GIT_INDEX_FILE="$tmp_index" git add -- "$path"
  else
    GIT_INDEX_FILE="$tmp_index" git rm -q --cached --ignore-unmatch -- "$path"
  fi
done

tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree)"
old_tree="$(git rev-parse "$old_head^{tree}")"
if [[ "$tree" == "$old_tree" ]]; then
  echo "commit-own: nothing to commit for the given paths" >&2
  exit 1
fi

root="$(git rev-parse --show-toplevel)"
if [[ -x "$root/scripts/pre-commit.sh" ]]; then
  GIT_INDEX_FILE="$tmp_index" "$root/scripts/pre-commit.sh" || {
    echo "commit-own: pre-commit refused" >&2
    exit 1
  }
fi

new_commit="$(git commit-tree "$tree" -p "$old_head" -F "$message_file")"

if [[ -n "${COMMIT_OWN_BEFORE_UPDATE:-}" ]]; then
  eval "$COMMIT_OWN_BEFORE_UPDATE"
fi

git update-ref -m "commit-own: $(head -1 "$message_file")" HEAD "$new_commit" "$old_head" || {
  echo "commit-own: HEAD moved while committing; nothing changed, run again" >&2
  exit 1
}

git reset -q -- ${paths[@]+"${paths[@]}"}

# Every path the commit changed must be one that was asked for.
committed_paths="$(git diff --name-only "$old_head" HEAD)"
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  if ! printf '%s\n' ${paths[@]+"${paths[@]}"} | grep -Fxq -- "$p"; then
    echo "commit-own: commit touched an unexpected path: $p" >&2
    exit 1
  fi
done <<< "$committed_paths"

git log -1 --format='%h %s'
printf '%s\n' "$committed_paths"
exit 0
