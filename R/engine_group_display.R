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
  indent_size = 0L,
  subgroup_hide_cols = character(0L)
) {
  # Finalize NA "unset" sentinels (visible / group_display / usage) so
  # every read below is concrete, even when this phase is exercised
  # directly on a raw col_spec map (production feeds finalized cols via
  # .cols_by_name; idempotent here). Single resolver, no duplicated
  # defaults.
  cols <- .finalize_col_specs(cols)
  indent_unit <- .indent_text_unit(indent_size)
  nrow_data <- nrow(cells_text)
  ncol_data <- ncol(cells_text)
  col_names <- colnames(cells_text)
  if (is.null(col_names)) {
    col_names <- character(0L)
  }

  # Snapshot the user's DECLARED visibility before the auto-hide block
  # below mutates it. A `usage = "group"` column the user hid is
  # break-only (contributes group_skip transitions but no header rows),
  # so `.header_row_columns()` must gate on user intent, not on the
  # post-auto-hide flag (indent / subgroup columns are flipped to
  # FALSE below, and header_row's own auto-hide happens later still).
  user_visible <- vapply(
    col_names,
    function(nm) {
      cs <- cols[[nm]]
      !is_col_spec(cs) || isTRUE(cs@visible)
    },
    logical(1L)
  )

  # Sidecar matrix carrying per-cell indent depth in integer levels.
  # `col_spec@indent` (a fixed count or a per-row column) and the
  # `header_row` auto-indent write to it additively. Header / blank rows
  # injected later by `.inject_header_rows_for_page()` carry depth 0L
  # on every column (the parent at depth 0 — never indented). Each
  # backend reads this matrix and emits native padding-left in its
  # own unit (HTML: em; LaTeX: pt; RTF / DOCX: twips). Markdown is the
  # exception — it keeps the engine text-prefix and ignores the
  # sidecar.
  cells_indent <- matrix(
    0L,
    nrow = nrow_data,
    ncol = ncol_data,
    dimnames = list(NULL, col_names)
  )

  if (nrow_data == 0L || ncol_data == 0L) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      cells_indent = cells_indent,
      cols = cols,
      header_row_plan = NULL
    ))
  }

  # Resolve `col_spec@indent` BEFORE any group/column-mode processing.
  # Two modes per target column:
  #   * numeric scalar N — every body row indented N levels;
  #   * character "<name>" — per-row depths from `data[[<name>]]`, and
  #     the referenced depth column gets its `visible` auto-flipped to
  #     FALSE (unless the user set it) so depth values don't render.
  # Either way the target column's text + AST is prefixed in-place with
  # `strrep(indent_unit, depth)` where `indent_unit` is
  # `strrep(" ", indent_size)`.
  #
  # Independent of `group_display = "header_row"` — works in plain
  # listings (no group cols) just as well as in SOC/PT tables. An
  # explicit `indent` on a header_row host suppresses the section
  # auto-indent below (the host carries the depth itself).
  indent_apply <- .resolve_indent_targets(
    cols = cols,
    col_names = col_names,
    data = data,
    nrow_data = nrow_data,
    indent_size = indent_size,
    call = rlang::caller_env()
  )
  if (length(indent_apply$targets) > 0L && nzchar(indent_unit)) {
    for (target in indent_apply$targets) {
      cells_text[, target$col] <- paste0(
        target$prefixes,
        cells_text[, target$col]
      )
      cells_ast[, target$col] <- .indent_host_asts_per_row(
        cells_ast[, target$col],
        target$prefixes
      )
      cells_indent[, target$col] <- cells_indent[, target$col] +
        as.integer(target$depths)
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
      cells_indent = cells_indent,
      cols = cols,
      header_row_plan = NULL
    ))
  }

  # Per-column group_skip plan. A blank row is inserted BEFORE any
  # row that is a transition (on the data row scale) for any group
  # column whose effective `group_skip` resolves TRUE. The first
  # transition on the page never gets a leading blank.
  #
  # Computed HERE, before Phase 1 column-mode suppression, so the
  # run grouping sees the LOGICAL group values. Reading post-
  # suppression text turns "Age", "", "" into a phantom run boundary
  # at row 2 and injects a stray blank after each group's first row.
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

  # Identify every group column declaring `header_row` mode, in
  # declaration order. Outer = index 1. Each becomes one band in the
  # header-row plan below.
  header_cols <- .header_row_columns(cols, group_names)
  # A group column the user hid is break-only: drop it from the
  # header-row plan so its values never render as section headers.
  # It stays in `group_names`, so its `group_skip` transitions (above)
  # still fire; its body is filtered by `.visible_col_names()`.
  header_cols <- header_cols[vapply(
    header_cols,
    function(nm) isTRUE(user_visible[[nm]]),
    logical(1L)
  )]
  header_col <- if (length(header_cols) > 0L) header_cols[[1L]] else NULL

  # Outer-group run ids — drives column-mode suppression reset. Use
  # the OUTERMOST header_row column when one exists; otherwise fall
  # back to the first group column.
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

  # Phase 2: build the multi-band header-row plan + the blank-skip
  # plan + hide source columns. EVERY `header_row` group column
  # contributes a band; bands nest by declaration order (outer first).
  # Per-band transitions are computed from a composite-key run
  # grouping over bands 1..b joined with the ASCII unit separator
  # `\x1F`, so an inner band re-emits whenever its OWN value changes
  # OR any outer band's value changes (canonical "subsection resets
  # when section changes" semantic).
  #
  # `data_depth = length(bands)` is added to `cells_indent[, host_col]`
  # for every body row -- UNLESS the host column itself declares an
  # explicit `indent`, in which case the user's depth wins and the
  # auto-contribution is suppressed (preserves cdisc_saf_aesocpt's SOC/PT
  # rendering exactly).
  #
  # Per-column `group_skip` (TRUE / FALSE / NA-defaulting-via-
  # `group_display`) drives the blank-row plan independently — every
  # group column whose `.effective_group_skip()` resolves TRUE
  # contributes its transition row indices.
  header_row_plan <- NULL
  if (length(header_cols) > 0L) {
    host_col <- .header_row_host_column(
      col_names,
      group_names,
      cols,
      hidden_extra = hide_union
    )
    bands <- vector("list", length(header_cols))
    for (b in seq_along(header_cols)) {
      composite <- do.call(
        paste,
        c(
          lapply(
            seq_len(b),
            function(i) as.character(cells_text[, header_cols[[i]]])
          ),
          list(sep = "\x1F")
        )
      )
      run_ids <- .runs_grouping(composite)
      bands[[b]] <- list(
        group_col = header_cols[[b]],
        group_values = cells_text[, header_cols[[b]]],
        group_asts = cells_ast[, header_cols[[b]]],
        transitions = which(c(TRUE, diff(run_ids) != 0L)),
        depth = b - 1L
      )
    }
    data_depth <- length(bands)
    header_row_plan <- list(
      bands = bands,
      host_col = host_col,
      data_depth = data_depth
    )

    # Conditional auto-indent on the host column's body cells:
    # suppressed when the host already carries an explicit `indent`
    # (the user controls the depth). Composes additively with the
    # `indent` contribution the engine has already written into
    # `cells_indent` above.
    #
    # **Invariant**: the leading-space count in `cells_text[, col]`
    # must equal `indent_unit * cells_indent[i, col]`. We bump BOTH
    # the matrix AND the text-prefix together so backends can
    # blindly strip `indent_unit * cells_indent[i, j]` chars on
    # paper backends (HTML/LaTeX/RTF/DOCX emit native padding) and
    # markdown can render the prefix verbatim (markdown has no
    # native padding-left).
    if (
      !is.na(host_col) &&
        host_col %in% colnames(cells_indent) &&
        data_depth > 0L
    ) {
      host_col_spec <- cols[[host_col]]
      host_has_indent <- is_col_spec(host_col_spec) &&
        length(host_col_spec@indent) == 1L &&
        !is.na(host_col_spec@indent)
      if (!host_has_indent) {
        cells_indent[, host_col] <- cells_indent[, host_col] + data_depth
        if (nzchar(indent_unit)) {
          data_prefix <- strrep(indent_unit, data_depth)
          cells_text[, host_col] <- paste0(
            data_prefix,
            cells_text[, host_col]
          )
          cells_ast[, host_col] <- .indent_host_asts_per_row(
            cells_ast[, host_col],
            rep(data_prefix, nrow_data)
          )
        }
      }
    }

    for (nm in header_cols) {
      cols[[nm]] <- S7::set_props(cols[[nm]], visible = FALSE)
    }
  }

  list(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cells_indent = cells_indent,
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

# Group columns whose `group_display == "header_row"`, in declaration
# order. Returns a character vector (possibly empty). Index 1 is the
# OUTERMOST band; later entries nest inside.
.header_row_columns <- function(cols, group_names) {
  keep <- vapply(
    group_names,
    function(nm) identical(cols[[nm]]@group_display, "header_row"),
    logical(1L)
  )
  group_names[keep]
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
  # seq_len(n)[-1L] is empty when n == 1 (a single-row group); seq.int(2L, n)
  # would count DOWN to c(2, 1) there and read x[[2]] out of bounds.
  for (i in seq_len(n)[-1L]) {
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
  empty <- .parse_inline("", call = call)
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
.header_row_host_column <- function(
  col_names,
  group_names,
  cols,
  hidden_extra = character(0L)
) {
  hidden <- hidden_extra
  for (nm in group_names) {
    cs <- cols[[nm]]
    if (identical(cs@group_display, "header_row")) {
      hidden <- c(hidden, nm)
    }
  }
  # A host column must actually render. Skip explicitly-hidden columns
  # (visible = FALSE) and any caller-supplied hidden set (indent-by
  # targets, subgroup auto-hidden cols); otherwise the host resolves to
  # a hidden column, `match(host_col, visible_col_names)` is NA, and the
  # entire section-header plan is silently dropped downstream.
  for (nm in col_names) {
    cs <- cols[[nm]]
    if (is_col_spec(cs) && isFALSE(cs@visible)) {
      hidden <- c(hidden, nm)
    }
  }
  candidates <- setdiff(col_names, unique(hidden))
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
.indent_host_asts <- function(asts, indent_size) {
  indent_unit <- .indent_text_unit(indent_size)
  if (length(asts) == 0L || !nzchar(indent_unit)) {
    return(asts)
  }
  prefix_run <- list(type = "plain", text = indent_unit)
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

# Walk `cols` for every entry with `@indent` set and resolve each into
# a per-row prefix vector. Two modes by type:
#   * numeric scalar N — every body row gets depth N (no `data` needed);
#   * character "<name>" — per-row depths from `data[[<name>]]`, and the
#     named depth column is flagged for auto-hide.
# Returns a list with two slots:
#
#   $targets  — list of records, one per resolved indent target:
#                 list(col = <target>, depth_col = <depth | NA>,
#                      prefixes = character(nrow_data), depths = integer)
#   $hide_cols — character vector of depth-column names (character mode
#                only) whose visibility should be auto-flipped to FALSE.
#
# Hard errors (class = "tabular_error_input") on a character target:
#   - referenced depth column not present in `data`
#   - depth column wrong length
#   - depth column not numeric / logical
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
  indent_size,
  call
) {
  out <- list(targets = list(), hide_cols = character(0L))
  for (nm in names(cols)) {
    cs <- cols[[nm]]
    if (!is_col_spec(cs)) {
      next
    }
    ind <- cs@indent
    if (length(ind) != 1L || is.na(ind)) {
      next
    }
    if (!(nm %in% col_names)) {
      # Target column isn't in cells_text (e.g. it was dropped
      # upstream). Silently skip — no engine error on a stale
      # reference; the engine doesn't get to choose which columns
      # ride through every phase.
      next
    }
    if (is.numeric(ind)) {
      # Fixed depth on every body row — independent of `data`.
      depths <- rep(as.integer(ind), nrow_data)
      prefixes <- .build_indent_prefixes(depths, indent_size)
      out$targets[[length(out$targets) + 1L]] <- list(
        col = nm,
        depth_col = NA_character_,
        prefixes = prefixes,
        depths = depths
      )
      next
    }
    # Character: per-row depth from a data column.
    by <- ind
    if (is.null(data)) {
      # No data to read the depth column from (e.g. a header-only
      # engine call). Skip silently rather than erroring.
      next
    }
    if (!(by %in% names(data))) {
      cli::cli_abort(
        c(
          "{.code col_spec(indent = ...)} references missing column.",
          "x" = "Column {.val {nm}} declares {.code indent = {.val {by}}}, but {.val {by}} is not in {.code spec@data}."
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
    prefixes <- .build_indent_prefixes(depths, indent_size)
    out$targets[[length(out$targets) + 1L]] <- list(
      col = nm,
      depth_col = by,
      prefixes = prefixes,
      depths = depths
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
        class = "tabular_warning_input",
        call = call
      )
    }
    out <- suppressWarnings(as.integer(floor(x)))
    out[is.na(out)] <- 0L
    if (any(out < 0L)) {
      cli::cli_warn(
        "Indent depth column {.val {depth_col}} has negative values; clamped to 0.",
        class = "tabular_warning_input",
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

# Convert a `preset@indent_size` integer count to its monospace
# text-prefix unit (one indent level). `0L` / `NA` / negative all
# yield "" so callers can `nzchar()`-gate on the result without a
# special-case branch. Single source of truth for any code path
# that needs to translate the integer knob into characters for
# `cells_text` (the engine prefix pass, `.indent_host_asts*`,
# `.build_indent_prefixes`, and every backend leading-strip pass).
.indent_text_unit <- function(indent_size) {
  size <- suppressWarnings(as.integer(indent_size))
  if (length(size) != 1L || is.na(size) || size <= 0L) {
    return("")
  }
  strrep(" ", size)
}

# Map an integer depth vector to a parallel character prefix
# vector. Empty string for depth 0; `strrep(indent_unit, N)` for
# depth N, where `indent_unit` is `strrep(" ", indent_size)`. The
# caller injects these on `cells_text[, target]` and on
# `cells_ast[, target]`.
.build_indent_prefixes <- function(depths, indent_size) {
  indent_unit <- .indent_text_unit(indent_size)
  if (!nzchar(indent_unit)) {
    return(rep("", length(depths)))
  }
  vapply(
    depths,
    function(d) {
      if (d <= 0L) {
        return("")
      }
      strrep(indent_unit, d)
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
  cells_indent = NULL,
  row_indices,
  visible_col_names,
  header_row_plan,
  skip_transitions = integer(0L),
  call = rlang::caller_env()
) {
  # `cells_indent` defaults to a zero matrix of the right shape so
  # callers that bypass the engine (older fixtures, ad-hoc test
  # builds) still get a usable sidecar with no native padding.
  if (is.null(cells_indent)) {
    cells_indent <- matrix(
      0L,
      nrow = nrow(cells_text),
      ncol = ncol(cells_text),
      dimnames = list(NULL, colnames(cells_text))
    )
  }

  # Header transitions (drive section-header row injection) and
  # blank transitions (drive blank-row injection) are computed
  # independently. Header transitions are computed PER BAND from
  # `header_row_plan$bands`; the union across bands is used only for
  # the early-return short-circuit and output sizing. Blank
  # transitions come from every group column whose effective
  # `group_skip` resolves TRUE.
  bands <- if (is.null(header_row_plan)) NULL else header_row_plan$bands
  band_transitions_on_page <- if (is.null(bands)) {
    list()
  } else {
    lapply(bands, function(band) intersect(band$transitions, row_indices))
  }
  header_transitions <- unique(unlist(
    band_transitions_on_page,
    use.names = FALSE
  ))
  blank_transitions <- intersect(skip_transitions, row_indices)

  has_header_plan <- !is.null(header_row_plan) &&
    length(header_transitions) > 0L
  has_blank_plan <- length(blank_transitions) > 0L

  if (length(row_indices) == 0L || (!has_header_plan && !has_blank_plan)) {
    return(list(
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      cells_indent = cells_indent,
      is_header_row = rep(FALSE, length(row_indices)),
      is_blank_row = rep(FALSE, length(row_indices)),
      header_meta = vector("list", length(row_indices))
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
  blank_ast <- .parse_inline("", call = call)
  default_node <- style_node()

  n_page <- length(row_indices)
  # Output-row upper bound: data rows + one row per band-transition
  # (some rows have multiple bands firing simultaneously, each gets
  # its own header row) + one blank row per blank-transition. Sum
  # band transition counts; the inner `+ length(blank_transitions)`
  # term handles the blank rows.
  total_header_rows <- sum(vapply(
    band_transitions_on_page,
    length,
    integer(1L)
  ))
  total_out_max <- n_page + total_header_rows + length(blank_transitions)
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
  # Sidecar travels with the matrices. Data rows copy from
  # `cells_indent`; header rows are zero on every column except
  # host_col, where the BAND's own depth lands (band 1 = 0, band 2
  # = 1, ...) so backends can paint the band-N header at the right
  # native padding-left.
  indent_out <- matrix(
    0L,
    nrow = total_out_max,
    ncol = ncol_visible,
    dimnames = list(NULL, visible_col_names)
  )
  is_header_row <- logical(total_out_max)
  is_blank_row <- logical(total_out_max)
  # Per-row provenance for the group-header style stamp: NULL on data /
  # blank rows, list(group_col, data_idx) on each injected header row so
  # `.stamp_group_headers()` can match `cells_group_headers(j = )` against
  # the band's group column and evaluate `where = ` against the source
  # data row.
  header_meta <- vector("list", total_out_max)

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
    # Walk bands in OUTER-to-INNER order; each band that transitions
    # at this row emits its own header row. Multiple bands firing at
    # the same data_idx stack (outer band header, then inner band
    # header, then the data row).
    if (has_header_plan) {
      for (band in bands) {
        if (!(data_idx %in% band$transitions)) {
          next
        }
        out_pos <- out_pos + 1L
        text_out[out_pos, host_idx] <- band$group_values[[data_idx]]
        for (j in seq_len(ncol_visible)) {
          ast_out[[out_pos, j]] <- if (j == host_idx) {
            band$group_asts[[data_idx]]
          } else {
            blank_ast
          }
          style_out[[out_pos, j]] <- default_node
        }
        # Band depth lives on the host column so backends can read
        # `cells_indent[i, host_idx]` and paint native padding.
        # Other columns stay at 0 (the matrix init).
        indent_out[out_pos, host_idx] <- band$depth
        is_header_row[[out_pos]] <- TRUE
        header_meta[[out_pos]] <- list(
          group_col = band$group_col,
          data_idx = data_idx
        )
        first_emit <- FALSE
      }
    }
    out_pos <- out_pos + 1L
    text_out[out_pos, ] <- cells_text[k, ]
    indent_out[out_pos, ] <- cells_indent[k, ]
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
    cells_indent = indent_out[seq_len(total_out), , drop = FALSE],
    is_header_row = is_header_row[seq_len(total_out)],
    is_blank_row = is_blank_row[seq_len(total_out)],
    header_meta = header_meta[seq_len(total_out)]
  )
}
