# Attach an auto-numbered footnote to a table location

Anchor a footnote to a cell, column header, title line, or any other
`cells_*()` location. The engine assigns the marker, places a
superscript at every matching anchor, and emits the marked-footnote line
at the foot of the table. Markers are assigned **once**, in reading
order, deduped by `id`, and are byte-identical across every backend (RTF
/ LaTeX / PDF / HTML / DOCX) and every page, so the marker at the anchor
can never desynchronise from its note.

## Usage

``` r
footnote(.spec, text, .at = cells_body(), id = NULL, symbol = NULL)
```

## Arguments

- .spec:

  *The `tabular_spec` to annotate.* `<tabular_spec>: required`.

- text:

  *The footnote text.* `<character(1)> | md() | html()`. Wrap in
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  for inline markup; plain strings are shown verbatim. A plain string
  supports glue-style `{expr}` interpolation, evaluated as R code in the
  calling environment at build time (double a brace for a literal one);
  an [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  value is passed through without interpolation.

- .at:

  *Where the marker is placed.*
  `<tabular_location>: default [`cells_body()`]`. Any `cells_*()`
  location: a body-cell predicate (`cells_body(where = ...)`), a column
  header
  ([`cells_headers()`](https://vthanik.github.io/tabular/dev/reference/cells.md)),
  a title line
  ([`cells_title()`](https://vthanik.github.io/tabular/dev/reference/cells.md)),
  and so on.

      # data-driven body anchor: mark every high-frequency preferred term
      footnote(spec, "Includes events of any severity.",
               .at = cells_body(where = n_total >= 50, j = "label"))

      # column-header anchor: mark the analysis-population denominator
      footnote(spec, "Safety population.",
               .at = cells_headers(j = "Total"))

  **Note:** the styling argument is `.at`, never `at`.

- id:

  *Stable identifier for sharing one marker across anchors.*
  `<character(1)> | NULL`. Two `footnote()` calls with the same `id`
  share a single marker and a single note line. `NULL` (default) makes
  each call its own note.

- symbol:

  *Pin an explicit marker glyph.* `<character(1)> | NULL`. Overrides the
  auto-allocated marker for this note (e.g. `"*"`). A pinned symbol is
  reserved and skipped by the auto-allocator, so it never collides.
  `NULL` (default) auto-allocates from the preset scheme.

## Value

*A `tabular_spec`.* Pipe it onward to more verbs or to
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).

## Details

**Engine-assigned, never hand-typed.** Unlike a literal `^a^` typed into
both a cell and the `footnotes` argument, a `footnote()` marker is
allocated by the resolve engine after decimal alignment, so it never
disturbs column alignment and never drifts out of sync. The scheme
(`letters` / `numbers` / `symbols`) and the block-line format come from
the active preset (`footnote_markers`, `footnote_label`).

**Dedup by id.** Give two anchors the same `id` to share one marker and
one note line. Without an `id`, each `footnote()` call is its own note.

**Coexists with `footnotes`.** Manual `footnotes` lines render first;
the auto-numbered block follows. The two systems do not cross-dedup, so
do not mix a hand-typed marker with an engine one for the same note.

## See also

**Manual footnote lines:** the `footnotes` argument to
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md).

**Location helpers:**
[`cells_body()`](https://vthanik.github.io/tabular/dev/reference/cells.md),
[`cells_headers()`](https://vthanik.github.io/tabular/dev/reference/cells.md),
[`cells_title()`](https://vthanik.github.io/tabular/dev/reference/cells.md).

**Inline markup:**
[`md()`](https://vthanik.github.io/tabular/dev/reference/md.md),
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).

## Examples

``` r
# ---- Example 1: a denominator note on a column header ----
#
# AE-by-SOC/PT table whose Total column header carries the analysis-
# population note. The engine drops a superscript "a" on the header
# and prints "a <text>" beneath the table.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(cdisc_saf_aesocpt) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
    Total    = col_spec(label = "Total\nN={n['Total']}")
  ) |>
  footnote(
    "Safety population: all randomised subjects who took study drug.",
    .at = cells_headers(j = "Total")
  )

#tabular-63b28d89ab { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-63b28d89ab .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-63b28d89ab p { line-height: inherit; }
#tabular-63b28d89ab .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-63b28d89ab .tabular-caption { margin: 0; padding: 0; }
#tabular-63b28d89ab .tabular-pad { margin: 0; line-height: 1; }
#tabular-63b28d89ab .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-63b28d89ab .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-63b28d89ab .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-63b28d89ab .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-63b28d89ab .tabular-table th, #tabular-63b28d89ab .tabular-table td { padding: .18rem .6rem; }
#tabular-63b28d89ab .tabular-table td { text-align: left; vertical-align: top; }
#tabular-63b28d89ab .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-63b28d89ab .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-63b28d89ab .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-63b28d89ab .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-63b28d89ab .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-63b28d89ab .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-63b28d89ab .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-63b28d89ab .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-63b28d89ab .tabular-table tbody tr td { border-top: none; }
#tabular-63b28d89ab .tabular-band { text-align: center; }
#tabular-63b28d89ab .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-63b28d89ab .tabular-subgroup-label { font-weight: 600; }
#tabular-63b28d89ab .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-63b28d89ab .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-63b28d89ab .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-63b28d89ab .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-63b28d89ab .text-left { text-align: left; }
#tabular-63b28d89ab .text-center { text-align: center; }
#tabular-63b28d89ab .text-right { text-align: right; }
#tabular-63b28d89ab .tabular-table thead th.text-left { text-align: left; }
#tabular-63b28d89ab .tabular-table thead th.text-center { text-align: center; }
#tabular-63b28d89ab .tabular-table thead th.text-right { text-align: right; }
#tabular-63b28d89ab .valign-top { vertical-align: top; }
#tabular-63b28d89ab .valign-middle { vertical-align: middle; }
#tabular-63b28d89ab .valign-bottom { vertical-align: bottom; }
#tabular-63b28d89ab .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-63b28d89ab .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-63b28d89ab .tabular-page-break-row { display: none; }
#tabular-63b28d89ab { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-63b28d89ab .tabular-page-header, #tabular-63b28d89ab .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-63b28d89ab .tabular-page-header { margin-bottom: 1rem; }
#tabular-63b28d89ab .tabular-page-footer { margin-top: 1rem; }
#tabular-63b28d89ab .tabular-page-header-left, #tabular-63b28d89ab .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-63b28d89ab .tabular-page-header-center, #tabular-63b28d89ab .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-63b28d89ab .tabular-page-header-right, #tabular-63b28d89ab .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-63b28d89ab .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-63b28d89ab .tabular-table tr { page-break-inside: avoid; } #tabular-63b28d89ab .tabular-page-header, #tabular-63b28d89ab .tabular-page-footer { display: none; } #tabular-63b28d89ab .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-63b28d89ab .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-63b28d89ab .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }




SOC / PT
```
