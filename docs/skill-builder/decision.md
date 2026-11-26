# Decision — the skill-building system (`building-skills`)

2026-11-25. Method: `deepen-the-task`, then `decide-by-debate`. Files in this folder:
`deepen-and-frame.md` (deepened request, baseline), `frame.md` (bars, data, roles),
`debate/` (proposals, cross-examinations, fixtures), `verdict.md` (judge), `runs/` (scores),
`trigger-sets/` (queries; held-out kept apart).

## Question

How should a kit skill that builds skills get its checks, and which description should it
carry? It rests on a measured incident: six kit skills were listed by Claude Code with no
description (a multi-line plain YAML description containing `: `), and nothing checked labels.

## Who proposed what

| Proposer | Architecture | Lint | Descriptions |
|---|---|---|---|
| Sonnet subagent | hybrid: own lint, skill-creator located for evals | stdlib, optional PyYAML | pruned 160 B, pushy 692 B |
| Codex (GPT) | hybrid: own lint, skill-creator for evals | PyYAML required | pruned 187 B, pushy 644 B |

## Faults found, and by whom

- **Scorer (lead):** skill-creator's `run_eval.py` scored "not triggered" at the first
  non-Skill tool call (the model usually runs `ls` first), and its parallel workers shared one
  commands folder. A probe built the same way undercounted the field-test baseline (5/10
  missed reported; 3/10 true). Fixed by `score_triggers.py` (isolated project per run, real
  SKILL.md, up to 6 tool calls). Codex raised the same weakness independently.
- **Sonnet proposer:** swift-xcode-audit was assumed to load; a probe showed a sixth
  description-less skill. Also: Codex's lint fails all skills without PyYAML; false fails on
  "chapter I" and a plain-list TOC.
- **Codex proposer:** Sonnet's lint passed broken flow YAML without PyYAML and escaped angle
  brackets, failed valid `{owner: kit}`, miscounted a 499-line body, and only warned on
  non-string descriptions and reference chains. Reproduced: `debate/cross-exam-scored.md`.
- **Self-lint during the build:** the lint treated `SKILL.md` mentioned in a body as a
  reference file; fixed, covered by the self-lint test.

## Scores

Lint (A1), 18-skill frozen corpus: both proposals 18/18 with PyYAML; without it, Sonnet 18/18,
Codex 9/18. Built lint: 18/18 in three modes (PyYAML, PyYAML blocked, macOS python3 3.9),
plus 13 guard fixtures (`tests/test_building_skills.sh`).

Triggers, tuning set (7 should / 7 near-miss, 3 runs, `runs/*.train.json`):

| Candidate | Bytes | Missed | Fired |
|---|---|---|---|
| sonnet-pruned | 160 | 0 | 0 |
| codex-pruned | 187 | 0 | 0 |
| codex-pushy | 644 | 0 | 0 |
| sonnet-pushy | 692 | 1 | 0 |

## Verdict (judge: Opus subagent, wrote nothing; `verdict.md`)

Hybrid on Sonnet's lint with strict PyYAML parsing when present and a named WARN when not;
the kit's `score_triggers.py` as trigger scorer; skill-creator located, never auto-picked
among differing copies; description `sonnet-pruned`, runner-up `codex-pruned`. 18 guards.

## Held-out check (frozen description, scored once)

`runs/sonnet-pruned.heldout.json`: **missed 1 of 4 should-trigger, fired 0 of 4 near-misses.**
Passes the B2 floor (≤ 1 and ≤ 1). The miss: "Turn what we just did, setting up the
diagnostics channel, into a skill" (0/3; the session went on without a skill). Recorded, not
tuned away; it is the first candidate for the skill's Learn step.

Listing probe in this repository: full description printed.

## Still open

1. Task evals (done; bar B3 passes): `claude plugin eval`, 3 cases, with and without the
   skill, 2 runs each (`runs/task-evals/summary.json`, $4.35). **With the skill 0.83, without 0.17; the
   skill wins every case** (fires-too-often 1.0 vs 0.0; repair-dropped-description 1.0 vs 0.5;
   new-skill-from-workflow 0.5 vs 0.0). Two cases first scored low because the cases lacked
   their input files (the agent rightly refused to invent them); fixed by giving them files.
   Open: in new-skill-from-workflow the agent wrote SKILL.md before its trigger queries (0/2).
   Step 3 was sharpened ("before SKILL.md exists"); re-run 1/2 (`runs/task-evals-step3/summary.json`).
   Not yet reliable: the next fix is a check, e.g. lint_skill.py failing when no queries file
   sits beside a new skill.
2. Field test (done, separate commit): the nine flagged descriptions were rewritten as `>-`
   blocks, wording unchanged (project-code-review: "<commit>" became "a commit"). All 19 kit
   skills pass `lint_skill.py` and Anthropic's `quick_validate.py`; a listing probe prints all
   nine descriptions. Held-out, scored with the hardened scorer (read-only tools, no MCP; API
   errors, synthetic error replies and timeouts counted apart from misses; 0 errors in these
   runs; `runs/five-skills.{before,after}.confined.json`): **before 2 of 10 should-trigger
   missed (session-report 2/2), after 0 of 10; near-misses 0 of 10 both.**
   Withdrawn along the way, each a scorer artefact: "session-report's wording is the fault"
   (unconfined run), "error-report misses 2/2" and "before 10/10" (a batch whose late runs
   failed silently: the API errors arrived as ordinary results; error-report fires 6/6 when
   re-run). The scorer now counts those as errors.
3. Codex fixtures (done): `empty-toc` (a contents heading with no list now FAILs
   RESOURCE-TOC; the lint had passed it), `empty-eval-dirs` (FAIL EVALS) and `legacy-evals`
   (three cases in evals.json count) are guards in `tests/test_building_skills.sh`.

Note: one tuning query named a real project; it was renamed to "the app's social posts" in
`trigger-sets/` and `runs/` after scoring, so the kit carries no project names.

Also renamed after scoring: tracked-bug numbers and a project skill name in the queries.
