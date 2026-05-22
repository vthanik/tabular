#' Row organisation
#'
#' Configure grouping, indentation, pagination boundaries, blank-row
#' spacing, sorting, and row-level visibility. All grouping/indent/page
#' selectors are column-name strings.
#'
#' @param spec A `tabular_spec`.
#' @param group_by `character()` of column names to group rows by; group
#'   labels become header rows.
#' @param page_by `character(1)` column name that introduces a hard page
#'   break (each value starts a new page).
#' @param indent_by `character(1)` column name whose row text gets
#'   leading indent in the display.
#' @param blank_after `character(1)` column whose value-change inserts a
#'   blank row.
#' @param sort_by `character()` of column names to sort rows by (within
#'   their group).
#' @param suppress `character()` of column names that participate in
#'   internal ordering but are dropped from the final display.
#'
#' @return The updated `tabular_spec`.
#' @family structure
#' @export
tb_rows <- function(
  spec,
  group_by = NULL,
  page_by = NULL,
  indent_by = NULL,
  blank_after = NULL,
  sort_by = NULL,
  suppress = NULL
) {
  cli::cli_abort(
    "{.fn tb_rows} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
