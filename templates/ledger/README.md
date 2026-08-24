# Ledger

An append-only execution log. **One folder per ISO week, one file per day inside it:**

```
ledger/
  2026-W34/
    README.md        generated index — do not hand-edit
    2026-08-17.md
    …
    2026-08-23.md
  2026-W35/
```

**Ids stay week-scoped and sequential across the whole week** — `2026-W34-70`, not
`2026-08-23-04`. That is what makes the split safe: a citation names an id, never a path,
so every id cited across the repository survives the layout change untouched. Find an entry
with `grep -rn 2026-W34-70 ledger/` rather than by guessing its day.

**Why days.** A busy week's single file passes several thousand lines within a month — one
file nobody can open, read, or diff usefully. Split by day it stays in the hundreds.

Regenerate a week's index after adding a day:

```bash
scripts/generate-ledger-index.sh            # every week
scripts/generate-ledger-index.sh 2026-W35   # one week
```

Get the week from the machine, not from memory:

```bash
date +"%G-W%V"     # ISO year and ISO week — 2026-W33
```

**The same applies to every timestamp in an entry, and it is the rule most easily
skipped** — `Reserved:` and `### Closed —` are prose fields, so nothing rejects a wrong
one. Read them off the machine too:

```bash
date +"%Y-%m-%d %H:%M %z"     # 2026-08-21 08:20 +0100
```

A fabricated timestamp is worse than a missing one: it reads as evidence.
`scripts/check-ledger-entries.sh` compares an entry's stamps against its neighbours at
commit time and warns on a contradiction.

## What it is for

Other logs record *what changed*, *how to undo a fix*, *which defects are open*, and
*what a session did*. What none of them record is **what was started, when, by which
model, and whether it ever finished**.

That is the ledger. It is the spine the other logs cite instead of re-narrating each
other. It is deliberately thin: if you find yourself writing paragraphs into it, that
content belongs in a report, and the ledger entry should link to the report instead.

## The rule

**Reserve before starting. Close when done.** No task runs without an open entry.

Reserving before the work means the entry records what you *intended*, which is the
only version of that information that survives contact with the work. An entry
written afterwards is a summary, and there is already a place for summaries.

## Reserving an entry

Get the id from the file, never from memory — more than one session can be running at
once:

```bash
scripts/next-ledger-id.sh
```

Append to **today's file** in the current week's folder —
`ledger/$(date +%G-W%V)/$(date +%F).md`, creating it if this is the day's first entry:

```markdown
## YYYY-Www-NN — Fix cursor not advancing after scoped purge

**Reserved:** 2026-08-15 14:02 +01
**Model:** Sonnet 5
**Session prompt:** `prompts/SESSION_<name>.md`   (if any)
**Roadmap row:** `docs/roadmap/phase_08_cloud_sync_account.md` — 8.7  (if any)
**Follows from:** YYYY-Www-NN                                          (if any)

**Expected files:**
- `src/managers/SyncManager.ts`
- `docs/FIX_LOG/D1_cursor_advance.md` (new)

**Status:** 🟡 Open
```

- **ID** — `<ISO year>-W<week>-NN`, sequential within the week, zero-padded, never
  reused. Week-qualified so a citation from another log is unambiguous without a date
  next to it.
- **Model** — the model actually running the session, per `MODEL_DELEGATION.md`.
  If the session prompt suggested one and a different one is running, record what is
  running and note what was suggested. The suggestion is a plan; the ledger is a log.
- **Expected files** — the honest guess at open time. It will not match the closing
  list exactly, and the gap between them is the useful part.

  **The dashboard reads this field.** While an entry is open it is the only file
  information that exists — the closing block has not been written yet — so the
  Ledger view shows it, labelled *expected*. Once the entry closes, both lists are
  known and anything expected but never touched is listed separately. Same contract
  as the closing block: backtick real paths, leave prose unbackticked. Globs are
  ignored; directories are kept.

## Closing an entry

Append a closing block **under that same entry**. Not a new entry, not a new file.

```markdown
**Status:** ✅ Closed

### Closed — 2026-08-15 16:40 +01

**Summary:** One paragraph. What was done, not how.

**Needs attention:** no

**Files actually touched:**
Created: `reports/bugs/2026-08-15_cursor_advance.md`
Modified: `src/managers/SyncManager.ts`
Deleted: nothing

**Verified by:** The scenario run and the capture filename — or "Not verified",
and what would verify it.

**Report:** `reports/sessions/2026-08-15_cursor_advance.md`
```

### `Needs attention:` — set when you close, never later

`yes` or `no`, plus a short reason when `yes`. **Optional; absent means `no`.**

Set it **at the moment you close the entry**, using your own judgment about what you
just did. This is deliberately not a decision anyone makes afterwards, and explicitly not
one the dashboard sync makes — the sync only ever *forwards* what is already tagged. The
session that did the work is the only party that has the context, and it has it exactly
once.

Reach for `yes` when the entry leaves something a person should look at: a defect found
but not fixed, a verification that could not be run, a decision taken under an assumption,
a claim recorded as unverified. Routine completed work is `no`.

### `Files actually touched:` — what the sync can and cannot read

Five prefixes are in use. Four describe files that changed; one does not:

| Prefix | Parsed as touched? |
|---|---|
| `Created:` · `Modified:` · `Deleted:` · `Moved:` | ✅ yes |
| `Not touched:` | ❌ **never** — it is negative space, and reading it as a change list would invert its meaning |

**Backtick every real path, and leave prose unbackticked.** That one rule is what lets
this stay readable prose *and* be machine-readable, with no second field duplicating it:
the sync extracts backticked tokens and keeps only those that resolve to a real file
under the repository root. So `the backup above` and `nothing` are ignored automatically.

Paths are **repository-relative**. Continuation lines are fine; the sync reads the whole
block until the next `**Bold:**` heading.

## Rules that keep it trustworthy

**A task's whole lifecycle lives in the day it was opened in.** A task opened on one day
that finishes on another — or in the following week — is closed in the file where it
started. Do not re-open it in today's file, and do not move it. The closing block's own
`### Closed —` stamp carries the real finish time, so nothing is lost.

**Past weeks are not edited retroactively** — the one exception being closing an
entry that was still open. No fixing typos, no adding forgotten entries, no
adjusting a summary after the fact. A log that gets rewritten is a draft.

**An entry still open at the end of a session says so.** `**Status:** 🟡 Open —
<what remains, and what it is waiting on>`. Ambiguity here is the failure mode: an
entry with no closing block and no note is indistinguishable from one someone forgot.

**Statuses:** 🟡 Open · ✅ Closed · ⏸️ Abandoned (closed with a reason and no work
landed, rather than left dangling).

## How the other logs cite it

Reports written with the `bug-report`, `error-report`, `audit-report`, and
`session-report` skills all carry a `**Ledger:**` line naming the entry they were
produced under.

Nothing gets duplicated into the ledger in return. The ledger points outward; that
is the whole design.
