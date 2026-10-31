#!/usr/bin/env bash
#
# Warn when a commit changes a kit-owned file beyond anything the kit has.
#
# The rule (.claude/rules/changing-the-governance-system.md, step 3) says every change to
# how the system works is mirrored into the kit and pushed. In GLOOD, the project this kit
# came from, 22 kit-owned files had changed without reaching the kit (2026-10-31),
# including a generator fix every project needed. A prose rule depends on a session
# remembering it; this makes the commit remember.
#
# A staged kit-owned file warns only when its exact content appears nowhere in the kit's
# history. A file that is merely BEHIND the kit is quiet (update.sh will bring it
# forward), and so is one listed in governance.config.json `kit.projectOwned`: a version
# the project keeps on purpose.
#
#   scripts/check-kit-drift.sh     # staged files (pre-commit)
#
# Warn-tier: exit 1 means findings, printed to stdout. Nothing is blocked. With no `kit`
# entry in the config it says so once and exits 0: an unconfigured project is not an
# error, but a check that never says it is not running is.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
config="$root/governance.config.json"
[ -f "$config" ] || exit 0
command -v python3 >/dev/null || { echo "Kit drift check DID NOT RUN — needs python3."; exit 1; }

# kit.path, the dashboard dir, then one projectOwned path per line.
read_config() {
  python3 -I - "$config" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
k = c.get("kit") or {}
print(k.get("path", "") if k.get("path") != "KIT_PATH" else "")
print((c.get("dashboard") or {}).get("dir", "bug-tracker-dashboard/app"))
for p in k.get("projectOwned") or []: print(p)
PY
}
cfg=$(read_config) || { echo "Kit drift check DID NOT RUN — governance.config.json is not valid JSON."; exit 1; }
kit=$(printf '%s\n' "$cfg" | sed -n 1p)
dash=$(printf '%s\n' "$cfg" | sed -n 2p)
owned_list=$(printf '%s\n' "$cfg" | sed -n '3,$p')

if [ -z "$kit" ]; then
  echo "Kit drift check: no kit.path in governance.config.json, so changes to kit files are not compared with the kit."
  exit 0
fi
[ "$(cd "$kit" 2>/dev/null && pwd -P)" = "$(cd "$root" && pwd -P)" ] && exit 0   # this IS the kit
git -C "$kit" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "Kit drift check DID NOT RUN — kit.path ($kit) is not a git checkout."; exit 1; }

# Project path -> kit path, for the files the kit owns. Anything else is the project's.
kit_path_for() {
  case "$1" in
    scripts/*/*) return 1 ;;                         # project code under scripts/
    scripts/*.sh) echo "$1" ;;
    .claude/rules/changing-the-governance-system.md) echo "$1" ;;
    .claude/skills/UPSTREAM.md) return 1 ;;           # project's provenance record
    .claude/skills/*) echo "$1" ;;
    "$dash"/scripts/*.mjs) echo "dashboard/app/scripts/${1#"$dash"/scripts/}" ;;
    *) return 1 ;;
  esac
}

blobs=$(mktemp); trap 'rm -f "$blobs"' EXIT
git -C "$kit" rev-list --all --objects 2>/dev/null | cut -d' ' -f1 | sort -u > "$blobs"

findings=()
while IFS= read -r -d '' f; do
  kp=$(kit_path_for "$f") || continue
  [ -e "$kit/$kp" ] || continue                       # a project-only skill or script
  printf '%s\n' "$owned_list" | grep -qxF -- "$f" && continue
  blob=$(git rev-parse ":$f" 2>/dev/null) || continue # deleted in this commit
  grep -qxF "$blob" "$blobs" && continue              # the kit has had this exact version
  findings+=("$f")
done < <(git diff --cached --name-only -z --diff-filter=AM)

[ ${#findings[@]} -eq 0 ] && exit 0
echo "Kit-owned files changed beyond the kit — ${#findings[@]} — mirror them, or keep them as this project's own:"
printf '  %s\n' "${findings[@]}"
echo "  Mirror: copy into $kit, parameterise anything project-specific, commit and push"
echo "          (.claude/rules/changing-the-governance-system.md, step 3)."
echo "  Or keep: add the path to kit.projectOwned in governance.config.json."
exit 1
