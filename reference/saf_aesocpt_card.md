# Cards hierarchical ARD for AEs by SOC and PT

Long-format companion to `saf_aesocpt`. Produced by
[`cards::ard_stack_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack_hierarchical.html)
over `(AEBODSYS, AEDECOD)` with adsl-level denominators, sorted by
descending overall incidence via
[`cards::sort_ard_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/sort_ard_hierarchical.html).
Limited to the same top-10 SOC, top-5 PT subset as `saf_aesocpt` so the
two datasets describe the same slice of the data.

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
[`cards::ard_stack_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack_hierarchical.html)
over
[`pharmaverseadam::adae`](https://pharmaverse.github.io/pharmaverseadam/reference/adae.html)
filtered to the top SOC / PT subset.

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
      sprintf("Safety Population (N=%d)", n["Total"])
    )
  )

#tabular-568bfaaa50 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-568bfaaa50 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-568bfaaa50 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-568bfaaa50 .tabular-pad { margin: 0; line-height: 1; }
#tabular-568bfaaa50 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-568bfaaa50 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-568bfaaa50 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-568bfaaa50 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-568bfaaa50 .tabular-table th, #tabular-568bfaaa50 .tabular-table td { padding: .35rem .6rem; }
#tabular-568bfaaa50 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-568bfaaa50 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-568bfaaa50 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-568bfaaa50 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-568bfaaa50 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-568bfaaa50 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-568bfaaa50 .tabular-table tbody tr td { border-top: none; }
#tabular-568bfaaa50 .tabular-band { text-align: center; }
#tabular-568bfaaa50 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-568bfaaa50 .tabular-subgroup-label { font-weight: 600; }
#tabular-568bfaaa50 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-568bfaaa50 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-568bfaaa50 .text-left { text-align: left; }
#tabular-568bfaaa50 .text-center { text-align: center; }
#tabular-568bfaaa50 .text-right { text-align: right; }
#tabular-568bfaaa50 .tabular-table thead th.text-left { text-align: left; }
#tabular-568bfaaa50 .tabular-table thead th.text-center { text-align: center; }
#tabular-568bfaaa50 .tabular-table thead th.text-right { text-align: right; }
#tabular-568bfaaa50 .valign-top { vertical-align: top; }
#tabular-568bfaaa50 .valign-middle { vertical-align: middle; }
#tabular-568bfaaa50 .valign-bottom { vertical-align: bottom; }
#tabular-568bfaaa50 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-568bfaaa50 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-568bfaaa50 .tabular-page-break-row { display: none; }
#tabular-568bfaaa50 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-568bfaaa50 .tabular-page-header, #tabular-568bfaaa50 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-568bfaaa50 .tabular-page-header { margin-bottom: 1rem; }
#tabular-568bfaaa50 .tabular-page-footer { margin-top: 1rem; }
#tabular-568bfaaa50 .tabular-page-header-left, #tabular-568bfaaa50 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-568bfaaa50 .tabular-page-header-center, #tabular-568bfaaa50 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-568bfaaa50 .tabular-page-header-right, #tabular-568bfaaa50 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-568bfaaa50 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-568bfaaa50 .tabular-table tr { page-break-inside: avoid; } #tabular-568bfaaa50 .tabular-page-header, #tabular-568bfaaa50 .tabular-page-footer { display: none; } #tabular-568bfaaa50 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-568bfaaa50 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-568bfaaa50 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Adverse Events by SOC and PT
Safety Population (N=254)
 



soc
```
