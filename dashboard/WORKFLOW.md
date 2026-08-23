# Dashboard Workflow

## Overview

The dashboard has four generated data flows, all derived from Markdown and files
already in the repository:

- **Ledger catalog** — `generate-ledger-catalog.mjs` parses `ledger/*.md` into one
  row per *entry* (not per file — the ledger's unit is the task, not the week file).
- **Bug catalog** — `generate-bug-catalog.mjs` parses the bug tracker (path from
  `governance.config.json`) and, when present, `STRUCTURAL_PROBLEMS.md` (register
  rows and its `## Lessons` table).
- **Report catalog** — `generate-report-catalog.mjs` indexes `reports/` metadata.
  Full report contents are never embedded.
- **Project catalog** — `generate-project-catalog.mjs` inventories the working
  tree: paths, sizes, line counts, extensions, and Swift symbol metadata when the
  project is Swift. Source bodies and credentials are never embedded.

A fifth generator, `generate-config.mjs`, bridges `governance.config.json` into
`src/data/config.ts` so the static UI can show the project name.

## Canonical layout in a governed project

```text
<project>/                       # git root; holds governance.config.json
├── CLAUDE.md                    # the rules
├── ledger/                      # one ISO-week file per week + SYNC_LOG.tsv
├── reports/
│   ├── bugs reports/BUG_TRACKER.md
│   └── {bugs,errors,audits,sessions,verification}/
├── scripts/                     # hooks and checks
├── .claude/                     # skills, rules, settings.json (hooks)
└── bug-tracker-dashboard/app/   # this dashboard
```

Generators find the git root by walking up to `.git`, then read
`governance.config.json`. Every configured root is validated by a **sentinel**
file, not by existence — a directory of the right name that was recreated empty
must fail loudly, not produce an empty catalog.

## What "synced" means, and what it does not

A `SessionEnd` hook runs the sync when a Claude Code session ends; a `Stop` hook
runs a quieter per-turn variant. The sync publishes only what changed, keyed on
(ledger entry, status) — an entry is published once when reserved and again when
closed, because the closing block is the half that matters.

Two limits, in plain language:

1. **The dashboard is current as of the last session's end — it is not live.** A
   gap of days with no session means it sits unchanged until the next one starts.
2. **The hook is loaded per session start directory.** A session started outside
   the repository runs no sync. The script logs every skip to
   `~/.claude/<projectShortName>-session-end-sync.log`, so a stale dashboard
   always has an explanation on disk.

## Manual fallback

```bash
cd bug-tracker-dashboard/app && npm run sync
```

Idempotent: a second run prints `nothing new — no generator run`.
