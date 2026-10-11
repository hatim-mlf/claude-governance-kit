#!/usr/bin/env python3
"""Fetch public App Store reviews of an app (free, no key) for voice-of-customer mining.

Two modes:
  app_reviews.py search "cycling gpx" [--country us]      find app ids by term
  app_reviews.py reviews APP_ID [--country us] [--pages 10] [--max-stars 3] [--out f.csv]

Reviews come from Apple's public customer-reviews feed (most recent first, up to
10 pages of 50 per country). Output CSV: app_id,country,stars,title,body,version,date.
Run once per country: reviews are stored per storefront.

Mine the output for pain points, objections and the riders' own words. It is
evidence for content and FAQ, never a feature list to copy.

Standard library only.
"""

import argparse
import csv
import json
import sys
import time
import urllib.parse
import urllib.request

SEARCH_URL = "https://itunes.apple.com/search"
REVIEWS_URL = "https://itunes.apple.com/{country}/rss/customerreviews/page={page}/id={app_id}/sortby=mostrecent/json"
MAX_PAGES = 10
DELAY = 1.0
TIMEOUT = 15


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def search(term, country, limit):
    q = urllib.parse.urlencode({"term": term, "entity": "software", "country": country, "limit": limit})
    for app in get_json(f"{SEARCH_URL}?{q}").get("results", []):
        print(f"{app['trackId']}\t{app.get('averageUserRating', 0):.1f}★ "
              f"({app.get('userRatingCount', 0)})\t{app['trackName']}\t{app.get('sellerName', '')}")


def reviews(app_id, country, pages, max_stars):
    for page in range(1, min(pages, MAX_PAGES) + 1):
        try:
            feed = get_json(REVIEWS_URL.format(country=country, page=page, app_id=app_id)).get("feed", {})
        except Exception as exc:
            print(f"warning: page {page} failed: {exc}", file=sys.stderr)
            break
        entries = feed.get("entry", [])
        if isinstance(entries, dict):
            entries = [entries]
        entries = [e for e in entries if "im:rating" in e]  # first entry can be the app itself
        if not entries:
            if page == 1:
                print("warning: page 1 had no reviews. The app may have none in this storefront, "
                      "or Apple is throttling (it answers 200 with an empty feed); retry later.", file=sys.stderr)
            break
        for e in entries:
            stars = int(e["im:rating"]["label"])
            if max_stars and stars > max_stars:
                continue
            yield {
                "app_id": app_id, "country": country, "stars": stars,
                "title": e.get("title", {}).get("label", ""),
                "body": e.get("content", {}).get("label", "").replace("\n", " "),
                "version": e.get("im:version", {}).get("label", ""),
                "date": e.get("updated", {}).get("label", "")[:10],
            }
        time.sleep(DELAY)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search")
    s.add_argument("term")
    s.add_argument("--country", default="us")
    s.add_argument("--limit", type=int, default=15)
    r = sub.add_parser("reviews")
    r.add_argument("app_id")
    r.add_argument("--country", default="us")
    r.add_argument("--pages", type=int, default=MAX_PAGES)
    r.add_argument("--max-stars", type=int, default=0, help="keep only reviews at or below this rating; 0 = all")
    r.add_argument("--out")
    args = ap.parse_args()

    if args.cmd == "search":
        search(args.term, args.country, args.limit)
        return
    out = open(args.out, "w", newline="", encoding="utf-8") if args.out else sys.stdout
    fields = ["app_id", "country", "stars", "title", "body", "version", "date"]
    writer = csv.DictWriter(out, fieldnames=fields)
    writer.writeheader()
    count = 0
    for row in reviews(args.app_id, args.country, args.pages, args.max_stars):
        writer.writerow(row)
        count += 1
    if out is not sys.stdout:
        out.close()
    print(f"{count} reviews", file=sys.stderr)


if __name__ == "__main__":
    main()
