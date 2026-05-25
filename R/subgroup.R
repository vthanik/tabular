# subgroup.R — partition a tabular_spec by one or more variables.
# When set, the engine runs the full resolve pipeline per group and
# concatenates the resulting page sets with a hard page break between
# groups. Each page descriptor of the merged grid carries a pre-
# rendered banner inline_ast so backends can emit the centred
# `<Label>: <Value>` row above the column-header rule.
#
# Phase 1 ships single-variable subgroup() only; multi-variable
# crossing lands in Phase 2.
#
# The column-list argument is `by =`, matching `sort_rows(by = ...)`.

#' Partition the report by a variable
#'
#' Attach a `subgroup_spec` to a `tabular_spec`. At render time the
#' engine partitions `spec@data` by the unique values of `by`,
#' runs the full resolve pipeline per group, and concatenates the
#' results. **A hard page break is inserted between groups** —
#' every subgroup value starts on its own page. A centred banner
#' line appears above the column-header rule on every page of the
#' group (including continuation pages), matching the canonical
#' submission page-layout convention.
#'
#' @details
#'
#' **Label is a glue-style template.** When `label` carries
#' `{col}` placeholders, the engine substitutes each placeholder
#' against the FIRST ROW of the group's filtered data — so any
#' column whose value is constant within group (BigN, cohort
#' descriptor, qualifier text) can ride into the banner. Columns
#' that vary within group also resolve, but always to the first
#' row's value; pre-compute aggregates upstream.
#'
#' **Default label** (when `label = NULL`, single var): the engine
#' generates `"<attr(data[[by]], 'label') %||% by>: {<by>}"`,
#' so `subgroup(by = "cohort")` renders banners like `"Cohort: A"`
#' and `"Cohort: B"` without further configuration.
#'
#' **Replace, not stack.** A second `subgroup()` call REPLACES the
#' prior partition — subgroup is a single spec, not a stackable
#' list. Passing `by = character(0)` clears the slot, though
#' typical clinical pipelines set the partition once up front.
#'
#' **Display-side only.** `subgroup()` partitions a pre-summarised
#' wide data frame; it does not aggregate, filter, or weight. The
#' user supplies one summary row per displayed row per group;
#' tabular's job is solely to lay them out with the per-group
#' banner and page break.
#'
#' **Multi-variable crossing.** `by = c("SEX", "AGEGR1")` partitions
#' on every combination present in the data (first variable varies
#' slowest, matching `expand.grid()` convention). An explicit
#' `label` template is required for multi-var partitions since the
#' single-var default `"<var>: {<var>}"` does not generalise; raise
#' `tabular_error_subgroup_label_required` otherwise.
#'
#' @param spec *The `tabular_spec` to partition.*
#'   `<tabular_spec>: required`.
#'
#' @param by *Column name(s) to partition by.*
#'   `<character>: required`. Must reference a column in
#'   `spec@data`. Length-0 (or `character(0)`) clears the partition.
#'   Matches the `by =` arg convention of [`sort_rows()`].
#'
#'   **Multi-variable.** Pass `c("var1", "var2")` to cross on every
#'   combination present in the data. Multi-var partitions require
#'   an explicit `label` template (the single-var auto-default does
#'   not generalise).
#'
#' @param label *Banner template.*
#'   `<character(1) | NULL>: default NULL`. Glue-style template
#'   with `{column_name}` placeholders. `NULL` derives a default
#'   from the partition variable's `attr(data[[by]], "label")`
#'   (falling back to the column name).
#'
#'   **Tip:** reference auxiliary columns to inline the BigN or
#'   any qualifier that is constant within group — e.g.
#'   `"Cohort: {cohort} (N = {n})"`.
#'
#'   **Restriction:** Every `{col}` reference must be a column in
#'   `spec@data`. Unknown columns raise
#'   `tabular_error_subgroup_template_unknown_col`.
#'
#' @return *The updated `tabular_spec`.* Continue chaining or
#'   resolve via [`as_grid()`] / [`emit()`].
#'
#' @examples
#' # ---- Example 1: TEAEs by treatment arm — one set of pages per arm ----
#' #
#' # Partition the AE-by-SOC/PT pipeline by treatment arm. Each arm
#' # value gets its own page set with a centred `Treatment Arm: <value>`
#' # banner above the column-header rule on every page, separated by
#' # hard page breaks. The default label uses the variable's `label`
#' # attribute when present, falling back to the column name.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total  <- as.integer(sub(" .*", "", ae$Total))
#' attr(ae$row_type, "label") <- "Row Type"
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "SOC / PT"),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100", align = "decimal"),
#'     Total    = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   subgroup(by = "row_type")
#'
#' # ---- Example 2: Cohort with inline BigN via template ----
#' #
#' # `label` is a glue-style template; any column whose value is
#' # constant within group can ride into the banner. Here the BigN
#' # column `cohort_n` is pre-computed upstream so each cohort's
#' # banner reads `"Cohort: A (N = 50)"`, etc.
#' demo <- data.frame(
#'   cohort   = factor(c("A", "A", "B", "B"), levels = c("A", "B")),
#'   cohort_n = c(50L, 50L, 75L, 75L),
#'   param    = c("ALT", "AST", "ALT", "AST"),
#'   value    = c("12.4", "18.1", "11.7", "17.5")
#' )
#' tabular(demo) |>
#'   cols(
#'     cohort   = col_spec(visible = FALSE),
#'     cohort_n = col_spec(visible = FALSE),
#'     param    = col_spec(label = "Parameter"),
#'     value    = col_spec(label = "Result")
#'   ) |>
#'   subgroup(by = "cohort", label = "Cohort: {cohort} (N = {cohort_n})")
#'
#' # ---- Example 3: Multi-variable crossing (Sex x Age group) ----
#' #
#' # Pass two columns to partition on every combination present in
#' # the data. The label template MUST reference each variable
#' # explicitly because the single-var auto-default does not
#' # generalise. expand.grid order: first var (sex) varies slowest,
#' # second (agegr) fastest, giving banner sequence F/<65, F/>=65,
#' # M/<65, M/>=65.
#' vitals <- data.frame(
#'   sex   = factor(rep(c("F", "M"), each = 4), levels = c("F", "M")),
#'   agegr = factor(
#'     rep(c("<65", "<65", ">=65", ">=65"), 2),
#'     levels = c("<65", ">=65")
#'   ),
#'   param = rep(c("Systolic BP", "Diastolic BP"), 4),
#'   value = c("121", "78", "129", "82", "118", "75", "127", "80")
#' )
#' tabular(vitals) |>
#'   cols(
#'     sex   = col_spec(visible = FALSE),
#'     agegr = col_spec(visible = FALSE),
#'     param = col_spec(label = "Parameter"),
#'     value = col_spec(label = "Mean")
#'   ) |>
#'   subgroup(
#'     by    = c("sex", "agegr"),
#'     label = "Sex: {sex} / Age: {agegr}"
#'   )
#'
#' @seealso
#' **Pipeline siblings:** [`sort_rows()`], [`paginate()`],
#' [`derive()`].
#'
#' **Resolve / render:** [`as_grid()`], [`emit()`].
#'
#' @export
subgroup <- function(spec, by, label = NULL) {
  call <- rlang::caller_env()
  check_tabular_spec(spec, call = call)

  if (missing(by) || is.null(by)) {
    by <- character()
  }
  if (!is.character(by)) {
    cli::cli_abort(
      c(
        "{.arg by} must be a character vector of column names.",
        "x" = "You supplied {.obj_type_friendly {by}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (anyNA(by) || (length(by) > 0L && any(!nzchar(by)))) {
    cli::cli_abort(
      c(
        "{.arg by} must not contain NA or empty strings."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  # Empty by clears the slot — kept for the API shape; typical
  # clinical pipelines do not toggle subgroup mid-build.
  if (length(by) == 0L) {
    return(S7::set_props(spec, subgroup = NULL))
  }

  unknown <- setdiff(by, names(spec@data))
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{.arg by} references column{?s} not present in {.field spec@data}: {.val {unknown}}.",
        "i" = "Available columns: {.val {names(spec@data)}}."
      ),
      class = "tabular_error_subgroup_unknown_var",
      call = call
    )
  }

  if (anyDuplicated(by) > 0L) {
    cli::cli_abort(
      c(
        "{.arg by} must not repeat column names.",
        "x" = "Duplicate{?s}: {.val {by[duplicated(by)]}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (!is.null(label)) {
    if (!is.character(label) || length(label) != 1L || is.na(label)) {
      cli::cli_abort(
        c(
          "{.arg label} must be NULL or a length-1 non-NA character.",
          "i" = "Use a glue-style template, e.g. {.val Cohort: {{cohort}} (N = {{n}})}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    # Validate template references up-front so failures land at the
    # verb call site, not deep in the engine.
    refs <- .subgroup_template_refs(label)
    unknown_refs <- setdiff(refs, names(spec@data))
    if (length(unknown_refs) > 0L) {
      cli::cli_abort(
        c(
          "{.arg label} references column{?s} not in {.field spec@data}: {.val {unknown_refs}}.",
          "i" = "Available columns: {.val {names(spec@data)}}."
        ),
        class = "tabular_error_subgroup_template_unknown_col",
        call = call
      )
    }
  } else if (length(by) > 1L) {
    # Multi-var partition without an explicit template — error
    # rather than guess at a default join. Aesthetic decisions
    # (separator, label-per-var, value formatting) belong to the
    # user, not the package.
    cli::cli_abort(
      c(
        "{.arg label} is required for multi-variable {.arg by}.",
        "i" = "Supply a glue-style template referencing each var, e.g. {.val Sex: {{SEX}} / Age: {{AGEGR1}}}."
      ),
      class = "tabular_error_subgroup_label_required",
      call = call
    )
  }

  sg <- subgroup_spec(by = by, label = label)
  S7::set_props(spec, subgroup = sg)
}

# ---------------------------------------------------------------------
# Internal helpers shared with engine_subgroup_split
# ---------------------------------------------------------------------

# Resolve the effective label template. Returns `spec@subgroup@label`
# when the user supplied one; otherwise derives a default of
# `<attr_label or var_name>: {<var>}` for the (single) partition var.
.subgroup_effective_template <- function(spec) {
  user_template <- spec@subgroup@label
  if (!is.null(user_template) && nzchar(user_template)) {
    return(user_template)
  }
  var <- spec@subgroup@by[[1L]]
  col_label <- attr(spec@data[[var]], "label", exact = TRUE)
  lbl <- if (
    is.character(col_label) && length(col_label) == 1L && nzchar(col_label)
  ) {
    col_label
  } else {
    var
  }
  paste0(lbl, ": {", var, "}")
}

# Extract column references from a `{col}` template. Used at verb
# time for up-front validation and at engine time for substitution.
# Skips escaped `{{` / `}}` pairs (reserved for future literal-brace
# support; today they're simply not substituted).
.subgroup_template_refs <- function(template) {
  if (!is.character(template) || length(template) != 1L || is.na(template)) {
    return(character())
  }
  m <- gregexpr("\\{([^{}]+)\\}", template, perl = TRUE)[[1L]]
  if (length(m) == 1L && m[[1L]] == -1L) {
    return(character())
  }
  starts <- as.integer(m)
  lens <- attr(m, "match.length")
  refs <- vapply(
    seq_along(starts),
    function(i) {
      substr(template, starts[[i]] + 1L, starts[[i]] + lens[[i]] - 2L)
    },
    character(1L)
  )
  unique(refs)
}

# Substitute `{col}` tokens in `template` against `row_data` (a
# 1-row data.frame). Mirrors the .substitute_engine_tokens pattern
# at R/page_chrome.R:293 — fixed-string gsub over each token.
.subgroup_render_label <- function(template, row_data) {
  refs <- .subgroup_template_refs(template)
  out <- template
  for (col in refs) {
    val <- row_data[[col]]
    rendered <- if (is.factor(val)) {
      as.character(val)
    } else {
      format(val, trim = TRUE)
    }
    out <- gsub(paste0("{", col, "}"), rendered, out, fixed = TRUE)
  }
  out
}
