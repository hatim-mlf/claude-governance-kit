---
name: {{project}}-seo
description: SEO and GEO for {{site}} — keywords, personas, buying journey, pages to write, internal linking, cannibalization, technical/local/international/conversion audits, AI-answer visibility. Use for any search, ranking or landing-page task on {{project}}. Runs the global seo-geo method under {{project}}'s rules.
---

# {{Project}} SEO

Run the **`seo-geo`** skill's method. This file holds only what is true for {{project}}: where
things are, what is already decided, and the rules that override the generic method. Where the
two disagree, this file wins.

## Sources of truth: read before phase 1

- `{{strategy doc}}`: the strategy. Extend it; never write a second one.
- `{{claims register}}`: the only source of product facts for public copy (if the project has
  one; otherwise name what plays that role).
- `{{business model doc}}`: what is free and what is paid. Paid-intent searches get the
  strongest pages.

## The workspace

`{{docs/seo/}}`. Audits use `{{the project's audit format}}`.

## Decided — apply, do not revisit

| Date | Decision |
|---|---|
| {{date}} | Comparison stage: named "vs" pages, or unnamed "how to choose" guides |
| {{date}} | Local: a physical location (Business Profile), place-based content, or none |
| {{date}} | Tool budget: free only, pay-as-you-go, or a full suite |

Open decisions: list them with their owner. Present options with a recommendation; do not pick.

## Rules that override the generic method

- {{claims rule}}
- {{trademark, pricing and wording rules}}
- {{features that are planned but not shipped, which must never be a page}}

## Site paths and commands

- Public pages: `{{path}}`. Build: `{{command}}` into `{{build dir}}`.
- Link graph: `python3 -I ~/.claude/skills/seo-geo/scripts/link_graph.py {{build dir}} --host {{host}} --ignore {{app routes}}`
- Cannibalization: `cannibalization.py --site {{build dir}} --brand {{brand}}`, and
  `--keyword-map {{docs/seo/keyword-map.csv}}`.

## Known gotchas

Record project-specific traps here as they are found (for example, robots.txt `Disallow`
prefixes that would also block a new public section).
