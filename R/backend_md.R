# backend_md.R — Markdown / GFM pipe-table backend. Consumes a
# resolved `tabular_grid` and writes a UTF-8 .md file that renders
# in any GFM previewer (GitHub, gitlab, vscode, pandoc, quarto).
# The simplest backend in the family; lands here so the grid +
# emit() + manifest pipeline have a real consumer for the Round 2
# verification gate.
#
# Output layout — one page block per `grid@pages` entry, separated
# by an HTML page-marker comment + horizontal rule:
#
#   # Title 1
#   # Title 2
#
#   | Band A           ||   Band B          |
#   | Col1 | Col2 | Col3 | Col4 | Col5 | Col6 |
#   |:-----|-----:|-----:|-----:|-----:|-----:|
#   |  ... |  ... |  ... |  ... |  ... |  ... |
#
#   Footnote 1
#   Footnote 2
#
#   <!-- page 2 of 3 -->
#   ----
#   ...
#
# GFM has no native row spanning, so multi-level header bands emit
# one row per depth where the band label is repeated in every
# spanned cell (the most readable rendering across GFM previewers
# that don't support `colspan`).
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

# Compose every page in the grid, separated by a page-marker
# comment and a horizontal rule. Returns a character vector of
# lines ready for `writeLines()`. Pure — no I/O.
.render_md_grid <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  if (total == 0L) {
    return(.render_md_empty_grid(grid))
  }
  out <- list()
  for (i in seq_along(pages)) {
    page_lines <- .render_md_page(
      page = pages[[i]],
      meta = grid@metadata,
      page_number = i,
      total_pages = total
    )
    if (i > 1L) {
      out[[length(out) + 1L]] <- c(
        "",
        sprintf("<!-- page %d of %d -->", i, total),
        "",
        "----",
        ""
      )
    }
    out[[length(out) + 1L]] <- page_lines
  }
  unlist(out, use.names = FALSE)
}

# Render the markdown skeleton for a spec whose grid has zero
# pages (empty data + no body content). Titles + footnotes still
# appear; the table block is replaced with a `(no rows)` marker so
# the reader sees the table exists but is empty.
.render_md_empty_grid <- function(grid) {
  meta <- grid@metadata
  c(
    .render_md_title_block(meta$titles_ast),
    "",
    "(no rows)",
    "",
    .render_md_footnote_block(meta$footnotes_ast)
  )
}

# Render one page: title block (page 1 only) -> header bands ->
# column labels row -> alignment row -> body rows -> footnote
# block (page 1 only).
#
# Titles and footnotes ride on page 1 only; continuation pages get
# the (optional) `continuation` marker the user set on
# `paginate()`. Header band + column-labels row repeat on every
# page when `page$repeat_headers` is TRUE (the default).
.render_md_page <- function(page, meta, page_number, total_pages) {
  out <- character()

  if (page_number == 1L) {
    titles <- .render_md_title_block(meta$titles_ast)
    if (length(titles) > 0L) {
      out <- c(out, titles, "")
    }
  } else if (length(page$continuation) > 0L) {
    out <- c(out, paste0("*", as.character(page$continuation), "*"), "")
  }

  show_header <- page_number == 1L || isTRUE(page$repeat_headers)
  if (show_header) {
    out <- c(
      out,
      .render_md_header_bands(meta$headers, page$col_names),
      .render_md_col_labels_row(meta$col_labels_ast, page$col_names),
      .render_md_alignment_row(
        meta$col_names,
        page$col_names,
        meta$cols %||% list()
      )
    )
  }

  out <- c(out, .render_md_body_rows(page$cells_text))

  if (page_number == 1L) {
    footnotes <- .render_md_footnote_block(meta$footnotes_ast)
    if (length(footnotes) > 0L) {
      out <- c(out, "", footnotes)
    }
  }
  out
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
  cols
) {
  vapply(
    col_names_visible,
    function(nm) {
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
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
