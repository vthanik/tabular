#' Print a `tabular_spec`
#'
#' Renders a `tabular_spec` interactively. The default behaviour
#' mirrors `gt::gt()`: convert the spec to an `htmltools` tag
#' list and let htmltools dispatch — RStudio + Positron viewer
#' panes, Quarto / Rmd notebook inline, Databricks `displayHTML`,
#' and plain-console `cat()` are all handled without any IDE-
#' specific branching.
#'
#' @details
#'
#' **Dispatch.** `print()` delegates to [`as.tags.tabular_spec()`]
#' which returns an `htmltools::tagList`. That tag list is handed
#' to `htmltools`'s own print method with `browse = view`:
#' htmltools opens the IDE viewer when one is registered,
#' inlines under a Quarto / Rmd chunk when running inside one,
#' or `cat()`s the HTML when neither applies. No `is_rstudio()`
#' / `is_positron()` / `is_notebook()` heuristics — htmltools
#' already knows.
#'
#' **`view` argument.** Defaults to `interactive()`, the same
#' universal off-switch `gt::gt()` uses. Non-interactive
#' contexts (`Rscript`, `R CMD check`, CI, devtools::test)
#' bypass the viewer automatically. Pass `view = FALSE`
#' explicitly at an interactive prompt to suppress the viewer
#' for a single call.
#'
#' **`output` argument.** Forces a specific preview format
#' instead of the default HTML-via-htmltools path. One of:
#'
#' * `"html"` — same as the default, but explicit.
#' * `"md"` / `"markdown"` — `cat()` the markdown source to the
#'   console (round-trips through `backend_md`).
#' * `"latex"` — `cat()` the markdown source as a temporary
#'   placeholder (real LaTeX preview lands with `backend_latex`).
#' * `"rtf"` / `"docx"` / `"pdf"` — render an HTML preview and
#'   emit a cli note pointing at [`emit()`] for the real
#'   artefact. The viewer pane cannot render RTF / OOXML, and
#'   we deliberately do *not* compile through tinytex on every
#'   autoprint.
#' * `"cli"` — print the structural cli-tree summary (props,
#'   headers, derives, sort, pagination, preset). Useful for
#'   debugging spec composition without paying the HTML render
#'   cost.
#'
#' **Robustness.** The HTML render is wrapped in `tryCatch`; if
#' rendering fails for any reason the printer falls back to the
#' cli-tree summary and a `cli::cli_warn()` describing the
#' failure, so a broken spec never crashes the REPL.
#'
#' **Tempdir.** Preview HTML files live under
#' `getOption("tabular_preview_dir", default = tempdir())`.
#' Override the option to keep them in a stable location (handy
#' on Linux distros where browsers don't have read access to
#' `/tmp/`).
#'
#' @param x *The `tabular_spec` to render.*
#'   `<tabular_spec>: required`. The same object you'd hand to
#'   [`emit()`].
#'
#' @param ... *Forwarded to `htmltools::print` / `as.tags()`.*
#'   Use this to pass `id`, `style`, `class` overrides to the
#'   wrapping `<div>`.
#'
#' @param view *Open the viewer?* `<logical(1)>: default
#'   `interactive()``. Same role as `gt::gt`'s `view` argument:
#'   passes through to htmltools as `browse = view`. Set
#'   `view = FALSE` to suppress the viewer for one call (e.g.
#'   to capture the HTML string without launching a window).
#'
#' @param output *Force a specific preview format.* `<character(1)
#'   | NULL>: default `NULL` (auto)`. See the **`output`
#'   argument** section above for the full list. The session
#'   default can be set via `options(tabular_print_output =
#'   "cli")` for users who prefer the structural summary over
#'   the HTML preview.
#'
#' @return *Invisibly returns `x`.* Side effect: opens the
#'   viewer, inlines under a chunk, or `cat()`s output.
#'
#' @examples
#' # ---- Example 1: Build + autoprint (HTML preview) ----
#' #
#' # Build a spec and let autoprint render it. Inside RStudio /
#' # Positron the HTML lands in the viewer pane; inside a
#' # Quarto / Rmd chunk it inlines under the chunk; at a plain
#' # console the HTML source is `cat()`-ed.
#' tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics"),
#'   footnotes = "Safety Population."
#' )
#'
#' # ---- Example 2: Force the cli-tree structural view ----
#' #
#' # The cli-tree summary shows props at a glance. Useful for
#' # debugging spec composition without paying the HTML render
#' # cost.
#' spec <- tabular(saf_demo, titles = "Demographics") |>
#'   cols(variable = col_spec(usage = "group", label = "Characteristic"))
#'
#' print(spec, output = "cli")
#'
#' @seealso
#' **Tag conversion:** `as.tags.tabular_spec()` — the
#' htmltools tag list that `print()` delegates to. Call it
#' directly to embed the table in a custom `htmltools::tagList`
#' or Shiny UI.
#'
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
  ...,
  view = interactive(),
  output = getOption("tabular_print_output", default = NULL)
) {
  # Databricks notebook: bypass htmltools and call the runtime's
  # `displayHTML` directly. The runtime registers no `viewer`
  # option, so htmltools would otherwise just `cat()` raw HTML.
  if (.is_databricks()) {
    html <- tryCatch(
      as.character(htmltools::as.tags(x)),
      error = function(e) NULL
    )
    if (!is.null(html)) {
      return(rlang::exec("displayHTML", html))
    }
  }

  # Explicit `output =` override walks a separate router (cli /
  # md source / latex source / rtf-docx-pdf HTML fallback).
  if (!is.null(output)) {
    .check_output_format(output)
    .print_with_output(x, output, view = view)
    return(invisible(x))
  }

  # Default: HTML via htmltools. The render is wrapped in
  # tryCatch so a broken spec never crashes the REPL — we fall
  # back to the cli-tree summary with a warning.
  tryCatch(
    {
      print(htmltools::as.tags(x, ...), browse = view, ...)
    },
    error = function(e) {
      cli::cli_warn(
        c(
          "!" = "HTML preview failed; showing the structural summary instead.",
          "i" = conditionMessage(e)
        )
      )
      .tabular_spec_print_cli(x)
    }
  )
  invisible(x)
}

# Validate an explicit `output =` argument. cli_abort with the
# input class so callers can catch it as `tabular_error_input`.
.check_output_format <- function(output) {
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
}

# Dispatch the explicit-format branch.
.print_with_output <- function(x, output, view) {
  switch(
    output,
    cli = .tabular_spec_print_cli(x),
    html = .print_html(x, view = view),
    md = .print_source(x, "md"),
    markdown = .print_source(x, "md"),
    latex = .print_source(x, "md"), # backend_latex pending
    rtf = .print_fallback(x, "rtf", view = view),
    docx = .print_fallback(x, "docx", view = view),
    pdf = .print_fallback(x, "pdf", view = view),
    .tabular_spec_print_cli(x)
  )
}

# Explicit HTML branch — same as the default path but reachable
# via `output = "html"`. Kept separate so the cli / source /
# fallback branches all read the same.
.print_html <- function(x, view = TRUE) {
  print(htmltools::as.tags(x), browse = view)
  invisible(x)
}

# Markdown / LaTeX source branch — render through the matching
# backend and cat() the source to the console. Tempfile lives
# under `tabular_preview_dir` for symmetry with the HTML path.
.print_source <- function(x, fmt) {
  dir <- getOption("tabular_preview_dir", default = tempdir())
  file <- tempfile(tmpdir = dir, fileext = paste0(".", fmt))
  emit(x, file, format = fmt)
  cat(readLines(file, warn = FALSE), sep = "\n")
  cat("\n")
  invisible(file)
}

# RTF / DOCX / PDF fallback — render HTML preview + cli note.
# The viewer pane can't render these formats; we render HTML so
# the user still sees the table, and cli_inform points them at
# emit() for the real artefact.
.print_fallback <- function(x, fmt, view = TRUE) {
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
  .print_html(x, view = view)
}

# ---------------------------------------------------------------------
# as.tags S3 method — the SINGLE delegation point
# ---------------------------------------------------------------------

#' Convert a `tabular_spec` to an `htmltools` `tagList`
#'
#' Renders the spec to a self-contained HTML fragment and wraps
#' it in an `htmltools::tagList` suitable for inline embedding in
#' Quarto / Rmd chunks, RStudio / Positron viewer panes,
#' pkgdown reference pages, and Shiny UIs.
#'
#' @details
#'
#' **Fragment extraction.** Tabular's HTML backend emits a full
#' `<!DOCTYPE html>` document with a `<style>` block in the head
#' and the table inside `<body>`. For inline embedding we
#' extract the `<style>` and `<body>` content separately and re-
#' wrap them in an `htmltools::tagList`:
#'
#' ```
#' <style>...table CSS...</style>
#' <div id="..." style="overflow-x:auto;max-width:100%;">
#'   ...table content...
#' </div>
#' ```
#'
#' The wrapping `<div>` gets a random unique `id` (so multiple
#' tables on the same page have CSS-scopable hooks) and
#' `overflow-x: auto` so wide tables get a horizontal scrollbar
#' instead of overflowing their container.
#'
#' @param x *The `tabular_spec` to convert.*
#'   `<tabular_spec>: required`.
#'
#' @param ... *Reserved.* Ignored.
#'
#' @param id *Wrapping div id.* `<character(1) | NULL>: default
#'   NULL (auto-generate)`. Pass an explicit id when you need to
#'   target the table from external CSS or JavaScript.
#'
#' @return *An `htmltools::tagList`* containing a `<style>`
#'   block plus a wrapping `<div>` containing the table. Knitr,
#'   htmltools, and RStudio / Positron viewer panes all know how
#'   to render it.
#'
#' @examples
#' # ---- Example 1: Embed in a custom htmltools page ----
#' #
#' # Compose two tabular tables side-by-side in a parent div.
#' # `as.tags(spec)` is the entry point used by `print()` and
#' # `knit_print()` under the hood.
#' s1 <- tabular(saf_demo, titles = "Demographics")
#' s2 <- tabular(saf_aeoverall, titles = "AE overall")
#'
#' if (requireNamespace("htmltools", quietly = TRUE)) {
#'   htmltools::tagList(
#'     htmltools::as.tags(s1),
#'     htmltools::as.tags(s2)
#'   )
#' }
#'
#' @seealso
#' **Renders via:** [`print.tabular_spec`], `knit_print()`.
#'
#' **Terminal verb:** [`emit()`].
#'
#' @exportS3Method htmltools::as.tags
as.tags.tabular_spec <- function(x, ..., id = NULL) {
  dir <- getOption("tabular_preview_dir", default = tempdir())
  file <- tempfile(tmpdir = dir, fileext = ".html")
  emit(x, file, format = "html")

  payload <- paste(readLines(file, warn = FALSE), collapse = "\n")
  frag <- .extract_html_fragment(payload)
  if (is.null(id)) {
    id <- .random_id("tabular_")
  }

  htmltools::tagList(
    if (nzchar(frag$style)) htmltools::HTML(frag$style) else NULL,
    htmltools::tags$div(
      id = id,
      style = htmltools::css(
        `overflow-x` = "auto",
        `max-width` = "100%"
      ),
      htmltools::HTML(frag$body)
    )
  )
}

# Extract the `<style>` block and the `<body>` inner contents
# from a full HTML document string. Returns `list(style, body)`;
# either element may be the empty string when not present.
.extract_html_fragment <- function(html_str) {
  style <- ""
  body <- ""

  style_match <- regmatches(
    html_str,
    regexpr("<style[^>]*>(?s).*?</style>", html_str, perl = TRUE)
  )
  if (length(style_match) > 0L) {
    style <- style_match
  }

  body_match <- regmatches(
    html_str,
    regexpr("<body[^>]*>(?s).*?</body>", html_str, perl = TRUE)
  )
  if (length(body_match) > 0L) {
    body <- sub("<body[^>]*>\\s*", "", body_match, perl = TRUE)
    body <- sub("\\s*</body>\\s*$", "", body, perl = TRUE)
  } else {
    body <- html_str
  }

  list(style = style, body = body)
}

# Generate a short random identifier with the given prefix.
# Used by `as.tags.tabular_spec()` for the wrapping div so
# multiple tables on the same page have distinct CSS hooks.
.random_id <- function(prefix = "id_") {
  paste0(
    prefix,
    paste(
      sample(c(letters, LETTERS, 0:9), 10L, replace = TRUE),
      collapse = ""
    )
  )
}

# ---------------------------------------------------------------------
# knit_print — defers to as.tags for HTML; raw blocks for other targets
# ---------------------------------------------------------------------

#' @rawNamespace S3method(knitr::knit_print, tabular_spec)
knit_print.tabular_spec <- function(x, ..., inline = FALSE) {
  pandoc_to <- tryCatch(knitr::pandoc_to(), error = function(e) NULL)

  if (isTRUE(pandoc_to %in% c("latex", "beamer"))) {
    # backend_latex pending — render markdown source as a
    # transitional pandoc fallback. Quarto / Rmd will compile it
    # back into LaTeX before TeX-engine ingestion.
    return(.knit_print_md(x))
  }
  if (isTRUE(pandoc_to == "docx")) {
    return(.knit_print_md(x))
  }
  if (isTRUE(pandoc_to == "rtf")) {
    return(.knit_print_md(x))
  }

  # Default (html / revealjs / typst / unknown / interactive
  # autoprint) routes through as.tags so knitr's tag handler
  # renders inline.
  knitr::knit_print(htmltools::as.tags(x, ...), ..., inline = inline)
}

# Knit-print fallback for non-HTML targets pending their real
# backends — emits the markdown source through a `knit_asis`
# wrapper so pandoc swallows it directly.
.knit_print_md <- function(x) {
  file <- tempfile(fileext = ".md")
  emit(x, file, format = "md")
  payload <- paste(readLines(file, warn = FALSE), collapse = "\n")
  class(payload) <- "knit_asis"
  payload
}

# ---------------------------------------------------------------------
# Structural cli-tree summary (the `output = "cli"` branch + the
# fallback when an HTML render fails).
# ---------------------------------------------------------------------

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
