#' Construct a tabular spec for a figure
#'
#' Figure constructor; separate from [tb_table()] because a ggplot or
#' grob is type-distinct from a `data.frame`. Style defaults (preset)
#' flow from the session preset set via [tb_set_preset()]; per-figure
#' overrides compose in the pipe via [tb_preset()].
#'
#' @param plot A ggplot object or grob.
#' @param titles `character()` of title lines.
#' @param footnotes `character()` of footnote lines.
#' @param width Physical width in inches.
#' @param height Physical height in inches.
#'
#' @return A `tabular_spec` S7 object holding the figure.
#' @family entry_points
#' @export
tb_figure <- function(
  plot,
  titles = NULL,
  footnotes = NULL,
  width = NULL,
  height = NULL
) {
  cli::cli_abort(
    "{.fn tb_figure} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
