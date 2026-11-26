---
name: decide-by-debate
description: >-
  Choose between competing fixes by debate: bars first, proposals made apart, faults shown by
  runs, one scorer, a judge who wrote none. Use when more than one fix is credible, or on
  "debate".
---

# Decide by debate

One mind proposing and judging its own solution confirms its first idea. A debate breaks that: the
proposals are made apart, attacked with evidence, scored by one yardstick, and judged by someone who
wrote none of them. The **runs** decide; the arguments only point at what to run.

Asking the user questions is a different job. This skill settles a choice with evidence.

## Steps

### 1. Frame the decision and fix the bars

Write, before any proposal exists:

- **The decision** in one sentence, and what is out of scope.
- **The data** every side scores on: raw recordings, fixtures, logs. One copy, paths named.
- **The bars**: numbers a solution must meet, each with the reason for its value (a measurement, a
  calculation, a requirement). Mark which are pass/fail and which rank.
- **The held-out set**: data no side may tune on, scored once after the decision.

Show the frame to the user when the decision is theirs (product behaviour, money, anything they
asked to decide). The bars are the hardest part to change later; they get agreed first.

**Done when** the frame is written to a file and no bar reads "good enough".

### 2. Independent proposals

Get at least two proposals from different minds that cannot see each other: the lead and one or more
subagents or other models, as the project's delegation rules allow (cheapest capable model; outside
models read-only on code they must not write). Each brief carries the frame, the data paths, and the
return shape: the method, its parameters with reasons, its own score on the bars from a run, and its
known weaknesses.

**Done when** every proposal came back with a run behind its scores, not an estimate.

### 3. Cross-examine

Give each side the other proposals. Each must find faults **with a run**: a case where the other
method fails a bar, a scoring error, a hidden assumption shown false on the data. A fault without a
run is a question, carried to step 4 for the scorer to settle.

Faults in the scorer itself are the most valuable finding: fix the scorer, then re-score everyone.

**Done when** each side has answered every fault raised against it, with a run or a concession.

### 4. Score on one yardstick

One scoring script, one data copy, identical time spans and inputs for every candidate, including
any hybrid the cross-examination produced. Save the scorer and its output next to the decision.

**Done when** a table shows every candidate against every bar from the same run.

### 5. Judge

A judge who wrote no proposal reads the frame, the proposals, the faults and the scores, and decides:
a stronger model, a different model family, or the user. The judge may require guards (cases the
winner must handle) and may reject all options. With no judge available, the bars decide; a tie goes
to the simpler method.

**Done when** the verdict names the winner, why each other option lost, and the guards required.

### 6. Write the decision

Write `decision.md` beside the scorer: the question, who proposed what, the faults found and by whom,
the score table, the verdict, what stays open, and the held-out test still to run. Then build the
winner test-first, matched to the scorer's reference within a stated tolerance.

### 7. Held-out check

After building, score the held-out set with everything frozen and add the result to `decision.md`.
A miss reopens the decision; it is not tuned away.

**Done when** the held-out result is in `decision.md`, pass or fail.
