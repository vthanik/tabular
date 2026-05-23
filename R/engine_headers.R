# engine_headers.R — resolve-engine phase that flattens the header
# tree on spec@headers into a band-grid the backends can render. The
# verb (R/headers.R) has already validated existence and uniqueness
# of every spanned column; the engine adds the contiguity check
# (header spans must map to a contiguous range of data columns) and
# computes per-node (col_start, col_end) positions.
#
# Returns a data.frame of header cells, one row per (header_node,
# depth) pair, sorted by depth then col_start. Each row carries:
#
#   depth      1L for outermost band, increasing for nested levels
#   label      the band's display text
#   col_start  1-indexed leftmost data column the band covers
#   col_end    1-indexed rightmost data column the band covers
#   leaf       TRUE iff the node has no children (touches data row)
#   span_cols  the spanned data-column names (list-column)
#
# Backends iterate this frame by depth ascending to draw band rows;
# each row of cells is positioned by (col_start, col_end). An empty
# header tree yields an empty data.frame with the same schema -- no
# header band rendered.

#' Flatten the header tree into a band-grid data.frame
#'
#' Pure function. Called by the resolve engine before backend emit.
#' Returns a data.frame whose rows are the header cells the backend
#' will render, ordered top-down (smallest depth first) and
#' left-to-right within each depth.
#'
#' @param spec A `tabular_spec`.
#' @return A data.frame with columns `depth`, `label`, `col_start`,
#'   `col_end`, `leaf`, `span_cols`. Empty data.frame with the
#'   correct schema when no headers are configured.
#' @keywords internal
#' @noRd
engine_headers <- function(spec) {
  if (length(spec@headers) == 0L) {
    return(.empty_header_grid())
  }

  call <- rlang::caller_env()
  col_order <- names(spec@data)

  bands <- do.call(
    rbind,
    lapply(spec@headers, function(node) {
      .flatten_header_node(node, depth = 1L, col_order = col_order, call = call)
    })
  )

  bands <- bands[order(bands$depth, bands$col_start), , drop = FALSE]
  row.names(bands) <- NULL
  bands
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Recursive flatten. For each node:
# 1. Compute its column range from the leaves under it.
# 2. Require those leaves to be CONTIGUOUS in col_order; otherwise
#    abort with a clear message naming the offending band.
# 3. Emit one row for this node, then recurse into children at
#    depth + 1L.
.flatten_header_node <- function(node, depth, col_order, call) {
  spans <- .collect_header_spans(node)
  # The verb (R/headers.R) has already validated every name is in
  # data, so `match()` cannot return NA here.
  positions <- sort(match(spans, col_order))
  col_start <- positions[1L]
  col_end <- positions[length(positions)]
  if (!identical(positions, seq(col_start, col_end))) {
    intruders <- setdiff(seq(col_start, col_end), positions)
    intruder_names <- col_order[intruders]
    cli::cli_abort(
      c(
        "{.fn headers} band {.val {node@label}} spans non-contiguous columns.",
        "x" = "{length(intruder_names)} intruder column{?s} between its leaves: {.val {intruder_names}}.",
        "i" = "Reorder data columns upstream, or place the intruder under the same band."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  leaf <- length(node@children) == 0L
  this_row <- data.frame(
    depth = depth,
    label = node@label,
    col_start = col_start,
    col_end = col_end,
    leaf = leaf,
    stringsAsFactors = FALSE
  )
  this_row$span_cols <- I(list(spans))

  if (leaf) {
    return(this_row)
  }

  child_rows <- do.call(
    rbind,
    lapply(node@children, function(c) {
      .flatten_header_node(
        c,
        depth = depth + 1L,
        col_order = col_order,
        call = call
      )
    })
  )
  rbind(this_row, child_rows)
}

# Empty header-grid skeleton -- matches the populated frame's schema
# so backends can iterate uniformly when no header tree is set.
.empty_header_grid <- function() {
  out <- data.frame(
    depth = integer(),
    label = character(),
    col_start = integer(),
    col_end = integer(),
    leaf = logical(),
    stringsAsFactors = FALSE
  )
  out$span_cols <- I(list())
  out
}
