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
#> <div id="tabular_nBty9ufgg5" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.0</h1>
#> <h1 class="tabular-title">Adverse Event Overview</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-center">Total<br/>N=254</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Drug 50<br/>N=96</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any TEAE</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">217 (85.4)</td><td class="text-right">65 (75.6)</td><td class="text-right">68 (94.4)</td><td class="text-right">84 (87.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any Serious AE (SAE)</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">  3 (1.2) </td><td class="text-right"> 0       </td><td class="text-right"> 1 (1.4) </td><td class="text-right"> 2 (2.1) </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Related to Study Drug</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">184 (72.4)</td><td class="text-right">43 (50.0)</td><td class="text-right">64 (88.9)</td><td class="text-right">77 (80.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Leading to Death</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">  3 (1.2) </td><td class="text-right"> 2 (2.3) </td><td class="text-right"> 0       </td><td class="text-right"> 1 (1.0) </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Recovered / Resolved</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">157 (61.8)</td><td class="text-right">47 (54.7)</td><td class="text-right">49 (68.1)</td><td class="text-right">61 (63.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Mild</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);"> 77 (30.3)</td><td class="text-right">36 (41.9)</td><td class="text-right">20 (27.8)</td><td class="text-right">21 (21.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Moderate</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">111 (43.7)</td><td class="text-right">24 (27.9)</td><td class="text-right">40 (55.6)</td><td class="text-right">47 (49.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Severe</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;"> 29 (11.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 5 (5.8) </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 8 (11.1)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
