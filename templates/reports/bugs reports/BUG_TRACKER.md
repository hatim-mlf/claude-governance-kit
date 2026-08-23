# Bug Tracker

The live defect register for app and dashboard behaviour. Tooling, layout and
process defects go in `STRUCTURAL_PROBLEMS.md` instead — the rule is: **a defect
gets an identifier and a status in a list someone reads, or it is not filed.**

## How to file

One section per bug, numbered sequentially, never reused. Written with the
`bug-report` skill; the full report lives in `reports/bugs/` and this row cites it.

```markdown
## Bug 1 — Short title

**Status:** 🟠 Open
**Severity:** High
**Surface:** where the user meets it
**Ledger:** 2026-W34-01
**Report:** `reports/bugs/2026-08-22_short_slug.md`

**Symptom:** what is observed.
**Root cause:** what causes it, once known — "unknown" is a valid entry.
**Next step:** the smallest action that moves it.
**Verification bar:** what evidence moves this to *Fixed, verified*.
```

## Status vocabulary

| Status | Meaning |
|---|---|
| 🟠 Open | Confirmed, unfixed |
| 🟡 Fixed, unverified | A commit claims it; nothing proves it |
| 🟢 Fixed, verified | Named evidence (a capture, a test run, a scenario) proves it |
| ⚪ Product gap | Not a defect — a decision to make |

**A fix with a commit but no evidence is not done; it is a claim.** The
unverified/verified split is the point of this tracker. Only named evidence moves a
row to verified.

---

## Bugs

<!-- Newest first. Do not leave example rows here — even inside an HTML comment,
the dashboard's bug-catalog parser reads every "BUG N —" heading as a real row. -->
