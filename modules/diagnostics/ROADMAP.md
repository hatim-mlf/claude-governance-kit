# Diagnostics channel — rows

Written by the governance kit's `install.sh` because this project runs somewhere you cannot
see and has no diagnostics channel yet (`governance.config.json` → `diagnostics.state:
not-yet`, `row` points here). Build these before the first feature ships; each closes with
its proof. When all six are done, set `diagnostics.state` to `implemented` and fill
`diagnostics.parts` with the paths; `scripts/check-diagnostics.sh` then checks they exist.
Rule: `.claude/rules/diagnostics-channel.md`. Starter: `diagnostics/README.md`.

| Row | Part | Status | Proof |
|---|---|---|---|
| D.1 | **intake**: server tables and functions that validate, cap per install and globally, and purge | 📋 Planned | its tests pass on a throwaway database (Supabase: `diagnostics/supabase/test.sh`) |
| D.2 | **devTag**: dev and test builds send `app_version` `dev-…` | 📋 Planned | a unit test on the version the client sends in a dev build |
| D.3 | **contractTest**: every code the client can send is one the server keeps | 📋 Planned | the test fails when a code breaks the pattern or a context key is not allowed |
| D.4 | **featureReports**: `<feature>.started` + outcome codes for the first feature | 📋 Planned | a unit test per path that it records its code; one forced failure seen in the table |
| D.5 | **reader**: a daily digest that reaches the operator | 📋 Planned | one digest received, listing a dev event |
| D.6 | **coverage**: a script counting error sites that report vs. not | 📋 Planned | its first count, saved |
