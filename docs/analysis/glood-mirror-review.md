# GLOOD mirror review — 2026-10-31

`./update.sh --collect` on GLOOD sent back 22 kit-owned files whose content the kit had
never had (branch `mirror/glood`, `9e3aac7`). For each file, the base was taken as the
kit version closest to GLOOD's copy, and only GLOOD's own delta was read.

## Verdict: not merged as a branch

Nearly all of the delta is **GLOOD's own specifics**: the dashboard imports
`glood-paths.mjs` (the kit's is `project-paths.mjs`), plus `GLOOD/GLOODApp.swift`, the
external Xcode root, `Secrets.xcconfig`, "TestFlight", "rider", real row ids (`U-15`,
`U-63`), and skills retitled "— GLOOD" with Swift-specific guidance. The kit holds the
generalised form of these on purpose. In several places **the kit is ahead of GLOOD**:
evidence patterns that accept `.py`/`.ts`, a bug catalog that tolerates a missing
`STRUCTURAL_PROBLEMS.md`, and every fix from PRs #2–#4. Merging the branch would have
undone both.

## Taken into the kit

| From GLOOD | Where it went |
|---|---|
| Ledger catalog maps retired week-file paths (`ledger/2026-W33.md` → `ledger/2026-W33`) | `generate-ledger-catalog.mjs` `canonicalPath` |
| Ledger catalog counts cited directories as touched | same |
| `marketing/…` → `docs/marketing/…` path mapping | **Not** hard-coded. It became the general `pathAliases` key in `governance.config.json`; GLOOD declares its own move there |
| Pre-commit says "Reports check DID NOT RUN" when `check-reports.sh` is missing | `scripts/pre-commit.sh` |

Pinned by `tests/test_ledger_catalog_paths.sh`.

## Left in GLOOD

`check-dashboard-bug-ids.sh` (GLOOD-only, not shipped by the kit), GLOOD's tailored
skills, and its `glood-paths.mjs` dashboard. GLOOD's copies of kit files are **forks**:
`update.sh` keeps them (reporting them as diverged), and this branch's kit changes reach
them only by hand-porting. GLOOD's config needs this for its moved marketing paths:

```json
"pathAliases": [
  { "from": "^marketing/(content-system|tracker)(?=/|$)", "to": "docs/marketing/$1" }
]
```
