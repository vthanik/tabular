#' Inline markup dispatcher
#'
#' Wrap a string in a markup sentinel that survives concatenation and is
#' resolved per-backend at render time. One function handles all markup
#' types (superscript, subscript, bold, italic, etc.).
#'
#' @param text `character()` text to wrap.
#' @param type `character(1)` markup type. One of:
#'   `"super"`, `"sub"`, `"bold"`, `"italic"`, `"underline"`,
#'   `"strike"`, `"code"`.
#'
#' @return A character vector with the sentinel wrapper applied.
#' @family markup
#' @export
tb_mark <- function(text, type) {
  cli::cli_abort(
    "{.fn tb_mark} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
