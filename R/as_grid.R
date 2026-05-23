# as_grid.R — public entry to the resolve engine. Composes every
# engine_* phase into one pure function that returns a fully
# resolved `tabular_grid`: a per-page list of cell texts, parsed
# inline ASTs, per-cell style nodes, and the flattened header band
# grid, plus metadata the backends need (rows_per_page, total_pages,
# titles_ast, footnotes_ast, col_labels_ast, ...). No I/O.
#
# `as_grid()` is the no-I/O sibling of `emit()`: it produces exactly
# the same intermediate object that `emit()` hands to a backend, so
# users can inspect what tabular intends to render before committing
# to a file, and tests can pin grid shapes without round-tripping
# through a backend writer.
#
# Pipeline order (locked):
#
#   1. engine_derive()    — materialise derived columns onto spec@data.
#   2. engine_sort()      — apply sort_spec to data rows.
#   3. engine_headers()   — validate + flatten spec@headers into a
#                           band grid (rows = header cells).
#   4. engine_style()     — resolve style predicates into a per-cell
#                           style matrix (one style_node per cell).
#   5. engine_format()    — per-column format + NA substitution +
#                           parse_inline() over cells, titles,
#                           footnotes, and col labels.
#   6. engine_decimal()   — column-wide decimal alignment for any
#                           col_spec(align = "decimal").
#   7. engine_paginate()  — split into pages (vertical row chunks +
#                           horizontal panel chunks).
#
# Steps 1-2 mutate the spec (data widened by derives, then sorted).
# Steps 3-6 read from the post-derive/post-sort spec and produce
# parallel matrices and lists, all aligned to the same row order.
# Step 7 returns a plan that the slicer uses to project per-page
# views of those matrices.

# ---------------------------------------------------------------------
# Public entry
# ---------------------------------------------------------------------

#' Resolve a `tabular_spec` into a `tabular_grid`
#'
#' Runs the full engine pipeline against `spec` and returns the
#' resolved `tabular_grid` — the same intermediate object `emit()`
#' hands to a backend. Pure function: no files written, no global
#' state touched.
#'
#' @param spec A `tabular_spec` built via [`tabular()`] and the
#'   downstream verb chain.
#' @return A `tabular_grid` whose `@pages` is a list of one entry per
#'   display page and whose `@metadata` carries the per-table
#'   information (headers, titles_ast, footnotes_ast, col_names,
#'   rows_per_page, total_pages, total_panels, ...). Each page entry
#'   is a named list:
#'   * `page_index`, `panel_index`, `is_continuation`, `continuation`,
#'     `repeat_headers` — pagination plan from [`paginate()`].
#'   * `row_indices`, `col_indices` — integer indices into the
#'     resolved data.
#'   * `col_names` — character vector of data columns visible on
#'     this page (subset of `metadata$col_names`).
#'   * `cells_text` — character matrix sliced to `[row_indices,
#'     col_indices]`.
#'   * `cells_ast` — list-matrix of `inline_ast` sliced to the same
#'     shape.
#'   * `cells_style` — list-matrix of `style_node` sliced to the same
#'     shape.
#'   * `col_labels_ast` — named list of `inline_ast` sliced to the
#'     visible columns.
#' @export
#' @examples
#' # ---- Example 1: demographics grid ----
#' #
#' # Resolve the canonical safety-pop demographics table into a
#' # grid you can inspect before emitting. The grid is what every
#' # backend consumes; printing the first page's cell matrix shows
#' # exactly what the table will look like.
#' spec <- tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics", "Safety Population"),
#'   footnotes = "Source: ADSL."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = "Placebo\nN=86",   align = "decimal"),
#'     drug_50  = col_spec(label = "Low Dose\nN=96",  align = "decimal"),
#'     drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN=254",    align = "decimal")
#'   )
#' grid <- as_grid(spec)
#' grid@metadata$total_pages
#' grid@pages[[1]]$cells_text[1:3, ]
#'
#' # ---- Example 2: paginated safety AE-by-SOC/PT grid ----
#' #
#' # Same shape; with pagination the grid carries multiple page
#' # entries, each with its own sliced cell matrix. The header band
#' # grid lives at the grid-level metadata, not per-page.
#' ae <- tabular(
#'   saf_aesocpt,
#'   titles = c("Table 14.3.1", "AE by SOC and Preferred Term"),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "System Organ Class"),
#'     pt       = col_spec(label = "Preferred Term"),
#'     placebo  = col_spec(label = "Placebo\nN=86",   align = "decimal"),
#'     drug_50  = col_spec(label = "Low Dose\nN=96",  align = "decimal"),
#'     drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN=254",    align = "decimal")
#'   ) |>
#'   paginate(keep_together = "soc")
#' ae_grid <- as_grid(ae)
#' length(ae_grid@pages)
as_grid <- function(spec) {
  call <- rlang::caller_env()
  check_tabular_spec(spec, call = call)
  .resolve_spec_to_grid(spec, format = NA_character_, call = call)
}

# ---------------------------------------------------------------------
# Engine pipeline
# ---------------------------------------------------------------------

# Compose every engine_* phase. Returns a fully populated
# `tabular_grid`. `format` is stamped into metadata so emit() can
# carry the resolved backend tag through to the manifest layer;
# `as_grid()` (no I/O) passes NA_character_.
.resolve_spec_to_grid <- function(spec, format, call) {
  spec <- engine_derive(spec)
  spec <- engine_sort(spec)

  headers <- engine_headers(spec)
  style_mat <- engine_style(spec)
  fmt <- engine_format(spec)

  cols_named <- .cols_named_for_decimal(spec)
  cells_text <- engine_decimal(
    fmt$cells_text,
    cols = cols_named
  )

  pag <- engine_paginate(spec)

  pages <- .build_pages(
    pag = pag,
    cells_text = cells_text,
    cells_ast = fmt$cells_ast,
    cells_style = style_mat,
    col_labels_ast = fmt$col_labels_ast,
    col_names = names(spec@data)
  )

  tabular_grid(
    pages = pages,
    metadata = list(
      format = format,
      rows_per_page = pag$rows_per_page,
      total_pages = pag$total_pages,
      total_panels = pag$total_panels,
      nrow_data = nrow(spec@data),
      ncol_data = ncol(spec@data),
      col_names = names(spec@data),
      headers = headers,
      titles = spec@titles,
      footnotes = spec@footnotes,
      titles_ast = fmt$titles_ast,
      footnotes_ast = fmt$footnotes_ast,
      col_labels_ast = fmt$col_labels_ast
    )
  )
}

# Build the name-keyed col_spec map engine_decimal expects. Only
# user-declared col_specs are forwarded; default-only columns
# (engine_format synthesises a default col_spec internally for those)
# never need decimal alignment, so leaving them absent here is the
# right thing — engine_decimal's loop skips entries that are not
# col_spec objects, matching the smoke-test pattern.
.cols_named_for_decimal <- function(spec) {
  cols <- spec@cols
  if (length(cols) == 0L) {
    return(list())
  }
  cols
}

# ---------------------------------------------------------------------
# Page slicing
# ---------------------------------------------------------------------

# Project the cell / ast / style matrices and the col-label list to
# each page's (row_indices, col_indices) view, attach the
# pagination-plan fields, and return a list of page descriptors.
.build_pages <- function(
  pag,
  cells_text,
  cells_ast,
  cells_style,
  col_labels_ast,
  col_names
) {
  lapply(pag$pages, function(p) {
    .slice_one_page(
      p = p,
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      col_labels_ast = col_labels_ast,
      col_names = col_names
    )
  })
}

# Slice a single page. The cell / style matrices and the col-label
# list all share the same column-name ordering, so a single
# `col_indices` projection keeps them coherent.
.slice_one_page <- function(
  p,
  cells_text,
  cells_ast,
  cells_style,
  col_labels_ast,
  col_names
) {
  ri <- p$row_indices
  ci <- p$col_indices
  visible <- col_names[ci]

  list(
    page_index = p$page_index,
    panel_index = p$panel_index,
    is_continuation = p$is_continuation,
    continuation = p$continuation,
    repeat_headers = p$repeat_headers,
    row_indices = ri,
    col_indices = ci,
    col_names = visible,
    cells_text = .slice_matrix(cells_text, ri, ci),
    cells_ast = .slice_list_matrix(cells_ast, ri, ci),
    cells_style = .slice_list_matrix(cells_style, ri, ci),
    col_labels_ast = col_labels_ast[visible]
  )
}

# Slice a character matrix by row + column indices, preserving the
# dimnames. Empty row or column selections preserve a zero-extent
# matrix of the correct shape (backends iterate by seq_len; an empty
# matrix is a no-op there).
.slice_matrix <- function(mat, ri, ci) {
  mat[ri, ci, drop = FALSE]
}

# Slice a list-matrix (a list with a `dim` attribute) the same way.
# `[` on a list with `dim` works exactly like matrix subsetting.
.slice_list_matrix <- function(mat, ri, ci) {
  mat[ri, ci, drop = FALSE]
}
