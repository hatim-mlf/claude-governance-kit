# CLAUDE.md

Behavioral guidelines for AI-assisted work on this project, plus the reporting and
ledger protocol that keeps the work auditable. Installed from
[claude-governance-kit](https://github.com/) — adapt the marked sections to the
project.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

---

## 5. A Stop Gate Is Not Yours to Lift

**When a prompt, a row, or a skill says "stop and report" on a condition, and that
condition fires — stop. Report. Wait.** Not "stop unless the fix looks obvious." Not "stop
unless you can see it is contained." The gate exists because someone decided in advance
that this specific call was not the session's to make, and by the time you meet it you are
the least positioned to re-judge that: you are mid-task, you have a plan, and continuing is
cheaper than pausing.

**This applies most to a gate you wrote yourself.** The failure that produced this rule:
a session prompt named a specific collision as a stop condition, the collision happened,
and the session judged the fix obvious, folded it into its plan before starting, and told
the operator only after implementing. The fix was sound and not optional — and that is the
point: **soundness is not the test.** The gate did not ask whether the fix was good, it
asked who decides.

Three specific traps:

- **"It is required, so it is not a decision."** If the work cannot proceed without it, that
  is *more* reason to surface it, not less — it means the gate found a real fork.
- **"I will mention it when I report at the end."** Telling the operator after the code is
  written is not reporting, it is announcing.
- **"The gate was written for something bigger than what happened."** Possibly true. Say so
  and let the operator re-scope it. A gate that turns out too wide gets narrowed by the
  person who set it, not stepped over by the person who met it.

**What stopping actually costs:** one message. Hand back the finding with its evidence, the
options with their costs, and a recommendation. What you want back is a choice.

## Reporting, Ledger, and Model Selection

- On finding a defect in app or tooling behaviour, use the **bug-report** skill.
- On a failed command, build, migration, or tool call, use the **error-report** skill.
- On writing up any audit or multi-finding sweep, use the **audit-report** skill.
- On ending, pausing, or handing off a session, use the **session-report** skill.
- On writing the prompt that will run the next session, use the **session-prompt** skill.
- On the dashboard looking stale, or a report not appearing on it, use the
  **dashboard-sync** skill. Routine syncing is automatic — a `SessionEnd` hook does it.

**Before starting any task, reserve a ledger entry** in today's file under the current
ISO week's folder — `ledger/$(date +%G-W%V)/$(date +%F).md`, and append its closing block when the task ends. Do not work without
an open entry. Format and rules: `ledger/README.md`.

**Get the id from the file, never from memory or from context** — run
`scripts/next-ledger-id.sh` and take what it prints. More than one session can be
running in this repository at once, so the highest id you remember is not necessarily
the highest id there is.

**Check the session prompt's "Suggested model" line before starting.** If there isn't
one: Sonnet for normal work, Opus for judgment calls, Haiku for mechanical work, and
set every subagent's model explicitly rather than letting it inherit. Full rule:
`MODEL_DELEGATION.md`.

## Working discipline

The six skills above record what happened. The five below decide what to do and prove
it worked:

- **Before a hard bug gets a theory, use the `diagnosing-bugs` skill.** No hypothesis
  until one named command has already been run, output shown, that goes red on *this*
  bug.
- **When a plan is not yet sharp, run `/grill-me`.** It interviews you in rounds until
  no branch of the decision is left silently assumed.
- **When designing or judging a module's shape, use the `codebase-design` skill** for
  the vocabulary — module, interface, depth, seam, adapter, leverage, locality.
- **When writing anything an agent reads** — a skill, a path-scoped rule, this file, a
  session prompt — use the `writing-for-agents` skill.
- **Before building a behaviour or fixing a bug, use the `tdd` skill.**
- **Before committing, use the `project-code-review` skill.**
- **When work is too big for one session, use the `to-tickets` skill.**

**Name things from `CONTEXT.md`.** It is the project glossary. Adding or renaming a
domain concept updates it in the same change.

## Improving the system

**A defect in the system itself gets its own row, not a mention.** A numbered row in
the bug tracker when it is app or dashboard behaviour; a lettered row in
`STRUCTURAL_PROBLEMS.md` when it is tooling, layout or process. Written into a session
report, it is **recorded but not filed** — it has no status, appears in no index, and
surfaces again only by accident. File it when you find it, not when you write up.

**The brake: the system is a means, not an end.** Filing a system defect does not mean
stopping to fix it. System work is scheduled deliberately like any other work.

## Project Invariants

Invariants that only matter when a specific kind of file is touched live in
`.claude/rules/`, path-scoped, so they load when that code is opened instead of on
every session. See `.claude/rules/README.md` for how to add one.

**Two of them govern the governance system itself**, and ship with this kit:

- `skills-stay-indexed.md` — a skill records where it came from in
  `.claude/skills/UPSTREAM.md`, and the catalog is generated rather than hand-kept.
  [`affaan-m/ECC`](https://github.com/affaan-m/ECC) and
  [`mattpocock/skills`](https://github.com/mattpocock/skills) are pre-approved sources;
  anywhere else is allowed once its source and licence are recorded. A skill runs with
  the session's permissions, so an unrecorded one is an unreviewed dependency with write
  access to this repository.
- `governance-changes-reach-the-kit.md` — a change to a rule, skill, script or the ledger
  format is mirrored back into the governance kit in the same session, so other projects
  do not inherit a version this one has already moved past.

The rest are yours: an invariant about your own types, tables or subsystems belongs
here, and does **not** get mirrored to the kit. The test that separates them is in
`governance-changes-reach-the-kit.md`.

## Enforcement

**A rule that nothing checks is a wish. A check that blocks legitimate work gets
bypassed until it means nothing.** Every rule below states which of the two it is.

### Blocked — credentials never reach a commit

`scripts/pre-commit.sh` refuses any staged change containing a credential: JWTs,
common API-token shapes, and string literals assigned to credential-named symbols.

This one blocks because a credential in source is never legitimate, and because git
history is permanent — deleting the line later does not remove the key.

Install once per clone: `./scripts/install-hooks.sh`

False positives take `// pragma: allowlist-secret` on the line. `--no-verify` bypasses
everything, and should be rare enough to be memorable.

### Warned — debug scaffolding, and ledger entries left open

`TODO … REMOVE BEFORE RELEASE` and similar markers are reported at commit time and
never blocked. The same tier reports ledger entries reserved on an earlier day that
still have no closing block, and ledger timestamp anomalies
(`scripts/check-ledger-entries.sh`).

### Flagged — file size

**Large files are flagged for review. They are never blocked, and there is no line
limit.** A file past roughly 800 lines is a prompt to ask a question, not a violation.
Each flagged file reaches a resolution recorded in `FILE_SIZE_REVIEW.md`:
**Splittable** (becomes a row in the owning phase file) or **Accepted** (reviewed and
judged irreducible, with the reason written down).
