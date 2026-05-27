# util_runs.R — vector run-grouping primitive shared by every
# backend's header-band renderer (and any future renderer that
# needs to collapse contiguous equal values into colspan-style
# runs). Defined once here so the five backends never drift.

# Group a vector into runs of consecutive equal values, treating
# NA-as-equal-to-NA. Returns a list of `{value, length}` records
# in left-to-right order. Backends consume the records to compute
# colspan / `\SetCell[c=N]` / `<w:gridSpan>` / `\cellx` widths.
#
# Empty input -> empty list. Single-element input -> one record
# of length 1. Boundary changes detected by mixed-NA awareness
# (two NAs in a row collapse into one run; an NA next to a real
# value starts a new run).
#
# @keywords internal
# @noRd
.group_contiguous_runs <- function(x) {
  n <- length(x)
  if (n == 0L) {
    return(list())
  }
  runs <- list()
  start <- 1L
  for (i in seq_len(n)[-1L]) {
    cur <- x[[i]]
    prev <- x[[i - 1L]]
    same <- (is.na(cur) && is.na(prev)) ||
      (!is.na(cur) && !is.na(prev) && identical(cur, prev))
    if (!same) {
      runs[[length(runs) + 1L]] <- list(
        value = x[[start]],
        length = i - start
      )
      start <- i
    }
  }
  runs[[length(runs) + 1L]] <- list(
    value = x[[start]],
    length = n - start + 1L
  )
  runs
}
