# Attach per-column specifications

Add
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
entries to a `tabular_spec`. Each named argument is one column: the name
is the input column in `.spec@data` and the value is the `col_spec`
carrying that column's display attributes (usage, label, format,
alignment, width, visibility, NA text). Columns not mentioned get a
default
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
(usage = display) at engine-validate time.

## Usage

``` r
cols(.spec, ...)
```

## Arguments

- .spec:

  *The `tabular_spec` to extend.* `<tabular_spec>: required`.
  Dot-prefixed so R's partial argument matching cannot accidentally bind
  a short user-supplied name (e.g. `s`, `sp`) in `...` to the spec slot.
  Pipe input (`tabular(...) |> cols(...)`) works the normal way — the
  spec is supplied positionally.

- ...:

  *Named `col_spec` objects, one per column.* Each name is the input
  column name in `.spec@data`. Names must match an existing column —
  pre-compute derived columns upstream with
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  (or equivalent) before
  [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).

  **Restriction:** Names must be unique within a single `cols()` call
  (duplicates warn; "last value wins"). **Tip:** To override an
  attribute already declared, use a second `cols()` call downstream and
  let the merge rule apply.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

## Details

**Sparse declaration.** Declare only the columns whose attributes differ
from the default — a typical pipeline uses one `cols()` call with one
entry per non-default column.

**Within-call duplicates warn.** A duplicate name inside one `cols()`
call warns and "last value wins". To intentionally override an
attribute, use a second `cols()` call downstream and let the merge rule
below apply.

## Repeat-call merge semantics

When `cols()` is called more than once for the same column, the engine
merges the new `col_spec` into the existing one field-by- field. A
non-default value on the new spec overrides; a default- valued field
leaves the existing field intact. This lets you build a column's spec in
stages — declare the label-and-alignment block up front, add the width
once you know it fits, then attach a sort key, all without re-stating
earlier attributes. Essential when generating specs programmatically
(looping over arms, layering a house-style helper).

Default values that do NOT override the existing field:

|           |                                |
|-----------|--------------------------------|
| field     | default that does not override |
| `usage`   | `NA_character_`                |
| `label`   | `NA_character_`                |
| `format`  | `NULL`                         |
| `visible` | `TRUE`                         |
| `width`   | `NA_real_`                     |
| `align`   | `NA_character_`                |
| `na_text` | `""`                           |

    # Three-stage build: label/usage first, alignment second, width
    # third. Each stage leaves earlier fields intact.
    tabular(saf_demo) |>
      cols(variable = col_spec(usage = "group", label = "Parameter")) |>
      cols(variable = col_spec(align = "left")) |>
      cols(variable = col_spec(width = 2.0))
    # Result: variable has usage="group", label="Parameter",
    #         align="left", width=2.0 — all four fields set.

## See also

**Companion constructor:**
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
builds the per-column DSL object that `cols()` attaches.

**Sibling build verbs:**
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Demographics with arm BigN inline in headers ----
#
# Demographics table where the row-label columns sit on the left
# and the four treatment-arm columns embed BigN in the header
# label (drawn inline from the bundled `saf_n` data frame). Every
# arm column is decimal-aligned so mixed-format cells like
# "5 (3.2%)" line up on the decimal mark.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Percentages based on N per treatment group."
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
  ) |>
  sort_rows(by = c("variable", "stat_label"))
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
#> <div id="tabular_1neMYlWKqm" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
#> <h1 class="tabular-title">Demographics and Baseline Characteristics</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age (years)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 75.2 (8.59) </td><td class="text-right"> 73.8 (7.94) </td><td class="text-right"> 76.0 (8.11) </td><td class="text-right"> 75.1 (8.25) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 76.0        </td><td class="text-right"> 75.5        </td><td class="text-right"> 78.0        </td><td class="text-right"> 77.0        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 52  , 89    </td><td class="text-right"> 56  , 88    </td><td class="text-right"> 51  , 88    </td><td class="text-right"> 51  , 89    </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 69.2, 81.8  </td><td class="text-right"> 70.5, 79.0  </td><td class="text-right"> 71.0, 82.0  </td><td class="text-right"> 70.0, 81.0  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age Group, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">18-64</td><td class="text-right"> 14 (16.3)   </td><td class="text-right"> 11 (15.3)   </td><td class="text-right">  8 ( 8.3)   </td><td class="text-right"> 33 (13.0)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">&gt;64</td><td class="text-right"> 72 (83.7)   </td><td class="text-right"> 61 (84.7)   </td><td class="text-right"> 88 (91.7)   </td><td class="text-right">221 (87.0)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI (kg/m^2)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 23.6 (3.67) </td><td class="text-right"> 25.2 (3.97) </td><td class="text-right"> 25.2 (4.40) </td><td class="text-right"> 24.7 (4.09) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 23.4        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.2        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 15  , 33    </td><td class="text-right"> 14  , 35    </td><td class="text-right"> 15  , 40    </td><td class="text-right"> 14  , 40    </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 21.2, 25.6  </td><td class="text-right"> 22.7, 27.6  </td><td class="text-right"> 22.3, 28.2  </td><td class="text-right"> 21.9, 27.3  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI Category, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Normal (18.5-24.9)</td><td class="text-right"> 57 (66.3)   </td><td class="text-right"> 39 (54.2)   </td><td class="text-right"> 46 (47.9)   </td><td class="text-right">142 (55.9)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Obese (&gt;=30)</td><td class="text-right">  6 ( 7.0)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right"> 13 (13.5)   </td><td class="text-right"> 28 (11.0)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Overweight (25-29.9)</td><td class="text-right"> 20 (23.3)   </td><td class="text-right"> 23 (31.9)   </td><td class="text-right"> 32 (33.3)   </td><td class="text-right"> 75 (29.5)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Underweight (&lt;18.5)</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  4 ( 4.2)   </td><td class="text-right">  8 ( 3.1)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Ethnicity, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HISPANIC OR LATINO</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  3 ( 4.2)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 12 ( 4.7)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT HISPANIC OR LATINO</td><td class="text-right"> 83 (96.5)   </td><td class="text-right"> 69 (95.8)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">242 (95.3)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT REPORTED</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Height (cm)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right">162.6 (11.52)</td><td class="text-right">165.9 (10.28)</td><td class="text-right">163.7 (10.30)</td><td class="text-right">163.9 (10.76)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right">162.6        </td><td class="text-right">165.1        </td><td class="text-right">162.6        </td><td class="text-right">162.8        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right">137  , 185   </td><td class="text-right">146  , 190   </td><td class="text-right">136  , 196   </td><td class="text-right">136  , 196   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right">154.0, 171.1 </td><td class="text-right">157.5, 172.8 </td><td class="text-right">157.5, 170.2 </td><td class="text-right">156.2, 171.4 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right">  0          </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  0          </td><td class="text-right">  1 ( 0.4)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ASIAN</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLACK OR AFRICAN AMERICAN</td><td class="text-right">  8 ( 9.3)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 23 ( 9.1)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">WHITE</td><td class="text-right"> 78 (90.7)   </td><td class="text-right"> 62 (86.1)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">230 (90.6)   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">F</td><td class="text-right"> 53 (61.6)   </td><td class="text-right"> 35 (48.6)   </td><td class="text-right"> 55 (57.3)   </td><td class="text-right">143 (56.3)   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">M</td><td class="text-right"> 33 (38.4)   </td><td class="text-right"> 37 (51.4)   </td><td class="text-right"> 41 (42.7)   </td><td class="text-right">111 (43.7)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Weight (kg)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 62.8 (12.77)</td><td class="text-right"> 69.5 (14.35)</td><td class="text-right"> 68.0 (14.50)</td><td class="text-right"> 66.6 (14.13)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 60.6        </td><td class="text-right"> 69.0        </td><td class="text-right"> 66.7        </td><td class="text-right"> 66.7        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 34  , 86    </td><td class="text-right"> 44  , 108   </td><td class="text-right"> 42  , 106   </td><td class="text-right"> 34  , 108   </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 53.6, 74.2  </td><td class="text-right"> 56.9,  80.3 </td><td class="text-right"> 56.0,  78.2 </td><td class="text-right"> 55.3,  77.1 </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">n</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 86          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 72          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">253          </td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Percentages based on N per treatment group.</p>
#> </div></div>

# ---- Example 2: BOR table with CDISC factor ordering and hidden helper ----
#
# Best Overall Response table where `stat_label` carries the
# canonical CDISC factor levels (driving the sort) and `row_type`
# is hidden — present in the data for the sort, absent from the
# rendered output via `col_spec(visible = FALSE)`.
bor_levels <- c(
  "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
  "Objective Response Rate (CR + PR)",
  "Disease Control Rate (CR + PR + SD)"
)
eff <- eff_resp
eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
ne <- stats::setNames(eff_n$n, eff_n$arm_short)

tabular(
  eff,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  ),
  footnotes = "Response per RECIST 1.1, investigator assessment."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Response"),
    row_type   = col_spec(visible = FALSE),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]), align = "decimal")
  ) |>
  sort_rows(by = "stat_label")
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
#> <div id="tabular_LGGmrFe2kG" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=84</th><th class="text-center">Drug 100<br/>N=84</th><th>groupid</th><th>group_label</th></tr>
#> </thead>
#> <tbody>
#> <tr><td class="text-right"> 1 (1.2)   </td><td class="text-right"> 1 (1.2)   </td><td class="text-right"> 1 (1.2)   </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 1 (1.2)   </td><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 1 (1.2)   </td><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td class="text-right"> 1 (1.2)   </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 0         </td><td class="text-right"> 0         </td><td class="text-right"> 1 (1.2)   </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 0         </td><td class="text-right"> 1 (1.2)   </td><td class="text-right"> 0         </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right">83 (96.5)  </td><td class="text-right">82 (97.6)  </td><td class="text-right">81 (96.4)  </td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td class="text-right"> 2   (2.3) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 1   (1.2) </td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td class="text-right">( 0.3, 8.1)</td><td class="text-right">( 0.0, 6.5)</td><td class="text-right">( 0.0, 6.5)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td class="text-right"> 3   (3.5) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 1   (1.2) </td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td class="text-right">( 0.7, 9.9)</td><td class="text-right">( 0.0, 6.5)</td><td class="text-right">( 0.0, 6.5)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td class="text-right"> 3   (3.5) </td><td class="text-right"> 1   (1.2) </td><td class="text-right"> 2   (2.4) </td><td>4</td><td>Disease Control Rate</td></tr>
#> <tr><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.7, 9.9)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.0, 6.5)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">( 0.3, 8.3)</td><td style="border-bottom: 0.5pt solid #212529;">4</td><td style="border-bottom: 0.5pt solid #212529;">Disease Control Rate</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Response per RECIST 1.1, investigator assessment.</p>
#> </div></div>

# ---- Example 3: AE-by-SOC/PT with indented label + repeat-call merge ----
#
# `label` carries SOC text on SOC rows and PT text on PT rows;
# `indent_by = "indent_level"` indents the PT rows one level under
# their SOC. `soc`, `row_type`, and `n_total` ride along as hidden
# sort keys. A second `cols()` call later in the chain adds widths
# once the user knows the page geometry; the repeat-call merge
# preserves prior attributes (label, indent_by, align, visible)
# without restating them.
ae <- saf_aesocpt
ae$n_total <- as.integer(sub(" .*", "", ae$Total))
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))

tabular(
  ae,
  titles = c("Table 14.3.1", "Adverse Events by SOC and Preferred Term")
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100", align = "decimal"),
    Total    = col_spec(label = "Total",    align = "decimal")
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
  # Second `cols()` call: add widths after the rest of the spec
  # is built. Repeat-call merge preserves prior attributes.
  cols(
    label    = col_spec(width = "2.5in"),
    placebo  = col_spec(width = "0.9in"),
    drug_50  = col_spec(width = "0.9in"),
    drug_100 = col_spec(width = "0.9in"),
    Total    = col_spec(width = "0.9in")
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
#> <div id="tabular_JgwxHhiYO6" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by SOC and Preferred Term</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>SOC / PT</th><th>soc_n</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td class="text-right">52 (60.5)</td><td class="text-right">81 (84.4)</td><td class="text-right">66 (91.7)</td><td class="text-right">199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right"> 90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right"> 81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right"> 29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 22 ( 8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 19 ( 7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Compact AE-overall with pre-derived Active column ----
#
# Drop the per-arm columns and surface only the Total. Pre-compute
# the pooled "Active" column upstream (here `paste0(drug_50, " / ",
# drug_100)`) before piping into `tabular()`; `cols()` then just
# declares each column's display role. The same pattern handles
# any post-pivot derivation (`pivot_across() |> mutate(...) |>
# tabular()`).
ae <- saf_aeoverall
ae$active <- paste0(ae$drug_50, " / ", ae$drug_100)

tabular(
  ae,
  titles = c("Table 14.3.0", "Adverse Event Overview"),
  footnotes = "Active = pooled Drug 50 + Drug 100 columns."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = ""),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    active     = col_spec(label = "Active arms"),
    drug_50    = col_spec(visible = FALSE),
    drug_100   = col_spec(visible = FALSE),
    Total      = col_spec(label = "Total", align = "decimal")
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
#> <div id="tabular_8LSSy0ISrw" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.0</h1>
#> <h1 class="tabular-title">Adverse Event Overview</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th class="text-center">Total</th><th class="text-center">Placebo</th><th>Active arms</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="3"><strong>Any TEAE</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">217 (85.4)</td><td class="text-right">65 (75.6)</td><td>84 (87.5) / 68 (94.4)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>Any Serious AE (SAE)</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">  3 (1.2) </td><td class="text-right"> 0       </td><td>2 (2.1) / 1 (1.4)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>Any AE Related to Study Drug</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">184 (72.4)</td><td class="text-right">43 (50.0)</td><td>77 (80.2) / 64 (88.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>Any AE Leading to Death</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">  3 (1.2) </td><td class="text-right"> 2 (2.3) </td><td>1 (1.0) / 0 (0.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>Any AE Recovered / Resolved</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">157 (61.8)</td><td class="text-right">47 (54.7)</td><td>61 (63.5) / 49 (68.1)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>  Maximum severity: Mild</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);"> 77 (30.3)</td><td class="text-right">36 (41.9)</td><td>21 (21.9) / 20 (27.8)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>  Maximum severity: Moderate</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">111 (43.7)</td><td class="text-right">24 (27.9)</td><td>47 (49.0) / 40 (55.6)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="3">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="3"><strong>  Maximum severity: Severe</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;"> 29 (11.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 5 (5.8) </td><td style="border-bottom: 0.5pt solid #212529;">16 (16.7) / 8 (11.1)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Active = pooled Drug 50 + Drug 100 columns.</p>
#> </div></div>
```
