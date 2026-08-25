#!/usr/bin/env bash
#
# Ledger entry check — claude-governance-kit.
#
# WHAT IT IS FOR
#   Ledger timestamps and the `Verified by:` field are prose. Nothing rejects a
#   wrong one, and a fabricated timestamp is worse than a missing one because it
#   reads as evidence and gets cited by other documents. The method: compare an
#   entry's stamps against something real. Three of the four checks here need
#   nothing external, because an entry's own stamps and its neighbours already
#   contradict a fabrication most of the time:
#
#     T1  closed is not in the future
#     T2  closed is not before this entry's own reserved
#     T3  reserved is not before the previous entry's closed
#     V1  a closed entry states how it was verified, and a build alone is not it
#
#   T3 is the one that earns its keep. Reserving and closing happen at different
#   moments, often in different sessions, so a stamp invented for one entry is
#   very likely to collide with a real stamp on a neighbour.
#
# WHY IT WARNS AND NEVER BLOCKS
#   A wrong stamp is worth a nudge and is never worth refusing a commit over —
#   and a gate that blocks legitimate work gets bypassed until it means nothing.
#   The one thing that blocks here is a credential, and it stays that way.
#
# WHY IT DOES NOT PARSE DATES
#   Comparisons are lexical on "YYYY-MM-DD HH:MM", which is correct as long as
#   two stamps share a UTC offset. Mixed offsets are reported rather than
#   compared, because `date -j -f` is macOS-only and `date -d` is GNU-only, and
#   a check that runs on one machine is the failure mode this file exists to
#   avoid. Travel across a timezone is rare; getting it silently wrong is not.
#
# TWO MODES, AND WHY
#   --staged   report only entries this commit adds or edits. This is what the
#              pre-commit hook runs. Relitigating the whole history on every
#              commit would print the same historical findings forever, and a
#              warning you have already decided to ignore trains you to ignore
#              the next one.
#   (default)  report every entry in the week file. This is the audit mode; run
#              it by hand when you want the whole picture.
#
# USAGE
#   scripts/check-ledger-entries.sh [--staged] [week-file]
#   Defaults to the current ISO week. Exit 1 means findings, printed to stdout.
#
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Ledger entry check DID NOT RUN — not inside a git repository."
  exit 1
}

staged_only=0
if [ "${1:-}" = "--staged" ]; then staged_only=1; shift; fi

# A week is a folder of daily files. Concatenate them into one stream so the rest of this
# script is unchanged — entries are week-scoped, so day boundaries do not matter to any
# check here.
week_dir="${1:-${root}/ledger/$(date +%G-W%V)}"

# Fall back to the most recent week rather than going dark at every week boundary: this
# used to require the CURRENT week and stopped running each Monday until someone reserved
# the week's first entry. A check that quietly stops running is the failure this file is
# meant to prevent, not to demonstrate.
if [ ! -d "$week_dir" ]; then
  fallback="$(ls -d "${root}/ledger/"20*-W* 2>/dev/null | sort | tail -1)"
  if [ -n "$fallback" ]; then
    echo "No folder for this ISO week yet — checking the most recent, $(basename "$fallback")."
    week_dir="$fallback"
  fi
fi

week_file="$(mktemp)"; trap 'rm -f "$week_file"' EXIT
[ -d "$week_dir" ] && cat "${week_dir}"/*.md > "$week_file" 2>/dev/null

if [ ! -s "$week_file" ]; then
  echo "Ledger entry check DID NOT RUN — no week folder under ${root}/ledger"
  echo "  A check that quietly stops running is worse than one that never ran."
  exit 1
fi

# In staged mode, the ids worth reporting are the ones this commit touches.
# Anything else in the file is history, and history is the audit mode's job.
touched_ids=""
if [ $staged_only -eq 1 ]; then
  rel="${week_dir#$root/}"   # the folder — a commit may touch any day inside it
  git diff --cached --quiet -- "$rel" 2>/dev/null && exit 0
  # Only ids introduced as an entry HEADING. Matching every id in the added lines
  # picked up ids merely *cited* in prose — a closing block that says "this found
  # conflicts in 2026-W34-16" made the check report entry 16, which this commit did
  # not touch. Citing an entry is not editing it.
  touched_ids="$(git diff --cached -U0 -- "$rel" 2>/dev/null \
    | grep -oE '^\+## [0-9]{4}-W[0-9]{2}-[0-9]{2}' \
    | sed 's/^+## //' | sort -u | tr '\n' ' ')"
  # An edit that adds no heading and no id still belongs to the entry it sits
  # in. Falling back to every id in the file would be noisy; reporting nothing
  # would be silent. Take the last entry in the file, which is where an
  # in-progress closing block always lands.
  if [ -z "$touched_ids" ]; then
    touched_ids="$(grep -oE '^## [0-9]{4}-W[0-9]{2}-[0-9]{2}' "$week_file" | tail -1 | sed 's/^## //')"
  fi
fi

# Duplicate ids. Scanned across the WHOLE week file, never limited to the entries this
# commit touched — a collision by definition involves an entry someone else wrote, so a
# --staged-scoped check would miss exactly the case it exists for.
#
# This check is the reason next-ledger-id.sh exists. Two sessions appended to the same
# week file believing they held the same free id; the second append destroyed the first
# entry, and nothing noticed until the work it recorded was looked for and was not there.
# The allocator makes the collision unlikely; this makes it visible when the allocator
# was not used.
duplicate_ids="$(
  grep -oE '^## [0-9]{4}-W[0-9]{2}-[0-9]+' "$week_file" \
    | sed 's|^## ||' | sort | uniq -d
)"

now_stamp="$(date +'%Y-%m-%d %H:%M')"
now_offset="$(date +'%z')"

findings="$(
  awk -v now="$now_stamp" -v now_off="$now_offset" -v only="$touched_ids" '
    function stamp(line,   s) {
      # "**Reserved:** 2026-08-22 16:12 +0100" -> "2026-08-22 16:12"
      if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}/))
        return substr(line, RSTART, RLENGTH)
      return ""
    }
    function offset(line) {
      if (match(line, /[-+][0-9]{2}:?[0-9]{2}[ ]*$/)) {
        s = substr(line, RSTART, RLENGTH); gsub(/[ :]/, "", s); return s
      }
      return ""
    }
    function report(id, msg) {
      # In staged mode `only` is a space-separated allowlist of ids.
      if (only != "" && index(" " only " ", " " id " ") == 0) return
      print "  " id ": " msg; found = 1
    }

    function flush(   ) {
      if (id == "") return

      # T2 — closed before its own reserved
      if (closed != "" && reserved != "" && r_off == c_off && closed < reserved)
        report(id, "closed " closed " is BEFORE its own reserved " reserved)

      # T1 — closed in the future
      if (closed != "" && c_off == now_off && closed > now)
        report(id, "closed " closed " is in the FUTURE (now " now ")")

      # T3 — reserved before the previous entry closed
      if (reserved != "" && prev_closed != "" && r_off == prev_c_off && reserved < prev_closed)
        report(id, "reserved " reserved " is BEFORE " prev_id " closed " prev_closed)

      # mixed offsets: report, never compare
      if (reserved != "" && closed != "" && r_off != "" && c_off != "" && r_off != c_off)
        report(id, "reserved and closed carry different UTC offsets (" r_off " vs " c_off ") — not compared")

      # V1 — a closed entry must say how it was verified
      if (status_closed) {
        if (!has_verified)
          report(id, "closed with NO \"Verified by:\" field")
        else if (verified_weak)
          report(id, "\"Verified by:\" cites only a build or a compile — a build succeeding is not a verification")
      }

      if (closed != "") { prev_closed = closed; prev_c_off = c_off; prev_id = id }
    }

    /^## / {
      flush()
      id = substr($0, 4); sub(/ .*/, "", id)
      reserved = ""; closed = ""; r_off = ""; c_off = ""
      status_closed = 0; has_verified = 0; verified_weak = 0; in_verified = 0
      next
    }
    /^\*\*Reserved:\*\*/  { reserved = stamp($0); r_off = offset($0); in_verified = 0; next }
    /^### Closed —/       { closed   = stamp($0); c_off = offset($0); in_verified = 0; next }
    /^\*\*Status:\*\*/    { if ($0 ~ /Closed/) status_closed = 1; in_verified = 0; next }

    /^\*\*Verified by:\*\*/ {
      has_verified = 1; in_verified = 1
      body = $0
      if (body ~ /[Nn]ot verified/) { verified_weak = 0; in_verified = 0; next }
      # A build or a compile, with nothing else named alongside it.
      if (body ~ /[Bb]uild|[Cc]ompile/ &&
          body !~ /test|Test|capture|scenario|\.md|\.swift|\.py|\.ts|\.png|\.mov|\.json|diff|`/)
        verified_weak = 1
      next
    }
    in_verified && /^\*\*/ { in_verified = 0 }
    in_verified {
      # continuation lines can supply the evidence the first line lacked
      if ($0 ~ /test|Test|capture|scenario|\.md|\.swift|\.py|\.ts|\.png|\.mov|\.json|diff|`/) verified_weak = 0
    }

    END { flush(); exit (found ? 1 : 0) }
  ' "$week_file"
)"
status=$?

duplicate_report=""
if [ -n "$duplicate_ids" ]; then
  duplicate_report="$(printf '  %s: id used more than once in this week file\n' $duplicate_ids)"
fi

if [ -n "$findings" ] || [ -n "$duplicate_report" ]; then
  echo "Ledger entries need a look — $(basename "$week_dir")"
  [ -n "$duplicate_report" ] && echo "$duplicate_report"
  [ -n "$findings" ] && echo "$findings"
  echo
  if [ -n "$duplicate_report" ]; then
    echo "  Get the next free id before reserving, never from memory:"
    echo "    scripts/next-ledger-id.sh"
    echo "  Ids are never reused — see ledger/README.md."
  fi
  if [ -n "$findings" ]; then
    echo "  Read stamps off the machine, never from session context:"
    echo "    date +\"%Y-%m-%d %H:%M %z\""
    echo "  A fabricated timestamp reads as evidence."
  fi
  exit 1
fi

exit "$status"
