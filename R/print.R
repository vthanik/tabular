#' Print a `tabular_spec`
#'
#' Pretty-prints a `tabular_spec` as a structured cli tree showing
#' data dimensions, titles, footnotes, and any column / header /
#' sort / pivot / derive / style / pagination configuration the spec
#' carries.
#'
#' Phase 1b upgrade: once the HTML backend lands, this method will
#' render the spec to a tempfile via `emit()` and open it in the
#' active viewer (`getOption("viewer")`) when called interactively --
#' mirroring `gt::gt()` and `tinytable::tt()`. Until then, the cli
#' tree view is the print output.
#'
#' @param x A `tabular_spec` object.
#' @param ... Ignored.
#' @return Invisibly returns `x`.
#'
#' @examples
#' # Build a spec and print it — the cli tree shows data dims,
#' # titles, footnotes, and any verb-state attached so far.
#' tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics"),
#'   footnotes = "Safety Population."
#' )
#'
#' @name print.tabular_spec
#' @usage NULL
NULL

# The body is a stand-alone helper so covr can instrument it (S7
# stores the method as a separate function object, and covr does not
# follow the dispatch path).
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

  configured <- c(
    cols = length(x@cols),
    headers = length(x@headers),
    derives = length(x@derives)
  )
  configured <- configured[configured > 0L]
  if (length(configured) > 0L) {
    parts <- paste0(names(configured), " (", configured, ")")
    cli::cli_text("Config: {paste(parts, collapse = ', ')}")
  }

  if (is_sort_spec(x@sort) && length(x@sort@by) > 0L) {
    cli::cli_text("Sort: {paste(x@sort@by, collapse = ', ')}")
  }
  if (is_pagination_spec(x@pagination)) {
    pag <- x@pagination
    bits <- character()
    if (length(pag@keep_together) > 0L) {
      bits <- c(
        bits,
        paste0(
          "keep_together=",
          paste(pag@keep_together, collapse = ",")
        )
      )
    }
    if (!identical(pag@panels, 1L)) {
      bits <- c(bits, paste0("panels=", pag@panels))
    }
    if (length(bits) > 0L) {
      cli::cli_text("Pagination: {paste(bits, collapse = '; ')}")
    } else {
      cli::cli_text("Pagination: auto")
    }
  }

  if (is_preset_spec(x@preset)) {
    bits <- .preset_diff_summary(x@preset)
    if (length(bits) > 0L) {
      cli::cli_text("Preset: {paste(bits, collapse = '; ')}")
    } else {
      cli::cli_text("Preset: defaults")
    }
  }

  invisible(x)
}

# Summarise a preset_spec by listing knobs that differ from the
# preset_spec() factory defaults. Used by .tabular_spec_print so the
# `Preset:` line stays short for the common case (one or two knobs
# overridden) and silent for the all-defaults case.
.preset_diff_summary <- function(p) {
  defaults <- preset_spec()
  fields <- c("font_size", "font_family", "orientation", "paper_size")
  bits <- character()
  for (f in fields) {
    cur <- S7::prop(p, f)
    def <- S7::prop(defaults, f)
    if (!identical(cur, def)) {
      bits <- c(bits, paste0(f, "=", cur))
    }
  }
  bits
}

# nocov start — S7::method<- assignments are not instrumented by
# covr; tests cover .tabular_spec_print() directly.
S7::method(print, tabular_spec) <- function(x, ...) {
  .tabular_spec_print(x, ...)
}
# nocov end
