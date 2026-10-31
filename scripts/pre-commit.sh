#!/usr/bin/env bash
#
# Pre-commit hook — claude-governance-kit
#
# Three checks, deliberately different in severity:
#
#   SECRETS  — BLOCKS the commit. A credential in source is never legitimate,
#              and once it reaches git history it is there permanently even
#              after the line is deleted. This is the one thing worth refusing.
#
#   DEBUG    — WARNS only. Debug scaffolding is legitimate mid-development;
#              it is only wrong at release. The hard gate for it belongs in
#              the pre-release checklist, not here.
#
#   LEDGER   — WARNS only. A ledger entry reserved on an earlier day and never
#              closed is either stalled work or a forgotten closing block.
#              Worth a nudge, never worth refusing a commit over. If the
#              ledger cannot be found at all, that is reported too — a check
#              that quietly stops running is worse than one that never ran.
#
# There is NO file-size check. Large files are flagged for review through the
# dashboard's Project Inventory and resolved per CLAUDE.md — a big file is a
# prompt to ask a question, not a defect, and must never block work.
#
# Escapes:
#   git commit --no-verify          skip every check once
#   // pragma: allowlist-secret     mark one line as a known false positive
#
set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
if [ ! -t 1 ]; then RED=""; YEL=""; GRN=""; DIM=""; OFF=""; fi

fail=0

# Staged, non-deleted files only. Never scans history or the working tree.
#
# Filled with a read loop rather than `mapfile`, which is a bash 4 builtin.
# macOS ships bash 3.2, so `mapfile` would leave this hook dead on every Mac:
# it aborts under `set -u` and returns 1, which git reads as a refused commit.
# A gate that fails for a reason unrelated to what it checks is the exact
# failure the Enforcement section of CLAUDE.md warns about.
staged=()
while IFS= read -r line; do
  [ -n "$line" ] && staged+=("$line")
done < <(git diff --cached --name-only --diff-filter=ACMR)
[ ${#staged[@]} -eq 0 ] && exit 0

# ---------------------------------------------------------------- exclusions
# Template/example files exist precisely to show the shape of a credential,
# and docs quote keys when explaining an incident. Neither is a leak.
is_excluded() {
  case "$1" in
    *.example|*.example.*|*.sample|*.template)      return 0 ;;
    *.md|*.txt|*.lock|*.png|*.jpg|*.jpeg|*.pdf)     return 0 ;;
    */Fixtures/*|*/fixtures/*|*Tests/Resources/*)   return 0 ;;
    *node_modules/*|*/dist/*)                       return 0 ;;
    reports/*|*/reports/*|FIX_LOG/*)                return 0 ;;
  esac
  return 1
}

# Machine-generated files whose CONTENT is quoted prose from the ledger and the
# reports. They are excluded from the DEBUG scan only, never from the secrets scan
# — a generated file is still a file, and the secrets check stays as wide as it is.
#
# Why this exists: a ledger entry recording a test of this very check quoted the
# marker it was testing, the generator copied that prose into the ledger catalog,
# and the debug scan then matched its own test fixture on every commit. A warning
# that fires on a known false positive forever is a warning that gets ignored.
#
# This script itself is excluded for the same reason: the debug scan would match
# this file's own pattern table, flagging the check for checking.
#
# Note the second-order case, found the same way: this comment must DESCRIBE the
# marker rather than spell it, or the hook flags the fix for the flagging.
is_generated() {
  case "$1" in
    */src/data/*.ts)          return 0 ;;
    scripts/pre-commit.sh)    return 0 ;;
  esac
  return 1
}

# ------------------------------------------------------------------- secrets
# Patterns are anchored to things that are actually credentials, not to the
# word "key". A property called apiKeyHeader is not a finding.
#
#   eyJ…            JWT — every Supabase anon/service key starts this way.
#   sb_… / sbp_…    Supabase personal/project access tokens.
#   sk-ant-…        Anthropic API keys. Their own pattern because the segments are
#                   hyphen-separated (sk-ant-api03-…), so the generic sk- rule below
#                   — whose character class stops at the first hyphen — never sees
#                   them. Found by testing this hook against a real key shape: it
#                   passed the commit. A secrets gate shipped with a Claude kit that
#                   misses Claude's own credential is the worst false negative here.
#   sk-… / ghp_…    OpenAI and GitHub tokens, in case they ever appear.
#   assignment      a *literal* string assigned to a credential-named symbol.
#                   Reading from config or a keychain never matches.
secret_patterns=(
  '\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}'
  '\bsbp?_[A-Za-z0-9]{20,}'
  '\bsk-ant-[A-Za-z0-9_-]{20,}'
  '\bsk-[A-Za-z0-9]{20,}'
  '\bgh[pousr]_[A-Za-z0-9]{20,}'
  '(anonKey|apiKey|api_key|secretKey|serviceRole|service_role|accessToken|password|passwd)[[:space:]]*[:=][[:space:]]*"[^"]{12,}"'
)

echo "${DIM}pre-commit: scanning ${#staged[@]} staged file(s)${OFF}"

for file in "${staged[@]}"; do
  is_excluded "$file" && continue
  [ -f "$file" ] || continue

  # Only added lines. Existing code is not this hook's business — it would
  # fire on every unrelated commit and train you to bypass it.
  added=$(git diff --cached -U0 -- "$file" | grep '^+' | grep -v '^+++' || true)
  [ -z "$added" ] && continue

  # Honour the inline allowlist before matching.
  added=$(echo "$added" | grep -v 'pragma:[[:space:]]*allowlist-secret' || true)
  [ -z "$added" ] && continue

  # Collect across all patterns first, then dedupe — a line that matches both
  # the JWT shape and the assignment shape is one finding, not two.
  hits=""
  for pat in "${secret_patterns[@]}"; do
    m=$(echo "$added" | grep -nE "$pat" || true)
    [ -n "$m" ] && hits="${hits}${m}"$'\n'
  done
  hits=$(echo "$hits" | grep -v '^$' | sort -t: -k1,1n -u || true)

  if [ -n "$hits" ]; then
    if [ $fail -eq 0 ]; then
      echo
      echo "${RED}COMMIT REFUSED — credential in staged changes${OFF}"
      echo
    fi
    fail=1
    echo "  ${RED}${file}${OFF}"
    # Show the shape, never the value. Printing the key into a terminal
    # log would defeat the point of catching it.
    while IFS= read -r line; do
      masked=$(echo "$line" | sed -E 's/[A-Za-z0-9_.-]{18,}/[REDACTED]/g' | cut -c1-100)
      echo "    ${DIM}${masked}${OFF}"
    done <<< "$hits"
  fi
done

if [ $fail -eq 1 ]; then
  cat <<EOF

  ${YEL}Move it out before committing:${OFF}
    1. Put the value in an environment variable or a gitignored config file
    2. Read it at runtime through your platform's secrets mechanism
    3. For user tokens use the platform keychain — never plain storage

  ${DIM}False positive?  add  // pragma: allowlist-secret  to that line${OFF}
  ${DIM}Genuinely need to bypass?  git commit --no-verify${OFF}

  ${DIM}Deleting the line in a later commit does not remove it from history.${OFF}

EOF
  exit 1
fi

# --------------------------------------------------------------------- debug
# Warn, never block. The release gate for these lives in the pre-publish
# checklist, where "is this shippable" is the actual question being asked.
debug_patterns=(
  'TODO.{0,30}(REMOVE|DELETE).{0,30}(RELEASE|APP[ _]?STORE|SHIP|PROD)'
  'FIXME.{0,30}(RELEASE|APP[ _]?STORE|SHIP|PROD)'
  'HACK.{0,30}(RELEASE|APP[ _]?STORE|SHIP)'
)

warned=0
for file in "${staged[@]}"; do
  is_excluded "$file" && continue
  is_generated "$file" && continue
  [ -f "$file" ] || continue

  added=$(git diff --cached -U0 -- "$file" | grep '^+' | grep -v '^+++' || true)
  [ -z "$added" ] && continue

  for pat in "${debug_patterns[@]}"; do
    hits=$(echo "$added" | grep -nEi "$pat" || true)
    if [ -n "$hits" ]; then
      if [ $warned -eq 0 ]; then
        echo
        echo "${YEL}Heads up — debug scaffolding in this commit${OFF}"
        echo "${DIM}Committing anyway. Clear these before the next release build.${OFF}"
        echo
      fi
      warned=1
      echo "  ${YEL}${file}${OFF}"
      echo "$hits" | while IFS= read -r line; do
        echo "    ${DIM}$(echo "$line" | sed 's/^+//' | cut -c1-100)${OFF}"
      done
    fi
  done
done

# -------------------------------------------------------------------- ledger
# Warn, never block — and warn when it CANNOT run, which is the whole point of
# the shape below. The root is resolved from git, so the check survives a change
# to the repository's nesting depth. A broken path becomes a visible warning
# rather than a check that silently stops running.
ledger_dir="$(git rev-parse --show-toplevel)/ledger"
week_dir="${ledger_dir}/$(date +%G-W%V)"
# Fall back to the most recent week that holds entries rather than going dark at every
# week boundary. Same lookup as check-ledger-entries.sh — keep the two in step: folders
# only (a retired week FILE is not a week), and an empty folder is "no entries yet".
has_entries() { compgen -G "$1/*.md" > /dev/null; }
if [ ! -d "$week_dir" ] || ! has_entries "$week_dir"; then
  week_dir=""
  for d in $(ls -d "${ledger_dir}/"20*-W*/ 2>/dev/null | sort -r); do
    has_entries "${d%/}" && { week_dir="${d%/}"; break; }
  done
fi
week_file="$(mktemp)"; trap 'rm -f "$week_file"' EXIT
[ -n "$week_dir" ] && [ -d "$week_dir" ] && cat "${week_dir}"/*.md > "$week_file" 2>/dev/null

if [ -d "$ledger_dir" ] && [ -z "$week_dir" ]; then
  : # A ledger with no entries yet is a project that has not reserved one. Nothing to check.
elif [ ! -d "$ledger_dir" ]; then
  echo
  echo "${YEL}Ledger check DID NOT RUN — no ledger directory${OFF}"
  echo "${DIM}  looked for: ${ledger_dir}${OFF}"
  echo "${DIM}  Open entries are not being checked. If the layout moved, fix the"
  echo "  path in scripts/pre-commit.sh rather than leaving this quiet.${OFF}"
  warned=1
elif [ ! -s "$week_file" ]; then
  echo
  echo "${YEL}Ledger check DID NOT RUN — no week folder under ledger/${OFF}"
  echo "${DIM}  looked for: ${ledger_dir}/$(date +%G-W%V)/ and any earlier 20*-W* folder${OFF}"
  warned=1
else
  # Every week, not just the current one. GLOOD's audit found 26 entries open or
  # status-less for more than two days, none of them warned about: the check read only
  # this week, and an entry with no status line and no `### Closed` block was never
  # counted as open. An entry nobody closed is open, whatever its status line says.
  stale=$(cat "${ledger_dir}"/20*-W*/*.md 2>/dev/null | awk -v today="$(date +%Y-%m-%d)" '
    function flush() {
      if (id != "" && !closed && (open || !has_status) && reserved != "" && reserved < today)
        print "  " id "  (reserved " reserved ")"
    }
    /^## [0-9]{4}-W[0-9]{2}-[0-9]+/ { flush(); split(substr($0, 4), w, " "); id = w[1]
                                      reserved = ""; open = 0; has_status = 0; closed = 0; next }
    /^## /                { flush(); id = ""; next }
    /^\*\*Reserved:\*\*/    { if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/))
                              reserved = substr($0, RSTART, RLENGTH); next }
    /^\*\*Status:\*\*/      { has_status = 1; open = ($0 ~ /Open/) ? 1 : 0
                              if ($0 ~ /Closed|Abandoned/) closed = 1; next }
    /^### Closed/         { closed = 1; next }
    END                   { flush() }
  ' || true)

  if [ -n "$stale" ]; then
    n=$(printf '%s\n' "$stale" | wc -l | tr -d ' ')
    echo
    echo "${YEL}Heads up — $n ledger entries left open from an earlier day${OFF}"
    echo "${DIM}ledger/ (every week) — close them, or abandon them with a Status note saying why.${OFF}"
    echo
    echo "${YEL}$(printf '%s\n' "$stale" | head -10)${OFF}"
    [ "$n" -gt 10 ] && echo "${DIM}  … and $((n - 10)) more${OFF}"
    warned=1
  fi
fi

# ------------------------------------------------------------- ledger stamps
# Warn, never block. Ledger timestamps are prose fields that nothing else
# checks, and a fabricated one reads as evidence — it gets cited by other
# documents as though it were a fact.
#
# --staged so it reports only the entries this commit touches. History is the
# audit mode's job (`scripts/check-ledger-entries.sh` with no arguments).
# Repeating findings you have already decided not to act on is how a warning
# stops being read.
ledger_entry_check="$(git rev-parse --show-toplevel)/scripts/check-ledger-entries.sh"
if [ -x "$ledger_entry_check" ]; then
  if ! entry_output=$("$ledger_entry_check" --staged 2>&1); then
    echo
    echo "${YEL}${entry_output}${OFF}"
    warned=1
  fi
else
  echo
  echo "${YEL}Ledger entry check DID NOT RUN — scripts/check-ledger-entries.sh missing or not executable${OFF}"
  echo "${DIM}  A check that quietly stops running is worse than one that never ran.${OFF}"
  warned=1
fi

# ------------------------------------------------------------ stale blockers
# Warn, never block. A row that says it is blocked on a register row which has since been
# RESOLVED is blocked on nothing, and nobody finds out until a session happens to look.
# Closed rows are exempt: their narrative may name a blocker they once had.
blockers_check="$(git rev-parse --show-toplevel)/scripts/check-stale-blockers.sh"
if [ -x "$blockers_check" ]; then
  if ! blockers_output=$("$blockers_check" 2>&1); then
    echo
    echo "${YEL}${blockers_output}${OFF}"
    warned=1
  fi
else
  echo
  echo "${YEL}Stale-blocker check DID NOT RUN — scripts/check-stale-blockers.sh missing or not executable${OFF}"
  warned=1
fi

# ------------------------------------------------------------------- reports
# Warn, never block. The "every bug row gets a report file" rule was followed
# 11 times in 73 rows in the project this came from, because nothing checked
# it; and the session-report skill triggers on a session *ending*, which a
# thread running days across a compaction never does. Both checks are
# deliberately narrow — the wider versions measured 50 and 73 findings and
# would have been bypassed on the first commit.
reports_check="$(git rev-parse --show-toplevel)/scripts/check-reports.sh"
if [ -x "$reports_check" ]; then
  if reports_output=$("$reports_check" 2>&1) && [ -n "$reports_output" ]; then
    echo "${YEL}${reports_output}${OFF}"
    warned=1
  fi
else
  # From the originating project's copy: every other check says when it did not run,
  # and this one skipped in silence.
  echo
  echo "${YEL}Reports check DID NOT RUN — scripts/check-reports.sh missing or not executable${OFF}"
  warned=1
fi

# -------------------------------------------------------------- status lines
# Warn, never block. A status line holds one vocabulary word; prose goes on a
# `**Status note:**` line. Only lines this commit adds are checked. The project this came
# from reached over 100 distinct tracker statuses, and fixed-versus-verified stopped being
# countable.
status_check="$(git rev-parse --show-toplevel)/scripts/check-status-lines.sh"
if [ -x "$status_check" ]; then
  if ! status_output=$("$status_check" --staged 2>&1); then
    echo
    echo "${YEL}${status_output}${OFF}"
    warned=1
  fi
else
  echo
  echo "${YEL}Status-line check DID NOT RUN — scripts/check-status-lines.sh missing or not executable${OFF}"
  warned=1
fi

# --------------------------------------------------------------- obligations
# Warn, never block. Something owed is past its due date (obligations/README.md). A due
# date nobody is reminded of is not a deadline; this is the reminder the repo can give
# without Notion.
obligations_check="$(git rev-parse --show-toplevel)/scripts/obligations.sh"
if [ -x "$obligations_check" ]; then
  if ! obligations_output=$("$obligations_check" --check 2>&1); then
    echo
    echo "${YEL}${obligations_output}${OFF}"
    warned=1
  fi
else
  echo
  echo "${YEL}Obligations check DID NOT RUN — scripts/obligations.sh missing or not executable${OFF}"
  warned=1
fi

# ----------------------------------------------------------------- kit drift
# Warn, never block. A kit-owned file changed beyond anything the kit has is a change
# that has not been mirrored (changing-the-governance-system.md, step 3). In the project
# this came from, 22 such files built up unnoticed.
drift_check="$(git rev-parse --show-toplevel)/scripts/check-kit-drift.sh"
if [ -x "$drift_check" ]; then
  drift_output=$("$drift_check" 2>&1); drift_rc=$?
  if [ $drift_rc -ne 0 ]; then
    echo
    echo "${YEL}${drift_output}${OFF}"
    warned=1
  elif [ -n "$drift_output" ]; then
    echo "${DIM}${drift_output}${OFF}"
  fi
else
  echo
  echo "${YEL}Kit drift check DID NOT RUN — scripts/check-kit-drift.sh missing or not executable${OFF}"
  warned=1
fi

# ------------------------------------------------------------------ optional
# Project-specific checks (e.g. a database-migration drift check) are opt-in:
# drop an executable at scripts/check-extra.sh and it runs here, warning only.
extra_check="$(git rev-parse --show-toplevel)/scripts/check-extra.sh"
if [ -x "$extra_check" ]; then
  if ! extra_output=$("$extra_check" 2>&1); then
    echo
    echo "${YEL}${extra_output}${OFF}"
    warned=1
  fi
fi

[ $warned -eq 1 ] && echo
echo "${GRN}pre-commit: no credentials found${OFF}"
exit 0
