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

#tabular-fadaf8b5f2 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#tabular-fadaf8b5f2 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-fadaf8b5f2 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-fadaf8b5f2 .tabular-pad { margin: 0; }
#tabular-fadaf8b5f2 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-fadaf8b5f2 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-fadaf8b5f2 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-fadaf8b5f2 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-fadaf8b5f2 .tabular-table th, #tabular-fadaf8b5f2 .tabular-table td { padding: .35rem .6rem; }
#tabular-fadaf8b5f2 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-fadaf8b5f2 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-fadaf8b5f2 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-fadaf8b5f2 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-fadaf8b5f2 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-fadaf8b5f2 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-fadaf8b5f2 .tabular-table tbody tr td { border-top: none; }
#tabular-fadaf8b5f2 .tabular-band { text-align: center; }
#tabular-fadaf8b5f2 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-fadaf8b5f2 .tabular-subgroup-label { font-weight: 600; }
#tabular-fadaf8b5f2 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-fadaf8b5f2 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-fadaf8b5f2 .text-left { text-align: left; }
#tabular-fadaf8b5f2 .text-center { text-align: center; }
#tabular-fadaf8b5f2 .text-right { text-align: right; }
#tabular-fadaf8b5f2 .tabular-table thead th.text-left { text-align: left; }
#tabular-fadaf8b5f2 .tabular-table thead th.text-center { text-align: center; }
#tabular-fadaf8b5f2 .tabular-table thead th.text-right { text-align: right; }
#tabular-fadaf8b5f2 .valign-top { vertical-align: top; }
#tabular-fadaf8b5f2 .valign-middle { vertical-align: middle; }
#tabular-fadaf8b5f2 .valign-bottom { vertical-align: bottom; }
#tabular-fadaf8b5f2 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-fadaf8b5f2 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-fadaf8b5f2 .tabular-page-break-row { display: none; }
#tabular-fadaf8b5f2 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-fadaf8b5f2 .tabular-page-header, #tabular-fadaf8b5f2 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-fadaf8b5f2 .tabular-page-header { margin-bottom: 1rem; }
#tabular-fadaf8b5f2 .tabular-page-footer { margin-top: 1rem; }
#tabular-fadaf8b5f2 .tabular-page-header-left, #tabular-fadaf8b5f2 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-fadaf8b5f2 .tabular-page-header-center, #tabular-fadaf8b5f2 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-fadaf8b5f2 .tabular-page-header-right, #tabular-fadaf8b5f2 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-fadaf8b5f2 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-fadaf8b5f2 .tabular-table tr { page-break-inside: avoid; } #tabular-fadaf8b5f2 .tabular-page-header, #tabular-fadaf8b5f2 .tabular-page-footer { display: none; } #tabular-fadaf8b5f2 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-fadaf8b5f2 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-fadaf8b5f2 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.4.1
Vital Signs Summary at Baseline and End of Treatment
Safety Population (N=254)
 



Statistic
```
