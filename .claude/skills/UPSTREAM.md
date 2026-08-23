# Vendored skills — provenance

Five of the skills in this directory derive from a third-party repository, copied and
kept byte-for-byte identical to upstream, so re-syncing is a diff rather than an
archaeology exercise. **If you need to change one of these skills, that is the moment
it stops being vendored** — record the fork here and stop claiming upstream parity,
because a modified file that still says "byte-for-byte identical" is worse than no
provenance record at all.

**Upstream:** https://github.com/mattpocock/skills
**Commit:** `5b15a47f2d7150f545fbcacbfe381787fc0230dc`
**Dated:** 2026-08-21 (upstream `v1.2.3`)
**Licence:** MIT — full text below, as the licence requires.

## What was taken

| Directory | Upstream path | Files |
|---|---|---|
| `grilling/` | `skills/productivity/grilling/` | `SKILL.md` |
| `grill-me/` | `skills/productivity/grill-me/` | `SKILL.md` |
| `writing-for-agents/` | `skills/productivity/writing-for-agents/` | `SKILL.md`, `SKILL-MECHANICS.md` |
| `diagnosing-bugs/` | `skills/engineering/diagnosing-bugs/` | `SKILL.md`, `scripts/hitl-loop.template.sh` |
| `codebase-design/` | `skills/engineering/codebase-design/` | `SKILL.md`, `DEEPENING.md`, `DESIGN-IT-TWICE.md` |

**The one deliberate difference from upstream:** `agents/openai.yaml` was dropped from
every directory. It configures invocation policy for Codex, and there is no Codex
harness here. A re-sync will show these as the only missing files; that is expected,
not drift.

## Re-syncing

```sh
git clone --depth 1 https://github.com/mattpocock/skills /tmp/mp-skills
for pair in productivity/grilling productivity/grill-me productivity/writing-for-agents \
            engineering/diagnosing-bugs engineering/codebase-design; do
  diff -r --exclude=agents "/tmp/mp-skills/skills/$pair" ".claude/skills/$(basename "$pair")"
done
```

Clean output means we are current. Update the commit SHA and date above whenever you
take a newer version, in the same commit that takes it.

## Forks — derived, not vendored

Three were taken as **forks**, not vendored copies. They are **not** upstream code and
carry no parity claim: the discipline was kept, everything else was rewritten to be
project-agnostic and to route into this kit's registers. Do not diff them against
upstream.

| Fork | Derived from | What changed |
|---|---|---|
| `tdd/` | `skills/engineering/tdd/` | Test framework left unnamed so the skill works in any language; a fourth anti-pattern (asserting nothing); the closing note that a green test is not the tracker's *Fixed, verified* state |
| `project-code-review/` | `skills/engineering/code-review/` | Two independent axes run as parallel sub-agents — Standards reads `CLAUDE.md` and `.claude/rules/`, Spec reads the commissioning ledger entry or session prompt; a matching path-scoped rule is a hard violation; output goes to `audit-report` |
| `to-tickets/` | `skills/engineering/to-tickets/` | Rows land in `docs/roadmap/phase_XX_*.md` tables rather than GitHub Issues; the three-register routing; each row must state how it is verified |

## Written here

Six skills have no upstream. They are listed so the generated catalog can tell "we wrote
this" apart from "nobody recorded where this came from" — which are very different
things, and the reason `unrecorded` is a finding rather than a default.

| Directory | What it is | First recorded |
|---|---|---|
| `bug-report/` | The format for a defect in app or dashboard behaviour | inherited from the originating project |
| `error-report/` | The format for a failed command, build or migration | inherited from the originating project |
| `audit-report/` | The shared shape for any multi-finding sweep | inherited from the originating project |
| `session-report/` | What a working session actually did | inherited from the originating project |
| `session-prompt/` | The commission for the next session | inherited from the originating project |
| `dashboard-sync/` | How the dashboard is kept current from the ledger and reports | inherited from the originating project |

The optional `modules/swift-xcode/swift-xcode-audit/` skill is also written-here, and is
outside this directory on purpose: it is toolchain-specific, so it is not part of the
core kit and does not appear in the catalog until you install it.

## Keeping this file honest

`<dashboard>/scripts/generate-skills-catalog.mjs` reads the three tables above and
cross-references them against the directories on disk. **The section a row sits in
decides its origin**, so a row in the wrong section is silently mis-labelled — and a
skill with no row at all comes out `unrecorded` and is named in the generator's output.
That is the mechanism behind `.claude/rules/skills-stay-indexed.md`: adding a skill
quietly is not possible, because the next sync says so.

---

## MIT Licence

Reproduced in full, as the licence requires of anyone distributing substantial portions
of the software. It covers the five vendored directories listed above.

```
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
