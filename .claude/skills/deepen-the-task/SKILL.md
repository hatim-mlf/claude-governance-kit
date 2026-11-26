---
name: deepen-the-task
description: >-
  Deepen a feature request before building it: a professional's habits, the rawest material,
  the methods, outside proof, then the request rewritten. Use before a new feature, or on
  "deeper".
---

# Deepen the task

A request arrives already digested: someone's summary, a feature name, an idea of where it goes. Built as
written, it gets the shallow version. This skill turns it into the version a top professional would
build, at the **same scope**: deeper, not bigger. Nothing is built here. The output is four answers
and a rewritten request, handed to the user for a go.

## Steps

### 1. Name the field and the professional

One line: the request as written, then the field it belongs to (sensor fusion, payments, typography,
search ranking, …) and the professional who does it for a living (a firmware engineer at a device
maker, a survey statistician, …). Several fields → name each; the questions below run per field.

**Done when** the professional is specific enough that you could name the documents they read.

### 2. What they would do that the request does not ask

List what that professional does by habit on this kind of work, that the request leaves out: the
check they always run, the failure they always design for, the measurement they take before choosing.
Each item says **why** they do it, and what goes wrong without it.

Keep it at the request's scope. An item that adds a feature belongs on a "later" list, not here.

**Done when** each item is a concrete practice tied to this request, never a virtue ("be careful",
"test well"), and at least one item would change how the work is done.

### 3. The rawest material

Name what they start from instead of what has already been digested: the sensor's raw samples, not
the derived series; the primary spec, manual, patent, standard or source code, not a blog or a
summary; the logged data, not the last session's numbers about it. For each one: where it is (a path,
a URL, an API), and if it does not exist yet, what would record it.

Name the digested material too, so the rewrite can tell the session to treat it as a hypothesis.

**Done when** every source has a location or a named way to get it.

### 4. Methods and tools

Name the specific methods (an estimator, a statistic, a test design, a protocol) and the tools
(libraries, instruments, harnesses already in the repository) the professional would use, each with
the question it answers. Prefer what the repository already has over new dependencies.

**Done when** each method names its question, and nothing is a category ("some filtering", "analytics").

### 5. Outside proof

Say what, other than the user and the agent agreeing, will show the result is right:

- **Ground truth**: an independent measurement of the same quantity.
- **Bars set before building**: numbers the result must meet, written down before any option is
  scored, so the result cannot move the goalposts.
- **Held-out data**: cases kept back from tuning, scored once at the end.
- **A judge** that wrote none of the options: `decide-by-debate` when several methods compete.
- **The user's own use**: the field test that would make them trust it, stated as a protocol.

**Done when** each proof names what it compares against and the number that passes.

### 6. Rewrite the request

Rewrite the user's request so it asks for exactly the answers to steps 2–5, in the user's own
terms. Every line traces to the original request or to one of those answers; a line that traces to
neither is cut. When the rewrite is the commission for a session, write it in the project's session
prompt format (a session-prompt skill, if the project has one), with a stop gate before anything user-visible is built.

**Done when** the rewrite is no bigger in scope than the request, and every requirement in it says
what proves it met.

### 7. Hand back

Show the four answers and the rewritten request. Wait for the user's go: the rewrite is a proposal,
and choices in it (placement, thresholds, what to measure first) are theirs.
