#' Spanning column headers
#'
#' Add a header row that groups consecutive columns under a shared label.
#' The variadic arguments are named character vectors whose names are the
#' span labels and whose values list the column names to span.
#'
#' @param spec A `tabular_spec`.
#' @param ... Named arguments of the form
#'   `"Active" = c("drug_50", "drug_100")`. Span labels are positional;
#'   columns listed in `...` must already exist in `spec`.
#'
#' @return The updated `tabular_spec`.
#' @family structure
#' @export
tb_spans <- function(spec, ...) {
  cli::cli_abort(
    "{.fn tb_spans} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
