# posit.R — Tiny set of context-detection helpers that decide
# whether `print(spec)` should preview in an IDE viewer pane,
# inline under a Quarto chunk, or fall back to the markdown /
# cli-tree console form. Modeled on tinytable's `posit.R`
# (Vincent Arel-Bundock, GPL-3) but reduced to the surface
# tabular's print router actually uses.
#
# Detection is environmental, not options-based — RStudio and
# Positron each set a deterministic environment variable when
# they spawn an R session. `getOption("viewer")` is the IDE-
# agnostic capability check; both IDEs (and the htmlwidgets
# shim under base R) install it.

# ---------------------------------------------------------------------
# IDE / environment detection
# ---------------------------------------------------------------------

# TRUE when the current R session was launched by RStudio
# Desktop / Server. RStudio sets `RSTUDIO=1` in the spawned
# environment.
.is_rstudio <- function() {
  identical(Sys.getenv("RSTUDIO"), "1")
}

# TRUE when the current R session was launched by Positron.
# Positron sets `POSITRON=1` analogously.
.is_positron <- function() {
  identical(Sys.getenv("POSITRON"), "1")
}

# TRUE when *any* viewer-pane mechanism is installed for this
# session. RStudio, Positron, and `htmlwidgets`'s standalone
# shim all set `options(viewer = ...)`. This is the capability
# check we care about — the IDE-specific predicates above are
# only useful when we need a different rendering strategy
# (e.g. notebook-inline vs viewer-pane).
.has_viewer <- function() {
  interactive() && !is.null(getOption("viewer"))
}

# TRUE when we are *inside* an active Quarto / Rmd document in
# RStudio (not just an open .qmd / .Rmd file). The check
# inspects the active document context via rstudioapi, so it
# only fires when rstudioapi is installed AND we're in RStudio.
# Positron doesn't expose an equivalent inline preview API; we
# return FALSE there even when an .qmd is the active document.
.is_rstudio_notebook <- function() {
  if (!.is_rstudio()) {
    return(FALSE)
  }
  if (!requireNamespace("rstudioapi", quietly = TRUE)) {
    return(FALSE)
  }
  ctx <- tryCatch(
    rstudioapi::getActiveDocumentContext(),
    error = function(e) NULL
  )
  if (is.null(ctx)) {
    return(FALSE)
  }
  .is_notebook_context(ctx[["path"]] %||% "", ctx[["contents"]] %||% "")
}

# Heuristic: a path ending in .qmd / .Rmd is a notebook; failing
# that, look at the buffer contents for a YAML header with
# `output:` / `format:` or for any chunk fence. Used inside
# `.is_rstudio_notebook()`; exposed as its own helper so the
# logic can be unit-tested without an rstudioapi roundtrip.
.is_notebook_context <- function(path, contents) {
  if (grepl("\\.qmd$|\\.Rmd$", path, ignore.case = TRUE)) {
    return(TRUE)
  }
  if (length(contents) == 0L) {
    return(FALSE)
  }
  text <- paste(contents, collapse = "\n")
  if (!nzchar(text)) {
    return(FALSE)
  }
  has_yaml <- grepl("^---\\s*\n", text)
  has_format <- grepl(
    "(?m)^\\s*(output|format)\\s*:",
    text,
    perl = TRUE
  )
  has_chunk <- grepl("(?m)^```\\{[a-zA-Z]", text, perl = TRUE)
  isTRUE(has_chunk || (has_yaml && has_format))
}

# TRUE when knitr is loaded AND we are inside a live knit pass
# (i.e. `knit_print` is the dispatch surface, not the console).
# We don't depend on knitr at the Imports level, so guard the
# requireNamespace call.
.is_knit_pass <- function() {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(FALSE)
  }
  isTRUE(getOption("knitr.in.progress"))
}

# Local `%||%`. Mirrors rlang::`%||%` semantics: returns `b`
# when `a` is NULL. Keeps this file free of rlang re-entry
# (rlang is in Imports, but the helper is so tiny it's not
# worth a cross-file dep).
`%||%` <- function(a, b) if (is.null(a)) b else a
