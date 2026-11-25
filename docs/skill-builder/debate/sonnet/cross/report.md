# Cross-examination (Sonnet side)

Runs: `runs.txt` (`bash run.sh`). Fixtures: `fixtures/`.

## Faults in the other design

| Fault | Fixture | Other | Mine | Correct, and source |
|---|---|---|---|---|
| Lint dies without PyYAML | no-pyyaml (tdd, `yaml` import blocked) | FAIL rc=1, "install PyYAML in a venv" | PASS rc=0 | PASS. Frame bar A2 (lint must still run) and A4 (stdlib only). `check_skill.py` imports the same module, so the whole entry point is affected. |
| Rejects "I" in a Roman numeral as first person | voice-roman-i ("chapter I of a report") | FAIL "voice" | PASS | PASS. Anthropic says third person; this is third person. |
| Rejects a TOC with no links | toc-plain-list (110 lines, plain bullet list under "Contents") | FAIL | PASS | PASS. Anthropic's own best-practices example is a plain list. |
| Rejects an unlinked file in `references/` | orphan-reference | FAIL "link directly" | PASS | Debatable. This is guidance (best practices), not a validator rule. A WARN fits better than FAIL. |

## Faults in my design (conceded, each with a run)

| Fault | Fixture | Other | Mine | Correct, and source |
|---|---|---|---|---|
| Non-string description passes | desc-flow-list (`[a, b]`) | FAIL | PASS | FAIL. `quick_validate.py`: "Description must be a string". |
| Integer name passes | name-integer (`name: 123`) | FAIL | PASS (warn only) | FAIL. Same validator: "Name must be a string". |
| Backslash path in a reference file is missed | backslash-in-reference | FAIL | PASS | FAIL. Anthropic checklist: forward slashes. I only scan SKILL.md. |
| Reference chain is only a WARN | reference-chain (SKILL.md to a.md to b.md) | FAIL | PASS (WARN) | FAIL. Anthropic: one level deep. The WARN was too weak. |

I rebut none. All four are real and cheap to fix.

## Questions (no run)
- Does Claude Code drop swift-xcode-audit's description? Both lints flag it; no run settles it.
- Other's `check_skill.py` not run beyond its imports.

## What I would adopt
- Its complete-case count for `--release`.
- Its string-type and duplicate-key checks.
- Its backslash scan over references; chaining as FAIL.
- Its `--skill-creator DIR` flag, safer than my newest-copy search.

I would not adopt the PyYAML hard dependency.
