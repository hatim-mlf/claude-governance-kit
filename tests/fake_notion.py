"""A minimal stand-in for the Notion API, for tests/test_obligations_sync.sh.

Implements only what scripts/obligations-sync.sh calls: create a database, read its
schema, query it (filter on Project), create a page, update a page. State is in memory;
every request is appended to the log file named by argv[2] as one JSON line.

Like the real API, a query filtering on a Project option the database does not have yet
is a 400 validation_error, and creating a page adds its Project option. A second project
syncing into the shared database failed exactly so (2026-11-01, PlanScol and launchpad).
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
            i = "db-" + uuid.uuid4().hex[:8]; dbs[i] = set(); return self.reply(200, {"object": "database", "id": i})
        if self.path.startswith("/v1/databases/") and self.path.endswith("/query"):
            proj = b["filter"]["select"]["equals"]
            if proj not in dbs.get(self.path.split("/")[3], set()):
                return self.reply(400, {"object": "error", "status": 400, "code": "validation_error",
                                        "message": f'select option "{proj}" not found for property "Project".'})
            res = [{"id": k, "properties": v} for k, v in pages.items()
                   if v.get("Project", {}).get("select", {}).get("name") == proj]
            return self.reply(200, {"results": res, "has_more": False, "next_cursor": None})
        if self.path == "/v1/pages":
            i = "page-" + uuid.uuid4().hex[:8]; pages[i] = b["properties"]
            dbs.setdefault(b["parent"]["database_id"], set()).add(b["properties"]["Project"]["select"]["name"])
            return self.reply(200, {"id": i})
        self.reply(404, {})
    def do_PATCH(self):
        b = self.body(); self.record(b)
        i = self.path.rsplit("/", 1)[-1]
        if i not in pages: return self.reply(404, {})
        pages[i].update(b["properties"]); self.reply(200, {"id": i})
    def do_GET(self):
        if self.path.startswith("/v1/databases/"):
            i = self.path.split("/")[3]
            if i not in dbs: return self.reply(404, {})
            opts = [{"name": n} for n in sorted(dbs[i])]
            return self.reply(200, {"object": "database", "id": i, "properties": {"Project": {"select": {"options": opts}}}})
        if self.path == "/_state":  # test inspection only
            out = {text(v["Id"]): {"status": v["Status"]["select"]["name"], "due": (v.get("Due", {}).get("date") or {}).get("start"),
                                    "project": v["Project"]["select"]["name"], "name": text(v["Name"])} for v in pages.values()}
            return self.reply(200, out)
        self.reply(404, {})

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
