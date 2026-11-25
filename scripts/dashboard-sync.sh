#!/bin/sh
# Dashboard sync runner — claude-governance-kit. What both hooks in
# `.claude/settings.json` run.
#
#   SessionEnd  → this script with no argument. One log line per session end, always.
#   Stop        → this script with `--turn`, after every assistant turn. Logs only when
#                 something actually happened.
#
# WHY ONE SCRIPT AND NOT TWO
#   The root-resolution below is the whole reason this file exists. Copying it into a
#   second script would mean a future fix to it has to be found twice, and the copy
#   that is missed fails silently. The two hooks differ only in how loudly they
#   report, so that is the only thing the argument changes.
#
# WHY --turn IS QUIET ON THE NO-OP PATH
#   It runs after every turn. A line per turn saying "nothing new" would be most of
#   the log, and a log that is mostly noise stops being read. Skips and failures are
#   still always reported.
#
# WHY THIS IS A SCRIPT AND NOT AN INLINE HOOK COMMAND
#   An inline hook resolves its root from $CLAUDE_PROJECT_DIR, which Claude Code
#   fixes once, when a session starts. If the repository moves afterwards, the
#   variable goes on naming a vacated path, and a `cd` into a vacated path fails
#   with nothing said to anyone: a configured root goes stale, and the step skips
#   in silence rather than breaking visibly.
#
# WHERE THE ROOT COMES FROM
#   This script's own location, walked up one level. It cannot go stale relative to
#   itself: move the repository and the script moves with it. Then it is validated
#   by SENTINEL rather than by existence, because a directory of the right name can
#   be recreated empty by an IDE or a build tool, and an existence check passes on
#   that.
#
# IT NEVER FAILS A SESSION END
#   Every path here exits 0, including the failures. A missed sync costs one manual
#   `npm run sync`, or costs nothing at all, because the sync is keyed on
#   (entry, status) and the next session end catches up. A hook that exits non-zero
#   at session end costs the session's exit. The first is recoverable and the second
#   is not, so this reports and stands down; it never blocks.
#
# WHERE IT SAYS SO
#   ~/.claude/<projectShortName>-session-end-sync.log — one line per session end,
#   whatever happened, including "nothing to do". Deliberately **outside** the
#   repository: the case most worth recording is the one where the repository could
#   not be found, and a log inside a repository you cannot find is not a log.
#   Also to stderr, for whoever is watching a terminal at the time.

set -u

mode="session-end"
[ "${1:-}" = "--turn" ] && mode="turn"

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
repository_root=$(dirname -- "$script_directory")

# Project identity comes from governance.config.json at the repository root.
config="$repository_root/governance.config.json"
short_name="project"
dashboard_dir="bug-tracker-dashboard/app"
if [ -f "$config" ]; then
    v=$(sed -n 's/^ *"projectShortName": *"\([^"]*\)".*/\1/p' "$config" | head -n 1)
    [ -n "$v" ] && short_name="$v"
    v=$(sed -n 's/^ *"dir": *"\([^"]*\)".*/\1/p' "$config" | head -n 1)
    [ -n "$v" ] && dashboard_dir="$v"
fi

log_file="${HOME}/.claude/${short_name}-session-end-sync.log"
sentinel="${dashboard_dir}/scripts/sync-dashboard.mjs"

# Always recorded: skips and failures, in both modes.
say() {
    printf '%s  [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$mode" "$1" >>"$log_file" 2>/dev/null || true
    printf 'dashboard sync: %s\n' "$1" >&2
}

# Routine success. Recorded every time at session end; in turn mode only when the run
# actually did something, so an idle turn leaves no trace.
say_routine() {
    if [ "$mode" = "turn" ] && [ "${2:-}" = "no-op" ]; then
        return 0
    fi
    say "$1"
}

if [ -z "$script_directory" ]; then
    say "SKIPPED — cannot resolve this script's own directory from '$0'. Dashboard NOT synced."
    exit 0
fi

# Sentinel, not existence. A directory of the right name is not the repository.
if [ ! -f "$repository_root/$sentinel" ]; then
    if [ -d "$repository_root" ]; then
        why="the directory exists but has no $sentinel in it"
    else
        why="the directory does not exist"
    fi
    say "SKIPPED — '$repository_root' has no dashboard at $sentinel: $why. Dashboard NOT synced; run 'npm run sync' from $dashboard_dir."
    exit 0
fi

if ! command -v node >/dev/null 2>&1; then
    say "SKIPPED — node is not on PATH for this hook, so the sync could not run. Dashboard NOT synced; run 'npm run sync' from $dashboard_dir."
    exit 0
fi

if ! cd "$repository_root/$dashboard_dir"; then
    say "SKIPPED — cannot enter '$repository_root/$dashboard_dir'. Dashboard NOT synced."
    exit 0
fi

output=$(node scripts/sync-dashboard.mjs 2>&1)
status=$?

# The full generator output is useful once per session; after every turn it is noise.
if [ "$mode" != "turn" ] || [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&2
fi

if [ "$status" -ne 0 ]; then
    say "FAILED — sync-dashboard.mjs exited $status. Dashboard NOT synced; last line: $(printf '%s\n' "$output" | tail -n 1)"
    exit 0
fi

# The script's own summary line is either "nothing new — no generator run" or
# "N ledger entries to publish". Log that rather than re-deriving it here.
summary=$(printf '%s\n' "$output" | grep -m 1 '^Dashboard sync:' | sed 's/^Dashboard sync: //')
[ -n "$summary" ] || summary="ran, but printed no summary line"

case "$summary" in
    'nothing new'*) say_routine "ok — $summary" "no-op" ;;
    *)              say_routine "ok — $summary" ;;
esac
exit 0
