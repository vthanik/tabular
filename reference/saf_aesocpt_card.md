# Cards hierarchical ARD for AEs by SOC and PT

Long-format companion to `saf_aesocpt`. Produced by
[`cards::ard_stack_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack_hierarchical.html)
over `(AEBODSYS, AEDECOD)` with adsl-level denominators, sorted by
descending overall incidence via
[`cards::sort_ard_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/sort_ard_hierarchical.html).
Limited to the same top-10 SOC, top-5 PT subset as `saf_aesocpt` so the
two datasets describe the same slice of the data.

## Usage

``` r
saf_aesocpt_card
```

## Format

A `card`-classed tibble. Carries an `..ard_hierarchical_overall..`
sentinel row that
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
passes through as the table's "overall" row.

## Source

Derived in `data-raw/bundle-demo.R` via
[`cards::ard_stack_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack_hierarchical.html)
over
[`pharmaverseadam::adae`](https://pharmaverse.github.io/pharmaverseadam/reference/adae.html)
filtered to the top SOC / PT subset.

## Details

This is the package's canonical **hierarchical ARD** demo (two grouping
variables nested SOC -\> PT). Its flat counterpart is
[saf_demo_card](https://vthanik.github.io/tabular/reference/saf_demo_card.md);
together they cover both shapes
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
must handle.

## See also

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
for the long-to-wide bridge;
[saf_aesocpt](https://vthanik.github.io/tabular/reference/saf_aesocpt.md)
for the wide companion.

## Examples

``` r
# Hierarchical ARD pivot. pivot_across() recognises the
# ard_stack_hierarchical shape and emits soc / label / row_type.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
saf_aesocpt_card |>
  pivot_across(statistic = "{n} ({p}%)") |>
  tabular(
    titles = c(
      "Table 14.3.1",
      "Adverse Events by SOC and PT",
      sprintf("Safety Population (N=%d)", n["Total"])
    )
  )
#> <style>
#> #tabular-58c91c0259 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-58c91c0259 .tabular-content { width: 100%; }
#> #tabular-58c91c0259 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-58c91c0259 .tabular-pad { margin: 0; }
#> #tabular-58c91c0259 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-58c91c0259 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-58c91c0259 .tabular-table th, #tabular-58c91c0259 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-58c91c0259 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-58c91c0259 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-58c91c0259 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-58c91c0259 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-58c91c0259 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-58c91c0259 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-58c91c0259 .tabular-table tbody tr td { border-top: none; }
#> #tabular-58c91c0259 .tabular-band { text-align: center; }
#> #tabular-58c91c0259 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-58c91c0259 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-58c91c0259 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-58c91c0259 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-58c91c0259 .text-left { text-align: left; }
#> #tabular-58c91c0259 .text-center { text-align: center; }
#> #tabular-58c91c0259 .text-right { text-align: right; }
#> #tabular-58c91c0259 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-58c91c0259 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-58c91c0259 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-58c91c0259 .valign-top { vertical-align: top; }
#> #tabular-58c91c0259 .valign-middle { vertical-align: middle; }
#> #tabular-58c91c0259 .valign-bottom { vertical-align: bottom; }
#> #tabular-58c91c0259 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-58c91c0259 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-58c91c0259 .tabular-page-break-row { display: none; }
#> #tabular-58c91c0259 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-58c91c0259 .tabular-page-header, #tabular-58c91c0259 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-58c91c0259 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-58c91c0259 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-58c91c0259 .tabular-page-header-left, #tabular-58c91c0259 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-58c91c0259 .tabular-page-header-center, #tabular-58c91c0259 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-58c91c0259 .tabular-page-header-right, #tabular-58c91c0259 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-58c91c0259 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-58c91c0259 .tabular-table tr { page-break-inside: avoid; } #tabular-58c91c0259 .tabular-page-header, #tabular-58c91c0259 .tabular-page-footer { display: none; } #tabular-58c91c0259 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-58c91c0259 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-58c91c0259 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-58c91c0259" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by SOC and PT</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>soc</th><th>label</th><th>row_type</th><th>Placebo</th><th>Xanomeline High Dose</th><th>Xanomeline Low Dose</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>..ard_hierarchical_overall..</td><td>..ard_hierarchical_overall..</td><td>overall</td><td>52 (60%)</td><td>66 (92%)</td><td>81 (84%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>soc</td><td>19 (22%)</td><td>35 (49%)</td><td>36 (38%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>PRURITUS</td><td>pt</td><td>8 (9%)</td><td>25 (35%)</td><td>21 (22%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>ERYTHEMA</td><td>pt</td><td>8 (9%)</td><td>14 (19%)</td><td>14 (15%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>RASH</td><td>pt</td><td>5 (6%)</td><td>8 (11%)</td><td>13 (14%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>HYPERHIDROSIS</td><td>pt</td><td>2 (2%)</td><td>8 (11%)</td><td>4 (4%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>SKIN IRRITATION</td><td>pt</td><td>3 (3%)</td><td>5 (7%)</td><td>6 (6%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>soc</td><td>15 (17%)</td><td>30 (42%)</td><td>36 (38%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>APPLICATION SITE PRURITUS</td><td>pt</td><td>6 (7%)</td><td>21 (29%)</td><td>23 (24%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>APPLICATION SITE ERYTHEMA</td><td>pt</td><td>3 (3%)</td><td>14 (19%)</td><td>13 (14%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>APPLICATION SITE DERMATITIS</td><td>pt</td><td>5 (6%)</td><td>7 (10%)</td><td>9 (9%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>APPLICATION SITE IRRITATION</td><td>pt</td><td>3 (3%)</td><td>9 (12%)</td><td>9 (9%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>APPLICATION SITE VESICLES</td><td>pt</td><td>1 (1%)</td><td>5 (7%)</td><td>5 (5%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>GASTROINTESTINAL DISORDERS</td><td>soc</td><td>13 (15%)</td><td>17 (24%)</td><td>12 (12%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>DIARRHOEA</td><td>pt</td><td>9 (10%)</td><td>3 (4%)</td><td>5 (5%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>VOMITING</td><td>pt</td><td>3 (3%)</td><td>6 (8%)</td><td>4 (4%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>NAUSEA</td><td>pt</td><td>3 (3%)</td><td>6 (8%)</td><td>3 (3%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>ABDOMINAL PAIN</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>3 (3%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>SALIVARY HYPERSECRETION</td><td>pt</td><td>0</td><td>4 (6%)</td><td>0</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>NERVOUS SYSTEM DISORDERS</td><td>soc</td><td>6 (7%)</td><td>17 (24%)</td><td>18 (19%)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>DIZZINESS</td><td>pt</td><td>2 (2%)</td><td>10 (14%)</td><td>9 (9%)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>HEADACHE</td><td>pt</td><td>3 (3%)</td><td>5 (7%)</td><td>3 (3%)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>SYNCOPE</td><td>pt</td><td>0</td><td>2 (3%)</td><td>5 (5%)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>SOMNOLENCE</td><td>pt</td><td>2 (2%)</td><td>1 (1%)</td><td>3 (3%)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>TRANSIENT ISCHAEMIC ATTACK</td><td>pt</td><td>0</td><td>1 (1%)</td><td>2 (2%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>CARDIAC DISORDERS</td><td>soc</td><td>7 (8%)</td><td>14 (19%)</td><td>12 (12%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>SINUS BRADYCARDIA</td><td>pt</td><td>2 (2%)</td><td>8 (11%)</td><td>7 (7%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>MYOCARDIAL INFARCTION</td><td>pt</td><td>4 (5%)</td><td>4 (6%)</td><td>2 (2%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>ATRIAL FIBRILLATION</td><td>pt</td><td>1 (1%)</td><td>2 (3%)</td><td>2 (2%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>SUPRAVENTRICULAR EXTRASYSTOLES</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>VENTRICULAR EXTRASYSTOLES</td><td>pt</td><td>0</td><td>1 (1%)</td><td>2 (2%)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>INFECTIONS AND INFESTATIONS</td><td>soc</td><td>12 (14%)</td><td>11 (15%)</td><td>6 (6%)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>NASOPHARYNGITIS</td><td>pt</td><td>2 (2%)</td><td>6 (8%)</td><td>4 (4%)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>UPPER RESPIRATORY TRACT INFECTION</td><td>pt</td><td>6 (7%)</td><td>3 (4%)</td><td>1 (1%)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>INFLUENZA</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>URINARY TRACT INFECTION</td><td>pt</td><td>2 (2%)</td><td>1 (1%)</td><td>0</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>CYSTITIS</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>0</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>soc</td><td>5 (6%)</td><td>9 (12%)</td><td>8 (8%)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>COUGH</td><td>pt</td><td>1 (1%)</td><td>5 (7%)</td><td>5 (5%)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>NASAL CONGESTION</td><td>pt</td><td>3 (3%)</td><td>3 (4%)</td><td>1 (1%)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>DYSPNOEA</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>EPISTAXIS</td><td>pt</td><td>0</td><td>2 (3%)</td><td>1 (1%)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>PHARYNGOLARYNGEAL PAIN</td><td>pt</td><td>0</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>PSYCHIATRIC DISORDERS</td><td>soc</td><td>7 (8%)</td><td>3 (4%)</td><td>9 (9%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>CONFUSIONAL STATE</td><td>pt</td><td>2 (2%)</td><td>1 (1%)</td><td>3 (3%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>AGITATION</td><td>pt</td><td>2 (2%)</td><td>0</td><td>3 (3%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>INSOMNIA</td><td>pt</td><td>2 (2%)</td><td>2 (3%)</td><td>0</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>ANXIETY</td><td>pt</td><td>0</td><td>0</td><td>3 (3%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>DELUSION</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>0</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>soc</td><td>3 (3%)</td><td>5 (7%)</td><td>6 (6%)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>BACK PAIN</td><td>pt</td><td>1 (1%)</td><td>3 (4%)</td><td>1 (1%)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>ARTHRALGIA</td><td>pt</td><td>1 (1%)</td><td>1 (1%)</td><td>2 (2%)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>SHOULDER PAIN</td><td>pt</td><td>1 (1%)</td><td>0</td><td>2 (2%)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>MUSCLE SPASMS</td><td>pt</td><td>0</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>ARTHRITIS</td><td>pt</td><td>0</td><td>1 (1%)</td><td>0</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>INVESTIGATIONS</td><td>soc</td><td>5 (6%)</td><td>3 (4%)</td><td>4 (4%)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>pt</td><td>4 (5%)</td><td>0</td><td>1 (1%)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>ELECTROCARDIOGRAM T WAVE INVERSION</td><td>pt</td><td>2 (2%)</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>BLOOD GLUCOSE INCREASED</td><td>pt</td><td>0</td><td>1 (1%)</td><td>1 (1%)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>pt</td><td>1 (1%)</td><td>0</td><td>1 (1%)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">INVESTIGATIONS</td><td style="border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">pt</td><td style="border-bottom: 0.5pt solid #212529;">0</td><td style="border-bottom: 0.5pt solid #212529;">1 (1%)</td><td style="border-bottom: 0.5pt solid #212529;">0</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
