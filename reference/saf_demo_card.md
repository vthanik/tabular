# Cards ARD for demographics (flat ARD companion)

The same demographics summary as `saf_demo`, but in the long Analysis
Results Data (ARD) format produced by
[`cards::ard_stack()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack.html).
One row per (treatment arm, variable, statistic). Shipped as a teaching
dataset that shows the upstream shape users typically have when they
start from `cards`. Convert it to the wide form
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
accepts via
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
— tabular itself does **not** consume the long ARD format, since
pre-summarised wide data is the package boundary.

## Usage

``` r
saf_demo_card
```

## Format

A `card`-classed tibble with columns `group1`, `group1_level`,
`variable`, `variable_level`, `context`, `stat_name`, `stat_label`,
`stat`. `group1 == "TRT01A"` and `group1_level` carries the original
pharmaverseadam arm labels (`"Placebo"`, `"Xanomeline Low Dose"`,
`"Xanomeline High Dose"`). `cards::ard_stack(.overall = TRUE)` adds
overall rows with `group1_level = NA`;
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
renders those into a `Total` column.

## Source

Derived in `data-raw/bundle-demo.R` via
`cards::ard_stack(.by = "TRT01A", .overall = TRUE)` over
[`pharmaverseadam::adsl`](https://pharmaverse.github.io/pharmaverseadam/reference/adsl.html).

## Details

Continuous variables: `AGE`, `WEIGHT`, `HEIGHT`, `BMI` (each emitting
`N`, `mean`, `sd`, `median`, `p25`, `p75`, `min`, `max`). Categorical
variables: `AGEGR1`, `SEX`, `RACE`, `ETHNIC`, `BMI_CAT` (each emitting
`n`, `N`, `p`).

This is the package's canonical **flat ARD** demo. Its hierarchical
counterpart is
[saf_aesocpt_card](https://vthanik.github.io/tabular/reference/saf_aesocpt_card.md);
together they cover both shapes
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
must handle.

## See also

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
for the long-to-wide bridge;
[saf_demo](https://vthanik.github.io/tabular/reference/saf_demo.md) for
the wide companion.

## Examples

``` r
# 95% demographics pattern: cards ARD -> wide -> rendered table.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
saf_demo_card |>
  pivot_across(
    statistic = list(
      continuous  = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    ),
    label = c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
  ) |>
  tabular(
    titles = c(
      "Table 14.1.1",
      "Demographics",
      sprintf("Safety Population (N=%d)", n["Total"])
    )
  )
#> <style>
#> #tabular-e03c830a8e { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-e03c830a8e .tabular-content { width: 100%; }
#> #tabular-e03c830a8e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-e03c830a8e .tabular-pad { margin: 0; }
#> #tabular-e03c830a8e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-e03c830a8e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-e03c830a8e .tabular-table th, #tabular-e03c830a8e .tabular-table td { padding: .35rem .6rem; }
#> #tabular-e03c830a8e .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-e03c830a8e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-e03c830a8e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-e03c830a8e .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-e03c830a8e .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-e03c830a8e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-e03c830a8e .tabular-table tbody tr td { border-top: none; }
#> #tabular-e03c830a8e .tabular-band { text-align: center; }
#> #tabular-e03c830a8e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-e03c830a8e .tabular-subgroup-label { font-weight: 600; }
#> #tabular-e03c830a8e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-e03c830a8e .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-e03c830a8e .text-left { text-align: left; }
#> #tabular-e03c830a8e .text-center { text-align: center; }
#> #tabular-e03c830a8e .text-right { text-align: right; }
#> #tabular-e03c830a8e .tabular-table thead th.text-left { text-align: left; }
#> #tabular-e03c830a8e .tabular-table thead th.text-center { text-align: center; }
#> #tabular-e03c830a8e .tabular-table thead th.text-right { text-align: right; }
#> #tabular-e03c830a8e .valign-top { vertical-align: top; }
#> #tabular-e03c830a8e .valign-middle { vertical-align: middle; }
#> #tabular-e03c830a8e .valign-bottom { vertical-align: bottom; }
#> #tabular-e03c830a8e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-e03c830a8e .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-e03c830a8e .tabular-page-break-row { display: none; }
#> #tabular-e03c830a8e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-e03c830a8e .tabular-page-header, #tabular-e03c830a8e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-e03c830a8e .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-e03c830a8e .tabular-page-footer { margin-top: 1rem; }
#> #tabular-e03c830a8e .tabular-page-header-left, #tabular-e03c830a8e .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-e03c830a8e .tabular-page-header-center, #tabular-e03c830a8e .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-e03c830a8e .tabular-page-header-right, #tabular-e03c830a8e .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-e03c830a8e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-e03c830a8e .tabular-table tr { page-break-inside: avoid; } #tabular-e03c830a8e .tabular-page-header, #tabular-e03c830a8e .tabular-page-footer { display: none; } #tabular-e03c830a8e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-e03c830a8e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-e03c830a8e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-e03c830a8e" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
#> <h1 class="tabular-title">Demographics</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>variable</th><th>stat_label</th><th>Placebo</th><th>Xanomeline High Dose</th><th>Xanomeline Low Dose</th><th>Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Age (years)</td><td>AGE</td><td>75.2 (8.59)</td><td>73.8 (7.94)</td><td>76.0 (8.11)</td><td>75.1 (8.25)</td></tr>
#> <tr><td>WEIGHT</td><td>WEIGHT</td><td>62.8 (12.77)</td><td>69.5 (14.35)</td><td>68.0 (14.50)</td><td>66.6 (14.13)</td></tr>
#> <tr><td>HEIGHT</td><td>HEIGHT</td><td>162.6 (11.52)</td><td>165.9 (10.28)</td><td>163.7 (10.30)</td><td>163.9 (10.76)</td></tr>
#> <tr><td>BMI</td><td>BMI</td><td>23.6 (3.67)</td><td>25.2 (3.97)</td><td>25.2 (4.40)</td><td>24.7 (4.09)</td></tr>
#> <tr><td>AGEGR1</td><td>  18-64</td><td>14 (16%)</td><td>11 (15%)</td><td>8 (8%)</td><td>33 (13%)</td></tr>
#> <tr><td>AGEGR1</td><td>  &gt;64</td><td>72 (84%)</td><td>61 (85%)</td><td>88 (92%)</td><td>221 (87%)</td></tr>
#> <tr><td>Sex</td><td>  F</td><td>53 (62%)</td><td>35 (49%)</td><td>55 (57%)</td><td>143 (56%)</td></tr>
#> <tr><td>Sex</td><td>  M</td><td>33 (38%)</td><td>37 (51%)</td><td>41 (43%)</td><td>111 (44%)</td></tr>
#> <tr><td>Race</td><td>  WHITE</td><td>78 (91%)</td><td>62 (86%)</td><td>90 (94%)</td><td>230 (91%)</td></tr>
#> <tr><td>Race</td><td>  BLACK OR AFRICAN AMERICAN</td><td>8 (9%)</td><td>9 (12%)</td><td>6 (6%)</td><td>23 (9%)</td></tr>
#> <tr><td>Race</td><td>  ASIAN</td><td>0</td><td>0</td><td>0</td><td>0</td></tr>
#> <tr><td>Race</td><td>  AMERICAN INDIAN OR ALASKA NATIVE</td><td>0</td><td>1 (1%)</td><td>0</td><td>1 (0%)</td></tr>
#> <tr><td>ETHNIC</td><td>  HISPANIC OR LATINO</td><td>3 (3%)</td><td>3 (4%)</td><td>6 (6%)</td><td>12 (5%)</td></tr>
#> <tr><td>ETHNIC</td><td>  NOT HISPANIC OR LATINO</td><td>83 (97%)</td><td>69 (96%)</td><td>90 (94%)</td><td>242 (95%)</td></tr>
#> <tr><td>ETHNIC</td><td>  NOT REPORTED</td><td>0</td><td>0</td><td>0</td><td>0</td></tr>
#> <tr><td>BMI_CAT</td><td>  Underweight (&lt;18.5)</td><td>3 (3%)</td><td>1 (1%)</td><td>4 (4%)</td><td>8 (3%)</td></tr>
#> <tr><td>BMI_CAT</td><td>  Normal (18.5-24.9)</td><td>57 (66%)</td><td>39 (54%)</td><td>46 (48%)</td><td>142 (56%)</td></tr>
#> <tr><td>BMI_CAT</td><td>  Overweight (25-29.9)</td><td>20 (23%)</td><td>23 (32%)</td><td>32 (34%)</td><td>75 (30%)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">BMI_CAT</td><td style="border-bottom: 0.5pt solid #212529;">  Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7%)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12%)</td><td style="border-bottom: 0.5pt solid #212529;">13 (14%)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11%)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
