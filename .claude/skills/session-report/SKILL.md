---
name: session-report
description: Write the GLOOD session report for what a working session actually
  did. Use this skill when a session ends, when work is being handed off or paused,
  or when writing up a session's outcome — files touched, decisions made,
  verification performed, what is still open or deferred. Also triggers for:
  "write the session report", "wrap up this session", "session summary", "hand
  this off", "what did we do", "close out the session", and whenever a phase_XX.md
  Update Log entry or a session_*.md file is about to be written.
---

# GLOOD Session Report

## This is not a fifth place to write things down

The project already has session write-ups: the `session_*.md` and `SESSION_*.md`
files at `docs/history/`, and the `## Update Log` sections in
`docs/roadmap/phase_XX_*.md`. This skill does not replace them and
does not add a parallel record. It is **the format those follow**.

- **Going forward**, a session's write-up is a file under `reports/sessions/`,
  in this format.
- **The phase Update Log** gets one line, not a copy: the date, what changed in
  that phase, and a link to the session report. The roadmap tracks feature state;
  the session report holds the narrative. **Format below** — it is documented here
  because this is the file that tells you to write the line.
- **`docs/CHANGE_LOG.md`** keeps doing its own job — the revert index,
  listing every file modified per session. The session report does not duplicate that list's purpose;
  it explains the *why* that the change log deliberately leaves out. Both cite the
  same ledger ID.
- **Existing `session_*.md` files stay where they are.** They are not migrated.

## The `## Update Log` line — format

Every `docs/roadmap/phase_XX_*.md` ends with an `## Update Log` heading. This is the
format of what goes under it, and it is **documentation of an existing convention, not a
new one** — derived from the 20 phase files that have entries (ledger `2026-W34-17`).

### Write this

```markdown
### Session — 2026-08-19 (Bug 42)
**Bug 42 profile-push trigger (✅ Done — applied 2026-08-13, confirmed 2026-08-19)** —
`2026-W34-20`, `reports/sessions/2026-08-19_bug42_profile_push_trigger.md`
```

**That example is real.** It is the entry at the top of
`docs/roadmap/phase_08_cloud_sync_account.md`, and both citations resolve — go and read it
rather than trusting this. The first version of this section used an invented filename that
looked real and pointed at nothing, which is the same trap `ARCHITECTURE.md`'s gap 5 was
about; a worked example that cannot be followed is worse than no example.

One `###` heading, one bold line naming the row and its new status, then the ledger ID
and the report path. **Newest entry goes at the top**, under the heading — that is what
the existing files do, and it is why they read as a stack rather than a queue.

The status marker matches the one now in the phase table's Status column, so the two
cannot disagree: **✅ Done · 📋 Planned · 🐛 Bug · ⏸️ Deferred**.

### Do not write this

**Anything longer.** The temptation is to paste the implementation detail, because it
is fresh and it feels like the roadmap should carry it. It should not: the roadmap
tracks *where a feature stands*, the session report holds *what was done and why*, and
`docs/CHANGE_LOG.md` holds the file list. A phase file that carries all three becomes a
fourth place the same facts can drift.

### The existing entries disagree with this, and that is expected

**Read the existing files as history, not as the template.** All 20 phase files with
entries were written between March and April 2026, before the ledger, the reports tree
and these skills existed. They cannot cite a ledger ID or a session report because
neither existed, so every one of them inlines the full implementation detail instead —
`phase_27` runs to hundreds of lines of it.

Their headings vary too: `### Session A — March 2026`, `### Session — March 2026 (§4.16
…)`, `### Session 26-B — March 2026`, `## Session Notes — March 2026`, and
`**March 2026 — Session D complete**`. The dominant form is
`### Session <label> — <Month Year>`, and the form above is that one with an ISO date
and the two citations added, because the two things it can now point at are the two
things that did not exist when the rest were written.

**Exactly one entry uses the form above** — `phase_08`'s, quoted verbatim at the top of
this section. Every other entry across the 20 phase files predates it. Stated plainly so
nobody reads the historical ones as the template.

## The ledger ID is not optional

Every session report names the ledger entry the session ran under
(`ledger/README.md`). The ledger entry was reserved before the work started; the
session report is written when it closes. If there is no ledger ID, the session ran
outside the execution log — say so plainly in the report rather than backfilling an
entry as though it had been reserved up front.

## When it is due

A session is a piece of **work** — a bug or bug thread, a roadmap row, an audit — not an
interval. It is due when that work reaches a terminal state: the row is closed, the audit is
published, or the thread is handed off.

**A calendar-week trigger was tried on 2026-08-27 and withdrawn the same night.** The
operator called it illogical and was right: a week is an accident of the calendar, and
nothing about Tuesday makes a thread finished. It had been reached for because a week was
the only unit that measured cleanly, which is expedience, not design.

What is checked instead, by `scripts/check-reports.sh` against **staged entries only**:

- every ledger entry declares a `Tracker row:`, `Roadmap row:` or `Session prompt:` — that
  is what makes it a session rather than a note;
- every closed entry's `**Report:**` resolves to a file that exists, or names the row it was
  filed as;
- every `✅ Fixed, verified` bug row has a report file naming its capture.

Staged-only is deliberate. 42 of 107 existing `Report:` lines resolve to nothing; warning
about all of them would be correct and ignored by the second commit. The backlog lives in
`U-31c` (in the project this came from), not in every commit.

One report may cover several entries — this thread's covers ten. Cite them all in the header.

## Where it goes

`reports/sessions/YYYY-MM-DD_<short_slug>.md`

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

What was actually run, and what it actually showed. Use the project's own bar:

- A build that compiles is **not** verification that behaviour changed.
- "Fixed, verified" needs a capture, and the capture's filename gets named here.
- If nothing was verified, write **"Not verified"** and say what would verify it.

Do not write "verified" for something you reasoned about. The most expensive
pattern on this project is a fix recorded as done before anyone confirmed it.

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
**Model:** Opus 5 (prompt suggested: Sonnet 5)

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
