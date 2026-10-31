---
name: obligations
description: Deadlines and must-dos — add one, sync to Notion with calendar reminders,
  or work one ("work O-3"). Use on "remind me", "deadline", "what's overdue", or when
  scripts/obligations.sh reports overdue items.
---

# Obligations

The register is `obligations/OBLIGATIONS.md`; the format, classes and due rules are in
`obligations/README.md`. **The repository is the source of truth; Notion is where
reminders fire.** Never edit an obligation only in Notion.

## Who runs it: delegate, on the smallest model

Adding an obligation and syncing to Notion are **recording**: read a file, write a
section, upsert pages, write the mapping back. The answer is found, not decided, so this
is rule 3 of `MODEL_DELEGATION.md`, and it never runs on a frontier tier.

- **Delegate it to a subagent with `model: haiku`.** Give it the item's fields, or "sync",
  and this skill. Do not do it inline in an Opus or Sonnet session.
- **The delegating session checks, it does not redo.** `scripts/obligations.sh` exits
  with no finding, and `git diff obligations/` shows only the expected sections and ids.
  If either fails, send the failure back to the same subagent.
- **What stays with the operator:** overriding a class's importance, and confirming a
  close made in Notion. The subagent asks; it does not decide.
- **Working an obligation** ("work O-3") is not recording. That session's model comes
  from its own session prompt.

## Add one

1. Get the id from the file: `scripts/obligations.sh --next-id`.
2. Append a section to `obligations/OBLIGATIONS.md` with `Class`, `Added` (today),
   `Owner`, `Source` and `Done when`. Add `Due` only when the date is external or
   differs from the class default. `deadline` always needs one.
3. `Done when` is checkable: "the old key is revoked", not "handle the key".
4. Run `scripts/obligations.sh`. It must list the new id without a finding.

Something already implied by the repo, like a ledger entry left open, is derived
automatically. Do not register it again.

## Sync to Notion

Run `scripts/obligations.sh` first. Then read `obligations/obligations.json` and
`obligations/notion.json` (create it as `{"database": null, "items": {}}` if absent).
Use the Notion connector's own tools; only the shape below is fixed.

1. **Database.** If `notion.json` has no `database`, ask the operator where it should
   live, then create one database named `Obligations` with these properties: `Name`
   (title), `Id` (text, the key), `Project` (select), `Class` (select), `Importance`
   (select: high, normal, low), `Due` (date), `Status` (select: Open, Done, Dropped),
   `Done when` (text), `Source` (text). Record its id in `notion.json`. **One database
   serves every project**; `Project` separates them, so the operator triages in one place.
2. **Upsert by `Id`.** For each obligation, create the page when `items[id]` is absent,
   otherwise update that page. Never match by title. Record each page id in
   `items[id].page`.
3. **Reminder.** For each item, create one all-day **Notion Calendar event** on its due
   date, titled `[<project>] <id> — <title>`, with `Done when` and "Ask a session to work
   <id>" in the description. Record `items[id].event` and `items[id].due`. When the due
   date changes, update the event; never create a second one.
4. **Closed in the repo:** an id in `notion.json` but no longer in `obligations.json`
   gets `Status` set to `Done` (or `Dropped`, matching the register), and its event is
   cancelled.
5. **Changed in Notion:** for each page marked `Done` in Notion but still open in the
   repo, ask the operator. If they confirm, set `**Status:** Done` with a
   `**Status note:** closed in Notion <date>` in the register. A derived ledger item
   cannot close this way: it closes when its entry is closed.
6. Commit `obligations/notion.json` with the register change.

The sync spends tokens, one connector call per changed item, so run it when the
register changed or when `obligations.sh` shows a new derived item. Do not run it on
every turn.

## Work one: "work O-3"

1. Read the item. If it is not owed (Done, Dropped, unknown id), say so and stop.
2. Write the session prompt with the **session-prompt** skill: its pass condition is the
   item's `Done when`, and it cites `Source`.
3. The ledger entry for that work names the obligation, as `**Obligation:** O-3`.
4. When the entry closes with its pass condition met, set `**Status:** Done` with a
   `**Status note:**` naming the entry, then sync.

## What this skill does not do

- Decide importance on the operator's behalf. The class sets a default; the operator
  overrides it.
- Create reminders for routine work. If nothing is owed by a date, it is a roadmap row,
  not an obligation.
