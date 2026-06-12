# geometry.R — internal unit-conversion and page-geometry helpers
# shared by engine_paginate (page row-budget) and the upcoming
# engine_decimal phase (decimal alignment via font metrics). All
# functions are pure; no I/O, no state. Names are dot-prefixed and
# never exported.
#
# The twips model is portable: 1440 twips = 1 inch, 20 twips = 1
# point. Galley uses the same units throughout its render stack; we
# port the small set we need rather than depending on it.

# Paper sizes in twips (width x height in portrait orientation).
# Values taken from the W3C @page reference and verified against
# Word's page-setup dialog. landscape() swaps width and height.
.tabular_paper_twips <- list(
  letter = c(width = 12240L, height = 15840L),
  a4 = c(width = 11906L, height = 16838L),
  legal = c(width = 12240L, height = 20163L)
)

# Word's single-line spacing ratio: 1.2 x font_size. Matches LaTeX's
# baseline_skip convention.
.tabular_baseline_ratio <- 1.2

# Inches -> twips. 1in = 1440 twips.
.inches_to_twips <- function(inches) as.integer(round(inches * 1440))

# Points -> twips. 1pt = 20 twips.
.pt_to_twips <- function(pt) as.integer(round(pt * 20))

# Paper dimensions accounting for orientation. Returns a length-2
# named integer vector: c(width = w, height = h) in twips. Aborts
# (internal) if the paper key is unknown — callers gate this via
# preset_spec validators so end users see a friendly verb error.
.paper_dims_twips <- function(paper = "letter", orientation = "portrait") {
  dims <- .tabular_paper_twips[[paper]]
  if (is.null(dims)) {
    cli::cli_abort(
      c(
        "Unknown paper {.val {paper}}.",
        "i" = "Known: {.val {names(.tabular_paper_twips)}}."
      ),
      class = "tabular_error_input"
    )
  }
  if (orientation == "landscape") {
    c(width = unname(dims[["height"]]), height = unname(dims[["width"]]))
  } else {
    dims
  }
}

# Row height in twips for body text at the given point size. Uses
# the LaTeX Companion formula:
#   height = array_stretch * (extra_row_height_pt + baseline_skip_pt)
#   baseline_skip = .tabular_baseline_ratio * font_size_pt
# Defaults match a single-spaced regulatory body row.
.row_height_twips <- function(
  font_size_pt,
  array_stretch = 1.0,
  extra_row_height_pt = 1.0
) {
  baseline_pt <- .tabular_baseline_ratio * font_size_pt
  height_pt <- array_stretch * (extra_row_height_pt + baseline_pt)
  .pt_to_twips(height_pt)
}

# Resolve top/bottom margin twips from preset@margins. `margins`
# follows CSS shorthand:
#
# * length 1: all four sides equal
# * length 2: vertical (top+bottom), horizontal (left+right)
# * length 4: top, right, bottom, left
#
# Each element may be numeric (interpreted as inches, back-compat)
# or character with a TeX unit suffix (in / cm / mm / pt / pc).
# Routes through `.parse_dim` so the unit semantics are shared
# with backend_latex's `\geometry{}` composer.
.margin_top_bottom_twips <- function(margins) {
  parsed <- lapply(seq_along(margins), function(i) {
    .parse_dim(margins[[i]], allow_percent = FALSE)
  })
  if (length(parsed) == 1L) {
    m <- .dim_to_twips(parsed[[1L]])
    return(c(top = m, bottom = m))
  }
  if (length(parsed) == 2L) {
    m <- .dim_to_twips(parsed[[1L]])
    return(c(top = m, bottom = m))
  }
  c(
    top = .dim_to_twips(parsed[[1L]]),
    bottom = .dim_to_twips(parsed[[3L]])
  )
}

# Resolve left/right margin twips from preset@margins. Mirror of
# `.margin_top_bottom_twips` for the horizontal pair, using the same
# CSS-shorthand length rule:
#
# * length 1: all four sides equal
# * length 2: vertical (top+bottom), horizontal (left+right)
# * length 4: top, right, bottom, left
#
# Used by `.content_box()` to size the body region's width.
.margin_left_right_twips <- function(margins) {
  parsed <- lapply(seq_along(margins), function(i) {
    .parse_dim(margins[[i]], allow_percent = FALSE)
  })
  if (length(parsed) == 1L) {
    m <- .dim_to_twips(parsed[[1L]])
    return(c(left = m, right = m))
  }
  if (length(parsed) == 2L) {
    m <- .dim_to_twips(parsed[[2L]])
    return(c(left = m, right = m))
  }
  c(
    left = .dim_to_twips(parsed[[4L]]),
    right = .dim_to_twips(parsed[[2L]])
  )
}

# Placement descriptor for a single content block (the empty-state
# message; a figure image in a later release) within a content box.
# Backend-neutral: each renderer translates `halign` / `valign` into its
# native mechanism (RTF `\ql/\qc/\qr` + `\clvertalt/c/b`, DOCX `<w:jc>` +
# `<w:vAlign>`, LaTeX `\raggedright/\centering/\raggedleft` + `\vfill`
# bracketing, HTML flex `justify-content` / `align-items`). Carries the
# box geometry so paged backends can size the host cell to the box height
# and centre vertically exactly. `box` is a `.content_box()` result.
.place_block <- function(halign, valign, box) {
  list(
    halign = halign,
    valign = valign,
    width_in = box$width_in,
    height_in = box$height_in,
    width_twips = box$width_twips,
    height_twips = box$height_twips
  )
}

# Return the effective preset_spec for `spec` using the documented
# cascade:
#   1. spec@preset (attached via `preset()`),
#   2. .tabular_session$preset (attached via `set_preset()`),
#   3. fresh `preset_spec()` defaults.
# The first non-NULL layer wins; layers are not field-merged across
# the cascade. Used by every engine phase that needs paper / font
# geometry.
.effective_preset <- function(spec) {
  p <- spec@preset
  if (is_preset_spec(p)) {
    return(p)
  }
  s <- .tabular_session$preset
  if (is_preset_spec(s)) {
    return(s)
  }
  preset_spec()
}
