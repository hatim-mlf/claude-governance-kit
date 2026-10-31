#!/usr/bin/env bash
#
# A status line holds one word from the vocabulary, and nothing else.
#
#   Ledger:  🟡 Open · ✅ Closed · ⏸️ Abandoned
#   Tracker: 🟠 Open · 🟡 Fixed, unverified · 🟢 Fixed, verified · ⚪ Product gap
#
# The explanation goes on the next line, as `**Status note:** …`.
#
# Why: the fixed-versus-verified split is the point of the tracker, and it only counts if
# a parser can read it. In the project this kit came from, the format invited prose after
# the status word. A 2026-10-31 audit found over 100 distinct status strings for 332 bugs
# and 23 ledger entries with no status at all, so nothing could count how many fixes were
# still unverified.
#
#   scripts/check-status-lines.sh --staged   # only lines this commit ADDS (pre-commit)
#   scripts/check-status-lines.sh            # every status line (audit mode)
#
# Warn-tier: exit 1 means findings, printed to stdout. Nothing is blocked. At commit time
# only added lines are checked; a mature project's legacy rows would otherwise print a
# hundred warnings on every commit, and a warning that always fires is not read.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Status-line check DID NOT RUN — not inside a git repository."; exit 1; }
cd "$root"

# Emoji are optional; the words are exact; nothing may follow them.
ledger_re='^\*\*Status:\*\*[[:space:]]*(🟡[[:space:]]*Open|✅[[:space:]]*Closed|⏸️?[[:space:]]*Abandoned|Open|Closed|Abandoned)[[:space:]]*$'
tracker_re='^\*\*Status:\*\*[[:space:]]*(🟠[[:space:]]*|🟡[[:space:]]*|🟢[[:space:]]*|⚪[[:space:]]*)?(Open|Fixed, unverified|Fixed, verified|Product gap)[[:space:]]*$'

kind_of() {
  case "$1" in
    ledger/*/README.md|ledger/README.md) echo skip ;;
    ledger/*.md|ledger/*/*.md) echo ledger ;;
    */BUG_TRACKER.md|BUG_TRACKER.md) case "$1" in */archive/*) echo skip ;; *) echo tracker ;; esac ;;
    *) echo skip ;;
  esac
}

findings="$(mktemp)"; trap 'rm -f "$findings"' EXIT
check_line() {  # file lineno text
  local kind; kind=$(kind_of "$1")
  [ "$kind" = skip ] && return
  local re="$ledger_re"; [ "$kind" = tracker ] && re="$tracker_re"
  printf '%s' "$3" | grep -qE "$re" || printf '  %s:%s\n' "$1" "$2" >> "$findings"
}

if [ "${1:-}" = "--staged" ]; then
  # Added lines only, with their new line numbers, from a zero-context diff.
  file=""; n=0
  while IFS= read -r line; do
    case "$line" in
      # git ends the header with a tab when the path holds a space — and the tracker's
      # default path does (reports/bugs reports/).
      "+++ b/"*) file="${line#+++ b/}"; file="${file%$'\t'}" ;;
      "@@ "*) n=$(printf '%s' "$line" | sed -E 's/^@@ -[0-9,]+ \+([0-9]+).*/\1/'); n=$((n - 1)) ;;
      "+**Status:**"*) n=$((n + 1)); check_line "$file" "$n" "${line#+}" ;;
      "+"*) n=$((n + 1)) ;;
    esac
  done < <(git diff --cached -U0 --no-color -- 'ledger/' '*BUG_TRACKER.md')
else
  while IFS= read -r -d '' f; do
    rel="${f#./}"
    [ "$(kind_of "$rel")" = skip ] && continue
    grep -n '^\*\*Status:\*\*' "$f" | while IFS=: read -r ln text; do check_line "$rel" "$ln" "$text"; done
  done < <(find . \( -path ./node_modules -o -path ./.git \) -prune -o \( -path './ledger/*.md' -o -name BUG_TRACKER.md \) -type f -print0)
fi

[ -s "$findings" ] || exit 0
count=$(wc -l < "$findings" | tr -d ' ')
echo "$count status lines carry more than a status word — put the explanation on a **Status note:** line below"
echo "  Ledger:  🟡 Open · ✅ Closed · ⏸️ Abandoned"
echo "  Tracker: 🟠 Open · 🟡 Fixed, unverified · 🟢 Fixed, verified · ⚪ Product gap"
head -20 "$findings"
[ "$count" -gt 20 ] && echo "  … and $((count - 20)) more (scripts/check-status-lines.sh lists them all in audit mode)"
exit 1
