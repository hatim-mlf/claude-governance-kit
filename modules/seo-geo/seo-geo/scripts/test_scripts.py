#!/usr/bin/env python3
"""Tests for link_graph.py and cannibalization.py. Run: python3 -I test_scripts.py"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from link_graph import analyse  # noqa: E402
from cannibalization import from_keyword_map, from_gsc, from_site  # noqa: E402


def page(title, h1, body_links=(), nav_links=()):
    nav = "".join(f'<a href="{h}">n</a>' for h in nav_links)
    body = "".join(f'<a href="{h}">b</a>' for h in body_links)
    return f"<html><head><title>{title}</title></head><body><nav>{nav}</nav><main><h1>{h1}</h1>{body}</main></body></html>"


class LinkGraphTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        for rel, html in {
            "index.html": page("Home", "Home", body_links=["/a/", "/missing/"]),
            "a/index.html": page("Offline cycling maps", "Offline maps", body_links=["/"]),
            "b/index.html": page("Orphan page", "Orphan", body_links=["/a/"]),
            "c/index.html": page("Nav only", "Nav only", nav_links=["/a/"]),
        }.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(html)
        self.root = root

    def tearDown(self):
        self.tmp.cleanup()

    def rows(self, report):
        return {r["url"]: r for r in report["pages"]}

    def test_finds_orphans_and_dead_links(self):
        report = analyse(self.root, "", False)
        rows = self.rows(report)
        self.assertIn("orphan", rows["/b/"]["problems"])
        self.assertEqual(report["dead_links"], [{"from": "/", "to": "/missing/"}])

    def test_linked_page_outranks_orphan(self):
        rows = self.rows(analyse(self.root, "", False))
        self.assertGreater(rows["/a/"]["pagerank"], rows["/b/"]["pagerank"])

    def test_contextual_only_drops_nav_links(self):
        rows = self.rows(analyse(self.root, "", True))
        self.assertEqual(rows["/c/"]["outbound"], 0)

    def test_ignore_prefix_hides_app_routes(self):
        report = analyse(self.root, "", False, ["/missing/"])
        self.assertEqual(report["dead_links"], [])


class CannibalizationTests(unittest.TestCase):
    def test_keyword_map_flags_cluster_with_two_primary_urls(self):
        with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False) as fh:
            fh.write("keyword,cluster,role,target_url\n"
                     "gpx app,gpx,primary,/a/\ngpx iphone,gpx,primary,/b/\n"
                     "offline map,off,primary,/c/\noffline map,off,secondary,/\n")
        hits = from_keyword_map(fh.name)
        self.assertEqual(hits, [("cluster", "gpx", ["/a/", "/b/"])])

    def test_gsc_flags_query_split_across_pages(self):
        with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False) as fh:
            fh.write("query,page,impressions\ngpx app,/a/,40\ngpx app,/b/,12\nx,/a/,50\ny,/b/,3\ny,/c/,2\n")
        hits = from_gsc(fh.name, 10)
        self.assertEqual([q for q, _ in hits], ["gpx app"])

    def test_site_overlap_ignores_brand_word(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "a").mkdir()
            (root / "b").mkdir()
            (root / "a/index.html").write_text(page("Acme maps | Acme", "Acme maps"))
            (root / "b/index.html").write_text(page("Acme plans | Acme", "Acme plans"))
            self.assertTrue(from_site(root, 0.3, "en"))
            self.assertEqual(from_site(root, 0.3, "en", ["acme"]), [])

    def test_cli_exits_1_when_cannibalization_found(self):
        with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False) as fh:
            fh.write("keyword,cluster,role,target_url\nk,c,primary,/a/\nk,c,primary,/b/\n")
        result = subprocess.run([sys.executable, "-I", str(HERE / "cannibalization.py"), "--keyword-map", fh.name],
                                capture_output=True)
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
