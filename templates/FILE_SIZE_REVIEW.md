# File Size Review

Large files are **flagged for review, never blocked, and there is no line limit.**

A file past roughly 800 lines is a prompt to ask a question, not a violation. Some
files are genuinely that size and cannot honestly be split; blocking them would mean
crucial work could never be committed, which is a broken tool rather than a standard.

Line counts are surfaced by the dashboard's Project Inventory view. What matters is
that each flagged file reaches a resolution:

| State | Meaning |
|---|---|
| **Not reviewed** | Default. Nobody has looked yet. |
| **Splittable** | Can be reduced. Becomes a numbered row in the phase file that owns it, and is reduced like any other unit of work. |
| **Accepted** | Reviewed and judged irreducible, with the reason written down. Stops being flagged and is not raised again unless the file's purpose changes. |

## Reviewed files

| File | Lines | State | Reason |
|---|---|---|---|
| — | | | |
