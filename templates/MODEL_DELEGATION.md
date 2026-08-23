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
