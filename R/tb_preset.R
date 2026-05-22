#' Study-wide rendering defaults
#'
#' Set page geometry (orientation, margins, font), n-counts formatting,
#' page header/footer, and horizontal-rule style for the entire session.
#' Called once per program; subsequent `tb_table()` calls pick up the
#' active preset. Code-only -- no YAML / config-file discovery.
#'
#' @param name `character(1)` registered preset name to apply
#'   (e.g. `"gsk_house_style"`), or `NULL` (default) when supplying
#'   values inline via `...`.
#' @param ... Named geometry / styling values. Accepted keys:
#'   `font_size`, `font_family`, `orientation` (`"portrait"`/
#'   `"landscape"`), `margins`, `paper_size`, `hlines`, `n_format`,
#'   `pagehead` (list of left/center/right), `pagefoot` (same).
#' @param reset Logical. `TRUE` clears the active preset to defaults.
#'
#' @return Invisibly returns the preset list that is now active.
#' @family defaults
#' @export
tb_preset <- function(name = NULL, ..., reset = FALSE) {
  cli::cli_abort(
    "{.fn tb_preset} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
