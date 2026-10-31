# Control register — baseline from GLOOD

**Source:** `scripts/governance-audit.sh`, `AUDIT RESULT v1`, generated 2026-10-31 01:27, run
read-only on GLOOD. Covers 43 transcripts (2026-09-08 → 2026-10-31), 530 ledger entries
(2026-W33 → W44), 332 bugs and 645 commits. Only counts crossed over.

## What the governance system costs

| Measure | Value | Note |
|---|---|---|
| Context at the first model call | median 68,135 tok, p90 75,277 | Startup cost of a GLOOD session |
| Always-loaded governance text | 22,848 B, ~5.7K tok | CLAUDE.md is 15,354 B (template: 10,721 B), skill frontmatter 7,494 B. **About 8% of startup.** Most of the 68K is system prompt and tool definitions, not governance |
| Path-scoped rules | 7 files, 25,103 B, ~6.3K tok | Loaded in 28–38 of the 43 sessions. Path scoping is barely saving anything |
| Governance tool calls | 3,254 of 20,486 (**16%**), median 54 per session | Each one re-reads the whole context |
| Cache-read tokens | 3.42 B total, median 42.7 M per session | The dominant cost. It scales with context size × number of calls |
| **Estimated governance share of input tokens** | **roughly 20%** | ≈16% of calls are governance, plus ~7% of every call's context is resident governance text. The average context per tool call is ≈167K (3.42 B ÷ 20,486), so this is an estimate, not a measurement |

## What it delivers

| Measure | Value |
|---|---|
| Ledger entries | 530 in 12 weeks |
| Closed with real `Verified by:` evidence | **453 / 503 (90%)** |
| Reserve → close | median **0.1 h (6 min)**, p90 1.7 h, max 138 h |
| Bugs tracked | 332 |
| Reports | 104 session, 68 bug, 49 verification, 31 audit, 24 error |
| Commits touching governance paths | 570 / 645 (88%); 249 governance-only |
| Other projects running the kit | daftira, eduflow, launchpad, daftir, planscol (from their sync logs) |

## Controls — evidence and proposed decision

| # | Control | Evidence | Proposed decision |
|---|---|---|---|
| C1 | One ledger entry per task | Median entry lasts **6 minutes**. 530 entries × ~5 ceremony calls ≈ the 3,254 governance calls | **Change:** one entry per commissioned task or row. Steps go inside the entry, not into new entries |
| C2 | `publish-ledger-entry.sh` after *reserve* | The PostToolUse hook already publishes on every ledger write (1,755 sync-log lines, 5 skipped) | **Cut** the reserve-time publish in Claude Code. Keep publish-at-close as the verification. Other runtimes keep both |
| C3 | Status vocabulary (fixed ≠ verified) | Ledger: 23 entries with no status line, ~20 "Closed — prose" variants. Tracker: **over 100 distinct status strings for 332 bugs** | **Fix, top priority:** the status line holds an enum only, and prose goes on the next line. Add a warn-tier check. Without this, the kit's core claim (fixed ≠ verified) can't be counted |
| C4 | `Needs attention:` | `yes` on **323 / 530 (61%)** | **Redefine:** `yes` only when the operator must act. At 61% it filters nothing |
| C5 | Open-entry check | 26 entries open or status-less for more than 2 days. The check only reads the current week | **Extend:** warn on open entries in every week |
| C6 | Three governance-on-governance rules | 12.8 KB together; each loads in 23–29 of 43 sessions | **Merge** into one rule of about 4 KB |
| C7 | CLAUDE.md | 15.3 KB, +4.6 KB over the template | **Trim after C1–C6**, then cap (§5.6) |
| C8 | Skills | Never invoked in 43 sessions: `codebase-design`, `dashboard-sync`, `grill-me`, `grilling`, `glood-seo`, `swift-xcode-audit`. Used most: `glood-code-review` 29, `session-report` 17, `session-prompt` 17, `bug-report` 15, `tdd` 12 | **Cut `grill-me`** (duplicates `grilling`). Keep the rest; their frontmatter costs ~1.5 KB together. Review again after 43 more sessions |
| C9 | Pre-commit secrets block | No firing data (`--no-verify` and blocks leave no trace) | **Keep.** Log fires to a file outside the repo so the next audit can count them |
| C10 | SessionEnd / Stop sync hooks | 1,755 log lines, 5 skipped; milliseconds per no-op turn | **Keep** |

## Outcome measures — baselines

| Measure | Baseline | Target direction |
|---|---|---|
| Evidence rate: closed entries with real `Verified by:` | 90% | Hold at ≥ 90% |
| Ceremony share: governance tool calls ÷ all | 16%, median 54 per session | Down, with no drop in evidence rate |
| Verification lag: fixed → verified | **Not measurable.** The tracker's status line has no date and no enum | Measurable once C3 lands |

## Defects in the audit script found by this run

- Status strings aren't bucketed into open / fixed-unverified / fixed-verified / gap.
- `STRUCTURAL_PROBLEMS.md` parsed to `{}`: GLOOD's row format differs from the template.
- `reports/archive/` trackers are counted as live.
- "Rule loads" counts any mention of a rule file, not only the times it was injected into
  context, so it is an upper bound.
