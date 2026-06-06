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
#' @param .spec *The `tabular_spec` to resolve.*
#'   `<tabular_spec>: required`. Built by the verb chain ([`tabular()`]
#'   -> [`cols()`] -> [`headers()`] -> [`sort_rows()`] -> [`style()`]
#'   -> [`paginate()`] -> [`preset()`]).
#'
#' @return *A `tabular_grid` S7 object.* Two slots:
#'   * `@pages` — a list of one entry per display page. Each entry is
#'     a named list with pagination fields (`page_index`,
#'     `panel_index`, `is_continuation`, `continuation`,
#'     `show_titles`, `repeat_headers`, `show_footnotes_here`),
#'     row + column slice indices
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
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' demo <- tabular(
#'   cdisc_saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     "Safety Population"
#'   ),
#'   footnotes = "Source: ADSL."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
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
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' ae <- cdisc_saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#'
#' ae_spec <- tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     "Safety Population"
#'   ),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level"),
#'     soc      = col_spec(usage = "group", visible = FALSE,
#'                         group_display = "column_repeat"),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
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
#' # pipeline once per group and concatenates the pages. `cdisc_saf_subgroup`
#' # carries `sex` as a natural partition axis; inspect
#' # `@pages[[i]]$subgroup_index` and `@pages[[i]]$subgroup_line_ast`
#' # to confirm each page knows its group identity and banner text.
#' # `sex` auto-hides as the partition `by` column; no explicit
#' # `col_spec(visible = FALSE)` needed.
#' sg_spec <- tabular(cdisc_saf_subgroup) |>
#'   cols(
#'     sex_n      = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
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
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' demog_spec <- tabular(
#'   cdisc_saf_demo,
#'   titles = "Demographics"
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal"
#'     ),
#'     Total      = col_spec(
#'       label = "Total\nN={n['Total']}",
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
as_grid <- function(.spec) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  .resolve_spec_to_grid(.spec, format = NA_character_, call = call)
}

# ---------------------------------------------------------------------
# Engine pipeline
# ---------------------------------------------------------------------

# Backends that paginate the body themselves (the consuming application
# decides vertical page breaks) receive an UNSPLIT grid: one vertical
# page per `(subgroup x horizontal panel)`. The RTF backend emits one
# continuous Word table per panel with `\trhdr` repeating header rows;
# the LaTeX backend emits one `longtblr` per panel (tabularray paginates
# the body, `rowhead` repeats the header band, and a keep-with-next mask
# drives `\\*`); DOCX reuses this hook, emitting one `<w:tbl>` per panel
# with Word repeating the `<w:tblHeader/>` rows. Every other backend (and
# `as_grid()` with `format = NA`) keeps tabular's estimated vertical split.
.native_pagination_formats <- c("rtf", "latex", "docx")

# Continuous, scrollable backends have no fixed page width, so a
# horizontal `panels = N` split is meaningless: the engine collapses it
# to one all-columns table (stub once, original order) and reports the
# would-be boundaries via `panel_spans` for a header note. HTML and
# Markdown only. `as_grid()` (format = NA) is neither native nor
# continuous, so introspection still shows the full split.
.continuous_formats <- c("html", "md")

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
  # Finalize boundary (A): resolve the NA "unset" col_spec sentinels
  # (visible / group_display / usage) to concrete defaults on spec@cols
  # before any engine phase or backend reads it. engine_borders and
  # engine_paginate read spec@cols directly (with isTRUE / identical),
  # and engine_borders runs before the visibility merge-back, so a raw
  # default col_spec (visible = NA) must already read as TRUE here.
  # Boundary (B) is inside `.cols_by_name()` for the synthesized defaults
  # of unlisted columns, which never appear in spec@cols.
  #
  # F3: warn (once per render) about inert group_display / group_skip on
  # non-group columns BEFORE finalize, while the "was it set" signal
  # (group_display NA = unset) still survives.
  .warn_inert_group_knobs(spec@cols, call)
  spec <- S7::set_props(spec, cols = .finalize_col_specs(spec@cols))
  groups <- engine_subgroup_split(spec)
  # Assign footnote markers ONCE, at the spec level, in reading order
  # across the full data (subgroup-major), so the marker at every anchor
  # is byte-identical across subgroups and pages. NULL when the spec
  # carries no `footnote()` refs (every downstream helper is a no-op).
  registry <- engine_footnotes_assign(spec, groups, call)
  if (length(groups) == 1L && is.null(groups[[1L]]$runtime)) {
    return(.resolve_single_to_grid(
      groups[[1L]]$spec,
      format = format,
      call = call,
      runtime = NULL,
      registry = registry
    ))
  }
  # Per-page BigN: each sub-grid's leaf labels + header bands carry
  # that subgroup's `(N=x)` suffix (paged backends read them per page).
  # The GLOBAL header must stay un-suffixed so the continuous backends
  # (HTML/MD) and the DOCX top header show clean arm names. Compute the
  # base (un-suffixed) labels + bands from the PARENT spec, where the
  # footnote `registry` is in scope, so column-label superscripts
  # survive onto the global header.
  #
  # Computed BEFORE the sub-grid loop on purpose: `engine_headers(spec)`
  # runs the band-contiguity check against the user's ORIGINAL band
  # labels, so a non-contiguous band aborts naming "Placebo", not the
  # engine-suffixed "Placebo (N=24)" a sub-spec would surface first.
  base_labels <- NULL
  base_headers <- NULL
  if (!is.null(spec@subgroup) && !is.null(spec@subgroup@big_n)) {
    base_cols <- .cols_by_name(spec@cols, names(spec@data))
    base_labels <- engine_footnotes_mark_ast(
      .parse_col_labels(base_cols, names(spec@data), call),
      NULL,
      registry,
      names(spec@data)
    )$col_labels_ast
    base_headers <- engine_headers(spec)
  }

  sub_grids <- lapply(groups, function(g) {
    .resolve_single_to_grid(
      g$spec,
      format = format,
      call = call,
      runtime = g$runtime,
      registry = registry
    )
  })

  .merge_subgroup_grids(
    sub_grids,
    format = format,
    spec = spec,
    base_col_labels_ast = base_labels,
    base_headers = base_headers
  )
}

# Resolve a single (sub-)spec into a tabular_grid. `runtime` is the
# per-group annotation from engine_subgroup_split (NULL when the
# parent spec carries no subgroup); when set, every page descriptor
# is stamped with subgroup_* fields and a pre-rendered
# subgroup_line_ast banner.
.resolve_single_to_grid <- function(
  spec,
  format,
  call,
  runtime,
  registry = NULL
) {
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

  # Footnotes — AST surfaces (column labels / titles) get a native
  # superscript run now (never touched by decimal); the marked-footnote
  # block is appended to `footnotes_ast` once. Identical across every
  # subgroup, so the first-subgroup-only grid merge carries it correctly.
  # Body-cell markers are stamped later, after engine_decimal. All
  # no-ops when `registry` is NULL.
  fn_ast <- engine_footnotes_mark_ast(
    fmt$col_labels_ast,
    fmt$titles_ast,
    registry,
    names(spec@data)
  )
  fmt$col_labels_ast <- fn_ast$col_labels_ast
  fmt$titles_ast <- fn_ast$titles_ast
  fmt$footnotes_ast <- engine_footnotes_append_block(
    fmt$footnotes_ast,
    registry
  )

  # Snapshot of formatted cells BEFORE any cosmetic mutation. The
  # `data_file` QC artefact reads from this — never from
  # post-engine_group_display (which suppresses repeats in column
  # mode) or post-engine_decimal (which pads with NBSP for visual
  # alignment). One character row per source data row, every
  # column from `names(spec@data)`.
  data_cells_text <- fmt$cells_text

  # Apply per-cell pretext / posttext literal decorations from the
  # resolved style cascade. Done after the `data_file` snapshot (so the
  # QC artefact stays decoration-free) and before engine_group_display
  # (so the affix flows through repeat-suppression / indent / header
  # injection and is measured by engine_decimal + column widths).
  fmt <- .apply_affixes(fmt, style_mat, call = call)

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

  # Stamp footnote markers on body cells AFTER decimal alignment (so the
  # padded field is never disturbed) and BEFORE width measurement (so
  # the column reserves room for the superscript). Anchors resolve
  # against this (sub)grid's data; the marker glyph comes from the
  # spec-level registry. No-op when `registry` is NULL.
  cells_text <- engine_footnotes_mark_body(
    cells_text,
    registry,
    data = spec@data,
    col_names = names(spec@data),
    call = call
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
    cols_override = spec_cols_post,
    cells_style = style_mat
  )

  # Native-pagination backends (RTF/Word, LaTeX, DOCX) receive an unsplit
  # grid: one vertical page per panel, so the consumer paginates the body
  # and the `\trhdr` / `<w:tblHeader/>` header repeats natively.
  # Continuous backends (HTML / Markdown) collapse the horizontal panel
  # split into one all-columns table + a header note. `as_grid()`
  # (format = NA) is neither, so it keeps the full split for inspection.
  native <- isTRUE(format %in% .native_pagination_formats)
  continuous <- isTRUE(format %in% .continuous_formats)
  pag <- engine_paginate(spec, native = native, continuous = continuous)

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

  # Attach a per-rendered-row keep vector to every page WHILE
  # `pag$keep_with_next` is still group-local (each sub-spec resolves
  # independently). Native backends read `page$keep_with_next` to drive
  # `\trkeep` / `\keepn`; doing it here keeps subgroups correct without an
  # out-of-bounds guard against the merged (first-subgroup-only) metadata
  # mask.
  pages <- .attach_keep_with_next(pages, pag$keep_with_next)

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

  # Group-header styling: route `cells_group_headers()` cascade layers
  # onto the synthesized section-header rows. Runs BEFORE the stripe so
  # an explicit `cells_group_headers(background = ...)` is set first and
  # the stripe's `is.na(bg)` guard then leaves it alone (explicit wins).
  # `bold = FALSE` here is what `preset_minimal()` uses to render section
  # labels in normal weight.
  pages <- .stamp_group_headers(
    pages,
    .collect_group_header_layers(spec),
    spec@data,
    call = call
  )

  # Zebra striping: stamp the resolved stripe fill onto cell backgrounds
  # wherever no explicit background is already set, so every backend
  # renders it via its per-cell background path. Synthesised group-header
  # and blank-separator rows are striped too (they inherit the fill of
  # the data block they introduce / precede) so the bands read as
  # continuous with no white gaps; the parity counter still advances on
  # DATA rows only, so the zebra never desyncs. `stripe = NULL` (the
  # default) leaves the pages untouched.
  pages <- .stamp_stripe(pages, resolve_stripe(eff_preset@stripe))

  tabular_grid(
    pages = pages,
    metadata = list(
      format = format,
      rows_per_page = pag$rows_per_page,
      total_pages = pag$total_pages,
      total_panels = pag$total_panels,
      panel_spans = pag$panel_spans,
      keep_with_next = pag$keep_with_next,
      repeat_titles = pag$repeat_titles,
      repeat_headers = pag$repeat_headers,
      repeat_footnotes = pag$repeat_footnotes,
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
      spacing = resolve_spacing(eff_preset@spacing),
      gaps = gap_counts(eff_preset@spacing),
      stripe = resolve_stripe(eff_preset@stripe),
      subgroup_runtime = runtime
    )
  )
}

# Prepend `pretext` / append `posttext` to every cell whose resolved
# style node carries one. Updates BOTH the character matrix (consumed by
# every backend's plain-cell path + engine_decimal + col widths) and the
# AST matrix (consumed when a cell carries md() / html() runs). Affixes
# may themselves be md() / html()-wrapped: the text path strips the
# inline marker so width / decimal measure the displayed glyphs, while
# the AST path parses each affix to its own runs and splices them on.
# `style_mat` is the post-engine_borders matrix, index-aligned 1:1 with
# `fmt$cells_text` / `fmt$cells_ast` (same shape + column dimnames).
.apply_affixes <- function(fmt, style_mat, call) {
  ct <- fmt$cells_text
  ca <- fmt$cells_ast
  if (is.null(style_mat) || nrow(ct) == 0L || ncol(ct) == 0L) {
    return(fmt)
  }
  for (j in seq_len(ncol(ct))) {
    for (i in seq_len(nrow(ct))) {
      sn <- style_mat[[i, j]]
      if (!is_style_node(sn)) {
        next
      }
      pre <- sn@pretext
      post <- sn@posttext
      has_pre <- length(pre) == 1L && !is.na(pre)
      has_post <- length(post) == 1L && !is.na(post)
      if (!has_pre && !has_post) {
        next
      }
      if (has_pre) {
        ct[i, j] <- paste0(.strip_inline_marker(pre), ct[[i, j]])
      }
      if (has_post) {
        ct[i, j] <- paste0(ct[[i, j]], .strip_inline_marker(post))
      }
      runs <- ca[[i, j]]@runs
      if (has_pre) {
        runs <- c(parse_inline(pre, call = call)@runs, runs)
      }
      if (has_post) {
        runs <- c(runs, parse_inline(post, call = call)@runs)
      }
      ca[[i, j]] <- inline_ast(runs = runs)
    }
  }
  fmt$cells_text <- ct
  fmt$cells_ast <- ca
  fmt
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

# Attach a per-rendered-row keep-with-next logical to every page. The
# engine's `keep_mask` is indexed by SOURCE data row (post-sort,
# pre-injection); this maps it onto the page's RENDERED rows (which
# interleave injected section-header and blank rows). Walk each page's
# rendered rows, advancing a pointer into `row_indices` only on data rows
# (a row is synthetic iff `is_header_row` or `is_blank_row`):
#
#   - data row          -> keep_mask[row_indices[ptr]]  (group glue)
#   - section-header row -> TRUE                          (never orphan a
#                                                          header from its
#                                                          first child)
#   - blank row          -> FALSE                         (natural break)
#
# The final rendered row of every page is forced FALSE (nothing follows
# it on the page). Called per (sub-)spec while `keep_mask` is still
# group-local, so subgroup grids stay correct.
.attach_keep_with_next <- function(pages, keep_mask) {
  lapply(pages, function(p) {
    n_rendered <- nrow(p$cells_text)
    if (is.null(n_rendered) || n_rendered == 0L) {
      p$keep_with_next <- logical(0L)
      return(p)
    }
    is_hdr <- p$is_header_row %||% rep(FALSE, n_rendered)
    is_blk <- p$is_blank_row %||% rep(FALSE, n_rendered)
    ri <- p$row_indices
    keep <- logical(n_rendered)
    ptr <- 0L
    for (r in seq_len(n_rendered)) {
      if (isTRUE(is_blk[[r]])) {
        keep[[r]] <- FALSE
      } else if (isTRUE(is_hdr[[r]])) {
        keep[[r]] <- TRUE
      } else {
        ptr <- ptr + 1L
        src <- if (ptr <= length(ri)) ri[[ptr]] else NA_integer_
        keep[[r]] <- !is.na(src) &&
          src <= length(keep_mask) &&
          isTRUE(keep_mask[[src]])
      }
    }
    keep[[n_rendered]] <- FALSE
    p$keep_with_next <- keep
    p
  })
}

# Resolve the header band frame + column-label AST a backend should
# render for one page/segment. Shared by the RTF, LaTeX, and DOCX
# header renderers so the per-page BigN read is identical across them.
#
#   * Bands ride `page$headers` (stamped per subgroup in the merge, the
#     SUFFIXED frame under big_n). `%||%` is safe ungated: a page only
#     carries `$headers` on a subgroup table, where it is content-equal
#     to the base bands when big_n is off (a distinct but equal frame),
#     so the rendered output is unchanged.
#   * Leaf labels stay flag-gated: every page (subgroup or not) carries
#     a visible-sliced `$col_labels_ast`, so reading it unconditionally
#     would change non-subgroup output. Only read it when big_n is on.
#
# @keywords internal
# @noRd
.page_header_for_render <- function(meta, page) {
  list(
    headers = page$headers %||% meta$headers,
    col_labels_ast = if (isTRUE(meta$subgroup_big_n_active)) {
      page$col_labels_ast
    } else {
      meta$col_labels_ast
    }
  )
}

# Group a flat page list into the render segments a paged backend
# emits as one continuous table each. Shared by the RTF, LaTeX, and
# DOCX panel renderers so the segmentation rule lives in one place.
#
#   * `by_subgroup = TRUE` (RTF / LaTeX, and DOCX under per-page BigN):
#     key by `(subgroup_index, panel_index)` so every subgroup is its
#     own table.
#   * `by_subgroup = FALSE` (DOCX without big_n): key by `panel_index`
#     only, so subgroups stay inline in one table per panel.
#
# Each group's pages are returned in `page_index` order. Group order
# follows first appearance of each key (subgroup-major, since the
# merged page list is subgroup-major).
#
# @keywords internal
# @noRd
.group_pages_into_panels <- function(pages, by_subgroup = TRUE) {
  if (length(pages) == 0L) {
    return(list())
  }
  keys <- vapply(
    pages,
    function(p) {
      panel <- as.integer(p$panel_index %||% 1L)
      if (by_subgroup) {
        sprintf("%d\x1f%d", as.integer(p$subgroup_index %||% 0L), panel)
      } else {
        sprintf("%d", panel)
      }
    },
    character(1L)
  )
  lapply(unique(keys), function(k) {
    grp <- pages[keys == k]
    idx <- vapply(
      grp,
      function(p) as.integer(p$page_index %||% 1L),
      integer(1L)
    )
    grp[order(idx)]
  })
}

# Merge per-group sub-grids into one tabular_grid. Pages
# concatenate in group order; each page keeps its per-group
# page_index (1..rows_per_page) so {page} / {npages} tokens resolve
# to per-group numbering at backend time. Aggregate metadata
# (total_pages, nrow_data) sums across groups; the per-group
# runtime list is published at `metadata$subgroup_groups` for
# backends or downstream tooling that wants to enumerate groups.
.merge_subgroup_grids <- function(
  sub_grids,
  format,
  spec,
  base_col_labels_ast = NULL,
  base_headers = NULL
) {
  # Stamp each page with its own subgroup's header band frame (the
  # SUFFIXED bands when big_n is active), the same per-page model as
  # `col_labels_ast`. Backends read `page$headers` directly, so there
  # is one source of truth per header element and no index-keyed
  # lookup to drift. For a subgroup table WITHOUT big_n every group's
  # bands are content-equal, so `page$headers` renders identically to
  # the global `headers` (a distinct but equal frame).
  #
  # `page$subgroup_bign` rides the same per-page model: the per-arm N
  # records for the continuous-backend N row (one list per subgroup,
  # keyed to the page's group via `runtime$index`). NULL without big_n,
  # so HTML / md skip the row and render byte-identically.
  # Constant fold: HTML / md show the N once in the suffixed column
  # header (kept on `meta` below), so there are no per-arm N records to
  # build or stamp. Decide once and skip the record build entirely.
  constant_fold <- !is.null(base_col_labels_ast) &&
    .subgroup_bign_constant(spec)
  bign_records <- if (constant_fold) {
    NULL
  } else {
    .subgroup_bign_records_all(spec)
  }
  pages <- unlist(
    lapply(sub_grids, function(g) {
      bands <- g@metadata$headers
      recs <- if (is.null(bign_records)) {
        NULL
      } else {
        bign_records[[g@metadata$subgroup_runtime$index]]
      }
      lapply(g@pages, function(p) {
        p$headers <- bands
        p$subgroup_bign <- recs
        p
      })
    }),
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

  # Per-page BigN: the per-subgroup treatment stays active for BOTH the
  # folded and the unfolded case so every paged backend agrees, each
  # subgroup is its own table with the banner above the header band and
  # the suffixed header printed per page. The only difference is where
  # the N surfaces:
  #
  #   * Varying BigN: force the GLOBAL leaf labels + bands back to the
  #     un-suffixed base so the continuous backends (HTML/MD) and the
  #     DOCX top header show clean arm names; the N rides the per-arm
  #     `(N=x)` row. The SUFFIXED per-subgroup bands + leaf labels ride
  #     the page descriptors, which paged backends read per page.
  #   * Constant fold: keep the SUFFIXED header `meta` already holds from
  #     the first sub-grid (every subgroup is content-equal), so the N
  #     folds into the single column header once. No per-arm records were
  #     built, so HTML / md emit no repeated `(N=x)` row.
  if (!is.null(base_col_labels_ast)) {
    meta$subgroup_big_n_active <- TRUE
    if (!constant_fold) {
      meta$col_labels_ast <- base_col_labels_ast
      meta$headers <- base_headers
    }
  }

  # Restore aggregate ncol_data + col_names from the parent spec so
  # the merged grid reports the unfiltered shape (each sub-spec has
  # the same columns; either is fine, but the parent is canonical).
  meta$ncol_data <- ncol(spec@data)
  meta$col_names <- names(spec@data)

  # Reassemble the QC snapshot across ALL subgroups. `first` carries
  # only the first subgroup's rows, so without this the
  # `emit(data_file=)` double-programming artefact is silently
  # truncated to one group while reporting the full nrow_data.
  dct <- Filter(
    Negate(is.null),
    lapply(sub_grids, function(g) g@metadata$data_cells_text)
  )
  if (length(dct) > 0L) {
    meta$data_cells_text <- do.call(rbind, dct)
  }

  # Each subgroup resolved its own auto column widths, but the merged
  # grid renders every subgroup from this single `cols` spec. Widen
  # each column to the widest subgroup so a later group's content is
  # not crammed into the first group's (narrower) column.
  meta$cols <- .merge_subgroup_col_widths(sub_grids, first$cols)

  tabular_grid(
    pages = pages,
    metadata = meta
  )
}

# Per-column max of the resolved auto widths across subgroups. The
# merged grid carries one width per column for every subgroup, so the
# width must fit the widest group's content. Non-numeric / unresolved
# widths are ignored (the base spec's value is kept).
.merge_subgroup_col_widths <- function(sub_grids, base_cols) {
  if (length(base_cols) == 0L) {
    return(base_cols)
  }
  for (nm in names(base_cols)) {
    widths <- vapply(
      sub_grids,
      function(g) {
        cs <- g@metadata$cols[[nm]]
        if (is.null(cs)) {
          return(NA_real_)
        }
        w <- cs@width
        if (length(w) == 1L && is.numeric(w) && !is.na(w)) w else NA_real_
      },
      numeric(1L)
    )
    if (any(!is.na(widths))) {
      base_cols[[nm]] <- S7::set_props(
        base_cols[[nm]],
        width = max(widths, na.rm = TRUE)
      )
    }
  }
  base_cols
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
# Stamp the resolved zebra `stripe` (`c(odd, even)` fills, NA = none)
# onto data-row cell backgrounds. Synthetic header / blank rows are
# skipped; the odd / even parity counts data rows continuously across
# pages. An explicit per-cell background (from the `colors` knob /
# `style()`) is never overwritten -- the stripe is a default fill only.
# Collect every `cells_group_headers()` style layer in the three-tier
# cascade, in priority order (session preset -> spec preset -> per-spec
# layers; later layers win per attribute). Mirrors
# `.collect_chrome_layers()` in R/engine_borders.R but for the
# `group_headers` surface, which `engine_style()` deliberately drops
# (those rows do not exist until pagination). Returns an ordered list.
.collect_group_header_layers <- function(spec) {
  sources <- list()
  session <- get_preset()
  if (is_preset_spec(session)) {
    sources <- c(sources, session@style)
  }
  if (is_preset_spec(spec@preset)) {
    sources <- c(sources, spec@preset@style)
  }
  if (is_style_spec(spec@styles)) {
    sources <- c(sources, spec@styles@layers)
  }
  if (length(sources) == 0L) {
    return(list())
  }
  keep <- vapply(
    sources,
    function(layer) {
      loc <- layer@location
      !is.null(loc) && identical(loc$surface, "group_headers")
    },
    logical(1L)
  )
  sources[keep]
}

# Stamp the resolved `cells_group_headers()` cascade onto the synthetic
# section-header rows. Header rows are injected at pagination with an
# all-NA `style_node`; this is where their style override lands (the
# backends then read the host cell's node, NA bold == bold, FALSE ==
# off). Mirrors `.stamp_stripe()`: post-pagination, per-cell merge that
# only overrides non-NA incoming fields (so it never clobbers a stripe
# background).
#
# Each layer is resolved ONCE up front (not per row): `j` to a set of
# column names, `where` to a single vectorized `logical(nrow(data))`
# mask via the same one-shot eval `engine_style()` uses. Per header row
# then collapses to a band-column membership test plus a mask index --
# no predicate eval, no allocation, in the page/row loops.
.stamp_group_headers <- function(
  pages,
  layers,
  data,
  call = rlang::caller_env()
) {
  if (length(layers) == 0L || length(pages) == 0L) {
    return(pages)
  }
  col_names <- names(data)
  # Pre-resolve every layer's column + row predicates once.
  resolved <- lapply(layers, function(layer) {
    loc <- layer@location
    cols_mask <- if (is.null(loc$j)) {
      NULL
    } else {
      col_names[.resolve_layer_cols(loc, col_names, call = call)]
    }
    where_mask <- if (is.null(loc$where)) {
      NULL
    } else {
      .group_header_where_mask(loc$where, data, call = call)
    }
    list(style = layer@style, cols_mask = cols_mask, where_mask = where_mask)
  })

  for (pi in seq_along(pages)) {
    mat <- pages[[pi]]$cells_style
    if (is.null(mat) || nrow(mat) == 0L || ncol(mat) == 0L) {
      next
    }
    is_hdr <- pages[[pi]]$is_header_row %||% rep(FALSE, nrow(mat))
    meta <- pages[[pi]]$header_meta %||% vector("list", nrow(mat))
    for (r in seq_len(nrow(mat))) {
      if (!isTRUE(is_hdr[[r]])) {
        next
      }
      m <- meta[[r]]
      for (res in resolved) {
        if (
          !is.null(res$cols_mask) &&
            !(is.list(m) && m$group_col %in% res$cols_mask)
        ) {
          next
        }
        if (
          !is.null(res$where_mask) &&
            !(is.list(m) && isTRUE(res$where_mask[[m$data_idx]]))
        ) {
          next
        }
        for (cn in colnames(mat)) {
          sn <- mat[[r, cn]]
          if (!is_style_node(sn)) {
            sn <- style_node()
          }
          mat[[r, cn]] <- .merge_style_node(sn, res$style)
        }
      }
    }
    pages[[pi]]$cells_style <- mat
  }
  pages
}

# Evaluate a `cells_group_headers(where = )` predicate against the
# source data, returning a `logical(nrow(data))` mask. Reuses the
# `engine_style()` contract: `.eval_style_where()` for the data-mask
# eval, length-1 recycling, and a `tabular_error_input` on a
# non-logical result.
.group_header_where_mask <- function(quo, data, call) {
  result <- .eval_style_where(quo, data, call = call)
  if (!is.logical(result)) {
    cli::cli_abort(
      c(
        "{.fn cells_group_headers} {.arg where} must evaluate to a logical vector.",
        "x" = "Got {.obj_type_friendly {result}} of length {length(result)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(result) == 1L && nrow(data) > 1L) {
    result <- rep(result, nrow(data))
  }
  if (length(result) != nrow(data)) {
    cli::cli_abort(
      c(
        "{.fn cells_group_headers} {.arg where} returned length {length(result)}, expected {nrow(data)}.",
        "i" = "The expression must evaluate to a length-{.code nrow} logical vector (or length 1)."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  result
}

.stamp_stripe <- function(pages, stripe) {
  if (is.null(stripe) || length(pages) == 0L) {
    return(pages)
  }
  data_idx <- 0L
  for (pi in seq_along(pages)) {
    mat <- pages[[pi]]$cells_style
    if (is.null(mat) || nrow(mat) == 0L || ncol(mat) == 0L) {
      next
    }
    is_hdr <- pages[[pi]]$is_header_row %||% rep(FALSE, nrow(mat))
    is_blk <- pages[[pi]]$is_blank_row %||% rep(FALSE, nrow(mat))
    for (r in seq_len(nrow(mat))) {
      is_special <- isTRUE(is_hdr[[r]]) || isTRUE(is_blk[[r]])
      if (is_special) {
        # A group-header / blank row inherits the fill of the data block
        # it introduces / precedes: the parity of the NEXT data row
        # (`data_idx + 1`). The counter itself does NOT advance here, so
        # the zebra stays locked to the data and the band reads as one
        # continuous colour with no white gap.
        fill <- if ((data_idx + 1L) %% 2L == 1L) {
          stripe[["odd"]]
        } else {
          stripe[["even"]]
        }
      } else {
        data_idx <- data_idx + 1L
        fill <- if (data_idx %% 2L == 1L) {
          stripe[["odd"]]
        } else {
          stripe[["even"]]
        }
      }
      if (is.na(fill)) {
        next
      }
      for (cn in colnames(mat)) {
        sn <- mat[[r, cn]]
        if (!is_style_node(sn)) {
          sn <- style_node()
        }
        bg <- sn@background
        if (length(bg) == 0L || is.na(bg)) {
          mat[[r, cn]] <- S7::set_props(sn, background = fill)
        }
      }
    }
    pages[[pi]]$cells_style <- mat
  }
  pages
}

# Safe lookup of one physical inter-section gap (from `gap_counts()`)
# off grid metadata. `meta$gaps` is absent on hand-built fixtures and
# NA-keyed gaps fall back to `default`. Backends use this as the
# blank-line fallback so the `spacing` knob (which feeds `meta$gaps`)
# drives inter-section spacing, while a per-surface `style()` blank
# count still overrides it.
.meta_gap <- function(meta, key, default = 0L) {
  g <- meta$gaps
  if (is.null(g) || is.null(g[[key]]) || is.na(g[[key]])) {
    return(as.integer(default))
  }
  as.integer(g[[key]])
}

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
    header_meta <- injected$header_meta
  } else {
    is_header_row <- rep(FALSE, length(ri))
    is_blank_row <- rep(FALSE, length(ri))
    header_meta <- vector("list", length(ri))
  }

  list(
    page_index = p$page_index,
    panel_index = p$panel_index,
    is_continuation = p$is_continuation,
    continuation = p$continuation,
    show_titles = p$show_titles,
    repeat_headers = p$repeat_headers,
    show_footnotes_here = p$show_footnotes_here,
    row_indices = ri,
    col_indices = ci,
    col_names = visible,
    cells_text = text_slice,
    cells_ast = ast_slice,
    cells_style = style_slice,
    cells_indent = indent_slice,
    is_header_row = is_header_row,
    is_blank_row = is_blank_row,
    header_meta = header_meta,
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
