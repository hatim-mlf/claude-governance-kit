---
name: session-control_audit
description: Audit every control in the kit for measured cost and evidenced value, then cut, merge or keep each one.
---

# Session — control audit: cost, quality, value

**Suggested model:** Opus. Deciding what to cut is a judgment call; the measuring is mechanical.
**Roadmap row:** `docs/roadmap/phase_01_kit_tests_itself.md`, Phase 05
**Ledger:** the kit repo has no ledger of its own. Evidence goes in the commits and in `docs/analysis/control-register.md`.

## The operator's request, verbatim

> how can we improve our repo without gstack, i need to make sure if there is anything
> good to us to our project / governance kit to be a cost and quality system architecture
> efficiency and value, I want a deeper version of this task, not a bigger one.

## The deeper version

Audit the kit as a set of **controls**. A control is any rule, check, hook, skill or
`CLAUDE.md` section that costs a session something in exchange for preventing a failure.
For each control, prove two things from real data, not from the template:

- it prevents a failure that **actually happened**, and
- it does so at a cost that was **actually measured** from the API's own token counts in
  real session transcripts.

Cut or merge any control that can't show both. Then cap the always-loaded text and set
three outcome measures, so the kit stays lean and its value stays visible.

## Step 0 — ground truth

The data comes from GLOOD, the project the kit was extracted from, which exists only on
the operator's Mac. It is measured **read-only**, by a session running there. That
session returns counts and timings only: no code, no bug text, no transcript content.
Brief: `AUDIT RESULT v1`, sections A–G (governance text, ledger, tracker, reports, git,
transcripts, hook logs).

## Scope

1. Collect `AUDIT RESULT v1` from GLOOD.
2. Write `docs/analysis/control-register.md`. One row per control: the failure it
   prevents → evidence it fired → cost (bytes, tokens, tool calls) → keep, merge or cut.
3. Define three outcome measures and compute their baselines: evidence rate (closed
   entries with `Verified by:`), verification lag (fixed → verified), and ceremony share
   (governance tool calls as a percent of all tool calls).
4. Turn the measurement into `scripts/governance-audit.sh`, so every governed project can
   audit itself.
5. Make the cuts and merges as separate commits, each one revertible.
6. Add a size cap on always-loaded text, enforced by a test.

## Explicitly not doing

- Writing anything into GLOOD. The audit there is read-only.
- Adding new controls before the cuts are decided.
- Copying GLOOD content into the kit. Only counts come across.

## Pass condition

Every control in the register has either firing evidence and a measured cost, or a cut
or merge decision. The always-loaded byte count is lower than the baseline, or each byte
of growth has a recorded reason. `tests/run.sh` is green.

## Verification

- The API's token counts from the transcripts, not estimates.
- The cap test.
- The second project's operator (row §4.1) reports which controls they kept and which
  they bypassed.
