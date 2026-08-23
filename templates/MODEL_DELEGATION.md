# Model Delegation

Which Claude model runs a given task, so cost scales with the difficulty of the
work instead of everything defaulting to one tier.

The choice is made per session, in the session prompt, not once globally.

## The four rules

**1. Sonnet is the default for a normal session.**

Implementing a planned change, fixing a diagnosed bug, writing a report, updating
the tracker, following a session prompt that already says what to do. Most work
is this.

**2. Escalate to Opus for judgment calls.**

Architecture decisions, ambiguous debugging where the symptom does not point at a
cause, and anything where **a wrong-but-plausible answer is expensive to catch
later**. If the honest response to being unsure is to stop and ask rather than to
pick, the task was never cheap enough to run on a cheap tier.

**3. Haiku for mechanical, bounded, low-risk work.**

File inventories, grep sweeps across the tree, formatting a ledger entry, counting
lines, listing what exists. Work where the answer is *found* rather than *decided* —
where being wrong shows up immediately as a wrong file list rather than quietly as a
wrong conclusion.

**4. Set a subagent's model explicitly.**

`model: sonnet` · `model: opus` · `model: haiku` · `model: inherit`

Do not leave every subagent inheriting the main session's tier by default. A
session running on Opus for one hard design call does not need its file-inventory
subagent on Opus too. `inherit` is a valid answer — but a chosen one, written down.

## The suggested-model line

Every session prompt starts with a **Suggested model** line, stating the tier and the
condition that would change it:

```markdown
Suggested model: Sonnet 5 for the whole session. Escalate to Opus 5 only if Step 0
turns up a real conflict that needs a design call rather than a mechanical
extension — stop and report it instead of guessing.
```

The point of putting it in the prompt is that the choice is made **once, in the planning
conversation**, rather than re-decided at the top of every session by whoever happens to
start it.

Two things follow:

- **The escalation condition is part of the line.** "Sonnet" alone tells the next session
  nothing about when to disagree with it.
- **The ledger records the model that actually ran**, not the one suggested. When they
  differ, both are recorded. A suggestion nobody checks against reality stops being a
  decision and becomes decoration.

`prompts/SESSION_template.md` carries the field, and the `session-prompt` skill explains
how to write it.

## Agent Teams — deferred, not rejected

Claude Code has an experimental, off-by-default Agent Teams feature where teammates share
a task list and message each other directly, rather than a worker receiving a task
description and nothing else. That is worth recording: "no shared context between
workers" is no longer a hard platform limitation.

It is still not worth enabling, for a reason specific to rules 1–3 above: **as of 2026-08
every teammate in a team runs the same model tier — there is no per-role model
selection** — which is in direct conflict with the point of tiering by complexity. A team
also multiplies token cost roughly 3–4× per teammate before any work happens. Revisit
once per-teammate model selection ships.

Until then, do not reintroduce any form of multi-agent delegation beyond this note
without a separate, explicit decision.
