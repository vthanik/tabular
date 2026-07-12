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
.body_border_manifest <- function(spec) {
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
  # The booktabs baseline is injected first (lowest precedence) so a
  # table with no `rules` knob still gets the clinical default rules;
  # session / preset / per-spec layers override via later position.
  sources <- .default_rule_layers()
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
  # Outer LEFT / RIGHT edges are NOT stamped per-cell. They are drawn
  # structurally by each backend from `.body_border_manifest()` (which
  # reads the same cascade, so it already carries the resolved triple):
  # HTML as a table-level `border-left/right`, RTF as `\trbrdrl/r` on
  # every table-proper `\trowd`, DOCX as `<w:left>/<w:right>` on the
  # first / last cell of every row, LaTeX as `vline{}`. A per-cell stamp
  # only reaches body DATA rows, so the synthesised spanner-band /
  # blank-separator / group-header rows would gap the vertical edge (the
  # original `rules = "frame"` defect). Outer TOP is ALSO structural: the
  # table top is the column-header band's top rule (above the body), which a
  # per-cell body stamp cannot reach, so each backend draws it from the
  # manifest at the header-band top (HTML `thead tr:first-child th`, LaTeX
  # `hline{1}`, RTF / DOCX topmost header row). Only outer BOTTOM stays
  # per-cell: the last body row's bottom IS the table bottom, so the stamp
  # coincides with the chrome bottomrule and one line renders.
  if (is.null(side) || identical(side, "outer")) {
    triple <- .style_node_border_triple(node, "bottom")
    if (!is.null(triple)) {
      cells_style <- .stamp_outer_edge_force(
        cells_style,
        visible_idx = visible_idx,
        side = "bottom",
        triple = triple
      )
    }
    return(cells_style)
  }
  if (side %in% c("outer_left", "outer_right", "outer_top")) {
    # Structural-only (see comment above); the manifest carries it.
    return(cells_style)
  }
  if (identical(side, "outer_bottom")) {
    triple <- .style_node_border_triple(node, "bottom")
    if (!is.null(triple)) {
      cells_style <- .stamp_outer_edge_force(
        cells_style,
        visible_idx = visible_idx,
        side = "bottom",
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
  # Only TOP / BOTTOM are stamped per-cell now (LEFT / RIGHT are drawn
  # structurally from the manifest, see .apply_table_layer): top -> the
  # first row, bottom -> the last row, across every visible body column.
  rows <- if (side == "top") 1L else nrow_data
  cols <- visible_idx
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

# Read the first cell carrying any non-NA per-side padding from a
# cells_style matrix; returns a named c(top, right, bottom, left)
# (NA where unset), or all-NA when no override exists anywhere. The
# lowered `preset(padding = list(body = ...))` knob stamps the same
# per-side values on every body cell, so the first non-default cell is
# canonical; the scan skips synthetic group-header / blank rows whose
# injected style_nodes carry default NA padding.
.first_cell_padding_sides <- function(cells_style) {
  out <- c(
    top = NA_real_,
    right = NA_real_,
    bottom = NA_real_,
    left = NA_real_
  )
  if (!is.matrix(cells_style) || length(cells_style) == 0L) {
    return(out)
  }
  for (i in seq_len(nrow(cells_style))) {
    for (j in seq_len(ncol(cells_style))) {
      node <- cells_style[[i, j]]
      if (!is_style_node(node)) {
        next
      }
      sides <- vapply(
        c("top", "right", "bottom", "left"),
        function(s) {
          v <- S7::prop(node, paste0("padding_", s))
          if (length(v) == 1L) as.numeric(v) else NA_real_
        },
        numeric(1L)
      )
      if (!all(is.na(sides))) {
        return(sides)
      }
    }
  }
  out
}

# Scalar table-wide padding shim used by backends that take a single
# representative value (RTF `\trgaph`, DOCX `<w:tcMar>` horizontal,
# LaTeX `tabcolsep`). Returns the first cell's horizontal (left)
# padding override, NA when none is set.
.first_cell_padding <- function(cells_style) {
  unname(.first_cell_padding_sides(cells_style)[["left"]])
}

# Read the table-wide body text colour from a cells_style matrix, for
# backends that emit it as one token (e.g. RTF's `\cf<idx>` body token).
# Returns the colour SHARED by more than one cell (the uniform colour
# stamped by the lowered `preset(colors = list(body = ...))` knob), or
# NA when no such shared colour exists. A lone per-cell `style(color =)`
# override must NOT become the table-wide default: it is rendered
# per-cell by `.rtf_cell_text_props()`, so promoting it would wrongly
# recolour every other (uncoloured) cell.
.first_cell_color <- function(cells_style) {
  if (!is.matrix(cells_style) || length(cells_style) == 0L) {
    return(NA_character_)
  }
  seen <- character(0L)
  for (i in seq_len(nrow(cells_style))) {
    for (j in seq_len(ncol(cells_style))) {
      node <- cells_style[[i, j]]
      if (!is_style_node(node)) {
        next
      }
      col <- node@color
      if (length(col) == 1L && !is.na(col) && nzchar(col)) {
        seen <- c(seen, as.character(col))
      }
    }
  }
  if (length(seen) == 0L) {
    return(NA_character_)
  }
  counts <- table(seen)
  if (max(counts) > 1L) names(counts)[which.max(counts)] else NA_character_
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
  # Inject the booktabs baseline first (lowest precedence) for the
  # chrome rules (toprule / midrule / spanrule / footnoterule); later
  # cascade sources override.
  sources <- .default_rule_layers()
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

  # Explicit chrome-region target (set by `.preset_rules_to_layers()`):
  # write the triple straight to the named region, bypassing the
  # border-side heuristic that otherwise conflates header_top and
  # header_between. The triple may carry style = "none" (clear), which
  # overrides the injected booktabs default for that region.
  if (!is.null(loc$chrome_region)) {
    triple <- .style_node_border_triple(node, "top")
    if (is.null(triple)) {
      triple <- .style_node_border_triple(node, "bottom")
    }
    if (!is.null(triple)) {
      cs$borders[[loc$chrome_region]] <- triple
    }
    return(cs)
  }

  # Merge the layer's text/alignment properties onto the surface node.
  # Reuse engine_style's merge contract — non-NA overrides. The page
  # bands are slot-keyed: a layer with `loc$slot` targets that one slot;
  # `loc$slot = NULL` (`cells_pagehead()` with no slot) broadcasts to all
  # three. Other surfaces are a single flat node.
  if (surface_key %in% c("pagehead", "pagefoot")) {
    slots <- if (is.null(loc$slot)) .location_band_slots else loc$slot
    for (s in slots) {
      existing <- cs$surfaces[[surface_key]][[s]]
      if (!is_style_node(existing)) {
        existing <- style_node()
      }
      cs$surfaces[[surface_key]][[s]] <- .merge_style_node(existing, node)
    }
  } else {
    existing <- cs$surfaces[[surface_key]]
    if (!is_style_node(existing)) {
      existing <- style_node()
    }
    cs$surfaces[[surface_key]] <- .merge_style_node(existing, node)
  }

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

# Visible column indices on `cells_style` -- preserves the order in
# which they appear in `col_names`. Hidden cols are skipped so
# `body_cols` doesn't stamp a vertical separator on, e.g., a
# `visible = FALSE` sort-key helper.
.visible_col_indices <- function(spec, col_names) {
  # Finalize the NA "unset" visible sentinel so visibility reads are
  # correct even when this phase is exercised on a raw spec (the production
  # path finalizes upstream; this keeps the read self-sufficient). Idempotent.
  cols <- .finalize_col_specs(spec@cols)
  # section grouping keys are pulled OUT of the body into synthesised
  # section-header rows by engine_group_display(), and "none" keys are
  # break-only; since engine_borders runs BEFORE that drop, their
  # per-cell border stamps would land on a column that never renders.
  # Exclude them so outer_left / cols / outer_right target the
  # first/last true BODY column. (LaTeX is unaffected: it reads the
  # per-side triple via .body_border_manifest(), not these stamps.)
  hidden_keys <- .row_group_hidden_keys(spec@row_groups)
  vis <- vapply(
    col_names,
    function(nm) {
      if (nm %in% hidden_keys) {
        return(FALSE)
      }
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
