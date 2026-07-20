# Best Overall Response and Response Rates

Pre-summarised efficacy table. Per-arm counts of best overall response
(BOR) per CDISC category, plus derived ORR, CBR, and DCR rate rows each
followed by an exact (Clopper-Pearson) 95% CI row. Four sections (Best
Overall Response, Objective Response Rate, Clinical Benefit Rate,
Disease Control Rate) are encoded via the `groupid` + `group_label` pair
so a single `group_rows(by = "group_label")` synthesises one bold
section band per groupid block; the body rows render below each band,
auto-indented one level by the `"section"` display itself (the stub
needs no `indent` — the section supplies it).

## Usage

``` r
cdisc_eff_resp
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
  Drives the engine's
  [`group_rows()`](https://vthanik.github.io/tabular/reference/group_rows.md)
  section-header synthesis.

## Source

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::adrs_onco`
filtered to `PARAMCD == "BOR"`.

## See also

[cdisc_eff_n](https://vthanik.github.io/tabular/reference/cdisc_eff_n.md)
for BigN denominators.

## Examples

``` r
# 95% efficacy pattern: four bold section bands (Best Overall
# Response / Objective Response Rate / Clinical Benefit Rate /
# Disease Control Rate), each followed by indented stat rows. The
# source already ships in the right display order, so no sort step
# is needed; `group_label` repeats across every row of its section
# so the engine's `section` mode emits exactly one band per
# section.
ne <- stats::setNames(cdisc_eff_n$n, cdisc_eff_n$arm_short)
tabular(
  cdisc_eff_resp,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    "Efficacy Evaluable Population"
  )
) |>
  cols(
    stat_label  = col_spec(label = "Response"),
    groupid     = col_spec(visible = FALSE),
    row_type    = col_spec(visible = FALSE),
    placebo     = col_spec(
      label = "Placebo\nN={ne['placebo']}",
      align = "decimal"
    ),
    drug_50     = col_spec(
      label = "Drug 50\nN={ne['drug_50']}",
      align = "decimal"
    ),
    drug_100    = col_spec(
      label = "Drug 100\nN={ne['drug_100']}",
      align = "decimal"
    )
  ) |>
  group_rows(by = "group_label")

#tabular-8024c4df67 { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-8024c4df67 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-8024c4df67 p { line-height: inherit; }
#tabular-8024c4df67 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-8024c4df67 .tabular-caption { margin: 0; padding: 0; }
#tabular-8024c4df67 .tabular-pad { margin: 0; line-height: 1; }
#tabular-8024c4df67 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-8024c4df67 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-8024c4df67 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-8024c4df67 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-8024c4df67 .tabular-table th, #tabular-8024c4df67 .tabular-table td { padding: .18rem .6rem; }
#tabular-8024c4df67 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-8024c4df67 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-8024c4df67 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-8024c4df67 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-8024c4df67 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-8024c4df67 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-8024c4df67 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-8024c4df67 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-8024c4df67 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-8024c4df67 .tabular-table tbody tr td { border-top: none; }
#tabular-8024c4df67 .tabular-band { text-align: center; }
#tabular-8024c4df67 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-8024c4df67 .tabular-subgroup-label { font-weight: 600; }
#tabular-8024c4df67 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-8024c4df67 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-8024c4df67 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-8024c4df67 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-8024c4df67 .text-left { text-align: left; }
#tabular-8024c4df67 .text-center { text-align: center; }
#tabular-8024c4df67 .text-right { text-align: right; }
#tabular-8024c4df67 .tabular-table thead th.text-left { text-align: left; }
#tabular-8024c4df67 .tabular-table thead th.text-center { text-align: center; }
#tabular-8024c4df67 .tabular-table thead th.text-right { text-align: right; }
#tabular-8024c4df67 .tabular-table td.text-left { text-align: left; }
#tabular-8024c4df67 .tabular-table td.text-center { text-align: center; }
#tabular-8024c4df67 .tabular-table td.text-right { text-align: right; }
#tabular-8024c4df67 .valign-top { vertical-align: top; }
#tabular-8024c4df67 .valign-middle { vertical-align: middle; }
#tabular-8024c4df67 .valign-bottom { vertical-align: bottom; }
#tabular-8024c4df67 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-8024c4df67 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-8024c4df67 .tabular-page-break-row { display: none; }
#tabular-8024c4df67 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-8024c4df67 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-8024c4df67 .tabular-page-header, #tabular-8024c4df67 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-8024c4df67 .tabular-page-header { margin-bottom: 1rem; }
#tabular-8024c4df67 .tabular-page-footer { margin-top: 1rem; }
#tabular-8024c4df67 .tabular-page-header-left, #tabular-8024c4df67 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-8024c4df67 .tabular-page-header-center, #tabular-8024c4df67 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-8024c4df67 .tabular-page-header-right, #tabular-8024c4df67 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-8024c4df67 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-8024c4df67 .tabular-table tr { page-break-inside: avoid; } #tabular-8024c4df67 .tabular-page-header, #tabular-8024c4df67 .tabular-page-footer { display: none; } #tabular-8024c4df67 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-8024c4df67 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-8024c4df67 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.2.1
Best Overall Response and Response Rates
Efficacy Evaluable Population
 



Response
```
