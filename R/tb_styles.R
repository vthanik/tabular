#' Conditional cell styling
#'
#' Apply visual styling to selected cells. Selection is tri-mode: a
#' string expression (`where`), tidy-eval predicates (`i`, `j`), or a
#' named list. All three compile to the same internal selector.
#'
#' @param spec A `tabular_spec`.
#' @param where `character(1)` expression evaluated in `data`'s scope,
#'   e.g. `"row_type == 'total'"`. SAS-migrant friendly.
#' @param i Row predicate (tidy-eval, e.g. `row_type == "total"`).
#' @param j Column predicate (tidy-eval).
#' @param ... Reserved for future selector modes.
#' @param bold,italic Logical. Apply bold / italic to selected cells.
#' @param color,bg Character (hex or named colour). Foreground / background.
#'
#' @return The updated `tabular_spec`.
#' @family styling
#' @export
tb_styles <- function(
  spec,
  where = NULL,
  i = NULL,
  j = NULL,
  ...,
  bold = NULL,
  italic = NULL,
  color = NULL,
  bg = NULL
) {
  cli::cli_abort(
    "{.fn tb_styles} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
