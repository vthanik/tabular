#' Print a `tabular_spec`
#'
#' Pretty-prints a `tabular_spec` as a structured cli tree showing
#' data dimensions, titles, footnotes, pagination, and any column /
#' row / span / style configuration the spec carries. Useful during
#' pipeline construction to inspect the spec before rendering.
#'
#' Phase 1b upgrade: once the HTML backend lands, this method will
#' render the spec to a tempfile via [tb_render()] and open it in
#' the active viewer (`getOption("viewer")`) when called
#' interactively — mirroring the `gt::gt()` and `tinytable::tt()`
#' UX. Quarto / Rmd / pkgdown inline rendering arrives at the same
#' time via a `knit_print.tabular_spec` method. Until then, the cli
#' tree view is the print output.
#'
#' @param x A `tabular_spec` object.
#' @param ... Ignored.
#' @return Invisibly returns `x`.
#'
#' @examples
#' tb_table(saf_demo, titles = c("Table 14.1.1", "Demographics"))
#'
#' @name print.tabular_spec
#' @usage NULL
NULL

# Body kept as an internal helper so covr can track line coverage --
# S7 stores the method as a separate function object, and covr does
# not instrument the dispatch path. Tests call this directly.
.tabular_spec_print <- function(x, ...) {
  cli::cli_h3("{.cls tabular_spec}")

  nr <- nrow(x@data)
  nc <- ncol(x@data)
  cli::cli_text("Data: {nr} row{?s} x {nc} column{?s}")

  n_titles <- length(x@titles)
  if (n_titles > 0L) {
    cli::cli_text("Titles ({n_titles}):")
    for (i in seq_len(n_titles)) {
      t <- x@titles[[i]]
      if (nchar(t) > 60L) {
        t <- paste0(substr(t, 1L, 57L), "...")
      }
      cli::cli_text("  {i}. {.val {t}}")
    }
  }

  n_footnotes <- length(x@footnotes)
  if (n_footnotes > 0L) {
    cli::cli_text("Footnotes: {n_footnotes} line{?s}")
  }

  if (!is.na(x@rows_per_page)) {
    cli::cli_text("Pagination: every {x@rows_per_page} row{?s}")
  }

  configured <- c(
    columns = length(x@columns),
    rows = length(x@rows),
    spans = length(x@spans),
    styles = length(x@styles),
    markup = length(x@markup)
  )
  configured <- configured[configured > 0L]
  if (length(configured) > 0L) {
    parts <- paste0(names(configured), " (", configured, ")")
    cli::cli_text("Config: {paste(parts, collapse = ', ')}")
  }

  invisible(x)
}

# nocov start -- S7::method<- assignments are not instrumented by covr;
# tests cover .tabular_spec_print() directly.
S7::method(print, tabular_spec) <- function(x, ...) .tabular_spec_print(x, ...)
# nocov end
