# Convert a `tabular_spec` to an `htmltools` `tagList`

Renders the spec to a self-contained HTML fragment and wraps it in an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)
suitable for inline embedding in Quarto / Rmd chunks, RStudio / Positron
viewer panes, pkgdown reference pages, and Shiny UIs.

## Usage

``` r
# S3 method for class 'tabular_spec'
as.tags(x, ..., id = NULL)
```

## Arguments

- x:

  *The `tabular_spec` to convert.* `<tabular_spec>: required`.

- ...:

  *Reserved.* Ignored.

- id:

  *Wrapping div id.*
  `<character(1) | NULL>: default NULL (auto-generate)`. Pass an
  explicit id when you need to target the table from external CSS or
  JavaScript.

## Value

*An
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)*
containing a `<style>` block plus a wrapping `<div>` containing the
table. Knitr, htmltools, and RStudio / Positron viewer panes all know
how to render it.

## Details

**Fragment extraction.** Tabular's HTML backend emits a full
`<!DOCTYPE html>` document with a `<style>` block in the head and the
table inside `<body>`. For inline embedding we extract the `<style>` and
`<body>` content separately and re- wrap them in an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html):

    <style>...table CSS...</style>
    <div id="..." style="overflow-x:auto;max-width:100%;">
      ...table content...
    </div>

The wrapping `<div>` gets a random unique `id` (so multiple tables on
the same page have CSS-scopable hooks) and `overflow-x: auto` so wide
tables get a horizontal scrollbar instead of overflowing their
container.

## See also

**Renders via:**
[`print.tabular_spec`](https://vthanik.github.io/tabular/reference/print.tabular_spec.md),
`knit_print()`.

**Terminal verb:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Examples

``` r
# ---- Example 1: Embed in a custom htmltools page ----
#
# Compose two tabular tables side-by-side in a parent div.
# `as.tags(spec)` is the entry point used by `print()` and
# `knit_print()` under the hood.
s1 <- tabular(saf_demo, titles = "Demographics")
s2 <- tabular(saf_aeoverall, titles = "AE overall")

if (requireNamespace("htmltools", quietly = TRUE)) {
  htmltools::tagList(
    htmltools::as.tags(s1),
    htmltools::as.tags(s2)
  )
}
#> <style>
#> #tabular-3cbad83d81 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-3cbad83d81 .tabular-content { width: 100%; }
#> #tabular-3cbad83d81 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-3cbad83d81 .tabular-pad { margin: 0; }
#> #tabular-3cbad83d81 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-3cbad83d81 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-3cbad83d81 .tabular-table th, #tabular-3cbad83d81 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-3cbad83d81 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-3cbad83d81 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-3cbad83d81 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-3cbad83d81 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-3cbad83d81 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-3cbad83d81 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-3cbad83d81 .tabular-table tbody tr td { border-top: none; }
#> #tabular-3cbad83d81 .tabular-band { text-align: center; }
#> #tabular-3cbad83d81 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-3cbad83d81 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-3cbad83d81 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-3cbad83d81 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-3cbad83d81 .text-left { text-align: left; }
#> #tabular-3cbad83d81 .text-center { text-align: center; }
#> #tabular-3cbad83d81 .text-right { text-align: right; }
#> #tabular-3cbad83d81 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-3cbad83d81 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-3cbad83d81 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-3cbad83d81 .valign-top { vertical-align: top; }
#> #tabular-3cbad83d81 .valign-middle { vertical-align: middle; }
#> #tabular-3cbad83d81 .valign-bottom { vertical-align: bottom; }
#> #tabular-3cbad83d81 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-3cbad83d81 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-3cbad83d81 .tabular-page-break-row { display: none; }
#> #tabular-3cbad83d81 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-3cbad83d81 .tabular-page-header, #tabular-3cbad83d81 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-3cbad83d81 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-3cbad83d81 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-3cbad83d81 .tabular-page-header-left, #tabular-3cbad83d81 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-3cbad83d81 .tabular-page-header-center, #tabular-3cbad83d81 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-3cbad83d81 .tabular-page-header-right, #tabular-3cbad83d81 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-3cbad83d81 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3cbad83d81 .tabular-table tr { page-break-inside: avoid; } #tabular-3cbad83d81 .tabular-page-header, #tabular-3cbad83d81 .tabular-page-footer { display: none; } #tabular-3cbad83d81 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3cbad83d81 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3cbad83d81 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-3cbad83d81" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Demographics</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>variable</th><th>stat_label</th><th>placebo</th><th>drug_100</th><th>drug_50</th><th>Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Age (years)</td><td>n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td>Age (years)</td><td>Mean (SD)</td><td>75.2 (8.59)</td><td>73.8 (7.94)</td><td>76.0 (8.11)</td><td>75.1 (8.25)</td></tr>
#> <tr><td>Age (years)</td><td>Median</td><td>76.0</td><td>75.5</td><td>78.0</td><td>77.0</td></tr>
#> <tr><td>Age (years)</td><td>Q1, Q3</td><td>69.2, 81.8</td><td>70.5, 79.0</td><td>71.0, 82.0</td><td>70.0, 81.0</td></tr>
#> <tr><td>Age (years)</td><td>Min, Max</td><td>52, 89</td><td>56, 88</td><td>51, 88</td><td>51, 89</td></tr>
#> <tr><td>Age Group, n (%)</td><td>18-64</td><td>14 (16.3)</td><td>11 (15.3)</td><td>8 (8.3)</td><td>33 (13.0)</td></tr>
#> <tr><td>Age Group, n (%)</td><td>&gt;64</td><td>72 (83.7)</td><td>61 (84.7)</td><td>88 (91.7)</td><td>221 (87.0)</td></tr>
#> <tr><td>Sex, n (%)</td><td>F</td><td>53 (61.6)</td><td>35 (48.6)</td><td>55 (57.3)</td><td>143 (56.3)</td></tr>
#> <tr><td>Sex, n (%)</td><td>M</td><td>33 (38.4)</td><td>37 (51.4)</td><td>41 (42.7)</td><td>111 (43.7)</td></tr>
#> <tr><td>Race, n (%)</td><td>WHITE</td><td>78 (90.7)</td><td>62 (86.1)</td><td>90 (93.8)</td><td>230 (90.6)</td></tr>
#> <tr><td>Race, n (%)</td><td>BLACK OR AFRICAN AMERICAN</td><td>8 (9.3)</td><td>9 (12.5)</td><td>6 (6.2)</td><td>23 (9.1)</td></tr>
#> <tr><td>Race, n (%)</td><td>ASIAN</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr><td>Race, n (%)</td><td>AMERICAN INDIAN OR ALASKA NATIVE</td><td>0 (0.0)</td><td>1 (1.4)</td><td>0 (0.0)</td><td>1 (0.4)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>HISPANIC OR LATINO</td><td>3 (3.5)</td><td>3 (4.2)</td><td>6 (6.2)</td><td>12 (4.7)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>NOT HISPANIC OR LATINO</td><td>83 (96.5)</td><td>69 (95.8)</td><td>90 (93.8)</td><td>242 (95.3)</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>NOT REPORTED</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr><td>Weight (kg)</td><td>n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td>Weight (kg)</td><td>Mean (SD)</td><td>62.8 (12.77)</td><td>69.5 (14.35)</td><td>68.0 (14.50)</td><td>66.6 (14.13)</td></tr>
#> <tr><td>Weight (kg)</td><td>Median</td><td>60.6</td><td>69.0</td><td>66.7</td><td>66.7</td></tr>
#> <tr><td>Weight (kg)</td><td>Q1, Q3</td><td>53.6, 74.2</td><td>56.9, 80.3</td><td>56.0, 78.2</td><td>55.3, 77.1</td></tr>
#> <tr><td>Weight (kg)</td><td>Min, Max</td><td>34, 86</td><td>44, 108</td><td>42, 106</td><td>34, 108</td></tr>
#> <tr><td>Height (cm)</td><td>n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td>Height (cm)</td><td>Mean (SD)</td><td>162.6 (11.52)</td><td>165.9 (10.28)</td><td>163.7 (10.30)</td><td>163.9 (10.76)</td></tr>
#> <tr><td>Height (cm)</td><td>Median</td><td>162.6</td><td>165.1</td><td>162.6</td><td>162.8</td></tr>
#> <tr><td>Height (cm)</td><td>Q1, Q3</td><td>154.0, 171.1</td><td>157.5, 172.8</td><td>157.5, 170.2</td><td>156.2, 171.4</td></tr>
#> <tr><td>Height (cm)</td><td>Min, Max</td><td>137, 185</td><td>146, 190</td><td>136, 196</td><td>136, 196</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Mean (SD)</td><td>23.6 (3.67)</td><td>25.2 (3.97)</td><td>25.2 (4.40)</td><td>24.7 (4.09)</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Median</td><td>23.4</td><td>24.8</td><td>24.8</td><td>24.2</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Q1, Q3</td><td>21.2, 25.6</td><td>22.7, 27.6</td><td>22.3, 28.2</td><td>21.9, 27.3</td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Min, Max</td><td>15, 33</td><td>14, 35</td><td>15, 40</td><td>14, 40</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Underweight (&lt;18.5)</td><td>3 (3.5)</td><td>1 (1.4)</td><td>4 (4.2)</td><td>8 (3.1)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Normal (18.5-24.9)</td><td>57 (66.3)</td><td>39 (54.2)</td><td>46 (47.9)</td><td>142 (55.9)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Overweight (25-29.9)</td><td>20 (23.3)</td><td>23 (31.9)</td><td>32 (33.3)</td><td>75 (29.5)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">BMI Category, n (%)</td><td style="border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7.0)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12.5)</td><td style="border-bottom: 0.5pt solid #212529;">13 (13.5)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
#> <style>
#> #tabular-a6839e0cf9 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-a6839e0cf9 .tabular-content { width: 100%; }
#> #tabular-a6839e0cf9 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-a6839e0cf9 .tabular-pad { margin: 0; }
#> #tabular-a6839e0cf9 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-a6839e0cf9 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-a6839e0cf9 .tabular-table th, #tabular-a6839e0cf9 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-a6839e0cf9 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-a6839e0cf9 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-a6839e0cf9 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-a6839e0cf9 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-a6839e0cf9 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-a6839e0cf9 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-a6839e0cf9 .tabular-table tbody tr td { border-top: none; }
#> #tabular-a6839e0cf9 .tabular-band { text-align: center; }
#> #tabular-a6839e0cf9 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-a6839e0cf9 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-a6839e0cf9 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-a6839e0cf9 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-a6839e0cf9 .text-left { text-align: left; }
#> #tabular-a6839e0cf9 .text-center { text-align: center; }
#> #tabular-a6839e0cf9 .text-right { text-align: right; }
#> #tabular-a6839e0cf9 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-a6839e0cf9 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-a6839e0cf9 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-a6839e0cf9 .valign-top { vertical-align: top; }
#> #tabular-a6839e0cf9 .valign-middle { vertical-align: middle; }
#> #tabular-a6839e0cf9 .valign-bottom { vertical-align: bottom; }
#> #tabular-a6839e0cf9 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-a6839e0cf9 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-a6839e0cf9 .tabular-page-break-row { display: none; }
#> #tabular-a6839e0cf9 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-a6839e0cf9 .tabular-page-header, #tabular-a6839e0cf9 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-a6839e0cf9 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-a6839e0cf9 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-a6839e0cf9 .tabular-page-header-left, #tabular-a6839e0cf9 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-a6839e0cf9 .tabular-page-header-center, #tabular-a6839e0cf9 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-a6839e0cf9 .tabular-page-header-right, #tabular-a6839e0cf9 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-a6839e0cf9 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-a6839e0cf9 .tabular-table tr { page-break-inside: avoid; } #tabular-a6839e0cf9 .tabular-page-header, #tabular-a6839e0cf9 .tabular-page-footer { display: none; } #tabular-a6839e0cf9 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-a6839e0cf9 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-a6839e0cf9 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-a6839e0cf9" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">AE overall</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>stat_label</th><th>Total</th><th>placebo</th><th>drug_100</th><th>drug_50</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Any TEAE</td><td>217 (85.4)</td><td>65 (75.6)</td><td>68 (94.4)</td><td>84 (87.5)</td></tr>
#> <tr><td>Any Serious AE (SAE)</td><td>3 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (2.1)</td></tr>
#> <tr><td>Any AE Related to Study Drug</td><td>184 (72.4)</td><td>43 (50.0)</td><td>64 (88.9)</td><td>77 (80.2)</td></tr>
#> <tr><td>Any AE Leading to Death</td><td>3 (1.2)</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.0)</td></tr>
#> <tr><td>Any AE Recovered / Resolved</td><td>157 (61.8)</td><td>47 (54.7)</td><td>49 (68.1)</td><td>61 (63.5)</td></tr>
#> <tr><td>  Maximum severity: Mild</td><td>77 (30.3)</td><td>36 (41.9)</td><td>20 (27.8)</td><td>21 (21.9)</td></tr>
#> <tr><td>  Maximum severity: Moderate</td><td>111 (43.7)</td><td>24 (27.9)</td><td>40 (55.6)</td><td>47 (49.0)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">  Maximum severity: Severe</td><td style="border-bottom: 0.5pt solid #212529;">29 (11.4)</td><td style="border-bottom: 0.5pt solid #212529;">5 (5.8)</td><td style="border-bottom: 0.5pt solid #212529;">8 (11.1)</td><td style="border-bottom: 0.5pt solid #212529;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
