---
name: session-gstack_comparison
description: Compare gstack with this kit from raw sources, plan the improvements as rows, and start executing them.
---

# Session — learn from gstack, deepen the kit

**Suggested model:** Opus. Most of the work is judgment: what to take, what to reject, and what counts as proof.
**Roadmap row:** `docs/roadmap/phase_01_kit_tests_itself.md`
**Ledger:** the kit repo has no ledger of its own yet. Record evidence in the commits and in `docs/analysis/gstack-comparison.md`.

## The operator's request, verbatim

> inside this report we have to improve this governance kit, but first i need you to see
> this repos "https://github.com/garrytan/gstack", i need you to analyse both porjects and
> see how can we benefit so we can improve out our, repo. for that I want a deeper version
> of this task, not a bigger one. Before rewriting it: (1) say what a top professional in
> this field would do here that I'm not asking for; (2) name the rawest material they would
> start from instead of what has already been digested for me; (3) name the specific
> methods and tools they would use; (4) say what, other than you or me, would show the
> result is right. then i need you to create plan to execute save the prompt and the phases
> and start executing

## The deeper version (rewritten after answering 1–4)

Treat the kit as a product with an acceptance test that has never been run. Install it
into an empty repository and run its own loop. File what breaks. From gstack, take
**mechanisms** (how a lesson becomes a check), not **features**. Every borrowed mechanism
must be shown to catch a defect this kit has actually had.

## Step 0 — ground truth

Read the source, not the READMEs: gstack's hook scripts, test helpers and budget tests,
and this kit's scripts and installer. Run `install.sh` into a scratch repository. Where a
document disagrees with what runs, what runs is the truth.

## Scope

1. Write `docs/analysis/gstack-comparison.md`: the evidence, the take/reject table, and
   the arbiters.
2. Write `docs/roadmap/phase_01_kit_tests_itself.md`: rows sized to one session, each with
   blockers and verification.
3. Execute the frontier rows, test first.

## Explicitly not doing

- Vendoring any gstack skill wholesale.
- The `.tmpl` generation pipeline, telemetry, paid evals, browser or design tooling.
- Rewriting the kit's prose rules. They stay; this work adds the checks underneath them.

## Pass condition

`tests/run.sh` exits 0 on this branch. Each fixed defect has a test that was shown red
before its fix.

## Verification

The red-then-green output for each row is recorded in its commit message. CI on a clean
runner is the outside arbiter once §1.4 lands.
