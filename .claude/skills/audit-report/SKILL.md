---
name: audit-report
description: The shared write-up format for any audit finding, whatever
  produced it. Use this skill whenever audit findings are being written up — the
  output of a code-audit skill, a security or performance sweep, a
  pre-publish check, a dependency review, or any multi-finding review
  that is not a single bug. Also triggers for: "write up the audit", "format
  these findings", "audit report", "sweep results", "review findings",
  "diagnosis report". This is the format contract audit skills write into; they
  supply the findings, this supplies the shape.
---

# Audit Report

This is the **format**, not an audit method. The audit itself comes from whatever
produced the findings — a language-specific audit skill, a targeted sweep, a
manual review. Those decide *what* to look for. This decides *what the write-up
looks like*, so that findings from different audits are comparable, sortable, and
readable side by side instead of each audit inventing its own shape.

## Before writing

Name the ledger entry the audit ran under (`ledger/README.md`). An audit report
without a ledger ID cannot be traced back to when it ran or what it ran against,
which is exactly how a finding gets re-fixed or wrongly assumed still true.

## Where it goes

`reports/audits/YYYY-MM-DD_<scope_slug>.md` — e.g. `2026-08-15_account_scoping.md`.

Individual findings do **not** each become a bug report. If a finding warrants a
tracker row — anything Blocker or High that is a live defect rather than tech debt
— file it with the `bug-report` skill and cite the finding ID (`4.2`) in that
report. The audit stays the single narrative document; the tracker gets the rows
it needs.

## Severity — four levels, no others

> 🔴 **Blocker** (must fix before publishing) · 🟠 **High** (fix before publishing;
> will be rejected or broken) · 🟡 **Medium** (fix soon after) · 🟢 **Low** (polish)

Copy that legend line verbatim into every audit report.

Audits that internally use P-levels map on the way in:

| Audit's internal level | Report severity |
|---|---|
| P0 Critical | 🔴 Blocker |
| P1 High | 🟠 High |
| P2 Medium | 🟡 Medium |
| P3 Low | 🟢 Low |

Write the report severity. Do not carry `P0`/`P1` into the report body; two
vocabularies for one scale is how a "P1" gets read as a blocker by one person and
as a nice-to-have by another.

## Structure

**Header block** — purpose, scope, method, severity legend, and the ledger ID.
Scope is a count, not a gesture: "223 source files, the database schema, the
generators", not "the codebase".

**Departments** — group findings by area, one `## DEPARTMENT N — <Area>` per
group — Security & Credentials, Submission Requirements, Open Bugs, Performance,
and so on; reuse the ones that fit and add new ones only for genuinely new areas.

**Findings** — numbered `N.M` within their department, ordered **most severe
first inside each department**. Every finding carries the same four fields:

```markdown
### Finding 4.2 — <what is wrong, stated as the problem not the fix>
**File:** `src/sync/manager.ts` lines 412–418
**Severity:** 🟠 High
**Detail:** What is actually there and why it is wrong. Quote the code when the
quote is the argument. If a claim rests on something you did not open, say so.
**Action:** The concrete change. Specific enough that someone else could do it
without re-deriving the diagnosis.
```

For a finding with no single file — a missing manifest, an absent test target —
drop the **File:** line rather than inventing a location.

**Summary table** — close with counts by severity and department, so the reader
knows the shape of the report before reading it.

## The two rules that make an audit report worth reading

**Every claim cites its evidence.** File and line, a command and its output, or a
capture filename. A finding that cannot cite anything is a hypothesis, and it goes
in a clearly-marked "Unverified suspicions" section at the end — never mixed in
with cited findings at a severity that implies it was confirmed.

**Re-audits state what changed.** When auditing an area that has been audited
before, say which prior findings are now fixed, which are still open, and which
were wrong. The bug tracker records the cost of the alternative: statuses that
drift because nobody re-checked them, and fixes marked done that were never
applied. An audit that only adds findings and never retires them turns into a
list nobody reads.
