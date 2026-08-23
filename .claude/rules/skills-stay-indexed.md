---
paths:
  - "**/.claude/skills/**"
---

# Project Invariant — a skill records where it came from, and the index is generated

**Adding, creating, renaming or removing a skill updates `.claude/skills/UPSTREAM.md` in
the same change.** The catalog is then regenerated, not hand-edited.

## The two halves, and why neither alone is enough

**Provenance** lives in `.claude/skills/UPSTREAM.md`, which is the record for **every**
skill here — not only the imported ones. It has three sections and a skill belongs to
exactly one:

| Section | For | Must record |
|---|---|---|
| *What was taken* | vendored, byte-for-byte from upstream | source repo, commit SHA, date, licence |
| *Forks* | derived from an upstream skill, then rewritten | what it came from and what changed |
| *Written here* | your project's own, no upstream | what it is and when it first appeared |

**The index** is `<dashboard>/scripts/generate-skills-catalog.mjs`, which
reads the skills off disk and cross-references that file. Run it, or let the sync run it;
never write `<dashboard>/src/data/skillsCatalog.ts` by hand.

A skill on disk that `UPSTREAM.md` does not mention comes out as **`unrecorded`**, and the
generator names it in its own output. That is the check: it is not possible to add a skill
quietly, because the next sync says so.

Provenance without an index goes stale silently. An index without provenance tells you a
skill exists but not whether anyone reviewed it. Hence both.

> Originating project's evidence: a hand-kept file-size review row was 1,759 lines out of
> date before anyone checked it. Hand-kept lists lose to generated ones every time.

## Where a new skill may come from

Two repositories are **pre-approved**. Vendor from them freely, recording the commit SHA:

- [`affaan-m/ECC`](https://github.com/affaan-m/ECC)
- [`mattpocock/skills`](https://github.com/mattpocock/skills)

**Anywhere else is allowed, and must record its source and licence before the skill is
used.** This is not bureaucracy: a skill is instructions that run with the same permissions
as the session that reaches it, so an unrecorded one is an unreviewed dependency with write
access to this repository. Writing a skill here from scratch is always fine — record it
under *Written here*.

## Also update, when it applies

- **`CLAUDE.md`** — only if the skill is one a session should be told to reach for. Most are
  not: a skill's own `description` is what makes it fire, and the `CLAUDE.md` pointer is a
  cross-reference for a person skimming the file. Adding every skill there would grow the
  always-resident file for no mechanical gain.
- **A fork stops being vendored the moment you edit it.** Move its row from *What was taken*
  to *Forks* and drop the parity claim. A modified file still labelled byte-for-byte is
  worse than no record at all.

## What this rule does not ask for

It does not ask you to review the skill's contents, test it, or justify it. It asks only
that its origin is written down and the index regenerated. Judging whether a skill is
worth having is a separate decision and belongs to whoever adds it.
