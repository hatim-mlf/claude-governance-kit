---
name: bug-report
description: Write a bug report for a defect in app or dashboard behaviour.
  Use this skill whenever a defect in how the app or the dashboard
  behaves is found, reproduced, or confirmed — wrong values on screen, a feature
  that silently does nothing, data lost on account switch, a result that
  disagrees with the server, a crash, a regression. Also triggers for: "file a
  bug", "log this bug", "write a bug report", "this is broken", "add this to the
  bug tracker", "record this defect". Not for failed commands, builds, or tool
  calls — that is the error-report skill.
---

# Bug Report

A bug report is about **the app's behaviour being wrong**. If a command, build,
migration, or tool call failed, use `error-report` instead. If you are writing up
a sweep of many findings at once, use `audit-report`.

## Before writing

Reserve or identify the ledger entry this work belongs to (`ledger/README.md`).
Every bug report names its ledger ID. A bug report that cannot name one was
written outside the execution log, which is the thing the ledger exists to prevent.

## Where it goes

- The report file: `reports/bugs/YYYY-MM-DD_<short_slug>.md`
- The tracker row: `reports/bugs reports/BUG_TRACKER.md`

**Both, in the same pass.** The tracker is the file the dashboard's defect view
is generated from; a report written without its tracker row is invisible to every
view that matters, and "I'll add the row after" is how reports go missing. Append
a new `## Bug N — <title>` section using the numbering already in that file, and
use its status vocabulary exactly:

| Status | Bar |
|---|---|
| 🔴 Open / diagnosed | Cause identified with file+line evidence, no fix written |
| ✅ Fixed, unverified | Code changed and builds. A commit SHA. Nobody confirmed behaviour |
| ✅ Fixed, verified | Named evidence exists showing the failure before and the scenario passing after |
| 🔵 Product gap | Behaves as written; what's missing is a decision, not a fix |

Do not invent a fifth state, and do not write "Fixed" without saying which of the
two fixed states it is.

One tracker. If an archived copy of `BUG_TRACKER.md` exists anywhere, do not
update it.

(Paths in this skill are relative to the project root, the folder holding
`CLAUDE.md`, `ledger/`, and `reports/`.)

## Required content

A report missing any of these four is not finished.

### 1. Severity — one of four, no others

🔴 **Blocker** · 🟠 **High** · 🟡 **Medium** · 🟢 **Low**

Blocker means it must not ship. High means it ships broken or gets rejected.
Medium means fix soon after. Low is polish. Pick by consequence, not by how
annoying it was to find.

### 2. Root cause — exact file and line

`src/sync/manager.ts:412-418`, not "somewhere in the sync manager". Read the
file and quote the lines. Every finding cites the source, and you never report a
cause you have not opened the file to confirm.

If you genuinely cannot locate the cause yet, say **"Cause not yet located"** and
record what you ruled out. That is an honest 🔴 Open entry. A plausible guess
written as a cause is worse than no cause, because the next session acts on it.

### 3. Reproduction steps

Numbered, from a known starting state, ending in the observed wrong result.
Name the account, the environment (device, browser, OS), and the build if any of
them matter — some bugs only appear on a second account or after a relaunch.
If it is intermittent, say so and give the hit rate you actually saw.

### 4. Verification plan

What will make this **Fixed, verified** rather than **Fixed, unverified** — the
specific scenario to run and the specific capture or export that proves it. Write
this before the fix exists, so the bar is not set afterwards by whatever happened
to be convenient.

## Template

```markdown
# Bug — <short title>

**Ledger:** 2026-W33-04
**Date:** 2026-08-15
**Severity:** 🟠 High
**Status:** 🔴 Open / diagnosed
**Surface:** app | dashboard
**Tracker row:** BUG_TRACKER.md — Bug 49

## Symptom

What the user sees, in one or two sentences. Observed, not inferred.

## Reproduction

1. …
2. …
3. Observed: … · Expected: …

Environment: <account> · <device / browser + OS version> · <build or commit>
Frequency: every time | ~3 of 5 attempts

## Root cause

**File:** `src/sync/manager.ts:412-418`

```
<the actual lines>
```

Why those lines produce the symptom.

## Fix

What to change, or "Not yet written".

## Verification plan

Scenario to run, and the capture/export filename that will prove it. Until that
file exists and is named here, this stays **Fixed, unverified**.
```

## Closing out

When the fix lands, the changelog and any fix log cite the same ledger ID as this
report. The ledger is the index across all of them; none of them re-narrates the
others.
