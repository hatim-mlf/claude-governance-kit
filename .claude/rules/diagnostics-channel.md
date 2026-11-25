---
paths:
  - "**/*.swift"
  - "**/*.kt"
  - "**/*.java"
  - "**/*.dart"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.go"
  - "**/*.rs"
  - "**/*.sql"
  - "**/governance.config.json"
---

# Project Invariant — every feature reports its own problems, to the project's own server

**Fires** when a feature is built or changed in application code (an app, a website, a server
or worker). **Does not fire** on the governance tooling itself (`scripts/`, the dashboard), on
tests, or in a project whose `diagnostics.state` is `not-applicable`.

## The rule

A project that runs somewhere you cannot see — on people's devices, as a public website, as a
server or worker — ships a **built-in diagnostics channel** to a server the project owns
(Supabase, Cloudflare, or another), and **every feature reports through it**:

- a `<feature>.started` breadcrumb, and one outcome per run: `succeeded`, `nothing_to_do`, or
  `failed` with a typed reason code (`<feature>.<event>`, `^[a-z0-9_.]{1,64}$`);
- each path proved by a unit test that it records its code;
- context only from an allowed list of keys, each answering a stated question; **never** user
  content, places, names, ids or typed text. A new key is a reviewed change.

## The channel is a state, checked

`governance.config.json` → `diagnostics.state`, read by `scripts/check-diagnostics.sh` (warns
at commit, never blocks):

| State | Means | Must carry |
|---|---|---|
| `implemented` | the channel exists | `backend` and all six `parts` as paths that exist |
| `not-yet` | decided, planned | `row`: the roadmap file that builds it, first row before any feature |
| `not-applicable` | runs only where the operator sees it (a local tool, a research harness) | `reason` |

**The six parts** — each one is a separate way the project this came from failed:

1. **intake** — server side validates shape, caps per install and globally (the client key is
   public; anyone can invent install ids), purges on a schedule.
2. **devTag** — dev and test builds are tagged (e.g. version `dev-…`) so they never count as users.
3. **contractTest** — every code the client can send is proven to be one the server keeps.
4. **featureReports** — the typed codes, one list per feature.
5. **reader** — a digest someone actually reads. Crash reports sat unread for days without one.
6. **coverage** — a script measuring which error sites still report nothing: a standing worklist.

Starter material (wire contract, a Supabase intake with its tests, a generic digest):
`diagnostics/` in this project, installed from the kit's `modules/diagnostics/`.

## Why

In the project this kit came from (2026-11-24), a tester's failed import reached the team only
by chat: the app had a diagnostics channel, his install had sent 0 events, and 74 of the app's
106 error-log sites were not wired to it. The rule then lived in one `CLAUDE.md` template
paragraph, which `update.sh` never delivers: 0 of 4 other governed projects had it. A rule file
and a check are what `update.sh` does deliver.
