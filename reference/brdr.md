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
brdr(width = "thin", style = "solid", color = "ink")

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
`"slategray"`), the `"ink"` token (default; resolves to the primary rule
ink `#212529`, decoupled from the surrounding text colour so a
recoloured header keeps a neutral rule), or `"currentColor"` (inherit
the surrounding text colour per backend convention — `w:color="auto"` in
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
demo_n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(
  cdisc_saf_ae,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Category"),
    placebo    = col_spec(label = "Placebo\nN={demo_n['placebo']}"),
    drug_50    = col_spec(label = "Drug 50\nN={demo_n['drug_50']}"),
    drug_100   = col_spec(label = "Drug 100\nN={demo_n['drug_100']}"),
    Total      = col_spec(label = "Total\nN={demo_n['Total']}")
  ) |>
  preset(
    rules = list(
      midrule  = brdr(width = "thick"),
      rowrule  = brdr(width = "hairline", style = "dotted"),
      spanrule = "none"
    )
  )

#tabular-6c93b3da7c { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-6c93b3da7c .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-6c93b3da7c p { line-height: inherit; }
#tabular-6c93b3da7c .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-6c93b3da7c .tabular-caption { margin: 0; padding: 0; }
#tabular-6c93b3da7c .tabular-pad { margin: 0; line-height: 1; }
#tabular-6c93b3da7c .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-6c93b3da7c .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-6c93b3da7c .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-6c93b3da7c .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-6c93b3da7c .tabular-table th, #tabular-6c93b3da7c .tabular-table td { padding: .18rem .6rem; }
#tabular-6c93b3da7c .tabular-table td { text-align: left; vertical-align: top; }
#tabular-6c93b3da7c .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-6c93b3da7c .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-6c93b3da7c .tabular-table thead tr:last-child th { border-bottom: 1.5pt solid #212529; }
#tabular-6c93b3da7c .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-6c93b3da7c .tabular-table tbody tr td { border-top: none; }
#tabular-6c93b3da7c .tabular-band { text-align: center; }
#tabular-6c93b3da7c .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-6c93b3da7c .tabular-subgroup-label { font-weight: 600; }
#tabular-6c93b3da7c .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-6c93b3da7c .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-6c93b3da7c .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-6c93b3da7c .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-6c93b3da7c .text-left { text-align: left; }
#tabular-6c93b3da7c .text-center { text-align: center; }
#tabular-6c93b3da7c .text-right { text-align: right; }
#tabular-6c93b3da7c .tabular-table thead th.text-left { text-align: left; }
#tabular-6c93b3da7c .tabular-table thead th.text-center { text-align: center; }
#tabular-6c93b3da7c .tabular-table thead th.text-right { text-align: right; }
#tabular-6c93b3da7c .valign-top { vertical-align: top; }
#tabular-6c93b3da7c .valign-middle { vertical-align: middle; }
#tabular-6c93b3da7c .valign-bottom { vertical-align: bottom; }
#tabular-6c93b3da7c .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-6c93b3da7c .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-6c93b3da7c .tabular-page-break-row { display: none; }
#tabular-6c93b3da7c { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-6c93b3da7c .tabular-page-header, #tabular-6c93b3da7c .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-6c93b3da7c .tabular-page-header { margin-bottom: 1rem; }
#tabular-6c93b3da7c .tabular-page-footer { margin-top: 1rem; }
#tabular-6c93b3da7c .tabular-page-header-left, #tabular-6c93b3da7c .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-6c93b3da7c .tabular-page-header-center, #tabular-6c93b3da7c .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-6c93b3da7c .tabular-page-header-right, #tabular-6c93b3da7c .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-6c93b3da7c .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-6c93b3da7c .tabular-table tr { page-break-inside: avoid; } #tabular-6c93b3da7c .tabular-page-header, #tabular-6c93b3da7c .tabular-page-footer { display: none; } #tabular-6c93b3da7c .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-6c93b3da7c .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-6c93b3da7c .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Overall Summary of Adverse Events
Safety Population
 



Total
N=254
```
