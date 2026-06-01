# Test for tabular S7 class instances

Class predicates returning a single logical indicating whether `x`
inherits from the corresponding tabular S7 class. Use them to gate
user-side code that branches on what a verb has returned, to write
defensive helpers that wrap tabular pipelines, or to assert intermediate
shapes during pipeline debugging.

## Usage

``` r
is_tabular_spec(x)

is_tabular_grid(x)

is_col_spec(x)

is_header_node(x)

is_sort_spec(x)

is_style_node(x)

is_style_layer(x)

is_style_spec(x)

is_pagination_spec(x)

is_preset_spec(x)

is_subgroup_spec(x)

is_inline_ast(x)
```

## Arguments

- x:

  *Object to test.* Any R value. Each predicate returns `TRUE` if `x`
  inherits from the named class, `FALSE` otherwise.

## Value

*A single `TRUE` / `FALSE`.* Use in `if` / `stopifnot` guards, or chain
into validation helpers.

*A length-1 `logical`* — `TRUE` or `FALSE`. Never `NA`.

## Details

Eleven predicates cover the full S7 surface:

|  |  |  |
|----|----|----|
| predicate | tests for | produced by |
| `is_tabular_spec()` | `tabular_spec` | [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) and every build verb |
| `is_tabular_grid()` | `tabular_grid` | [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) |
| `is_col_spec()` | `col_spec` | [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md) |
| `is_header_node()` | `header_node` | [`headers()`](https://vthanik.github.io/tabular/reference/headers.md) (internal nodes) |
| `is_sort_spec()` | `sort_spec` | [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md) |
| `is_style_node()` | `style_node` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (per-cell style) |
| `is_style_predicate()` | `style_predicate` | (legacy) [`style()`](https://vthanik.github.io/tabular/reference/style.md) predicate path |
| `is_style_layer()` | `style_layer` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (one per call) |
| `is_style_spec()` | `style_spec` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (the cascade root) |
| `is_pagination_spec()` | `pagination_spec` | [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md) |
| `is_preset_spec()` | `preset_spec` | [`preset()`](https://vthanik.github.io/tabular/reference/preset.md), [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md) |
| `is_subgroup_spec()` | `subgroup_spec` | [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md) |
| `is_inline_ast()` | `inline_ast` | `parse_inline()` (post-format) |

Predicates never error — they return `FALSE` for `NULL`, vectors,
objects of any other class, and S7 objects from other packages. Use them
at any layer of a user's pipeline without a defensive
[`tryCatch()`](https://rdrr.io/r/base/conditions.html).

## See also

**Class definitions:**
[`tabular_classes`](https://vthanik.github.io/tabular/reference/tabular_classes.md).

**Verbs producing each class:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Gate user-side code on the spec class ----
#
# A user-side helper that pre-validates its input before piping
# into a downstream tabular chain. The predicate returns FALSE
# for any non-spec input without raising, so the helper can emit
# a friendlier error than tabular's own S7 validator would.
add_safety_footnote <- function(spec) {
  if (!is_tabular_spec(spec)) {
    stop("`spec` must be a tabular_spec; build one with tabular().")
  }
  spec
}

demo <- tabular(saf_demo, titles = "Demographics")
is_tabular_spec(demo)         # TRUE
#> [1] TRUE
is_tabular_spec("not a spec") # FALSE — does not raise
#> [1] FALSE
add_safety_footnote(demo)
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
#> <div id="tabular_hP5pWJOAFS" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
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

# ---- Example 2: Assert intermediate shapes during debugging ----
#
# When chaining many verbs, dropping `stopifnot()` between verbs
# gives a clear stack trace if a verb silently returns the wrong
# type. Predicates are cheap (single S7 dispatch each) and never
# error, so they are safe to leave in pipelines during dev.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

spec <- tabular(
  saf_demo,
  titles = c("Table 14.1.1", "Demographics",
             sprintf("Safety Population (N=%d)", n["Total"]))
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
  ) |>
  sort_rows(by = c("variable", "stat_label"))

stopifnot(
  is_tabular_spec(spec),
  is_col_spec(spec@cols[["placebo"]]),
  is_sort_spec(spec@sort)
)

grid <- as_grid(spec)
stopifnot(is_tabular_grid(grid))
```
