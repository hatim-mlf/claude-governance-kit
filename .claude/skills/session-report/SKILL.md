---
name: session-report
description: Write the session report for what a working session actually
  did. Use this skill when a session ends, when work is being handed off or paused,
  or when writing up a session's outcome — files touched, decisions made,
  verification performed, what is still open or deferred. Also triggers for:
  "write the session report", "wrap up this session", "session summary", "hand
  this off", "what did we do", "close out the session".
---

# Session Report

## When it is due

The usual trigger is "ending, pausing, or handing off a session". **That event does not fire
in a long thread** — in the project this came from, a session running three days across a
compaction reached ten ledger entries and six closed bugs with no report until it was asked
for.

So there is a second trigger, and it is checked rather than remembered: **an ISO week with
five or more ledger entries wants a session report dated in that week.**
`scripts/check-reports.sh` warns when the current week passes that line without one. Per
week, not per entry — 73 of 106 entries had never been cited by a session report, so a
per-entry rule would fire on almost everything and be ignored.

One report may cover several entries. Cite them all in the header.

## Where it goes

`reports/sessions/YYYY-MM-DD_<short_slug>.md`

If the project keeps a roadmap with per-phase update logs, a session adds **one
line** there — the date, what changed, and a link to the session report — never a
copy of the report. The roadmap tracks where a feature stands; the session report
holds what was done and why.

## The ledger ID is not optional

Every session report names the ledger entry the session ran under
(`ledger/README.md`). The ledger entry was reserved before the work started; the
session report is written when it closes. If there is no ledger ID, the session ran
outside the execution log — say so plainly in the report rather than backfilling an
entry as though it had been reserved up front.

## Required sections

### 1. Header

Date, ledger ID, the session prompt file it executed (if any), the model it ran on,
and the model the prompt suggested — when those two differ, record both. The point
of the suggested-model line in the prompt is to make the choice reviewable, and it
is not reviewable if the report only ever says what was suggested.

### 2. What was done

Prose, grouped by outcome, not a transcript. Someone reading this in three months
wants to know what the session accomplished and why, not the order the tool calls
happened in.

### 3. Files touched

Split **Created** / **Modified** / **Deleted**, with one clause per file saying
what changed in it. This is the list checked against `git status`, so it has to be
complete — including files touched and reverted, which are worth a line saying so.

### 4. Decisions made

Every non-obvious choice, with its reason, and what the alternative was. This is
the section that stops the next session from re-litigating a settled question or
silently reversing it. A decision recorded without its alternative reads as an
inevitability and gets overturned by the next person who sees a different option.

### 5. Verification performed

What was actually run, and what it actually showed:

- A build that compiles is **not** verification that behaviour changed.
- "Fixed, verified" needs named evidence — a capture, a test run, a scenario — and
  the evidence's filename gets named here.
- If nothing was verified, write **"Not verified"** and say what would verify it.

Do not write "verified" for something you reasoned about. The most expensive
pattern a project can have is a fix recorded as done before anyone confirmed it.

### 6. Open / deferred

Anything left unfinished, and for each one: whether it is blocked, deferred by
choice, or simply not reached — those are three different things and only one of
them is a decision. Name where each now lives: a roadmap row, a bug report, an
open ledger entry, or a follow-up session prompt.

### 7. Stop-and-report

If scope was hit mid-session — the prompt's assumptions contradicted what was
found, a change would have exceeded the stated boundaries, or the work turned out
to need a design call rather than execution — this section says what was hit, what
was done instead, and what is still waiting on a decision. **If nothing was hit,
write "None."** An absent section reads as an omission; an explicit "None" is a
statement.

## Template

```markdown
# Session Report — <title>

**Date:** 2026-08-15
**Ledger:** 2026-W33-01
**Session prompt:** `prompts/SESSION_<name>.md`
**Model:** Opus (prompt suggested: Sonnet)

## What was done
## Files touched
### Created
### Modified
### Deleted
## Decisions made
## Verification performed
## Open / deferred
## Stop-and-report
```

## Last step

Close the ledger entry — a closing block appended under the same entry, in the same
weekly file, citing this report. The session is not finished until that entry is
closed or explicitly marked still open.
