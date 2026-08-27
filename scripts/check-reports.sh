#!/usr/bin/env bash
#
# check-reports.sh — warn when the reports the system asks for were not written.
#
# Register row U-31c in the project this came from. The rule "every bug row gets a report file, both in the same pass"
# was followed 11 times in 73 rows, and nothing checked it — so it read as optional to
# anyone working from the repository rather than the skill. CLAUDE.md's own doctrine:
# a rule that nothing checks is a wish.
#
# **Both checks are deliberately narrow, and the narrowness is the design.** The obvious
# versions were measured first and rejected for firing so often they would be bypassed
# into meaninglessness, which is the other failure the Enforcement section names:
#
#   every row needs a report file .................. 50 rows would fire
#   every ledger entry needs a session report ...... 73 entries would fire
#   only VERIFIED rows need a report file ........... 8 rows  ← chosen
#   a week with real activity needs one report ...... 0 weeks ← chosen
#
# Warn tier. Never blocks: a missing write-up is not a reason to refuse a commit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 0

TRACKER="reports/bugs reports/BUG_TRACKER.md"
[ -f "$TRACKER" ] || exit 0

# A week is worth a session report once it has this many closed entries. Chosen so the
# check is green on a normal week and fires on a thread like 2026-W35's sixteen.
BUSY_WEEK_ENTRIES="${BUSY_WEEK_ENTRIES:-5}"

python3 - "$BUSY_WEEK_ENTRIES" <<'PY'
import re, glob, sys, os, datetime

busy = int(sys.argv[1])
problems = []

# --- 1. A row claiming "Fixed, verified" must cite its evidence in a report file. -------
# Verified is the state other work relies on: it asserts a capture exists. The report is
# where that capture is named, so a verified row with no report is a claim with nowhere to
# check it. Unverified and open rows are exempt — the tracker row genuinely carries them.
tracker = open("reports/bugs reports/BUG_TRACKER.md", errors="ignore").read()
bug_reports = " ".join(open(f, errors="ignore").read() for f in glob.glob("reports/bugs/*.md"))
missing = []
for row in re.split(r"\n## Bug ", tracker)[1:]:
    m = re.match(r"(\d+[a-z]?)", row)
    if not m:
        continue
    num, head = m.group(1), row[:900]
    if "Fixed, verified" not in head:
        continue
    if not re.search(rf"Bug {num}\b", bug_reports):
        missing.append(num)
if missing:
    problems.append(
        "Bug rows marked ✅ Fixed, verified with no file in reports/bugs/ citing them:\n"
        f"    {', '.join(missing)}\n"
        "    'Verified' asserts a capture exists. The report is where it is named."
    )

# --- 2. A week with real activity should have a session report. -------------------------
# Per week, not per entry: 73 of 106 entries have never been cited by one, so a per-entry
# rule would fire on almost everything. A week is the unit a person actually writes up.
weeks = {}
for f in glob.glob("ledger/*/[0-9]*.md") + glob.glob("ledger/[0-9]*.md"):
    text = open(f, errors="ignore").read()
    for eid in re.findall(r"^## (\d{4}-W\d{2})-\d+", text, re.M):
        weeks[eid] = weeks.get(eid, 0) + 1

def week_of(path):
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", os.path.basename(path))
    if not m:
        return None
    y, mo, d = map(int, m.groups())
    iso = datetime.date(y, mo, d).isocalendar()
    return f"{iso[0]}-W{iso[1]:02d}"

reported = {week_of(f) for f in glob.glob("reports/sessions/*.md")}
reported.discard(None)

# Only the current week is reported on. Weeks already past are history and warning about
# them forever is how a check stops being read.
today = datetime.date.today().isocalendar()
current = f"{today[0]}-W{today[1]:02d}"
if weeks.get(current, 0) >= busy and current not in reported:
    problems.append(
        f"{current} has {weeks[current]} ledger entries and no session report.\n"
        "    reports/sessions/YYYY-MM-DD_<slug>.md — see the session-report skill.\n"
        "    The skill triggers on a session *ending*; a long thread never fires that."
    )

if problems:
    print("\nReports the system asks for — worth a look")
    for p in problems:
        print(f"  {p}")
    print("\n  Register row U-31c in the project this came from. Warn only; nothing is blocked.")
PY
exit 0
