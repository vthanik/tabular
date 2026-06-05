# Treatment-effect estimates by model

Four competing efficacy models with their treatment-effect point
estimate, 95% confidence-interval bounds, and nominal p-value. Shaped as
a numeric-cell table (one row per model) rather than the usual
pre-formatted character cells, so it exercises the
`col_spec(format = ...)` + `col_spec(na_text = ...)` cascade. One row
(`MMRM`) carries `NA` CI bounds to demonstrate `na_text`.

## Usage

``` r
cdisc_eff_estimates
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
tabular(cdisc_eff_estimates, titles = "Treatment-effect estimates by model") |>
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

#tabular-c090976b2e { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-c090976b2e .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-c090976b2e p { line-height: inherit; }
#tabular-c090976b2e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-c090976b2e .tabular-caption { margin: 0; padding: 0; }
#tabular-c090976b2e .tabular-pad { margin: 0; line-height: 1; }
#tabular-c090976b2e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-c090976b2e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-c090976b2e .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-c090976b2e .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-c090976b2e .tabular-table th, #tabular-c090976b2e .tabular-table td { padding: .18rem .6rem; }
#tabular-c090976b2e .tabular-table td { text-align: left; vertical-align: top; }
#tabular-c090976b2e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-c090976b2e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-c090976b2e .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-c090976b2e .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-c090976b2e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-c090976b2e .tabular-table tbody tr td { border-top: none; }
#tabular-c090976b2e .tabular-band { text-align: center; }
#tabular-c090976b2e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-c090976b2e .tabular-subgroup-label { font-weight: 600; }
#tabular-c090976b2e .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-c090976b2e .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-c090976b2e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-c090976b2e .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-c090976b2e .text-left { text-align: left; }
#tabular-c090976b2e .text-center { text-align: center; }
#tabular-c090976b2e .text-right { text-align: right; }
#tabular-c090976b2e .tabular-table thead th.text-left { text-align: left; }
#tabular-c090976b2e .tabular-table thead th.text-center { text-align: center; }
#tabular-c090976b2e .tabular-table thead th.text-right { text-align: right; }
#tabular-c090976b2e .valign-top { vertical-align: top; }
#tabular-c090976b2e .valign-middle { vertical-align: middle; }
#tabular-c090976b2e .valign-bottom { vertical-align: bottom; }
#tabular-c090976b2e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-c090976b2e .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-c090976b2e .tabular-page-break-row { display: none; }
#tabular-c090976b2e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-c090976b2e .tabular-page-header, #tabular-c090976b2e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-c090976b2e .tabular-page-header { margin-bottom: 1rem; }
#tabular-c090976b2e .tabular-page-footer { margin-top: 1rem; }
#tabular-c090976b2e .tabular-page-header-left, #tabular-c090976b2e .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-c090976b2e .tabular-page-header-center, #tabular-c090976b2e .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-c090976b2e .tabular-page-header-right, #tabular-c090976b2e .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-c090976b2e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-c090976b2e .tabular-table tr { page-break-inside: avoid; } #tabular-c090976b2e .tabular-page-header, #tabular-c090976b2e .tabular-page-footer { display: none; } #tabular-c090976b2e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-c090976b2e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-c090976b2e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Treatment-effect estimates by model
 



Estimate
```
