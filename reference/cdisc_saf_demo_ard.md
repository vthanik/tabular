# Cards ARD for demographics (flat ARD companion)

The same demographics summary as `cdisc_saf_demo`, but in the long
Analysis Results Data (ARD) format produced by `cards::ard_stack()`. One
row per (treatment arm, variable, statistic). Shipped as a teaching
dataset that shows the upstream shape users typically have when they
start from `cards`. Convert it to the wide form
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
accepts via
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
— tabular itself does **not** consume the long ARD format, since
pre-summarised wide data is the package boundary.

## Usage

``` r
cdisc_saf_demo_ard
```

## Format

A `card`-classed tibble with columns `group1`, `group1_level`,
`variable`, `variable_level`, `context`, `stat_name`, `stat_label`,
`stat`. `group1 == "TRT01A"` and `group1_level` carries the original
pharmaverseadam arm labels (`"Placebo"`, `"Xanomeline Low Dose"`,
`"Xanomeline High Dose"`). `cards::ard_stack(.overall = TRUE)` adds
overall rows with `group1_level = NA`;
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
renders those into a `Total` column.

## Source

Derived in `data-raw/bundle-demo.R` via
`cards::ard_stack(.by = "TRT01A", .overall = TRUE)` over
`pharmaverseadam::adsl`.

## Details

Continuous variables: `AGE`, `WEIGHT`, `HEIGHT`, `BMI` (each emitting
`N`, `mean`, `sd`, `median`, `p25`, `p75`, `min`, `max`). Categorical
variables: `AGEGR1`, `SEX`, `RACE`, `ETHNIC`, `BMI_CAT` (each emitting
`n`, `N`, `p`).

This is the package's canonical **flat ARD** demo. Its hierarchical
counterpart is
[cdisc_saf_aesocpt_ard](https://vthanik.github.io/tabular/reference/cdisc_saf_aesocpt_ard.md);
together they cover both shapes
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
must handle.

## See also

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
for the long-to-wide bridge;
[cdisc_saf_demo](https://vthanik.github.io/tabular/reference/cdisc_saf_demo.md)
for the wide companion.

## Examples

``` r
# 95% demographics pattern: cards ARD -> wide -> rendered table.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
cdisc_saf_demo_ard |>
  pivot_across(
    statistic = list(
      continuous  = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    ),
    label = c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
  ) |>
  tabular(
    titles = c(
      "Table 14.1.1",
      "Demographics",
      "Safety Population"
    )
  )

#tabular-d70f21365e { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-d70f21365e .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-d70f21365e p { line-height: inherit; }
#tabular-d70f21365e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-d70f21365e .tabular-caption { margin: 0; padding: 0; }
#tabular-d70f21365e .tabular-pad { margin: 0; line-height: 1; }
#tabular-d70f21365e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-d70f21365e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-d70f21365e .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-d70f21365e .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-d70f21365e .tabular-table th, #tabular-d70f21365e .tabular-table td { padding: .18rem .6rem; }
#tabular-d70f21365e .tabular-table td { text-align: left; vertical-align: top; }
#tabular-d70f21365e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-d70f21365e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-d70f21365e .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-d70f21365e .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-d70f21365e .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-d70f21365e .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-d70f21365e .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-d70f21365e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-d70f21365e .tabular-table tbody tr td { border-top: none; }
#tabular-d70f21365e .tabular-band { text-align: center; }
#tabular-d70f21365e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-d70f21365e .tabular-subgroup-label { font-weight: 600; }
#tabular-d70f21365e .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-d70f21365e .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-d70f21365e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-d70f21365e .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-d70f21365e .text-left { text-align: left; }
#tabular-d70f21365e .text-center { text-align: center; }
#tabular-d70f21365e .text-right { text-align: right; }
#tabular-d70f21365e .tabular-table thead th.text-left { text-align: left; }
#tabular-d70f21365e .tabular-table thead th.text-center { text-align: center; }
#tabular-d70f21365e .tabular-table thead th.text-right { text-align: right; }
#tabular-d70f21365e .tabular-table td.text-left { text-align: left; }
#tabular-d70f21365e .tabular-table td.text-center { text-align: center; }
#tabular-d70f21365e .tabular-table td.text-right { text-align: right; }
#tabular-d70f21365e .valign-top { vertical-align: top; }
#tabular-d70f21365e .valign-middle { vertical-align: middle; }
#tabular-d70f21365e .valign-bottom { vertical-align: bottom; }
#tabular-d70f21365e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-d70f21365e .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-d70f21365e .tabular-page-break-row { display: none; }
#tabular-d70f21365e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-d70f21365e .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-d70f21365e .tabular-page-header, #tabular-d70f21365e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-d70f21365e .tabular-page-header { margin-bottom: 1rem; }
#tabular-d70f21365e .tabular-page-footer { margin-top: 1rem; }
#tabular-d70f21365e .tabular-page-header-left, #tabular-d70f21365e .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-d70f21365e .tabular-page-header-center, #tabular-d70f21365e .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-d70f21365e .tabular-page-header-right, #tabular-d70f21365e .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-d70f21365e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-d70f21365e .tabular-table tr { page-break-inside: avoid; } #tabular-d70f21365e .tabular-page-header, #tabular-d70f21365e .tabular-page-footer { display: none; } #tabular-d70f21365e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-d70f21365e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-d70f21365e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics
Safety Population
 



variable
```
