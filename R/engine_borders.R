# engine_borders.R — translate `preset@borders` region specifications
# to per-cell `border_<side>_{style,width,color}` entries on the
# resolved cells_style matrix. Runs AFTER `engine_style()` in the
# resolve pipeline so per-cell predicate borders (the highest layer
# in the cascade) can override theme-side region borders if needed.
#
# Region semantics (Phase 6 implements body-cell regions; header /
# subgroup / footer regions defer to backends rendering those
# surfaces — engine_borders is a no-op for them today):
#
#   outer / outer_top / outer_bottom / outer_left / outer_right
#       - The four outer edges of the body table. `outer` is the
#         shorthand for all four; per-side keys override per side.
#   body_top / body_bottom
#       - Aliases for outer_top / outer_bottom; both keys are
#         recognised so users have a vocabulary that maps to either
#         "the top of the body" or "the table's outer top".
#   body_rows
#       - The horizontal separators BETWEEN body rows. Implemented
#         as `border_top` on every row except the first.
#   body_cols
#       - The vertical separators BETWEEN body columns. Implemented
#         as `border_left` on every visible column except the first.
#
# Region values follow the same shape as `style()`'s per-cell
# triple:
#
#   brdr()-constructed `tabular_brdr`     -> applied
#   bare list(style, width, color)        -> applied
#   "none"                                -> applied as explicit clear
#   NULL                                  -> ignored (no effect)
#
# Visibility-aware: only `col_spec@visible` columns participate in
# `body_cols`. The cells_style matrix carries entries for every data
# column; engine_borders stamps borders on hidden columns harmlessly
# (backends iterate by visible names and ignore the rest).

#' Translate preset@borders region specs to per-cell style entries
#'
#' Pure function. Called by the resolve engine after `engine_style()`
#' so per-cell predicate borders (highest priority) override theme
#' region borders (this layer). Returns the cells_style matrix with
#' updated `border_<side>_*` scalars wherever the active preset's
#' `@borders` named-list resolves a region to a non-NULL value.
#'
#' @param spec A `tabular_spec`.
#' @param cells_style The output of `engine_style(spec)` -- an
#'   nrow x ncol list-matrix of `style_node` objects.
#' @return The updated cells_style matrix (same shape, same column
#'   names). Cells outside any region come through unchanged.
#' @keywords internal
#' @noRd
engine_borders <- function(spec, cells_style) {
  if (!is.matrix(cells_style)) {
    return(cells_style)
  }
  preset <- .effective_preset(spec)
  borders <- preset@borders
  if (length(borders) == 0L) {
    return(cells_style)
  }

  nrow_data <- nrow(cells_style)
  ncol_data <- ncol(cells_style)
  if (nrow_data == 0L || ncol_data == 0L) {
    return(cells_style)
  }
  col_names <- colnames(cells_style)
  visible_idx <- .visible_col_indices(spec, col_names)
  if (length(visible_idx) == 0L) {
    return(cells_style)
  }

  # Region resolution: merge the umbrella `outer` triple into each
  # per-side override (per-side wins). Body aliases collapse onto
  # outer_top / outer_bottom.
  resolved <- .resolve_border_regions(borders)

  # Apply the resolved per-region triples to the corresponding
  # cells. Order matters only for visual debugging — the resolver
  # consults all 4 per-side scalars per cell anyway, so the final
  # `style_node` carries the last-write wins for each side.
  for (side in c("top", "bottom", "left", "right")) {
    edge_key <- paste0("outer_", side)
    triple <- resolved[[edge_key]]
    if (!is.null(triple)) {
      cells_style <- .stamp_outer_edge(
        cells_style,
        visible_idx = visible_idx,
        side = side,
        triple = triple
      )
    }
  }

  if (!is.null(resolved$body_rows)) {
    cells_style <- .stamp_body_rows(
      cells_style,
      visible_idx = visible_idx,
      triple = resolved$body_rows
    )
  }
  if (!is.null(resolved$body_cols)) {
    cells_style <- .stamp_body_cols(
      cells_style,
      visible_idx = visible_idx,
      triple = resolved$body_cols
    )
  }
  cells_style
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Resolve a `preset@borders` named-list to a flat per-region triple
# list. Splits the umbrella `outer` into its four per-side aliases;
# `body_top` / `body_bottom` collapse onto `outer_top` /
# `outer_bottom`. Per-side keys win over `outer` (e.g.
# `list(outer = brdr(), outer_right = "none")` clears just the
# right edge).
.resolve_border_regions <- function(borders) {
  out <- list(
    outer_top = NULL,
    outer_bottom = NULL,
    outer_left = NULL,
    outer_right = NULL,
    body_rows = NULL,
    body_cols = NULL
  )
  outer <- .normalise_region_value(borders[["outer"]])
  if (!is.null(outer)) {
    out$outer_top <- outer
    out$outer_bottom <- outer
    out$outer_left <- outer
    out$outer_right <- outer
  }
  # Per-side keys override the `outer` shorthand.
  side_keys <- c(
    outer_top = "outer_top",
    outer_bottom = "outer_bottom",
    outer_left = "outer_left",
    outer_right = "outer_right"
  )
  for (slot in names(side_keys)) {
    v <- .normalise_region_value(borders[[side_keys[[slot]]]])
    if (!is.null(v)) {
      out[[slot]] <- v
    }
  }
  # body_top / body_bottom aliases — they layer onto the per-side
  # outer_top / outer_bottom slots (last-set wins).
  bt <- .normalise_region_value(borders[["body_top"]])
  if (!is.null(bt)) {
    out$outer_top <- bt
  }
  bb <- .normalise_region_value(borders[["body_bottom"]])
  if (!is.null(bb)) {
    out$outer_bottom <- bb
  }
  out$body_rows <- .normalise_region_value(borders[["body_rows"]])
  out$body_cols <- .normalise_region_value(borders[["body_cols"]])
  out
}

# Coerce a region's value to the bare `list(style, width, color)`
# triple that engine_borders writes to style_node. Accepts:
#   * NULL                  -> NULL (no effect)
#   * "none"                -> explicit clear sentinel
#   * tabular_brdr value    -> unwrap via `.as_brdr_triple`
#   * bare list(style, width, color) -> pass through
.normalise_region_value <- function(v) {
  if (is.null(v)) {
    return(NULL)
  }
  if (identical(v, "none") || identical(v, "off")) {
    return(list(style = "none", width = 0, color = NA_character_))
  }
  .as_brdr_triple(v)
}

# Visible column indices on `cells_style` -- preserves the order in
# which they appear in `col_names`. Hidden cols are skipped so
# `body_cols` doesn't stamp a vertical separator on, e.g., a
# `visible = FALSE` sort-key helper.
.visible_col_indices <- function(spec, col_names) {
  cols <- spec@cols
  vis <- vapply(
    col_names,
    function(nm) {
      cs <- cols[[nm]]
      if (!is_col_spec(cs)) {
        return(TRUE)
      }
      isTRUE(cs@visible)
    },
    logical(1L)
  )
  which(vis)
}

# Stamp the four outer-edge cells along one side. Each side covers
# either an entire row (top / bottom) or an entire visible column
# (left / right).
.stamp_outer_edge <- function(cells_style, visible_idx, side, triple) {
  nrow_data <- nrow(cells_style)
  ncol_visible <- length(visible_idx)
  if (nrow_data == 0L || ncol_visible == 0L) {
    return(cells_style)
  }
  prop_style <- paste0("border_", side, "_style")
  prop_width <- paste0("border_", side, "_width")
  prop_color <- paste0("border_", side, "_color")

  if (side == "top") {
    rows <- 1L
    cols <- visible_idx
  } else if (side == "bottom") {
    rows <- nrow_data
    cols <- visible_idx
  } else if (side == "left") {
    rows <- seq_len(nrow_data)
    cols <- visible_idx[[1L]]
  } else {
    rows <- seq_len(nrow_data)
    cols <- visible_idx[[length(visible_idx)]]
  }
  for (r in rows) {
    for (c in cols) {
      cells_style[[r, c]] <- .set_border_triple(
        cells_style[[r, c]],
        prop_style = prop_style,
        prop_width = prop_width,
        prop_color = prop_color,
        triple = triple
      )
    }
  }
  cells_style
}

# Stamp horizontal separators between body rows: every row except
# the first carries the triple on its TOP side.
.stamp_body_rows <- function(cells_style, visible_idx, triple) {
  nrow_data <- nrow(cells_style)
  if (nrow_data < 2L) {
    return(cells_style)
  }
  for (r in seq(2L, nrow_data)) {
    for (c in visible_idx) {
      cells_style[[r, c]] <- .set_border_triple(
        cells_style[[r, c]],
        prop_style = "border_top_style",
        prop_width = "border_top_width",
        prop_color = "border_top_color",
        triple = triple
      )
    }
  }
  cells_style
}

# Stamp vertical separators between body columns: every visible
# column except the first carries the triple on its LEFT side.
.stamp_body_cols <- function(cells_style, visible_idx, triple) {
  ncol_visible <- length(visible_idx)
  if (ncol_visible < 2L) {
    return(cells_style)
  }
  nrow_data <- nrow(cells_style)
  for (c in visible_idx[-1L]) {
    for (r in seq_len(nrow_data)) {
      cells_style[[r, c]] <- .set_border_triple(
        cells_style[[r, c]],
        prop_style = "border_left_style",
        prop_width = "border_left_width",
        prop_color = "border_left_color",
        triple = triple
      )
    }
  }
  cells_style
}

# Apply one (style, width, color) triple to a style_node's per-side
# scalars — but ONLY where the cell does not already carry a
# predicate-layer border on that side. This preserves the cascade
# (predicate > region) even though engine_borders runs after
# engine_style: predicate borders survive intact, region values
# fill the silent gaps.
.set_border_triple <- function(
  node,
  prop_style,
  prop_width,
  prop_color,
  triple
) {
  if (!is_style_node(node)) {
    node <- style_node()
  }
  # If any of the three per-side scalars is already explicit (the
  # predicate layer touched it), respect that and skip this region.
  if (.border_side_explicit(node, prop_style, prop_width, prop_color)) {
    return(node)
  }
  args <- list(node)
  args[[prop_style]] <- if (is.null(triple$style)) {
    NA_character_
  } else {
    triple$style
  }
  args[[prop_width]] <- if (is.null(triple$width)) NA_real_ else triple$width
  args[[prop_color]] <- if (is.null(triple$color)) {
    NA_character_
  } else {
    triple$color
  }
  do.call(S7::set_props, args)
}

# True iff any of the three per-side scalars is already non-default
# (NA / 0-length). Used by engine_borders to skip region stamping on
# cells the predicate layer already touched.
.border_side_explicit <- function(node, prop_style, prop_width, prop_color) {
  for (p in c(prop_style, prop_width, prop_color)) {
    v <- S7::prop(node, p)
    if (length(v) == 1L && !is.na(v)) {
      return(TRUE)
    }
  }
  FALSE
}
