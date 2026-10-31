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

**When a prompt, a row or a skill says "stop and report" on a condition, and it fires:
stop, report, wait.** Not "unless the fix looks obvious". Someone decided in advance that
this call was not the session's to make, and mid-task you are the least placed to
re-judge that. **This applies most to a gate you wrote yourself.** The incident behind
it: a session met its own named stop condition, judged the fix obvious, built it, and
told the operator afterwards. The fix was sound, and that is the point: **the gate asks
who decides, not whether the fix is good.** "It is required" makes it a real fork, not a
non-decision. "I'll mention it at the end" is announcing, not reporting. A gate that was
set too wide gets narrowed by the person who set it.

Stopping costs one message: the finding with its evidence, the options with their costs,
and a recommendation.

## Reporting, Ledger, and Model Selection

- On finding a defect in app or tooling behaviour, use the **bug-report** skill.
- On a failed command, build, migration, or tool call, use the **error-report** skill.
- On writing up any audit or multi-finding sweep, use the **audit-report** skill.
- On ending, pausing, or handing off a session, use the **session-report** skill.
- On anything owed by a date, use the **obligations** skill, delegated to a Haiku
  subagent. Start each session with `scripts/obligations.sh`; overdue items come first.
- On writing the prompt that will run the next session, use the **session-prompt** skill.
- On the dashboard looking stale, or a report not appearing on it, use the
  **dashboard-sync** skill. Routine syncing is automatic in Claude Code — a `SessionEnd`
  hook does it — but hooks cover one runtime and report nothing back, so they are not
  publication evidence. That is why a closed entry is published with the verifier.

**Before starting any task, reserve a ledger entry** in today's file under the current
ISO week's folder — `ledger/$(date +%G-W%V)/$(date +%F).md`, and append its closing block when the task ends. Do not work without
an open entry. Format and rules: `ledger/README.md`.

**One entry per commissioned task, not per step.** A task is what one session prompt,
roadmap row, bug row or user request asks for. The probes, fixes and re-runs inside it
are lines in that entry's closing block. Open a new entry only when the scope changes,
and link it with `Follows from:`.

**Publish when you close.** Run `scripts/publish-ledger-entry.sh <entry-id>` after the
closing block. It regenerates the week index, syncs the dashboard, and proves this exact
id and status reached all three generated views. In Claude Code, the PostToolUse hook
publishes the reservation as soon as it is written, week index included. **In any
runtime without that hook, also run the command right after reserving.** An entry nobody
can see is an entry nobody knew was in flight.

**Get the id from the file, never from memory or from context** — run
`scripts/next-ledger-id.sh` and take what it prints. More than one session can be
running in this repository at once, so the highest id you remember is not necessarily
the highest id there is.

**Check the session prompt's "Suggested model" line before starting.** If there isn't
one: Sonnet for normal work, Opus for judgment calls, Haiku for mechanical work, and
set every subagent's model explicitly rather than letting it inherit. Full rule:
`MODEL_DELEGATION.md`.

## Working discipline

The six skills above record what happened. The seven below decide what to do and prove
it worked:

- **Before a hard bug gets a theory, use the `diagnosing-bugs` skill.** No hypothesis
  until one named command has already been run, output shown, that goes red on *this*
  bug.
- **When a plan is not yet sharp, use the `grilling` skill.** It interviews you in rounds until
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

**One of them governs the governance system itself**, and ships with this kit:
`changing-the-governance-system.md`. A change to a rule, check, script, skill or the
ledger format is **placed** (name the destination before writing it), **indexed** (a
skill records its source in `.claude/skills/UPSTREAM.md`) and **mirrored** (copied into
the kit and pushed in the same session, with every consumer of the old shape updated).

The rest are yours: an invariant about your own types, tables or subsystems belongs
here, and does **not** get mirrored to the kit. The test that separates them is in that
rule's step 3.

## Enforcement

**A rule that nothing checks is a wish. A check that blocks legitimate work gets
bypassed until it means nothing.** `scripts/pre-commit.sh` runs all of these; install
it once per clone with `./scripts/install-hooks.sh`.

| Tier | What | Why this tier |
|---|---|---|
| **Blocked** | Credentials: JWTs, API-token shapes, literals assigned to credential-named symbols. False positives take `// pragma: allowlist-secret` | Never legitimate, and git history is permanent |
| **Warned** | Debug markers (`TODO … REMOVE BEFORE RELEASE`); ledger entries left open from an earlier day, in any week; ledger timestamp anomalies; a new status line carrying more than its status word; a kit-owned file changed beyond the kit | Real work trips these sometimes; a block would be bypassed |
| **Flagged** | Files past ~800 lines. Each gets a resolution in `FILE_SIZE_REVIEW.md`: **Splittable** (a row in the phase file) or **Accepted** (with the reason) | A question, not a violation; there is no line limit |

`--no-verify` bypasses everything, and should be rare enough to be memorable.
