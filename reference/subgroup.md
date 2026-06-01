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
#> <style>
#> #tabular-d1273b0db5 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-d1273b0db5 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-d1273b0db5 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-d1273b0db5 .tabular-pad { margin: 0; }
#> #tabular-d1273b0db5 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-d1273b0db5 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-d1273b0db5 .tabular-table th, #tabular-d1273b0db5 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-d1273b0db5 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-d1273b0db5 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-d1273b0db5 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-d1273b0db5 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-d1273b0db5 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-d1273b0db5 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-d1273b0db5 .tabular-table tbody tr td { border-top: none; }
#> #tabular-d1273b0db5 .tabular-band { text-align: center; }
#> #tabular-d1273b0db5 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-d1273b0db5 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-d1273b0db5 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-d1273b0db5 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-d1273b0db5 .text-left { text-align: left; }
#> #tabular-d1273b0db5 .text-center { text-align: center; }
#> #tabular-d1273b0db5 .text-right { text-align: right; }
#> #tabular-d1273b0db5 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-d1273b0db5 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-d1273b0db5 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-d1273b0db5 .valign-top { vertical-align: top; }
#> #tabular-d1273b0db5 .valign-middle { vertical-align: middle; }
#> #tabular-d1273b0db5 .valign-bottom { vertical-align: bottom; }
#> #tabular-d1273b0db5 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-d1273b0db5 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-d1273b0db5 .tabular-page-break-row { display: none; }
#> #tabular-d1273b0db5 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-d1273b0db5 .tabular-page-header, #tabular-d1273b0db5 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-d1273b0db5 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-d1273b0db5 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-d1273b0db5 .tabular-page-header-left, #tabular-d1273b0db5 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-d1273b0db5 .tabular-page-header-center, #tabular-d1273b0db5 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-d1273b0db5 .tabular-page-header-right, #tabular-d1273b0db5 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-d1273b0db5 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-d1273b0db5 .tabular-table tr { page-break-inside: avoid; } #tabular-d1273b0db5 .tabular-page-header, #tabular-d1273b0db5 .tabular-page-footer { display: none; } #tabular-d1273b0db5 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-d1273b0db5 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-d1273b0db5 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-d1273b0db5" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by SOC and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>SOC / PT</th><th>soc_n</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-subgroup"><td colspan="6" class="tabular-subgroup-label"><strong>Row Type: overall</strong></td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">TOTAL SUBJECTS WITH AN EVENT</td><td style="border-bottom: 0.5pt solid #212529;">199</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">52 (60.5)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">81 (84.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">66 (91.7)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">199 (78.3)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="6" class="tabular-subgroup-label"><strong>Row Type: soc</strong></td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right">90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right">81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right">42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right">41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right">33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right">29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right">22 ( 8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">19 ( 7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right">14 ( 5.5)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">INVESTIGATIONS</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 5 ( 5.8)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 4 ( 4.2)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 3 ( 4.2)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">12 ( 4.7)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="6" class="tabular-subgroup-label"><strong>Row Type: pt</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td class="text-right">8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right">54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td class="text-right">6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right">50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td class="text-right">8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right">36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td class="text-right">3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right">30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td class="text-right">5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right">26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td class="text-right">5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right">21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right">21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right">21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td class="text-right">9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right">17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right">14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right">14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right">13 ( 5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right">12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right">12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right">11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right">11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right">11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td class="text-right">4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td class="text-right">6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td class="text-right">0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right"> 7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td class="text-right">3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right"> 5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td class="text-right">4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 2.0)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="6" class="tabular-subgroup-label"><strong>Row Type: pt</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td class="text-right">0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right"> 4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td class="text-right">0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right">0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td class="text-right">2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td class="text-right">0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td class="text-right">0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td class="text-right">0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td class="text-right">0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td class="text-right">0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td class="text-right">1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td class="text-right">0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right"> 1 ( 0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects counted once per SOC and once per PT.</p>
#> </div></div>

# ---- Example 2: Partition by Sex with inline BigN via template ----
#
# `label` is a glue-style template; any column whose value is
# constant within group can ride into the banner. `saf_subgroup`
# ships partition-constant `sex_n` / `agegr_n` BigN columns
# alongside the value cells, so each banner reads
# `"Sex: F (N = 106)"`, etc. `sex` and `sex_n` auto-hide from the
# body (partition `by` and template-referenced columns).
tabular(saf_subgroup, titles = "Vital Signs at End of Treatment") |>
  cols(
    agegr      = col_spec(usage = "group", label = "Age Group"),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")
#> <style>
#> #tabular-1f88c49413 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-1f88c49413 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-1f88c49413 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-1f88c49413 .tabular-pad { margin: 0; }
#> #tabular-1f88c49413 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-1f88c49413 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-1f88c49413 .tabular-table th, #tabular-1f88c49413 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-1f88c49413 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-1f88c49413 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-1f88c49413 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-1f88c49413 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-1f88c49413 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-1f88c49413 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-1f88c49413 .tabular-table tbody tr td { border-top: none; }
#> #tabular-1f88c49413 .tabular-band { text-align: center; }
#> #tabular-1f88c49413 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-1f88c49413 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-1f88c49413 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-1f88c49413 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-1f88c49413 .text-left { text-align: left; }
#> #tabular-1f88c49413 .text-center { text-align: center; }
#> #tabular-1f88c49413 .text-right { text-align: right; }
#> #tabular-1f88c49413 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-1f88c49413 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-1f88c49413 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-1f88c49413 .valign-top { vertical-align: top; }
#> #tabular-1f88c49413 .valign-middle { vertical-align: middle; }
#> #tabular-1f88c49413 .valign-bottom { vertical-align: bottom; }
#> #tabular-1f88c49413 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-1f88c49413 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-1f88c49413 .tabular-page-break-row { display: none; }
#> #tabular-1f88c49413 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-1f88c49413 .tabular-page-header, #tabular-1f88c49413 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-1f88c49413 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-1f88c49413 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-1f88c49413 .tabular-page-header-left, #tabular-1f88c49413 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-1f88c49413 .tabular-page-header-center, #tabular-1f88c49413 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-1f88c49413 .tabular-page-header-right, #tabular-1f88c49413 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-1f88c49413 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-1f88c49413 .tabular-table tr { page-break-inside: avoid; } #tabular-1f88c49413 .tabular-page-header, #tabular-1f88c49413 .tabular-page-footer { display: none; } #tabular-1f88c49413 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-1f88c49413 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-1f88c49413 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-1f88c49413" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Vital Signs at End of Treatment</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: F (N = 106)</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9         </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (10.5)</td><td class="text-right"> 79.9 (8.3) </td><td class="text-right"> 81.6 (8.5) </td><td class="text-right"> 76.8 (10.0)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 78.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 84.0       </td><td class="text-right"> 79.5       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 88   </td><td class="text-right"> 68  , 90   </td><td class="text-right"> 68  , 90   </td><td class="text-right"> 49  , 90   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9         </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">129.9 (11.2)</td><td class="text-right">132.1 (4.3) </td><td class="text-right">121.8 (13.6)</td><td class="text-right">128.6 (11.1)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">130.0       </td><td class="text-right">128.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right">113  , 156  </td><td class="text-right">128  , 140  </td><td class="text-right">100  , 140  </td><td class="text-right">100  , 156  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.0 (10.8)</td><td class="text-right"> 76.9 (12.2)</td><td class="text-right"> 75.9 (11.9)</td><td class="text-right"> 75.5 (11.7)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 76.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 100  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td><td class="text-right"> 50  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">137.1 (15.8)</td><td class="text-right">137.5 (16.7)</td><td class="text-right">140.1 (16.8)</td><td class="text-right">138.0 (16.4)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">134.0       </td><td class="text-right">142.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 172  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 98  , 178  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 177  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 178  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: M (N = 83)</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3         </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 83.0 (13.3)</td><td class="text-right"> 80.7 (3.1) </td><td class="text-right"> 77.1 (7.0) </td><td class="text-right"> 80.1 (10.2)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 80.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 68  , 104  </td><td class="text-right"> 78  , 84   </td><td class="text-right"> 68  , 87   </td><td class="text-right"> 68  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3         </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.4 (8.3) </td><td class="text-right">122.7 (4.6) </td><td class="text-right">124.8 (12.0)</td><td class="text-right">128.9 (10.9)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">120.0       </td><td class="text-right">127.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right">123  , 150  </td><td class="text-right">120  , 128  </td><td class="text-right">107  , 146  </td><td class="text-right">107  , 150  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (9.7) </td><td class="text-right"> 73.7 (9.7) </td><td class="text-right"> 75.3 (7.9) </td><td class="text-right"> 74.4 (9.2) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 58  , 100  </td><td class="text-right"> 52  , 94   </td><td class="text-right"> 57  , 90   </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">127.6 (15.3)</td><td class="text-right">127.0 (17.1)</td><td class="text-right">127.4 (11.5)</td><td class="text-right">127.3 (14.7)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">124.0       </td><td class="text-right">130.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 92  , 162  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 156  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 3: Multi-variable crossing (Sex x Age group) ----
#
# Pass two columns to partition on every combination present in
# the data. The label template MUST reference each variable
# explicitly because the single-var auto-default does not
# generalise. expand.grid order: first var (sex) varies slowest,
# second (agegr) fastest, giving banner sequence F/<65, F/>=65,
# M/<65, M/>=65.
tabular(saf_subgroup, titles = "Vital Signs by Sex and Age Group") |>
  cols(
    sex_n      = col_spec(visible = FALSE),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(
    by    = c("sex", "agegr"),
    label = "Sex: {sex} / Age: {agegr}"
  )
#> <style>
#> #tabular-59a4de2b07 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-59a4de2b07 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-59a4de2b07 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-59a4de2b07 .tabular-pad { margin: 0; }
#> #tabular-59a4de2b07 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-59a4de2b07 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-59a4de2b07 .tabular-table th, #tabular-59a4de2b07 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-59a4de2b07 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-59a4de2b07 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-59a4de2b07 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-59a4de2b07 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-59a4de2b07 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-59a4de2b07 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-59a4de2b07 .tabular-table tbody tr td { border-top: none; }
#> #tabular-59a4de2b07 .tabular-band { text-align: center; }
#> #tabular-59a4de2b07 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-59a4de2b07 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-59a4de2b07 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-59a4de2b07 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-59a4de2b07 .text-left { text-align: left; }
#> #tabular-59a4de2b07 .text-center { text-align: center; }
#> #tabular-59a4de2b07 .text-right { text-align: right; }
#> #tabular-59a4de2b07 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-59a4de2b07 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-59a4de2b07 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-59a4de2b07 .valign-top { vertical-align: top; }
#> #tabular-59a4de2b07 .valign-middle { vertical-align: middle; }
#> #tabular-59a4de2b07 .valign-bottom { vertical-align: bottom; }
#> #tabular-59a4de2b07 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-59a4de2b07 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-59a4de2b07 .tabular-page-break-row { display: none; }
#> #tabular-59a4de2b07 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-59a4de2b07 .tabular-page-header, #tabular-59a4de2b07 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-59a4de2b07 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-59a4de2b07 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-59a4de2b07 .tabular-page-header-left, #tabular-59a4de2b07 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-59a4de2b07 .tabular-page-header-center, #tabular-59a4de2b07 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-59a4de2b07 .tabular-page-header-right, #tabular-59a4de2b07 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-59a4de2b07 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-59a4de2b07 .tabular-table tr { page-break-inside: avoid; } #tabular-59a4de2b07 .tabular-page-header, #tabular-59a4de2b07 .tabular-page-footer { display: none; } #tabular-59a4de2b07 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-59a4de2b07 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-59a4de2b07 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-59a4de2b07" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Vital Signs by Sex and Age Group</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: F / Age: &lt;65</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9        </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (10.5)</td><td class="text-right"> 79.9 (8.3)</td><td class="text-right"> 81.6 (8.5) </td><td class="text-right"> 76.8 (10.0)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 78.0       </td><td class="text-right"> 80.0      </td><td class="text-right"> 84.0       </td><td class="text-right"> 79.5       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 88   </td><td class="text-right"> 68  , 90  </td><td class="text-right"> 68  , 90   </td><td class="text-right"> 49  , 90   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9        </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">129.9 (11.2)</td><td class="text-right">132.1 (4.3)</td><td class="text-right">121.8 (13.6)</td><td class="text-right">128.6 (11.1)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">130.0      </td><td class="text-right">128.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">113  , 156  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">128  , 140 </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 140  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 156  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: F / Age: &gt;=65</strong></td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.0 (10.8)</td><td class="text-right"> 76.9 (12.2)</td><td class="text-right"> 75.9 (11.9)</td><td class="text-right"> 75.5 (11.7)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 76.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 100  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td><td class="text-right"> 50  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">137.1 (15.8)</td><td class="text-right">137.5 (16.7)</td><td class="text-right">140.1 (16.8)</td><td class="text-right">138.0 (16.4)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">134.0       </td><td class="text-right">142.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 172  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 98  , 178  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 177  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 178  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: M / Age: &lt;65</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3        </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 83.0 (13.3)</td><td class="text-right"> 80.7 (3.1)</td><td class="text-right"> 77.1 (7.0) </td><td class="text-right"> 80.1 (10.2)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 80.0       </td><td class="text-right"> 80.0      </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 68  , 104  </td><td class="text-right"> 78  , 84  </td><td class="text-right"> 68  , 87   </td><td class="text-right"> 68  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3        </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.4 (8.3) </td><td class="text-right">122.7 (4.6)</td><td class="text-right">124.8 (12.0)</td><td class="text-right">128.9 (10.9)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">120.0      </td><td class="text-right">127.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">123  , 150  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">120  , 128 </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">107  , 146  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">107  , 150  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: M / Age: &gt;=65</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (9.7) </td><td class="text-right"> 73.7 (9.7) </td><td class="text-right"> 75.3 (7.9) </td><td class="text-right"> 74.4 (9.2) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 58  , 100  </td><td class="text-right"> 52  , 94   </td><td class="text-right"> 57  , 90   </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">127.6 (15.3)</td><td class="text-right">127.0 (17.1)</td><td class="text-right">127.4 (11.5)</td><td class="text-right">127.3 (14.7)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">124.0       </td><td class="text-right">130.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 92  , 162  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 156  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Clear a partition with subgroup(character()) ----
#
# `subgroup(by = character())` (or `subgroup(by = NULL)`)
# explicitly clears any prior partition. Useful in
# programmatically-built pipelines where a downstream branch
# decides not to paginate by group after all — the call resets
# the spec back to a single-page-set render.
tabular(saf_subgroup, titles = "Pooled (no sex partition)") |>
  subgroup("sex", label = "Sex: {sex}") |>
  # Decide later that the sex split was the wrong default —
  # clear it before rendering.
  subgroup(character())
#> <style>
#> #tabular-99f5b7e4f3 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-99f5b7e4f3 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-99f5b7e4f3 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-99f5b7e4f3 .tabular-pad { margin: 0; }
#> #tabular-99f5b7e4f3 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-99f5b7e4f3 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-99f5b7e4f3 .tabular-table th, #tabular-99f5b7e4f3 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-99f5b7e4f3 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-99f5b7e4f3 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-99f5b7e4f3 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-99f5b7e4f3 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-99f5b7e4f3 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-99f5b7e4f3 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-99f5b7e4f3 .tabular-table tbody tr td { border-top: none; }
#> #tabular-99f5b7e4f3 .tabular-band { text-align: center; }
#> #tabular-99f5b7e4f3 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-99f5b7e4f3 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-99f5b7e4f3 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-99f5b7e4f3 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-99f5b7e4f3 .text-left { text-align: left; }
#> #tabular-99f5b7e4f3 .text-center { text-align: center; }
#> #tabular-99f5b7e4f3 .text-right { text-align: right; }
#> #tabular-99f5b7e4f3 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-99f5b7e4f3 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-99f5b7e4f3 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-99f5b7e4f3 .valign-top { vertical-align: top; }
#> #tabular-99f5b7e4f3 .valign-middle { vertical-align: middle; }
#> #tabular-99f5b7e4f3 .valign-bottom { vertical-align: bottom; }
#> #tabular-99f5b7e4f3 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-99f5b7e4f3 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-99f5b7e4f3 .tabular-page-break-row { display: none; }
#> #tabular-99f5b7e4f3 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-99f5b7e4f3 .tabular-page-header, #tabular-99f5b7e4f3 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-99f5b7e4f3 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-99f5b7e4f3 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-99f5b7e4f3 .tabular-page-header-left, #tabular-99f5b7e4f3 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-99f5b7e4f3 .tabular-page-header-center, #tabular-99f5b7e4f3 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-99f5b7e4f3 .tabular-page-header-right, #tabular-99f5b7e4f3 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-99f5b7e4f3 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-99f5b7e4f3 .tabular-table tr { page-break-inside: avoid; } #tabular-99f5b7e4f3 .tabular-page-header, #tabular-99f5b7e4f3 .tabular-page-footer { display: none; } #tabular-99f5b7e4f3 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-99f5b7e4f3 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-99f5b7e4f3 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-99f5b7e4f3" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Pooled (no sex partition)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>sex</th><th>agegr</th><th>sex_n</th><th>agegr_n</th><th>paramcd</th><th>param</th><th>stat_label</th><th>placebo</th><th>drug_50</th><th>drug_100</th><th>Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>n</td><td>24</td><td>9</td><td>9</td><td>42</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Mean (SD)</td><td>73.9 (10.5)</td><td>79.9 (8.3)</td><td>81.6 (8.5)</td><td>76.8 (10.0)</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Median</td><td>78.0</td><td>80.0</td><td>84.0</td><td>79.5</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Min, Max</td><td>49, 88</td><td>68, 90</td><td>68, 90</td><td>49, 90</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>n</td><td>24</td><td>9</td><td>9</td><td>42</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Mean (SD)</td><td>129.9 (11.2)</td><td>132.1 (4.3)</td><td>121.8 (13.6)</td><td>128.6 (11.1)</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Median</td><td>130.0</td><td>130.0</td><td>128.0</td><td>130.0</td></tr>
#> <tr><td>F</td><td>&lt;65</td><td>106</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Min, Max</td><td>113, 156</td><td>128, 140</td><td>100, 140</td><td>100, 156</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>n</td><td>105</td><td>99</td><td>72</td><td>276</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Mean (SD)</td><td>74.0 (10.8)</td><td>76.9 (12.2)</td><td>75.9 (11.9)</td><td>75.5 (11.7)</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Median</td><td>72.0</td><td>79.0</td><td>80.0</td><td>76.0</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Min, Max</td><td>50, 100</td><td>50, 100</td><td>56, 98</td><td>50, 100</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>n</td><td>105</td><td>99</td><td>72</td><td>276</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Mean (SD)</td><td>137.1 (15.8)</td><td>137.5 (16.7)</td><td>140.1 (16.8)</td><td>138.0 (16.4)</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Median</td><td>134.0</td><td>134.0</td><td>142.0</td><td>138.0</td></tr>
#> <tr><td>F</td><td>&gt;=65</td><td>106</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Min, Max</td><td>95, 172</td><td>98, 178</td><td>100, 177</td><td>95, 178</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>n</td><td>12</td><td>3</td><td>12</td><td>27</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Mean (SD)</td><td>83.0 (13.3)</td><td>80.7 (3.1)</td><td>77.1 (7.0)</td><td>80.1 (10.2)</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Median</td><td>80.0</td><td>80.0</td><td>79.0</td><td>80.0</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Min, Max</td><td>68, 104</td><td>78, 84</td><td>68, 87</td><td>68, 104</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>n</td><td>12</td><td>3</td><td>12</td><td>27</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Mean (SD)</td><td>134.4 (8.3)</td><td>122.7 (4.6)</td><td>124.8 (12.0)</td><td>128.9 (10.9)</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Median</td><td>131.0</td><td>120.0</td><td>127.0</td><td>130.0</td></tr>
#> <tr><td>M</td><td>&lt;65</td><td>83</td><td>23</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Min, Max</td><td>123, 150</td><td>120, 128</td><td>107, 146</td><td>107, 150</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>n</td><td>81</td><td>66</td><td>75</td><td>222</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Mean (SD)</td><td>73.9 (9.7)</td><td>73.7 (9.7)</td><td>75.3 (7.9)</td><td>74.4 (9.2)</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Median</td><td>73.0</td><td>74.0</td><td>76.0</td><td>74.0</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>DIABP</td><td>Diastolic BP (mmHg)</td><td>Min, Max</td><td>58, 100</td><td>52, 94</td><td>57, 90</td><td>52, 100</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>n</td><td>81</td><td>66</td><td>75</td><td>222</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Mean (SD)</td><td>127.6 (15.3)</td><td>127.0 (17.1)</td><td>127.4 (11.5)</td><td>127.3 (14.7)</td></tr>
#> <tr><td>M</td><td>&gt;=65</td><td>83</td><td>166</td><td>SYSBP</td><td>Systolic BP (mmHg)</td><td>Median</td><td>130.0</td><td>124.0</td><td>130.0</td><td>130.0</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">M</td><td style="border-bottom: 0.5pt solid #212529;">&gt;=65</td><td style="border-bottom: 0.5pt solid #212529;">83</td><td style="border-bottom: 0.5pt solid #212529;">166</td><td style="border-bottom: 0.5pt solid #212529;">SYSBP</td><td style="border-bottom: 0.5pt solid #212529;">Systolic BP (mmHg)</td><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td style="border-bottom: 0.5pt solid #212529;">78, 164</td><td style="border-bottom: 0.5pt solid #212529;">92, 162</td><td style="border-bottom: 0.5pt solid #212529;">100, 156</td><td style="border-bottom: 0.5pt solid #212529;">78, 164</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
