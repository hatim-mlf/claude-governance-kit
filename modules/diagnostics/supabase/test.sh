#!/usr/bin/env bash
# Run the intake's tests on a throwaway local Postgres (never a project): 01 then 02, each followed
# by its test file. Stand-ins for Supabase's roles, auth.uid() and pg_cron, so the files run
# unchanged. Needs initdb, pg_ctl and psql (Homebrew: postgresql).
#   ./test.sh            # the files beside this script
#   ./test.sh DIR        # a project's adapted copies, same file names
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:-$here}"
for t in initdb pg_ctl psql; do command -v "$t" >/dev/null || { echo "test.sh: needs $t (PostgreSQL client and server)" >&2; exit 2; }; done
dir="$(mktemp -d "${TMPDIR:-/tmp}/diag-pg.XXXXXX")"
port=$(( 55000 + RANDOM % 1000 ))
trap 'pg_ctl -D "$dir/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT
initdb -D "$dir/data" -U postgres --auth=trust >/dev/null
pg_ctl -D "$dir/data" -o "-p $port -k $dir -c listen_addresses=''" -l "$dir/log" start >/dev/null
psql_() { psql -h "$dir" -p "$port" -U postgres -v ON_ERROR_STOP=1 -q "$@"; }
psql_ -d postgres -c "CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN;"
psql_ -d postgres -c "CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$\$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid \$\$; GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role; GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role; ALTER ROLE service_role BYPASSRLS; CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY);"
psql_ -d postgres -c "CREATE SCHEMA cron; CREATE FUNCTION cron.schedule(text, text, text) RETURNS bigint LANGUAGE sql AS 'SELECT 1::bigint';"
psql_ -d postgres -f "$src/01_diagnostics.sql"
psql_ -d postgres -f "$src/01_diagnostics_test.sql"
psql_ -d postgres -f "$src/02_diagnostics_reports.sql"
psql_ -d postgres -f "$src/02_diagnostics_reports_test.sql"
