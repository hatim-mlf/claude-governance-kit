---
name: session-prompt
description: Write the prompt that will run the next working session. Use this
  skill whenever the next session is being specified — after a session ends and the
  follow-up needs writing, when a stop-and-report gate has been answered and the
  decision must become work, when a backlog or register row is being picked up, or
  when any file under prompts/ is being created or revised. Also triggers for:
  "write the next session's prompt", "what should the next session do", "turn this
  into a session", "draft the prompt for", "commission this work", "SESSION_*.md",
  "hand this to a new session", "spec out the next session". Not for reporting on a
  session that already ran — that is session-report.
---

# Session Prompt

## What this is

A session prompt is a **commission**, not a task list. It is the one artifact written
before the work, by someone with the whole picture, for someone who will have only the
prompt and the repository. Everything below exists because a prompt that left it out
produced a session that went wrong.

**One prompt, one session, one ledger entry.** Filename `prompts/SESSION_<snake_case>.md`.

## The shape

```markdown
# Session: <what this session is>

Suggested model: <tier>. <Why that tier, and what would change it.>

## Purpose

<What this session is for. Two or three sentences, not a restatement of the parts.>

## Non-goals

<What this session must not do, stated explicitly.>

## Step 0

Reserve a ledger entry (`scripts/next-ledger-id.sh`). Read <the live state this
session's decisions depend on>.

## Part 1 — <name>

## Part 2 — <name>

## Verification

- <What must be true to call this done.>
- Close the ledger entry, stating <what the closing block must record>.
```

Add `## Deliverable` between the parts and Verification when what comes out is a
document rather than a change. Skip it when Verification already says what must exist.

---

## The six things every prompt does, and why each one is there

### 1. `Suggested model:` — the tier, the reason, and the condition that would change it

**The reason and the condition are the load-bearing parts, not the tier.** A tier on its
own is an instruction; a tier with its condition is a decision the running session can
re-make when it sees something the writer could not.

> *"Opus. This edits a generated build file — untracked, so there is no git undo — and
> it changes build membership, which leaves no diff."*

> *"Haiku for the discovery checks — mechanical, bounded, low-risk. Escalate to Sonnet
> only if a finding needs a judgment call."*

Each names **what kind of work it is** and **what would make it a different kind**. Tiers
themselves are in `MODEL_DELEGATION.md`; do not restate them here.

A session may run on a different model than suggested. That is fine and the ledger
records both — the suggestion is a plan, the ledger is a log.

### 2. `## Purpose` — what the session is *for*

Not a summary of the parts. The parts say what to do; Purpose says why anyone should,
and it is what a session falls back on when a part turns out to be wrong.

### 3. `## Non-goals` — stated, not implied

**The strongest single predictor of a session staying in scope.** Name the specific
adjacent things, not "don't do anything else": *"Do not touch the mobile app. Do not
fix anything on the backlog. Do not add tooling beyond the one check this session
commissions."* A session that knows the exact boundary can work confidently up to it.

Include the pressure-release valve when the scope is uncertain: *"If any part of this
grows past a small, contained change, file it and move on rather than expanding the
session."*

### 4. `## Step 0` — read live state before touching anything

**Name the files, and say why each is needed** where it is not obvious. The point is not
diligence for its own sake — it is that a prompt is written against the state of the repo
at writing time, and the session runs against the state at running time. Step 0 is where
that gap gets found instead of assumed.

When the session depends on something a previous session left unresolved, Step 0 is where
that dependency gets checked **first**, with instructions to stop if it has not cleared.

### 5. `## Part N` — the work, numbered

Numbered because they get cited: by the `Suggested model` line (*"Opus for Part 2"*), by
the ledger entry, and by the session report's Open/deferred list. Give each a name, not
just a number.

Order them so that anything read-only comes before anything destructive, and so a session
that stops halfway has still produced something.

### 6. `## Verification` — what must be true to call it done

A checklist, in the imperative, that someone else could run. It ends with the ledger
close and what the closing block must state.

---

## The two properties that matter more than completeness

A prompt that gets these right and the structure wrong is a good prompt; the reverse is not.

### Verification must describe an action, not an argument

> **"The hook exits 0 on three staged states"** is a run.
> **"The fix should work because the loop is equivalent"** is not.

Write verification steps that can only be satisfied by doing something and reporting what
came back — *"demonstrated with real files"*, *"stated as a count, not an impression"*,
*"confirm from the running app"*, *"state what was observed, not what the code should
do"*.

**The failure this closes off:** a fix recorded as done before anyone confirmed it. The
reasoning was sound and the thing did not work — in every case of that pattern, the
verification step could be satisfied by an argument.

When something genuinely cannot be verified in-session, say so in the prompt and say what
would verify it, rather than writing a step that will be satisfied by an argument.

### The prompt says where to stop and report rather than decide

**A gate fires when the session hits something that needs a decision only the operator can
make** — usually because proceeding either way produces work that is wrong if the guess
was wrong. The phrasing carries the whole meaning:

> *"stop and report **rather than merging blind**"*
> *"stop and report **rather than archiving it**"*
> *"stop and report **rather than guessing why**"*

**Always name the wrong action.** "Stop and report if unsure" is not a gate — it has no
trigger and no alternative. "Stop and report rather than archiving it" tells the session
exactly which tempting next step is the one to refuse.

A well-formed gate hands back: **the finding with its evidence, the options with their
costs, and a recommendation.** What it wants back is a choice — not approval to continue.

---

## Writing one

1. **Start from what the last session left.** Its ledger entry's `Needs attention` flag,
   its report's Open/deferred list, and its Stop-and-report section. If that section is
   not `None.`, the decision named in it is probably the next session.
2. **Decide the tier and the condition that would change it** before writing the parts —
   it forces you to name what kind of work this is.
3. **Write Non-goals early**, while the adjacent temptations are still obvious to you.
   They will not be obvious to the session.
4. **Write Verification before the parts if you can.** If you cannot state what would make
   it done, the parts are not specified yet.
5. **Re-read every verification line** and ask: could this be satisfied by an argument? If
   yes, rewrite it as a run.
6. **Ask where a wrong guess would be expensive.** Each answer is a stop-and-report gate,
   and each gate names the wrong action.

## What a prompt is not

- **Not a design document.** If the prompt has to explain an architecture at length, that
  is a decision that has not been made yet, and making it is the session — not a preamble
  to a different one.
- **Not a place to re-derive settled facts.** Cite the ledger entry, register row or bug
  number that settled them.
- **Not open-ended.** A prompt with no Non-goals and no Verification is a conversation, and
  a conversation does not need a prompt file.
