# Convert a cards ARD to a wide display data.frame

`pivot_across()` is tabular's input-side helper: it consumes a long
Analysis Results Data (ARD) data frame (typically produced by
[`cards::ard_stack()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack.html)
or
[`cards::ard_stack_hierarchical()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack_hierarchical.html))
and returns a wide display data.frame ready to pass to
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).

## Usage

``` r
pivot_across(
  data,
  statistic = list(continuous = "{mean} ({sd})", categorical = "{n} ({p}%)"),
  column = NULL,
  label = NULL,
  overall = "Total",
  decimals = NULL,
  fmt = NULL
)
```

## Arguments

- data:

  *Long ARD input data.* `<data.frame>: required`. At minimum needs
  `stat_name` and `stat`. Cards-style group columns (`group1`,
  `group1_level`, ...) and `variable` / `variable_level` are
  auto-detected. Tibbles / `card` objects / arrow tables are coerced via
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- statistic:

  *Format spec for cell composition.*
  `<character(1) | named list>: required`. Combines one or more ARD
  stats into one display cell. Three accepted forms — each illustrated
  below. Inside a format string, `{stat_name}` substitutes that stat's
  value from the ARD (for example, `"{n} ({p}%)"` interpolates the `n`
  and `p` stats into a `"53 (62%)"` cell). The lookup order when a value
  is needed for a variable is: per-variable -\> per-context -\>
  `default` -\> the literal `"{n}"`.

  ### Form 1: single string

  One format string applied to every variable regardless of context. Use
  when your ARD is homogeneous (e.g. all categorical).

      # Every variable rendered as "n (p%)" — categorical-only slice.
      cat_only <- saf_demo_card[saf_demo_card$context == "categorical", ]
      pivot_across(
        cat_only,
        statistic = "{n} ({p}%)"
      )

  ### Form 2: named list by context

  Different formats for continuous vs categorical contexts. This is the
  typical clinical-table form because demographics mix the two.

      # AGE (continuous) -> "75.2 (8.59)"; SEX (categorical) -> "53 (62%)"
      pivot_across(
        saf_demo_card,
        statistic = list(
          continuous  = "{mean} ({sd})",
          categorical = "{n} ({p}%)"
        )
      )

  ### Form 3: named list by variable

  Override on a per-variable basis; fall back to `default` or context.
  Use when one variable needs a custom format.

      # AGE shows just the mean; SEX / RACE keep the categorical default.
      pivot_across(
        saf_demo_card,
        statistic = list(
          AGE         = "{mean}",
          categorical = "{n} ({p}%)",
          default     = "{mean} ({sd})"
        )
      )

  ### Multi-row continuous spec

  Any single entry can itself be a **named character vector** — each
  element becomes one display row, with the name as the row label. Use
  for `N / Mean (SD) / Median / Min, Max`-style blocks.

      pivot_across(
        saf_demo_card,
        statistic = list(
          continuous = c(
            N           = "{N}",
            "Mean (SD)" = "{mean} ({sd})",
            Median      = "{median}",
            "Min, Max"  = "{min}, {max}"
          ),
          categorical = "{n} ({p}%)"
        )
      )

- column:

  *Grouping column whose unique values become arms.*
  `<character(1) | NULL>: default NULL`. `NULL` auto-detects from the
  ARD's `group1` value or — for renamed input — picks the single
  non-standard column. Pass a string when multiple group columns exist.

- label:

  *Variable-name to display-label map.*
  `<character> | NULL: default NULL`. Named character vector mapping
  variable names to display labels (e.g.
  `c(AGE = "Age (years)", SEX = "Sex")`). Applies to `variable`, `soc`,
  and `label` columns of the output. `NULL` leaves the upstream variable
  names verbatim.

- overall:

  *Column name for `NA`-arm (overall / total) rows.*
  `<character(1) | NULL>: default "Total"`. Pass `NULL` to drop overall
  rows entirely (per-arm only output).

- decimals:

  *Per-stat decimal precision.*
  `<named integer | named list>: default `c()“. Accepts two forms:

  - **named integer vector** — global per-stat overrides
    (`c(mean = 1, sd = 2, p = 0)`).

  - **named list** — per-variable plus `.default`
    (`list(AGE = c(mean = 2), .default = c(p = 1))`).

  Built-in defaults apply when neither sets a stat.

- fmt:

  *Per-stat custom formatter functions.*
  `<named list of function>: default `list()“. Each function takes a
  numeric value and returns a character string; overrides built-ins and
  `decimals` for that stat. Useful for p-value styling and other
  domain-specific formatting.

      # p-value formatter: render below-threshold values as "<0.001".
      fmt = list(
        p.value = function(x) {
          ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
        }
      )

## Value

*A wide `data.frame` ready for
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).*
Schema:

- `variable` — variable name (or label after `label = ...`).

- `stat_label` — display-row label.

- One column per arm level (named after the `group1_level` values or the
  renamed arm column).

- `Total` (or whatever `overall` is set to) when applicable.

- Hierarchical ARD adds `soc`, `label`, `row_type` instead of
  `variable`.

Pass the result straight into
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) to
start the render pipeline.

## Details

tabular's package boundary is **display-only**: pre-summarised data in,
rendered file out. `pivot_across()` is the canonical bridge between the
cards aggregation backend and that boundary. It does not aggregate — it
pivots arms to columns, interpolates per-cell display strings from the
stat values, and applies decimal precision. Filtering, weighting, and
aggregation happen upstream in cards or your own data-prep step.

### Zero-suppression (always-on default)

A row whose `n` value equals zero renders the whole cell as the bare `n`
value instead of fully interpolating the format string. For a
categorical level with `n = 0`, the cell shows `"0"`, not `"0 (0.0%)"`.
This is clinical convention — empty cells should read as a single zero,
not advertise a meaningless rate.

**How the default fires (chain of events).** During cell assembly,
before format-string interpolation, the engine checks the row's `n`
stat. If it is zero, the engine short-circuits and returns the formatted
`n` value (`"0"`) as the entire cell — `{p}` is never substituted, so
the `(0.0%)` half of the format string is dropped.

**How to opt out: supply a custom `fmt$n`.** Setting any function under
`fmt$n` is the engine's signal that the user owns the `n` rendering. The
short-circuit is disabled for the whole table; for every row the full
format string interpolates, so `{n}` becomes your formatter's output and
`{p}` becomes the standard percentage. For `n = 0`, that's `"0 (0.0%)"`.

    # Force "0 (0.0%)" for n = 0 rows by attaching a custom n formatter.
    # The body of fmt$n can be the default integer rendering — its
    # presence alone is what disables the zero-suppression branch.
    pivot_across(
      saf_demo_card,
      statistic = list(
        continuous  = "{mean} ({sd})",
        categorical = "{n} ({p}%)"
      ),
      fmt = list(n = function(x) sprintf("%d", as.integer(x)))
    )

### Pharma rounding (always-on default)

A percentage that would otherwise round to `0` (when the value is
positive but smaller than the chosen precision) renders as `<0.1`; one
that would round to `100` (positive but smaller than 100) renders as
`>99.9`. The threshold is precision-aware: `decimals = c(p = 2)`
produces `<0.01` / `>99.99`. This matches the pharma convention of never
claiming exactly `0%` or `100%` when at least one subject contributed.

Override per-stat via `fmt`:

    # Show exact rounded percentages even at the extremes
    pivot_across(
      data,
      statistic = "{n} ({p}%)",
      decimals  = c(p = 1),
      fmt = list(p = function(x) sprintf("%.1f", x * 100))
    )

Your `fmt$p` receives the raw stat value (a proportion between 0 and 1)
and returns the displayed string. The pharma-threshold branch only fires
inside the built-in `p` formatter and the `decimals`-driven path, so any
custom `fmt$p` bypasses it.

## See also

**Pipeline entry consumer:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) —
wraps the wide data frame this helper returns.

**Downstream spec-build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Terminal verbs:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Demographics — long ARD to rendered spec ----
#
# Full pipeline from a `cards::ard_stack()`-style long ARD to a
# sorted `tabular_spec`. The multi-row continuous block (N /
# Mean (SD) / Median / Min, Max) sits above each categorical
# block; decimals are set per-stat (mean 1, sd 2, p 1) to match
# the CDISC convention.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

saf_demo_card |>
  pivot_across(
    statistic = list(
      continuous = c(
        N           = "{N}",
        "Mean (SD)" = "{mean} ({sd})",
        Median      = "{median}",
        "Min, Max"  = "{min}, {max}"
      ),
      categorical = "{n} ({p}%)"
    ),
    decimals = c(mean = 1, sd = 2, p = 1, median = 1, min = 0, max = 0),
    label    = c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
  ) |>
  tabular(
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
    Placebo    = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal"
    ),
    `Xanomeline Low Dose` = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal"
    ),
    `Xanomeline High Dose` = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal"
    ),
    Total = col_spec(
      label = sprintf("Total\nN=%d", n["Total"]),
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
#> <div id="tabular_WxNDvhncrU" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
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
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  N</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Mean (SD)</td><td class="text-right"> 75.2 (8.59) </td><td class="text-right"> 73.8 (7.94) </td><td class="text-right"> 76.0 (8.11) </td><td class="text-right"> 75.1 (8.25) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Median</td><td class="text-right"> 76.0        </td><td class="text-right"> 75.5        </td><td class="text-right"> 78.0        </td><td class="text-right"> 77.0        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Min, Max</td><td class="text-right"> 52  , 89    </td><td class="text-right"> 56  , 88    </td><td class="text-right"> 51  , 88    </td><td class="text-right"> 51  , 89    </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>WEIGHT</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  N</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Mean (SD)</td><td class="text-right"> 62.8 (12.77)</td><td class="text-right"> 69.5 (14.35)</td><td class="text-right"> 68.0 (14.50)</td><td class="text-right"> 66.6 (14.13)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Median</td><td class="text-right"> 60.6        </td><td class="text-right"> 69.0        </td><td class="text-right"> 66.7        </td><td class="text-right"> 66.7        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Min, Max</td><td class="text-right"> 34  , 86    </td><td class="text-right"> 44  , 108   </td><td class="text-right"> 42  , 106   </td><td class="text-right"> 34  , 108   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>HEIGHT</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  N</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Mean (SD)</td><td class="text-right">162.6 (11.52)</td><td class="text-right">165.9 (10.28)</td><td class="text-right">163.7 (10.30)</td><td class="text-right">163.9 (10.76)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Median</td><td class="text-right">162.6        </td><td class="text-right">165.1        </td><td class="text-right">162.6        </td><td class="text-right">162.8        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Min, Max</td><td class="text-right">137  , 185   </td><td class="text-right">146  , 190   </td><td class="text-right">136  , 196   </td><td class="text-right">136  , 196   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  N</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Mean (SD)</td><td class="text-right"> 23.6 (3.67) </td><td class="text-right"> 25.2 (3.97) </td><td class="text-right"> 25.2 (4.40) </td><td class="text-right"> 24.7 (4.09) </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Median</td><td class="text-right"> 23.4        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.2        </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Min, Max</td><td class="text-right"> 15  , 33    </td><td class="text-right"> 14  , 35    </td><td class="text-right"> 15  , 40    </td><td class="text-right"> 14  , 40    </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>AGEGR1</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  18-64</td><td class="text-right"> 14 (16.3%)  </td><td class="text-right"> 11 (15.3%)  </td><td class="text-right">  8 ( 8.3%)  </td><td class="text-right"> 33 (13.0%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  &gt;64</td><td class="text-right"> 72 (83.7%)  </td><td class="text-right"> 61 (84.7%)  </td><td class="text-right"> 88 (91.7%)  </td><td class="text-right">221 (87.0%)  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  F</td><td class="text-right"> 53 (61.6%)  </td><td class="text-right"> 35 (48.6%)  </td><td class="text-right"> 55 (57.3%)  </td><td class="text-right">143 (56.3%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  M</td><td class="text-right"> 33 (38.4%)  </td><td class="text-right"> 37 (51.4%)  </td><td class="text-right"> 41 (42.7%)  </td><td class="text-right">111 (43.7%)  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  WHITE</td><td class="text-right"> 78 (90.7%)  </td><td class="text-right"> 62 (86.1%)  </td><td class="text-right"> 90 (93.8%)  </td><td class="text-right">230 (90.6%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  BLACK OR AFRICAN AMERICAN</td><td class="text-right">  8 ( 9.3%)  </td><td class="text-right">  9 (12.5%)  </td><td class="text-right">  6 ( 6.2%)  </td><td class="text-right"> 23 ( 9.1%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  ASIAN</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right">  0          </td><td class="text-right">  1 ( 1.4%)  </td><td class="text-right">  0          </td><td class="text-right">  1 ( 0.4%)  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>ETHNIC</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  HISPANIC OR LATINO</td><td class="text-right">  3 ( 3.5%)  </td><td class="text-right">  3 ( 4.2%)  </td><td class="text-right">  6 ( 6.2%)  </td><td class="text-right"> 12 ( 4.7%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  NOT HISPANIC OR LATINO</td><td class="text-right"> 83 (96.5%)  </td><td class="text-right"> 69 (95.8%)  </td><td class="text-right"> 90 (93.8%)  </td><td class="text-right">242 (95.3%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  NOT REPORTED</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI_CAT</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Underweight (&lt;18.5)</td><td class="text-right">  3 ( 3.5%)  </td><td class="text-right">  1 ( 1.4%)  </td><td class="text-right">  4 ( 4.2%)  </td><td class="text-right">  8 ( 3.2%)  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Normal (18.5-24.9)</td><td class="text-right"> 57 (66.3%)  </td><td class="text-right"> 39 (54.2%)  </td><td class="text-right"> 46 (48.4%)  </td><td class="text-right">142 (56.1%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">  Overweight (25-29.9)</td><td class="text-right"> 20 (23.3%)  </td><td class="text-right"> 23 (31.9%)  </td><td class="text-right"> 32 (33.7%)  </td><td class="text-right"> 75 (29.6%)  </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">  Obese (&gt;=30)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  6 ( 7.0%)  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  9 (12.5%)  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 13 (13.7%)  </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 28 (11.1%)  </td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Percentages based on N per treatment group.</p>
#> </div></div>

# ---- Example 2: Hierarchical SOC/PT AE table ----
#
# Hierarchical `cards::ard_stack_hierarchical()` output threaded
# through `pivot_across()`. The hierarchical ARD emits a
# (soc, label, row_type) triple plus one stat row per (arm, SOC, PT);
# `pivot_across()` folds the arm dimension to columns and preserves
# the hierarchy markers. Derive `indent_level` from `row_type` so
# `col_spec(indent_by = "indent_level")` drives the SOC -> PT
# indent on the `label` column.
wide <- saf_aesocpt_card |>
  pivot_across(statistic = "{n} ({p}%)")
wide$indent_level <- as.integer(wide$row_type == "pt")

tabular(
  wide,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = c(
    "Subjects are counted once per SOC and once per PT.",
    "Percentages based on N per treatment group."
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    Placebo  = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal"
    ),
    `Xanomeline Low Dose` = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal"
    ),
    `Xanomeline High Dose` = col_spec(
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
#> <div id="tabular_oBF7QxMz0h" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>SOC / PT</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Drug 50<br/>N=96</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>..ard_hierarchical_overall..</td><td class="text-right">52 (60%)</td><td class="text-right">66 (92%)</td><td class="text-right">81 (84%)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td class="text-right">19 (22%)</td><td class="text-right">35 (49%)</td><td class="text-right">36 (38%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td class="text-right"> 8 ( 9%)</td><td class="text-right">25 (35%)</td><td class="text-right">21 (22%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td class="text-right"> 8 ( 9%)</td><td class="text-right">14 (19%)</td><td class="text-right">14 (15%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td class="text-right"> 5 ( 6%)</td><td class="text-right"> 8 (11%)</td><td class="text-right">13 (14%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 8 (11%)</td><td class="text-right"> 4 ( 4%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 5 ( 7%)</td><td class="text-right"> 6 ( 6%)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td class="text-right">15 (17%)</td><td class="text-right">30 (42%)</td><td class="text-right">36 (38%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td class="text-right"> 6 ( 7%)</td><td class="text-right">21 (29%)</td><td class="text-right">23 (24%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td class="text-right"> 3 ( 3%)</td><td class="text-right">14 (19%)</td><td class="text-right">13 (14%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td class="text-right"> 5 ( 6%)</td><td class="text-right"> 7 (10%)</td><td class="text-right"> 9 ( 9%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 9 (12%)</td><td class="text-right"> 9 ( 9%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 5 ( 7%)</td><td class="text-right"> 5 ( 5%)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td class="text-right">13 (15%)</td><td class="text-right">17 (24%)</td><td class="text-right">12 (12%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td class="text-right"> 9 (10%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 5 ( 5%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 6 ( 8%)</td><td class="text-right"> 4 ( 4%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 6 ( 8%)</td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td class="text-right"> 0      </td><td class="text-right"> 4 ( 6%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td class="text-right"> 6 ( 7%)</td><td class="text-right">17 (24%)</td><td class="text-right">18 (19%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td class="text-right"> 2 ( 2%)</td><td class="text-right">10 (14%)</td><td class="text-right"> 9 ( 9%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 5 ( 7%)</td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td class="text-right"> 0      </td><td class="text-right"> 2 ( 3%)</td><td class="text-right"> 5 ( 5%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td class="text-right"> 7 ( 8%)</td><td class="text-right">14 (19%)</td><td class="text-right">12 (12%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 8 (11%)</td><td class="text-right"> 7 ( 7%)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td class="text-right"> 4 ( 5%)</td><td class="text-right"> 4 ( 6%)</td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 2 ( 3%)</td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td class="text-right">12 (14%)</td><td class="text-right">11 (15%)</td><td class="text-right"> 6 ( 6%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 6 ( 8%)</td><td class="text-right"> 4 ( 4%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td class="text-right"> 6 ( 7%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td class="text-right"> 5 ( 6%)</td><td class="text-right"> 9 (12%)</td><td class="text-right"> 8 ( 8%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 5 ( 7%)</td><td class="text-right"> 5 ( 5%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td class="text-right"> 0      </td><td class="text-right"> 2 ( 3%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td class="text-right"> 7 ( 8%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 9 ( 9%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 0      </td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 2 ( 3%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td class="text-right"> 0      </td><td class="text-right"> 0      </td><td class="text-right"> 3 ( 3%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td class="text-right"> 3 ( 3%)</td><td class="text-right"> 5 ( 7%)</td><td class="text-right"> 6 ( 6%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td><td class="text-right"> 2 ( 2%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td></tr>
#> <tr><td>INVESTIGATIONS</td><td class="text-right"> 5 ( 6%)</td><td class="text-right"> 3 ( 4%)</td><td class="text-right"> 4 ( 4%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td class="text-right"> 4 ( 5%)</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td class="text-right"> 2 ( 2%)</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td class="text-right"> 1 ( 1%)</td><td class="text-right"> 0      </td><td class="text-right"> 1 ( 1%)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0      </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1%)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0      </td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects are counted once per SOC and once per PT.</p>
#> <p class="tabular-footnote">Percentages based on N per treatment group.</p>
#> </div></div>

# ---- Example 3: Hierarchical ARD (SOC / PT) ----
#
# `saf_aesocpt_card` carries an `ard_stack_hierarchical` shape with
# two grouping variables (AEBODSYS / AEDECOD). `pivot_across()`
# recognises the hierarchical structure and emits dedicated `soc`,
# `label`, and `row_type` columns so the SOC -> PT nesting survives
# the pivot. The result is ready for `tabular()` plus `sort_rows()`.
head(saf_aesocpt_card, 3)
#> {cards} data frame: 3 x 10
#>   group1 group1_level group2 group2_level variable variable_level
#> 1   <NA>                <NA>                TRT01A        Placebo
#> 2   <NA>                <NA>                TRT01A        Placebo
#> 3   <NA>                <NA>                TRT01A        Placebo
#>   stat_name stat_label  stat
#> 1         n          n    86
#> 2         N          N   254
#> 3         p          % 0.339
#> ℹ 1 more variable: context

wide <- saf_aesocpt_card |>
  pivot_across(statistic = "{n} ({p}%)")
head(wide, 3)
#>                                      soc
#> 1           ..ard_hierarchical_overall..
#> 2 SKIN AND SUBCUTANEOUS TISSUE DISORDERS
#> 3 SKIN AND SUBCUTANEOUS TISSUE DISORDERS
#>                                    label row_type  Placebo
#> 1           ..ard_hierarchical_overall..  overall 52 (60%)
#> 2 SKIN AND SUBCUTANEOUS TISSUE DISORDERS      soc 19 (22%)
#> 3                               PRURITUS       pt   8 (9%)
#>   Xanomeline High Dose Xanomeline Low Dose
#> 1             66 (92%)            81 (84%)
#> 2             35 (49%)            36 (38%)
#> 3             25 (35%)            21 (22%)

# ---- Example 4: Multi-row continuous spec + label re-labelling ----
#
# `statistic = c(<label> = <template>, ...)` produces one display
# row per named entry — the canonical "N / Mean (SD) / Median /
# Min, Max" block for continuous variables. `label = c(...)`
# renames the variable headings emitted into the wide output.
saf_demo_card |>
  pivot_across(
    statistic = list(
      continuous = c(
        N            = "{N}",
        "Mean (SD)"  = "{mean} ({sd})",
        Median       = "{median}",
        "Q1, Q3"     = "{p25}, {p75}",
        "Min, Max"   = "{min}, {max}"
      ),
      categorical = "{n} ({p}%)"
    ),
    label = c(
      AGE    = "Age (years)",
      WEIGHT = "Weight (kg)",
      HEIGHT = "Height (cm)",
      BMI    = "BMI (kg/m^2)"
    )
  )
#>        variable                         stat_label       Placebo
#> 1   Age (years)                                  N            86
#> 2   Age (years)                          Mean (SD)   75.2 (8.59)
#> 3   Age (years)                             Median          76.0
#> 4   Age (years)                             Q1, Q3    69.0, 82.0
#> 5   Age (years)                           Min, Max    52.0, 89.0
#> 6   Weight (kg)                                  N            86
#> 7   Weight (kg)                          Mean (SD)  62.8 (12.77)
#> 8   Weight (kg)                             Median          60.6
#> 9   Weight (kg)                             Q1, Q3    53.5, 74.4
#> 10  Weight (kg)                           Min, Max    34.0, 86.2
#> 11  Height (cm)                                  N            86
#> 12  Height (cm)                          Mean (SD) 162.6 (11.52)
#> 13  Height (cm)                             Median         162.6
#> 14  Height (cm)                             Q1, Q3  153.7, 171.4
#> 15  Height (cm)                           Min, Max  137.2, 185.4
#> 16 BMI (kg/m^2)                                  N            86
#> 17 BMI (kg/m^2)                          Mean (SD)   23.6 (3.67)
#> 18 BMI (kg/m^2)                             Median          23.4
#> 19 BMI (kg/m^2)                             Q1, Q3    21.2, 25.7
#> 20 BMI (kg/m^2)                           Min, Max    15.1, 33.3
#> 21       AGEGR1                              18-64      14 (16%)
#> 22       AGEGR1                                >64      72 (84%)
#> 23          SEX                                  F      53 (62%)
#> 24          SEX                                  M      33 (38%)
#> 25         RACE                              WHITE      78 (91%)
#> 26         RACE          BLACK OR AFRICAN AMERICAN        8 (9%)
#> 27         RACE                              ASIAN             0
#> 28         RACE   AMERICAN INDIAN OR ALASKA NATIVE             0
#> 29       ETHNIC                 HISPANIC OR LATINO        3 (3%)
#> 30       ETHNIC             NOT HISPANIC OR LATINO      83 (97%)
#> 31       ETHNIC                       NOT REPORTED             0
#> 32      BMI_CAT                Underweight (<18.5)        3 (3%)
#> 33      BMI_CAT                 Normal (18.5-24.9)      57 (66%)
#> 34      BMI_CAT               Overweight (25-29.9)      20 (23%)
#> 35      BMI_CAT                       Obese (>=30)        6 (7%)
#>    Xanomeline High Dose Xanomeline Low Dose         Total
#> 1                    72                  96           254
#> 2           73.8 (7.94)         76.0 (8.11)   75.1 (8.25)
#> 3                  75.5                78.0          77.0
#> 4            70.0, 79.0          71.0, 82.0    70.0, 81.0
#> 5            56.0, 88.0          51.0, 88.0    51.0, 89.0
#> 6                    72                  95           253
#> 7          69.5 (14.35)        68.0 (14.50)  66.6 (14.13)
#> 8                  69.0                66.7          66.7
#> 9            56.7, 80.3          55.8, 78.5    55.3, 77.1
#> 10          44.5, 108.0         41.7, 106.1   34.0, 108.0
#> 11                   72                  96           254
#> 12        165.9 (10.28)       163.7 (10.30) 163.9 (10.76)
#> 13                165.1               162.6         162.8
#> 14         157.5, 172.9        157.5, 170.2  156.2, 171.4
#> 15         146.1, 190.5        135.9, 195.6  135.9, 195.6
#> 16                   72                  95           253
#> 17          25.2 (3.97)         25.2 (4.40)   24.7 (4.09)
#> 18                 24.8                24.8          24.2
#> 19           22.7, 27.6          22.2, 28.3    21.9, 27.3
#> 20           13.7, 34.6          15.3, 40.2    13.7, 40.2
#> 21             11 (15%)              8 (8%)      33 (13%)
#> 22             61 (85%)            88 (92%)     221 (87%)
#> 23             35 (49%)            55 (57%)     143 (56%)
#> 24             37 (51%)            41 (43%)     111 (44%)
#> 25             62 (86%)            90 (94%)     230 (91%)
#> 26              9 (12%)              6 (6%)       23 (9%)
#> 27                    0                   0             0
#> 28               1 (1%)                   0        1 (0%)
#> 29               3 (4%)              6 (6%)       12 (5%)
#> 30             69 (96%)            90 (94%)     242 (95%)
#> 31                    0                   0             0
#> 32               1 (1%)              4 (4%)        8 (3%)
#> 33             39 (54%)            46 (48%)     142 (56%)
#> 34             23 (32%)            32 (34%)      75 (30%)
#> 35              9 (12%)            13 (14%)      28 (11%)
```
