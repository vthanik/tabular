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

#' Apply `col_spec@group_display` semantics in the resolve pipeline
#'
#' @param cells_text Character matrix of formatted cell strings
#'   (one row per data row, one column per data column).
#' @param cells_ast List-matrix of inline-AST nodes parallel to
#'   `cells_text`.
#' @param cells_style List-matrix of `style_node` overrides parallel
#'   to `cells_text`.
#' @param cols Named list of `col_spec` objects keyed by data column
#'   name. Columns with `usage = "group"` drive the per-group
#'   behaviour selected by `col_spec@group_display`.
#' @return A list with six named slots: `cells_text`, `cells_ast`,
#'   `cells_style` (the possibly-blanked matrices), `cols` (the
#'   possibly-visibility-flipped col_spec map for header_row
#'   columns), `header_row_plan` (per-row injection sidecar consumed
#'   by `.slice_one_page()`), and `skip_transitions` (sorted integer
#'   vector of transition row indices unioned across every group
#'   column whose effective `group_skip` is `TRUE` — coincident
#'   transitions collapse to a single index so only one blank row is
#'   injected).
#' @keywords internal
#' @noRd
engine_group_display <- function(
  cells_text,
  cells_ast,
  cells_style,
  cols,
  data = NULL,
  indent_chars = "",
  subgroup_hide_cols = character(0L)
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

  # Resolve `col_spec@indent_by` references BEFORE any group/column-
  # mode processing. Each target column with `indent_by = "<name>"`
  # set picks up per-row depths from `data[[<name>]]`; the target
  # column's text + AST is prefixed in-place with
  # `paste(rep(indent_chars, depth), collapse = "")`. The
  # referenced depth column gets its `visible` auto-flipped to FALSE
  # (unless the user set it explicitly) so depth values don't render.
  #
  # Independent of `group_display = "header_row"` — works in plain
  # listings (no group cols) just as well as in SOC/PT tables.
  indent_apply <- .resolve_indent_targets(
    cols = cols,
    col_names = col_names,
    data = data,
    nrow_data = nrow_data,
    indent_chars = indent_chars,
    call = rlang::caller_env()
  )
  if (length(indent_apply$targets) > 0L && nzchar(indent_chars %||% "")) {
    for (target in indent_apply$targets) {
      cells_text[, target$col] <- paste0(
        target$prefixes,
        cells_text[, target$col]
      )
      cells_ast[, target$col] <- .indent_host_asts_per_row(
        cells_ast[, target$col],
        target$prefixes
      )
    }
  }
  # Apply the visibility auto-hide on the depth columns that
  # `.resolve_indent_targets()` flagged AND on the subgroup
  # partition / template-ref columns the caller pre-computed via
  # `.subgroup_auto_hide_cols()`. Done after the prefix block
  # (which still needs to read from data[, depth_col] even if the
  # column is hidden) and BEFORE the rest of the pipeline so
  # `.visible_col_names()` filters them out downstream.
  hide_union <- unique(c(indent_apply$hide_cols, subgroup_hide_cols))
  for (hide_col in hide_union) {
    cs <- cols[[hide_col]]
    if (is_col_spec(cs)) {
      cols[[hide_col]] <- S7::set_props(cs, visible = FALSE)
    }
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

  # Phase 2: build the header-row plan + the blank-skip plan + hide
  # source columns. Only the FIRST header_row group column produces
  # a header plan (multi-header nesting is a follow-up). Per-column
  # `group_skip` (TRUE / FALSE / NA-defaulting-via-group_display)
  # drives the blank-row plan independently — every group column
  # whose `.effective_group_skip()` resolves TRUE contributes its
  # transition row indices.
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

  # Per-column group_skip plan. A blank row is inserted BEFORE any
  # row that is a transition (on the data row scale) for any group
  # column whose effective `group_skip` resolves TRUE. The first
  # transition on the page never gets a leading blank.
  skip_transitions <- integer(0L)
  for (nm in group_names) {
    cs <- cols[[nm]]
    if (.effective_group_skip(cs)) {
      run_ids <- .runs_grouping(cells_text[, nm])
      col_trans <- which(c(TRUE, diff(run_ids) != 0L))
      skip_transitions <- union(skip_transitions, col_trans)
    }
  }
  skip_transitions <- sort(as.integer(skip_transitions))

  list(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    header_row_plan = header_row_plan,
    skip_transitions = skip_transitions
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

# Prepend an indent prefix to every AST in `asts` (a list-column of
# `inline_ast` records). The prefix becomes a leading `plain` run on
# each AST, which every backend already renders verbatim through its
# inline-run pipeline.
#
# NA / NULL / non-inline_ast entries pass through unchanged — the
# user might have hand-attached a wrapper that doesn't carry runs,
# and the host column may contain entries from rows the
# group_display engine doesn't manage.
.indent_host_asts <- function(asts, indent_chars) {
  if (length(asts) == 0L || !is.character(indent_chars)) {
    return(asts)
  }
  prefix_run <- list(type = "plain", text = indent_chars)
  for (i in seq_along(asts)) {
    a <- asts[[i]]
    if (!is_inline_ast(a)) {
      next
    }
    asts[[i]] <- inline_ast(runs = c(list(prefix_run), a@runs))
  }
  asts
}

# Per-row variant of `.indent_host_asts`. Takes a parallel
# `prefixes` character vector (length == length(asts)); each row's
# AST gets its OWN prefix prepended as a leading `plain` run.
# Empty prefix on a row means no prefix run is added (zero-depth
# row stays clean — no spurious empty plain run polluting the
# inline-AST shape).
.indent_host_asts_per_row <- function(asts, prefixes) {
  if (length(asts) == 0L) {
    return(asts)
  }
  if (length(prefixes) != length(asts)) {
    return(asts)
  }
  for (i in seq_along(asts)) {
    pfx <- prefixes[[i]]
    if (!is.character(pfx) || is.na(pfx) || !nzchar(pfx)) {
      next
    }
    a <- asts[[i]]
    if (!is_inline_ast(a)) {
      next
    }
    asts[[i]] <- inline_ast(
      runs = c(list(list(type = "plain", text = pfx)), a@runs)
    )
  }
  asts
}

# Walk `cols` for every entry with `@indent_by` set and resolve
# each into a per-row prefix vector against the named depth column
# in `data`. Returns a list with two slots:
#
#   $targets  — list of records, one per resolved indent target:
#                 list(col = <target>, depth_col = <depth>,
#                      prefixes = character(nrow_data))
#   $hide_cols — character vector of depth-column names whose
#                visibility should be auto-flipped to FALSE.
#
# Hard errors (class = "tabular_error_input") on:
#   - referenced depth column not present in `data`
#   - depth column wrong length
#   - depth column not numeric / logical
#   - target column declares indent_by but isn't in cells_text
#
# Soft handling (clamp + continue) on:
#   - NA depth values  -> 0
#   - negative depths  -> 0
#   - fractional depths -> floor()
.resolve_indent_targets <- function(
  cols,
  col_names,
  data,
  nrow_data,
  indent_chars,
  call
) {
  out <- list(targets = list(), hide_cols = character(0L))
  if (is.null(data)) {
    return(out)
  }
  for (nm in names(cols)) {
    cs <- cols[[nm]]
    if (!is_col_spec(cs)) {
      next
    }
    by <- cs@indent_by
    if (length(by) != 1L || is.na(by) || !nzchar(by)) {
      next
    }
    if (!(nm %in% col_names)) {
      # Target column isn't in cells_text (e.g. it was dropped
      # upstream). Silently skip — no engine error on a stale
      # reference; the engine doesn't get to choose which columns
      # ride through every phase.
      next
    }
    if (!(by %in% names(data))) {
      cli::cli_abort(
        c(
          "{.code col_spec(indent_by = ...)} references missing column.",
          "x" = "Column {.val {nm}} declares {.code indent_by = {.val {by}}}, but {.val {by}} is not in {.code spec@data}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    raw <- data[[by]]
    if (length(raw) != nrow_data) {
      cli::cli_abort(
        c(
          "Bad indent depth column.",
          "x" = "Column {.val {by}} has length {length(raw)}, expected {nrow_data}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    depths <- .coerce_indent_depths(raw, by, call = call)
    prefixes <- .build_indent_prefixes(depths, indent_chars)
    out$targets[[length(out$targets) + 1L]] <- list(
      col = nm,
      depth_col = by,
      prefixes = prefixes
    )
    if (!(by %in% out$hide_cols)) {
      out$hide_cols <- c(out$hide_cols, by)
    }
  }
  out
}

# Coerce a depth column to an integer vector of non-negative
# values. Logical -> 0/1; numeric -> floor with a warn on
# fractional; NA -> 0; negative -> 0 with a warn. Non-numeric +
# non-logical input is a hard error.
.coerce_indent_depths <- function(x, depth_col, call) {
  if (is.logical(x)) {
    out <- as.integer(x)
    out[is.na(out)] <- 0L
    return(out)
  }
  if (is.numeric(x)) {
    if (any(stats::na.omit(x) != floor(stats::na.omit(x)))) {
      cli::cli_warn(
        "Indent depth column {.val {depth_col}} has fractional values; floored.",
        call = call
      )
    }
    out <- suppressWarnings(as.integer(floor(x)))
    out[is.na(out)] <- 0L
    if (any(out < 0L)) {
      cli::cli_warn(
        "Indent depth column {.val {depth_col}} has negative values; clamped to 0.",
        call = call
      )
      out[out < 0L] <- 0L
    }
    return(out)
  }
  cli::cli_abort(
    c(
      "Bad indent depth column.",
      "x" = "Column {.val {depth_col}} must be integer or logical.",
      "i" = "Got {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Map an integer depth vector to a parallel character prefix
# vector. Empty string for depth 0; `paste(rep(indent_chars, N),
# collapse = "")` for depth N. The caller injects these on
# `cells_text[, target]` and on `cells_ast[, target]`.
.build_indent_prefixes <- function(depths, indent_chars) {
  if (
    !is.character(indent_chars) ||
      length(indent_chars) != 1L ||
      is.na(indent_chars) ||
      !nzchar(indent_chars)
  ) {
    return(rep("", length(depths)))
  }
  vapply(
    depths,
    function(d) {
      if (d <= 0L) {
        return("")
      }
      paste(rep(indent_chars, d), collapse = "")
    },
    character(1L)
  )
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
  skip_transitions = integer(0L),
  call = rlang::caller_env()
) {
  # Header transitions (drive section-header row injection) and
  # blank transitions (drive blank-row injection) are computed
  # independently. Header transitions come from the outer
  # `header_row` group column; blank transitions come from every
  # group column whose effective `group_skip` resolves TRUE.
  header_transitions <- if (is.null(header_row_plan)) {
    integer(0L)
  } else {
    intersect(header_row_plan$transitions, row_indices)
  }
  blank_transitions <- intersect(skip_transitions, row_indices)

  has_header_plan <- !is.null(header_row_plan) &&
    length(header_transitions) > 0L
  has_blank_plan <- length(blank_transitions) > 0L

  if (length(row_indices) == 0L || (!has_header_plan && !has_blank_plan)) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      is_header_row = rep(FALSE, length(row_indices)),
      is_blank_row = rep(FALSE, length(row_indices))
    ))
  }

  host_idx <- NA_integer_
  if (has_header_plan) {
    host_idx <- match(header_row_plan$host_col, visible_col_names)
    if (length(host_idx) != 1L || is.na(host_idx)) {
      has_header_plan <- FALSE
    }
  }

  ncol_visible <- length(visible_col_names)
  blank_ast <- parse_inline("", call = call)
  default_node <- style_node()

  n_page <- length(row_indices)
  total_out_max <- n_page +
    length(header_transitions) +
    length(blank_transitions)
  text_out <- matrix(
    "",
    nrow = total_out_max,
    ncol = ncol_visible,
    dimnames = list(NULL, visible_col_names)
  )
  ast_out <- matrix(list(), nrow = total_out_max, ncol = ncol_visible)
  style_out <- matrix(list(), nrow = total_out_max, ncol = ncol_visible)
  colnames(ast_out) <- visible_col_names
  colnames(style_out) <- visible_col_names
  is_header_row <- logical(total_out_max)
  is_blank_row <- logical(total_out_max)

  out_pos <- 0L
  first_emit <- TRUE
  for (k in seq_len(n_page)) {
    data_idx <- row_indices[[k]]
    # Blank row goes BEFORE the row at this transition, but not for
    # the very first row of the page (no preceding group on page).
    if (data_idx %in% blank_transitions && !first_emit) {
      out_pos <- out_pos + 1L
      for (j in seq_len(ncol_visible)) {
        ast_out[[out_pos, j]] <- blank_ast
        style_out[[out_pos, j]] <- default_node
      }
      is_blank_row[[out_pos]] <- TRUE
    }
    if (has_header_plan && data_idx %in% header_transitions) {
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
      first_emit <- FALSE
    }
    out_pos <- out_pos + 1L
    text_out[out_pos, ] <- cells_text[k, ]
    for (j in seq_len(ncol_visible)) {
      ast_out[[out_pos, j]] <- cells_ast[[k, j]]
      style_out[[out_pos, j]] <- cells_style[[k, j]]
    }
    is_header_row[[out_pos]] <- FALSE
    is_blank_row[[out_pos]] <- FALSE
    first_emit <- FALSE
  }

  total_out <- out_pos
  list(
    cells_text = text_out[seq_len(total_out), , drop = FALSE],
    cells_ast = ast_out[seq_len(total_out), , drop = FALSE],
    cells_style = style_out[seq_len(total_out), , drop = FALSE],
    is_header_row = is_header_row[seq_len(total_out)],
    is_blank_row = is_blank_row[seq_len(total_out)]
  )
}
