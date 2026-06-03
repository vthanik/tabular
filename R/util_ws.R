# Verbatim whitespace preservation.
#
# Backends collapse significant runs of ASCII space by default (HTML
# folds runs to one, LaTeX/md likewise, the visual indent of a
# hand-built label like "     Placebo" is lost). `.preserve_ws()`
# rewrites significant U+0020 runs into the backend non-breaking token
# so the rendered cell is WYSIWYG, while keeping cells wrappable: a
# single interior space stays breakable, and each interior run of 2+
# spaces keeps exactly one breakable space.
#
# Rules:
#   * a leading run (any length)  -> all non-breaking
#   * a trailing run (any length) -> all non-breaking
#   * an interior run of length k>=2 -> (k-1) non-breaking + 1 breakable
#   * a single interior space     -> untouched (stays breakable)
#   * U+00A0 (engine_decimal padding) and tab are never touched -- the
#     regexes operate on U+0020 only, so decimal alignment is safe by
#     construction.
#
# MUST run as the LAST step of a backend's cell path: after the indent
# strip (HTML CSS padding / RTF `\li`), after escaping, and after the
# `\n` -> line-break conversion, so it only ever sees residual user
# whitespace -- never the engine's own indent or structural markup.

#' @noRd
# `lead` / `trail` say whether this string sits at the start / end of
# its visual LINE. A leading / trailing space run is only significant
# (made non-breaking) at a true line edge; at a run boundary inside a
# line (e.g. the spaces in "Page <b>1</b> of 2" split across plain
# runs) it must stay a breakable inter-word space. Interior runs of 2+
# spaces are always preserved regardless of position. The whole-cell
# body path uses the default `lead = trail = TRUE`.
.preserve_ws <- function(x, nbsp, lead = TRUE, trail = TRUE) {
  if (length(x) == 0L) {
    return(x)
  }
  # leading run (if lead) | trailing run (if trail) | interior 2+ run
  pat <- if (lead && trail) {
    "^ | $|  "
  } else if (lead) {
    "^ |  "
  } else if (trail) {
    " $|  "
  } else {
    "  "
  }
  hit <- !is.na(x) & grepl(pat, x)
  if (!any(hit)) {
    return(x)
  }
  x[hit] <- vapply(
    x[hit],
    .preserve_ws_one,
    character(1L),
    nbsp = nbsp,
    lead = lead,
    trail = trail,
    USE.NAMES = FALSE
  )
  x
}

#' @noRd
# Resolve the whitespace-preservation flag from a (possibly NULL or
# non-preset) backend preset handle. The package-wide default is
# "preserve", so a missing / non-preset handle preserves.
.preset_ws_preserve <- function(preset) {
  !is_preset_spec(preset) || identical(preset@whitespace, "preserve")
}

#' @noRd
# Split one line into its non-breaking wrap segments under whitespace
# preservation -- the units the renderer can break BETWEEN. Mirrors
# `.preserve_ws_one`: leading / trailing runs and the (k-1) extra
# spaces of an interior run of length k>=2 stay attached (non-
# breaking); a single interior space (and the one kept space of a 2+
# run) is the only break point. Used by column-width measurement so a
# hand-built indent is reserved, while a normal single-spaced header
# still wraps word-by-word. Spaces in the returned segments are plain
# U+0020 -- safe to measure directly because a non-breaking token
# renders at the same glyph width as a space.
.ws_wrap_segments <- function(s) {
  if (is.na(s) || !nzchar(s)) {
    return(character())
  }
  pieces <- regmatches(s, gregexpr("( +)|[^ ]+", s))[[1L]]
  n <- length(pieces)
  segs <- character()
  cur <- ""
  for (i in seq_len(n)) {
    p <- pieces[[i]]
    if (substr(p, 1L, 1L) != " ") {
      cur <- paste0(cur, p) # non-space token: attach to current segment
      next
    }
    k <- nchar(p)
    if (i == 1L || i == n) {
      cur <- paste0(cur, p) # leading / trailing run: non-breaking
    } else if (k == 1L) {
      segs <- c(segs, cur) # single interior space: break point
      cur <- ""
    } else {
      cur <- paste0(cur, strrep(" ", k - 1L)) # (k-1) non-breaking
      segs <- c(segs, cur) # then one breakable space
      cur <- ""
    }
  }
  segs <- c(segs, cur)
  segs[nzchar(segs)]
}

#' @noRd
.preserve_ws_one <- function(s, nbsp, lead = TRUE, trail = TRUE) {
  # Split into alternating space-runs (U+0020 only) and non-space runs.
  pieces <- regmatches(s, gregexpr("( +)|[^ ]+", s))[[1L]]
  n <- length(pieces)
  for (i in seq_len(n)) {
    p <- pieces[[i]]
    if (substr(p, 1L, 1L) != " ") {
      next # non-space run (keeps tab / U+00A0 / glyphs verbatim)
    }
    k <- nchar(p)
    line_lead <- i == 1L && lead
    line_trail <- i == n && trail
    if (line_lead || line_trail) {
      pieces[[i]] <- strrep(nbsp, k) # true line edge: all non-breaking
    } else if (k >= 2L) {
      pieces[[i]] <- paste0(strrep(nbsp, k - 1L), " ") # interior: keep 1 break
    }
    # else: a single space that is not a line edge stays a breakable
    # U+0020 (normal inter-word / run-boundary spacing).
  }
  paste0(pieces, collapse = "")
}
