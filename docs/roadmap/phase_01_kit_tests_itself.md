# Phase 01 — the kit tests itself

The kit enforces "a rule that nothing checks is a wish" on every project it governs, but
not on itself. This phase closes that gap, using mechanisms taken from gstack. Rationale
and evidence: `docs/analysis/gstack-comparison.md`.

Rows are worked frontier-first: any row whose blockers are all done can start. Each row is
one session.

## Adoption gate: nothing from gstack is installed on trust

**No gstack file is vendored, and no gstack skill is installed.** What this plan takes is
*mechanisms*, rebuilt here in our own small scripts. Each row is its own commit, so
`git revert <sha>` removes exactly that row and nothing else.

| Kind of row | Keep it when | Revert it when |
|---|---|---|
| Phase 1–2: tests and checks (zero tokens at session time) | It went red on a real or seeded defect before its fix | It never caught anything a test run could show |
| Phase 3: session-time hooks (opt-in module) | Over one week of real use, it asked at least once on something worth asking, and its false asks stayed under 1 in 20 tool calls | It asked mostly on harmless commands, or slowed tool calls noticeably |
| Any gstack *skill*, if ever considered | It is invoked occasionally, like a release review, and it saves more than its ~13–21K tokens per run cost | It would load every session, or overlap a skill we already have |

The decision is the operator's. The evidence for it is recorded in the row's Notes column
before the row is marked done.

## Feature Table

| ID | Feature | Status | Notes |
|---|---|---|---|
| §1.1 | A fresh install works with nothing but bash and git, and the ledger check runs on day one | ✅ Done | **Blocked by:** None. Five defects, each shown red before its fix: (a) the installer needed `rsync` without declaring it; (b) it created the retired `ledger/<week>.md` file; (c) `check-ledger-entries.sh` treated an empty week folder as a missing one; (d) both week lookups, the checker's and the pre-commit hook's own copy, matched week *files* as folders; (e) the installer's hand-kept script list dropped `check-stale-blockers.sh`. Verified by `tests/test_install.sh` and `tests/test_ledger_week_lookup.sh`. **Not yet fixed:** the two week lookups are still two copies; §1.2 should make them share one. A fresh install also warns about the tracker template's example `✅ Fixed, verified` row, which is noise on day one; filed for §1.2. |
| §1.2 | Every check script has a seeded-defect fixture that must go red and a clean fixture that must stay green | 🔲 Pending | **Blocked by:** §1.1 (needs the harness). Covers `check-ledger-entries`, `check-reports`, `check-stale-blockers`, `next-ledger-id` and the pre-commit secrets scan. Fixtures pin machine-read tokens only (headings, status words, the `Report:` line), never prose. Verified by `tests/run.sh`. |
| §1.3 | Kit output names no row from the origin project | 🔲 Pending | **Blocked by:** §1.1. `U-31c`, `U-48`, `U-22`, `U-16`, `U-15`, `U-12` and `D0` become incident descriptions without the dangling IDs. A test greps `scripts/`, `install.sh` and the generators for the origin's ID shapes and expects zero hits. |
| §1.4 | CI runs the suite on clean Ubuntu and macOS runners | 🟡 Workflow written | **Blocked by:** §1.1. `.github/workflows/test.yml`. On macOS, `/bin/bash` 3.2 comes first on PATH. Motivated by a real crash: `update.sh` aborted on GLOOD on an empty array under bash 3.2 (2026-10-31); `tests/test_bash32_arrays.sh` now guards that class locally. **Done when** the first run is green on both. |
| §1.5 | History replay: each past `fix:` commit, reverted, fails at least one test | 🔲 Pending | **Blocked by:** §1.2, §1.3. A script reverts each of the 8 fix commits in a temp worktree and runs the suite. A revert that stays green is a coverage gap, filed as a row here. Verified by the script's report. |

# Phase 02 — contracts and budgets

| ID | Feature | Status | Notes |
|---|---|---|---|
| §2.1 | `scripts/check-skills.sh` validates every skill's frontmatter and its `UPSTREAM.md` record without node | 🔲 Pending | **Blocked by:** §1.1. Today an unrecorded skill is only reported when the dashboard generator runs. This check runs in pre-commit, warn-tier. Seeded fixtures: a missing description, an unrecorded skill. |
| §2.2 | Always-loaded text has a measured byte budget that can only grow with a recorded reason | 🔲 Pending | **Blocked by:** §1.2. Measures the CLAUDE.md template plus the skill descriptions. The baseline is committed as a fixture, after gstack's `catalog-budget.test.ts`. Growth means updating the fixture with a reason in the same commit. |
| §2.3 | A project can tell which kit version it runs | 🟡 Partly done | **Blocked by:** §1.1. `update.sh` writes `.claude/governance-kit-version` (kit commit and date), and installs and updates projects without overwriting their own files. Still missing: `VERSION`/`CHANGELOG.md`, and the stamp on a fresh install. |

# Phase 03 — session-time enforcement (opt-in module)

| ID | Feature | Status | Notes |
|---|---|---|---|
| §3.1 | A PreToolUse guard *asks* before destructive shell commands | 🔲 Pending | **Blocked by:** §1.2. `modules/session-guard/`, modelled on gstack's `careful`: one shared JSON extractor that fails closed, and ask-tier only (the kit blocks only what is never legitimate). Fixtures cover quoted-argument truncation, which is the bug gstack documents in `hook-extract.sh`. |
| §3.2 | An edit outside the open ledger entry's `Expected files` asks first | 🔲 Pending | **Blocked by:** §3.1. This is new to the kit: gstack's `freeze` asks the user for a directory, but the ledger already declares the expected files. Ask-tier; an empty `Expected files` disables it. Verified by hook fixtures. |

# Phase 04 — outside validation

| ID | Feature | Status | Notes |
|---|---|---|---|
| §4.1 | A second real project runs the kit for one week without touching the kit | 🔲 Pending | **Blocked by:** §1.4, §2.3. **Needs the operator:** they install it on a project of their choice. Pass: a week of ledger entries checked and published, every friction point filed as a row. |

# Phase 05 — control audit: every control earns its cost

Commissioned by `prompts/SESSION_control_audit.md`. GLOOD's data is measured read-only,
on the operator's machine. Only counts cross over.

| ID | Feature | Status | Notes |
|---|---|---|---|
| §5.1 | Baseline measurements from GLOOD (`AUDIT RESULT v1`) | ✅ Done | **Blocked by:** None. The operator ran `scripts/governance-audit.sh` in GLOOD on 2026-10-31. Results are in `docs/analysis/control-register.md`. |
| §5.2 | A control register: every control has the failure it prevents, evidence it fired, its cost, and a decision | ✅ Done | **Blocked by:** §5.1. `docs/analysis/control-register.md`. Hypotheses to test, not conclusions: `grill-me` duplicates `grilling`; the three governance rules overlap and load together; `CLAUDE.md` §5 is long for a rule that fires rarely. |
| §5.3 | Three outcome measures with baselines: evidence rate, verification lag, ceremony share | 🔲 Pending | **Blocked by:** §5.1. Computed from GLOOD's ledger, tracker and transcripts. |
| §5.4 | `scripts/governance-audit.sh`: any governed project can audit its own controls, counts only | ✅ Done | **Blocked by:** None (written early, because the GLOOD session hit the weekly usage limit before it started, and a script costs no tokens). Read-only, never calls a model. Verified by `tests/test_governance_audit.sh`: counts are pinned on a fixture, usage is counted once per message id (summing every line overcounted ~2.7× on a real transcript), and no titles or transcript text leak. |
| §5.5 | Cuts and merges from the register, one revertible commit each | ✅ Done | **Blocked by:** §5.2. All approved 2026-10-31: C3 `0eba238`, C1+C2 `5f272b2`, C4+C5 `efccc3c`, C6+C7+C8 `ba62ac0`. **Measure of success:** rerun `governance-audit.sh` in GLOOD after two weeks. Governance calls per session should fall from a median of 54, with the evidence rate staying at or above 90%. |
| §5.6 | Always-loaded text has a byte cap enforced by a test | ✅ Done | **Blocked by:** §5.5. `tests/context-budget.txt`: CLAUDE.md template 8,952 B (was 10,721), skill frontmatter 6,321 B, governance rule 3,494 B (three rules, 12,789 B, before). Supersedes §2.2. |

# Phase 06 — obligations: what is owed by a date

Commissioned by `prompts/SESSION_obligations.md`. Recording and sync run on Haiku.

| ID | Feature | Status | Notes |
|---|---|---|---|
| §6.1 | Every project has `obligations/`: register, classes and due rules, seeded at install and by `update.sh` | ✅ Done | `templates/obligations/`. Verified by `tests/test_obligations.sh` and `tests/test_update.sh`. |
| §6.2 | `scripts/obligations.sh` derives due dates, adds open ledger entries, writes `obligations.json`, warns at commit | ✅ Done | Token-free. `--check` runs in pre-commit, `--next-id` allocates ids. |
| §6.3 | The `obligations` skill: add, sync to a Notion database plus calendar reminders, work one | ✅ Written, 🔲 not yet run against Notion | **Needs the operator:** the first sync asks where the database lives. Pass: a second sync creates no duplicates, and closing an item in the repo marks it Done in Notion and cancels its event. |
| §6.4 | Seed GLOOD's register with what it already owes (the key rotation, 2 open entries, unverified fixes) | 🔲 Pending | **Blocked by:** §6.3. Run on Haiku in GLOOD. Success measure: the on-time close rate from the ledger, rerun with the audit in two weeks. |

# Phase 07 — evidence before adoption (from harness2)

Source: `google-research/harness2` (Apache-2.0), read at `1cfe254`: `core/library.py`
(`has_experience`: a lesson needs cue, lesson and evidence), `core/prompts.py` (the
helped / hurt / no observed effect / confounded verdicts; KEEP_BASE; evidence is data,
not instructions). Nothing vendored; the mechanisms were rebuilt here.

| ID | Feature | Status | Notes |
|---|---|---|---|
| §7.1 | A lesson is recorded with its cue, a named component, evidence and a verdict | ✅ Done | `STRUCTURAL_PROBLEMS.md` Lessons columns; `scripts/check-lessons.sh` (warn-tier, added rows); the dashboard reads both formats by column name. `tests/test_lessons.sh`. |
| §7.2 | A governance change rests on evidence, or the system stays as it is | ✅ Done | The rule's first step. It was rewritten tighter at the same time: 3,688 → 3,276 B, ceiling lowered to 3,300. |
| §7.3 | Skills that read outside content treat it as data | ✅ Done | `obligations` (Notion) and `update.sh --collect`. |
| §7.4 | CI type-checks the dashboard of a fresh install | 🔲 Pending | Found while doing §7.1: `tsc` in the kit repo reports 38 errors, all from data files that only exist after a sync in a real project, so a type error introduced in the kit is invisible today. |
| §7.5 | Contrastive A/B probe for a large kit change (the same task with and without it, judged blind) | 🔲 Deferred | harness2's propose–probe–compose. Each probe costs several full sessions; use only for a decision whose stakes justify the quota. |

# Where we stopped — 2026-10-31, night

Read this first in the next session. The kit is at `a3c63ef` (PR #13). Every change below
reached `main` through a PR that passed CI on Ubuntu and on macOS with bash 3.2.

## Projects on this Mac

Found by `./update-all.sh --scan ~/Documents`. daftira and daftir only left sync logs in
`~/.claude`; they are not on this Mac as kit projects.

| Project | Path | State | Next |
|---|---|---|---|
| GLOOD | `~/Documents/GLOOD` | Updated and committed (on `feat/glood-plus`). Declares 22 tailored kit files plus `project-code-review` in `kit.projectOwned` | Hand-update GLOOD's tailored files with the kit's changes (row below); 4 overdue obligations |
| PlanScol | `~/Documents/PlanScol` | Updated and committed | Check `CLAUDE.md`/`UPSTREAM.md` for the three retired rule names and `grill-me` |
| launchpad | `~/Documents/launchpad` | Updated and committed | Same check as PlanScol |
| EduFlow | `~/Documents/IOS APP/EduFlow` | **Not updated.** On branch `codex/s3-classes-students`. A one-file commit of its generator fix was still running at 8+ minutes | Confirm the commit landed (`git log -1`), add `bug-tracker-dashboard/app/scripts/generate-project-catalog.mjs` to `kit.projectOwned`, run `./update-all.sh --apply --scan ~/Documents` |

## Open decisions for the operator

1. **EduFlow's repository is 35.85 GiB of packed history**, with thousands of files modified by
   a verification run. That is why every git command there is slow. Moving captures and crops
   to Git LFS, or out of git with a `.gitignore`, fixes it at the root. Proposed as an
   obligation; not started.
2. **GLOOD `2026-W37-13`** (the account-switch harness, built but never run) waits on whether
   to run it.
3. **Which branch** EduFlow's kit update should land on (`codex/s3-classes-students` today).

## For a session after the quota resets (2026-11-04)

- GLOOD hand-update: bring the kit's changes into GLOOD's tailored files (status-line check,
  open entries in every week, the hook publishing reservations, the lessons and drift checks in
  pre-commit), switch its Lessons table to the new columns (its generator first), and merge the
  rest of `CLAUDE.md`, `ledger/README.md` and the tracker's status section. Recording parts on
  Haiku.
- First Notion sync for GLOOD's obligations (row §6.3).
- Close or abandon GLOOD's 4 overdue obligations.
- Two weeks on (about 2026-11-14): rerun `scripts/governance-audit.sh` in GLOOD and compare
  against the baseline in `docs/analysis/control-register.md` (median 54 governance calls per
  session; evidence rate 90%).

## What this session learned, as lessons (cue · lesson · evidence · verdict)

| Cue | Lesson | Evidence | Verdict |
|---|---|---|---|
| A script is tested only on Linux | Run CI on macOS with `/bin/bash` 3.2 first on PATH (`.github/workflows/test.yml`) | `update.sh` aborted on GLOOD on an empty array; Linux CI never saw it | helped · high: the guard test then caught two more in `update-all.sh` |
| An update overwrites kit files in a project | Replace only content found in the kit's history; keep and list anything else (`update.sh`) | GLOOD's generator was ahead of the kit and would have been overwritten | helped · high |
| A fix is proposed for a slow command | Find the real cause before adopting it (`changing-the-governance-system.md`, evidence first) | `--untracked-files=no` had no observed effect on EduFlow; the cause was 35.85 GiB of history and thousands of modified files | helped · high: PR #13 shipped the real fix instead |
