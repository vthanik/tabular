# engine_style.R — resolve-engine phase that materialises the
# style cascade on spec into a per-cell style matrix. Step 10
# implements the predicate layer only (defaults / cols / headers
# layers will land with preset() and col_spec() integration).
#
# Output: a list-matrix with nrow(spec@data) rows and ncol(spec@data)
# columns, each cell holding one style_node. Cells with no matched
# predicate carry the default (all-NA) style_node. Backends index
# this matrix by (row, col) when rendering body cells.
#
# Cascade within the predicate layer: predicates are applied in
# declaration order; later predicates override earlier ones for
# overlapping cells. Within one style_node merge, a non-NA field on
# the incoming style overrides the existing field; an NA field
# leaves the existing field intact.

#' Resolve the style cascade to a per-cell style matrix
#'
#' Pure function. Called by the resolve engine after `engine_derive()`
#' so predicates can reference derived columns. Returns a list-matrix
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

  styles <- spec@styles
  if (!is_style_spec(styles)) {
    return(grid)
  }

  call <- rlang::caller_env()
  for (pred in styles@predicates) {
    grid <- .apply_style_predicate(
      pred = pred,
      grid = grid,
      data = data,
      col_names = col_names,
      call = call
    )
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

# Apply one style_predicate to the grid. Scope-specific logic:
# *   "row"  -> all cells in matching rows
# *   "cell" -> cells in `all.vars(where)` ∩ data cols at matching
#              rows; falls back to all cols if no data col referenced
# *   "col"  -> raises tabular_error_input (post-v0.1.0)
.apply_style_predicate <- function(pred, grid, data, col_names, call) {
  scope <- pred@scope

  if (scope == "col") {
    cli::cli_abort(
      c(
        '{.code .scope = "col"} is not implemented in this release.',
        "i" = 'Use {.code .scope = "row"} or {.code .scope = "cell"} for now.'
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  result <- .eval_style_where(pred@where, data, call = call)
  if (!is.logical(result)) {
    cli::cli_abort(
      c(
        "{.fn style} {.arg where} must evaluate to a logical vector.",
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
        "{.fn style} {.arg where} returned length {length(result)}, expected {nrow(data)}.",
        "i" = "The expression must evaluate to a length-{.code nrow} logical vector (or length 1, which recycles)."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  target_rows <- which(result & !is.na(result))
  if (length(target_rows) == 0L) {
    return(grid)
  }

  if (scope == "row") {
    target_cols <- seq_along(col_names)
  } else {
    refs <- .referenced_symbols(pred@where)
    matched <- intersect(refs, col_names)
    target_cols <- if (length(matched) == 0L) {
      seq_along(col_names)
    } else {
      match(matched, col_names)
    }
  }

  incoming <- pred@style
  for (r in target_rows) {
    for (c in target_cols) {
      grid[[r, c]] <- .merge_style_node(grid[[r, c]], incoming)
    }
  }
  grid
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
  incoming <- layer@style
  for (r in target_rows) {
    for (c in target_cols) {
      grid[[r, c]] <- .merge_style_node(grid[[r, c]], incoming)
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
    "Character row indices on {.fn cells_body} are not yet supported; applying to every row."
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
# holds end-to-end (same approach as engine_derive's eval helper).
.eval_style_where <- function(quo, data, call) {
  mask <- as.list(data)
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
  overrides <- list()
  for (f in .style_node_fields) {
    v <- S7::prop(incoming, f)
    if (.style_field_is_default(v)) {
      next
    }
    overrides[[f]] <- v
  }
  do.call(S7::set_props, c(list(existing), overrides))
}

# Detect "no override" state on a style_node field. Defaults across
# style_node properties are all some form of NA (or zero-length); a
# length-1 NA or length-0 vector means "leave the existing field
# alone" in the merge. A length-1 non-NA value or any length>=2 value
# is a real override.
.style_field_is_default <- function(v) {
  length(v) == 0L || (length(v) == 1L && is.na(v))
}
