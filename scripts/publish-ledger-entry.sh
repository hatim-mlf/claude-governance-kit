#!/bin/sh
# Ledger publication verifier — claude-governance-kit.
#
# WHAT IT IS FOR
#   Publish one ledger entry and then prove the exact entry AND its exact status
#   reached every generated place that claims to show it: the week index, the sync
#   log, and the dashboard's ledger catalog. Run it twice per entry — once after
#   reserving it, once after closing it.
#
# WHY IT EXISTS AND THE HOOKS ARE NOT ENOUGH
#   `dashboard-sync.sh` is wired into Claude Code hooks in `.claude/settings.json`.
#   That covers exactly one runtime. A session run from any other agent gets no
#   hook at all, so an entry could be reserved, worked and closed without ever
#   appearing on the dashboard — which is the one place a person looks to see what
#   is in flight. The originating failure: an open entry sat invisible while the
#   work it described was already underway, and nothing anywhere said so.
#
# WHY IT VERIFIES INSTEAD OF JUST SYNCING
#   `dashboard-sync.sh` exits 0 on every path by design — a hook that fails a
#   session end costs the session, which is worse than a missed sync. That makes it
#   the wrong thing to call when you need an answer. This script calls it and then
#   goes and looks, so "published" is a checked claim rather than an assumption.
#
# WHY IT REGENERATES THE WEEK INDEX
#   `ledger/<week>/README.md` is generated, and nothing else in the publication path
#   touches it. When this command replaced the separate `generate-ledger-index.sh`
#   step at closeout, the index quietly stopped being rebuilt and drifted three
#   entries behind while publication kept reporting success. A generated file that
#   only some paths regenerate is a stale file waiting to happen, so publication
#   owns it.
#
# WHY THE INDEX IS CHECKED BY COUNT
#   The index records a first…last span per day and never lists every id, so
#   grepping for the id fails for every entry that is not a day's first or last.
#   The entry count is what staleness actually shows up in: an index that disagrees
#   with the headings present in the week's files has not seen them.
#
# USAGE
#   scripts/publish-ledger-entry.sh YYYY-Www-NN
#   Exit 0 means published and verified. Exit 1 means it is not on the dashboard,
#   whatever the sync said. Exit 2 is a usage error.

set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s YYYY-Www-NN\n' "$0" >&2
    exit 2
fi

entry_id=$1
case "$entry_id" in
    [0-9][0-9][0-9][0-9]-W[0-9][0-9]-[0-9][0-9]) ;;
    *)
        printf 'Invalid ledger id: %s\n' "$entry_id" >&2
        exit 2
        ;;
esac

# Root from this script's own location, for the reason `dashboard-sync.sh` explains
# at length: a configured root goes stale when the repository moves, and its own
# path cannot.
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(dirname -- "$script_directory")

# Paths come from governance.config.json so a project that renamed its dashboard or
# moved its sync log does not need this file edited.
config="$repository_root/governance.config.json"
dashboard_dir="bug-tracker-dashboard/app"
sync_log_path="ledger/SYNC_LOG.tsv"
if [ -f "$config" ]; then
    v=$(sed -n 's/^ *"dir": *"\([^"]*\)".*/\1/p' "$config" | head -n 1)
    [ -n "$v" ] && dashboard_dir="$v"
    v=$(sed -n 's/^ *"syncLog": *"\([^"]*\)".*/\1/p' "$config" | head -n 1)
    [ -n "$v" ] && sync_log_path="$v"
fi

ledger_root="$repository_root/ledger"
sync_log="$repository_root/$sync_log_path"
catalog="$repository_root/$dashboard_dir/src/data/ledgerCatalog.ts"
week=${entry_id%-*}
week_index="$ledger_root/$week/README.md"

# Exactly one, because an id that exists twice is the duplicate-reservation failure
# and publishing either copy would paper over it.
matches=$(grep -R -l "^## $entry_id — " "$ledger_root" --include='*.md' || true)
match_count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$match_count" -ne 1 ]; then
    printf 'Expected exactly one %s ledger entry; found %s.\n' \
        "$entry_id" "$match_count" >&2
    exit 1
fi

# The entry's own text decides its status. Asking the caller would let a closed entry
# be published as open by a typo, which is the state the dashboard would then show.
entry_file=$matches
status=$(awk -v id="$entry_id" '
    $0 ~ "^## " id " — " { inside = 1; next }
    inside && /^## [0-9][0-9][0-9][0-9]-W[0-9][0-9]-[0-9][0-9] — / { exit }
    inside && /^### Closed — / { closed = 1 }
    END { if (closed) print "closed"; else print "open" }
' "$entry_file")

"$script_directory/generate-ledger-index.sh" "$week" >/dev/null
"$script_directory/dashboard-sync.sh" --turn

counted=$(grep -h -c "^## $week-[0-9][0-9] — " "$ledger_root/$week"/[0-9]*.md \
    | awk '{ total += $1 } END { print total + 0 }')
indexed=$(sed -n 's/^\*\*\([0-9][0-9]*\) entries across .*/\1/p' "$week_index")
if [ "${indexed:-none}" != "$counted" ]; then
    printf '%s reports %s entries but %s contains %s.\n' \
        "$week_index" "${indexed:-none}" "$week" "$counted" >&2
    exit 1
fi

tab=$(printf '\t')
if ! grep -q "^${entry_id}${tab}${status}${tab}" "$sync_log"; then
    printf '%s was not published as %s in %s.\n' \
        "$entry_id" "$status" "$sync_log" >&2
    exit 1
fi

# Status, not just presence: an entry closed hours ago that the catalog still calls
# open is the same lie as one that is missing, and harder to notice.
catalog_status=$(awk -v id="$entry_id" '
    $0 ~ "\"id\": \"" id "\"," { found = 1; next }
    found && /"status":/ {
        value = $0
        sub(/^.*"status": "/, "", value)
        sub(/".*$/, "", value)
        print value
        exit
    }
' "$catalog")
if [ "$catalog_status" != "$status" ]; then
    printf '%s was not published as %s in %s (found: %s).\n' \
        "$entry_id" "$status" "$catalog" "${catalog_status:-absent}" >&2
    exit 1
fi

printf 'Published %s (%s) to the governance dashboard.\n' "$entry_id" "$status"
