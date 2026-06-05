# Cards hierarchical ARD for AEs by SOC and PT

Long-format companion to `saf_aesocpt`. Produced by
`cards::ard_stack_hierarchical()` over `(AEBODSYS, AEDECOD)` with
adsl-level denominators, sorted by descending overall incidence via
`cards::sort_ard_hierarchical()`. Limited to the same top-10 SOC, top-5
PT subset as `saf_aesocpt` so the two datasets describe the same slice
of the data.

## Usage

``` r
saf_aesocpt_card
```

## Format

A `card`-classed tibble. Carries an `..ard_hierarchical_overall..`
sentinel row that
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
passes through as the table's "overall" row.

## Source

Derived in `data-raw/bundle-demo.R` via
`cards::ard_stack_hierarchical()` over `pharmaverseadam::adae` filtered
to the top SOC / PT subset.

## Details

This is the package's canonical **hierarchical ARD** demo (two grouping
variables nested SOC -\> PT). Its flat counterpart is
[saf_demo_card](https://vthanik.github.io/tabular/reference/saf_demo_card.md);
together they cover both shapes
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
must handle.

## See also

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
for the long-to-wide bridge;
[saf_aesocpt](https://vthanik.github.io/tabular/reference/saf_aesocpt.md)
for the wide companion.

## Examples

``` r
# Hierarchical ARD pivot. pivot_across() recognises the
# ard_stack_hierarchical shape and emits soc / label / row_type.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
saf_aesocpt_card |>
  pivot_across(statistic = "{n} ({p}%)") |>
  tabular(
    titles = c(
      "Table 14.3.1",
      "Adverse Events by SOC and PT",
      "Safety Population"
    )
  ) |>
  cols(
    label    = col_spec(label = "SOC / PT", align = "left"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    `Placebo`              = col_spec(align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(align = "decimal"),
    `Xanomeline High Dose` = col_spec(align = "decimal")
  )

#tabular-3c65061517 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-3c65061517 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-3c65061517 p { line-height: inherit; }
#tabular-3c65061517 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-3c65061517 .tabular-caption { margin: 0; padding: 0; }
#tabular-3c65061517 .tabular-pad { margin: 0; line-height: 1; }
#tabular-3c65061517 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-3c65061517 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-3c65061517 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-3c65061517 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-3c65061517 .tabular-table th, #tabular-3c65061517 .tabular-table td { padding: .18rem .6rem; }
#tabular-3c65061517 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-3c65061517 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-3c65061517 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-3c65061517 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-3c65061517 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-3c65061517 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-3c65061517 .tabular-table tbody tr td { border-top: none; }
#tabular-3c65061517 .tabular-band { text-align: center; }
#tabular-3c65061517 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-3c65061517 .tabular-subgroup-label { font-weight: 600; }
#tabular-3c65061517 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-3c65061517 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-3c65061517 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-3c65061517 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-3c65061517 .text-left { text-align: left; }
#tabular-3c65061517 .text-center { text-align: center; }
#tabular-3c65061517 .text-right { text-align: right; }
#tabular-3c65061517 .tabular-table thead th.text-left { text-align: left; }
#tabular-3c65061517 .tabular-table thead th.text-center { text-align: center; }
#tabular-3c65061517 .tabular-table thead th.text-right { text-align: right; }
#tabular-3c65061517 .valign-top { vertical-align: top; }
#tabular-3c65061517 .valign-middle { vertical-align: middle; }
#tabular-3c65061517 .valign-bottom { vertical-align: bottom; }
#tabular-3c65061517 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-3c65061517 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-3c65061517 .tabular-page-break-row { display: none; }
#tabular-3c65061517 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-3c65061517 .tabular-page-header, #tabular-3c65061517 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-3c65061517 .tabular-page-header { margin-bottom: 1rem; }
#tabular-3c65061517 .tabular-page-footer { margin-top: 1rem; }
#tabular-3c65061517 .tabular-page-header-left, #tabular-3c65061517 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-3c65061517 .tabular-page-header-center, #tabular-3c65061517 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-3c65061517 .tabular-page-header-right, #tabular-3c65061517 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-3c65061517 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3c65061517 .tabular-table tr { page-break-inside: avoid; } #tabular-3c65061517 .tabular-page-header, #tabular-3c65061517 .tabular-page-footer { display: none; } #tabular-3c65061517 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3c65061517 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3c65061517 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by SOC and PT
Safety Population
 



SOC / PT
```
