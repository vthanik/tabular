# engine_group_display.R — apply `col_spec@group_display` semantics.
#
# Runs AFTER engine_format (cells_text + cells_ast carry their final
# per-cell values) and BEFORE engine_decimal. Three behaviours, one
# per `group_display` value:
#
#   "header_row" (default) — for each transition on the group
#     column, signal that a section header row should render above
#     the data row. Hide the source column from the visible body via
#     `col_spec@visible = FALSE`. The actual row INJECTION happens
#     per-page inside `.slice_one_page()`; this phase only sets up
#     the visibility flip and the per-row "transition" sidecar so
#     pagination + decimal alignment + width math operate on the
#     un-augmented matrices.
#
#   "column" — column stays visible; cells whose value matches the
#     previous row's value (within the same outer-group block) are
#     blanked. First row of each value still shows the label.
#
#   "column_repeat" — no-op. Every row carries the value verbatim.
#
# Output is the same triple of matrices (cells_text, cells_ast,
# cells_style) — possibly with blanked cells under "column" mode —
# plus a possibly-updated col_spec map (visibility flipped for
# "header_row" columns) and a `header_row_plan` sidecar that
# `.slice_one_page()` consumes at render time to inject header
# rows into each page's slice.
#
# Pure function. No I/O.

engine_group_display <- function(
  cells_text,
  cells_ast,
  cells_style,
  cols
) {
  nrow_data <- nrow(cells_text)
  ncol_data <- ncol(cells_text)
  col_names <- colnames(cells_text)
  if (is.null(col_names)) {
    col_names <- character(0L)
  }

  if (nrow_data == 0L || ncol_data == 0L) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      cols = cols,
      header_row_plan = NULL
    ))
  }

  # Identify group columns in declaration order. Outer = first.
  group_names <- .group_display_columns(cols, col_names)
  if (length(group_names) == 0L) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      cols = cols,
      header_row_plan = NULL
    ))
  }

  # Find the first group column using "header_row" mode. Drives
  # both the per-row transition sidecar AND the visibility flip on
  # source columns.
  header_col <- .first_header_row_column(cols, group_names)

  # Outer-group run ids — drives column-mode suppression reset.
  outer_run_ids <- if (!is.null(header_col)) {
    .runs_grouping(cells_text[, header_col])
  } else {
    .runs_grouping(cells_text[, group_names[[1L]]])
  }

  # Phase 1: apply "column"-mode suppression.
  for (nm in group_names) {
    cs <- cols[[nm]]
    if (identical(cs@group_display, "column")) {
      cells_text[, nm] <- .suppress_column_repeats(
        cells_text[, nm],
        outer_run_ids
      )
      cells_ast[, nm] <- .suppress_column_repeats_ast(
        cells_ast[, nm],
        outer_run_ids,
        call = rlang::caller_env()
      )
    }
  }

  # Phase 2: build the header-row plan + hide source columns. Only
  # the FIRST header_row group column produces a plan (multi-header
  # nesting is a follow-up).
  header_row_plan <- NULL
  if (!is.null(header_col)) {
    host_col <- .header_row_host_column(col_names, group_names, cols)
    header_row_plan <- list(
      group_col = header_col,
      group_values = cells_text[, header_col],
      group_asts = cells_ast[, header_col],
      host_col = host_col,
      transitions = which(c(TRUE, diff(outer_run_ids) != 0L))
    )
    for (nm in group_names) {
      cs <- cols[[nm]]
      if (identical(cs@group_display, "header_row")) {
        cols[[nm]] <- S7::set_props(cs, visible = FALSE)
      }
    }
  }

  list(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    header_row_plan = header_row_plan
  )
}

# Group columns in declaration order. Returns a character vector
# of column names whose `col_spec@usage == "group"`.
.group_display_columns <- function(cols, col_names) {
  keep <- vapply(
    col_names,
    function(nm) {
      cs <- cols[[nm]]
      is_col_spec(cs) && !is.na(cs@usage) && cs@usage == "group"
    },
    logical(1L)
  )
  col_names[keep]
}

# First group column with group_display == "header_row", in
# declaration order. Returns NULL when none.
.first_header_row_column <- function(cols, group_names) {
  for (nm in group_names) {
    cs <- cols[[nm]]
    if (identical(cs@group_display, "header_row")) {
      return(nm)
    }
  }
  NULL
}

# Run-length grouping. Returns an integer vector the same length
# as `x` where consecutive runs of equal values share an id. Two
# rows are in the same run iff they are adjacent AND their values
# are equal (NA == NA for grouping purposes).
.runs_grouping <- function(x) {
  n <- length(x)
  if (n == 0L) {
    return(integer(0L))
  }
  ids <- integer(n)
  ids[[1L]] <- 1L
  prev <- x[[1L]]
  current <- 1L
  for (i in seq.int(2L, n)) {
    cur <- x[[i]]
    same <- (is.na(prev) && is.na(cur)) ||
      (!is.na(prev) && !is.na(cur) && identical(prev, cur))
    if (!same) {
      current <- current + 1L
    }
    ids[[i]] <- current
    prev <- cur
  }
  ids
}

# Suppress repeats on a character column within each outer-group
# section.
.suppress_column_repeats <- function(col, outer_run_ids) {
  n <- length(col)
  if (n <= 1L) {
    return(col)
  }
  out <- col
  for (i in seq.int(2L, n)) {
    if (outer_run_ids[[i]] != outer_run_ids[[i - 1L]]) {
      next
    }
    if (identical(col[[i]], col[[i - 1L]])) {
      out[[i]] <- ""
    }
  }
  out
}

.suppress_column_repeats_ast <- function(col, outer_run_ids, call) {
  n <- length(col)
  if (n <= 1L) {
    return(col)
  }
  empty <- parse_inline("", call = call)
  out <- col
  for (i in seq.int(2L, n)) {
    if (outer_run_ids[[i]] != outer_run_ids[[i - 1L]]) {
      next
    }
    if (identical(col[[i]], col[[i - 1L]])) {
      out[[i]] <- empty
    }
  }
  out
}

# Pick the column that hosts the header-row text. Skip every
# `usage = "group"` column whose `group_display = "header_row"`
# (those are hidden). Falls back to NA when nothing visible
# remains.
.header_row_host_column <- function(col_names, group_names, cols) {
  hidden <- character(0L)
  for (nm in group_names) {
    cs <- cols[[nm]]
    if (identical(cs@group_display, "header_row")) {
      hidden <- c(hidden, nm)
    }
  }
  candidates <- setdiff(col_names, hidden)
  if (length(candidates) == 0L) {
    return(NA_character_)
  }
  candidates[[1L]]
}

# Per-page header-row injection. Called by `.slice_one_page()` after
# the page's matrices have been sliced by `row_indices`. Augments
# the sliced matrices with synthesised header rows at every group-
# value transition that falls within the page's range. Returns the
# augmented (cells_text, cells_ast, cells_style) triple plus an
# `is_header_row` logical aligned to the new row count.
.inject_header_rows_for_page <- function(
  cells_text,
  cells_ast,
  cells_style,
  row_indices,
  visible_col_names,
  header_row_plan,
  call = rlang::caller_env()
) {
  if (is.null(header_row_plan) || length(row_indices) == 0L) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      is_header_row = rep(FALSE, length(row_indices))
    ))
  }

  # Transitions that fall within this page's row range.
  page_transitions <- intersect(header_row_plan$transitions, row_indices)
  if (length(page_transitions) == 0L) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      is_header_row = rep(FALSE, length(row_indices))
    ))
  }

  host_col <- header_row_plan$host_col
  host_idx <- match(host_col, visible_col_names)
  if (length(host_idx) != 1L || is.na(host_idx)) {
    # Host column isn't visible on this page (unusual — skip).
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      is_header_row = rep(FALSE, length(row_indices))
    ))
  }

  ncol_visible <- length(visible_col_names)
  blank_ast <- parse_inline("", call = call)
  default_node <- style_node()

  # Output row by row. At each page row, prepend a header row if
  # that row is a transition.
  n_page <- length(row_indices)
  total_out <- n_page + length(page_transitions)
  text_out <- matrix(
    "",
    nrow = total_out,
    ncol = ncol_visible,
    dimnames = list(NULL, visible_col_names)
  )
  ast_out <- matrix(list(), nrow = total_out, ncol = ncol_visible)
  style_out <- matrix(list(), nrow = total_out, ncol = ncol_visible)
  colnames(ast_out) <- visible_col_names
  colnames(style_out) <- visible_col_names
  is_header_row <- logical(total_out)

  out_pos <- 0L
  for (k in seq_len(n_page)) {
    data_idx <- row_indices[[k]]
    if (data_idx %in% page_transitions) {
      out_pos <- out_pos + 1L
      text_out[out_pos, host_idx] <- header_row_plan$group_values[[data_idx]]
      for (j in seq_len(ncol_visible)) {
        ast_out[[out_pos, j]] <- if (j == host_idx) {
          header_row_plan$group_asts[[data_idx]]
        } else {
          blank_ast
        }
        style_out[[out_pos, j]] <- default_node
      }
      is_header_row[[out_pos]] <- TRUE
    }
    out_pos <- out_pos + 1L
    text_out[out_pos, ] <- cells_text[k, ]
    for (j in seq_len(ncol_visible)) {
      ast_out[[out_pos, j]] <- cells_ast[[k, j]]
      style_out[[out_pos, j]] <- cells_style[[k, j]]
    }
    is_header_row[[out_pos]] <- FALSE
  }

  list(
    cells_text = text_out,
    cells_ast = ast_out,
    cells_style = style_out,
    is_header_row = is_header_row
  )
}
