# Register format

The register is `docs/decisions/REGISTER.md`. Each decision is a section headed `### D-<n> — <title>`: ids are
never reused, and the next id is the highest one plus 1. Under the heading are `- **Field:** value` lines,
which `decisions.py` reads.

| Field | Required | Holds |
|---|---|---|
| Date | all | The day it was decided (YYYY-MM-DD) |
| Kind | all | `data`, `values` or `reversible` (SKILL.md step 2) |
| Door | all | `one-way` or `two-way` |
| Decided by | all | A debate's ledger id, the operator's quote, or the lead |
| Decision | all | What was decided, in one or two sentences, or "not decided" while it awaits the operator |
| Prediction | data | What the checking event will show, in that event's own measures |
| Confidence | data | 1-99 %, then who gave it: `60 % (Claude, at seeding)` |
| Overturn if | data | The result that overturns it, with a number |
| Checked by | data | The event names in backticks: `` `H1` ``, `` `Ride B` ``, `` `first app build` `` |
| Premortem | one-way | The most likely reason it fails, written before it is decided |
| Principle | values, once decided | the operator's answer, quoted, written to apply to the next similar call |
| Status | all | `awaiting check`, `awaiting operator`, `held`, `overturned`, `unchecked`, `superseded by D-<n>` |
| Check | held, overturned | Date, the event's numbers, `information missed: no` or `yes`, then what was missed |
| Record | all | The path of the document that holds the reasoning |

**Never edit after the fact:** Decision, Prediction, Confidence, Overturn if. When a decision is replaced, the
replacement gets a new entry and the old entry's Status becomes `superseded by D-<m>`. The history of what was
believed is the point.

## Example

```markdown
### D-2 — The new smoothing filter, tested on the held-out recordings
- **Date:** 2026-11-27
- **Kind:** data
- **Door:** two-way
- **Decided by:** debate 2026-W48-65 (candidate); adopting it needs the operator's go
- **Decision:** the filter is the candidate. It stays off by default until H1 and H2 are scored.
- **Prediction:** on H1 and H2 together, the filter holds all five of the debate's conditions against the incumbent.
- **Confidence:** 45 % (the lead, at seeding)
- **Overturn if:** any one of the five fails: for example, accuracy within tolerance falls by 1 s or more.
- **Checked by:** `H1`, `H2`
- **Status:** awaiting check
- **Record:** reports/logs/2026-W48-65_filter_debate/decision.md
```
