# Structural Problems Register

Defects in **tooling, layout and process** — the system itself, not the app.
App and dashboard behaviour goes in `reports/bugs reports/BUG_TRACKER.md`.

Row ids are lettered, never reused: `U-1`, `U-2`, … A row records the defect, why
it matters, and its resolution or owner. Resolved rows stay — the register is
append-only history, not a todo list.

## Open rows

| Row | What | Why / resolution |
|---|---|---|
| — | _none yet_ | |

## Resolved rows

| Row | What | Why / resolution |
|---|---|---|
| — | _none yet_ | |

## Lessons

These are not defects to fix. They are findings worth not re-learning, and **each one is
recorded with the evidence it rests on**, or not at all:

- **Cue:** the shape of situation it applies to, so it can fire on a different task.
- **Lesson:** the operation to perform, naming the `component` it changes (a rule, skill,
  check, script or `CLAUDE.md` section).
- **Evidence:** the incident or measurement: a ledger id, a bug, an audit number.
- **Verdict:** `helped`, `hurt`, `no observed effect` or `confounded`, then `·` and a
  confidence (high, medium, low) with its reason. A lesson resting only on `confounded`
  evidence (several things changed at once, or one run) is a guess: narrow it, or don't
  record it. Keeping things as they are is a valid outcome.

`scripts/check-lessons.sh` warns at commit time on a new row missing any of these.

| Row | Cue | Lesson | Evidence | Verdict |
|---|---|---|---|---|
