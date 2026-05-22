# engine_sort.R — one of the resolve-engine phases. Applies a
# `sort_spec` (if any) to `spec@data` and returns the spec with the
# data slot reordered. NA-last regardless of direction; factors
# sort by level via xtfrm; descending inverts the xtfrm key so a
# single `order()` call handles mixed directions.

#' Apply the sort spec to spec@data
#'
#' Pure function. Called by the resolve engine before pagination.
#' Returns the spec unchanged when the sort is empty (no spec set,
#' or `by = character()`); otherwise returns the spec with
#' `@data` reordered.
#'
#' Per-key direction is handled by inverting the xtfrm rank of any
#' descending key, then calling `order()` once on all keys with
#' `na.last = TRUE`. This survives factor columns (xtfrm gives the
#' level rank), Date columns (xtfrm gives the day count), and any
#' other class with an xtfrm method.
#'
#' @param spec A `tabular_spec`.
#' @return The spec with `@data` reordered, or unchanged if no sort
#'   is configured.
#' @keywords internal
#' @noRd
engine_sort <- function(spec) {
  s <- spec@sort
  if (!is_sort_spec(s) || length(s@by) == 0L) {
    return(spec)
  }

  data <- spec@data
  if (nrow(data) == 0L) {
    return(spec)
  }

  by <- s@by
  desc <- s@descending
  keys <- vector("list", length(by))
  for (i in seq_along(by)) {
    col <- data[[by[[i]]]]
    rank <- xtfrm(col)
    if (isTRUE(desc[[i]])) {
      keys[[i]] <- -rank
    } else {
      keys[[i]] <- rank
    }
  }
  ord <- do.call(order, c(keys, list(na.last = TRUE)))
  S7::set_props(spec, data = data[ord, , drop = FALSE])
}
