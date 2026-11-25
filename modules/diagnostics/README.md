# Diagnostics channel — starter

Installed into a project as `diagnostics/` by the kit's `install.sh` (from
`modules/diagnostics/`). After that it is the project's own: adapt it, the kit never
overwrites it. The rule it serves: `.claude/rules/diagnostics-channel.md`. The check that
reads the project's state: `scripts/check-diagnostics.sh`.

Everything here ran in production in the project this kit came from (an iOS app on
Supabase), except where marked **not yet proven**.

## The six parts, and what here gives you each

| Part (`governance.config.json` → `diagnostics.parts`) | Here | You still write |
|---|---|---|
| `intake` — validates, caps, purges | `supabase/01_diagnostics.sql`, `02_diagnostics_reports.sql`, tested by `supabase/test.sh` | apply them as migrations (enable pg_cron first: the purge schedule is the last line) |
| `devTag` — dev builds told apart | the contract's `devVersionPrefix` (`dev-`) | the client: dev/debug builds send `app_version` as `dev-<version>` |
| `contractTest` — client codes the server keeps | `contract.json` + `check_events.py` | a client test that writes one event per code to a JSON file and runs `check_events.py` on it (or the same checks in the client's language) |
| `featureReports` — typed codes per feature | the event shape and the four outcomes | one list of codes per feature, each path unit-tested |
| `reader` — a digest someone reads | `diagnostics-digest.py` (Supabase CLI, read-only, bounded queries) | schedule it daily and send its one-line summary where you read it |
| `coverage` — what still reports nothing | — | a script counting error sites (`catch`, `except`, error logs) that report vs. not, for your language |

## The wire contract (`contract.json`)

An event: `occurred_at`, `install_id` (random UUID per install, never an account id),
`app_version`, `build`, `os_version`, `device_model`, `category` (`^[a-z_]{1,32}$`),
`code` (`^[a-z0-9_.]{1,64}$`, shaped `<feature>.<event>`), optional `session_id` and
`context`. Context keys come only from the allowed list (`status, attempt, count, phase,
reason, durationMs`), text values 32 characters at most; a new key is a reviewed change.
**Never** location, user content, names, ids or typed text.

Each feature run sends `<feature>.started`, then one of `succeeded`, `nothing_to_do`,
`failed` (with a `reason` code). Crash reports go through `report_crash`; a signed-in
user's own "Send a report" goes through `submit_report` and is the only path that carries
their account and a note, only when they tap Send.

## The digest writes user notes

`diagnostics-digest.py` writes to `reports/diagnostics/` and includes the first 200 characters
of each user's note. The installer gitignores that folder; keep it that way.

## Client rules that matter more than the code

- **Consent**: a setting the user can turn off; off means nothing is kept or sent.
- **Queue, then send**: cap the queue (500) and the daily send (200); never send while the
  app is doing its main job (recording, playback); retry later, drop oldest.
- **The key is public**: the server caps are the only defence. Do not loosen them without
  a calculation (expected users × events per run).

## Backends

- **Supabase**: the SQL here. Proven.
- **Cloudflare (Worker + D1)**: **not yet proven**. The first project to run it writes the
  Worker against `contract.json` and the same SQL tests' cases, then adds it here.
