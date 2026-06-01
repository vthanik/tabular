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
# first, then SOCs, then PTs). `saf_aesocpt$Total` cells are
# formatted text ("171 (67.3)"), so a lexical sort on `Total`
# would be wrong ("14" < "171" < "29") — attach a numeric rank
# column upstream and sort on (row_type, n_total).
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total <- as.integer(sub(" .*", "", ae$Total))
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#> <style>
#> #tabular-0bbe4c54d2 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-0bbe4c54d2 .tabular-content { width: 100%; }
#> #tabular-0bbe4c54d2 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-0bbe4c54d2 .tabular-pad { margin: 0; }
#> #tabular-0bbe4c54d2 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-0bbe4c54d2 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-0bbe4c54d2 .tabular-table th, #tabular-0bbe4c54d2 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-0bbe4c54d2 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-0bbe4c54d2 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-0bbe4c54d2 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-0bbe4c54d2 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-0bbe4c54d2 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-0bbe4c54d2 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-0bbe4c54d2 .tabular-table tbody tr td { border-top: none; }
#> #tabular-0bbe4c54d2 .tabular-band { text-align: center; }
#> #tabular-0bbe4c54d2 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-0bbe4c54d2 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-0bbe4c54d2 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-0bbe4c54d2 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-0bbe4c54d2 .text-left { text-align: left; }
#> #tabular-0bbe4c54d2 .text-center { text-align: center; }
#> #tabular-0bbe4c54d2 .text-right { text-align: right; }
#> #tabular-0bbe4c54d2 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-0bbe4c54d2 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-0bbe4c54d2 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-0bbe4c54d2 .valign-top { vertical-align: top; }
#> #tabular-0bbe4c54d2 .valign-middle { vertical-align: middle; }
#> #tabular-0bbe4c54d2 .valign-bottom { vertical-align: bottom; }
#> #tabular-0bbe4c54d2 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-0bbe4c54d2 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-0bbe4c54d2 .tabular-page-break-row { display: none; }
#> #tabular-0bbe4c54d2 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-0bbe4c54d2 .tabular-page-header, #tabular-0bbe4c54d2 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-0bbe4c54d2 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-0bbe4c54d2 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-0bbe4c54d2 .tabular-page-header-left, #tabular-0bbe4c54d2 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-0bbe4c54d2 .tabular-page-header-center, #tabular-0bbe4c54d2 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-0bbe4c54d2 .tabular-page-header-right, #tabular-0bbe4c54d2 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-0bbe4c54d2 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-0bbe4c54d2 .tabular-table tr { page-break-inside: avoid; } #tabular-0bbe4c54d2 .tabular-page-header, #tabular-0bbe4c54d2 .tabular-page-footer { display: none; } #tabular-0bbe4c54d2 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-0bbe4c54d2 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-0bbe4c54d2 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-0bbe4c54d2" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>SOC / PT</th><th>soc_n</th><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=96</th><th>Drug 100<br/>N=72</th><th>Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td>52 (60.5)</td><td>81 (84.4)</td><td>66 (91.7)</td><td>199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td>19 (22.1)</td><td>36 (37.5)</td><td>35 (48.6)</td><td>90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td>15 (17.4)</td><td>36 (37.5)</td><td>30 (41.7)</td><td>81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td>13 (15.1)</td><td>12 (12.5)</td><td>17 (23.6)</td><td>42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td>6 (7.0)</td><td>18 (18.8)</td><td>17 (23.6)</td><td>41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td>7 (8.1)</td><td>12 (12.5)</td><td>14 (19.4)</td><td>33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td>12 (14.0)</td><td>6 (6.2)</td><td>11 (15.3)</td><td>29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td>5 (5.8)</td><td>8 (8.3)</td><td>9 (12.5)</td><td>22 (8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td>7 (8.1)</td><td>9 (9.4)</td><td>3 (4.2)</td><td>19 (7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td>5 (5.8)</td><td>4 (4.2)</td><td>3 (4.2)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td>8 (9.3)</td><td>21 (21.9)</td><td>25 (34.7)</td><td>54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td>6 (7.0)</td><td>23 (24.0)</td><td>21 (29.2)</td><td>50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td>8 (9.3)</td><td>14 (14.6)</td><td>14 (19.4)</td><td>36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td>3 (3.5)</td><td>13 (13.5)</td><td>14 (19.4)</td><td>30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td>5 (5.8)</td><td>13 (13.5)</td><td>8 (11.1)</td><td>26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td>5 (5.8)</td><td>9 (9.4)</td><td>7 (9.7)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td>3 (3.5)</td><td>9 (9.4)</td><td>9 (12.5)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td>2 (2.3)</td><td>9 (9.4)</td><td>10 (13.9)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td>9 (10.5)</td><td>5 (5.2)</td><td>3 (4.2)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td>2 (2.3)</td><td>7 (7.3)</td><td>8 (11.1)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td>2 (2.3)</td><td>4 (4.2)</td><td>8 (11.1)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td>3 (3.5)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>13 (5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td>3 (3.5)</td><td>3 (3.1)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td>2 (2.3)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td>3 (3.5)</td><td>3 (3.1)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td>4 (4.7)</td><td>2 (2.1)</td><td>4 (5.6)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td>6 (7.0)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td>0 (0.0)</td><td>5 (5.2)</td><td>2 (2.8)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td>3 (3.5)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td>1 (1.2)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td>1 (1.2)</td><td>2 (2.1)</td><td>2 (2.8)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td>1 (1.2)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td>4 (4.7)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td>0 (0.0)</td><td>0 (0.0)</td><td>4 (5.6)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td>2 (2.3)</td><td>0 (0.0)</td><td>2 (2.8)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td>2 (2.3)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>2 (2.8)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td>0 (0.0)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td>1 (1.2)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td>0 (0.0)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>1 (0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">1 (1.4)</td><td style="border-bottom: 0.5pt solid #212529;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects are counted once per SOC and once per PT.</p>
#> </div></div>

# ---- Example 2: BOR table in CDISC factor order ----
#
# Efficacy BOR table that must appear in CDISC clinical order
# (CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING < ORR < DCR),
# not alphabetical. `eff_resp$stat_label` arrives as character, so
# coerce to a factor with the canonical levels upstream and
# `sort_rows()` uses those levels directly.
bor_levels <- c(
  "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
  "Objective Response Rate (CR + PR)",
  "Disease Control Rate (CR + PR + SD)"
)
eff <- eff_resp
eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
ne <- stats::setNames(eff_n$n, eff_n$arm_short)

tabular(
  eff,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  ),
  footnotes = "Response per RECIST 1.1, investigator assessment."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Response"),
    row_type   = col_spec(visible = FALSE),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
  ) |>
  sort_rows(by = "stat_label")
#> <style>
#> #tabular-39a9349e6a { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-39a9349e6a .tabular-content { width: 100%; }
#> #tabular-39a9349e6a .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-39a9349e6a .tabular-pad { margin: 0; }
#> #tabular-39a9349e6a .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-39a9349e6a .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-39a9349e6a .tabular-table th, #tabular-39a9349e6a .tabular-table td { padding: .35rem .6rem; }
#> #tabular-39a9349e6a .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-39a9349e6a .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-39a9349e6a .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-39a9349e6a .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-39a9349e6a .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-39a9349e6a .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-39a9349e6a .tabular-table tbody tr td { border-top: none; }
#> #tabular-39a9349e6a .tabular-band { text-align: center; }
#> #tabular-39a9349e6a .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-39a9349e6a .tabular-subgroup-label { font-weight: 600; }
#> #tabular-39a9349e6a .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-39a9349e6a .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-39a9349e6a .text-left { text-align: left; }
#> #tabular-39a9349e6a .text-center { text-align: center; }
#> #tabular-39a9349e6a .text-right { text-align: right; }
#> #tabular-39a9349e6a .tabular-table thead th.text-left { text-align: left; }
#> #tabular-39a9349e6a .tabular-table thead th.text-center { text-align: center; }
#> #tabular-39a9349e6a .tabular-table thead th.text-right { text-align: right; }
#> #tabular-39a9349e6a .valign-top { vertical-align: top; }
#> #tabular-39a9349e6a .valign-middle { vertical-align: middle; }
#> #tabular-39a9349e6a .valign-bottom { vertical-align: bottom; }
#> #tabular-39a9349e6a .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-39a9349e6a .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-39a9349e6a .tabular-page-break-row { display: none; }
#> #tabular-39a9349e6a { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-39a9349e6a .tabular-page-header, #tabular-39a9349e6a .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-39a9349e6a .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-39a9349e6a .tabular-page-footer { margin-top: 1rem; }
#> #tabular-39a9349e6a .tabular-page-header-left, #tabular-39a9349e6a .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-39a9349e6a .tabular-page-header-center, #tabular-39a9349e6a .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-39a9349e6a .tabular-page-header-right, #tabular-39a9349e6a .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-39a9349e6a .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-39a9349e6a .tabular-table tr { page-break-inside: avoid; } #tabular-39a9349e6a .tabular-page-header, #tabular-39a9349e6a .tabular-page-footer { display: none; } #tabular-39a9349e6a .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-39a9349e6a .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-39a9349e6a .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-39a9349e6a" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=84</th><th>Drug 100<br/>N=84</th><th>groupid</th><th>group_label</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>1 (1.2)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>1 (1.2)</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>83 (96.5)</td><td>82 (97.6)</td><td>81 (96.4)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>2 (2.3)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>(0.3, 8.1)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>(0.7, 9.9)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>2 (2.4)</td><td>4</td><td>Disease Control Rate</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">(0.7, 9.9)</td><td style="border-bottom: 0.5pt solid #212529;">(0.0, 6.5)</td><td style="border-bottom: 0.5pt solid #212529;">(0.3, 8.3)</td><td style="border-bottom: 0.5pt solid #212529;">4</td><td style="border-bottom: 0.5pt solid #212529;">Disease Control Rate</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Response per RECIST 1.1, investigator assessment.</p>
#> </div></div>

# ---- Example 3: Mixed-direction multi-key sort with hidden helper ----
#
# Demographics-style table sorted by `variable` ascending and a
# hidden numeric key descending. The `descending` argument takes
# one value per `by` entry so each key can flip direction
# independently. The helper column rides in `spec@data` for the
# sort but never renders (visible = FALSE on its col_spec).
demo <- saf_demo
demo$display_order <- match(demo$variable, unique(demo$variable))

tabular(demo, titles = "Demographics, ranked within section") |>
  cols(
    variable      = col_spec(usage = "group", label = "Characteristic"),
    stat_label    = col_spec(label = "Statistic"),
    display_order = col_spec(visible = FALSE),
    placebo       = col_spec(label = "Placebo",  align = "decimal"),
    drug_50       = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100      = col_spec(label = "Drug 100", align = "decimal"),
    Total         = col_spec(label = "Total",    align = "decimal")
  ) |>
  sort_rows(
    by         = c("display_order", "stat_label"),
    descending = c(FALSE, TRUE)
  )
#> <style>
#> #tabular-4c4a81cb87 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-4c4a81cb87 .tabular-content { width: 100%; }
#> #tabular-4c4a81cb87 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-4c4a81cb87 .tabular-pad { margin: 0; }
#> #tabular-4c4a81cb87 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-4c4a81cb87 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-4c4a81cb87 .tabular-table th, #tabular-4c4a81cb87 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-4c4a81cb87 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-4c4a81cb87 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-4c4a81cb87 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-4c4a81cb87 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-4c4a81cb87 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-4c4a81cb87 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-4c4a81cb87 .tabular-table tbody tr td { border-top: none; }
#> #tabular-4c4a81cb87 .tabular-band { text-align: center; }
#> #tabular-4c4a81cb87 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-4c4a81cb87 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-4c4a81cb87 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-4c4a81cb87 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-4c4a81cb87 .text-left { text-align: left; }
#> #tabular-4c4a81cb87 .text-center { text-align: center; }
#> #tabular-4c4a81cb87 .text-right { text-align: right; }
#> #tabular-4c4a81cb87 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-4c4a81cb87 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-4c4a81cb87 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-4c4a81cb87 .valign-top { vertical-align: top; }
#> #tabular-4c4a81cb87 .valign-middle { vertical-align: middle; }
#> #tabular-4c4a81cb87 .valign-bottom { vertical-align: bottom; }
#> #tabular-4c4a81cb87 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-4c4a81cb87 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-4c4a81cb87 .tabular-page-break-row { display: none; }
#> #tabular-4c4a81cb87 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-4c4a81cb87 .tabular-page-header, #tabular-4c4a81cb87 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-4c4a81cb87 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-4c4a81cb87 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-4c4a81cb87 .tabular-page-header-left, #tabular-4c4a81cb87 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-4c4a81cb87 .tabular-page-header-center, #tabular-4c4a81cb87 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-4c4a81cb87 .tabular-page-header-right, #tabular-4c4a81cb87 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-4c4a81cb87 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-4c4a81cb87 .tabular-table tr { page-break-inside: avoid; } #tabular-4c4a81cb87 .tabular-page-header, #tabular-4c4a81cb87 .tabular-page-footer { display: none; } #tabular-4c4a81cb87 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-4c4a81cb87 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-4c4a81cb87 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-4c4a81cb87" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Demographics, ranked within section</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 100</th><th class="text-center">Drug 50</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age (years)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 69.2, 81.8  </td><td class="text-right"> 70.5, 79.0  </td><td class="text-right"> 71.0, 82.0  </td><td class="text-right"> 70.0, 81.0  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 52  , 89    </td><td class="text-right"> 56  , 88    </td><td class="text-right"> 51  , 88    </td><td class="text-right"> 51  , 89    </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 76.0        </td><td class="text-right"> 75.5        </td><td class="text-right"> 78.0        </td><td class="text-right"> 77.0        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 75.2 (8.59) </td><td class="text-right"> 73.8 (7.94) </td><td class="text-right"> 76.0 (8.11) </td><td class="text-right"> 75.1 (8.25) </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age Group, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">&gt;64</td><td class="text-right"> 72 (83.7)   </td><td class="text-right"> 61 (84.7)   </td><td class="text-right"> 88 (91.7)   </td><td class="text-right">221 (87.0)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">18-64</td><td class="text-right"> 14 (16.3)   </td><td class="text-right"> 11 (15.3)   </td><td class="text-right">  8 ( 8.3)   </td><td class="text-right"> 33 (13.0)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">M</td><td class="text-right"> 33 (38.4)   </td><td class="text-right"> 37 (51.4)   </td><td class="text-right"> 41 (42.7)   </td><td class="text-right">111 (43.7)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">F</td><td class="text-right"> 53 (61.6)   </td><td class="text-right"> 35 (48.6)   </td><td class="text-right"> 55 (57.3)   </td><td class="text-right">143 (56.3)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">WHITE</td><td class="text-right"> 78 (90.7)   </td><td class="text-right"> 62 (86.1)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">230 (90.6)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLACK OR AFRICAN AMERICAN</td><td class="text-right">  8 ( 9.3)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 23 ( 9.1)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ASIAN</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right">  0          </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  0          </td><td class="text-right">  1 ( 0.4)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Ethnicity, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT REPORTED</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT HISPANIC OR LATINO</td><td class="text-right"> 83 (96.5)   </td><td class="text-right"> 69 (95.8)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">242 (95.3)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HISPANIC OR LATINO</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  3 ( 4.2)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 12 ( 4.7)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Weight (kg)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 53.6, 74.2  </td><td class="text-right"> 56.9,  80.3 </td><td class="text-right"> 56.0,  78.2 </td><td class="text-right"> 55.3,  77.1 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 34  , 86    </td><td class="text-right"> 44  , 108   </td><td class="text-right"> 42  , 106   </td><td class="text-right"> 34  , 108   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 60.6        </td><td class="text-right"> 69.0        </td><td class="text-right"> 66.7        </td><td class="text-right"> 66.7        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 62.8 (12.77)</td><td class="text-right"> 69.5 (14.35)</td><td class="text-right"> 68.0 (14.50)</td><td class="text-right"> 66.6 (14.13)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Height (cm)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right">154.0, 171.1 </td><td class="text-right">157.5, 172.8 </td><td class="text-right">157.5, 170.2 </td><td class="text-right">156.2, 171.4 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right">137  , 185   </td><td class="text-right">146  , 190   </td><td class="text-right">136  , 196   </td><td class="text-right">136  , 196   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right">162.6        </td><td class="text-right">165.1        </td><td class="text-right">162.6        </td><td class="text-right">162.8        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right">162.6 (11.52)</td><td class="text-right">165.9 (10.28)</td><td class="text-right">163.7 (10.30)</td><td class="text-right">163.9 (10.76)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI (kg/m^2)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 21.2, 25.6  </td><td class="text-right"> 22.7, 27.6  </td><td class="text-right"> 22.3, 28.2  </td><td class="text-right"> 21.9, 27.3  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 15  , 33    </td><td class="text-right"> 14  , 35    </td><td class="text-right"> 15  , 40    </td><td class="text-right"> 14  , 40    </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 23.4        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.2        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 23.6 (3.67) </td><td class="text-right"> 25.2 (3.97) </td><td class="text-right"> 25.2 (4.40) </td><td class="text-right"> 24.7 (4.09) </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI Category, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Underweight (&lt;18.5)</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  4 ( 4.2)   </td><td class="text-right">  8 ( 3.1)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Overweight (25-29.9)</td><td class="text-right"> 20 (23.3)   </td><td class="text-right"> 23 (31.9)   </td><td class="text-right"> 32 (33.3)   </td><td class="text-right"> 75 (29.5)   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Obese (&gt;=30)</td><td class="text-right">  6 ( 7.0)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right"> 13 (13.5)   </td><td class="text-right"> 28 (11.0)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">Normal (18.5-24.9)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 57 (66.3)   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 39 (54.2)   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 46 (47.9)   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">142 (55.9)   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Hierarchical SOC -> PT sort with factor outer key ----
#
# A factor outer key locks the SOC display order to the canonical
# interleaved sequence (`overall` first, then `soc` blocks, then
# `pt` detail rows inside each SOC) regardless of input order. The
# numeric inner key sorts PTs within each SOC by descending total
# subject count.
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total  <- as.integer(sub(" .*", "", ae$Total))
tabular(ae, titles = "AE by SOC and PT, ranked within SOC") |>
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
  sort_rows(
    by         = c("row_type", "soc", "n_total"),
    descending = c(FALSE, FALSE, TRUE)
  )
#> <style>
#> #tabular-3411a3e203 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-3411a3e203 .tabular-content { width: 100%; }
#> #tabular-3411a3e203 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-3411a3e203 .tabular-pad { margin: 0; }
#> #tabular-3411a3e203 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-3411a3e203 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-3411a3e203 .tabular-table th, #tabular-3411a3e203 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-3411a3e203 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-3411a3e203 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-3411a3e203 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-3411a3e203 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-3411a3e203 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-3411a3e203 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-3411a3e203 .tabular-table tbody tr td { border-top: none; }
#> #tabular-3411a3e203 .tabular-band { text-align: center; }
#> #tabular-3411a3e203 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-3411a3e203 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-3411a3e203 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-3411a3e203 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-3411a3e203 .text-left { text-align: left; }
#> #tabular-3411a3e203 .text-center { text-align: center; }
#> #tabular-3411a3e203 .text-right { text-align: right; }
#> #tabular-3411a3e203 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-3411a3e203 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-3411a3e203 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-3411a3e203 .valign-top { vertical-align: top; }
#> #tabular-3411a3e203 .valign-middle { vertical-align: middle; }
#> #tabular-3411a3e203 .valign-bottom { vertical-align: bottom; }
#> #tabular-3411a3e203 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-3411a3e203 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-3411a3e203 .tabular-page-break-row { display: none; }
#> #tabular-3411a3e203 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-3411a3e203 .tabular-page-header, #tabular-3411a3e203 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-3411a3e203 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-3411a3e203 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-3411a3e203 .tabular-page-header-left, #tabular-3411a3e203 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-3411a3e203 .tabular-page-header-center, #tabular-3411a3e203 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-3411a3e203 .tabular-page-header-right, #tabular-3411a3e203 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-3411a3e203 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3411a3e203 .tabular-table tr { page-break-inside: avoid; } #tabular-3411a3e203 .tabular-page-header, #tabular-3411a3e203 .tabular-page-footer { display: none; } #tabular-3411a3e203 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3411a3e203 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3411a3e203 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-3411a3e203" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">AE by SOC and PT, ranked within SOC</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>SOC / PT</th><th>soc_n</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td class="text-right">52 (60.5)</td><td class="text-right">81 (84.4)</td><td class="text-right">66 (91.7)</td><td class="text-right">199 (78.3)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 33 (13.0)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 42 (16.5)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right"> 81 (31.9)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right"> 29 (11.4)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 41 (16.1)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 19 ( 7.5)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 22 ( 8.7)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right"> 90 (35.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BIOPSY</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">SKIN IRRITATION</td><td style="border-bottom: 0.5pt solid #212529;">90</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 3 ( 3.5)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 6 ( 6.2)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 5 ( 6.9)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 14 ( 5.5)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
