#!/bin/bash
# Entry point: lint always; trigger eval only when Anthropic's skill-creator is found.
# usage: eval_skill.sh SKILL_DIR EVAL_SET.json [extra run_eval.py args]
# exit: 0 ok, 1 lint failed, 3 skill-creator missing (lint still ran), 4 eval failed
here="$(cd "$(dirname "$0")" && pwd)"
skill="$1"; set_="$2"; shift 2 2>/dev/null
[ -n "$skill" ] || { echo "usage: eval_skill.sh SKILL_DIR EVAL_SET.json [run_eval.py args]" >&2; exit 2; }

echo "== lint (kit-owned, stdlib only)"
python3 "$here/lint_skill.py" --ship "$skill"; lint_rc=$?
[ $lint_rc -eq 0 ] && echo "lint: PASS" || echo "lint: FAIL (fix before the eval)"

find_creator() {  # first dir holding scripts/run_eval.py; env var wins, else newest copy
  [ -n "$SKILL_CREATOR_DIR" ] && [ -f "$SKILL_CREATOR_DIR/scripts/run_eval.py" ] && { echo "$SKILL_CREATOR_DIR"; return; }
  ls -dt "$HOME"/.claude/skills/skill-creator "$HOME"/.claude/skills/*/skill-creator \
     "$HOME"/.claude/skills/synced/*/skill-creator "$HOME"/.claude/plugins/*/*/*/skill-creator \
     "$HOME"/.claude/plugins/cache/*/*/*/skills/skill-creator ./.claude/skills/skill-creator 2>/dev/null |
  while read -r d; do [ -f "$d/scripts/run_eval.py" ] && { echo "$d"; break; }; done
}
sc="$(find_creator)"
if [ -z "$sc" ]; then
  cat >&2 <<MSG
== trigger eval: SKIPPED. Missing: Anthropic's skill-creator (needs scripts/run_eval.py).
   Searched: \$SKILL_CREATOR_DIR, ~/.claude/skills/**/skill-creator, ~/.claude/plugins/**/skill-creator, ./.claude/skills/skill-creator
   To get it: install the skill-creator plugin (claude-plugins-official), or copy
   github.com/anthropics/skills (skills/skill-creator), then either put it in ~/.claude/skills/
   or export SKILL_CREATOR_DIR=/path/to/skill-creator and run this again.
   Lint above is complete without it; only the trigger eval needs skill-creator.
MSG
  exit 3
fi
[ $lint_rc -eq 0 ] || exit 1
[ -f "$set_" ] || { echo "eval set not found: $set_" >&2; exit 2; }
echo "== trigger eval via $sc"
(cd "$sc" && python3 -m scripts.run_eval --eval-set "$(cd "$(dirname "$set_")" && pwd)/$(basename "$set_")" \
   --skill-path "$(cd "$skill" && pwd)" --runs-per-query 3 "$@") || exit 4
