# backend_rtf.R — RTF 1.9.1 backend. Consumes a resolved
# `tabular_grid` and writes a regulatory-grade UTF-8 `.rtf` file
# whose page chrome, header bands, decimal alignment, multi-page
# pagination, and inline formatting all honour the canonical submission Appendix I
# layout contract. Output renders identically in Microsoft Word
# and LibreOffice; no JVM, no shell-out, no `pandoc`.
#
# Output layout — one `\sect` per `grid@pages` entry. Each section
# carries its own `\sectd` (page geometry: paper size, orientation,
# four margins), optional `{\header}` and `{\footer}` groups
# (driven by `grid@metadata$pagehead_ast` / `$pagefoot_ast`), then
# the section body: page-1 title block, optional continuation
# marker on pages 2+, the data table, and the page-1 footnote
# block. `\sect` carries `\sbkpage` so every section starts on a
# fresh page in the consuming app.
#
# Page chrome (header / footer bands) follows the cross-backend
# contract documented in `R/page_chrome.R`: index 1 hugs the body
# edge; `pagehead` rows emit in REVERSE so index 1 ends up at the
# bottom of the header zone; `pagefoot` rows emit in FORWARD order
# so index 1 ends up at the top of the footer zone. Per-row
# layout is an invisible 1-row 3-cell table inside `{\header}` /
# `{\footer}`, one cell per non-empty slot (cells COLLAPSE for
# NULL / empty slots — no blank-padded cells). Field codes resolve
# `{page}` and `{npages}` at view time:
# `{\field{\*\fldinst PAGE}}` and `{\field{\*\fldinst NUMPAGES}}`.
#
# Font table — `{\fonttbl{\f0\<family>\fprq<pitch> <name>;}}`
# where `<family>` is the RTF family-class keyword (`\froman` /
# `\fswiss` / `\fmodern`) derived from the generic the user
# requested. `\f0` is the body font; we name-reference (not embed)
# the entire stack returned by `.resolve_font_stack(family, "rtf")`
# so the consuming app picks the first installed face.
#
# Inline ASTs (cell text, titles, footnotes, col labels, page-
# chrome cells) render through `.render_rtf_inline()` — a
# recursive walker over the `inline_ast@runs` list:
#
#   plain    -> escaped text (\, {, }, non-ASCII -> \uNNNN?)
#   bold     -> {\b ... \b0}
#   italic   -> {\i ... \i0}
#   sup      -> {\super ... \nosupersub}
#   sub      -> {\sub ... \nosupersub}
#   code     -> {\f1 ... }   (\f1 = the mono branch of the stack)
#   link     -> {\field{\*\fldinst HYPERLINK "..."}{\fldrslt ...}}
#   span     -> children only
#   newline  -> \line       (cell-safe; \par would close the cell)

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a UTF-8 .rtf file. Called by `emit()` via the
# backend registry. Returns the file path invisibly.
backend_rtf <- function(grid, file) {
  lines <- .render_rtf_doc(grid)
  writeLines(lines, file, useBytes = TRUE)
  invisible(file)
}

# ---------------------------------------------------------------------
# Document shell + page composition
# ---------------------------------------------------------------------

# Compose the full RTF document: `{\rtf1` header, font table, one
# section per render panel, closing `}`. Returns a character vector of
# lines ready for `writeLines()`. Pure — no I/O.
#
# Galley one-table model: the engine's per-page descriptors are grouped
# into render panels keyed by `(subgroup, horizontal panel)`. Each panel
# becomes ONE continuous RTF table whose title + spanner + column-label
# rows carry `\trhdr`, so Word repeats them at every page break it
# chooses and paginates the body natively. `\sect` (with `\sbkpage`)
# separates panels only.
.render_rtf_doc <- function(grid) {
  pages <- grid@pages
  meta <- grid@metadata
  preset <- .rtf_resolve_preset(meta$preset)
  cs <- meta$chrome_style %||% chrome_style()

  # Walk every style_node that might contribute a color / font family
  # to the rendered document so the colortbl + fonttbl carry every
  # value used by any cell or chrome surface. Per-cell `\cf<idx>` /
  # `\cb<idx>` / `\f<idx>` references then resolve to a real table
  # entry instead of pointing at the silently-truncated single-slot
  # tables the static helpers emitted.
  colors <- .rtf_collect_colors(pages, cs, preset)
  fonts <- .rtf_collect_fonts(pages, cs, preset)

  preamble <- c(
    "{\\rtf1\\ansi\\ansicpg1252\\deff0\\uc1",
    .rtf_font_table(fonts),
    .rtf_color_table(colors),
    sprintf(
      "\\fs%d",
      as.integer(round(.effective_font_size(preset) * 2))
    )
  )
  preamble <- preamble[nzchar(preamble)]

  if (length(pages) == 0L) {
    section <- .render_rtf_empty(grid, preset, cs, colors, fonts)
    return(c(preamble, section, "}"))
  }

  panels <- .group_pages_into_panels(pages)
  body <- lapply(panels, function(panel_pages) {
    .render_rtf_panel(
      panel_pages = panel_pages,
      meta = meta,
      preset = preset,
      cs = cs,
      colors = colors,
      fonts = fonts
    )
  })
  c(preamble, unlist(body, use.names = FALSE), "}")
}

# Render the RTF skeleton for a spec whose grid has zero pages
# (empty data + no body content). Titles + footnotes still
# appear; the table block is replaced with a centred "(no rows)"
# marker. Single section, no page chrome.
.render_rtf_empty <- function(grid, preset, cs, colors, fonts) {
  meta <- grid@metadata
  c(
    .rtf_section_def(preset, has_pagehead = FALSE, has_pagefoot = FALSE),
    .render_rtf_title_block(meta$titles_ast, preset, cs, colors, fonts),
    paste0(
      "\\pard\\plain",
      .rtf_body_fs(preset),
      "\\qc {\\i (no rows)}\\par"
    ),
    .render_rtf_footnote_block(meta$footnotes_ast, preset, cs, colors, fonts)
  )
}

# Render one panel as one RTF section + one continuous table. The
# section carries its own geometry; `{\header}` (pagehead) and
# `{\footer}` (program-path band + repeating footnotes) repeat on every
# Word page. The table's title + spanner + column-label + subgroup-banner
# rows carry `\trhdr` when their `repeat_*` flag is set, so Word redraws
# them at every page break and paginates the body itself. `\pard\par`
# exits table context before the closing `\sect`.
.render_rtf_panel <- function(panel_pages, meta, preset, cs, colors, fonts) {
  first <- panel_pages[[1L]]
  col_names_vis <- first$col_names
  cols <- meta$cols %||% list()
  # Frame outer LEFT / RIGHT edges, drawn structurally on every table-
  # proper `\trowd` (the manifest is the SSOT; NULL when the frame is off).
  body_borders <- meta$body_borders %||% list()
  cellx <- .rtf_cellx_positions(col_names_vis, cols, preset)
  .rtf_warn_cellx_overflow(cellx, preset)

  # Default to "everything repeats" (the regulatory norm) when a grid
  # carries no repeat flags (e.g. a hand-built fixture).
  rep_titles <- meta$repeat_titles %||% TRUE
  rep_headers <- meta$repeat_headers %||% TRUE
  rep_footnotes <- meta$repeat_footnotes %||% TRUE

  is_cont_panel <- isTRUE((first$panel_index %||% 1L) > 1L)
  continuation <- first$continuation
  has_cont <- is_cont_panel && length(continuation) > 0L

  has_ph <- .page_band_is_populated(meta$pagehead_ast)
  has_pf <- .page_band_is_populated(meta$pagefoot_ast)
  has_titles <- length(meta$titles_ast) > 0L
  has_footnotes <- length(meta$footnotes_ast) > 0L

  # Footnotes ride the repeating `{\footer}` group when repeat_content
  # includes "footnotes"; otherwise they trail the table as paragraphs
  # (landing on the final Word page only). The program-path band always
  # rides `{\footer}`.
  footer_footnotes <- has_footnotes && isTRUE(rep_footnotes)
  trailing_footnotes <- has_footnotes && !isTRUE(rep_footnotes)
  footer_active <- has_pf || footer_footnotes
  # Blank line(s) above the footnotes: the footer surface's
  # `blank_above` (via `style(.at = cells_footnotes())`) wins, else the
  # `body_to_footnote` spacing gap. Stands in for the bottomrule when
  # `preset_minimal()` drops it.
  foot_pad <- rep(
    "\\pard\\plain\\par",
    .rtf_blank_count(
      cs,
      "footer",
      "above",
      .meta_gap(meta, "body_to_footnote", 0L)
    )
  )
  footnote_lines <- if (footer_footnotes) {
    c(
      foot_pad,
      .render_rtf_footnote_block(
        meta$footnotes_ast,
        preset,
        cs,
        colors,
        fonts,
        cellx
      )
    )
  } else {
    character()
  }

  out <- list()
  out[[length(out) + 1L]] <- .rtf_section_def(
    preset,
    has_pagehead = has_ph,
    has_pagefoot = footer_active
  )
  if (has_ph) {
    out[[length(out) + 1L]] <- .rtf_header_group(
      meta$pagehead_ast,
      preset,
      cs,
      colors,
      fonts
    )
  }
  if (footer_active) {
    out[[length(out) + 1L]] <- .rtf_footer_group(
      meta$pagefoot_ast,
      footnote_lines,
      preset,
      cs,
      colors,
      fonts
    )
  }

  pad_top <- .rtf_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_bottom <- .rtf_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )

  # Non-repeating titles: paragraphs ABOVE the table (panel 1 only, so
  # they appear once). The continuation marker, when titles do not
  # repeat, is a standalone right-aligned paragraph on panels 2+.
  cont_in_title <- isTRUE(rep_titles) && has_titles
  if (!isTRUE(rep_titles) && has_titles && !is_cont_panel) {
    titles <- .render_rtf_title_block(
      meta$titles_ast,
      preset,
      cs,
      colors,
      fonts
    )
    if (length(titles) > 0L) {
      blank_par <- "\\pard\\plain\\par"
      out[[length(out) + 1L]] <- c(
        rep(blank_par, pad_top),
        titles,
        rep(blank_par, pad_bottom)
      )
    }
  }
  if (has_cont && !cont_in_title) {
    out[[length(out) + 1L]] <- paste0(
      "\\pard\\plain",
      .rtf_body_fs(preset),
      "\\qr {\\i ",
      .rtf_escape(as.character(continuation)),
      "}\\par"
    )
  }

  # ---- the one continuous table ----
  table_rows <- list()

  # Repeating titles -> `\trhdr` merged rows + `\trhdr` blank spacing rows
  # so the title block and its spacing repeat with the header at every
  # Word page break. The continuation marker rides the first title cell
  # on panels 2+.
  if (isTRUE(rep_titles) && has_titles) {
    table_rows[[length(table_rows) + 1L]] <- .rtf_blank_trhdr_rows(
      pad_top,
      cellx,
      preset
    )
    table_rows[[length(table_rows) + 1L]] <- .rtf_title_header_rows(
      meta$titles_ast,
      cellx,
      preset,
      cs,
      colors,
      fonts,
      continuation = if (has_cont) continuation else character(),
      mark_continuation = has_cont
    )
    table_rows[[length(table_rows) + 1L]] <- .rtf_blank_trhdr_rows(
      pad_bottom,
      cellx,
      preset
    )
  }

  # Per-page BigN: this panel is one subgroup, so read that subgroup's
  # SUFFIXED bands + leaf labels from the page descriptor via the shared
  # resolver. Without big_n it returns the global metadata, leaving
  # existing output byte-identical.
  panel_hdr <- .page_header_for_render(meta, first)
  panel_headers <- panel_hdr$headers
  panel_col_labels_ast <- panel_hdr$col_labels_ast

  table_rows[[length(table_rows) + 1L]] <- .render_rtf_header_bands(
    panel_headers,
    col_names_vis,
    cols,
    cellx,
    preset,
    cs,
    colors,
    fonts,
    trhdr = rep_headers,
    body_borders = body_borders
  )
  # The full-width header top rule rides the topmost header row. When
  # spanner bands are present they own it; otherwise the column-labels
  # row is the top row and carries it.
  has_bands <- is.data.frame(panel_headers) && nrow(panel_headers) > 0L
  table_rows[[length(table_rows) + 1L]] <- .render_rtf_col_labels_row(
    panel_col_labels_ast,
    col_names_vis,
    cols,
    cellx,
    preset,
    cs,
    colors,
    fonts,
    trhdr = rep_headers,
    outer_top = !has_bands,
    body_borders = body_borders
  )
  table_rows[[length(table_rows) + 1L]] <- .render_rtf_subgroup_banner_row(
    first$subgroup_line_ast,
    cellx = cellx,
    preset = preset,
    cs = cs,
    colors = colors,
    fonts = fonts,
    trhdr = rep_headers,
    body_borders = body_borders
  )

  body <- .rtf_concat_panel_body(panel_pages)
  table_rows[[length(table_rows) + 1L]] <- .render_rtf_body_rows(
    body$cells_text,
    col_names_vis,
    cols,
    cellx,
    cells_style = body$cells_style,
    cells_indent = body$cells_indent,
    is_header_row = body$is_header_row,
    is_blank_row = body$is_blank_row,
    host_col = body$host_col,
    keep_with_next = body$keep_with_next,
    preset = preset,
    cs = cs,
    colors = colors,
    fonts = fonts,
    body_borders = body_borders
  )

  out[[length(out) + 1L]] <- unlist(table_rows, use.names = FALSE)

  # Non-repeating footnotes trail the table as paragraphs (final page).
  if (trailing_footnotes) {
    out[[length(out) + 1L]] <- c(
      foot_pad,
      .render_rtf_footnote_block(
        meta$footnotes_ast,
        preset,
        cs,
        colors,
        fonts,
        cellx
      )
    )
  }

  # `\pard\par` exits the table context so Word does not merge this
  # panel's table with the next section's; `\sect` closes the section.
  out[[length(out) + 1L]] <- c("\\pard\\par", "\\sect")
  unlist(out, use.names = FALSE)
}

# Concatenate a panel's page slices into one body. For a native (unsplit)
# grid this is a single page (pass-through); for a split inspection grid
# it stitches the per-page slices back into one continuous table. rbinds
# the cell-text + sidecar matrices (column names preserved so
# `.cell_style_at` keeps indexing by name) and concatenates the parallel
# row vectors in render order.
.rtf_concat_panel_body <- function(panel_pages) {
  first <- panel_pages[[1L]]
  if (length(panel_pages) == 1L) {
    return(list(
      cells_text = first$cells_text,
      cells_style = first$cells_style,
      cells_indent = first$cells_indent,
      is_header_row = first$is_header_row,
      is_blank_row = first$is_blank_row,
      keep_with_next = first$keep_with_next,
      host_col = first$host_col
    ))
  }
  list(
    cells_text = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_text)
    ),
    cells_style = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_style)
    ),
    cells_indent = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_indent)
    ),
    is_header_row = unlist(
      lapply(panel_pages, function(p) p$is_header_row),
      use.names = FALSE
    ),
    is_blank_row = unlist(
      lapply(panel_pages, function(p) p$is_blank_row),
      use.names = FALSE
    ),
    keep_with_next = unlist(
      lapply(panel_pages, function(p) p$keep_with_next),
      use.names = FALSE
    ),
    host_col = first$host_col
  )
}

# `\trhdr` row-prelude token. Marks a table row as a repeating header so
# Word redraws it at the top of every page the table spans.
.rtf_trhdr <- function(trhdr) {
  if (isTRUE(trhdr)) "\\trhdr" else ""
}

# Emit one full-width merged row on the body `\cellx` grid (galley's
# `\clmgf` / `\clmrg` model). Cell 1 carries `\clmgf` + the shared cell
# prelude (borders / shading / valign) + `\cellx[1]`; cells 2..N carry
# `\clmrg` + the same prelude + `\cellx[i]`. Keeping all N boundaries
# identical to the body grid lets Word treat the panel as one coherent
# table (a single trailing `\cellx` would desync the column model).
# `first_body` is the fully-rendered first-cell paragraph (without the
# trailing `\cell`); the remaining cells are empty. `trhdr` marks a
# repeating header row; `keep` adds `\trkeep` / and the caller threads
# `\keepn` into `first_body`.
.rtf_merged_row <- function(
  first_body,
  cellx,
  preset,
  trhdr = FALSE,
  keep = FALSE,
  prelude = "",
  trgaph = 108L,
  body_borders = NULL
) {
  n <- length(cellx)
  if (n == 0L) {
    return(character())
  }
  cell_defs <- character(n)
  cell_defs[[1L]] <- paste0(
    prelude,
    "\\clmgf",
    sprintf("\\cellx%d", as.integer(cellx[[1L]]))
  )
  if (n > 1L) {
    for (i in seq.int(2L, n)) {
      cell_defs[[i]] <- paste0(
        prelude,
        "\\clmrg",
        sprintf("\\cellx%d", as.integer(cellx[[i]]))
      )
    }
  }
  cell_bodies <- c(
    paste0(first_body, "\\cell"),
    rep("\\pard\\plain\\intbl\\cell", n - 1L)
  )
  c(
    paste0(
      "\\trowd",
      .rtf_trhdr(trhdr),
      sprintf("\\trgaph%d\\trqc", as.integer(trgaph)),
      .rtf_row_height_str(preset),
      if (isTRUE(keep)) "\\trkeep" else "",
      .rtf_row_frame_edges(body_borders)
    ),
    cell_defs,
    cell_bodies,
    "\\row"
  )
}

# Render the title block as `\trhdr` merged rows (one per title line),
# centred + bold by the title-surface cascade. The continuation marker,
# when present, is appended to the FIRST title line's text on panels 2+.
.rtf_title_header_rows <- function(
  titles_ast,
  cellx,
  preset,
  cs,
  colors,
  fonts,
  continuation = character(),
  mark_continuation = FALSE
) {
  n <- length(titles_ast)
  if (n == 0L || length(cellx) == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "{\\b "
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"
  rows <- vector("list", n)
  # Honour preset(whitespace=) on this default (trhdr) title path too;
  # the sibling .render_rtf_title_block already threads it, so without
  # this `collapse` is silently a no-op on repeated page titles.
  ws_preserve <- .preset_ws_preserve(preset)
  for (i in seq_len(n)) {
    halign <- if (
      is_style_node(surface_node) &&
        length(surface_node@halign) == 1L &&
        !is.na(surface_node@halign)
    ) {
      surface_node@halign
    } else {
      h <- .effective_title_halign(preset, line_index = i, n_lines = n)
      if (is.na(h)) "center" else h
    }
    inner <- .render_rtf_inline(titles_ast[[i]], preserve = ws_preserve)
    if (i == 1L && isTRUE(mark_continuation) && length(continuation) > 0L) {
      inner <- paste0(
        inner,
        " ",
        .rtf_escape(as.character(continuation))
      )
    }
    first_body <- paste0(
      "\\pard\\plain\\intbl",
      .rtf_body_fs(preset),
      .rtf_align_token(halign),
      surface_props,
      " ",
      bold_open,
      inner,
      bold_close
    )
    rows[[i]] <- .rtf_merged_row(first_body, cellx, preset, trhdr = TRUE)
  }
  unlist(rows, use.names = FALSE)
}

# Emit `n` blank `\trhdr` merged rows for vertical spacing inside the
# repeating header block (so the gap repeats with the header at every
# Word page break).
.rtf_blank_trhdr_rows <- function(n, cellx, preset) {
  if (n <= 0L || length(cellx) == 0L) {
    return(character())
  }
  one <- .rtf_merged_row(
    paste0("\\pard\\plain\\intbl", .rtf_body_fs(preset)),
    cellx,
    preset,
    trhdr = TRUE
  )
  rep(one, n)
}

# Warn once per panel when the rightmost `\cellx` overruns the printable
# area (paper width minus left/right margins): Word renders the overflow
# off-page. Neither r2rtf nor galley diagnoses this; surfacing it lets
# the user widen the page or shrink columns before shipping.
.rtf_warn_cellx_overflow <- function(cellx, preset) {
  if (length(cellx) == 0L) {
    return(invisible())
  }
  paper <- .rtf_paper_twips(preset@paper_size, preset@orientation)
  margins <- .rtf_margins_twips(preset@margins)
  printable <- paper$width - margins$left - margins$right
  last <- as.integer(cellx[[length(cellx)]])
  if (last > printable) {
    over_in <- round((last - printable) / .tabular_unit_twips[["in"]], 2)
    cli::cli_warn(
      c(
        "Table is wider than the printable area.",
        "x" = "Columns overrun the page by {over_in} in; the overflow renders off-page in Word.",
        "i" = "Widen the page, shrink margins, or set narrower {.code col_spec(width = ...)}."
      ),
      class = "tabular_warning_layout"
    )
  }
  invisible()
}

# Resolve the blank-line count for a chrome surface side. chrome_style
# wins when the user set `style(blank_above = N, at = cells_title())`;
# otherwise the legacy preset `*_pad_*` scalar fills in. Always
# returns a non-negative whole integer.
.rtf_blank_count <- function(cs, surface, side, legacy) {
  node <- .chrome_surface_at(cs, surface)
  prop <- if (identical(side, "above")) node@blank_above else node@blank_below
  if (length(prop) == 1L && !is.na(prop)) {
    return(max(0L, as.integer(prop)))
  }
  max(0L, as.integer(legacy))
}

# ---------------------------------------------------------------------
# Section definition + page geometry
# ---------------------------------------------------------------------

# Resolve the active preset, falling back to factory defaults when
# the grid carries no preset attachment (matches backend_latex /
# backend_html convention).
.rtf_resolve_preset <- function(preset) {
  if (is.null(preset) || !is_preset_spec(preset)) preset_spec() else preset
}

# Compose the `\sectd ...` section definition: paper width / height
# in twips (from preset@paper_size + @orientation), four margins
# (from preset@margins via the .parse_dim / .dim_to_twips pipe),
# `\lndscpsxn` for landscape, `\headery` / `\footery` only when a
# page band is populated (saves dead-space reservation otherwise).
.rtf_section_def <- function(
  preset,
  has_pagehead,
  has_pagefoot
) {
  paper <- .rtf_paper_twips(preset@paper_size, preset@orientation)
  margins <- .rtf_margins_twips(preset@margins)

  # Margins are exactly the preset values, never enlarged. The footer
  # (footnotes + program-path band) sits at `\footery = bottom margin`
  # and flows DOWNWARD; the header at `\headery` flows UPWARD. Word
  # auto-expands either band into the body when its content exceeds
  # the margin, so a tall footnote block eats body space instead of
  # growing the page margin (galley's model).
  parts <- c(
    "\\sectd\\sbkpage",
    if (identical(preset@orientation, "landscape")) "\\lndscpsxn" else "",
    sprintf("\\pgwsxn%d\\pghsxn%d", paper$width, paper$height),
    sprintf(
      "\\margt%d\\margb%d\\margl%d\\margr%d",
      margins$top,
      margins$bottom,
      margins$left,
      margins$right
    )
  )

  if (has_pagehead) {
    # Header starts one body line above the top margin and flows up.
    head_line <- as.integer(round(preset@font_size * 28))
    headery <- max(360L, margins$top - head_line)
    parts <- c(parts, sprintf("\\headery%d", headery))
  }
  if (has_pagefoot) {
    # Footer sits at the bottom-margin line and flows downward; Word
    # expands it upward into the body when footnotes are tall.
    parts <- c(parts, sprintf("\\footery%d", margins$bottom))
  }
  paste(parts[nzchar(parts)], collapse = "")
}

# Paper dimensions in twips. Defaults match the user's preset
# defaults (`letter`); recognises `letter`, `legal`, `a4`. Any
# other paper key falls back to letter to keep the output valid.
.rtf_paper_twips <- function(paper, orientation) {
  dims <- switch(
    paper,
    letter = list(width = 12240L, height = 15840L),
    legal = list(width = 12240L, height = 20160L),
    a4 = list(width = 11906L, height = 16838L),
    list(width = 12240L, height = 15840L)
  )
  if (identical(orientation, "landscape")) {
    dims <- list(width = dims$height, height = dims$width)
  }
  dims
}

# Resolve `preset@margins` (CSS shorthand: length 1, 2, or 4)
# into twips for each of the four sides. Length 1 = all sides;
# length 2 = top/bottom, left/right; length 4 = top, right,
# bottom, left.
.rtf_margins_twips <- function(margins) {
  parsed <- .parse_margins(margins)
  twips <- as.integer(round(vapply(parsed, .dim_to_twips, numeric(1L))))
  if (length(twips) == 1L) {
    return(list(
      top = twips[[1L]],
      right = twips[[1L]],
      bottom = twips[[1L]],
      left = twips[[1L]]
    ))
  }
  if (length(twips) == 2L) {
    return(list(
      top = twips[[1L]],
      right = twips[[2L]],
      bottom = twips[[1L]],
      left = twips[[2L]]
    ))
  }
  list(
    top = twips[[1L]],
    right = twips[[2L]],
    bottom = twips[[3L]],
    left = twips[[4L]]
  )
}

# ---------------------------------------------------------------------
# Page chrome — {\header} / {\footer} groups
# ---------------------------------------------------------------------

# `{\header ...}` group. Emits one invisible 1-row 3-cell table
# per band row, in REVERSE index order so row 1 (body-edge) ends
# up at the bottom of the header zone, closest to the table body.
.rtf_header_group <- function(pagehead_ast, preset, cs, colors, fonts) {
  nrow_band <- .page_band_nrow(pagehead_ast)
  order <- rev(seq_len(nrow_band))
  rows <- lapply(order, function(i) {
    .rtf_chrome_row(
      .page_band_row(pagehead_ast, i),
      preset,
      cs,
      "pagehead",
      colors,
      fonts
    )
  })
  c("{\\header", unlist(rows, use.names = FALSE), "}")
}

# `{\footer ...}` group. Emits one invisible 1-row 3-cell table
# per band row, in FORWARD index order so row 1 (body-edge) ends
# up at the top of the footer zone.
.rtf_footer_group <- function(
  pagefoot_ast,
  footnote_lines,
  preset,
  cs,
  colors,
  fonts
) {
  nrow_band <- .page_band_nrow(pagefoot_ast)
  rows <- lapply(seq_len(nrow_band), function(i) {
    .rtf_chrome_row(
      .page_band_row(pagefoot_ast, i),
      preset,
      cs,
      "pagefoot",
      colors,
      fonts
    )
  })
  # Footnote paragraphs sit ABOVE the program-path band so the footer
  # reads footnotes-then-program-path top to bottom (the regulatory layout contract).
  c("{\\footer", footnote_lines, unlist(rows, use.names = FALSE), "}")
}

# Render ONE band row as an invisible 3-cell table (Left / Center
# / Right). Cells with empty ASTs collapse — only non-empty slots
# emit a `\cell`. Cell widths divide the printable area evenly
# across non-empty cells; `\cellx<position>` is cumulative.
.rtf_chrome_row <- function(
  row_slots_ast,
  preset,
  cs = NULL,
  surface = NULL,
  colors = NULL,
  fonts = NULL
) {
  slots <- c("left", "center", "right")
  alignments <- c(left = "\\ql", center = "\\qc", right = "\\qr")
  cells <- list()
  for (s in slots) {
    ast <- row_slots_ast[[s]]
    if (is_inline_ast(ast) && length(ast@runs) > 0L) {
      # Per-slot text props (bold/italic/color/font) from
      # cells_pagehead(slot = s) (Thread G). Pagehead/pagefoot slots own
      # their halign via slot position, so the surface halign is not
      # applied here.
      slot_node <- if (!is.null(surface)) {
        .chrome_surface_at_slot(cs, surface, slot = s)
      } else {
        NULL
      }
      cells[[length(cells) + 1L]] <- list(
        align = alignments[[s]],
        text = .rtf_resolve_page_tokens(.render_rtf_inline(ast)),
        props = .rtf_chrome_text_props(slot_node, colors, fonts),
        shd = .rtf_cell_shading(slot_node, colors)
      )
    }
  }
  if (length(cells) == 0L) {
    return(character())
  }

  paper <- .rtf_paper_twips(preset@paper_size, preset@orientation)
  margins <- .rtf_margins_twips(preset@margins)
  printable <- paper$width - margins$left - margins$right
  per_cell <- as.integer(printable %/% length(cells))

  # Band rule (Thread G): `style(border_bottom = brdr(), .at =
  # cells_pagehead())` draws a rule on the page-header band's bottom edge;
  # `border_top` on the footer band's top edge. Read from the chrome
  # border region (`pagehead_bottom` / `pagefoot_top`); the other three
  # edges and the default (no region) stay borderless.
  band_edge <- if (identical(surface, "pagefoot")) "top" else "bottom"
  region <- if (identical(surface, "pagehead")) {
    "pagehead_bottom"
  } else if (identical(surface, "pagefoot")) {
    "pagefoot_top"
  } else {
    NULL
  }
  edge_seg <- if (is.null(region)) {
    paste0("\\clbrdr", substr(band_edge, 1L, 1L), "\\brdrnone")
  } else {
    .rtf_chrome_border_seg(cs, region, band_edge, "none")
  }
  other_segs <- paste0(
    vapply(
      setdiff(c("top", "bottom", "left", "right"), band_edge),
      function(side) paste0("\\clbrdr", substr(side, 1L, 1L), "\\brdrnone"),
      character(1L)
    ),
    collapse = ""
  )

  cellx_lines <- character(length(cells))
  cumulative <- 0L
  for (i in seq_along(cells)) {
    cumulative <- cumulative + per_cell
    pos <- if (i == length(cells)) printable else cumulative
    cellx_lines[[i]] <- paste0(
      other_segs,
      edge_seg,
      cells[[i]]$shd %||% "",
      sprintf("\\cellx%d", as.integer(pos))
    )
  }

  cell_bodies <- vapply(
    cells,
    function(c) {
      paste0(
        "\\pard\\plain\\intbl",
        # `\plain` resets to the RTF default 12pt; re-emit the preset body
        # size so page chrome matches the table (mirrors the title / footnote
        # / body surfaces). `c$props` follows, so an explicit
        # `style(.at = cells_pagehead())` font override still wins (last-wins).
        .rtf_body_fs(preset),
        " ",
        c$align,
        c$props,
        " ",
        c$text,
        "\\cell"
      )
    },
    character(1L)
  )

  c(
    "\\trowd\\trgaph0\\trleft0",
    cellx_lines,
    cell_bodies,
    "\\row"
  )
}

# Substitute the backend-phase `{page}` and `{npages}` tokens
# inside a flat RTF fragment string. The escape pass converts `{`
# / `}` to `\{` / `\}`, so tokens arrive here as `\{page\}` /
# `\{npages\}`. Swap in Word field codes that Word and
# LibreOffice expand at view / print time.
.rtf_resolve_page_tokens <- function(text) {
  text <- gsub(
    "\\{npages\\}",
    "{\\field{\\*\\fldinst NUMPAGES}}",
    text,
    fixed = TRUE
  )
  text <- gsub(
    "\\{page\\}",
    "{\\field{\\*\\fldinst PAGE}}",
    text,
    fixed = TRUE
  )
  text
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line emits as a paragraph whose alignment
# and text properties cascade from `chrome_style$surfaces$title`
# (set by `style(at = cells_title(), ...)`) down to
# `chrome_style$surfaces$title@halign` (legacy theme layer). Bold by
# default; the cascade-default alignment is centre when nothing
# overrides.
# Body font-size token (`\fsN`, N = 2 * point size). RTF's `\plain`
# resets the character font size to its 12pt default, so every
# paragraph must re-emit this for a uniform size across titles, body,
# and footnotes (galley's model). A per-surface font_size override
# emitted after this token wins.
.rtf_body_fs <- function(preset) {
  sprintf("\\fs%d", as.integer(round(.effective_font_size(preset) * 2)))
}

# Row-height + zero-vertical-padding token (galley's model). Pins a
# uniform minimum row height (`\trrh`, grows for multi-line cells) and
# strips Word's default top/bottom cell margins, so every row renders
# at the same compact height regardless of content (continuous-stat
# rows no longer sit taller than categorical rows).
.rtf_row_height_str <- function(preset) {
  rh <- .row_height_twips(.effective_font_size(preset))
  sprintf("\\trrh%d\\trpaddt0\\trpaddft3\\trpaddb0\\trpaddfb3", rh)
}

.render_rtf_title_block <- function(
  titles_ast,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL
) {
  n <- length(titles_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  ws_preserve <- .preset_ws_preserve(preset)
  vapply(
    seq_len(n),
    function(i) {
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        h <- .effective_title_halign(preset, line_index = i, n_lines = n)
        if (is.na(h)) "center" else h
      }
      align_tok <- .rtf_align_token(halign)
      bold_open <- if (
        is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
      ) {
        ""
      } else {
        "{\\b "
      }
      bold_close <- if (identical(bold_open, "")) "" else "}"
      paste0(
        "\\pard\\plain",
        .rtf_body_fs(preset),
        align_tok,
        surface_props,
        " ",
        bold_open,
        .render_rtf_inline(titles_ast[[i]], preserve = ws_preserve),
        bold_close,
        "\\par"
      )
    },
    character(1L)
  )
}

# Footnote block: each footnote line emits as a paragraph whose
# alignment and text props cascade from
# `chrome_style$surfaces$footer` (set by
# `style(at = cells_footnotes(), ...)`) down to
# `chrome_style$surfaces$footer@halign` (legacy theme layer).
# Slightly smaller font size by default; the cascade default
# halign is left.
.render_rtf_footnote_block <- function(
  footnotes_ast,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  cellx = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  ws_preserve <- .preset_ws_preserve(preset)
  # Footer font size cascade: chrome_style@font_size > body font_size.
  # Footnotes default to the SAME size as the body (uniform typography);
  # a per-surface override still wins.
  fs_pt <- if (
    is_style_node(surface_node) &&
      length(surface_node@font_size) == 1L &&
      !is.na(surface_node@font_size)
  ) {
    as.numeric(surface_node@font_size)
  } else {
    .effective_font_size(preset)
  }
  fs_half <- as.integer(round(fs_pt * 2))
  # Strip the font_size token from surface_props since we emit it
  # explicitly on the paragraph; .rtf_chrome_text_props drops it
  # when we override below.
  surface_props_no_fs <- .rtf_chrome_text_props(
    surface_node,
    colors,
    fonts,
    skip = "font_size"
  )
  paras <- vapply(
    seq_len(n),
    function(i) {
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        h <- .effective_footnote_halign(
          preset,
          line_index = i,
          n_lines = n
        )
        if (is.na(h)) "left" else h
      }
      align_tok <- .rtf_align_token(halign)
      paste0(
        "\\pard\\plain",
        align_tok,
        sprintf("\\fs%d ", fs_half),
        surface_props_no_fs,
        .render_rtf_inline(footnotes_ast[[i]], preserve = ws_preserve),
        "\\par"
      )
    },
    character(1L)
  )
  # The footnote-section opening rule (footnoterule). OFF by default:
  # the body `bottomrule` is the mutually-exclusive default closer, so
  # the footnote block carries no rule of its own. When the user opts in
  # via the `rules` knob, draw it as a TABLE-WIDTH merged-cell top border
  # (the same `\cellx`-grid idiom as the title / spanner rows), NOT a
  # paragraph `\brdrt` border -- a Word reader stretches a paragraph
  # border to the full page text column (margin to margin), which is the
  # page-width defect. The merged row is sized to the table `\cellx`
  # grid, so the rule matches the toprule / bottomrule width.
  foot_triple <- .chrome_border_at(cs, "footer_top")
  rule_row <- .rtf_foot_rule_row(foot_triple, cellx, preset)
  c(rule_row, paras)
}

# Build the table-width footnote-opening rule as a merged-cell row with
# a top border. NULL / "none" triple, or no resolved `\cellx` grid ->
# no rule (character(0)).
.rtf_foot_rule_row <- function(triple, cellx, preset) {
  if (
    is.null(triple) ||
      identical(triple$style, "none") ||
      length(cellx) == 0L
  ) {
    return(character())
  }
  style_tok <- switch(
    triple$style,
    solid = "\\brdrs",
    dashed = "\\brdrdash",
    dotted = "\\brdrdot",
    double = "\\brdrdb",
    dashdot = "\\brdrdashd",
    "\\brdrs"
  )
  twips <- max(
    1L,
    as.integer(round((triple$width %||% .tabular_rule_width) * 20))
  )
  top_token <- paste0("\\clbrdrt", style_tok, sprintf("\\brdrw%d", twips))
  .rtf_merged_row("", cellx, preset, prelude = top_token)
}

# Helper — render the run-level text props from a chrome surface
# node, with an optional `skip` set to drop selected props (e.g.
# the footer block emits font_size explicitly and skips it here).
# Returns a string like " \\b \\cf3 \\f2 " (always starts and ends
# with whitespace when non-empty so it can be concatenated between
# the alignment token and the body inline AST).
.rtf_chrome_text_props <- function(
  node,
  colors = NULL,
  fonts = NULL,
  skip = character()
) {
  if (!is_style_node(node)) {
    return("")
  }
  parts <- character()
  if (isTRUE(node@bold) && !("bold" %in% skip)) {
    parts <- c(parts, "\\b")
  }
  if (isTRUE(node@italic) && !("italic" %in% skip)) {
    parts <- c(parts, "\\i")
  }
  if (isTRUE(node@underline) && !("underline" %in% skip)) {
    parts <- c(parts, "\\ul")
  }
  fs <- node@font_size
  if (
    length(fs) == 1L &&
      !is.na(fs) &&
      is.numeric(fs) &&
      !("font_size" %in% skip)
  ) {
    parts <- c(parts, sprintf("\\fs%d", as.integer(round(fs * 2))))
  }
  if (!is.null(colors) && !("color" %in% skip)) {
    color <- node@color
    if (length(color) == 1L && !is.na(color) && nzchar(color)) {
      idx <- colors$lookup(color)
      if (!is.na(idx)) {
        parts <- c(parts, sprintf("\\cf%d", as.integer(idx)))
      }
    }
  }
  if (!is.null(fonts) && !("font_family" %in% skip)) {
    ff <- node@font_family
    if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
      idx <- fonts$lookup(ff)
      if (!is.na(idx) && idx > 0L) {
        parts <- c(parts, sprintf("\\f%d", as.integer(idx)))
      }
    }
  }
  if (length(parts) == 0L) {
    return("")
  }
  paste0(" ", paste(parts, collapse = ""), " ")
}

# ---------------------------------------------------------------------
# Table assembly
# ---------------------------------------------------------------------

# Render the subgroup banner as a full-width merged row on the body
# `\cellx` grid (`\clmgf` / `\clmrg`), centred + bold, with a top +
# bottom rule for visual separation from the column-header band above and
# the body rows below. `trhdr` repeats the banner as a header within the
# subgroup's pages. Returns character(0) when the page carries no
# subgroup runtime.
.render_rtf_subgroup_banner_row <- function(
  subgroup_line_ast,
  cellx,
  preset = NULL,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  trhdr = FALSE,
  body_borders = NULL
) {
  if (
    is.null(subgroup_line_ast) ||
      !is_inline_ast(subgroup_line_ast) ||
      length(subgroup_line_ast@runs) == 0L ||
      length(cellx) == 0L
  ) {
    return(character())
  }
  inner <- .render_rtf_inline(subgroup_line_ast)
  surface_node <- .chrome_surface_at(cs, "subgroup")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    h <- .effective_subgroup_halign(preset)
    if (is.na(h)) "center" else h
  }
  valign <- if (
    is_style_node(surface_node) &&
      length(surface_node@valign) == 1L &&
      !is.na(surface_node@valign)
  ) {
    surface_node@valign
  } else {
    .effective_subgroup_valign(preset)
  }
  align_tok <- .rtf_align_token(halign)
  valign_tok <- .rtf_valign_token(valign)
  # Subgroup banner chrome rules: chrome_style$borders takes priority
  # over the legacy `solid top / solid bottom` backend defaults. The
  # prelude rides every merged cell so the rules span the full width.
  top_tok <- .rtf_chrome_border_seg(cs, "subgroup_top", "top", "solid")
  bot_tok <- .rtf_chrome_border_seg(cs, "subgroup_bottom", "bottom", "solid")
  shading <- .rtf_cell_shading(surface_node, colors)
  prelude <- paste0(
    top_tok,
    bot_tok,
    .rtf_border_seg("left", NULL, "none"),
    .rtf_border_seg("right", NULL, "none"),
    shading,
    valign_tok
  )
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "{\\b "
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"
  first_body <- paste0(
    "\\pard\\plain\\intbl",
    .rtf_body_fs(preset),
    align_tok,
    surface_props,
    " ",
    bold_open,
    inner,
    bold_close
  )
  .rtf_merged_row(
    first_body,
    cellx,
    preset,
    trhdr = trhdr,
    prelude = prelude,
    body_borders = body_borders
  )
}

# Compute cumulative `\cellx` positions for the visible columns.
# Columns with an explicit width route through `.parse_dim` ->
# twips; percent widths scale against the printable area; columns
# without a declared width get equal shares of the leftover space.
.rtf_cellx_positions <- function(col_names_vis, cols, preset) {
  paper <- .rtf_paper_twips(preset@paper_size, preset@orientation)
  margins <- .rtf_margins_twips(preset@margins)
  printable <- paper$width - margins$left - margins$right
  n <- length(col_names_vis)
  if (n == 0L) {
    return(integer(0L))
  }

  # Engine resolves every visible col_spec@width to numeric inches
  # before backends see the grid. Fallback for the rare case of a
  # synthesised column (or a backend invoked without the engine
  # pass): equal share of the printable area.
  widths <- vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      if (!is_col_spec(cs)) {
        return(NA_real_)
      }
      w <- cs@width
      if (is.numeric(w) && length(w) == 1L && !is.na(w)) {
        return(w * .tabular_unit_twips[["in"]])
      }
      NA_real_
    },
    numeric(1L)
  )

  declared <- !is.na(widths)
  remaining <- printable - sum(widths[declared])
  share <- if (any(!declared)) {
    max(remaining %/% sum(!declared), 720L)
  } else {
    0L
  }
  widths[!declared] <- share

  positions <- as.integer(round(cumsum(widths)))
  positions
}

# Render multi-level header bands. `headers` is a data.frame with
# `depth`, `label`, `span_cols`. For each band-row depth we walk
# visible columns left-to-right, group contiguous runs sharing
# the same band label, and emit one cell per run with the
# appropriate `\cellx` boundary. Returns a character vector of
# zero or more `\trowd ... \row` blocks.
.render_rtf_header_bands <- function(
  headers,
  col_names_vis,
  cols,
  cellx,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  trhdr = FALSE,
  body_borders = NULL
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  out <- vector("list", length(depths))
  for (k in seq_along(depths)) {
    labels <- .band_labels_for_depth(headers, depths[[k]], col_names_vis)
    runs <- .group_contiguous_runs(labels)
    # The first (topmost) band row carries the full-width header top rule.
    out[[k]] <- .rtf_band_row(
      runs,
      cellx,
      preset,
      cs,
      colors,
      fonts,
      trhdr,
      outer_top = (k == 1L),
      body_borders = body_borders
    )
  }
  unlist(out, use.names = FALSE)
}

# Resolve a chrome border region into an RTF cell-prelude border
# segment. chrome_style$borders takes priority; otherwise the
# backend default. `side` is the cell side ("top" / "bottom" /
# "left" / "right") this segment writes to — chrome border regions
# map onto cell sides via the caller's choice (e.g. "header_top"
# maps to the cell's top side).
.rtf_chrome_border_seg <- function(cs, region, side, backend_default) {
  .rtf_border_seg_from_triple(
    .chrome_border_at(cs, region),
    side,
    backend_default
  )
}

# Build a `\clbrdr<side>...` cell-border fragment from a resolved
# (style, width, color) triple. NULL falls back to the backend default
# (solid -> the 0.5pt rule; otherwise `\brdrnone`); an explicit "none"
# clears the edge.
.rtf_border_seg_from_triple <- function(triple, side, backend_default) {
  letter <- substr(side, 1L, 1L)
  prefix <- paste0("\\clbrdr", letter)
  if (is.null(triple)) {
    if (identical(backend_default, "solid")) {
      return(paste0(prefix, "\\brdrs\\brdrw10"))
    }
    return(paste0(prefix, "\\brdrnone"))
  }
  if (identical(triple$style, "none")) {
    return(paste0(prefix, "\\brdrnone"))
  }
  style_tok <- switch(
    triple$style,
    solid = "\\brdrs",
    dashed = "\\brdrdash",
    dotted = "\\brdrdot",
    double = "\\brdrdb",
    dashdot = "\\brdrdashd",
    "\\brdrs"
  )
  twips <- max(1L, as.integer(round(as.numeric(triple$width) * 20)))
  paste0(prefix, style_tok, sprintf("\\brdrw%d", twips))
}

# Effective RTF top-border fragment for the topmost header row: the
# outer-frame `outer_top` triple wins over the chrome `header_top` rule,
# so `cells_table(side = "outer")` thickens the true table top (above the
# column-header band) rather than the first body row.
.rtf_header_top_seg <- function(cs, body_borders) {
  ot <- if (is.list(body_borders)) body_borders[["outer_top"]] else NULL
  if (!is.null(ot)) {
    return(.rtf_border_seg_from_triple(ot, "top", "solid"))
  }
  .rtf_chrome_border_seg(cs, "header_top", "top", "solid")
}

# Emit one band row on the body `\cellx` grid. Each contiguous run of
# columns sharing a band label becomes one merged cell (`\clmgf` on the
# run's first column, `\clmrg` on the rest) carrying the label; a
# single-column run is a plain cell. Every column gets a `\cellx`
# boundary equal to the body grid, so the band row stays column-aligned
# with the data rows in the one continuous table. The full-width header
# top rule rides the TOPMOST header row only (`outer_top = TRUE`), across
# every column (the "long" rule above all spanning headers). Each band's
# OWN bottom rule is a cmidrule(lr): only band cells carry it; flanking
# cells over unmapped columns stay borderless. `trhdr` marks the row
# repeating so Word redraws it at every page break.
.rtf_band_row <- function(
  runs,
  cellx,
  preset = NULL,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  trhdr = FALSE,
  outer_top = FALSE,
  body_borders = NULL
) {
  ncol <- length(cellx)
  if (ncol == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "header")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  shading <- .rtf_cell_shading(surface_node, colors)
  top_tok <- .rtf_header_top_seg(cs, body_borders)
  bot_tok <- .rtf_chrome_border_seg(cs, "header_bottom", "bottom", "solid")
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    "center"
  }
  align_tok <- .rtf_align_token(halign)
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "{\\b "
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"

  cell_defs <- character(ncol)
  cell_bodies <- character(ncol)
  col <- 1L
  for (run in runs) {
    run_len <- run$length
    is_band <- !is.na(run$value)
    # Top rule is the full-width header rule, emitted only on the topmost
    # header row (across band AND flanking cells). The bottom rule is the
    # band's cmidrule(lr): only band cells carry it; flanking cells stay
    # borderless so the spanner underline does not run the full width.
    top_tok_i <- if (isTRUE(outer_top)) top_tok else "\\clbrdrt\\brdrnone"
    bot_tok_i <- if (is_band) bot_tok else "\\clbrdrb\\brdrnone"
    prelude <- paste0(
      top_tok_i,
      bot_tok_i,
      "\\clbrdrl\\brdrnone\\clbrdrr\\brdrnone",
      shading,
      .rtf_cell_padding(surface_node)
    )
    label_body <- if (is_band) {
      paste0(
        "\\pard\\plain\\intbl",
        .rtf_body_fs(preset),
        align_tok,
        surface_props,
        " ",
        bold_open,
        # Convert embedded newlines to RTF `\line` so a multi-line band
        # label (e.g. a per-page BigN `\n(N=x)` suffix) breaks inside the
        # cell instead of closing it. A label with no `\n` is unchanged,
        # so every existing single-line band stays byte-identical. Not
        # `.rtf_escape_cell` here, which also peels footnote sentinels
        # and rewrites significant whitespace on band labels.
        gsub("\n", "\\line ", .rtf_escape(run$value), fixed = TRUE),
        bold_close,
        "\\cell"
      )
    } else {
      paste0(
        "\\pard\\plain\\intbl",
        .rtf_body_fs(preset),
        align_tok,
        surface_props,
        " \\cell"
      )
    }
    for (k in seq_len(run_len)) {
      idx <- col + k - 1L
      merge_tok <- if (run_len == 1L) {
        ""
      } else if (k == 1L) {
        "\\clmgf"
      } else {
        "\\clmrg"
      }
      cell_defs[[idx]] <- paste0(
        prelude,
        merge_tok,
        sprintf("\\cellx%d", as.integer(cellx[[idx]]))
      )
      cell_bodies[[idx]] <- if (k == 1L) {
        label_body
      } else {
        "\\pard\\plain\\intbl\\cell"
      }
    }
    col <- col + run_len
  }
  c(
    paste0(
      "\\trowd",
      .rtf_trhdr(trhdr),
      "\\trgaph108\\trqc",
      .rtf_row_height_str(preset),
      .rtf_row_frame_edges(body_borders)
    ),
    cell_defs,
    cell_bodies,
    "\\row"
  )
}

# Column-labels row: one cell per visible column, alignment via
# the header cascade (col_spec@align / @valign >
# chrome_style$surfaces$header@halign / header_valign > backend
# default), label from `col_labels_ast` (the parsed AST already
# created by engine_format). The full-width header bottom rule always
# closes this row; the full-width header top rule is emitted only when
# this row is the topmost header row (`outer_top = TRUE`, i.e. no spanner
# bands sit above it) so the "long" top rule is not doubled under a band.
.render_rtf_col_labels_row <- function(
  col_labels_ast,
  col_names_vis,
  cols,
  cellx,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  trhdr = FALSE,
  outer_top = TRUE,
  body_borders = NULL
) {
  cellx_lines <- character(length(col_names_vis))
  cell_bodies <- character(length(col_names_vis))
  surface_node <- .chrome_surface_at(cs, "header")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  shading <- .rtf_cell_shading(surface_node, colors)
  top_tok <- if (isTRUE(outer_top)) {
    .rtf_header_top_seg(cs, body_borders)
  } else {
    "\\clbrdrt\\brdrnone"
  }
  bot_tok <- .rtf_chrome_border_seg(cs, "header_bottom", "bottom", "solid")
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "{\\b "
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"
  for (i in seq_along(col_names_vis)) {
    nm <- col_names_vis[[i]]
    col <- cols[[nm]]
    # Per-column alignment wins over the chrome surface default —
    # users picking `col_spec(align = "right")` expect the header
    # cell to follow the column. Surface halign provides the
    # cascade default when no col_spec sets one.
    halign <- if (
      is_col_spec(col) &&
        length(col@align) == 1L &&
        !is.na(col@align)
    ) {
      # A decimal column's header centres over the column (TFL centroid
      # convention, HTML parity); the body stays decimal / right-aligned.
      if (col@align == "decimal") "center" else col@align
    } else if (
      is_style_node(surface_node) &&
        length(surface_node@halign) == 1L &&
        !is.na(surface_node@halign)
    ) {
      surface_node@halign
    } else {
      .effective_header_halign(col, preset)
    }
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
    # Header cells default to bottom valign (HTML parity) only when
    # nothing in the cascade set one, so a wrapped multi-line header sits
    # flush with single-line neighbours.
    if (is.na(valign)) {
      valign <- "bottom"
    }
    align_tok <- .rtf_align_token(halign)
    valign_tok <- .rtf_valign_token(valign)
    cellx_lines[[i]] <- paste0(
      top_tok,
      bot_tok,
      .rtf_border_seg("left", NULL, "none"),
      .rtf_border_seg("right", NULL, "none"),
      shading,
      .rtf_cell_padding(surface_node),
      valign_tok,
      sprintf("\\cellx%d", as.integer(cellx[[i]]))
    )
    ast <- col_labels_ast[[nm]]
    label <- if (is.null(ast)) {
      .rtf_escape(nm)
    } else {
      .render_rtf_inline(ast, preserve = .preset_ws_preserve(preset))
    }
    cell_bodies[[i]] <- paste0(
      "\\pard\\plain\\intbl ",
      .rtf_body_fs(preset),
      align_tok,
      surface_props,
      " ",
      bold_open,
      label,
      bold_close,
      "\\cell"
    )
  }
  c(
    paste0(
      "\\trowd",
      .rtf_trhdr(trhdr),
      "\\trgaph108\\trqc",
      .rtf_row_height_str(preset),
      .rtf_row_frame_edges(body_borders)
    ),
    cellx_lines,
    cell_bodies,
    "\\row"
  )
}

# Body rows: one `\trowd ... \row` per data row, one cell per
# visible column, alignment via the three-layer cascade
# (cells_style@halign / @valign > col_spec@align / @valign >
# cells_style[r,c]@halign / body_valign), text from
# `cells_text` (post-engine_decimal). Cells use `\line` for
# embedded newlines so multi-line cells render without closing the
# cell (a `\par` would close it).
.render_rtf_body_rows <- function(
  cells_text,
  col_names_vis,
  cols,
  cellx,
  cells_style = NULL,
  cells_indent = NULL,
  is_header_row = NULL,
  is_blank_row = NULL,
  host_col = NA_character_,
  keep_with_next = NULL,
  close_bottom_rule = TRUE,
  preset = NULL,
  cs = NULL,
  colors = NULL,
  fonts = NULL,
  body_borders = NULL
) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }

  col_specs <- lapply(col_names_vis, function(nm) cols[[nm]])
  trgaph <- .rtf_body_trgaph(cells_style, preset)
  cf_tok <- .rtf_body_cf_token(cells_style, colors)
  # Engine sidecar + row-type flags default to no-op shape for any
  # caller that bypasses as_grid.
  ncol_data <- length(col_names_vis)
  if (is.null(cells_indent)) {
    cells_indent <- matrix(0L, nrow = nrow_data, ncol = ncol_data)
  }
  is_header_row <- is_header_row %||% rep(FALSE, nrow_data)
  is_blank_row <- is_blank_row %||% rep(FALSE, nrow_data)
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_twips_per_level <- .indent_native_twips_per_level(preset)
  ws_preserve <- .preset_ws_preserve(preset)

  # Group-aware keep mask (per rendered row). Under native pagination the
  # `keep_with_next` vector (built in `.attach_keep_with_next`) is what
  # tells Word which rows must NOT break apart: keep_together groups glue
  # fully, oversized groups protect only their orphan/widow edges,
  # section headers glue to their following row, blanks break freely.
  # Fallback (NULL, e.g. a hand-built grid) glues every row but the last,
  # the legacy single-page behaviour.
  keep_vec <- if (is.null(keep_with_next)) {
    c(rep(TRUE, max(0L, nrow_data - 1L)), FALSE)[seq_len(nrow_data)]
  } else {
    vapply(
      seq_len(nrow_data),
      function(r) isTRUE(keep_with_next[[r]]),
      logical(1L)
    )
  }

  # Borderless prelude shared by synthesised section-header / blank rows.
  blank_prelude <- paste0(
    .rtf_border_seg("top", NULL, "none"),
    .rtf_border_seg("bottom", NULL, "none"),
    .rtf_border_seg("left", NULL, "none"),
    .rtf_border_seg("right", NULL, "none")
  )

  out <- vector("list", nrow_data)
  for (r in seq_len(nrow_data)) {
    keep_row <- keep_vec[[r]]
    keepn_tok <- if (keep_row) "\\keepn" else ""

    if (isTRUE(is_blank_row[[r]])) {
      # Blank-gap row: a full-width merged row so it keeps the body
      # column grid (a single trailing \cellx would desync the table).
      # The stripe fill stamped onto the row's node shades the merged
      # cell so the zebra band stays continuous across the gap.
      blank_node <- if (!is.null(cells_style)) {
        tryCatch(cells_style[[r, 1L]], error = function(e) NULL)
      } else {
        NULL
      }
      blank_shd <- .rtf_cell_shading(blank_node, colors)
      out[[r]] <- .rtf_merged_row(
        # `\plain` resets to the RTF 12pt default; re-emit the preset body
        # size so the blank-gap line matches the body height (mirrors the
        # header-row branch below and the chrome / title / footnote rows).
        paste0(
          "\\pard\\plain\\intbl",
          .rtf_body_fs(preset),
          keepn_tok,
          "\\ql"
        ),
        cellx,
        preset,
        trhdr = FALSE,
        keep = keep_row,
        prelude = paste0(blank_prelude, blank_shd),
        body_borders = body_borders
      )
      next
    }
    if (isTRUE(is_header_row[[r]])) {
      host_text <- ""
      host_idx <- NA_integer_
      for (jj in seq_along(col_names_vis)) {
        val <- cells_text[r, jj]
        if (!is.na(val) && nzchar(val)) {
          host_text <- val
          host_idx <- jj
          break
        }
      }
      # Band-depth padding on the header-row paragraph via `\liN`
      # (twips). Band-1 (depth 0) -> no `\li`; band-2+ -> `\liN` BEFORE
      # the alignment token so RTF readers honour the cell-side indent.
      header_li_tok <- ""
      if (!is.na(host_idx)) {
        header_depth <- cells_indent[r, host_idx]
        if (isTRUE(header_depth > 0L) && indent_twips_per_level > 0L) {
          header_li_tok <- sprintf(
            "\\li%d",
            indent_twips_per_level * header_depth
          )
        }
      }
      # Group-header weight + text props from the host cell's stamped
      # style_node: NA bold == bold (default), `isFALSE` == off. Mirrors
      # the subgroup-banner idiom (chrome text props + cell shading);
      # `skip = "bold"` defers the weight to the explicit `bold_open`
      # gate so there is no double `\b`.
      host_node <- if (!is.null(cells_style) && !is.na(host_idx)) {
        cells_style[[r, host_idx]]
      } else {
        NULL
      }
      host_props <- .rtf_chrome_text_props(
        host_node,
        colors,
        fonts,
        skip = "bold"
      )
      header_shading <- .rtf_cell_shading(host_node, colors)
      bold_open <- if (
        is_style_node(host_node) && isTRUE(host_node@bold == FALSE)
      ) {
        ""
      } else {
        "{\\b "
      }
      bold_close <- if (identical(bold_open, "")) "" else "}"
      out[[r]] <- .rtf_merged_row(
        paste0(
          "\\pard\\plain\\intbl",
          .rtf_body_fs(preset),
          keepn_tok,
          header_li_tok,
          "\\ql ",
          host_props,
          bold_open,
          .rtf_escape_cell(host_text, preserve = ws_preserve),
          bold_close
        ),
        cellx,
        preset,
        trhdr = FALSE,
        keep = keep_row,
        prelude = paste0(blank_prelude, header_shading),
        body_borders = body_borders
      )
      next
    }
    cellx_lines <- character(ncol_data)
    cell_bodies <- character(ncol_data)
    is_last_row <- (r == nrow_data)
    trkeep_tok <- if (keep_row) "\\trkeep" else ""
    for (i in seq_along(col_names_vis)) {
      sn <- .cell_style_at(cells_style, r, col_names_vis[[i]])
      col <- col_specs[[i]]
      halign <- .effective_body_halign(sn, col, preset)
      valign <- .effective_body_valign(sn, col, preset)
      align_tok <- .rtf_align_token(halign)
      valign_tok <- .rtf_valign_token(valign)
      # Backend default per-side borders for a body cell: top and left
      # and right are clear; bottom carries the closing solid rule only
      # on the table's final rendered row (the canonical Appendix I
      # closing rule). The cascade resolver overrides these defaults
      # when the user has set explicit border_<side>_style / etc.
      bottom_default <- if (is_last_row && isTRUE(close_bottom_rule)) {
        "solid"
      } else {
        "none"
      }
      shading <- .rtf_cell_shading(sn, colors)
      cellx_lines[[i]] <- paste0(
        .rtf_border_seg("top", sn, "none", colors),
        .rtf_border_seg("bottom", sn, bottom_default, colors),
        .rtf_border_seg("left", sn, "none", colors),
        .rtf_border_seg("right", sn, "none", colors),
        shading,
        .rtf_cell_padding(sn),
        valign_tok,
        sprintf("\\cellx%d", as.integer(cellx[[i]]))
      )
      # Per-cell native left indent: strip the engine-baked leading
      # spaces and emit `\liN` (twips) on the paragraph BEFORE the
      # alignment token. RTF readers honour `\li` as the cell-side left
      # indent, so wrapped continuation lines inside a narrow column
      # align with the indented baseline.
      raw <- cells_text[r, i]
      depth <- cells_indent[r, i]
      li_tok <- ""
      if (isTRUE(depth > 0L) && indent_unit > 0L && !is.na(raw)) {
        n_leading <- indent_unit * depth
        if (
          nchar(raw) >= n_leading &&
            startsWith(raw, strrep(" ", n_leading))
        ) {
          raw <- substr(raw, n_leading + 1L, nchar(raw))
        }
        if (indent_twips_per_level > 0L) {
          li_tok <- sprintf("\\li%d", indent_twips_per_level * depth)
        }
      }
      text <- .rtf_escape_cell(raw, preserve = ws_preserve)
      text_props <- .rtf_cell_text_props(sn, colors, fonts)
      cell_bodies[[i]] <- paste0(
        "\\pard\\plain\\intbl ",
        .rtf_body_fs(preset),
        keepn_tok,
        li_tok,
        align_tok,
        " ",
        cf_tok,
        text_props,
        text,
        "\\cell"
      )
    }
    out[[r]] <- c(
      paste0(
        sprintf("\\trowd\\trgaph%d\\trqc", trgaph),
        .rtf_row_height_str(preset),
        trkeep_tok,
        .rtf_row_frame_edges(body_borders)
      ),
      cellx_lines,
      cell_bodies,
      "\\row"
    )
  }
  unlist(out, use.names = FALSE)
}

# Resolve the body row's `\trgaph<halfWidth>` value (twips). Reads
# the representative [1,1] body cell's @padding (set by the lowered
# `preset(padding = list(body = N))` knob or `style(at =
# cells_body(), padding = N)`) and converts pt -> twips (1pt = 20
# twips). RTF's `\trgaph` is a single symmetric gap per row, so an
# asymmetric `cell_padding_h = c(left, right)` is rendered as its
# average; the TOTAL (left + right) still equals what the column was
# measured for, so column widths stay correct. Default 5.4pt -> 108
# twips (the legacy value), so unset presets stay byte-stable.
# (DOCX and LaTeX render left / right exactly.)
.rtf_body_trgaph <- function(cells_style, preset = NULL) {
  lr <- if (is_preset_spec(preset)) {
    .resolve_cell_padding_lr(cells_style, preset)
  } else {
    p <- .first_cell_padding(cells_style)
    if (length(p) == 1L && !is.na(p)) c(p, p) else c(5.4, 5.4)
  }
  as.integer(round(mean(lr) * 20))
}

# Body cell text color token. Empty string when no body-level text
# color is set anywhere in the cascade; otherwise `\cf<idx> ` with
# the dynamic-table index. Reads the representative [1,1] body
# cell's @color (set by the lowered `preset(colors = list(text = ...))`
# knob or `style(at = cells_body(), color = ...)`); the per-cell
# layer cascade stamps the same value on every body cell, so reading
# any one is canonical. The colortbl index is resolved via the
# preamble-time `.rtf_collect_colors()` lookup.
.rtf_body_cf_token <- function(cells_style, colors) {
  text_color <- .first_cell_color(cells_style)
  if (is.na(text_color) || !nzchar(text_color)) {
    return("")
  }
  idx <- colors$lookup(text_color)
  if (is.na(idx)) {
    return("")
  }
  sprintf("\\cf%d ", as.integer(idx))
}

# Map an `align` value to the RTF paragraph alignment control.
# `decimal` -> right-align (the engine_decimal phase has already
# NBSP-padded the cell text, so visual alignment survives a
# simple right-justify).
#
# RTF cell text-property tokens from one style_node. All seven
# text properties cascade through here now: bold (`\b`), italic
# (`\i`), underline (`\ul`), font_size (`\fs<half-points>`), color
# (`\cf<idx>`), background (cell-level — emitted on the cellx
# prelude via `.rtf_cell_shading`, NOT here), and font_family
# (`\f<idx>`). Emitted AFTER `\pard\plain\intbl` resets the
# paragraph state, so each cell starts fresh and only the
# explicitly-set properties land.
.rtf_cell_text_props <- function(style, colors = NULL, fonts = NULL) {
  if (!is_style_node(style)) {
    return("")
  }
  parts <- character()
  if (isTRUE(style@bold)) {
    parts <- c(parts, "\\b ")
  }
  if (isTRUE(style@italic)) {
    parts <- c(parts, "\\i ")
  }
  if (isTRUE(style@underline)) {
    parts <- c(parts, "\\ul ")
  }
  fs <- style@font_size
  if (length(fs) == 1L && !is.na(fs) && is.numeric(fs)) {
    parts <- c(parts, sprintf("\\fs%d ", as.integer(round(fs * 2))))
  }
  if (!is.null(colors)) {
    color <- style@color
    if (length(color) == 1L && !is.na(color) && nzchar(color)) {
      idx <- colors$lookup(color)
      if (!is.na(idx)) {
        parts <- c(parts, sprintf("\\cf%d ", as.integer(idx)))
      }
    }
  }
  if (!is.null(fonts)) {
    ff <- style@font_family
    if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
      idx <- fonts$lookup(ff)
      if (!is.na(idx) && idx > 0L) {
        parts <- c(parts, sprintf("\\f%d ", as.integer(idx)))
      }
    }
  }
  paste0(parts, collapse = "")
}

# Cell-level background shading token (`\clcbpat<idx>` on the
# cellx prelude). Empty when no background is set or the color
# isn't in the colortbl. Backends emit this BEFORE `\cellx<pos>`.
.rtf_cell_shading <- function(style, colors) {
  if (!is_style_node(style) || is.null(colors)) {
    return("")
  }
  bg <- style@background
  if (length(bg) != 1L || is.na(bg) || !nzchar(bg)) {
    return("")
  }
  idx <- colors$lookup(bg)
  if (is.na(idx)) {
    return("")
  }
  sprintf("\\clcbpat%d", as.integer(idx))
}

# Per-side RTF cell padding from a chrome surface style_node (the header
# band / column-label rows). RTF cell margins are
# `\clpad<side><twips>\clpadf<side>3` where the `\clpadf<side>3` unit
# flag (3 = twips) is mandatory; 1pt = 20 twips. Only explicitly-set
# sides emit, so unset sides keep the row's `\trgaph` default. Lets
# `preset(padding = list(header = c(top = , bottom = )))` reach RTF.
.rtf_cell_padding <- function(style = NULL) {
  if (!is_style_node(style)) {
    return("")
  }
  tags <- c(top = "t", right = "r", bottom = "b", left = "l")
  out <- character()
  for (side in c("top", "right", "bottom", "left")) {
    pad <- S7::prop(style, paste0("padding_", side))
    if (length(pad) == 1L && !is.na(pad)) {
      tw <- as.integer(round(as.numeric(pad) * 20))
      tag <- tags[[side]]
      out <- c(out, sprintf("\\clpad%s%d\\clpadf%s3", tag, tw, tag))
    }
  }
  paste(out, collapse = "")
}

.rtf_align_token <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("\\ql")
  }
  switch(
    align,
    left = "\\ql",
    center = "\\qc",
    right = "\\qr",
    decimal = "\\qr",
    "\\ql"
  )
}

# Map a `valign` value to the RTF cell-level vertical-alignment
# control (`\clvertalt`, `\clvertalc`, `\clvertalb`). Returns ""
# when valign is NA / NULL so cells default to RTF's natural
# top alignment (the readers Word and LibreOffice render this as
# top).
.rtf_valign_token <- function(valign) {
  if (is.null(valign) || length(valign) == 0L || is.na(valign)) {
    return("")
  }
  switch(
    valign,
    top = "\\clvertalt",
    middle = "\\clvertalc",
    bottom = "\\clvertalb",
    ""
  )
}

# Per-side border segment for the cell prelude. `side` is one of
# "top", "bottom", "left", "right". `cell_style` may be NULL or a
# `style_node`; `backend_default` is the backend's intrinsic per-
# row choice ("solid" or "none") and applies only when the cascade
# does not return an override.
#
# Returns a fragment like `\clbrdrt\brdrs\brdrw10` (solid 0.5pt) or
# `\clbrdrt\brdrnone` for the cleared case.
.rtf_border_seg <- function(
  side,
  cell_style,
  backend_default = "none",
  colors = NULL
) {
  brd <- .effective_border(side, cell_style)
  letter <- substr(side, 1, 1)
  prefix <- paste0("\\clbrdr", letter)
  if (is.null(brd)) {
    # No cascade override; fall back to the backend's per-row default.
    if (identical(backend_default, "solid")) {
      return(paste0(prefix, "\\brdrs\\brdrw10"))
    }
    return(paste0(prefix, "\\brdrnone"))
  }
  if (identical(brd$style, "none")) {
    # Explicit clear -> suppress the backend default and emit
    # \brdrnone unconditionally.
    return(paste0(prefix, "\\brdrnone"))
  }
  style_tok <- switch(
    brd$style,
    solid = "\\brdrs",
    dashed = "\\brdrdash",
    dotted = "\\brdrdot",
    double = "\\brdrdb",
    dashdot = "\\brdrdashd",
    "\\brdrs"
  )
  twips <- max(1L, as.integer(round(brd$width * 20)))
  paste0(
    prefix,
    style_tok,
    sprintf("\\brdrw%d", twips),
    .rtf_brdrcf(brd$color, colors)
  )
}

# `\brdrcf<n>` colour token for a border, or "" when the colour is unset,
# the default ink, or not registered in the colour table. The default ink
# (`.tabular_ink`, the colour the engine stamps on every default rule) is
# skipped so default borders render via Word's own black default and only
# a genuinely custom border colour emits a token (no churn on the common
# case). Keeps the border builders' colour handling in one place.
.rtf_brdrcf <- function(color, colors) {
  if (
    is.null(colors) ||
      is.null(color) ||
      length(color) != 1L ||
      is.na(color) ||
      !nzchar(color) ||
      identical(color, "currentColor") ||
      identical(color, "ink") ||
      identical(color, .tabular_ink)
  ) {
    return("")
  }
  idx <- colors$lookup(color)
  if (is.na(idx)) "" else sprintf("\\brdrcf%d", idx)
}

# Row-level border segment (`\trbrdr<letter>`) from a manifest triple,
# for the outer frame LEFT / RIGHT edges. Sibling of the cell-level
# `.rtf_border_seg` (`\clbrdr`): a ROW border applies to the whole
# `\trowd`, so the same edge rides the spanner band, the column-label
# row, the subgroup banner, and every body row including the synthesised
# blank-separator and group-header rows. That is what makes the frame
# continuous in Word (a per-cell stamp only reaches data rows).
.rtf_row_border_seg <- function(side, triple) {
  if (is.null(triple) || identical(triple$style, "none")) {
    return("")
  }
  letter <- substr(side, 1L, 1L)
  style_tok <- switch(
    triple$style,
    solid = "\\brdrs",
    dashed = "\\brdrdash",
    dotted = "\\brdrdot",
    double = "\\brdrdb",
    dashdot = "\\brdrdashd",
    "\\brdrs"
  )
  twips <- max(1L, as.integer(round(as.numeric(triple$width) * 20)))
  paste0("\\trbrdr", letter, style_tok, sprintf("\\brdrw%d", twips))
}

# Both outer LEFT / RIGHT row-border tokens for a table-proper `\trowd`,
# read from the body-border manifest. Returns "" when the frame is off
# (manifest carries no outer_left / outer_right), so non-frame presets
# are byte-unchanged.
.rtf_row_frame_edges <- function(body_borders) {
  if (!is.list(body_borders)) {
    return("")
  }
  paste0(
    .rtf_row_border_seg("left", body_borders[["outer_left"]]),
    .rtf_row_border_seg("right", body_borders[["outer_right"]])
  )
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single RTF fragment. Walks every run
# in `ast@runs` recursively. Unknown run types fall through to
# their escaped `text` field.
.render_rtf_inline <- function(ast, preserve = TRUE) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  .render_rtf_children(ast@runs, preserve, lead = TRUE, trail = TRUE)
}

# Render one AST run record to its RTF markup. Recurses through
# `children` for wrapping types. `lead` / `trail` flag the run's
# line-edge position (only line-edge whitespace becomes `\~`; inter-
# run spaces stay breakable).
.render_rtf_run <- function(run, preserve = TRUE, lead = TRUE, trail = TRUE) {
  type <- run$type
  switch(
    type,
    plain = .rtf_escape_text_run(run$text %||% "", preserve, lead, trail),
    bold = paste0(
      "{\\b ",
      .render_rtf_children(run$children, preserve, lead, trail),
      "}"
    ),
    italic = paste0(
      "{\\i ",
      .render_rtf_children(run$children, preserve, lead, trail),
      "}"
    ),
    sup = paste0(
      "{\\super ",
      .render_rtf_children(run$children, preserve, lead, trail),
      "\\nosupersub}"
    ),
    sub = paste0(
      "{\\sub ",
      .render_rtf_children(run$children, preserve, lead, trail),
      "\\nosupersub}"
    ),
    code = paste0(
      "{\\f1 ",
      .render_rtf_children(run$children, preserve, lead, trail),
      "}"
    ),
    link = .render_rtf_link(run, preserve, lead, trail),
    span = .render_rtf_children(run$children, preserve, lead, trail),
    newline = "\\line ",
    .rtf_escape_text_run(run$text %||% "", preserve, lead, trail)
  )
}

# Escape a plain-text run and, when preserving, rewrite significant
# whitespace runs into `\~` (the single chokepoint for inline plain
# text, mirroring the body-cell path).
.rtf_escape_text_run <- function(text, preserve, lead = TRUE, trail = TRUE) {
  .escape_text_run(text, .rtf_escape, "\\~", preserve, lead, trail)
}

# Render the children of a wrapping run. Each child's line-edge flags
# come from its position (first / after-newline -> line-leading, etc.).
.render_rtf_children <- function(
  children,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  .render_ast_children(children, .render_rtf_run, preserve, lead, trail)
}

# Render a link run as an RTF hyperlink field. Word and
# LibreOffice both render the `\fldrslt` text as the clickable
# anchor that resolves to the `HYPERLINK` URL on click.
.render_rtf_link <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  href <- .rtf_escape(run$href %||% "")
  text <- .render_rtf_children(run$children, preserve, lead, trail)
  sprintf(
    "{\\field{\\*\\fldinst HYPERLINK \"%s\"}{\\fldrslt %s}}",
    href,
    text
  )
}

# ---------------------------------------------------------------------
# Escaping
# ---------------------------------------------------------------------

# Escape one plain text string for safe insertion into RTF body
# / cell / chrome content. Order matters — backslash first, then
# braces. Non-ASCII characters use the `\uNNNN?` form (signed
# 16-bit Unicode point + fallback ASCII char) that Word + LibreOffice
# both accept and round-trip cleanly.
.rtf_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  text <- gsub("\\", "\\\\", text, fixed = TRUE)
  text <- gsub("{", "\\{", text, fixed = TRUE)
  text <- gsub("}", "\\}", text, fixed = TRUE)
  .rtf_escape_non_ascii(text)
}

# Cell-text variant of `.rtf_escape` that also converts embedded
# newlines (`\n`, `\r\n`) into RTF `\line` so multi-line cells
# render without closing the cell (a `\par` would do that).
.rtf_escape_cell <- function(text, preserve = TRUE) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  # Peel any auto-footnote marker sentinel off the cell end before
  # escaping; re-attach it as a `{\super ...}` run afterwards.
  peeled <- .fn_peel(text)
  out <- .rtf_escape(peeled$base)
  out <- gsub("\r\n", "\\line ", out, fixed = TRUE)
  out <- gsub("\n", "\\line ", out, fixed = TRUE)
  # Preserve significant ASCII whitespace LAST, after the indent strip
  # at the call site and the `\n` -> `\line` conversion. `\~` is the RTF
  # non-breaking space; inserted post-escape so it is not re-escaped.
  if (isTRUE(preserve)) {
    out <- .preserve_ws(out, "\\~")
  }
  if (any(peeled$has)) {
    out[peeled$has] <- paste0(
      out[peeled$has],
      "{\\super ",
      .rtf_escape(peeled$marker[peeled$has]),
      "\\nosupersub}"
    )
  }
  out
}

# Replace every non-ASCII character with an RTF `\uNNNN?` escape.
# NNNN is the signed 16-bit Unicode code point (RTF spec requires
# signed); `?` is the fallback ASCII char rendered by readers that
# do not understand the Unicode escape.
#
# Supplementary-plane characters (U+10000 and above) are encoded
# as a UTF-16 surrogate pair (high surrogate + low surrogate),
# matching the RTF 1.9.1 spec. Both halves carry their own `?`
# fallback so legacy readers still see two `?` glyphs rather than
# garbage. This covers emoji, ancient scripts, CJK Extension B+.
.rtf_escape_non_ascii <- function(text) {
  if (length(text) == 0L) {
    return(text)
  }
  # Vectorized pre-filter: the surrogate-pair walker is only needed for
  # strings that actually carry a non-ASCII byte. A single C-level
  # `grepl` over the whole vector lets the all-ASCII common case (the
  # vast majority of clinical cells) skip the per-character split +
  # `utf8ToInt` entirely.
  needs <- grepl("[^\x01-\x7f]", text, perl = TRUE)
  if (!any(needs)) {
    return(text)
  }
  text[needs] <- vapply(
    text[needs],
    function(s) {
      chars <- strsplit(s, "", fixed = TRUE)[[1L]]
      cp <- utf8ToInt(s)
      out <- chars
      idx <- which(cp > 127L)
      if (length(idx) == 0L) {
        return(s)
      }
      for (i in idx) {
        n <- cp[[i]]
        out[[i]] <- if (n > 65535L) {
          # Supplementary plane -> UTF-16 surrogate pair.
          n2 <- n - 65536L
          high <- 0xD800L + bitwShiftR(n2, 10L)
          low <- 0xDC00L + bitwAnd(n2, 0x3FFL)
          sprintf(
            "\\u%d?\\u%d?",
            as.integer(.signed16(high)),
            as.integer(.signed16(low))
          )
        } else {
          sprintf("\\u%d?", as.integer(.signed16(n)))
        }
      }
      paste(out, collapse = "")
    },
    character(1L),
    USE.NAMES = FALSE
  )
  text
}

# Convert an unsigned 16-bit Unicode value to its RTF signed-16
# representation. Values > 32767 wrap to negative per the RTF spec.
.signed16 <- function(n) {
  if (n > 32767L) n - 65536L else n
}

# ---------------------------------------------------------------------
# Font table
# ---------------------------------------------------------------------

# Compose the `{\fonttbl ...}` block. `\f0` is the body font (the
# first entry of the resolved stack), `\f1` is the matching mono
# face used for `code` inline runs, and `\f2+` register any
# additional font families that body cells or chrome surfaces use
# (driven by `style(font_family = ..., at = ...)` layers). The RTF
# family-class keyword (`\froman` / `\fswiss` / `\fmodern`) is
# derived from the generic the user requested; for an explicit
# stack or a single named font, we default to `\froman` (the
# safest fallback class for Word's font matcher).
#
# When the resolved chain has >=2 entries, every font definition
# carries a `{\*\falt <second>}` token — RTF 1.5+ font-alternate
# syntax that Word and LibreOffice honour when the primary face is
# not installed. This is what closes the cross-OS rendering gap:
# the file NAMES "Liberation Serif" (the Linux server emits what
# it has), and Word on a Mac / Windows consumer without Liberation
# reads the `\*\falt` -> "Times New Roman" -> match. Result: same
# metric-compatible rendering on every OS.
#
# Compose the `{\colortbl ...}` group. Always emits a leading
# semicolon (the RTF "auto" sentinel at index 0). Subsequent
# entries register every distinct color used by any body cell or
# chrome surface so `\cf<idx>` / `\cb<idx>` references resolve to
# real entries instead of silently truncating against the static
# single-slot tables the legacy helpers emitted.
.rtf_color_table <- function(colors) {
  values <- colors$values
  if (length(values) == 0L) {
    return("")
  }
  entries <- vapply(
    values,
    function(hex) {
      rgb <- .rtf_color_rgb(hex)
      sprintf(
        "\\red%d\\green%d\\blue%d;",
        rgb[[1L]],
        rgb[[2L]],
        rgb[[3L]]
      )
    },
    character(1L)
  )
  paste0("{\\colortbl;", paste(entries, collapse = ""), "}")
}

# Translate a "#RRGGBB" hex color into an integer RGB triple. Falls
# back to black on malformed input so the colortbl never emits a
# negative or NA component.
.rtf_color_rgb <- function(hex) {
  s <- toupper(sub("^#", "", as.character(hex)))
  if (!grepl("^[0-9A-F]{6}$", s)) {
    return(c(0L, 0L, 0L))
  }
  c(
    strtoi(substr(s, 1L, 2L), 16L),
    strtoi(substr(s, 3L, 4L), 16L),
    strtoi(substr(s, 5L, 6L), 16L)
  )
}

.rtf_font_table <- function(fonts) {
  values <- fonts$values
  if (length(values) < 2L) {
    # Defensive — `.rtf_collect_fonts` always seeds the body and
    # mono entries, so this branch only fires if a caller passes a
    # malformed structure.
    return(character())
  }
  body_chain <- .resolve_font_stack(values[[1L]], "rtf")
  mono_chain <- .resolve_font_stack(values[[2L]], "rtf")
  body_class <- .rtf_family_class(values[[1L]], "serif")
  out <- c(
    "{\\fonttbl",
    sprintf(
      "{\\f0\\%s\\fprq2 %s%s;}",
      body_class,
      .rtf_escape(body_chain[[1L]]),
      .rtf_falt(body_chain)
    ),
    sprintf(
      "{\\f1\\fmodern\\fprq1 %s%s;}",
      .rtf_escape(mono_chain[[1L]]),
      .rtf_falt(mono_chain)
    )
  )
  if (length(values) > 2L) {
    extra <- vapply(
      seq.int(3L, length(values)),
      function(i) {
        family <- values[[i]]
        chain <- .resolve_font_stack(family, "rtf")
        class <- .rtf_family_class(family, "serif")
        pitch <- if (identical(class, "fmodern")) 1L else 2L
        sprintf(
          "{\\f%d\\%s\\fprq%d %s%s;}",
          i - 1L,
          class,
          pitch,
          .rtf_escape(chain[[1L]]),
          .rtf_falt(chain)
        )
      },
      character(1L)
    )
    out <- c(out, extra)
  }
  c(out, "}")
}

# ---------------------------------------------------------------------
# Color / font collectors — Phase 2b: scan resolved styles
# ---------------------------------------------------------------------

# Flatten a list of per-element property vectors (color / background /
# font_family pulled off style_nodes) to the valid scalar character
# values: non-NA, non-empty. Used by the color / font collectors so the
# final `unique()` sees only real values.
.rtf_valid_props <- function(prop_lists) {
  vals <- unlist(prop_lists, use.names = FALSE)
  if (length(vals) == 0L) {
    return(character())
  }
  vals[!is.na(vals) & nzchar(vals)]
}

# Flatten one `chrome_style$surfaces` entry to a list of style_nodes. A
# plain surface (title / header / footer / subgroup) is a single node;
# the slot-keyed page bands (pagehead / pagefoot) are a `left/center/right`
# list of nodes. Returns `list()` for anything else, so the colour / font
# collectors register slot-level overrides, not just whole-surface ones.
.rtf_surface_nodes <- function(node) {
  if (is_style_node(node)) {
    list(node)
  } else if (is.list(node)) {
    Filter(is_style_node, node)
  } else {
    list()
  }
}

# Walk every style_node that might contribute a color to the
# rendered document. Returns a deduplicated character vector of
# "#RRGGBB" hex codes plus a `lookup(hex) -> integer` closure that
# resolves a hex string to its 1-indexed slot in `\colortbl`. Slot
# 0 is the RTF "auto" sentinel and is reserved.
.rtf_collect_colors <- function(pages, cs, preset) {
  # One vector per page, unlisted + deduplicated once at the end (the
  # per-cell `c(buf, ...)` accumulation was quadratic on large tables).
  buf <- lapply(pages, function(page) {
    cell_styles <- page$cells_style
    if (is.null(cell_styles)) {
      return(character())
    }
    .rtf_valid_props(lapply(
      cell_styles,
      function(sn) {
        if (!is_style_node(sn)) {
          return(NULL)
        }
        # Border colours equal to the default ink are NOT registered: the
        # engine stamps the ink on every default rule, and emitting it would
        # churn the colour table on every table. Only a genuinely custom
        # border colour earns a colortbl slot (and a `\brdrcf` token).
        border_cols <- c(
          sn@border_top_color,
          sn@border_bottom_color,
          sn@border_left_color,
          sn@border_right_color
        )
        border_cols <- border_cols[
          !is.na(border_cols) &
            border_cols != .tabular_ink &
            border_cols != "ink" &
            border_cols != "currentColor"
        ]
        c(sn@color, sn@background, border_cols)
      }
    ))
  })
  if (is.list(cs) && is.list(cs$surfaces)) {
    nodes <- unlist(
      lapply(cs$surfaces, .rtf_surface_nodes),
      recursive = FALSE
    )
    buf[[length(buf) + 1L]] <- .rtf_valid_props(lapply(
      nodes,
      function(node) c(node@color, node@background)
    ))
  }
  values <- unique(unlist(buf, use.names = FALSE))
  lookup <- function(hex) {
    if (
      is.null(hex) ||
        length(hex) != 1L ||
        is.na(hex) ||
        !nzchar(hex)
    ) {
      return(NA_integer_)
    }
    idx <- match(hex, values)
    if (is.na(idx)) NA_integer_ else as.integer(idx)
  }
  list(values = values, lookup = lookup)
}

# Walk every style_node for unique font families. Always seeds the
# resolved body family at index 0 (`\f0`) and the mono family at
# index 1 (`\f1`) per the RTF backend's invariant; additional
# families register at 2+. Returns a list with `values` (character
# vector) and `lookup(family) -> integer` (0-indexed, returns 0
# when family is NULL / NA / unrecognised so cells fall through to
# the body font).
.rtf_collect_fonts <- function(pages, cs, preset) {
  body_family <- .effective_font_family(preset)
  # Seed body + mono first; collect cell + surface families once and
  # dedup preserving the seed order (the per-cell `c(values, ...)` append
  # was quadratic on large tables).
  buf <- lapply(pages, function(page) {
    cell_styles <- page$cells_style
    if (is.null(cell_styles)) {
      return(character())
    }
    .rtf_valid_props(lapply(
      cell_styles,
      function(sn) if (is_style_node(sn)) sn@font_family else NULL
    ))
  })
  if (is.list(cs) && is.list(cs$surfaces)) {
    nodes <- unlist(
      lapply(cs$surfaces, .rtf_surface_nodes),
      recursive = FALSE
    )
    buf[[length(buf) + 1L]] <- .rtf_valid_props(lapply(
      nodes,
      function(node) node@font_family
    ))
  }
  # `\f0` (body) and `\f1` (mono) are POSITIONAL slots that must both
  # exist even when the body family is itself "mono"; only the extra
  # families (registering at `\f2+`) are deduplicated, and against the
  # seed so a cell font equal to the body resolves back to `\f0`.
  extras <- unique(unlist(buf, use.names = FALSE))
  extras <- extras[!(extras %in% c(body_family, "mono"))]
  values <- c(body_family, "mono", extras)
  lookup <- function(family) {
    if (
      is.null(family) ||
        length(family) != 1L ||
        is.na(family) ||
        !nzchar(family)
    ) {
      return(0L)
    }
    idx <- match(family, values)
    if (is.na(idx)) 0L else as.integer(idx) - 1L
  }
  list(values = values, lookup = lookup)
}

# Compose the optional `{\*\falt <second>}` fragment from a
# resolved font chain. Empty when the chain has only one entry
# (no alternate to suggest). Word and LibreOffice substitute the
# alternate name when the primary face is missing on the
# consumer's machine.
.rtf_falt <- function(chain) {
  if (length(chain) < 2L) {
    return("")
  }
  sprintf("{\\*\\falt %s}", .rtf_escape(chain[[2L]]))
}

# Map a `font_family` input to its RTF family-class keyword. Only
# generic-family inputs route to `\fswiss` / `\fmodern`; explicit
# named fonts and stacks default to `\froman` (safe fallback).
.rtf_family_class <- function(font_family, default_generic) {
  if (length(font_family) != 1L) {
    return(switch(
      default_generic,
      sans = "fswiss",
      mono = "fmodern",
      "froman"
    ))
  }
  gen <- switch(
    font_family,
    serif = "serif",
    sans = "sans",
    `sans-serif` = "sans",
    mono = "mono",
    monospace = "mono",
    NA_character_
  )
  if (is.na(gen)) {
    return("froman")
  }
  switch(gen, serif = "froman", sans = "fswiss", mono = "fmodern", "froman")
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("rtf", backend_rtf)
