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
#' @param column *Grouping column whose unique values become arms.*
#'   `<character(1) | NULL>: default NULL`. `NULL` auto-detects
#'   from the ARD's `group1` value or — for renamed input — picks
#'   the single non-standard column. Pass a string when multiple
#'   group columns exist.
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
#' @param decimals *Per-stat decimal precision.*
#'   `<named integer | named list>: default `c()``. Accepts two
#'   forms:
#'
#'   *   **named integer vector** — global per-stat overrides
#'       (`c(mean = 1, sd = 2, p = 0)`).
#'   *   **named list** — per-variable plus `.default`
#'       (`list(AGE = c(mean = 2), .default = c(p = 1))`).
#'
#'   Built-in defaults apply when neither sets a stat.
#'
#' @param fmt *Per-stat custom formatter functions.*
#'   `<named list of function>: default `list()``. Each function
#'   takes a numeric value and returns a character string;
#'   overrides built-ins and `decimals` for that stat. Useful for
#'   p-value styling and other domain-specific formatting.
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
#' ## Indentation of `stat_label`
#'
#' Categorical levels and the multi-row continuous stat labels come
#' back already indented with two leading spaces, ready to render as a
#' plain display column. Do **not** also set `col_spec(indent = ...)` on
#' `stat_label` — that stacks the engine indent on top of the string
#' indent (a double indent). Use one or the other.
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
  fmt = NULL
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

  df <- .apply_overall_label(df, overall = overall)
  df <- .filter_to_column_group(df, column = column, overall = overall)

  # Warn once when an explicitly-supplied `statistic` matches no context
  # or variable in the ARD: every cell falls back to `{n}`, the single
  # most common way to get silently wrong output (the canonical
  # `summary`-vs-`continuous` mis-key). Skipped on the hierarchical path,
  # which formats counts directly regardless of the statistic keys.
  .warn_unmatched_context(
    df,
    statistic,
    stat_explicit = stat_explicit,
    is_hierarchical = hierarchy$is_hierarchical,
    call = call
  )

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

  decimals_resolved <- .resolve_ard_decimals(decimals)
  df$stat_fmt <- .format_stat_vectorised(
    df,
    decimals = decimals_resolved,
    fmt = fmt,
    pct_threshold = TRUE,
    call = call
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

  # Indent BEFORE label remap so the stat_label == variable comparison
  # uses raw variable names. After remap, "AGE" stat_label would no
  # longer equal the remapped "Age (years)" variable and would be
  # falsely indented.
  if (!hierarchy$is_hierarchical && "stat_label" %in% names(wide)) {
    is_level_row <- !is.na(wide$stat_label) &
      !is.na(wide$variable) &
      wide$stat_label != wide$variable
    wide$stat_label[is_level_row] <- paste0(
      "  ",
      wide$stat_label[is_level_row]
    )
  }

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

.apply_overall_label <- function(df, overall) {
  if (is.null(overall)) {
    return(df[!is.na(df$arm), , drop = FALSE])
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

.resolve_ard_decimals <- function(decimals) {
  if (is.null(decimals)) {
    return(list(global = NULL, per_var = NULL))
  }
  if (is.numeric(decimals) && !is.null(names(decimals))) {
    return(list(global = decimals, per_var = NULL))
  }
  if (is.list(decimals)) {
    return(list(
      global = decimals[[".default"]],
      per_var = decimals[setdiff(names(decimals), ".default")]
    ))
  }
  list(global = NULL, per_var = NULL)
}

.format_stat_vectorised <- function(df, decimals, fmt, pct_threshold, call) {
  # Vectorised by stat_name group (fixes galley B1: per-row vapply).
  out <- character(nrow(df))
  if (nrow(df) == 0L) {
    return(out)
  }

  stat_names <- df$stat_name
  unique_stats <- unique(stat_names)

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
      call = call
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
  call
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
