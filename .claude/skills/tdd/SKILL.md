---
name: tdd
description: Test-driven development — red, then green, one vertical
  slice at a time, at seams agreed with the operator before any test is written. Use this
  skill whenever a behaviour is about to be built or a bug fixed test-first, when the user
  says "write tests", "test-first", "red-green-refactor", "add coverage", or asks whether
  something is testable. Also triggers when a fix is about to be committed with no test
  behind it. Not for diagnosing a bug you cannot yet reproduce — that is diagnosing-bugs,
  which hands its minimised repro back here in its phase 5.
---

# Test-Driven Development

TDD is the red → green loop. This skill is what makes that loop produce tests worth
keeping: where tests are allowed to live, what a seam is, and the four ways a test
can look green and be worthless.

Read `CONTEXT.md` before naming anything, so test names use the project's vocabulary
rather than inventing a parallel one. Respect the path-scoped rules in `.claude/rules/`
for whatever you are touching.

## Where tests live — structural, not a preference

**Test files go in the project's test target/directory. Never inside a build target's
synchronized or globbed sources.**

The general rule: if the build target picks up sources by directory glob (an Xcode
synchronized root group, a `src/**` glob in a bundler), a test file placed inside that
tree joins the **app** build and fails it — or worse, ships. Put tests in the tree the
test runner owns (`MyAppTests/` for an Xcode app target, `tests/` or `__tests__/` for most stacks), and
if the project has no such tree, creating it is the first slice.

## Seams: where tests go

A **seam** is the public boundary you observe behaviour at without reaching inside. Call
the Skill tool with "codebase-design" for the full vocabulary — module, interface, depth,
seam, adapter, leverage, locality. It is a reference to consult, not a session to run.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under
test and confirm them with the operator. No test is written at an unconfirmed seam.

This matters more on a project with thin coverage, because agreeing the seams up front
is how the effort lands on the paths that have actually produced defects instead of
spreading evenly over the whole tree.

Ask: "What is the public interface here, and which seams should we test?"

## The four anti-patterns

**Implementation-coupled.** Mocks an internal collaborator, reaches a private member, or
verifies through a side channel — querying the database file directly instead of reading
back through the store's own interface. The tell: it breaks on a refactor when behaviour
did not change.

**Tautological.** The expected value is recomputed the way the code computes it, so the
test passes by construction and can never disagree with the code.

```swift
// BAD — recomputes the implementation
let expected = segments.reduce(0) { $0 + $1.lengthM }
XCTAssertEqual(route.totalDistance, expected)

// GOOD — an independent, known literal
XCTAssertEqual(route.totalDistance, 1_450, accuracy: 0.5)
```

Expected values come from an independent source of truth: a known-good literal, a worked
example, a captured fixture, the spec.

**Horizontal slicing.** All the tests first, then all the implementation. Bulk tests
verify *imagined* behaviour — you test the shape of things, the tests go insensitive to
real changes, and you commit to a test structure before understanding the implementation.
Work in **vertical slices**: one test, one implementation, repeat, each test responding to
what the last cycle taught you.

**Asserting nothing.** A test whose only assertion is trivially true, or whose only
failure mode is a crash. One narrow exception exists: a test whose doc comment says it
exists to prove the test target itself links and runs. Anything else of that shape is a
test that cannot fail.

## Mock only at system boundaries

Mock: the network, the backend SDK, platform APIs, the clock, randomness.

Do not mock: your own stores, managers, or models. If a test needs one of those mocked
to test something else, that something else is reaching through a seam that should not be
there — which is a **finding about the design**, not a reason to add the mock.

Accept dependencies rather than constructing them, so the boundary is substitutable.
Where an existing singleton shape blocks a test at an agreed seam, say so rather than
testing around it.

## Rules of the loop

- **Red before green.** Write the failing test first, run it, watch it fail, then write
  only enough code to pass it. A test that has never been seen red has not been shown to
  test anything.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to review — call the Skill tool with
  "project-code-review" — not to the red → green cycle.

## Pinning tests

A pinning test does not close a gap; it pins a behaviour already caught misbehaving so a
future edit cannot quietly regress it again. Name the bug number it defends in its doc
comment.

When a fix has no correct seam for a true regression test, a pinning test at a coarser
seam is better than nothing — but say which it is in the doc comment, and do not let it
be counted as verification of the fix.

## What a test does and does not settle

Passing tests are not the tracker's **Fixed, verified** state. That state requires
evidence the failure happened before and does not happen now, in the scenario the user
reported. A green unit test at an agreed seam is strong evidence for a logic defect and
weak evidence for anything involving a device or a real network round-trip.
Record which one you have, in the ledger entry's `Verified by:` field.
