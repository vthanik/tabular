# fonts.R — cross-platform font handling for tabular's backends.
#
# Three input shapes for `preset@font_family` (and any other slot
# that takes a font specification):
#
#   1. Generic family   — `"serif"` / `"sans"` / `"mono"` (or the
#      CSS aliases `"sans-serif"` / `"monospace"`). The resolver
#      returns the canonical fallback chain for that category,
#      tailored to each backend.
#
#   2. Single named font — `"Courier New"`, `"Inter"`, etc. The
#      resolver returns just that name. The consuming app
#      (browser, LaTeX engine, Word) picks its own default if the
#      named font is missing on the consumer's machine.
#
#   3. Explicit stack    — `c("Courier New", "mono")` etc. The
#      user owns the chain (gt-style). The resolver returns the
#      stack verbatim, suitable for the backend's font-stack
#      syntax (CSS list, fontspec cascade, RTF font table, ...).
#
# No heuristic "is this a known mono font?" lookup — too fragile
# (Cascadia? Iosevka? PT Mono?). Either the user names the
# category (`"mono"`) or hands us the chain.

# ---------------------------------------------------------------------
# Generic-family identification
# ---------------------------------------------------------------------

# The five generic family keywords we recognise. CSS aliases
# `sans-serif` / `monospace` normalise to `sans` / `mono`. Anything
# else is treated as a specific font name.
.tabular_generic_families <- c(
  "serif",
  "sans",
  "sans-serif",
  "mono",
  "monospace"
)

# Normalise CSS aliases to the canonical short form used by the
# per-backend stack tables.
.normalize_generic <- function(name) {
  switch(
    name,
    `sans-serif` = "sans",
    monospace = "mono",
    name
  )
}

.is_generic_family <- function(name) {
  length(name) == 1L && name %in% .tabular_generic_families
}

# ---------------------------------------------------------------------
# Per-backend canonical stacks for the three generic families
# ---------------------------------------------------------------------

# HTML — CSS `font-family` stack. First entry is the modern Adobe
# Source Pro family (Phase 2 install helper makes it ubiquitous);
# next are the per-platform native faces (macOS / Windows / Linux);
# the chain always ends in the bare CSS generic so the browser
# falls through to its own default of the right category.
.html_stack_serif <- c(
  "Source Serif Pro",
  "Liberation Serif",
  "Georgia",
  "Times New Roman",
  "Times",
  "serif"
)
.html_stack_sans <- c(
  "Source Sans Pro",
  "Inter",
  "Liberation Sans",
  "system-ui",
  "-apple-system",
  "Segoe UI",
  "Roboto",
  "Helvetica Neue",
  "Helvetica",
  "Arial",
  "sans-serif"
)
.html_stack_mono <- c(
  "Source Code Pro",
  "JetBrains Mono",
  "Liberation Mono",
  "ui-monospace",
  "Consolas",
  "Menlo",
  "Monaco",
  "Courier New",
  "monospace"
)

# LaTeX — used for diagnostic reporting via check_fonts(). The
# actual preamble emission is done by backend_latex's
# .latex_pdftex_font_pkg() (one TeX bundle per generic). Listing
# the chain here lets check_fonts() walk the same priority order
# the LaTeX engine will try.
.latex_stack_serif <- c(
  "Source Serif Pro",
  "TeX Gyre Termes",
  "Latin Modern Roman"
)
.latex_stack_sans <- c(
  "Source Sans Pro",
  "TeX Gyre Heros",
  "Latin Modern Sans"
)
.latex_stack_mono <- c(
  "Source Code Pro",
  "TeX Gyre Cursor",
  "Latin Modern Mono"
)

# RTF — fonts are name-referenced in the `{\fonttbl}` group; Word
# and LibreOffice walk the list at open time and substitute the
# first installed face. The chain leads with the modern Adobe
# Source Pro family (Phase 2 install helper), then per-platform
# native faces (Liberation set ships on Linux, TNR / Helvetica /
# Courier ship with Word everywhere). No bare generic at the end
# (RTF has no equivalent of CSS `serif`); the consuming app picks
# its own default if the entire chain misses.
.rtf_stack_serif <- c(
  "Source Serif Pro",
  "Liberation Serif",
  "Times New Roman",
  "Times"
)
.rtf_stack_sans <- c(
  "Source Sans Pro",
  "Liberation Sans",
  "Helvetica",
  "Arial"
)
.rtf_stack_mono <- c(
  "Source Code Pro",
  "Liberation Mono",
  "Courier New",
  "Courier"
)

# ---------------------------------------------------------------------
# Public resolver
# ---------------------------------------------------------------------

# Resolve a `font_family` input to the per-backend fallback chain.
# Returns a character vector of font names in priority order.
.resolve_font_stack <- function(font_family, backend) {
  if (length(font_family) == 0L) {
    font_family <- "serif"
  }
  # Explicit stack: emit verbatim, no fabrication.
  if (length(font_family) > 1L) {
    return(as.character(font_family))
  }
  # Single value: generic OR named font.
  if (.is_generic_family(font_family)) {
    fam <- .normalize_generic(font_family)
    return(switch(
      backend,
      html = switch(
        fam,
        serif = .html_stack_serif,
        sans = .html_stack_sans,
        mono = .html_stack_mono
      ),
      latex = switch(
        fam,
        serif = .latex_stack_serif,
        sans = .latex_stack_sans,
        mono = .latex_stack_mono
      ),
      rtf = switch(
        fam,
        serif = .rtf_stack_serif,
        sans = .rtf_stack_sans,
        mono = .rtf_stack_mono
      ),
      # Unknown backend: best-effort, return the HTML chain.
      switch(
        fam,
        serif = .html_stack_serif,
        sans = .html_stack_sans,
        mono = .html_stack_mono
      )
    ))
  }
  # Named font, no fallback fabricated.
  as.character(font_family)
}

# ---------------------------------------------------------------------
# CSS name quoting helper used by backend_html
# ---------------------------------------------------------------------

# Quote a CSS font-family name when it contains whitespace OR is a
# multi-word display name. CSS generics (`serif`, `sans-serif`,
# `monospace`, `system-ui`, `ui-monospace`, `-apple-system`) and
# single-word names render unquoted.
.html_quote_font <- function(name) {
  if (
    name %in%
      c(
        "serif",
        "sans-serif",
        "monospace",
        "cursive",
        "fantasy",
        "system-ui",
        "ui-monospace",
        "ui-serif",
        "ui-sans-serif",
        "-apple-system"
      )
  ) {
    return(name)
  }
  if (grepl("[[:space:]]", name)) {
    return(sprintf("\"%s\"", name))
  }
  name
}

# ---------------------------------------------------------------------
# check_fonts() — local-availability diagnostic
# ---------------------------------------------------------------------

#' Check font availability across backends
#'
#' Walks the resolved font fallback chain for each backend and
#' reports which entries the local machine can find. Useful for
#' answering "is the preview I'm seeing the same fonts the
#' downstream reviewer will see?".
#'
#' @details
#'
#' The diagnostic does NOT change what `emit()` writes to the
#' file. Tabular's backends emit font *names* (CSS strings, LaTeX
#' `\setmainfont` commands, RTF font-table entries); the consuming
#' application (browser, LaTeX engine, Word, Adobe Reader) on the
#' opening machine resolves those names against its own installed
#' fonts. `check_fonts()` is purely informational — it tells you
#' which entries of the cross-platform fallback chain you can see
#' on this machine, so you can predict drift.
#'
#' **Status markers:**
#'
#' * `v` — font is installed on this machine (via `systemfonts`).
#' * `o` — font is a CSS / LaTeX generic; always resolvable by
#'   the consuming application.
#' * `x` — font is not installed on this machine; the consuming
#'   app on a different machine may or may not have it.
#'
#' Requires the `systemfonts` package (in `Suggests`); call
#' `install.packages("systemfonts")` first if it isn't installed.
#'
#' @param spec *A `tabular_spec` or `preset_spec`.*
#'   `<tabular_spec | preset_spec>: required`. The spec whose
#'   effective preset determines which font chain to walk.
#'
#' @return *Invisibly returns the resolved per-backend chains as
#'   a named list of character vectors.* Side effect: prints a
#'   cli tree showing the availability marker for every entry.
#'
#' @examples
#' # ---- Example 1: Inspect default font resolution ----
#' #
#' # Build a spec with the default font_family ("serif") and ask
#' # which entries in the cross-platform chain are findable
#' # locally. Useful before sharing a render with downstream
#' # reviewers who may be on a different OS.
#' spec <- tabular(
#'   saf_demo,
#'   titles = "Demographics"
#' )
#' if (requireNamespace("systemfonts", quietly = TRUE)) {
#'   check_fonts(spec)
#' }
#'
#' # ---- Example 2: Diagnose a Courier New request ----
#' #
#' # A request for "Courier New" (a specific named font) renders
#' # on macOS / Windows but may fall back to a serif on Linux.
#' # `check_fonts()` flags this so the user knows to switch to
#' # the "mono" generic for portable output.
#' spec_mono <- tabular(
#'   saf_demo,
#'   titles = "Mono request"
#' ) |>
#'   preset(font_family = "Courier New")
#' if (requireNamespace("systemfonts", quietly = TRUE)) {
#'   check_fonts(spec_mono)
#' }
#'
#' @seealso
#' **Builds the spec:** [`tabular()`], [`preset()`].
#'
#' **Resolves the spec:** [`as_grid()`], [`emit()`].
#'
#' @export
check_fonts <- function(spec) {
  rlang::check_installed(
    "systemfonts",
    reason = "to inspect local font availability"
  )
  preset <- .check_fonts_preset(spec)
  fam <- preset@font_family

  cli::cli_h3("Font resolution for {.code font_family = {format(fam)}}")
  out <- list()
  for (backend in c("html", "latex", "rtf")) {
    chain <- .resolve_font_stack(fam, backend)
    cli::cli_text("{.strong backend:} {backend}")
    for (name in chain) {
      status <- .font_status(name)
      cli::cli_text("  {status$marker} {name}{status$note}")
    }
    out[[backend]] <- chain
  }
  invisible(out)
}

# Resolve a check_fonts() input to a preset_spec. Accepts either
# a tabular_spec (extracts the effective preset) or a preset_spec
# (passes through).
.check_fonts_preset <- function(spec) {
  if (is_preset_spec(spec)) {
    return(spec)
  }
  if (is_tabular_spec(spec)) {
    return(.effective_preset(spec))
  }
  cli::cli_abort(
    c(
      "{.arg spec} must be a {.cls tabular_spec} or {.cls preset_spec}.",
      "x" = "You supplied {.obj_type_friendly {spec}}."
    ),
    class = "tabular_error_input",
    call = rlang::caller_env(2L)
  )
}

# Report whether a single font name is locally available. Returns
# `list(marker, note)` for the cli printer.
.font_status <- function(name) {
  if (
    name %in%
      c(
        "serif",
        "sans",
        "sans-serif",
        "mono",
        "monospace",
        "system-ui",
        "ui-monospace",
        "ui-serif",
        "ui-sans-serif",
        "-apple-system",
        "cursive",
        "fantasy"
      )
  ) {
    return(list(marker = "o", note = " (generic, always available)"))
  }
  # systemfonts::system_fonts() returns a data frame of every
  # installed font on the machine; check the `family` column for
  # a case-insensitive exact match. Cheaper + more reliable than
  # match_fonts() (which always returns *some* path even when no
  # family matches — it falls back to a sensible default).
  installed <- tryCatch(
    systemfonts::system_fonts(),
    error = function(e) NULL
  )
  if (
    !is.null(installed) &&
      "family" %in% names(installed) &&
      tolower(name) %in% tolower(installed$family)
  ) {
    return(list(marker = "v", note = ""))
  }
  list(marker = "x", note = " (not on this machine)")
}
