# Apply one column spec to many columns

Field-merge a single
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
onto every column matched by name or by a predicate. The vectorized
companion to
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) for the
common case of a variable number of treatment-arm columns that all share
the same display rule (decimal alignment, a numeric format), so you
avoid [`do.call()`](https://rdrr.io/r/base/do.call.html) / `!!!`
splicing one named argument per arm.

## Usage

``` r
cols_apply(.spec, .cols, .col_spec)
```

## Arguments

- .spec:

  *The `tabular_spec` to extend.* `<tabular_spec>: required`.
  Dot-prefixed so partial matching cannot bind a user name in another
  slot.

- .cols:

  *Columns to match.* `<character | function>: required`. Either a
  character vector of input column names in `.spec@data`, or a predicate
  `function(names) -> logical` evaluated against `names(.spec@data)`
  (one logical per column, same length).

  **Restriction:** Named columns must exist in `.spec@data`. A predicate
  must return a logical vector the length of `names(.spec@data)`.
  **Tip:** No tidyselect helpers ship; pass a base vector
  (`grep("^ARM", names(df), value = TRUE)`) or a predicate
  (`\(nm) startsWith(nm, "ARM")`).

- .col_spec:

  *The spec to field-merge onto every match.* `<col_spec>: required`.
  Built with
  [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md).

## Value

*The updated `tabular_spec`.* Continue chaining with
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

## Details

**Field-merge, not replace.** `cols_apply()` reuses the same
field-by-field merge as repeated
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) calls: a
non-default field on `.col_spec` overrides; a default-valued field
leaves any prior attribute on the matched column intact. Set the shared
rule across arms first, then refine an individual arm with a later
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) call (or
the reverse).

## See also

**Companion verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) attaches
per-column specs by name;
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
builds the spec.

**Sibling build verbs:**
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

## Examples

``` r
# ---- Example 1: Decimal-align every arm column by name vector ----
#
# Demographics table whose treatment-arm columns are selected by a
# name vector (`grep()` against the data) and given one shared
# decimal-alignment spec, while the two row-label columns keep
# their own roles set with `cols()`.
arm_cols <- grep("^placebo$|^drug_|^Total$", names(saf_demo), value = TRUE)

tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  )
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic")
  ) |>
  cols_apply(arm_cols, col_spec(align = "decimal")) |>
  sort_rows(by = c("variable", "stat_label"))

#tabular-43f8866ef1 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-43f8866ef1 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-43f8866ef1 p { line-height: inherit; }
#tabular-43f8866ef1 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-43f8866ef1 .tabular-caption { margin: 0; padding: 0; }
#tabular-43f8866ef1 .tabular-pad { margin: 0; line-height: 1; }
#tabular-43f8866ef1 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-43f8866ef1 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-43f8866ef1 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-43f8866ef1 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-43f8866ef1 .tabular-table th, #tabular-43f8866ef1 .tabular-table td { padding: .18rem .6rem; }
#tabular-43f8866ef1 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-43f8866ef1 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-43f8866ef1 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-43f8866ef1 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-43f8866ef1 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-43f8866ef1 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-43f8866ef1 .tabular-table tbody tr td { border-top: none; }
#tabular-43f8866ef1 .tabular-band { text-align: center; }
#tabular-43f8866ef1 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-43f8866ef1 .tabular-subgroup-label { font-weight: 600; }
#tabular-43f8866ef1 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-43f8866ef1 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-43f8866ef1 .text-left { text-align: left; }
#tabular-43f8866ef1 .text-center { text-align: center; }
#tabular-43f8866ef1 .text-right { text-align: right; }
#tabular-43f8866ef1 .tabular-table thead th.text-left { text-align: left; }
#tabular-43f8866ef1 .tabular-table thead th.text-center { text-align: center; }
#tabular-43f8866ef1 .tabular-table thead th.text-right { text-align: right; }
#tabular-43f8866ef1 .valign-top { vertical-align: top; }
#tabular-43f8866ef1 .valign-middle { vertical-align: middle; }
#tabular-43f8866ef1 .valign-bottom { vertical-align: bottom; }
#tabular-43f8866ef1 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-43f8866ef1 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-43f8866ef1 .tabular-page-break-row { display: none; }
#tabular-43f8866ef1 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-43f8866ef1 .tabular-page-header, #tabular-43f8866ef1 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-43f8866ef1 .tabular-page-header { margin-bottom: 1rem; }
#tabular-43f8866ef1 .tabular-page-footer { margin-top: 1rem; }
#tabular-43f8866ef1 .tabular-page-header-left, #tabular-43f8866ef1 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-43f8866ef1 .tabular-page-header-center, #tabular-43f8866ef1 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-43f8866ef1 .tabular-page-header-right, #tabular-43f8866ef1 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-43f8866ef1 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-43f8866ef1 .tabular-table tr { page-break-inside: avoid; } #tabular-43f8866ef1 .tabular-page-header, #tabular-43f8866ef1 .tabular-page-footer { display: none; } #tabular-43f8866ef1 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-43f8866ef1 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-43f8866ef1 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Statistic
```
