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

#tabular-0870887ddb { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-0870887ddb .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-0870887ddb .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-0870887ddb .tabular-pad { margin: 0; line-height: 1; }
#tabular-0870887ddb .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-0870887ddb .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-0870887ddb .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-0870887ddb .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-0870887ddb .tabular-table th, #tabular-0870887ddb .tabular-table td { padding: .35rem .6rem; }
#tabular-0870887ddb .tabular-table td { text-align: left; vertical-align: top; }
#tabular-0870887ddb .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-0870887ddb .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-0870887ddb .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-0870887ddb .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-0870887ddb .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-0870887ddb .tabular-table tbody tr td { border-top: none; }
#tabular-0870887ddb .tabular-band { text-align: center; }
#tabular-0870887ddb .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-0870887ddb .tabular-subgroup-label { font-weight: 600; }
#tabular-0870887ddb .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-0870887ddb .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-0870887ddb .text-left { text-align: left; }
#tabular-0870887ddb .text-center { text-align: center; }
#tabular-0870887ddb .text-right { text-align: right; }
#tabular-0870887ddb .tabular-table thead th.text-left { text-align: left; }
#tabular-0870887ddb .tabular-table thead th.text-center { text-align: center; }
#tabular-0870887ddb .tabular-table thead th.text-right { text-align: right; }
#tabular-0870887ddb .valign-top { vertical-align: top; }
#tabular-0870887ddb .valign-middle { vertical-align: middle; }
#tabular-0870887ddb .valign-bottom { vertical-align: bottom; }
#tabular-0870887ddb .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-0870887ddb .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-0870887ddb .tabular-page-break-row { display: none; }
#tabular-0870887ddb { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-0870887ddb .tabular-page-header, #tabular-0870887ddb .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-0870887ddb .tabular-page-header { margin-bottom: 1rem; }
#tabular-0870887ddb .tabular-page-footer { margin-top: 1rem; }
#tabular-0870887ddb .tabular-page-header-left, #tabular-0870887ddb .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-0870887ddb .tabular-page-header-center, #tabular-0870887ddb .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-0870887ddb .tabular-page-header-right, #tabular-0870887ddb .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-0870887ddb .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-0870887ddb .tabular-table tr { page-break-inside: avoid; } #tabular-0870887ddb .tabular-page-header, #tabular-0870887ddb .tabular-page-footer { display: none; } #tabular-0870887ddb .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-0870887ddb .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-0870887ddb .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population (N=254)
 



Statistic
```
