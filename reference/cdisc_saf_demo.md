# Demographics summary, Safety Population

Pre-summarised wide-format demographics suitable for direct passing into
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).
One row per displayed statistic. Eight parameter blocks:

## Usage

``` r
cdisc_saf_demo
```

## Format

A data frame with 35 rows and 6 columns:

- `variable`:

  Display-block label (`"Age (years)"`, `"Age Group, n (%)"`,
  `"Sex, n (%)"`, `"Race, n (%)"`, `"Ethnicity, n (%)"`). Driven by
  `cols(usage = "group")` to collapse repeat values at render.

- `stat_label`:

  Statistic or level label (`"n"`, `"Mean (SD)"`, `"Median"`, `"M"`,
  `"WHITE"`, ...).

- `placebo`:

  Placebo arm cell text.

- `drug_50`:

  Xanomeline Low Dose (50 mg) arm cell text.

- `drug_100`:

  Xanomeline High Dose (100 mg) arm cell text.

- `Total`:

  Pooled-across-arms cell text.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adsl`](https://pharmaverse.github.io/pharmaverseadam/reference/adsl.html)
filtered to `SAFFL == "Y"` and the three CDISCPILOT01 treatment arms.
Baseline Weight / Height / BMI are joined in from
[`pharmaverseadam::advs`](https://pharmaverse.github.io/pharmaverseadam/reference/advs.html).

## Details

- continuous: `Age (years)`, `Weight (kg)`, `Height (cm)`,
  `BMI (kg/m^2)` — each emitted as `n`, `Mean (SD)`, `Median`, `Q1, Q3`,
  `Min, Max`

- categorical: `Age Group`, `Sex`, `Race`, `Ethnicity`, `BMI Category` —
  each level rendered as `n (%)`

Shaped for the display-only contract: every cell is the final string
that will appear in the rendered table.

## See also

[cdisc_saf_demo_ard](https://vthanik.github.io/tabular/reference/cdisc_saf_demo_ard.md)
for the long-format ARD companion;
[cdisc_saf_n](https://vthanik.github.io/tabular/reference/cdisc_saf_n.md)
for the matching BigN denominators.

## Examples

``` r
# 95% safety pattern: demographics table with BigN-embedded
# column labels and CDISC-canonical statistic order.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  )
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(
      label = "Placebo\nN={n['placebo']}",
      align = "decimal"
    ),
    drug_50    = col_spec(
      label = "Drug 50\nN={n['drug_50']}",
      align = "decimal"
    ),
    drug_100   = col_spec(
      label = "Drug 100\nN={n['drug_100']}",
      align = "decimal"
    ),
    Total      = col_spec(
      label = "Total\nN={n['Total']}",
      align = "decimal"
    )
  )

#tabular-1d4d8de915 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-1d4d8de915 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-1d4d8de915 p { line-height: inherit; }
#tabular-1d4d8de915 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-1d4d8de915 .tabular-caption { margin: 0; padding: 0; }
#tabular-1d4d8de915 .tabular-pad { margin: 0; line-height: 1; }
#tabular-1d4d8de915 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-1d4d8de915 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-1d4d8de915 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-1d4d8de915 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-1d4d8de915 .tabular-table th, #tabular-1d4d8de915 .tabular-table td { padding: .18rem .6rem; }
#tabular-1d4d8de915 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-1d4d8de915 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-1d4d8de915 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-1d4d8de915 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-1d4d8de915 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-1d4d8de915 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-1d4d8de915 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-1d4d8de915 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-1d4d8de915 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-1d4d8de915 .tabular-table tbody tr td { border-top: none; }
#tabular-1d4d8de915 .tabular-band { text-align: center; }
#tabular-1d4d8de915 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-1d4d8de915 .tabular-subgroup-label { font-weight: 600; }
#tabular-1d4d8de915 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-1d4d8de915 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-1d4d8de915 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-1d4d8de915 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-1d4d8de915 .text-left { text-align: left; }
#tabular-1d4d8de915 .text-center { text-align: center; }
#tabular-1d4d8de915 .text-right { text-align: right; }
#tabular-1d4d8de915 .tabular-table thead th.text-left { text-align: left; }
#tabular-1d4d8de915 .tabular-table thead th.text-center { text-align: center; }
#tabular-1d4d8de915 .tabular-table thead th.text-right { text-align: right; }
#tabular-1d4d8de915 .valign-top { vertical-align: top; }
#tabular-1d4d8de915 .valign-middle { vertical-align: middle; }
#tabular-1d4d8de915 .valign-bottom { vertical-align: bottom; }
#tabular-1d4d8de915 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-1d4d8de915 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-1d4d8de915 .tabular-page-break-row { display: none; }
#tabular-1d4d8de915 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-1d4d8de915 .tabular-page-header, #tabular-1d4d8de915 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-1d4d8de915 .tabular-page-header { margin-bottom: 1rem; }
#tabular-1d4d8de915 .tabular-page-footer { margin-top: 1rem; }
#tabular-1d4d8de915 .tabular-page-header-left, #tabular-1d4d8de915 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-1d4d8de915 .tabular-page-header-center, #tabular-1d4d8de915 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-1d4d8de915 .tabular-page-header-right, #tabular-1d4d8de915 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-1d4d8de915 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-1d4d8de915 .tabular-table tr { page-break-inside: avoid; } #tabular-1d4d8de915 .tabular-page-header, #tabular-1d4d8de915 .tabular-page-footer { display: none; } #tabular-1d4d8de915 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-1d4d8de915 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-1d4d8de915 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Statistic
```
