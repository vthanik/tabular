#' Column setup
#'
#' Configure column labels, widths, alignment, visibility, and BigN. All
#' arguments accept flat named character/numeric vectors. The wildcard
#' name `"*"` sets a default for unnamed columns.
#'
#' @param spec A `tabular_spec` from [tb_table()] or another verb.
#' @param labels Named character vector of column-display labels.
#' @param width Named numeric vector of column widths in inches.
#' @param align Named character vector; one of `"left"`, `"center"`,
#'   `"right"`, `"decimal"`. `"*"` sets the default.
#' @param visible Named logical vector. `FALSE` hides a column from the
#'   rendered output (but it remains available for grouping / sorting).
#' @param n Named integer vector of BigN counts (one per arm + `Total`).
#'
#' @return The updated `tabular_spec`.
#' @family structure
#' @export
tb_cols <- function(
  spec,
  labels = NULL,
  width = NULL,
  align = NULL,
  visible = NULL,
  n = NULL
) {
  cli::cli_abort(
    "{.fn tb_cols} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
