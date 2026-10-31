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
#     T1  reserved and closed are not in the future
#     T2  closed is not before this entry's own reserved
#     T3  reservation order does not move backward as ids increase
#     V1  a closed entry states how it was verified, and a build alone is not it
#
#   T3 compares reservation stamps, not a reservation against the previous close.
#   Sessions may overlap; overlap is not an error. A later id appearing to have been
#   reserved before an earlier id is the contradiction worth surfacing.
#
# WHY IT WARNS AND NEVER BLOCKS
#   A wrong stamp is worth a nudge and is never worth refusing a commit over —
#   and a gate that blocks legitimate work gets bypassed until it means nothing.
#   The one thing that blocks here is a credential, and it stays that way.
#
# DATES AND OFFSETS
#   scripts/lib/ledger_timestamps.mjs validates and compares UTC instants for both
#   this checker and the dashboard. Node is already required by publication.
#   Missing/invalid offsets produce visible findings rather than disabling checks.
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
    | grep -oE '^\+## [0-9]{4}-W[0-9]{2}-[0-9]{2,}' \
    | sed 's/^+## //' | sort -u | tr '\n' ' ')"
  # An edit that adds no heading and no id still belongs to the entry it sits
  # in. Falling back to every id in the file would be noisy; reporting nothing
  # would be silent. Take the last entry in the file, which is where an
  # in-progress closing block always lands.
  if [ -z "$touched_ids" ]; then
    touched_ids="$(grep -oE '^## [0-9]{4}-W[0-9]{2}-[0-9]{2,}' "$week_file" | tail -1 | sed 's/^## //')"
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

now_stamp="$(date +'%Y-%m-%d %H:%M %z')"

timestamp_findings="$(node "${root}/scripts/lib/ledger_timestamps.mjs" "$week_file" "$touched_ids" "$now_stamp")"
timestamp_status=$?
if [ "$timestamp_status" -ne 0 ]; then
  echo "Ledger timestamp check DID NOT RUN — helper failed (exit ${timestamp_status})."
  [ -n "$timestamp_findings" ] && echo "$timestamp_findings"
  exit 1
fi

findings="$(
  awk -v only="$touched_ids" '
    function report(id, msg) {
      # In staged mode `only` is a space-separated allowlist of ids.
      if (only != "" && index(" " only " ", " " id " ") == 0) return
      print "  " id ": " msg; found = 1
    }

    function flush(   ) {
      if (id == "") return

      # V1 — a closed entry must say how it was verified
      if (status_closed) {
        if (!has_verified)
          report(id, "closed with NO \"Verified by:\" field")
        else if (verified_weak)
          report(id, "\"Verified by:\" cites only a build or a compile — a build succeeding is not a verification")
      }
    }

    /^## / {
      flush()
      id = substr($0, 4); sub(/ .*/, "", id)
      status_closed = 0; has_verified = 0; verified_weak = 0; in_verified = 0
      next
    }
    /^\*\*Reserved:\*\*/  { in_verified = 0; next }
    /^### Closed —/       { in_verified = 0; next }
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
if [ "$status" -gt 1 ]; then
  echo "Ledger verification check DID NOT RUN — awk failed (exit ${status})."
  exit 1
fi
findings="${timestamp_findings}${timestamp_findings:+${findings:+$'\n'}}${findings}"

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
