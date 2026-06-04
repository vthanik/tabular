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
# header tree yields an empty data.frame with the same schema — no
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
  # Columns that actually render. A band whose two visible leaves are
  # separated only by a hidden (visible = FALSE / header_row) column is
  # contiguous on the page, so the contiguity check below tolerates a
  # hidden intruder and rejects only a VISIBLE column splitting a band.
  visible_cols <- col_order[.visible_col_indices(spec, col_order)]

  bands <- do.call(
    rbind,
    lapply(spec@headers, function(node) {
      .flatten_header_node(
        node,
        depth = 1L,
        col_order = col_order,
        visible_cols = visible_cols,
        call = call
      )
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
.flatten_header_node <- function(node, depth, col_order, visible_cols, call) {
  spans <- .collect_header_spans(node)
  # The verb (R/headers.R) has already validated every name is in
  # data, so `match()` cannot return NA here.
  positions <- sort(match(spans, col_order))
  col_start <- positions[1L]
  col_end <- positions[length(positions)]
  if (!identical(positions, seq(col_start, col_end))) {
    intruders <- setdiff(seq(col_start, col_end), positions)
    intruder_names <- col_order[intruders]
    # A hidden column between two visible leaves does not split the band
    # on the rendered page (backends place bands by visible column name),
    # so only a VISIBLE intruder is a genuine non-contiguity error.
    visible_intruders <- intruder_names[intruder_names %in% visible_cols]
    if (length(visible_intruders) > 0L) {
      cli::cli_abort(
        c(
          "{.fn headers} band {.val {node@label}} spans non-contiguous columns.",
          "x" = "{length(visible_intruders)} intruder column{?s} between its leaves: {.val {visible_intruders}}.",
          "i" = "Reorder data columns upstream, or place the intruder under the same band."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
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
        visible_cols = visible_cols,
        call = call
      )
    })
  )
  rbind(this_row, child_rows)
}

# Build the per-visible-column band-label vector for one depth.
# Returns `character(length(col_names_visible))` with `NA_character_`
# over columns not under any band at this depth. Replaces the
# nested-vapply duplicate that every backend renderer used to carry.
#
# Complexity: O(total_spans + visible_cols). Columns inside a span
# but absent from `col_names_visible` (i.e. hidden) silently drop;
# the band renders over its visible subset only.
#
# @keywords internal
# @noRd
.band_labels_for_depth <- function(headers, depth, col_names_visible) {
  band_at_depth <- headers[headers$depth == depth, , drop = FALSE]
  if (nrow(band_at_depth) == 0L) {
    return(rep(NA_character_, length(col_names_visible)))
  }
  lookup <- stats::setNames(
    rep(NA_character_, length(col_names_visible)),
    col_names_visible
  )
  for (i in seq_len(nrow(band_at_depth))) {
    spans <- band_at_depth$span_cols[[i]]
    visible_spans <- intersect(spans, col_names_visible)
    lookup[visible_spans] <- band_at_depth$label[[i]]
  }
  unname(lookup)
}

# Map per-subgroup BigN records onto the visible column order for the
# continuous-backend N row (the per-arm `(N=x)` under a subgroup
# banner). Parallels `.band_labels_for_depth`: returns two aligned
# vectors of length `length(col_names_visible)` -- a `key` (the target
# name over each covered column, `NA` elsewhere) and a `text` (the
# `(N=x)` string over each covered column, "" elsewhere).
#
# Keying on the target NAME, not the rendered text, is deliberate: two
# arms with an equal N (e.g. adjacent `(N=9)` columns) keep distinct
# keys, so the backend's run-grouping never coalesces them into one
# `colspan=2` cell. A band target's N rides every visible leaf under
# that band -- HTML colspans the contiguous run, md repeats it across
# the columns (matching `.band_labels_for_depth`'s band repeat).
#
# `headers` is the base (un-suffixed) band frame from `engine_headers`;
# `span_cols` carries data-column NAMES (suffix-independent) and the
# record's `name` is the original band label, so the match holds
# regardless of any per-page `(N=x)` suffix.
#
# @keywords internal
# @noRd
.subgroup_bign_spans <- function(records, headers, col_names_visible) {
  n <- length(col_names_visible)
  key <- rep(NA_character_, n)
  text <- rep("", n)
  for (rec in records) {
    if (identical(rec$kind, "leaf")) {
      pos <- match(rec$name, col_names_visible)
      if (!is.na(pos)) {
        key[[pos]] <- rec$name
        text[[pos]] <- rec$text
      }
    } else if (identical(rec$kind, "band")) {
      hit <- which(headers$label == rec$name)
      if (length(hit) == 0L) {
        next
      }
      spans <- headers$span_cols[[hit[[1L]]]]
      pos <- match(intersect(spans, col_names_visible), col_names_visible)
      pos <- pos[!is.na(pos)]
      key[pos] <- rec$name
      text[pos] <- rec$text
    }
  }
  list(key = key, text = text)
}

# Empty header-grid skeleton — matches the populated frame's schema
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
