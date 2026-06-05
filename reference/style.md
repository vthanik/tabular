# Attach a style layer to a `tabular_spec` or `style_template`

One verb, one cascade. Each `style()` call appends a single
`style_layer` (location + style attributes) to the spec or template.
Layers accumulate in declaration order; the engine merges them at render
time so later layers win per attribute, NA-valued fields leave the prior
layer intact.

## Usage

``` r
style(.spec, ..., .at = cells_body())
```

## Arguments

- .spec:

  *A `tabular_spec` OR a `tabular_style_template`.*
  `<tabular_spec | tabular_style_template>: required`. Dot-prefixed so
  R's partial argument matching cannot accidentally bind a short
  attribute name in `...` to the spec slot. When piping through
  `style_template() |> style(...)` layers accumulate onto the template
  instead of a spec.

- ...:

  *Named style attributes.* At least one required. See the vocabulary
  list above for recognised names.

- .at:

  *Location object selecting which surface the layer targets.*
  `<tabular_location>: default cells_body()`. Build with one of the
  `cells_*()` constructors; see
  [`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md)
  and siblings. Dot-prefixed (tidyverse convention) because it comes
  AFTER `...` — that way a user-passed style attribute can never collide
  with this arg's name.

## Value

The updated `tabular_spec` (or `tabular_style_template`, when called
against one).

## Details

**Locations.** The `at` argument selects which surface the layer
targets. Every region of the rendered page has a `cells_*()`
constructor:

- [`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md)
  — body cells (default)

- [`cells_headers()`](https://vthanik.github.io/tabular/reference/cells.md)
  — column header band

- [`cells_group_headers()`](https://vthanik.github.io/tabular/reference/cells.md)
  — synthetic group-header rows

- [`cells_title()`](https://vthanik.github.io/tabular/reference/cells.md)
  — title block

- [`cells_subgroup_labels()`](https://vthanik.github.io/tabular/reference/cells.md)
  — subgroup banner row

- [`cells_footnotes()`](https://vthanik.github.io/tabular/reference/cells.md)
  — footnote block

- [`cells_pagehead()`](https://vthanik.github.io/tabular/reference/cells.md)
  — page-header band

- [`cells_pagefoot()`](https://vthanik.github.io/tabular/reference/cells.md)
  — page-footer band

- [`cells_table()`](https://vthanik.github.io/tabular/reference/cells.md)
  — table-wide regions (outer borders, body-row separators)

Body filters live on
[`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md):
`i = 1:3` for integer-index rows, `j = "Total"` for column-name
targeting, `where = <expr>` for a quosure-captured predicate evaluated
against `spec@data`.

**Attribute vocabulary.** Each layer carries a `style_node` built from
`...`. Recognised attribute names:

- Text — `bold`, `italic`, `underline`, `color`, `background`,
  `font_family`, `font_size`

- Alignment — `halign` (`"left" / "center" / "right"`), `valign`
  (`"top" / "middle" / "bottom"`)

- Borders — `border` (umbrella), `border_top`, `border_bottom`,
  `border_left`, `border_right` (each takes a
  [`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md) value
  or the literal `"none"`); per-side scalars
  `border_<side>_{style,width,color}` for finer control

- Padding — `padding` (a scalar applies to all four sides; a named
  vector `c(top = , right = , bottom = , left = )` sets each side); or
  the per-side scalars `padding_<side>` directly

- Spacing — `blank_above`, `blank_below` (integer blank lines above /
  below the block — for
  [`cells_title()`](https://vthanik.github.io/tabular/reference/cells.md)
  /
  [`cells_footnotes()`](https://vthanik.github.io/tabular/reference/cells.md)
  /
  [`cells_subgroup_labels()`](https://vthanik.github.io/tabular/reference/cells.md))

- Inline — `pretext`, `posttext` (literal text prepended / appended
  around the cell value)

Unknown attribute names emit a
[`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html) and
drop from the constructed node; the engine never sees a foreign
property.

## See also

**Companion verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md).

**Location constructors:**
[`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_headers()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_group_headers()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_title()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_subgroup_labels()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_footnotes()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_pagehead()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_pagefoot()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_table()`](https://vthanik.github.io/tabular/reference/cells.md).

**Style values:**
[`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md),
[`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md).

## Examples

``` r
# ---- AE table by SOC and PT with per-row indent + styled hierarchy ----
# `saf_aesocpt` ships with `indent_level` (0 on overall/SOC rows,
# 1 on PT rows); `col_spec(indent_by = "indent_level")` drives the
# PT indent on the `label` column.
tabular(saf_aesocpt, titles = "Adverse Events by SOC / PT",
        footnotes = "") |>
  cols(
    label    = col_spec(label = "Category", align = "left",
                        indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100", align = "decimal"),
    Total    = col_spec(label = "Total",    align = "decimal")
  ) |>
  # SOC summary rows bolded (depth 0 — flush)
  style(bold = TRUE,
        .at = cells_body(where = row_type == "soc")) |>
  # Overall row gets a light background
  style(background = "#f0f0f0",
        .at = cells_body(where = row_type == "overall"))

#tabular-3b7b8aca0f { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-3b7b8aca0f .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-3b7b8aca0f p { line-height: inherit; }
#tabular-3b7b8aca0f .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-3b7b8aca0f .tabular-caption { margin: 0; padding: 0; }
#tabular-3b7b8aca0f .tabular-pad { margin: 0; line-height: 1; }
#tabular-3b7b8aca0f .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-3b7b8aca0f .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-3b7b8aca0f .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-3b7b8aca0f .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-3b7b8aca0f .tabular-table th, #tabular-3b7b8aca0f .tabular-table td { padding: .18rem .6rem; }
#tabular-3b7b8aca0f .tabular-table td { text-align: left; vertical-align: top; }
#tabular-3b7b8aca0f .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-3b7b8aca0f .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-3b7b8aca0f .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-3b7b8aca0f .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-3b7b8aca0f .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-3b7b8aca0f .tabular-table tbody tr td { border-top: none; }
#tabular-3b7b8aca0f .tabular-band { text-align: center; }
#tabular-3b7b8aca0f .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-3b7b8aca0f .tabular-subgroup-label { font-weight: 600; }
#tabular-3b7b8aca0f .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-3b7b8aca0f .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-3b7b8aca0f .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-3b7b8aca0f .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-3b7b8aca0f .text-left { text-align: left; }
#tabular-3b7b8aca0f .text-center { text-align: center; }
#tabular-3b7b8aca0f .text-right { text-align: right; }
#tabular-3b7b8aca0f .tabular-table thead th.text-left { text-align: left; }
#tabular-3b7b8aca0f .tabular-table thead th.text-center { text-align: center; }
#tabular-3b7b8aca0f .tabular-table thead th.text-right { text-align: right; }
#tabular-3b7b8aca0f .valign-top { vertical-align: top; }
#tabular-3b7b8aca0f .valign-middle { vertical-align: middle; }
#tabular-3b7b8aca0f .valign-bottom { vertical-align: bottom; }
#tabular-3b7b8aca0f .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-3b7b8aca0f .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-3b7b8aca0f .tabular-page-break-row { display: none; }
#tabular-3b7b8aca0f { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-3b7b8aca0f .tabular-page-header, #tabular-3b7b8aca0f .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-3b7b8aca0f .tabular-page-header { margin-bottom: 1rem; }
#tabular-3b7b8aca0f .tabular-page-footer { margin-top: 1rem; }
#tabular-3b7b8aca0f .tabular-page-header-left, #tabular-3b7b8aca0f .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-3b7b8aca0f .tabular-page-header-center, #tabular-3b7b8aca0f .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-3b7b8aca0f .tabular-page-header-right, #tabular-3b7b8aca0f .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-3b7b8aca0f .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3b7b8aca0f .tabular-table tr { page-break-inside: avoid; } #tabular-3b7b8aca0f .tabular-page-header, #tabular-3b7b8aca0f .tabular-page-footer { display: none; } #tabular-3b7b8aca0f .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3b7b8aca0f .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3b7b8aca0f .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Adverse Events by SOC / PT
 



Category
```
