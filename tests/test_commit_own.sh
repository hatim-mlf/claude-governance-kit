#!/usr/bin/env bash
# Tests for scripts/commit-own.sh: commit only your paths, refuse if HEAD moved.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/commit-own.sh"
fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }

new_repo() {
  local d; d="$(mktemp -d)"; cd "$d" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name t
  printf 'a1\n' > a.txt; printf 'b1\n' > b.txt; printf 'c1\n' > c.txt
  git add a.txt b.txt c.txt && git commit -q -m init
  printf 'commit message\n' > ../msg-$$.txt
}

# 1. Commits only the given paths; another session's staged file stays staged and out of the commit.
new_repo
printf 'a2\n' > a.txt                        # mine
printf 'b2\n' > b.txt; git add b.txt         # another session's, staged
"$SCRIPT" -F "../msg-$$.txt" -- a.txt >/dev/null 2>&1; rc=$?
check "exits 0" "[ $rc -eq 0 ]"
check "commit holds only a.txt" "[ \"\$(git show --name-only --format= HEAD)\" = a.txt ]"
check "a.txt committed" "[ \"\$(git show HEAD:a.txt)\" = a2 ]"
check "b.txt still staged, not committed" "[ \"\$(git diff --cached --name-only)\" = b.txt ] && [ \"\$(git show HEAD:b.txt)\" = b1 ]"
check "a.txt clean afterwards" "[ -z \"\$(git status --porcelain a.txt)\" ]"

# 2. A commit made by someone else between reading HEAD and moving it: refuse, lose nothing.
new_repo
printf 'a2\n' > a.txt
COMMIT_OWN_BEFORE_UPDATE='git -c core.hooksPath=/dev/null commit -q --allow-empty -m other' \
  "$SCRIPT" -F "../msg-$$.txt" -- a.txt >/dev/null 2>&1; rc=$?
check "refuses when HEAD moved" "[ $rc -ne 0 ]"
check "the other commit is still HEAD" "[ \"\$(git log -1 --format=%s)\" = other ]"
check "a.txt change still in the working tree" "[ \"\$(cat a.txt)\" = a2 ]"

# 3. A deleted path is committed as a deletion.
new_repo
rm c.txt
"$SCRIPT" -F "../msg-$$.txt" -- c.txt >/dev/null 2>&1; rc=$?
check "deletion exits 0" "[ $rc -eq 0 ]"
check "c.txt gone from HEAD" "! git cat-file -e HEAD:c.txt 2>/dev/null"

# 4. Nothing to commit for the given paths: refuse.
new_repo
"$SCRIPT" -F "../msg-$$.txt" -- a.txt >/dev/null 2>&1; rc=$?
check "refuses an empty commit" "[ $rc -ne 0 ]"
check "no new commit" "[ \"\$(git rev-list --count HEAD)\" = 1 ]"

# 5. Usage errors.
new_repo
"$SCRIPT" -- a.txt >/dev/null 2>&1; rc=$?
check "refuses without -F" "[ $rc -ne 0 ]"

exit $fail
