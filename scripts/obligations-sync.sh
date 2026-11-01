#!/usr/bin/env bash
#
# Mirror the obligations register to Notion and Apple Reminders, with no model involved.
#
#   scripts/obligations-sync.sh                 # sync now (a failure exits non-zero)
#   scripts/obligations-sync.sh --hook          # what the post-commit hook runs: logs, always exits 0
#   scripts/obligations-sync.sh --setup PAGE    # create the Obligations database under a Notion page
#
# Why: the obligations skill's sync ran only inside a Claude session, and the operator's
# quota ran out (2026-10-31), so the reminders would stop exactly when sessions stop. This
# runs from git's post-commit hook instead, costs no tokens, and is the same every time.
#
# The repository stays the source of truth, and nothing is written back to it: each
# Notion page is matched by its Id property (O-3, 2026-W44-06), so a re-run never
# duplicates. An obligation that is no longer owed becomes Done (or Dropped, as the
# register says) in Notion, and its reminder is completed. Calendar events are not made
# here: the Notion API cannot create them, so the obligations skill does that part.
#
# Configuration, in governance.config.json:
#   "notion": { "database": "<database id>", "reminders": true }
# The Notion key (an internal integration's secret) is read from $NOTION_TOKEN, else from
# the macOS Keychain, service "claude-governance-notion". It never lives in the repository.
#   security add-generic-password -s claude-governance-notion -a "$USER" -w
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "obligations-sync: not inside a git repository" >&2; exit 2; }
mode="${1:-}"; arg="${2:-}"
command -v python3 >/dev/null || { echo "obligations-sync: needs python3" >&2; [ "$mode" = "--hook" ] && exit 0; exit 2; }

token="${NOTION_TOKEN:-}"
if [ -z "$token" ] && command -v security >/dev/null 2>&1; then
  token=$(security find-generic-password -s claude-governance-notion -w 2>/dev/null || true)
fi

# Refresh obligations.json first; its exit status reports overdue items, not failure.
[ "$mode" = "--setup" ] || "$root/scripts/obligations.sh" >/dev/null 2>&1 || true

NOTION_TOKEN="$token" python3 -I - "$root" "$mode" "$arg" <<'PY'
import datetime as dt, json, os, platform, re, shutil, subprocess, sys, time, urllib.error, urllib.request

root, mode, arg = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {}
try: cfg = json.load(open(os.path.join(root, "governance.config.json")))
except (OSError, ValueError): pass
short = (cfg.get("projectShortName") or os.path.basename(root)).lower().replace(" ", "-")
project = cfg.get("projectName") if cfg.get("projectName") and "YOUR PROJECT" not in cfg.get("projectName", "") else os.path.basename(root)
notion = cfg.get("notion") or {}
log_path = os.path.expanduser(f"~/.claude/{short}-obligations-sync.log")

def log(msg):
    line = f"{dt.datetime.now():%Y-%m-%d %H:%M} {msg}"
    if mode == "--hook":
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a") as f: f.write(line + "\n")
    else:
        print(msg, file=sys.stderr)

def finish(code):
    sys.exit(0 if mode == "--hook" else code)

token = os.environ.get("NOTION_TOKEN", "")
api = os.environ.get("NOTION_API", "https://api.notion.com").rstrip("/")
delay = float(os.environ.get("NOTION_SYNC_DELAY", "0.35"))   # Notion allows ~3 requests a second

def call(method, path, body=None):
    req = urllib.request.Request(api + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {token}", "Notion-Version": "2022-06-28",
                                          "Content-Type": "application/json"})
    time.sleep(delay)
    try:
        with urllib.request.urlopen(req, timeout=30) as r: return json.load(r)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Notion {method} {path}: HTTP {e.code} {e.read()[:200]!r}")

def rich(s): return {"rich_text": [{"text": {"content": (s or "")[:2000]}}]}

if not token:
    log("obligations-sync: no Notion key ($NOTION_TOKEN or Keychain service claude-governance-notion), skipped")
    finish(2)

if mode == "--setup":
    parent = (re.findall(r"[0-9a-f]{32}", arg.replace("-", "")) or [arg])[-1]
    if not parent: log("obligations-sync --setup needs the Notion page to create the database under"); finish(2)
    sel = lambda *names: {"select": {"options": [{"name": n} for n in names]}}
    db = call("POST", "/v1/databases", {
        "parent": {"type": "page_id", "page_id": parent},
        "title": [{"type": "text", "text": {"content": "Obligations"}}],
        "properties": {"Name": {"title": {}}, "Id": {"rich_text": {}}, "Project": {"select": {}},
                       "Class": sel("security", "decision", "deadline", "verification", "maintenance", "open-entry"),
                       "Importance": sel("high", "normal", "low"), "Due": {"date": {}},
                       "Status": sel("Open", "Done", "Dropped"), "Done when": {"rich_text": {}},
                       "Source": {"rich_text": {}}, "Calendar event": {"rich_text": {}}}})
    print(f"Created the Obligations database: {db['id']}")
    print('Add it to governance.config.json:  "notion": { "database": "%s", "reminders": true }' % db["id"])
    print("One database serves every project; give the other projects the same id.")
    sys.exit(0)

database = notion.get("database")
if not database:
    log('obligations-sync: no "notion": {"database": ...} in governance.config.json, skipped')
    finish(2)

owed = json.load(open(os.path.join(root, "obligations/obligations.json")))["obligations"]
register = open(os.path.join(root, "obligations/OBLIGATIONS.md"), encoding="utf-8").read()
closed_status = {m.group(1): m.group(2) for m in re.finditer(
    r"(?ms)^## (O-\d+)\b.*?^\*\*Status:\*\*\s*(Done|Dropped)\s*$", register)}

def props(o):
    return {"Name": {"title": [{"text": {"content": o["title"][:2000]}}]}, "Id": rich(o["id"]),
            "Project": {"select": {"name": project}}, "Class": {"select": {"name": o["class"]}},
            "Importance": {"select": {"name": o["importance"]}}, "Due": {"date": {"start": o["due"]}},
            "Status": {"select": {"name": "Open"}}, "Done when": rich(o.get("doneWhen")), "Source": rich(o.get("source"))}

def text(p): return "".join(x.get("text", {}).get("content", x.get("plain_text", "")) for x in (p or {}).get("rich_text", p.get("title", []) if p else []))
def comparable(p):
    return (text(p.get("Name")), text(p.get("Id")), (p.get("Class", {}).get("select") or {}).get("name"),
            (p.get("Importance", {}).get("select") or {}).get("name"), ((p.get("Due", {}).get("date")) or {}).get("start"),
            (p.get("Status", {}).get("select") or {}).get("name"), text(p.get("Done when")), text(p.get("Source")))

try:
    existing, cursor = {}, None
    # Notion rejects a query on a select option the database does not have yet (HTTP 400),
    # and a project's option appears only with its first page: PlanScol and launchpad
    # failed their first sync so (2026-11-01). No option means no pages to match.
    schema = call("GET", f"/v1/databases/{database}")
    options = {o.get("name") for o in ((schema.get("properties", {}).get("Project") or {}).get("select") or {}).get("options", [])}
    while project in options:
        body = {"filter": {"property": "Project", "select": {"equals": project}}}
        if cursor: body["start_cursor"] = cursor
        page = call("POST", f"/v1/databases/{database}/query", body)
        for r in page["results"]: existing[text(r["properties"].get("Id"))] = r
        if not page.get("has_more"): break
        cursor = page["next_cursor"]

    created = updated = closed = 0
    for o in owed:
        want = props(o); have = existing.get(o["id"])
        if have is None:
            call("POST", "/v1/pages", {"parent": {"database_id": database}, "properties": want}); created += 1
        elif comparable(have["properties"]) != comparable(want):
            call("PATCH", f"/v1/pages/{have['id']}", {"properties": want}); updated += 1
    owed_ids = {o["id"] for o in owed}
    gone = []
    for oid, page in existing.items():
        if oid in owed_ids: continue
        status = closed_status.get(oid, "Done")
        gone.append(oid)
        if (page["properties"].get("Status", {}).get("select") or {}).get("name") != status:
            call("PATCH", f"/v1/pages/{page['id']}", {"properties": {"Status": {"select": {"name": status}}}}); closed += 1
    log(f"obligations-sync: Notion — {created} created, {updated} updated, {closed} closed ({len(owed)} owed)")
except (RuntimeError, OSError, KeyError, ValueError) as e:
    log(f"obligations-sync: Notion sync FAILED — {e}")
    finish(1)

# ---- Apple Reminders: the alert on the operator's phone (macOS only, opt-in).
reminders = os.environ.get("OBLIGATIONS_REMINDERS") or ("on" if notion.get("reminders") else "")
if not reminders: sys.exit(0)
def q(s): return '"' + (s or "").replace("\\", "\\\\").replace('"', '\\"') + '"'
lines = ['tell application "Reminders"',
         '  if not (exists list "Obligations") then make new list with properties {name:"Obligations"}',
         '  set L to list "Obligations"']
for o in owed:
    y, m, d = (int(x) for x in o["due"].split("-"))
    prefix = f"[{project}] {o['id']} "
    lines += ['  set d to current date', f'  set day of d to 1', f'  set year of d to {y}', f'  set month of d to {m}',
              f'  set day of d to {d}', '  set time of d to 9 * hours',
              f'  set found to (reminders of L whose name starts with {q(prefix)} and completed is false)',
              f'  if (count of found) = 0 then',
              f'    make new reminder at end of L with properties {{name:{q(prefix + "— " + o["title"])}, due date:d, body:{q("Done when: " + (o.get("doneWhen") or ""))}}}',
              '  else', '    set r to item 1 of found', '    set due date of r to d',
              f'    set name of r to {q(prefix + "— " + o["title"])}', '  end if']
for oid in sorted(set(gone) | set(closed_status)):
    prefix = f"[{project}] {oid} "
    lines += [f'  repeat with r in (reminders of L whose name starts with {q(prefix)} and completed is false)',
              '    set completed of r to true', '  end repeat']
lines.append('end tell')
script = "\n".join(lines)
if reminders == "dryrun":
    print(script); sys.exit(0)
if platform.system() != "Darwin" or not shutil.which("osascript"):
    log("obligations-sync: Apple Reminders skipped (not macOS)"); sys.exit(0)
r = subprocess.run(["osascript", "-"], input=script, text=True, capture_output=True, timeout=120)
log("obligations-sync: Apple Reminders updated" if r.returncode == 0 else
    f"obligations-sync: Apple Reminders FAILED — {r.stderr.strip()[:300]} (run it once by hand to grant access)")
finish(0 if r.returncode == 0 else 1)
PY
