# Adverse events by System Organ Class and Preferred Term

Pre-summarised AE-by-SOC/PT table. Interleaved row order: overall "any
TEAE" row first, then per-SOC blocks where each SOC row is followed by
its preferred-term detail rows. Top 10 SOCs and top 5 PTs per SOC are
kept; `row_type` marks the role of each row and `indent_level` carries
the canonical depth (0 for overall and SOC, 1 for PT) so the downstream
pipeline drives the SOC -\> PT indent via
`col_spec(indent_by = "indent_level")` without reconstructing it in
every script. The richer SOC × PT slice exercises
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
and the engine's horizontal-panel splitter end-to-end on a realistic
submission shell.

## Usage

``` r
saf_aesocpt
```

## Format

A data frame with 61 rows and 10 columns:

- `soc`:

  System Organ Class label. Repeats across the SOC's PT rows; hide via
  `col_spec(visible = FALSE)` once `label` carries the same SOC text on
  SOC rows.

- `label`:

  The row's display label. Equal to `soc` on the overall and SOC-summary
  rows; equal to the preferred-term name on PT detail rows. Promoted to
  the primary display column — pair with `indent_by = "indent_level"` to
  drive the SOC -\> PT indent.

- `row_type`:

  One of `"overall"`, `"soc"`, `"pt"`. Partition marker; hide via
  `col_spec(visible = FALSE)`.

- `indent_level`:

  Integer depth (0 on overall and SOC rows, 1 on PT rows). Consumed by
  `col_spec(indent_by = "indent_level")` on the `label` column; the
  engine auto-hides this column at resolve time.

- `n_total`:

  Integer. The row's own subject count — overall TEAE count on the
  overall row, the SOC's count on each SOC row, the PT's count on each
  PT row. Inner sort key.

- `soc_n`:

  Integer. The parent SOC's count, broadcast to every row in that SOC's
  cluster (SOC row + its PT children) so a descending sort on `soc_n`
  keeps PTs grouped under their parent. On the overall row, equal to the
  overall TEAE count. Outer sort key.

- `placebo`:

  Placebo arm cell text (`"n (pct)"`).

- `drug_50`, `drug_100`:

  Drug arms cell text.

- `Total`:

  Pooled-across-arms cell text.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adae`](https://pharmaverse.github.io/pharmaverseadam/reference/adae.html).
Filtered to the top 10 SOCs by total incidence and the top 5 PTs per
SOC. Body rows are pre-sorted with the cards-style two-level rule
(`arrange(desc(soc_n), soc, desc(n_total))`) so the canonical render
order is already baked in; the render-time
`sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))`
reproduces it via stable sort.

## See also

[saf_aesocpt_card](https://vthanik.github.io/tabular/reference/saf_aesocpt_card.md)
for the hierarchical long ARD;
[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for BigN
denominators.

## Examples

``` r
# 95% safety pattern: SOC/PT table where `label` carries SOC text
# on SOC rows and PT text on PT rows, indented by `indent_level`.
# `soc` / `row_type` / `n_total` / `soc_n` ride along as hidden
# partition + sort keys. `sort_rows(soc_n, n_total)` clusters PTs
# under their parent SOC and orders both levels by descending count.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  )
) |>
  cols(
    label    = col_spec(
      label = "SOC / PT",
      indent_by = "indent_level",
      align = "left"
    ),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    placebo  = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal"
    ),
    drug_50  = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal"
    ),
    drug_100 = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal"
    ),
    Total    = col_spec(
      label = sprintf("Total\nN=%d", n["Total"]),
      align = "decimal"
    )
  ) |>
  sort_rows(
    by = c("soc_n", "n_total"),
    descending = c(TRUE, TRUE)
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
#> <div id="tabular_felhkFpkHj" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by SOC and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-left">SOC / PT</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td class="text-left">TOTAL SUBJECTS WITH AN EVENT</td><td class="text-right">52 (60.5)</td><td class="text-right">81 (84.4)</td><td class="text-right">66 (91.7)</td><td class="text-right">199 (78.3)</td></tr>
#> <tr><td class="text-left">SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right"> 90 (35.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">RASH</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left">GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right"> 81 (31.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left">GASTROINTESTINAL DISORDERS</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 42 (16.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left">NERVOUS SYSTEM DISORDERS</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 41 (16.1)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left">CARDIAC DISORDERS</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 33 (13.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left">INFECTIONS AND INFESTATIONS</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right"> 29 (11.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left">RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 22 ( 8.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left">PSYCHIATRIC DISORDERS</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 19 ( 7.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left">MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td class="text-left">INVESTIGATIONS</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
