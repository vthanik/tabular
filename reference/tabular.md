# Start a tabular display

Wrap a pre-summarised data frame into a `tabular_spec` ready for the
verb chain. `tabular()` is the entry verb — it owns the `data`,
`titles`, and `footnotes` slots; every downstream verb
([`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md))
returns an updated spec for further chaining, terminating in
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (write
to file) or
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
(resolve without writing).

## Usage

``` r
tabular(data, titles = NULL, footnotes = NULL)
```

## Arguments

- data:

  *The display rows.* `<data.frame>: required`. Pre-summarised
  wide-format data; tibbles, data.tables, and arrow tables are coerced
  via [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).
  Factor columns are preserved (their levels drive
  [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)).

  **Restriction:** At least one column; column names must be unique.
  Zero rows is accepted (engine renders a "No data" stub).
  **Interaction:** The `cards`-format counterparts (`saf_demo_card`,
  `saf_aesocpt_card`) are NOT accepted directly; pipe through
  [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
  first.

- titles:

  *Page-title block, one element per row.*
  `<character> | NULL: default NULL`. Each element renders on its own
  centred line; embedded `\n` wraps within that row. The backend
  collapses unused rows so the column-header band sits flush against the
  lowest used title.

  **Restriction:** No NAs.

      # Canonical 3-line title block with BigN-qualified population.
      n <- stats::setNames(saf_n$n, saf_n$arm_short)
      titles = c(
        "Table 14.3.1",
        "Adverse Events by System Organ Class and Preferred Term",
        sprintf("Safety Population (N=%d)", n["Total"])
      )

- footnotes:

  *Page-footnote block, one element per row.*
  `<character> | NULL: default NULL`. User-supplied prose rows only; the
  backend appends its own program-path / program-name / timestamp band
  below them at render time.

  **Restriction:** No NAs.

      # Canonical 3-line footnote block.
      footnotes = c(
        "Subjects are counted once per SOC and once per PT.",
        "Percentages based on N per treatment group.",
        "TEAE = treatment-emergent adverse event."
      )

## Value

*A `tabular_spec` S7 object.* Pipe it into
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
and [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
to build the display, then into
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) to
render or
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) to
resolve without writing.

## Details

**Pre-summarised input contract.** `data` is one row per displayed row
of the final table. `tabular()` does not aggregate, filter, weight, or
generate subtotal rows — those happen upstream in `cards`, `dplyr`, or
SAS. If the upstream is a long
[`cards::ard_stack()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack.html)
ARD, pipe through
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
first to land in the wide shape `tabular()` accepts.

**Multi-line titles and footnotes by contract.** Clinical tables
routinely carry 2-4 title rows and 1-4 user footnote rows. Pass each row
as one element of the character vector; the backend renders each element
on its own line, collapsing unused rows so the column-header band sits
flush against the lowest used title.

## See also

**Downstream build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Terminal verbs:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (write),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
(resolve without I/O).

**Input helper:**
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
(cards ARD -\> wide).

**Demo data:** `saf_demo`, `saf_aesocpt`, `eff_resp`, `saf_n`, `eff_n`.

## Examples

``` r
# ---- Example 1: Adverse-event table by SOC and Preferred Term ----
#
# The regulatory work-horse layout: AE-by-SOC/PT with the
# canonical 3-line title block (table number, description,
# population qualifier with BigN drawn inline from `saf_n`) and a
# two-line footnote block explaining the denominator. The
# downstream pipeline hides the hierarchy markers (`row_type`,
# `n_total`) but keeps them in the data so `sort_rows()` can
# arrange SOCs and PTs in descending order of subject count.
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
  footnotes = c(
    "Subjects are counted once per SOC and once per PT.",
    "Percentages based on N per treatment group."
  )
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
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_KytsiP4a3p" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
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
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td>3 (3.5)</td><td>3 (3.1)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
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
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td>1 (1.2)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td>0 (0.0)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>1 (0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">1 (1.4)</td><td style="border-bottom: 0.5pt solid #212529;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects are counted once per SOC and once per PT.</p>
#> <p class="tabular-footnote">Percentages based on N per treatment group.</p>
#> </div></div>

# ---- Example 2: Best overall response with CDISC factor ordering ----
#
# Efficacy table where response categories must appear in CDISC
# clinical order (CR < PR < SD < NON-CR/NON-PD < PD < NE <
# MISSING < ORR < DCR), not alphabetical. Coerce `stat_label` to
# a factor with the canonical levels upstream and `sort_rows()`
# picks up the order for free.
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
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_vjfhceVyvC" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
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

# ---- Example 3: Minimal three-line BigN table from saf_n ----
#
# The smallest viable `tabular()` call: the bundled `saf_n` 4-row
# BigN table, a single-line title, no footnotes. The default
# `col_spec` per column kicks in, giving sensible labels (the
# data frame's column names) and left-aligned text. Useful when
# teaching the core API shape without the clinical-context
# surface noise.
tabular(saf_n, titles = "Safety-population BigN per arm")
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_zqTiZvfqQI" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Safety-population BigN per arm</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>arm</th><th>arm_short</th><th>n</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Placebo</td><td>placebo</td><td>86</td></tr>
#> <tr><td>Xanomeline Low Dose</td><td>drug_50</td><td>96</td></tr>
#> <tr><td>Xanomeline High Dose</td><td>drug_100</td><td>72</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Total</td><td style="border-bottom: 0.5pt solid #212529;">Total</td><td style="border-bottom: 0.5pt solid #212529;">254</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Vital-signs panel with hidden code column ----
#
# Show the canonical 4-visit-by-4-parameter vitals shape. The
# CDISC `paramcd` is kept in the data frame as the natural sort
# key but hidden at render via `col_spec(visible = FALSE)`, while
# `param` (the display label) drives the group block.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_vital,
  titles = c(
    "Table 14.4.1",
    "Summary of Vital Signs",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Statistics computed on observed cases."
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    visit      = col_spec(usage = "group", label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal"
    ),
    drug_50    = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal"
    ),
    drug_100   = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal"
    )
  )
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_kai6WDzHCS" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.4.1</h1>
#> <h1 class="tabular-title">Summary of Vital Signs</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Drug 100<br/>N=72</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 77.1 (10.7)</td><td class="text-right"> 76.6 (9.8) </td><td class="text-right"> 78.2 (10.3)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 77.7       </td><td class="text-right"> 76.7       </td><td class="text-right"> 78.8       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 40  , 110  </td><td class="text-right"> 48  , 108  </td><td class="text-right"> 51  , 108  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (9.1) </td><td class="text-right"> 75.4 (10.6)</td><td class="text-right"> 77.4 (9.1) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 78.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 101  </td><td class="text-right"> 52  , 100  </td><td class="text-right"> 54  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.1 (10.9)</td><td class="text-right"> 75.2 (10.0)</td><td class="text-right"> 76.0 (9.0) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 75.7       </td><td class="text-right"> 77.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 98   </td><td class="text-right"> 55  , 98   </td><td class="text-right"> 50  , 92   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.4 (10.7)</td><td class="text-right"> 76.0 (11.2)</td><td class="text-right"> 76.0 (9.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.5       </td><td class="text-right"> 76.0       </td><td class="text-right"> 78.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.5 (11.6)</td><td class="text-right"> 72.1 (10.8)</td><td class="text-right"> 72.4 (9.7) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.3       </td><td class="text-right"> 70.0       </td><td class="text-right"> 71.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 134  </td><td class="text-right"> 50  , 104  </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 71.8 (9.0) </td><td class="text-right"> 72.6 (11.1)</td><td class="text-right"> 74.0 (8.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 72.0       </td><td class="text-right"> 73.2       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 52  , 102  </td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 70.6 (8.8) </td><td class="text-right"> 68.8 (9.4) </td><td class="text-right"> 73.2 (9.5) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 70.2       </td><td class="text-right"> 68.0       </td><td class="text-right"> 72.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 90   </td><td class="text-right"> 48  , 104  </td><td class="text-right"> 51  , 96   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (11.5)</td><td class="text-right"> 74.1 (9.4) </td><td class="text-right"> 73.6 (9.6) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 74.0       </td><td class="text-right"> 75.0       </td><td class="text-right"> 73.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 106  </td><td class="text-right"> 50  , 94   </td><td class="text-right"> 50  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.8 (17.6)</td><td class="text-right">137.9 (18.5)</td><td class="text-right">137.8 (17.2)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.3       </td><td class="text-right">138.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 80  , 184  </td><td class="text-right">100  , 194  </td><td class="text-right">100  , 192  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.3 (17.0)</td><td class="text-right">134.9 (17.8)</td><td class="text-right">135.1 (15.5)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.5       </td><td class="text-right">132.3       </td><td class="text-right">134.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 90  , 189  </td><td class="text-right"> 92  , 200  </td><td class="text-right"> 91  , 198  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.6 (18.3)</td><td class="text-right">132.5 (14.3)</td><td class="text-right">133.7 (16.0)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">130.0       </td><td class="text-right">132.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 76  , 190  </td><td class="text-right">100  , 168  </td><td class="text-right"> 99  , 186  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">132.7 (15.4)</td><td class="text-right">133.0 (17.1)</td><td class="text-right">132.3 (15.6)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">130.0       </td><td class="text-right">131.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 78  , 172  </td><td class="text-right"> 92  , 178  </td><td class="text-right">100  , 177  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">172         </td><td class="text-right">190         </td><td class="text-right">144         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.5 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.6       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 35  , 37   </td><td class="text-right"> 35  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">146         </td><td class="text-right">118         </td><td class="text-right">112         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>n</td><td class="text-right">136         </td><td class="text-right"> 82         </td><td class="text-right"> 74         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.3) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 74         </td><td class="text-right"> 59         </td><td class="text-right"> 56         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.8       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 37   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 38   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 36  , 37   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Statistics computed on observed cases.</p>
#> </div></div>
```
