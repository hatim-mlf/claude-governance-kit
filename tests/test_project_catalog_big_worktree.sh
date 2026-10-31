#!/usr/bin/env bash
# The project catalog survives a working tree with thousands of changed paths.
#
# From EduFlow (2026-10-31): a whole-track verification run left many thousands of changed
# paths, `git status --porcelain -z` passed 1 MB, and execFileSync's default 1 MB buffer
# made the generator throw ENOBUFS, so the dashboard could not sync. EduFlow had fixed its
# copy locally (a 64 MB maxBuffer); this pins the fix in the kit.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v node >/dev/null || { echo "  - skipped: node not on PATH"; exit 0; }

target=$(fresh_install); cd "$target"
mkdir -p src/many && echo keep > src/many/keep.txt
git add -A && git commit -qm base --no-verify
# Untracked files beside a tracked one are listed one by one: ~20k x ~70 B > 1 MB.
python3 -I -c '
import os
for i in range(20000):
    open(os.path.join("src/many", "verification-capture-%05d-%s.txt" % (i, "x" * 40)), "w").close()'
bytes=$(git status --porcelain=v1 -z | wc -c)
[ "$bytes" -gt 1100000 ] || fail "test setup: porcelain output is only $bytes bytes"
(cd bug-tracker-dashboard/app && node scripts/generate-project-catalog.mjs) > "$SCRATCH/gen" 2>&1 \
  || { tail -5 "$SCRATCH/gen" >&2; fail "project catalog failed on a ${bytes}-byte git status"; }
ok "project catalog handles a ${bytes}-byte git status"
