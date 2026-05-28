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
#   1. engine_sort()      — apply sort_spec to data rows.
#   2. engine_headers()   — validate + flatten spec@headers into a
#                           band grid (rows = header cells).
#   3. engine_style()     — resolve style predicates into a per-cell
#                           style matrix (one style_node per cell).
#   4. engine_format()    — per-column format + NA substitution +
#                           parse_inline() over cells, titles,
#                           footnotes, and col labels.
#   5. engine_decimal()   — column-wide decimal alignment for any
#                           col_spec(align = "decimal").
#   6. engine_paginate()  — split into pages (vertical row chunks +
#                           horizontal panel chunks).
#
# Step 1 mutates the spec (sort reorders @data). Steps 2-5 read from
# the post-sort spec and produce parallel matrices and lists, all
# aligned to the same row order. Step 6 returns a plan that the
# slicer uses to project per-page views of those matrices.

# ---------------------------------------------------------------------
# Public entry
# ---------------------------------------------------------------------

#' Resolve a `tabular_spec` into a `tabular_grid`
#'
#' Runs the full engine pipeline against `spec` and returns the
#' resolved `tabular_grid` — the same intermediate object [`emit()`]
#' hands to a backend. Pure function: no files written, no global
#' state touched. Use this during development to inspect what
#' [`emit()`] will pass downstream, when building a custom backend,
#' or when piping the resolved grid into a non-file consumer (e.g. an
#' inline preview chunk in a Quarto notebook).
#'
#' @details
#'
#' **Engine pipeline order is load-bearing.** Phases run in this
#' fixed order; the order matters because each phase reads the post-
#' previous-phase state of the spec:
#'
#' 1. `engine_sort()` — apply the sort spec.
#' 2. `engine_headers()` — validate the header tree and flatten it
#'    to a band grid.
#' 3. `engine_style()` — evaluate every style predicate against the
#'    post-sort data grid. A predicate may reference any column in
#'    `spec@data`.
#' 4. `engine_format()` — apply per-column formats, substitute
#'    `na_text`, and parse every cell / title / footnote / label
#'    through `parse_inline()` to its `inline_ast`.
#' 5. `engine_decimal()` — column-wide decimal alignment for any
#'    column flagged `col_spec(align = "decimal")`. Operates on the
#'    formatted text; output is the same character matrix with NBSP
#'    padding inserted so the decimal marks line up.
#' 6. `engine_paginate()` — split into pages (vertical row chunks +
#'    horizontal panel chunks). The plan drives the per-page slicing
#'    of cells / styles / ASTs below.
#'
#' **The grid is the backend contract.** Every backend
#' (`backend_md`, future `backend_html`, etc.) consumes a
#' `tabular_grid` — never a `tabular_spec`. New backends only need
#' to walk `grid@pages` and `grid@metadata`; the engine pipeline is
#' a fixed dependency they never re-implement.
#'
#' **No I/O.** `as_grid()` writes nothing to disk and touches no
#' global state. It is safe to call repeatedly during interactive
#' exploration; cost is roughly that of one [`emit()`] without the
#' backend write step.
#'
#' @param spec *The `tabular_spec` to resolve.*
#'   `<tabular_spec>: required`. Built by the verb chain ([`tabular()`]
#'   -> [`cols()`] -> [`headers()`] -> [`sort_rows()`] -> [`style()`]
#'   -> [`paginate()`] -> [`preset()`]).
#'
#' @return *A `tabular_grid` S7 object.* Two slots:
#'   * `@pages` — a list of one entry per display page. Each entry is
#'     a named list with pagination fields (`page_index`,
#'     `panel_index`, `is_continuation`, `continuation`,
#'     `repeat_headers`), row + column slice indices
#'     (`row_indices`, `col_indices`, `col_names`), the sliced
#'     cell text (`cells_text` — character matrix), sliced inline
#'     ASTs (`cells_ast` — list-matrix of [`inline_ast`]), sliced
#'     style nodes (`cells_style` — list-matrix of `style_node`),
#'     and the column-label ASTs for the visible columns
#'     (`col_labels_ast`).
#'   * `@metadata` — per-table information backends consume once per
#'     render: `format` (the resolved backend tag, `NA_character_`
#'     for `as_grid()` calls), `rows_per_page`, `total_pages`,
#'     `total_panels`, `nrow_data`, `ncol_data`, `col_names`, `cols`
#'     (the original [`col_spec()`] entries keyed by column name),
#'     `headers` (the flattened header band grid), `titles`,
#'     `footnotes`, `titles_ast`, `footnotes_ast`, `col_labels_ast`,
#'     `pagehead_ast` / `pagefoot_ast` (resolved page-band content —
#'     `NULL` when the active preset declares no band, otherwise
#'     `list(left, center, right)` of length-N lists of [`inline_ast`]
#'     where N = row count and index 1 is the body-edge row).
#'
#' @examples
#' # ---- Example 1: Demographics — inspect the resolved grid ----
#' #
#' # Resolve the canonical safety-pop demographics pipeline into a
#' # `tabular_grid` and inspect what `emit()` would hand a backend.
#' # The first page's `cells_text` matrix is the decimal-aligned
#' # output as the backend would render it; the metadata carries the
#' # pagination plan + header / title / footnote ASTs.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' demo <- tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Source: ADSL."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' demo_grid <- as_grid(demo)
#' demo_grid@metadata$total_pages
#' demo_grid@pages[[1]]$cells_text[1:3, c("stat_label", "placebo")]
#'
#' # ---- Example 2: AE-by-SOC/PT paginated grid — verify the split ----
#' #
#' # Same shape as Example 1 plus pagination protecting the SOC
#' # grouping. With a tight font size the grid carries multiple page
#' # entries; concatenating each page's `row_indices` reconstructs
#' # the full data, and every page carries the full header band grid
#' # at `grid@metadata$headers` so backends can re-render the header
#' # on every continuation page.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#'
#' ae_spec <- tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(usage = "group", visible = FALSE,
#'                         group_display = "column_repeat"),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   paginate(keep_together = "soc")
#'
#' ae_grid <- as_grid(ae_spec)
#' length(ae_grid@pages)
#'
#' # ---- Example 3: Subgroup partition — one page set per group ----
#' #
#' # When `subgroup()` is attached, `as_grid()` runs the resolve
#' # pipeline once per group and concatenates the pages. `saf_subgroup`
#' # carries `sex` as a natural partition axis; inspect
#' # `@pages[[i]]$subgroup_index` and `@pages[[i]]$subgroup_line_ast`
#' # to confirm each page knows its group identity and banner text.
#' # `sex` auto-hides as the partition `by` column; no explicit
#' # `col_spec(visible = FALSE)` needed.
#' sg_spec <- tabular(saf_subgroup) |>
#'   cols(
#'     agegr      = col_spec(usage = "group", label = "Age Group"),
#'     sex_n      = col_spec(visible = FALSE),
#'     agegr_n    = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic")
#'   ) |>
#'   subgroup("sex")
#'
#' sg_grid <- as_grid(sg_spec)
#' length(sg_grid@pages)
#' vapply(sg_grid@pages, function(p) p$subgroup_index %||% NA_integer_, integer(1))
#'
#' # ---- Example 4: Pre-flight inspection before emit() ----
#' #
#' # Resolve a spec to its grid without writing anywhere. Useful in
#' # tests, for snapshotting cell text under different presets, or
#' # for spec-introspection inside higher-level wrappers that need
#' # to know how many pages a render will produce.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' demog_spec <- tabular(
#'   saf_demo,
#'   titles = "Demographics"
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total      = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   )
#' grid <- as_grid(demog_spec)
#' length(grid@pages)
#' dim(grid@pages[[1]]$cells_text)
#'
#' @seealso
#' **I/O sibling:** [`emit()`] writes the resolved grid to a file
#' via a registered backend; `as_grid()` is the no-I/O entry into
#' the same pipeline.
#'
#' **Build verbs the pipeline feeds from:** [`tabular()`],
#' [`cols()`] / [`col_spec()`], [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' **Inline formatting helpers:** [`md()`], [`html()`].
#'
#' @export
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
#
# When `spec@subgroup` is set, the partition phase splits @data and
# this function runs the rest of the pipeline per sub-spec, then
# merges the resulting page sets into a single `tabular_grid` with
# per-page subgroup runtime annotations. Page numbers reset per
# group; a hard page break between groups falls out naturally from
# the per-spec pagination plans.
.resolve_spec_to_grid <- function(spec, format, call) {
  groups <- engine_subgroup_split(spec)
  if (length(groups) == 1L && is.null(groups[[1L]]$runtime)) {
    return(.resolve_single_to_grid(
      groups[[1L]]$spec,
      format = format,
      call = call,
      runtime = NULL
    ))
  }
  sub_grids <- lapply(groups, function(g) {
    .resolve_single_to_grid(
      g$spec,
      format = format,
      call = call,
      runtime = g$runtime
    )
  })
  .merge_subgroup_grids(sub_grids, format = format, spec = spec)
}

# Resolve a single (sub-)spec into a tabular_grid. `runtime` is the
# per-group annotation from engine_subgroup_split (NULL when the
# parent spec carries no subgroup); when set, every page descriptor
# is stamped with subgroup_* fields and a pre-rendered
# subgroup_line_ast banner.
.resolve_single_to_grid <- function(spec, format, call, runtime) {
  spec <- engine_sort(spec)

  headers <- engine_headers(spec)
  style_mat <- engine_style(spec)
  # engine_borders runs after engine_style so per-cell predicate
  # borders (the user's highest-priority layer via `style(border_
  # <side>_*)`) survive theme-side region stamping. Region values
  # only apply where the predicate layer is silent.
  style_mat <- engine_borders(spec, style_mat)
  # Body-region border manifest (outer edges + row/col separators) —
  # one resolved triple per side. Backends like LaTeX consume this
  # to emit table-level `hline{i}={spec}` / `vline{j}={spec}`
  # directives without inferring from per-cell scalars on cells_style.
  body_borders_mat <- body_border_manifest(spec)
  # Chrome regions (header_*, subgroup_*, footer_*, pagehead_bottom,
  # pagefoot_top) live outside the body-cell matrix; populate the
  # parallel sidecar from the lowered cells_*() chrome layers.
  chrome_style_mat <- engine_chrome_borders(spec)
  fmt <- engine_format(spec)

  # Snapshot of formatted cells BEFORE any cosmetic mutation. The
  # `data_file` QC artefact reads from this — never from
  # post-engine_group_display (which suppresses repeats in column
  # mode) or post-engine_decimal (which pads with NBSP for visual
  # alignment). One character row per source data row, every
  # column from `names(spec@data)`.
  data_cells_text <- fmt$cells_text

  # Apply col_spec@group_display semantics. Header_row mode
  # splices section-header rows above each group-variable
  # transition; column mode suppresses repeats; column_repeat is a
  # no-op. The phase may augment the cells matrices with new
  # synthesised rows + hide source group columns from the visible
  # body. When `header_row` mode is active, every data row's
  # host-column text is prefixed with `strrep(" ", preset@indent_size)`
  # so the data rows visually nest under their synthetic section
  # header.
  gd_preset <- .effective_preset(spec)
  gd <- engine_group_display(
    cells_text = fmt$cells_text,
    cells_ast = fmt$cells_ast,
    cells_style = style_mat,
    cols = .cols_by_name(spec@cols, names(spec@data)),
    data = spec@data,
    indent_size = if (is_preset_spec(gd_preset)) {
      gd_preset@indent_size
    } else {
      preset_spec()@indent_size
    },
    subgroup_hide_cols = .subgroup_auto_hide_cols(spec)
  )
  fmt$cells_text <- gd$cells_text
  fmt$cells_ast <- gd$cells_ast
  style_mat <- gd$cells_style
  cells_indent <- gd$cells_indent
  spec_cols_post <- gd$cols
  # Merge visibility updates back onto spec@cols so downstream
  # `engine_paginate()` (which filters via `.visible_col_names()`)
  # and every backend that consults `spec@cols` directly see the
  # hidden header_row columns.
  spec <- S7::set_props(spec, cols = spec_cols_post)

  cols_named <- spec_cols_post
  # Em-aware decimal alignment when the active preset opts into it
  # via `decimal_metrics = "afm"`. The default "chars" mode keeps
  # the byte-for-byte legacy behaviour (every glyph counts as one
  # NBSP-unit). The AFM mode looks up real glyph widths so the pad
  # count converges on visually-equal slot widths in proportional
  # fonts (Times-Roman, Helvetica).
  decimal_metrics <- .effective_preset(spec)@decimal_metrics
  afm_name <- if (identical(decimal_metrics, "afm")) {
    .resolve_afm_name(.effective_preset(spec)@font_family)
  } else {
    NA_character_
  }
  # Section the decimal aligner on the same group_skip blank-line
  # transitions the body uses, so each block (e.g. continuous stats
  # vs categorical n_pct) aligns in isolation and a continuous
  # decimal slot never leaks onto an integer count in the next block.
  # Empty transitions -> one section -> the historic single-column
  # behaviour. `not_considered` lets the preset's missing-value
  # markers (NR / NE / ...) be shown and slot-aligned.
  decimal_transitions <- gd$skip_transitions %||% integer(0L)
  decimal_sections <- if (length(decimal_transitions) > 0L) {
    .decimal_sections(nrow(fmt$cells_text), decimal_transitions)
  } else {
    NULL
  }
  cells_text <- engine_decimal(
    fmt$cells_text,
    cols = cols_named,
    sections = decimal_sections,
    not_considered = .effective_preset(spec)@decimal_markers,
    metrics = decimal_metrics,
    afm_name = afm_name
  )

  # Resolve col widths via AFM Core 13 metrics (auto sizing).
  # Runs AFTER engine_decimal so prefix-padded values contribute
  # their actual rendered width. `resolved_cols` is the full
  # name-keyed col_spec map (one entry per data column) with every
  # visible width resolved to numeric inches. Backends read this
  # via `grid@metadata$cols`.
  resolved_cols <- .resolve_col_widths(
    spec,
    cells_text = cells_text,
    col_labels_ast = fmt$col_labels_ast,
    cols_override = spec_cols_post
  )

  pag <- engine_paginate(spec)

  pages <- .build_pages(
    pag = pag,
    cells_text = cells_text,
    cells_ast = fmt$cells_ast,
    cells_style = style_mat,
    cells_indent = cells_indent,
    col_labels_ast = fmt$col_labels_ast,
    col_names = names(spec@data),
    header_row_plan = gd$header_row_plan,
    skip_transitions = gd$skip_transitions
  )

  # Stamp per-group subgroup metadata onto every page descriptor.
  # Backends key on `page$subgroup_line_ast` to decide whether to
  # emit the centred banner row above the column-header rule.
  pages <- .stamp_subgroup_runtime(pages, runtime = runtime, call = call)

  # Page chrome (header / footer bands) — resolved against the
  # cascade-effective preset so the session default's pagehead /
  # pagefoot wins when the spec carries no per-call preset. Token
  # substitution for {program} / {datetime} happens inside
  # `.resolve_page_band` before parse_inline runs. {page} /
  # {npages} are deferred to backend emission.
  eff_preset <- .effective_preset(spec)
  pagehead_ast <- .resolve_page_band(
    eff_preset@pagehead,
    arg = "pagehead",
    call = call
  )
  pagefoot_ast <- .resolve_page_band(
    eff_preset@pagefoot,
    arg = "pagefoot",
    call = call
  )

  tabular_grid(
    pages = pages,
    metadata = list(
      format = format,
      rows_per_page = pag$rows_per_page,
      total_pages = pag$total_pages,
      total_panels = pag$total_panels,
      keep_with_next = pag$keep_with_next,
      nrow_data = nrow(spec@data),
      ncol_data = ncol(spec@data),
      col_names = names(spec@data),
      data_cells_text = data_cells_text,
      cols = resolved_cols,
      headers = headers,
      titles = spec@titles,
      footnotes = spec@footnotes,
      titles_ast = fmt$titles_ast,
      footnotes_ast = fmt$footnotes_ast,
      col_labels_ast = fmt$col_labels_ast,
      pagehead_ast = pagehead_ast,
      pagefoot_ast = pagefoot_ast,
      preset = eff_preset,
      chrome_style = chrome_style_mat,
      body_borders = body_borders_mat,
      subgroup_runtime = runtime
    )
  )
}

# Stamp per-group subgroup runtime onto every page in `pages` and
# parse the pre-rendered banner text (produced by
# `.subgroup_render_label()` against the group's first row) into an
# inline_ast every backend can consume directly. When `runtime` is
# NULL, pages pass through unchanged.
.stamp_subgroup_runtime <- function(pages, runtime, call) {
  if (is.null(runtime)) {
    return(pages)
  }
  banner_ast <- parse_inline(runtime$banner_text, call = call)
  lapply(pages, function(p) {
    p$subgroup_by <- runtime$by
    p$subgroup_values <- runtime$values
    p$subgroup_index <- runtime$index
    p$subgroup_total <- runtime$total
    p$subgroup_banner_text <- runtime$banner_text
    p$subgroup_line_ast <- banner_ast
    p
  })
}

# Merge per-group sub-grids into one tabular_grid. Pages
# concatenate in group order; each page keeps its per-group
# page_index (1..rows_per_page) so {page} / {npages} tokens resolve
# to per-group numbering at backend time. Aggregate metadata
# (total_pages, nrow_data) sums across groups; the per-group
# runtime list is published at `metadata$subgroup_groups` for
# backends or downstream tooling that wants to enumerate groups.
.merge_subgroup_grids <- function(sub_grids, format, spec) {
  pages <- unlist(
    lapply(sub_grids, function(g) g@pages),
    recursive = FALSE,
    use.names = FALSE
  )
  first <- sub_grids[[1L]]@metadata
  total_pages <- sum(vapply(
    sub_grids,
    function(g) g@metadata$total_pages,
    integer(1L)
  ))
  nrow_data <- sum(vapply(
    sub_grids,
    function(g) g@metadata$nrow_data,
    integer(1L)
  ))
  subgroup_groups <- lapply(
    sub_grids,
    function(g) g@metadata$subgroup_runtime
  )

  meta <- first
  meta$format <- format
  meta$total_pages <- as.integer(total_pages)
  meta$nrow_data <- as.integer(nrow_data)
  meta$subgroup_runtime <- NULL
  meta$subgroup_groups <- subgroup_groups

  # Restore aggregate ncol_data + col_names from the parent spec so
  # the merged grid reports the unfiltered shape (each sub-spec has
  # the same columns; either is fine, but the parent is canonical).
  meta$ncol_data <- ncol(spec@data)
  meta$col_names <- names(spec@data)

  tabular_grid(
    pages = pages,
    metadata = meta
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

# Map a vector of group_skip transition rows (1-based indices where a
# new block begins) to a length-`n` section id vector for the decimal
# aligner. Each transition row starts a new section; the count rises
# by one at every transition. `c(1, 3)` over n = 4 -> c(1, 1, 2, 2).
.decimal_sections <- function(n, transitions) {
  if (n == 0L) {
    return(integer(0L))
  }
  cumsum(seq_len(n) %in% transitions)
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
  cells_indent = NULL,
  col_labels_ast,
  col_names,
  header_row_plan = NULL,
  skip_transitions = integer(0L)
) {
  lapply(pag$pages, function(p) {
    .slice_one_page(
      p = p,
      cells_text = cells_text,
      cells_ast = cells_ast,
      cells_style = cells_style,
      cells_indent = cells_indent,
      col_labels_ast = col_labels_ast,
      col_names = col_names,
      header_row_plan = header_row_plan,
      skip_transitions = skip_transitions
    )
  })
}

# Slice a single page. The cell / style / indent matrices and the
# col-label list all share the same column-name ordering, so a single
# `col_indices` projection keeps them coherent. When a
# `header_row_plan` is non-NULL, header rows are injected into the
# sliced matrices for any group-value transitions that fall within
# this page's row range. The `cells_indent` sidecar travels through
# unchanged for data rows; injected header / blank rows carry depth 0.
.slice_one_page <- function(
  p,
  cells_text,
  cells_ast,
  cells_style,
  cells_indent = NULL,
  col_labels_ast,
  col_names,
  header_row_plan = NULL,
  skip_transitions = integer(0L)
) {
  ri <- p$row_indices
  ci <- p$col_indices
  visible <- col_names[ci]

  text_slice <- .slice_matrix(cells_text, ri, ci)
  ast_slice <- .slice_list_matrix(cells_ast, ri, ci)
  style_slice <- .slice_list_matrix(cells_style, ri, ci)
  # `cells_indent` is optional — callers that haven't been threaded
  # yet (or fixtures that synthesise pages by hand) get a zero matrix
  # so the sidecar always has the right shape.
  indent_slice <- if (is.null(cells_indent)) {
    matrix(
      0L,
      nrow = length(ri),
      ncol = length(ci),
      dimnames = list(NULL, visible)
    )
  } else {
    .slice_matrix(cells_indent, ri, ci)
  }

  has_any_plan <- !is.null(header_row_plan) || length(skip_transitions) > 0L
  if (has_any_plan) {
    injected <- .inject_header_rows_for_page(
      cells_text = text_slice,
      cells_ast = ast_slice,
      cells_style = style_slice,
      cells_indent = indent_slice,
      row_indices = ri,
      visible_col_names = visible,
      header_row_plan = header_row_plan,
      skip_transitions = skip_transitions
    )
    text_slice <- injected$cells_text
    ast_slice <- injected$cells_ast
    style_slice <- injected$cells_style
    indent_slice <- injected$cells_indent
    is_header_row <- injected$is_header_row
    is_blank_row <- injected$is_blank_row
  } else {
    is_header_row <- rep(FALSE, length(ri))
    is_blank_row <- rep(FALSE, length(ri))
  }

  list(
    page_index = p$page_index,
    panel_index = p$panel_index,
    is_continuation = p$is_continuation,
    continuation = p$continuation,
    repeat_headers = p$repeat_headers,
    row_indices = ri,
    col_indices = ci,
    col_names = visible,
    cells_text = text_slice,
    cells_ast = ast_slice,
    cells_style = style_slice,
    cells_indent = indent_slice,
    is_header_row = is_header_row,
    is_blank_row = is_blank_row,
    host_col = if (is.null(header_row_plan)) {
      NA_character_
    } else {
      header_row_plan$host_col
    },
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
