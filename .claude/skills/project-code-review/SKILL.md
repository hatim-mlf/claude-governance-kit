---
name: project-code-review
description: Review a diff on two independent axes at once — Standards (does it follow
  this repository's documented rules and invariants?) and Spec (does it do what the row
  that commissioned it asked for?) — run as parallel sub-agents so neither contaminates
  the other. Use this skill whenever a change is about to be committed, when the user says
  "review this", "review the diff", "review since <commit>", "check this before I commit",
  or when a session's implementation work is finishing. Not for sweeping the whole project
  for defects — that is a language-specific audit skill's job. Findings from either skill
  are written up with audit-report.
---

# Project Code Review

Two-axis review of the diff between `HEAD` and a fixed point:

- **Standards** — does the code follow this repository's documented rules?
- **Spec** — does the code do what the row, prompt, or ledger entry that commissioned it
  actually asked for?

Both axes run as **parallel sub-agents** so they cannot pollute each other's context, then
this skill reports them side by side.

**Why two.** A change can pass one and fail the other. Code that follows every convention
and implements the wrong thing is Standards pass, Spec fail. Code that does exactly what
the row asked and breaks an invariant is Spec pass, Standards fail. Reported together, one
masks the other — and this project already has the failure that proves it: fixes recorded
as done, correctly formatted, that nobody had checked against the behaviour they claimed
to fix.

## 1. Pin the fixed point

Whatever the operator names — a SHA, `main`, `HEAD~5`, a tag. If they did not name one,
ask; do not guess.

```sh
git rev-parse <fixed-point>          # must resolve
git diff <fixed-point>...HEAD        # three-dot: against the merge-base
git log <fixed-point>..HEAD --oneline
```

Confirm the ref resolves and the diff is non-empty **before** spawning anything. A bad ref
should fail here, not twice inside two sub-agents.

## 2. Find the spec source

In this order, stopping at the first hit:

1. The **ledger entry** for this work — `ledger/<ISO-week>.md`. Its `Roadmap row:` and
   `Session prompt:` fields point at the other two. This is the best source because it
   records what was *intended*, written before the work.
2. The **session prompt** named there, under `prompts/`.
3. The **roadmap row** named there — `docs/roadmap/phase_XX_*.md`, a `§NN.N` row in the
   phase's Feature Table.
4. A tracker row the commits reference — a numbered `Bug NN` in
   `reports/bugs reports/BUG_TRACKER.md`, or a lettered row in `STRUCTURAL_PROBLEMS.md`.

If none exists, ask. If the operator says there is no spec, skip the Spec sub-agent and
say so in the report — **and note it as a finding in itself**, because work with no
commissioning record is exactly what the ledger exists to prevent.

## 3. Assemble the standards sources

Always, in every review:

- `CLAUDE.md` — the four behaviours, the ledger rule, the enforcement tiers.
- **`.claude/rules/*.md`** — the path-scoped invariants. Check each rule's `paths:` globs
  against the changed files and include every rule that matches. **A matching rule is a
  hard violation if broken, not a judgement call**: these exist because each one has
  already been violated once in this repository.
- `FILE_SIZE_REVIEW.md` — if the diff pushes a file past roughly 800 lines and it has no
  row there, that is a finding: it needs one. Never a blocker.

On top of whatever the repository documents, the Standards axis always carries the
**smell baseline** below. Two rules bind it: **the repository overrides** — a documented
rule always wins — and **every smell is a judgement call**, never a hard violation. Skip
anything tooling already enforces.

- **Mysterious Name** — a name that does not reveal what it does or holds. → Rename; if no
  honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape in more than one hunk. → Extract, call both.
- **Feature Envy** — a method reaching into another type's data more than its own. → Move
  it onto the data it envies.
- **Data Clumps** — the same few parameters always travelling together. → Give them a type.
- **Primitive Obsession** — a `String` or `Double` standing in for a domain concept that
  `CONTEXT.md` names. → Give the concept its own small type.
- **Repeated Switches** — the same `switch` on the same type recurring. → Polymorphism, or
  one shared map.
- **Shotgun Surgery** — one logical change forcing scattered edits across the diff. →
  Gather what changes together.
- **Divergent Change** — one file edited for several unrelated reasons. → Split by reason.
- **Speculative Generality** — abstraction the spec did not ask for. → Delete it. This one
  is explicitly a `CLAUDE.md` rule here, so it is a **hard violation**, not a smell.
- **Message Chains** — long `a.b().c().d()` the caller should not depend on. → Hide the walk.
- **Middle Man** — a type that mostly delegates onward. → Cut it out.
- **Refused Bequest** — a conformer ignoring most of what it inherits. → Composition.

## 4. Spawn both sub-agents, in parallel, in one message

Set each sub-agent's model explicitly per `MODEL_DELEGATION.md`; do not let it inherit.

**Standards brief.** Give it the diff command, the commit list, the paths of every
standards source from step 3, **and the smell baseline pasted in full** — it has no other
access to it. Then:

> Report, per file and hunk: (a) every place the diff breaks a documented rule — cite the
> file and the rule; (b) every path-scoped rule in `.claude/rules/` whose globs match a
> changed file, and whether the diff honours it; (c) any baseline smell — name it, quote
> the hunk. Distinguish hard violations from judgement calls: documented rules and matching
> path-scoped invariants are hard, baseline smells never are. Skip anything the compiler or
> `scripts/pre-commit.sh` already catches. Under 400 words.

**Spec brief.** Give it the diff command, the commit list, and the spec's path or contents.
Then:

> Report: (a) requirements the spec asked for that are missing or only partial; (b) behaviour
> in the diff nobody asked for — scope creep, which `CLAUDE.md` treats as a violation, not a
> bonus; (c) requirements that look implemented but where the implementation looks wrong.
> Quote the spec line for each finding. Under 400 words.

## 5. Aggregate

Report under `## Standards` and `## Spec`, verbatim or lightly cleaned. **Do not merge or
rerank across axes** — that is precisely the masking the separation exists to prevent.

End with one line: total findings per axis, and the worst issue *within each axis*. No
single winner across axes.

## 6. Two closing checks

Before declaring the review done, check these by hand — they are cheap and neither
sub-agent is positioned to see them:

- **Does the ledger entry's `Verified by:` claim more than the evidence supports?** A build
  succeeding is not a behaviour verified. This is the single most expensive recurring error
  on this project.
- **Did the change surface a defect that was noted but never filed?** A defect described in
  a commit message, a session report, or a comment has no status and appears in no index.
  It needs a numbered row in `BUG_TRACKER.md` or a lettered row in `STRUCTURAL_PROBLEMS.md`.
  File it now, not at write-up.

Write the findings up with the **audit-report** skill.
