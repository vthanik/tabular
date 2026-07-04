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

      # Two-key hierarchical sort: SOC clusters by descending count,
      # each PT nested under its SOC.
      sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))

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
# ---- Example 1: AE table clustered by SOC, PTs nested by count ----
#
# AE-by-SOC/PT table sorted so each SOC is followed immediately by
# its own preferred terms, SOC clusters in descending subject-count
# order. The sort runs on the bundled numeric helpers `soc_n` and
# `n_total`, not the formatted `Total` text, which would sort
# lexically ("14" < "171" < "29").
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_aesocpt,
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
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))

#tabular-a5be29b229 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-a5be29b229 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-a5be29b229 p { line-height: inherit; }
#tabular-a5be29b229 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-a5be29b229 .tabular-caption { margin: 0; padding: 0; }
#tabular-a5be29b229 .tabular-pad { margin: 0; line-height: 1; }
#tabular-a5be29b229 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-a5be29b229 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-a5be29b229 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-a5be29b229 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-a5be29b229 .tabular-table th, #tabular-a5be29b229 .tabular-table td { padding: .18rem .6rem; }
#tabular-a5be29b229 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-a5be29b229 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-a5be29b229 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-a5be29b229 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-a5be29b229 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-a5be29b229 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-a5be29b229 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-a5be29b229 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-a5be29b229 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-a5be29b229 .tabular-table tbody tr td { border-top: none; }
#tabular-a5be29b229 .tabular-band { text-align: center; }
#tabular-a5be29b229 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-a5be29b229 .tabular-subgroup-label { font-weight: 600; }
#tabular-a5be29b229 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-a5be29b229 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-a5be29b229 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-a5be29b229 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-a5be29b229 .text-left { text-align: left; }
#tabular-a5be29b229 .text-center { text-align: center; }
#tabular-a5be29b229 .text-right { text-align: right; }
#tabular-a5be29b229 .tabular-table thead th.text-left { text-align: left; }
#tabular-a5be29b229 .tabular-table thead th.text-center { text-align: center; }
#tabular-a5be29b229 .tabular-table thead th.text-right { text-align: right; }
#tabular-a5be29b229 .tabular-table td.text-left { text-align: left; }
#tabular-a5be29b229 .tabular-table td.text-center { text-align: center; }
#tabular-a5be29b229 .tabular-table td.text-right { text-align: right; }
#tabular-a5be29b229 .valign-top { vertical-align: top; }
#tabular-a5be29b229 .valign-middle { vertical-align: middle; }
#tabular-a5be29b229 .valign-bottom { vertical-align: bottom; }
#tabular-a5be29b229 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-a5be29b229 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-a5be29b229 .tabular-page-break-row { display: none; }
#tabular-a5be29b229 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-a5be29b229 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-a5be29b229 .tabular-page-header, #tabular-a5be29b229 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-a5be29b229 .tabular-page-header { margin-bottom: 1rem; }
#tabular-a5be29b229 .tabular-page-footer { margin-top: 1rem; }
#tabular-a5be29b229 .tabular-page-header-left, #tabular-a5be29b229 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-a5be29b229 .tabular-page-header-center, #tabular-a5be29b229 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-a5be29b229 .tabular-page-header-right, #tabular-a5be29b229 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-a5be29b229 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-a5be29b229 .tabular-table tr { page-break-inside: avoid; } #tabular-a5be29b229 .tabular-page-header, #tabular-a5be29b229 .tabular-page-footer { display: none; } #tabular-a5be29b229 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-a5be29b229 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-a5be29b229 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



SOC / PT
```
