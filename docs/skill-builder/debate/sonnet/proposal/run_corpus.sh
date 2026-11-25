#!/bin/bash
# one line per skill: PASS/FAIL + reason. usage: run_corpus.sh CORPUS_DIR
c="$1"; here="$(cd "$(dirname "$0")" && pwd)"
for d in "$c"/skills/*/ "$c"/modules/*/; do
  d="${d%/}"
  case "$d" in */modules/*) rel="modules/${d##*/}" ;; *) rel="skills/${d##*/}" ;; esac
  t="$d"
  if [ ! -f "$d/SKILL.md" ]; then
    t=""; for s in "$d"/*/; do [ -f "$s/SKILL.md" ] && t="${s%/}"; done
    if [ -z "$t" ]; then
      [ "$rel" = "skills/${d##*/}" ] && [ ! -f "$d/SKILL.md" ] || { echo "SKIP $rel: no SKILL.md (support folder, not a skill)"; continue; }
    fi
  fi
  [ -n "$t" ] || { echo "SKIP $rel: no SKILL.md"; continue; }
  out="$(python3 "$here/lint_skill.py" "$t")"; rc=$?
  w="$(printf '%s\n' "$out" | grep -c '^WARN')"
  if [ $rc -eq 0 ]; then echo "PASS $rel (${w} warn)"
  else echo "FAIL $rel: $(printf '%s\n' "$out" | grep '^FAIL' | sed 's/^FAIL //' | cut -c1-300 | tr '\n' '|')"; fi
done
