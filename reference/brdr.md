# Border-line specification

Build a small immutable record describing one border line — width,
style, and colour. A `brdr()` value is the stroke you hand to the
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
`rules` knob (one entry per rule name, e.g.
`rules = list(midrule = brdr(width = 0.75))`) or to
[`style()`](https://vthanik.github.io/tabular/reference/style.md)'s
border arguments
(`style(border_top = brdr(...), .at = cells_table(side = "rows"))`).
Successive
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
calls layer cleanly, so a one-off override composes onto a house-style
template without disturbing the other rules.

## Usage

``` r
brdr(width = "thin", style = "solid", color = "currentColor")

is_brdr(x)
```

## Arguments

- width:

  *Stroke width.*
  `<numeric(1) | character(1)>: default `"thin"`*. Either a numeric in points (>= 0) or one of the four named keywords (`"hairline"`, `"thin"`, `"medium"`, `"thick"\`).

- style:

  *Line style.*
  `<character(1)>: default `"solid"`*. One of `"solid"`, `"dashed"`, `"dotted"`, `"double"`, `"dashdot"`, `"none"\`.

- color:

  *Stroke colour.*
  `<character(1)>: default `"currentColor"`*. Hex (`"#RRGGBB"`), CSS colour name, or `"currentColor"\`
  to inherit the surrounding text colour.

- x:

  *Any R object* — tested by `is_brdr()` for membership in the
  `tabular_brdr` S3 class.

## Value

*A `tabular_brdr` S3 object* — a length-3 named list suitable for
`preset(rules = list(<rule> = .))` or `style(border_* = .)`.

## Details

**Surface.** A single `tabular_brdr` value is a length-3 named list with
class `"tabular_brdr"`: `list(style, width, color)`. The shape is
identical to the bare triple
[`style()`](https://vthanik.github.io/tabular/reference/style.md)'s
per-side scalars accept, so the resolver in `R/borders.R` can ingest
either form transparently. Construct with `brdr()`; test with
`is_brdr()`.

**Width keywords.** `width` accepts either a numeric in points (typical
clinical values: 0.25, 0.5, 1, 1.5) or one of the four named keywords:

|              |        |
|--------------|--------|
| keyword      | points |
| `"hairline"` | 0.25   |
| `"thin"`     | 0.5    |
| `"medium"`   | 1      |
| `"thick"`    | 1.5    |

Keywords resolve to numeric points immediately; the constructed value
carries a numeric `width`. Numeric inputs pass through unchanged after a
non-negative check.

**Style enum.** `style` is one of `"solid"` (default), `"dashed"`,
`"dotted"`, `"double"`, `"dashdot"`, `"none"`. `"none"` is the explicit
clear-this-rule sentinel: setting a rule to `brdr(style = "none")` (or
the bare string `"none"`) in
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)`(rules = list(...))`
suppresses the baseline rule that backend would otherwise draw.

**Color.** Hex (`"#212529"`), CSS colour name (`"black"`,
`"slategray"`), or `"currentColor"` (default; resolves to the
surrounding text colour per backend convention — `w:color="auto"` in
DOCX, the document text colour in RTF, the CSS `currentColor` keyword in
HTML).

## See also

**Where to attach:**
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)'s
`rules` knob (one brdr() per rule name) and
[`style()`](https://vthanik.github.io/tabular/reference/style.md)'s
`border_*` arguments.

**Per-cell predicates:**
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
accepts the same per-side `border_<side>_{style,width,color}` triples
without going through `brdr()`.

**Resolver internals:**
[`tabular_classes`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
(`style_node`'s 12 border scalars).

## Examples

``` r
# ---- Example 1: A house-style rule set ----
#
# The `rules` knob takes one brdr() value per rule name. Here a
# thick column-label divider (midrule), a hairline dotted rule
# between body rows (rowrule), and the muted spanner rule dropped.
# Unlisted rules keep their booktabs defaults.
demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_aeoverall,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    sprintf("Safety Population (N=%d)", demo_n["Total"])
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Category"),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
    Total      = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
  ) |>
  preset(
    rules = list(
      midrule  = brdr(width = "thick"),
      rowrule  = brdr(width = "hairline", style = "dotted"),
      spanrule = "none"
    )
  )
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 1.5pt solid currentColor; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_9QeuR8HfdV" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Overall Summary of Adverse Events</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Total<br/>N=254</th><th>Placebo<br/>N=86</th><th>Drug 100<br/>N=72</th><th>Drug 50<br/>N=96</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any TEAE</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">217 (85.4)</td><td style="border-left: none;">65 (75.6)</td><td style="border-left: none;">68 (94.4)</td><td style="border-left: none;">84 (87.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any Serious AE (SAE)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">3 (1.2)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">1 (1.4)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">2 (2.1)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Related to Study Drug</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">184 (72.4)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">43 (50.0)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">64 (88.9)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">77 (80.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Leading to Death</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">3 (1.2)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">2 (2.3)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">0 (0.0)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">1 (1.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Recovered / Resolved</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">157 (61.8)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">47 (54.7)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">49 (68.1)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">61 (63.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Mild</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">77 (30.3)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">36 (41.9)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">20 (27.8)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">21 (21.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Moderate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor;">111 (43.7)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">24 (27.9)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">40 (55.6)</td><td style="border-top: 0.25pt dotted currentColor; border-left: none;">47 (49.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Severe</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: 0.25pt dotted currentColor; border-bottom: 0.5pt solid #212529;">29 (11.4)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 0.5pt solid #212529; border-left: none;">5 (5.8)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 0.5pt solid #212529; border-left: none;">8 (11.1)</td><td style="border-top: 0.25pt dotted currentColor; border-bottom: 0.5pt solid #212529; border-left: none;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects counted once per category.</p>
#> </div></div>

# ---- Example 2: Wrap a custom style into a reusable function ----
#
# The recommended way to share a rule style across many tables is to
# wrap the `preset()` call in a small function. A later `preset()` /
# `style()` call layers a one-off override cleanly on top.
custom_style <- function(spec) {
  spec |>
    preset(
      rules = list(
        toprule    = brdr(width = "thin", color = "#212529"),
        midrule    = brdr(width = "thin", color = "#212529"),
        bottomrule = brdr(width = "thin", color = "#212529")
      )
    )
}

tabular(saf_n) |>
  custom_style() |>
  preset(rules = list(rowrule = brdr("hairline", "dashed")))
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_HIyvQgF0fi" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>arm</th><th>arm_short</th><th>n</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Placebo</td><td style="border-left: none;">placebo</td><td style="border-left: none;">86</td></tr>
#> <tr><td style="border-top: 0.25pt dashed currentColor;">Xanomeline Low Dose</td><td style="border-top: 0.25pt dashed currentColor; border-left: none;">drug_50</td><td style="border-top: 0.25pt dashed currentColor; border-left: none;">96</td></tr>
#> <tr><td style="border-top: 0.25pt dashed currentColor;">Xanomeline High Dose</td><td style="border-top: 0.25pt dashed currentColor; border-left: none;">drug_100</td><td style="border-top: 0.25pt dashed currentColor; border-left: none;">72</td></tr>
#> <tr><td style="border-top: 0.25pt dashed currentColor; border-bottom: 0.5pt solid #212529;">Total</td><td style="border-top: 0.25pt dashed currentColor; border-bottom: 0.5pt solid #212529; border-left: none;">Total</td><td style="border-top: 0.25pt dashed currentColor; border-bottom: 0.5pt solid #212529; border-left: none;">254</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 3: Width keyword vs numeric, every style enum value ----
#
# Width accepts both the four named keywords and a bare numeric
# in points; style accepts six enum values. Use `is_brdr()` to
# confirm the constructor returned a valid `tabular_brdr` rather
# than a fallback list.
for (w in c("hairline", "thin", "medium", "thick")) {
  cat(w, "=", brdr(width = w)$width, "pt\n")
}
#> hairline = 0.25 pt
#> thin = 0.5 pt
#> medium = 1 pt
#> thick = 1.5 pt
is_brdr(brdr(width = 0.75))
#> [1] TRUE

lapply(
  c("solid", "dashed", "dotted", "double", "dashdot", "none"),
  function(s) brdr(style = s)
)
#> [[1]]
#> <tabular_brdr> 0.5pt solid currentColor
#> 
#> [[2]]
#> <tabular_brdr> 0.5pt dashed currentColor
#> 
#> [[3]]
#> <tabular_brdr> 0.5pt dotted currentColor
#> 
#> [[4]]
#> <tabular_brdr> 0.5pt double currentColor
#> 
#> [[5]]
#> <tabular_brdr> 0.5pt dashdot currentColor
#> 
#> [[6]]
#> <tabular_brdr> 0.5pt none currentColor
#> 

# ---- Example 4: A full grid via the body-edge style() path ----
#
# The `rules` knob covers the named booktabs anatomy; for the body
# outer frame and inter-column separators, hand brdr() to
# `style(.at = cells_table(side = ...))`. Here a medium outer frame
# plus hairline column separators on a demographics table.
tabular(saf_demo, titles = "Demographics with a full grid") |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  style(border = brdr(width = "medium"), .at = cells_table(side = "outer")) |>
  style(border_left = brdr("hairline"), .at = cells_table(side = "cols"))
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 1pt solid currentColor; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 1pt solid currentColor; }
#> .tabular-table { border-left: 1pt solid currentColor; }
#> .tabular-table { border-right: 1pt solid currentColor; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_vjF0HqZ3vE" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Demographics with a full grid</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 100</th><th class="text-center">Drug 50</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age (years)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 86          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 72          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 96          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 75.2 (8.59) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 73.8 (7.94) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 76.0 (8.11) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 75.1 (8.25) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 76.0        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 75.5        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 78.0        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 77.0        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 69.2, 81.8  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 70.5, 79.0  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 71.0, 82.0  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 70.0, 81.0  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 52  , 89    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 56  , 88    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 51  , 88    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 51  , 89    </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age Group, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">18-64</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 14 (16.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 11 (15.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  8 ( 8.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 33 (13.0)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">&gt;64</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 72 (83.7)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 61 (84.7)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 88 (91.7)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">221 (87.0)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">F</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 53 (61.6)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 35 (48.6)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 55 (57.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">143 (56.3)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">M</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 33 (38.4)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 37 (51.4)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 41 (42.7)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">111 (43.7)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">WHITE</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 78 (90.7)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 62 (86.1)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 90 (93.8)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">230 (90.6)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLACK OR AFRICAN AMERICAN</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  8 ( 9.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  9 (12.5)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  6 ( 6.2)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 23 ( 9.1)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ASIAN</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  1 ( 1.4)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  1 ( 0.4)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Ethnicity, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HISPANIC OR LATINO</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  3 ( 3.5)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  3 ( 4.2)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  6 ( 6.2)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 12 ( 4.7)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT HISPANIC OR LATINO</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 83 (96.5)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 69 (95.8)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 90 (93.8)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">242 (95.3)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT REPORTED</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  0          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Weight (kg)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 86          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 72          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 95          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 62.8 (12.77)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 69.5 (14.35)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 68.0 (14.50)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 66.6 (14.13)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 60.6        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 69.0        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 66.7        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 66.7        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 53.6, 74.2  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 56.9,  80.3 </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 56.0,  78.2 </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 55.3,  77.1 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 34  , 86    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 44  , 108   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 42  , 106   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 34  , 108   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Height (cm)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 86          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 72          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 96          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">162.6 (11.52)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">165.9 (10.28)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">163.7 (10.30)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">163.9 (10.76)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">162.6        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">165.1        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">162.6        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">162.8        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">154.0, 171.1 </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">157.5, 172.8 </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">157.5, 170.2 </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">156.2, 171.4 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">137  , 185   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">146  , 190   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">136  , 196   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">136  , 196   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI (kg/m^2)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 86          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 72          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 95          </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 23.6 (3.67) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 25.2 (3.97) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 25.2 (4.40) </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 24.7 (4.09) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 23.4        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 24.8        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 24.8        </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 24.2        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 21.2, 25.6  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 22.7, 27.6  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 22.3, 28.2  </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 21.9, 27.3  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 15  , 33    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 14  , 35    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 15  , 40    </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 14  , 40    </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI Category, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Underweight (&lt;18.5)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  3 ( 3.5)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  1 ( 1.4)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  4 ( 4.2)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">  8 ( 3.1)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Normal (18.5-24.9)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 57 (66.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 39 (54.2)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 46 (47.9)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;">142 (55.9)   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Overweight (25-29.9)</td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 20 (23.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 23 (31.9)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 32 (33.3)   </td><td class="text-right" style="border-left: 0.25pt solid currentColor;"> 75 (29.5)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 1pt solid currentColor;">Obese (&gt;=30)</td><td class="text-right" style="border-bottom: 1pt solid currentColor; border-left: 0.25pt solid currentColor;">  6 ( 7.0)   </td><td class="text-right" style="border-bottom: 1pt solid currentColor; border-left: 0.25pt solid currentColor;">  9 (12.5)   </td><td class="text-right" style="border-bottom: 1pt solid currentColor; border-left: 0.25pt solid currentColor;"> 13 (13.5)   </td><td class="text-right" style="border-bottom: 1pt solid currentColor; border-left: 0.25pt solid currentColor;"> 28 (11.0)   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
