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
# Shared per-generic chains (production-Linux-first)
# ---------------------------------------------------------------------

# Chain priority for every generic family: lead with the Liberation
# face (the Red Hat metric-compatible set that ships on Linux
# servers — Posit Workbench, Domino, Citrix, RStudio Server, every
# major Linux distro), then the Microsoft Office face for desktop
# Win / Mac consumers, then the bundled macOS-only legacy face.
# Liberation Serif / Sans / Mono are metric-compatible with Times
# New Roman / Arial / Courier New by design, so a document rendered
# with the Liberation face has the same layout (line breaks, decimal
# alignment, page breaks) as the same document rendered with the
# Office face. This is the right default for cross-OS regulatory-
# submission output where the server emits on Linux and the
# consumer opens on Windows / macOS.
#
# Per-backend tails are appended in `.resolve_font_stack`:
#   * HTML adds the CSS generic family (`serif` / `sans-serif` /
#     `monospace`) so the browser closes the chain with its own
#     class-appropriate default.
#   * LaTeX adds TeX Gyre (every TeX distribution ships it) and
#     Latin Modern (LaTeX always has it as the ultimate fallback).
#     The xelatex `\IfFontExistsTF` cascade walks the chain at
#     compile time.
#   * RTF appends nothing — the consuming app handles substitution
#     when the named face is missing (and we emit `\*\falt` so it
#     can pick the next chain entry explicitly).
.stack_serif <- c("Liberation Serif", "Times New Roman", "Times")
.stack_sans <- c("Liberation Sans", "Arial", "Helvetica")
.stack_mono <- c("Liberation Mono", "Courier New", "Courier")

# Backend tails — appended after the shared chain so the backend's
# native fallback layer always closes the chain. The LaTeX tail
# leads with TeX Gyre (ships with every TeX distribution including
# the minimal tinytex bundle) and ends with Latin Modern (LaTeX's
# guaranteed default — compile cannot fail with this leaf).
.latex_tail_serif <- c("TeX Gyre Termes", "Latin Modern Roman")
.latex_tail_sans <- c("TeX Gyre Heros", "Latin Modern Sans")
.latex_tail_mono <- c("TeX Gyre Cursor", "Latin Modern Mono")
.html_tail_serif <- "serif"
.html_tail_sans <- "sans-serif"
.html_tail_mono <- "monospace"

# ---------------------------------------------------------------------
# Named-font alias table for the PS-era four
# ---------------------------------------------------------------------

# The four PostScript-era font names (Times / Arial / Helvetica /
# Courier) and their Microsoft `_New` variants are intent aliases
# for the corresponding generic family. When the user writes
# `font_family = "Times"` they mean "Times-like rendering" — and on
# a Linux server with no Times installed, the only way to honour
# that intent is to expand to the serif chain (Liberation Serif is
# metric-compatible, so the rendering is layout-identical).
#
# The alias path triggers ONLY for length-1 inputs. Users who
# genuinely mean "Times only, fail if absent" pass an explicit
# length>1 vector — `c("Times", "Times")` — which the resolver
# returns verbatim without consulting the alias table.
.font_name_aliases <- list(
  "Times" = "serif",
  "Times New Roman" = "serif",
  "Arial" = "sans",
  "Helvetica" = "sans",
  "Courier" = "mono",
  "Courier New" = "mono"
)

# Look up the generic family for a named font, or return NULL when
# the name has no alias entry.
.resolve_font_alias <- function(name) {
  if (length(name) != 1L) {
    return(NULL)
  }
  .font_name_aliases[[name]]
}

# Compose the resolved chain for a generic family + backend. Shared
# core + per-backend tail. Used by `.resolve_font_stack` for both
# the generic-family path and the alias-hit path.
.compose_generic_chain <- function(fam, backend) {
  core <- switch(
    fam,
    serif = .stack_serif,
    sans = .stack_sans,
    mono = .stack_mono
  )
  tail <- switch(
    backend,
    latex = switch(
      fam,
      serif = .latex_tail_serif,
      sans = .latex_tail_sans,
      mono = .latex_tail_mono
    ),
    html = switch(
      fam,
      serif = .html_tail_serif,
      sans = .html_tail_sans,
      mono = .html_tail_mono
    ),
    # RTF + unknown backends: no tail (consuming app handles
    # substitution; RTF also gets explicit \*\falt in the font
    # table).
    character()
  )
  c(core, tail)
}

# ---------------------------------------------------------------------
# Public resolver
# ---------------------------------------------------------------------

# Resolve a `font_family` input to the per-backend fallback chain.
# Returns a character vector of font names in priority order.
#
# Five branches, in dispatch order:
#   1. Empty / NULL  -> normalise to `"mono"`.
#   2. Length > 1    -> explicit stack, verbatim; alias table is
#                       NOT consulted (escape hatch for users who
#                       want exact-name semantics).
#   3. Generic family (`serif` / `sans` / `mono` + CSS aliases) ->
#                       shared chain + backend tail.
#   4. Aliased name (Times / Arial / Helvetica / Courier and the
#      `_New` variants) -> resolve via alias to the generic chain
#      (same path as 3).
#   5. Non-aliased named font (Inter / JetBrains Mono / Source Pro
#      / sponsor-specific face) -> emit verbatim, no fallback.
.resolve_font_stack <- function(font_family, backend) {
  if (length(font_family) == 0L) {
    font_family <- "mono"
  }
  # Explicit stack: emit verbatim, no fabrication, no alias lookup.
  if (length(font_family) > 1L) {
    return(as.character(font_family))
  }
  # Single value path.
  if (.is_generic_family(font_family)) {
    fam <- .normalize_generic(font_family)
    return(.compose_generic_chain(fam, backend))
  }
  alias <- .resolve_font_alias(font_family)
  if (!is.null(alias)) {
    return(.compose_generic_chain(alias, backend))
  }
  # Named font, no alias, no fallback fabricated.
  as.character(font_family)
}

# ---------------------------------------------------------------------
# Generic-class classifier — single source of truth for Word formats
# ---------------------------------------------------------------------

# Classify a font specification (a resolved stack, a generic keyword, or
# an alias-named PS face) into ONE of "mono" / "serif" / "sans". This is
# the SSOT both Word-family backends consult so RTF and DOCX classify a
# given `font_family` identically: RTF maps the result to its family
# class (`mono` -> `\fmodern`, `serif` -> `\froman`, `sans` -> `\fswiss`)
# and DOCX to its OOXML class (`modern` / `roman` / `swiss`).
#
# Resolution: membership in the shared metric-compatible cores wins
# first (mono before serif before sans, matching the package default),
# then a literal generic keyword or PS-era alias appearing anywhere in
# the stack. A spec with no recognisable signal returns NA so each
# backend applies its own unclassified default (RTF -> `\froman`, the
# serif fallback; DOCX -> `swiss`) without this helper having to pick a
# class it cannot justify.
.font_generic_class <- function(stack) {
  if (any(stack %in% .stack_mono)) {
    return("mono")
  }
  if (any(stack %in% .stack_serif)) {
    return("serif")
  }
  if (any(stack %in% .stack_sans)) {
    return("sans")
  }
  generics <- vapply(
    stack,
    function(f) {
      if (.is_generic_family(f)) {
        return(.normalize_generic(f))
      }
      .resolve_font_alias(f) %||% NA_character_
    },
    character(1L)
  )
  generics <- generics[!is.na(generics)]
  if (length(generics) > 0L) {
    return(generics[[1L]])
  }
  NA_character_
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
#' @param .spec *A `tabular_spec` or `preset_spec`.*
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
#' # Build a spec with the default font_family ("mono") and ask
#' # which entries in the cross-platform chain are findable
#' # locally. Useful before sharing a render with downstream
#' # reviewers who may be on a different OS.
#' spec <- tabular(
#'   cdisc_saf_demo,
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
#'   cdisc_saf_demo,
#'   titles = "Mono request"
#' ) |>
#'   preset(font_family = "Courier New")
#' if (requireNamespace("systemfonts", quietly = TRUE)) {
#'   check_fonts(spec_mono)
#' }
#'
#' # ---- Example 3: Explicit cross-platform stack ----
#' #
#' # A length>1 input is treated as an explicit fallback chain and
#' # emitted verbatim — no alias lookup, no fabrication. Use this
#' # when the first choice is a sponsor / brand face that needs an
#' # honest fallback for reviewers who don't have it installed.
#' spec_brand <- tabular(cdisc_saf_demo) |>
#'   preset(font_family = c("Inter", "Liberation Sans", "Arial", "sans"))
#' if (requireNamespace("systemfonts", quietly = TRUE)) {
#'   check_fonts(spec_brand)
#' }
#'
#' # ---- Example 4: Compare serif vs sans fallback chains ----
#' #
#' # Side-by-side check of the two generic families. Useful when
#' # deciding the house-style default: the serif chain leads with
#' # Liberation Serif (Linux-server-first); the sans chain leads
#' # with Liberation Sans. Both close with the backend's native
#' # fallback layer (CSS generic on HTML, Latin Modern on LaTeX).
#' if (requireNamespace("systemfonts", quietly = TRUE)) {
#'   tabular(cdisc_saf_demo) |>
#'     preset(font_family = "serif") |>
#'     check_fonts()
#'
#'   tabular(cdisc_saf_demo) |>
#'     preset(font_family = "sans") |>
#'     check_fonts()
#' }
#'
#' @seealso
#' **Builds the spec:** [`tabular()`], [`preset()`].
#'
#' **Resolves the spec:** [`as_grid()`], [`emit()`].
#'
#' @export
check_fonts <- function(.spec) {
  rlang::check_installed(
    "systemfonts",
    reason = "to inspect local font availability"
  )
  preset <- .check_fonts_preset(.spec)
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
