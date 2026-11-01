"""A minimal stand-in for the Notion API, for tests/test_obligations_sync.sh.

Implements only what scripts/obligations-sync.sh calls: create a database, query a
database (filter on Project), create a page, update a page. State is in memory; every
request is appended to the log file named by argv[2] as one JSON line.
"""
import json, sys, uuid
from http.server import BaseHTTPRequestHandler, HTTPServer

pages, dbs, log = {}, {}, sys.argv[2]

def text(p):
    v = p.get("rich_text") or p.get("title") or []
    return "".join(x.get("text", {}).get("content", "") for x in v)

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")
    def record(self, b):
        with open(log, "a") as f:
            f.write(json.dumps({"method": self.command, "path": self.path, "auth": self.headers.get("Authorization"), "body": b}) + "\n")
    def do_POST(self):
        b = self.body(); self.record(b)
        if self.headers.get("Authorization") != "Bearer test-key":
            return self.reply(401, {"object": "error", "message": "unauthorized"})
        if self.path == "/v1/databases":
            i = "db-" + uuid.uuid4().hex[:8]; dbs[i] = b; return self.reply(200, {"object": "database", "id": i})
        if self.path.startswith("/v1/databases/") and self.path.endswith("/query"):
            proj = b["filter"]["select"]["equals"]
            res = [{"id": k, "properties": v} for k, v in pages.items()
                   if v.get("Project", {}).get("select", {}).get("name") == proj]
            return self.reply(200, {"results": res, "has_more": False, "next_cursor": None})
        if self.path == "/v1/pages":
            i = "page-" + uuid.uuid4().hex[:8]; pages[i] = b["properties"]; return self.reply(200, {"id": i})
        self.reply(404, {})
    def do_PATCH(self):
        b = self.body(); self.record(b)
        i = self.path.rsplit("/", 1)[-1]
        if i not in pages: return self.reply(404, {})
        pages[i].update(b["properties"]); self.reply(200, {"id": i})
    def do_GET(self):  # test inspection only
        if self.path == "/_state":
            out = {text(v["Id"]): {"status": v["Status"]["select"]["name"], "due": (v.get("Due", {}).get("date") or {}).get("start"),
                                    "project": v["Project"]["select"]["name"], "name": text(v["Name"])} for v in pages.values()}
            return self.reply(200, out)
        self.reply(404, {})

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
