---
paths:
  - "**/.claude/**"
  - "**/scripts/**"
  - "**/CLAUDE.md"
  - "**/docs/SYSTEM_FLOW.md"
  - "**/dashboard/WORKFLOW.md"
  - "**/ledger/README.md"
  - "**/STRUCTURAL_PROBLEMS.md"
---

# Project Invariant — a governance change rests on evidence, then is placed, indexed, mirrored

**First, evidence.** Name what the change rests on, an incident (ledger id, bug, commit) or
a measurement, and its verdict: helped, hurt, no observed effect, or confounded. With
none, change nothing: an unargued change costs context and buys nothing (from harness2).
Lessons take the same form in `STRUCTURAL_PROBLEMS.md`; `scripts/check-lessons.sh` warns.

## 1. Place it — name the destination before writing

Fires on **adding** a rule, check, script, skill or prose, not on editing. First match wins:

1. Every task, whatever is touched → `CLAUDE.md`, kept short.
2. Only when a kind of file is opened → a path-scoped rule here, **reason attached**.
3. A thing to *do*, with steps → a skill (then step 2).
4. A claim about layout, paths or counts → that document **and every one repeating it**.

None fits → content (a bug row, report, roadmap row), not system. Say the destination in
one line before writing; justifying it after the file exists is a different act.

*Why:* the failure is the fifth placement, made late into whatever file was open: a defect
written into a session report instead of a row, a flow document left on the old ledger
layout, a check written into the project instead of the kit.

## 2. Index it — a skill records where it came from

Adding, renaming or removing a skill updates `.claude/skills/UPSTREAM.md` in the same
change: *What was taken* (source, SHA, licence), *Forks*, or *Written here*. The catalog
is generated, never hand-edited, and names any unrecorded skill. Pre-approved sources:
`affaan-m/ECC`, `mattpocock/skills`; anywhere else, record source and licence first.
Editing a vendored skill moves it to *Forks*.

*Why:* a skill runs with the session's permissions; an unrecorded one is an unreviewed
dependency with write access. A hand-kept list once drifted 1,759 lines out of date.

## 3. Mirror it — the change reaches the kit, the same session

A change to how the system works (rule, skill, script, ledger format, generator) is
copied into the kit at `kit.path` in `governance.config.json` (missing: ask the operator),
parameterised, committed and **pushed** to `kit.remote`. Done when the kit's `git status`
is clean and `git log origin/main..HEAD` is empty; a failed push is named in the ledger.

**Do not mirror** project content: invariants naming your types, tables or bugs, or
platform-specific skills. Test: would a project that never saw this app want it? A kit
file kept as the project's own goes in `kit.projectOwned`; `check-kit-drift.sh` warns on
anything else. **Coverage:** ask *what reads this, and did all of it come too?* Grep the
kit for the old shape and expect zero hits.

*Why:* a ledger format change was mirrored in five files and pushed, while four consumers
still read the old path; one would have published an empty week that looked quiet.

## When none of this applies

Editing content already in the right place; application code; a note in a report or a
ledger entry, which are the place.
