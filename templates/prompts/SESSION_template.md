---
name: session-<short_slug>
description: One line — what this session must achieve.
---

# Session — <title>

**Suggested model:** Sonnet | Opus | Haiku — and why, in one clause.
**Roadmap row:** `docs/roadmap/phase_XX_*.md` — §N.N  (if any)
**Ledger:** reserve an entry first (`scripts/next-ledger-id.sh`).

## Step 0 — ground truth

Before any change, read the files this session will touch and confirm the prompt's
picture matches disk. Where it does not, the prompt is wrong, not the disk — record
the deviation and proceed from what is actually there.

## Scope

What this session does, in order. One numbered list. Each step names its files.

## Explicitly not doing

The adjacent work this session must NOT slide into. Named, so a drift is visible.

## Pass condition

The checkable state that ends the session: a command that goes green, a capture that
exists, a number that changed. "Make it work" is not a pass condition.

## Verification

How the pass condition is demonstrated, and what evidence is named in the ledger
entry's `Verified by:` field.
