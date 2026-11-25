# Cross-examination — faults reproduced by the scorer

Fixtures: `scorer-fixtures/` (Codex's own were in memory only; its sandbox refused `mkdir`).
Sonnet's fixtures: `sonnet/cross/fixtures/`. Reference verdict: Anthropic's `quick_validate.py`
where it has a rule; otherwise the brief's rule. Run 2026-11-25.

| Fixture | Sonnet lint | Codex lint | Correct | Fault in |
|---|---|---|---|---|
| broken-flow (unclosed `[`) | FAIL with PyYAML, **PASS without** | FAIL | FAIL (validator) | Sonnet (stdlib fallback not strict) |
| flow-metadata `{owner: kit}` | **FAIL** | PASS | PASS (validator) | Sonnet |
| escaped-angle `"\x3c…\x3e"` | **PASS** | FAIL | FAIL (validator) | Sonnet |
| boolean-description | WARN only | FAIL | FAIL (validator) | Sonnet |
| body-499 | **FAIL** (counts 500) | PASS | PASS (499 < 500) | Sonnet |
| regex-example `build\d+` | PASS | **FAIL** | PASS | Codex |
| no PyYAML, valid skill | PASS | **dependency error** | PASS (bar A2/A4) | Codex |
| voice "chapter I" | PASS | **FAIL** | PASS | Codex (Sonnet's run) |
| plain-list TOC | PASS | **FAIL** | PASS (Anthropic example is a plain list) | Codex (Sonnet's run) |
| reference chain | WARN | FAIL | FAIL (one level deep) | Sonnet (conceded) |
| backslash in reference file | PASS | FAIL | FAIL | Sonnet (conceded) |
| non-string / integer name | PASS | FAIL | FAIL (validator) | Sonnet (conceded) |

Reading: a hand-written YAML subset cannot be as strict as a YAML parser (broken-flow,
flow-metadata, escaped-angle). Codex's lint is right more often on frontmatter; Sonnet's
avoids a hard dependency and false fails on prose heuristics (voice, TOC, regex).
