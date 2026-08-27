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
#
# A calendar-week trigger was tried on 2026-08-27 and withdrawn the same night: the
# operator called it illogical, and they were right. A session is a piece of work — a bug,
# a roadmap row, an audit — not an interval. The entry-shape checks below replace it, and
# they run against STAGED entries only, so they are enforceable from today rather than
# retroactively correct and ignored.
#
# Warn tier. Never blocks: a missing write-up is not a reason to refuse a commit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 0

TRACKER="reports/bugs reports/BUG_TRACKER.md"
[ -f "$TRACKER" ] || exit 0

python3 - <<'PY'
import re, glob, os

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

# --- 2. Every ledger entry declares why it exists, and how it ended. --------------------
# Staged entries only, deliberately. The repository holds 107 closed entries; 42 of their
# `Report:` lines resolve to nothing and 53 never named a session prompt. Warning about all
# of that would be right in principle and ignored by the second commit. Scoped to what the
# commit touches, the rule is enforceable from today and the backlog stays visible in
# U-31c rather than in every commit.
#
# A session is a piece of *work*, not an interval — a bug, a roadmap row, an audit. So an
# entry has to say which, and a closed one has to say where the write-up went.
staged = os.popen("git diff --cached --name-only 2>/dev/null").read().split()
ledger_files = [f for f in staged if re.match(r"ledger/.*\d{4}-\d{2}-\d{2}\.md$", f)]

undeclared, unresolved = [], []
for f in ledger_files:
    if not os.path.exists(f):
        continue
    text = open(f, errors="ignore").read()
    for block in re.split(r"\n(?=## \d{4}-W\d{2}-\d+)", text):
        m = re.match(r"## (\d{4}-W\d{2}-\d+)", block)
        if not m:
            continue
        eid = m.group(1)
        head = block[:1500]
        if not re.search(r"\*\*(Tracker row|Roadmap row|Session prompt):\*\*", head):
            undeclared.append(eid)
        if "### Closed" in block:
            rep = re.search(r"\*\*Report:\*\*\s*(.{0,400})", block, re.S)
            if not rep:
                unresolved.append(f"{eid} (no Report: line)")
                continue
            paths = re.findall(r"`?((?:reports|docs|prompts)/[^\s`,;)]+\.md)`?", rep.group(1))
            named_row = re.search(r"\b(Bug \d+[a-z]?|U-\d+[a-z]?|§\d+\.\d+)\b", rep.group(1))
            if paths:
                gone = [p for p in paths if not os.path.exists(p)]
                if gone:
                    unresolved.append(f"{eid} -> {', '.join(gone)} does not exist")
            elif not named_row:
                unresolved.append(f"{eid} (Report: names neither a file nor a row)")

if undeclared:
    problems.append(
        "Ledger entries with no Tracker row / Roadmap row / Session prompt:\n"
        f"    {', '.join(undeclared)}\n"
        "    An entry has to say what work it belongs to — that is what makes it a session."
    )
if unresolved:
    problems.append(
        "Closed entries whose Report: does not resolve:\n"
        + "".join(f"    {u}\n" for u in unresolved)
        + "    Name a file under reports/ that exists, or the row it was filed as."
    )

if problems:
    print("\nReports the system asks for — worth a look")
    for p in problems:
        print(f"  {p}")
    print("\n  Register row U-31c in the project this came from. Warn only; nothing is blocked.")
PY
exit 0
