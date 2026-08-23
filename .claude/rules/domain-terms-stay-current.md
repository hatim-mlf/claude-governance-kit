---
paths:
  - "**/models/**/*"
  - "**/managers/**/*"
  - "**/store/**/*"
---

# Project Invariant — domain terms stay current

**Introducing or renaming a domain concept updates `CONTEXT.md` in the same change.**

`CONTEXT.md` is the glossary every session, roadmap row, tracker entry and commit
message names things from. It is authoritative by construction: a reader has no way
to tell a current definition from one that drifted months ago. **A stale glossary is
worse than none**, because an absent definition prompts a question and a wrong one
does not.

## When this fires

You are adding, renaming, or materially changing the meaning of a **type, interface,
or store that represents a concept people talk about** — the things `CONTEXT.md`'s
domain-terms table defines. Concretely:

- A new model type that is not a pure helper or a DTO.
- A new singleton or store holding per-user or per-account state.
- Renaming any of them.
- Changing what an existing term covers.

## When it does not

Most changes. Editing the body of an existing type, fixing a bug, adding a private
helper, adding an enum case that carries no new concept. **The test is whether a
person would say a new word out loud to describe what you added.** If the answer is
no, this rule is satisfied by doing nothing.

## What updating means

One line in `CONTEXT.md`'s domain-terms table, in the same commit as the code. Not a
separate docs task — a definition that lands later lands never.
