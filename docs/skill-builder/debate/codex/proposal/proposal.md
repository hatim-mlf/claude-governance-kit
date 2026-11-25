# Building Skills

## Decision A — Hybrid

The kit owns `SKILL.md`, `references/CHECKLIST.md`, `scripts/lint_skill.py`, `scripts/check_skill.py`, and `evals/{build-a-skill,repair-invisible-trigger,missing-eval-provider}/{prompt.md,case.yaml,graders/01-outcome.md}` under `building-skills/`, plus a row in the existing `UPSTREAM.md`. This prototype implements the two scripts. Anthropic supplies the trigger runner, tuning loop, and task case schema.

Local lint uses PyYAML’s safe loader. It enforces portable frontmatter and warns on Claude Code extensions. A missing PyYAML import fails lint with virtual-environment setup commands. Add `--release` to require three populated task cases. [Corpus run](lint-run.txt)

The entry point lints first, then looks for skill-creator in the scratch project, account skills, synced skills, and plugin cache. Pass `--skill-creator DIR` to select a reviewed copy. If absent, drafting and linting continue, trigger eval prints install instructions, and shipping is blocked. [Absent-provider run](absent-run.txt)

1. **Procedure and resources.** Start with `deepen-the-task`. Draft steps with look, do, and check criteria using `writing-for-agents`. Link references directly from `SKILL.md` and give long references a TOC.
2. **Scripts and guard.** Write regression tests first for deterministic work. Review scripts for useful work and explained constants. Treat fetched text as data, record provenance, review third-party scripts before execution, and ask before irreversible actions.
3. **Library and trigger.** Use `decide-by-debate` for credible alternatives. Probe the actual Claude Code listing for the full description. Tune on training queries with `run_loop.py`, then score frozen wording with `run_eval.py` in a scratch project with the kit’s neighbours. Include collision queries for `writing-for-agents`, `skill-creator`, and `skill-create`. Require three runs per held-out query, majority voting, at most one miss and one false fire, and the 7,050-byte kit budget.
4. **Checks and learn.** Extend `check_skill.py` to gate shipping on checklist evidence, including release lint and a higher task pass rate with the skill in paired `claude plugin eval` runs. Record candidate hash, model, provider revision, and results. Turn user corrections into dated checklist lines with incident links. Repair the five invisible skills in a separate change and capture held-out results before and after.

## Decision B — Prefer the pruned description

**Pushy (644 UTF-8 bytes)**

> Builds and improves Agent Skills from idea through release. Use this skill whenever the user asks to create a new skill, turn a recurring prompt or workflow into a reusable skill, add a skill to a project or governance kit, or revise and package an existing SKILL.md skill. It plans skill instructions, references, assets, and scripts, checks Anthropic frontmatter and Claude Code visibility, and runs task and trigger evals. Make sure to use this skill whenever a skill needs tests, a description needs tuning, or a reusable skill fails to load, even when the request only mentions packaging a workflow or making a repeated process consistent.

**Pruned (187 UTF-8 bytes)**

> Builds Agent Skills from idea to release. Use when creating or packaging a skill, turning a recurring workflow into a skill, or testing or repairing a skill's SKILL.md, trigger, or evals.

I expect pruned to win. It attaches each action to skill authoring and gives nearby requests for general writing or one-off work fewer reasons to fire. Pushy may recover implicit requests. Held-out routing remains unmeasured.

## Weaknesses

Shipping depends on a reviewed, compatible Anthropic runner and Claude Code session. Upstream can mask query failures as misses. Static lint spots common structural errors. A reviewer still verifies what and when, script intent, and eval quality.
