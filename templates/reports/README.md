# Reports

The single root for **new** reports. One subfolder per report type, each written
with its own skill.

| Folder | Skill | Contents |
|---|---|---|
| `bugs/` | `bug-report` | Defects in app or dashboard behaviour |
| `errors/` | `error-report` | Failed commands, builds, migrations, tool calls |
| `audits/` | `audit-report` | Multi-finding sweeps and reviews |
| `sessions/` | `session-report` | What a working session did |
| `verification/` | — | Raw diagnostic exports and run transcripts |

Naming: `YYYY-MM-DD_<short_slug>.md`. Verification transcripts keep whatever name
the exporting tool produced — the tracker cites them by filename, so renaming them
breaks the citation.

Every report carries a `**Ledger:**` line naming the entry it was produced under.
See `ledger/README.md`.

Paths are relative to the project root — the folder holding `CLAUDE.md`,
`ledger/`, and this `reports/` tree.

## The live bug tracker

`reports/bugs reports/BUG_TRACKER.md` is the live tracker. The dashboard's defect
view is generated from that file specifically. Bug reports written here update
*that* row — not a copy anywhere else.
