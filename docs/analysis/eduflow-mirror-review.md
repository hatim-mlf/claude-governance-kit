# EduFlow mirror review — 2026-10-31

`./update.sh --collect` on EduFlow sent back 15 kit-owned files whose content the kit has
never had (branch `mirror/eduflow`, `7252ccc`). As for GLOOD, each file's base is the kit
version nearest to EduFlow's copy, and only EduFlow's own delta was read.

## Verdict: not merged yet, and it can't be as it stands

Unlike GLOOD's copies, EduFlow's carry **real engineering**, not just its own names. But they
depend on three modules EduFlow added outside the kit-owned set, which `--collect` did not
bring:

- `scripts/lib/ledger_entry.mjs` (read by `sync-dashboard.mjs` and `generate-ledger-catalog.mjs`)
- `scripts/lib/ledger_timestamps.mjs` (read by `check-ledger-entries.sh` and `generate-ledger-catalog.mjs`)
- `bug-tracker-dashboard/app/scripts/bug-status.mjs` (read by `generate-bug-catalog.mjs`)

Merging the branch as it is would break the ledger checks and the dashboard in every project.

## File by file

| File | EduFlow's delta | What it is | Proposal |
|---|---|---|---|
| `scripts/next-ledger-id.sh` | 105 | **Allocates** an id, not just previews one: an atomic `mkdir` claim under git's common directory, shared by every linked worktree, seeded from every worktree's headings. Claims are never removed. Validates the week argument; duplicate ids are an error | **Take**, after the operator approves the change in meaning (allocate, not preview). Needs a test: two concurrent calls never return the same id |
| `scripts/publish-ledger-entry.sh` | 141 | Strict publication: fails if generation fails, or if the entry's exact content is absent from the latest sync event | **Take with `sync-dashboard.mjs`**: they share the content-hash identity |
| `dashboard/app/scripts/sync-dashboard.mjs` | 187 | Publication keyed by the latest event's status and the entry's content hash; a reservation's identity cannot change once fingerprinted; **one writer**, with a lock a live session's sync never steals | **Take**, with `scripts/lib/ledger_entry.mjs`. Needs a test: a second concurrent sync does not corrupt the catalog |
| `scripts/check-ledger-entries.sh` | 73 | Timestamp checks on real UTC instants through `ledger_timestamps.mjs`: T1 (not in the future) and T3 (reservation order does not go backward as ids rise); missing offsets become findings | **Take**, with `scripts/lib/ledger_timestamps.mjs` |
| `dashboard/app/scripts/generate-ledger-catalog.mjs` | 56 | Uses the two shared libraries; the sync stages the catalog until validation passes | **Take** with the libraries. Keep the kit's `pathAliases` and week-file mapping |
| `dashboard/app/scripts/generate-bug-catalog.mjs` | 12 | Status classifier moved to `bug-status.mjs` | **Take** with `bug-status.mjs`, after checking it against the kit's status-line vocabulary |
| `dashboard/app/scripts/generate-project-catalog.mjs` | 147 | Starts from the kit's current version (`47ac72f`); EduFlow-side changes not yet read line by line | **Read next**; nothing decided |
| `dashboard/app/scripts/project-paths.mjs` | 2 | Small | Read next |
| `scripts/pre-commit.sh` | 77 | A `.env` warning for Flutter, which bundles `.env`: EduFlow-specific | **Keep as EduFlow's own.** The shape (warn on a bundled env file) could become an optional check later |
| `scripts/ledger-sync-guard.sh` | 2 | Small | Read next |
| `.claude/skills/session-prompt/SKILL.md` | 201 | Large rewrite, not yet read | Read next |
| `.claude/skills/session-report/SKILL.md` | 134 | Large rewrite, not yet read | Read next |
| `.claude/skills/dashboard-sync/SKILL.md` | 36 | Describes the strict sync | Take with the sync |
| `.claude/skills/project-code-review/SKILL.md` | 28 | Not yet read | Read next |
| `.claude/skills/to-tickets/SKILL.md` | 14 | Not yet read | Read next |

## What the operator decides

1. **Ledger ids change meaning**, from "preview the next free id" to "claim it". That is safer
   for parallel sessions, but every project's sessions call this script, and an interrupted
   session now burns its id. Approve before it reaches the kit.
2. **Which EduFlow incidents these rest on.** Under the evidence rule, each change needs one: a
   duplicate id from two sessions, a sync that overwrote another, a fabricated timestamp. EduFlow's
   ledger or register should name them; the integration session cites them.

## Next steps

1. Bring the three missing modules to `mirror/eduflow`. `--collect` cannot see them, because
   they are not kit-owned. That `--collect` gap is a kit defect in its own right: it should
   report a collected file's new local imports.
2. Finish reading the files marked "read next".
3. Integrate in slices, each with its own test that is red first: ids (concurrency) →
   timestamps → strict sync and publication → bug-status. CI on both platforms for each.
4. Then EduFlow lists only what stays its own (`pre-commit.sh`, and whatever the skills review
   decides) in `kit.projectOwned`, and `update-all.sh` updates it like the rest.
