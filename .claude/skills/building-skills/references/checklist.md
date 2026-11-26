# Skill checklist

Contents: commands · bars · lint rules · eval case layout · Anthropic's checklist · sources

## Commands (paths relative to this skill's folder)

```sh
python3 scripts/lint_skill.py [--ship] SKILL_DIR      # 0 pass, 1 fail, 2 usage
python3 scripts/score_triggers.py --corpus PROJECT/.claude/skills \
  --queries tuning.json --candidate NAME --desc-file desc.txt --runs 3 --out run.json
                                                       # add --runner codex to score with Codex
python3 scripts/score_triggers.py --corpus PROJECT/.claude/skills --queries map.json
                                                       # existing skills: {"name": [queries]}
python3 scripts/find_skill_creator.py [--skill-creator DIR]   # 0 found, 3 missing or ambiguous
```

`score_triggers.py` copies the neighbour skills into a throwaway project per run, writes the
candidate as a real `SKILL.md`, and watches up to 6 tool calls (the model often runs `ls`
before choosing a skill). Each run calls `claude -p`: about 3 × queries calls per description.

## Bars

| Check | Passes when |
|---|---|
| Lint | zero FAIL; `--ship` adds ≥ 3 eval cases |
| Tuning set | ≤ 1 should-trigger missed, ≤ 1 near-miss fired (3 runs, majority) |
| Held-out | same bar, scored once, after the description is frozen |
| Task evals | with-skill pass rate above without-skill |
| Listing probe | the full description is printed for the skill |
| Library budget | the sum of all descriptions stays small: each one is loaded on every turn |

## Lint rules

FAIL: FRONTMATTER, YAML-COLON, YAML-FLOW, YAML-QUOTE, YAML-TAB, YAML-DUPLICATE, YAML-LINE,
YAML-INDICATOR, YAML-PARSE (only when PyYAML is installed), NAME-MISSING,
NAME-TYPE, NAME-LENGTH (64), NAME-CHARS, NAME-RESERVED (anthropic, claude), DESC-MISSING,
DESC-TYPE, DESC-EMPTY, DESC-LENGTH (1,024), DESC-ANGLE, BODY-LENGTH (500), PATH-BACKSLASH,
RESOURCE-TOC (100 lines), RESOURCE-CHAIN, SKILL-MD, SKILL-MD-COUNT, EVALS (`--ship`).

WARN: STRICT-YAML-UNVERIFIED (no PyYAML), KEY-UNKNOWN (in neither key list; the Claude Code
list was read from a truncated docs page, so an unlisted key is not proof of an error),
KEY-CLAUDE-CODE-ONLY (allowed in Claude Code,
rejected by claude.ai and the Skills API), NAME-FOLDER, DESC-VOICE, DESC-WHEN,
RESOURCE-ORPHAN, SCRIPT-PUNT.

## Eval case layout (the one `claude plugin eval` reads)

```
evals/<case-name>/prompt.md        settings block (tags, max_turns, timeout_seconds,
                                   allowed_tools), then the prompt as a user types it
evals/<case-name>/case.yaml        schema_version: "1.1", name, expected_outcome: |
evals/<case-name>/graders/NN-*.md  ---\ntype: llm\nfocus: trace\nweight: 1\n---\n<one statement>
evals/<case-name>/files/           input files, if any; then add place-files.sh, end the
                                   prompt with "Input files: ...", and set
                                   context: {scaffold_script: place-files.sh} in case.yaml
```

## Anthropic's checklist for effective skills

Core: description is specific with key terms; says what and when; body under 500 lines;
details in separate files; no time-sensitive information; consistent terms; concrete
examples; references one level deep; progressive disclosure; clear workflow steps.
Scripts: solve rather than punt; explicit error handling; no unexplained constants; packages
listed and verified; documented; forward slashes; validation for critical operations;
feedback loops for quality-critical tasks.
Testing: at least three evaluations; tested on the models that will run it; real usage
scenarios; team feedback.

## Sources

- platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (limits, checklist)
- code.claude.com/docs/en/skills (Claude Code frontmatter keys, locations)
- Anthropic `skill-creator` (Apache-2.0): `quick_validate.py` rules, eval case schema
- How it was designed and measured: `docs/HOW-IT-WORKS.md` in the skill-builder repository
