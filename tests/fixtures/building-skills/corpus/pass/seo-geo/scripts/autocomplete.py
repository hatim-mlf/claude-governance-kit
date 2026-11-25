#!/usr/bin/env python3
"""Mine Google autocomplete for keyword variants and real questions (free, no key).

For each seed it queries the seed alone, the seed with each question or
comparison modifier, and optionally the seed followed by a–z. Output is one
deduplicated suggestion per line, tagged with the modifier that produced it, as
CSV: seed,modifier,suggestion.

The endpoint is unofficial and rate-limited: keep batches small (DELAY seconds
between calls) and treat results as vocabulary, not volume.

Usage:
  autocomplete.py "gpx navigation app" ["offline cycling map" ...] \
      [--lang en] [--country us] [--alphabet] [--out file.csv]

Standard library only.
"""

import argparse
import csv
import json
import string
import sys
import time
import urllib.parse
import urllib.request

ENDPOINT = "https://suggestqueries.google.com/complete/search"
DELAY = 1.0
TIMEOUT = 10

MODIFIERS = {
    "en": {
        "prefix": ["how to", "how", "what", "why", "which", "can", "is", "best", "free"],
        "suffix": ["vs", "or", "alternative", "for beginners", "app", "iphone", "offline", "near me", "reddit"],
    },
    "fr": {
        "prefix": ["comment", "pourquoi", "quel", "quelle", "quoi", "meilleur", "meilleure", "gratuit"],
        "suffix": ["vs", "ou", "alternative", "débutant", "application", "iphone", "hors ligne", "avis"],
    },
}


def suggest(query, lang, country):
    params = urllib.parse.urlencode({"client": "firefox", "q": query, "hl": lang, "gl": country})
    req = urllib.request.Request(f"{ENDPOINT}?{params}", headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        payload = resp.read().decode(resp.headers.get_content_charset() or "utf-8", errors="replace")
    data = json.loads(payload)
    return data[1] if len(data) > 1 else []


def queries_for(seed, lang, alphabet):
    mods = MODIFIERS.get(lang, MODIFIERS["en"])
    yield "seed", seed
    for m in mods["prefix"]:
        yield m, f"{m} {seed}"
    for m in mods["suffix"]:
        yield m, f"{seed} {m}"
    if alphabet:
        for ch in string.ascii_lowercase:
            yield f"+{ch}", f"{seed} {ch}"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("seeds", nargs="+")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--country", default="us")
    ap.add_argument("--alphabet", action="store_true", help="also query seed + a..z (26 extra calls per seed)")
    ap.add_argument("--out", help="CSV path; stdout when omitted")
    args = ap.parse_args()

    out = open(args.out, "w", newline="", encoding="utf-8") if args.out else sys.stdout
    writer = csv.writer(out)
    writer.writerow(["seed", "modifier", "suggestion"])
    seen, failures = set(), 0
    for seed in args.seeds:
        for modifier, query in queries_for(seed, args.lang, args.alphabet):
            try:
                results = suggest(query, args.lang, args.country)
            except Exception as exc:  # network, rate limit, bad JSON: report and keep going
                failures += 1
                print(f"warning: '{query}' failed: {exc}", file=sys.stderr)
                results = []
            for s in results:
                if s.lower() not in seen:
                    seen.add(s.lower())
                    writer.writerow([seed, modifier, s])
            time.sleep(DELAY)
    if out is not sys.stdout:
        out.close()
    print(f"{len(seen)} unique suggestions, {failures} failed calls", file=sys.stderr)
    sys.exit(1 if failures and not seen else 0)


if __name__ == "__main__":
    main()
