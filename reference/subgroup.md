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
subgroup(.spec, by, label = NULL, big_n = NULL, big_n_fmt = "\n(N={n})")
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

- big_n:

  *Per-page BigN denominators.* `<data.frame> | NULL: default NULL`. A
  table giving the `(N=x)` denominator each arm's header should show on
  each subgroup page. Each arm is named as it appears in the header —
  either a data column (the N rides that column's leaf label) **or** a
  [`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
  band label (the N rides that spanner band). Ns are non-negative whole
  numbers; provide one per `by` combination present in the data. Accepts
  **either** shape:

  - **Wide** — the `by` column(s) plus one numeric column per arm (cells
    are the Ns).

  - **Long** — the `by` column(s) plus one arm-name column and one
    numeric N column, i.e. `dplyr::count()` / `summarise()` output used
    directly with no reshaping.

      # Wide: one column per arm.
      wide <- data.frame(
        sex     = factor(c("F", "M")),
        placebo = c(24L, 18L), drug_50 = c(9L, 15L), Total = c(42L, 47L)
      )
      # Long: count()-style, pivoted internally. Equivalent to `wide`.
      long <- data.frame(
        sex  = factor(rep(c("F", "M"), each = 3)),
        arm  = rep(c("placebo", "drug_50", "Total"), 2),
        n    = c(24L, 9L, 42L, 18L, 15L, 47L)
      )
      spec |> subgroup(by = "sex", big_n = long)

  **Requirement:** band keying needs
  [`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
  **before** `subgroup()` in the pipeline; each arm name must resolve to
  exactly one leaf XOR one band. Every missing per-page N is a call-time
  error, never a silently wrong denominator.

  **Note:** the per-arm N renders in every backend. The paged backends
  (RTF, PDF / LaTeX, DOCX) carry it on the column header that repeats on
  every page of the subgroup. HTML and Markdown are continuous (one
  stacked table, one header), so they instead emit a per-arm N row
  directly under each subgroup banner, the `(N=x)` aligned beneath its
  arm column.

- big_n_fmt:

  *Per-page BigN template.* `<character(1)>: default "\n(N={n})"`.
  Appended to each arm's header label, with `{n}` substituted by that
  page/column's integer N. Only the `{n}` token is allowed; the default
  puts the N on its own line under the arm name.

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
    "Safety Population"
  ),
  footnotes = "Subjects counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100", align = "decimal"),
    Total    = col_spec(label = "Total",    align = "decimal")
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
  subgroup(by = "row_type")

#tabular-833090277c { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-833090277c .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-833090277c p { line-height: inherit; }
#tabular-833090277c .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-833090277c .tabular-caption { margin: 0; padding: 0; }
#tabular-833090277c .tabular-pad { margin: 0; line-height: 1; }
#tabular-833090277c .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-833090277c .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-833090277c .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-833090277c .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-833090277c .tabular-table th, #tabular-833090277c .tabular-table td { padding: .18rem .6rem; }
#tabular-833090277c .tabular-table td { text-align: left; vertical-align: top; }
#tabular-833090277c .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-833090277c .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-833090277c .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-833090277c .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-833090277c .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-833090277c .tabular-table tbody tr td { border-top: none; }
#tabular-833090277c .tabular-band { text-align: center; }
#tabular-833090277c .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-833090277c .tabular-subgroup-label { font-weight: 600; }
#tabular-833090277c .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-833090277c .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-833090277c .text-left { text-align: left; }
#tabular-833090277c .text-center { text-align: center; }
#tabular-833090277c .text-right { text-align: right; }
#tabular-833090277c .tabular-table thead th.text-left { text-align: left; }
#tabular-833090277c .tabular-table thead th.text-center { text-align: center; }
#tabular-833090277c .tabular-table thead th.text-right { text-align: right; }
#tabular-833090277c .valign-top { vertical-align: top; }
#tabular-833090277c .valign-middle { vertical-align: middle; }
#tabular-833090277c .valign-bottom { vertical-align: bottom; }
#tabular-833090277c .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-833090277c .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-833090277c .tabular-page-break-row { display: none; }
#tabular-833090277c { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-833090277c .tabular-page-header, #tabular-833090277c .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-833090277c .tabular-page-header { margin-bottom: 1rem; }
#tabular-833090277c .tabular-page-footer { margin-top: 1rem; }
#tabular-833090277c .tabular-page-header-left, #tabular-833090277c .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-833090277c .tabular-page-header-center, #tabular-833090277c .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-833090277c .tabular-page-header-right, #tabular-833090277c .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-833090277c .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-833090277c .tabular-table tr { page-break-inside: avoid; } #tabular-833090277c .tabular-page-header, #tabular-833090277c .tabular-page-footer { display: none; } #tabular-833090277c .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-833090277c .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-833090277c .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by SOC and Preferred Term
Safety Population
 



SOC / PT
```
