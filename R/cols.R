# cols.R — variadic per-column DSL verb. Attaches col_spec objects
# to a tabular_spec, keyed by input column name. Repeat-call merge
# is field-by-field: a non-default field overrides the prior value;
# a default-valued field leaves the prior alone.

#' Attach per-column specifications
#'
#' Adds `col_spec` entries to a `tabular_spec`. Each named argument's
#' name must match a column in `spec@data` (or have `usage =
#' "computed"` if it is a derived column added later by `derive()`).
#'
#' Columns not mentioned in any `cols()` call get default
#' `col_spec(usage = "display")` at engine-validate time, so a sparse
#' `cols()` call is fine — only declare the columns whose attributes
#' (label, alignment, BigN denominator, hidden status, derived
#' source) differ from defaults.
#'
#' @section Repeat-call merge semantics:
#'
#' Repeated `cols()` calls **merge** field-by-field on existing
#' col_specs: a non-default value in the new spec overrides the
#' existing field; a default-valued field (NA / NULL / "" / `TRUE`)
#' leaves the existing field unchanged. The merge happens per
#' column; columns not mentioned in the second call are left alone.
#'
#' This lets you build a column's spec in stages — declare the
#' label-and-alignment block up front, then add the width once you
#' know it fits, then attach a sort key, all without re-stating the
#' earlier attributes. The pattern is essential when generating
#' specs programmatically (looping over arms, applying a house-style
#' helper, layering sponsor overrides).
#'
#' Default values that *do not* override:
#'
#' | field | default that does not override |
#' |---|---|
#' | `usage`   | `NA_character_` |
#' | `label`   | `NA_character_` |
#' | `format`  | `NULL` |
#' | `visible` | `TRUE` |
#' | `width`   | `NA_real_` |
#' | `align`   | `NA_character_` |
#' | `na_text` | `""` |
#'
#' ```r
#' # Three-stage build: label/usage first, alignment second, width
#' # third. Each stage leaves earlier fields intact.
#' tabular(saf_demo) |>
#'   cols(variable = col_spec(usage = "group", label = "Parameter")) |>
#'   cols(variable = col_spec(align = "left")) |>
#'   cols(variable = col_spec(width = 2.0))
#' # Result: variable has usage = "group", label = "Parameter",
#' #         align = "left", width = 2.0 -- all four fields set.
#' ```
#'
#' @param spec A `tabular_spec` built by `tabular()`.
#' @param ... Named `col_spec` objects. Each name is the input column
#'   name in `spec@data`. For `usage = "computed"` the name does not
#'   need to exist in `data` — it will be supplied by a later
#'   `derive()` call. Names must be unique within a single `cols()`
#'   call (a duplicate within one call warns; "last value wins"); to
#'   intentionally override an attribute, use a second `cols()` call
#'   downstream and let the merge rule apply.
#' @return The updated `tabular_spec`.
#'
#' @examples
#' # 95% safety pattern: demographics with row-label cols on the
#' # left and decimal-aligned treatment cols carrying BigN inline.
#' # Complete pipeline through every landed verb so the example is
#' # paste-ready into a Quarto vignette.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total      = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # 95% efficacy pattern: BOR table with CDISC factor ordering.
#' # row_type is hidden (sort-helper only) and stat_label uses the
#' # group usage so consecutive runs collapse in render.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "Objective Response Rate (CR + PR)",
#'   "Disease Control Rate (CR + PR + SD)"
#' )
#' eff <- eff_resp
#' eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#'
#' tabular(
#'   eff,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Best Overall Response and Response Rates",
#'     sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
#'   ),
#'   footnotes = "Response per RECIST 1.1, investigator assessment."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Response"),
#'     row_type   = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"]),  align = "decimal"),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"]),  align = "decimal"),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]), align = "decimal")
#'   ) |>
#'   sort_rows(by = "stat_label")
#'
#' @export
cols <- function(spec, ...) {
  call <- rlang::caller_env()
  check_tabular_spec(spec, call = call)

  args <- list(...)
  if (length(args) == 0L) {
    return(spec)
  }

  arg_names <- names(args)
  if (is.null(arg_names) || any(arg_names == "")) {
    cli::cli_abort(
      c(
        "All arguments to {.fn cols} must be named.",
        "i" = "Each name is the input column name in {.arg data}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  for (i in seq_along(args)) {
    if (!is_col_spec(args[[i]])) {
      cli::cli_abort(
        c(
          "Each entry in {.fn cols} must be a {.cls col_spec}.",
          "x" = "{.arg {arg_names[[i]]}} is {.obj_type_friendly {args[[i]]}}.",
          "i" = "Use {.fn col_spec} to build one."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  dup_idx <- duplicated(arg_names)
  if (any(dup_idx)) {
    dups <- unique(arg_names[dup_idx])
    cli::cli_warn(
      c(
        "{length(dups)} duplicate column name{?s} in {.fn cols}, last value wins.",
        "x" = "Repeated: {.val {dups}}."
      ),
      call = call
    )
    keep <- !duplicated(arg_names, fromLast = TRUE)
    args <- args[keep]
    arg_names <- arg_names[keep]
  }

  data_cols <- names(spec@data)
  for (i in seq_along(args)) {
    nm <- arg_names[[i]]
    cs <- args[[i]]
    if (!(nm %in% data_cols) && !.is_computed(cs)) {
      cli::cli_abort(
        c(
          "{.val {nm}} is not a column of {.arg data}.",
          "x" = "Available columns: {.val {data_cols}}.",
          "i" = "For derived columns, set {.code usage = \"computed\"} and add a {.fn derive} entry."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  new_cols <- spec@cols
  for (i in seq_along(args)) {
    nm <- arg_names[[i]]
    incoming <- S7::set_props(args[[i]], name = nm)
    if (nm %in% names(new_cols)) {
      new_cols[[nm]] <- .merge_col_spec(new_cols[[nm]], incoming)
    } else {
      new_cols[[nm]] <- incoming
    }
  }

  S7::set_props(spec, cols = new_cols)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

.is_computed <- function(cs) {
  u <- cs@usage
  is.character(u) && length(u) == 1L && !is.na(u) && u == "computed"
}

# Merge `new` into `existing` field-by-field. A non-default value in
# `new` overrides the corresponding field in `existing`; a default
# (NA / NULL / "") leaves the existing field unchanged. Defaults map
# to the constructor defaults of col_spec(). `name` always takes the
# new value (cols() just stamped it).
.merge_col_spec <- function(existing, new) {
  out <- existing
  out <- S7::set_props(out, name = new@name)
  if (!is.na(new@usage)) {
    out <- S7::set_props(out, usage = new@usage)
  }
  if (!is.na(new@label)) {
    out <- S7::set_props(out, label = new@label)
  }
  if (!is.null(new@format)) {
    out <- S7::set_props(out, format = new@format)
  }
  if (!isTRUE(new@visible)) {
    out <- S7::set_props(out, visible = new@visible)
  }
  if (!is.na(new@width)) {
    out <- S7::set_props(out, width = new@width)
  }
  if (!is.na(new@align)) {
    out <- S7::set_props(out, align = new@align)
  }
  if (!identical(new@na_text, "")) {
    out <- S7::set_props(out, na_text = new@na_text)
  }
  out
}
