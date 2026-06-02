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

#tabular-a516433d0e { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#tabular-a516433d0e .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-a516433d0e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-a516433d0e .tabular-pad { margin: 0; }
#tabular-a516433d0e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-a516433d0e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-a516433d0e .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-a516433d0e .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-a516433d0e .tabular-table th, #tabular-a516433d0e .tabular-table td { padding: .35rem .6rem; }
#tabular-a516433d0e .tabular-table td { text-align: left; vertical-align: top; }
#tabular-a516433d0e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-a516433d0e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-a516433d0e .tabular-table thead tr:last-child th { border-bottom: 1.5pt solid currentColor; }
#tabular-a516433d0e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-a516433d0e .tabular-table tbody tr td { border-top: none; }
#tabular-a516433d0e .tabular-band { text-align: center; }
#tabular-a516433d0e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-a516433d0e .tabular-subgroup-label { font-weight: 600; }
#tabular-a516433d0e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-a516433d0e .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-a516433d0e .text-left { text-align: left; }
#tabular-a516433d0e .text-center { text-align: center; }
#tabular-a516433d0e .text-right { text-align: right; }
#tabular-a516433d0e .tabular-table thead th.text-left { text-align: left; }
#tabular-a516433d0e .tabular-table thead th.text-center { text-align: center; }
#tabular-a516433d0e .tabular-table thead th.text-right { text-align: right; }
#tabular-a516433d0e .valign-top { vertical-align: top; }
#tabular-a516433d0e .valign-middle { vertical-align: middle; }
#tabular-a516433d0e .valign-bottom { vertical-align: bottom; }
#tabular-a516433d0e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-a516433d0e .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-a516433d0e .tabular-page-break-row { display: none; }
#tabular-a516433d0e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-a516433d0e .tabular-page-header, #tabular-a516433d0e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-a516433d0e .tabular-page-header { margin-bottom: 1rem; }
#tabular-a516433d0e .tabular-page-footer { margin-top: 1rem; }
#tabular-a516433d0e .tabular-page-header-left, #tabular-a516433d0e .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-a516433d0e .tabular-page-header-center, #tabular-a516433d0e .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-a516433d0e .tabular-page-header-right, #tabular-a516433d0e .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-a516433d0e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-a516433d0e .tabular-table tr { page-break-inside: avoid; } #tabular-a516433d0e .tabular-page-header, #tabular-a516433d0e .tabular-page-footer { display: none; } #tabular-a516433d0e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-a516433d0e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-a516433d0e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Overall Summary of Adverse Events
Safety Population (N=254)
 



Total
N=254
```
