# Treatment-effect estimates by model

Four competing efficacy models with their treatment-effect point
estimate, 95% confidence-interval bounds, and nominal p-value. Shaped as
a numeric-cell table (one row per model) rather than the usual
pre-formatted character cells, so it exercises the
`col_spec(format = ...)` + `col_spec(na_text = ...)` cascade. One row
(`MMRM`) carries `NA` CI bounds to demonstrate `na_text`.

## Usage

``` r
eff_estimates
```

## Format

A data frame with 4 rows and 5 columns:

- `model`:

  Model name (`"ANCOVA"`, `"MMRM"`, `"Cox PH"`,
  `"Bootstrap (1000 reps)"`).

- `estimate`:

  Numeric point estimate.

- `lower_ci`, `upper_ci`:

  Numeric 95% CI bounds. The MMRM row has `NA` bounds.

- `p_value`:

  Nominal p-value (numeric).

## Source

Synthetic estimates following the
`_archive/.../arframe-examples/tables/tte-summary.qmd` and
`efficacy-bor.qmd` shapes. Not derived from any patient-level data —
illustrative values only.

## See also

[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
for the formatting cascade these values exercise.

## Examples

``` r
# Numeric-cell efficacy table — format = "%.2f" pins precision,
# na_text = "--" renders the MMRM row's NA bounds as dashes.
tabular(eff_estimates, titles = "Treatment-effect estimates by model") |>
  cols(
    model    = col_spec(usage = "group",  label = "Model", valign = "top"),
    estimate = col_spec(label = "Estimate", align = "decimal",
                        format = "%.2f"),
    lower_ci = col_spec(label = "Lower\n95% CI", align = "decimal",
                        format = "%.2f", na_text = "--"),
    upper_ci = col_spec(label = "Upper\n95% CI", align = "decimal",
                        format = "%.2f", na_text = "--"),
    p_value  = col_spec(label = "p-value",  align = "decimal",
                        format = "%.4f")
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
#> <div id="tabular_ZQdHOrDslY" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Treatment-effect estimates by model</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-center">Estimate</th><th class="text-center">Lower<br/>95% CI</th><th class="text-center">Upper<br/>95% CI</th><th class="text-center">p-value</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>ANCOVA</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">-2.31</td><td class="text-right">-3.42</td><td class="text-right">-1.20</td><td class="text-right">0.0042</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>MMRM</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">-2.45</td><td class="text-right">--   </td><td class="text-right">--   </td><td class="text-right">0.0061</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Cox PH</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);"> 0.81</td><td class="text-right"> 0.68</td><td class="text-right"> 0.97</td><td class="text-right">0.0087</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Bootstrap (1000 reps)</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">-2.29</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">-3.50</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">-1.10</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">0.0050</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
