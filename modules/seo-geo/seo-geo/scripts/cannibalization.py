#!/usr/bin/env python3
"""Find pages competing for the same search (keyword cannibalization).

Three independent sources; pass any combination:

  --site DIR        built HTML: pairs of pages whose title + H1 share most of their
                    meaningful words (a prediction, before Google has any data)
  --keyword-map CSV the planned keyword map: one keyword, or one variant cluster,
                    assigned a primary target on more than one URL (a planning error)
  --gsc CSV         a Search Console "Pages x Queries" export with columns
                    query,page,impressions[,clicks]: one query that already sends
                    impressions to two or more URLs (the real thing)

Usage:
  cannibalization.py --site dist/ [--threshold 0.5] [--lang en] [--brand acme]
  cannibalization.py --keyword-map docs/seo/keyword-map.csv
  cannibalization.py --gsc gsc-export.csv [--min-impressions 10]

Standard library only.
"""

import argparse
import csv
import re
import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from link_graph import PageParser, url_path_for, SKIP_FILES  # noqa: E402

STOPWORDS = {
    "en": set("a an and are as at be by for from how in is it of on or the to with your you our "
              "what why when which app apps".split()),
    "fr": set("a au aux avec ce ces dans de des du en et la le les leur pour par sur un une vos votre "
              "nos notre quoi comment pourquoi quand quel quelle".split()),
}


def terms(text, lang, brand=()):
    words = re.findall(r"[\w'-]+", text.lower())
    stop = STOPWORDS.get(lang, set()) | STOPWORDS["en"] | set(brand)
    return {w for w in words if w not in stop and len(w) > 2}


def from_site(site_dir, threshold, lang, brand=()):
    pages = {}
    for f in sorted(site_dir.rglob("*.html")):
        if f.name in SKIP_FILES:
            continue
        p = PageParser()
        p.feed(f.read_text(encoding="utf-8", errors="replace"))
        brand_split = re.split(r"\s[|—–-]\s", p.title)[0]  # drop " | Brand" suffix
        pages[url_path_for(f, site_dir)] = terms(brand_split + " " + p.h1, lang, brand)
    hits = []
    for (u1, t1), (u2, t2) in combinations(pages.items(), 2):
        if not t1 or not t2:
            continue
        score = len(t1 & t2) / len(t1 | t2)
        if score >= threshold:
            hits.append((round(score, 2), u1, u2, sorted(t1 & t2)))
    return sorted(hits, reverse=True)


def from_keyword_map(path):
    by_kw, by_cluster = defaultdict(set), defaultdict(set)
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            url = (row.get("target_url") or "").strip()
            if not url or (row.get("role") or "primary").strip() != "primary":
                continue
            by_kw[(row.get("keyword") or "").strip().lower()].add(url)
            cluster = (row.get("cluster") or "").strip().lower()
            if cluster:
                by_cluster[cluster].add(url)
    out = [("keyword", k, sorted(v)) for k, v in by_kw.items() if len(v) > 1]
    out += [("cluster", k, sorted(v)) for k, v in by_cluster.items() if len(v) > 1]
    return out


def from_gsc(path, min_impressions):
    by_query = defaultdict(list)
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            imp = int(float(row.get("impressions") or 0))
            if imp >= min_impressions:
                by_query[row["query"]].append((imp, row["page"]))
    return sorted(((q, sorted(v, reverse=True)) for q, v in by_query.items() if len(v) > 1),
                  key=lambda x: -sum(i for i, _ in x[1]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--site", type=Path)
    ap.add_argument("--keyword-map", type=Path)
    ap.add_argument("--gsc", type=Path)
    ap.add_argument("--threshold", type=float, default=0.5, help="title+H1 Jaccard overlap to flag (site mode)")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--brand", action="append", default=[], help="brand word to ignore in overlap (repeatable)")
    ap.add_argument("--min-impressions", type=int, default=10)
    args = ap.parse_args()
    if not (args.site or args.keyword_map or args.gsc):
        ap.error("pass at least one of --site, --keyword-map, --gsc")

    found = False
    if args.site:
        hits = from_site(args.site.resolve(), args.threshold, args.lang, [b.lower() for b in args.brand])
        print(f"## Site: title + H1 overlap ≥ {args.threshold}\n")
        for score, u1, u2, shared in hits:
            found = True
            print(f"- {score}  `{u1}` ↔ `{u2}`  shared: {', '.join(shared)}")
        print("- none" if not hits else "")
    if args.keyword_map:
        hits = from_keyword_map(args.keyword_map)
        print("\n## Keyword map: one primary target on several URLs\n")
        for kind, key, urls in hits:
            found = True
            print(f"- {kind} `{key}` → {', '.join(urls)}")
        print("- none" if not hits else "")
    if args.gsc:
        hits = from_gsc(args.gsc, args.min_impressions)
        print(f"\n## Search Console: queries splitting impressions (≥ {args.min_impressions})\n")
        for q, pages in hits:
            found = True
            print(f"- `{q}`: " + "; ".join(f"{p} ({i})" for i, p in pages))
        print("- none" if not hits else "")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
