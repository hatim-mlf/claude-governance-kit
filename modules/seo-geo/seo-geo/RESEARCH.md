# Phase 1: research

Four inputs, in this order, because each one sharpens the next.

## 1. Personas and their journey

A persona is a **job to be done**, not a demographic. For each one write, in `personas.md`:

- **Job:** what they are trying to get done ("ride a route I don't know without getting lost").
- **Trigger:** the moment they start searching (a new route, a race date, a bad ride).
- **Pains:** what goes wrong today. Quote them from phase 1.3, don't invent them.
- **Objections:** why they would *not* choose you (price, battery, learning curve, privacy,
  "my current app does it").
- **Decision criteria:** what they compare on at the decision stage.
- **Journey:** the searches they make at each stage (see
  [INTENT-AND-JOURNEY.md](INTENT-AND-JOURNEY.md)), from first problem to purchase.
- **Where they talk:** forums, subreddits, clubs, YouTube channels. These are the GEO and
  backlink targets in phase 6.

Start with three to five personas. One persona per pricing tier or premium feature is a
good default, because those are the searches that lead to revenue.

## 2. Competitors

Two lists, which are not the same:

- **Business competitors:** products a buyer would choose instead of you. Find them with
  `app_reviews.py search "<category term>"` per country, App Store and Play Store "you might
  also like" lists, and "<category> app" results pages.
- **Search competitors:** whoever ranks for your keywords. Often blogs, forums, magazines and
  YouTube, not the products. Find them by reading the results page for each cluster's head
  keyword. They show which content format wins (guide, list, tool, video).

## 3. Voice of the customer

The words customers use are the words they search with. Sources, all free:

| Source | How | Notes |
|---|---|---|
| App Store reviews | `app_reviews.py reviews <id> --max-stars 3 --country <cc>` per competitor and market | 1–3★ for pains; 4–5★ for what people value |
| Google Play reviews | the `google-play-scraper` package (npm or PyPI), run in a separate venv | Not standard library; install only when Android competitors matter |
| Reddit, forums | search the site; read threads by hand or via the site's JSON where it is allowed | Respect each site's terms and rate limits. Read; never post marketing |
| YouTube comments | under competitor reviews and tutorials | Rich in objections |
| Your own support inbox | if the product is live | The best source there is |

Code each quote into `voice-of-customer.md` under **pain**, **objection**, **desired outcome**
or **vocabulary**. Keep the quote and its source link. A pain that appears in several
competitors' reviews is a content opportunity (a guide that solves it) and a positioning line.

## 4. Keywords, variants and questions

1. **Seeds:** two to four words per persona job and per product feature, in the user's
   language, plus each target market's language. **Research each language natively;
   translating keywords loses the way people actually search.**
2. **Expand:** `autocomplete.py <seeds> --lang <l> --country <c>` (add `--alphabet` for
   depth). Then "People also ask" boxes and related searches on the results page, read
   by hand. Use AlsoAsked's free tier (a few searches a day) for question trees, Google Trends
   for seasonality and country comparison, and Keyword Planner (free with an Ads account) for
   volume ranges.
3. **Variants into clusters:** group keywords that one page would answer (synonyms, word
   order, singular and plural, "app" against "application", accents). One cluster is one
   future page. The test: would the same search results page satisfy both? If the top results
   overlap heavily, they belong to one cluster.
4. **Record** every row in `keyword-map.csv` with its `source` (`autocomplete`, `paa`,
   `review`, `kwp`, `gsc`, `trends`) and `volume_hint` (`kwp:100-1k`, `trend:rising`, or
   empty). Never invent a number.

**Long tail first** for a new domain: three to six word queries with a clear job. Head terms
("cycling app") belong to incumbents for the first year.
