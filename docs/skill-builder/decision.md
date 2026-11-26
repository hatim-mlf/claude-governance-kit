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

1. Task evals with and without the skill (bar B3): three cases are written in
   `.claude/skills/building-skills/evals/`; they need billed runs (`claude plugin eval` or
   skill-creator), not run yet.
2. Field test (done, separate commit): the nine flagged descriptions were rewritten as `>-`
   blocks, wording unchanged (project-code-review: "<commit>" became "a commit"). All 19 kit
   skills now pass `lint_skill.py` and Anthropic's `quick_validate.py`; a listing probe prints
   all nine descriptions. Held-out (`runs/five-skills.after.json`, neighbours now include
   building-skills): **missed 2 of 10 should-trigger (before: 3 of 10), fired 0 of 10.**
   audit-report recovered; **session-report still misses 2 of 2** with its description
   visible, so its wording, not its YAML, is now the fault. Next: rework session-report's
   description with `building-skills` steps 3-4 on fresh queries; this held-out set is spent.
3. Codex fixtures `empty-toc`, `empty-eval-dirs`, `legacy-evals` were never saved; the
   built lint covers the last two by design (only folders with `prompt.md` count; evals.json
   counted), but no fixture proves it yet.

Note: one tuning query named a real project; it was renamed to "the app's social posts" in
`trigger-sets/` and `runs/` after scoring, so the kit carries no project names.
