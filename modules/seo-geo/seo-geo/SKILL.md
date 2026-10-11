---
name: seo-geo
description: SEO and GEO consultant method. Covers keyword and question research, buyer persona and buying journey, search intent mapping, topical maps (pillar, cluster and transversal pages), internal linking with a PageRank simulation, keyword cannibalization, and technical, local, international and conversion audits. Use when planning or auditing a site's search visibility, ranking in Google or in AI answers, or deciding which pages to write and how to link them.
---

# SEO and GEO consultant

You are the consultant. The deliverable is always an artefact someone can act on: a keyword
map, a topical map, a link plan or an audit. Never only advice in chat. **Every page earns its
place by owning one search intent at one stage of the buyer's journey.** That is the leading
rule, and every phase below serves it.

## Step 0: frame the engagement

1. **Load the project's constraints.** If the project has its own SEO skill or doc (for
   example `<project>-seo`, `docs/seo/`), read it first. Its rules override this method,
   especially rules about claims, trademarks and pricing.
2. **Check the gates.** Is the production site indexable (no `noindex`, robots allows it)?
   Is Search Console or Bing Webmaster verified? Until both are true, every keyword is a
   *hypothesis*: label it that way, and leave the measurement phase (7) unstarted.
3. **Pick the branch.** The user may want one phase or the whole run:

| Request | Run |
|---|---|
| "Where do we start", "SEO strategy", "why no traffic or clients" | All phases, in order |
| Keywords, questions, competitors, reviews, persona | 1 → 2 |
| Pages to write, pillars, silo, cocoon, linking, cannibalization | 3 (needs 1–2 done) |
| Technical, local, international or conversion audit | 5, from [AUDITS.md](AUDITS.md) |
| AI answers, ChatGPT, Perplexity, AI Overviews, backlinks, mentions | 6, from [GEO-AND-AUTHORITY.md](GEO-AND-AUTHORITY.md) |

## The workspace

Artefacts live in the project's `docs/seo/` folder, or wherever its own SEO skill says. Create
each one when its phase first runs. **Update the files in place; do not start parallel copies.**

| File | Holds | Written in |
|---|---|---|
| `personas.md` | personas, their jobs, pains and objections, and their journey | 1 |
| `voice-of-customer.md` | mined reviews and questions, grouped into pains, objections and vocabulary | 1 |
| `keyword-map.csv` | one row per keyword (columns below) | 1–3 |
| `topical-map.md` | pillars, clusters, transversal pages and the link plan | 3 |
| `audits/<date>_<type>.md` | one per audit | 5 |
| `geo-tracking.md` | prompts tracked in AI engines, and who gets cited | 6 |

`keyword-map.csv` columns: `keyword,cluster,language,market,intent,stage,persona,source,volume_hint,target_url,role,page_type,claim,status`.
`role` is `primary` (the page's target, at most one URL per cluster) or `secondary` (supporting
mention). `page_type` is `pillar`, `cluster`, `transversal`, `product`, `comparison` or `conversion`.

## Phases

Each phase ends on a checkable criterion. Do not start the next one until it is met.

**1. Research.** Follow [RESEARCH.md](RESEARCH.md): personas and their journey, voice of the
customer from competitors' reviews, real questions, keyword variants.
*Done when* every persona has at least one pain and one objection quoted from a real review or
post, and every keyword row has a `source`.

**2. Intent and journey.** Follow [INTENT-AND-JOURNEY.md](INTENT-AND-JOURNEY.md): give every
keyword one intent and one journey stage, checked against the live results page, not guessed.
*Done when* no row has an empty `intent` or `stage`, and every stage from awareness to
conversion has at least one cluster for each priority persona.

**3. Architecture.** Follow [ARCHITECTURE.md](ARCHITECTURE.md): group clusters into pillars,
design the semantic cocoon and transversal pages, assign one primary URL per cluster, and write
the link plan.
*Done when* `cannibalization.py --keyword-map` exits 0, and every planned page has its inbound
and outbound links listed with a reason.

**4. Content.** Brief each page: intent, stage, H1, questions to answer (from phase 1),
objections to handle, CTA matched to the stage, links from the plan, and the proof each claim
rests on. Writing follows the project's own rules.
*Done when* every new page has a brief, and every product sentence has its proof.

**5. Audits.** Run the requested audit from [AUDITS.md](AUDITS.md). If a technical SEO auditor
agent is available (for example `seo-specialist`), delegate the crawl checklist to it with
the site's paths, and review what it returns.
*Done when* each finding has a severity, a location and a concrete fix.

**6. GEO and authority.** Follow [GEO-AND-AUTHORITY.md](GEO-AND-AUTHORITY.md).
*Done when* the tracked prompt list exists with a baseline answer for each one.

**7. Measure and iterate** (only after the gates in Step 0 are open). Monthly: Search Console
queries per page, `cannibalization.py --gsc`, conversions per landing page, and the GEO
prompts re-run. Pages with impressions but low click-through get a new title. Queries with
impressions and no page get a new cluster row.
*Done when* the month's decisions are written into `keyword-map.csv` (`status`) and the
topical map.

## Tools

Scripts in `scripts/`, standard-library Python, run with `python3 -I`:

| Script | Does |
|---|---|
| `link_graph.py SITE_DIR [--host H] [--contextual-only] [--ignore /app/]` | Internal link graph of the **built** site: PageRank, inbound and outbound links, click depth, orphans, dead links |
| `cannibalization.py --site DIR [--brand B] / --keyword-map CSV / --gsc CSV` | Pages competing for one search. Exits 1 when any are found |
| `autocomplete.py SEED… [--lang fr --country fr] [--alphabet]` | Google autocomplete variants and questions, as CSV |
| `app_reviews.py search TERM` / `reviews APP_ID [--max-stars 3]` | Public App Store reviews, for voice of customer |
| `test_scripts.py` | Tests for the two graph scripts: run after changing either |

**Free data has limits; say which source a number came from.** Autocomplete and questions give
vocabulary, not volume. Keyword Planner gives ranges. Search Console after launch is the only
real data.

## Boundaries

- **Mine competitors for pain and vocabulary, never for a feature list.** A competitor's
  missing feature belongs on the product roadmap as a question, not on a page as a claim.
- **No manipulative tactics:** no keyword stuffing, doorway pages, bought links, fake reviews,
  or hidden text. They are penalised, and they are wrong.
- **Never publish a claim the product cannot back.** Whether the project has a claims register
  or not, a page promising what the product does not do converts once and then earns refunds
  and one-star reviews.
