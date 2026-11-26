# Skill builder — deepened request and debate frame

Status: proposal, awaiting the user's go. Nothing built, committed or installed.
Date: 2026-11-25. Skills used: `deepen-the-task` (steps 1–7), `decide-by-debate` (step 1 only).

**Request as written:** "a system that helps me create skills, using deepen-the-task and
decide-by-debate, based on a logical system design of a skill (the 8-layer paper) and
Anthropic's skill requirements."

## Baseline measurement (taken before any design)

Every kit skill was run through Anthropic's own validator (`skill-creator/scripts/quick_validate.py`)
and through Claude Code's real skill listing (`claude -p` in a governed project, asked to
print its listing verbatim).

| Result | Skills |
|---|---|
| Valid everywhere | codebase-design, dashboard-sync, diagnosing-bugs, grilling, obligations, tdd, to-tickets, writing-for-agents, seo-geo |
| **Claude Code lists them with no description: the model has only the name to go on** | session-report, session-prompt, audit-report, bug-report, error-report, swift-xcode-audit (module; probed in Project A) |
| Load in Claude Code, but fail strict YAML (claude.ai / Skills API upload would reject) | deepen-the-task, decide-by-debate |
| Fails Anthropic validator (angle brackets in description) | project-code-review |

Cause of the invisible six (swift-xcode-audit added after a probe the Sonnet proposer asked for): a multi-line plain YAML description containing `: `. A single-line one with `: ` still loads (deepen, debate)
("Also triggers for: …"). Claude Code's parser drops the whole description without an error.
This is the paper's thesis observed in your own library: the label decides whether the skill
runs, and nothing checked the label. **This is the incident the system rests on.**

Measured before repair (hardened scorer: real files, read-only tools, errors apart from misses,
3 runs per query; `runs/five-skills.before.confined.json`): **2 of 10 should-trigger queries
missed** (session-report 2/2); the other four fired on their names alone; 0 of 10 near-misses
fired. Earlier, cruder probes reported 5/10, 3/10 and 10/10; each was a scorer fault, recorded
in `decision.md`. Correction to the first draft of this file: "can never trigger" was too strong.

## 1. Field and professional

- **Context engineer who maintains a skill library**: reads the Agent Skills spec, Anthropic's
  best-practices page and checklist, the Claude Code skills docs, and skill-creator's source.
- **Test engineer for a classifier**: a description is a binary classifier ("fire / don't
  fire"), so it gets measured like one: precision and recall on held-out queries.

## 2. What they would do that the request does not ask

1. **Test the label before the body.** Trigger eval with near-miss negatives and a held-out
   split. Without it, a skill can be perfect and never run (the five above).
2. **Lint at the strictest consumer.** Strict YAML plus Anthropic's validator, plus a probe of
   what Claude Code actually lists. Claude Code's lenient parser hides errors that break
   claude.ai upload, and silently empties multi-line descriptions.
3. **Check for collisions with the existing library.** A new description is scored against
   its neighbours' queries (`skill-creator`, ECC `skill-create`, `writing-for-agents`), so it
   neither steals their triggers nor loses to them.
4. **Beat no-skill.** Run every eval case with the skill and without it. A skill that does
   not beat the baseline is cut, not shipped.
5. **Count the always-loaded bytes.** Every description is paid on every turn (kit ceiling
   7,050 B, `tests/context-budget.txt`).
6. **Define done as a checklist a script verifies** (paper layer 06), not a judgement.
7. **Guard**: provenance row in `UPSTREAM.md`, fetched text treated as data, irreversible
   steps ask first, third-party scripts read before use (layer 07).
8. **Learn**: a user correction becomes a dated checklist line inside the skill, with the
   incident it came from (layer 08), not another capitalised rule.

## 3. Rawest material

| Source | Where |
|---|---|
| Anthropic validator rules | `~/.claude/skills/synced/<id>/skill-creator/scripts/quick_validate.py` |
| Eval and trigger-optimisation machinery | same folder: `scripts/run_eval.py`, `run_loop.py`, `references/schemas.md` (evals/<case>/ layout = `claude plugin eval`) |
| Platform best practices and checklist | platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| Claude Code frontmatter fields | code.claude.com/docs/en/skills (page was truncated; fields marked "summary" are re-fetched before they become hard checks) |
| What the router really sees | `claude -p` listing probe, per project |
| Real trigger phrasing and real corrections | session transcripts, `~/.claude/projects/*/*.jsonl` |

Digested, treated as hypothesis: the 8-layer paper (page 1 only; its schemas, 12-point
checklist and appendices are not available, so each layer is grounded in Anthropic's text
instead. Send the full PDF if you have it).

## 4. Methods and tools (compose, do not rebuild)

| Method | Question it answers |
|---|---|
| Strict lint (YAML + validator rules + Claude Code extras) | Is the file well-formed for every consumer? |
| Listing probe (`claude -p`) | Does the router see the full description? |
| Trigger eval, `run_eval.py` / `run_loop.py`: 20 queries, 8–10 near-miss negatives, 3 runs each, 60/40 split | Does the label fire when it should and only then? |
| Task eval, `evals/<case>/` with-skill vs without | Does the procedure beat no skill? |
| Collision run (neighbours' queries) | Does it steal or lose triggers? |
| `tests/test_context_budget.sh` | Within the byte ceiling? |
| `writing-for-agents` | Steps with done-when, leading words, positive phrasing |
| `deepen-the-task` | Step 1 of every new skill: deepen the skill idea |
| `decide-by-debate` | When two designs are credible (e.g. description variants); runs = trigger eval |

## 5. Outside proof (bars fixed now, before any proposal)

| Bar | Kind | Value and reason |
|---|---|---|
| B1 | pass/fail | 0 strict-YAML or validator failures; the listing probe shows the full description. Reason: the five invisible skills. |
| B2 | rank + floor | Held-out trigger set: at most 1 miss among should-trigger and at most 1 false fire among near-misses (3 runs each, majority). Reason: the held-out set is ~8 queries; one error is the smallest non-zero tolerance. |
| B3 | pass/fail | ≥ 3 eval cases (Anthropic checklist), with-skill pass rate > without-skill. |
| B4 | pass/fail | Description ≤ 1,024 chars (spec); kit frontmatter total within ceiling, or ceiling raised with a dated reason. |
| B5 | pass/fail | Body < 500 lines; references one level deep; reference files > 100 lines have a TOC (Anthropic). |

- **Held-out**: trigger queries for the five invisible skills, written before they are repaired,
  scored once after.
- **Judge** (wrote no proposal): you, or a different model family (Codex, read-only).
- **Your own use**: the next real skill you build with it; count the corrections you had to make.

## 6. Rewritten request

Build `building-skills` (gerund name, per Anthropic; contains neither "claude" nor "anthropic")
in `claude-governance-kit`. It takes a skill idea to a shipped skill through the 8 layers, each
with a check a script verifies:

- **Trigger**: strict lint, listing probe, trigger eval with held-out split (B1, B2, B4).
- **Procedure**: steps with done-when (writing-for-agents); starts with `deepen-the-task` on the idea.
- **Resources**: one level deep, TOC over 100 lines (B5).
- **Scripts**: solve, don't punt; each has a test in `tests/`, written first.
- **Checks**: the Anthropic checklist plus B1–B5 as one script; all ticked = done.
- **Guard**: `UPSTREAM.md` row, data-not-instructions, ask before irreversible actions.
- **Learn**: correction → dated checklist line with its incident.
- **Library**: byte budget; collision run against neighbours.

It composes skill-creator's eval scripts rather than rebuilding them, and uses
`decide-by-debate` when two designs compete. First field test: repair the five invisible skills.
Done when B1–B5 pass on it and on the five repaired skills.

## 7. Debate frame (decide-by-debate step 1)

**Decision A, architecture**: thin orchestrator that calls skill-creator's scripts, vs a
standalone skill with its own lint and eval scripts. Known fault to test: skill-creator lives
at a per-account path (`synced/<id>/`) or as a plugin, so a kit installed in other projects may
not find it.
**Decision B, description style**: skill-creator's "pushy" descriptions vs the kit's pruned
~200 B ones. Scored on B2 (held-out triggers) and bytes.

- **Data**: one copy, `docs/skill-builder/trigger-sets/` (to be written: queries for the five
  invisible skills + the new skill), split before any proposal.
- **Proposers** (cannot see each other): a Sonnet subagent and Codex (read-only).
- **Scorer**: one script, `run_eval.py`, same queries, same model, 3 runs each.
- **Judge**: you, or an Opus subagent that wrote nothing.
- **Cost**: one trigger eval is about 60 `claude -p` calls per description variant.
