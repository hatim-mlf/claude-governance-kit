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
| §1.4 | CI runs the suite and shellcheck on clean Ubuntu and macOS runners | 🔲 Pending | **Blocked by:** §1.1. `.github/workflows/test.yml`. Verified by a green run on the PR. This is the outside arbiter for every other row. |
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
