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

# Project Invariant — a change to the governance system is placed, indexed and mirrored

Three steps, in this order. Each one exists because it was skipped once.

## 1. Place it — name the destination before writing the content

Fires on **adding** a rule, check, script, skill or section of prose, not on editing one.
The first question that answers decides:

1. Applies to every task, whatever is touched? → `CLAUDE.md`, kept short.
2. Matters only when a kind of file is opened? → a path-scoped rule here, **with its
   reason attached**.
3. A thing to *do*, with steps? → a skill (then step 2).
4. A claim about layout, paths or counts? → the document that makes it, **and every
   other document that repeats it**.

None fits → it is content (a bug row, a report, a roadmap row), not system.

Say it in one line before writing: *"This fires only when `scripts/` is touched, so it
is a rule, not a `CLAUDE.md` line."* Stating the destination early is a different act
from justifying it after the file exists.

*Why:* every piece was placed correctly once; the failure is the fifth placement, made
late into whatever file was open. A defect went into a session report instead of a row.
A system-flow document kept describing the old ledger layout. A check was written into
the working repository instead of the kit.

## 2. Index it — a skill records where it came from

Adding, renaming or removing a skill updates `.claude/skills/UPSTREAM.md` in the same
change: *What was taken* (source, SHA, licence), *Forks* (what changed), or *Written
here*. The catalog is generated (`generate-skills-catalog.mjs`), never hand-edited, and
names any skill that has no record. Pre-approved sources: `affaan-m/ECC` and
`mattpocock/skills`. Anywhere else, record the source and licence before use. Editing a
vendored skill moves it to *Forks*.

*Why:* a skill runs with the session's permissions, so an unrecorded one is an
unreviewed dependency with write access. Hand-kept lists drift: one was 1,759 lines out
of date.

## 3. Mirror it — the change reaches the kit, the same session

A change to how the system works (a rule, skill, script, ledger format or generator) is
copied into the kit at `kit.path` in `governance.config.json` (missing: ask the operator,
then add it), parameterised, committed and **pushed** to `kit.remote`. It is done when
the kit's `git status` is clean and `git log origin/main..HEAD` is empty. If the push fails, say so in the ledger entry and name the
waiting commit.

**Do not mirror** your project's own content: invariants naming your types, tables or
bug numbers, or platform-specific audit skills. The test: would a project that has never
seen this app want it? A kit file kept as this project's own version goes in
`kit.projectOwned`. `scripts/check-kit-drift.sh` warns at commit time on anything else.

**Coverage:** before calling a mirror done, ask *what reads this, and did all of it come
too?* Grep the kit for the old shape and expect zero hits.

*Why:* a ledger format change was mirrored with five files and a clean push, while four
consumers (the id helper, the entry checker, the pre-commit hook and the catalog
generator) still read the old path. The generator would have published an empty week
that looked like a quiet one.

## When none of this applies

- Editing content that is already in the right place.
- Application code: it goes where the app's own structure puts it.
- A note in a report or a ledger entry. Those are the place.
