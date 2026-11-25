# Verdict: building-skills debate

Judge: an Opus subagent that wrote no proposal and no scorer, 2026-11-25. The runs used `python3 -I` and the stock `/usr/bin/python3` 3.9, which has no PyYAML.

## A. Hybrid, with Sonnet's lint as the base

- **A1.** Both lints get 9 of 9 right when PyYAML is present. On stock python3, Codex's lint fails every must-pass skill; Sonnet's still gets 9 of 9.
- **A3.** A tie: 250 lines against 266.
- **A4.** Sonnet needs no dependency; Codex needs one.

**Lost:** Codex's lint, on A1 (stock python3) and A4.

**PyYAML.** Strict parse when PyYAML is present. Otherwise print a named WARN that strict YAML was not verified. Guards 2 to 4 must give the same verdict in both modes, so the WARN never hides a known-wrong verdict.
- **Requiring PyYAML loses:** it fails A4, and A1 on stock python3.
- **Bare stdlib loses:** it silently passes `broken-flow` and `escaped-angle`.

**Trigger scorer: the kit's `score_triggers.py`, not `run_eval.py`.**
- The faults of `run_eval.py` are in `score_triggers.py`'s docstring; `frame.md` names only one.
- It scored the five skills as 5/10 missed; the true count is 3/10.
- It never tests the real SKILL.md.
- The train runs came from `score_triggers.py`, so held-out must too.
- Cost: 144 owned lines. None are copied, so they carry no drift risk.

**Finding skill-creator.** Only task evals and description tuning need it. Under A2, that step alone stops; lint and trigger scoring run without it. Lookup order:
1. `--skill-creator DIR`
2. `$SKILL_CREATOR_DIR`
3. a fixed search list

## B. Score `sonnet-pruned` on held-out

- **B2.** Held-out is unscored. On the tuning set, three candidates tie at 0 missed, 0 fired.
- **B4.** sonnet-pruned is smallest: 160 B, against 187 and 644.
- **Runner-up:** codex-pruned, the next smallest at 0/0.
- **Lost:** codex-pushy on B4 (644 B); sonnet-pushy on B2 (1 miss).

## Required guards

"Both modes" means with PyYAML present and with it blocked.

1. **Kit corpus.** The 9 must-flag fail with the right rule; the 9 must-pass pass. Holds in both modes and on python3 3.9.
2. `scorer-fixtures/broken-flow`: FAIL, both modes.
3. `scorer-fixtures/escaped-angle`: FAIL, both modes. Decode escapes before the angle check.
4. `scorer-fixtures/flow-metadata`: PASS, both modes.
5. `scorer-fixtures/boolean-description`: FAIL.
6. `desc-flow-list`: FAIL. `name-integer`: FAIL.
7. `scorer-fixtures/body-499`: PASS.
8. `reference-chain`: FAIL.
9. `backslash-in-reference`: FAIL.
10. `scorer-fixtures/regex-example`: PASS.
11. `voice-roman-i`: PASS. `toc-plain-list`: PASS.
12. `orphan-reference`: PASS with a WARN.
13. `no-pyyaml`: exit 0. It prints one `WARN STRICT-YAML-UNVERIFIED` when PyYAML is blocked, and none when present.
14. **Entry point, `grilling`.** PASS by default, FAIL EVALS with `--ship`. Today the entry point always passes `--ship`.
15. **skill-creator discovery.**
    - (a) The flag or the env var wins.
    - (b) One copy found: use it and print its path.
    - (c) Two or more found: exit 3 and list them. Never auto-pick.
    - (d) None found: exit 3, naming what is missing, the paths searched and how to get it.
16. **Message 15(d) with TMPDIR unwritable.** It still prints. This is unreproduced; write the fixture.
17. **`score_triggers.py --help` on python3 3.9.** It runs. Today `str | None` crashes it.
18. **Held-out settings.** Scored with `score_triggers.py`, 3 runs, `max_tool_calls` 6, the same corpus as train.

## Rejected outright

- Requiring PyYAML.
- Letting the newest skill-creator copy win. The three copies differ.
- `run_eval.py` as the trigger scorer.
- Codex's prose FAILs: the first-person "I" check, TOCs that must be links, regexes read as backslash paths.
- Using held-out results for anything beyond falling back to the runner-up.
- Turning `empty-toc`, `empty-eval-dirs` and `legacy-evals` into guards. Their fixtures were never saved; write them first.
