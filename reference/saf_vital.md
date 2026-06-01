# Vital-signs summary

Pre-summarised vital-signs stats. Four parameters (SYSBP, DIABP, PULSE,
TEMP) at four visits (Baseline, Week 8, Week 16, End of Treatment), each
producing four statistic rows (`n`, `Mean (SD)`, `Median`, `Min, Max`).
The 4 x 4 x 4 grid makes this dataset a natural fit for
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
examples — 64 rows comfortably exceed a single page under typical
clinical row-per-page settings.

## Usage

``` r
saf_vital
```

## Format

A data frame with 64 rows and 7 columns:

- `paramcd`:

  CDISC parameter code (`SYSBP` / `DIABP` / `PULSE` / `TEMP`). Repeats
  across visit and statistic; use `col_spec(usage = "group")` to
  collapse.

- `param`:

  Decoded parameter name.

- `visit`:

  Analysis visit label (`"Baseline"` / `"Week 8"` / `"Week 16"` /
  `"End of Treatment"`).

- `stat_label`:

  Statistic label.

- `placebo`, `drug_50`, `drug_100`:

  Per-arm cell text.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::advs`](https://pharmaverse.github.io/pharmaverseadam/reference/advs.html).

## See also

[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for BigN
denominators.

## Examples

``` r
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_vital,
  titles = c(
    "Table 14.4.1",
    "Vital Signs Summary at Baseline and End of Treatment",
    sprintf("Safety Population (N=%d)", n["Total"])
  )
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter"),
    visit      = col_spec(usage = "group", label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
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
#> <div id="tabular_ljj7AHPg2Z" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.4.1</h1>
#> <h1 class="tabular-title">Vital Signs Summary at Baseline and End of Treatment</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Drug 100<br/>N=72</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 77.1 (10.7)</td><td class="text-right"> 76.6 (9.8) </td><td class="text-right"> 78.2 (10.3)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 77.7       </td><td class="text-right"> 76.7       </td><td class="text-right"> 78.8       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 40  , 110  </td><td class="text-right"> 48  , 108  </td><td class="text-right"> 51  , 108  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (9.1) </td><td class="text-right"> 75.4 (10.6)</td><td class="text-right"> 77.4 (9.1) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 78.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 101  </td><td class="text-right"> 52  , 100  </td><td class="text-right"> 54  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.1 (10.9)</td><td class="text-right"> 75.2 (10.0)</td><td class="text-right"> 76.0 (9.0) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 75.7       </td><td class="text-right"> 77.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 98   </td><td class="text-right"> 55  , 98   </td><td class="text-right"> 50  , 92   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.4 (10.7)</td><td class="text-right"> 76.0 (11.2)</td><td class="text-right"> 76.0 (9.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.5       </td><td class="text-right"> 76.0       </td><td class="text-right"> 78.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.5 (11.6)</td><td class="text-right"> 72.1 (10.8)</td><td class="text-right"> 72.4 (9.7) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.3       </td><td class="text-right"> 70.0       </td><td class="text-right"> 71.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 134  </td><td class="text-right"> 50  , 104  </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 71.8 (9.0) </td><td class="text-right"> 72.6 (11.1)</td><td class="text-right"> 74.0 (8.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 72.0       </td><td class="text-right"> 73.2       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 52  , 102  </td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 70.6 (8.8) </td><td class="text-right"> 68.8 (9.4) </td><td class="text-right"> 73.2 (9.5) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 70.2       </td><td class="text-right"> 68.0       </td><td class="text-right"> 72.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 90   </td><td class="text-right"> 48  , 104  </td><td class="text-right"> 51  , 96   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (11.5)</td><td class="text-right"> 74.1 (9.4) </td><td class="text-right"> 73.6 (9.6) </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>Median</td><td class="text-right"> 74.0       </td><td class="text-right"> 75.0       </td><td class="text-right"> 73.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 106  </td><td class="text-right"> 50  , 94   </td><td class="text-right"> 50  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.8 (17.6)</td><td class="text-right">137.9 (18.5)</td><td class="text-right">137.8 (17.2)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.3       </td><td class="text-right">138.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 80  , 184  </td><td class="text-right">100  , 194  </td><td class="text-right">100  , 192  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.3 (17.0)</td><td class="text-right">134.9 (17.8)</td><td class="text-right">135.1 (15.5)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.5       </td><td class="text-right">132.3       </td><td class="text-right">134.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 90  , 189  </td><td class="text-right"> 92  , 200  </td><td class="text-right"> 91  , 198  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.6 (18.3)</td><td class="text-right">132.5 (14.3)</td><td class="text-right">133.7 (16.0)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">130.0       </td><td class="text-right">132.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 76  , 190  </td><td class="text-right">100  , 168  </td><td class="text-right"> 99  , 186  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">132.7 (15.4)</td><td class="text-right">133.0 (17.1)</td><td class="text-right">132.3 (15.6)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">130.0       </td><td class="text-right">131.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 78  , 172  </td><td class="text-right"> 92  , 178  </td><td class="text-right">100  , 177  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">172         </td><td class="text-right">190         </td><td class="text-right">144         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.5 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.6       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 35  , 37   </td><td class="text-right"> 35  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">146         </td><td class="text-right">118         </td><td class="text-right">112         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">136         </td><td class="text-right"> 82         </td><td class="text-right"> 74         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.3) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>n</td><td class="text-right"> 74         </td><td class="text-right"> 59         </td><td class="text-right"> 56         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.8       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 37   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 38   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 36  , 37   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
