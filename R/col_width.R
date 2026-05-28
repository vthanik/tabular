# col_width.R — column-width auto-sizing helpers.
#
# Three @noRd internals used by `.resolve_spec_to_grid()` when
# `col_spec(width = "auto")` columns need resolving:
#
#   .available_content_width(preset) -> inches
#     The page's printable area inside the margins.
#
#   .compute_col_width(cells, header_text, preset) -> inches
#     Measure widest cell (header + body) via AFM Core 13 and
#     return inches at the preset's font_size, with cell padding
#     added.
#
#   .distribute_widths(widths, available, ...) -> numeric inches
#     Combine pinned / auto / percent widths into a final vector.
#     In "content" mode auto widths keep their natural size and warn
#     on overflow (Word AutoFit-to-Contents); "window" fills, "fixed"
#     collapses auto cols to the minimum.
#
# Engine-side wiring lives in `R/as_grid.R::.resolve_spec_to_grid`.
# Pure helpers in this file — no S7 mutation, no I/O.

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------

# Paper inner dimensions in inches. Letter and A4 only; the
# preset enum (.paper_size_values) admits no others.
.paper_size_in <- list(
  letter = c(width = 8.5, height = 11),
  a4 = c(width = 8.27, height = 11.69)
)

# Minimum auto-resolved column width in inches. Below this, a
# column collapses to an unreadable sliver — clamp up so the
# layout stays sane even when a column has no content.
.min_auto_width_in <- 0.3

# ---------------------------------------------------------------------
# .available_content_width
# ---------------------------------------------------------------------

# Compute the printable area width in inches for a preset.
# Reads paper_size, orientation, margins. Returns numeric inches.
.available_content_width <- function(preset) {
  dims <- .paper_size_in[[preset@paper_size]]
  page_w <- if (identical(preset@orientation, "landscape")) {
    unname(dims[["height"]])
  } else {
    unname(dims[["width"]])
  }
  # Expand margins to (top, right, bottom, left) inches via the
  # CSS shorthand interpretation already used by other backends.
  m <- preset@margins
  parsed <- vapply(
    m,
    function(x) {
      p <- .parse_dim(x, allow_percent = FALSE)
      p$value * .tabular_unit_inches[[p$unit]]
    },
    numeric(1L)
  )
  margins_in <- switch(
    as.character(length(parsed)),
    "1" = c(parsed, parsed, parsed, parsed),
    "2" = c(parsed[[1L]], parsed[[2L]], parsed[[1L]], parsed[[2L]]),
    "4" = parsed
  )
  page_w - margins_in[[2L]] - margins_in[[4L]]
}

# Inches conversion factors mirroring `.tabular_unit_twips` in
# R/units.R. Inches are the canonical width unit for tabular's
# user-facing API; the existing twips table is for pagination
# math. Keep both in sync.
.tabular_unit_inches <- c(
  "in" = 1,
  "cm" = 1 / 2.54,
  "mm" = 1 / 25.4,
  "pt" = 1 / 72,
  "pc" = 12 / 72,
  # CSS px: 96 px = 1 in by spec. Matches gt's px-to-pt
  # conversion factor of 0.75 in `convert_to_pt()`.
  "px" = 1 / 96
)

# ---------------------------------------------------------------------
# .compute_col_width
# ---------------------------------------------------------------------

# Measure the widest cell (header + body) in a single column and
# return its rendered width in inches under the preset's font.
#
# Arguments:
#   cells     character vector. Body cell strings, already
#             formatted + decimal-padded (so prefix-padded values
#             contribute their actual rendered width). May
#             contain "\n" for multi-line cells; width is the
#             max line width.
#   header    character(1). Header label, post-flattening (no
#             markdown / HTML markup). Pass "" if column has no
#             header.
#   preset    `preset_spec` for font_family + font_size.
#   pad_x_pt  numeric(1). Per-side horizontal cell padding in pt
#             (the SSOT). Measurement adds `2 *` this for the
#             left + right margins. Defaults to
#             `preset@cell_padding_x`; callers pass the resolved
#             body override (see `.resolve_col_widths`).
#
# Returns numeric(1) inches. Floor at `.min_auto_width_in` so
# the column doesn't collapse.
.compute_col_width <- function(
  cells,
  header,
  preset,
  pad_x_pt = preset@cell_padding_x
) {
  body_afm <- .resolve_afm_name(preset@font_family, bold = FALSE)
  head_afm <- .resolve_afm_name(preset@font_family, bold = TRUE)
  font_size <- preset@font_size

  body_em <- if (length(cells) == 0L) {
    0L
  } else {
    body_lines <- unlist(strsplit(cells, "\n", fixed = TRUE))
    body_lines <- body_lines[!is.na(body_lines)]
    if (length(body_lines) == 0L) {
      0L
    } else {
      max(.text_width_em(body_lines, body_afm))
    }
  }

  head_em <- if (!nzchar(header)) {
    0L
  } else {
    head_lines <- unlist(strsplit(header, "\n", fixed = TRUE))
    max(.text_width_em(head_lines, head_afm))
  }

  max_em <- max(body_em, head_em)
  # em -> pt -> inches; add left + right cell padding (per-side pt).
  width_in <- (max_em / 1000) * font_size / 72 + 2 * pad_x_pt / 72
  max(width_in, .min_auto_width_in)
}

# ---------------------------------------------------------------------
# .ast_flatten_text — inline_ast -> plain text
# ---------------------------------------------------------------------

# Walk an `inline_ast` and concatenate all text content, dropping
# markup. Recursive over `children` for nested runs (bold inside
# italic, link inside span, etc.). Newlines become "\n" so the
# downstream max-line splitter sees them.
.ast_flatten_text <- function(ast) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  parts <- vapply(
    ast@runs,
    .run_text,
    character(1L)
  )
  paste0(parts, collapse = "")
}

# One run -> string. Dispatch on `type`; recursive for runs with
# children.
.run_text <- function(run) {
  if (!is.list(run) || is.null(run$type)) {
    return("")
  }
  switch(
    run$type,
    plain = as.character(run$text %||% ""),
    code = as.character(run$text %||% ""),
    newline = "\n",
    {
      kids <- run$children %||% list()
      if (length(kids) == 0L) {
        return("")
      }
      paste0(
        vapply(kids, .run_text, character(1L)),
        collapse = ""
      )
    }
  )
}

# ---------------------------------------------------------------------
# .resolve_col_widths — engine entry point
# ---------------------------------------------------------------------

# Build the resolved cols map for a spec at engine time. Walks
# every visible data column, resolves each width to numeric
# inches (auto -> AFM-measured; percent -> share of available;
# dim string -> parsed; numeric -> pass-through), then distributes
# against the printable area via `.distribute_widths()`.
#
# Returns a name-keyed list of col_spec entries covering every
# data column. Hidden columns retain their input width verbatim
# (their resolved width is not consumed by backends).
#
# Args:
#   spec        the `tabular_spec` (post-engine_format).
#   cells_text  decimal-aligned cells matrix (post-engine_decimal).
#               Column names = data column names; used to drive
#               measurement.
#   col_labels_ast  named list of `inline_ast` per data column;
#                   header text is the AST flattened.
.resolve_col_widths <- function(
  spec,
  cells_text,
  col_labels_ast,
  cols_override = NULL,
  cells_style = NULL
) {
  col_names <- names(spec@data)
  full_cols <- if (!is.null(cols_override)) {
    cols_override
  } else {
    .cols_by_name(spec@cols, col_names)
  }
  if (length(full_cols) == 0L) {
    return(full_cols)
  }
  preset <- .effective_preset(spec)
  available <- .available_content_width(preset)

  # Horizontal cell-padding SSOT: a resolved body @padding override
  # (from preset(padding=list(body=)) / style(at=cells_body())) drives
  # measurement so auto widths track the rendered cell margin; else the
  # preset default. This is the SAME scalar `.first_cell_padding()`
  # returns to the backends at render time.
  override_pad <- if (is.null(cells_style)) {
    NA_real_
  } else {
    .first_cell_padding(cells_style)
  }
  pad_x <- if (is.na(override_pad)) preset@cell_padding_x else override_pad

  visible <- vapply(
    full_cols,
    function(cs) isTRUE(cs@visible),
    logical(1L)
  )
  vis_names <- col_names[visible]
  if (length(vis_names) == 0L) {
    return(full_cols)
  }

  widths <- vector("list", length(vis_names))
  names(widths) <- vis_names
  for (nm in vis_names) {
    w <- full_cols[[nm]]@width
    widths[[nm]] <- .classify_width(
      w,
      cells_text,
      col_labels_ast,
      nm,
      preset,
      pad_x
    )
  }

  resolved <- .distribute_widths(widths, available, mode = preset@width_mode)

  for (nm in vis_names) {
    full_cols[[nm]] <- S7::set_props(
      full_cols[[nm]],
      width = unname(resolved[[nm]])
    )
  }
  full_cols
}

# Classify a raw col_spec@width value into the (kind, value)
# record `.distribute_widths()` consumes. Auto values are
# resolved to numeric inches via `.compute_col_width()` here so
# the distributor sees a numeric for every entry.
.classify_width <- function(
  w,
  cells_text,
  col_labels_ast,
  col_name,
  preset,
  pad_x_pt = preset@cell_padding_x
) {
  if (.is_auto_width(w)) {
    cells <- if (col_name %in% colnames(cells_text)) {
      cells_text[, col_name]
    } else {
      character(0L)
    }
    header <- .ast_flatten_text(col_labels_ast[[col_name]])
    list(
      kind = "auto",
      value = .compute_col_width(cells, header, preset, pad_x_pt)
    )
  } else if (is.numeric(w)) {
    list(kind = "pin", value = as.numeric(w))
  } else {
    parsed <- .parse_dim(w, allow_percent = TRUE)
    if (identical(parsed$unit, "%")) {
      list(kind = "pct", value = parsed$value)
    } else {
      list(
        kind = "pin",
        value = parsed$value * .tabular_unit_inches[[parsed$unit]]
      )
    }
  }
}

# ---------------------------------------------------------------------
# .distribute_widths
# ---------------------------------------------------------------------

# Resolve a list of mixed-kind column widths against an available
# content width. Returns a named numeric vector of inches.
#
# Input `widths` is a named list. Each entry is a length-2 list:
#
#   list(kind = "pin",  value = <numeric inches>)
#   list(kind = "auto", value = <numeric inches, pre-computed by
#                                 .compute_col_width>)
#   list(kind = "pct",  value = <numeric percent 0-100>)
#
# Rules:
#   - Pinned and resolved-percent widths take priority.
#   - remaining = available - sum(pinned) - sum(resolved_percent).
#   - If remaining <= 0: pinned overflow. Warn (class
#     "tabular_warn_layout") and return widths as-is (auto values
#     unchanged, percent values resolved).
#   - "content" mode: keep auto widths as-is (Word AutoFit-to-
#     Contents). Don't expand to fill; don't shrink on overflow.
#     Warn (class "tabular_warn_layout") when the natural total
#     exceeds the page so the user can pin widths or switch mode.
.distribute_widths <- function(widths, available, mode = "content") {
  if (length(widths) == 0L) {
    return(numeric(0L))
  }
  kinds <- vapply(widths, function(w) w$kind, character(1L))
  values <- vapply(widths, function(w) as.numeric(w$value), numeric(1L))
  names(values) <- names(widths)

  is_pin <- kinds == "pin"
  is_auto <- kinds == "auto"
  is_pct <- kinds == "pct"

  resolved <- values
  resolved[is_pct] <- values[is_pct] / 100 * available

  reserved <- sum(resolved[is_pin]) + sum(resolved[is_pct])
  remaining <- available - reserved

  if (!any(is_auto)) {
    return(resolved)
  }

  if (remaining <= 0) {
    cli::cli_warn(
      c(
        "Pinned column widths exceed the available content width.",
        "i" = "Reserved: {round(reserved, 2)} in; available: {round(available, 2)} in.",
        "i" = "Auto-sized columns left at their natural width; layout may overflow."
      ),
      class = "tabular_warn_layout"
    )
    return(resolved)
  }

  # Table-level width_mode dispatch. "content" (default) keeps the
  # natural-fit shrink behavior; "window" promotes auto cols to share
  # the residual equally (Word's Auto-fit Window); "fixed" collapses
  # auto cols to the minimum sliver so only pinned + percent drive
  # the layout (Word's Fixed Column Width).
  if (identical(mode, "fixed")) {
    resolved[is_auto] <- .min_auto_width_in
    return(resolved)
  }
  if (identical(mode, "window")) {
    resolved[is_auto] <- remaining / sum(is_auto)
    return(resolved)
  }

  # mode == "content" (default): Word AutoFit-to-Contents. Each auto
  # column keeps its natural measured width, never silently shrunk. If
  # the natural total overflows, warn and overflow rather than
  # cramming text into too-narrow columns.
  sum_auto <- sum(values[is_auto])
  if (sum_auto > remaining) {
    cli::cli_warn(
      c(
        "Auto-sized columns exceed the available content width.",
        "i" = "Natural width {round(reserved + sum_auto, 2)} in; available {round(available, 2)} in.",
        "i" = "Columns kept at natural width; the table will overflow. Set {.code col_spec(width = ...)} or {.code preset(width_mode = \"fixed\")} to constrain it."
      ),
      class = "tabular_warn_layout"
    )
  }
  resolved
}
