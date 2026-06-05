# Vital-signs subgroup summary by Sex and Age Group

Pre-summarised vital-signs stats partitioned by sex (`F` / `M`) and age
group (`<65` / `>=65`) at the End-of-Treatment visit. Two parameters
(Systolic BP, Diastolic BP) emit four statistic rows each (`n`,
`Mean (SD)`, `Median`, `Min, Max`). Partition-constant BigN columns
(`sex_n`, `agegr_n`) ride alongside so banners can inline the
denominator via `subgroup(label = "Sex: {sex} (N = {sex_n})")` without
reaching for a separate lookup.

## Usage

``` r
cdisc_saf_subgroup
```

## Format

A data frame with 32 rows and 11 columns:

- `sex`:

  Factor (`F` / `M`).

- `agegr`:

  Factor (`<65` / `>=65`).

- `sex_n`:

  Integer BigN — number of subjects in the partition row's sex
  (partition-constant; rides into the banner via `{sex_n}` template
  tokens).

- `agegr_n`:

  Integer BigN per age group.

- `paramcd`:

  CDISC parameter code (`SYSBP` / `DIABP`).

- `param`:

  Decoded parameter name (`"Systolic BP (mmHg)"`,
  `"Diastolic BP (mmHg)"`).

- `stat_label`:

  Statistic label (`n`, `Mean (SD)`, `Median`, `Min, Max`).

- `placebo`, `drug_50`, `drug_100`, `Total`:

  Per-arm cell text.

## Source

Derived in `data-raw/bundle-demo.R` from `pharmaverseadam::advs`
filtered to `SAFFL == "Y"`, the three CDISCPILOT01 arms, the `SYSBP` /
`DIABP` parameters, and the End-of-Treatment visit.

## Details

Designed for
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
and
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
examples: the two partition axes plus the partition-constant BigN
columns cover both single-variable cohort-style partitions and the
multi-variable (sex × agegr) crossing.

## See also

[cdisc_saf_n](https://vthanik.github.io/tabular/reference/cdisc_saf_n.md)
for BigN denominators;
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
for the verb this dataset is designed for.

## Examples

``` r
# 95% pattern: subgroup partition by sex with inline BigN.
# `sex` and `sex_n` auto-hide from the body: `sex` because it is
# the partition `by` column; `sex_n` because the banner template
# references it. No explicit `col_spec(visible = FALSE)` needed.
tabular(cdisc_saf_subgroup, titles = "Vital Signs at End of Treatment") |>
  cols(
    agegr      = col_spec(usage = "group", label = "Age Group"),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")

#tabular-091df1279b { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-091df1279b .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-091df1279b p { line-height: inherit; }
#tabular-091df1279b .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-091df1279b .tabular-caption { margin: 0; padding: 0; }
#tabular-091df1279b .tabular-pad { margin: 0; line-height: 1; }
#tabular-091df1279b .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-091df1279b .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-091df1279b .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-091df1279b .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-091df1279b .tabular-table th, #tabular-091df1279b .tabular-table td { padding: .18rem .6rem; }
#tabular-091df1279b .tabular-table td { text-align: left; vertical-align: top; }
#tabular-091df1279b .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-091df1279b .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-091df1279b .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-091df1279b .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-091df1279b .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-091df1279b .tabular-table tbody tr td { border-top: none; }
#tabular-091df1279b .tabular-band { text-align: center; }
#tabular-091df1279b .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-091df1279b .tabular-subgroup-label { font-weight: 600; }
#tabular-091df1279b .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-091df1279b .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-091df1279b .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-091df1279b .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-091df1279b .text-left { text-align: left; }
#tabular-091df1279b .text-center { text-align: center; }
#tabular-091df1279b .text-right { text-align: right; }
#tabular-091df1279b .tabular-table thead th.text-left { text-align: left; }
#tabular-091df1279b .tabular-table thead th.text-center { text-align: center; }
#tabular-091df1279b .tabular-table thead th.text-right { text-align: right; }
#tabular-091df1279b .valign-top { vertical-align: top; }
#tabular-091df1279b .valign-middle { vertical-align: middle; }
#tabular-091df1279b .valign-bottom { vertical-align: bottom; }
#tabular-091df1279b .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-091df1279b .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-091df1279b .tabular-page-break-row { display: none; }
#tabular-091df1279b { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-091df1279b .tabular-page-header, #tabular-091df1279b .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-091df1279b .tabular-page-header { margin-bottom: 1rem; }
#tabular-091df1279b .tabular-page-footer { margin-top: 1rem; }
#tabular-091df1279b .tabular-page-header-left, #tabular-091df1279b .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-091df1279b .tabular-page-header-center, #tabular-091df1279b .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-091df1279b .tabular-page-header-right, #tabular-091df1279b .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-091df1279b .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-091df1279b .tabular-table tr { page-break-inside: avoid; } #tabular-091df1279b .tabular-page-header, #tabular-091df1279b .tabular-page-footer { display: none; } #tabular-091df1279b .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-091df1279b .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-091df1279b .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Vital Signs at End of Treatment
 



Statistic
```
