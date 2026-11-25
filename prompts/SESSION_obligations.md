---
name: session-obligations
description: Give every project a register of what is owed by a date, synced to Notion where reminders fire.
---

# Session — obligations: deadlines and must-dos, with reminders

**Suggested model:** Opus to design it. Recording and syncing obligations afterwards runs
on Haiku, by the operator's rule (2026-10-31).
**Roadmap row:** `docs/roadmap/phase_01_kit_tests_itself.md`, Phase 06

## The operator's request, verbatim

> we need to improve in one more area, this area is remembering task dead line
> information a must do ... like a reminder, we can use notion to create those
> reminders ... by type task by importance ... we need to be able to manage those
> reminders, so when we get the reminder of something, we attack it fixe it do it ...
> notion is connected via mcp; this must be added as a rule or a task, so every project
> has it own folder and data that must be created at the start of each project like the
> ledger ... this task must not be done by higher or a frontier model, but only with
> models that can record data writing files based on results, so we use delegation.

## The deeper version

Turn the obligations the system already records into **commitments**: each has an
owner, a due date derived from its class, and a checkable "done when". Publish them one
way, keyed by stable id, to a Notion database for triage, with one Notion Calendar event
per due date as the reminder. Working a reminder starts the session that does the work.
The repository stays the source of truth. Recording and sync are delegated to Haiku.

## Pass condition

A fresh install has `obligations/`; `scripts/obligations.sh` derives due dates and open
ledger entries; pre-commit warns on overdue items; `update.sh` seeds the folder in
existing projects; `tests/run.sh` is green. Then, in a real project, the first sync
creates the Notion database and calendar events without duplicates on a second run.
