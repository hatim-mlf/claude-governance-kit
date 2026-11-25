---
name: to-tickets
description: Break a plan, spec, or the current conversation into tracer-bullet rows in a
  roadmap phase file, each sized to one fresh context window and each declaring what blocks
  it. Use this skill when work is too big for one session and needs splitting, when the user
  says "break this down", "split this up", "turn this into rows", "make tickets", or when a
  wide refactor needs sequencing so the build stays green. Not for writing the prompt that
  runs one of the resulting rows — that is session-prompt.
---

# To Tickets

Break a plan, spec, or conversation into **rows**: tracer-bullet vertical slices in a
roadmap phase file, each declaring the rows that block it.

The tracker here is not GitHub or Linear. It is:

| Where | For |
|---|---|
| `docs/roadmap/phase_XX_*.md` Feature Table, `§NN.N` rows | Feature and build work |
| `reports/bugs reports/BUG_TRACKER.md`, numbered | App or dashboard defects |
| `STRUCTURAL_PROBLEMS.md`, lettered | Tooling, layout, process |

Rows written here become sessions via the **session-prompt** skill, one at a time, each
with its own ledger entry.

## 1. Gather context

Work from what is already in the conversation. If the operator passes a reference — a
phase file, a `§` row, a bug number, a path under `prompts/` — read it in full first.

## 2. Explore before slicing

If you have not already read the code this touches, read it. Row titles and bodies must
use `CONTEXT.md` vocabulary, and must respect any `.claude/rules/` invariant whose globs
match the files involved.

Look for prefactoring that would make the real change easy. Make the change easy, then
make the easy change. Prefactoring rows come first and block the rest.

## 3. Draft vertical slices

Each slice:

- Cuts a **narrow but complete** path through every layer it touches — model, store,
  manager, view, test. Vertical, never a horizontal slice of one layer.
- Is **demoable or verifiable on its own**. If you cannot say how you would see it work,
  it is not a slice.
- **Fits in a single fresh context window.** This is the binding constraint on this
  project, not an aspiration: each row becomes a session that starts cold.
- Declares its **blocking edges** — the rows that must finish before it can start. A row
  with no blockers can start immediately.

Say plainly how each row would be verified, and prefer rows whose verification does not
need a manual device run. A row whose only proof is a manual capture cannot be closed by
an agent session, and that is how tracker rows end up "fixed, unverified" forever.

## 4. Wide refactors are the exception

A **wide refactor** is one mechanical change — rename a column, retype a shared symbol —
whose blast radius fans across the codebase, so a single edit breaks hundreds of call
sites and no vertical slice can land green. Do not force it into a tracer bullet.
Sequence it **expand → migrate → contract**:

1. **Expand.** Add the new form beside the old. Nothing breaks. One row.
2. **Migrate.** Move call sites over in batches sized by blast radius — per directory,
   per manager. Each batch is its own row, blocked by the expand. The build stays green
   batch to batch because the old form still exists.
3. **Contract.** Delete the old form once no caller remains. One row, blocked by every
   migrate batch.

Where even a batch cannot stay green alone, keep the sequence but let the batches share a
branch that all block a final integrate-and-verify row. Green is promised only there, and
the sequence must say so.

## 5. Put the breakdown to the operator

Present as a numbered list. Per row: **title**, **blocked by**, **what it delivers**
end-to-end, and **how it would be verified**. Then ask:

- Is the granularity right — too coarse, too fine?
- Are the blocking edges real? Does each row depend only on what genuinely gates it?
- Should any be merged or split further?

Iterate until they approve. Do not write anything into a phase file before that.

## 6. Write the rows

Append to the owning phase file's Feature Table in dependency order, blockers first,
continuing its existing `§NN.N` numbering. Match the table's columns exactly; do not
invent new ones.

| Column | What goes in it |
|---|---|
| ID | `§NN.N`, continuing the phase's sequence |
| Feature | The end-to-end behaviour, from the user's point of view |
| Status | `🔲 Pending` |
| Notes | **Blocked by:** `§NN.N` or `None`. Then how it is verified. Then any decision the grilling settled. |

**Avoid file paths and code snippets in a row.** They go stale fastest and are the first
thing to mislead a session that starts cold. The exception is a snippet that encodes a
decision more precisely than prose can — a state machine, a schema, a type shape. Inline
only the decision-rich part.

Defects go to `BUG_TRACKER.md` or `STRUCTURAL_PROBLEMS.md` instead, in that file's own
format. Do not put a defect in a phase table.

Do not modify a parent row's status. Splitting work does not complete it.

## 7. Hand off

Rows are worked **frontier-first**: any row whose blockers are all done. Each becomes its
own session with its own ledger entry, and context is cleared between them — that is what
sizing each row to one fresh window buys. Write the first one up with the
**session-prompt** skill.
