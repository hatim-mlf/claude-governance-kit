# gstack × claude-governance-kit — what to take, and what not to

**Date:** 2026-10-31 · **gstack at:** `1.91.342.0` (MIT, © Garry Tan) · **kit at:** `79ffa4c`

## The two projects are not the same kind of thing

| | gstack | this kit |
|---|---|---|
| Goal | Velocity: one person shipping like a team | Accountability: what a session did is written down and visible |
| Size | ~4,400 files, ~1,290 test files, ~50 skills, browser + design binaries | ~100 files, 14 skills, 10 shell scripts, a dashboard |
| How a lesson is kept | **As a test.** Every incident becomes a pinned check that fails CI | **As prose.** Every incident becomes a rule with its story attached |
| Enforcement point | Session time (PreToolUse hooks) + CI | Commit time (pre-commit) + sync hooks |
| Self-verification | Free suite, paid evals, size budgets that only go down | None: no tests on any script, no CI |

The row that matters is the last one. gstack's skills aren't what's worth copying. The
**discipline that turns every lesson into a check that runs without anyone remembering it**
is. This kit already says it believes that ("a rule that nothing checks is a wish"). It
applies that belief to the projects it governs, but not to itself.

## Evidence (raw, not digested)

Gathered by installing the kit into an empty repository and running its own loop. No
documentation was trusted.

1. **The installer depends on `rsync` without saying so.** On a machine without it,
   `install.sh` stops after the templates and never writes `governance.config.json`. It
   also never installs the pre-commit hook. The error is one line in the middle of the
   output.
2. **The installer creates the retired ledger layout.** It writes `ledger/<week>.md`, a
   week *file*, but every consumer expects `ledger/<week>/<day>.md`. On a fresh install,
   `check-ledger-entries.sh` reports `DID NOT RUN`. This is the "consumer left behind"
   failure that `governance-changes-reach-the-kit.md` describes. It survived the commit
   that fixed the same failure in four other consumers (`d8f4d29`).
3. **Row IDs from the origin project leak into kit output.** `U-31c`, `U-48`, `U-22`,
   `U-16`, `U-15`, `U-12` and `D0` appear in scripts and generators. A fresh project's
   first commit prints `Register row U-31c`, a row that doesn't exist in that project.
4. **8 of the kit's 23 commits are `fix:`.** Every one is a regression that a fixture test
   would have caught (a path with a space, entry numbers past 99, a resolver matching prose,
   a dropped directory). Nothing automated caught any of them.
5. **Always-loaded context is unmeasured.** The CLAUDE.md template (10.7 KB), the skill
   descriptions (6.2 KB) and the path-scoped rules (~15 KB when they fire) have no budget.
   gstack caps its equivalent and lets the cap only go down, or up only with a recorded
   reason.
6. **Once the legacy file is removed, the core loop works.** Reserve → `next-ledger-id.sh` →
   `check-ledger-entries.sh` → `publish-ledger-entry.sh` succeeded end to end in the
   probe. The design is sound. What's missing is its safety net.

## What we take, mapped to a gstack mechanism

| # | gstack mechanism (file) | What it becomes here |
|---|---|---|
| T1 | Hermetic E2E env (`test/helpers/hermetic-env.ts`) | `tests/` — install into a temp repo and run the real loop. No dependencies beyond bash and git |
| T2 | Prompt-byte contract and test value bar (`docs/test-value-bar.md`) | Fixtures pin what **software reads**: ledger headings, status words, the `Report:` line. They never pin prose |
| T3 | Each incident pinned by a tripwire test | Fault injection: for every check script, a seeded-defect fixture that must go red and a clean one that must stay green |
| T4 | `skill:check` frontmatter validation (`scripts/skill-check.ts`) | `scripts/check-skills.sh`: valid frontmatter plus `UPSTREAM.md` coverage, without needing node |
| T5 | Catalog and context-budget ratchet (`test/catalog-budget.test.ts`) | A measured byte budget for always-loaded text. Growth needs a recorded reason in the same commit |
| T6 | `VERSION` + `CHANGELOG.md` | The installer stamps `kitVersion` into `governance.config.json`, so a project can tell which kit it runs. That gives the mirror rule something to compare against |
| T7 | `careful` / `freeze` PreToolUse hooks with one shared fail-closed JSON extractor (`careful/bin/hook-extract.sh`) | An opt-in **session-time** module. It *asks* (never denies) before destructive commands, and when an edit lands outside the open ledger entry's `Expected files` |
| T8 | CI on a clean runner | GitHub Actions on Ubuntu and macOS: tests + shellcheck |

T7's second half is not in gstack. It's what this kit's own data makes possible: the
ledger already declares, before work starts, which files a task expects to touch. gstack's
`freeze` asks the user for a directory. Our kit already knows the answer.

## What we do not take, and why

- **"Boil the Ocean".** It directly contradicts the template's *Simplicity First*, which
  is the right default for a governance layer that has to stay small enough to be read.
- **`.tmpl` → generated `SKILL.md` pipeline.** gstack needs it for ~50 skills across
  several hosts. At 14 skills on one host it adds a build step and saves nothing.
- **Telemetry and analytics JSONL in every skill preamble.** This kit doesn't send data
  off the machine, and should stay that way.
- **Paid model evals.** Worth it only once the free tests exist and a skill's wording is
  shown to change behaviour. Revisit after Phase 2.
- **Browser, design, deploy, retro and learn skills.** These are outside the kit's scope.
  The ledger plus `STRUCTURAL_PROBLEMS.md` already cover learnings.

## What would show this is right, other than us

- A **clean CI runner** going green on Ubuntu and macOS. Neither of us gets a vote.
- The **seeded-defect corpus**: each check must go red on its seeded defect. A check that
  stays green on a known defect is broken, whatever its prose says.
- **Git history replay**: each of the 8 historical `fix:` commits, reverted, must make at
  least one test fail. This is how we know the suite covers the defects that actually
  happen.
- A **second real project** installed from scratch by its operator, with its first week's
  ledger checked and published without touching the kit.
- **Budget numbers** that only go down, or go up with a reason written in the same commit.

Execution plan: `docs/roadmap/phase_01_kit_tests_itself.md`. The prompt that commissioned
this work: `prompts/SESSION_gstack_comparison.md`.
