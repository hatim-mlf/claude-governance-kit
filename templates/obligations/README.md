# Obligations

Commitments with a due date: things that **must be done by a time**, and that a person
has to be reminded of. The ledger records work started and finished. This folder
records work that is **owed**.

The repository is the source of truth. Notion is where the reminders fire, and where
items are triaged by class, importance and due date. Nothing here is hand-copied into
Notion: the `obligations` skill syncs it, keyed by id.

## Files

| File | What | Who writes it |
|---|---|---|
| `OBLIGATIONS.md` | The register: one section per obligation | Sessions and the operator, through the `obligations` skill |
| `obligations.json` | Everything owed: the register plus what the repo already implies | `scripts/obligations.sh`. Generated, never hand-edited |
| `notion.json` | Which Notion page and calendar event each id maps to | The `obligations` skill's sync |

## An obligation

```markdown
## O-3 — Rotate the API key removed from source

**Class:** security
**Importance:** high
**Added:** 2026-10-31
**Due:** 2026-11-02                         (optional: derived from Class when absent)
**Owner:** operator
**Source:** `reports/bugs reports/BUG_TRACKER.md` — Bug 54
**Done when:** the old key is revoked and the app reads the new one at runtime
**Status:** Open
```

The status line holds one word: **Open**, **Done** or **Dropped**. A reason or a date
goes on a `**Status note:**` line below it, as in the ledger. Ids are `O-<n>`,
sequential, never reused. `scripts/obligations.sh --next-id` prints the next one.

## Classes, and the due date each one implies

A due date is **derived** from the class unless the item states its own, so a date is
rarely typed and never forgotten.

| Class | For | Due when absent | Default importance |
|---|---|---|---|
| `security` | A credential, a leak, an exposure | Added + 2 days | high |
| `decision` | Something only the operator can decide; a stop gate waiting on an answer | Added + 3 days | high |
| `deadline` | An external date: a store review, a renewal, a launch, a payment | **Due is required** | high |
| `verification` | A fix that needs a device run or a capture before it counts | Added + 7 days | normal |
| `maintenance` | Debt with a cost of waiting: an upgrade, a cleanup, an expiring dependency | Added + 30 days | low |

`**Importance:**` overrides the default when it is stated: `high`, `normal` or `low`.

## What the repo already owes

`scripts/obligations.sh` adds one derived class without anyone writing it down:

| Derived | Id | Due |
|---|---|---|
| A ledger entry still open from an earlier day | the entry id (`2026-W44-06`) | Reserved + 2 days |

Derived items close themselves when the entry closes. A derived item can't be closed
from Notion, because closing a ledger entry needs its closing block.

## When a reminder fires

Attack it in one step: ask a session to **work obligation O-3**. The `obligations` skill
writes the session prompt from the item's `Done when` and `Source`, the session reserves
a ledger entry citing `O-3`, and closing that entry marks the obligation **Done**.
