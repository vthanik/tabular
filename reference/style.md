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
#> <style>
#> #tabular-c7dae80141 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-c7dae80141 .tabular-content { width: 100%; }
#> #tabular-c7dae80141 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-c7dae80141 .tabular-pad { margin: 0; }
#> #tabular-c7dae80141 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-c7dae80141 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-c7dae80141 .tabular-table th, #tabular-c7dae80141 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-c7dae80141 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-c7dae80141 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-c7dae80141 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-c7dae80141 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-c7dae80141 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-c7dae80141 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-c7dae80141 .tabular-table tbody tr td { border-top: none; }
#> #tabular-c7dae80141 .tabular-band { text-align: center; }
#> #tabular-c7dae80141 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-c7dae80141 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-c7dae80141 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-c7dae80141 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-c7dae80141 .text-left { text-align: left; }
#> #tabular-c7dae80141 .text-center { text-align: center; }
#> #tabular-c7dae80141 .text-right { text-align: right; }
#> #tabular-c7dae80141 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-c7dae80141 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-c7dae80141 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-c7dae80141 .valign-top { vertical-align: top; }
#> #tabular-c7dae80141 .valign-middle { vertical-align: middle; }
#> #tabular-c7dae80141 .valign-bottom { vertical-align: bottom; }
#> #tabular-c7dae80141 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-c7dae80141 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-c7dae80141 .tabular-page-break-row { display: none; }
#> #tabular-c7dae80141 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-c7dae80141 .tabular-page-header, #tabular-c7dae80141 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-c7dae80141 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-c7dae80141 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-c7dae80141 .tabular-page-header-left, #tabular-c7dae80141 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-c7dae80141 .tabular-page-header-center, #tabular-c7dae80141 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-c7dae80141 .tabular-page-header-right, #tabular-c7dae80141 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-c7dae80141 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-c7dae80141 .tabular-table tr { page-break-inside: avoid; } #tabular-c7dae80141 .tabular-page-header, #tabular-c7dae80141 .tabular-page-footer { display: none; } #tabular-c7dae80141 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-c7dae80141 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-c7dae80141 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-c7dae80141" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Adverse Events by SOC / PT</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-left">Category</th><th>n_total</th><th>soc_n</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td class="text-left" style="background-color: #f0f0f0;">TOTAL SUBJECTS WITH AN EVENT</td><td style="background-color: #f0f0f0;">199</td><td style="background-color: #f0f0f0;">199</td><td class="text-right" style="background-color: #f0f0f0;">52 (60.5)</td><td class="text-right" style="background-color: #f0f0f0;">81 (84.4)</td><td class="text-right" style="background-color: #f0f0f0;">66 (91.7)</td><td class="text-right" style="background-color: #f0f0f0;">199 (78.3)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td style="font-weight: bold;">90</td><td style="font-weight: bold;">90</td><td class="text-right" style="font-weight: bold;">19 (22.1)</td><td class="text-right" style="font-weight: bold;">36 (37.5)</td><td class="text-right" style="font-weight: bold;">35 (48.6)</td><td class="text-right" style="font-weight: bold;"> 90 (35.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>54</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>36</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>26</td><td>90</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>14</td><td>90</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>14</td><td>90</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td style="font-weight: bold;">81</td><td style="font-weight: bold;">81</td><td class="text-right" style="font-weight: bold;">15 (17.4)</td><td class="text-right" style="font-weight: bold;">36 (37.5)</td><td class="text-right" style="font-weight: bold;">30 (41.7)</td><td class="text-right" style="font-weight: bold;"> 81 (31.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>50</td><td>81</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>30</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>21</td><td>81</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>21</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>11</td><td>81</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">GASTROINTESTINAL DISORDERS</td><td style="font-weight: bold;">42</td><td style="font-weight: bold;">42</td><td class="text-right" style="font-weight: bold;">13 (15.1)</td><td class="text-right" style="font-weight: bold;">12 (12.5)</td><td class="text-right" style="font-weight: bold;">17 (23.6)</td><td class="text-right" style="font-weight: bold;"> 42 (16.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>17</td><td>42</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>13</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>12</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>5</td><td>42</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>4</td><td>42</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">NERVOUS SYSTEM DISORDERS</td><td style="font-weight: bold;">41</td><td style="font-weight: bold;">41</td><td class="text-right" style="font-weight: bold;"> 6 ( 7.0)</td><td class="text-right" style="font-weight: bold;">18 (18.8)</td><td class="text-right" style="font-weight: bold;">17 (23.6)</td><td class="text-right" style="font-weight: bold;"> 41 (16.1)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>21</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>11</td><td>41</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>7</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>6</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>3</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">CARDIAC DISORDERS</td><td style="font-weight: bold;">33</td><td style="font-weight: bold;">33</td><td class="text-right" style="font-weight: bold;"> 7 ( 8.1)</td><td class="text-right" style="font-weight: bold;">12 (12.5)</td><td class="text-right" style="font-weight: bold;">14 (19.4)</td><td class="text-right" style="font-weight: bold;"> 33 (13.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>17</td><td>33</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>10</td><td>33</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>5</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">INFECTIONS AND INFESTATIONS</td><td style="font-weight: bold;">29</td><td style="font-weight: bold;">29</td><td class="text-right" style="font-weight: bold;">12 (14.0)</td><td class="text-right" style="font-weight: bold;"> 6 ( 6.2)</td><td class="text-right" style="font-weight: bold;">11 (15.3)</td><td class="text-right" style="font-weight: bold;"> 29 (11.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>12</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="7"></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>10</td><td>29</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>3</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>3</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>2</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td style="font-weight: bold;">22</td><td style="font-weight: bold;">22</td><td class="text-right" style="font-weight: bold;"> 5 ( 5.8)</td><td class="text-right" style="font-weight: bold;"> 8 ( 8.3)</td><td class="text-right" style="font-weight: bold;"> 9 (12.5)</td><td class="text-right" style="font-weight: bold;"> 22 ( 8.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>11</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>7</td><td>22</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>3</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>3</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>2</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">PSYCHIATRIC DISORDERS</td><td style="font-weight: bold;">19</td><td style="font-weight: bold;">19</td><td class="text-right" style="font-weight: bold;"> 7 ( 8.1)</td><td class="text-right" style="font-weight: bold;"> 9 ( 9.4)</td><td class="text-right" style="font-weight: bold;"> 3 ( 4.2)</td><td class="text-right" style="font-weight: bold;"> 19 ( 7.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>6</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>5</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>4</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>3</td><td>19</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>2</td><td>19</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td style="font-weight: bold;">14</td><td style="font-weight: bold;">14</td><td class="text-right" style="font-weight: bold;"> 3 ( 3.5)</td><td class="text-right" style="font-weight: bold;"> 6 ( 6.2)</td><td class="text-right" style="font-weight: bold;"> 5 ( 6.9)</td><td class="text-right" style="font-weight: bold;"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>5</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>4</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>3</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>2</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>1</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td class="text-left" style="font-weight: bold;">INVESTIGATIONS</td><td style="font-weight: bold;">12</td><td style="font-weight: bold;">12</td><td class="text-right" style="font-weight: bold;"> 5 ( 5.8)</td><td class="text-right" style="font-weight: bold;"> 4 ( 4.2)</td><td class="text-right" style="font-weight: bold;"> 3 ( 4.2)</td><td class="text-right" style="font-weight: bold;"> 12 ( 4.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>5</td><td>12</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>4</td><td>12</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>2</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>2</td><td>12</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">1</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote"></p>
#> </div></div>

# ---- Chrome styling ----
tabular(saf_demo) |>
  style(bold = TRUE, .at = cells_headers()) |>
  style(border_top = brdr("thick", "double"),
        .at = cells_headers()) |>
  style(halign = "left", .at = cells_title()) |>
  style(blank_above = 1, blank_below = 1,
        .at = cells_title())
#> <style>
#> #tabular-9a4cc432db { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-9a4cc432db .tabular-content { width: 100%; }
#> #tabular-9a4cc432db .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-9a4cc432db .tabular-pad { margin: 0; }
#> #tabular-9a4cc432db .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-9a4cc432db .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-9a4cc432db .tabular-table th, #tabular-9a4cc432db .tabular-table td { padding: .35rem .6rem; }
#> #tabular-9a4cc432db .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-9a4cc432db .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-9a4cc432db .tabular-table thead tr:first-child th { border-top: 1.5pt double currentColor; }
#> #tabular-9a4cc432db .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-9a4cc432db .tabular-table thead .tabular-band { border-bottom: 1.5pt double currentColor; }
#> #tabular-9a4cc432db .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-9a4cc432db .tabular-table tbody tr td { border-top: none; }
#> #tabular-9a4cc432db .tabular-band { text-align: center; }
#> #tabular-9a4cc432db .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-9a4cc432db .tabular-subgroup-label { font-weight: 600; }
#> #tabular-9a4cc432db .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-9a4cc432db .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-9a4cc432db .text-left { text-align: left; }
#> #tabular-9a4cc432db .text-center { text-align: center; }
#> #tabular-9a4cc432db .text-right { text-align: right; }
#> #tabular-9a4cc432db .tabular-table thead th.text-left { text-align: left; }
#> #tabular-9a4cc432db .tabular-table thead th.text-center { text-align: center; }
#> #tabular-9a4cc432db .tabular-table thead th.text-right { text-align: right; }
#> #tabular-9a4cc432db .valign-top { vertical-align: top; }
#> #tabular-9a4cc432db .valign-middle { vertical-align: middle; }
#> #tabular-9a4cc432db .valign-bottom { vertical-align: bottom; }
#> #tabular-9a4cc432db .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-9a4cc432db .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-9a4cc432db .tabular-page-break-row { display: none; }
#> #tabular-9a4cc432db { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-9a4cc432db .tabular-page-header, #tabular-9a4cc432db .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-9a4cc432db .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-9a4cc432db .tabular-page-footer { margin-top: 1rem; }
#> #tabular-9a4cc432db .tabular-page-header-left, #tabular-9a4cc432db .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-9a4cc432db .tabular-page-header-center, #tabular-9a4cc432db .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-9a4cc432db .tabular-page-header-right, #tabular-9a4cc432db .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-9a4cc432db .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-9a4cc432db .tabular-table tr { page-break-inside: avoid; } #tabular-9a4cc432db .tabular-page-header, #tabular-9a4cc432db .tabular-page-footer { display: none; } #tabular-9a4cc432db .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-9a4cc432db .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-9a4cc432db .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-9a4cc432db" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th style="font-weight: bold">variable</th><th style="font-weight: bold">stat_label</th><th style="font-weight: bold">placebo</th><th style="font-weight: bold">drug_100</th><th style="font-weight: bold">drug_50</th><th style="font-weight: bold">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Age (years)</td><td>n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td>Age (years)</td><td>Mean (SD)</td><td>75.2 (8.59)</td><td>73.8 (7.94)</td><td>76.0 (8.11)</td><td>75.1 (8.25)</td></tr>
#> <tr><td>Age (years)</td><td>Median</td><td>76.0</td><td>75.5</td><td>78.0</td><td>77.0</td></tr>
#> <tr><td>Age (years)</td><td>Q1, Q3</td><td>69.2, 81.8</td><td>70.5, 79.0</td><td>71.0, 82.0</td><td>70.0, 81.0</td></tr>
#> <tr><td>Age (years)</td><td>Min, Max</td><td>52, 89</td><td>56, 88</td><td>51, 88</td><td>51, 89</td></tr>
#> <tr><td>Age Group, n (%)</td><td>18-64</td><td>14 (16.3)</td><td>11 (15.3)</td><td>8 (8.3)</td><td>33 (13.0)</td></tr>
#> <tr><td>Age Group, n (%)</td><td>&gt;64</td><td>72 (83.7)</td><td>61 (84.7)</td><td>88 (91.7)</td><td>221 (87.0)</td></tr>
#> <tr><td>Sex, n (%)</td><td>F</td><td>53 (61.6)</td><td>35 (48.6)</td><td>55 (57.3)</td><td>143 (56.3)</td></tr>
#> <tr><td>Sex, n (%)</td><td>M</td><td>33 (38.4)</td><td>37 (51.4)</td><td>41 (42.7)</td><td>111 (43.7)</td></tr>
#> <tr><td>Race, n (%)</td><td>WHITE</td><td>78 (90.7)</td><td>62 (86.1)</td><td>90 (93.8)</td><td>230 (90.6)</td></tr>
#> <tr><td>Race, n (%)</td><td>BLACK OR AFRICAN AMERICAN</td><td>8 (9.3)</td><td>9 (12.5)</td><td>6 (6.2)</td><td>23 (9.1)</td></tr>
#> <tr><td>Race, n (%)</td><td>ASIAN</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr><td>Race, n (%)</td><td>AMERICAN INDIAN OR ALASKA NATIVE</td><td>0 (0.0)</td><td>1 (1.4)</td><td>0 (0.0)</td><td>1 (0.4)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>HISPANIC OR LATINO</td><td>3 (3.5)</td><td>3 (4.2)</td><td>6 (6.2)</td><td>12 (4.7)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>NOT HISPANIC OR LATINO</td><td>83 (96.5)</td><td>69 (95.8)</td><td>90 (93.8)</td><td>242 (95.3)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>NOT REPORTED</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr><td>Weight (kg)</td><td>n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td>Weight (kg)</td><td>Mean (SD)</td><td>62.8 (12.77)</td><td>69.5 (14.35)</td><td>68.0 (14.50)</td><td>66.6 (14.13)</td></tr>
#> <tr><td>Weight (kg)</td><td>Median</td><td>60.6</td><td>69.0</td><td>66.7</td><td>66.7</td></tr>
#> <tr><td>Weight (kg)</td><td>Q1, Q3</td><td>53.6, 74.2</td><td>56.9, 80.3</td><td>56.0, 78.2</td><td>55.3, 77.1</td></tr>
#> <tr><td>Weight (kg)</td><td>Min, Max</td><td>34, 86</td><td>44, 108</td><td>42, 106</td><td>34, 108</td></tr>
#> <tr><td>Height (cm)</td><td>n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td>Height (cm)</td><td>Mean (SD)</td><td>162.6 (11.52)</td><td>165.9 (10.28)</td><td>163.7 (10.30)</td><td>163.9 (10.76)</td></tr>
#> <tr><td>Height (cm)</td><td>Median</td><td>162.6</td><td>165.1</td><td>162.6</td><td>162.8</td></tr>
#> <tr><td>Height (cm)</td><td>Q1, Q3</td><td>154.0, 171.1</td><td>157.5, 172.8</td><td>157.5, 170.2</td><td>156.2, 171.4</td></tr>
#> <tr><td>Height (cm)</td><td>Min, Max</td><td>137, 185</td><td>146, 190</td><td>136, 196</td><td>136, 196</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Mean (SD)</td><td>23.6 (3.67)</td><td>25.2 (3.97)</td><td>25.2 (4.40)</td><td>24.7 (4.09)</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Median</td><td>23.4</td><td>24.8</td><td>24.8</td><td>24.2</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Q1, Q3</td><td>21.2, 25.6</td><td>22.7, 27.6</td><td>22.3, 28.2</td><td>21.9, 27.3</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Min, Max</td><td>15, 33</td><td>14, 35</td><td>15, 40</td><td>14, 40</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Underweight (&lt;18.5)</td><td>3 (3.5)</td><td>1 (1.4)</td><td>4 (4.2)</td><td>8 (3.1)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Normal (18.5-24.9)</td><td>57 (66.3)</td><td>39 (54.2)</td><td>46 (47.9)</td><td>142 (55.9)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Overweight (25-29.9)</td><td>20 (23.3)</td><td>23 (31.9)</td><td>32 (33.3)</td><td>75 (29.5)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">BMI Category, n (%)</td><td style="border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7.0)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12.5)</td><td style="border-bottom: 0.5pt solid #212529;">13 (13.5)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Table-wide borders ----
tabular(saf_demo) |>
  style(border = brdr("medium"),
        .at = cells_table(side = "outer")) |>
  style(border_top = brdr("hairline", "dotted"),
        .at = cells_table(side = "rows"))
#> <style>
#> #tabular-8c4dcb4349 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-8c4dcb4349 .tabular-content { width: 100%; }
#> #tabular-8c4dcb4349 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-8c4dcb4349 .tabular-pad { margin: 0; }
#> #tabular-8c4dcb4349 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-8c4dcb4349 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-8c4dcb4349 .tabular-table th, #tabular-8c4dcb4349 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-8c4dcb4349 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-8c4dcb4349 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-8c4dcb4349 .tabular-table thead tr:first-child th { border-top: 1pt solid currentColor; }
#> #tabular-8c4dcb4349 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-8c4dcb4349 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-8c4dcb4349 .tabular-table tbody tr:last-child td { border-bottom: 1pt solid currentColor; }
#> #tabular-8c4dcb4349 .tabular-table { border-left: 1pt solid currentColor; }
#> #tabular-8c4dcb4349 .tabular-table { border-right: 1pt solid currentColor; }
#> #tabular-8c4dcb4349 .tabular-table tbody tr td { border-top: none; }
#> #tabular-8c4dcb4349 .tabular-band { text-align: center; }
#> #tabular-8c4dcb4349 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-8c4dcb4349 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-8c4dcb4349 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-8c4dcb4349 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-8c4dcb4349 .text-left { text-align: left; }
#> #tabular-8c4dcb4349 .text-center { text-align: center; }
#> #tabular-8c4dcb4349 .text-right { text-align: right; }
#> #tabular-8c4dcb4349 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-8c4dcb4349 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-8c4dcb4349 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-8c4dcb4349 .valign-top { vertical-align: top; }
#> #tabular-8c4dcb4349 .valign-middle { vertical-align: middle; }
#> #tabular-8c4dcb4349 .valign-bottom { vertical-align: bottom; }
#> #tabular-8c4dcb4349 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-8c4dcb4349 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-8c4dcb4349 .tabular-page-break-row { display: none; }
#> #tabular-8c4dcb4349 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-8c4dcb4349 .tabular-page-header, #tabular-8c4dcb4349 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-8c4dcb4349 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-8c4dcb4349 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-8c4dcb4349 .tabular-page-header-left, #tabular-8c4dcb4349 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-8c4dcb4349 .tabular-page-header-center, #tabular-8c4dcb4349 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-8c4dcb4349 .tabular-page-header-right, #tabular-8c4dcb4349 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-8c4dcb4349 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-8c4dcb4349 .tabular-table tr { page-break-inside: avoid; } #tabular-8c4dcb4349 .tabular-page-header, #tabular-8c4dcb4349 .tabular-page-footer { display: none; } #tabular-8c4dcb4349 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-8c4dcb4349 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-8c4dcb4349 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-8c4dcb4349" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>variable</th><th>stat_label</th><th>placebo</th><th>drug_100</th><th>drug_50</th><th>Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Age (years)</td><td>n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age (years)</td><td style="border-top: 0.25pt dotted currentColor;">Mean (SD)</td><td style="border-top: 0.25pt dotted currentColor;">75.2 (8.59)</td><td style="border-top: 0.25pt dotted currentColor;">73.8 (7.94)</td><td style="border-top: 0.25pt dotted currentColor;">76.0 (8.11)</td><td style="border-top: 0.25pt dotted currentColor;">75.1 (8.25)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age (years)</td><td style="border-top: 0.25pt dotted currentColor;">Median</td><td style="border-top: 0.25pt dotted currentColor;">76.0</td><td style="border-top: 0.25pt dotted currentColor;">75.5</td><td style="border-top: 0.25pt dotted currentColor;">78.0</td><td style="border-top: 0.25pt dotted currentColor;">77.0</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age (years)</td><td style="border-top: 0.25pt dotted currentColor;">Q1, Q3</td><td style="border-top: 0.25pt dotted currentColor;">69.2, 81.8</td><td style="border-top: 0.25pt dotted currentColor;">70.5, 79.0</td><td style="border-top: 0.25pt dotted currentColor;">71.0, 82.0</td><td style="border-top: 0.25pt dotted currentColor;">70.0, 81.0</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age (years)</td><td style="border-top: 0.25pt dotted currentColor;">Min, Max</td><td style="border-top: 0.25pt dotted currentColor;">52, 89</td><td style="border-top: 0.25pt dotted currentColor;">56, 88</td><td style="border-top: 0.25pt dotted currentColor;">51, 88</td><td style="border-top: 0.25pt dotted currentColor;">51, 89</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age Group, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">18-64</td><td style="border-top: 0.25pt dotted currentColor;">14 (16.3)</td><td style="border-top: 0.25pt dotted currentColor;">11 (15.3)</td><td style="border-top: 0.25pt dotted currentColor;">8 (8.3)</td><td style="border-top: 0.25pt dotted currentColor;">33 (13.0)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Age Group, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">&gt;64</td><td style="border-top: 0.25pt dotted currentColor;">72 (83.7)</td><td style="border-top: 0.25pt dotted currentColor;">61 (84.7)</td><td style="border-top: 0.25pt dotted currentColor;">88 (91.7)</td><td style="border-top: 0.25pt dotted currentColor;">221 (87.0)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Sex, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">F</td><td style="border-top: 0.25pt dotted currentColor;">53 (61.6)</td><td style="border-top: 0.25pt dotted currentColor;">35 (48.6)</td><td style="border-top: 0.25pt dotted currentColor;">55 (57.3)</td><td style="border-top: 0.25pt dotted currentColor;">143 (56.3)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Sex, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">M</td><td style="border-top: 0.25pt dotted currentColor;">33 (38.4)</td><td style="border-top: 0.25pt dotted currentColor;">37 (51.4)</td><td style="border-top: 0.25pt dotted currentColor;">41 (42.7)</td><td style="border-top: 0.25pt dotted currentColor;">111 (43.7)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Race, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">WHITE</td><td style="border-top: 0.25pt dotted currentColor;">78 (90.7)</td><td style="border-top: 0.25pt dotted currentColor;">62 (86.1)</td><td style="border-top: 0.25pt dotted currentColor;">90 (93.8)</td><td style="border-top: 0.25pt dotted currentColor;">230 (90.6)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Race, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">BLACK OR AFRICAN AMERICAN</td><td style="border-top: 0.25pt dotted currentColor;">8 (9.3)</td><td style="border-top: 0.25pt dotted currentColor;">9 (12.5)</td><td style="border-top: 0.25pt dotted currentColor;">6 (6.2)</td><td style="border-top: 0.25pt dotted currentColor;">23 (9.1)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Race, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">ASIAN</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Race, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">AMERICAN INDIAN OR ALASKA NATIVE</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">1 (1.4)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">1 (0.4)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Ethnicity, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">HISPANIC OR LATINO</td><td style="border-top: 0.25pt dotted currentColor;">3 (3.5)</td><td style="border-top: 0.25pt dotted currentColor;">3 (4.2)</td><td style="border-top: 0.25pt dotted currentColor;">6 (6.2)</td><td style="border-top: 0.25pt dotted currentColor;">12 (4.7)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Ethnicity, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">NOT HISPANIC OR LATINO</td><td style="border-top: 0.25pt dotted currentColor;">83 (96.5)</td><td style="border-top: 0.25pt dotted currentColor;">69 (95.8)</td><td style="border-top: 0.25pt dotted currentColor;">90 (93.8)</td><td style="border-top: 0.25pt dotted currentColor;">242 (95.3)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Ethnicity, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">NOT REPORTED</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor;">0 (0.0)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Weight (kg)</td><td style="border-top: 0.25pt dotted currentColor;">n</td><td style="border-top: 0.25pt dotted currentColor;">86</td><td style="border-top: 0.25pt dotted currentColor;">72</td><td style="border-top: 0.25pt dotted currentColor;">95</td><td style="border-top: 0.25pt dotted currentColor;">253</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Weight (kg)</td><td style="border-top: 0.25pt dotted currentColor;">Mean (SD)</td><td style="border-top: 0.25pt dotted currentColor;">62.8 (12.77)</td><td style="border-top: 0.25pt dotted currentColor;">69.5 (14.35)</td><td style="border-top: 0.25pt dotted currentColor;">68.0 (14.50)</td><td style="border-top: 0.25pt dotted currentColor;">66.6 (14.13)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Weight (kg)</td><td style="border-top: 0.25pt dotted currentColor;">Median</td><td style="border-top: 0.25pt dotted currentColor;">60.6</td><td style="border-top: 0.25pt dotted currentColor;">69.0</td><td style="border-top: 0.25pt dotted currentColor;">66.7</td><td style="border-top: 0.25pt dotted currentColor;">66.7</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Weight (kg)</td><td style="border-top: 0.25pt dotted currentColor;">Q1, Q3</td><td style="border-top: 0.25pt dotted currentColor;">53.6, 74.2</td><td style="border-top: 0.25pt dotted currentColor;">56.9, 80.3</td><td style="border-top: 0.25pt dotted currentColor;">56.0, 78.2</td><td style="border-top: 0.25pt dotted currentColor;">55.3, 77.1</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Weight (kg)</td><td style="border-top: 0.25pt dotted currentColor;">Min, Max</td><td style="border-top: 0.25pt dotted currentColor;">34, 86</td><td style="border-top: 0.25pt dotted currentColor;">44, 108</td><td style="border-top: 0.25pt dotted currentColor;">42, 106</td><td style="border-top: 0.25pt dotted currentColor;">34, 108</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Height (cm)</td><td style="border-top: 0.25pt dotted currentColor;">n</td><td style="border-top: 0.25pt dotted currentColor;">86</td><td style="border-top: 0.25pt dotted currentColor;">72</td><td style="border-top: 0.25pt dotted currentColor;">96</td><td style="border-top: 0.25pt dotted currentColor;">254</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Height (cm)</td><td style="border-top: 0.25pt dotted currentColor;">Mean (SD)</td><td style="border-top: 0.25pt dotted currentColor;">162.6 (11.52)</td><td style="border-top: 0.25pt dotted currentColor;">165.9 (10.28)</td><td style="border-top: 0.25pt dotted currentColor;">163.7 (10.30)</td><td style="border-top: 0.25pt dotted currentColor;">163.9 (10.76)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Height (cm)</td><td style="border-top: 0.25pt dotted currentColor;">Median</td><td style="border-top: 0.25pt dotted currentColor;">162.6</td><td style="border-top: 0.25pt dotted currentColor;">165.1</td><td style="border-top: 0.25pt dotted currentColor;">162.6</td><td style="border-top: 0.25pt dotted currentColor;">162.8</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Height (cm)</td><td style="border-top: 0.25pt dotted currentColor;">Q1, Q3</td><td style="border-top: 0.25pt dotted currentColor;">154.0, 171.1</td><td style="border-top: 0.25pt dotted currentColor;">157.5, 172.8</td><td style="border-top: 0.25pt dotted currentColor;">157.5, 170.2</td><td style="border-top: 0.25pt dotted currentColor;">156.2, 171.4</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">Height (cm)</td><td style="border-top: 0.25pt dotted currentColor;">Min, Max</td><td style="border-top: 0.25pt dotted currentColor;">137, 185</td><td style="border-top: 0.25pt dotted currentColor;">146, 190</td><td style="border-top: 0.25pt dotted currentColor;">136, 196</td><td style="border-top: 0.25pt dotted currentColor;">136, 196</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI (kg/m^2)</td><td style="border-top: 0.25pt dotted currentColor;">n</td><td style="border-top: 0.25pt dotted currentColor;">86</td><td style="border-top: 0.25pt dotted currentColor;">72</td><td style="border-top: 0.25pt dotted currentColor;">95</td><td style="border-top: 0.25pt dotted currentColor;">253</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI (kg/m^2)</td><td style="border-top: 0.25pt dotted currentColor;">Mean (SD)</td><td style="border-top: 0.25pt dotted currentColor;">23.6 (3.67)</td><td style="border-top: 0.25pt dotted currentColor;">25.2 (3.97)</td><td style="border-top: 0.25pt dotted currentColor;">25.2 (4.40)</td><td style="border-top: 0.25pt dotted currentColor;">24.7 (4.09)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI (kg/m^2)</td><td style="border-top: 0.25pt dotted currentColor;">Median</td><td style="border-top: 0.25pt dotted currentColor;">23.4</td><td style="border-top: 0.25pt dotted currentColor;">24.8</td><td style="border-top: 0.25pt dotted currentColor;">24.8</td><td style="border-top: 0.25pt dotted currentColor;">24.2</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI (kg/m^2)</td><td style="border-top: 0.25pt dotted currentColor;">Q1, Q3</td><td style="border-top: 0.25pt dotted currentColor;">21.2, 25.6</td><td style="border-top: 0.25pt dotted currentColor;">22.7, 27.6</td><td style="border-top: 0.25pt dotted currentColor;">22.3, 28.2</td><td style="border-top: 0.25pt dotted currentColor;">21.9, 27.3</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI (kg/m^2)</td><td style="border-top: 0.25pt dotted currentColor;">Min, Max</td><td style="border-top: 0.25pt dotted currentColor;">15, 33</td><td style="border-top: 0.25pt dotted currentColor;">14, 35</td><td style="border-top: 0.25pt dotted currentColor;">15, 40</td><td style="border-top: 0.25pt dotted currentColor;">14, 40</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI Category, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">Underweight (&lt;18.5)</td><td style="border-top: 0.25pt dotted currentColor;">3 (3.5)</td><td style="border-top: 0.25pt dotted currentColor;">1 (1.4)</td><td style="border-top: 0.25pt dotted currentColor;">4 (4.2)</td><td style="border-top: 0.25pt dotted currentColor;">8 (3.1)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI Category, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">Normal (18.5-24.9)</td><td style="border-top: 0.25pt dotted currentColor;">57 (66.3)</td><td style="border-top: 0.25pt dotted currentColor;">39 (54.2)</td><td style="border-top: 0.25pt dotted currentColor;">46 (47.9)</td><td style="border-top: 0.25pt dotted currentColor;">142 (55.9)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor;">BMI Category, n (%)</td><td style="border-top: 0.25pt dotted currentColor;">Overweight (25-29.9)</td><td style="border-top: 0.25pt dotted currentColor;">20 (23.3)</td><td style="border-top: 0.25pt dotted currentColor;">23 (31.9)</td><td style="border-top: 0.25pt dotted currentColor;">32 (33.3)</td><td style="border-top: 0.25pt dotted currentColor;">75 (29.5)</td></tr>
#> <tr><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">BMI Category, n (%)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">Obese (&gt;=30)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">6 (7.0)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">9 (12.5)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">13 (13.5)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 1pt solid currentColor;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- House style via style_template() ----
house <- style_template() |>
  style(bold = TRUE, .at = cells_headers()) |>
  style(border_top = brdr("thick"), .at = cells_headers()) |>
  style(border_bottom = brdr("thick"), .at = cells_headers()) |>
  style(border_bottom = brdr("medium"),
        .at = cells_table(side = "outer_bottom"))
# Attach once via set_preset(); every tabular() chain inherits.
# set_preset(style = house, font_size = 9)
```
