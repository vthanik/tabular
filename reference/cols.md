# Attach per-column specifications

Add
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
entries to a `tabular_spec`. Each named argument is one column: the name
is the input column in `.spec@data` and the value is the `col_spec`
carrying that column's display attributes (usage, label, format,
alignment, width, visibility, NA text). Columns not mentioned get a
default
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
(usage = display) at engine-validate time.

## Usage

``` r
cols(.spec, ..., .default = NULL)
```

## Arguments

- .spec:

  *The `tabular_spec` to extend.* `<tabular_spec>: required`.
  Dot-prefixed so R's partial argument matching cannot accidentally bind
  a short user-supplied name (e.g. `s`, `sp`) in `...` to the spec slot.
  Pipe input (`tabular(...) |> cols(...)`) works the normal way — the
  spec is supplied positionally.

- ...:

  *Named `col_spec` objects, one per column.* Each name is the input
  column name in `.spec@data`. Names must match an existing column —
  pre-compute derived columns upstream with
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  (or equivalent) before
  [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).

  **Restriction:** Names must be unique within a single `cols()` call
  (duplicates warn; "last value wins"). **Tip:** To override an
  attribute already declared, use a second `cols()` call downstream and
  let the merge rule apply.

- .default:

  *Fallback `col_spec` for unmentioned columns.*
  `<col_spec | NULL>: default NULL`. When a `col_spec`, it is
  field-merged onto every data column that is NOT named in `...` and
  does not already carry a spec from an earlier `cols()` call. `NULL`
  (default) leaves unmentioned columns to the engine-time default. Use
  it to set one alignment / format across a variable number of arm
  columns in a single call.

  **Interaction:** Explicit `...` specs always win — `.default` only
  fills the gaps. A column carried over from a prior `cols()` call is
  treated as already specified and is left untouched.

      # Decimal-align every arm column without listing each by name.
      tabular(cdisc_saf_demo) |>
        cols(
          variable   = col_spec(usage = "group", label = "Parameter"),
          stat_label = col_spec(label = "Statistic"),
          .default   = col_spec(align = "decimal")
        )

## Value

*The updated `tabular_spec`.* Continue chaining with
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

## Details

**Sparse declaration.** Declare only the columns whose attributes differ
from the default — a typical pipeline uses one `cols()` call with one
entry per non-default column.

**Within-call duplicates warn.** A duplicate name inside one `cols()`
call warns and "last value wins". To intentionally override an
attribute, use a second `cols()` call downstream and let the merge rule
below apply.

## Repeat-call merge semantics

When `cols()` is called more than once for the same column, the engine
merges the new `col_spec` into the existing one field-by- field. A
non-default value on the new spec overrides; a default- valued field
leaves the existing field intact. This lets you build a column's spec in
stages — declare the label-and-alignment block up front, add the width
once you know it fits, then attach a sort key, all without re-stating
earlier attributes. Essential when generating specs programmatically
(looping over arms, layering a house-style helper).

Default values that do NOT override the existing field:

|           |                                  |
|-----------|----------------------------------|
| field     | default that does not override   |
| `usage`   | `NA_character_`                  |
| `label`   | `NA_character_`                  |
| `format`  | `NULL`                           |
| `visible` | `TRUE`                           |
| `width`   | `NA_real_`                       |
| `align`   | `NA_character_`                  |
| `na_text` | `NA_character_` (inherit preset) |

    # Three-stage build: label/usage first, alignment second, width
    # third. Each stage leaves earlier fields intact.
    tabular(cdisc_saf_demo) |>
      cols(variable = col_spec(usage = "group", label = "Parameter")) |>
      cols(variable = col_spec(align = "left")) |>
      cols(variable = col_spec(width = 2.0))
    # Result: variable has usage="group", label="Parameter",
    #         align="left", width=2.0 — all four fields set.

## See also

**Companion constructor:**
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
builds the per-column DSL object that `cols()` attaches.

**Sibling build verbs:**
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Demographics with arm BigN inline in headers ----
#
# Demographics table where the row-label columns sit on the left
# and the four treatment-arm columns embed BigN in the header
# label (drawn inline from the bundled `cdisc_saf_n` data frame). Every
# arm column is decimal-aligned so mixed-format cells like
# "5 (3.2%)" line up on the decimal mark.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Percentages based on N per treatment group."
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total      = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  ) |>
  sort_rows(by = c("variable", "stat_label"))

#tabular-9350918ac1 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-9350918ac1 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-9350918ac1 p { line-height: inherit; }
#tabular-9350918ac1 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-9350918ac1 .tabular-caption { margin: 0; padding: 0; }
#tabular-9350918ac1 .tabular-pad { margin: 0; line-height: 1; }
#tabular-9350918ac1 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-9350918ac1 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-9350918ac1 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-9350918ac1 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-9350918ac1 .tabular-table th, #tabular-9350918ac1 .tabular-table td { padding: .18rem .6rem; }
#tabular-9350918ac1 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-9350918ac1 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-9350918ac1 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-9350918ac1 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-9350918ac1 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-9350918ac1 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-9350918ac1 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-9350918ac1 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-9350918ac1 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-9350918ac1 .tabular-table tbody tr td { border-top: none; }
#tabular-9350918ac1 .tabular-band { text-align: center; }
#tabular-9350918ac1 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-9350918ac1 .tabular-subgroup-label { font-weight: 600; }
#tabular-9350918ac1 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-9350918ac1 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-9350918ac1 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-9350918ac1 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-9350918ac1 .text-left { text-align: left; }
#tabular-9350918ac1 .text-center { text-align: center; }
#tabular-9350918ac1 .text-right { text-align: right; }
#tabular-9350918ac1 .tabular-table thead th.text-left { text-align: left; }
#tabular-9350918ac1 .tabular-table thead th.text-center { text-align: center; }
#tabular-9350918ac1 .tabular-table thead th.text-right { text-align: right; }
#tabular-9350918ac1 .valign-top { vertical-align: top; }
#tabular-9350918ac1 .valign-middle { vertical-align: middle; }
#tabular-9350918ac1 .valign-bottom { vertical-align: bottom; }
#tabular-9350918ac1 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-9350918ac1 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-9350918ac1 .tabular-page-break-row { display: none; }
#tabular-9350918ac1 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-9350918ac1 .tabular-page-header, #tabular-9350918ac1 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-9350918ac1 .tabular-page-header { margin-bottom: 1rem; }
#tabular-9350918ac1 .tabular-page-footer { margin-top: 1rem; }
#tabular-9350918ac1 .tabular-page-header-left, #tabular-9350918ac1 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-9350918ac1 .tabular-page-header-center, #tabular-9350918ac1 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-9350918ac1 .tabular-page-header-right, #tabular-9350918ac1 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-9350918ac1 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-9350918ac1 .tabular-table tr { page-break-inside: avoid; } #tabular-9350918ac1 .tabular-page-header, #tabular-9350918ac1 .tabular-page-footer { display: none; } #tabular-9350918ac1 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-9350918ac1 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-9350918ac1 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Statistic
```
