# Vital-signs subgroup summary by Sex, by Visit

Pre-summarised vital-signs stats partitioned by sex (`F` / `M`) across
four visits (`Baseline`, `Week 8`, `Week 16`, `End of Treatment`). Two
parameters (Systolic BP, Diastolic BP) emit four statistic rows each
(`n`, `Mean (SD)`, `Median`, `Min, Max`). A partition-constant `sex_n`
BigN column rides alongside so banners can inline the denominator via
`subgroup(label = "Sex: {sex} (N = {sex_n})")` without reaching for a
separate lookup.

## Usage

``` r
cdisc_saf_subgroup
```

## Format

A data frame with 64 rows and 10 columns:

- `sex`:

  Factor (`F` / `M`).

- `sex_n`:

  Integer BigN — number of subjects in the partition row's sex
  (partition-constant; rides into the banner via `{sex_n}` template
  tokens).

- `paramcd`:

  CDISC parameter code (`SYSBP` / `DIABP`).

- `param`:

  Decoded parameter name (`"Systolic BP (mmHg)"`,
  `"Diastolic BP (mmHg)"`).

- `visit`:

  Analysis visit (`Baseline`, `Week 8`, `Week 16`, `End of Treatment`).

- `stat_label`:

  Statistic label (`n`, `Mean (SD)`, `Median`, `Min, Max`).

- `placebo`, `drug_50`, `drug_100`, `Total`:

  Per-arm cell text.

## Source

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::advs`
filtered to `SAFFL == "Y"`, the three CDISCPILOT01 arms, the `SYSBP` /
`DIABP` parameters, and the four scheduled visits.

## Details

Designed for
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
and
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
examples: partition by sex (one page set per sex) and nest parameter
then visit inside each page for the canonical by-visit CSR shape, or
cross sex with visit for a multi-variable partition.

## See also

[cdisc_saf_n](https://vthanik.github.io/tabular/reference/cdisc_saf_n.md)
for BigN denominators;
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
for the verb this dataset is designed for.

## Examples

``` r
# 95% pattern: subgroup partition by sex with inline BigN, parameter
# nesting visit inside each sex page. `sex` and `sex_n` auto-hide
# from the body: `sex` because it is the partition `by` column;
# `sex_n` because the banner template references it. No explicit
# `col_spec(visible = FALSE)` needed.
tabular(cdisc_saf_subgroup, titles = "Vital Signs by Visit") |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    visit      = col_spec(usage = "group", label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")

#tabular-73386d1217 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-73386d1217 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-73386d1217 p { line-height: inherit; }
#tabular-73386d1217 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-73386d1217 .tabular-caption { margin: 0; padding: 0; }
#tabular-73386d1217 .tabular-pad { margin: 0; line-height: 1; }
#tabular-73386d1217 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-73386d1217 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-73386d1217 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-73386d1217 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-73386d1217 .tabular-table th, #tabular-73386d1217 .tabular-table td { padding: .18rem .6rem; }
#tabular-73386d1217 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-73386d1217 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-73386d1217 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-73386d1217 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-73386d1217 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-73386d1217 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-73386d1217 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-73386d1217 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-73386d1217 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-73386d1217 .tabular-table tbody tr td { border-top: none; }
#tabular-73386d1217 .tabular-band { text-align: center; }
#tabular-73386d1217 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-73386d1217 .tabular-subgroup-label { font-weight: 600; }
#tabular-73386d1217 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-73386d1217 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-73386d1217 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-73386d1217 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-73386d1217 .text-left { text-align: left; }
#tabular-73386d1217 .text-center { text-align: center; }
#tabular-73386d1217 .text-right { text-align: right; }
#tabular-73386d1217 .tabular-table thead th.text-left { text-align: left; }
#tabular-73386d1217 .tabular-table thead th.text-center { text-align: center; }
#tabular-73386d1217 .tabular-table thead th.text-right { text-align: right; }
#tabular-73386d1217 .valign-top { vertical-align: top; }
#tabular-73386d1217 .valign-middle { vertical-align: middle; }
#tabular-73386d1217 .valign-bottom { vertical-align: bottom; }
#tabular-73386d1217 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-73386d1217 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-73386d1217 .tabular-page-break-row { display: none; }
#tabular-73386d1217 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-73386d1217 .tabular-page-header, #tabular-73386d1217 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-73386d1217 .tabular-page-header { margin-bottom: 1rem; }
#tabular-73386d1217 .tabular-page-footer { margin-top: 1rem; }
#tabular-73386d1217 .tabular-page-header-left, #tabular-73386d1217 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-73386d1217 .tabular-page-header-center, #tabular-73386d1217 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-73386d1217 .tabular-page-header-right, #tabular-73386d1217 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-73386d1217 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-73386d1217 .tabular-table tr { page-break-inside: avoid; } #tabular-73386d1217 .tabular-page-header, #tabular-73386d1217 .tabular-page-footer { display: none; } #tabular-73386d1217 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-73386d1217 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-73386d1217 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Vital Signs by Visit
 



Statistic
```
