# Vital-signs summary

Pre-summarised vital-signs stats. Four parameters (SYSBP, DIABP, PULSE,
TEMP) at four visits (Baseline, Week 8, Week 16, End of Treatment), each
producing four statistic rows (`n`, `Mean (SD)`, `Median`, `Min, Max`).
The 4 x 4 x 4 grid makes this dataset a natural fit for
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
examples — 64 rows comfortably exceed a single page under typical
clinical row-per-page settings.

## Usage

``` r
cdisc_saf_vital
```

## Format

A data frame with 64 rows and 7 columns:

- `paramcd`:

  CDISC parameter code (`SYSBP` / `DIABP` / `PULSE` / `TEMP`). Repeats
  across visit and statistic; use
  [`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)
  to collapse.

- `param`:

  Decoded parameter name.

- `visit`:

  Analysis visit label (`"Baseline"` / `"Week 8"` / `"Week 16"` /
  `"End of Treatment"`).

- `stat_label`:

  Statistic label.

- `placebo`, `drug_50`, `drug_100`:

  Per-arm cell text.

## Source

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::advs`.

## See also

[cdisc_saf_n](https://vthanik.github.io/tabular/dev/reference/cdisc_saf_n.md)
for BigN denominators.

## Examples

``` r
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(
  cdisc_saf_vital,
  titles = c(
    "Table 14.4.1",
    "Vital Signs Summary at Baseline and End of Treatment",
    "Safety Population"
  )
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(label = "Parameter"),
    visit      = col_spec(label = "Visit"),
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
    )
  )

#tabular-b13c054115 { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-b13c054115 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-b13c054115 p { line-height: inherit; }
#tabular-b13c054115 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-b13c054115 .tabular-caption { margin: 0; padding: 0; }
#tabular-b13c054115 .tabular-pad { margin: 0; line-height: 1; }
#tabular-b13c054115 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-b13c054115 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-b13c054115 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-b13c054115 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-b13c054115 .tabular-table th, #tabular-b13c054115 .tabular-table td { padding: .18rem .6rem; }
#tabular-b13c054115 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-b13c054115 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-b13c054115 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-b13c054115 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-b13c054115 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-b13c054115 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-b13c054115 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-b13c054115 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-b13c054115 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-b13c054115 .tabular-table tbody tr td { border-top: none; }
#tabular-b13c054115 .tabular-band { text-align: center; }
#tabular-b13c054115 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-b13c054115 .tabular-subgroup-label { font-weight: 600; }
#tabular-b13c054115 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-b13c054115 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-b13c054115 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-b13c054115 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-b13c054115 .text-left { text-align: left; }
#tabular-b13c054115 .text-center { text-align: center; }
#tabular-b13c054115 .text-right { text-align: right; }
#tabular-b13c054115 .tabular-table thead th.text-left { text-align: left; }
#tabular-b13c054115 .tabular-table thead th.text-center { text-align: center; }
#tabular-b13c054115 .tabular-table thead th.text-right { text-align: right; }
#tabular-b13c054115 .tabular-table td.text-left { text-align: left; }
#tabular-b13c054115 .tabular-table td.text-center { text-align: center; }
#tabular-b13c054115 .tabular-table td.text-right { text-align: right; }
#tabular-b13c054115 .valign-top { vertical-align: top; }
#tabular-b13c054115 .valign-middle { vertical-align: middle; }
#tabular-b13c054115 .valign-bottom { vertical-align: bottom; }
#tabular-b13c054115 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-b13c054115 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-b13c054115 .tabular-page-break-row { display: none; }
#tabular-b13c054115 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-b13c054115 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-b13c054115 .tabular-page-header, #tabular-b13c054115 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-b13c054115 .tabular-page-header { margin-bottom: 1rem; }
#tabular-b13c054115 .tabular-page-footer { margin-top: 1rem; }
#tabular-b13c054115 .tabular-page-header-left, #tabular-b13c054115 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-b13c054115 .tabular-page-header-center, #tabular-b13c054115 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-b13c054115 .tabular-page-header-right, #tabular-b13c054115 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-b13c054115 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-b13c054115 .tabular-table tr { page-break-inside: avoid; } #tabular-b13c054115 .tabular-page-header, #tabular-b13c054115 .tabular-page-footer { display: none; } #tabular-b13c054115 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-b13c054115 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-b13c054115 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.4.1
Vital Signs Summary at Baseline and End of Treatment
Safety Population
 



Parameter
```
