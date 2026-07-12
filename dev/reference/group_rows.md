# Declare the row-grouping structure of the table

`group_rows()` names the columns whose runs of identical values define
the table's row hierarchy, ordered outer to inner, and how each level
renders — as a section header row, as a repeat-suppressed column, as a
fully repeated column, or as an invisible break-only key. It is the
row-structure counterpart of
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md):
one declaration per table, replaced wholesale on a repeat call.

## Usage

``` r
group_rows(.spec, by, display = "header_row", skip = NA)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach the grouping plan to.*
  `<tabular_spec>: required`.

- by:

  *Grouping key columns, ordered outer to inner.*
  `<character(>= 1)>: required`. Every entry must be a column of `data`;
  duplicates are rejected.

  **Interaction:** A
  [`subgroup()`](https://vthanik.github.io/tabular/dev/reference/subgroup.md)`(by = )`
  partition column may also be a grouping key; within each partition the
  key is constant and auto-hidden, so the combination composes.

- display:

  *How each key's values render in the body.*
  `<character>: default "header_row"`. Length 1 (applied to every key)
  or `length(by)` (one mode per key):

  - `"header_row"` (default) — each unique value emits a section header
    row spanning the visible columns; the key column is hidden from the
    body. The canonical submission shape.

  - `"column"` — the key column stays visible; repeated values are
    suppressed so only the first row of each run shows the label.

  - `"column_repeat"` — the key column stays visible and every row
    repeats the value.

  - `"none"` — break-only key: no header row, the column is hidden, and
    the key contributes only group transitions (skip spacers, decimal
    sections). Use for a hidden block key, e.g. an AE table whose SOC
    lives in the row text.

- skip:

  *Whether a blank spacer row separates consecutive groups of each key.*
  `<logical>: default NA`. Length 1 or `length(by)`. `NA` follows
  `display`: `TRUE` for `"header_row"` and `"none"`, `FALSE` for the
  column modes.

## Value

*`<tabular_spec>`.* A new spec with `@row_groups` replaced; pipe into
the remaining build verbs or
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).

## Details

**One plan per table.** A second `group_rows()` call replaces the first
(the
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
contract); levels never accumulate across calls.

**Grouping drives more than display.** The keys feed the section header
synthesis and repeat suppression in the body, the blank spacer rows
between groups (`skip`), the decimal-alignment sections (each skip block
aligns in isolation), and the default column stub repeated on every
horizontal panel from
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)`(panels = )`.

## See also

**Column display:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
for labels, alignment, and visibility of the key columns.

**Row order:**
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
— sort so each key's runs are contiguous before grouping.

**Pagination:**
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
— the grouping keys form the default panel stub; `keep_together`
protects runs across page breaks independently of grouping.

## Examples

``` r
# ---- Example 1: Demographics with section headers and a stat column ----
#
# The canonical demographics shape: `variable` renders as a section
# header row per parameter (Age, Sex, ...), and `stat_label` stays
# visible as a repeat-suppressed statistic column. The outer key is
# declared first.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_demo,
  titles = c("Table 14.1.1", "Demographics", "Safety Population")
) |>
  cols(
    variable = "Parameter",
    stat_label = "Statistic",
    placebo = "Placebo\nN={n['placebo']}",
    drug_50 = "Drug 50\nN={n['drug_50']}",
    drug_100 = "Drug 100\nN={n['drug_100']}",
    Total = "Total\nN={n['Total']}"
  ) |>
  cols_apply(
    c("placebo", "drug_50", "drug_100", "Total"),
    col_spec(align = "decimal")
  ) |>
  group_rows(by = c("variable", "stat_label"), display = c("header_row", "column"))

#tabular-70f56d538c { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-70f56d538c .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-70f56d538c p { line-height: inherit; }
#tabular-70f56d538c .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-70f56d538c .tabular-caption { margin: 0; padding: 0; }
#tabular-70f56d538c .tabular-pad { margin: 0; line-height: 1; }
#tabular-70f56d538c .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-70f56d538c .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-70f56d538c .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-70f56d538c .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-70f56d538c .tabular-table th, #tabular-70f56d538c .tabular-table td { padding: .18rem .6rem; }
#tabular-70f56d538c .tabular-table td { text-align: left; vertical-align: top; }
#tabular-70f56d538c .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-70f56d538c .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-70f56d538c .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-70f56d538c .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-70f56d538c .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-70f56d538c .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-70f56d538c .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-70f56d538c .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-70f56d538c .tabular-table tbody tr td { border-top: none; }
#tabular-70f56d538c .tabular-band { text-align: center; }
#tabular-70f56d538c .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-70f56d538c .tabular-subgroup-label { font-weight: 600; }
#tabular-70f56d538c .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-70f56d538c .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-70f56d538c .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-70f56d538c .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-70f56d538c .text-left { text-align: left; }
#tabular-70f56d538c .text-center { text-align: center; }
#tabular-70f56d538c .text-right { text-align: right; }
#tabular-70f56d538c .tabular-table thead th.text-left { text-align: left; }
#tabular-70f56d538c .tabular-table thead th.text-center { text-align: center; }
#tabular-70f56d538c .tabular-table thead th.text-right { text-align: right; }
#tabular-70f56d538c .tabular-table td.text-left { text-align: left; }
#tabular-70f56d538c .tabular-table td.text-center { text-align: center; }
#tabular-70f56d538c .tabular-table td.text-right { text-align: right; }
#tabular-70f56d538c .valign-top { vertical-align: top; }
#tabular-70f56d538c .valign-middle { vertical-align: middle; }
#tabular-70f56d538c .valign-bottom { vertical-align: bottom; }
#tabular-70f56d538c .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-70f56d538c .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-70f56d538c .tabular-page-break-row { display: none; }
#tabular-70f56d538c { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-70f56d538c .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-70f56d538c .tabular-page-header, #tabular-70f56d538c .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-70f56d538c .tabular-page-header { margin-bottom: 1rem; }
#tabular-70f56d538c .tabular-page-footer { margin-top: 1rem; }
#tabular-70f56d538c .tabular-page-header-left, #tabular-70f56d538c .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-70f56d538c .tabular-page-header-center, #tabular-70f56d538c .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-70f56d538c .tabular-page-header-right, #tabular-70f56d538c .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-70f56d538c .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-70f56d538c .tabular-table tr { page-break-inside: avoid; } #tabular-70f56d538c .tabular-page-header, #tabular-70f56d538c .tabular-page-footer { display: none; } #tabular-70f56d538c .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-70f56d538c .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-70f56d538c .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics
Safety Population
 



Statistic
```
