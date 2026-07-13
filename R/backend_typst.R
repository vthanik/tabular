# backend_typst.R — Typst backend using the native `#table` element.
# Consumes a resolved `tabular_grid` and writes a self-contained UTF-8
# `.typ` document that compiles standalone via `typst compile` (or
# `quarto typst compile`; Quarto >= 1.4 bundles the typst binary).
# Typst >= 0.11 is the floor — every construct below exists there.
#
# Why native `#table`. Typst's built-in table gives regulatory-grade
# tables everything the LaTeX backend gets from tabularray, natively:
#
# * **Repeating chrome** via `table.header(repeat: true)` /
#   `table.footer(repeat:)` — titles, header bands, and footnotes
#   replay on every physical page while typst paginates the body.
# * **Per-cell colspan** via `table.cell(colspan: N)` for header
#   bands, group-header rows, and the subgroup banner.
# * **Scoped rules** via `table.hline(start:, end:)` and
#   `table.vline(x:, start:, end:)` — declarative, pagination-aware.
# * **Per-cell fills and strokes** via `table.cell(fill:, stroke:)` —
#   typst renders per-cell body borders the LaTeX backend cannot.
# * **Page chrome** via `#set page(header:, footer:)` with
#   `context counter(page)` for `{page}` / `{npages}` tokens.
#
# Output layout — ONE `#table` per (subgroup x panel) group, with
# `#pagebreak()` between groups. Typst paginates the body natively; the
# title block rides the repeating `table.header` (one full-span cell) and
# the footnotes ride `table.footer`. This mirrors the LaTeX backend's
# longtblr model (one environment per group, head/foot templates).
#
# KNOWN DEVIATIONS from the LaTeX backend (documented, by design):
#
# * **No per-row keep-with-next.** Typst's `#table` has no analogue of
#   longtblr's `\\*` no-break row terminator (RTF `\keepn`, DOCX
#   `keepNext`), so the engine's keep mask is not enforced: a group
#   header may land as the last row of a page. Revisit when typst gains
#   row grouping (typst repo discussion on row-level orphan control).
# * **Continuation marker is panel-level.** The repeating header is
#   identical on every page, so the `paginate(continuation=)` marker
#   appears on continuation PANELS only (RTF-tier capability), not on
#   every continued physical page (LaTeX-tier).
# * **Spanner underline trim is inset-based.** The band underline is a
#   `#line(length: 100%)` inside the spanning cell, so it is trimmed by
#   the cell's horizontal inset at BOTH ends (HTML's inset-gradient
#   tier); LaTeX keeps outer edges flush via cmidrule `leftpos`/`rightpos`.
#
# Inline ASTs (cell text, titles, footnotes, col labels) render through
# `.render_typst_inline()` — a recursive walker over `inline_ast@runs`:
#
#   plain    -> escaped text (typst markup specials backslash-escaped)
#   bold     -> #strong[...]
#   italic   -> #emph[...]
#   sup      -> #super[...]
#   sub      -> #sub[...]
#   code     -> #raw("...")          (flattened text; typst raw font)
#   link     -> #link("url")[...]
#   span     -> children only        (parity with the LaTeX renderer)
#   newline  -> ` \ `                (typst linebreak)

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a self-contained UTF-8 .typ file. Called by
# `emit()` via the backend registry. Returns the file path
# invisibly.
backend_typst <- function(grid, file) {
  lines <- if (identical(grid@metadata$content_type, "figure")) {
    .render_typst_figure(grid, file)
  } else {
    .render_typst_doc(grid)
  }
  writeLines(lines, file, useBytes = FALSE)
  invisible(file)
}

# ---------------------------------------------------------------------
# Document shell + page composition
# ---------------------------------------------------------------------

# Compose the full Typst document: prelude (`#set` rules) + per-panel
# table blocks. Returns a character vector of lines ready for
# `writeLines()`. Pure — no I/O.
.render_typst_doc <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  meta <- grid@metadata
  cs <- meta$chrome_style %||% chrome_style()

  prelude <- .typst_prelude(
    preset = meta$preset,
    pagehead_ast = meta$pagehead_ast,
    pagefoot_ast = meta$pagefoot_ast,
    cs = cs
  )

  if (total == 0L) {
    return(c(prelude, .render_typst_empty(grid)))
  }

  # No long-table warning here: the LaTeX backend warns because
  # tabularray re-measures the whole buffered body (super-linear compile
  # cost); typst's layout engine has no such pathology.

  panels <- .group_pages_into_panels(pages)
  body <- list()
  for (k in seq_along(panels)) {
    if (k > 1L) {
      body[[length(body) + 1L]] <- "#pagebreak()"
    }
    body[[length(body) + 1L]] <- .render_typst_panel(panels[[k]], meta, cs)
  }
  c(prelude, unlist(body, use.names = FALSE))
}

# ---------------------------------------------------------------------
# Figure rendering (metadata$content_type == "figure")
# ---------------------------------------------------------------------

# Compose a figure document: the same prelude (page chrome) as a table,
# then one page per plot with the title block, the `#image()` of an
# image SIDECAR written next to the `.typ`, and the footnote block.
# `#v(1fr)` glue around the image carries valign (it absorbs whatever
# slack remains, so the figure can never overflow the page — the same
# rationale as the LaTeX backend's `\vfill`); `#align()` carries halign.
# `#pagebreak()` separates pages. Writes the sidecars as a side effect
# (the PDF compile resolves them source-relative; a `.typ` emit keeps
# them next to the file).
.render_typst_figure <- function(grid, file) {
  meta <- grid@metadata
  pages <- grid@pages
  cs <- meta$chrome_style %||% chrome_style()
  prelude <- .typst_prelude(
    preset = meta$preset,
    pagehead_ast = meta$pagehead_ast,
    pagefoot_ast = meta$pagefoot_ast,
    cs = cs
  )

  stem <- tools::file_path_sans_ext(basename(file))
  out_dir <- dirname(file)
  sidecars <- character(0)

  blank_line <- .typst_blank_line(meta$preset)
  pad_above_title <- .chrome_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_to_body <- .chrome_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )
  pad_body_to_foot <- .chrome_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )

  body <- list()
  for (i in seq_along(pages)) {
    pg <- pages[[i]]
    if (i > 1L) {
      body[[length(body) + 1L]] <- "#pagebreak()"
    }
    sidecar_name <- sprintf("%s-fig%d.%s", stem, i, pg$image_ext)
    writeBin(pg$image_bytes, file.path(out_dir, sidecar_name))
    sidecars <- c(sidecars, file.path(out_dir, sidecar_name))
    title_block <- .typst_title_block(
      pg$titles_ast,
      preset = meta$preset,
      cs = cs
    )
    title_part <- if (length(title_block) > 0L) {
      c(
        rep(blank_line, pad_above_title),
        title_block,
        rep(blank_line, pad_title_to_body)
      )
    } else {
      character()
    }
    foot_block <- .typst_footnote_block(
      pg$footnotes_ast,
      preset = meta$preset,
      cs = cs
    )
    foot_part <- if (length(foot_block) > 0L) {
      c(rep(blank_line, pad_body_to_foot), foot_block)
    } else {
      character()
    }
    body[[length(body) + 1L]] <- c(
      title_part,
      .typst_figure_image_block(pg, sidecar_name),
      foot_part
    )
  }

  .figure_inform_sidecars(out_dir, sidecars, ".typ")
  c(prelude, unlist(body, use.names = FALSE))
}

# One figure image placed in the page's body with `#v(1fr)` glue.
#
# valign maps to the glue around the image: top = image then #v(1fr)
# (image rides the top, footnotes pushed to the page bottom); middle =
# glue on both sides; bottom = #v(1fr) then image. halign rides
# `#align()`. `fit: "contain"` is the keepaspectratio safety net (the
# drawn dims already match the image aspect). Fractional glue absorbs
# whatever slack remains, so the figure can never overflow the page.
.typst_figure_image_block <- function(pg, sidecar_name) {
  place <- pg$place %||% list(halign = "center", valign = "middle")
  halign <- .typst_halign(place$halign %||% "center")
  img <- sprintf(
    "#align(%s)[#image(\"%s\", width: %sin, height: %sin, fit: \"contain\")]",
    halign,
    .typst_escape_str(sidecar_name),
    .typst_num(round(pg$draw_w_in, 2L)),
    .typst_num(round(pg$draw_h_in, 2L))
  )
  switch(
    place$valign %||% "middle",
    top = c(img, "#v(1fr)"),
    bottom = c("#v(1fr)", img),
    c("#v(1fr)", img, "#v(1fr)")
  )
}

# Render the Typst skeleton for a spec whose grid has zero pages
# (empty data + no body content). Titles + footnotes still appear;
# the table block is replaced with a centred empty-state message so
# the reader sees the table exists but is empty.
.render_typst_empty <- function(grid) {
  meta <- grid@metadata
  cs <- meta$chrome_style %||% chrome_style()
  msg <- if (is.null(meta$empty_text_ast)) {
    .tabular_empty_text_default
  } else {
    .render_typst_inline(meta$empty_text_ast)
  }
  c(
    .typst_title_block(meta$titles_ast, preset = meta$preset, cs = cs),
    .typst_blank_line(meta$preset),
    sprintf("#align(center)[%s]", msg),
    .typst_blank_line(meta$preset),
    .typst_footnote_block(
      meta$footnotes_ast,
      preset = meta$preset,
      cs = cs
    )
  )
}

# Render one panel as ONE `#table`. The title block rides the repeating
# `table.header` (so it repeats on every physical page while typst
# paginates the body) and the footnotes ride `table.footer`;
# `#pagebreak()` between panels is emitted by the caller.
.render_typst_panel <- function(panel_pages, meta, cs) {
  first <- panel_pages[[1L]]

  # Default to "everything repeats" (the regulatory norm) when a grid
  # carries no repeat flags (e.g. a hand-built fixture).
  rep_titles <- meta$repeat_titles %||% TRUE
  rep_footnotes <- meta$repeat_footnotes %||% TRUE

  is_cont_panel <- isTRUE((first$panel_index %||% 1L) > 1L)
  continuation <- first$continuation %||% character()
  body <- .concat_panel_body(panel_pages)

  # Titles that must NOT repeat are emitted once before the table;
  # repeating titles ride the header block inside the table.
  pre_table <- character()
  titles_in_header <- isTRUE(rep_titles)
  if (!titles_in_header && length(meta$titles_ast) > 0L) {
    pad_top <- .chrome_blank_count(
      cs,
      "title",
      "above",
      .meta_gap(meta, "above_title", 1L)
    )
    pad_bottom <- .chrome_blank_count(
      cs,
      "title",
      "below",
      .meta_gap(meta, "title_to_body", 1L)
    )
    blank_line <- .typst_blank_line(meta$preset)
    pre_table <- c(
      rep(blank_line, pad_top),
      .typst_title_block(meta$titles_ast, preset = meta$preset, cs = cs),
      rep(blank_line, pad_bottom)
    )
  }

  tbl <- .render_typst_table(
    first,
    meta,
    cs,
    body = body,
    titles_in_header = titles_in_header,
    rep_footnotes = rep_footnotes,
    is_cont_panel = is_cont_panel,
    continuation = continuation
  )
  c(pre_table, tbl)
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line renders bold with the alignment cascade
# (`chrome_style$surfaces$title@halign` wins; else the preset title
# halign; default centre). Consecutive lines sharing one alignment join
# into a single `#align()[.. \ ..]` block so they stack at the normal
# line pitch (typst inserts block spacing BETWEEN `#align` blocks, so
# per-line blocks would read double-spaced; a mixed-alignment title
# gains that block gap only at the alignment changes).
.typst_title_block <- function(titles_ast, preset = NULL, cs = NULL) {
  n <- length(titles_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  ws_preserve <- .preset_ws_preserve(preset)
  haligns <- character(n)
  bodies <- character(n)
  for (i in seq_len(n)) {
    haligns[[i]] <- if (
      is_style_node(surface_node) &&
        length(surface_node@halign) == 1L &&
        !is.na(surface_node@halign)
    ) {
      surface_node@halign
    } else {
      h <- .effective_title_halign(preset, line_index = i, n_lines = n)
      if (is.na(h)) "center" else h
    }
    inner <- .render_typst_inline(titles_ast[[i]], preserve = ws_preserve)
    if (
      !(is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE))
    ) {
      inner <- paste0("#strong[", inner, "]")
    }
    bodies[[i]] <- .typst_wrap_text_props(inner, surface_node)
  }
  lines <- .typst_aligned_lines(bodies, haligns)
  # Title borders ride the block edges as full-width rules (top above
  # the first line, bottom below the last). NULL / no border => no rule.
  c(
    .typst_rule_line(.effective_border("top", surface_node)),
    lines,
    .typst_rule_line(.effective_border("bottom", surface_node))
  )
}

# Footnote block: each footnote line renders at LaTeX-`\small` scale
# (0.9em) with the alignment cascade (`chrome_style$surfaces$footer`
# wins; else the preset footnote halign; default left). Same-alignment
# grouping as the title block.
.typst_footnote_block <- function(
  footnotes_ast,
  preset = NULL,
  cs = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  ws_preserve <- .preset_ws_preserve(preset)
  haligns <- character(n)
  bodies <- character(n)
  for (i in seq_len(n)) {
    haligns[[i]] <- if (
      is_style_node(surface_node) &&
        length(surface_node@halign) == 1L &&
        !is.na(surface_node@halign)
    ) {
      surface_node@halign
    } else {
      h <- .effective_footnote_halign(preset, line_index = i, n_lines = n)
      if (is.na(h)) "left" else h
    }
    bodies[[i]] <- .typst_wrap_text_props(
      .render_typst_inline(footnotes_ast[[i]], preserve = ws_preserve),
      surface_node
    )
  }
  # `0.9em` is the LaTeX `\small` ratio at the standard class sizes
  # (10pt -> 9pt). The `#[ ... ]` content block SCOPES the `#set` — at
  # the document top level (figure / empty-state pages) an unscoped set
  # would shrink everything after it.
  c(
    "#[",
    "#set text(size: 0.9em)",
    .typst_aligned_lines(bodies, haligns),
    "]"
  )
}

# Group consecutive same-alignment lines into single `#align()` blocks
# joined by typst linebreaks, so a homogeneous block (the common case)
# stacks at the normal line pitch.
.typst_aligned_lines <- function(bodies, haligns) {
  runs <- .group_contiguous_runs(haligns)
  out <- character()
  cursor <- 1L
  for (run in runs) {
    idx <- seq.int(cursor, cursor + run$length - 1L)
    out <- c(
      out,
      sprintf(
        "#align(%s)[%s]",
        .typst_halign(run$value),
        paste(bodies[idx], collapse = " \\ ")
      )
    )
    cursor <- cursor + run$length
  }
  out
}

# One full-height blank line: vertical space equal to the body line
# pitch (font size x the shared baseline ratio). The typst analogue of
# the LaTeX `{\strut\par}` blank line.
.typst_blank_line <- function(preset) {
  sprintf("#v(%spt)", .typst_num(.typst_line_pt(preset)))
}

# Body line pitch in points.
.typst_line_pt <- function(preset) {
  size <- if (is_preset_spec(preset)) {
    as.numeric(.effective_font_size(preset))
  } else {
    NA_real_
  }
  if (length(size) != 1L || !is.finite(size)) {
    size <- .latex_default_class_pt
  }
  round(size * .tabular_baseline_ratio, 2L)
}

# ---------------------------------------------------------------------
# Table assembly: the #table element
# ---------------------------------------------------------------------

# Render one panel's table as a `#table(...)` block. Typst paginates the
# body natively and replays `table.header` on every page.
.render_typst_table <- function(
  page,
  meta,
  cs = NULL,
  body = NULL,
  titles_in_header = TRUE,
  rep_footnotes = TRUE,
  is_cont_panel = FALSE,
  continuation = character()
) {
  col_names_vis <- page$col_names
  cols <- meta$cols %||% list()
  n_cols <- length(col_names_vis)

  src <- body %||%
    list(
      cells_text = page$cells_text,
      cells_style = page$cells_style,
      cells_indent = page$cells_indent,
      is_header_row = page$is_header_row,
      is_blank_row = page$is_blank_row,
      host_col = page$host_col,
      keep_with_next = page$keep_with_next
    )

  # Per-page BigN: one table per subgroup, so read that subgroup's
  # SUFFIXED bands + leaf labels from the page descriptor via the shared
  # resolver. Inert (global metadata) without big_n.
  page_hdr <- .page_header_for_render(meta, page)

  header_block <- .typst_header_block(
    page = page,
    meta = meta,
    cs = cs,
    page_headers = page_hdr$headers,
    page_col_labels_ast = page_hdr$col_labels_ast,
    col_names_vis = col_names_vis,
    cols = cols,
    titles_in_header = titles_in_header,
    is_cont_panel = is_cont_panel,
    continuation = continuation
  )

  body_rows <- if (isTRUE(page$is_empty_page)) {
    # Zero-row page: the body is ONE full-span, horizontally centred
    # message row, so the empty page renders as a normal short table.
    .typst_empty_message_row(meta, n_cols)
  } else {
    .render_typst_body_rows(
      src$cells_text,
      col_names_vis = col_names_vis,
      cells_style = src$cells_style,
      cells_indent = src$cells_indent,
      is_header_row = src$is_header_row,
      is_blank_row = src$is_blank_row,
      cols = cols,
      preset = meta$preset,
      body_valign = .typst_body_valign(meta$preset),
      rows_triple = if (is.list(meta$body_borders)) {
        meta$body_borders$rows
      } else {
        NULL
      }
    )
  }

  # Body bottom closer (the SSOT bottomrule / an explicit outer_bottom
  # border): a positional hline after the last body row, drawn once at
  # the true table end (parity with tabularray's hline{nrow + 1}).
  bottom_rule <- character()
  if (
    is.list(meta$body_borders) && !is.null(meta$body_borders$outer_bottom)
  ) {
    stroke <- .typst_stroke(meta$body_borders$outer_bottom)
    if (!is.null(stroke)) {
      bottom_rule <- sprintf("  table.hline(stroke: %s),", stroke)
    }
  }

  vlines <- .typst_vline_directives(
    meta$body_borders,
    n_cols = n_cols,
    n_title_rows = header_block$n_title_rows,
    n_header_rows = header_block$n_rows,
    nrow_body = body_rows$n_rows
  )

  footer_block <- .typst_footer_block(
    meta,
    cs,
    n_cols = n_cols,
    rep_footnotes = rep_footnotes
  )

  inset_arg <- .typst_table_inset(src$cells_style, meta$preset)
  args <- c(
    sprintf("  columns: %s,", .typst_columns(col_names_vis, cols)),
    sprintf(
      "  align: %s,",
      .typst_align_array(col_names_vis, cols, meta$preset)
    ),
    "  stroke: none,",
    if (length(inset_arg) > 0L) sprintf("  inset: %s,", inset_arg)
  )

  c(
    "#table(",
    args,
    header_block$lines,
    vlines,
    body_rows$lines,
    bottom_rule,
    footer_block,
    ")"
  )
}

# One full-span, horizontally centred empty-state message row for a
# zero-row page, occupying the body slot of the normal `#table`.
.typst_empty_message_row <- function(meta, n_cols) {
  msg <- if (is.null(meta$empty_text_ast)) {
    .tabular_empty_text_default
  } else {
    .render_typst_inline(meta$empty_text_ast)
  }
  list(
    lines = sprintf(
      "  %s,",
      .typst_cell(
        msg,
        colspan = if (n_cols > 1L) n_cols else NULL,
        align = "center + top"
      )
    ),
    n_rows = 1L
  )
}

# Table-level body row baseline valign from the preset (cascade default
# top), as the typst keyword.
.typst_body_valign <- function(preset) {
  v <- .preset_align(preset, "body_valign")
  if (is.na(v)) {
    v <- "top"
  }
  .typst_valign(v)
}

# ---------------------------------------------------------------------
# Repeating header block: titles + banner + bands + column labels
# ---------------------------------------------------------------------

# Build the `table.header(repeat: true, ...)` block. Row anatomy (each
# a full-width element):
#
#   1. title cell        — ONE spanning cell carrying the continuation
#                          marker + every title line + blank-line pads
#                          (only when `titles_in_header`)
#   2. [outer frame top] — body_borders$outer_top hline (above banner)
#   3. banner cell       — ONE spanning cell: blank pads + subgroup
#                          banner text
#   4. header_top hline  — full-width rule on top of the band
#   5. band rows         — spanner cells; the underline is a
#                          `#line(length: 100%)` INSIDE each spanning
#                          cell (trimmed by the cell inset at both ends)
#   6. column-labels row
#   7. header_bottom hline
#
# Returns `list(lines, n_rows, n_title_rows)`; the row counts feed the
# vline start/end computation so vertical rules skip the title band and
# the footer (parity with LaTeX, where titles/footnotes live outside
# the table).
.typst_header_block <- function(
  page,
  meta,
  cs,
  page_headers,
  page_col_labels_ast,
  col_names_vis,
  cols,
  titles_in_header = TRUE,
  is_cont_panel = FALSE,
  continuation = character()
) {
  n_cols <- length(col_names_vis)
  out <- character()
  n_rows <- 0L
  n_title_rows <- 0L

  # -- title cell ------------------------------------------------------
  cont_text <- if (length(continuation) > 0L) {
    as.character(continuation)[[1L]]
  } else {
    ""
  }
  cont_marker <- if (isTRUE(is_cont_panel) && nzchar(cont_text)) {
    sprintf("#align(left)[#emph[%s]]", .typst_escape(cont_text))
  } else {
    character()
  }
  title_lines <- if (titles_in_header) {
    .typst_title_block(meta$titles_ast, preset = meta$preset, cs = cs)
  } else {
    character()
  }
  if (length(title_lines) > 0L || length(cont_marker) > 0L) {
    pad_top <- .chrome_blank_count(
      cs,
      "title",
      "above",
      .meta_gap(meta, "above_title", 1L)
    )
    pad_bottom <- .chrome_blank_count(
      cs,
      "title",
      "below",
      .meta_gap(meta, "title_to_body", 1L)
    )
    blank_line <- .typst_blank_line(meta$preset)
    content <- c(
      if (length(title_lines) > 0L) rep(blank_line, pad_top),
      cont_marker,
      title_lines,
      if (length(title_lines) > 0L) rep(blank_line, pad_bottom)
    )
    out <- c(
      out,
      sprintf(
        "    %s,",
        .typst_cell(
          # Newline-joined: `#set` lines inside the block need a line
          # break before the following markup.
          paste(content, collapse = "\n"),
          colspan = if (n_cols > 1L) n_cols else NULL,
          align = "left + top",
          inset = "(left: 0pt, right: 0pt, top: 0pt, bottom: 0pt)"
        )
      )
    )
    n_rows <- n_rows + 1L
    n_title_rows <- 1L
  }

  # -- outer frame top (above the banner + band, below the titles) -----
  if (is.list(meta$body_borders) && !is.null(meta$body_borders$outer_top)) {
    stroke <- .typst_stroke(meta$body_borders$outer_top)
    if (!is.null(stroke)) {
      out <- c(out, sprintf("    table.hline(stroke: %s),", stroke))
    }
  }

  # -- subgroup banner cell ---------------------------------------------
  banner <- .typst_subgroup_banner_cell(
    page$subgroup_line_ast,
    n_cols = n_cols,
    meta = meta,
    cs = cs
  )
  if (length(banner) > 0L) {
    out <- c(out, banner)
    n_rows <- n_rows + 1L
  }

  # -- header_top rule ---------------------------------------------------
  # When the outer frame top is set and there is no banner between them,
  # both rules would land on the same boundary; the frame wins (LaTeX
  # parity: tabularray's last-written directive wins on a shared index).
  frame_top_set <- is.list(meta$body_borders) &&
    !is.null(meta$body_borders$outer_top)
  if (!(frame_top_set && length(banner) == 0L)) {
    top_stroke <- .typst_chrome_stroke(cs, "header_top")
    if (!is.null(top_stroke)) {
      out <- c(out, sprintf("    table.hline(stroke: %s),", top_stroke))
    }
  }

  # -- spanner band rows -------------------------------------------------
  band <- .render_typst_header_bands(page_headers, col_names_vis, cs)
  out <- c(out, band$lines)
  n_rows <- n_rows + band$n_rows

  # -- column-labels row -------------------------------------------------
  out <- c(
    out,
    .render_typst_col_labels_row(
      page_col_labels_ast,
      col_names_vis,
      cols,
      cs,
      preset = meta$preset
    )
  )
  n_rows <- n_rows + 1L

  # -- header_bottom rule ------------------------------------------------
  bottom_stroke <- .typst_chrome_stroke(cs, "header_bottom")
  if (!is.null(bottom_stroke)) {
    out <- c(out, sprintf("    table.hline(stroke: %s),", bottom_stroke))
  }

  list(
    lines = c("  table.header(", "    repeat: true,", out, "  ),"),
    n_rows = n_rows,
    n_title_rows = n_title_rows
  )
}

# The subgroup banner as ONE spanning cell: blank-line pads above /
# below ride `#v()` inside the cell (from the `subgroup` spacing gaps).
# Returns character(0) when the page has no subgroup runtime.
.typst_subgroup_banner_cell <- function(
  subgroup_line_ast,
  n_cols,
  meta,
  cs = NULL
) {
  if (
    is.null(subgroup_line_ast) ||
      !is_inline_ast(subgroup_line_ast) ||
      length(subgroup_line_ast@runs) == 0L ||
      n_cols < 1L
  ) {
    return(character())
  }
  inner <- .render_typst_inline(subgroup_line_ast)
  surface_node <- .chrome_surface_at(cs, "subgroup")
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    h <- .effective_subgroup_halign(meta$preset)
    # Paged backends left-align the banner by default (anatomy); an
    # explicit cells_subgroup_labels() halign override still wins.
    if (is.na(h)) "left" else h
  }
  if (!(is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE))) {
    inner <- paste0("#strong[", inner, "]")
  }
  body <- .typst_wrap_text_props(inner, surface_node)
  blank_line <- .typst_blank_line(meta$preset)
  pad_above <- rep(blank_line, .meta_gap(meta, "subgroup_above", 1L))
  pad_below <- rep(blank_line, .meta_gap(meta, "subgroup_to_body", 1L))
  content <- paste(
    c(
      pad_above,
      sprintf("#align(%s)[%s]", .typst_halign(halign), body),
      pad_below
    ),
    collapse = "\n"
  )
  sprintf(
    "    %s,",
    .typst_cell(
      content,
      colspan = if (n_cols > 1L) n_cols else NULL,
      align = "left + top",
      fill = .typst_fill(surface_node),
      inset = "(top: 0pt, bottom: 0pt)"
    )
  )
}

# Render multi-level header bands. For each band-row depth (top first)
# we walk visible columns left to right, group contiguous runs sharing
# the same band label (or none), and emit one spanning cell per run.
# The band underline (the SSOT spanrule, chrome region `header_between`)
# is a `#line(length: 100%)` as the LAST content of each spanning cell:
# `100%` is the cell's CONTENT width, so the rule is trimmed by the
# horizontal inset at both ends — typst's equivalent of booktabs
# `\cmidrule(lr)` / HTML's inset gradient. The cell's bottom inset is
# zeroed so the rule sits flush on the row boundary.
#
# Returns `list(lines, n_rows)`.
.render_typst_header_bands <- function(
  headers,
  col_names_visible,
  cs = NULL
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(list(lines = character(), n_rows = 0L))
  }
  surface_node <- .chrome_surface_at(cs, "header")
  band_stroke <- .typst_chrome_stroke(cs, "header_between")
  depths <- sort(unique(headers$depth))
  lines <- character()
  for (k in seq_along(depths)) {
    labels <- .band_labels_for_depth(headers, depths[[k]], col_names_visible)
    runs <- .group_contiguous_runs(labels)
    cells <- character()
    for (run in runs) {
      span <- run$length
      if (is.na(run$value)) {
        cells <- c(cells, rep("[]", span))
        next
      }
      lbl <- .typst_wrap_text_props(
        .typst_escape(run$value),
        surface_node,
        bold_default = TRUE
      )
      content <- sprintf("#align(center + bottom)[%s]", lbl)
      inset <- NULL
      if (!is.null(band_stroke)) {
        content <- paste0(
          content,
          sprintf(" #line(length: 100%%, stroke: %s)", band_stroke)
        )
        inset <- "(bottom: 0pt)"
      }
      cells <- c(
        cells,
        .typst_cell(
          content,
          colspan = if (span > 1L) span else NULL,
          align = "center + bottom",
          inset = inset
        )
      )
    }
    lines <- c(lines, sprintf("    %s,", paste(cells, collapse = ", ")))
  }
  list(lines = lines, n_rows = length(depths))
}

# Render the column-labels row: one cell per visible column, pulled
# from `col_labels_ast`. Falls back to the column name when the spec
# did not set a label for that column. Every cell emits an explicit
# align pair (the table `align:` array carries the BODY baseline, so
# the header needs its own — valign cascade default bottom, halign
# decimal -> center, else col align, else surface halign, else left).
.render_typst_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols,
  cs = NULL,
  preset = NULL
) {
  surface_node <- .chrome_surface_at(cs, "header")
  ws_preserve <- .preset_ws_preserve(preset)
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      raw <- if (is.null(ast)) {
        .typst_escape(nm)
      } else {
        .render_typst_inline(ast, preserve = ws_preserve)
      }
      body <- .typst_wrap_text_props(raw, surface_node, bold_default = TRUE)
      col <- cols[[nm]]
      valign <- if (
        is_col_spec(col) &&
          length(col@valign) == 1L &&
          !is.na(col@valign)
      ) {
        col@valign
      } else if (
        is_style_node(surface_node) &&
          length(surface_node@valign) == 1L &&
          !is.na(surface_node@valign)
      ) {
        surface_node@valign
      } else {
        .effective_header_valign(col, preset)
      }
      if (is.na(valign)) {
        valign <- "bottom"
      }
      col_align <- if (
        is_col_spec(col) && length(col@align) == 1L && !is.na(col@align)
      ) {
        col@align
      } else {
        NA_character_
      }
      halign <- if (identical(col_align, "decimal")) {
        # Decimal headers centre over the NBSP-padded block (HTML parity).
        "center"
      } else if (!is.na(col_align)) {
        col_align
      } else if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        "left"
      }
      .typst_cell(
        body,
        align = paste(.typst_halign(halign), "+", .typst_valign(valign))
      )
    },
    character(1L)
  )
  sprintf("    %s,", paste(cells, collapse = ", "))
}

# ---------------------------------------------------------------------
# Footer block: user footnotes ride table.footer
# ---------------------------------------------------------------------

# Build the `table.footer(repeat:, ...)` block carrying the user
# footnotes as ONE spanning cell (blank pads + the opt-in footnote
# opening rule + the footnote lines). `repeat: true` replays the
# footnotes on every physical page; `repeat: false` pins them to the
# final page only (lastfoot parity). Empty footnotes emit nothing.
.typst_footer_block <- function(meta, cs, n_cols, rep_footnotes = TRUE) {
  fn <- .typst_footnote_block(
    meta$footnotes_ast,
    preset = meta$preset,
    cs = cs
  )
  if (length(fn) == 0L) {
    return(character())
  }
  pad_above <- .chrome_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )
  blank_line <- .typst_blank_line(meta$preset)
  rule <- .typst_rule_line(.chrome_border_at(cs, "footer_top"))
  # Newline-joined: the footnote block opens with a scoped `#set`,
  # which needs a line break before the following markup.
  content <- paste(
    c(rep(blank_line, pad_above), rule, fn),
    collapse = "\n"
  )
  c(
    sprintf(
      "  table.footer(repeat: %s,",
      if (isTRUE(rep_footnotes)) "true" else "false"
    ),
    sprintf(
      "    %s,",
      .typst_cell(
        content,
        colspan = if (n_cols > 1L) n_cols else NULL,
        align = "left + top",
        inset = "(left: 0pt, right: 0pt, bottom: 0pt)"
      )
    ),
    "  ),"
  )
}

# ---------------------------------------------------------------------
# Body rows
# ---------------------------------------------------------------------

# Render one body row per data row. Cell text is the post-engine_decimal
# `cells_text` slice; embedded `\n` becomes a typst linebreak inside the
# cell. Markup specials are escaped. Per-cell predicate overrides from
# `cells_style@halign / @valign` emit an explicit `align:` pair on the
# cell; column-level alignment is carried by the table `align:` array.
# The engine's keep-with-next mask is NOT enforced (typst has no per-row
# no-break primitive — see the file header).
#
# Returns `list(lines, n_rows)` where `lines` may interleave
# `table.hline` directives (the body `rows` rules) between row lines.
.render_typst_body_rows <- function(
  cells_text,
  col_names_vis = NULL,
  cells_style = NULL,
  cells_indent = NULL,
  is_header_row = NULL,
  is_blank_row = NULL,
  cols = NULL,
  preset = NULL,
  body_valign = "top",
  rows_triple = NULL
) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(list(lines = character(), n_rows = 0L))
  }
  ncol_data <- ncol(cells_text)
  col_names_vis <- col_names_vis %||% rep(NA_character_, ncol_data)
  if (is.null(cells_indent)) {
    cells_indent <- matrix(0L, nrow = nrow_data, ncol = ncol_data)
  }
  is_header_row <- is_header_row %||% rep(FALSE, nrow_data)
  is_blank_row <- is_blank_row %||% rep(FALSE, nrow_data)
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_pt_per_level <- .indent_native_pt_per_level(preset)
  ws_preserve <- .preset_ws_preserve(preset)
  rows_stroke <- .typst_stroke(rows_triple)
  # Per-column CONTENT width in pt (track width minus the horizontal
  # inset) plus the measuring metrics, for the no-wrap fit test in the
  # cell loop. NA content width (auto track) never boxes — typst sizes
  # auto tracks to the natural content, so they cannot force a wrap.
  content_pt <- .typst_content_widths_pt(
    col_names_vis,
    cols,
    cells_style,
    preset
  )
  body_afm <- if (is_preset_spec(preset)) {
    .resolve_afm_name(preset@font_family, bold = FALSE)
  } else {
    NULL
  }
  body_font_pt <- if (is_preset_spec(preset)) preset@font_size else NA_real_

  lines <- character()
  for (i in seq_len(nrow_data)) {
    if (i > 1L && !is.null(rows_stroke)) {
      lines <- c(lines, sprintf("  table.hline(stroke: %s),", rows_stroke))
    }
    if (isTRUE(is_blank_row[[i]])) {
      # Blank separator row: one spanning cell whose hidden strut keeps
      # the row at exactly one text-line height. The stripe fill stamped
      # on the row's style nodes shades it (typst improves on the LaTeX
      # backend, whose text-colorbox stripe cannot reach an empty row).
      bg <- if (!is.null(cells_style)) {
        .typst_fill(cells_style[[i, 1L]])
      } else {
        NULL
      }
      first_node <- if (!is.null(cells_style)) cells_style[[i, 1L]] else NULL
      lines <- c(
        lines,
        sprintf(
          "  %s,",
          .typst_cell(
            "#hide[X]",
            colspan = if (ncol_data > 1L) ncol_data else NULL,
            fill = bg,
            stroke = .typst_cell_stroke(first_node)
          )
        )
      )
      next
    }
    if (isTRUE(is_header_row[[i]])) {
      lines <- c(
        lines,
        .typst_group_header_row(
          cells_text,
          cells_style,
          cells_indent,
          i,
          ncol_data,
          indent_pt_per_level,
          body_valign,
          ws_preserve
        )
      )
      next
    }
    cells <- vapply(
      seq_len(ncol_data),
      function(j) {
        raw <- cells_text[i, j]
        # The engine's fit decision, re-derived with the SAME AFM
        # machinery that sized the column — measured on the original
        # text (indent spaces still baked, matching what
        # `.compute_col_width` saw).
        no_wrap <- .typst_cell_fits(
          raw,
          content_pt[[j]],
          body_afm,
          body_font_pt
        )
        # Strip the engine-baked indent spaces, then carry the depth as
        # native left padding (`#pad(left:)` indents wrapped continuation
        # lines too — the SAS PADDINGLEFT contract).
        depth <- cells_indent[i, j]
        indent_pt <- 0
        if (isTRUE(depth > 0L) && indent_unit > 0L && !is.na(raw)) {
          n_leading <- indent_unit * depth
          if (
            nchar(raw) >= n_leading &&
              startsWith(raw, strrep(" ", n_leading))
          ) {
            raw <- substr(raw, n_leading + 1L, nchar(raw))
          }
          if (indent_pt_per_level > 0) {
            indent_pt <- indent_pt_per_level * depth
          }
        }
        text <- .typst_escape_cell(raw, preserve = ws_preserve)
        if (no_wrap) {
          # The engine sized the column so this cell fits on ONE line;
          # rewriting its interior spaces to `~` (typst's non-breaking
          # space, same advance width) removes every break point, so
          # sub-point metric drift between the measuring AFM and the
          # shipped face (e.g. Courier New's 1229/2048 em advance vs
          # the AFM's 600/1000) cannot re-wrap it. Typst breaks on
          # strict overflow where TeX absorbs it. Escaped sequences
          # contain no spaces, so the rewrite touches text only.
          text <- gsub(" ", "~", text, fixed = TRUE)
        }
        nm <- col_names_vis[[j]]
        sn <- if (is.character(nm) && !is.na(nm)) {
          .cell_style_at(cells_style, i, nm)
        } else {
          style_node()
        }
        wrapped <- .typst_wrap_text_props(text, sn)
        wrapped <- .typst_indent_wrap(wrapped, indent_pt)
        .typst_cell(
          wrapped,
          align = .typst_cell_align(sn),
          fill = .typst_fill(sn),
          stroke = .typst_cell_stroke(sn)
        )
      },
      character(1L)
    )
    lines <- c(lines, sprintf("  %s,", paste(cells, collapse = ", ")))
  }
  list(lines = lines, n_rows = nrow_data)
}

# One synthesised group-header row: a full-span left-aligned cell whose
# weight + text props come from the host cell's resolved style_node
# (stamped by `.stamp_group_headers()`): NA bold == bold (default),
# `isFALSE` == off. Band-depth indent rides `#pad(left:)`.
.typst_group_header_row <- function(
  cells_text,
  cells_style,
  cells_indent,
  i,
  ncol_data,
  indent_pt_per_level,
  body_valign,
  ws_preserve
) {
  host_text <- ""
  host_idx <- NA_integer_
  for (jj in seq_len(ncol_data)) {
    val <- cells_text[i, jj]
    if (!is.na(val) && nzchar(val)) {
      host_text <- val
      host_idx <- jj
      break
    }
  }
  header_indent_pt <- 0
  if (!is.na(host_idx)) {
    header_depth <- cells_indent[i, host_idx]
    if (isTRUE(header_depth > 0L) && indent_pt_per_level > 0) {
      header_indent_pt <- indent_pt_per_level * header_depth
    }
  }
  host_node <- if (!is.null(cells_style) && !is.na(host_idx)) {
    cells_style[[i, host_idx]]
  } else {
    NULL
  }
  body <- .typst_escape_cell(host_text, preserve = ws_preserve)
  if (!(is_style_node(host_node) && isTRUE(host_node@bold == FALSE))) {
    body <- paste0("#strong[", body, "]")
  }
  body <- .typst_wrap_text_props(body, host_node)
  body <- .typst_indent_wrap(body, header_indent_pt)
  sprintf(
    "  %s,",
    .typst_cell(
      body,
      colspan = if (ncol_data > 1L) ncol_data else NULL,
      align = paste("left", "+", body_valign),
      fill = .typst_fill(host_node),
      stroke = .typst_cell_stroke(host_node)
    )
  )
}

# Per-column content width in pt: the engine-resolved track width
# minus the horizontal inset, i.e. the box a cell's text must fit
# inside. NA for auto tracks and headless (no-preset) grids.
.typst_content_widths_pt <- function(
  col_names_vis,
  cols,
  cells_style,
  preset
) {
  if (!is_preset_spec(preset)) {
    return(rep(NA_real_, length(col_names_vis)))
  }
  lr <- .resolve_cell_padding_lr(cells_style, preset)
  vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      width <- if (is_col_spec(cs)) cs@width else NA_real_
      if (!is.numeric(width) || length(width) != 1L || is.na(width)) {
        return(NA_real_)
      }
      width * 72 - lr[[1L]] - lr[[2L]]
    },
    numeric(1L)
  )
}

# TRUE when a single-line cell fits its column's content box per the
# SAME AFM measurement the engine used to size the column
# (`.compute_col_width`) — i.e. the engine intends this cell to render
# on one line. Multi-line cells (explicit `\n`) are never boxed: their
# breaks are already explicit. A small epsilon absorbs the rounding of
# the emitted track width.
.typst_cell_fits <- function(text, content_pt, afm, font_pt) {
  if (
    is.null(afm) ||
      !is.finite(content_pt %||% NA_real_) ||
      !is.finite(font_pt %||% NA_real_) ||
      is.null(text) ||
      length(text) != 1L ||
      is.na(text)
  ) {
    return(FALSE)
  }
  if (grepl("\n", text, fixed = TRUE)) {
    return(FALSE)
  }
  width_pt <- (.text_width_em(text, afm) / 1000) * font_pt
  isTRUE(width_pt <= content_pt + 0.01)
}

# Wrap cell content in `#pad(left:)` for indent depth. `pt <= 0`
# returns the content unchanged. `#pad` is block-level inside the cell,
# so a wrapped cell's continuation lines align with the indented first
# line (SAS PADDINGLEFT).
.typst_indent_wrap <- function(content, pt) {
  if (!is.numeric(pt) || length(pt) != 1L || is.na(pt) || pt <= 0) {
    return(content)
  }
  sprintf("#pad(left: %spt)[%s]", .typst_num(pt), content)
}

# ---------------------------------------------------------------------
# Cell + style lowering helpers
# ---------------------------------------------------------------------

# Compose one table cell. All-default attributes collapse to the bare
# `[content]` form; any attribute promotes to `table.cell(...)[content]`.
.typst_cell <- function(
  content,
  colspan = NULL,
  align = NULL,
  fill = NULL,
  stroke = NULL,
  inset = NULL
) {
  args <- c(
    if (!is.null(colspan)) sprintf("colspan: %d", as.integer(colspan)),
    if (!is.null(align)) sprintf("align: %s", align),
    if (!is.null(fill)) sprintf("fill: %s", fill),
    if (!is.null(stroke)) sprintf("stroke: %s", stroke),
    if (!is.null(inset)) sprintf("inset: %s", inset)
  )
  if (length(args) == 0L) {
    return(sprintf("[%s]", content))
  }
  sprintf("table.cell(%s)[%s]", paste(args, collapse = ", "), content)
}

# Per-cell `align:` pair from a style_node's explicit halign / valign
# overrides (predicate layer). Column-level alignment is carried by the
# table `align:` array; NULL when the style is silent. A single-axis
# override is emitted alone — typst folds a one-axis alignment over the
# array's other axis.
.typst_cell_align <- function(style) {
  if (!is_style_node(style)) {
    return(NULL)
  }
  h <- if (length(style@halign) == 1L && !is.na(style@halign)) {
    .typst_halign(style@halign)
  } else {
    NULL
  }
  v <- if (length(style@valign) == 1L && !is.na(style@valign)) {
    .typst_valign(style@valign)
  } else {
    NULL
  }
  if (is.null(h) && is.null(v)) {
    return(NULL)
  }
  paste(c(h, v), collapse = " + ")
}

# Cell fill from a style_node background (NA = silent -> NULL).
.typst_fill <- function(style) {
  if (!is_style_node(style)) {
    return(NULL)
  }
  bg <- style@background
  if (length(bg) != 1L || is.na(bg) || !nzchar(bg)) {
    return(NULL)
  }
  .typst_color(bg)
}

# Per-cell stroke dict from a style_node's per-side border scalars.
# Typst draws these natively (`table.cell(stroke: (top: ...))`) — the
# per-cell body-border limitation documented on the LaTeX backend does
# not apply here. NULL when no side is set.
.typst_cell_stroke <- function(style) {
  if (!is_style_node(style)) {
    return(NULL)
  }
  sides <- c("top", "right", "bottom", "left")
  parts <- character()
  for (s in sides) {
    triple <- .effective_border(s, style)
    if (is.null(triple)) {
      next
    }
    stroke <- .typst_stroke(triple)
    parts <- c(
      parts,
      sprintf("%s: %s", s, if (is.null(stroke)) "none" else stroke)
    )
  }
  if (length(parts) == 0L) {
    return(NULL)
  }
  sprintf("(%s)", paste(parts, collapse = ", "))
}

# Wrap one cell's escaped text with typst markup for the text
# properties on a style_node: bold, italic, underline, font_size,
# font_family, color. Application order is fixed so the emitted source
# is stable: bold -> italic -> underline -> one `#text()` wrapper
# carrying size / font / fill. Background rides the CELL fill (see
# `.typst_fill`), not the text. Silent (NA) properties pass through.
.typst_wrap_text_props <- function(text, style, bold_default = FALSE) {
  if (!is.character(text) || length(text) != 1L) {
    return(text)
  }
  bold <- if (is_style_node(style)) style@bold else NA
  do_bold <- if (bold_default) !isTRUE(bold == FALSE) else isTRUE(bold)
  out <- text
  if (do_bold) {
    out <- paste0("#strong[", out, "]")
  }
  if (!is_style_node(style)) {
    return(out)
  }
  if (isTRUE(style@italic)) {
    out <- paste0("#emph[", out, "]")
  }
  if (isTRUE(style@underline)) {
    out <- paste0("#underline[", out, "]")
  }
  args <- character()
  fs <- style@font_size
  if (length(fs) == 1L && !is.na(fs) && is.numeric(fs)) {
    args <- c(args, sprintf("size: %spt", .typst_num(fs)))
  }
  ff <- style@font_family
  if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
    args <- c(args, sprintf("font: %s", .typst_font_array(ff)))
  }
  col <- style@color
  if (length(col) == 1L && !is.na(col) && nzchar(col)) {
    args <- c(args, sprintf("fill: %s", .typst_color(col)))
  }
  if (length(args) > 0L) {
    out <- sprintf("#text(%s)[%s]", paste(args, collapse = ", "), out)
  }
  out
}

# ---------------------------------------------------------------------
# Columns, alignment array, inset
# ---------------------------------------------------------------------

# Compose the `columns:` tuple. One entry per visible column: the
# engine-resolved width in inches (the TOTAL column footprint — typst's
# inset pads INSIDE the track width, so no separation correction is
# needed, unlike tabularray's outside-`wd` colsep), or `auto` for the
# rare synthesised column without engine resolution. The trailing comma
# keeps a 1-column tuple valid typst.
.typst_columns <- function(col_names_vis, cols) {
  toks <- vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      width <- if (is_col_spec(cs)) cs@width else NA_real_
      if (!is.numeric(width) || length(width) != 1L || is.na(width)) {
        "auto"
      } else {
        sprintf("%sin", .typst_num(round(width, 4L)))
      }
    },
    character(1L)
  )
  sprintf("(%s,)", paste(toks, collapse = ", "))
}

# Compose the `align:` tuple: per-column halign (from `col_spec@align`;
# decimal centres over the engine's NBSP padding) + the table-level body
# valign baseline.
.typst_align_array <- function(col_names_vis, cols, preset) {
  v <- .typst_body_valign(preset)
  toks <- vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      paste(.typst_halign_letterlike(align), "+", v)
    },
    character(1L)
  )
  sprintf("(%s,)", paste(toks, collapse = ", "))
}

# Map an align value to the typst horizontal keyword, with the decimal
# -> center mapping shared with the other backends (the engine's NBSP
# padding makes the block centre under the centred decimal header).
.typst_halign_letterlike <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("left")
  }
  switch(
    align,
    left = "left",
    center = "center",
    right = "right",
    decimal = "center",
    "left"
  )
}

# halign / valign keyword helpers.
.typst_halign <- function(halign) {
  switch(halign, left = "left", center = "center", right = "right", "left")
}
.typst_valign <- function(valign) {
  switch(valign, top = "top", middle = "horizon", bottom = "bottom", "top")
}

# Table-level `inset:` dict from the horizontal cell-padding SSOT
# (`.resolve_cell_padding_lr`, so the rendered per-side margin matches
# the measured column width) and the vertical padding override
# (tabularray's 2pt above/belowsep default fills in, keeping the row
# pitch at LaTeX parity). Returns character(0) without a preset so
# headless callers keep typst's own default inset.
.typst_table_inset <- function(cells_style = NULL, preset = NULL) {
  if (!is_preset_spec(preset)) {
    return(character())
  }
  lr <- .resolve_cell_padding_lr(cells_style, preset)
  sides <- .first_cell_padding_sides(cells_style)
  top <- if (is.na(sides[["top"]])) 2 else sides[["top"]]
  bottom <- if (is.na(sides[["bottom"]])) 2 else sides[["bottom"]]
  sprintf(
    "(left: %spt, right: %spt, top: %spt, bottom: %spt)",
    .typst_num(lr[[1L]]),
    .typst_num(lr[[2L]]),
    .typst_num(top),
    .typst_num(bottom)
  )
}

# ---------------------------------------------------------------------
# Borders / strokes
# ---------------------------------------------------------------------

# Map one resolved border triple to a typst stroke expression. `none` /
# NULL -> NULL; the caller skips emission. Solid strokes use the short
# `<width>pt + <paint>` form; dashed styles need the dict form. The
# paint is omitted for the default ink (typst's default black), exactly
# like the LaTeX backend omits `fg=` there.
.typst_stroke <- function(triple) {
  if (is.null(triple) || identical(triple$style, "none")) {
    return(NULL)
  }
  width <- sprintf("%spt", .typst_num(triple$width %||% .tabular_rule_width))
  has_color <- !is.null(triple$color) &&
    !is.na(triple$color) &&
    nzchar(triple$color) &&
    !identical(triple$color, "currentColor") &&
    !.is_default_ink(triple$color)
  paint <- if (has_color) .typst_color(triple$color) else NULL
  dash <- switch(
    triple$style %||% "solid",
    dashed = "dashed",
    dotted = "dotted",
    dashdot = "dash-dotted",
    # `double` has no typst dash pattern; degrade to solid (documented
    # on brdr()'s cross-backend notes as an RTF/DOCX-only style anyway).
    NULL
  )
  if (is.null(dash)) {
    if (is.null(paint)) {
      return(width)
    }
    return(sprintf("%s + %s", width, paint))
  }
  parts <- c(
    sprintf("thickness: %s", width),
    if (!is.null(paint)) sprintf("paint: %s", paint),
    sprintf("dash: \"%s\"", dash)
  )
  sprintf("(%s)", paste(parts, collapse = ", "))
}

# Resolve a chrome border region to a typst stroke. No user override ->
# the canonical thin solid rule at the SSOT width. `style = "none"` ->
# NULL (caller skips the directive entirely).
.typst_chrome_stroke <- function(cs, region) {
  triple <- .chrome_border_at(cs, region)
  if (is.null(triple)) {
    return(sprintf("%spt", .typst_num(.tabular_rule_width)))
  }
  .typst_stroke(triple)
}

# A full-width standalone rule (`#line`) from a border triple, for the
# title-block edges and the footnote-opening rule. NULL / "none" -> no
# rule.
.typst_rule_line <- function(triple) {
  stroke <- .typst_stroke(triple)
  if (is.null(stroke)) {
    return(character())
  }
  sprintf("#line(length: 100%%, stroke: %s)", stroke)
}

# Outer vertical frame edges from the body-borders manifest:
# `outer_left` (x = 0), `outer_right` (x = n). Table-level vlines are
# needed for the OUTER edges only, so the frame encloses the
# synthesized header-band rows that carry no per-cell stamps; the
# engine also stamps the outer layers on the edge BODY cells, whose
# per-cell strokes overlap these exactly (one visible line — the HTML
# backend's border-collapse hybrid, transplanted). Between-column
# `cols` rules ride the per-cell channel alone. The row range skips
# the in-table title cell (LaTeX parity: titles live outside the
# table there) and the footer block.
.typst_vline_directives <- function(
  body_borders,
  n_cols,
  n_title_rows,
  n_header_rows,
  nrow_body
) {
  if (!is.list(body_borders) || length(body_borders) == 0L) {
    return(character())
  }
  start <- n_title_rows
  end <- n_header_rows + nrow_body
  vline <- function(x, triple) {
    stroke <- .typst_stroke(triple)
    if (is.null(stroke)) {
      return(character())
    }
    sprintf(
      "  table.vline(x: %d, start: %d, end: %d, stroke: %s),",
      x,
      start,
      end,
      stroke
    )
  }
  out <- character()
  if (!is.null(body_borders$outer_left)) {
    out <- c(out, vline(0L, body_borders$outer_left))
  }
  if (!is.null(body_borders$outer_right)) {
    out <- c(out, vline(n_cols, body_borders$outer_right))
  }
  out
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single typst markup string. Walks every
# run in `ast@runs` recursively. Unknown run types fall through to
# their (escaped) `text` field.
.render_typst_inline <- function(ast, preserve = TRUE) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  .render_typst_children(ast@runs, preserve, lead = TRUE, trail = TRUE)
}

# Render one AST run record to its typst markup. Recurses through
# `children` for wrapping types. `lead` / `trail` flag the run's
# line-edge position (only line-edge whitespace becomes a `~`
# non-breaking space; inter-run spaces stay breakable).
.render_typst_run <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  type <- run$type
  switch(
    type,
    plain = .typst_escape_text_run(run$text %||% "", preserve, lead, trail),
    bold = paste0(
      "#strong[",
      .render_typst_children(run$children, preserve, lead, trail),
      "]"
    ),
    italic = paste0(
      "#emph[",
      .render_typst_children(run$children, preserve, lead, trail),
      "]"
    ),
    sup = paste0(
      "#super[",
      .render_typst_children(run$children, preserve, lead, trail),
      "]"
    ),
    sub = paste0(
      "#sub[",
      .render_typst_children(run$children, preserve, lead, trail),
      "]"
    ),
    # Raw takes a STRING (its own font handling); nested markup inside a
    # code run has no typst equivalent, so the children flatten to text
    # (parity with `\texttt`, which also renders children as-is).
    code = sprintf(
      "#raw(\"%s\")",
      .typst_escape_str(.typst_flatten_children(run$children))
    ),
    link = .render_typst_link(run, preserve, lead, trail),
    span = .render_typst_children(run$children, preserve, lead, trail),
    newline = " \\ ",
    .typst_escape_text_run(run$text %||% "", preserve, lead, trail)
  )
}

# Escape a plain-text run and, when preserving, rewrite significant
# whitespace runs into `~` non-breaking spaces (typst's markup NBSP).
.typst_escape_text_run <- function(
  text,
  preserve,
  lead = TRUE,
  trail = TRUE
) {
  .escape_text_run(text, .typst_escape, "~", preserve, lead, trail)
}

# Render the children of a wrapping run.
.render_typst_children <- function(
  children,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  .render_ast_children(children, .render_typst_run, preserve, lead, trail)
}

# Flatten a code run's children to plain text (for `#raw()`).
.typst_flatten_children <- function(children) {
  if (length(children) == 0L) {
    return("")
  }
  paste(
    vapply(children, .run_text, character(1L)),
    collapse = ""
  )
}

# Render a link run as `#link("url")[text]`.
.render_typst_link <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  text <- .render_typst_children(run$children, preserve, lead, trail)
  href <- run$href %||% ""
  sprintf("#link(\"%s\")[%s]", .typst_escape_str(href), text)
}

# ---------------------------------------------------------------------
# Escaping helpers
# ---------------------------------------------------------------------

# Typst-escape a string for safe insertion into MARKUP context. Every
# character with markup meaning is backslash-escaped (typst treats a
# backslash before any symbol as a literal escape): the strong/emph
# markers (`*`, `_`), code/math/label/ref sigils (`` ` ``, `$`, `#`,
# `<`, `>`, `@`), list/term markers (`-`, `+`, `/`), headings (`=`),
# content brackets and code braces (`[`, `]`, `{`, `}`), the NBSP
# shorthand (`~`), and backslash itself. Straight quotes are NOT
# escaped: typst's smartquote pass matches the LaTeX engines' ligature
# behaviour, so the two PDF paths render quotes identically.
# NULL / NA / length-0 collapse to the empty string.
.typst_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  gsub(
    "([\\\\`#\\$\\*_<>@=\\+/\\[\\]~\\{\\}-])",
    "\\\\\\1",
    text,
    perl = TRUE
  )
}

# Cell-level escape — full typst escape PLUS `\n` (and `\r\n`) -> a
# typst linebreak so multi-line strings emitted by engine_decimal
# render as proper line breaks inside cells. The auto-footnote marker
# sentinel is peeled before escaping and re-attached as `#super[]`.
.typst_escape_cell <- function(text, preserve = TRUE) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  peeled <- .fn_peel(text)
  text <- .typst_escape(peeled$base)
  text <- gsub("\r\n", " \\ ", text, fixed = TRUE)
  text <- gsub("\n", " \\ ", text, fixed = TRUE)
  # Preserve significant ASCII whitespace LAST, after the indent strip
  # at the call site and the newline conversion. `~` is typst's
  # non-breaking space; inserted post-escape so it is not rewritten to
  # `\~`. Single interior spaces stay breakable. (The engine's decimal
  # NBSP padding is U+00A0, which passes through the escape untouched
  # and renders as a non-breaking space natively.)
  if (isTRUE(preserve)) {
    text <- .preserve_ws(text, "~")
  }
  if (any(peeled$has)) {
    text[peeled$has] <- paste0(
      text[peeled$has],
      "#super[",
      .typst_escape(peeled$marker[peeled$has]),
      "]"
    )
  }
  text
}

# Escape a string for a typst STRING literal ("..."): backslash and
# double quote only.
.typst_escape_str <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return("")
  }
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  gsub("\"", "\\\"", x, fixed = TRUE)
}

# ---------------------------------------------------------------------
# Prelude — page geometry, chrome bands, fonts
# ---------------------------------------------------------------------

# Self-contained document prelude, driven by the preset_spec carried on
# `grid@metadata$preset`. The standalone `emit(spec, "out.typ")` path
# uses this as-is so the .typ compiles on its own via `typst compile`.
#
# Preset properties consumed:
#
# * `font_size`    -> `#set text(size: Xpt)`
# * `font_family`  -> `#set text(font: (...))` via the shared font-stack
#                     resolver; typst walks the fallback array natively
#                     (its analogue of a CSS font-family stack).
# * `orientation`  -> `#set page(flipped: true)` for landscape.
# * `paper_size`   -> `#set page(paper: "...")`.
# * `margins`      -> `#set page(margin: (...))` (CSS shorthand).
.typst_prelude <- function(
  preset = NULL,
  pagehead_ast = NULL,
  pagefoot_ast = NULL,
  cs = NULL
) {
  if (is.null(preset) || !is_preset_spec(preset)) {
    preset <- preset_spec()
  }
  size <- tryCatch(
    as.numeric(.effective_font_size(preset)),
    error = function(e) .latex_default_class_pt
  )
  if (length(size) != 1L || !is.finite(size)) {
    size <- .latex_default_class_pt
  }
  page_args <- c(
    sprintf("  paper: \"%s\",", .typst_paper(preset@paper_size)),
    if (identical(preset@orientation, "landscape")) "  flipped: true,",
    sprintf("  margin: %s,", .typst_margin_dict(preset@margins)),
    .typst_page_band_arg(pagehead_ast, head = TRUE, cs = cs, size = size),
    .typst_page_band_arg(pagefoot_ast, head = FALSE, cs = cs, size = size)
  )
  # Vertical metrics follow TeX's strut model so the line pitch is
  # deterministic and matches the LaTeX backend (and the engine's page
  # budgeting) exactly: every line box is `font_size * baseline_ratio`
  # tall, split 0.7 above / 0.3 below the baseline (TeX's \strutbox
  # proportions), with ZERO leading between lines. Typst's defaults
  # (cap-height top edge, baseline bottom edge, 0.65em leading) make
  # single-line table rows ~40% shorter than LaTeX's, drifting the
  # per-page row counts far from the other paged backends.
  top_edge <- round(0.7 * .tabular_baseline_ratio, 4L)
  bottom_edge <- round(0.3 * .tabular_baseline_ratio, 4L)
  c(
    "// Generated by the R package tabular. Compiles standalone:",
    "//   typst compile <file>.typ   (or: quarto typst compile <file>.typ)",
    "#set page(",
    page_args,
    ")",
    sprintf(
      "#set text(font: %s, size: %spt, top-edge: %sem, bottom-edge: -%sem)",
      .typst_font_array(.effective_font_family(preset)),
      .typst_num(size),
      .typst_num(top_edge),
      .typst_num(bottom_edge)
    ),
    "#set par(leading: 0em)",
    # Zero inter-block spacing is the `\parskip=0pt` parity line: title /
    # footnote lines and the explicit `#v()` pads stack at the normal
    # line pitch, with every gap carried by an explicit pad.
    "#set block(spacing: 0pt)"
  )
}

# Resolve a font_family input to a typst font tuple via the shared
# stack resolver (typst walks the array natively at compile time).
.typst_font_array <- function(font_family) {
  chain <- .resolve_font_stack(font_family, "typst")
  if (length(chain) == 0L) {
    chain <- "mono"
  }
  quoted <- vapply(
    chain,
    function(f) sprintf("\"%s\"", .typst_escape_str(f)),
    character(1L)
  )
  sprintf("(%s,)", paste(quoted, collapse = ", "))
}

# Map a preset paper_size to typst's paper identifier.
.typst_paper <- function(paper) {
  switch(
    paper,
    letter = "us-letter",
    legal = "us-legal",
    a4 = "a4",
    paper
  )
}

# Expand a CSS-shorthand margin vector to the typst `margin:` dict.
# Each value routes through `.parse_dim` so numeric inches and
# character units (in/cm/mm/pt/pc) format consistently.
.typst_margin_dict <- function(m) {
  parsed <- lapply(seq_along(m), function(i) {
    .parse_dim(m[[i]], allow_percent = FALSE)
  })
  fmt <- function(p) .dim_format(p)
  if (length(parsed) == 1L) {
    return(fmt(parsed[[1L]]))
  }
  if (length(parsed) == 2L) {
    return(sprintf(
      "(top: %s, bottom: %s, left: %s, right: %s)",
      fmt(parsed[[1L]]),
      fmt(parsed[[1L]]),
      fmt(parsed[[2L]]),
      fmt(parsed[[2L]])
    ))
  }
  sprintf(
    "(top: %s, right: %s, bottom: %s, left: %s)",
    fmt(parsed[[1L]]),
    fmt(parsed[[2L]]),
    fmt(parsed[[3L]]),
    fmt(parsed[[4L]])
  )
}

# One `header:` / `footer:` page argument from a resolved page band.
# Three slots ride a `1fr/1fr/1fr` grid (left / centre / right); the
# whole content is a `context` block so the `{page}` / `{npages}`
# counter substitutions resolve. The rule under the header band
# (`pagehead_bottom`) / above the footer band (`pagefoot_top`) rides a
# full-width `#line`. Empty band -> no argument (typst's default page
# has no header/footer, the `\pagestyle{empty}` parity).
.typst_page_band_arg <- function(band, head, cs = NULL, size = 11) {
  if (!.page_band_is_populated(band)) {
    return(character())
  }
  surface <- if (head) "pagehead" else "pagefoot"
  slots <- vapply(
    c("left", "center", "right"),
    function(s) {
      txt <- .typst_band_slot_text(band[[s]], head = head)
      node <- .chrome_surface_at_slot(cs, surface, slot = s)
      if (nzchar(txt) && is_style_node(node)) {
        txt <- .typst_wrap_text_props(txt, node)
      }
      sprintf("[%s]", txt)
    },
    character(1L)
  )
  rule_region <- if (head) "pagehead_bottom" else "pagefoot_top"
  rule <- .typst_rule_line(.chrome_border_at(cs, rule_region))
  grid_lines <- c(
    # The page bands typeset at the body size (fancyhdr parity: the
    # chrome must not print larger than an 8pt table).
    sprintf("    #set text(size: %spt)", .typst_num(size)),
    "    #grid(",
    "      columns: (1fr, 1fr, 1fr),",
    "      align: (left, center, right),",
    sprintf("      %s,", paste(slots, collapse = ", ")),
    "    )"
  )
  key <- if (head) "header" else "footer"
  body <- if (head) {
    c(grid_lines, if (length(rule) > 0L) paste0("    ", rule))
  } else {
    c(if (length(rule) > 0L) paste0("    ", rule), grid_lines)
  }
  c(
    sprintf("  %s: context [", key),
    body,
    "  ],"
  )
}

# Collapse N rows of one slot's inline_asts to a single typst fragment.
# Rows join with typst linebreaks; pagehead reverses index order (so
# index 1 ends up at the bottom of the header zone, body edge);
# pagefoot keeps forward order (index 1 at the top, body edge). Token
# substitution (`{page}` / `{npages}` -> page counters) runs per-cell
# after the inline render.
.typst_band_slot_text <- function(slot_asts, head) {
  if (length(slot_asts) == 0L) {
    return("")
  }
  order <- if (head) rev(seq_along(slot_asts)) else seq_along(slot_asts)
  parts <- vapply(
    order,
    function(i) {
      ast <- slot_asts[[i]]
      if (!is_inline_ast(ast) || length(ast@runs) == 0L) {
        return("")
      }
      .typst_resolve_page_tokens(.render_typst_inline(ast))
    },
    character(1L)
  )
  paste(parts, collapse = " \\ ")
}

# Substitute the backend-phase `{page}` and `{npages}` tokens inside a
# flat typst fragment. `.render_typst_inline` escapes braces in plain
# text, so the tokens arrive here as `\{page\}` / `\{npages\}`; we
# match the escaped form and swap in the counter expressions (the
# enclosing page band is a `context` block, so the bare counter calls
# resolve). `final()` is the whole-document page total — typst's
# `\pageref{LastPage}`. Idempotent on text that contains neither token.
.typst_resolve_page_tokens <- function(text) {
  text <- gsub(
    "\\{npages\\}",
    "#counter(page).final().first()",
    text,
    fixed = TRUE
  )
  gsub(
    "\\{page\\}",
    "#counter(page).display()",
    text,
    fixed = TRUE
  )
}

# ---------------------------------------------------------------------
# Numbers + colours
# ---------------------------------------------------------------------

# Trim-formatted number for typst source (never scientific).
.typst_num <- function(x) {
  format(x, trim = TRUE, scientific = FALSE)
}

# Map a colour to a typst paint expression. A CSS hex passes straight
# into `rgb()`; any other value R can resolve (named colours) converts
# through `grDevices::col2rgb()` to hex; an unresolvable value degrades
# to black rather than emitting a typst compile error.
.typst_color <- function(color) {
  col <- as.character(color)[[1L]]
  if (grepl("^#[0-9A-Fa-f]{6}$", col) || grepl("^#[0-9A-Fa-f]{3}$", col)) {
    return(sprintf("rgb(\"%s\")", col))
  }
  hex <- tryCatch(
    {
      v <- grDevices::col2rgb(col)
      sprintf("#%02x%02x%02x", v[1L, 1L], v[2L, 1L], v[3L, 1L])
    },
    error = function(e) NULL
  )
  if (is.null(hex)) {
    return("black")
  }
  sprintf("rgb(\"%s\")", hex)
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("typst", backend_typst)
