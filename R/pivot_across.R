# pivot_across.R — cards ARD long → wide display data.frame.
#
# Input helper that bridges the cards::ard_stack() output into the
# wide pre-summarised data tabular() consumes. No dependency on
# cards itself — accepts any data frame with the standard ARD
# columns (variable, stat_name, stat, group1, group1_level, ...).
#
# Ports galley::gy_wide_ard (1741 LOC) to base R + cli + rlang only:
# no glue dependency (manual {ref} substitution); vectorised stat
# formatting grouped by stat_name (fixes galley B1); single-pass
# row filter (fixes galley B4). 25 edge cases enumerated in
# plan section 2.5.
#
# Layout: the exported pivot_across() comes first. All internal
# helpers (validation, shape detection, hierarchy, formatting, wide
# assembly) and the .tabular_ard_const lookup table follow below.

# ---------------------------------------------------------------------
# Public entry
# ---------------------------------------------------------------------

#' Convert a cards ARD to a wide display data.frame
#'
#' `pivot_across()` is tabular's input-side helper: it consumes a
#' long Analysis Results Data (ARD) data frame (typically produced by
#' `cards::ard_stack()` or `cards::ard_stack_hierarchical()`) and
#' returns a wide display data.frame ready to pass to `tabular()`.
#'
#' tabular's package boundary is **display-only**: pre-summarised
#' data in, rendered file out. `pivot_across()` is the canonical
#' bridge between the cards aggregation backend and that boundary.
#' It does not aggregate — it pivots arms to columns, interpolates
#' per-cell display strings from the stat values, and applies
#' decimal precision. Filtering, weighting, and aggregation happen
#' upstream in cards or your own data-prep step.
#'
#' @param data *Long ARD input data.*
#'   `<data.frame>: required`. At minimum needs `stat_name` and
#'   `stat`. Cards-style group columns (`group1`, `group1_level`,
#'   ...) and `variable` / `variable_level` are auto-detected.
#'   Tibbles / `card` objects / arrow tables are coerced via
#'   `as.data.frame()`.
#'
#' @param statistic *Format spec for cell composition.*
#'   `<character(1) | named list>: required`. Combines one or more
#'   ARD stats into one display cell. Three accepted forms — each
#'   illustrated below. Inside a format string, `{stat_name}`
#'   substitutes that stat's value from the ARD (for example,
#'   `"{n} ({p}%)"` interpolates the `n` and `p` stats into a
#'   `"53 (62%)"` cell). The lookup order when a value is needed
#'   for a variable is: per-variable -> per-context -> `default`
#'   -> the literal `"{n}"`.
#'
#'   ## Form 1: single string
#'
#'   One format string applied to every variable regardless of
#'   context. Use when your ARD is homogeneous (e.g. all
#'   categorical).
#'
#'   ```r
#'   # Every variable rendered as "n (p%)" — categorical-only slice.
#'   cat_only <- cdisc_saf_demo_ard[cdisc_saf_demo_ard$context == "categorical", ]
#'   pivot_across(
#'     cat_only,
#'     statistic = "{n} ({p}%)"
#'   )
#'   ```
#'
#'   ## Form 2: named list by context
#'
#'   Different formats per context. This is the typical clinical-table
#'   form because demographics mix continuous and categorical
#'   variables.
#'
#'   **The list names must match the values in the ARD's `context`
#'   column verbatim.** Which strings appear there depends on how the
#'   ARD was built:
#'
#'   - `cards::ard_continuous()` / `ard_categorical()` emit
#'     `"continuous"` / `"categorical"`.
#'   - `cards::ard_summary()` / `ard_tabulate()` emit `"summary"` /
#'     `"tabulate"`.
#'
#'   So an ARD assembled with `ard_stack(ard_summary(...),
#'   ard_tabulate(...))` is keyed `summary` / `tabulate`, not
#'   `continuous` / `categorical`. Inspect `unique(ard$context)` when
#'   unsure.
#'
#'   ```r
#'   # AGE (continuous) -> "75.2 (8.59)"; SEX (categorical) -> "53 (62%)"
#'   pivot_across(
#'     cdisc_saf_demo_ard,
#'     statistic = list(
#'       continuous  = "{mean} ({sd})",
#'       categorical = "{n} ({p}%)"
#'     )
#'   )
#'   ```
#'
#'   ## Form 3: named list by variable
#'
#'   Override on a per-variable basis; fall back to `default` or
#'   context. Use when one variable needs a custom format.
#'
#'   ```r
#'   # AGE shows just the mean; SEX / RACE keep the categorical default.
#'   pivot_across(
#'     cdisc_saf_demo_ard,
#'     statistic = list(
#'       AGE         = "{mean}",
#'       categorical = "{n} ({p}%)",
#'       default     = "{mean} ({sd})"
#'     )
#'   )
#'   ```
#'
#'   ## Multi-row continuous spec
#'
#'   Any single entry can itself be a **named character vector** —
#'   each element becomes one display row, with the name as the row
#'   label. Use for `N / Mean (SD) / Median / Min, Max`-style blocks.
#'
#'   ```r
#'   pivot_across(
#'     cdisc_saf_demo_ard,
#'     statistic = list(
#'       continuous = c(
#'         N           = "{N}",
#'         "Mean (SD)" = "{mean} ({sd})",
#'         Median      = "{median}",
#'         "Min, Max"  = "{min}, {max}"
#'       ),
#'       categorical = "{n} ({p}%)"
#'     )
#'   )
#'   ```
#' @param column *What runs across the top of the table.*
#'   `<character | NULL>: default NULL`. A single grouping variable
#'   whose unique values become arm columns (`NULL` auto-detects from
#'   `group1`, or picks the single non-standard column of renamed
#'   input). Two reserved tokens turn the analysis variable into a
#'   **column band**:
#'
#'   *   `c(".variable", "<arm>")` — each variable becomes a band of
#'       arm columns; the statistic entries stack as rows. The cells
#'       are combined strings (e.g. `"323.9 (106)"`). Emitted columns
#'       are named `"<variable>..<arm>"`.
#'   *   `c(".variable", ".stat")` — each variable becomes a band whose
#'       statistic entries become their own columns (the landscape
#'       "value and change" shell); the arm drops to a leading row
#'       stub. Emitted columns are named `"<variable>..<stat-entry>"`.
#'
#'   Anything present in the ARD but not named in `column` (and not in
#'   `row_group`) stacks as rows. Per-variable `statistic` / `decimals`
#'   resolve inside each band, so bands may carry different (even
#'   different-length) stat lists; ragged bands pad with `NA`.
#'
#'   **Tip:** you reference the emitted column names verbatim in a
#'   manual [`headers()`] call to build the band spanners; pivot_across
#'   does not build spanners itself.
#'
#' @param row_group *Second, non-column grouping dimension.*
#'   `<character(1) | NULL>: default NULL`. Names the non-arm group
#'   variable of a two-variable `.by` (e.g. `SEX` in
#'   `ard_stack(.by = c(ARM, SEX))`). It widens into a leading row
#'   column (not a pivoted arm column), so the result composes with
#'   [`subgroup(by = ...)`][subgroup()] or
#'   `col_spec(usage = "group")` downstream.
#'
#'   **Why it is required.** cards encodes a crossing factor and a
#'   SOC/PT hierarchy identically (the second group variable appears
#'   in `variable` on its by-marginal rows), so the two cannot be told
#'   apart automatically. Naming `row_group` declares "this is a
#'   crossing factor": the by-marginal rows are dropped and the flat
#'   path is used. Leave it `NULL` for a genuine hierarchy.
#'
#'   **Restriction:** Must name a second grouping variable present in
#'   the ARD and must differ from `column`.
#'
#' @param label *Variable-name to display-label map.*
#'   `<character> | NULL: default NULL`. Named character vector
#'   mapping variable names to display labels (e.g.
#'   `c(AGE = "Age (years)", SEX = "Sex")`). Applies to
#'   `variable`, `soc`, and `label` columns of the output. `NULL`
#'   leaves the upstream variable names verbatim.
#'
#'   **Renaming the hierarchical "overall" row.** A
#'   `cards::ard_stack_hierarchical(overall = TRUE)` ARD carries an
#'   internal `..ard_hierarchical_overall..` sentinel for the
#'   grand-total ("any event") row. It is relabelled to `"Overall"`
#'   by default; map the sentinel key to override, e.g.
#'   `label = c("..ard_hierarchical_overall.." = "TOTAL SUBJECTS WITH AN EVENT")`.
#'   The raw sentinel never reaches the output at any hierarchy depth.
#'
#' @param overall *Column name for `NA`-arm (overall / total) rows.*
#'   `<character(1) | NULL>: default "Total"`. Pass `NULL` to drop
#'   overall rows entirely (per-arm only output).
#'
#'   **Requirement:** this relabels pooled rows the ARD already
#'   carries — the `NA`-arm rows cards emits from
#'   `cards::ard_stack_hierarchical(overall = TRUE)` or an
#'   `ard_*(.overall = TRUE)`. It does not synthesize a total: cards
#'   re-runs the calculation with the `by` variable removed, so the
#'   pooled `n` / `N` / `p` stay internally consistent. With no such
#'   rows in the input there is no overall column to label.
#'
#'   **Note:** if a study arm is literally named the same as `overall`
#'   (default `"Total"`), that arm and the pooled rows collide under
#'   one label and the pivot warns. Pass a distinct `overall =` or
#'   rename the arm upstream.
#'
#' @param decimals *Per-stat decimal precision.*
#'   `<named integer | named list>: default `c()``. Accepts three
#'   forms:
#'
#'   *   **named integer vector** — global per-stat overrides
#'       (`c(mean = 1, sd = 2, p = 0)`).
#'   *   **named list keyed by variable** — per-variable plus `.default`
#'       (`list(AGE = c(mean = 2), .default = c(p = 1))`).
#'   *   **named list keyed by `row_group` value** — per-group precision in
#'       one call (`list(SYSBP = c(mean = 0, sd = 1), WEIGHT = c(mean = 1),
#'       .default = c(mean = 1, sd = 2))`). Each entry is a per-token spec (a
#'       named numeric vector, or a bare scalar applied to every token).
#'
#'   Built-in defaults apply when none sets a stat.
#'
#'   **Interaction:** a list `decimals` is read as per-`row_group` only when
#'   `row_group` is set and every key (apart from `.default`) is one of its
#'   levels; otherwise it stays per-variable. Within the matched group the
#'   token falls back group token, then the per-group `.default` token, then
#'   the built-in default. A group present in the data but absent from the
#'   list (and NA / ungrouped rows) uses `.default`. If `row_group` is `NULL`
#'   but the keys match no variable, `pivot_across()` errors and asks for a
#'   `row_group`.
#'
#' @param fmt *Per-stat custom formatter functions.*
#'   `<named list of function>: default `list()``. Each function
#'   takes a numeric value and returns a character string;
#'   overrides built-ins and `decimals` for that stat. Useful for
#'   p-value styling and other domain-specific formatting.
#'
#' @param aux *Auxiliary comparison columns from a second ARD.*
#'   `<named list | NULL>: default NULL`. Each entry is a between-arm
#'   statistic (difference, hazard ratio, p-value, ...) computed in its
#'   own ARD and bound on as a trailing column, aligned 1:1 on the
#'   `row_group` key. The entry name is the column name; reference it in
#'   a manual [`headers()`] call. Each entry is a list:
#'
#'   *   `ard` — the auxiliary ARD (required), one row per `row_group`.
#'   *   `statistic` — its format string (e.g.
#'       `"{estimate} ({conf.low}, {conf.high})"`); defaults to `"{n}"`.
#'   *   `decimals` / `fmt` — optional, as for the main pivot.
#'
#'   Entries append left to right. One entry is one column; for several
#'   comparison columns (estimate then p-value) pass several entries.
#'
#'   **Requirement:** needs a `row_group`; the auxiliary rows align to
#'   the main table on it, which must be unique 1:1 on both sides (a
#'   many-to-many key would silently fabricate rows, so it aborts).
#'
#'   ```r
#'   # p-value formatter: render below-threshold values as "<0.001".
#'   fmt = list(
#'     p.value = function(x) {
#'       ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
#'     }
#'   )
#'   ```
#' @details
#'
#' ## Key `statistic` by the ARD `context`
#'
#' `statistic` (and `fmt`) are matched against the ARD's `context`
#' column verbatim, and that value differs per generating function.
#' Keying by the wrong name silently drops the format. Inspect
#' `unique(ard$context)` first and key to match (or pass a single
#' format string / `default =` to cover everything). When an
#' explicitly-supplied `statistic` matches no context at all,
#' `pivot_across()` warns rather than silently emitting `{n}`.
#'
#' | Generating function | `context` to key on |
#' |---|---|
#' | `cards::ard_summary()` | `summary` |
#' | `cards::ard_tabulate()` | `tabulate` |
#' | `cards::ard_continuous()` | `continuous` |
#' | `cards::ard_categorical()` | `categorical` |
#' | `cards::ard_stack_hierarchical()` | `tabulate` + `hierarchical` |
#' | `cardx::ard_categorical_ci()` | `proportion_ci` |
#' | `cardx::ard_continuous_ci()` | `continuous_ci` |
#'
#' ## Zero-suppression (always-on default)
#'
#' A row whose `n` value equals zero renders the whole cell as the
#' bare `n` value instead of fully interpolating the format string.
#' For a categorical level with `n = 0`, the cell shows `"0"`, not
#' `"0 (0.0%)"`. This is clinical convention — empty cells should
#' read as a single zero, not advertise a meaningless rate.
#'
#' **How the default fires (chain of events).** During cell assembly,
#' before format-string interpolation, the engine checks the row's
#' `n` stat. If it is zero, the engine short-circuits and returns the
#' formatted `n` value (`"0"`) as the entire cell — `{p}` is never
#' substituted, so the `(0.0%)` half of the format string is dropped.
#'
#' **How to opt out: supply a custom `fmt$n`.** Setting any function
#' under `fmt$n` is the engine's signal that the user owns the `n`
#' rendering. The short-circuit is disabled for the whole table; for
#' every row the full format string interpolates, so `{n}` becomes
#' your formatter's output and `{p}` becomes the standard percentage.
#' For `n = 0`, that's `"0 (0.0%)"`.
#'
#' ```r
#' # Force "0 (0.0%)" for n = 0 rows by attaching a custom n formatter.
#' # The body of fmt$n can be the default integer rendering — its
#' # presence alone is what disables the zero-suppression branch.
#' pivot_across(
#'   cdisc_saf_demo_ard,
#'   statistic = list(
#'     continuous  = "{mean} ({sd})",
#'     categorical = "{n} ({p}%)"
#'   ),
#'   fmt = list(n = function(x) sprintf("%d", as.integer(x)))
#' )
#' ```
#'
#' ## Pharma rounding (always-on default)
#'
#' A percentage that would otherwise round to `0` (when the value
#' is positive but smaller than the chosen precision) renders as
#' `<0.1`; one that would round to `100` (positive but smaller than
#' 100) renders as `>99.9`. The threshold is precision-aware:
#' `decimals = c(p = 2)` produces `<0.01` / `>99.99`. This matches
#' the pharma convention of never claiming exactly `0%` or `100%`
#' when at least one subject contributed.
#'
#' Override per-stat via `fmt`:
#'
#' ```r
#' # Show exact rounded percentages even at the extremes
#' pivot_across(
#'   data,
#'   statistic = "{n} ({p}%)",
#'   decimals  = c(p = 1),
#'   fmt = list(p = function(x) sprintf("%.1f", x * 100))
#' )
#' ```
#'
#' Your `fmt$p` receives the raw stat value (a proportion between
#' 0 and 1) and returns the displayed string. The pharma-threshold
#' branch only fires inside the built-in `p` formatter and the
#' `decimals`-driven path, so any custom `fmt$p` bypasses it.
#' @return *A wide `data.frame` ready for [`tabular()`].* Schema:
#'
#'   *   `variable` — variable name (or label after `label = ...`).
#'   *   `stat_label` — display-row label.
#'   *   One column per arm level (named after the `group1_level`
#'       values or the renamed arm column).
#'   *   `Total` (or whatever `overall` is set to) when applicable.
#'   *   A leading column named after `row_group` when set (the second
#'       grouping dimension).
#'   *   Hierarchical ARD adds `soc`, `label`, `row_type` instead of
#'       `variable`.
#'
#'   Pass the result straight into [`tabular()`] to start the
#'   render pipeline.
#'
#' @examples
#' # ---- Example 1: Demographics — long ARD to rendered spec ----
#' #
#' # Full pipeline from a `cards::ard_stack()`-style long ARD to a
#' # sorted `tabular_spec`. The multi-row continuous block (N /
#' # Mean (SD) / Median / Min, Max) sits above each categorical
#' # block; decimals are set per-stat (mean 1, sd 2, p 1) to match
#' # the CDISC convention.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' cdisc_saf_demo_ard |>
#'   pivot_across(
#'     statistic = list(
#'       continuous = c(
#'         N           = "{N}",
#'         "Mean (SD)" = "{mean} ({sd})",
#'         Median      = "{median}",
#'         "Min, Max"  = "{min}, {max}"
#'       ),
#'       categorical = "{n} ({p}%)"
#'     ),
#'     decimals = c(mean = 1, sd = 2, p = 1, median = 1, min = 0, max = 0),
#'     label    = c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
#'   ) |>
#'   tabular(
#'     titles = c(
#'       "Table 14.1.1",
#'       "Demographics and Baseline Characteristics",
#'       "Safety Population"
#'     ),
#'     footnotes = "Percentages based on N per treatment group."
#'   ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     Placebo    = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal"
#'     ),
#'     `Xanomeline Low Dose` = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal"
#'     ),
#'     `Xanomeline High Dose` = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal"
#'     ),
#'     Total = col_spec(
#'       label = "Total\nN={n['Total']}",
#'       align = "decimal"
#'     )
#'   )
#'
#' # ---- Example 2: Hierarchical SOC/PT AE table ----
#' #
#' # Hierarchical `cards::ard_stack_hierarchical()` output threaded
#' # through `pivot_across()`. The hierarchical ARD emits a
#' # (soc, label, row_type) triple plus one stat row per (arm, SOC, PT);
#' # `pivot_across()` folds the arm dimension to columns and preserves
#' # the hierarchy markers. Derive `indent_level` from `row_type` so
#' # `col_spec(indent = "indent_level")` drives the SOC -> PT
#' # indent on the `label` column.
#' wide <- cdisc_saf_aesocpt_ard |>
#'   pivot_across(statistic = "{n} ({p}%)")
#' wide$indent_level <- as.integer(wide$row_type == "pt")
#'
#' tabular(
#'   wide,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     "Safety Population"
#'   ),
#'   footnotes = c(
#'     "Subjects are counted once per SOC and once per PT.",
#'     "Percentages based on N per treatment group."
#'   )
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     Placebo  = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal"
#'     ),
#'     `Xanomeline Low Dose` = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal"
#'     ),
#'     `Xanomeline High Dose` = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal"
#'     )
#'   )
#'
#' # ---- Example 3: Hierarchical ARD (SOC / PT) ----
#' #
#' # `cdisc_saf_aesocpt_ard` carries an `ard_stack_hierarchical` shape with
#' # two grouping variables (AEBODSYS / AEDECOD). `pivot_across()`
#' # recognises the hierarchical structure and emits dedicated `soc`,
#' # `label`, and `row_type` columns so the SOC -> PT nesting survives
#' # the pivot. The result is ready for `tabular()` plus `sort_rows()`.
#' head(cdisc_saf_aesocpt_ard, 3)
#'
#' wide <- cdisc_saf_aesocpt_ard |>
#'   pivot_across(statistic = "{n} ({p}%)")
#' head(wide, 3)
#'
#' # ---- Example 4: Multi-row continuous spec + label re-labelling ----
#' #
#' # `statistic = c(<label> = <template>, ...)` produces one display
#' # row per named entry — the canonical "N / Mean (SD) / Median /
#' # Min, Max" block for continuous variables. `label = c(...)`
#' # renames the variable headings emitted into the wide output.
#' cdisc_saf_demo_ard |>
#'   pivot_across(
#'     statistic = list(
#'       continuous = c(
#'         N            = "{N}",
#'         "Mean (SD)"  = "{mean} ({sd})",
#'         Median       = "{median}",
#'         "Q1, Q3"     = "{p25}, {p75}",
#'         "Min, Max"   = "{min}, {max}"
#'       ),
#'       categorical = "{n} ({p}%)"
#'     ),
#'     label = c(
#'       AGE    = "Age (years)",
#'       WEIGHT = "Weight (kg)",
#'       HEIGHT = "Height (cm)",
#'       BMI    = "BMI (kg/m^2)"
#'     )
#'   )
#'
#' # ---- Example 5: ARD keyed by summary / tabulate contexts ----
#' #
#' # The `statistic` list names must match the ARD's `context` column
#' # verbatim. `cards::ard_summary()` / `ard_tabulate()` emit `"summary"` /
#' # `"tabulate"` (not the `"continuous"` / `"categorical"` of
#' # `ard_continuous()` / `ard_categorical()`), so a list keyed
#' # `continuous`/`categorical` would silently match nothing. Always check
#' # `unique(ard$context)` first. Here the bundled `cdisc_saf_demo_ard` is
#' # relabelled to mimic `ard_summary()` + `ard_tabulate()` output; the
#' # by-variable's own row drops automatically and both the summary and
#' # the tabulate variables survive.
#' card_st <- cdisc_saf_demo_ard
#' card_st$context[card_st$context == "continuous"] <- "summary"
#' card_st$context[card_st$context == "categorical"] <- "tabulate"
#' pivot_across(
#'   card_st,
#'   statistic = list(
#'     summary  = "{mean} ({sd})",
#'     tabulate = "{n} ({p}%)"
#'   )
#' )
#'
#' # ---- Example 6: Analysis variables as side-by-side column bands ----
#' #
#' # `column = c(".variable", "<arm>")` turns each analysis variable into
#' # its own band of arm columns (the "value and change side by side"
#' # shape), with statistics stacked as rows. Per-variable `statistic` /
#' # `decimals` resolve inside each band. Emitted columns are named
#' # "<variable>..<arm>"; reference them verbatim in a manual `headers()`
#' # call to draw the band spanners (pivot_across never builds spanners).
#' vitals <- cdisc_saf_demo_ard[
#'   cdisc_saf_demo_ard$variable %in% c("AGE", "WEIGHT"),
#' ]
#' vitals |>
#'   pivot_across(
#'     column = c(".variable", "TRT01A"),
#'     overall = NULL,
#'     statistic = list(
#'       AGE    = c(N = "{N}", "Mean (SD)" = "{mean} ({sd})", Median = "{median}"),
#'       WEIGHT = c(N = "{N}", "Mean (SD)" = "{mean} ({sd})", Median = "{median}")
#'     ),
#'     decimals = list(
#'       AGE    = c(mean = 1, sd = 2, median = 1),
#'       WEIGHT = c(mean = 1, sd = 2, median = 1)
#'     )
#'   ) |>
#'   tabular(
#'     titles = c(
#'       "Table 14.2.1",
#'       "Summary of Continuous Parameters by Treatment",
#'       "Safety Population"
#'     )
#'   ) |>
#'   cols(stat_label = col_spec(label = "Statistic")) |>
#'   headers(
#'     Age = c(
#'       "AGE..Placebo",
#'       "AGE..Xanomeline Low Dose",
#'       "AGE..Xanomeline High Dose"
#'     ),
#'     Weight = c(
#'       "WEIGHT..Placebo",
#'       "WEIGHT..Xanomeline Low Dose",
#'       "WEIGHT..Xanomeline High Dose"
#'     )
#'   )
#'
#' # ---- Example 7: Statistics as columns within each band ----
#' #
#' # `column = c(".variable", ".stat")` spreads each statistic entry into
#' # its own column (the landscape shell); the arm drops to a leading row
#' # stub. Emitted columns are named "<variable>..<stat-entry>". Bands may
#' # carry different stat sets, with no row-alignment needed.
#' vitals |>
#'   pivot_across(
#'     column = c(".variable", ".stat"),
#'     overall = NULL,
#'     statistic = list(
#'       AGE    = c(N = "{N}", Mean = "{mean}", SD = "{sd}"),
#'       WEIGHT = c(N = "{N}", Mean = "{mean}", SD = "{sd}", Median = "{median}")
#'     ),
#'     decimals = c(mean = 1, sd = 2, median = 1)
#'   )
#'
#' # ---- Example 8: Per-row-group decimal precision ----
#' #
#' # A by-parameter vitals table where each parameter carries its own
#' # value precision: systolic BP to 0 dp, weight to 1 dp, in ONE call.
#' # `decimals` is keyed by the `row_group` (PARAM) value; the engine
#' # selects each row's token precision by its parameter. No bundled ARD
#' # carries a second grouping dimension, so build a tiny one inline.
#' vital_ard <- do.call(rbind, lapply(
#'   list(
#'     c("SYSBP", "Placebo", "mean", "133.27"),
#'     c("SYSBP", "Placebo", "sd", "15.81"),
#'     c("SYSBP", "Drug", "mean", "128.94"),
#'     c("SYSBP", "Drug", "sd", "14.02"),
#'     c("WEIGHT", "Placebo", "mean", "71.43"),
#'     c("WEIGHT", "Placebo", "sd", "12.77"),
#'     c("WEIGHT", "Drug", "mean", "73.06"),
#'     c("WEIGHT", "Drug", "sd", "13.19")
#'   ),
#'   function(r) {
#'     data.frame(
#'       group1 = "PARAM",
#'       group1_level = r[[1]],
#'       group2 = "TRTA",
#'       group2_level = r[[2]],
#'       variable = "AVAL",
#'       variable_level = NA_character_,
#'       context = "continuous",
#'       stat_name = r[[3]],
#'       stat_label = r[[3]],
#'       stat = I(list(as.numeric(r[[4]]))),
#'       stringsAsFactors = FALSE
#'     )
#'   }
#' ))
#' vital_ard |>
#'   pivot_across(
#'     column = "TRTA",
#'     row_group = "PARAM",
#'     overall = NULL,
#'     statistic = list(continuous = "{mean} ({sd})"),
#'     decimals = list(
#'       SYSBP = c(mean = 0, sd = 1),
#'       WEIGHT = c(mean = 1, sd = 2)
#'     )
#'   )
#'
#' @seealso
#' **Pipeline entry consumer:** [`tabular()`] — wraps the wide data
#' frame this helper returns.
#'
#' **Downstream spec-build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`style()`],
#' [`paginate()`], [`preset()`].
#'
#' **Terminal verbs:** [`emit()`], [`as_grid()`].
#'
#' @export
pivot_across <- function(
  data,
  statistic = list(
    continuous = "{mean} ({sd})",
    categorical = "{n} ({p}%)"
  ),
  column = NULL,
  row_group = NULL,
  label = NULL,
  overall = "Total",
  decimals = NULL,
  fmt = NULL,
  aux = NULL
) {
  call <- rlang::caller_env()
  # Captured before `statistic` is reassigned: the unmatched-context
  # warning fires only when the user supplied keys explicitly. The
  # default `{n}` fallback is the correct output for tabulate /
  # hierarchical counts, so a default call must never warn.
  stat_explicit <- !missing(statistic)

  data <- .check_ard_data(data, call = call)
  statistic <- .resolve_statistic_arg(statistic, call = call)
  .check_fmt_arg(fmt, call = call)
  col_spec <- .parse_column_spec(column, call = call)
  aux <- .check_aux_arg(aux, call = call)

  if (col_spec$variable_band) {
    wide <- .build_variable_band(
      data,
      col_spec = col_spec,
      statistic = statistic,
      row_group = row_group,
      label = label,
      overall = overall,
      decimals = decimals,
      fmt = fmt,
      stat_explicit = stat_explicit,
      call = call
    )
  } else {
    wide <- .pivot_core(
      data,
      statistic = statistic,
      column = col_spec$arm,
      row_group = row_group,
      label = label,
      overall = overall,
      decimals = decimals,
      fmt = fmt,
      stat_explicit = stat_explicit,
      warn = TRUE,
      call = call
    )
  }

  if (!is.null(aux)) {
    wide <- .bind_aux(
      wide,
      aux = aux,
      row_group = row_group,
      fmt = fmt,
      call = call
    )
  }
  wide
}

# ---------------------------------------------------------------------
# Core single-variable / simple pivot: data -> wide display frame.
# Factored out of pivot_across so the variable-band and aux paths reuse
# it per variable / per aux ARD. `column` is the resolved arm group var
# (or NULL). `warn` gates the unmatched-context warning so band / aux
# sub-calls do not fire it repeatedly.
# ---------------------------------------------------------------------
.pivot_core <- function(
  data,
  statistic,
  column = NULL,
  row_group = NULL,
  label = NULL,
  overall = "Total",
  decimals = NULL,
  fmt = NULL,
  stat_explicit = TRUE,
  warn = TRUE,
  call = rlang::caller_env()
) {
  norm <- .normalise_ard_input(data, column = column, call = call)
  df <- norm$df
  column <- norm$column
  extra_groups <- norm$extra_groups
  shape <- norm$shape

  row_group <- .check_row_group(
    row_group,
    column = column,
    extra_groups = extra_groups,
    call = call
  )

  df <- .extract_context(df)
  df <- .filter_internal_rows(df, column = column)

  # A user-declared second grouping dimension (`row_group`, e.g. SEX in
  # `ard_stack(.by = c(ARM, SEX))`) carries by-marginal rows whose
  # `variable` IS the group var name AND whose `row_group` value is absent
  # (the ungrouped tabulation of the group var itself). Those marginals
  # (a) make the group var name appear in `variable`, which mis-trips
  # hierarchy detection, and (b) would leak into a phantom Total. Drop
  # only those marginals -- a genuine analysis variable that happens to
  # share the group name keeps its rows (it has a populated `row_group`
  # value). The dimension already rides the `row_group` column, and the
  # table composes with `subgroup(by = row_group)` downstream.
  if (!is.null(row_group)) {
    # A genuine SOC/PT hierarchy carries `hierarchical`-context rows and
    # the hierarchical-overall sentinel; `row_group` is for a crossing
    # factor, not a hierarchy level. Refuse rather than silently flatten.
    if (
      any(df$ctx == "hierarchical", na.rm = TRUE) ||
        any(df$variable %in% .tabular_ard_const$keep_sentinels)
    ) {
      cli::cli_abort(
        c(
          "{.arg row_group} cannot be used with a hierarchical ARD.",
          "x" = "{.val {row_group}} reads as a SOC/PT hierarchy level, not a crossing factor.",
          "i" = "Drop {.arg row_group} to render the hierarchy with its nested layout."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    is_marginal <- !is.na(df$variable) &
      df$variable == row_group &
      is.na(df[[row_group]])
    df <- df[!is_marginal, , drop = FALSE]
  }

  # Hierarchy detection runs AFTER internal-row filtering so that
  # multi-group `.by` ARDs (where variable transiently holds the
  # by-variable names in tabulate / total_n rows) aren't misclassified
  # as hierarchical (SOC / PT). A declared `row_group` forces the flat
  # path: cards encodes a crossing factor and a SOC/PT hierarchy
  # identically, so only the user's declaration disambiguates them.
  hierarchy <- .detect_ard_hierarchy(df)
  if (!is.null(row_group)) {
    hierarchy$is_hierarchical <- FALSE
  }

  if (nrow(df) == 0L) {
    cli::cli_abort(
      c(
        "No displayable rows remain after filtering internal ARD rows.",
        "i" = "Check that {.arg data} contains analysis results, not just metadata."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  df <- .apply_overall_label(df, overall = overall, call = call)
  df <- .filter_to_column_group(df, column = column, overall = overall)

  # Warn once when an explicitly-supplied `statistic` matches no context
  # or variable in the ARD: every cell falls back to `{n}`, the single
  # most common way to get silently wrong output (the canonical
  # `summary`-vs-`continuous` mis-key). Skipped on the hierarchical path,
  # which formats counts directly regardless of the statistic keys.
  if (warn) {
    .warn_unmatched_context(
      df,
      statistic,
      stat_explicit = stat_explicit,
      is_hierarchical = hierarchy$is_hierarchical,
      call = call
    )
  }

  # nocov start — defensive: .filter_to_column_group only narrows, and
  # the earlier post-internal-filter check at L286 catches the realistic
  # empty case. Kept as a final safety net for malformed input.
  if (nrow(df) == 0L) {
    cli::cli_abort(
      c(
        "No rows remain after applying {.arg column} / {.arg overall} filters.",
        "i" = "Verify {.arg column} matches a {.code group1} value in the ARD."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # nocov end

  rg_levels <- if (!is.null(row_group) && row_group %in% names(df)) {
    lv <- .normalise_ard_chr(df[[row_group]])
    unique(lv[!is.na(lv)])
  } else {
    NULL
  }
  decimals_resolved <- .resolve_ard_decimals(
    decimals,
    row_group = row_group,
    rg_levels = rg_levels,
    variables = unique(df$variable),
    call = call
  )
  df$stat_fmt <- .format_stat_vectorised(
    df,
    decimals = decimals_resolved,
    fmt = fmt,
    pct_threshold = TRUE,
    call = call,
    row_group = row_group
  )

  # Zero-suppression default: show "0" for n=0 rows. A user-supplied
  # fmt$n means the user has taken responsibility for the cell content,
  # so disable zero-suppression and let the full format interpolate.
  pct_zero <- !is.null(fmt) && "n" %in% names(fmt)

  if (hierarchy$is_hierarchical) {
    wide <- .build_hierarchical_wide(
      df,
      statistic = statistic,
      hierarchy = hierarchy,
      column = column,
      pct_zero = pct_zero,
      call = call
    )
  } else {
    wide <- .build_flat_wide(
      df,
      statistic = statistic,
      extra_groups = extra_groups,
      pct_zero = pct_zero,
      call = call
    )
  }

  arm_levels <- unique(df$arm[!is.na(df$arm)])

  # Always run: even with no user `label`, the map applies the registry
  # default for kept sentinels so a raw `..` name never reaches output. The
  # default keys only the sentinel string, so non-sentinel rows (and the flat
  # path, which has no soc/label columns) are untouched.
  wide <- .apply_label_map(wide, label = label)

  rownames(wide) <- NULL
  # Stamp the arm column names so downstream verbs (e.g. sort_rows())
  # can reject sort keys that target pivoted arm columns — those cells
  # hold rendered stat strings that don't order meaningfully. No user-
  # visible col_spec tag needed; the attribute is the engine's wire.
  attr(wide, "across_cols") <- intersect(
    as.character(arm_levels),
    names(wide)
  )
  wide
}

# Separator between a variable band and its arm / stat sub-column in the
# emitted column name (e.g. "AVAL..Mean (SD)"). User references these names
# verbatim in a manual headers() call, so it is part of the wire contract.
.tabular_band_sep <- ".."

# ---------------------------------------------------------------------
# Variable-band assembly (column = c(".variable", arm) or c(".variable",
# ".stat")). Pivots each variable independently via .pivot_core and binds
# the blocks side by side, aligned on the shared row keys.
# ---------------------------------------------------------------------

.build_variable_band <- function(
  data,
  col_spec,
  statistic,
  row_group,
  label,
  overall,
  decimals,
  fmt,
  stat_explicit,
  call
) {
  if (!("variable" %in% names(data))) {
    cli::cli_abort(
      c(
        "A {.val .variable} band needs a {.val variable} column in {.arg data}.",
        "i" = "Renamed ARDs without a {.val variable} column are not supported here."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (any(data$context == "hierarchical", na.rm = TRUE)) {
    cli::cli_abort(
      c(
        "A {.val .variable} band cannot be combined with a hierarchical (SOC/PT) ARD.",
        "i" = "Render the hierarchy on its own; it already nests as section + indent."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  var_chr <- .normalise_ard_chr(data$variable)
  vars <- unique(var_chr[!is.na(var_chr)])
  vars <- setdiff(vars, .tabular_ard_const$keep_sentinels)
  # nocov start — defensive: .check_ard_data + the variable-column check
  # above guarantee at least one real variable by this point.
  if (length(vars) == 0L) {
    cli::cli_abort(
      "No analysis variables found for the {.val .variable} band.",
      class = "tabular_error_input",
      call = call
    )
  }
  # nocov end

  if (col_spec$stat_cols) {
    # Detect the arm var = a grouping variable that is not the row_group.
    probe <- .normalise_ard_input(data, column = NULL, call = call)
    candidates <- c(probe$column, probe$extra_groups)
    candidates <- candidates[!is.na(candidates)]
    arm_var <- setdiff(candidates, row_group)
    arm_var <- if (length(arm_var) >= 1L) arm_var[[1L]] else NULL
    id_keys <- c(row_group, arm_var)
  } else {
    arm_var <- col_spec$arm
    id_keys <- c(row_group, "stat_label")
  }

  blocks <- vector("list", length(vars))
  names(blocks) <- vars
  for (v in vars) {
    data_v <- data[!is.na(var_chr) & var_chr == v, , drop = FALSE]
    wide_v <- .pivot_core(
      data_v,
      statistic = statistic,
      column = arm_var,
      row_group = row_group,
      label = label,
      overall = overall,
      decimals = decimals,
      fmt = fmt,
      stat_explicit = FALSE,
      warn = FALSE,
      call = call
    )
    val_cols <- attr(wide_v, "across_cols")

    if (col_spec$stat_cols) {
      block <- .transpose_stats(wide_v, row_group, val_cols, arm_var)
      stat_cols <- setdiff(names(block), id_keys)
      names(block)[match(stat_cols, names(block))] <- paste0(
        v,
        .tabular_band_sep,
        stat_cols
      )
    } else {
      keep <- c(intersect(id_keys, names(wide_v)), val_cols)
      block <- wide_v[, keep, drop = FALSE]
      is_val <- names(block) %in% val_cols
      names(block)[is_val] <- paste0(
        v,
        .tabular_band_sep,
        names(block)[is_val]
      )
    }
    blocks[[v]] <- block
  }

  present_keys <- intersect(id_keys, names(blocks[[1L]]))
  out <- .bind_band_blocks(blocks, present_keys, call = call)
  attr(out, "across_cols") <- setdiff(names(out), present_keys)
  out
}

# Transpose one variable's rows-mode wide block so each statistic becomes
# its own column and the arm drops to a leading row stub. Reuses the
# already-formatted cells in `wide_v`; pure reshape, no re-formatting.
.transpose_stats <- function(wide_v, row_group, arm_levels, arm_var) {
  stat_order <- unique(wide_v$stat_label)
  has_rg <- !is.null(row_group) && row_group %in% names(wide_v)
  arm_col <- arm_var %||% ".arm"

  pieces <- lapply(arm_levels, function(a) {
    piece <- data.frame(
      .stat_label = wide_v$stat_label,
      stringsAsFactors = FALSE
    )
    if (has_rg) {
      piece[[row_group]] <- wide_v[[row_group]]
    }
    piece[[arm_col]] <- a
    piece$.value <- wide_v[[a]]
    piece
  })
  long <- do.call(rbind, pieces)

  id_keys <- c(if (has_rg) row_group, arm_col)
  ikey <- do.call(paste, c(long[id_keys], list(sep = "\x1f")))
  first <- !duplicated(ikey)
  out <- long[first, id_keys, drop = FALSE]
  okey <- ikey[first]
  for (s in stat_order) {
    sub <- long[long$.stat_label == s, , drop = FALSE]
    skey <- do.call(paste, c(sub[id_keys], list(sep = "\x1f")))
    out[[s]] <- sub$.value[match(okey, skey)]
  }
  rownames(out) <- NULL
  out
}

# Full-outer union of band blocks on the shared id keys, preserving
# first-appearance row order. Differing stat labels across bands stack;
# absent cells stay NA (the engine renders na_text). Value columns are
# uniquely named per band, so there is never a column collision.
.bind_band_blocks <- function(blocks, id_keys, call) {
  key_frames <- lapply(blocks, function(b) b[, id_keys, drop = FALSE])
  all_keys <- unique(do.call(rbind, key_frames))
  rownames(all_keys) <- NULL
  okey <- do.call(paste, c(all_keys[id_keys], list(sep = "\x1f")))

  out <- all_keys
  for (b in blocks) {
    bkey <- do.call(paste, c(b[id_keys], list(sep = "\x1f")))
    for (cn in setdiff(names(b), id_keys)) {
      out[[cn]] <- b[[cn]][match(okey, bkey)]
    }
  }
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------
# Auxiliary column binding (aux = list(<band> = list(ard, statistic, ...)))
# ---------------------------------------------------------------------

.check_aux_arg <- function(aux, call) {
  if (is.null(aux)) {
    return(NULL)
  }
  nms <- names(aux)
  if (
    !is.list(aux) ||
      length(aux) == 0L ||
      is.null(nms) ||
      anyNA(nms) ||
      any(nms == "")
  ) {
    cli::cli_abort(
      c(
        "{.arg aux} must be a named list of auxiliary column specs.",
        "x" = "You supplied {.obj_type_friendly {aux}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  for (nm in nms) {
    entry <- aux[[nm]]
    if (!is.list(entry) || is.null(entry[["ard"]])) {
      cli::cli_abort(
        c(
          "Each {.arg aux} entry must be a list with an {.field ard}.",
          "x" = "Entry {.val {nm}} has no {.field ard}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  aux
}

.bind_aux <- function(wide, aux, row_group, fmt, call) {
  if (is.null(row_group)) {
    cli::cli_abort(
      c(
        "{.arg aux} columns require a {.arg row_group}.",
        "i" = "Auxiliary columns align to the main table on the {.arg row_group} key.",
        "i" = "Pass {.arg row_group} so the comparison rows line up."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  across <- attr(wide, "across_cols")
  for (nm in names(aux)) {
    entry <- aux[[nm]]
    ard <- .check_ard_data(entry[["ard"]], call = call)
    stat <- .resolve_statistic_arg(
      entry[["statistic"]] %||% "{n}",
      call = call
    )

    # The comparison is keyed by the row_group dimension with no arm of its
    # own. Pivot it ON the row_group (levels become columns), then melt
    # those level-columns back into one keyed `nm` column so it joins onto
    # the main table's row_group rows.
    inner <- .pivot_core(
      ard,
      statistic = stat,
      column = row_group,
      row_group = NULL,
      overall = nm,
      decimals = entry[["decimals"]],
      fmt = entry[["fmt"]] %||% fmt,
      stat_explicit = TRUE,
      warn = FALSE,
      call = call
    )
    levels <- attr(inner, "across_cols")
    add <- do.call(
      rbind,
      lapply(seq_len(nrow(inner)), function(i) {
        data.frame(
          .rg = levels,
          .val = as.character(unlist(inner[i, levels, drop = TRUE])),
          stringsAsFactors = FALSE
        )
      })
    )
    names(add) <- c(row_group, nm)

    wide <- .bind_on_keys(wide, add, keys = row_group, what = nm, call = call)
    across <- c(across, nm)
  }
  attr(wide, "across_cols") <- across
  wide
}

# Strict 1:1 left join of `add`'s non-key columns onto `base`, aligned on
# `keys`. Aborts on duplicate keys on either side: a many-to-many join
# silently fabricates rows, the worst failure mode for a display frame.
.bind_on_keys <- function(base, add, keys, what, call) {
  # nocov start — defensive: aux binding always passes a non-empty
  # row_group key that is present in both frames.
  if (length(keys) == 0L) {
    cli::cli_abort(
      c(
        "No shared row key to align the {.val {what}} columns on.",
        "i" = "The auxiliary ARD shares no key column with the main table.",
        "i" = "Pass {.arg row_group} so both pivot on the same keys."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # nocov end
  bkey <- do.call(paste, c(base[keys], list(sep = "\x1f")))
  akey <- do.call(paste, c(add[keys], list(sep = "\x1f")))
  if (anyDuplicated(bkey) || anyDuplicated(akey)) {
    cli::cli_abort(
      c(
        "Cannot bind {.val {what}} columns: row keys are not unique 1:1.",
        "i" = "Aligned on {.val {keys}}; duplicate combinations would fabricate rows.",
        "i" = "Aggregate or align the auxiliary ARD to one row per key."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  m <- match(bkey, akey)
  for (cn in setdiff(names(add), keys)) {
    base[[cn]] <- add[[cn]][m]
  }
  base
}

# ---------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------

.check_ard_data <- function(data, call) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "{.arg data} must be a data frame.",
        "x" = "You supplied {.obj_type_friendly {data}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (!("stat_name" %in% names(data)) || !("stat" %in% names(data))) {
    cli::cli_abort(
      c(
        "ARD data is missing required columns: {.val stat_name} and / or {.val stat}.",
        "i" = "Typically produced by {.fn cards::ard_stack}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  data
}

# Reserved column tokens. `.variable` makes the analysis variable a column
# band; `.stat` spreads each statistic entry across its own column (the
# landscape "value & change" shell). Both are illegal as real ARD group
# names, so they cannot collide with a user column.
.tabular_col_tokens <- c(".variable", ".stat")

# Parse the `column` argument into a structured pivot spec. Supports:
#   NULL / "TRTA"               simple: arm pivots to columns (today)
#   c(".variable", "TRTA")      variable band x arm; stat entries are ROWS
#   c(".variable", ".stat")     variable band x stat columns; arm -> row stub
# Anything else aborts with a friendly tabular_error_input (replaces the
# raw `the condition has length > 1` crash on a length>1 `column`).
.parse_column_spec <- function(column, call) {
  if (is.null(column)) {
    return(list(arm = NULL, variable_band = FALSE, stat_cols = FALSE))
  }
  if (!is.character(column) || anyNA(column) || length(column) == 0L) {
    cli::cli_abort(
      c(
        "{.arg column} must be a non-empty character vector or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {column}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  toks <- intersect(column, .tabular_col_tokens)
  vars <- setdiff(column, .tabular_col_tokens)

  if (length(toks) == 0L) {
    if (length(column) == 1L) {
      return(list(arm = column, variable_band = FALSE, stat_cols = FALSE))
    }
    cli::cli_abort(
      c(
        "{.arg column} must name a single grouping variable.",
        "x" = "You supplied {length(column)} names: {.val {column}}.",
        "i" = "For a variable band, use {.code column = c(\".variable\", \"<arm>\")}.",
        "i" = "For one column per statistic, use {.code column = c(\".variable\", \".stat\")}.",
        "i" = "A second grouping variable goes in {.arg row_group}, or page it with {.fn subgroup}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (anyDuplicated(column)) {
    cli::cli_abort(
      c(
        "{.arg column} has a repeated entry.",
        "x" = "You supplied {.val {column}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!(".variable" %in% toks)) {
    cli::cli_abort(
      c(
        "{.arg column} uses {.val .stat} without {.val .variable}.",
        "i" = "Stat columns need a variable band: {.code column = c(\".variable\", \".stat\")}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (".stat" %in% toks) {
    if (length(vars) > 0L) {
      cli::cli_abort(
        c(
          "{.arg column} cannot mix {.val .stat} with a grouping variable.",
          "x" = "You also named {.val {vars}}.",
          "i" = "In stat-column mode the arm becomes a leading row stub, not a column band."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(list(arm = NULL, variable_band = TRUE, stat_cols = TRUE))
  }

  if (length(vars) != 1L) {
    cli::cli_abort(
      c(
        "{.arg column} with {.val .variable} needs exactly one arm variable.",
        "x" = "Found {length(vars)} non-token name{?s}: {.val {vars}}.",
        "i" = "Use {.code column = c(\".variable\", \"<arm>\")}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  list(arm = vars, variable_band = TRUE, stat_cols = FALSE)
}

.resolve_statistic_arg <- function(statistic, call) {
  if (
    is.character(statistic) && length(statistic) == 1L && !is.na(statistic)
  ) {
    # Single string applies to every variable regardless of context.
    # Mirror onto the three lookup keys so .resolve_ard_statistic
    # hits one of them whatever the context column says.
    return(list(
      continuous = statistic,
      categorical = statistic,
      default = statistic
    ))
  }
  if (is.list(statistic)) {
    return(statistic)
  }
  cli::cli_abort(
    c(
      "{.arg statistic} must be a single string or a named list.",
      "x" = "You supplied {.obj_type_friendly {statistic}}.",
      "i" = "See {.help pivot_across} for the three accepted forms."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_fmt_arg <- function(fmt, call) {
  if (is.null(fmt)) {
    return(invisible(NULL))
  }
  if (!is.list(fmt) || is.null(names(fmt))) {
    cli::cli_abort(
      c(
        "{.arg fmt} must be a named list of functions or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {fmt}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  bad <- vapply(fmt, function(f) !is.function(f), logical(1L))
  if (any(bad)) {
    cli::cli_abort(
      c(
        "Every entry in {.arg fmt} must be a function.",
        "x" = "These are not functions: {.val {names(fmt)[bad]}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(NULL)
}


# ---------------------------------------------------------------------
# Normalisation helpers (handle list-cols and atomic uniformly)
# ---------------------------------------------------------------------

.normalise_ard_chr <- function(col) {
  if (is.list(col)) {
    return(vapply(
      col,
      function(x) {
        if (is.null(x) || length(x) == 0L) {
          NA_character_
        } else {
          tryCatch(as.character(x[[1L]]), error = function(e) NA_character_)
        }
      },
      character(1L)
    ))
  }
  if (is.character(col)) {
    return(col)
  }
  if (is.factor(col)) {
    return(as.character(col))
  }
  as.character(col)
}

.normalise_ard_num <- function(col) {
  if (is.list(col)) {
    return(vapply(
      col,
      function(s) {
        if (is.null(s) || length(s) == 0L) {
          return(NA_real_)
        }
        v <- s[[1L]]
        if (is.logical(v)) {
          return(as.numeric(v))
        }
        suppressWarnings(tryCatch(
          as.numeric(v),
          error = function(e) NA_real_
        ))
      },
      numeric(1L)
    ))
  }
  if (is.numeric(col)) {
    return(as.double(col))
  }
  if (is.logical(col)) {
    return(as.numeric(col))
  }
  suppressWarnings(as.numeric(col))
}

# ---------------------------------------------------------------------
# Shape detection + input normalisation
# ---------------------------------------------------------------------

.normalise_ard_input <- function(data, column, call) {
  has_variable <- "variable" %in% names(data)
  has_group1 <- "group1" %in% names(data)
  has_group1_level <- "group1_level" %in% names(data)

  if (!has_variable && has_group1_level) {
    # Variable column missing but group cols present: rare odd shape.
    # Treat as Shape A but raise a friendly error if we can't proceed.
    cli::cli_abort(
      c(
        "ARD has {.code group1_level} but no {.code variable} column.",
        "i" = "Provide a {.code variable} column or rename via {.fn cards::rename_ard_columns}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (!has_variable) {
    return(.normalise_shape_d(data, column = column, call = call))
  }

  if (has_group1_level) {
    return(.normalise_shape_a(data, column = column))
  }

  .normalise_shape_b_or_c(data, column = column, call = call)
}

.normalise_shape_a <- function(data, column) {
  df <- data
  df$stat_val <- .normalise_ard_num(df$stat)
  df$stat_chr <- .normalise_ard_chr(df$stat)
  df$var_level <- if ("variable_level" %in% names(df)) {
    .normalise_ard_chr(df$variable_level)
  } else {
    NA_character_
  }
  if (is.list(df$group1)) {
    df$group1 <- .normalise_ard_chr(df$group1)
  }

  group_pairs <- list()
  for (i in seq_len(6L)) {
    g <- paste0("group", i)
    gl <- paste0("group", i, "_level")
    if (g %in% names(df) && gl %in% names(df)) {
      group_pairs[[i]] <- list(name_col = g, level_col = gl)
    } else {
      break
    }
  }

  arm_group_idx <- 1L
  if (!is.null(column) && length(group_pairs) > 0L) {
    for (gi in seq_along(group_pairs)) {
      gp <- group_pairs[[gi]]
      gvals <- .normalise_ard_chr(df[[gp$name_col]])
      if (column %in% gvals) {
        arm_group_idx <- gi
        break
      }
    }
  }

  if (length(group_pairs) >= arm_group_idx) {
    gp <- group_pairs[[arm_group_idx]]
    df$arm <- .normalise_ard_chr(df[[gp$level_col]])
    if (is.null(column)) {
      col_vals <- .normalise_ard_chr(df[[gp$name_col]])
      column <- col_vals[!is.na(col_vals)][1L]
    }
  } else {
    df$arm <- NA_character_
  }

  extra_groups <- character()
  for (gi in seq_along(group_pairs)) {
    if (gi == arm_group_idx) {
      next
    }
    gp <- group_pairs[[gi]]
    group_var_names <- .normalise_ard_chr(df[[gp$name_col]])
    group_var_name <- unique(group_var_names[!is.na(group_var_names)])
    if (length(group_var_name) == 1L) {
      df[[group_var_name]] <- .normalise_ard_chr(df[[gp$level_col]])
      extra_groups <- c(extra_groups, group_var_name)
    }
  }

  list(df = df, column = column, extra_groups = extra_groups, shape = "A")
}

.normalise_shape_b_or_c <- function(data, column, call) {
  df <- data
  df$stat_val <- .normalise_ard_num(df$stat)
  df$stat_chr <- .normalise_ard_chr(df$stat)
  df$var_level <- if ("variable_level" %in% names(df)) {
    .normalise_ard_chr(df$variable_level)
  } else {
    NA_character_
  }

  arm_info <- .detect_renamed_arm(df, column = column, call = call)
  if (!is.null(arm_info)) {
    # Use the canonical list-col normaliser, not as.character(): a cards
    # list-column with NULL elements (the by-variable's own ungrouped row)
    # would otherwise stringify to the literal "NULL" instead of NA.
    df$arm <- .normalise_ard_chr(df[[arm_info$col_name]])
    return(list(
      df = df,
      column = arm_info$col_name,
      extra_groups = arm_info$extra_cols,
      shape = "B"
    ))
  }

  df$arm <- NA_character_
  list(df = df, column = column, extra_groups = character(), shape = "C")
}

.normalise_shape_d <- function(data, column, call) {
  reconstructed <- .reconstruct_renamed_ard(
    data,
    column = column,
    call = call
  )
  df <- reconstructed$df
  # Canonical list-col normaliser, not as.character(): a cards list-column
  # with NULL elements would otherwise stringify to the literal "NULL"
  # instead of NA (mirrors `.normalise_shape_b_or_c`).
  df$arm <- .normalise_ard_chr(df[[reconstructed$column]])
  df$stat_val <- .normalise_ard_num(df$stat)
  df$stat_chr <- .normalise_ard_chr(df$stat)
  df$var_level <- .normalise_ard_chr(df$variable_level)
  list(
    df = df,
    column = reconstructed$column,
    extra_groups = reconstructed$extra_groups,
    shape = "D"
  )
}

.detect_renamed_arm <- function(df, column, call) {
  computed_cols <- c("arm", "var_level", "stat_val", "stat_chr", "ctx")
  non_std <- setdiff(
    names(df),
    c(.tabular_ard_const$standard_cols, computed_cols)
  )
  if ("variable" %in% names(df)) {
    non_std <- setdiff(non_std, unique(df$variable))
  }
  if (length(non_std) == 0L) {
    return(NULL)
  }
  if (!is.null(column)) {
    if (!column %in% non_std) {
      return(NULL)
    }
    return(list(col_name = column, extra_cols = setdiff(non_std, column)))
  }
  if (length(non_std) == 1L) {
    return(list(col_name = non_std, extra_cols = character()))
  }
  cli::cli_abort(
    c(
      "Multiple potential group columns found: {.val {non_std}}.",
      "i" = "Pass {.arg column} to identify the treatment-arm column.",
      "i" = "Example: {.code pivot_across(data, column = {.val {non_std[1L]}})}"
    ),
    class = "tabular_error_input",
    call = call
  )
}

.reconstruct_renamed_ard <- function(df, column, call) {
  std_cols <- intersect(
    names(df),
    c(
      "context",
      "stat_name",
      "stat_label",
      "stat",
      "fmt_fun",
      "warning",
      "error",
      "stat_fmt"
    )
  )
  non_std <- setdiff(names(df), std_cols)

  if (is.null(column)) {
    cli::cli_abort(
      c(
        "Cannot auto-detect treatment-arm column from fully-renamed ARD.",
        "i" = "Pass {.arg column} explicitly.",
        "i" = "Non-standard columns found: {.val {non_std}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!(column %in% names(df))) {
    cli::cli_abort(
      c(
        "Column {.val {column}} not found in data.",
        "i" = "Available columns: {.val {names(df)}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  var_cols <- setdiff(non_std, column)
  n <- nrow(df)
  variable <- rep(NA_character_, n)
  var_level <- rep(NA_character_, n)
  remaining <- rep(TRUE, n)
  for (vc in var_cols) {
    vals <- as.character(df[[vc]])
    hit <- remaining & !is.na(vals) & nzchar(vals)
    if (any(hit)) {
      variable[hit] <- vc
      var_level[hit] <- vals[hit]
      remaining[hit] <- FALSE
    }
    if (!any(remaining)) {
      break
    }
  }

  unknown_rows <- is.na(variable)
  if (any(unknown_rows) && length(var_cols) > 0L) {
    always_na <- var_cols[vapply(
      var_cols,
      function(vc) all(is.na(df[[vc]])),
      logical(1L)
    )]
    fallback <- if (length(always_na) >= 1L) {
      always_na[1L]
    } else {
      used <- unique(variable[!is.na(variable)])
      unused <- setdiff(var_cols, used)
      if (length(unused) >= 1L) unused[1L] else NA_character_
    }
    if (!is.na(fallback)) {
      variable[unknown_rows] <- fallback
    }
  }

  df$variable <- variable
  df$variable_level <- var_level
  list(df = df, column = column, extra_groups = character())
}

# ---------------------------------------------------------------------
# Hierarchical detection
# ---------------------------------------------------------------------

.detect_ard_hierarchy <- function(df) {
  result <- list(
    is_hierarchical = FALSE,
    column_group = "group1",
    n_levels = 0L,
    hier_vars = character()
  )
  if (!all(c("group1", "variable") %in% names(df))) {
    return(result)
  }
  if (!("group2" %in% names(df) && "group2_level" %in% names(df))) {
    return(result)
  }
  g2 <- .normalise_ard_chr(df$group2)
  g2_vals <- unique(g2[!is.na(g2)])
  var_vals <- unique(df$variable)
  if (length(g2_vals) == 0L || length(var_vals) == 0L) {
    return(result)
  }
  if (!all(g2_vals %in% var_vals)) {
    return(result)
  }

  result$is_hierarchical <- TRUE
  result$column_group <- "group1"

  max_group <- 2L
  while (paste0("group", max_group + 1L) %in% names(df)) {
    max_group <- max_group + 1L
  }

  all_group_vals <- character()
  for (g in 2:max_group) {
    gcol <- paste0("group", g)
    if (gcol %in% names(df)) {
      g_norm <- .normalise_ard_chr(df[[gcol]])
      gvals <- unique(g_norm[!is.na(g_norm)])
      all_group_vals <- c(all_group_vals, intersect(gvals, var_vals))
    }
  }
  g1 <- .normalise_ard_chr(df$group1)
  g1_vals <- unique(g1[!is.na(g1)])

  leaf_vars <- setdiff(
    var_vals,
    c(all_group_vals, g1_vals, .tabular_ard_const$keep_sentinels)
  )
  hier_candidates <- unique(c(all_group_vals, leaf_vars))

  depth <- vapply(
    hier_candidates,
    function(hv) {
      hv_rows <- df[df$variable == hv, , drop = FALSE]
      if (nrow(hv_rows) == 0L) {
        return(0L)
      }
      n_parents <- 0L
      for (g in 2:max_group) {
        gcol <- paste0("group", g)
        if (gcol %in% names(hv_rows)) {
          gv <- .normalise_ard_chr(hv_rows[[gcol]])
          if (any(!is.na(gv) & gv %in% hier_candidates)) {
            n_parents <- n_parents + 1L
          }
        }
      }
      n_parents
    },
    integer(1L)
  )
  result$hier_vars <- hier_candidates[order(depth)]
  result$n_levels <- length(result$hier_vars)
  result
}

# ---------------------------------------------------------------------
# Context derivation + row filtering (single-pass)
# ---------------------------------------------------------------------

.extract_context <- function(df) {
  df$ctx <- if ("context" %in% names(df)) {
    as.character(df$context)
  } else {
    ifelse(is.na(df$var_level), "continuous", "categorical")
  }
  df
}

.filter_internal_rows <- function(df, column) {
  is_dot_var <- !is.na(df$variable) &
    grepl("^\\.\\.", df$variable) &
    !(df$variable %in% .tabular_ard_const$keep_sentinels)
  is_internal_ctx <- df$ctx %in% .tabular_ard_const$internal_contexts
  is_column_var <- if (!is.null(column)) {
    !is.na(df$variable) & df$variable == column
  } else {
    rep(FALSE, nrow(df))
  }
  # The `.by` by-variable's own ungrouped tabulation row. `ard_stack(.by =
  # ARM)` injects an `ard_tabulate(ARM)` row whose `variable` IS the
  # grouping variable (e.g. "ARM" / "TRT01A") and whose context is
  # "tabulate". That row is already removed by `is_column_var` above: the
  # resolved `column` is the grouping variable's name, so `variable ==
  # column` drops the self-row by NAME. We must NOT additionally drop every
  # NA-arm tabulate row: a genuine `ard_tabulate()` categorical variable
  # (SEX, RACE, ...) carries its pooled / overall row (the one a later
  # `overall =` relabels to "Total") with NA arm and the SAME tabulate
  # context, so a blanket structural mask would blank the entire Total
  # column for every categorical variable.
  keep <- !(is_dot_var | is_internal_ctx | is_column_var)
  df[keep, , drop = FALSE]
}

.apply_overall_label <- function(df, overall, call = rlang::caller_env()) {
  if (is.null(overall)) {
    return(df[!is.na(df$arm), , drop = FALSE])
  }
  if (anyNA(df$arm) && overall %in% df$arm[!is.na(df$arm)]) {
    cli::cli_warn(
      c(
        "Overall label {.val {overall}} collides with an existing arm.",
        "i" = "The pooled rows and that arm now share one column; pass a distinct {.arg overall} or rename the arm upstream."
      ),
      class = "tabular_warning_input",
      call = call
    )
  }
  df$arm <- ifelse(is.na(df$arm), overall, df$arm)
  df
}

.filter_to_column_group <- function(df, column, overall) {
  if (is.null(column) || !("group1" %in% names(df))) {
    return(df)
  }
  g1 <- if (is.list(df$group1)) {
    .normalise_ard_chr(df$group1)
  } else {
    df$group1
  }
  if (!(column %in% g1)) {
    return(df)
  }
  is_overall_row <- if (!is.null(overall)) df$arm == overall else FALSE
  keep <- is.na(g1) | g1 == column | is_overall_row
  df[keep, , drop = FALSE]
}

# ---------------------------------------------------------------------
# Glue-ref parsing + format string interpolation (no glue dep)
# ---------------------------------------------------------------------

.parse_glue_refs <- function(fmt_str) {
  cleaned <- gsub("\\{\\{[^}]*\\}\\}", "", fmt_str)
  m <- gregexpr("\\{([^{}]+)\\}", cleaned)
  refs <- regmatches(cleaned, m)[[1L]]
  if (length(refs) == 0L) {
    return(character())
  }
  gsub("^\\{|\\}$", "", refs)
}

.interpolate_format <- function(fmt_str, refs, values) {
  out <- fmt_str
  for (r in refs) {
    val <- values[[r]]
    if (is.null(val) || is.na(val)) {
      val <- ""
    }
    out <- gsub(
      paste0("\\{", r, "\\}"),
      val,
      out,
      fixed = FALSE,
      perl = FALSE
    )
  }
  out
}

# ---------------------------------------------------------------------
# Statistic resolution
# ---------------------------------------------------------------------

.resolve_ard_statistic <- function(var_name, context, statistic) {
  statistic[[var_name]] %||%
    statistic[[context]] %||%
    statistic[["default"]] %||%
    "{n}"
}

# Emit one warning when NONE of the `statistic` keys match any context
# or variable present in the ARD: the whole list is mis-keyed (the
# canonical `summary`-vs-`continuous` footgun), so every cell falls to
# the `{n}` fallback, the most common cause of silently wrong output.
#
# Deliberately narrow: a `{n}` fallback is the CORRECT output for some
# contexts (hierarchical AE counts, plain tabulate counts), so when at
# least one key is relevant the user is trusted and no warning fires.
# A `default` key covers everything, so it also suppresses the warning.
.warn_unmatched_context <- function(
  df,
  statistic,
  stat_explicit,
  is_hierarchical,
  call
) {
  if (!stat_explicit || is_hierarchical) {
    return(invisible(NULL))
  }
  keys <- names(statistic)
  if (is.null(keys) || "default" %in% keys) {
    return(invisible(NULL))
  }
  rows <- df[
    !is.na(df$variable) &
      !(df$variable %in% .tabular_ard_const$keep_sentinels),
    ,
    drop = FALSE
  ]
  # nocov start — defensive: the earlier empty-after-filter abort means
  # at least one displayable row always remains by the time we get here.
  if (nrow(rows) == 0L) {
    return(invisible(NULL))
  }
  # nocov end
  present <- unique(c(rows$ctx, rows$variable))
  if (any(keys %in% present)) {
    return(invisible(NULL))
  }
  ctxs <- sort(unique(rows$ctx))
  cli::cli_warn(
    c(
      "No {.arg statistic} key matches this ARD; every cell fell back to {.code {{n}}}.",
      "x" = "Provided key{cli::qty(keys)}{?s}: {.val {keys}}.",
      "x" = "ARD context{cli::qty(ctxs)}{?s}: {.val {ctxs}}.",
      "i" = "Key {.arg statistic} by {.code unique(ard$context)}, for example {.code list({ctxs[1]} = \"...\")}, or pass a {.code default}."
    ),
    class = "tabular_warning_unmatched_context",
    call = call
  )
  invisible(NULL)
}

# Validate the `row_group` argument: a single second-dimension grouping
# variable (the non-column `.by` var, e.g. SEX). NULL is the default
# (single dimension). Must name a group surfaced by normalisation
# (`extra_groups`) and must differ from `column`.
.check_row_group <- function(row_group, column, extra_groups, call) {
  if (is.null(row_group)) {
    return(NULL)
  }
  if (
    !is.character(row_group) || length(row_group) != 1L || is.na(row_group)
  ) {
    cli::cli_abort(
      c(
        "{.arg row_group} must be a single column name or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {row_group}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!is.null(column) && identical(row_group, column)) {
    cli::cli_abort(
      c(
        "{.arg row_group} must differ from {.arg column}.",
        "x" = "Both are {.val {column}}.",
        "i" = "{.arg column} pivots into arm columns; {.arg row_group} stays a leading row dimension."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!(row_group %in% extra_groups)) {
    cli::cli_abort(
      c(
        "{.arg row_group} {.val {row_group}} is not a second grouping variable in {.arg data}.",
        "i" = if (length(extra_groups) > 0L) {
          "Available second-dimension group{?s}: {.val {extra_groups}}."
        } else {
          "No second grouping dimension was detected; {.arg row_group} is supported for a cards {.fn ard_stack} 2-variable {.code .by}."
        },
        "i" = "For a 2-variable {.code .by}, pass the non-arm group var as {.arg row_group}, or page it with {.fn subgroup} instead."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  row_group
}

.is_multirow_spec <- function(fmt_spec) {
  is.character(fmt_spec) && length(fmt_spec) > 1L && !is.null(names(fmt_spec))
}

.validate_format_stats <- function(fmt_str, available_stats, var_name, call) {
  refs <- .parse_glue_refs(fmt_str)
  if (length(refs) == 0L) {
    return(invisible(NULL))
  }
  missing <- setdiff(refs, available_stats)
  if (length(missing) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_abort(
    c(
      "Format string for {.val {var_name}} references unknown stat{?s}: {.val {missing}}.",
      "i" = "Format string: {.val {fmt_str}}",
      "i" = "Available stat_names: {.val {sort(available_stats)}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# ---------------------------------------------------------------------
# Decimals + per-stat formatting (vectorised by stat_name group)
# ---------------------------------------------------------------------

.resolve_ard_decimals <- function(
  decimals,
  row_group = NULL,
  rg_levels = NULL,
  variables = NULL,
  call = rlang::caller_env()
) {
  if (is.null(decimals)) {
    return(list(global = NULL, per_var = NULL))
  }
  if (is.numeric(decimals) && !is.null(names(decimals))) {
    return(list(global = decimals, per_var = NULL))
  }
  if (is.list(decimals)) {
    keys <- setdiff(names(decimals), ".default")
    # Per-row-group: a list keyed by row_group values. Engages only when a
    # row_group is declared AND every non-.default key is one of its levels,
    # so a per-variable list (keyed by variable names) is never reinterpreted.
    if (
      !is.null(row_group) && length(keys) > 0L && all(keys %in% rg_levels)
    ) {
      return(list(
        global = NULL,
        per_var = NULL,
        per_group = list(
          default = decimals[[".default"]],
          map = decimals[keys]
        )
      ))
    }
    # A list whose keys look like group values but no row_group was passed:
    # the keys match nothing in the data, so the user almost certainly meant
    # per-row-group. Fail loud rather than silently format nothing.
    if (
      is.null(row_group) &&
        length(keys) > 0L &&
        !is.null(variables) &&
        !any(keys %in% variables)
    ) {
      cli::cli_abort(
        c(
          "{.arg decimals} keys match no variable in {.arg data}.",
          "x" = "Names {.val {keys}} look like {.arg row_group} values.",
          "i" = "Pass {.arg row_group} to format decimals per row group."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(list(
      global = decimals[[".default"]],
      per_var = decimals[keys]
    ))
  }
  list(global = NULL, per_var = NULL)
}

# Resolve a per-row-group token spec to a decimal count for one stat.
# Token fallback mirrors the per-variable path: the matched group's token, then
# the per-group .default token, then NULL (built-in). A bare unnamed scalar
# applies to every token in the group.
.group_decimals_for_stat <- function(spec_map, spec_def, stat_name) {
  pick <- function(spec) {
    if (is.null(spec)) {
      return(NULL)
    }
    if (is.null(names(spec)) && length(spec) == 1L) {
      return(spec[[1L]])
    }
    if (stat_name %in% names(spec)) {
      return(spec[[stat_name]])
    }
    NULL
  }
  pick(spec_map) %||% pick(spec_def)
}

.format_stat_vectorised <- function(
  df,
  decimals,
  fmt,
  pct_threshold,
  call,
  row_group = NULL
) {
  # Vectorised by stat_name group (fixes galley B1: per-row vapply).
  out <- character(nrow(df))
  if (nrow(df) == 0L) {
    return(out)
  }

  stat_names <- df$stat_name
  unique_stats <- unique(stat_names)
  groups <- if (!is.null(row_group) && row_group %in% names(df)) {
    .normalise_ard_chr(df[[row_group]])
  } else {
    NULL
  }

  for (sn in unique_stats) {
    idx <- which(stat_names == sn)
    values <- df$stat_val[idx]
    value_chrs <- df$stat_chr[idx]
    variables <- df$variable[idx]

    out[idx] <- .format_stat_group(
      values,
      value_chrs = value_chrs,
      stat_name = sn,
      variables = variables,
      decimals = decimals,
      fmt = fmt,
      pct_threshold = pct_threshold,
      call = call,
      groups = if (is.null(groups)) NULL else groups[idx]
    )
  }
  out
}

.format_stat_group <- function(
  values,
  value_chrs,
  stat_name,
  variables,
  decimals,
  fmt,
  pct_threshold,
  call,
  groups = NULL
) {
  n <- length(values)
  out <- character(n)
  non_finite <- !is.na(values) & !is.finite(values)
  out[non_finite] <- ""

  if (stat_name %in% .tabular_ard_const$logical_stat_names) {
    has_chr <- !is.na(value_chrs)
    out[has_chr] <- value_chrs[has_chr]
    return(out)
  }

  is_chr_only <- is.na(values) & !is.na(value_chrs)
  out[is_chr_only] <- value_chrs[is_chr_only]

  both_na <- is.na(values) & is.na(value_chrs)
  todo <- !(non_finite | is_chr_only | both_na)
  if (!any(todo)) {
    return(out)
  }

  if (!is.null(fmt) && stat_name %in% names(fmt)) {
    fn <- fmt[[stat_name]]
    out[todo] <- vapply(
      values[todo],
      function(v) as.character(fn(v)),
      character(1L)
    )
    return(out)
  }

  # Per-row-group decimals: select the token precision by each row's row_group
  # value. Sits after the fmt override (fmt still wins) and before per_var /
  # global. `groups` is aligned 1:1 with `values`.
  per_group <- decimals[["per_group"]]
  if (!is.null(per_group) && !is.null(groups)) {
    # split() drops NA-group rows (overall-arm / ungrouped rows reach format
    # time with NA row_group), which would blank them. Bucket NA to a sentinel
    # that never matches a real level, so it falls to .default then built-in.
    gv <- groups[todo]
    gv[is.na(gv)] <- "\x01"
    by_grp <- split(which(todo), gv)
    for (g in names(by_grp)) {
      sel <- by_grp[[g]]
      grp_dec <- if (identical(g, "\x01")) NULL else per_group$map[[g]]
      d <- .group_decimals_for_stat(grp_dec, per_group$default, stat_name)
      if (!is.null(d)) {
        out[sel] <- .format_stat_with_decimals(
          values[sel],
          stat_name,
          as.integer(d),
          pct_threshold
        )
      } else {
        out[sel] <- .format_stat_default(values[sel], stat_name)
      }
    }
    return(out)
  }

  per_var <- decimals$per_var
  global <- decimals$global

  if (
    !is.null(per_var) &&
      any(variables[todo] %in% names(per_var)) &&
      stat_name %in% unique(unlist(lapply(per_var, names)))
  ) {
    by_var <- split(which(todo), variables[todo])
    for (var_name in names(by_var)) {
      sel <- by_var[[var_name]]
      var_dec <- per_var[[var_name]]
      if (
        !is.null(var_dec) &&
          stat_name %in% names(var_dec)
      ) {
        d <- as.integer(var_dec[[stat_name]])
        out[sel] <- .format_stat_with_decimals(
          values[sel],
          stat_name,
          d,
          pct_threshold
        )
      } else if (!is.null(global) && stat_name %in% names(global)) {
        d <- as.integer(global[[stat_name]])
        out[sel] <- .format_stat_with_decimals(
          values[sel],
          stat_name,
          d,
          pct_threshold
        )
      } else {
        out[sel] <- .format_stat_default(values[sel], stat_name)
      }
    }
    return(out)
  }

  if (!is.null(global) && stat_name %in% names(global)) {
    d <- as.integer(global[[stat_name]])
    out[todo] <- .format_stat_with_decimals(
      values[todo],
      stat_name,
      d,
      pct_threshold
    )
    return(out)
  }

  out[todo] <- .format_stat_default(values[todo], stat_name)
  out
}

.format_stat_default <- function(values, stat_name) {
  switch(
    stat_name,
    n = ,
    N = ,
    N_obs = ,
    N_miss = ,
    N_nonmiss = ,
    n_cum = ,
    n_event = ,
    n.risk = sprintf("%d", as.integer(round(values))),
    p = sprintf("%.0f", values * 100),
    p_miss = ,
    p_nonmiss = ,
    p_cum = sprintf("%.1f", values * 100),
    mean = sprintf("%.1f", values),
    sd = sprintf("%.2f", values),
    median = sprintf("%.1f", values),
    min = ,
    max = sprintf("%.1f", values),
    p25 = ,
    p75 = sprintf("%.1f", values),
    p.value = .format_p_value(values),
    estimate = ,
    std.error = sprintf("%.4f", values),
    statistic = sprintf("%.2f", values),
    parameter = sprintf("%.1f", values),
    conf.low = ,
    conf.high = ,
    conf.level = sprintf("%.2f", values),
    sprintf("%.1f", values)
  )
}

.format_stat_with_decimals <- function(values, stat_name, d, pct_threshold) {
  is_pct <- stat_name %in% c("p", "p_miss", "p_nonmiss", "p_cum")
  v <- if (is_pct) values * 100 else values
  fmt <- paste0("%.", d, "f")
  out <- sprintf(fmt, v)
  if (is_pct && isTRUE(pct_threshold)) {
    lo <- 10^(-d)
    hi <- 100 - lo
    below <- !is.na(v) & v > 0 & v < lo
    above <- !is.na(v) & v > hi & v < 100
    out[below] <- paste0("<", sprintf(fmt, lo))
    out[above] <- paste0(">", sprintf(fmt, hi))
  }
  out
}

.format_p_value <- function(values) {
  out <- character(length(values))
  out[is.na(values)] <- ""
  ok <- !is.na(values)
  small <- ok & values < 0.001
  out[small] <- "<0.001"
  rest <- ok & !small
  out[rest] <- sprintf("%.3f", values[rest])
  out
}

# ---------------------------------------------------------------------
# Per-arm cell interpolation (vectorised over arms via single split)
# ---------------------------------------------------------------------

.interpolate_cells_all_arms <- function(
  var_df,
  arm_levels,
  fmt_str,
  pct_zero
) {
  refs <- .parse_glue_refs(fmt_str)
  by_arm <- split(var_df, var_df$arm)
  vapply(
    arm_levels,
    function(a) {
      subset <- by_arm[[a]]
      if (is.null(subset) || nrow(subset) == 0L) {
        return("")
      }
      stat_vec <- stats::setNames(subset$stat_fmt, subset$stat_name)
      if (!pct_zero && "n" %in% names(stat_vec)) {
        n_num <- suppressWarnings(as.numeric(stat_vec[["n"]]))
        if (!is.na(n_num) && n_num == 0) {
          return(stat_vec[["n"]])
        }
      }
      .interpolate_format(fmt_str, refs, as.list(stat_vec))
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Build flat (non-hierarchical) wide output
# ---------------------------------------------------------------------

.build_flat_wide <- function(df, statistic, extra_groups, pct_zero, call) {
  arm_levels <- unique(df$arm[!is.na(df$arm)])
  n_arms <- length(arm_levels)

  if (length(extra_groups) > 0L) {
    eg_vals <- lapply(extra_groups, function(ec) as.character(df[[ec]]))
    df$var_group_key <- do.call(
      paste,
      c(list(df$variable), eg_vals, sep = "\x1f")
    )
  } else {
    df$var_group_key <- df$variable
  }
  key_order <- unique(df$var_group_key)

  chunks <- list()
  chunk_idx <- 0L
  df_by_key <- split(df, df$var_group_key)

  add_chunk <- function(var_name, label, cells, eg_values) {
    chunk <- list(
      variable = rep(var_name, n_arms),
      stat_label = rep(label, n_arms),
      arm = arm_levels,
      cell_text = unname(cells)
    )
    for (ec in names(eg_values)) {
      chunk[[ec]] <- rep(eg_values[[ec]], n_arms)
    }
    chunk_idx <<- chunk_idx + 1L
    chunks[[chunk_idx]] <<- chunk
  }

  for (key in key_order) {
    key_df <- df_by_key[[key]]
    if (is.null(key_df) || nrow(key_df) == 0L) {
      next
    }
    var_name <- key_df$variable[1L]
    ctx <- key_df$ctx[1L]
    fmt_spec <- .resolve_ard_statistic(var_name, ctx, statistic)

    eg_values <- if (length(extra_groups) > 0L) {
      stats::setNames(
        lapply(extra_groups, function(ec) as.character(key_df[[ec]][1L])),
        extra_groups
      )
    } else {
      list()
    }

    if (.is_multirow_spec(fmt_spec)) {
      for (row_label in names(fmt_spec)) {
        .validate_format_stats(
          fmt_spec[[row_label]],
          unique(key_df$stat_name),
          var_name,
          call
        )
        cells <- .interpolate_cells_all_arms(
          key_df,
          arm_levels,
          fmt_spec[[row_label]],
          pct_zero
        )
        add_chunk(var_name, row_label, cells, eg_values)
      }
    } else {
      fmt_str <- fmt_spec
      .validate_format_stats(
        fmt_str,
        unique(key_df$stat_name),
        var_name,
        call
      )
      levels <- unique(key_df$var_level)
      if (all(is.na(levels))) {
        cells <- .interpolate_cells_all_arms(
          key_df,
          arm_levels,
          fmt_str,
          pct_zero
        )
        add_chunk(var_name, var_name, cells, eg_values)
      } else {
        levels <- levels[!is.na(levels)]
        for (lvl in levels) {
          lvl_df <- key_df[
            !is.na(key_df$var_level) & key_df$var_level == lvl,
            ,
            drop = FALSE
          ]
          cells <- .interpolate_cells_all_arms(
            lvl_df,
            arm_levels,
            fmt_str,
            pct_zero
          )
          add_chunk(var_name, lvl, cells, eg_values)
        }
      }
    }
  }

  if (chunk_idx == 0L) {
    empty <- data.frame(
      variable = character(),
      stat_label = character(),
      stringsAsFactors = FALSE
    )
    for (a in arm_levels) {
      empty[[a]] <- character()
    }
    return(empty)
  }

  all_chunks <- chunks[seq_len(chunk_idx)]
  col_names <- c("variable", "stat_label", "arm", "cell_text", extra_groups)
  combined <- vector("list", length(col_names))
  names(combined) <- col_names
  for (cn in col_names) {
    combined[[cn]] <- unlist(lapply(all_chunks, `[[`, cn), use.names = FALSE)
  }
  long_df <- as.data.frame(combined, stringsAsFactors = FALSE)
  .pivot_long_to_wide(long_df, arm_levels, extra_groups)
}

.pivot_long_to_wide <- function(long_df, arm_levels, extra_groups) {
  key_cols <- c(extra_groups, "variable", "stat_label")
  keep <- c(key_cols, "arm", "cell_text")
  long_df <- unique(long_df[, keep, drop = FALSE])

  key_parts <- lapply(key_cols, function(k) long_df[[k]])
  long_df$row_key <- do.call(paste, c(key_parts, list(sep = "\x1f")))

  first_arm <- long_df[long_df$arm == arm_levels[1L], , drop = FALSE]
  wide <- first_arm[, key_cols, drop = FALSE]
  wide_key_parts <- lapply(key_cols, function(k) wide[[k]])
  wide_key <- do.call(paste, c(wide_key_parts, list(sep = "\x1f")))

  for (a in arm_levels) {
    arm_df <- long_df[long_df$arm == a, , drop = FALSE]
    wide[[a]] <- arm_df$cell_text[match(wide_key, arm_df$row_key)]
  }
  wide
}

# ---------------------------------------------------------------------
# Build hierarchical (SOC / PT, N-level) wide output
# ---------------------------------------------------------------------

.build_hierarchical_wide <- function(
  df,
  statistic,
  hierarchy,
  column,
  pct_zero,
  call
) {
  arm_levels <- unique(df$arm[!is.na(df$arm)])
  hier_vars <- hierarchy$hier_vars
  n_levels <- hierarchy$n_levels

  gval_col <- function(g) paste0("_g", g, "_val")
  max_g <- 1L
  while (paste0("group", max_g + 1L, "_level") %in% names(df)) {
    g <- max_g + 1L
    df[[gval_col(g)]] <- .normalise_ard_chr(df[[paste0(
      "group",
      g,
      "_level"
    )]])
    max_g <- g
  }
  if ("group1_level" %in% names(df)) {
    df[[gval_col(1L)]] <- .normalise_ard_chr(df$group1_level)
  }

  if (
    !is.null(column) && gval_col(1L) %in% names(df) && "group1" %in% names(df)
  ) {
    g1_names <- .normalise_ard_chr(df$group1)
    is_shifted <- !is.na(g1_names) &
      g1_names != column &
      g1_names %in% hier_vars
    if (any(is_shifted)) {
      needed <- gval_col(seq(2L, max_g + 1L))
      for (nc in setdiff(needed, names(df))) {
        df[[nc]] <- NA_character_
      }
      for (g in seq(max_g, 1L, -1L)) {
        df[[gval_col(g + 1L)]][is_shifted] <- df[[gval_col(g)]][is_shifted]
      }
      df[[gval_col(1L)]][is_shifted] <- NA_character_
    }
  }

  fmt_strs <- list()
  for (hv in hier_vars) {
    hv_df <- df[df$variable == hv, , drop = FALSE]
    if (nrow(hv_df) == 0L) {
      next
    }
    fs <- .resolve_ard_statistic(hv, hv_df$ctx[1L], statistic)
    if (.is_multirow_spec(fs)) {
      fs <- fs[[1L]]
    }
    .validate_format_stats(fs, unique(hv_df$stat_name), hv, call)
    fmt_strs[[hv]] <- fs
  }

  out_cols <- if (n_levels <= 2L) {
    c("soc", "label")[seq_len(n_levels)]
  } else {
    c("soc", paste0("l", seq(2L, n_levels - 1L)), "label")
  }

  df_by_var <- split(df, df$variable)
  state <- new.env(parent = emptyenv())
  state$chunks <- list()
  state$chunk_idx <- 0L

  overall_df <- df_by_var[["..ard_hierarchical_overall.."]]
  if (!is.null(overall_df) && nrow(overall_df) > 0L) {
    fmt_str <- .resolve_ard_statistic(
      "..ard_hierarchical_overall..",
      overall_df$ctx[1L],
      statistic
    )
    if (.is_multirow_spec(fmt_str)) {
      fmt_str <- fmt_str[[1L]]
    }
    .validate_format_stats(
      fmt_str,
      unique(overall_df$stat_name),
      "..ard_hierarchical_overall..",
      call
    )
    # The cards overall row carries the internal
    # `..ard_hierarchical_overall..` sentinel as its variable name with no
    # human label (variable_level is just TRUE). Append it as a LENGTH-1
    # level: `.hier_append_chunk()` then fills the leaf (`label`) and `soc`
    # with the sentinel and leaves the intermediate nesting-key columns
    # (`l2`, `l3`, ...) NA -- the grand total has no SOC/PT ancestor.
    # `.apply_label_map()` resolves the sentinel to the registry default
    # ("Overall") or the user's `label` override, at every hierarchy depth.
    overall_sentinel <- "..ard_hierarchical_overall.."
    cells <- .interpolate_cells_all_arms(
      overall_df,
      arm_levels,
      fmt_str,
      pct_zero
    )
    .hier_append_chunk(
      state,
      overall_sentinel,
      "overall",
      cells,
      out_cols,
      n_levels
    )
  }

  .hier_process_level(
    state,
    level = 1L,
    parent_filters = list(),
    df_by_var = df_by_var,
    hier_vars = hier_vars,
    fmt_strs = fmt_strs,
    arm_levels = arm_levels,
    n_levels = n_levels,
    out_cols = out_cols,
    pct_zero = pct_zero,
    gval_col_fn = gval_col
  )

  if (state$chunk_idx == 0L) {
    empty <- as.data.frame(
      stats::setNames(
        replicate(n_levels, character(), simplify = FALSE),
        out_cols
      ),
      stringsAsFactors = FALSE
    )
    empty$row_type <- character()
    return(empty)
  }

  all_chunks <- state$chunks[seq_len(state$chunk_idx)]
  col_names <- c(out_cols, "row_type", "arm", "cell_text")
  combined <- vector("list", length(col_names))
  names(combined) <- col_names
  for (cn in col_names) {
    combined[[cn]] <- unlist(lapply(all_chunks, `[[`, cn), use.names = FALSE)
  }
  long_df <- as.data.frame(combined, stringsAsFactors = FALSE)

  meta_cols <- c(out_cols, "row_type")
  long_df$row_key <- do.call(paste, c(long_df[meta_cols], list(sep = "\x1f")))
  row_keys <- unique(long_df$row_key)
  wide <- long_df[match(row_keys, long_df$row_key), meta_cols, drop = FALSE]
  for (a in arm_levels) {
    arm_df <- long_df[long_df$arm == a, , drop = FALSE]
    wide[[a]] <- arm_df$cell_text[match(row_keys, arm_df$row_key)]
  }
  wide
}

# ---------------------------------------------------------------------
# Hierarchical helpers (top-level so covr can instrument; the env-based
# state replaces what would otherwise be `<<-` mutations inside nested
# closures)
# ---------------------------------------------------------------------

.hier_append_chunk <- function(
  state,
  level_vals,
  row_type,
  cells,
  out_cols,
  n_levels
) {
  n <- length(cells)
  chunk <- vector("list", n_levels + 3L)
  names(chunk) <- c(out_cols, "row_type", "arm", "cell_text")
  # The leaf column (out_cols[n_levels], "label") always shows THIS row's
  # own deepest level value (the display stub); the intermediate
  # nesting-key columns hold the ancestor value at their depth, or NA for
  # depths below this row's level.
  display_val <- level_vals[[length(level_vals)]]
  for (i in seq_len(n_levels)) {
    val <- if (i == n_levels) {
      display_val
    } else if (i <= length(level_vals)) {
      level_vals[[i]]
    } else {
      NA_character_
    }
    chunk[[out_cols[i]]] <- rep(val, n)
  }
  chunk$row_type <- rep(row_type, n)
  chunk$arm <- names(cells)
  chunk$cell_text <- unname(cells)
  state$chunk_idx <- state$chunk_idx + 1L
  state$chunks[[state$chunk_idx]] <- chunk
  invisible(state)
}

.hier_process_level <- function(
  state,
  level,
  parent_filters,
  df_by_var,
  hier_vars,
  fmt_strs,
  arm_levels,
  n_levels,
  out_cols,
  pct_zero,
  gval_col_fn
) {
  hv <- hier_vars[level]
  if (is.null(fmt_strs[[hv]])) {
    return(invisible(state))
  }
  lv_df <- df_by_var[[hv]]
  if (is.null(lv_df) || nrow(lv_df) == 0L) {
    return(invisible(state))
  }
  for (pf in parent_filters) {
    if (pf$col %in% names(lv_df)) {
      lv_df <- lv_df[
        !is.na(lv_df[[pf$col]]) & lv_df[[pf$col]] == pf$val,
        ,
        drop = FALSE
      ]
    }
  }
  lv_levels <- unique(lv_df$var_level[!is.na(lv_df$var_level)])
  ancestors <- vapply(parent_filters, `[[`, character(1L), "val")
  rtype <- if (n_levels <= 2L && level == 1L) {
    "soc"
  } else if (n_levels <= 2L && level == 2L) {
    "pt"
  } else {
    tolower(hv)
  }
  for (lv_val in lv_levels) {
    lv_subset <- lv_df[
      !is.na(lv_df$var_level) & lv_df$var_level == lv_val,
      ,
      drop = FALSE
    ]
    # Length == this row's depth: ancestors plus the current level value.
    # `.hier_append_chunk` fills the leaf (display) column with the
    # current value and leaves deeper nesting-key columns NA, rather than
    # repeating the current value into them (which polluted l2.. for a
    # 3+-level hierarchy).
    level_vals <- c(ancestors, lv_val)
    cells <- .interpolate_cells_all_arms(
      lv_subset,
      arm_levels,
      fmt_strs[[hv]],
      pct_zero
    )
    .hier_append_chunk(state, level_vals, rtype, cells, out_cols, n_levels)
    if (level < n_levels) {
      new_filters <- c(
        parent_filters,
        list(list(col = gval_col_fn(level + 1L), val = lv_val))
      )
      .hier_process_level(
        state,
        level + 1L,
        new_filters,
        df_by_var,
        hier_vars,
        fmt_strs,
        arm_levels,
        n_levels,
        out_cols,
        pct_zero,
        gval_col_fn
      )
    }
  }
  invisible(state)
}

# ---------------------------------------------------------------------
# Label remap
# ---------------------------------------------------------------------

.apply_label_map <- function(wide, label) {
  # Seed registry defaults for kept sentinels (e.g.
  # `..ard_hierarchical_overall..` -> "Overall"); a user `label` for the same
  # key wins. `c(NULL, defaults) == defaults`, so this also supplies the
  # default when the caller passed no `label` at all.
  defaults <- .tabular_ard_const$sentinel_labels
  label <- c(label, defaults[setdiff(names(defaults), names(label))])
  label_from <- names(label)
  label_to <- unname(unlist(label))
  for (col in intersect(c("variable", "soc", "label"), names(wide))) {
    m <- match(wide[[col]], label_from)
    hit <- !is.na(m)
    if (any(hit)) {
      wide[[col]][hit] <- label_to[m[hit]]
    }
  }
  wide
}

# ---------------------------------------------------------------------
# ARD lookup tables — sentinels, internal contexts, stat-type classes,
# and the canonical column list used by shape detection.
# ---------------------------------------------------------------------

.tabular_ard_const <- list(
  # Sentinels that represent real display rows; never filter.
  keep_sentinels = c("..ard_hierarchical_overall.."),

  # Default display label for each kept sentinel, applied by
  # `.apply_label_map()` unless the user's `label` overrides the same key.
  # INVARIANT: names(sentinel_labels) == keep_sentinels (pinned by a test) so
  # no kept sentinel can ever reach output carrying its raw `..` name.
  sentinel_labels = c("..ard_hierarchical_overall.." = "Overall"),

  # Internal contexts to filter out. `tabulate` is NOT here: it is a
  # genuine categorical context from `cards::ard_tabulate()`. The
  # `.by` by-variable's own tabulation row is dropped by VARIABLE NAME
  # (`variable == column`, via `is_column_var` in
  # `.filter_internal_rows()`), not by blanket context.
  internal_contexts = c("attributes", "total_n"),

  # stat_name values that hold character values (not numeric).
  char_stat_names = c("method", "alternative", "label", "class", "conf.type"),

  # stat_name values that hold logical values.
  logical_stat_names = c("paired", "var.equal", "correct", "conf.int"),

  # Standard ARD column names; anything else is a renamed group / variable.
  standard_cols = c(
    "variable",
    "variable_level",
    paste0("group", 1:6),
    paste0("group", 1:6, "_level"),
    "context",
    "stat_name",
    "stat_label",
    "stat",
    "fmt_fun",
    "warning",
    "error",
    "stat_fmt"
  )
)
