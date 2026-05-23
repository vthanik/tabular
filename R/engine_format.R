# engine_format.R — resolve-engine phase that converts a
# tabular_spec's data + string slots into formatted text + parsed
# inline_ast. Runs between engine_derive / engine_sort (which finalize
# the data frame and row order) and engine_decimal (which space-pads
# decimal-aligned columns). The output is the canonical hand-off to
# the backend layer:
#
#   cells_text       : character matrix, one cell per (row, col).
#                      NA values substituted with the column's
#                      `na_text`; non-NA values run through
#                      `col_spec@format` (sprintf string, unary
#                      function, or pass-through).
#   cells_ast        : list-matrix of `inline_ast`, one per cell.
#                      Every cell text is parsed via
#                      `parse_inline()` so cell-level md() / html()
#                      content surfaces as structured runs.
#   titles_ast       : list of `inline_ast`, one per title line.
#                      Empty list when spec carries no titles.
#   footnotes_ast    : list of `inline_ast`, one per footnote line.
#   col_labels_ast   : named list of `inline_ast`, one per data
#                      column. Source = col_spec@label (or column
#                      name when label is NA / not set).
#
# Pure function. No I/O. The output is consumed by engine_decimal
# (which only needs `cells_text` + the cols list) and by the
# emit / backend layer (which consumes everything).
#
# Format semantics:
#   - When `col_spec@format` is a sprintf template, it is applied
#     to non-NA cells via `sprintf(format, value)`. Templates were
#     validated at `col_spec()` construction with a sample probe,
#     so a downstream mismatch (e.g. `%d` applied to a float) is
#     surfaced as `tabular_error_runtime`.
#   - When `col_spec@format` is a unary function, it is applied
#     once to the column's non-NA values. The function must return
#     a vector of the same length as its input; any other length is
#     a runtime error.
#   - When `col_spec@format` is NULL, the cell value is coerced to
#     character (`as.character()`).
#
# NA handling:
#   - NAs are detected via `is.na(value)` BEFORE format application
#     so the format step never sees NA. Each NA cell is replaced
#     with `col_spec@na_text` (default "" empty string).
#
# Inline-format parsing:
#   - Every formatted string is run through `parse_inline()` to
#     produce an `inline_ast`. Plain strings parse to a trivial
#     single-run AST; cells / titles / footnotes / labels that were
#     constructed via `md()` or `html()` parse to the typed run
#     list. Backends consume the AST directly.

# ---------------------------------------------------------------------
# Public entry — engine_format
# ---------------------------------------------------------------------

#' Apply column formats, substitute NA tokens, and parse inline ASTs
#'
#' Pure function. Called by the resolve engine after `engine_sort()`
#' (so the row order is final) and before `engine_decimal()` (which
#' aligns decimal columns on the already-formatted text). Returns a
#' named list of resolved artifacts that the emit / backend layer
#' consumes directly.
#'
#' @param spec A `tabular_spec`.
#' @return A named list with five entries:
#'   * `cells_text` — character matrix (`nrow(spec@data)` rows,
#'     `ncol(spec@data)` cols).
#'   * `cells_ast` — list-matrix of `inline_ast` with the same
#'     shape as `cells_text`.
#'   * `titles_ast` — list of `inline_ast`, one per title line.
#'   * `footnotes_ast` — list of `inline_ast`, one per footnote
#'     line.
#'   * `col_labels_ast` — named list of `inline_ast`, one per data
#'     column.
#' @keywords internal
#' @noRd
engine_format <- function(spec) {
  data <- spec@data
  call <- rlang::caller_env()

  col_names <- names(data)
  cols <- .cols_by_name(spec@cols, col_names)

  cells_text <- .format_cells(data, cols, call = call)
  cells_ast <- .parse_cells_ast(cells_text, call = call)

  titles_ast <- .parse_string_vec(spec@titles, call = call)
  footnotes_ast <- .parse_string_vec(spec@footnotes, call = call)
  col_labels_ast <- .parse_col_labels(cols, col_names, call = call)

  list(
    cells_text = cells_text,
    cells_ast = cells_ast,
    titles_ast = titles_ast,
    footnotes_ast = footnotes_ast,
    col_labels_ast = col_labels_ast
  )
}

# ---------------------------------------------------------------------
# Cell formatting
# ---------------------------------------------------------------------

# Build a name-keyed list of col_spec entries covering every data
# column. Columns the user did not declare via `cols()` get a default
# `col_spec()`. The internal `name` field of each spec is stamped
# with the column name so error messages can reference it.
.cols_by_name <- function(cols, col_names) {
  out <- vector("list", length(col_names))
  names(out) <- col_names
  for (nm in col_names) {
    cs <- cols[[nm]]
    if (is_col_spec(cs)) {
      out[[nm]] <- cs
    } else {
      out[[nm]] <- col_spec()
    }
    if (is.na(out[[nm]]@name)) {
      out[[nm]] <- S7::set_props(out[[nm]], name = nm)
    }
  }
  out
}

# Apply per-column format + NA substitution. Returns a character
# matrix shaped like spec@data.
.format_cells <- function(data, cols, call) {
  nrow_data <- nrow(data)
  ncol_data <- ncol(data)
  col_names <- names(data)

  mat <- matrix(
    character(1L),
    nrow = nrow_data,
    ncol = ncol_data,
    dimnames = list(NULL, col_names)
  )

  if (nrow_data == 0L) {
    return(mat)
  }

  for (j in seq_len(ncol_data)) {
    nm <- col_names[[j]]
    mat[, j] <- .format_one_column(
      values = data[[j]],
      cs = cols[[nm]],
      call = call
    )
  }
  mat
}

# Format one column. NA cells are substituted with `na_text` BEFORE
# the format step so neither sprintf nor the user-supplied function
# sees NA. Returns a character vector of length `length(values)`.
.format_one_column <- function(values, cs, call) {
  n <- length(values)
  na_mask <- is.na(values)
  out <- character(n)
  na_text <- cs@na_text

  if (all(na_mask)) {
    out[] <- na_text
    return(out)
  }

  fmt <- cs@format
  non_na <- !na_mask
  rendered <- .apply_format(
    values = values[non_na],
    format = fmt,
    col_name = cs@name,
    call = call
  )
  out[non_na] <- rendered
  out[na_mask] <- na_text
  out
}

# Dispatch on the format argument: NULL -> as.character, character
# (sprintf template) -> sprintf, function -> user fn. The col_spec
# construction validator already rejected everything that is not
# NULL / character(1) / function, so the function branch is the
# final fallback.
.apply_format <- function(values, format, col_name, call) {
  if (is.null(format)) {
    return(as.character(values))
  }

  if (is.character(format)) {
    return(.apply_sprintf(values, format, col_name, call))
  }

  .apply_function(values, format, col_name, call)
}

# Apply a sprintf template. Wraps any error as tabular_error_runtime
# so the failure carries the offending column name.
.apply_sprintf <- function(values, template, col_name, call) {
  result <- tryCatch(
    sprintf(template, values),
    error = function(e) e
  )
  if (inherits(result, "condition")) {
    cli::cli_abort(
      c(
        "{.fn sprintf} failed for column {.val {col_name}}.",
        "x" = "Template {.val {template}} could not format the column.",
        "i" = "Underlying error: {conditionMessage(result)}."
      ),
      class = "tabular_error_runtime",
      call = call
    )
  }
  result
}

# Apply a user-supplied unary function. Validates that the result is
# the same length as the input and coerces to character. Failures
# during the call are wrapped as tabular_error_runtime.
.apply_function <- function(values, fn, col_name, call) {
  result <- tryCatch(fn(values), error = function(e) e)
  if (inherits(result, "condition")) {
    cli::cli_abort(
      c(
        "{.arg format} function failed for column {.val {col_name}}.",
        "x" = "Underlying error: {conditionMessage(result)}."
      ),
      class = "tabular_error_runtime",
      call = call
    )
  }
  if (length(result) != length(values)) {
    cli::cli_abort(
      c(
        "{.arg format} function for column {.val {col_name}} returned length {length(result)}, expected {length(values)}.",
        "i" = "The function must return a vector of the same length as its input."
      ),
      class = "tabular_error_runtime",
      call = call
    )
  }
  as.character(result)
}

# ---------------------------------------------------------------------
# AST construction
# ---------------------------------------------------------------------

# Parse every cell into an `inline_ast`. Returns a list-matrix shaped
# like cells_text. Empty data returns an empty list-matrix with the
# right dimnames.
.parse_cells_ast <- function(cells_text, call) {
  nrow_data <- nrow(cells_text)
  ncol_data <- ncol(cells_text)
  asts <- vector("list", nrow_data * ncol_data)
  for (k in seq_along(asts)) {
    asts[[k]] <- parse_inline(cells_text[[k]], call = call)
  }
  dim(asts) <- c(nrow_data, ncol_data)
  dimnames(asts) <- dimnames(cells_text)
  asts
}

# Parse a character vector of strings into a list of `inline_ast`.
# Length-0 input returns an empty list.
.parse_string_vec <- function(x, call) {
  if (length(x) == 0L) {
    return(list())
  }
  lapply(seq_along(x), function(i) parse_inline(x[[i]], call = call))
}

# Build the per-column label AST. Source: col_spec@label when set
# (non-NA), otherwise the column name itself. Output is a named list
# of inline_ast keyed by data column name.
.parse_col_labels <- function(cols, col_names, call) {
  out <- vector("list", length(col_names))
  names(out) <- col_names
  for (nm in col_names) {
    cs <- cols[[nm]]
    label <- cs@label
    text <- if (is.na(label)) nm else label
    out[[nm]] <- parse_inline(text, call = call)
  }
  out
}
