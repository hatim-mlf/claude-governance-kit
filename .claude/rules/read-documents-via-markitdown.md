---
paths:
  - "**/*.pdf"
  - "**/*.docx"
  - "**/*.pptx"
  - "**/*.xlsx"
---

# Project Invariant — read documents as Markdown first

## When it fires

Fires when you need to *read* a PDF, Word, PowerPoint or Excel file to understand it: what it covers, where a section starts, which file is which. Convert the file to Markdown once, into the session scratchpad, then read the `.md`:

```sh
uv tool install "markitdown[pdf,docx,pptx,xlsx]"   # once per machine (microsoft/markitdown, MIT)
markitdown "<file>" > "$SCRATCH/<name>.md"
```

Read only the part you need (`grep`, `sed -n`), not the whole file. Worker briefs carry the same instruction.

## When it does not fire

- **Extraction and fidelity.** When document content must reach a product verbatim, use the project's own extractor or a source-bound image crop. markitdown's PDF text layer drops images and positions. It also loses symbol-font glyphs (σ, λ, τ, exponent signs) and multi-column reading order.
- **Visual questions.** Questions about figures, layout or completeness need the rendered page or the original file.

## Why

Measured 2026-11-22. A 14-page course PDF of 2.8 MB converted to 30,081 characters, about 8.6k tokens. Reading the same PDF directly costs about 21–42k tokens, at 1,500–3,000 per page, because each page is sent as an image plus text. That is a 2.5–5× saving per read.

Verdict: it helps for reading and orientation. It is not a source for extracted content.
