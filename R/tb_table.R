#' Construct a tabular spec from pre-summarised wide data
#'
#' Lean constructor for the 95% case. Takes a pre-summarised wide
#' `data.frame` (one row per display row, columns per treatment arm) plus
#' title and footnote strings. The result is a `tabular_spec` that further
#' verbs (`tb_cols()`, `tb_rows()`, ...) update functionally.
#'
#' @param data Pre-summarised wide `data.frame`. One row per displayed
#'   row; columns are stat-label, treatment arms, and optional `Total`.
#' @param titles `character()` of title lines (e.g. table number, body,
#'   population). Rendered top-of-table.
#' @param footnotes `character()` of footnote lines, rendered below table.
#' @param preset Name of a `tb_preset()` to apply, or `NULL` (default) to
#'   use the current session preset.
#' @param paginate_at Integer row count at which to break to a new page,
#'   or `NULL` (default) to let the backend handle it.
#' @param continuation `character(1)` continuation text for paginated
#'   tables (e.g. `"(continued)"`). Default `"(continued)"`.
#'
#' @return A `tabular_spec` S7 object.
#' @family entry-points
#' @export
tb_table <- function(
  data,
  titles = NULL,
  footnotes = NULL,
  preset = NULL,
  paginate_at = NULL,
  continuation = "(continued)"
) {
  cli::cli_abort(
    "{.fn tb_table} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
