#!/usr/bin/env bash
#
# Does this project have its diagnostics channel, and if not, is that a decision?
# (.claude/rules/diagnostics-channel.md)
#
# Reads the "diagnostics" block of governance.config.json and prints one state:
#   implemented     — every one of the six parts names a path that exists
#   not-yet         — a "row" names the roadmap file where the channel is planned
#   not-applicable  — a "reason" says why (the project runs only where you can see it)
#
# Warn, never block: exits 1 when the block is missing, malformed, or an implemented
# project lost a part, so pre-commit prints it in yellow and the commit goes through.
# A decided state (not-yet with its row, not-applicable with its reason) is quiet, the
# same way FILE_SIZE_REVIEW.md's "Accepted" stops a file being flagged.
#
#   scripts/check-diagnostics.sh            # state + problems
#   scripts/check-diagnostics.sh --quiet    # problems only (pre-commit)
#
# Why: a tester's failed import reached the team of the project this kit came from only
# by chat; the app had a diagnostics channel and 74 of its 106 error-log sites were not
# wired to it. The rule existed as a paragraph in a CLAUDE.md template, which reached
# new installs only: 0 of 4 other governed projects had it.
set -uo pipefail

quiet=0
[ "${1:-}" = "--quiet" ] && quiet=1

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
config="$root/governance.config.json"
[ -f "$config" ] || { echo "Diagnostics check DID NOT RUN — no governance.config.json at $root"; exit 1; }

python3 -I - "$root" "$config" "$quiet" << 'PY'
import glob, json, os, sys

root, config, quiet = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
PARTS = {
    "intake": "server intake that validates, caps and purges",
    "devTag": "where dev/test builds are tagged apart",
    "contractTest": "contract test both client and server rules agree on",
    "featureReports": "typed start/outcome codes per feature",
    "reader": "the digest someone reads",
    "coverage": "the measure of what still reports nothing",
}
STATES = ("implemented", "not-yet", "not-applicable")
RULE = ".claude/rules/diagnostics-channel.md"

ROOT = os.path.realpath(root)

def exists(pattern):
    """A file inside the repository matches: no absolute path, no "..", no bare directory.
    A trailing "#anchor" (a row inside a roadmap file) is ignored."""
    path = pattern.rsplit("#", 1)[0].strip() if "#" in pattern else pattern.strip()
    if not path or os.path.isabs(path) or ".." in path.replace("\\", "/").split("/"):
        return False
    for match in glob.glob(os.path.join(ROOT, path), recursive=True):
        real = os.path.realpath(match)
        if os.path.isfile(real) and real.startswith(ROOT + os.sep):
            return True
    return False

def text(value):
    return value.strip() if isinstance(value, str) else ""

try:
    block = json.load(open(config)).get("diagnostics")
except ValueError as e:
    print("Diagnostics check DID NOT RUN — governance.config.json is not valid JSON: %s" % e)
    sys.exit(1)

problems, info = [], []
if not isinstance(block, dict):
    problems.append('no "diagnostics" block in governance.config.json: set its state to '
                    "implemented, not-yet (with its row) or not-applicable (with its reason). See %s" % RULE)
else:
    state = block.get("state")
    parts = block.get("parts") if isinstance(block.get("parts"), dict) else {}
    if "parts" in block and not isinstance(block.get("parts"), dict):
        problems.append("diagnostics.parts must be an object of part -> path")
    present = [p for p in PARTS if isinstance(parts.get(p), str) and exists(parts[p])]
    if state not in STATES:
        problems.append('diagnostics.state is %r; expected one of %s' % (state, ", ".join(STATES)))
    elif state == "not-applicable":
        if not text(block.get("reason")):
            problems.append("diagnostics.state is not-applicable with no reason written")
        else:
            info.append("diagnostics: not applicable — %s" % text(block["reason"]))
    elif state == "not-yet":
        row = text(block.get("row"))
        if not row:
            problems.append("diagnostics.state is not-yet with no row: name the roadmap file that plans the channel")
        elif not exists(row):
            problems.append("diagnostics.row names %s, which is not a file in this repository" % row)
        else:
            info.append("diagnostics: not yet — planned in %s; %d of %d parts present" % (row, len(present), len(PARTS)))
    else:
        if not text(block.get("backend")):
            problems.append("diagnostics.state is implemented with no backend named")
        for p, what in PARTS.items():
            if p not in present:
                given = parts.get(p)
                problems.append("diagnostics.parts.%s (%s): %s" % (
                    p, what, "missing" if not given else "%s is not a file in this repository" % given))
        if not problems:
            info.append("diagnostics: implemented (%s) — %d of %d parts present" % (text(block["backend"]), len(present), len(PARTS)))

if not quiet:
    for line in info:
        print(line)
for line in problems:
    print("Diagnostics: " + line)
sys.exit(1 if problems else 0)
PY
