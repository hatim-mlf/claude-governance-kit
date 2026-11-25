# Governance Dashboard

A local Vite/React dashboard that renders what the governance system already knows:
the **ledger** (what was started, when, by which model, and whether it finished),
the **defect registers** (the bug tracker and the project register), the **reports
catalog**, and a **project-file inventory**.

It has no backend and no accounts. Every view is generated from Markdown files in
the repository by the scripts in `app/scripts/`.

## Quick start

```bash
cd bug-tracker-dashboard/app   # or wherever governance.config.json puts it
npm install
npm run sync                   # generates src/data/* from the repository
npm run dev                    # http://localhost:5173
```

`npm run sync` reads `governance.config.json` at the git root, validates every
configured root by sentinel, and fails loudly if one is wrong — a generator that
skips a missing root produces a confidently wrong dashboard instead of an error.

## Commands

| Command | Description |
|---|---|
| `npm run dev` | Start the Vite dev server |
| `npm run build` | Production build |
| `npm run sync` | Regenerate only what changed (what the hooks run) |
| `npm run generate` | Regenerate every catalog unconditionally |
| `npm run watch` | Re-generate when watched sources change |
| `npm run {ledger,reports,project,bugs,config}:generate` | One catalog only |

## How it stays current

A `SessionEnd` hook (and a per-turn `Stop` hook) in `.claude/settings.json` runs
`scripts/dashboard-sync.sh`, which runs `sync-dashboard.mjs`. The sync:

1. regenerates the ledger catalog and compares `(entry id, status)` pairs against
   `ledger/SYNC_LOG.tsv` — append-only, so the ledger itself is never edited to
   record sync state;
2. hashes every watched source file (path + size + mtime) and compares against
   `.sync-state.json`;
3. regenerates catalogs only if something changed, then records both.

If nothing changed it prints `nothing new — no generator run` and exits. The hook
never fails a session end: every failure mode logs one line to
`~/.claude/<projectShortName>-session-end-sync.log` and exits 0.

**The dashboard is current as of the last session's end — it is not live.** It
never shows anything wrong; it shows the last published state.

See `WORKFLOW.md` for the full protocol.
