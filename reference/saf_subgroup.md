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
saf_subgroup
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

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::advs`](https://pharmaverse.github.io/pharmaverseadam/reference/advs.html)
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

[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for BigN
denominators;
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
for the verb this dataset is designed for.

## Examples

``` r
# 95% pattern: subgroup partition by sex with inline BigN.
# `sex` and `sex_n` auto-hide from the body: `sex` because it is
# the partition `by` column; `sex_n` because the banner template
# references it. No explicit `col_spec(visible = FALSE)` needed.
tabular(saf_subgroup, titles = "Vital Signs at End of Treatment") |>
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
#> <div id="tabular_fuPO1T8x9I" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Vital Signs at End of Treatment</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: F (N = 106)</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9         </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (10.5)</td><td class="text-right"> 79.9 (8.3) </td><td class="text-right"> 81.6 (8.5) </td><td class="text-right"> 76.8 (10.0)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 78.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 84.0       </td><td class="text-right"> 79.5       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 88   </td><td class="text-right"> 68  , 90   </td><td class="text-right"> 68  , 90   </td><td class="text-right"> 49  , 90   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 24         </td><td class="text-right">  9         </td><td class="text-right">  9         </td><td class="text-right"> 42         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">129.9 (11.2)</td><td class="text-right">132.1 (4.3) </td><td class="text-right">121.8 (13.6)</td><td class="text-right">128.6 (11.1)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">130.0       </td><td class="text-right">128.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right">113  , 156  </td><td class="text-right">128  , 140  </td><td class="text-right">100  , 140  </td><td class="text-right">100  , 156  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.0 (10.8)</td><td class="text-right"> 76.9 (12.2)</td><td class="text-right"> 75.9 (11.9)</td><td class="text-right"> 75.5 (11.7)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 76.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 100  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td><td class="text-right"> 50  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">105         </td><td class="text-right"> 99         </td><td class="text-right"> 72         </td><td class="text-right">276         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">137.1 (15.8)</td><td class="text-right">137.5 (16.7)</td><td class="text-right">140.1 (16.8)</td><td class="text-right">138.0 (16.4)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">134.0       </td><td class="text-right">142.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 172  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 98  , 178  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 177  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95  , 178  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-subgroup"><td colspan="5" class="tabular-subgroup-label"><strong>Sex: M (N = 83)</strong></td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3         </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 83.0 (13.3)</td><td class="text-right"> 80.7 (3.1) </td><td class="text-right"> 77.1 (7.0) </td><td class="text-right"> 80.1 (10.2)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 80.0       </td><td class="text-right"> 80.0       </td><td class="text-right"> 79.0       </td><td class="text-right"> 80.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 68  , 104  </td><td class="text-right"> 78  , 84   </td><td class="text-right"> 68  , 87   </td><td class="text-right"> 68  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 12         </td><td class="text-right">  3         </td><td class="text-right"> 12         </td><td class="text-right"> 27         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.4 (8.3) </td><td class="text-right">122.7 (4.6) </td><td class="text-right">124.8 (12.0)</td><td class="text-right">128.9 (10.9)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">120.0       </td><td class="text-right">127.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right">123  , 150  </td><td class="text-right">120  , 128  </td><td class="text-right">107  , 146  </td><td class="text-right">107  , 150  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.9 (9.7) </td><td class="text-right"> 73.7 (9.7) </td><td class="text-right"> 75.3 (7.9) </td><td class="text-right"> 74.4 (9.2) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 58  , 100  </td><td class="text-right"> 52  , 94   </td><td class="text-right"> 57  , 90   </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 81         </td><td class="text-right"> 66         </td><td class="text-right"> 75         </td><td class="text-right">222         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">127.6 (15.3)</td><td class="text-right">127.0 (17.1)</td><td class="text-right">127.4 (11.5)</td><td class="text-right">127.3 (14.7)</td></tr>
#> <tr><td>Median</td><td class="text-right">130.0       </td><td class="text-right">124.0       </td><td class="text-right">130.0       </td><td class="text-right">130.0       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 92  , 162  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">100  , 156  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 78  , 164  </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
