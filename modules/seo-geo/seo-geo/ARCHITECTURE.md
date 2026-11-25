# Phase 3: architecture — topical authority, cocoon, linking, cannibalization

## Topical authority

Search engines, and AI answer engines even more, trust a site that covers a **topic** in
depth over one that has a single page per keyword. Topical authority comes from:

- **coverage:** the clusters around a topic, across every journey stage, all answered;
- **structure:** the pages linked so that the relationships are explicit;
- **consistency:** the same entities, terms and facts everywhere.

A small site wins by picking **few topics and covering them completely**, not many topics
thinly.

## Page roles

| Role | What it is | Links |
|---|---|---|
| **Pillar** (mother page) | the broad page for one topic: answers the head query, introduces every subtopic | down to all its clusters |
| **Cluster** (daughter page) | one subtopic, one intent: answers it in full | up to its pillar; across to sister clusters that the reader would need next |
| **Transversal page** | deliberately bridges two pillars, because a real task crosses them ("plan a hilly route and train for it") | to the relevant clusters in both pillars, each with a reason |
| **Product or conversion page** | the action page | receives links from decision-stage pages in every pillar |

## The semantic cocoon (cocon sémantique)

The strict form of the topical map, and the reason "do not link pages arbitrarily":

1. **Links follow the reader's next question, not the menu.** A link exists when the reader of
   page A, at that sentence, would naturally want page B.
2. **Mother → daughters, daughter → mother, daughter → sisters.** A link to a different
   cocoon goes through a transversal page, or is justified in the link plan.
3. **Contextual links carry the meaning.** Links in body copy, with a descriptive anchor, tell
   search engines what the target is about. Header, nav and footer links are sitewide, so they
   say little.
4. **Anchors vary,** taken from the target's keyword variants (its cluster), never the same
   exact-match anchor everywhere.
5. **Every link has a reason** in `topical-map.md`: `A → B — anchor — why the reader goes there`.

## The PageRank simulation

Run `scripts/link_graph.py <built site>` twice: once with all links and once with
`--contextual-only`.

- **All links** shows crawlability: orphans, dead links, click depth (keep money pages ≤ 3
  clicks from home).
- **Contextual-only** shows where meaning and authority flow through body copy alone. This
  is the graph the cocoon designs.

Read the result against intent:

- **Pillars and conversion pages should have the highest internal PageRank.** If a legal page
  or a thin page outranks them, authority is leaking. Usually the cause is sitewide links, or
  a pillar with few contextual inbound links.
- **An orphan in contextual-only mode** is a page no body copy argues for. Either link it from
  where its question arises, or ask whether it should exist.
- **Before adding pages,** add their planned links to a copy of the graph (or build first) and
  re-run. The goal is the distribution that matches the business priority, not a high number
  everywhere.

## Cannibalization

Two pages of one site competing for the same search split their signals, and Google picks
one, often the wrong one. Detect it three ways with `scripts/cannibalization.py`:

- `--keyword-map`: at planning time, two `primary` rows of one cluster on different URLs;
- `--site`: before launch, titles and H1s that overlap heavily;
- `--gsc`: after launch, one query sending impressions to several URLs (the proof).

Resolve by intent, in this order:

1. **Different intents?** Then make each page's title, H1 and copy own its intent clearly,
   and link between them with anchors that say which is which.
2. **Same intent?** Merge into the stronger page, and 301 the weaker one to it.
3. **One is a subtopic of the other?** Make it a cluster under the other as pillar,
   retarget it at its long-tail variant, and link up.

## The output: `topical-map.md`

Per pillar: the pillar URL and head cluster, its clusters (URL, cluster key, intent, stage),
transversal pages with the two pillars they bridge, and the link plan (one line per link,
with its reason). End with the latest `link_graph.py` summary: top ten pages by contextual
PageRank, plus the orphans.
