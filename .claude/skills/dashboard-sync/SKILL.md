---
name: dashboard-sync
description: How the governance dashboard is kept current from the ledger and reports/.
  Read this when the dashboard looks stale, when a report or tracker row does not appear
  on it, when deciding whether something needs a manual sync, when the SessionEnd hook is
  unavailable, or when changing what the dashboard reads. Also triggers for "sync the
  dashboard", "the dashboard is out of date", "why isn't my report showing", "regenerate
  the catalogs". Not for writing a report — that is bug-report, error-report,
  audit-report or session-report.
---

# Dashboard Sync

**You almost never need to do anything.** A `SessionEnd` hook runs the sync automatically
when a session ends, and a `Stop` hook runs a quieter variant after every turn. This skill
exists so the mechanism is legible — to a person, and to any session that has to reason
about it — and so there is a manual fallback when the hook cannot run.

It documents the protocol. It does not perform the sync; the hook does that without
invoking this file.

## What counts as dashboard-relevant

**Any change to a watched source file.** The roots from `governance.config.json`
(`reports`, `ledger`, `docs`, `source`), plus the trackers at the repository root
(`STRUCTURAL_PROBLEMS.md`, `CLAUDE.md` and their neighbours). Writing a report, filing a
bug row, editing a register row or reserving a ledger entry all qualify.

There is no separate "publish" step and nothing to tag by hand beyond the attention flag
below.

**Two independent triggers, either sufficient.** A run happens when the source
fingerprint changed (any watched file's path, size or mtime) OR when a ledger entry
appears in a status the sync log has not seen. The ledger is not the only trigger — that
was tried, and it meant a new report with no ledger change regenerated nothing.

## The ledger fields it reads

| Field | Used for |
|---|---|
| `## <id> — <title>` | the entry's identity and headline |
| `**Reserved:**` · `**Model:**` · `**Session prompt:**` | context columns |
| `### Closed — <timestamp>` | **authoritative** for open vs closed |
| `**Summary:**` · `**Report:**` | what it did, and where the detail lives |
| `**Needs attention:**` | the highlight flag — see below |
| `**Files actually touched:**` | the paths the entry produced |

**Paths are read by a rule, not by a format.** The sync takes backticked tokens from that
block and keeps only those that resolve to a real file under the repository root. So prose
mixed among the paths — "the backup above", "nothing" — is ignored because it is not a
backticked path. **`Not touched:` is skipped entirely**, since reading it as a change list
would invert its meaning. Full spec: `ledger/README.md`.

## The attention flag

```markdown
**Needs attention:** yes — cause narrowed to two candidates; one capture settles it
```

`yes` or `no`, plus a short reason when `yes`. Optional; absent means `no`.

**Set it when you close the entry, never later.** The session that did the work is the
only party with the context, and it has it exactly once. The sync **never decides this
itself** — it only forwards what is already tagged. That separation is deliberate: a
script guessing at significance would be guessing, and the dashboard would highlight
noise.

Reach for `yes` when the entry leaves something a person should look at — a defect found
but not fixed, a verification that could not be run, a decision taken under an assumption,
a claim recorded as unverified. Routine completed work is `no`.

## What the automatic mechanism does, in plain language

The hooks run `scripts/dashboard-sync.sh`, which runs
`bug-tracker-dashboard/app/scripts/sync-dashboard.mjs`, which:

1. Parses every `ledger/YYYY-Www/YYYY-MM-DD.md` into entries — one folder per ISO week,
   one file per day, ids week-scoped.
2. Compares them against `ledger/SYNC_LOG.tsv`, keyed on **entry ID *and* status**.
3. Fingerprints every watched source file — path, size and mtime — and compares that
   against `.sync-state.json` from the last run.
4. **If neither has changed, stops there** — no generator runs, nothing is written.
5. Otherwise regenerates the config, ledger, bug, report and project catalogs, then
   appends one line per published ledger entry to the sync log.

**Why a gate at all, rather than always regenerating.** The project catalog records each
file's mtime, and the files it inventories can include the generated catalogs themselves —
so every run would change its own next input and dirty the working tree on every turn,
forever.

**Why `SYNC_LOG.tsv` is excluded from the fingerprint.** It lives under `ledger/`, which
is watched, and the sync appends to it — including it meant every run invalidated its own
fingerprint and the next run always saw "changed".

The key is the **pair**, not the ID. An entry is reserved in one session and closed in
another; keying on ID alone would mark it synced while still open and never publish the
closing block — the summary, the paths, the attention flag, which is the half that
matters.

**The ledger is never edited to record sync state.** A closed entry is not edited again;
that is the ledger's own discipline. Sync state lives beside it in its own append-only
file, so the ledger stays the record of what happened and the log stays the record of what
has been published.

## Did the hook actually run? — `~/.claude/<projectShortName>-session-end-sync.log`

**Check the log before assuming anything.** One line per session end, whatever happened:

```
2026-08-17T23:23:57Z  ok — nothing new — no generator run.
2026-08-17T23:23:18Z  SKIPPED — no governed repository found (…), so scripts/…never ran.
```

This exists because the sync log alone cannot answer the question. `SYNC_LOG.tsv` only
gains a line when something was genuinely unpublished, so **a run that found nothing and a
run that never happened leave it identical**. The hook log says which it was.

Both hooks run `scripts/dashboard-sync.sh`, and it **never fails the thing that ran it**:
every path exits 0, reports, and stands down. A missed sync costs one `npm run sync`; a
hook that fails a session end costs the session's exit, and a `Stop` hook that exits
non-zero blocks the turn.

**There are two hooks, not one:**

| Hook | When | Argument | Logging |
|---|---|---|---|
| `SessionEnd` | the session ends | none | one line, always, including "nothing new" |
| `Stop` | after every assistant turn | `--turn` | only when something happened, or on a skip or failure |

`Stop` is what makes the dashboard current *during* a session rather than after it —
without it, a session cannot see its own state on the Ledger tab.

**Why `--turn` is quiet on the no-op path.** It runs after every turn. A line per turn
saying "nothing new" would be most of the log, and a log that is mostly noise stops being
read. Skips and failures are still always recorded.

**The one case the log cannot cover.** A session started *outside* the repository (from
`~`, say) never loads the project's `.claude/settings.json` at all, so there is no hook to
run and nothing to write a line. If you work from outside the repository, the dashboard
does not sync and nothing anywhere says so: run `npm run sync` by hand.

## Manual fallback

From `bug-tracker-dashboard/app`:

```bash
npm run sync              # what the hook runs — safe to run any time
```

`.sync-state.json` is a local cache and is gitignored: committing it would let one
machine declare another up to date. Deleting it is harmless — the next run simply has no
previous fingerprint and regenerates once.

Individual generators, if you need one on its own:

```bash
npm run ledger:generate   # ledgerCatalog.ts
npm run bugs:generate     # bugCatalog.ts — the bug tracker + STRUCTURAL_PROBLEMS.md
npm run reports:generate  # reports.ts + reportCatalogStats.ts
npm run project:generate  # projectCatalog.ts
npm run generate          # all of the above, plus config.ts
```

**To see the result:** `npm run dev`, then `http://localhost:5173`. Vite picks the
regenerated `src/data/*.ts` straight up, so regenerating *is* updating — no build step is
involved for local viewing. `npm run build` only matters for the production `dist/`
bundle, which is a separate, lower-frequency action deliberately kept out of the hook.

## Two limits, stated so they are not discovered

**Freshness is per-turn, not live.** The dashboard is current as of the last completed
assistant turn. It never shows anything *wrong*; it shows the last published state.
Mid-turn it can still lag: an entry reserved at the start of a long turn is not published
until that turn finishes. Several days with no session means it sits unchanged until the
next one starts.

**There is no scheduled trigger, and that is a decision rather than a gap.** A cron job
runs independently of any session, which makes it a second writer to the same working
tree — exactly the untracked-concurrent-state problem this whole system exists to prevent.
If continuous freshness is genuinely needed, the shape to reach for is `npm run watch`
inside an active session, not a scheduler outside one.
