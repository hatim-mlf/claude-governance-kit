---
name: session-prompt
description: Write a Daftira prompt that commissions one future working session. Use when creating or revising prompts/SESSION_*.md, turning a decision or tracker row into work, or handing a bounded follow-up to a fresh session. Not for reporting work already done.
---

# Daftira Session Prompt

A session prompt is a commission for one bounded unit of work, sized to a fresh
context window. Filename: `prompts/SESSION_<snake_case>.md`.

## Required shape

```markdown
# Session: <outcome>

Suggested model: <tier and why>. Escalate when <specific condition>.

## Purpose
<Why this work matters and the canonical row it advances.>

## Non-goals
- <Adjacent work this session must not absorb.>

## Step 0 — orient and reserve
Resolve the repository root with `git rev-parse --show-toplevel`. Read `CLAUDE.md`,
`AGENTS.md`, `docs/WORKFLOW.md`, and <specific live records>. Inspect `git status`.
Reserve a ledger entry before changing files.

## Part 1 — <bounded part>
## Part 2 — <bounded part>

## Stop-and-report gates
- If <observable condition>, stop and report rather than <tempting unauthorized action>.

## Verification
- <Exact action whose output proves the result.>
- Write a session report, close the ledger entry, regenerate the index, and sync the dashboard.
```

## Writing rules

- Name exact live files in Step 0 and why they are needed. Never hard-code a developer's
  home-directory path.
- Write verification before implementation steps when possible. A verification item
  must require an action and observable result, not an argument that code looks right.
- State concrete non-goals. “Do nothing else” is not useful scope.
- Every stop gate names its trigger and the action that must not be taken without the
  operator's decision.
- For bug work, search the bug tracker, structural register, decision/risk logs, and
  nearby code terms before defining scope. List related rows and explicitly excluded
  neighbors.
- For curriculum work, `docs/pipeline/PIPELINE_SPEC.md` supplies mandatory gates,
  allowed runtimes, sources, and concurrency rules; quote or cite them, do not weaken
  them.
- The model line is advice. The active runtime policy and explicit user instructions
  control actual delegation; the ledger records what really ran.

Do not use a session prompt as a design document or duplicate settled decisions. Link
the canonical record and commission the next verifiable action.
