# Phase 6: GEO (generative engine optimisation) and authority

GEO means being **cited or recommended in AI answers**: ChatGPT, Perplexity, Gemini, Claude,
and Google AI Overviews or AI Mode. The evidence base is young. Everything below is current
practice, not settled science, so present it that way to the user.

## What makes a page citable

- **Answer first.** Under each question heading, a self-contained 40–60 word answer, then
  the detail. Engines lift passages, not pages.
- **Question headings that match real prompts,** taken from the phase 1 questions. People ask
  AI engines in full sentences.
- **Specifics over adjectives:** numbers, steps, named methods, dates, first-hand
  observations. Vague marketing copy is never quoted.
- **Clean structure:** semantic HTML, lists and tables for comparisons, content in the HTML
  rather than only rendered by JavaScript.
- **Structured data that matches the page:** Organization, SoftwareApplication, FAQPage,
  Article (with an author), BreadcrumbList.
- **Freshness:** a visible updated date, and pages actually kept current.

## Entity consistency

Engines build a picture of *what you are* from every source. Keep the name, one-line
description, category, founder and key facts **identical** across the site, the store
listings, social profiles, directories and press. `sameAs` links in the Organization schema
tie the profiles together.

## Crawler access, which is a decision for the owner

AI crawlers are controlled in robots.txt per agent. Some fetch pages for live answers:
`OAI-SearchBot`, `ChatGPT-User`, `PerplexityBot`, `Claude-SearchBot`, `Claude-User`. Others
collect training data: `GPTBot`, `ClaudeBot`, `Google-Extended`, `CCBot`. Blocking the
answer-time bots removes you from those answers. Present the choice to the owner and record
it. `llms.txt` is optional and low-evidence: cheap to add, but promise nothing from it.

## Mentions: where AI engines and Google both learn trust

AI answers lean heavily on third-party sources: forums, Reddit, review sites, "best X" list
articles, YouTube and press. Authority work therefore serves SEO and GEO at once:

- **Backlinks that make sense:** from sites the persona actually reads (clubs, associations,
  niche blogs, local press, podcasts, tool directories). Relevance beats domain authority.
- **Earned, never bought.** The usual earners: a founder story, original data, a free tool or
  resource, guest expertise, launch platforms, and partnerships with communities.
- **Community presence:** useful answers in the communities found in phase 1, written as a
  person, with the product mentioned only when it answers the question and the community
  allows it.
- **Listicles:** ask the authors of "best <category> apps" articles to evaluate the product,
  without paying for placement.
- **Reviews** on the store listing: ask at a moment of success, never with an incentive.

Track backlinks and mentions in `geo-tracking.md` (source, date, link or mention, context).

## Tracking AI visibility, free and manual

1. In `geo-tracking.md`, list 15–30 **prompts** the personas would type, one or more per
   journey stage: "what's the best app to follow a GPX route on iPhone offline?"
2. Monthly, run each prompt in ChatGPT, Perplexity, Gemini and Google (AI Overview). Record
   whether you are **mentioned**, **cited** (linked), which competitors appear, and which
   **sources** the engine cites.
3. Those cited sources are the GEO target list: get mentioned there, or publish the better
   answer they draw on.
4. In Search Console, watch long, conversational queries. They are often the same prompts
   reaching classic search.
