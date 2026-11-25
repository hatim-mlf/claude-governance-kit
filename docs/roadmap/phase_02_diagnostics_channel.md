# Phase 02 — every governed project has a built-in diagnostics channel

A project that runs where the operator cannot see it (an app on people's devices, a public
website, a server or worker) reports its problems to its own server, and every feature reports
through it. Rule: `.claude/rules/diagnostics-channel.md`. Evidence it rests on: in the project
this kit came from, a tester's failed import reached the team only by chat while 74 of 106
error-log sites sent nothing; the rule then lived only in `templates/CLAUDE.md`, which
`update.sh` never delivers, so 0 of 4 other governed projects had it (measured 2026-11-25).

## Feature Table

| ID | Feature | Status | Notes |
|---|---|---|---|
| §2.1 | The rule travels as a kit-owned file, and each project's channel is a **state** a commit check reads | ✅ Done | **Blocked by:** None. `.claude/rules/diagnostics-channel.md` (delivered by `update.sh`, shown: a project missing it gets it added), `governance.config.json` → `diagnostics` (schema), `scripts/check-diagnostics.sh` (warns at commit, never blocks; a decided state is quiet), `templates/CLAUDE.md` paragraph cut to the rule and pointers. Verified by `tests/test_diagnostics.sh` cases 1–4. |
| §2.2 | A fresh install is never silent about diagnostics | ✅ Done | **Blocked by:** §2.1. `install.sh` asks where the project runs and which server; local-only → `not-applicable` with its reason, otherwise `not-yet` with `diagnostics/` (starter) and `docs/roadmap/diagnostics_channel.md` (six rows). An existing `diagnostics/` is never touched. Verified by `tests/test_diagnostics.sh` cases 1, 5, 6; `tests/test_install.sh`. |
| §2.3 | Supabase intake template, taken from the reference project's production schema | ✅ Done | **Blocked by:** None. `modules/diagnostics/supabase/`: events + crashes (per-install and global caps, 90-day purge) and user reports (signed-in only, 180 days, removed with the account), names removed. `test.sh` runs both test files on a throwaway Postgres: both pass; goes red when the per-install cap is loosened. Verified by `tests/test_diagnostics.sh` case 8. |
| §2.4 | One wire contract, language-neutral | ✅ Done | **Blocked by:** None. `contract.json` + `check_events.py`; a client test writes one event per code and runs it. Verified by `tests/test_diagnostics.sh` case 7. |
| §2.5 | Cloudflare Worker + D1 intake | 🔲 Pending | **Blocked by:** None. Built first in the reference project's website (its own row), against `contract.json` and the same cases as the SQL tests, then brought here. Not shipped as a template before it has run. |
| §2.6 | Coverage measure for Python and TypeScript | 🔲 Pending | **Blocked by:** the first governed project in that language reaching row D.6. The reference script counts Swift error sites only. |
| §2.7 | Every governed project prints a state | ✅ Done | **Blocked by:** None. 2026-11-25: each project's pending work committed first (update.sh refuses over it), then `update.sh` to `4c9084d` and the state set as the operator decided: the reference app implemented 6 of 6; two projects not-yet with Cloudflare, one not-yet with its own PostgreSQL (hosting must stay in-country), each with the starter and six rows; the research harness not-applicable. Pass met: 5 of 5 print a state (0 of 5 before). Found on the way: the archived research harness's dashboard sync fails because its configured source folder no longer exists; not caused by this change. |
| §2.8 | Held out: the next project built under the kit ships its first feature with codes | 🔲 Pending | **Blocked by:** that project starting. Pass: its first feature records its codes in unit tests and one dev event is seen in its intake before its first real user. |

## Update Log

### Session — 2026-11-25 (§2.7)
**§2.7 (✅ Done)** — 5 of 5 governed projects print a diagnostics state.

### Session — 2026-11-25 (§2.1–§2.4)
**§2.1–§2.4 (✅ Done)** — from the reference project's ledger entry `2026-W48-37`.
