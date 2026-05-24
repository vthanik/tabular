#' Print a `tabular_spec`
#'
#' Renders a `tabular_spec` interactively. Default behaviour
#' mirrors `tinytable::tt()` and `gt::gt()`: when an IDE viewer
#' pane is available (RStudio, Positron, `htmlwidgets`'s
#' standalone shim) the spec is rendered to a self-contained
#' HTML tempfile and opened in the pane; at a plain console the
#' markdown source is `cat()`-printed; in non-interactive
#' contexts (Rscript, R CMD check, CI) the structural cli-tree
#' summary is printed instead.
#'
#' @details
#'
#' **Output resolution.** The router considers, in order:
#'
#' 1. An explicit `output =` argument (always wins).
#' 2. An active `knit_print()` pass — handled by the
#'    `knit_print` S3 method, not here.
#' 3. An RStudio notebook context (active .qmd / .Rmd buffer) —
#'    HTML wrapped in `htmltools::browsable()` so it inlines
#'    under the chunk instead of opening the viewer pane.
#' 4. An interactive session with a viewer pane installed
#'    (`interactive() && !is.null(getOption("viewer"))`) — HTML
#'    in the pane.
#' 5. An interactive session with no viewer pane — markdown
#'    source `cat()`-ed to the console.
#' 6. Everything else (non-interactive) — the structural cli-tree
#'    summary.
#'
#' **Format support.** Tabular has five backends; not all of
#' them preview natively in the IDE pane:
#'
#' * `"html"` — viewer pane (native).
#' * `"md"` — markdown source `cat()` to console.
#' * `"latex"` — LaTeX source `cat()` to console (preview when
#'   `backend_latex` lands).
#' * `"rtf"` / `"docx"` — *fall back to an HTML preview* + a
#'   cli note pointing at `emit(spec, "out.rtf")` /
#'   `emit(spec, "out.docx")` for the real artefact. The viewer
#'   pane cannot render RTF / OOXML; we render HTML so the user
#'   still sees the table.
#' * `"pdf"` — *falls back to HTML preview*. We deliberately do
#'   NOT compile through tinytex on every autoprint (would burn
#'   seconds per print); `emit(spec, "out.pdf")` does the real
#'   compile.
#' * `"cli"` — force the structural cli-tree summary (handy when
#'   you want a quick prop / header / derive overview at the
#'   console even with the viewer pane available).
#'
#' **Temp-file location.** Preview HTML files are written under
#' `getOption("tabular_preview_dir", default = tempdir())`.
#' Override the option to keep them in a stable location (handy
#' when Linux browsers don't have read access to `/tmp/`).
#'
#' @param x *The `tabular_spec` to render.*
#'   `<tabular_spec>: required`. The same object you'd hand to
#'   [`emit()`].
#'
#' @param output *Preview format.* `<character(1) | NULL>:
#'   default `NULL` (auto)`. One of:
#'
#'   * `NULL` (default) — auto-resolved per the rules above.
#'   * `"html"` — viewer pane (or `cat()` if no viewer).
#'   * `"md"` / `"markdown"` — markdown source to console.
#'   * `"latex"` — LaTeX source to console.
#'   * `"rtf"` / `"docx"` — HTML preview + cli note.
#'   * `"pdf"` — HTML preview (PDF compile only on `emit()`).
#'   * `"cli"` — structural cli-tree summary.
#'
#'   **Tip:** set `options(tabular_print_output = "md")` to
#'   force markdown source at the console even when a viewer
#'   pane is available (handy when you want the raw text for
#'   copy / diff).
#'
#' @param ... *Reserved.* Ignored.
#'
#' @return *Invisibly returns `x`.* Side effect: opens the
#'   viewer or `cat()`s output.
#'
#' @examples
#' # ---- Example 1: Build + autoprint ----
#' #
#' # Build a spec and print it. Inside RStudio / Positron the
#' # rendered HTML lands in the viewer pane; at a plain console
#' # the markdown source is `cat()`-ed.
#' tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics"),
#'   footnotes = "Safety Population."
#' )
#'
#' # ---- Example 2: Force the cli-tree structural view ----
#' #
#' # The cli-tree summary shows props (cols, headers, derives,
#' # sort, pagination, preset) at a glance. Useful for
#' # debugging spec composition without paying the HTML render
#' # cost.
#' spec <- tabular(
#'   saf_demo,
#'   titles = "Demographics"
#' ) |>
#'   cols(variable = col_spec(usage = "group", label = "Characteristic"))
#'
#' print(spec, output = "cli")
#'
#' @seealso
#' **Terminal verb:** [`emit()`] writes the resolved artefact to
#' disk; `print()` is for in-session preview only.
#'
#' **Pipeline shape:** [`as_grid()`] resolves the engine pipeline
#' to a `tabular_grid` without I/O.
#'
#' @name print.tabular_spec
#' @usage NULL
NULL

# ---------------------------------------------------------------------
# Public dispatcher (S7 -> S3 fallback)
# ---------------------------------------------------------------------

# The body is a stand-alone helper so covr can instrument it (S7
# stores the method as a separate function object, and covr does
# not follow the dispatch path).
.tabular_spec_print <- function(
  x,
  output = getOption("tabular_print_output", default = NULL),
  ...
) {
  resolved <- .resolve_print_output(output, x)
  switch(
    resolved,
    cli = .tabular_spec_print_cli(x),
    html = .tabular_spec_print_html(x),
    md = .tabular_spec_print_source(x, "md"),
    markdown = .tabular_spec_print_source(x, "md"),
    latex = .tabular_spec_print_source(x, "md"), # backend_latex pending
    rtf = .tabular_spec_print_fallback(x, "rtf"),
    docx = .tabular_spec_print_fallback(x, "docx"),
    pdf = .tabular_spec_print_fallback(x, "pdf"),
    .tabular_spec_print_cli(x)
  )
  invisible(x)
}

# Decide the effective output format. Explicit `output =`
# always wins; otherwise the router walks the precedence rules
# from the @details block.
.resolve_print_output <- function(output, x) {
  if (!is.null(output)) {
    if (!is.character(output) || length(output) != 1L || is.na(output)) {
      cli::cli_abort(
        c(
          "{.arg output} must be a length-1 character.",
          "i" = "Pass one of: {.val html}, {.val md}, {.val latex}, {.val rtf}, {.val docx}, {.val pdf}, {.val cli}."
        ),
        class = "tabular_error_input",
        call = rlang::caller_env(2L)
      )
    }
    return(output)
  }
  if (.is_rstudio_notebook()) {
    return("html")
  }
  if (.has_viewer()) {
    return("html")
  }
  if (interactive()) {
    return("md")
  }
  "cli"
}

# ---------------------------------------------------------------------
# Branch handlers
# ---------------------------------------------------------------------

# HTML preview branch. Inside an RStudio notebook context the
# rendered string is wrapped in `htmltools::browsable()` so it
# inlines under the chunk; everywhere else it's written to a
# tempfile and handed to the viewer / fallback URL opener.
.tabular_spec_print_html <- function(x) {
  dir <- getOption("tabular_preview_dir", default = tempdir())
  file <- tempfile(tmpdir = dir, fileext = ".html")
  emit(x, file, format = "html")

  if (
    .is_rstudio_notebook() && requireNamespace("htmltools", quietly = TRUE)
  ) {
    payload <- paste(readLines(file, warn = FALSE), collapse = "\n")
    return(htmltools::browsable(htmltools::HTML(payload)))
  }

  viewer <- getOption("viewer", utils::browseURL)
  viewer(file)
  invisible(file)
}

# Markdown / LaTeX source branch. We render through the
# matching backend, read the file back, and `cat()` it so the
# user sees the raw source at the console. Tempfile is written
# under the same dir as the HTML preview for symmetry.
.tabular_spec_print_source <- function(x, fmt) {
  dir <- getOption("tabular_preview_dir", default = tempdir())
  file <- tempfile(tmpdir = dir, fileext = paste0(".", fmt))
  emit(x, file, format = fmt)
  cat(readLines(file, warn = FALSE), sep = "\n")
  cat("\n")
  invisible(file)
}

# RTF / DOCX / PDF preview fallback. The viewer pane can't
# render these formats natively, so we render HTML instead and
# `cat()` a one-line cli note pointing at `emit()` for the real
# artefact. Keeps the user in the IDE without a wrong-format
# error.
.tabular_spec_print_fallback <- function(x, fmt) {
  msg <- switch(
    fmt,
    rtf = c(
      "i" = "Preview rendered as HTML; {.fn emit} the spec to a {.path .rtf} for the regulatory-grade output."
    ),
    docx = c(
      "i" = "Preview rendered as HTML; {.fn emit} the spec to a {.path .docx} for the OOXML artefact."
    ),
    pdf = c(
      "i" = "Preview rendered as HTML; {.fn emit} the spec to a {.path .pdf} to compile through tinytex."
    )
  )
  cli::cli_inform(msg)
  .tabular_spec_print_html(x)
}

# ---------------------------------------------------------------------
# Quarto / Rmd autoprint (knit_print)
# ---------------------------------------------------------------------

#' @rawNamespace S3method(knitr::knit_print, tabular_spec)
knit_print.tabular_spec <- function(x, ...) {
  pandoc_to <- tryCatch(knitr::pandoc_to(), error = function(e) NULL)
  fmt <- if (isTRUE(pandoc_to %in% c("latex", "beamer"))) {
    "latex"
  } else if (isTRUE(pandoc_to %in% c("html", "revealjs"))) {
    "html"
  } else {
    "md"
  }

  dir <- getOption("tabular_preview_dir", default = tempdir())
  file <- tempfile(tmpdir = dir, fileext = paste0(".", fmt))
  emit(x, file, format = fmt)
  payload <- paste(readLines(file, warn = FALSE), collapse = "\n")

  out <- switch(
    fmt,
    html = sprintf("\n```{=html}\n%s\n```\n", payload),
    latex = sprintf("\n```{=latex}\n%s\n```\n", payload),
    payload
  )
  class(out) <- "knit_asis"
  out
}

# ---------------------------------------------------------------------
# cli-tree structural summary (kept as the non-interactive
# default + the explicit `output = "cli"` branch)
# ---------------------------------------------------------------------

# Structural cli-tree summary. Shows data dims, titles,
# footnotes, and any prop set on the spec so far. Useful for
# debugging spec composition without rendering — and the
# default in non-interactive contexts (Rscript, R CMD check, CI)
# where neither a viewer pane nor a console preview makes sense.
.tabular_spec_print_cli <- function(x) {
  cli::cli_h3("{.cls tabular_spec}")

  nr <- nrow(x@data)
  nc <- ncol(x@data)
  cli::cli_text("Data: {nr} row{?s} x {nc} column{?s}")

  n_titles <- length(x@titles)
  if (n_titles > 0L) {
    cli::cli_text("Titles ({n_titles}):")
    for (i in seq_len(n_titles)) {
      t <- .strip_inline_marker(x@titles[[i]])
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
# preset_spec() factory defaults. Keeps the `Preset:` line short
# for the common case (one or two knobs overridden) and silent
# for the all-defaults case.
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
