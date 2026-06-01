# Print a `tabular_spec`

Renders a `tabular_spec` interactively. The default behaviour mirrors
[`gt::gt()`](https://gt.rstudio.com/reference/gt.html): convert the spec
to an `htmltools` tag list and let htmltools dispatch — RStudio +
Positron viewer panes, Quarto / Rmd notebook inline, Databricks
`displayHTML`, and plain-console
[`cat()`](https://rdrr.io/r/base/cat.html) are all handled without any
IDE- specific branching.

## Arguments

- x:

  *The `tabular_spec` to render.* `<tabular_spec>: required`. The same
  object you'd hand to
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

- ...:

  *Forwarded to `htmltools::print` / `as.tags()`.* Use this to pass
  `id`, `style`, `class` overrides to the wrapping `<div>`.

- view:

  *Open the viewer?* `<logical(1)>: default `interactive()“. Same role
  as [`gt::gt`](https://gt.rstudio.com/reference/gt.html)'s \`view\`
  argument: passes through to htmltools as \`browse = view\`. Set \`view
  = FALSE\` to suppress the viewer for one call (e.g. to capture the
  HTML string without launching a window).

- output:

  *Force a specific preview format.*
  `<character(1) | NULL>: default `NULL` (auto)`. See the **`output`
  argument** section above for the full list. The session default can be
  set via `options(tabular_print_output = "cli")` for users who prefer
  the structural summary over the HTML preview.

## Value

*Invisibly returns `x`.* Side effect: opens the viewer, inlines under a
chunk, or [`cat()`](https://rdrr.io/r/base/cat.html)s output.

## Details

**Dispatch.** [`print()`](https://rdrr.io/r/base/print.html) delegates
to
[`as.tags.tabular_spec()`](https://vthanik.github.io/tabular/reference/as.tags.tabular_spec.md)
which returns an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html).
That tag list is handed to `htmltools`'s own print method with
`browse = view`: htmltools opens the IDE viewer when one is registered,
inlines under a Quarto / Rmd chunk when running inside one, or
[`cat()`](https://rdrr.io/r/base/cat.html)s the HTML when neither
applies. No `is_rstudio()` / `is_positron()` / `is_notebook()`
heuristics — htmltools already knows.

**`view` argument.** Defaults to
[`interactive()`](https://rdrr.io/r/base/interactive.html), the same
universal off-switch
[`gt::gt()`](https://gt.rstudio.com/reference/gt.html) uses.
Non-interactive contexts (`Rscript`, `R CMD check`, CI, devtools::test)
bypass the viewer automatically. Pass `view = FALSE` explicitly at an
interactive prompt to suppress the viewer for a single call.

**`output` argument.** Forces a specific preview format instead of the
default HTML-via-htmltools path. One of:

- `"html"` — same as the default, but explicit.

- `"md"` / `"markdown"` — [`cat()`](https://rdrr.io/r/base/cat.html) the
  markdown source to the console (round-trips through `backend_md`).

- `"latex"` — [`cat()`](https://rdrr.io/r/base/cat.html) the markdown
  source as a temporary placeholder (real LaTeX preview lands with
  `backend_latex`).

- `"rtf"` / `"docx"` / `"pdf"` — render an HTML preview and emit a cli
  note pointing at
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) for
  the real artefact. The viewer pane cannot render RTF / OOXML, and we
  deliberately do *not* compile through tinytex on every autoprint.

- `"cli"` — print the structural cli-tree summary (props, headers, sort,
  pagination, preset). Useful for debugging spec composition without
  paying the HTML render cost.

**Robustness.** The HTML render is wrapped in `tryCatch`; if rendering
fails for any reason the printer falls back to the cli-tree summary and
a [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
describing the failure, so a broken spec never crashes the REPL.

**Tempdir.** Preview HTML files live under
`getOption("tabular_preview_dir", default = tempdir())`. Override the
option to keep them in a stable location (handy on Linux distros where
browsers don't have read access to `/tmp/`).

## See also

**Tag conversion:**
[`as.tags.tabular_spec()`](https://vthanik.github.io/tabular/reference/as.tags.tabular_spec.md)
— the htmltools tag list that
[`print()`](https://rdrr.io/r/base/print.html) delegates to. Call it
directly to embed the table in a custom
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)
or Shiny UI.

**Terminal verb:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes
the resolved artefact to disk;
[`print()`](https://rdrr.io/r/base/print.html) is for in-session preview
only.

**Pipeline shape:**
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
resolves the engine pipeline to a `tabular_grid` without I/O.

## Examples

``` r
# ---- Example 1: Build + autoprint (HTML preview) ----
#
# Build a spec and let autoprint render it. Inside RStudio /
# Positron the HTML lands in the viewer pane; inside a
# Quarto / Rmd chunk it inlines under the chunk; at a plain
# console the HTML source is `cat()`-ed.
tabular(
  saf_demo,
  titles = c("Table 14.1.1", "Demographics"),
  footnotes = "Safety Population."
)
#> Warning: Auto-sized columns exceed the available content width.
#> ℹ Natural width 9.48 in; available 9 in.
#> ℹ Columns kept at natural width; the table will overflow. Set
#>   `col_spec(width = ...)` or `preset(width_mode = "fixed")` to
#>   constrain it.
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
#> <div id="tabular_ds9uvuVs7T" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
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
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>Min, Max</td><td>15, 33</td><td>14, 35</td><td>15, 40</td><td>14, 40</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Underweight (&lt;18.5)</td><td>3 (3.5)</td><td>1 (1.4)</td><td>4 (4.2)</td><td>8 (3.1)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Normal (18.5-24.9)</td><td>57 (66.3)</td><td>39 (54.2)</td><td>46 (47.9)</td><td>142 (55.9)</td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Overweight (25-29.9)</td><td>20 (23.3)</td><td>23 (31.9)</td><td>32 (33.3)</td><td>75 (29.5)</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">BMI Category, n (%)</td><td style="border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7.0)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12.5)</td><td style="border-bottom: 0.5pt solid #212529;">13 (13.5)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Safety Population.</p>
#> </div></div>

# ---- Example 2: Force the cli-tree structural view ----
#
# The cli-tree summary shows props at a glance. Useful for
# debugging spec composition without paying the HTML render
# cost.
spec <- tabular(saf_demo, titles = "Demographics") |>
  cols(variable = col_spec(usage = "group", label = "Characteristic"))

print(spec, output = "cli")
#> 
#> ── <tabular_spec> 
#> Data: 35 rows x 6 columns
#> Titles (1):
#> 1. "Demographics"
#> Config: cols (1)
```
