# engine_style.R — resolve-engine phase that materialises the
# style cascade on spec into a per-cell style matrix.
#
# Output: a list-matrix with nrow(spec@data) rows and ncol(spec@data)
# columns, each cell holding one style_node. Cells with no matched
# layer carry the default (all-NA) style_node. Backends index this
# matrix by (row, col) when rendering body cells.
#
# Cascade ordering (low -> high priority):
#   1. Session preset's @style layers   — set via `set_preset(style = ...)`
#   2. Spec preset's @style layers      — set via `preset(spec, style = ...)`
#   3. Per-spec @styles@layers          — set via `spec |> style(...)`
#
# Layers are applied in source-order within each tier; within one
# style_node merge a non-NA field on the incoming style overrides
# the existing field, an NA field leaves it intact. Later layers
# (higher tiers, or later index within a tier) win per attribute.

#' Resolve the style cascade to a per-cell style matrix
#'
#' Pure function. Called by the resolve engine after `engine_sort()`
#' so predicates see the final row order. Returns a list-matrix
#' aligned with `spec@data`: `[i, j]` holds the resolved
#' `style_node` for the cell at row `i`, column `j`.
#'
#' @param spec A `tabular_spec`.
#' @return A list-matrix of `style_node` objects with `nrow(spec@data)`
#'   rows and `ncol(spec@data)` columns. Column names are preserved.
#'   Empty cells carry the default `style_node()`.
#' @keywords internal
#' @noRd
engine_style <- function(spec) {
  data <- spec@data
  nrow_data <- nrow(data)
  ncol_data <- ncol(data)
  col_names <- names(data)

  grid <- .empty_style_grid(nrow_data, ncol_data, col_names)

  call <- rlang::caller_env()

  session_preset <- get_preset()
  if (is_preset_spec(session_preset) && length(session_preset@style) > 0L) {
    for (layer in session_preset@style) {
      grid <- .apply_style_layer(
        layer = layer,
        grid = grid,
        data = data,
        col_names = col_names,
        call = call
      )
    }
  }

  spec_preset <- spec@preset
  if (is_preset_spec(spec_preset) && length(spec_preset@style) > 0L) {
    for (layer in spec_preset@style) {
      grid <- .apply_style_layer(
        layer = layer,
        grid = grid,
        data = data,
        col_names = col_names,
        call = call
      )
    }
  }

  styles <- spec@styles
  if (!is_style_spec(styles)) {
    return(grid)
  }

  for (layer in styles@layers) {
    grid <- .apply_style_layer(
      layer = layer,
      grid = grid,
      data = data,
      col_names = col_names,
      call = call
    )
  }
  grid
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Build the empty nrow x ncol list-matrix of default style_nodes.
.empty_style_grid <- function(nrow_data, ncol_data, col_names) {
  default <- style_node()
  cells <- rep(list(default), nrow_data * ncol_data)
  dim(cells) <- c(nrow_data, ncol_data)
  colnames(cells) <- col_names
  cells
}

# Apply one style_layer to the grid. Only body-surface layers
# affect the per-cell style matrix; layers with any other surface
# (headers, footnotes, table-edges, etc.) are routed by other
# engines and are silently ignored here.
.apply_style_layer <- function(layer, grid, data, col_names, call) {
  loc <- layer@location
  if (!identical(loc$surface, "body")) {
    return(grid)
  }
  target_rows <- .resolve_layer_rows(loc, data, col_names, call = call)
  if (length(target_rows) == 0L) {
    return(grid)
  }
  target_cols <- .resolve_layer_cols(loc, col_names, call = call)
  # The layer's override list is identical for every stamped cell, so
  # extract it ONCE and re-apply, instead of re-walking the incoming
  # node's fields per cell (.merge_style_node would redo that O(rows
  # x cols) times). Merged results repeat too (most cells still hold
  # the shared default node), so memoise by existing-node identity.
  overrides <- .style_node_overrides(layer@style)
  merged_default <- NULL
  for (r in target_rows) {
    for (c in target_cols) {
      existing <- grid[[r, c]]
      grid[[r, c]] <- if (.style_node_is_default(existing)) {
        merged_default <- merged_default %||%
          do.call(S7::set_props, c(list(existing), overrides))
        merged_default
      } else {
        do.call(S7::set_props, c(list(existing), overrides))
      }
    }
  }
  grid
}

# Resolve a location's row filters (`i` and/or `where`) to a set of
# row indices into `data`. Returns `seq_len(nrow(data))` when no
# filter is set.
.resolve_layer_rows <- function(loc, data, col_names, call) {
  if (!is.null(loc$where)) {
    result <- .eval_style_where(loc$where, data, call = call)
    if (!is.logical(result)) {
      cli::cli_abort(
        c(
          "{.fn cells_body} {.arg where} must evaluate to a logical vector.",
          "x" = "Got {.obj_type_friendly {result}} of length {length(result)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    if (length(result) == 1L && nrow(data) > 1L) {
      result <- rep(result, nrow(data))
    }
    if (length(result) != nrow(data)) {
      cli::cli_abort(
        c(
          "{.fn cells_body} {.arg where} returned length {length(result)}, expected {nrow(data)}.",
          "i" = "The expression must evaluate to a length-{.code nrow} logical vector (or length 1)."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(which(result & !is.na(result)))
  }
  i <- loc$i
  if (is.null(i)) {
    return(seq_len(nrow(data)))
  }
  if (is.logical(i)) {
    if (length(i) == 1L) {
      i <- rep(i, nrow(data))
    }
    if (length(i) != nrow(data)) {
      cli::cli_abort(
        "Logical {.arg i} must be length 1 or {.code nrow(data)} ({nrow(data)}).",
        class = "tabular_error_input",
        call = call
      )
    }
    return(which(i))
  }
  if (is.numeric(i)) {
    if (any(i > nrow(data))) {
      cli::cli_abort(
        c(
          "{.arg i} out of bounds.",
          "x" = "Row {.val {as.integer(i[i > nrow(data)])}} exceeds nrow(data) = {nrow(data)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(as.integer(i))
  }
  # Character — match against row names if any (uncommon for clinical
  # tables) or warn and fall back to every row. For now, every row.
  cli::cli_warn(
    "Character row indices on {.fn cells_body} are not yet supported; applying to every row.",
    class = "tabular_warning_input",
    call = call
  )
  seq_len(nrow(data))
}

# Resolve a location's column filter (`j`) to column indices. Returns
# every column when no filter is set.
.resolve_layer_cols <- function(loc, col_names, call) {
  j <- loc$j
  if (is.null(j)) {
    return(seq_along(col_names))
  }
  if (is.character(j)) {
    matched <- match(j, col_names)
    if (anyNA(matched)) {
      missing <- j[is.na(matched)]
      cli::cli_abort(
        c(
          "Unknown column{?s} in {.arg j}: {.val {missing}}.",
          "i" = "Available: {.val {col_names}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(matched)
  }
  if (is.numeric(j)) {
    if (any(j > length(col_names))) {
      cli::cli_abort(
        c(
          "{.arg j} out of bounds.",
          "x" = "Column {.val {as.integer(j[j > length(col_names)])}} exceeds ncol(data) = {length(col_names)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(as.integer(j))
  }
  seq_along(col_names)
}

# Evaluate the `where` quosure against the data mask. Errors are
# rewrapped as tabular_error_input so the verb's class contract
# holds end-to-end.
.eval_style_where <- function(quo, data, call) {
  # Wrap in a tidyverse data mask so users can write `.data$col` and
  # `.env$var` pronouns (dplyr-style); bare column references continue
  # to work because the mask is permissive about implicit lookup.
  # Missing columns produce a clear "Column `xxx` not found in `.data`"
  # error courtesy of the rlang mask machinery.
  mask <- rlang::as_data_mask(as.list(data))
  tryCatch(
    rlang::eval_tidy(quo, data = mask),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to evaluate {.fn style} {.arg where}.",
          "x" = "Underlying error: {conditionMessage(e)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  )
}

# Merge `incoming` into `existing` field-by-field. A non-NA value on
# the incoming style_node overrides; NA / length-0 leaves the
# existing field intact. Matches the col_spec merge contract.
#
# `.build_style_node` in R/style.R guarantees at least one non-
# default field on every incoming node (the verb errored if the user
# supplied no attributes), so the override list is always non-empty.
.merge_style_node <- function(existing, incoming) {
  do.call(
    S7::set_props,
    c(list(existing), .style_node_overrides(incoming))
  )
}

# Extract a style_node's non-default fields as a named list, ready for
# one set_props() call. Shared by the per-layer stamp loop (hoisted out
# of the per-cell path) and .merge_style_node.
.style_node_overrides <- function(incoming) {
  overrides <- list()
  for (f in .style_node_fields) {
    v <- S7::prop(incoming, f)
    if (.style_field_is_default(v)) {
      next
    }
    overrides[[f]] <- v
  }
  overrides
}

# TRUE when every field of the node is still at its default (the
# shared .empty_style_grid node, before any layer touched it).
.style_node_is_default <- function(node) {
  length(.style_node_overrides(node)) == 0L
}

# Detect "no override" state on a style_node field. Defaults across
# style_node properties are all some form of NA (or zero-length); a
# length-1 NA or length-0 vector means "leave the existing field
# alone" in the merge. A length-1 non-NA value or any length>=2 value
# is a real override.
.style_field_is_default <- function(v) {
  length(v) == 0L || (length(v) == 1L && is.na(v))
}
