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
#' Repeated `cols()` calls **merge** field-by-field on existing
#' col_specs: a non-default value in the new spec overrides the
#' existing field; a default-valued field (NA / NULL) leaves the
#' existing field alone. This lets you build a column's spec in
#' stages.
#'
#' Columns not mentioned in any `cols()` call get default
#' `col_spec(usage = "display")` at engine-validate time.
#'
#' @param spec A `tabular_spec` built by `tabular()`.
#' @param ... Named `col_spec` objects. Each name is the input column
#'   name in `spec@data`. For `usage = "computed"` the name does not
#'   need to exist in `data` — it will be supplied by a later
#'   `derive()` call.
#' @return The updated `tabular_spec`.
#'
#' @examples
#' # Realistic per-column spec on the demographics demo:
#' # row labels on the left, decimal-aligned treatment columns with
#' # BigN joined inline from `saf_n`.
#' n <- setNames(saf_n$n, saf_n$arm_short)
#' tabular(saf_demo) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total      = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   )
#'
#' # Repeated cols() calls merge field-by-field; the second call adds
#' # a width without erasing the label set on the first call.
#' tabular(saf_demo) |>
#'   cols(variable = col_spec(usage = "group", label = "Parameter")) |>
#'   cols(variable = col_spec(width = 2))
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
