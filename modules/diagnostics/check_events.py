#!/usr/bin/env python3
"""Validate events against contract.json: the language-neutral contract test.

A client test writes every event its features can send (one of each code) to a JSON array file;
this exits 1, naming each event that breaks the contract: either the server refuses it, or the
contract forbids it (a context key not on the allowed list). Read-only, no network.
  python3 -I check_events.py events.json [--contract contract.json]
"""
import argparse, datetime, json, re, sys
from pathlib import Path


def problems(event, c):
    e = c["event"]
    if not isinstance(event, dict):
        return ["not an object"]
    out = [f"missing {k}" for k in e["required"] if k not in event]
    out += [f"{k} is not a non-empty string" for k in e["required"]
            if k in event and (not isinstance(event[k], str) or not event[k])]
    if isinstance(event.get("occurred_at"), str):
        try:
            datetime.datetime.fromisoformat(event["occurred_at"].replace("Z", "+00:00"))
        except ValueError:
            out.append("occurred_at is not an ISO 8601 time")
    if "session_id" in event and not re.fullmatch(e["pattern"]["install_id"], str(event["session_id"])):
        out.append("session_id is not a UUID")
    out += [f"unknown field {k}" for k in event if k not in e["required"] + e["optional"]]
    out += [f"{k} does not match {p}" for k, p in e["pattern"].items()
            if k in event and not re.fullmatch(p, str(event[k]))]
    out += [f"{k} longer than {n}" for k, n in e["maxLength"].items() if len(str(event.get(k, ""))) > n]
    ctx = event.get("context", {})
    if not isinstance(ctx, dict):
        return out + ["context is not an object"]
    rules = e["context"]
    out += [f"context key {k} not allowed" for k in ctx if k not in rules["allowedKeys"]]
    out += [f"context {k} is not a string, number or boolean" for k, v in ctx.items()
            if not isinstance(v, (str, int, float, bool))]
    out += [f"context {k} text longer than {rules['maxTextLength']}" for k, v in ctx.items()
            if isinstance(v, str) and len(v) > rules["maxTextLength"]]
    if len(json.dumps(ctx).encode()) > rules["maxBytes"]:
        out.append("context too large")
    return out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("events")
    ap.add_argument("--contract", default=str(Path(__file__).with_name("contract.json")))
    a = ap.parse_args(argv)
    contract = json.loads(Path(a.contract).read_text())
    events = json.loads(Path(a.events).read_text())
    if not isinstance(events, list) or not events:
        print("no events: the file must hold a non-empty JSON array")
        return 1
    bad = [(i, p) for i, ev in enumerate(events) for p in problems(ev, contract)]
    for i, p in bad:
        print(f"event {i} ({events[i].get('code', '?')}): {p}")
    print(f"{len(events)} event(s), {len({i for i, _ in bad})} breaking the contract")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
