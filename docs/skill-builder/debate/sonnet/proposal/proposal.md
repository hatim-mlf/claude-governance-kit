# building-skills: proposal (Sonnet)

## Decision A: hybrid. Own the lint, borrow the eval.

The kit owns two files, 250 lines in all:
- `lint_skill.py` (python3 stdlib only). It holds every rule that decides whether a skill is valid and visible, and does not depend on skill-creator.
- `eval_skill.sh` (bash 3.2). It runs the lint, then finds skill-creator and calls its `scripts.run_eval`. No skill-creator code is copied into the kit.

`run_corpus.sh` is a test helper, not shipped.

**Finding skill-creator.** Search order: `$SKILL_CREATOR_DIR`, then `~/.claude/skills/**/skill-creator`, `~/.claude/plugins/**/skill-creator`, `./.claude/skills/skill-creator`. A folder counts only if it holds `scripts/run_eval.py`. If several match, the newest wins.

**When skill-creator is absent** (`absent-run.txt`): lint still runs in full. The eval step stops with exit 3 and names what is missing (`scripts/run_eval.py` of skill-creator), where it searched, and how to get it (install the plugin, or copy `skills/skill-creator` from github.com/anthropics/skills and set `SKILL_CREATOR_DIR`).

**Why not the alternatives.** Standalone re-owns `run_eval` and `run_loop` (hundreds of lines whose three local copies already differ), so A3 and A4 lose. A pure orchestrator fails A2, because lint would die with skill-creator, and lint is the part the incident needs.

**PyYAML.** The lint has its own frontmatter reader for the subset skills use. It applies the rule behind the incident: an unquoted value may not contain `: `. If PyYAML is importable it adds a second opinion; its absence changes nothing. I ran the whole corpus with `yaml` blocked and the output was identical.

**Scope.** FAIL: name, description, unknown keys, body length, backslash paths, reference TOC, extra `SKILL.md`. WARN: Claude Code-only keys, reference depth and chaining, voice. `--ship` adds the 3-eval gate; it is off by default because no corpus skill has evals.

**Corpus result** (`lint-run.txt`): 9 PASS, 9 FAIL, 1 SKIP (`modules/diagnostics`, which holds no skill). The nine FAIL lines are exactly the nine must-flag skills, each naming its rule. The nine PASS lines are exactly the nine must-pass skills.

## Decision B: two descriptions

Pruned, 159 B (`desc-pruned.txt`):
> Take a skill idea to a shipped skill, with lint and trigger tests. Use on "make a skill", "new SKILL.md", "my skill never triggers", "fix a skill description".

Pushy, 691 B (`desc-pushy.txt`): "Make sure to use this skill whenever..." with contexts listed and a "Not for..." tail. Neither contains angle brackets.

**Expected winner on held-out triggering: pruned.** This is a prediction; the scorer measures it.
- B4 is certain: 159 B against 691 B.
- On B2 I expect a tie. The near-misses will sit close to skill-creator and `skill-create` ("write a slash command"). The pushy "even if they only say..." clause is the kind that fires on those.
- A tie goes to the simpler option.
- Pruned loses if a held-out should-trigger query shares no wording with its four quoted phrases.

## Known weaknesses
1. The lint cannot tell which `: ` descriptions Claude Code drops. swift-xcode-audit has the same shape as session-report but loads. Its flag is right (strict YAML fails), but the reason text says "may".
2. Claude Code-only keys are checked by name, not by value.
3. The built-in reader is a subset of YAML. Flow mappings and anchors read as plain text.
4. "Scripts solve rather than punt" and "no unexplained constants" are only partly checkable (one `except: pass` heuristic).
5. The skill-creator search paths are guesses at install layouts. Only `$SKILL_CREATOR_DIR` is certain.
6. No trigger scores here; I was told not to run them.
