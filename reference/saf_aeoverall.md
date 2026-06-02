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
    sprintf("Safety Population (N=%d)", n["Total"])
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

#tabular-0029d18151 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-0029d18151 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-0029d18151 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-0029d18151 .tabular-pad { margin: 0; line-height: 1; }
#tabular-0029d18151 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-0029d18151 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-0029d18151 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-0029d18151 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-0029d18151 .tabular-table th, #tabular-0029d18151 .tabular-table td { padding: .35rem .6rem; }
#tabular-0029d18151 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-0029d18151 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-0029d18151 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-0029d18151 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-0029d18151 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-0029d18151 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-0029d18151 .tabular-table tbody tr td { border-top: none; }
#tabular-0029d18151 .tabular-band { text-align: center; }
#tabular-0029d18151 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-0029d18151 .tabular-subgroup-label { font-weight: 600; }
#tabular-0029d18151 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-0029d18151 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-0029d18151 .text-left { text-align: left; }
#tabular-0029d18151 .text-center { text-align: center; }
#tabular-0029d18151 .text-right { text-align: right; }
#tabular-0029d18151 .tabular-table thead th.text-left { text-align: left; }
#tabular-0029d18151 .tabular-table thead th.text-center { text-align: center; }
#tabular-0029d18151 .tabular-table thead th.text-right { text-align: right; }
#tabular-0029d18151 .valign-top { vertical-align: top; }
#tabular-0029d18151 .valign-middle { vertical-align: middle; }
#tabular-0029d18151 .valign-bottom { vertical-align: bottom; }
#tabular-0029d18151 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-0029d18151 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-0029d18151 .tabular-page-break-row { display: none; }
#tabular-0029d18151 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-0029d18151 .tabular-page-header, #tabular-0029d18151 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-0029d18151 .tabular-page-header { margin-bottom: 1rem; }
#tabular-0029d18151 .tabular-page-footer { margin-top: 1rem; }
#tabular-0029d18151 .tabular-page-header-left, #tabular-0029d18151 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-0029d18151 .tabular-page-header-center, #tabular-0029d18151 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-0029d18151 .tabular-page-header-right, #tabular-0029d18151 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-0029d18151 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-0029d18151 .tabular-table tr { page-break-inside: avoid; } #tabular-0029d18151 .tabular-page-header, #tabular-0029d18151 .tabular-page-footer { display: none; } #tabular-0029d18151 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-0029d18151 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-0029d18151 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.0
Adverse Event Overview
Safety Population (N=254)
 



Total
N=254
```
