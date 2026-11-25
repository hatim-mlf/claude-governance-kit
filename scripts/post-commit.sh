#!/usr/bin/env bash
#
# post-commit hook — claude-governance-kit. Installed by scripts/install-hooks.sh.
#
# After a commit that touches obligations/ or ledger/, sync the obligations to Notion and
# Apple Reminders in the background (scripts/obligations-sync.sh --hook). It never slows or
# fails a commit: the sync runs detached, and its outcome goes to a log outside the repo.
# Why a hook and not a schedule: the kit has no cron (a scheduler would be a second writer),
# and a commit is exactly the moment the register changes.
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -x "$root/scripts/obligations-sync.sh" ] || exit 0
changed=$(git -C "$root" diff-tree --root --no-commit-id --name-only -r HEAD -- obligations ledger 2>/dev/null | head -1)
[ -n "$changed" ] || exit 0
(cd "$root" && nohup ./scripts/obligations-sync.sh --hook >/dev/null 2>&1 &)
exit 0
