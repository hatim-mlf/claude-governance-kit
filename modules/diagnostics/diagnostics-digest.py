#!/usr/bin/env python3
"""Daily digest of what the diagnostics intake received (modules/diagnostics, Supabase backend).

Read-only. Every query filters on received_at (indexed) and has LIMIT <= 500.
Needs the Supabase CLI linked to the project (npx supabase) and DIAGNOSTICS_SUPABASE_REF set to the
project ref; DIAGNOSTICS_APP_BINARY names the app's own binary in crash stacks (MetricKit payloads).
Schedule it daily (cron, launchd) and send the summary line somewhere it is read.
Usage: diagnostics-digest.py [--hours N] [--out-dir DIR]
Prints the one-line summary on stdout; writes reports/diagnostics/digest-YYYY-MM-DD.md.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PROJECT_REF = os.environ.get("DIAGNOSTICS_SUPABASE_REF", "")
APP_BINARY = os.environ.get("DIAGNOSTICS_APP_BINARY", "")
# -o json: without a terminal (launchd) the CLI otherwise prints a table.
CLI = ["npx", "-y", "supabase@2.120.0", "db", "query", "--linked", "--project-ref", PROJECT_REF, "-o", "json"]
MAX_ROWS = 500
MAX_CRASHES = 50
MAX_REPORTS = 50
NOTE_PREVIEW = 200
NEW_LOOKBACK_DAYS = 30  # bounded so the "seen before?" check stays an index range scan
QUERY_TIMEOUT_S = 120
SAFE_CODE = re.compile(r"^[a-z0-9_.]{1,64}$")  # same shape the table enforces


def parse_rows(out):
    """The CLI's -o json output: a bare list of rows (no terminal, e.g. launchd) or, when it detects an AI agent,
    an object with "rows". Either way, the rows."""
    text = out.strip()
    start = min([i for i in (text.find("["), text.find("{")) if i >= 0], default=-1)
    if start < 0:
        raise ValueError("no JSON in output")
    value, _ = json.JSONDecoder().raw_decode(text[start:])
    return value if isinstance(value, list) else value.get("rows", [])


def run_query(sql):
    proc = subprocess.run(CLI + [sql], capture_output=True, text=True, timeout=QUERY_TIMEOUT_S)
    out = proc.stdout
    try:
        if proc.returncode != 0:
            raise ValueError("exit %d" % proc.returncode)
        return parse_rows(out)
    except ValueError as e:
        raise RuntimeError("query failed (%s): %s" % (e, (proc.stderr or out)[:400]))


def clean(value, limit=64):
    """Database text is untrusted: flatten to a short, markdown-safe token."""
    text = re.sub(r"[^A-Za-z0-9_.,\-+ /:]", "?", str(value))
    return text[:limit]


def window_sql(hours):
    return "received_at > now() - interval '%d hours'" % hours


def is_dev(row):
    """Rows from dev and test builds carry app_version "dev-..."."""
    return row.get("is_dev") in (True, "t", "true")


def fetch_codes(hours):
    """Real and dev rows are queried apart, each with its own limits, so a noisy dev session cannot push
    real rows out of them."""
    rows = []
    for dev in (False, True):
        sql = (
            "select category, code, %s as is_dev, count(*) as n, "
            "count(distinct install_id) as installs, string_agg(distinct build, ',') as builds "
            "from (select category, code, install_id, build from diagnostics.events "
            "where %s and app_version %s like 'dev-%%' order by received_at desc limit 20000) w "
            "group by category, code order by n desc limit %d"
            % ("true" if dev else "false", window_sql(hours), "" if dev else "not", MAX_ROWS)
        )
        rows += run_query(sql)
    return rows


def fetch_known_codes(codes, hours):
    """Codes from `codes` that also appeared before the window (bounded lookback)."""
    safe = [c for c in codes if SAFE_CODE.match(c)]
    if not safe:
        return set()
    values = ",".join("('%s')" % c for c in safe[:MAX_ROWS])
    sql = (
        "select c.code from (values %s) as c(code) where exists (select 1 from diagnostics.events e "
        "where e.code = c.code and e.app_version not like 'dev-%%' and e.received_at < now() - interval '%d hours' "
        "and e.received_at > now() - interval '%d days') limit %d"
        % (values, hours, NEW_LOOKBACK_DAYS, MAX_ROWS)
    )
    return {r["code"] for r in run_query(sql)}


def fetch_crashes(hours):
    rows = []
    for dev in (False, True):
        sql = (
            "select id, received_at, install_id, build, device_model, kind, payload, %s as is_dev "
            "from diagnostics.crashes where %s and app_version %s like 'dev-%%' "
            "order by received_at desc limit %d"
            % ("true" if dev else "false", window_sql(hours), "" if dev else "not", MAX_CRASHES)
        )
        rows += run_query(sql)
    return rows


def frame_label(frame):
    name = clean(frame.get("binaryName", "?"), 48)
    offset = frame.get("offsetIntoBinaryTextSegment")
    return "%s+%s" % (name, offset) if offset is not None else name


def frame_chain(payload):
    """Frames of the attributed thread, top of stack first (MetricKit: root = crash site)."""
    if not isinstance(payload, dict):
        return []
    tree = payload.get("callStackTree")
    stacks = tree.get("callStacks", []) if isinstance(tree, dict) else []
    attributed = next((s for s in stacks if isinstance(s, dict) and s.get("threadAttributed")), None)
    if attributed is None:
        return []
    chain = []
    level = attributed.get("callStackRootFrames", [])
    while isinstance(level, list) and level and isinstance(level[0], dict):
        chain.append(level[0])
        level = level[0].get("subFrames", [])
    return chain


def top_frames(payload, count=3):
    return [frame_label(f) for f in frame_chain(payload)[:count]]


def app_frames(payload, count=3):
    app = [f for f in frame_chain(payload) if f.get("binaryName") == APP_BINARY]
    return [frame_label(f) for f in app[:count]]


def code_lines(codes, new_codes):
    if not codes:
        return ["None."]
    lines = ["| Code | Count | Installs | Builds | |", "|---|---|---|---|---|"]
    for c in codes:
        flag = "**NEW**" if c["code"] in new_codes else ""
        lines.append("| %s | %s | %s | %s | %s |" % (
            clean(c["code"]), int(c["n"]), int(c["installs"]), clean(c.get("builds") or "", 48), flag))
    return lines


def crash_lines(crashes):
    if not crashes:
        return ["None."]
    lines = ["| Kind | Build | Device | Install | Top of stack | First app frames |", "|---|---|---|---|---|---|"]
    for r in crashes:
        payload = r.get("payload")
        frames = ", ".join("`%s`" % f for f in top_frames(payload)) or "no attributed thread"
        mine = ", ".join("`%s`" % f for f in app_frames(payload)) or "none"
        lines.append("| %s | %s | %s | %s | %s | %s |" % (
            clean(r["kind"], 8), clean(r["build"], 16), clean(r["device_model"], 32),
            clean(r["install_id"], 8), frames, mine))
    return lines


def fetch_reports(hours):
    """Reports users chose to send: newest first, the note cut in the query so little leaves the table."""
    sql = ("select id, received_at, topic, app_version, build, device_model, left(note, %d) as note "
           "from diagnostics.reports where %s order by received_at desc limit %d"
           % (NOTE_PREVIEW, window_sql(hours), MAX_REPORTS))
    return run_query(sql)


def report_lines(reports):
    if not reports:
        return ["None."]
    lines = ["| Id | Topic | Version | Device | Note (first %d characters) |" % NOTE_PREVIEW, "|---|---|---|---|---|"]
    for r in reports:
        lines.append("| %s | %s | %s%s | %s | %s |" % (
            int(r["id"]), clean(r["topic"], 16), clean(r.get("app_version") or "", 24),
            " (dev)" if str(r.get("app_version") or "").startswith("dev-") else "",
            clean(r["device_model"], 32), clean(r.get("note") or "", NOTE_PREVIEW).replace("|", "?")))
    return lines


def build_report(hours, codes, known, crashes, now, reports=()):
    """Real users first; dev-build rows (app_version "dev-...") in their own short section."""
    real_codes = [c for c in codes if not is_dev(c)]
    dev_codes = [c for c in codes if is_dev(c)]
    real_crashes = [r for r in crashes if not is_dev(r)]
    dev_crashes = [r for r in crashes if is_dev(r)]
    new_codes = new_codes_set([c for c in real_codes if c["code"] not in known])
    summary = "%d event code(s), %d NEW; %d crash/hang/cpu report(s) in the last %dh" % (
        len(real_codes), len(new_codes), len(real_crashes), hours)
    summary += "; %d user report(s)" % len(reports)
    summary += " (dev builds: %d event(s) in %d code(s), %d crash report(s))" % (
        sum(int(c["n"]) for c in dev_codes), len(dev_codes), len(dev_crashes))
    lines = ["# Diagnostics digest %s" % now.strftime("%Y-%m-%d"), "", "**%s**" % summary, "",
             "Window: last %d hours, generated %s. NEW = not seen in the %d days before the window. "
             "Real users only above the Dev builds section." % (
                 hours, now.strftime("%Y-%m-%d %H:%M"), NEW_LOOKBACK_DAYS), "",
             "## Codes seen", ""]
    lines += code_lines(real_codes, new_codes)
    lines += ["", "## Crashes, hangs and CPU reports", ""] + crash_lines(real_crashes)
    lines += ["", "## Reports from users", ""] + report_lines(reports)
    lines += ["", "## Dev builds (app_version dev-...)", "",
              "%d event(s) in %d code(s), %d crash report(s). Not real users." % (
                  sum(int(c["n"]) for c in dev_codes), len(dev_codes), len(dev_crashes))]
    if dev_codes:
        lines += [""] + code_lines(dev_codes, set())
    if dev_crashes:
        lines += [""] + crash_lines(dev_crashes)
    if len(real_crashes) >= MAX_CRASHES or len(dev_crashes) >= MAX_CRASHES or len(real_codes) >= MAX_ROWS or len(dev_codes) >= MAX_ROWS or len(reports) >= MAX_REPORTS:
        lines += ["", "Note: a row limit was reached; the list is truncated."]
    return summary, "\n".join(lines) + "\n"


def new_codes_set(new_codes):
    return {c["code"] for c in new_codes}


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--out-dir", default=str(Path(__file__).resolve().parent.parent / "reports" / "diagnostics"))
    args = parser.parse_args(argv)
    if not 1 <= args.hours <= 24 * 30:
        parser.error("--hours must be between 1 and 720")
    if not PROJECT_REF:
        parser.error("set DIAGNOSTICS_SUPABASE_REF to the Supabase project ref")
    now = datetime.datetime.now()
    codes = fetch_codes(args.hours)
    known = fetch_known_codes([c["code"] for c in codes], args.hours)
    crashes = fetch_crashes(args.hours)
    reports = fetch_reports(args.hours)
    summary, body = build_report(args.hours, codes, known, crashes, now, reports)
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / ("digest-%s.md" % now.strftime("%Y-%m-%d"))).write_text(body)
    print(summary)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # report, never hide, a failed run
        print("diagnostics digest failed: %s" % exc, file=sys.stderr)
        sys.exit(1)
