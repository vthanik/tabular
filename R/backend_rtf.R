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
# section per page, closing `}`. Returns a character vector of
# lines ready for `writeLines()`. Pure — no I/O.
.render_rtf_doc <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
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

  if (total == 0L) {
    section <- .render_rtf_empty(grid, preset, cs, colors, fonts)
    return(c(preamble, section, "}"))
  }

  body <- list()
  for (i in seq_along(pages)) {
    body[[i]] <- .render_rtf_page(
      page = pages[[i]],
      meta = meta,
      preset = preset,
      cs = cs,
      colors = colors,
      fonts = fonts,
      page_number = i,
      total_pages = total
    )
  }
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
    "\\pard\\plain\\qc {\\i (no rows)}\\par",
    .render_rtf_footnote_block(meta$footnotes_ast, preset, cs, colors, fonts)
  )
}

# Render one page as one RTF section. Carries its own section
# definition (so per-page geometry stays self-contained), optional
# header / footer groups, page-1 title block, optional continuation
# marker on pages 2+, the table, and the page-1 footnote block.
.render_rtf_page <- function(
  page,
  meta,
  preset,
  cs,
  colors,
  fonts,
  page_number,
  total_pages
) {
  has_ph <- .page_band_is_populated(meta$pagehead_ast)
  has_pf <- .page_band_is_populated(meta$pagefoot_ast)

  out <- character()
  out <- c(
    out,
    .rtf_section_def(preset, has_pagehead = has_ph, has_pagefoot = has_pf)
  )
  if (has_ph) {
    out <- c(
      out,
      .rtf_header_group(meta$pagehead_ast, preset, cs, colors, fonts)
    )
  }
  if (has_pf) {
    out <- c(
      out,
      .rtf_footer_group(meta$pagefoot_ast, preset, cs, colors, fonts)
    )
  }

  blank_par <- "\\pard\\plain\\par"
  pad_title_top <- .rtf_blank_count(cs, "title", "above", 1L)
  pad_title_bottom <- .rtf_blank_count(cs, "title", "below", 1L)
  pad_body_top <- 0L
  pad_body_bottom <- 0L

  if (page_number == 1L) {
    titles <- .render_rtf_title_block(
      meta$titles_ast,
      preset,
      cs,
      colors,
      fonts
    )
    if (length(titles) > 0L) {
      out <- c(
        out,
        rep(blank_par, pad_title_top),
        titles,
        rep(blank_par, pad_title_bottom)
      )
    }
  } else if (length(page$continuation) > 0L) {
    out <- c(
      out,
      paste0(
        "\\pard\\plain\\qr {\\i ",
        .rtf_escape(as.character(page$continuation)),
        "}\\par"
      )
    )
  }

  out <- c(out, rep(blank_par, pad_body_top))
  out <- c(out, .render_rtf_table(page, meta, preset, cs, colors, fonts))
  out <- c(out, rep(blank_par, pad_body_bottom))

  if (page_number == 1L) {
    out <- c(
      out,
      .render_rtf_footnote_block(
        meta$footnotes_ast,
        preset,
        cs,
        colors,
        fonts
      )
    )
  }

  out <- c(out, "\\sect")
  out
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
.rtf_section_def <- function(preset, has_pagehead, has_pagefoot) {
  paper <- .rtf_paper_twips(preset@paper_size, preset@orientation)
  margins <- .rtf_margins_twips(preset@margins)

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
    # Reserve roughly two body-line heights for the header zone;
    # \fs is in half-points, twips at 6pt body lead = 240 twips.
    head_line <- as.integer(round(preset@font_size * 28))
    headery <- max(360L, margins$top - head_line)
    parts <- c(parts, sprintf("\\headery%d", headery))
  }
  if (has_pagefoot) {
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
  rows <- character()
  for (i in rev(seq_len(nrow_band))) {
    row_ast <- .page_band_row(pagehead_ast, i)
    rows <- c(
      rows,
      .rtf_chrome_row(row_ast, preset, cs, "pagehead", colors, fonts)
    )
  }
  c("{\\header", rows, "}")
}

# `{\footer ...}` group. Emits one invisible 1-row 3-cell table
# per band row, in FORWARD index order so row 1 (body-edge) ends
# up at the top of the footer zone.
.rtf_footer_group <- function(pagefoot_ast, preset, cs, colors, fonts) {
  nrow_band <- .page_band_nrow(pagefoot_ast)
  rows <- character()
  for (i in seq_len(nrow_band)) {
    row_ast <- .page_band_row(pagefoot_ast, i)
    rows <- c(
      rows,
      .rtf_chrome_row(row_ast, preset, cs, "pagefoot", colors, fonts)
    )
  }
  c("{\\footer", rows, "}")
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
      cells[[length(cells) + 1L]] <- list(
        align = alignments[[s]],
        text = .rtf_resolve_page_tokens(.render_rtf_inline(ast))
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

  # Chrome surface text props (bold/italic/color/font_family/etc).
  # Pagehead/pagefoot slots own their own halign via slot position,
  # so the surface's halign is intentionally not applied here.
  surface_node <- if (!is.null(surface)) {
    .chrome_surface_at(cs, surface)
  } else {
    NULL
  }
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)

  cellx_lines <- character(length(cells))
  cumulative <- 0L
  for (i in seq_along(cells)) {
    cumulative <- cumulative + per_cell
    pos <- if (i == length(cells)) printable else cumulative
    cellx_lines[[i]] <- paste0(
      "\\clbrdrt\\brdrnone\\clbrdrl\\brdrnone\\clbrdrb\\brdrnone\\clbrdrr\\brdrnone",
      sprintf("\\cellx%d", as.integer(pos))
    )
  }

  cell_bodies <- vapply(
    cells,
    function(c) {
      paste0(
        "\\pard\\plain\\intbl ",
        c$align,
        surface_props,
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
        align_tok,
        surface_props,
        " ",
        bold_open,
        .render_rtf_inline(titles_ast[[i]]),
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
  fonts = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  # Footer font size cascade: chrome_style@font_size > preset@font_size - 1
  fs_pt <- if (
    is_style_node(surface_node) &&
      length(surface_node@font_size) == 1L &&
      !is.na(surface_node@font_size)
  ) {
    as.numeric(surface_node@font_size)
  } else {
    max(preset@font_size - 1, 7)
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
        .render_rtf_inline(footnotes_ast[[i]]),
        "\\par"
      )
    },
    character(1L)
  )
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

# Render one page's table. Multi-level header bands emit first
# (each band depth = one `\trowd\...\row`), then the column-labels
# row, then the body rows. Cell widths route through
# `.rtf_cellx_positions` to compute cumulative `\cellx` values.
.render_rtf_table <- function(
  page,
  meta,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL
) {
  col_names_vis <- page$col_names
  cols <- meta$cols %||% list()
  cellx <- .rtf_cellx_positions(col_names_vis, cols, preset)

  band_rows <- .render_rtf_header_bands(
    meta$headers,
    col_names_vis,
    cols,
    cellx,
    preset,
    cs,
    colors,
    fonts
  )
  label_row <- .render_rtf_col_labels_row(
    meta$col_labels_ast,
    col_names_vis,
    cols,
    cellx,
    preset,
    cs,
    colors,
    fonts
  )
  # Subgroup banner row — single merged cell spanning every visible
  # column, centred and bold, with a top + bottom rule for visual
  # separation from the column-header band above and the body rows
  # below. Inserted between the column-labels row and the first
  # body row. Empty when the page carries no subgroup runtime.
  banner_row <- .render_rtf_subgroup_banner_row(
    page$subgroup_line_ast,
    cellx = cellx,
    preset = preset,
    cs = cs,
    colors = colors,
    fonts = fonts
  )

  body_rows <- .render_rtf_body_rows(
    page$cells_text,
    col_names_vis,
    cols,
    cellx,
    cells_style = page$cells_style,
    cells_indent = page$cells_indent,
    is_header_row = page$is_header_row,
    is_blank_row = page$is_blank_row,
    host_col = page$host_col,
    preset = preset,
    cs = cs,
    colors = colors,
    fonts = fonts
  )

  c(band_rows, label_row, banner_row, body_rows)
}

# Render the subgroup banner as a single merged-cell RTF row. Right
# edge sits at the table's final `\cellx` so the cell spans every
# visible column. Returns character(0) when the page carries no
# subgroup runtime.
.render_rtf_subgroup_banner_row <- function(
  subgroup_line_ast,
  cellx,
  preset = NULL,
  cs = NULL,
  colors = NULL,
  fonts = NULL
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
  # over the legacy `solid top / solid bottom` backend defaults.
  top_tok <- .rtf_chrome_border_seg(cs, "subgroup_top", "top", "solid")
  bot_tok <- .rtf_chrome_border_seg(cs, "subgroup_bottom", "bottom", "solid")
  shading <- .rtf_cell_shading(surface_node, colors)
  cellx_line <- paste0(
    top_tok,
    bot_tok,
    .rtf_border_seg("left", NULL, "none"),
    .rtf_border_seg("right", NULL, "none"),
    shading,
    valign_tok,
    sprintf("\\cellx%d", as.integer(cellx[[length(cellx)]]))
  )
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "{\\b "
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"
  cell_body <- paste0(
    "\\pard\\plain\\intbl",
    align_tok,
    surface_props,
    " ",
    bold_open,
    inner,
    bold_close,
    "\\cell"
  )
  c(
    "\\trowd\\trgaph108",
    cellx_line,
    cell_body,
    "\\row"
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
  fonts = NULL
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  out <- character()
  for (d in depths) {
    band_at_depth <- headers[headers$depth == d, , drop = FALSE]
    labels <- vapply(
      col_names_vis,
      function(nm) {
        hit <- vapply(
          seq_len(nrow(band_at_depth)),
          function(i) nm %in% band_at_depth$span_cols[[i]],
          logical(1L)
        )
        if (any(hit)) {
          band_at_depth$label[which(hit)[1L]]
        } else {
          NA_character_
        }
      },
      character(1L)
    )
    runs <- .rtf_group_contiguous_runs(labels)
    out <- c(out, .rtf_band_row(runs, cellx, cs, colors, fonts))
  }
  out
}

# Resolve a chrome border region into an RTF cell-prelude border
# segment. chrome_style$borders takes priority; otherwise the
# backend default. `side` is the cell side ("top" / "bottom" /
# "left" / "right") this segment writes to — chrome border regions
# map onto cell sides via the caller's choice (e.g. "header_top"
# maps to the cell's top side).
.rtf_chrome_border_seg <- function(cs, region, side, backend_default) {
  triple <- .chrome_border_at(cs, region)
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

# Emit one band row given the contiguous-run groups + the
# cumulative `\cellx` positions for the visible columns. Each run
# emits one cell with its right edge at `cellx[run$end]`. Cells
# carry bold + centre alignment + a top + bottom rule (chrome
# style for band headers).
.rtf_band_row <- function(
  runs,
  cellx,
  cs = NULL,
  colors = NULL,
  fonts = NULL
) {
  cellx_lines <- character(length(runs))
  cell_bodies <- character(length(runs))
  col_end <- 0L
  surface_node <- .chrome_surface_at(cs, "header")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  shading <- .rtf_cell_shading(surface_node, colors)
  top_tok <- .rtf_chrome_border_seg(cs, "header_top", "top", "solid")
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
  for (i in seq_along(runs)) {
    run <- runs[[i]]
    col_end <- col_end + run$length
    pos <- cellx[[col_end]]
    cellx_lines[[i]] <- paste0(
      top_tok,
      bot_tok,
      "\\clbrdrl\\brdrnone\\clbrdrr\\brdrnone",
      shading,
      sprintf("\\cellx%d", as.integer(pos))
    )
    label <- run$value
    body <- if (is.na(label)) {
      ""
    } else {
      paste0(bold_open, .rtf_escape(label), bold_close)
    }
    cell_bodies[[i]] <- paste0(
      "\\pard\\plain\\intbl",
      align_tok,
      surface_props,
      " ",
      body,
      "\\cell"
    )
  }
  c(
    "\\trowd\\trgaph108",
    cellx_lines,
    cell_bodies,
    "\\row"
  )
}

# Column-labels row: one cell per visible column, alignment via
# the header cascade (col_spec@align / @valign >
# chrome_style$surfaces$header@halign / header_valign > backend
# default), label from `col_labels_ast` (the parsed AST already
# created by engine_format). Top + bottom rules so the row
# visually separates the head from the body.
.render_rtf_col_labels_row <- function(
  col_labels_ast,
  col_names_vis,
  cols,
  cellx,
  preset,
  cs = NULL,
  colors = NULL,
  fonts = NULL
) {
  cellx_lines <- character(length(col_names_vis))
  cell_bodies <- character(length(col_names_vis))
  surface_node <- .chrome_surface_at(cs, "header")
  surface_props <- .rtf_chrome_text_props(surface_node, colors, fonts)
  shading <- .rtf_cell_shading(surface_node, colors)
  top_tok <- .rtf_chrome_border_seg(cs, "header_top", "top", "solid")
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
      if (col@align == "decimal") "right" else col@align
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
    align_tok <- .rtf_align_token(halign)
    valign_tok <- .rtf_valign_token(valign)
    cellx_lines[[i]] <- paste0(
      top_tok,
      bot_tok,
      .rtf_border_seg("left", NULL, "none"),
      .rtf_border_seg("right", NULL, "none"),
      shading,
      valign_tok,
      sprintf("\\cellx%d", as.integer(cellx[[i]]))
    )
    ast <- col_labels_ast[[nm]]
    label <- if (is.null(ast)) .rtf_escape(nm) else .render_rtf_inline(ast)
    cell_bodies[[i]] <- paste0(
      "\\pard\\plain\\intbl ",
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
    "\\trowd\\trgaph108",
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
  preset = NULL,
  cs = NULL,
  colors = NULL,
  fonts = NULL
) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }

  col_specs <- lapply(col_names_vis, function(nm) cols[[nm]])
  trgaph <- .rtf_body_trgaph(cells_style)
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

  # Final-twip edge for synthesised section-header / blank-gap rows.
  # Single `\cellx` at the right edge so the row spans all columns
  # (mirrors the subgroup-banner emitter).
  final_cellx <- if (length(cellx) > 0L) {
    as.integer(cellx[[length(cellx)]])
  } else {
    0L
  }

  out <- character()
  for (r in seq_len(nrow_data)) {
    if (isTRUE(is_blank_row[[r]])) {
      out <- c(
        out,
        "\\trowd\\trgaph108",
        paste0(
          .rtf_border_seg("top", NULL, "none"),
          .rtf_border_seg("bottom", NULL, "none"),
          .rtf_border_seg("left", NULL, "none"),
          .rtf_border_seg("right", NULL, "none"),
          sprintf("\\cellx%d", final_cellx)
        ),
        "\\pard\\plain\\intbl\\ql \\cell",
        "\\row"
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
      # (twips). Band-1 (depth 0) -> no `\li`; band-2+ -> `\liN`
      # BEFORE the alignment token so RTF readers honour the cell-
      # side left indent.
      header_li_tok <- ""
      if (!is.na(host_idx)) {
        header_depth <- cells_indent[r, host_idx]
        if (
          isTRUE(header_depth > 0L) &&
            indent_twips_per_level > 0L
        ) {
          header_li_tok <- sprintf(
            "\\li%d",
            indent_twips_per_level * header_depth
          )
        }
      }
      out <- c(
        out,
        "\\trowd\\trgaph108",
        paste0(
          .rtf_border_seg("top", NULL, "none"),
          .rtf_border_seg("bottom", NULL, "none"),
          .rtf_border_seg("left", NULL, "none"),
          .rtf_border_seg("right", NULL, "none"),
          sprintf("\\cellx%d", final_cellx)
        ),
        paste0(
          "\\pard\\plain\\intbl",
          header_li_tok,
          "\\ql ",
          "{\\b ",
          .rtf_escape_cell(host_text),
          "}",
          "\\cell"
        ),
        "\\row"
      )
      next
    }
    cellx_lines <- character(length(col_names_vis))
    cell_bodies <- character(length(col_names_vis))
    is_last_row <- (r == nrow_data)
    # Word-side keep-with-next: every row except the last on the
    # page emits \trkeep at the row level and \keepn inside each
    # cell paragraph so Word never re-paginates inside the page
    # tabular has already split. Galley pattern lifted to tabular's
    # manual-pagination model — defense-in-depth against viewer-
    # side re-flow (font substitution, DPI change, locale).
    keep_row <- !is_last_row
    trkeep_tok <- if (keep_row) "\\trkeep" else ""
    keepn_tok <- if (keep_row) "\\keepn" else ""
    for (i in seq_along(col_names_vis)) {
      sn <- .cell_style_at(cells_style, r, col_names_vis[[i]])
      col <- col_specs[[i]]
      halign <- .effective_body_halign(sn, col, preset)
      valign <- .effective_body_valign(sn, col, preset)
      align_tok <- .rtf_align_token(halign)
      valign_tok <- .rtf_valign_token(valign)
      # Backend default per-side borders for a body cell: top and
      # left and right are clear; bottom carries the solid rule only
      # on the final body row of the page (matches the canonical submission Appendix I's
      # closing rule). The cascade resolver overrides these defaults
      # when the user has set explicit border_<side>_style / etc.
      bottom_default <- if (is_last_row) "solid" else "none"
      shading <- .rtf_cell_shading(sn, colors)
      cellx_lines[[i]] <- paste0(
        .rtf_border_seg("top", sn, "none"),
        .rtf_border_seg("bottom", sn, bottom_default),
        .rtf_border_seg("left", sn, "none"),
        .rtf_border_seg("right", sn, "none"),
        shading,
        valign_tok,
        sprintf("\\cellx%d", as.integer(cellx[[i]]))
      )
      # Per-cell native left indent: strip the engine-baked leading
      # spaces and emit `\liN` (twips) on the paragraph BEFORE the
      # alignment token. RTF readers honour `\li` as the cell-side
      # left indent, so wrapped continuation lines inside a narrow
      # column align with the indented baseline.
      raw <- cells_text[r, i]
      depth <- cells_indent[r, i]
      li_tok <- ""
      if (
        isTRUE(depth > 0L) &&
          indent_unit > 0L &&
          !is.na(raw)
      ) {
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
      text <- .rtf_escape_cell(raw)
      text_props <- .rtf_cell_text_props(sn, colors, fonts)
      cell_bodies[[i]] <- paste0(
        "\\pard\\plain\\intbl ",
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
    out <- c(
      out,
      paste0(sprintf("\\trowd\\trgaph%d", trgaph), trkeep_tok),
      cellx_lines,
      cell_bodies,
      "\\row"
    )
  }
  out
}

# Resolve the body row's `\trgaph<halfWidth>` value (twips). Reads
# the representative [1,1] body cell's @padding (set by the lowered
# `preset(padding = list(body = N))` knob or `style(at =
# cells_body(), padding = N)`) and converts pt -> twips (1pt = 20
# twips). Returns the legacy 108-twip (5.4pt) default when no
# override is active. RTF carries one gap per row, so per-side
# padding isn't expressible; the per-cell stamp's scalar value
# applies.
.rtf_body_trgaph <- function(cells_style) {
  pt <- .first_cell_padding(cells_style)
  if (is.na(pt)) {
    return(108L)
  }
  as.integer(round(pt * 20))
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
.rtf_border_seg <- function(side, cell_style, backend_default = "none") {
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
  paste0(prefix, style_tok, sprintf("\\brdrw%d", twips))
}

# Group a vector into runs of consecutive equal values, including
# NA-as-equal-to-NA. Returns a list of `{value, length}` records.
# Same algorithm as `.group_contiguous_runs` in backend_html.R;
# kept local per the per-backend self-containment convention.
.rtf_group_contiguous_runs <- function(x) {
  n <- length(x)
  if (n == 0L) {
    return(list())
  }
  runs <- list()
  start <- 1L
  for (i in seq_len(n)[-1L]) {
    cur <- x[[i]]
    prev <- x[[i - 1L]]
    same <- (is.na(cur) && is.na(prev)) ||
      (!is.na(cur) && !is.na(prev) && identical(cur, prev))
    if (!same) {
      runs[[length(runs) + 1L]] <- list(
        value = x[[start]],
        length = i - start
      )
      start <- i
    }
  }
  runs[[length(runs) + 1L]] <- list(
    value = x[[start]],
    length = n - start + 1L
  )
  runs
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single RTF fragment. Walks every run
# in `ast@runs` recursively. Unknown run types fall through to
# their escaped `text` field.
.render_rtf_inline <- function(ast) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(ast@runs, .render_rtf_run, character(1L)),
    collapse = ""
  )
}

# Render one AST run record to its RTF markup. Recurses through
# `children` for wrapping types.
.render_rtf_run <- function(run) {
  type <- run$type
  switch(
    type,
    plain = .rtf_escape(run$text %||% ""),
    bold = paste0("{\\b ", .render_rtf_children(run$children), "}"),
    italic = paste0("{\\i ", .render_rtf_children(run$children), "}"),
    sup = paste0(
      "{\\super ",
      .render_rtf_children(run$children),
      "\\nosupersub}"
    ),
    sub = paste0(
      "{\\sub ",
      .render_rtf_children(run$children),
      "\\nosupersub}"
    ),
    code = paste0("{\\f1 ", .render_rtf_children(run$children), "}"),
    link = .render_rtf_link(run),
    span = .render_rtf_children(run$children),
    newline = "\\line ",
    .rtf_escape(run$text %||% "")
  )
}

# Render the children of a wrapping run.
.render_rtf_children <- function(children) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(children, .render_rtf_run, character(1L)),
    collapse = ""
  )
}

# Render a link run as an RTF hyperlink field. Word and
# LibreOffice both render the `\fldrslt` text as the clickable
# anchor that resolves to the `HYPERLINK` URL on click.
.render_rtf_link <- function(run) {
  href <- .rtf_escape(run$href %||% "")
  text <- .render_rtf_children(run$children)
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
.rtf_escape_cell <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  out <- .rtf_escape(text)
  out <- gsub("\r\n", "\\line ", out, fixed = TRUE)
  out <- gsub("\n", "\\line ", out, fixed = TRUE)
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
  vapply(
    text,
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

# Walk every style_node that might contribute a color to the
# rendered document. Returns a deduplicated character vector of
# "#RRGGBB" hex codes plus a `lookup(hex) -> integer` closure that
# resolves a hex string to its 1-indexed slot in `\colortbl`. Slot
# 0 is the RTF "auto" sentinel and is reserved.
.rtf_collect_colors <- function(pages, cs, preset) {
  buf <- character()
  for (page in pages) {
    cell_styles <- page$cells_style
    if (is.null(cell_styles)) {
      next
    }
    for (i in seq_len(nrow(cell_styles))) {
      for (j in seq_len(ncol(cell_styles))) {
        sn <- cell_styles[[i, j]]
        if (!is_style_node(sn)) {
          next
        }
        for (prop in c(sn@color, sn@background)) {
          if (length(prop) == 1L && !is.na(prop) && nzchar(prop)) {
            buf <- c(buf, prop)
          }
        }
      }
    }
  }
  if (is.list(cs) && is.list(cs$surfaces)) {
    for (node in cs$surfaces) {
      if (!is_style_node(node)) {
        next
      }
      for (prop in c(node@color, node@background)) {
        if (length(prop) == 1L && !is.na(prop) && nzchar(prop)) {
          buf <- c(buf, prop)
        }
      }
    }
  }
  values <- unique(buf)
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
  values <- c(body_family, "mono")
  for (page in pages) {
    cell_styles <- page$cells_style
    if (is.null(cell_styles)) {
      next
    }
    for (i in seq_len(nrow(cell_styles))) {
      for (j in seq_len(ncol(cell_styles))) {
        sn <- cell_styles[[i, j]]
        if (!is_style_node(sn)) {
          next
        }
        ff <- sn@font_family
        if (
          length(ff) == 1L &&
            !is.na(ff) &&
            nzchar(ff) &&
            !(ff %in% values)
        ) {
          values <- c(values, ff)
        }
      }
    }
  }
  if (is.list(cs) && is.list(cs$surfaces)) {
    for (node in cs$surfaces) {
      if (!is_style_node(node)) {
        next
      }
      ff <- node@font_family
      if (
        length(ff) == 1L &&
          !is.na(ff) &&
          nzchar(ff) &&
          !(ff %in% values)
      ) {
        values <- c(values, ff)
      }
    }
  }
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
