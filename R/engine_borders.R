# engine_borders.R — stamp `cells_table()` border layers onto the
# resolved cells_style matrix. Runs AFTER `engine_style()` in the
# resolve pipeline so per-cell predicate borders survive intact
# alongside the table-region layers.
#
# After the Task 4/5 slot cut, every theme-level border specification
# enters through `preset(borders = list(...))` or `set_preset(borders
# = list(...))`, gets lowered to `style_layer` records targeting
# `cells_*()` locations by `.preset_args_to_layers()`, and lands on
# `preset@style`. The body-region half (locations whose
# `loc$surface == "table"`) is the engine_borders responsibility; the
# chrome half (header / subgroup / footer / pagehead / pagefoot) is
# the engine_chrome_borders responsibility.
#
# Region semantics for body-region `cells_table(side = ...)` layers:
#
#   outer / outer_top / outer_bottom / outer_left / outer_right
#       - The four outer edges of the body table. `outer` (or
#         `NULL` for the whole-body shorthand) stamps all four;
#         per-side keys stamp one edge.
#   rows
#       - The horizontal separators BETWEEN body rows. Stamped on
#         the `border_top` scalar of every row except the first.
#   cols
#       - The vertical separators BETWEEN body columns. Stamped on
#         the `border_left` scalar of every visible column except
#         the first.
#
# Layer values follow the per-cell triple shape (style / width /
# color) read off the layer's `style_node` via
# `.style_node_border_triple()`.
#
# Visibility-aware: only `col_spec@visible` columns participate in
# `cols` and `outer_left` / `outer_right`. The cells_style matrix
# carries entries for every data column; engine_borders stamps
# borders on hidden columns harmlessly (backends iterate by visible
# names and ignore the rest).

#' Stamp `cells_table()` border layers onto the cells_style matrix
#'
#' Pure function. Called by the resolve engine after `engine_style()`
#' so per-cell predicate borders survive intact alongside the
#' table-region layers (predicates land first, table layers stamp
#' over them — layer order is precedence within the cascade).
#' Walks the session preset → spec preset → per-spec layer cascade
#' and applies every layer whose location is a `cells_table`.
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
  for (layer in .collect_table_layers(spec)) {
    cells_style <- .apply_table_layer(
      layer = layer,
      cells_style = cells_style,
      visible_idx = visible_idx
    )
  }
  cells_style
}

#' Resolve body-region border triples for backend manifest emission
#'
#' Walk the cascade collected by `.collect_table_layers(spec)` and
#' flatten to one resolved triple per body-region side. Returns a
#' fixed-shape named list with slots
#' `outer_top` / `outer_bottom` / `outer_left` / `outer_right` /
#' `rows` / `cols`; each slot is either `NULL` (no override — backend
#' uses its built-in default rule) or a `list(style, width, color)`
#' triple. Last-write wins per slot (layer order is precedence).
#'
#' Used by backends like LaTeX that emit table-level border
#' directives (`hline{i}={spec}` / `vline{j}={spec}`) which can't be
#' inferred efficiently from per-cell border scalars on `cells_style`.
#' Sits alongside `chrome_style$borders` as the body half of the
#' equivalent sidecar.
#'
#' @param spec A `tabular_spec`.
#' @return Named list (length 6) of triples or NULLs.
#' @keywords internal
#' @noRd
body_border_manifest <- function(spec) {
  out <- list(
    outer_top = NULL,
    outer_bottom = NULL,
    outer_left = NULL,
    outer_right = NULL,
    rows = NULL,
    cols = NULL
  )
  for (layer in .collect_table_layers(spec)) {
    side <- layer@location$side
    node <- layer@style
    if (is.null(side) || identical(side, "outer")) {
      for (s in c("top", "bottom", "left", "right")) {
        triple <- .style_node_border_triple(node, s)
        if (!is.null(triple)) {
          out[[paste0("outer_", s)]] <- triple
        }
      }
      next
    }
    if (
      side %in% c("outer_top", "outer_bottom", "outer_left", "outer_right")
    ) {
      s <- sub("^outer_", "", side)
      triple <- .style_node_border_triple(node, s)
      if (!is.null(triple)) {
        out[[side]] <- triple
      }
      next
    }
    if (identical(side, "rows")) {
      triple <- .style_node_border_triple(node, "top")
      if (!is.null(triple)) {
        out$rows <- triple
      }
      next
    }
    if (identical(side, "cols")) {
      triple <- .style_node_border_triple(node, "left")
      if (!is.null(triple)) {
        out$cols <- triple
      }
    }
  }
  out
}

# Collect every layer in the four-tier cascade whose location is a
# `cells_table` (border-only surface). Returns layers in cascade
# order — session preset first, per-spec layers last — so the
# last-write wins per side at stamp time.
.collect_table_layers <- function(spec) {
  sources <- list()
  session <- get_preset()
  if (is_preset_spec(session)) {
    sources <- c(sources, session@style)
  }
  if (is_preset_spec(spec@preset)) {
    sources <- c(sources, spec@preset@style)
  }
  if (is_style_spec(spec@styles)) {
    sources <- c(sources, spec@styles@layers)
  }
  matches <- vapply(
    sources,
    function(layer) {
      loc <- layer@location
      !is.null(loc) && identical(loc$surface, "table")
    },
    logical(1L)
  )
  sources[matches]
}

# Stamp one cells_table layer onto the cells_style matrix. Maps the
# location's `side` onto the per-side / per-row / per-col force-stamp
# helpers; reads the matching border_<side>_{style,width,color}
# triple off the layer's style_node.
#
# Every cells_table layer force-writes — layer order IS precedence
# within the cascade, so users compose layers expecting later writes
# to win per attribute. Per-cell predicate borders on cells_style
# survive UNTIL a later table-region layer in the cascade overlays
# them; if you want a predicate border to win, declare the predicate
# layer AFTER the table-region layer in the chain.
.apply_table_layer <- function(layer, cells_style, visible_idx) {
  side <- layer@location$side
  node <- layer@style
  if (is.null(side) || identical(side, "outer")) {
    for (s in c("top", "bottom", "left", "right")) {
      triple <- .style_node_border_triple(node, s)
      if (!is.null(triple)) {
        cells_style <- .stamp_outer_edge_force(
          cells_style,
          visible_idx = visible_idx,
          side = s,
          triple = triple
        )
      }
    }
    return(cells_style)
  }
  if (side %in% c("outer_top", "outer_bottom", "outer_left", "outer_right")) {
    s <- sub("^outer_", "", side)
    triple <- .style_node_border_triple(node, s)
    if (!is.null(triple)) {
      cells_style <- .stamp_outer_edge_force(
        cells_style,
        visible_idx = visible_idx,
        side = s,
        triple = triple
      )
    }
    return(cells_style)
  }
  if (identical(side, "rows")) {
    triple <- .style_node_border_triple(node, "top")
    if (!is.null(triple)) {
      cells_style <- .stamp_body_rows_force(
        cells_style,
        visible_idx = visible_idx,
        triple = triple
      )
    }
    return(cells_style)
  }
  if (identical(side, "cols")) {
    triple <- .style_node_border_triple(node, "left")
    if (!is.null(triple)) {
      cells_style <- .stamp_body_cols_force(
        cells_style,
        visible_idx = visible_idx,
        triple = triple
      )
    }
    return(cells_style)
  }
  cells_style
}

# Force-stamp helpers — always write the triple onto the targeted
# cells. Each is the canonical write surface for one body-region
# location side; their write contract (always-write, per-attribute
# overlay) is what makes layer order = precedence.
.stamp_outer_edge_force <- function(cells_style, visible_idx, side, triple) {
  nrow_data <- nrow(cells_style)
  ncol_visible <- length(visible_idx)
  if (nrow_data == 0L || ncol_visible == 0L) {
    return(cells_style)
  }
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
  prop_style <- paste0("border_", side, "_style")
  prop_width <- paste0("border_", side, "_width")
  prop_color <- paste0("border_", side, "_color")
  for (r in rows) {
    for (c in cols) {
      cells_style[[r, c]] <- .force_border_triple(
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

.stamp_body_rows_force <- function(cells_style, visible_idx, triple) {
  nrow_data <- nrow(cells_style)
  if (nrow_data < 2L) {
    return(cells_style)
  }
  for (r in seq(2L, nrow_data)) {
    for (c in visible_idx) {
      cells_style[[r, c]] <- .force_border_triple(
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

.stamp_body_cols_force <- function(cells_style, visible_idx, triple) {
  ncol_visible <- length(visible_idx)
  if (ncol_visible < 2L) {
    return(cells_style)
  }
  nrow_data <- nrow(cells_style)
  for (r in seq_len(nrow_data)) {
    for (c in visible_idx[-1L]) {
      cells_style[[r, c]] <- .force_border_triple(
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

# Read the first non-NA @padding scalar from any cell in a
# cells_style matrix. Returns NA_real_ when no override is set
# anywhere. Shared across backends that need a scalar table-wide
# padding (LaTeX's `rowsep=Xpt`, RTF's `\trgaph<twips>`, DOCX's
# `<w:tcMar>`). The lowered `preset(padding = list(body = N))` knob
# stamps the same value on every body cell, so any non-NA cell is
# canonical; the scan skips synthetic group-header / blank rows
# whose injected style_nodes carry the default NA padding.
.first_cell_padding <- function(cells_style) {
  if (!is.matrix(cells_style) || length(cells_style) == 0L) {
    return(NA_real_)
  }
  for (i in seq_len(nrow(cells_style))) {
    for (j in seq_len(ncol(cells_style))) {
      node <- cells_style[[i, j]]
      if (!is_style_node(node)) {
        next
      }
      pad <- node@padding
      if (length(pad) == 1L && !is.na(pad)) {
        return(as.numeric(pad))
      }
    }
  }
  NA_real_
}

# Read the first non-NA @color scalar from any cell in a cells_style
# matrix, falling back to NA_character_ when no override is set.
# Shared across backends that emit a table-wide text colour from a
# per-cell stamp (e.g. RTF's `\cf<idx>` body token). Same scan
# rationale as `.first_cell_padding()`.
.first_cell_color <- function(cells_style) {
  if (!is.matrix(cells_style) || length(cells_style) == 0L) {
    return(NA_character_)
  }
  for (i in seq_len(nrow(cells_style))) {
    for (j in seq_len(ncol(cells_style))) {
      node <- cells_style[[i, j]]
      if (!is_style_node(node)) {
        next
      }
      col <- node@color
      if (length(col) == 1L && !is.na(col) && nzchar(col)) {
        return(as.character(col))
      }
    }
  }
  NA_character_
}

# Set a style_node's per-side border scalars unconditionally. Used
# by the force-stamp helpers above; every non-NA / non-NULL field in
# `triple` writes through to the matching `border_<side>_*` scalar.
.force_border_triple <- function(
  node,
  prop_style,
  prop_width,
  prop_color,
  triple
) {
  if (!is_style_node(node)) {
    node <- style_node()
  }
  args <- list(node)
  if (!is.null(triple$style) && !is.na(triple$style)) {
    args[[prop_style]] <- triple$style
  }
  if (!is.null(triple$width) && !is.na(triple$width)) {
    args[[prop_width]] <- triple$width
  }
  if (!is.null(triple$color) && !is.na(triple$color)) {
    args[[prop_color]] <- triple$color
  }
  do.call(S7::set_props, args)
}

# Pull the per-side border triple off a style_node. Returns NULL if
# all three scalars are NA (= no override for this side).
.style_node_border_triple <- function(node, side) {
  sty <- S7::prop(node, paste0("border_", side, "_style"))
  wid <- S7::prop(node, paste0("border_", side, "_width"))
  col <- S7::prop(node, paste0("border_", side, "_color"))
  if (
    (length(sty) == 0L || is.na(sty)) &&
      (length(wid) == 0L || is.na(wid)) &&
      (length(col) == 0L || is.na(col))
  ) {
    return(NULL)
  }
  list(
    style = if (length(sty) > 0L) sty else NA_character_,
    width = if (length(wid) > 0L) wid else NA_real_,
    color = if (length(col) > 0L) col else NA_character_
  )
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Build the chrome_style sidecar from a spec's effective preset.
# Pure function. Populates `chrome_style$borders` with the resolved
# triples for the chrome region keys; `chrome_style$surfaces` stays
# at its default no-op style_nodes (Phase 2 reserved).
#
# Backends consume the sidecar in place of their previously
# hardcoded chrome-rule emissions (`\hline` in LaTeX, `\trowd
# \brdrb` in RTF, `<hr>` in HTML, `<w:tcBorders>` in DOCX). A NULL
# value at a chrome key means "use the backend's built-in default
# rule"; the explicit-clear sentinel (style = "none") suppresses the
# default.
engine_chrome_borders <- function(spec) {
  cs <- chrome_style()

  # Walk session preset -> spec preset -> per-spec layers. For each
  # layer whose location targets a chrome surface, write its text
  # properties onto chrome_style$surfaces[<surface>] (merge with
  # later layers winning per attribute) and its border triple onto
  # the matching chrome border region.
  #
  # `preset(borders = list(<chrome region> = ...))` and
  # `preset(alignment = list(...))` / `colors = ...` / etc. flow
  # through this cascade via `.preset_args_to_layers()` in
  # `R/preset.R` — the lowering happens at `preset()` /
  # `set_preset()` call time so `preset@style` carries the layers.
  for (layer in .collect_chrome_layers(spec)) {
    cs <- .apply_chrome_layer(layer = layer, cs = cs)
  }
  cs
}

# Collect every layer in the four-tier cascade whose location is a
# chrome surface (anything mapping to a chrome_style surface key).
# Order: session preset -> spec preset -> per-spec layers.
.collect_chrome_layers <- function(spec) {
  sources <- list()
  session <- get_preset()
  if (is_preset_spec(session)) {
    sources <- c(sources, session@style)
  }
  if (is_preset_spec(spec@preset)) {
    sources <- c(sources, spec@preset@style)
  }
  if (is_style_spec(spec@styles)) {
    sources <- c(sources, spec@styles@layers)
  }
  chrome_surfaces <- names(.location_to_chrome_surface)
  matches <- vapply(
    sources,
    function(layer) {
      loc <- layer@location
      !is.null(loc) && loc$surface %in% chrome_surfaces
    },
    logical(1L)
  )
  sources[matches]
}

# Apply one chrome-surface layer to a chrome_style sidecar:
#   * text/alignment properties merge into chrome_style$surfaces[<key>]
#     via .merge_style_node (later layers win per attribute).
#   * border properties (border_top / border_bottom) flow into
#     chrome_style$borders[<region>] using the per-surface
#     region-mapping below.
.apply_chrome_layer <- function(layer, cs) {
  loc <- layer@location
  surface_key <- .location_to_chrome_surface[[loc$surface]]
  node <- layer@style

  # Merge the layer's text/alignment properties onto the surface
  # node. Reuse engine_style's merge contract — non-NA overrides.
  existing <- cs$surfaces[[surface_key]]
  if (!is_style_node(existing)) {
    existing <- style_node()
  }
  cs$surfaces[[surface_key]] <- .merge_style_node(existing, node)

  # Border properties → chrome border regions. Each chrome surface
  # has a top-edge region, a bottom-edge region (or neither for
  # pagehead/pagefoot which only own one edge each):
  region_map <- switch(
    loc$surface,
    pagehead = list(bottom = "pagehead_bottom"),
    title = list(),
    headers = list(
      top = "header_top",
      bottom = "header_bottom",
      between = "header_between"
    ),
    subgroup_labels = list(
      top = "subgroup_top",
      bottom = "subgroup_bottom"
    ),
    footnotes = list(
      top = "footer_top",
      bottom = "footer_bottom"
    ),
    pagefoot = list(top = "pagefoot_top"),
    list()
  )
  for (border_side in names(region_map)) {
    if (border_side == "between") {
      # header_between is fed by the umbrella `border` value if
      # neither top nor bottom carries a specific between-rule.
      triple <- .style_node_border_triple(node, "top")
    } else {
      triple <- .style_node_border_triple(node, border_side)
    }
    region <- region_map[[border_side]]
    if (!is.null(triple)) {
      cs$borders[[region]] <- triple
    }
  }
  cs
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
