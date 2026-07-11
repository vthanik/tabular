---
name: tabular
description: >
  Render clinical submission tables, listings, and figures to RTF, HTML,
  DOCX, PDF/LaTeX, and Markdown from R. Use when writing R code that uses
  the tabular package.
license: MIT
compatibility: Requires R >=4.3.
---

# tabular

Render tables, listings, and figures for clinical submissions, natively to
RTF, HTML, DOCX, PDF/LaTeX, and Markdown from a single immutable spec, with no
Java, SAS, or Office dependency.

## Installation

```r
install.packages("tabular")
# development version:
# pak::pak("vthanik/tabular")
```

## Mental model

tabular is **display-only**: it never aggregates, filters, weights, or computes
statistics. You bring a **pre-summarised, wide data frame** (one input row = one
display row) and pipe a `tabular()` object through verbs; each verb returns a
new immutable spec. Nothing renders until `emit()`, which picks the backend from
the file extension (`.rtf` `.html` `.docx` `.tex` `.pdf`) or an explicit
`format=`.

```r
library(tabular)
data(cdisc_saf_demo, package = "tabular")

tabular(cdisc_saf_demo, titles = c("Table 14-2.01", "Demographics", "ITT")) |>
  cols(variable = "", stat_label = "") |>
  group_rows(by = "variable", display = "header_row") |>
  emit("table.rtf")
```

## API overview

### Table creation

Wrap a pre-summarised wide data frame, a cards ARD, a plot, or an image into a
spec.

- `tabular`: Wrap a wide data frame into a `tabular_spec`
- `pivot_across`: Pivot a long ARD / tidy frame into the wide display shape
- `figure`: Wrap a ggplot, base plot, drawing function, or image into a `figure_spec`

### Column specification

Describe each column's role, label, width, alignment, and visibility.

- `cols`: Assign a `col_spec` to one or more columns (a bare string is label shorthand; `.hide` hides columns)
- `col_spec`: Build a per-column specification (`label`, `width`, `align`, `visible`, `indent`)
- `cols_apply`: Apply one `col_spec` across many columns by predicate
- `group_rows`: Declare the table-level row grouping (`by` keys outer to inner, per-key `display` and `skip`)

### Column headers

Build multi-level column spanners above the data columns.

- `headers`: Add multi-level column header bands / spanners

### Row ordering and grouping

Order rows on a (usually hidden) key and split the body into banner sections.

- `sort_rows`: Order display rows by one or more columns
- `subgroup`: Split the body into banner-led subgroup sections

### Pagination

Split a long table across pages for the paged backends (RTF, DOCX, PDF).

- `paginate`: Configure page splitting, repeated chrome, and continuation markers

### Styling and themes

Cosmetic control. `preset()` is pipe-scoped; `set_preset()` is session-scoped
(the ggplot2 `theme()` / `theme_set()` split).

- `style`: Apply styling to predicate-targeted locations (via `.at = cells_*()`)
- `style_template`: Build a reusable named style template
- `preset`: Set cosmetic defaults on a spec (`alignment`, `rules`, `fonts`, `colors`, `padding`, ...)
- `preset_minimal`: The one bundled minimal theme helper
- `set_preset`: Set session-wide cosmetic defaults
- `get_preset`: Read the active preset
- `brdr`: Build a border / rule line spec

### Location targeting

Select precise table regions for `style(.at = ...)`.

- `cells_body`
- `cells_headers`
- `cells_title`
- `cells_footnotes`
- `cells_group_headers`
- `cells_subgroup_labels`
- `cells_pagehead`
- `cells_pagefoot`
- `cells_table`

### Inline text and footnotes

- `md`: Interpret label text as Markdown
- `html`: Interpret label text as HTML
- `footnote`: Attach a footnote (with an optional reference marker) to a location

### Rendering and export

- `emit`: Render the spec to a file (backend chosen by extension or `format=`)
- `as_grid`: Resolve a spec to its finalized `tabular_grid` (the pre-backend IR)

### Font utilities

- `check_fonts`: Verify the fonts a spec needs are available for decimal alignment
- `check_latex`: Verify the LaTeX toolchain for `.pdf` / `.tex` output

### Predicates

Class checks for the spec types.

- `is_tabular_spec`, `is_figure_spec`, `is_col_spec`, `is_header_node`
- `is_sort_spec`, `is_subgroup_spec`, `is_pagination_spec`
- `is_preset_spec`, `is_style_spec`, `is_style_layer`, `is_style_node`, `is_style_template`
- `is_brdr`, `is_inline_ast`, `is_tabular_grid`, `is_tabular_location`

### Built-in datasets

Pre-summarised CDISC demo frames used throughout the examples. Use these instead
of inventing toy data.

- `cdisc_saf_demo`, `cdisc_saf_n`: demographics summary + BigN counts
- `cdisc_saf_ae`, `cdisc_saf_aesocpt`: adverse events overall / by SOC and PT
- `cdisc_saf_vital`, `cdisc_saf_subgroup`: vitals by visit, subgroup split
- `cdisc_eff_resp`, `cdisc_eff_n`, `cdisc_eff_estimates`: efficacy response, BigN, estimates
- `cdisc_saf_demo_ard`, `cdisc_saf_aesocpt_ard`: cards ARD variants for `pivot_across()`

## Conventions (don't fight these)

- **Sort on a hidden numeric key, never display text** — `"217 (85.4)"` sorts
  lexically; derive an integer key, hide it with `col_spec(visible = FALSE)`,
  then `sort_rows(by = key)`.
- **BigN goes inline in the label string**, not a field.
- **`group_rows(display = "header_row")` auto-indents its child rows** — don't
  also add `col_spec(indent = )` on the stub (double indent).
- **Titles and footnotes are multi-line** — pass a `character()` of any length.
- Cosmetic knobs are named lists keyed by surface; per-surface specs are flat
  `c(...)` vectors, validated strictly at call time.

## Resources

- [Full documentation](https://vthanik.github.io/tabular/)
- [llms.txt](https://vthanik.github.io/tabular/llms.txt) — Indexed reference for LLMs
- [llms-full.txt](https://vthanik.github.io/tabular/llms-full.txt) — Full documentation for LLMs
