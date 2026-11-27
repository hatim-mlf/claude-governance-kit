#!/usr/bin/env bash
# Start a session prompt in a new Terminal window, with Remote Control on, so the operator can
# follow it from another device. macOS Terminal only.
#
# usage: launch-session.sh [--bypass] [--dry-run] [--model NAME] PROMPT_FILE SESSION_NAME
#
#   --bypass   add --dangerously-skip-permissions. Off by default: pass it only when the
#              operator's own message asks for bypassed permissions for THIS session.
#   --dry-run  print the command instead of opening a window (used by the test).
#   --model    opus | sonnet | haiku | fable. Default: the first word after "Suggested model:"
#              in the prompt file; if there is none, the launch is refused (exit 2).
#
# Exit codes: 0 launched (or printed), 2 bad usage or input, 3 Terminal could not be opened.
set -euo pipefail

usage() { sed -n '5,13p' "$0" >&2; exit 2; }

bypass=0 dry=0 model=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bypass) bypass=1; shift ;;
    --dry-run) dry=1; shift ;;
    --model) [ $# -ge 2 ] || usage; model="$2"; shift 2 ;;
    -h|--help) usage ;;
    --*) echo "unknown option: $1" >&2; usage ;;
    *) break ;;
  esac
done
[ $# -eq 2 ] || usage
prompt="$1" name="$2"

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
case "$prompt" in /*) abs="$prompt" ;; *) abs="$root/$prompt" ;; esac
[ -f "$abs" ] || { echo "prompt file not found: $prompt" >&2; exit 2; }

# Remote Control shows this name on the other device; keep it short and shell-safe.
[[ "$name" =~ ^[a-z0-9][a-z0-9-]{2,63}$ ]] || {
  echo "session name must be 3-64 chars of a-z, 0-9 and '-': $name" >&2; exit 2; }

if [ -z "$model" ]; then
  model="$(grep -m1 -i '^Suggested model:' "$abs" | sed -E 's/^[^:]*:[[:space:]]*//' \
    | grep -oiE '^(opus|sonnet|haiku|fable)' | tr '[:upper:]' '[:lower:]' || true)"
  [ -n "$model" ] || { echo "no 'Suggested model:' line in $prompt; pass --model" >&2; exit 2; }
fi
case "$model" in opus|sonnet|haiku|fable) ;; *) echo "unknown model: $model" >&2; exit 2 ;; esac

rel="${abs#"$root"/}"
message="Run the session prompt $rel. Follow the project's CLAUDE.md fully: reserve your own \
ledger entry from the id script (other sessions may be running in this repository). Every \
stop-and-report gate in the prompt and in CLAUDE.md binds whatever the permission mode: stop \
and report rather than deciding past one."

cmd=(claude)
[ "$bypass" -eq 1 ] && cmd+=(--dangerously-skip-permissions)
cmd+=(--model "$model" --remote-control "$name" "$message")

line="cd $(printf %q "$root") && exec$(printf ' %q' "${cmd[@]}")"
if [ "$dry" -eq 1 ]; then printf '%s\n' "$line"; exit 0; fi

launcher="$(mktemp -t "launch-$name")"
printf '#!/bin/zsh\n%s\n' "$line" > "$launcher"
chmod +x "$launcher"
osascript -e "tell application \"Terminal\" to do script \"$launcher\"" \
          -e 'tell application "Terminal" to activate' >/dev/null || {
  echo "could not open a Terminal window; run it by hand: $launcher" >&2; exit 3; }
echo "launched $name ($model$([ "$bypass" -eq 1 ] && echo ', permissions bypassed')): $launcher"
