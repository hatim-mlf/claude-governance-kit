# Phase 5: audits

Write each audit to `docs/seo/audits/<date>_<type>.md`, or use the project's audit format if
it has one. Every finding takes: **severity** (critical, high, medium, low), **location**
(URL or file:line), **evidence** (command output, screenshot, results page), and a **fix**.

## Technical

Delegate the crawl to a technical SEO agent when one is available. Otherwise check:

- **Index:** robots.txt, meta robots, `X-Robots-Tag` header, preview hosts set to noindex, and
  production indexable.
- **Discovery:** sitemap present, submitted, holding only canonical 200 URLs with honest
  `lastmod` values; `link_graph.py` shows no orphans and no dead links.
- **Canonicals and duplicates:** one canonical per page, self-referencing, and http/https,
  www/non-www and trailing-slash variants all redirecting to it in one hop.
- **Status codes:** real 404s (no soft 404s), no redirect chains, no 5xx.
- **Rendering:** content and links present in the HTML, not only after JavaScript runs.
- **Structured data:** valid JSON-LD that matches the visible content (Organization or
  WebSite, SoftwareApplication or MobileApplication, BreadcrumbList, FAQPage, Article).
- **Core Web Vitals and mobile:** Lighthouse mobile, LCP < 2.5 s, CLS < 0.1, INP < 200 ms.
- **On-page:** one H1, titles of 50–60 characters, descriptions of 140–160 characters, image
  alt text, descriptive anchors.

## Local

Local SEO is ranking **for a place**: the map pack, "near me", "<service> in <city>".

- **If the business has a physical location or a service area:** Google Business Profile
  (category, hours, photos, posts, review replies); NAP (name, address and phone) consistent
  everywhere; LocalBusiness schema; local citations; one location page per real location.
- **If it has none (an app, a SaaS product):** there is no map pack to win. Local work means
  **place-based content** (pages about real places the persona searches for, built from
  first-hand data), **local communities** (clubs, associations, local press and blogs as link
  and mention sources), and the **market's language**. Say so plainly rather than setting up a
  Business Profile for an address that does not exist.

## International

- **Targeting:** decide language and country per market. Language-only (`/fr/`) is right when
  the offer is the same everywhere.
- **URL structure:** subfolders (`/fr/`) by default; ccTLDs only with a real local presence.
- **hreflang:** on every page of each set, reciprocal, self-referencing, plus `x-default`;
  validate that every pair points both ways.
- **Research per market:** keywords researched natively in each language (see
  [RESEARCH.md](RESEARCH.md)), not translated.
- **No automatic redirects by IP or language.** Suggest the version instead; crawlers come
  mostly from the US.
- **Store listings localised** alongside the pages.

## Conversion diagnosis: "why won't this site bring customers?"

Walk the funnel from the searcher's side and stop at the first broken link. That is the
finding that matters most.

1. **Seen?** Are the pages indexed, and do they rank for anything (Search Console)? If not,
   it is a technical or authority problem. Stop here.
2. **Right searches?** Do the ranking queries match buyer intent, or only awareness?
   Decision- and conversion-stage gaps come from the phase 2 grid.
3. **Clicked?** Do titles and descriptions promise what the searcher wants (CTR against
   position)?
4. **Convinced?** Does the landing page match the query's intent and stage, answer the top
   objections from voice of customer, and show proof (real screenshots, reviews, a founder,
   specifics)?
5. **Able to act?** Is there one obvious primary action matched to the stage, with price or
   trial clarity, platform clarity, and few clicks to the store or checkout?
6. **Measured?** Are CTA clicks and store installs per landing page tracked? Without
   measurement, the next round is guesswork.

## Content

Thin pages, outdated facts, pages with no impressions after 3 months (rewrite, merge or
remove), unsupported claims, and missing first-hand experience (E-E-A-T: show who wrote it
and why they know).
