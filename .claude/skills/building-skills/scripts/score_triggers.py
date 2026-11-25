#!/usr/bin/env python3
"""Trigger scorer for skills, run against REAL skill folders.

Each run gets its own throwaway project holding a copy of the neighbour skills (and, in
candidate mode, the candidate skill written as a real SKILL.md), so parallel runs never see
each other. It watches up to MAX_TOOL_CALLS tool calls, because the model often orients
(ls, find) before choosing a skill; a first-tool-only rule undercounts.

Why not skill-creator's run_eval.py (faults found 2026-11-25, debate on building-skills):
  1. it returns "not triggered" at the first non-Skill/Read tool call;
  2. parallel workers share one .claude/commands/, so up to N copies of the candidate coexist
     and the model can pick a sibling's copy, scored as a miss;
  3. it installs the description as a command, not the real SKILL.md, so YAML faults in the
     real file go untested.

Usage:
  score_triggers.py --corpus DIR --queries FILE [--candidate NAME --desc-file FILE]
                    [--runs 3] [--workers 6] [--out FILE]
  --queries: a list [{"query","should_trigger"}] (needs --candidate), or a map
             {skill_name: [...]} scoring existing skills in the corpus.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor

MAX_TOOL_CALLS = 6   # orientation seen in runs: 1-2 Bash calls before the Skill call
RUN_TIMEOUT_S = 180  # a run that has not chosen within this is scored as not triggered
MAJORITY = 0.5       # skill-creator's default threshold, kept for comparability


def make_project(corpus: str, candidate: str | None, desc: str | None) -> str:
    root = tempfile.mkdtemp(prefix="trig-")
    skills = os.path.join(root, ".claude", "skills")
    shutil.copytree(corpus, skills)
    if candidate:
        d = os.path.join(skills, candidate)
        os.makedirs(d, exist_ok=True)
        # json.dumps gives a double-quoted scalar, which is valid YAML for any text
        with open(os.path.join(d, "SKILL.md"), "w") as f:
            f.write(f"---\nname: {candidate}\ndescription: {json.dumps(desc)}\n---\n\n"
                    f"# {candidate}\n\nFollow the steps for this task.\n")
    return root


def watch(project: str, query: str, target: str) -> tuple[bool, str]:
    """Return (fired, what_happened). what_happened names a competing skill if one won."""
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    proc = subprocess.Popen(["claude", "-p", query, "--output-format", "stream-json",
                             "--verbose"], cwd=project, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    calls = 0
    try:
        for line in proc.stdout:
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if ev.get("type") == "result":
                return False, "no-skill"
            if ev.get("type") != "assistant":
                continue
            for c in ev.get("message", {}).get("content", []):
                if c.get("type") != "tool_use":
                    continue
                calls += 1
                name, inp = c.get("name", ""), c.get("input", {})
                if name == "Skill":
                    chosen = str(inp.get("skill", "")).split(":")[-1]
                    return (chosen == target), ("" if chosen == target else f"skill:{chosen}")
                if name == "Read" and f"/{target}/SKILL.md" in str(inp.get("file_path", "")):
                    return True, ""
                if calls >= MAX_TOOL_CALLS:
                    return False, "no-skill"
        return False, "no-skill"
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()


def one_run(args, target: str, query: str, desc: str | None) -> tuple[bool, str]:
    project = make_project(args.corpus, args.candidate, desc)
    try:
        return watch(project, query, target)
    finally:
        shutil.rmtree(project, ignore_errors=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--queries", required=True)
    ap.add_argument("--candidate")
    ap.add_argument("--desc-file")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--out")
    args = ap.parse_args()

    data = json.load(open(args.queries))
    desc = open(args.desc_file).read().strip() if args.desc_file else None
    if isinstance(data, list):
        if not (args.candidate and desc):
            ap.error("a query list needs --candidate and --desc-file")
        data = {args.candidate: data}

    jobs = [(t, q) for t, qs in data.items() for q in qs for _ in range(args.runs)]
    with ThreadPoolExecutor(args.workers) as ex:
        outs = list(ex.map(lambda j: one_run(args, j[0], j[1]["query"], desc), jobs))

    summary: dict = {}
    rows: dict = {}
    for (target, q), (hit, why) in zip(jobs, outs):
        r = rows.setdefault((target, q["query"]), {"query": q["query"],
                            "should_trigger": q["should_trigger"], "hits": 0, "runs": 0,
                            "instead": []})
        r["hits"] += hit
        r["runs"] += 1
        if why:
            r["instead"].append(why)
    for (target, _), r in rows.items():
        rate = r["hits"] / r["runs"]
        r["pass"] = rate >= MAJORITY if r["should_trigger"] else rate < MAJORITY
        s = summary.setdefault(target, {"pos_missed": 0, "neg_fired": 0, "rows": []})
        if not r["pass"]:
            s["pos_missed" if r["should_trigger"] else "neg_fired"] += 1
        s["rows"].append(r)
    text = json.dumps({"description": desc, "max_tool_calls": MAX_TOOL_CALLS,
                       "runs": args.runs, "scores": summary}, indent=1, ensure_ascii=False)
    if args.out:
        open(args.out, "w").write(text)
    for t, s in summary.items():
        n_pos = sum(r["should_trigger"] for r in s["rows"])
        print(f"{t}: missed {s['pos_missed']}/{n_pos} should-trigger, "
              f"fired {s['neg_fired']}/{len(s['rows']) - n_pos} near-misses")


if __name__ == "__main__":
    main()
