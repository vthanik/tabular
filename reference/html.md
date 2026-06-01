# Mark a string as HTML for inline formatting

Wrap a length-1 character vector so
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
and similar string slots interpret it as a constrained HTML subset at
render time. Use when CommonMark cannot express the formatting (custom
CSS via `<span style="...">`, raw destination codes via
`<span data-rtf="...">`).

## Usage

``` r
html(text)
```

## Arguments

- text:

  *The HTML fragment.* `<character(1)>: required`. Length-1 character
  vector. `NA` is rejected.

## Value

*A length-1 character vector classed `c("from_html", "character")`.*
Pass it directly into any string-bearing slot
([`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
titles / footnotes,
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
label, [`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext); the resolve engine calls `parse_inline()`
internally and backends walk the resulting `inline_ast`.

## Details

**Recognised tag whitelist.** `<p>`, `<br>` / `<br/>`, `<strong>`,
`<b>`, `<em>`, `<i>`, `<sup>`, `<sub>`, `<code>`, `<a href>`,
`<span style>`. Tags outside this set drop their wrapper and keep their
text content (no arbitrary HTML attack surface).

**Span styles.** `<span style="color: red; font-weight: bold">x</span>`
parses the style attribute into a named character vector
(`c(color = "red", "font-weight" = "bold")`). Backends translate CSS
keys to destination-specific markup (RTF `\cf`, LaTeX `\textcolor`, DOCX
`<w:color>`, HTML inline style).

**Backend-specific raw codes.** A span with `data-rtf`, `data-latex`,
`data-html`, or `data-docx` attributes carries per-backend raw markup.
The matching backend emits its data value verbatim and ignores the
others; non-matching backends render the span's text content as plain.
Use for cases the AST cannot express portably.

## See also

**Sibling helper:**
[`md()`](https://vthanik.github.io/tabular/reference/md.md) — Markdown
wrapper for the common case.

**String slots that consume the wrapper:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
(`titles`, `footnotes`),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
(`label`),
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
(`pretext`, `posttext`).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Colour-styled span in a title ----
#
# Demographics table title with the population subset shaded
# red. The HTML wrapper carries an inline CSS style; backends
# translate (RTF: \cf, LaTeX: \textcolor, HTML: inline style).
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics",
    html(sprintf("Safety Pop <span style='color:red'>(N=%d)</span>", n["Total"]))
  )
)
#> <style>
#> #tabular-f1beb41637 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-f1beb41637 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-f1beb41637 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-f1beb41637 .tabular-pad { margin: 0; }
#> #tabular-f1beb41637 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-f1beb41637 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-f1beb41637 .tabular-table th, #tabular-f1beb41637 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-f1beb41637 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-f1beb41637 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-f1beb41637 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-f1beb41637 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-f1beb41637 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-f1beb41637 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-f1beb41637 .tabular-table tbody tr td { border-top: none; }
#> #tabular-f1beb41637 .tabular-band { text-align: center; }
#> #tabular-f1beb41637 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-f1beb41637 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-f1beb41637 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-f1beb41637 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-f1beb41637 .text-left { text-align: left; }
#> #tabular-f1beb41637 .text-center { text-align: center; }
#> #tabular-f1beb41637 .text-right { text-align: right; }
#> #tabular-f1beb41637 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-f1beb41637 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-f1beb41637 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-f1beb41637 .valign-top { vertical-align: top; }
#> #tabular-f1beb41637 .valign-middle { vertical-align: middle; }
#> #tabular-f1beb41637 .valign-bottom { vertical-align: bottom; }
#> #tabular-f1beb41637 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-f1beb41637 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-f1beb41637 .tabular-page-break-row { display: none; }
#> #tabular-f1beb41637 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-f1beb41637 .tabular-page-header, #tabular-f1beb41637 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-f1beb41637 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-f1beb41637 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-f1beb41637 .tabular-page-header-left, #tabular-f1beb41637 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-f1beb41637 .tabular-page-header-center, #tabular-f1beb41637 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-f1beb41637 .tabular-page-header-right, #tabular-f1beb41637 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-f1beb41637 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-f1beb41637 .tabular-table tr { page-break-inside: avoid; } #tabular-f1beb41637 .tabular-page-header, #tabular-f1beb41637 .tabular-page-footer { display: none; } #tabular-f1beb41637 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-f1beb41637 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-f1beb41637 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-f1beb41637" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
#> <h1 class="tabular-title">Demographics</h1>
#> <h1 class="tabular-title">Safety Pop <span>(N=254)</span></h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
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
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Underweight (&lt;18.5)</td><td>3 (3.5)</td><td>1 (1.4)</td><td>4 (4.2)</td><td>8 (3.1)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Normal (18.5-24.9)</td><td>57 (66.3)</td><td>39 (54.2)</td><td>46 (47.9)</td><td>142 (55.9)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Overweight (25-29.9)</td><td>20 (23.3)</td><td>23 (31.9)</td><td>32 (33.3)</td><td>75 (29.5)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">BMI Category, n (%)</td><td style="border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7.0)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12.5)</td><td style="border-bottom: 0.5pt solid #212529;">13 (13.5)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 2: HTML link plus superscript footnote marker ----
#
# AE table footnote with an HTML link and a superscript marker.
# `html()` lets the user write tags directly when CommonMark
# would be awkward (e.g. attributes that Markdown does not
# surface).
tabular(
  saf_aeoverall,
  titles = c("Table 14.3.0", "Overall Adverse Event Summary"),
  footnotes = c(
    html('See <a href="https://www.meddra.org/">MedDRA</a> coding<sup>1</sup>.')
  )
) |>
  cols(stat_label = col_spec(usage = "group", label = "Category"))
#> <style>
#> #tabular-00a82039bb { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-00a82039bb .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-00a82039bb .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-00a82039bb .tabular-pad { margin: 0; }
#> #tabular-00a82039bb .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-00a82039bb .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-00a82039bb .tabular-table th, #tabular-00a82039bb .tabular-table td { padding: .35rem .6rem; }
#> #tabular-00a82039bb .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-00a82039bb .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-00a82039bb .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-00a82039bb .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-00a82039bb .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-00a82039bb .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-00a82039bb .tabular-table tbody tr td { border-top: none; }
#> #tabular-00a82039bb .tabular-band { text-align: center; }
#> #tabular-00a82039bb .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-00a82039bb .tabular-subgroup-label { font-weight: 600; }
#> #tabular-00a82039bb .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-00a82039bb .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-00a82039bb .text-left { text-align: left; }
#> #tabular-00a82039bb .text-center { text-align: center; }
#> #tabular-00a82039bb .text-right { text-align: right; }
#> #tabular-00a82039bb .tabular-table thead th.text-left { text-align: left; }
#> #tabular-00a82039bb .tabular-table thead th.text-center { text-align: center; }
#> #tabular-00a82039bb .tabular-table thead th.text-right { text-align: right; }
#> #tabular-00a82039bb .valign-top { vertical-align: top; }
#> #tabular-00a82039bb .valign-middle { vertical-align: middle; }
#> #tabular-00a82039bb .valign-bottom { vertical-align: bottom; }
#> #tabular-00a82039bb .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-00a82039bb .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-00a82039bb .tabular-page-break-row { display: none; }
#> #tabular-00a82039bb { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-00a82039bb .tabular-page-header, #tabular-00a82039bb .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-00a82039bb .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-00a82039bb .tabular-page-footer { margin-top: 1rem; }
#> #tabular-00a82039bb .tabular-page-header-left, #tabular-00a82039bb .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-00a82039bb .tabular-page-header-center, #tabular-00a82039bb .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-00a82039bb .tabular-page-header-right, #tabular-00a82039bb .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-00a82039bb .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-00a82039bb .tabular-table tr { page-break-inside: avoid; } #tabular-00a82039bb .tabular-page-header, #tabular-00a82039bb .tabular-page-footer { display: none; } #tabular-00a82039bb .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-00a82039bb .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-00a82039bb .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-00a82039bb" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.0</h1>
#> <h1 class="tabular-title">Overall Adverse Event Summary</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>Total</th><th>placebo</th><th>drug_100</th><th>drug_50</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any TEAE</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">217 (85.4)</td><td>65 (75.6)</td><td>68 (94.4)</td><td>84 (87.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any Serious AE (SAE)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">3 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (2.1)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Related to Study Drug</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">184 (72.4)</td><td>43 (50.0)</td><td>64 (88.9)</td><td>77 (80.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Leading to Death</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">3 (1.2)</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Recovered / Resolved</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">157 (61.8)</td><td>47 (54.7)</td><td>49 (68.1)</td><td>61 (63.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Mild</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">77 (30.3)</td><td>36 (41.9)</td><td>20 (27.8)</td><td>21 (21.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Moderate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">111 (43.7)</td><td>24 (27.9)</td><td>40 (55.6)</td><td>47 (49.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Severe</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">29 (11.4)</td><td style="border-bottom: 0.5pt solid #212529;">5 (5.8)</td><td style="border-bottom: 0.5pt solid #212529;">8 (11.1)</td><td style="border-bottom: 0.5pt solid #212529;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">See <a href="https://www.meddra.org/">MedDRA</a> coding<sup>1</sup>.</p>
#> </div></div>
```
