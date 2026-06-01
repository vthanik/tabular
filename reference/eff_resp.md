# Best Overall Response and Response Rates

Pre-summarised efficacy table. Per-arm counts of best overall response
(BOR) per CDISC category, plus derived ORR, CBR, and DCR rate rows each
followed by an exact (Clopper-Pearson) 95% CI row. Four sections (Best
Overall Response, Objective Response Rate, Clinical Benefit Rate,
Disease Control Rate) are encoded via the `groupid` + `group_label` pair
so a single `usage = "group"` / `group_display = "header_row"` on
`group_label` synthesises one bold section band per groupid block; the
body rows render below each band via `usage = "indent"` on `stat_label`.

## Usage

``` r
eff_resp
```

## Format

A data frame with 13 rows and 7 columns:

- `stat_label`:

  Row label (`"CR"`, `"PR"`, `"SD"`, `"NON-CR/NON-PD"`, `"PD"`, `"NE"`,
  `"MISSING"`, `"ORR (CR + PR)"`, `"95% CI (Clopper-Pearson)"`,
  `"CBR (CR + PR + SD)"`, `"95% CI (Clopper-Pearson)"`,
  `"DCR (CR + PR + SD + NON-CR/NON-PD)"`, `"95% CI (Clopper-Pearson)"`).

- `row_type`:

  `"category"` for BOR categorical rows, `"derived"` for ORR / CBR / DCR
  rate rows, `"ci"` for the paired confidence-interval rows. Hide via
  `col_spec(visible = FALSE)`.

- `placebo`, `drug_50`, `drug_100`:

  Per-arm cell text (`"n (pct)"` on rate rows, `"(lower, upper)"` on CI
  rows).

- `groupid`:

  Integer section id (1 = Best Overall Response, 2 = Objective Response
  Rate, 3 = Clinical Benefit Rate, 4 = Disease Control Rate). Hide via
  `col_spec(visible = FALSE)`; used as the section sort / partition key.

- `group_label`:

  Character section label, repeating across every row of its groupid
  block ("Best Overall Response" x7, "Objective Response Rate" x2, ...).
  Drives the engine's `usage = "group"` header_row synthesis when paired
  with `group_display = "header_row"`.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adrs_onco`](https://pharmaverse.github.io/pharmaverseadam/reference/adrs_onco.html)
filtered to `PARAMCD == "BOR"`.

## See also

[eff_n](https://vthanik.github.io/tabular/reference/eff_n.md) for BigN
denominators.

## Examples

``` r
# 95% efficacy pattern: four bold section bands (Best Overall
# Response / Objective Response Rate / Clinical Benefit Rate /
# Disease Control Rate), each followed by indented stat rows. The
# source already ships in the right display order, so no sort step
# is needed; `group_label` repeats across every row of its section
# so the engine's `header_row` mode emits exactly one band per
# section.
ne <- stats::setNames(eff_n$n, eff_n$arm_short)
tabular(
  eff_resp,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  )
) |>
  cols(
    group_label = col_spec(usage = "group", group_display = "header_row"),
    stat_label  = col_spec(usage = "indent", label = "Response"),
    groupid     = col_spec(visible = FALSE),
    row_type    = col_spec(visible = FALSE),
    placebo     = col_spec(
      label = sprintf("Placebo\nN=%d", ne["placebo"]),
      align = "decimal"
    ),
    drug_50     = col_spec(
      label = sprintf("Drug 50\nN=%d", ne["drug_50"]),
      align = "decimal"
    ),
    drug_100    = col_spec(
      label = sprintf("Drug 100\nN=%d", ne["drug_100"]),
      align = "decimal"
    )
  )
#> <style>
#> #tabular-6989842371 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-6989842371 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-6989842371 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-6989842371 .tabular-pad { margin: 0; }
#> #tabular-6989842371 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-6989842371 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-6989842371 .tabular-table th, #tabular-6989842371 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-6989842371 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-6989842371 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-6989842371 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-6989842371 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-6989842371 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-6989842371 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-6989842371 .tabular-table tbody tr td { border-top: none; }
#> #tabular-6989842371 .tabular-band { text-align: center; }
#> #tabular-6989842371 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-6989842371 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-6989842371 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-6989842371 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-6989842371 .text-left { text-align: left; }
#> #tabular-6989842371 .text-center { text-align: center; }
#> #tabular-6989842371 .text-right { text-align: right; }
#> #tabular-6989842371 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-6989842371 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-6989842371 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-6989842371 .valign-top { vertical-align: top; }
#> #tabular-6989842371 .valign-middle { vertical-align: middle; }
#> #tabular-6989842371 .valign-bottom { vertical-align: bottom; }
#> #tabular-6989842371 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-6989842371 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-6989842371 .tabular-page-break-row { display: none; }
#> #tabular-6989842371 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-6989842371 .tabular-page-header, #tabular-6989842371 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-6989842371 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-6989842371 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-6989842371 .tabular-page-header-left, #tabular-6989842371 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-6989842371 .tabular-page-header-center, #tabular-6989842371 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-6989842371 .tabular-page-header-right, #tabular-6989842371 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-6989842371 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-6989842371 .tabular-table tr { page-break-inside: avoid; } #tabular-6989842371 .tabular-page-header, #tabular-6989842371 .tabular-page-footer { display: none; } #tabular-6989842371 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-6989842371 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-6989842371 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-6989842371" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>Response</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=84</th><th class="text-center">Drug 100<br/>N=84</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Best Overall Response</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">CR</td><td class="text-right"> 1 ( 1.2)  </td><td class="text-right"> 1 ( 1.2)  </td><td class="text-right"> 1 ( 1.2)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">PR</td><td class="text-right"> 1 ( 1.2)  </td><td class="text-right"> 0         </td><td class="text-right"> 0         </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">SD</td><td class="text-right"> 1 ( 1.2)  </td><td class="text-right"> 0         </td><td class="text-right"> 0         </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">NON-CR/NON-PD</td><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td class="text-right"> 1 ( 1.2)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">PD</td><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td class="text-right"> 1 ( 1.2)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">NE</td><td class="text-right"> 0         </td><td class="text-right"> 1 ( 1.2)  </td><td class="text-right"> 0         </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">MISSING</td><td class="text-right">83 (96.5)  </td><td class="text-right">82 (97.6)  </td><td class="text-right">81 (96.4)  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Objective Response Rate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">ORR (CR + PR)</td><td class="text-right"> 2   (2.3) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 1   (1.2) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">95% CI (Clopper-Pearson)</td><td class="text-right">( 0.3, 8.1)</td><td class="text-right">( 0.0, 6.5)</td><td class="text-right">( 0.0, 6.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Clinical Benefit Rate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">CBR (CR + PR + SD)</td><td class="text-right"> 3   (3.5) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 1   (1.2) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">95% CI (Clopper-Pearson)</td><td class="text-right">( 0.7, 9.9)</td><td class="text-right">( 0.0, 6.5)</td><td class="text-right">( 0.0, 6.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Disease Control Rate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em);">DCR (CR + PR + SD + NON-CR/NON-PD)</td><td class="text-right"> 3   (3.5) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 2   (2.4) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 2.4em); border-bottom: 0.5pt solid #212529;">95% CI (Clopper-Pearson)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.7, 9.9)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.0, 6.5)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.3, 8.3)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
