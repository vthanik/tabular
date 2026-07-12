# Convert a cards ARD to a wide display data.frame

`pivot_across()` is tabular's input-side helper: it consumes a long
Analysis Results Data (ARD) data frame (typically produced by
`cards::ard_stack()` or `cards::ard_stack_hierarchical()`) and returns a
wide display data.frame ready to pass to
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md).

## Usage

``` r
pivot_across(
  data,
  statistic = list(continuous = "{mean} ({sd})", categorical = "{n} ({p}%)"),
  column = NULL,
  row_group = NULL,
  label = NULL,
  overall = "Total",
  decimals = NULL,
  fmt = NULL,
  aux = NULL
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
      cat_only <- cdisc_saf_demo_ard[cdisc_saf_demo_ard$context == "categorical", ]
      pivot_across(
        cat_only,
        statistic = "{n} ({p}%)"
      )

  ### Form 2: named list by context

  Different formats per context. This is the typical clinical-table form
  because demographics mix continuous and categorical variables.

  **The list names must match the values in the ARD's `context` column
  verbatim.** Which strings appear there depends on how the ARD was
  built:

  - `cards::ard_continuous()` / `ard_categorical()` emit `"continuous"`
    / `"categorical"`.

  - `cards::ard_summary()` / `ard_tabulate()` emit `"summary"` /
    `"tabulate"`.

  So an ARD assembled with
  `ard_stack(ard_summary(...), ard_tabulate(...))` is keyed `summary` /
  `tabulate`, not `continuous` / `categorical`. Inspect
  `unique(ard$context)` when unsure.

      # AGE (continuous) -> "75.2 (8.59)"; SEX (categorical) -> "53 (62%)"
      pivot_across(
        cdisc_saf_demo_ard,
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
        cdisc_saf_demo_ard,
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
        cdisc_saf_demo_ard,
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

  *What runs across the top of the table.*
  `<character | NULL>: default NULL`. A single grouping variable whose
  unique values become arm columns (`NULL` auto-detects from `group1`,
  or picks the single non-standard column of renamed input). Two
  reserved tokens turn the analysis variable into a **column band**:

  - `c(".variable", "<arm>")` — each variable becomes a band of arm
    columns; the statistic entries stack as rows. The cells are combined
    strings (e.g. `"323.9 (106)"`). Emitted columns are named
    `"<variable>..<arm>"`.

  - `c(".variable", ".stat")` — each variable becomes a band whose
    statistic entries become their own columns (the landscape "value and
    change" shell); the arm drops to a leading row stub. Emitted columns
    are named `"<variable>..<stat-entry>"`.

  Anything present in the ARD but not named in `column` (and not in
  `row_group`) stacks as rows. Per-variable `statistic` / `decimals`
  resolve inside each band, so bands may carry different (even
  different-length) stat lists; ragged bands pad with `NA`.

  **Tip:** you reference the emitted column names verbatim in a manual
  [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  call to build the band spanners; pivot_across does not build spanners
  itself.

- row_group:

  *Second, non-column grouping dimension.*
  `<character(1) | NULL>: default NULL`. Names the non-arm group
  variable of a two-variable `.by` (e.g. `SEX` in
  `ard_stack(.by = c(ARM, SEX))`). It widens into a leading row column
  (not a pivoted arm column), so the result composes with
  [`subgroup(by = ...)`](https://vthanik.github.io/tabular/dev/reference/subgroup.md)
  or
  [`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)
  downstream.

  **Why it is required.** cards encodes a crossing factor and a SOC/PT
  hierarchy identically (the second group variable appears in `variable`
  on its by-marginal rows), so the two cannot be told apart
  automatically. Naming `row_group` declares "this is a crossing
  factor": the by-marginal rows are dropped and the flat path is used.
  Leave it `NULL` for a genuine hierarchy.

  **Restriction:** Must name a second grouping variable present in the
  ARD and must differ from `column`.

- label:

  *Variable-name to display-label map.*
  `<character> | NULL: default NULL`. Named character vector mapping
  variable names to display labels (e.g.
  `c(AGE = "Age (years)", SEX = "Sex")`). Applies to `variable`, `soc`,
  and `label` columns of the output. `NULL` leaves the upstream variable
  names verbatim.

  **Renaming the hierarchical "overall" row.** A
  `cards::ard_stack_hierarchical(overall = TRUE)` ARD carries an
  internal `..ard_hierarchical_overall..` sentinel for the grand-total
  ("any event") row. It is relabelled to `"Overall"` by default; map the
  sentinel key to override, e.g.
  `label = c("..ard_hierarchical_overall.." = "TOTAL SUBJECTS WITH AN EVENT")`.
  The raw sentinel never reaches the output at any hierarchy depth.

- overall:

  *Column name for `NA`-arm (overall / total) rows.*
  `<character(1) | NULL>: default "Total"`. Pass `NULL` to drop overall
  rows entirely (per-arm only output).

  **Requirement:** this relabels pooled rows the ARD already carries —
  the `NA`-arm rows cards emits from
  `cards::ard_stack_hierarchical(overall = TRUE)` or an
  `ard_*(.overall = TRUE)`. It does not synthesize a total: cards
  re-runs the calculation with the `by` variable removed, so the pooled
  `n` / `N` / `p` stay internally consistent. With no such rows in the
  input there is no overall column to label.

  **Note:** if a study arm is literally named the same as `overall`
  (default `"Total"`), that arm and the pooled rows collide under one
  label and the pivot warns. Pass a distinct `overall =` or rename the
  arm upstream.

- decimals:

  *Per-stat decimal precision.*
  `<named integer | named list>: default `c()“. Accepts three forms:

  - **named integer vector** — global per-stat overrides
    (`c(mean = 1, sd = 2, p = 0)`).

  - **named list keyed by variable** — per-variable plus `.default`
    (`list(AGE = c(mean = 2), .default = c(p = 1))`).

  - **named list keyed by `row_group` value** — per-group precision in
    one call
    (`list(SYSBP = c(mean = 0, sd = 1), WEIGHT = c(mean = 1), .default = c(mean = 1, sd = 2))`).
    Each entry is a per-token spec (a named numeric vector, or a bare
    scalar applied to every token).

  Built-in defaults apply when none sets a stat.

  **Interaction:** a list `decimals` is read as per-`row_group` only
  when `row_group` is set and every key (apart from `.default`) is one
  of its levels; otherwise it stays per-variable. Within the matched
  group the token falls back group token, then the per-group `.default`
  token, then the built-in default. A group present in the data but
  absent from the list (and NA / ungrouped rows) uses `.default`. If
  `row_group` is `NULL` but the keys match no variable, `pivot_across()`
  errors and asks for a `row_group`.

- fmt:

  *Per-stat custom formatter functions.*
  `<named list of function>: default `list()“. Each function takes a
  numeric value and returns a character string; overrides built-ins and
  `decimals` for that stat. Useful for p-value styling and other
  domain-specific formatting.

- aux:

  *Auxiliary comparison columns from a second ARD.*
  `<named list | NULL>: default NULL`. Each entry is a between-arm
  statistic (difference, hazard ratio, p-value, ...) computed in its own
  ARD and bound on as a trailing column, aligned 1:1 on the `row_group`
  key. The entry name is the column name; reference it in a manual
  [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  call. Each entry is a list:

  - `ard` — the auxiliary ARD (required), one row per `row_group`.

  - `statistic` — its format string (e.g.
    `"{estimate} ({conf.low}, {conf.high})"`); defaults to `"{n}"`.

  - `decimals` / `fmt` — optional, as for the main pivot.

  Entries append left to right. One entry is one column; for several
  comparison columns (estimate then p-value) pass several entries.

  **Requirement:** needs a `row_group`; the auxiliary rows align to the
  main table on it, which must be unique 1:1 on both sides (a
  many-to-many key would silently fabricate rows, so it aborts).

      # p-value formatter: render below-threshold values as "<0.001".
      fmt = list(
        p.value = function(x) {
          ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
        }
      )

## Value

*A wide `data.frame` ready for
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md).*
Schema:

- `variable` — variable name (or label after `label = ...`).

- `stat_label` — display-row label.

- One column per arm level (named after the `group1_level` values or the
  renamed arm column).

- `Total` (or whatever `overall` is set to) when applicable.

- A leading column named after `row_group` when set (the second grouping
  dimension).

- Hierarchical ARD adds `soc`, `label`, `row_type` instead of
  `variable`.

Pass the result straight into
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
to start the render pipeline.

## Details

tabular's package boundary is **display-only**: pre-summarised data in,
rendered file out. `pivot_across()` is the canonical bridge between the
cards aggregation backend and that boundary. It does not aggregate — it
pivots arms to columns, interpolates per-cell display strings from the
stat values, and applies decimal precision. Filtering, weighting, and
aggregation happen upstream in cards or your own data-prep step.

### Key `statistic` by the ARD `context`

`statistic` (and `fmt`) are matched against the ARD's `context` column
verbatim, and that value differs per generating function. Keying by the
wrong name silently drops the format. Inspect `unique(ard$context)`
first and key to match (or pass a single format string / `default =` to
cover everything). When an explicitly-supplied `statistic` matches no
context at all, `pivot_across()` warns rather than silently emitting
`{n}`.

|                                   |                             |
|-----------------------------------|-----------------------------|
| Generating function               | `context` to key on         |
| `cards::ard_summary()`            | `summary`                   |
| `cards::ard_tabulate()`           | `tabulate`                  |
| `cards::ard_continuous()`         | `continuous`                |
| `cards::ard_categorical()`        | `categorical`               |
| `cards::ard_stack_hierarchical()` | `tabulate` + `hierarchical` |
| `cardx::ard_categorical_ci()`     | `proportion_ci`             |
| `cardx::ard_continuous_ci()`      | `continuous_ci`             |

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
      cdisc_saf_demo_ard,
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
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
— wraps the wide data frame this helper returns.

**Downstream spec-build verbs:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).

**Terminal verbs:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Demographics — long ARD to rendered spec ----
#
# Full pipeline from a `cards::ard_stack()`-style long ARD to a
# sorted `tabular_spec`. The multi-row continuous block (N /
# Mean (SD) / Median / Min, Max) sits above each categorical
# block; decimals are set per-stat (mean 1, sd 2, p 1) to match
# the CDISC convention.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

cdisc_saf_demo_ard |>
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
      "Safety Population"
    ),
    footnotes = "Percentages based on N per treatment group."
  ) |>
  cols(
    variable   = col_spec(label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    Placebo    = col_spec(
      label = "Placebo\nN={n['placebo']}",
      align = "decimal"
    ),
    `Xanomeline Low Dose` = col_spec(
      label = "Drug 50\nN={n['drug_50']}",
      align = "decimal"
    ),
    `Xanomeline High Dose` = col_spec(
      label = "Drug 100\nN={n['drug_100']}",
      align = "decimal"
    ),
    Total = col_spec(
      label = "Total\nN={n['Total']}",
      align = "decimal"
    )
  )

#tabular-0eb6858e8f { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-0eb6858e8f .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-0eb6858e8f p { line-height: inherit; }
#tabular-0eb6858e8f .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-0eb6858e8f .tabular-caption { margin: 0; padding: 0; }
#tabular-0eb6858e8f .tabular-pad { margin: 0; line-height: 1; }
#tabular-0eb6858e8f .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-0eb6858e8f .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-0eb6858e8f .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-0eb6858e8f .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-0eb6858e8f .tabular-table th, #tabular-0eb6858e8f .tabular-table td { padding: .18rem .6rem; }
#tabular-0eb6858e8f .tabular-table td { text-align: left; vertical-align: top; }
#tabular-0eb6858e8f .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-0eb6858e8f .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-0eb6858e8f .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-0eb6858e8f .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-0eb6858e8f .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-0eb6858e8f .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-0eb6858e8f .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-0eb6858e8f .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-0eb6858e8f .tabular-table tbody tr td { border-top: none; }
#tabular-0eb6858e8f .tabular-band { text-align: center; }
#tabular-0eb6858e8f .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-0eb6858e8f .tabular-subgroup-label { font-weight: 600; }
#tabular-0eb6858e8f .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-0eb6858e8f .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-0eb6858e8f .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-0eb6858e8f .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-0eb6858e8f .text-left { text-align: left; }
#tabular-0eb6858e8f .text-center { text-align: center; }
#tabular-0eb6858e8f .text-right { text-align: right; }
#tabular-0eb6858e8f .tabular-table thead th.text-left { text-align: left; }
#tabular-0eb6858e8f .tabular-table thead th.text-center { text-align: center; }
#tabular-0eb6858e8f .tabular-table thead th.text-right { text-align: right; }
#tabular-0eb6858e8f .tabular-table td.text-left { text-align: left; }
#tabular-0eb6858e8f .tabular-table td.text-center { text-align: center; }
#tabular-0eb6858e8f .tabular-table td.text-right { text-align: right; }
#tabular-0eb6858e8f .valign-top { vertical-align: top; }
#tabular-0eb6858e8f .valign-middle { vertical-align: middle; }
#tabular-0eb6858e8f .valign-bottom { vertical-align: bottom; }
#tabular-0eb6858e8f .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-0eb6858e8f .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-0eb6858e8f .tabular-page-break-row { display: none; }
#tabular-0eb6858e8f { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-0eb6858e8f .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-0eb6858e8f .tabular-page-header, #tabular-0eb6858e8f .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-0eb6858e8f .tabular-page-header { margin-bottom: 1rem; }
#tabular-0eb6858e8f .tabular-page-footer { margin-top: 1rem; }
#tabular-0eb6858e8f .tabular-page-header-left, #tabular-0eb6858e8f .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-0eb6858e8f .tabular-page-header-center, #tabular-0eb6858e8f .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-0eb6858e8f .tabular-page-header-right, #tabular-0eb6858e8f .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-0eb6858e8f .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-0eb6858e8f .tabular-table tr { page-break-inside: avoid; } #tabular-0eb6858e8f .tabular-page-header, #tabular-0eb6858e8f .tabular-page-footer { display: none; } #tabular-0eb6858e8f .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-0eb6858e8f .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-0eb6858e8f .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Parameter
```
