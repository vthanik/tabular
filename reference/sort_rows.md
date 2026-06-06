# Sort the display rows

Attach a `sort_spec` to a `tabular_spec`. The engine applies the sort
before pagination, so `by` may reference any column in `spec@data`
whether or not the column is declared in
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md).

## Usage

``` r
sort_rows(.spec, by = character(), descending = FALSE)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach the sort to.*
  `<tabular_spec>: required`.

- by:

  *Ordered column names to sort by, in precedence order.*
  `<character>: default character()`. Length 0 is accepted (no-op sort).
  May reference columns not declared in
  [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) —
  sort-only helper columns ride along through the engine.

  **Restriction:** Every entry must be a column in `spec@data`. Cannot
  reference arm columns produced by
  [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md);
  pivot upstream of the sort instead. Arm cells hold rendered stat
  strings (e.g. `"75.2 (8.3)"`) that do not order meaningfully.

      # Two-key clinical sort: row_type ascending, n_total descending.
      sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))

- descending:

  *Per-key sort direction.*
  `<logical(1) | logical(length(by))>: default FALSE`. `TRUE` sorts the
  corresponding key descending; length 1 recycles to every key.

  **Restriction:** No NAs. Length must be 1 or `length(by)`. **Tip:**
  For mixed-direction multi-key sorts, pass `length(by)` values; the
  engine inverts the `xtfrm` rank of each descending key and calls
  [`order()`](https://rdrr.io/r/base/order.html) once on all keys.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)).

## Details

**Replace, not stack.** A second `sort_rows()` call REPLACES the prior
sort — sort is a single spec, not a stackable list. Call with no
arguments to clear.

**NA last, regardless of direction.** NA values in a sort key are placed
at the end whether the key is ascending or descending (matching
`order(..., na.last = TRUE)`).

**Factor levels drive the order.** Factor columns sort by factor levels,
not by the character label. The CDISC BOR ordering
(`CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING`) survives a tabular
pipeline without an explicit `mutate()` — coerce `stat_label` to a
factor with the levels in clinical order upstream, then
`sort_rows(by = "stat_label")` does the rest.

## See also

**Sibling build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: AE table sorted by SOC, then by descending subject count ----
#
# AE-by-SOC/PT table where the SOCs and PTs appear in descending
# order of subject count within the row-type hierarchy (overall
# first, then SOCs, then PTs). `cdisc_saf_aesocpt$Total` cells are
# formatted text ("171 (67.3)"), so a lexical sort on `Total`
# would be wrong ("14" < "171" < "29") — attach a numeric rank
# column upstream and sort on (row_type, n_total).
ae <- cdisc_saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total <- as.integer(sub(" .*", "", ae$Total))
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
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
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))

#tabular-806c4a335f { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-806c4a335f .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-806c4a335f p { line-height: inherit; }
#tabular-806c4a335f .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-806c4a335f .tabular-caption { margin: 0; padding: 0; }
#tabular-806c4a335f .tabular-pad { margin: 0; line-height: 1; }
#tabular-806c4a335f .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-806c4a335f .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-806c4a335f .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-806c4a335f .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-806c4a335f .tabular-table th, #tabular-806c4a335f .tabular-table td { padding: .18rem .6rem; }
#tabular-806c4a335f .tabular-table td { text-align: left; vertical-align: top; }
#tabular-806c4a335f .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-806c4a335f .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-806c4a335f .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-806c4a335f .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-806c4a335f .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-806c4a335f .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-806c4a335f .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-806c4a335f .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-806c4a335f .tabular-table tbody tr td { border-top: none; }
#tabular-806c4a335f .tabular-band { text-align: center; }
#tabular-806c4a335f .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-806c4a335f .tabular-subgroup-label { font-weight: 600; }
#tabular-806c4a335f .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-806c4a335f .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-806c4a335f .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-806c4a335f .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-806c4a335f .text-left { text-align: left; }
#tabular-806c4a335f .text-center { text-align: center; }
#tabular-806c4a335f .text-right { text-align: right; }
#tabular-806c4a335f .tabular-table thead th.text-left { text-align: left; }
#tabular-806c4a335f .tabular-table thead th.text-center { text-align: center; }
#tabular-806c4a335f .tabular-table thead th.text-right { text-align: right; }
#tabular-806c4a335f .valign-top { vertical-align: top; }
#tabular-806c4a335f .valign-middle { vertical-align: middle; }
#tabular-806c4a335f .valign-bottom { vertical-align: bottom; }
#tabular-806c4a335f .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-806c4a335f .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-806c4a335f .tabular-page-break-row { display: none; }
#tabular-806c4a335f { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-806c4a335f .tabular-page-header, #tabular-806c4a335f .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-806c4a335f .tabular-page-header { margin-bottom: 1rem; }
#tabular-806c4a335f .tabular-page-footer { margin-top: 1rem; }
#tabular-806c4a335f .tabular-page-header-left, #tabular-806c4a335f .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-806c4a335f .tabular-page-header-center, #tabular-806c4a335f .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-806c4a335f .tabular-page-header-right, #tabular-806c4a335f .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-806c4a335f .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-806c4a335f .tabular-table tr { page-break-inside: avoid; } #tabular-806c4a335f .tabular-page-header, #tabular-806c4a335f .tabular-page-footer { display: none; } #tabular-806c4a335f .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-806c4a335f .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-806c4a335f .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



SOC / PT
```
