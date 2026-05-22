#' Terminal verb: render a tabular spec to a file
#'
#' Finalises the spec (`engine_finalize()`), then dispatches to one of
#' five backends based on `file` extension or explicit `format`. This is
#' the only verb that performs I/O.
#'
#' @param spec A `tabular_spec`.
#' @param file `character(1)` output path. Extension drives backend
#'   dispatch:
#'
#'   *   **`.rtf`** -- native RTF 1.9.1.
#'   *   **`.tex`** -- LaTeX (tabularray).
#'   *   **`.pdf`** -- PDF via LaTeX + tinytex.
#'   *   **`.html`** -- self-contained HTML.
#'   *   **`.docx`** -- native OOXML.
#' @param format `character(1)` override of extension dispatch. Same set
#'   of values; `NULL` (default) infers from `file`.
#'
#' @return Invisibly returns `file`.
#' @family rendering
#' @export
tb_render <- function(spec, file, format = NULL) {
  cli::cli_abort(
    "{.fn tb_render} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
