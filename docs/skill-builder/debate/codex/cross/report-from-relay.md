['schema', 'workdir', 'sandbox', 'model', 'resumeLast', 'codexVersion', 'startedAt', 'finishedAt', 'briefPath', 'eventsPath', 'finalPath', 'status', 'exitCode', 'signal', 'threadId', 'finalMessage', 'touchedFiles']
Both unmodified linters ran against in-memory fixtures. Anthropic’s bundled validator confirmed the YAML verdicts. `other/` contained no counterfixtures, so I tested likely objections to my lint. Claude was never invoked.

| Fault | Fixture | Other lint | My lint | Correct verdict and source |
|---|---|---|---|---|
| Escaped angle brackets | `escaped-angle` | PASS | FAIL | FAIL. YAML decodes `\x3c` to `<`. Anthropic validator. |
| Boolean description | `boolean-description` | PASS, warning | FAIL | FAIL. Description must be a string. Anthropic validator. |
| Unclosed YAML sequence | `broken-flow` | PASS without PyYAML, FAIL with it | FAIL with PyYAML | FAIL. Optional PyYAML changes the verdict. Anthropic validator. |
| Valid flow mapping | `flow-metadata` | FAIL, colon | PASS | PASS. `metadata: {owner: kit}` is valid. Anthropic validator. |
| Final newline counted twice | `body-499` | FAIL, 500 lines | PASS | PASS. The body has 499 lines. Brief. |
| Two-hop reference | `reference-chain` | PASS, warning | FAIL | FAIL. The second file needs a direct link. Brief. |
| Heading accepted as TOC | `empty-toc` | PASS | FAIL | FAIL. The long reference has no contents list. Brief. |
| Empty directories counted as evals | `empty-eval-dirs` | PASS | FAIL | FAIL. No cases have prompts or graders. Anthropic schemas. |
| **My lint** mistakes regex for a path | `regex-example` | PASS | FAIL | PASS. `build\d+` is a regex. Brief’s path rule. |
| **My lint** drops legacy evals | `legacy-evals` | PASS | FAIL | PASS. The schema recognizes all three cases. Anthropic schemas. |
| **My lint** requires PyYAML | `missing-pyyaml` | PASS | Dependency error | Valid skill. I concede the dependency cost under A4. |
| Missing-provider guidance fails on read-only Bash 3.2 | Existing `grilling` | Exit 3, temporary-file error | Exit 2, install guidance | A2 requires recovery instructions. The other proposal’s saved run showed them under writable conditions. |

I’d adopt the other design’s stable rule IDs and support for legacy eval cases.

**Open question.** Does automatic provider selection preserve the intended scratch project and its neighboring skills?

**Other design:** Eight lint faults reproduced, plus a conditional A2 failure.  
**My design:** Two false failures reproduced, plus the PyYAML dependency cost.  
**Artifacts:** The workspace denied `mkdir cross`, so the fixtures, raw outputs, and report could not be saved there.
