# col_spec.R -- user-facing per-column DSL constructor.
#
# Wraps .col_spec_class (the S7 class in aaa_class.R) with cli-friendly
# tabular_error_input messages instead of bare S7 validator strings.
# Sets `name` to NA_character_; cols() assigns the input column name
# from the named argument position.

#' Per-column display specification
#'
#' Build a column specification used inside `cols()`. Each col_spec
#' carries the seven display attributes for one column of the input
#' data frame; `cols()` then attaches it to a `tabular_spec` keyed by
#' the input column name.
#'
#' @param usage One of `"display"`, `"group"`, `"across"`,
#'   `"computed"`, or `NULL` (auto-default in `cols()`).
#'   Accepts:
#'
#'   *   **`"display"`** — pass-through column; rendered as-is.
#'   *   **`"group"`** — row-label column; repeat-suppression and
#'       continuation-page repeat keys to this column.
#'   *   **`"across"`** — column whose unique values become new
#'       output columns via `pivot_across()`.
#'   *   **`"computed"`** — derived column produced by a
#'       `derive_spec`.
#'   *   **`NULL`** (default) — inferred in `cols()` (always
#'       `"display"`).
#' @param label Display label for the column header. Single string;
#'   embed `\n` for line breaks. Embed BigN inline via
#'   `paste()` / `sprintf()` (no dedicated BigN field).
#'   `NA_character_` (default) means use the input column name.
#' @param format Post-cell formatter applied at `engine_format`:
#'
#'   *   **character** — a `sprintf()` template (e.g. `"%.1f"`).
#'   *   **function** — a unary function taking one column of values
#'       and returning a character vector of the same length.
#'   *   **`NULL`** (default) — backend-default formatting.
#' @param visible Logical. `FALSE` hides the column from output;
#'   useful for keeping a column for sort / derive / pagination
#'   without rendering it. Default `TRUE`.
#' @param width Column width in inches. `NA_real_` (default) leaves
#'   widths to backend auto-fit. Must be positive and finite when set.
#' @param align One of `"left"`, `"center"`, `"right"`, `"decimal"`,
#'   or `NULL` (backend default).
#'   `"decimal"` aligns numeric content on the decimal mark via the
#'   active preset's `decimal_metrics`.
#' @param na_text Single string substituted for `NA` cells before the
#'   `format` step. Default `""`.
#' @return A `col_spec` S7 object.
#'
#' @examples
#' # Defaults: pass-through display column
#' col_spec()
#'
#' # Group (row-label) column with an explicit display label
#' col_spec(usage = "group", label = "Parameter")
#'
#' # BigN embedded inline — join from `saf_n` so the denominator
#' # comes from a single source of truth.
#' n <- setNames(saf_n$n, saf_n$arm_short)
#' col_spec(
#'   label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'   align = "decimal"
#' )
#'
#' # Hidden column kept for sorting / pagination only
#' col_spec(visible = FALSE)
#'
#' # sprintf formatter for one-decimal display
#' col_spec(format = "%.1f")
#'
#' @export
col_spec <- function(
  usage = NULL,
  label = NA_character_,
  format = NULL,
  visible = TRUE,
  width = NA_real_,
  align = NULL,
  na_text = ""
) {
  call <- rlang::caller_env()

  usage_val <- .check_col_usage(usage, call = call)
  align_val <- .check_col_align(align, call = call)
  .check_col_label(label, call = call)
  .check_col_visible(visible, call = call)
  .check_col_width(width, call = call)
  .check_col_na_text(na_text, call = call)
  .check_col_format(format, call = call)

  .col_spec_class(
    name = NA_character_,
    label = label,
    usage = usage_val,
    format = format,
    visible = visible,
    width = width,
    align = align_val,
    na_text = na_text
  )
}

# ---------------------------------------------------------------------
# Per-argument validators (internal)
# ---------------------------------------------------------------------

.check_col_usage <- function(x, call) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .col_usage_values
  ) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg usage} must be one of {.val {(.col_usage_values)}} or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_align <- function(x, call) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .align_values
  ) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg align} must be one of {.val {(.align_values)}} or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_label <- function(x, call) {
  if (is.character(x) && length(x) == 1L) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg label} must be a single character string (NA allowed).",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_visible <- function(x, call) {
  if (is.logical(x) && length(x) == 1L && !is.na(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg visible} must be a single non-NA logical.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_width <- function(x, call) {
  if (
    is.numeric(x) &&
      length(x) == 1L &&
      (is.na(x) || (is.finite(x) && x > 0))
  ) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg width} must be a positive finite number or {.code NA}.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_na_text <- function(x, call) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg na_text} must be a single non-NA character string (length 1).",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_format <- function(x, call) {
  if (is.null(x) || is.function(x)) {
    return(invisible(x))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    # Probe the sprintf template with a representative numeric so
    # malformed format strings fail at build time instead of at render.
    probe <- tryCatch(
      sprintf(x, 0),
      error = function(e) e,
      warning = function(w) w
    )
    if (inherits(probe, "condition")) {
      cli::cli_abort(
        c(
          "{.arg format} sprintf template is invalid.",
          "x" = "Test call {.code sprintf({.val {x}}, 0)} failed: {conditionMessage(probe)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg format} must be a sprintf string, a function, or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}
