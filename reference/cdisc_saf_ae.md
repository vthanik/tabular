# Overall adverse-event summary, Safety Population

Pre-summarised wide-format AE overview. Two clinical blocks: high-level
flag rows (any TEAE, any SAE, any treatment-related, any AE leading to
death, any AE recovered / resolved) and maximum-severity rows (mild /
moderate / severe). Severity rows are indented with two leading spaces
in the data, so a plain `cols(stat_label = col_spec())` renders a flat
overview with the severity rows nested under the flags, one row per
category.

## Usage

``` r
cdisc_saf_ae
```

## Format

A data frame with 8 rows and 5 columns:

- `stat_label`:

  Row label (`"Any TEAE"`, `"Any Serious AE (SAE)"`,
  `"Any AE Related to Study Drug"`, `"Any AE Leading to Death"`,
  `"Any AE Recovered / Resolved"`, `" Maximum severity: Mild"`,
  `" Maximum severity: Moderate"`, `" Maximum severity: Severe"`).

- `placebo`:

  Placebo arm cell text (`"n (pct)"`).

- `drug_50`:

  Drug 50 arm cell text.

- `drug_100`:

  Drug 100 arm cell text.

- `Total`:

  Pooled-across-arms cell text.

## Source

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::adae`
filtered to `SAFFL == "Y"` and `TRTEMFL == "Y"`.

## See also

[cdisc_saf_n](https://vthanik.github.io/tabular/reference/cdisc_saf_n.md)
for BigN denominators;
[cdisc_saf_aesocpt](https://vthanik.github.io/tabular/reference/cdisc_saf_aesocpt.md)
for the SOC / PT detail companion.

## Examples

``` r
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(
  cdisc_saf_ae,
  titles = c(
    "Table 14.3.0",
    "Adverse Event Overview",
    "Safety Population"
  )
) |>
  cols(
    stat_label = col_spec(label = ""),
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

#tabular-7813587a48 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-7813587a48 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-7813587a48 p { line-height: inherit; }
#tabular-7813587a48 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-7813587a48 .tabular-caption { margin: 0; padding: 0; }
#tabular-7813587a48 .tabular-pad { margin: 0; line-height: 1; }
#tabular-7813587a48 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-7813587a48 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-7813587a48 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-7813587a48 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-7813587a48 .tabular-table th, #tabular-7813587a48 .tabular-table td { padding: .18rem .6rem; }
#tabular-7813587a48 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-7813587a48 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-7813587a48 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-7813587a48 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-7813587a48 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7813587a48 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7813587a48 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7813587a48 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7813587a48 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-7813587a48 .tabular-table tbody tr td { border-top: none; }
#tabular-7813587a48 .tabular-band { text-align: center; }
#tabular-7813587a48 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-7813587a48 .tabular-subgroup-label { font-weight: 600; }
#tabular-7813587a48 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-7813587a48 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-7813587a48 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-7813587a48 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-7813587a48 .text-left { text-align: left; }
#tabular-7813587a48 .text-center { text-align: center; }
#tabular-7813587a48 .text-right { text-align: right; }
#tabular-7813587a48 .tabular-table thead th.text-left { text-align: left; }
#tabular-7813587a48 .tabular-table thead th.text-center { text-align: center; }
#tabular-7813587a48 .tabular-table thead th.text-right { text-align: right; }
#tabular-7813587a48 .tabular-table td.text-left { text-align: left; }
#tabular-7813587a48 .tabular-table td.text-center { text-align: center; }
#tabular-7813587a48 .tabular-table td.text-right { text-align: right; }
#tabular-7813587a48 .valign-top { vertical-align: top; }
#tabular-7813587a48 .valign-middle { vertical-align: middle; }
#tabular-7813587a48 .valign-bottom { vertical-align: bottom; }
#tabular-7813587a48 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-7813587a48 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-7813587a48 .tabular-page-break-row { display: none; }
#tabular-7813587a48 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-7813587a48 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-7813587a48 .tabular-page-header, #tabular-7813587a48 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-7813587a48 .tabular-page-header { margin-bottom: 1rem; }
#tabular-7813587a48 .tabular-page-footer { margin-top: 1rem; }
#tabular-7813587a48 .tabular-page-header-left, #tabular-7813587a48 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-7813587a48 .tabular-page-header-center, #tabular-7813587a48 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-7813587a48 .tabular-page-header-right, #tabular-7813587a48 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-7813587a48 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-7813587a48 .tabular-table tr { page-break-inside: avoid; } #tabular-7813587a48 .tabular-page-header, #tabular-7813587a48 .tabular-page-footer { display: none; } #tabular-7813587a48 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-7813587a48 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-7813587a48 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.0
Adverse Event Overview
Safety Population
 


```
