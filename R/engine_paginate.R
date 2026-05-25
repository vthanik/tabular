# engine_paginate.R — resolve-engine phase that turns a
# pagination_spec into a flat list of page descriptors. Each
# descriptor names the rows and columns that ride on one display
# page. The downstream emit / backend layer iterates over the list
# to render one page at a time.
#
# Row budget is auto-computed (galley model): paper height for the
# active orientation, minus top + bottom margins, minus chrome rows
# (titles + spacing + column-header band + footnotes + spacing),
# divided by the row height at the active body font size. Landscape
# pages naturally carry fewer body rows than portrait at the same
# paper; smaller fonts carry more. Inputs come from the spec's
# preset (or preset_spec defaults) plus the spec's titles, headers,
# and footnotes.
#
# Vertical split: divide rows into chunks of the computed budget,
# adjusting break points so that contiguous runs of identical
# values in `keep_together` group columns are not split. The
# `widow_floor` rule merges a tiny final page back onto the
# previous one. The `orphan_floor` rule is the escape valve when
# a group run is taller than one page.
#
# Horizontal split: when `panels > 1`, divide the non-group
# columns into approximately equal chunks and replicate every
# group column on every panel. Group columns ride on every panel
# for row context.

#' Resolve the pagination spec to a list of page descriptors
#'
#' Pure function. Called by the resolve engine after `engine_style()`
#' and before backend emission. Returns a pagination plan: a list
#' that describes each display page in terms of row indices and
#' column indices into the resolved data.
#'
#' Returned shape:
#' \preformatted{
#' list(
#'   rows_per_page = integer(1),
#'   total_pages   = integer(1),
#'   total_panels  = integer(1),
#'   pages = list(
#'     list(
#'       page_index      = integer(1),
#'       panel_index     = integer(1),
#'       row_indices     = integer(),
#'       col_indices     = integer(),
#'       is_continuation = logical(1),
#'       continuation    = character(0|1),
#'       repeat_headers  = logical(1)
#'     ),
#'     ...
#'   )
#' )
#' }
#'
#' When no `pagination_spec` is attached, the function returns a
#' one-page plan covering every row and column with
#' `is_continuation = FALSE`.
#'
#' @param spec A `tabular_spec`.
#' @return A pagination plan as described above.
#' @keywords internal
#' @noRd
engine_paginate <- function(spec) {
  data <- spec@data
  nrow_data <- nrow(data)
  col_names <- names(data)

  pag <- spec@pagination
  pag_set <- is_pagination_spec(pag)

  orphan <- if (pag_set) pag@orphan_floor else .default_orphan_floor
  widow <- if (pag_set) pag@widow_floor else .default_widow_floor
  panels <- if (pag_set) pag@panels else 1L
  repeat_h <- if (pag_set) pag@repeat_headers else TRUE
  cont <- if (pag_set) pag@continuation else character()
  kt <- if (pag_set) pag@keep_together else character()

  rpp <- .compute_rows_per_page(spec)

  kt_idx <- if (length(kt) > 0L) match(kt, col_names) else integer()

  row_pages <- .compute_vertical_pages(
    nrow_data = nrow_data,
    rpp = rpp,
    kt_idx = kt_idx,
    data = data,
    orphan_floor = orphan,
    widow_floor = widow
  )

  group_cols <- .group_col_names(spec@cols)
  # Filter visible columns BEFORE pagination so the slice phase
  # (`.slice_one_page`) and every backend see only the columns the
  # user wants rendered. Hidden columns (col_spec@visible = FALSE)
  # remain in spec@data for upstream phases (sort_rows / derive /
  # subgroup) but never reach the backend renderer.
  visible_col_names <- .visible_col_names(spec, col_names)
  col_panels <- .compute_horizontal_panels(
    col_names = visible_col_names,
    group_col_names = group_cols,
    panels = panels
  )
  # `.compute_horizontal_panels` returns indices into its
  # `col_names` argument; remap them to indices into the full
  # `col_names` vector so the downstream slice picks the right
  # data / style / label columns.
  visible_indices <- match(visible_col_names, col_names)
  col_panels <- lapply(col_panels, function(idx) visible_indices[idx])

  n_vert <- length(row_pages)
  n_horiz <- length(col_panels)
  total_pages <- n_vert * n_horiz

  pages <- vector("list", total_pages)
  k <- 1L
  for (panel_i in seq_len(n_horiz)) {
    for (vert_i in seq_len(n_vert)) {
      pages[[k]] <- list(
        page_index = vert_i,
        panel_index = panel_i,
        row_indices = row_pages[[vert_i]],
        col_indices = col_panels[[panel_i]],
        is_continuation = vert_i > 1L || panel_i > 1L,
        continuation = cont,
        repeat_headers = repeat_h
      )
      k <- k + 1L
    }
  }

  list(
    rows_per_page = as.integer(rpp),
    total_pages = as.integer(total_pages),
    total_panels = as.integer(n_horiz),
    pages = pages
  )
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Floor for the computed rows-per-page. Below 5, pagination is more
# noise than signal — one big chrome-heavy spec on a tiny font
# could mathematically yield 0; we floor it instead. Matches
# galley's minimum-row constraint.
.min_rows_per_page <- 5L

# Defaults that mirror pagination_spec defaults; used when the spec
# carries no pagination_spec at all.
.default_orphan_floor <- 3L
.default_widow_floor <- 2L

# Compute the per-page body-row budget from the active preset and
# the spec's title / header / footnote chrome. Returns an integer.
.compute_rows_per_page <- function(spec) {
  preset <- .effective_preset(spec)

  dims <- .paper_dims_twips(preset@paper_size, preset@orientation)
  page_height <- dims[["height"]]

  m <- .margin_top_bottom_twips(preset@margins)
  margin_total <- m[["top"]] + m[["bottom"]]

  one_row <- .row_height_twips(preset@font_size)

  n_title_lines <- .count_lines(spec@titles)
  n_footnote_lines <- .count_lines(spec@footnotes)
  n_header_lines <- .count_header_lines(spec)

  # One blank line of separation after the title block (if any) and
  # before the footnote block (if any). Matches galley's spacing
  # convention.
  title_spacing <- if (n_title_lines > 0L) 1L else 0L
  footnote_spacing <- if (n_footnote_lines > 0L) 1L else 0L

  chrome_rows <- n_title_lines +
    title_spacing +
    n_header_lines +
    n_footnote_lines +
    footnote_spacing

  available <- page_height - margin_total - chrome_rows * one_row
  rpp <- as.integer(available %/% one_row)
  max(.min_rows_per_page, rpp)
}

# Count display lines in a character vector, expanding any embedded
# "\n" line breaks. Length-0 input returns 0L.
.count_lines <- function(x) {
  if (length(x) == 0L) {
    return(0L)
  }
  parts <- strsplit(x, "\n", fixed = TRUE)
  sum(vapply(parts, length, integer(1)))
}

# Count header-band rows. Header height is the max embedded-\n line
# count across visible column labels, plus the depth of any
# spanning-header tree. Returns 1L when the spec has no columns yet
# (auto-header band of one line).
.count_header_lines <- function(spec) {
  max_label_lines <- 1L
  cols <- spec@cols
  if (length(cols) > 0L) {
    visible_labels <- vapply(
      cols,
      function(cs) {
        if (isFALSE(cs@visible)) {
          return("")
        }
        lab <- cs@label
        if (is.na(lab)) cs@name else lab
      },
      character(1)
    )
    visible_labels <- visible_labels[nzchar(visible_labels)]
    if (length(visible_labels) > 0L) {
      per_label_lines <- vapply(
        visible_labels,
        function(lbl) length(strsplit(lbl, "\n", fixed = TRUE)[[1L]]),
        integer(1)
      )
      max_label_lines <- max(per_label_lines)
    }
  }

  header_depth <- 0L
  if (length(spec@headers) > 0L) {
    header_depth <- .header_max_depth(spec@headers)
  }
  max_label_lines + header_depth
}

# Recursive max depth of a list of header_node trees. Used to count
# spanner rows above the leaf-column-label row.
.header_max_depth <- function(nodes) {
  if (length(nodes) == 0L) {
    return(0L)
  }
  max(vapply(
    nodes,
    function(node) {
      kids <- node@children
      if (length(kids) == 0L) {
        1L
      } else {
        1L + .header_max_depth(kids)
      }
    },
    integer(1)
  ))
}

# Vertical pagination: return a list of integer vectors, each
# vector the row indices for one page. Honours `keep_together`
# (move break back to start of straddling group) and `widow_floor`
# (merge a tiny final page into the previous one).
.compute_vertical_pages <- function(
  nrow_data,
  rpp,
  kt_idx,
  data,
  orphan_floor,
  widow_floor
) {
  if (nrow_data == 0L) {
    return(list(integer()))
  }
  if (nrow_data <= rpp) {
    return(list(seq_len(nrow_data)))
  }

  pages <- list()
  start <- 1L
  while (start <= nrow_data) {
    tentative_end <- min(start + rpp - 1L, nrow_data)

    if (length(kt_idx) > 0L && tentative_end < nrow_data) {
      adjusted_end <- .respect_keep_together(
        start = start,
        tentative_end = tentative_end,
        kt_idx = kt_idx,
        data = data
      )
      if (adjusted_end >= start + orphan_floor - 1L) {
        tentative_end <- adjusted_end
      }
    }

    pages[[length(pages) + 1L]] <- seq.int(start, tentative_end)
    start <- tentative_end + 1L
  }

  n <- length(pages)
  if (n >= 2L && length(pages[[n]]) < widow_floor) {
    pages[[n - 1L]] <- c(pages[[n - 1L]], pages[[n]])
    pages[[n]] <- NULL
  }

  pages
}

# Move the tentative page break back if it would split a contiguous
# run of identical values in `keep_together` columns. Returns the
# adjusted page-end row index. If the run extends back past `start`
# (the entire page is one big run), returns the original
# `tentative_end` so the caller's orphan-floor escape can trigger.
.respect_keep_together <- function(start, tentative_end, kt_idx, data) {
  if (tentative_end + 1L > nrow(data)) {
    return(tentative_end)
  }

  key_at <- function(i) {
    parts <- vapply(
      kt_idx,
      function(j) as.character(data[i, j]),
      character(1)
    )
    paste(parts, collapse = "\x1f")
  }

  end_key <- key_at(tentative_end)
  next_key <- key_at(tentative_end + 1L)
  if (end_key != next_key) {
    return(tentative_end)
  }

  i <- tentative_end - 1L
  while (i >= start && key_at(i) == end_key) {
    i <- i - 1L
  }
  if (i < start) {
    return(tentative_end)
  }
  i
}

# Filter `col_names` to those whose `col_spec@visible` is TRUE.
# Columns absent from `spec@cols` (no col_spec set) default to
# visible. Used by engine_paginate to drop hidden columns BEFORE
# the slice phase; this is the single point that enforces
# `col_spec(visible = FALSE)` across every backend.
.visible_col_names <- function(spec, col_names) {
  cols <- spec@cols
  keep <- vapply(
    col_names,
    function(nm) {
      cs <- cols[[nm]]
      if (!is_col_spec(cs)) {
        return(TRUE)
      }
      isTRUE(cs@visible)
    },
    logical(1L)
  )
  col_names[keep]
}

# Horizontal pagination: split non-group columns into approximately
# equal slices; repeat group columns on every panel. Returns a list
# of integer column-index vectors — one per panel.
.compute_horizontal_panels <- function(col_names, group_col_names, panels) {
  ncol_data <- length(col_names)
  if (ncol_data == 0L) {
    return(list(integer()))
  }
  if (identical(panels, "auto")) {
    return(list(seq_len(ncol_data)))
  }
  panels_int <- as.integer(panels)
  if (panels_int <= 1L) {
    return(list(seq_len(ncol_data)))
  }

  group_idx <- match(intersect(group_col_names, col_names), col_names)
  group_idx <- group_idx[!is.na(group_idx)]
  non_group_idx <- setdiff(seq_len(ncol_data), group_idx)

  if (length(non_group_idx) == 0L) {
    return(list(seq_len(ncol_data)))
  }

  n_eff <- min(panels_int, length(non_group_idx))
  chunk_id <- .equal_chunks(length(non_group_idx), n_eff)
  chunks <- split(non_group_idx, chunk_id)

  lapply(chunks, function(ng) sort(c(group_idx, ng)))
}

# Assign 1..n positions into `k` approximately equal chunks; returns
# an integer vector of length n with values in 1..k. Used to split
# non-group columns across panels without leaning on a heavy stats
# helper.
.equal_chunks <- function(n, k) {
  base <- n %/% k
  rem <- n %% k
  sizes <- rep(base, k) + c(rep(1L, rem), rep(0L, k - rem))
  rep(seq_len(k), sizes)
}
