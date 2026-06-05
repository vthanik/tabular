# Cards ARD for demographics (flat ARD companion)

The same demographics summary as `saf_demo`, but in the long Analysis
Results Data (ARD) format produced by `cards::ard_stack()`. One row per
(treatment arm, variable, statistic). Shipped as a teaching dataset that
shows the upstream shape users typically have when they start from
`cards`. Convert it to the wide form
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
accepts via
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
— tabular itself does **not** consume the long ARD format, since
pre-summarised wide data is the package boundary.

## Usage

``` r
saf_demo_card
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
[saf_aesocpt_card](https://vthanik.github.io/tabular/reference/saf_aesocpt_card.md);
together they cover both shapes
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
must handle.

## See also

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
for the long-to-wide bridge;
[saf_demo](https://vthanik.github.io/tabular/reference/saf_demo.md) for
the wide companion.

## Examples

``` r
# 95% demographics pattern: cards ARD -> wide -> rendered table.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
saf_demo_card |>
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

#tabular-fa605876dd { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-fa605876dd .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-fa605876dd p { line-height: inherit; }
#tabular-fa605876dd .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-fa605876dd .tabular-caption { margin: 0; padding: 0; }
#tabular-fa605876dd .tabular-pad { margin: 0; line-height: 1; }
#tabular-fa605876dd .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-fa605876dd .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-fa605876dd .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-fa605876dd .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-fa605876dd .tabular-table th, #tabular-fa605876dd .tabular-table td { padding: .18rem .6rem; }
#tabular-fa605876dd .tabular-table td { text-align: left; vertical-align: top; }
#tabular-fa605876dd .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-fa605876dd .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-fa605876dd .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-fa605876dd .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-fa605876dd .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-fa605876dd .tabular-table tbody tr td { border-top: none; }
#tabular-fa605876dd .tabular-band { text-align: center; }
#tabular-fa605876dd .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-fa605876dd .tabular-subgroup-label { font-weight: 600; }
#tabular-fa605876dd .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-fa605876dd .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-fa605876dd .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-fa605876dd .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-fa605876dd .text-left { text-align: left; }
#tabular-fa605876dd .text-center { text-align: center; }
#tabular-fa605876dd .text-right { text-align: right; }
#tabular-fa605876dd .tabular-table thead th.text-left { text-align: left; }
#tabular-fa605876dd .tabular-table thead th.text-center { text-align: center; }
#tabular-fa605876dd .tabular-table thead th.text-right { text-align: right; }
#tabular-fa605876dd .valign-top { vertical-align: top; }
#tabular-fa605876dd .valign-middle { vertical-align: middle; }
#tabular-fa605876dd .valign-bottom { vertical-align: bottom; }
#tabular-fa605876dd .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-fa605876dd .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-fa605876dd .tabular-page-break-row { display: none; }
#tabular-fa605876dd { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-fa605876dd .tabular-page-header, #tabular-fa605876dd .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-fa605876dd .tabular-page-header { margin-bottom: 1rem; }
#tabular-fa605876dd .tabular-page-footer { margin-top: 1rem; }
#tabular-fa605876dd .tabular-page-header-left, #tabular-fa605876dd .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-fa605876dd .tabular-page-header-center, #tabular-fa605876dd .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-fa605876dd .tabular-page-header-right, #tabular-fa605876dd .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-fa605876dd .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-fa605876dd .tabular-table tr { page-break-inside: avoid; } #tabular-fa605876dd .tabular-page-header, #tabular-fa605876dd .tabular-page-footer { display: none; } #tabular-fa605876dd .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-fa605876dd .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-fa605876dd .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics
Safety Population
 



variable
```
