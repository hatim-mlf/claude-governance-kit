# Debate frame — the skill-building system

Written 2026-11-25, before any proposal exists. Context: `deepen-and-frame.md` (same folder).
User decisions (2026-11-25): lives in the governance kit; lint strict (Anthropic validator) and
allow Claude Code-only keys with a warning; first field test = repair the five invisible skills,
as a separate commit; run the debate on both decisions.

## Decisions

**A. Architecture.** How does `building-skills` get its checks and evals?
Candidates: a thin orchestrator that calls Anthropic's `skill-creator` scripts; a standalone
skill with its own scripts; or a hybrid. Out of scope: the dashboard, the catalog generator.

**B. Description style** for `building-skills` itself: skill-creator's "pushy" style (long,
lists contexts, "make sure to use this skill whenever…") vs the kit's pruned style (~200 B,
front-loaded leading word, one trigger per branch, per `writing-for-agents`).

## Data (one copy each)

| What | Path |
|---|---|
| Kit skills, the lint corpus | `~/Documents/claude-governance-kit/.claude/skills/*/` and `modules/*/*/` |
| Ground truth for the lint corpus | the baseline table in `deepen-and-frame.md` (Anthropic validator + Claude Code listing probe) |
| Trigger queries, tuning set | `trigger-sets/building-skills.train.json` (14) |
| Trigger queries, **held-out** | `trigger-sets/building-skills.heldout.json` (8). No proposer reads it. Scored once, after the verdict. |
| Field-test held-out | `trigger-sets/five-skills.heldout.json`. Scored before and after the repair. |
| Anthropic's skill-creator (Apache-2.0) | three differing copies exist on this machine: `~/.claude/skills/synced/<id>/skill-creator` (two ids) and the `claude-plugins-official` plugin |

Ground truth for the lint corpus:
- **Must flag (9):** session-report, session-prompt, audit-report, bug-report, error-report,
  swift-xcode-audit (description lost in Claude Code); deepen-the-task, decide-by-debate (strict
  YAML fails); project-code-review (angle brackets).
- **Must pass (9):** codebase-design, dashboard-sync, diagnosing-bugs, grilling, obligations,
  tdd, to-tickets, writing-for-agents, seo-geo.

## Bars

Decision A:

| Bar | Kind | Value | Reason |
|---|---|---|---|
| A1 | pass/fail | The lint flags all 9 must-flag skills, with the right reason, and none of the 9 must-pass | the baseline is measured, not judged |
| A2 | pass/fail | With skill-creator absent, lint still runs, and the eval step stops with a message naming what is missing and how to get it | the kit is installed into projects on other machines; skill-creator's path differs per account |
| A3 | rank | Lines of code the kit must own and maintain, fewer better | each copied line is a drift risk (three skill-creator copies already differ) |
| A4 | rank | Dependencies beyond bash 3.2 and python3 stdlib, fewer better | kit tests target bash 3.2 (`tests/test_bash32_arrays.sh`) |

Decision B:

| Bar | Kind | Value | Reason |
|---|---|---|---|
| B2 | floor, then rank | Held-out: at most 1 should-trigger missed and at most 1 near-miss fired (3 runs each, majority) | held-out has 4+4 queries; one error is the smallest non-zero tolerance |
| B4 | rank | Description bytes, fewer better; must be ≤ 1,024 chars | always loaded; kit ceiling 7,050 B for all skills together |

Tie on the bars → the simpler option wins.

## Scorer

- Trigger: `skill-creator/scripts/run_eval.py`, run from the scratch project
  `<scratchpad>/eval-project` (holds a copy of the kit skills as neighbours), default model,
  `--runs-per-query 3`. Every candidate scored on the same files in the same session.
- Known scorer limit: `run_eval.py` installs the description as a block scalar in
  `.claude/commands/`, so it tests the wording, not the real file's YAML. The listing probe covers
  the file.
- Lint: each proposal's own lint script, run by the scorer on the same corpus.

## Roles

- Proposers (cannot see each other): a Sonnet subagent; Codex (read-only on the kit).
- Scorer: the lead (writes no proposal).
- Judge: an Opus subagent that wrote no proposal and no scorer.

## Results so far

- Tuning-set triggers (`runs/*.train.json`, 7 should + 7 near-miss, 3 runs): sonnet-pruned 0
  missed / 0 fired (160 B); codex-pruned 0 / 0 (187 B); codex-pushy 0 / 0 (644 B); sonnet-pushy
  1 / 0 (692 B). An earlier codex-pruned 7/7 miss was runs failing at the usage limit; re-run.
- Lint cross-examination: `debate/cross-exam-scored.md`.
