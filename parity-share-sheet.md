# Backend parity share sheet — bring LaTeX + DOCX up to the RTF bar

Purpose: the RTF backend (`R/backend_rtf.R`) is the reference for
submission-grade table chrome. This sheet enumerates every requirement
RTF now satisfies so the **LaTeX** (`R/backend_latex.R`) and **DOCX**
(`R/backend_docx.R`) backends can be brought to the same bar. HTML
(`R/backend_html.R`) is the alignment oracle; do not change it.

Source of truth for the RTF behaviours below: the recent RTF commits
(`git log` — `82ea7a1` padding SSOT, `0761b9a` cell_padding_h per-side,
`bb267d1` repeat_content chrome, `ca4ba6b` font/margin/centering,
`a00b4bd` row height, plus the two commits this batch: native
pagination + header parity) and the galley reference at
`~/projects/r/_archive/2026-05-21/galley/R/render-rtf.R`.

Status legend: **[DONE]** already at parity · **[PENDING]** not yet ·
**[N/A]** not applicable to that backend.

---

## 1. Header alignment — decimal column header centres

**Requirement.** A column with `col_spec(align = "decimal")` centres its
**header** label over the column (TFL centroid convention, HTML parity);
the **body** cells stay right/decimal-aligned. Non-decimal columns keep
their own alignment.

- HTML oracle: `backend_html.R:800` (`if (col@align == "decimal") "center"`).
- RTF ref: `.render_rtf_col_labels_row()` — decimal → `\qc` on the header
  cell; body unchanged.
- **LaTeX [DONE]** `.render_latex_col_labels_row()` emits
  `\SetCell{halign=c,...}` for decimal headers only.
- **DOCX [DONE]** `.render_docx_col_labels_row()` header `halign` →
  `center` for decimal.

## 2. Header vertical alignment — default bottom

**Requirement.** Header cells default to **bottom** vertical alignment
(HTML `thead th { vertical-align: bottom }`, `backend_html.R:1447`), so a
wrapped multi-line header sits flush with single-line neighbours. Cascade:
`col_spec@valign` > surface (`chrome_style` header) valign >
`preset(alignment = list(header_valign = ...))`; the bottom default fires
ONLY when all are unset (`if (is.na(valign)) valign <- "bottom"`).

- RTF ref: `.render_rtf_col_labels_row()` valign cascade + bottom default
  → `\clvertalb`.
- **LaTeX [DONE]** per-header `\SetCell{...,valign=b}` (always emitted; the
  longtblr row baseline is body_valign, so the header needs its own).
- **DOCX [DONE]** `.render_docx_col_labels_row()` cascade now includes the
  surface tier + bottom default → `<w:vAlign w:val="bottom"/>`. (This also
  fixed a prior gap where `preset(header_valign=)` was ignored in DOCX.)

## 3. Auto-fit "by word" for headers (body never wraps)

**Requirement.** For `col_spec(width = "auto")` the **header** sizes to
its widest *word* (so a multi-word header like `"n, median"` wraps at the
space instead of forcing a wide column — matching Word AutoFit-to-
contents); the **body** sizes to its widest *line* and never wraps
(numeric values stay intact). A non-breaking space (NBSP, U+00A0) is NOT
a break point — `"Mean (SD)"` with NBSP stays on one line.

- Implemented backend-agnostically in `R/col_width.R::.compute_col_width()`
  (header split on `[ \t]+` keeping NBSP whole; body split on `\n` only).
  **[DONE] for all backends** — they read the resolved `col@width` from
  the grid, so LaTeX/DOCX inherit this automatically. No per-backend work.
- Verify: LaTeX `Q[wd=..in]` and DOCX `<w:tcW>` widths shrink for
  multi-word headers; confirm Word/LaTeX actually wrap the header at the
  space and never wrap a numeric body cell.

## 4. Spanner (column-band) rules — full-width top + cmidrule(lr)  ← MAIN PENDING ITEM

**Requirement.** The header band is bounded by a **full-width top rule**
on the TOPMOST header row (across ALL columns — the "long header on top
of all spanning headers") and a **full-width bottom rule** under the
column-labels row. Each spanner band carries ONLY its own
**cmidrule(lr)**: a bottom rule scoped to the spanned columns, leaving
flanking (unspanned) columns un-ruled. The column-labels row carries NO
top rule when spanner bands sit above it (no doubled rule). The spanner
label centres over its spanned columns.

- RTF ref (the model to mirror):
  - `.rtf_band_row(outer_top=)` — top rule emitted on every cell only when
    `outer_top` (topmost band); each band cell's bottom rule is the
    cmidrule (band cells only; flanking cells `\clbrdrb\brdrnone`).
  - `.render_rtf_header_bands()` passes `outer_top = (k == 1L)` (depths
    sorted ascending; first emitted row is topmost).
  - `.render_rtf_col_labels_row(outer_top=)` — top rule only when
    `outer_top` (no bands); `.render_rtf_panel` passes `outer_top = !has_bands`.
  - Merged spanner cells use `\clmgf` (first spanned col) + `\clmrg`
    (rest) on the body `\cellx` grid; label centred (`\qc`) in the first.
  - galley ref: `rtf_spanner_rows()` (render-rtf.R ~930-1072) — spanner
    emits only a bottom hline on spanned cells, never a partial top rule;
    levels iterate `rev(levels)` so the widest/topmost renders first.
- **LaTeX [PENDING]** `.render_latex_header_bands()` (`R/backend_latex.R`):
  today the band/`\cmidrule` logic does not implement the full-width top
  rule on the topmost band nor guarantee the col-labels row drops its top
  rule under a band. Target: topmost band row gets a `\hline`/full-width
  toprule across all columns; each spanner gets `\cmidrule(lr){i-j}` over
  its spanned colspec range only; the column-labels row gets the bottom
  rule but no top rule when bands exist. tabularray: use `hline{N}={...}`
  and `cmidrule` via `\SetCell` spans (`[c=N]`).
- **DOCX [PENDING]** `.render_docx_header_bands()` (`R/backend_docx.R`):
  the band `<w:tc>` cells currently set top+bottom borders on the spanned
  (gridSpan) cells. Target: the topmost band row's `<w:tcBorders>` sets a
  **top** border on EVERY cell (full width); each spanner sets a
  **bottom** border only on its spanned `<w:gridSpan>` cell (cmidrule);
  flanking cells get no bottom; the column-labels row drops its top border
  when bands sit above it. Mirror the RTF `outer_top` / `has_bands`
  threading.

## 5. Page chrome — running header / footer + repeat_content

**Requirement.** Titles, the column-header band, and footnotes repeat on
every page per `paginate(repeat_content = c("titles","headers","footnotes"))`
(default: all repeat). Footnotes + program-path band pin to the page
bottom. `{page}` / `{npages}` tokens resolve to live page numbers.

- RTF ref: titles/spanner/labels as `\trhdr` rows (Word repeats); program
  path + repeating footnotes in `{\footer}`; `{page}`/`{npages}` →
  `\field PAGE`/`NUMPAGES`. `repeat_titles/headers/footnotes` read from
  grid metadata (`engine_paginate` plan → `as_grid`).
- **LaTeX [DONE-ish]** `longtblr` head/foot + `fancyhdr`; verify titles
  vs the `\trhdr`-equivalent repeat and that repeat_content gating matches.
- **DOCX [DONE-ish]** `<w:tblHeader/>` on header rows + header/footer
  parts; verify repeat_content gating + `{page}`/`{npages}` field codes.
  (These predate this batch — confirm they still align after the native-
  pagination metadata changes; the `repeat_*` flags are now in metadata.)

## 6. Native pagination model (RTF-specific; LaTeX/DOCX differ)

**RTF [DONE].** One continuous table per `(subgroup × panel)`; Word
paginates the body natively; `engine_paginate(native = TRUE)` returns an
unsplit grid (one vertical page per panel) and `as_grid` attaches a
per-rendered-row `keep_with_next` vector. `\sect` only between panels.

- **DOCX [PENDING — candidate]** Word reads `.docx` too, so DOCX is the
  natural next consumer of `native_pagination`: add `"docx"` to
  `.native_pagination_formats` (`R/as_grid.R`) and render one continuous
  `<w:tbl>` per panel with `<w:tblHeader/>` repeating rows + keep
  (`<w:cantSplit/>` / `<w:keepNext/>`) driven by `page$keep_with_next`.
  Confirm DOCX currently still uses tabular's vertical split (non-native)
  before flipping.
- **LaTeX [N/A]** LaTeX/`longtblr` already paginates natively via its own
  head/foot repeat; it stays non-native (no unsplit grid needed).

## 7. Uniform typography — font size, row height, padding, margins, centering

These landed for RTF in `ca4ba6b` / `a00b4bd` / `82ea7a1` / `0761b9a`.
Confirm LaTeX/DOCX parity:

- **Uniform font size.** Every row re-asserts the body font size so no row
  renders larger/smaller. RTF: `\fsN` after each `\pard\plain`.
  LaTeX/DOCX: verify a single font size across title/body/footnote unless
  a per-surface override is set.
- **Uniform row height + zero vertical cell padding.** RTF:
  `\trrh<h>\trpaddt0\trpaddft3\trpaddb0\trpaddfb3` on every row.
  DOCX: `<w:trHeight>` minimum + zero cell margins; LaTeX: `rowsep=0` +
  consistent `\arraystretch` / row height.
- **Horizontal cell padding SSOT.** `preset@cell_padding_h` (scalar or
  `c(left, right)`) feeds BOTH column-width measurement and the rendered
  gap. RTF averages to a symmetric `\trgaph` (total preserved); **DOCX +
  LaTeX render left/right exactly** — confirm still true.
- **Preset margins, not enlarged.** Page margins are exactly the preset
  values; the footer flows down / header up and the consumer expands into
  the body when tall (never grows the margin). RTF: `\margb`/`\footery` =
  preset. DOCX: section `<w:pgMar>` = preset. LaTeX: `geometry` = preset.
- **Centered table.** The table block centres on the page. RTF: `\trqc` on
  every row. LaTeX: `longtblr` centred. DOCX: `<w:jc w:val="center"/>` on
  the table.

---

## Suggested implementation order (LaTeX + DOCX)

1. **Spanner full-width top + cmidrule (§4)** — the reported defect;
   mirror the RTF `outer_top` / `has_bands` threading in
   `.render_latex_header_bands` + `.render_docx_header_bands`.
2. Verify **header alignment (§1, §2)** and **auto-fit (§3)** render
   correctly in PDF (LaTeX) and Word (DOCX) — code is done; needs eyes.
3. Optional: **DOCX native pagination (§6)** — flip `docx` into
   `.native_pagination_formats` and render one `<w:tbl>` per panel with
   `<w:tblHeader/>` + keep, for true Word-native page breaks.
4. Re-verify §5 / §7 parity after the above.

## Verification (every change)

- `Rscript -e 'devtools::document()'` · `devtools::test()` ·
  `devtools::check(args = "--no-manual")` · `air format R/ tests/` —
  0/0/0.
- `covr::package_coverage()` — touched files ≥ 95%.
- Regenerate + review the LaTeX (`.tex`) and DOCX (`word/document.xml`)
  golden snapshots; eyeball the PDF and Word renders.
- Sandbox: `cd ~/projects/r/tabular-test && Rscript demographics.R`
  (the Xanomeline spanner table) for `.pdf` / `.docx`.
