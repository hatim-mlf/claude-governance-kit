#!/usr/bin/env python3
"""Internal link graph of a built static site, with a PageRank simulation.

Reads every .html file under SITE_DIR (the build output, not the sources), maps
each file to its URL path, and reports per page: internal PageRank, inbound and
outbound link counts, click depth from the home page, and problems (orphans,
dead internal links, pages deeper than MAX_DEPTH clicks).

Links inside <header>, <nav> and <footer> are site chrome. They are counted in
the full graph, and dropped with --contextual-only, which shows how authority
flows through body copy alone: the links a semantic cocoon is built from.

Usage:
  link_graph.py SITE_DIR [--host example.com] [--contextual-only] [--json]
                [--ignore /login/ --ignore /app/]   # client-side routes, not pages

Standard library only.
"""

import argparse
import json
import sys
from collections import deque
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse

DAMPING = 0.85
ITERATIONS = 100
MAX_DEPTH = 3
CHROME_TAGS = {"header", "nav", "footer"}
SKIP_FILES = {"404.html"}


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []          # (href, is_chrome)
        self.title = ""
        self.h1 = ""
        self.canonical = ""
        self.noindex = False
        self._chrome_depth = 0
        self._in_title = False
        self._in_h1 = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in CHROME_TAGS:
            self._chrome_depth += 1
        elif tag == "a" and a.get("href"):
            self.links.append((a["href"], self._chrome_depth > 0))
        elif tag == "title":
            self._in_title = True
        elif tag == "h1":
            self._in_h1 = True
        elif tag == "link" and (a.get("rel") or "").lower() == "canonical":
            self.canonical = a.get("href", "")
        elif tag == "meta" and (a.get("name") or "").lower() == "robots":
            self.noindex = "noindex" in (a.get("content") or "").lower()

    def handle_endtag(self, tag):
        if tag in CHROME_TAGS and self._chrome_depth:
            self._chrome_depth -= 1
        elif tag == "title":
            self._in_title = False
        elif tag == "h1":
            self._in_h1 = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_h1:
            self.h1 += data


def url_path_for(file_path, site_dir):
    rel = file_path.relative_to(site_dir).as_posix()
    if rel == "index.html":
        return "/"
    if rel.endswith("/index.html"):
        return "/" + rel[: -len("index.html")]
    return "/" + rel


def normalise(href, page_url, host):
    """Return the internal URL path an href points at, or None if external."""
    if href.startswith(("mailto:", "tel:", "javascript:", "#")):
        return None
    absolute = urljoin("https://site.invalid" + page_url, href)
    parsed = urlparse(absolute)
    if parsed.netloc not in ("site.invalid", host, "www." + host if host else None):
        return None
    path = parsed.path or "/"
    last = path.rsplit("/", 1)[-1]
    if "." not in last and not path.endswith("/"):
        path += "/"
    if path.endswith("/index.html"):
        path = path[: -len("index.html")]
    return path


def load_site(site_dir, host, contextual_only, ignore):
    pages, edges, dead = {}, {}, []
    for f in sorted(site_dir.rglob("*.html")):
        if f.name in SKIP_FILES:
            continue
        parser = PageParser()
        parser.feed(f.read_text(encoding="utf-8", errors="replace"))
        url = url_path_for(f, site_dir)
        pages[url] = {
            "title": " ".join(parser.title.split()),
            "h1": " ".join(parser.h1.split()),
            "canonical": parser.canonical,
            "noindex": parser.noindex,
        }
        targets = set()
        for href, is_chrome in parser.links:
            if contextual_only and is_chrome:
                continue
            target = normalise(href, url, host)
            if target and target != url and not target.startswith(ignore):
                targets.add(target)
        edges[url] = targets
    for src, targets in edges.items():
        for t in sorted(targets):
            if t not in pages and not Path(t).suffix:
                dead.append((src, t))
        edges[src] = {t for t in targets if t in pages}
    return pages, edges, dead


def pagerank(nodes, edges):
    n = len(nodes)
    rank = {u: 1.0 / n for u in nodes}
    for _ in range(ITERATIONS):
        dangling = sum(rank[u] for u in nodes if not edges[u])
        new = {u: (1 - DAMPING) / n + DAMPING * dangling / n for u in nodes}
        for u in nodes:
            out = edges[u]
            for v in out:
                new[v] += DAMPING * rank[u] / len(out)
        rank = new
    return rank


def click_depth(edges, root="/"):
    depth = {root: 0}
    queue = deque([root])
    while queue:
        u = queue.popleft()
        for v in edges.get(u, ()):
            if v not in depth:
                depth[v] = depth[u] + 1
                queue.append(v)
    return depth


def analyse(site_dir, host, contextual_only, ignore=()):
    pages, edges, dead = load_site(site_dir, host, contextual_only, tuple(ignore))
    if not pages:
        sys.exit(f"No .html pages found under {site_dir}")
    rank = pagerank(list(pages), edges)
    depth = click_depth(edges)
    inbound = {u: 0 for u in pages}
    for targets in edges.values():
        for v in targets:
            inbound[v] += 1
    rows = []
    for u in sorted(pages, key=lambda p: -rank[p]):
        problems = []
        if u != "/" and inbound[u] == 0:
            problems.append("orphan")
        if u not in depth:
            problems.append("unreachable from /")
        elif depth[u] > MAX_DEPTH:
            problems.append(f"depth>{MAX_DEPTH}")
        if pages[u]["noindex"]:
            problems.append("noindex")
        rows.append({
            "url": u,
            "pagerank": round(rank[u] * len(pages), 3),  # 1.0 = an average page
            "inbound": inbound[u],
            "outbound": len(edges[u]),
            "depth": depth.get(u),
            "title": pages[u]["title"],
            "problems": problems,
        })
    return {"mode": "contextual-only" if contextual_only else "all links",
            "pages": rows,
            "dead_links": [{"from": s, "to": t} for s, t in dead]}


def print_markdown(report):
    print(f"## Internal link graph ({report['mode']})\n")
    print("PageRank is relative: 1.0 = an average page. Pillars and conversion pages should lead.\n")
    print("| URL | PR | In | Out | Depth | Problems |")
    print("|---|---|---|---|---|---|")
    for r in report["pages"]:
        print(f"| `{r['url']}` | {r['pagerank']} | {r['inbound']} | {r['outbound']} | "
              f"{r['depth'] if r['depth'] is not None else '—'} | {', '.join(r['problems']) or ''} |")
    if report["dead_links"]:
        print("\n### Dead internal links\n")
        for d in report["dead_links"]:
            print(f"- `{d['from']}` → `{d['to']}`")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("site_dir", type=Path)
    ap.add_argument("--host", default="", help="production host, so absolute links to it count as internal")
    ap.add_argument("--contextual-only", action="store_true", help="ignore links inside header/nav/footer")
    ap.add_argument("--ignore", action="append", default=[], help="URL prefix to skip (repeatable)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if not args.site_dir.is_dir():
        sys.exit(f"Not a directory: {args.site_dir}")
    report = analyse(args.site_dir.resolve(), args.host, args.contextual_only, args.ignore)
    if args.json:
        json.dump(report, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        print_markdown(report)


if __name__ == "__main__":
    main()
