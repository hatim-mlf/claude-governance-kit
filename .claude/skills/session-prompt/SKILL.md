---
name: session-prompt
description: Write the prompt that will run the next GLOOD working session. Use this
  skill whenever the next session is being specified — after a session ends and the
  follow-up needs writing, when a stop-and-report gate has been answered and the
  decision must become work, when a backlog or register row is being picked up, or
  when any file under prompts/ is being created or revised. Also triggers for:
  "write the next session's prompt", "what should the next session do", "turn this
  into a session", "draft the prompt for", "commission this work", "SESSION_*.md",
  "hand this to a new session", "spec out the next session". Not for reporting on a
  session that already ran — that is session-report.
---

# GLOOD Session Prompt

## What this is

**The convention behind the files in `prompts/` — 48 of them, documented nowhere until
ledger `2026-W34-17`.** It is derived from those files, not from a description of them.

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

Start from ~/Documents/GLOOD. Reserve a ledger entry. Read <the live state this
session's decisions depend on>.

## Part 1 — <name>

## Part 2 — <name>

## Verification

- <What must be true to call this done.>
- Close the ledger entry, stating <what the closing block must record>.
```

`## Deliverable` appears in about a quarter of the files, between the parts and
Verification, when what comes out is a document rather than a change. Use it when the
output is the point; skip it when Verification already says what must exist.

---

## When the session is bug work: pull the rows before writing the prompt

**A bug thread starts by reading the tracker, not by opening the file the bug names.** This
is the part that was missing until 2026-08-27, and its absence has cost this project twice:

- **Bug 66** was filed as "a setting cleared to zero is never pushed". Reading the neighbouring
  rows and the code first showed the same twelve settings were written to **two tables** by
  two functions carrying the same defect. Fixing the row as written would have fixed one of
  two copies, and the other would have overwritten it.
- **Bug 70** was filed as "Max HR cannot be cleared". Pulling the read sites first showed
  **three different fallbacks** for the same missing value — 185, 190, and `220 − age` — which
  the row never mentioned and which was half the actual defect.

So before writing the prompt, produce the **related-rows block** and put it in the prompt's
`## Purpose`:

```markdown
## Related rows, pulled 2026-08-27

| Row | Status | Why it is in scope |
|---|---|---|
| Bug 66 | 🔴 Open / diagnosed | the row being worked |
| Bug 69 | ✅ Fixed, verified | its fix is what makes 66's clear reachable |
| Bug 70 | 🔴 Open | same two fields; do **not** fold in — 23 read sites |
| U-27 | open | tests mutate live singletons; this session touches them |

**Out of scope and why:** Bug 23 shares the storage but not the defect.
```

Three rules for that block:

1. **Search the tracker, do not recall it.** `grep` the file for the symptom, the file
   names, and the storage keys — not just the bug number you were given. Bug numbers are
   how work is referred to; they are not how defects cluster.
2. **Say what is deliberately *out* of scope**, with the reason. A row that is adjacent and
   excluded is a decision; a row nobody mentioned is an oversight, and the next session
   cannot tell them apart.
3. **If pulling the rows changes what the session is**, stop and say so before writing the
   prompt. That is the cheap moment to re-scope — `2026-W35-08` had to do it *after*
   starting, and the operator had to intervene.

This replaces the "pre-bug report" as a separate artefact. It is the same idea, put where a
session already begins, so it cannot become a fifth file nobody opens.

## The six things every prompt does, and why each one is there

### 1. `Suggested model:` — the tier, the reason, and the condition that would change it

**The reason and the condition are the load-bearing parts, not the tier.** A tier on its
own is an instruction; a tier with its condition is a decision the running session can
re-make when it sees something the writer could not.

Look at what the corpus actually does:

> *"Opus. This edits `project.pbxproj` — untracked until Phase 1, so there is no git
> undo — and it changes synchronized-folder membership, which leaves no diff."*

> *"Haiku for the discovery checks themselves — mechanical, bounded, low-risk. Escalate
> to Sonnet only if the Bug 49 window check turns up a commit that actually needs a
> judgment call."*

> *"Sonnet. This is a git move plus a re-run of an existing verification, not a new
> design decision — the decision (Option B) is already made below."*

Each names **what kind of work it is** and **what would make it a different kind**. Tiers
themselves are in `MODEL_DELEGATION.md`; do not restate them here.

A session may run on a different model than suggested. That is fine and the ledger
records both — the suggestion is a plan, the ledger is a log.

### 2. `## Purpose` — what the session is *for*

Not a summary of the parts. The parts say what to do; Purpose says why anyone should,
and it is what a session falls back on when a part turns out to be wrong.

### 3. `## Non-goals` — stated, not implied

**The strongest single predictor of a session staying in scope.** Every structural phase
this month named its non-goals, and the ledger entries show the sessions echoing them
back as *"Explicitly not doing:"* before starting.

Name the specific adjacent things, not "don't do anything else": *"Do not touch the iOS
app. Do not fix anything on BACKLOG.md. Do not add a sixth or seventh skill beyond the one
Gap 7 asks for."* A session that knows the exact boundary can work confidently up to it.

Include the pressure-release valve when the scope is uncertain: *"If any part of this
grows past a small, contained change, file it and move on rather than expanding the
session."*

> The older files use `## Out of scope` for the same thing — 25 of them, against 14 using
> `## Non-goals`. **`## Non-goals` is the settled form**: 13 of the last 15 prompts that
> have such a section use it. Do not rename the old ones.

### 4. `## Step 0` — read live state before touching anything

Two fixed instructions, then the reads:

```markdown
Start from ~/Documents/GLOOD. Reserve a ledger entry. Read <specific files>.
```

**Name the files, and say why each is needed** where it is not obvious. The point is not
diligence for its own sake — it is that a prompt is written against the state of the repo
at writing time, and the session runs against the state at running time. Step 0 is where
that gap gets found instead of assumed.

The earliest prompts made this explicit and it is still the best statement of it:

> *"Report back what you find in each — the existing structure, naming conventions… Do
> not assume either file is empty or that it matches any earlier description."*

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

Both were learned expensively on this project. A prompt that gets these right and the
structure wrong is a good prompt; the reverse is not.

### Verification must describe an action, not an argument

> **"The hook exits 0 on three staged states"** is a run.
> **"The fix should work because the loop is equivalent"** is not.

Write verification steps that can only be satisfied by doing something and reporting what
came back. *"Demonstrated with real files"*, *"stated as a count, not an impression"*,
*"confirm from the running app"*, *"state what was observed, not what the code should
do"* — every one of those phrasings is in the corpus, and each closes off the same
failure.

**The failure it closes off:** the most expensive pattern on this project is a fix
recorded as done before anyone confirmed it. `698a4eb` shipped a cursor fix that never
advanced the cursor. The pre-commit hook was dead for 13 hours while reading as correct.
The dashboard's ledger catalog was verified three times by watching the generator write
it, and nothing read the file. **In every case the reasoning was sound and the thing did
not work.**

When something genuinely cannot be verified in-session, say so in the prompt and say what
would verify it, rather than writing a step that will be satisfied by an argument.

### The prompt says where to stop and report rather than decide

**A gate fires when the session hits something that needs a decision only the operator can
make** — usually because proceeding either way produces work that is wrong if the guess
was wrong.

The corpus phrases these one way, and the phrasing carries the whole meaning:

> *"stop and report **rather than merging blind**"*
> *"stop and report **rather than archiving it**"*
> *"stop and report **rather than guessing why**"*
> *"stop **rather than assuming absence**"*

**Always name the wrong action.** "Stop and report if unsure" is not a gate — it has no
trigger and no alternative. "Stop and report rather than archiving it" tells the session
exactly which tempting next step is the one to refuse.

**This month's evidence is one-sided.** The sessions that stopped correctly stopped
because the prompt named the gate: `2026-W33-03` found `.claude/` outside the repository,
stopped, and offered three options — the answer became `2026-W33-04`. `2026-W33-07` hit a
hard dependency and closed as stopped rather than building on it. The sessions that went
wrong were the ones where no gate was named.

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
  number that settled them. `2026-W34-14` closed `U-10` with its reasoning precisely so a
  later prompt could cite it instead of re-litigating it.
- **Not open-ended.** A prompt with no Non-goals and no Verification is a conversation, and
  a conversation does not need a prompt file.
