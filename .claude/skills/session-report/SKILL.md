---
name: session-report
description: Write the Daftira session report when repository-changing work ends, pauses, or is handed off. Capture outcomes, exact files, decisions, verification evidence, deferred work, and any stop gate. Not for planning a future session; use session-prompt for that.
---

# Daftira Session Report

A session report explains one completed or handed-off unit of work. It is not a
second ledger and must not duplicate decision, risk, roadmap, bug, or curriculum
records. Link to those canonical records instead.

## Before writing

1. Read the commissioning ledger entry and any prompt, roadmap, bug, register, or
   curriculum row it cites.
2. Inspect the current worktree. In a dirty tree, list only files this session actually
   touched; do not claim unrelated changes.
3. Check the verification output rather than reconstructing it from memory.

## Location and name

`reports/sessions/YYYY-MM-DD_<short_slug>.md`

## Required format

```markdown
# Session Report — <title>

**Date:** YYYY-MM-DD
**Ledger:** YYYY-Www-NN
**Session prompt:** `prompts/SESSION_<name>.md` or “Conversation request; no file.”
**Model:** <model actually used>

## What was done

<Outcomes and why they matter; not a tool transcript.>

## Files touched

### Created
- `path` — purpose

### Modified
- `path` — change

### Deleted
- None.

## Decisions made

- <Choice, reason, and rejected alternative. Link `docs/DECISION_LOG.md` if it is a
  durable product/architecture decision.>

## Verification performed

- `<exact command>` — <actual result>

## Open / deferred

- None.  <!-- or classify each as blocked, deliberately deferred, or not reached -->

## Stop-and-report

None.
```

## Rules

- Every report names the ledger entry it closes.
- “Fixed, verified” requires named behavioral evidence. A successful compile is only
  build evidence.
- A new app/dashboard defect gets a bug row and bug report. A new tooling/process
  defect gets a structural register row. Merely mentioning it here does not file it.
- If a roadmap or pipeline record changed state, update that canonical record in its
  existing format and link this report where that format supports links. Do not invent
  a second status convention.
- State explicitly when nothing was deleted, nothing remains open, or no stop gate
  fired; absence is ambiguous.

After writing the report, append the closing block to the original ledger entry and
cite this report. Regenerate the weekly index and dashboard.
