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

# Project Invariant — new material is placed deliberately, not where the work happens to be

**Before adding anything to the system — a rule, a check, a script, a skill, a section of
prose — go back to the system and decide where it belongs. Name the place and the reason
before writing the content.**

This fires on *adding*, not on editing. Changing a rule that already exists has already had
this decision made for it.

## Why this rule exists

Every piece of this system was placed correctly once. The failure is never the first
placement — it is the fifth, made at the end of a long session by someone who has the
content in their head and just needs somewhere to put it. The nearest open file wins, and
the nearest open file is whatever the session was already editing.

Three failures of this shape occurred in the project this kit was extracted from, all
recoverable and none noticed at the time:

- **A defect written into a session report instead of filed as a row.** `CLAUDE.md`'s
  "Improving the system" section exists because of this: recorded but not filed means no
  status, no index, and rediscovery by accident.
- **A system-flow document left describing the old ledger layout** after the ledger became
  one folder per week and one file per day. The change itself was placed correctly and even
  mirrored; the document that tells an agent where things live was simply not on anyone's
  list. A session trusting it writes its entry to a path that no longer exists, and nothing
  catches that, because the file it creates looks valid.
- **A check written into the working repository when it belonged in the kit** — placed
  where the session happened to be, not where it was needed.

The common shape: **the content was right, the location was defaulted.**

## What the decision actually is

Four questions, in order. The first one that answers decides it.

1. **Does this apply to every task, whatever is touched?**
   → `CLAUDE.md`. Keep it short; this file regrowing into a manual is its own failure.

2. **Does it only matter when a particular kind of file is opened?**
   → a path-scoped rule in `.claude/rules/`, with globs that fire when that file is
   touched, and **the reason it exists kept attached to it**. A rule whose rationale lives
   somewhere else gets deleted by the next person who cannot see why it is there.

3. **Is it a thing to *do*, with steps, invoked by name or by task?**
   → a skill in `.claude/skills/`, recorded in `UPSTREAM.md` per
   [[skills-stay-indexed]].

4. **Is it a claim about how the system is arranged — paths, counts, flows?**
   → the document that already makes that claim, and **every other document that repeats
   it.** This is the question people skip. A fact about layout is usually written down in
   more than one place; changing one copy leaves the others lying with more confidence
   than before, because they now disagree with something.

If none of the four fits, it is content rather than system — a bug row, a report, a roadmap
row — and `CLAUDE.md`'s "Improving the system" section decides it.

## The check that makes this real

**Say the destination out loud before writing the content**, in the session, in one line:

> *"This is a placement decision: it fires only when `scripts/` is touched, so it is a
> path-scoped rule, not a `CLAUDE.md` line."*

That is the whole enforcement. Nothing scans for this and nothing can — the failure is a
judgement not made, and there is no artefact to grep for. What makes a sentence enough is
that it is cheap and it is *early*: stating a destination before the content exists is a
different act from justifying a location after the file is already written, which is what
happens when the question is asked at review time.

## After placing it

Two rules run next, and both are easy to skip in the same moment this one is:

- [[governance-changes-reach-the-kit]] — if it is about how the system works, it is
  mirrored into the kit in the same session.
- If the thing you added changed a **layout or count** that a system-flow document,
  `ledger/README.md`, `dashboard/WORKFLOW.md` or `CLAUDE.md` states, update those in the
  same change. Question 4 above is not finished until they agree.

## When it does not apply

- Editing content that is already in the right place.
- Application code. A new source file goes where the app's own structure puts it; that is a
  code-organisation question, not a system-placement one.
- A one-off note in a report or a ledger entry. Those *are* the place.
