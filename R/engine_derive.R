# engine_derive.R — resolve-engine phase that materialises the
# `derive_spec` entries on a tabular_spec into new columns on
# spec@data. Pure function. Steps:
#
#   1. Topo-sort the derives by their inter-dependencies.
#   2. For each derive in order, validate references, then evaluate
#      the quosure against a data mask (columns by name + `.c` list).
#   3. Coerce the result to length nrow(data) (length-1 recycled),
#      append to data, advance the available-columns set so the next
#      derive can reference this one.
#
# Vectorised throughout — one eval call per derive, never a per-row
# loop. The "row-arithmetic" mental model in user docs is realised by
# the fact that R's recycling rules make per-column arithmetic
# equivalent to per-row arithmetic when every operand has the same
# length.

#' Apply spec@derives to spec@data
#'
#' Pure function. Called by the resolve engine after `engine_sort()`
#' (a derive can reference any data column, but sort ordering does
#' not affect arithmetic). Returns the spec with one new column per
#' derive_spec entry appended to `@data` in topological order.
#'
#' @param spec A `tabular_spec`.
#' @return The spec with `@data` widened by one column per derive,
#'   or unchanged if no derives are configured.
#' @keywords internal
#' @noRd
engine_derive <- function(spec) {
  derives <- spec@derives
  if (length(derives) == 0L) {
    return(spec)
  }

  call <- rlang::caller_env()
  data <- spec@data
  data_cols <- names(data)

  ord <- .topo_sort_derives(derives, data_cols, call = call)

  for (nm in ord) {
    d <- derives[[nm]]
    .validate_derive_refs(d, available = data_cols, call = call)
    val <- .eval_derive(d, data = data, call = call)
    val <- .coerce_derive_result(
      val,
      name = nm,
      nrow_data = nrow(data),
      call = call
    )
    data[[nm]] <- val
    data_cols <- names(data)
  }

  S7::set_props(spec, data = data)
}

# ---------------------------------------------------------------------
# Topological sort over derive dependencies (Kahn's algorithm)
# ---------------------------------------------------------------------

# Derives can reference earlier derives by name. Build the dependency
# graph (edges = "this derive references another derive"), then
# Kahn-sort. A cycle leaves nonzero in-degree on every node in the
# cycle when the queue empties — detect and abort.
.topo_sort_derives <- function(derives, data_cols, call) {
  names_set <- names(derives)
  if (length(names_set) <= 1L) {
    return(names_set)
  }

  deps <- lapply(derives, function(d) {
    refs <- .referenced_symbols(d@expr)
    intersect(refs, names_set)
  })
  names(deps) <- names_set

  in_deg <- vapply(deps, length, integer(1))
  out <- character()

  while (any(in_deg == 0L)) {
    ready <- names(in_deg)[in_deg == 0L]
    out <- c(out, ready)
    in_deg <- in_deg[setdiff(names(in_deg), ready)]
    for (nm in names(in_deg)) {
      deps[[nm]] <- setdiff(deps[[nm]], ready)
      in_deg[[nm]] <- length(deps[[nm]])
    }
  }

  if (length(in_deg) > 0L) {
    cyc <- names(in_deg)
    cli::cli_abort(
      c(
        "Circular dependency among {.fn derive} expressions.",
        "x" = "Cycle involves {length(cyc)} derive{?s}: {.val {cyc}}.",
        "i" = "Each expression must only reference data columns and previously-defined derives."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  out
}

# ---------------------------------------------------------------------
# Reference validation (pre-eval)
# ---------------------------------------------------------------------

# Walk the quosure's expression tree and surface bare symbols that
# look like aggregation references (`<col>.<stat>`) BEFORE we try to
# evaluate. R would otherwise raise "object 'x.mean' not found" --
# a friendlier error explains that tabular does not aggregate and
# points the user to upstream pre-summarisation.
#
# `available` is the union of data columns and prior-derive outputs.
# Names not in `available` and not the `.c` accessor get checked
# against a dotted-name heuristic; matched names get the aggregation
# hint, others get the generic unknown-reference error.
.validate_derive_refs <- function(d, available, call) {
  refs <- .referenced_symbols(d@expr)
  # `.c` is the special list-of-columns accessor; never flagged.
  unknown <- setdiff(refs, c(available, ".c"))
  # Symbols that look like function/operator names are silently ignored
  # here — they resolve via the quosure environment at eval time.
  # Only flag identifiers whose dotted suffix matches a known stat.
  stat_pattern <- "\\.(n|mean|sd|median|min|max|sum|q1|q3|pct|p)$"
  agg_like <- unknown[grepl(stat_pattern, unknown)]
  if (length(agg_like) > 0L) {
    cli::cli_abort(
      c(
        "{.fn derive} expression for {.val {d@name}} references {length(agg_like)} aggregation-style symbol{?s}: {.val {agg_like}}.",
        "x" = "tabular does not aggregate. {.code col.stat} synthesis is not supported.",
        "i" = "Pre-compute the statistic upstream (cards / dplyr / SAS) and pass it in as a column."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(NULL)
}

# Symbols referenced by a quosure or expression. all.vars() walks
# the language tree and returns identifier names (including
# backticked ones), skipping function-position names like `+`.
.referenced_symbols <- function(expr) {
  e <- if (rlang::is_quosure(expr)) rlang::quo_get_expr(expr) else expr
  all.vars(e)
}

# ---------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------

# Evaluate one derive against the current data mask. The mask is the
# named list of column vectors plus `.c` (same list, exposed as a
# whole so users can write `.c[[3]]` when arm names are unknown at
# write time). Any error during eval is rewrapped as
# `tabular_error_input` so the verb's class contract holds end-to-end.
.eval_derive <- function(d, data, call) {
  mask <- as.list(data)
  mask[[".c"]] <- as.list(data)
  tryCatch(
    rlang::eval_tidy(d@expr, data = mask),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to evaluate {.fn derive} expression for {.val {d@name}}.",
          "x" = "Underlying error: {conditionMessage(e)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  )
}

# Coerce the derive's eval result to a length-nrow vector. Length 1
# recycles; any other length is an error. Type is preserved as-is --
# numeric, character, factor, Date all pass through; downstream
# engine_format applies the col_spec.format to render to text.
.coerce_derive_result <- function(val, name, nrow_data, call) {
  if (is.null(val)) {
    cli::cli_abort(
      c(
        "{.fn derive} expression for {.val {name}} returned {.code NULL}.",
        "i" = "Each expression must return a vector aligned with the input rows."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (is.data.frame(val) || is.list(val)) {
    cli::cli_abort(
      c(
        "{.fn derive} expression for {.val {name}} returned {.obj_type_friendly {val}}, not a vector.",
        "i" = "Each expression must return an atomic vector aligned with the input rows."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(val) == 1L && nrow_data > 1L) {
    val <- rep(val, nrow_data)
  }
  if (length(val) != nrow_data) {
    cli::cli_abort(
      c(
        "{.fn derive} expression for {.val {name}} returned length {length(val)}, not {nrow_data}.",
        "i" = "Each expression must return a vector aligned with the input rows (or length 1, which recycles)."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  val
}
