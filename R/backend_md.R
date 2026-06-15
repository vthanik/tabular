# backend_md.R — Markdown / GFM pipe-table backend. Consumes a
# resolved `tabular_grid` and writes a UTF-8 .md file that renders
# in any GFM previewer (GitHub, gitlab, vscode, pandoc, quarto).
# The simplest backend in the family; lands here so the grid +
# emit() + manifest pipeline have a real consumer for the Round 2
# verification gate.
#
# Output layout — one continuous document. Titles emit as
# level-1 headings once above the table. Markdown is a continuous
# medium with no page width, so a `paginate(panels = N)` request
# never splits: the engine collapses it to ONE pipe table (all
# columns, original order, stub once), carrying an optional
# `**Panel i**` note row (`.render_md_panel_note_row`) + header-band
# block + col-labels row + alignment row, then every vertical page's
# body rows concatenated underneath — no inter-page separator, no
# continuation marker. Footnotes emit once below the table. Optional
# pagehead / pagefoot chrome bands frame the whole document,
# separated by `----` rules:
#
#   Protocol: XYZ | Draft | Page 1 of 1
#
#   ----
#
#   # Title 1
#   # Title 2
#
#   | Band A           ||   Band B          |
#   | Col1 | Col2 | Col3 | Col4 | Col5 | Col6 |
#   |:-----|-----:|-----:|-----:|-----:|-----:|
#   |  ... |  ... |  ... |  ... |  ... |  ... |
#   |  ... |  ... |  ... |  ... |  ... |  ... |
#
#   Footnote 1
#   Footnote 2
#
#   ----
#
#   Program: tool.R | 24MAY2026
#
# GFM has no native row spanning, so multi-level header bands (and
# the `paginate(panels = N)` panel-note row) emit one row where the
# label is repeated in every spanned cell, blank over the stub (the
# most readable rendering across GFM previewers that don't support
# `colspan`).
#
# Inline ASTs (cell text, titles, footnotes, col labels) render
# through `.render_md_inline()` — a recursive walker over the
# `inline_ast@runs` list that maps every recognised run type to
# its CommonMark / Pandoc-extension marker:
#
#   plain    -> verbatim text (escaped for `|`)
#   bold     -> **...**
#   italic   -> *...*
#   sup      -> ^...^   (Pandoc extension)
#   sub      -> ~...~   (Pandoc extension)
#   code     -> `...`
#   link     -> [text](href)
#   span     -> children only (no markdown equivalent for inline styles)
#   newline  -> <br/>   (preserves multi-line cells inside tables)
#
# Alignment row (`:---`, `:---:`, `---:`) is driven by
# `col_spec@align`:
#
#   "left"     -> :---
#   "center"   -> :---:
#   "right"    -> ---:
#   "decimal"  -> ---:   (engine_decimal already padded with NBSP)
#   NA / unset -> :---   (the GFM default)

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a UTF-8 .md file. Called by `emit()` via the
# backend registry. Returns the file path invisibly so the same
# signature would also work when called directly in tests.
backend_md <- function(grid, file) {
  lines <- if (identical(grid@metadata$content_type, "figure")) {
    .render_md_figure(grid, file)
  } else {
    .render_md_grid(grid)
  }
  writeLines(lines, file, useBytes = FALSE)
  invisible(file)
}

# ---------------------------------------------------------------------
# Figure rendering (metadata$content_type == "figure")
# ---------------------------------------------------------------------

# Compose a figure document: faux page chrome (pagehead / pagefoot bands)
# top and bottom, then the plots, each a markdown image referencing a sidecar
# PNG written next to the `.md`. Markdown is a continuous medium with no page
# geometry, so valign is a documented no-op and halign maps to an `<div
# align>` wrapper (center / right; left is a bare image). Multi-page figures
# stack with a `----` rule between plots. Shared chrome (no `meta`) renders
# the title block once at the top and footnotes once at the bottom, like a
# table; per-page chrome (`meta`) keeps each page's own title / footnote.
.render_md_figure <- function(grid, file) {
  meta <- grid@metadata
  pages <- grid@pages
  ws_preserve <- .preset_ws_preserve(meta$preset)
  cs <- meta$chrome_style %||% chrome_style()
  # Inter-section blank-line pads from the spacing gaps (`style()` override
  # wins, else the preset `spacing` gap). Markdown is continuous, so these
  # are blank lines around the title / footnote blocks.
  pad_above_title <- .md_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_to_body <- .md_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )
  pad_body_to_foot <- .md_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )
  total_for_chrome <- max(length(pages), 1L)
  chrome_top <- .render_md_chrome_band(
    meta$pagehead_ast,
    total_pages = total_for_chrome
  )
  chrome_bot <- .render_md_chrome_band(
    meta$pagefoot_ast,
    total_pages = total_for_chrome
  )

  stem <- tools::file_path_sans_ext(basename(file))
  out_dir <- dirname(file)
  n <- length(pages)

  # Write each page's image sidecar once; both chrome layouts reference them.
  sidecar_names <- vapply(
    seq_len(n),
    function(i) sprintf("%s-fig%d.%s", stem, i, pages[[i]]$image_ext),
    character(1L)
  )
  for (i in seq_len(n)) {
    writeBin(pages[[i]]$image_bytes, file.path(out_dir, sidecar_names[i]))
  }
  sidecars <- file.path(out_dir, sidecar_names)

  out <- list()
  if (length(chrome_top) > 0L) {
    out[[length(out) + 1L]] <- c(chrome_top, "", "----", "")
  }

  if (isTRUE(meta$shared_chrome)) {
    # Shared chrome renders once: title block at the top, footnotes at the
    # bottom, the N images stacked with a `----` rule between plots.
    titles <- .render_md_title_block(meta$titles_ast, preserve = ws_preserve)
    if (length(titles) > 0L) {
      out[[length(out) + 1L]] <- c(
        rep("", pad_above_title),
        titles,
        rep("", pad_title_to_body)
      )
    }
    for (i in seq_len(n)) {
      if (i > 1L) {
        out[[length(out) + 1L]] <- c("", "----", "")
      }
      out[[length(out) + 1L]] <- c(
        .md_figure_image(pages[[i]], sidecar_names[i]),
        ""
      )
    }
    foot <- .render_md_footnote_block(
      meta$footnotes_ast,
      preserve = ws_preserve
    )
    if (length(foot) > 0L) {
      out[[length(out) + 1L]] <- c(rep("", pad_body_to_foot), foot)
    }
  } else {
    # Per-page chrome (`meta`): each page carries its own title / footnote.
    for (i in seq_len(n)) {
      pg <- pages[[i]]
      if (i > 1L) {
        out[[length(out) + 1L]] <- c("", "----", "")
      }
      titles <- .render_md_title_block(pg$titles_ast, preserve = ws_preserve)
      foot <- .render_md_footnote_block(
        pg$footnotes_ast,
        preserve = ws_preserve
      )
      title_part <- if (length(titles) > 0L) {
        c(rep("", pad_above_title), titles, rep("", pad_title_to_body))
      } else {
        character()
      }
      foot_part <- if (length(foot) > 0L) {
        c(rep("", pad_body_to_foot), foot)
      } else {
        character()
      }
      out[[length(out) + 1L]] <- c(
        title_part,
        .md_figure_image(pg, sidecar_names[i]),
        "",
        foot_part
      )
    }
  }

  if (length(chrome_bot) > 0L) {
    out[[length(out) + 1L]] <- c("", "----", "", chrome_bot)
  }

  .figure_inform_sidecars(out_dir, sidecars, ".md")
  unlist(out, use.names = FALSE)
}

# One figure image as a markdown image reference. halign center / right
# ride a `<div align>` wrapper (valign has no meaning in continuous
# markdown); left is a bare image.
.md_figure_image <- function(pg, sidecar_name) {
  halign <- pg$place$halign %||% "center"
  img <- sprintf("![Figure](%s)", sidecar_name)
  if (identical(halign, "left")) {
    return(img)
  }
  sprintf("<div align=\"%s\">%s</div>", halign, img)
}

# ---------------------------------------------------------------------
# Grid + page composition
# ---------------------------------------------------------------------

# Compose the full document — pagehead chrome, titles (once),
# one pipe table per horizontal panel concatenating every vertical
# page's body rows, footnotes (once), pagefoot chrome. Returns a
# character vector of lines ready for `writeLines()`. Pure — no
# I/O.
.render_md_grid <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  meta <- grid@metadata
  cs <- meta$chrome_style %||% chrome_style()
  pad_title_top <- .md_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_bottom <- .md_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )

  # Faux page chrome — markdown has no native page-band concept,
  # so emit pagehead at the top of the document and pagefoot at
  # the bottom, surrounded by `----` rules. Three-slot left /
  # center / right collapse to a single ` | `-joined line per row.
  total_for_chrome <- max(total, 1L)
  chrome_top <- .render_md_chrome_band(
    meta$pagehead_ast,
    total_pages = total_for_chrome
  )
  chrome_bot <- .render_md_chrome_band(
    meta$pagefoot_ast,
    total_pages = total_for_chrome
  )

  # Whitespace mode applies to title / footnote chrome too, not just
  # body cells: collapse must drop NBSP runs everywhere or it is a no-op
  # on these surfaces while HTML/LaTeX honour it.
  ws_preserve <- .preset_ws_preserve(meta$preset)
  titles <- .render_md_title_block(meta$titles_ast, preserve = ws_preserve)
  title_block <- if (length(titles) > 0L) {
    c(rep("", pad_title_top), titles, rep("", pad_title_bottom))
  } else {
    character()
  }
  footnote_block <- .render_md_footnote_block(
    meta$footnotes_ast,
    preserve = ws_preserve
  )

  out <- list()
  if (length(chrome_top) > 0L) {
    out[[length(out) + 1L]] <- c(chrome_top, "", "----", "")
  }
  if (length(title_block) > 0L) {
    out[[length(out) + 1L]] <- title_block
  }

  if (total == 0L) {
    out[[length(out) + 1L]] <- c(
      "",
      .render_md_empty_line(meta$empty_text_ast, meta$empty_place),
      ""
    )
  } else {
    # Group pages by panel_index — each horizontal panel renders as
    # its own pipe table. The grid is row-paginated within a panel
    # (every page in a panel shares `col_indices`), so the header
    # block + alignment row emit once per panel, then every page's
    # body rows concatenate underneath.
    panel_indices <- vapply(
      pages,
      function(p) as.integer(p$panel_index %||% 1L),
      integer(1L)
    )
    panel_order <- unique(panel_indices)
    for (k in seq_along(panel_order)) {
      pi <- panel_order[[k]]
      panel_pages <- pages[panel_indices == pi]
      col_names <- panel_pages[[1L]]$col_names
      panel_lines <- c(
        .render_md_panel_note_row(meta$panel_spans, col_names),
        .render_md_header_bands(meta$headers, col_names),
        .render_md_col_labels_row(meta$col_labels_ast, col_names),
        .render_md_alignment_row(
          meta$col_names,
          col_names,
          meta$cols %||% list(),
          cells_style = panel_pages[[1L]]$cells_style
        )
      )
      for (page in panel_pages) {
        panel_lines <- c(
          panel_lines,
          .render_md_page_body_rows(
            page,
            preset = meta$preset,
            cs = cs,
            headers = meta$headers,
            col_names = col_names
          )
        )
      }
      if (isTRUE(panel_pages[[1L]]$is_empty_page)) {
        # Zero-row page: header above is intact; the body is the empty
        # message on its own line below the (closed) pipe table. Markdown
        # has no page geometry, so empty_valign is a documented no-op;
        # empty_halign rides a `<div align>` wrapper (raw HTML, GFM-safe).
        panel_lines <- c(
          panel_lines,
          "",
          .render_md_empty_line(meta$empty_text_ast, meta$empty_place)
        )
      }
      if (k > 1L) {
        out[[length(out) + 1L]] <- ""
      }
      out[[length(out) + 1L]] <- panel_lines
    }
  }

  if (length(footnote_block) > 0L) {
    # Blank line between the pipe table and the footnotes — strict
    # GFM parsers expect a blank line to close a pipe table cleanly
    # before parsing the following prose. Any `body_to_footnote` spacing
    # gap rides ON TOP of that mandatory closing blank (default 0 keeps
    # output byte-identical).
    foot_blank_above <- .md_blank_count(
      cs,
      "footer",
      "above",
      .meta_gap(meta, "body_to_footnote", 0L)
    )
    out[[length(out) + 1L]] <- c(
      "",
      rep("", foot_blank_above),
      footnote_block
    )
  }
  if (length(chrome_bot) > 0L) {
    out[[length(out) + 1L]] <- c("", "----", "", chrome_bot)
  }
  unlist(out, use.names = FALSE)
}

# Empty-state message line for a zero-row page. Markdown cannot span a
# pipe-table cell or vertically position content, so the message rides a
# raw-HTML `<div align>` wrapper (GFM-safe) carrying empty_halign; valign
# is a documented no-op on this continuous medium.
.render_md_empty_line <- function(empty_text_ast, empty_place = NULL) {
  halign <- empty_place$halign %||% "center"
  msg <- if (is.null(empty_text_ast)) {
    "No data available to report"
  } else {
    .render_md_inline(empty_text_ast)
  }
  sprintf("<div align=\"%s\">%s</div>", halign, msg)
}

# Render one page slice's body lines: an optional subgroup banner
# (bold), an optional per-arm BigN row under it, then one pipe-table
# row per data row. Returns character(0) when the slice is empty (no
# banner, zero rows).
.render_md_page_body_rows <- function(
  page,
  preset = NULL,
  cs = NULL,
  headers = NULL,
  col_names = NULL
) {
  banner <- .render_md_subgroup_banner(page, cs)
  # Per-subgroup BigN: emit the per-arm N row only alongside the banner
  # (gated on the banner being present and the page carrying records).
  bign <- if (length(banner) > 0L) {
    .render_md_subgroup_bign_row(page$subgroup_bign, headers, col_names)
  } else {
    character()
  }
  c(
    banner,
    bign,
    .render_md_body_rows(
      page$cells_text,
      is_header_row = page$is_header_row,
      is_blank_row = page$is_blank_row,
      cells_indent = page$cells_indent,
      preset = preset,
      cells_style = page$cells_style
    )
  )
}

# Per-arm BigN row for a subgroup banner: one pipe row aligned to the
# visible columns, the `(N=x)` under each arm and "" elsewhere. A band
# target's N repeats across the band's visible columns -- the same way
# `.render_md_header_bands` repeats a band label, since GFM has no
# colspan -- so no first-leaf degradation and no extra fidelity warning.
# Returns character(0) when the page carries no records.
.render_md_subgroup_bign_row <- function(records, headers, col_names) {
  if (is.null(records) || length(records) == 0L) {
    return(character())
  }
  sp <- .subgroup_bign_spans(records, headers, col_names)
  .md_pipe_row(vapply(sp$text, .md_escape_cell, character(1L)))
}

# Resolve the blank-line count for a chrome surface side. chrome_style
# wins when the user set `style(blank_above = N, at = cells_title())`;
# otherwise the legacy preset `*_pad_*` scalar fills in.
.md_blank_count <- function(cs, surface, side, legacy) {
  node <- .chrome_surface_at(cs, surface)
  prop <- if (identical(side, "above")) node@blank_above else node@blank_below
  if (length(prop) == 1L && !is.na(prop)) {
    return(max(0L, as.integer(prop)))
  }
  max(0L, as.integer(legacy))
}

# Render the subgroup banner (e.g. "Treatment Arm: Placebo") as one
# bold line. Returns character(0) when the page has no subgroup
# runtime, so callers can collapse cleanly.
.render_md_subgroup_banner <- function(page, cs = NULL) {
  ast <- page$subgroup_line_ast
  if (is.null(ast) || !is_inline_ast(ast) || length(ast@runs) == 0L) {
    return(character())
  }
  # Weight + emphasis from the subgroup chrome surface node: NA bold ==
  # bold (default `**`), `isFALSE` == off; italic adds `*`. Colour /
  # background / font are not representable in GFM (one-shot warn).
  surface_node <- .chrome_surface_at(cs, "subgroup")
  .md_warn_dropped_text_props(surface_node, "subgroup banner")
  .md_emphasize(.render_md_inline(ast), surface_node)
}

# Render one chrome band (pagehead or pagefoot) as a character
# vector of literal markdown lines. Each band row collapses the
# three slots (left / center / right) to one `left | center | right`
# line; empty slots emit "" so the visual columns stay aligned. The
# `{page}` and `{npages}` tokens substitute statically to 1 and
# total_pages respectively for screen-reading sanity. Returns
# character(0) when the band has no populated rows.
.render_md_chrome_band <- function(band, total_pages) {
  if (!.page_band_is_populated(band)) {
    return(character())
  }
  n_rows <- .page_band_nrow(band)
  out <- character(n_rows)
  for (i in seq_len(n_rows)) {
    row <- .page_band_row(band, i)
    slots <- vapply(
      list(row$left, row$center, row$right),
      function(ast) .render_md_chrome_slot(ast, total_pages),
      character(1L)
    )
    out[[i]] <- paste(slots, collapse = " | ")
  }
  out
}

# Render one chrome-band slot's inline AST to plain markdown text,
# substituting `{page}` -> 1 and `{npages}` -> total_pages along
# the way (markdown has no live counters; static is the best we
# can do). Empty / missing ASTs return "".
.render_md_chrome_slot <- function(ast, total_pages) {
  if (is.null(ast) || !is_inline_ast(ast) || length(ast@runs) == 0L) {
    return("")
  }
  text <- .render_md_inline(ast)
  text <- gsub("{page}", "1", text, fixed = TRUE)
  text <- gsub("{npages}", as.character(total_pages), text, fixed = TRUE)
  text
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line becomes a level-1 heading. Empty
# title list returns an empty character vector so the caller can
# skip the surrounding spacing.
.render_md_title_block <- function(titles_ast, preserve = TRUE) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  vapply(
    titles_ast,
    function(ast) paste0("# ", .render_md_inline(ast, preserve = preserve)),
    character(1L)
  )
}

# Footnote block: each footnote line becomes a regular paragraph
# separated by a blank line. Empty list returns an empty character
# vector.
.render_md_footnote_block <- function(footnotes_ast, preserve = TRUE) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  rendered <- vapply(
    footnotes_ast,
    function(ast) .render_md_inline(ast, preserve = preserve),
    character(1L)
  )
  # Two-element interleave: line, blank, line, blank... drop
  # trailing blank.
  out <- character()
  for (line in rendered) {
    out <- c(out, line, "")
  }
  out[seq_len(length(out) - 1L)]
}

# ---------------------------------------------------------------------
# Header bands + column labels + alignment row
# ---------------------------------------------------------------------

# Render the panel-spanner note row for a collapsed continuous table.
# `panel_spans` (from the engine) lists each would-be panel's non-stub
# columns; GFM has no real colspan, so we mirror the band workaround:
# repeat `**Panel i**` across every column of panel i, blank over the
# stub. Returns character(0) when `panel_spans` is NULL/empty so
# single-panel / non-continuous output is byte-identical to today.
.render_md_panel_note_row <- function(panel_spans, col_names_visible) {
  if (is.null(panel_spans) || length(panel_spans) == 0L) {
    return(character())
  }
  labels <- rep(NA_character_, length(col_names_visible))
  for (span in panel_spans) {
    pos <- match(span$col_names, col_names_visible)
    pos <- pos[!is.na(pos)]
    labels[pos] <- span$label
  }
  cells <- vapply(
    labels,
    function(l) if (is.na(l)) "" else paste0("**", .md_escape_cell(l), "**"),
    character(1L)
  )
  .md_pipe_row(cells)
}

# Render multi-level header bands. Each band depth becomes one
# table row where the band's label is repeated across every
# spanned column visible on this page; columns not under any band
# at this depth get an empty cell. Returns a character vector of
# zero or more lines (zero when no bands exist).
.render_md_header_bands <- function(headers, col_names_visible) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  vapply(
    depths,
    function(d) {
      labels <- .band_labels_for_depth(headers, d, col_names_visible)
      cells <- vapply(
        labels,
        function(l) if (is.na(l)) "" else .md_escape_cell(l),
        character(1L)
      )
      .md_pipe_row(cells)
    },
    character(1L)
  )
}

# Render the column-labels row: one cell per visible column,
# pulled from `col_labels_ast`. Falls back to the column name when
# the spec did not set a label for that column (engine_format
# already wrote the name into the AST in that case).
.render_md_col_labels_row <- function(col_labels_ast, col_names_visible) {
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      if (is.null(ast)) {
        return(.md_escape_cell(nm))
      }
      .render_md_inline(ast)
    },
    character(1L)
  )
  .md_pipe_row(cells)
}

# Render the GFM alignment row (one `:---` / `:---:` / `---:` per
# visible column). When no col_spec is attached for a column, the
# default is left-align.
.render_md_alignment_row <- function(
  col_names_full,
  col_names_visible,
  cols,
  cells_style = NULL
) {
  # Cascade: col_spec@align > representative cell @halign > GFM left.
  # The per-column "representative cell" reads cells_style[1, nm] — the
  # lowered `preset(alignment = list(body_halign = ...))` stamps the
  # same value on every body cell, so [1, nm] is canonical.
  vapply(
    col_names_visible,
    function(nm) {
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      if (is.na(align) && is.matrix(cells_style) && nrow(cells_style) > 0L) {
        cn <- colnames(cells_style)
        if (is.character(cn) && nm %in% cn) {
          node <- cells_style[[1L, nm]]
          if (is_style_node(node) && !is.na(node@halign)) {
            align <- node@halign
          }
        }
      }
      .md_align_token(align)
    },
    character(1L)
  ) |>
    .md_pipe_row()
}

# Map an `align` value to the GFM separator token. Defaults to
# left when align is unset / NA.
.md_align_token <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return(":---")
  }
  switch(
    align,
    left = ":---",
    center = ":---:",
    right = "---:",
    decimal = "---:",
    ":---"
  )
}

# ---------------------------------------------------------------------
# Body rows
# ---------------------------------------------------------------------

# Render one body row per data row. Cell text is the post-
# engine_decimal `cells_text` slice; we route it through
# `.md_escape_cell()` so embedded `|` and newlines do not break
# the pipe-table parser.
# Wrap GFM emphasis around `text` from a host `style_node`: NA bold ==
# bold (default), `isFALSE` == off; italic adds `*`. `**bold**`,
# `*italic*`, `***both***`, or plain text.
.md_emphasize <- function(text, node) {
  is_bold <- !(is_style_node(node) && isFALSE(node@bold))
  is_italic <- is_style_node(node) && isTRUE(node@italic)
  out <- text
  if (is_italic) {
    out <- paste0("*", out, "*")
  }
  if (is_bold) {
    out <- paste0("**", out, "**")
  }
  out
}

# Markdown (GFM) cannot represent colour, background, or font on a
# surface. Emit a one-shot fidelity warning per (Markdown, attribute)
# per render when the resolved node carries one. Shared by the
# group-header and subgroup paths.
.md_warn_dropped_text_props <- function(node, surface) {
  if (!is_style_node(node)) {
    return(invisible(NULL))
  }
  checks <- list(
    color = node@color,
    background = node@background,
    `font family` = node@font_family,
    `font size` = node@font_size
  )
  for (feature in names(checks)) {
    v <- checks[[feature]]
    has <- length(v) == 1L &&
      !is.na(v) &&
      (is.numeric(v) || (is.character(v) && nzchar(v)))
    if (isTRUE(has)) {
      .fidelity_warn(
        paste(surface, feature),
        "Markdown",
        detail = "GFM has no syntax for colour / background / font; rendered without it."
      )
    }
  }
  invisible(NULL)
}

.render_md_body_rows <- function(
  cells_text,
  is_header_row = NULL,
  is_blank_row = NULL,
  cells_indent = NULL,
  preset = NULL,
  cells_style = NULL
) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }
  ncols <- ncol(cells_text)
  is_header_row <- is_header_row %||% rep(FALSE, nrow_data)
  is_blank_row <- is_blank_row %||% rep(FALSE, nrow_data)
  if (is.null(cells_indent)) {
    cells_indent <- matrix(0L, nrow = nrow_data, ncol = ncols)
  }
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit_text <- .indent_text_unit(indent_size)
  ws_preserve <- .preset_ws_preserve(preset)
  vapply(
    seq_len(nrow_data),
    function(i) {
      # fallback: GFM has no row-spanning. Synthesised section-header
      # rows render the group text bolded in cell 1 with the trailing
      # cells held by `&nbsp;` so renderers (GitHub / pandoc / Quarto)
      # don't collapse the row into a blank line. Blank-gap rows do
      # the same with empty bolded cell 1. Band-2+ headers (depth > 0)
      # prepend `strrep(" ", indent_size * depth)` to the bold text so
      # nested bands render visibly nested in markdown -- the only
      # backend without native padding-left support.
      if (isTRUE(is_blank_row[[i]])) {
        return(.md_pipe_row(rep("&nbsp;", ncols)))
      }
      if (isTRUE(is_header_row[[i]])) {
        host_text <- ""
        host_idx <- NA_integer_
        for (jj in seq_len(ncols)) {
          val <- cells_text[i, jj]
          if (!is.na(val) && nzchar(val)) {
            host_text <- val
            host_idx <- jj
            break
          }
        }
        header_prefix <- ""
        if (!is.na(host_idx) && nzchar(indent_unit_text)) {
          header_depth <- cells_indent[i, host_idx]
          if (isTRUE(header_depth > 0L)) {
            header_prefix <- strrep(indent_unit_text, header_depth)
          }
        }
        # Group-header weight + emphasis from the host cell's stamped
        # style_node: NA bold == bold (default `**`), `isFALSE` == off;
        # italic adds `*`. GFM cannot represent colour / background /
        # font, so those degrade with a one-shot fidelity warning.
        host_node <- if (!is.null(cells_style) && !is.na(host_idx)) {
          cells_style[[i, host_idx]]
        } else {
          NULL
        }
        .md_warn_dropped_text_props(host_node, "group header")
        first_cell <- .md_emphasize(
          paste0(
            header_prefix,
            .md_escape_cell(host_text, preserve = ws_preserve)
          ),
          host_node
        )
        return(.md_pipe_row(c(first_cell, rep("&nbsp;", ncols - 1L))))
      }
      cells <- vapply(
        seq_len(ncols),
        function(j) .md_escape_cell(cells_text[i, j], preserve = ws_preserve),
        character(1L)
      )
      .md_pipe_row(cells)
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single markdown string. Walks every
# run in `ast@runs` recursively. Unknown run types fall through to
# their `text` field (defensive — the inline_ast validator already
# rejects unknown types at construction).
.render_md_inline <- function(ast, preserve = TRUE) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  .render_md_children(ast@runs, preserve, lead = TRUE, trail = TRUE)
}

# Render one AST run record (a named list with at minimum a `type`
# field) to its markdown markup. Recurses through `children` for
# wrapping types. `lead` / `trail` flag whether the run is at the
# start / end of its visual line (only then is leading / trailing
# whitespace made non-breaking; inter-run spaces stay breakable).
.render_md_run <- function(run, preserve = TRUE, lead = TRUE, trail = TRUE) {
  type <- run$type
  switch(
    type,
    plain = .md_escape_text_run(run$text %||% "", preserve, lead, trail),
    bold = paste0(
      "**",
      .render_md_children(run$children, preserve, lead, trail),
      "**"
    ),
    italic = paste0(
      "*",
      .render_md_children(run$children, preserve, lead, trail),
      "*"
    ),
    sup = paste0(
      "^",
      .render_md_children(run$children, preserve, lead, trail),
      "^"
    ),
    sub = paste0(
      "~",
      .render_md_children(run$children, preserve, lead, trail),
      "~"
    ),
    code = paste0(
      "`",
      .render_md_children(run$children, preserve, lead, trail),
      "`"
    ),
    link = .render_md_link(run, preserve, lead, trail),
    span = .render_md_children(run$children, preserve, lead, trail),
    newline = "<br/>",
    .md_escape_text_run(run$text %||% "", preserve, lead, trail)
  )
}

# Escape a plain-text run and, when preserving, rewrite significant
# whitespace runs into `&nbsp;` (the single chokepoint for inline
# plain text, mirroring the body-cell path).
.md_escape_text_run <- function(text, preserve, lead = TRUE, trail = TRUE) {
  .escape_text_run(text, .md_escape_inline, "&nbsp;", preserve, lead, trail)
}

# Render the children of a wrapping run. Each child's line-edge flags
# come from its position (first / after-newline -> line-leading, etc.).
.render_md_children <- function(
  children,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  .render_ast_children(children, .render_md_run, preserve, lead, trail)
}

# Render a link run: `[text](href)`. The link title attribute is
# optional and rendered when set per CommonMark; parse_inline
# emits a character NA when the source markdown carried no title,
# so we guard against NA + empty string both.
.render_md_link <- function(run, preserve = TRUE, lead = TRUE, trail = TRUE) {
  text <- .render_md_children(run$children, preserve, lead, trail)
  href <- run$href %||% ""
  title <- run$title
  if (!is.null(title) && !is.na(title) && nzchar(title)) {
    return(sprintf('[%s](%s "%s")', text, href, title))
  }
  sprintf("[%s](%s)", text, href)
}

# ---------------------------------------------------------------------
# Pipe-table cell escaping
# ---------------------------------------------------------------------

# Escape a body / header cell. The pipe-table parser interprets `|`
# as a column separator and `\n` as a row separator; we escape
# both. NA cell values (caller-error guard) render as the empty
# string.
.md_escape_cell <- function(text, preserve = TRUE) {
  if (is.null(text) || is.na(text)) {
    return("")
  }
  text <- as.character(text)
  # Peel any auto-footnote marker sentinel off the cell end; re-attach
  # it as a Pandoc superscript after the base is escaped.
  sp <- .fn_peel(text)
  text <- sp$base
  text <- gsub("|", "\\|", text, fixed = TRUE)
  text <- gsub("\r\n", "<br/>", text, fixed = TRUE)
  text <- gsub("\n", "<br/>", text, fixed = TRUE)
  # Preserve significant ASCII whitespace LAST. md has no CSS / twips
  # indent channel, so the engine indent rides verbatim in `cells_text`;
  # rewriting runs to `&nbsp;` is what makes that indent survive the
  # GFM -> HTML render instead of collapsing.
  if (isTRUE(preserve)) {
    text <- .preserve_ws(text, "&nbsp;")
  }
  if (isTRUE(sp$has)) {
    text <- paste0(text, "^", .md_escape_inline(sp$marker), "^")
  }
  text
}

# Escape inline plain-text runs. Pipe characters inside titles and
# footnotes are still legal markdown — but inside a table cell they
# would break the row; the cell-level escape handles that
# downstream. Here we only escape characters that would
# accidentally start a markdown construct mid-run.
.md_escape_inline <- function(text) {
  if (is.null(text) || is.na(text)) {
    return("")
  }
  text <- as.character(text)
  text <- gsub("|", "\\|", text, fixed = TRUE)
  # Escape literal asterisks so a plain-text run is never reparsed as
  # emphasis/strong. The footnote symbols scheme spills to doubled
  # glyphs ("**" at the 7th marker); without this, "^**^" reads as a
  # strong delimiter inside the Pandoc superscript and corrupts the cell.
  text <- gsub("*", "\\*", text, fixed = TRUE)
  text
}

# Assemble a list of cell strings into one pipe-table row. Adds the
# canonical leading + trailing `|` so the GFM parser anchors the
# row correctly even when the leftmost / rightmost cell is empty.
.md_pipe_row <- function(cells) {
  paste0("| ", paste(cells, collapse = " | "), " |")
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("md", backend_md)
