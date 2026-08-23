---
paths:
  - "**/.claude/**"
  - "**/scripts/**"
---

# Project Invariant — a change to the governance system reaches the kit

**When you change how the system works — a rule, a skill, a script, the ledger format —
mirror the change into the governance kit (`governance.config.json` names its path) in the same session.**

## Why this rule exists

This kit is a snapshot of a governance system that lives in a working project. The moment
that project changes and the kit does not, every project running the kit is on a version
the origin has already moved past — and nobody finds out until one of them hits a defect
that was repaired upstream weeks ago.

This is `D0`'s class one level up. A stale document is a stale document; a stale *system*
is every other project inheriting a defect that has already been repaired.

## When it fires, and when it does not

The globs above are wide on purpose — the operator chose "everything under `.claude/` and
`scripts/`" over a narrower list, because a narrow list needs a judgement call at exactly
the moment nobody wants to make one.

**Mirror it** when the change is about how the system works:

- a rule in `.claude/rules/`
- a skill, or the provenance record in `.claude/skills/UPSTREAM.md`
- any script in `scripts/` — the hooks, the checks, the id helper
- the ledger format in `ledger/README.md`
- a generator under the dashboard's `scripts/`

**Do not mirror it** when the change is your project's own content, even though the glob matched:

- Invariants about *your* app's code — a rule naming your types, tables or subsystems.
  Their **shape** is worth carrying into the kit as a template; their content is not.
- Language- or platform-specific audit skills.
- Anything naming one of your bug numbers, tables or types.

**The test:** would a project that has never seen this app want the change? If yes, mirror
it. If it only makes sense next to one of your own modules, leave it where it is.

## What "mirror" means today

the governance kit (`governance.config.json` names its path) is a git repository with **one commit and no
remote** as of 2026-08-23 — the extraction landed, the publishing decision has not. So:

1. **Copy the change into the kit**, parameterised. Project-specific names, paths and bug
   numbers become placeholders; the mechanism survives, the content does not.
2. **Commit it there.**
3. **The push is the operator's step.** Creating a remote is outward-facing — it publishes
   the system under their name. Do not add a remote or push without being asked. Say in the
   ledger entry that the kit has an unpushed commit waiting.

Once a remote exists, tighten this rule to require the push. Requiring it before then makes
the rule unfollowable, and a rule that cannot be followed is one people learn to skip.

## The failure this prevents

Not a hypothetical. In one week the originating project gained `next-ledger-id.sh` after two
sessions collided on an id, four checks in `check-ledger-entries.sh` after six timestamps
were fabricated, and a `--staged` mode after the first version reported history on every
commit. Each is a repair another project would otherwise have to discover for itself, the
same expensive way.
