# backend_html.R — HTML backend. Consumes a resolved
# `tabular_grid` and writes a self-contained UTF-8 .html file
# whose visual style mirrors a Bootstrap-5-light table (no CDN
# dependency — the minimum CSS is inlined inside a `<style>`
# block so the file renders identically online, offline, in
# email, and in `file://` previews).
#
# Output layout — one `<section class="tabular-page">` per
# `grid@pages` entry; titles emit as `<h1 class="tabular-title">`,
# the table emits as `<table class="tabular-table">` with a
# proper `<thead>` (multi-row band stack + column-labels row) and
# `<tbody>` (post-engine_decimal cells), footnotes emit as
# `<p class="tabular-footnote">`. Multi-page documents stack
# sections separated by a horizontal rule on screen and a
# `page-break-after` rule when printed.
#
# HTML gives us real `colspan` for header bands — much cleaner
# than the GFM workaround in `backend_md.R`. For each band-row
# depth we walk the visible columns left-to-right and group
# contiguous runs sharing the same band label (or no band), then
# emit one `<th colspan="N">` per run.
#
# Inline ASTs (cell text, titles, footnotes, col labels) render
# through `.render_html_inline()` — a recursive walker over the
# `inline_ast@runs` list that maps every recognised run type to
# its HTML element:
#
#   plain    -> escaped text
#   bold     -> <strong>...</strong>
#   italic   -> <em>...</em>
#   sup      -> <sup>...</sup>
#   sub      -> <sub>...</sub>
#   code     -> <code>...</code>
#   link     -> <a href="...">...</a>
#   span     -> <span>...</span>     (carries inline style if needed)
#   newline  -> <br/>                (preserves multi-line cells)
#
# Cell text and inline plain runs are HTML-escaped via
# `.html_escape()` — `&`, `<`, `>`, `"`, `'` swapped for their
# named entities. Engine-decimal NBSP padding ( ) is
# preserved verbatim so column alignment survives.

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a self-contained UTF-8 .html file. Called by
# `emit()` via the backend registry. Returns the file path
# invisibly.
backend_html <- function(grid, file) {
  lines <- .render_html_grid(grid)
  writeLines(lines, file, useBytes = FALSE)
  invisible(file)
}

# ---------------------------------------------------------------------
# Document shell + page composition
# ---------------------------------------------------------------------

# Compose the full HTML document: doctype, head (charset, title,
# inline stylesheet), body with one section per page separated by
# a horizontal rule on screen + print page-break. Returns a
# character vector of lines ready for `writeLines()`. Pure — no
# I/O.
.render_html_grid <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  meta <- grid@metadata
  doc_title <- .html_doc_title(meta)

  head <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    paste0("<title>", .html_escape(doc_title), "</title>"),
    .html_inline_style(meta$preset),
    "</head>",
    "<body>"
  )
  tail <- c("</body>", "</html>")

  if (total == 0L) {
    return(c(head, .render_html_empty_grid(grid), tail))
  }

  body <- list()
  for (i in seq_along(pages)) {
    section <- .render_html_page(
      page = pages[[i]],
      meta = meta,
      page_number = i,
      total_pages = total
    )
    if (i > 1L) {
      body[[length(body) + 1L]] <- c(
        "<hr class=\"tabular-page-break\"/>",
        sprintf("<!-- page %d of %d -->", i, total)
      )
    }
    body[[length(body) + 1L]] <- section
  }
  c(head, unlist(body, use.names = FALSE), tail)
}

# Render the HTML skeleton for a spec whose grid has zero pages
# (empty data + no body content). Titles + footnotes still appear;
# the table block is replaced with a `<p class="tabular-empty">`
# marker so the reader sees the table exists but is empty.
.render_html_empty_grid <- function(grid) {
  meta <- grid@metadata
  c(
    "<section class=\"tabular-page\">",
    .render_html_title_block(meta$titles_ast),
    "<p class=\"tabular-empty\">(no rows)</p>",
    .render_html_footnote_block(meta$footnotes_ast),
    "</section>"
  )
}

# Render one page section. Page 1 carries titles + footnotes;
# continuation pages get the (optional) `continuation` marker the
# user set on `paginate()`. Header bands + column-labels row
# repeat on every page when `page$repeat_headers` is TRUE.
.render_html_page <- function(page, meta, page_number, total_pages) {
  out <- "<section class=\"tabular-page\">"

  if (page_number == 1L) {
    out <- c(out, .render_html_title_block(meta$titles_ast))
  } else if (length(page$continuation) > 0L) {
    out <- c(
      out,
      paste0(
        "<p class=\"tabular-continuation\"><em>",
        .html_escape(as.character(page$continuation)),
        "</em></p>"
      )
    )
  }

  show_header <- page_number == 1L || isTRUE(page$repeat_headers)
  table_lines <- .render_html_table(
    page = page,
    meta = meta,
    show_header = show_header
  )
  out <- c(out, table_lines)

  if (page_number == 1L) {
    out <- c(out, .render_html_footnote_block(meta$footnotes_ast))
  }
  c(out, "</section>")
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line becomes an `<h1 class="tabular-
# title">`. Empty title list returns an empty character vector so
# the caller can skip the surrounding spacing.
.render_html_title_block <- function(titles_ast) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  vapply(
    titles_ast,
    function(ast) {
      paste0(
        "<h1 class=\"tabular-title\">",
        .render_html_inline(ast),
        "</h1>"
      )
    },
    character(1L)
  )
}

# Footnote block: each footnote line becomes a `<p class="tabular-
# footnote">`. Empty list returns an empty character vector.
.render_html_footnote_block <- function(footnotes_ast) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  vapply(
    footnotes_ast,
    function(ast) {
      paste0(
        "<p class=\"tabular-footnote\">",
        .render_html_inline(ast),
        "</p>"
      )
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Table assembly: <table> / <thead> / <tbody>
# ---------------------------------------------------------------------

# Assemble the `<table>` block: optional `<thead>` (header bands
# + column-labels row), then `<tbody>` (one row per data row).
.render_html_table <- function(page, meta, show_header) {
  out <- "<table class=\"tabular-table\">"
  if (show_header) {
    thead <- .render_html_thead(
      headers = meta$headers,
      col_labels_ast = meta$col_labels_ast,
      col_names_visible = page$col_names,
      cols = meta$cols %||% list()
    )
    out <- c(out, thead)
  }
  out <- c(
    out,
    .render_html_tbody(
      cells_text = page$cells_text,
      col_names_visible = page$col_names,
      cols = meta$cols %||% list()
    )
  )
  c(out, "</table>")
}

# Compose the `<thead>` block: zero or more band rows (one per
# header-tree depth) plus the column-labels row.
.render_html_thead <- function(
  headers,
  col_labels_ast,
  col_names_visible,
  cols
) {
  out <- "<thead>"
  band_rows <- .render_html_header_bands(headers, col_names_visible)
  out <- c(out, band_rows)
  out <- c(
    out,
    .render_html_col_labels_row(col_labels_ast, col_names_visible, cols)
  )
  c(out, "</thead>")
}

# Render multi-level header bands using real `colspan`. For each
# band-row depth we walk visible columns left-to-right and group
# contiguous runs sharing the same band label (or no band); each
# run emits one `<th colspan="N">`. Returns a character vector of
# zero or more rows (zero when no bands exist).
.render_html_header_bands <- function(headers, col_names_visible) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  vapply(
    depths,
    function(d) {
      band_at_depth <- headers[headers$depth == d, , drop = FALSE]
      labels <- vapply(
        col_names_visible,
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
      runs <- .group_contiguous_runs(labels)
      cells <- vapply(
        runs,
        function(run) {
          lbl <- run$value
          span <- run$length
          if (is.na(lbl)) {
            sprintf("<th colspan=\"%d\"></th>", span)
          } else {
            sprintf(
              "<th colspan=\"%d\" class=\"tabular-band\">%s</th>",
              span,
              .html_escape(lbl)
            )
          }
        },
        character(1L)
      )
      paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    },
    character(1L)
  )
}

# Render the column-labels row: one `<th>` per visible column,
# alignment class derived from `col_spec@align`. Label pulled
# from `col_labels_ast`; falls back to the column name when the
# spec did not set a label.
.render_html_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols
) {
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      label <- if (is.null(ast)) {
        .html_escape(nm)
      } else {
        .render_html_inline(ast)
      }
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      cls <- .html_align_class(align)
      if (nzchar(cls)) {
        sprintf("<th class=\"%s\">%s</th>", cls, label)
      } else {
        paste0("<th>", label, "</th>")
      }
    },
    character(1L)
  )
  paste0("<tr>", paste(cells, collapse = ""), "</tr>")
}

# Render the `<tbody>` block: one `<tr>` per data row, one `<td>`
# per visible column, alignment class derived from
# `col_spec@align`. Cell text comes from `cells_text` (post-
# engine_decimal); we HTML-escape verbatim so NBSP padding
# survives.
.render_html_tbody <- function(cells_text, col_names_visible, cols) {
  out <- "<tbody>"
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(c(out, "</tbody>"))
  }
  align_classes <- vapply(
    col_names_visible,
    function(nm) {
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      .html_align_class(align)
    },
    character(1L)
  )
  rows <- vapply(
    seq_len(nrow_data),
    function(i) {
      cells <- vapply(
        seq_along(col_names_visible),
        function(j) {
          text <- .html_escape_cell(cells_text[i, j])
          cls <- align_classes[[j]]
          if (nzchar(cls)) {
            sprintf("<td class=\"%s\">%s</td>", cls, text)
          } else {
            paste0("<td>", text, "</td>")
          }
        },
        character(1L)
      )
      paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    },
    character(1L)
  )
  c(out, rows, "</tbody>")
}

# Map an `align` value to a CSS alignment class. Defaults to the
# empty string (inherit) when align is unset / NA, so the browser
# applies its own left-align default without us emitting a
# redundant class.
.html_align_class <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("")
  }
  switch(
    align,
    left = "text-left",
    center = "text-center",
    right = "text-right",
    decimal = "text-right",
    ""
  )
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single HTML fragment. Walks every
# run in `ast@runs` recursively. Unknown run types fall through
# to their (escaped) `text` field.
.render_html_inline <- function(ast) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(ast@runs, .render_html_run, character(1L)),
    collapse = ""
  )
}

# Render one AST run record to its HTML markup. Recurses through
# `children` for wrapping types.
.render_html_run <- function(run) {
  type <- run$type
  switch(
    type,
    plain = .html_escape(run$text %||% ""),
    bold = paste0(
      "<strong>",
      .render_html_children(run$children),
      "</strong>"
    ),
    italic = paste0("<em>", .render_html_children(run$children), "</em>"),
    sup = paste0("<sup>", .render_html_children(run$children), "</sup>"),
    sub = paste0("<sub>", .render_html_children(run$children), "</sub>"),
    code = paste0("<code>", .render_html_children(run$children), "</code>"),
    link = .render_html_link(run),
    span = paste0("<span>", .render_html_children(run$children), "</span>"),
    newline = "<br/>",
    .html_escape(run$text %||% "")
  )
}

# Render the children of a wrapping run. The children are
# themselves a list of run records; walk each and concatenate.
.render_html_children <- function(children) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(children, .render_html_run, character(1L)),
    collapse = ""
  )
}

# Render a link run as `<a href="..." title="...">text</a>`. The
# title attribute is optional and emitted only when set per
# CommonMark; parse_inline emits a character NA when the source
# markdown carried no title, so we guard against NA + empty
# string both. `href` and `title` are attribute-escaped.
.render_html_link <- function(run) {
  text <- .render_html_children(run$children)
  href <- run$href %||% ""
  title <- run$title
  if (!is.null(title) && !is.na(title) && nzchar(title)) {
    return(sprintf(
      "<a href=\"%s\" title=\"%s\">%s</a>",
      .html_escape(href),
      .html_escape(title),
      text
    ))
  }
  sprintf("<a href=\"%s\">%s</a>", .html_escape(href), text)
}

# ---------------------------------------------------------------------
# Escaping + utilities
# ---------------------------------------------------------------------

# HTML-escape a body cell — full attribute-safe escape PLUS `\n`
# (and `\r\n`) -> `<br/>` so multi-line strings emitted by
# engine_decimal survive into the rendered table. Use only for
# table-cell text; titles / footnotes / col labels go through the
# inline AST which has its own newline-run handling.
.html_escape_cell <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub("\"", "&quot;", text, fixed = TRUE)
  text <- gsub("'", "&#39;", text, fixed = TRUE)
  text <- gsub("\r\n", "<br/>", text, fixed = TRUE)
  text <- gsub("\n", "<br/>", text, fixed = TRUE)
  text
}

# HTML-escape a string for safe insertion into both element bodies
# and attribute values. Order matters — `&` first so we don't
# double-escape the entities we add. NULL / NA / length-0 collapse
# to the empty string.
.html_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub("\"", "&quot;", text, fixed = TRUE)
  text <- gsub("'", "&#39;", text, fixed = TRUE)
  text
}

# Group a vector into runs of consecutive equal values, including
# NA-as-equal-to-NA. Returns a list of `{value, length}` records.
# Used by the header-band renderer to compute `colspan` widths.
.group_contiguous_runs <- function(x) {
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

# Document `<title>` derived from the first title AST when
# available; falls back to "tabular" so the browser tab always
# has something readable.
.html_doc_title <- function(meta) {
  asts <- meta$titles_ast %||% list()
  if (length(asts) == 0L) {
    return("tabular")
  }
  text <- .render_html_inline(asts[[1L]])
  text <- gsub("<[^>]+>", "", text, perl = TRUE)
  text <- gsub("&[a-zA-Z#0-9]+;", "", text)
  if (!nzchar(text)) {
    return("tabular")
  }
  text
}

# Inline stylesheet — minimum Bootstrap-5-light table chrome,
# kept tight so the output file stays small and renders
# identically online, offline, in email, and via `file://`. Print
# media query inserts a hard page break after each
# `.tabular-page` so multi-page documents print 1-to-1.
#
# The body `font-family` stack is derived from the spec's preset
# (see `.resolve_font_stack` in `R/fonts.R`); falls back to the
# `serif` generic chain when no preset is attached.
.html_inline_style <- function(preset = NULL) {
  c(
    "<style>",
    sprintf(
      "body { font-family: %s; color: #212529; margin: 1.5rem; }",
      .html_font_family_css(preset)
    ),
    ".tabular-page { margin-bottom: 2rem; }",
    ".tabular-title { font-size: 1.1rem; font-weight: 600; text-align: center; margin: .2rem 0; }",
    ".tabular-continuation { text-align: right; color: #6c757d; margin: .25rem 0 .5rem; }",
    ".tabular-table { width: 100%; border-collapse: collapse; margin: .75rem 0; font-size: .9rem; }",
    ".tabular-table th, .tabular-table td { padding: .35rem .6rem; vertical-align: top; }",
    ".tabular-table thead th { border-top: 1px solid #212529; border-bottom: 1px solid #212529; font-weight: 600; }",
    ".tabular-table thead tr:not(:last-child) th { border-bottom: 1px solid #adb5bd; }",
    ".tabular-table tbody tr td { border-top: none; }",
    ".tabular-table tbody tr:last-child td { border-bottom: 1px solid #212529; }",
    ".tabular-band { text-align: center; }",
    ".text-left { text-align: left; }",
    ".text-center { text-align: center; }",
    ".text-right { text-align: right; }",
    ".tabular-footnote { font-size: .85rem; color: #495057; margin: .25rem 0; }",
    ".tabular-empty { font-style: italic; color: #6c757d; }",
    ".tabular-page-break { border: none; border-top: 1px dashed #adb5bd; margin: 1.5rem 0; }",
    "@media print { .tabular-page { page-break-after: always; } .tabular-page-break { display: none; } }",
    "</style>"
  )
}

# Compose the CSS `font-family` value from the spec's preset.
# Routes through `.resolve_font_stack` (R/fonts.R) so the chain
# logic (generic family / single name / explicit stack) is
# shared with every other backend.
.html_font_family_css <- function(preset) {
  fam <- if (is_preset_spec(preset)) preset@font_family else "serif"
  chain <- .resolve_font_stack(fam, "html")
  paste(vapply(chain, .html_quote_font, character(1L)), collapse = ", ")
}

# `%||%` — local fallback when rlang's is not in scope. Mirrors
# rlang::`%||%` semantics: returns `b` when `a` is NULL.
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("html", backend_html)
