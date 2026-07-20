# Demographics summary, Safety Population

Pre-summarised wide-format demographics suitable for direct passing into
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).
One row per displayed statistic. Three parameter blocks — a deliberately
minimal set covering both summary shapes:

## Usage

``` r
cdisc_saf_demo
```

## Format

A data frame with 11 rows and 6 columns:

- `variable`:

  Display-block label (`"Age (years)"`, `"Sex, n (%)"`,
  `"Race, n (%)"`). Driven by
  [`group_rows()`](https://vthanik.github.io/tabular/reference/group_rows.md)
  to collapse repeat values at render.

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

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::adsl`
filtered to `SAFFL == "Y"` and the three CDISCPILOT01 treatment arms.

## Details

- continuous: `Age (years)` — emitted as `n`, `Mean (SD)`, `Median`,
  `Q1, Q3`, `Min, Max`

- categorical: `Sex`, `Race` — each level rendered as `n (%)`

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
    variable   = col_spec(label = "Parameter"),
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

#tabular-c73e2cc0e2 { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-c73e2cc0e2 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-c73e2cc0e2 p { line-height: inherit; }
#tabular-c73e2cc0e2 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-c73e2cc0e2 .tabular-caption { margin: 0; padding: 0; }
#tabular-c73e2cc0e2 .tabular-pad { margin: 0; line-height: 1; }
#tabular-c73e2cc0e2 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-c73e2cc0e2 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-c73e2cc0e2 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-c73e2cc0e2 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-c73e2cc0e2 .tabular-table th, #tabular-c73e2cc0e2 .tabular-table td { padding: .18rem .6rem; }
#tabular-c73e2cc0e2 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-c73e2cc0e2 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-c73e2cc0e2 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-c73e2cc0e2 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-c73e2cc0e2 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-c73e2cc0e2 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-c73e2cc0e2 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-c73e2cc0e2 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-c73e2cc0e2 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-c73e2cc0e2 .tabular-table tbody tr td { border-top: none; }
#tabular-c73e2cc0e2 .tabular-band { text-align: center; }
#tabular-c73e2cc0e2 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-c73e2cc0e2 .tabular-subgroup-label { font-weight: 600; }
#tabular-c73e2cc0e2 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-c73e2cc0e2 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-c73e2cc0e2 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-c73e2cc0e2 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-c73e2cc0e2 .text-left { text-align: left; }
#tabular-c73e2cc0e2 .text-center { text-align: center; }
#tabular-c73e2cc0e2 .text-right { text-align: right; }
#tabular-c73e2cc0e2 .tabular-table thead th.text-left { text-align: left; }
#tabular-c73e2cc0e2 .tabular-table thead th.text-center { text-align: center; }
#tabular-c73e2cc0e2 .tabular-table thead th.text-right { text-align: right; }
#tabular-c73e2cc0e2 .tabular-table td.text-left { text-align: left; }
#tabular-c73e2cc0e2 .tabular-table td.text-center { text-align: center; }
#tabular-c73e2cc0e2 .tabular-table td.text-right { text-align: right; }
#tabular-c73e2cc0e2 .valign-top { vertical-align: top; }
#tabular-c73e2cc0e2 .valign-middle { vertical-align: middle; }
#tabular-c73e2cc0e2 .valign-bottom { vertical-align: bottom; }
#tabular-c73e2cc0e2 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-c73e2cc0e2 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-c73e2cc0e2 .tabular-page-break-row { display: none; }
#tabular-c73e2cc0e2 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-c73e2cc0e2 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-c73e2cc0e2 .tabular-page-header, #tabular-c73e2cc0e2 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-c73e2cc0e2 .tabular-page-header { margin-bottom: 1rem; }
#tabular-c73e2cc0e2 .tabular-page-footer { margin-top: 1rem; }
#tabular-c73e2cc0e2 .tabular-page-header-left, #tabular-c73e2cc0e2 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-c73e2cc0e2 .tabular-page-header-center, #tabular-c73e2cc0e2 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-c73e2cc0e2 .tabular-page-header-right, #tabular-c73e2cc0e2 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-c73e2cc0e2 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-c73e2cc0e2 .tabular-table tr { page-break-inside: avoid; } #tabular-c73e2cc0e2 .tabular-page-header, #tabular-c73e2cc0e2 .tabular-page-footer { display: none; } #tabular-c73e2cc0e2 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-c73e2cc0e2 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-c73e2cc0e2 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Parameter
```
