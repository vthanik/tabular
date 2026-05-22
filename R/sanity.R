# Input-validation helpers used by every public verb.
#
# Each helper aborts with class = "tabular_error_input" so callers can
# catch construction-time bad input separately from runtime/backend
# failures. `arg` is the user-facing argument name printed in the
# message; `call` is the calling environment for the error's call stack.

#' Check that `x` is a data frame
#'
#' @param x Object to check.
#' @param arg User-facing argument name (printed in the error message).
#' @param call Calling environment, for the error's call stack.
#' @return `x` invisibly when it is a data frame; otherwise aborts with
#'   class `"tabular_error_input"`.
#' @keywords internal
#' @noRd
check_data_frame <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (is.data.frame(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a data frame.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

#' Check that `x` is `NULL` or a single positive finite whole number
#'
#' Used for pagination row-count arguments. `NULL` is the "use the
#' backend default" signal and returns `NA_integer_`. Otherwise `x`
#' must be a single numeric whole-number value strictly greater than
#' zero and finite. Rejects `NA`, `Inf`, `-Inf`, `NaN`, fractional
#' numerics, multi-element vectors, strings, and logicals.
#'
#' @inheritParams check_data_frame
#' @return `NA_integer_` when `x` is `NULL`; otherwise the integer
#'   value of `x` (passes `as.integer()`).
#' @keywords internal
#' @noRd
check_rows_per_page <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (is.null(x)) {
    return(NA_integer_)
  }
  ok <- is.numeric(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x == trunc(x) &&
    x > 0
  if (ok) {
    return(as.integer(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a single positive whole number or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

#' Check that `x` is a `tabular_spec`
#'
#' Gate at the top of every verb that takes a spec as its first argument
#' (`tb_cols`, `tb_rows`, `tb_spans`, `tb_styles`, `tb_preset`,
#' `tb_render`, ...). Fails with a friendly `tabular_error_input` and
#' points the user back to `tb_table()`.
#'
#' @inheritParams check_data_frame
#' @return `x` invisibly on success; otherwise aborts.
#' @keywords internal
#' @noRd
check_tabular_spec <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (is_tabular_spec(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a {.cls tabular_spec}.",
      "x" = "You supplied {.obj_type_friendly {x}}.",
      "i" = "Build one with {.fn tb_table}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

#' Check that `x` is a character vector (any length, no NAs)
#'
#' Empty vectors are allowed; this is the right type for `titles` /
#' `footnotes` which are zero-or-more lines.
#'
#' @inheritParams check_data_frame
#' @return `x` invisibly on success; otherwise aborts.
#' @keywords internal
#' @noRd
check_chr <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (is.character(x) && !anyNA(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a character vector with no NAs.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}
