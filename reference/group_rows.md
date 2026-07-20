# Declare the row-grouping structure of the table

`group_rows()` names the **structural** columns whose runs of identical
values define the table's row hierarchy, ordered outer to inner. List
only the keys that drive the structure — the section headers and any
hidden break keys; the visible row-label column (e.g. the statistic
stub) stays an ordinary
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) column
and is indented automatically. It is the row-structure counterpart of
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md):
one declaration per table, replaced wholesale on a repeat call.

## Usage

``` r
group_rows(.spec, by, display = "section", skip = TRUE)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach the grouping plan to.*
  `<tabular_spec>: required`.

- by:

  *Structural grouping key columns, ordered outer to inner.*
  `<character>: required`. Names at least one column of `data`;
  duplicates are rejected. List only the section-header and break-only
  keys, not the visible label column.

  **Interaction:** A
  [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)`(by = )`
  partition column may also be a grouping key; within each partition the
  key is constant and auto-hidden, so the combination composes.

- display:

  *How the keys' values render in the body.*
  `<character(1)>: default "section"`. One value, applied to every key:

  - `"section"` (default) — each unique value emits a section header row
    spanning the visible columns; the key column is hidden from the
    body. The canonical submission shape.

  - `"collapse"` — the key column stays visible; repeated values are
    suppressed so only the first row of each run shows the label. The
    classic listing shape.

  - `"repeat"` — the key column stays visible and every row repeats the
    value. The export / QC shape, where every row must be
    self-describing.

  **Tip:** for a hidden break-only key, set `col_spec(visible = FALSE)`
  on it rather than a display mode.

- skip:

  *Which keys get a blank spacer row between their groups.*
  `<TRUE | FALSE | character>: default TRUE`. A logical flag or an
  explicit character set (the `readr::read_csv(col_names = )` pattern):

  - `TRUE` (default) — derive: a `"section"` key or a break-only
    (`visible = FALSE`) key breaks with a blank line; a visible
    `"collapse"` / `"repeat"` key runs continuous.

  - `FALSE` — no spacer rows anywhere.

  - `<character>` — exactly these `by` keys break, e.g. `skip = "param"`
    (blank line between params, none between visits). Every name must be
    in `by`; `character(0)` is equivalent to `FALSE`.

## Value

*`<tabular_spec>`.* A new spec with `@row_groups` replaced; pipe into
the remaining build verbs or
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Details

**One plan per table.** A second `group_rows()` call replaces the first
(the
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
contract); levels never accumulate across calls.

**Structural keys only.** Nesting is just listing the header keys:
`by = c("param", "visit")` renders `param` as the outer section header
and `visit` as the indented sub-header, and the first visible column
beneath (the label stub) is auto-indented one level per header. You do
not put the label column in `by`.

**Break-only keys use `visible = FALSE`.** A key you mark
`col_spec(visible = FALSE)` renders nothing and contributes only group
transitions — the blank spacer between blocks (`skip`) and the
decimal-alignment reset — exactly what a hidden sort/break key needs.
There is no separate display mode for it.

## See also

**Column display:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
for labels, alignment, and visibility of the key columns.

**Row order:**
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
— sort so each key's runs are contiguous before grouping.

**Pagination:**
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
— the grouping keys form the default panel stub; `keep_together`
protects runs across page breaks independently of grouping.

## Examples

``` r
# ---- Example 1: Demographics with section headers and a stat column ----
#
# The canonical demographics shape: `variable` is the one structural
# key. The defaults do all the work -- `display = "section"` renders
# one section header row per parameter (Age, Sex, ...) and hides the
# key column; `skip = TRUE` derives a blank spacer between sections.
# `stat_label` is NOT a grouping key -- it stays an ordinary column
# and is auto-indented one level under each section header.
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
  group_rows(by = "variable")

#tabular-70f56d538c { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
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
