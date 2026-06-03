# Overall adverse-event summary, Safety Population

Pre-summarised wide-format AE overview. Two clinical blocks: high-level
flag rows (any TEAE, any SAE, any treatment-related, any AE leading to
death, any AE recovered / resolved) and maximum-severity rows (mild /
moderate / severe). Severity rows are indented with two leading spaces
so a single `cols(stat_label = col_spec(usage = "group"))` declaration
drives both the block-header rows and the indented detail rows.

## Usage

``` r
saf_aeoverall
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

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adae`](https://pharmaverse.github.io/pharmaverseadam/reference/adae.html)
filtered to `SAFFL == "Y"` and `TRTEMFL == "Y"`.

## See also

[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for BigN
denominators;
[saf_aesocpt](https://vthanik.github.io/tabular/reference/saf_aesocpt.md)
for the SOC / PT detail companion.

## Examples

``` r
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_aeoverall,
  titles = c(
    "Table 14.3.0",
    "Adverse Event Overview",
    "Safety Population"
  )
) |>
  cols(
    stat_label = col_spec(usage = "group", label = ""),
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
    ),
    Total      = col_spec(
      label = sprintf("Total\nN=%d", n["Total"]),
      align = "decimal"
    )
  )

#tabular-9f626035cf { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-9f626035cf .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-9f626035cf p { line-height: inherit; }
#tabular-9f626035cf .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-9f626035cf .tabular-caption { margin: 0; padding: 0; }
#tabular-9f626035cf .tabular-pad { margin: 0; line-height: 1; }
#tabular-9f626035cf .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-9f626035cf .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-9f626035cf .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-9f626035cf .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-9f626035cf .tabular-table th, #tabular-9f626035cf .tabular-table td { padding: .18rem .6rem; }
#tabular-9f626035cf .tabular-table td { text-align: left; vertical-align: top; }
#tabular-9f626035cf .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-9f626035cf .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-9f626035cf .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-9f626035cf .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-9f626035cf .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-9f626035cf .tabular-table tbody tr td { border-top: none; }
#tabular-9f626035cf .tabular-band { text-align: center; }
#tabular-9f626035cf .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-9f626035cf .tabular-subgroup-label { font-weight: 600; }
#tabular-9f626035cf .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-9f626035cf .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-9f626035cf .text-left { text-align: left; }
#tabular-9f626035cf .text-center { text-align: center; }
#tabular-9f626035cf .text-right { text-align: right; }
#tabular-9f626035cf .tabular-table thead th.text-left { text-align: left; }
#tabular-9f626035cf .tabular-table thead th.text-center { text-align: center; }
#tabular-9f626035cf .tabular-table thead th.text-right { text-align: right; }
#tabular-9f626035cf .valign-top { vertical-align: top; }
#tabular-9f626035cf .valign-middle { vertical-align: middle; }
#tabular-9f626035cf .valign-bottom { vertical-align: bottom; }
#tabular-9f626035cf .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-9f626035cf .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-9f626035cf .tabular-page-break-row { display: none; }
#tabular-9f626035cf { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-9f626035cf .tabular-page-header, #tabular-9f626035cf .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-9f626035cf .tabular-page-header { margin-bottom: 1rem; }
#tabular-9f626035cf .tabular-page-footer { margin-top: 1rem; }
#tabular-9f626035cf .tabular-page-header-left, #tabular-9f626035cf .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-9f626035cf .tabular-page-header-center, #tabular-9f626035cf .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-9f626035cf .tabular-page-header-right, #tabular-9f626035cf .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-9f626035cf .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-9f626035cf .tabular-table tr { page-break-inside: avoid; } #tabular-9f626035cf .tabular-page-header, #tabular-9f626035cf .tabular-page-footer { display: none; } #tabular-9f626035cf .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-9f626035cf .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-9f626035cf .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.0
Adverse Event Overview
Safety Population
 



Total
N=254
```
