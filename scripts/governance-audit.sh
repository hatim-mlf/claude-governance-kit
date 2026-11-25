#!/usr/bin/env bash
#
# Measure what the governance system costs this project and what it has caught.
# Read-only, and it never calls a model, so it costs no tokens to run.
#
#   scripts/governance-audit.sh                  # this repository, its own transcripts
#   scripts/governance-audit.sh --transcripts DIR
#
# Prints COUNTS, DURATIONS and governance FILE NAMES only. It never prints source code,
# bug or entry titles, report text, or transcript content, so the output is safe to
# paste into another session or a review. Sections A–G match AUDIT RESULT v1 in
# prompts/SESSION_control_audit.md.
#
# Transcripts: Claude Code keeps one JSONL per session under ~/.claude/projects/<dir>,
# where <dir> is the repository's absolute path with every "/" and "." replaced by "-".
# One assistant message is written across several lines that repeat the same usage, so
# usage is counted once per message id. Summing every line overcounted ~2.7x on a real
# transcript.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "governance-audit: not inside a git repository" >&2; exit 1; }
transcripts="$HOME/.claude/projects/$(printf '%s' "$root" | sed 's|[/.]|-|g')"
while [ $# -gt 0 ]; do
  case "$1" in
    --transcripts) transcripts="$2"; shift 2 ;;
    *) echo "governance-audit: unknown argument $1" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null || { echo "governance-audit: needs python3" >&2; exit 1; }

git_log="$(mktemp)"; trap 'rm -f "$git_log"' EXIT
git -C "$root" log --no-merges --name-only --format='@@%ad%x09%s' --date=short > "$git_log" 2>/dev/null || true

python3 -I - "$root" "$transcripts" "$git_log" <<'PY'
import collections, datetime as dt, glob, json, os, re, statistics, sys

root, tdir, git_log = sys.argv[1:4]
out = ["AUDIT RESULT v1", f"generated: {dt.datetime.now().strftime('%Y-%m-%d %H:%M')}", ""]
notes = []
def p(s=""): out.append(s)
def rel(path): return os.path.relpath(path, root)
def size(path): return os.path.getsize(path) if os.path.exists(path) else None
def q(vals, f):
    if not vals: return "n/a"
    v = sorted(vals); return v[min(len(v) - 1, int(round(f * (len(v) - 1))))]
def stats(vals, unit=""):
    if not vals: return "n/a"
    return f"median {statistics.median(vals):.1f}{unit}, p90 {q(vals, .9):.1f}{unit}, max {max(vals):.1f}{unit}, n={len(vals)}"
def frontmatter(text):
    m = re.match(r"^---\r?\n(.*?)\r?\n---", text, re.S); return m.group(1) if m else ""

# ---------------------------------------------------------------- A. governance text
p("A. GOVERNANCE TEXT")
always = 0
for name in ("CLAUDE.md", "CLAUDE.governance.md"):
    b = size(os.path.join(root, name))
    if b is not None:
        p(f"  {name}: {b} B"); always += b if name == "CLAUDE.md" else 0
p("  rules (.claude/rules/):")
for r in sorted(glob.glob(os.path.join(root, ".claude/rules/*.md"))):
    globs = re.findall(r'^\s*-\s*"?([^"\n]+)"?', frontmatter(open(r, encoding="utf-8").read()), re.M)
    p(f"    {os.path.basename(r)}: {size(r)} B; paths: {', '.join(globs) or '(none: always loaded)'}")
p("  skills (.claude/skills/*/SKILL.md):")
fm_total = 0
for s in sorted(glob.glob(os.path.join(root, ".claude/skills/*/SKILL.md"))):
    fm = len(frontmatter(open(s, encoding="utf-8").read()).encode())
    fm_total += fm
    p(f"    {os.path.basename(os.path.dirname(s))}: file {size(s)} B, frontmatter {fm} B")
always += fm_total
p(f"  skill frontmatter total: {fm_total} B")
p(f"  always-loaded governance text (CLAUDE.md + skill frontmatter): {always} B (~{always // 4} tokens)")
settings = os.path.join(root, ".claude/settings.json")
if os.path.exists(settings):
    try:
        hooks = json.load(open(settings)).get("hooks", {})
        for ev, groups in hooks.items():
            scripts = sorted({m for g in groups for h in g.get("hooks", []) for m in re.findall(r"scripts/[\w.-]+", h.get("command", ""))})
            p(f"  hook {ev}: {', '.join(scripts) or '(inline)'}")
    except ValueError: notes.append("A4: .claude/settings.json is not valid JSON")

# ---------------------------------------------------------------- B. ledger
p(); p("B. LEDGER")
files = sorted(glob.glob(os.path.join(root, "ledger/20*-W*/*.md")) + glob.glob(os.path.join(root, "ledger/20*-W*.md")))
files = [f for f in files if os.path.basename(f) != "README.md"]
entries = []
for f in files:
    cur = None
    for line in open(f, encoding="utf-8", errors="replace"):
        m = re.match(r"^## (\d{4}-W\d{2})-(\d+)\b", line)
        if m:
            cur = {"week": m.group(1), "lines": []}; entries.append(cur); continue
        if cur is not None: cur["lines"].append(line.rstrip("\n"))
def ts(s):
    m = re.search(r"(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})", s)
    return dt.datetime.strptime(f"{m.group(1)} {m.group(2)}", "%Y-%m-%d %H:%M") if m else None
def field(lines, name):
    for l in lines:
        m = re.match(rf"^\*\*{re.escape(name)}:\*\*\s*(.*)$", l)
        if m: return m.group(1).strip()
    return None
status = collections.Counter(); verified = closed = 0; durations = []; stale_open = 0; attention = 0; per_week = collections.Counter()
now = dt.datetime.now()
for e in entries:
    L = e["lines"]; per_week[e["week"]] += 1
    st = [field([l], "Status") for l in L if l.startswith("**Status:**")]
    word = re.sub(r"[^\w ,]", "", (st[-1] if st else "missing")).strip() or "missing"
    status[word] += 1
    reserved = ts(field(L, "Reserved") or "")
    closed_at = next((ts(l) for l in L if l.startswith("### Closed")), None)
    if "Closed" in word:
        closed += 1
        v = field(L, "Verified by")
        if v and not re.match(r"(?i)^(not verified|none|n/?a|—|-)\b", v): verified += 1
        if reserved and closed_at: durations.append((closed_at - reserved).total_seconds() / 3600)
    elif reserved and (now - reserved).days > 2: stale_open += 1
    na = field(L, "Needs attention")
    if na and na.lower().startswith("yes"): attention += 1
p(f"  ledger files: {len(files)}; entries: {len(entries)}")
p(f"  by status: {dict(status)}")
p(f"  closed with a real Verified by: {verified}/{closed}" + (f" ({100 * verified / closed:.0f}%)" if closed else ""))
p(f"  reserve to close (hours): {stats(durations, 'h')}")
p(f"  open and reserved more than 2 days ago: {stale_open}")
p(f"  Needs attention: yes: {attention}")
p(f"  entries per week: {dict(sorted(per_week.items()))}")

# ---------------------------------------------------------------- C. registers
p(); p("C. REGISTERS")
trackers = glob.glob(os.path.join(root, "reports/**/BUG_TRACKER.md"), recursive=True)
for t in trackers:
    bug_status = collections.Counter(); bugs = 0; in_bug = False
    for line in open(t, encoding="utf-8", errors="replace"):
        if re.match(r"^## Bug \d+", line): bugs += 1; in_bug = True; continue
        if in_bug and line.startswith("**Status:**"):
            bug_status[re.sub(r"[^\w ,]", "", line.split(":**", 1)[1]).strip()] += 1; in_bug = False
    p(f"  {rel(t)}: {bugs} bugs; by status: {dict(bug_status)}")
if not trackers: notes.append("C1: no BUG_TRACKER.md under reports/")
notes.append("C2: fixed-unverified age needs a date on the status line; the tracker format has none")
sp = os.path.join(root, "STRUCTURAL_PROBLEMS.md")
if os.path.exists(sp):
    section = None; counts = collections.Counter()
    for line in open(sp, encoding="utf-8", errors="replace"):
        if line.startswith("## "): section = line[3:].strip(); continue
        if section and re.match(r"^\|\s*[A-Z]+-?\d", line): counts[section] += 1
    p(f"  STRUCTURAL_PROBLEMS.md rows by section: {dict(counts)}")

# ---------------------------------------------------------------- D. reports
p(); p("D. REPORTS")
for d in sorted(glob.glob(os.path.join(root, "reports/*/"))):
    n = len([f for f in glob.glob(os.path.join(d, "**/*.md"), recursive=True) if not f.endswith(("README.md", "BUG_TRACKER.md"))])
    p(f"  {rel(d).rstrip('/')}: {n} files")

# ---------------------------------------------------------------- E. git
p(); p("E. GIT")
GOV = ("ledger/", "reports/", ".claude/", "scripts/", "CLAUDE.md", "CONTEXT.md", "STRUCTURAL_PROBLEMS.md",
       "MODEL_DELEGATION.md", "FILE_SIZE_REVIEW.md", "prompts/", "docs/roadmap/", "bug-tracker-dashboard/", "governance.config")
commits = []
for line in open(git_log, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("@@"):
        d, _, subj = line[2:].partition("\t"); commits.append({"date": d, "subj": subj, "files": []})
    elif line and commits: commits[-1]["files"].append(line)
kind = collections.Counter()
for c in commits:
    g = [f.startswith(GOV) for f in c["files"]]
    kind["governance only" if g and all(g) else "app only" if g and not any(g) else "both" if g else "no files"] += 1
p(f"  commits (no merges): {len(commits)}; fix: {sum(c['subj'].lower().startswith('fix') for c in commits)}; "
  f"revert: {sum(c['subj'].lower().startswith('revert') for c in commits)}")
p(f"  by paths touched: {dict(kind)}")
if commits: p(f"  first {commits[-1]['date']}, last {commits[0]['date']}")
notes.append("E: --no-verify leaves no trace in git; bypass counts are not measurable from history")

# ---------------------------------------------------------------- F. transcripts
p(); p("F. TRANSCRIPTS")
GOV_T = re.compile(r"ledger/|publish-ledger-entry|next-ledger-id|check-ledger-entries|BUG_TRACKER|STRUCTURAL_PROBLEMS|reports/|bug-tracker-dashboard|dashboard-sync|prompts/SESSION")
sessions = sorted(glob.glob(os.path.join(tdir, "*.jsonl")))
if not sessions:
    p(f"  n/a: no transcripts in {tdir}")
else:
    keys = ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
    per = {k: [] for k in keys}; tools = collections.Counter(); gov_per = []; gov_total = tool_total = 0
    skills = collections.Counter(); slash = collections.Counter(); rules = collections.Counter(); dates = []; first_ctx = []
    for s in sessions:
        sid = os.path.basename(s)[:-6]
        paths = [s] + glob.glob(os.path.join(tdir, sid, "**/*.jsonl"), recursive=True)  # subagents belong to their session
        seen_msg, seen_tool = {}, set(); gov = 0; text_rules = set(); first = None
        for path in paths:
            for line in open(path, encoding="utf-8", errors="replace"):
                try: o = json.loads(line)
                except ValueError: continue
                if o.get("timestamp"): dates.append(o["timestamp"][:10])
                for r in re.findall(r"\.claude/rules/([\w.-]+\.md)", line): text_rules.add(r)
                for c in re.findall(r"<command-name>/?([\w:-]+)</command-name>", line): slash[c] += 1
                if o.get("type") != "assistant": continue
                m = o.get("message") or {}
                if m.get("usage") and m.get("id"):
                    seen_msg[m["id"]] = m["usage"]
                    if first is None and path == s:
                        u = m["usage"]; first = sum(u.get(k, 0) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
                for b in m.get("content") or []:
                    if not isinstance(b, dict) or b.get("type") != "tool_use" or b.get("id") in seen_tool: continue
                    seen_tool.add(b.get("id")); tools[b.get("name")] += 1; tool_total += 1
                    inp = b.get("input") or {}
                    if b.get("name") == "Skill": skills[inp.get("skill", "?")] += 1
                    if GOV_T.search(json.dumps(inp)): gov += 1
        for k in keys: per[k].append(sum((u.get(k) or 0) for u in seen_msg.values()))
        gov_per.append(gov); gov_total += gov
        if first is not None: first_ctx.append(first)
        for r in text_rules: rules[r] += 1
    p(f"  sessions: {len(sessions)}; dates {min(dates) if dates else '?'} to {max(dates) if dates else '?'}")
    for k in keys:
        p(f"  {k} per session: median {statistics.median(per[k]):.0f}, p90 {q(per[k], .9)}, total {sum(per[k])}")
    p(f"  context at first model call (startup cost): {stats(first_ctx, ' tok')}")
    p(f"  tool calls: {tool_total}; by tool: {dict(tools.most_common())}")
    p(f"  governance tool calls: {gov_total} ({100 * gov_total / tool_total:.0f}% of all)" if tool_total else "  governance tool calls: 0")
    p(f"  governance tool calls per session: median {statistics.median(gov_per):.0f}")
    p(f"  Skill tool invocations: {dict(skills.most_common())}")
    p(f"  slash commands: {dict(slash.most_common())}")
    p(f"  sessions mentioning each rule file: {dict(rules.most_common())}")

# ---------------------------------------------------------------- G. hook logs
p(); p("G. HOOK LOGS")
for log in glob.glob(os.path.expanduser("~/.claude/*session-end-sync.log")):
    lines = open(log, encoding="utf-8", errors="replace").read().splitlines()
    p(f"  {os.path.basename(log)}: {len(lines)} lines; SKIPPED: {sum('SKIPPED' in l for l in lines)}")
sync = os.path.join(root, "ledger/SYNC_LOG.tsv")
if os.path.exists(sync):
    rows = [l.split("\t") for l in open(sync, encoding="utf-8", errors="replace") if l.strip() and not l.startswith("#")]
    p(f"  ledger/SYNC_LOG.tsv: {len(rows)} rows")

p(); p("NOTES")
for n in notes: p(f"  - {n}")
print("\n".join(out))
PY
