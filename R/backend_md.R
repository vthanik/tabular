# backend_md.R — Markdown / GFM pipe-table backend. Consumes a
# resolved `tabular_grid` and writes a UTF-8 .md file that renders
# in any GFM previewer (GitHub, gitlab, vscode, pandoc, quarto).
# The simplest backend in the family; lands here so the grid +
# emit() + manifest pipeline have a real consumer for the Round 2
# verification gate.
#
# Output layout — one continuous document. Titles emit as
# level-1 headings once above the table. One pipe table per
# horizontal panel (the common case is a single panel) carries
# one header-band block + col-labels row + alignment row, then
# every vertical page's body rows concatenated underneath — no
# inter-page separator, no continuation marker. Footnotes emit
# once below the table. Optional pagehead / pagefoot chrome
# bands frame the whole document, separated by `----` rules:
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
# GFM has no native row spanning, so multi-level header bands emit
# one row per depth where the band label is repeated in every
# spanned cell (the most readable rendering across GFM previewers
# that don't support `colspan`). With `total_panels > 1` (driven by
# `paginate(panels = N)`), panel-tables stack inside the document
# separated by a blank line.
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
  lines <- .render_md_grid(grid)
  writeLines(lines, file, useBytes = FALSE)
  invisible(file)
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
  pad_title_top <- .md_blank_count(cs, "title", "above", 1L)
  pad_title_bottom <- .md_blank_count(cs, "title", "below", 1L)

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

  titles <- .render_md_title_block(meta$titles_ast)
  title_block <- if (length(titles) > 0L) {
    c(rep("", pad_title_top), titles, rep("", pad_title_bottom))
  } else {
    character()
  }
  footnote_block <- .render_md_footnote_block(meta$footnotes_ast)

  out <- list()
  if (length(chrome_top) > 0L) {
    out[[length(out) + 1L]] <- c(chrome_top, "", "----", "")
  }
  if (length(title_block) > 0L) {
    out[[length(out) + 1L]] <- title_block
  }

  if (total == 0L) {
    out[[length(out) + 1L]] <- c("", "(no rows)", "")
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
        panel_lines <- c(panel_lines, .render_md_page_body_rows(page))
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
    # before parsing the following prose.
    out[[length(out) + 1L]] <- c("", footnote_block)
  }
  if (length(chrome_bot) > 0L) {
    out[[length(out) + 1L]] <- c("", "----", "", chrome_bot)
  }
  unlist(out, use.names = FALSE)
}

# Render one page slice's body lines: an optional subgroup banner
# (bold) followed by one pipe-table row per data row. Returns
# character(0) when the slice is empty (no banner, zero rows).
.render_md_page_body_rows <- function(page) {
  c(
    .render_md_subgroup_banner(page),
    .render_md_body_rows(page$cells_text)
  )
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
.render_md_subgroup_banner <- function(page) {
  ast <- page$subgroup_line_ast
  if (is.null(ast) || !is_inline_ast(ast) || length(ast@runs) == 0L) {
    return(character())
  }
  paste0("**", .render_md_inline(ast), "**")
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
.render_md_title_block <- function(titles_ast) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  vapply(
    titles_ast,
    function(ast) paste0("# ", .render_md_inline(ast)),
    character(1L)
  )
}

# Footnote block: each footnote line becomes a regular paragraph
# separated by a blank line. Empty list returns an empty character
# vector.
.render_md_footnote_block <- function(footnotes_ast) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  rendered <- vapply(
    footnotes_ast,
    function(ast) .render_md_inline(ast),
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
      band_at_depth <- headers[headers$depth == d, , drop = FALSE]
      cells <- vapply(
        col_names_visible,
        function(nm) {
          hit <- vapply(
            seq_len(nrow(band_at_depth)),
            function(i) nm %in% band_at_depth$span_cols[[i]],
            logical(1L)
          )
          if (any(hit)) {
            .md_escape_cell(band_at_depth$label[which(hit)[1L]])
          } else {
            ""
          }
        },
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
.render_md_body_rows <- function(cells_text) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }
  vapply(
    seq_len(nrow_data),
    function(i) {
      cells <- vapply(
        seq_len(ncol(cells_text)),
        function(j) .md_escape_cell(cells_text[i, j]),
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
.render_md_inline <- function(ast) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(ast@runs, .render_md_run, character(1L)),
    collapse = ""
  )
}

# Render one AST run record (a named list with at minimum a `type`
# field) to its markdown markup. Recurses through `children` for
# wrapping types.
.render_md_run <- function(run) {
  type <- run$type
  switch(
    type,
    plain = .md_escape_inline(run$text %||% ""),
    bold = paste0("**", .render_md_children(run$children), "**"),
    italic = paste0("*", .render_md_children(run$children), "*"),
    sup = paste0("^", .render_md_children(run$children), "^"),
    sub = paste0("~", .render_md_children(run$children), "~"),
    code = paste0("`", .render_md_children(run$children), "`"),
    link = .render_md_link(run),
    span = .render_md_children(run$children),
    newline = "<br/>",
    .md_escape_inline(run$text %||% "")
  )
}

# Render the children of a wrapping run. The children are
# themselves a list of run records; we walk each and concatenate.
.render_md_children <- function(children) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(children, .render_md_run, character(1L)),
    collapse = ""
  )
}

# Render a link run: `[text](href)`. The link title attribute is
# optional and rendered when set per CommonMark; parse_inline
# emits a character NA when the source markdown carried no title,
# so we guard against NA + empty string both.
.render_md_link <- function(run) {
  text <- .render_md_children(run$children)
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
.md_escape_cell <- function(text) {
  if (is.null(text) || is.na(text)) {
    return("")
  }
  text <- as.character(text)
  text <- gsub("|", "\\|", text, fixed = TRUE)
  text <- gsub("\r\n", "<br/>", text, fixed = TRUE)
  text <- gsub("\n", "<br/>", text, fixed = TRUE)
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
