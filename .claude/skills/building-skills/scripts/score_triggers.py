#!/usr/bin/env python3
"""Trigger scorer for skills, run against REAL skill folders.

Each run gets its own throwaway project holding a copy of the neighbour skills (and, in
candidate mode, the candidate written as a real SKILL.md), so parallel runs never see each
other. It watches up to MAX_TOOL_CALLS tool calls, because the model often orients (Glob, Read)
before choosing a skill; a first-tool-only rule undercounts.

Runs are confined: built-in tools limited to SAFE_TOOLS (no Bash, no edits), no MCP servers,
permission mode dontAsk. A run that errors or times out is counted as an ERROR, never as a
miss; rates use only the runs that finished, and the exit code is 4 when any run errored.

Why not skill-creator's run_eval.py (faults found 2026-11-25, debate on building-skills):
  1. it returns "not triggered" at the first non-Skill/Read tool call;
  2. parallel workers share one .claude/commands/, so up to N copies of the candidate coexist
     and the model can pick a sibling's copy, scored as a miss;
  3. it installs the description as a command, not the real SKILL.md, so YAML faults in the
     real file go untested;
  4. a failed `claude -p` run is scored as a miss (seen here when a usage limit hit mid-run).

Usage:
  score_triggers.py --corpus DIR --queries FILE [--candidate NAME --desc-file FILE]
                    [--runs 3] [--workers 6] [--timeout 180] [--out FILE]
  --queries: a list [{"query","should_trigger"}] (needs --candidate), or a map
             {skill_name: [...]} scoring existing skills in the corpus.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor

MAX_TOOL_CALLS = 6   # orientation seen in runs: 1-2 calls before the Skill call
MAJORITY = 0.5       # skill-creator's default threshold, kept for comparability
SAFE_TOOLS = "Skill,Read,Glob,Grep"  # enough to choose a skill; nothing that writes or runs
ERRORS_EXIT = 4
HIT, MISS, ERROR = "hit", "miss", "error"


def make_project(corpus: str, candidate: str | None, desc: str | None) -> str:
    root = tempfile.mkdtemp(prefix="trig-")
    shutil.copytree(corpus, os.path.join(root, ".claude", "skills"))
    if candidate:
        d = os.path.join(root, ".claude", "skills", candidate)
        os.makedirs(d, exist_ok=True)
        # json.dumps gives a double-quoted scalar, which is valid YAML for any text
        with open(os.path.join(d, "SKILL.md"), "w") as f:
            f.write(f"---\nname: {candidate}\ndescription: {json.dumps(desc)}\n---\n\n"
                    f"# {candidate}\n\nFollow the steps for this task.\n")
    return root


def classify(event: dict, target: str) -> tuple[str, str] | None:
    """Return (outcome, detail) once a tool call decides the run, else None."""
    for c in event.get("message", {}).get("content", []):
        if c.get("type") != "tool_use":
            continue
        name, inp = c.get("name", ""), c.get("input", {})
        if name == "Skill":
            chosen = str(inp.get("skill", "")).split(":")[-1]
            return (HIT, "") if chosen == target else (MISS, f"skill:{chosen}")
        if name == "Read" and f"/{target}/SKILL.md" in str(inp.get("file_path", "")):
            return HIT, ""
    return None


def kill_group(proc: subprocess.Popen) -> None:
    """Kill claude and its children, which would otherwise hold the output pipe open."""
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        return  # already gone


def watch(project: str, query: str, target: str, timeout: float) -> tuple[str, str]:
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose",
           "--tools", SAFE_TOOLS, "--strict-mcp-config", "--permission-mode", "dontAsk"]
    try:
        proc = subprocess.Popen(cmd, cwd=project, env=env, text=True, start_new_session=True,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as exc:
        return ERROR, f"cannot start claude: {exc}"
    timer = threading.Timer(timeout, kill_group, (proc,))
    timer.start()
    calls, saw_assistant = 0, False
    try:
        for line in proc.stdout:
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if ev.get("type") == "result":
                if ev.get("is_error") and not saw_assistant:
                    return ERROR, f"claude result error: {str(ev.get('result', ''))[:80]}"
                return MISS, "no-skill"
            if ev.get("type") != "assistant":
                continue
            saw_assistant = True
            decided = classify(ev, target)
            if decided:
                return decided
            calls += sum(c.get("type") == "tool_use" for c in ev["message"].get("content", []))
            if calls >= MAX_TOOL_CALLS:
                return MISS, "no-skill"
        if not timer.is_alive():
            return ERROR, f"timeout after {timeout:.0f}s"
        return ERROR, f"claude exited ({proc.wait()}) without a result"
    finally:
        timer.cancel()
        kill_group(proc)
        proc.wait()


def one_run(args: argparse.Namespace, target: str, query: str, desc: str | None) -> tuple[str, str]:
    project = make_project(args.corpus, args.candidate, desc)
    try:
        return watch(project, query, target, args.timeout)
    finally:
        shutil.rmtree(project, ignore_errors=True)


def summarise(jobs: list, outs: list) -> dict:
    rows: dict = {}
    for (target, q), (outcome, detail) in zip(jobs, outs):
        r = rows.setdefault((target, q["query"]), {
            "query": q["query"], "should_trigger": q["should_trigger"],
            "hits": 0, "runs": 0, "errors": 0, "instead": []})
        if outcome == ERROR:
            r["errors"] += 1
        else:
            r["runs"] += 1
            r["hits"] += outcome == HIT
        if detail:
            r["instead"].append(detail)
    summary: dict = {}
    for (target, _), r in rows.items():
        s = summary.setdefault(target, {"pos_missed": 0, "neg_fired": 0, "errors": 0,
                                        "inconclusive": 0, "rows": []})
        s["errors"] += r["errors"]
        if r["runs"] == 0:
            r["pass"] = None
            s["inconclusive"] += 1
        else:
            rate = r["hits"] / r["runs"]
            r["pass"] = rate >= MAJORITY if r["should_trigger"] else rate < MAJORITY
            if not r["pass"]:
                s["pos_missed" if r["should_trigger"] else "neg_fired"] += 1
        s["rows"].append(r)
    return summary


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--queries", required=True)
    ap.add_argument("--candidate")
    ap.add_argument("--desc-file")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--timeout", type=float, default=180, help="seconds per run")
    ap.add_argument("--out")
    args = ap.parse_args()

    with open(args.queries) as f:
        data = json.load(f)
    desc = open(args.desc_file).read().strip() if args.desc_file else None
    if isinstance(data, list):
        if not (args.candidate and desc):
            ap.error("a query list needs --candidate and --desc-file")
        data = {args.candidate: data}

    jobs = [(t, q) for t, qs in data.items() for q in qs for _ in range(args.runs)]
    with ThreadPoolExecutor(args.workers) as ex:
        outs = list(ex.map(lambda j: one_run(args, j[0], j[1]["query"], desc), jobs))
    summary = summarise(jobs, outs)

    text = json.dumps({"description": desc, "max_tool_calls": MAX_TOOL_CALLS, "tools": SAFE_TOOLS,
                       "runs": args.runs, "scores": summary}, indent=1, ensure_ascii=False)
    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
    errors = 0
    for t, s in summary.items():
        n_pos = sum(r["should_trigger"] for r in s["rows"])
        print(f"{t}: missed {s['pos_missed']}/{n_pos} should-trigger, "
              f"fired {s['neg_fired']}/{len(s['rows']) - n_pos} near-misses, "
              f"{s['errors']} run errors, {s['inconclusive']} queries inconclusive")
        errors += s["errors"]
    if errors:
        print(f"WARNING: {errors} runs errored; re-run before trusting these numbers",
              file=sys.stderr)
        return ERRORS_EXIT
    return 0


if __name__ == "__main__":
    sys.exit(main())
