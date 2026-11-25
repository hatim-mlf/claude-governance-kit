# Path-scoped rules

Invariants that only matter when a specific kind of file is touched live here, with
a `paths:` frontmatter glob, so they load when matching code is opened instead of on
every session.

```markdown
---
paths:
  - "**/managers/**/*.ts"
  - "**/*Store.ts"
---

# Project Invariant — <name>

<The invariant, and the reason it exists — the incident that motivated it.>
```

## Where a new invariant goes

- If it only matters when a specific file pattern is touched → a rule here, with the
  reason kept attached.
- If it applies to every task no matter what is touched → `CLAUDE.md`.

Deciding this each time is what stops CLAUDE.md regrowing into a manual nobody reads.

## Writing one well

- Scope the globs from the codebase, not by guessing: count where the pattern
  actually lives, and list outliers by name when a glob cannot reach them.
- State when the rule fires *and* when it does not — a rule without a negative case
  gets applied to everything and then ignored.
- Keep the incident. "Two leaks were found in one session because nothing
  compiler-visible flags this" is what makes the rule survive contact with a busy
  session.

See `domain-terms-stay-current.md` for a working example.
