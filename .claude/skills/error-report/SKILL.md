---
name: error-report
description: Write an error report for a failed command, build, migration, or
  tool call. Use this skill whenever something in the toolchain fails rather than
  the app misbehaving — a compile or link error, a failed database migration or
  SQL statement, an npm/vite/build failure, a script that exits non-zero, a git
  or hook rejection, an MCP or tool call that errors out. Also triggers for: "the
  build failed", "this command errored", "log this error", "write an error
  report", "migration failed", "why did that fail". Not for wrong app behaviour —
  that is the bug-report skill.
---

# Error Report

An error report is about **an operation that failed**. The app misbehaving while
running correctly-built code is a `bug-report`. The distinction matters because
these two get triaged completely differently: a bug report goes to BUG_TRACKER.md
and gets a severity and an owner; an error report usually gets resolved, retried,
or dismissed inside the same session and never reaches the tracker at all.

## Before writing

Name the ledger entry this happened under (`ledger/README.md`). An error hit
mid-task belongs to that task's ID, not to a new one — errors are things that
happen inside work, not work in themselves.

## Where it goes

`reports/errors/YYYY-MM-DD_<short_slug>.md`

An error report does **not** get a BUG_TRACKER.md row. If the classification below
comes out as "real defect in our code", file a separate `bug-report` for the defect
and cross-reference the two; don't try to make one file do both jobs.

## Required content

### 1. The exact error text, verbatim

Paste it. Do not summarize it, do not clean it up, do not retype it from memory,
do not truncate the middle. If it is 200 lines of compiler output, include the
first error and the surrounding context, and say explicitly how much was cut and
where the full output is (`reports/verification/` for a saved transcript). Error
strings are the search key someone uses to find this file in a year — a paraphrase
is not findable.

### 2. The command or operation that produced it

The full invocation, with its flags, its working directory, and any environment
that mattered:

```bash
cd "$(git rev-parse --show-toplevel)"
npm run build
```

For a tool call rather than a shell command, name the tool and the arguments. For
a migration, name the SQL file and the target project.

### 3. Environmental / transient, or a real defect

State which, and say what makes you sure:

| Class | Means | Typical evidence |
|---|---|---|
| **Environmental** | The machine, network, credentials, environment state, or a stale cache — not our code | Succeeds on retry; succeeds after a clean; a 5xx or timeout; expired token; missing local tool |
| **Transient** | Same operation, same inputs, different outcome, cause unidentified | Failed then passed with nothing changed in between |
| **Real defect** | Our code, config, or migration is wrong and would fail for anyone | Reproduces deterministically from a clean state |

"Probably transient" without a retry is a guess. Retry once before classifying, and
record the retry's result. Calling a real defect transient is how it comes back
next week with less context attached.

If it is a real defect, name the follow-up: the `bug-report` file or the roadmap
row that now owns it.

## Template

```markdown
# Error — <what failed, in five words>

**Ledger:** 2026-W33-04
**Date:** 2026-08-15
**Operation:** build | migration | npm run build | git commit | tool call
**Classification:** Environmental | Transient | Real defect

## Command

```bash
<exact invocation, including cwd>
```

## Error output

```
<verbatim, uncut through the first error and its context>
```

<If trimmed: "Lines 40–380 of compiler output omitted; full transcript at
reports/verification/<file>.txt">

## What it means

Plain reading of the error — what the tool is actually complaining about.

## Classification rationale

Why Environmental / Transient / Real defect. Include the retry and its result.

## Resolution

What unblocked it, or "unresolved". If it was a real defect: the bug report or
roadmap row that now owns the fix.
```

## Note on the pre-commit hook

A `scripts/pre-commit.sh` rejection for a credential pattern is
**not** an error to report away. It is the hook working. Either the secret is real — remove it, and if
it ever reached a commit, rotate it — or it is a false positive, which takes
`// pragma: allowlist-secret` on the line. Write an error report only if the hook
itself is broken, and say plainly which of those two you concluded.
