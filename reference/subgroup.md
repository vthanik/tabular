# Partition the report by a variable

Attach a `subgroup_spec` to a `tabular_spec`. At render time the engine
partitions `spec@data` by the unique values of `by`, runs the full
resolve pipeline per group, and concatenates the results. **A hard page
break is inserted between groups** — every subgroup value starts on its
own page. A centred banner line appears above the column-header rule on
every page of the group (including continuation pages), matching the
canonical submission page-layout convention.

## Usage

``` r
subgroup(.spec, by, label = NULL)
```

## Arguments

- .spec:

  *The `tabular_spec` to partition.* `<tabular_spec>: required`.

- by:

  *Column name(s) to partition by.* `<character>: required`. Must
  reference a column in `spec@data`. Length-0 (or `character(0)`) clears
  the partition. Matches the `by =` arg convention of
  [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md).

  **Multi-variable.** Pass `c("var1", "var2")` to cross on every
  combination present in the data. Multi-var partitions require an
  explicit `label` template (the single-var auto-default does not
  generalise).

- label:

  *Banner template.* `<character(1) | NULL>: default NULL`. Glue-style
  template with `{column_name}` placeholders. `NULL` derives a default
  from the partition variable's `attr(data[[by]], "label")` (falling
  back to the column name).

  **Tip:** reference auxiliary columns to inline the BigN or any
  qualifier that is constant within group — e.g.
  `"Cohort: {cohort} (N = {n})"`.

  **Restriction:** Every `{col}` reference must be a column in
  `spec@data`. Unknown columns raise
  `tabular_error_subgroup_template_unknown_col`.

## Value

*The updated `tabular_spec`.* Continue chaining or resolve via
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) /
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Details

**Label is a glue-style template.** When `label` carries `{col}`
placeholders, the engine substitutes each placeholder against the FIRST
ROW of the group's filtered data — so any column whose value is constant
within group (BigN, cohort descriptor, qualifier text) can ride into the
banner. Columns that vary within group also resolve, but always to the
first row's value; pre-compute aggregates upstream.

**Default label** (when `label = NULL`, single var): the engine
generates `"<attr(data[[by]], 'label') %||% by>: {<by>}"`, so
`subgroup(by = "cohort")` renders banners like `"Cohort: A"` and
`"Cohort: B"` without further configuration.

**Replace, not stack.** A second `subgroup()` call REPLACES the prior
partition — subgroup is a single spec, not a stackable list. Passing
`by = character(0)` clears the slot, though typical clinical pipelines
set the partition once up front.

**Display-side only.** `subgroup()` partitions a pre-summarised wide
data frame; it does not aggregate, filter, or weight. The user supplies
one summary row per displayed row per group; tabular's job is solely to
lay them out with the per-group banner and page break.

**Multi-variable crossing.** `by = c("SEX", "AGEGR1")` partitions on
every combination present in the data (first variable varies slowest,
matching [`expand.grid()`](https://rdrr.io/r/base/expand.grid.html)
convention). An explicit `label` template is required for multi-var
partitions since the single-var default `"<var>: {<var>}"` does not
generalise; raise `tabular_error_subgroup_label_required` otherwise.

**Auto-hide of partition + template columns.** Every column named in
`by`, plus every column referenced via a `{col}` placeholder in `label`,
automatically flips to `visible = FALSE` at engine time. Users do not
restate `col_spec(visible = FALSE)` inside
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) for
these columns — mirroring the
[`col_spec(indent_by = ...)`](https://vthanik.github.io/tabular/reference/col_spec.md)
auto-hide ergonomic.

## See also

**Pipeline siblings:**
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md).

**Resolve / render:**
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Examples

``` r
# ---- Example 1: TEAEs by treatment arm — one set of pages per arm ----
#
# Partition the AE-by-SOC/PT pipeline by treatment arm. Each arm
# value gets its own page set with a centred `Treatment Arm: <value>`
# banner above the column-header rule on every page, separated by
# hard page breaks. The default label uses the variable's `label`
# attribute when present, falling back to the column name.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total  <- as.integer(sub(" .*", "", ae$Total))
attr(ae$row_type, "label") <- "Row Type"

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Subjects counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100", align = "decimal"),
    Total    = col_spec(label = "Total",    align = "decimal")
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
  subgroup(by = "row_type")

#tabular-5b20fffd60 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-5b20fffd60 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-5b20fffd60 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-5b20fffd60 .tabular-pad { margin: 0; line-height: 1; }
#tabular-5b20fffd60 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-5b20fffd60 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-5b20fffd60 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-5b20fffd60 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-5b20fffd60 .tabular-table th, #tabular-5b20fffd60 .tabular-table td { padding: .35rem .6rem; }
#tabular-5b20fffd60 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-5b20fffd60 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-5b20fffd60 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-5b20fffd60 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-5b20fffd60 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-5b20fffd60 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-5b20fffd60 .tabular-table tbody tr td { border-top: none; }
#tabular-5b20fffd60 .tabular-band { text-align: center; }
#tabular-5b20fffd60 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-5b20fffd60 .tabular-subgroup-label { font-weight: 600; }
#tabular-5b20fffd60 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-5b20fffd60 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-5b20fffd60 .text-left { text-align: left; }
#tabular-5b20fffd60 .text-center { text-align: center; }
#tabular-5b20fffd60 .text-right { text-align: right; }
#tabular-5b20fffd60 .tabular-table thead th.text-left { text-align: left; }
#tabular-5b20fffd60 .tabular-table thead th.text-center { text-align: center; }
#tabular-5b20fffd60 .tabular-table thead th.text-right { text-align: right; }
#tabular-5b20fffd60 .valign-top { vertical-align: top; }
#tabular-5b20fffd60 .valign-middle { vertical-align: middle; }
#tabular-5b20fffd60 .valign-bottom { vertical-align: bottom; }
#tabular-5b20fffd60 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-5b20fffd60 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-5b20fffd60 .tabular-page-break-row { display: none; }
#tabular-5b20fffd60 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-5b20fffd60 .tabular-page-header, #tabular-5b20fffd60 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-5b20fffd60 .tabular-page-header { margin-bottom: 1rem; }
#tabular-5b20fffd60 .tabular-page-footer { margin-top: 1rem; }
#tabular-5b20fffd60 .tabular-page-header-left, #tabular-5b20fffd60 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-5b20fffd60 .tabular-page-header-center, #tabular-5b20fffd60 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-5b20fffd60 .tabular-page-header-right, #tabular-5b20fffd60 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-5b20fffd60 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-5b20fffd60 .tabular-table tr { page-break-inside: avoid; } #tabular-5b20fffd60 .tabular-page-header, #tabular-5b20fffd60 .tabular-page-footer { display: none; } #tabular-5b20fffd60 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-5b20fffd60 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-5b20fffd60 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Adverse Events by SOC and Preferred Term
Safety Population (N=254)
 



SOC / PT
```
