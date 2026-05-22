# sanity.R -- input-validation helpers used by every public verb.
#
# Each helper aborts with class = "tabular_error_input" so callers can
# catch construction-time bad input separately from runtime/backend
# failures. `arg` is the user-facing argument name printed in the
# message; `call` is the calling environment for the error's call
# stack.
#
# Helpers are NOT exported (they are package-internal); users hit
# them indirectly via verbs.

#' Check that `x` is a `tabular_spec`
#'
#' Gate at the top of every verb that takes a spec as its first
#' argument (`cols`, `headers`, `sort_rows`, `pivot_across`,
#' `derive`, `style`, `paginate`, `preset`, `emit`, `as_grid`).
#' Aborts with friendly cli error and points back to `tabular()`.
#'
#' @param x Object to check.
#' @param arg User-facing argument name (printed in the error message).
#' @param call Calling environment, for the error's call stack.
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
      "i" = "Build one with {.fn tabular}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

#' Check that `x` is a data frame
#'
#' @inheritParams check_tabular_spec
#' @return `x` invisibly on success; otherwise aborts.
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

#' Check that `x` is a character vector with no NAs
#'
#' Empty vectors are allowed; this is the right type for `titles` /
#' `footnotes` / column-name lists.
#'
#' @inheritParams check_tabular_spec
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

#' Check that `x` is a logical vector with no NAs
#'
#' @inheritParams check_tabular_spec
#' @return `x` invisibly on success; otherwise aborts.
#' @keywords internal
#' @noRd
check_lgl <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (is.logical(x) && !anyNA(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a logical vector with no NAs.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

#' Check that `x` is `NULL` or a single positive finite whole number
#'
#' Used for pagination row-count arguments. `NULL` is the "use the
#' backend default" signal and returns `NA_integer_`.
#'
#' @inheritParams check_tabular_spec
#' @return `NA_integer_` when `x` is `NULL`; otherwise `as.integer(x)`.
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

#' Check that `x` is one of a fixed set of strings
#'
#' Single-element character; value must be in `choices`.
#'
#' @inheritParams check_tabular_spec
#' @param choices Allowed values.
#' @return `x` invisibly on success; otherwise aborts.
#' @keywords internal
#' @noRd
check_enum <- function(
  x,
  choices,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% choices
  ) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be one of {.val {choices}}.",
      "x" = "You supplied {.val {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}
