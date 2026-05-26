# backend_html.R — HTML backend. Consumes a resolved
# `tabular_grid` and writes a self-contained UTF-8 .html file
# whose visual style mirrors a Bootstrap-5-light table (no CDN
# dependency — the minimum CSS is inlined inside a `<style>`
# block so the file renders identically online, offline, in
# email, and in `file://` previews).
#
# Output layout — one continuous document. Titles emit as
# `<h1 class="tabular-title">` above the table (once). One
# `<table class="tabular-table">` per horizontal panel (the
# common case is a single panel) carries one `<colgroup>`, one
# `<thead>` (multi-row band stack + column-labels row), and one
# `<tbody>` whose rows concatenate every vertical page slice.
# Between vertical pages, an invisible `<tr class="tabular-page-
# break-row">` rides in the `<tbody>` — `display: none` on
# screen, `page-break-before: always` under `@media print`.
# Browsers natively repeat `<thead>` across printed page breaks
# of a single `<table>`, so no per-page header plumbing is
# needed. Footnotes emit as `<p class="tabular-footnote">` once
# below the table. When `total_panels > 1` (driven by
# `paginate(panels = N)`), panel-tables stack inside `<body>`
# and a single `@media print` rule on `.tabular-table +
# .tabular-table` forces each subsequent panel onto a new
# printed page.
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
# inline stylesheet), then a continuous body — chrome header,
# titles (once), one `<table>` per horizontal panel concatenating
# every vertical page's rows inside a single `<tbody>` (with
# print-only `<tr class="tabular-page-break-row">` markers between
# them), footnotes (once), chrome footer. Returns a character
# vector of lines ready for `writeLines()`. Pure — no I/O.
.render_html_grid <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  meta <- grid@metadata
  doc_title <- .html_doc_title(meta)
  cs <- meta$chrome_style %||% chrome_style()

  head <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    paste0("<title>", .html_escape(doc_title), "</title>"),
    .html_inline_style(
      preset = meta$preset,
      pagehead_ast = meta$pagehead_ast,
      pagefoot_ast = meta$pagefoot_ast
    ),
    "</head>",
    "<body class=\"tabular-doc\">"
  )
  tail <- c("</body>", "</html>")

  # On-screen chrome — semantic HTML5 `<header>` above the document
  # body and `<footer>` below. The CSS `@page` rules at
  # `.html_inline_style()` still drive print-time chrome (so
  # printed output continues to match the canonical submission
  # Appendix I per-page). `chrome_onscreen = "off"` on the preset
  # suppresses the on-screen band (print-only behaviour, useful
  # when the HTML is consumed exclusively via print-to-PDF).
  preset <- meta$preset
  chrome_mode <- if (is_preset_spec(preset)) {
    preset@chrome_onscreen
  } else {
    "auto"
  }
  total_for_chrome <- max(total, 1L)
  onscreen_header <- .html_render_chrome_band(
    meta$pagehead_ast,
    zone = "header",
    total_pages = total_for_chrome,
    chrome_mode = chrome_mode
  )
  onscreen_footer <- .html_render_chrome_band(
    meta$pagefoot_ast,
    zone = "footer",
    total_pages = total_for_chrome,
    chrome_mode = chrome_mode
  )

  # Title block — emitted once above the table, with optional
  # blank-paragraph padding from `chrome_style$surfaces$title`
  # (blank_above / blank_below).
  blank_p <- "<p class=\"tabular-pad\">&nbsp;</p>"
  pad_title_top <- .html_blank_count(cs, "title", "above", 1L)
  pad_title_bottom <- .html_blank_count(cs, "title", "below", 1L)
  titles <- .render_html_title_block(
    meta$titles_ast,
    preset = preset,
    cs = cs
  )
  title_block <- if (length(titles) > 0L) {
    c(
      rep(blank_p, pad_title_top),
      titles,
      rep(blank_p, pad_title_bottom)
    )
  } else {
    character()
  }

  footnote_block <- .render_html_footnote_block(
    meta$footnotes_ast,
    preset = preset,
    cs = cs
  )

  if (total == 0L) {
    body_inner <- c(
      title_block,
      "<p class=\"tabular-empty\">(no rows)</p>",
      footnote_block
    )
    return(c(head, onscreen_header, body_inner, onscreen_footer, tail))
  }

  # Group pages by panel_index so each horizontal panel renders as
  # its own `<table>`. The page order produced by
  # `engine_paginate.R:133-146` is (panel outer, vertical inner), so
  # iterating panels and pulling their vertical pages preserves the
  # original sequence. Hidden columns are already filtered upstream
  # at `engine_paginate.R:114`.
  panel_indices <- vapply(
    pages,
    function(p) as.integer(p$panel_index %||% 1L),
    integer(1L)
  )
  panel_order <- unique(panel_indices)
  tables <- list()
  for (pi in panel_order) {
    panel_pages <- pages[panel_indices == pi]
    tables[[length(tables) + 1L]] <- .render_html_table(
      panel_pages = panel_pages,
      meta = meta,
      cs = cs
    )
  }
  body_inner <- c(
    title_block,
    unlist(tables, use.names = FALSE),
    footnote_block
  )
  c(head, onscreen_header, body_inner, onscreen_footer, tail)
}

# Render a semantic HTML5 page band (`<header>` or `<footer>`) for
# on-screen display. Mirrors the three-slot left/center/right
# pattern the @page CSS rules already use, but produces real DOM
# nodes that browsers paint OUTSIDE of print context. Returns
# character(0) when the band is empty or `chrome_mode = "off"`.
#
# `{page}` and `{npages}` tokens are substituted statically here
# (page = 1 for the on-screen header, total_pages for {npages}) so
# the rendered text reads sensibly without CSS counter context.
# Multi-row slots stack vertically inside each slot div, matching
# the @page rule layout discipline.
.html_render_chrome_band <- function(
  band,
  zone,
  total_pages,
  chrome_mode
) {
  if (identical(chrome_mode, "off") || !.page_band_is_populated(band)) {
    return(character())
  }
  reverse <- identical(zone, "header")
  cls <- sprintf("tabular-page-%s", zone)
  tag <- if (identical(zone, "header")) "header" else "footer"
  c(
    sprintf("<%s class=\"%s\">", tag, cls),
    sprintf(
      "  <div class=\"%s-left\">%s</div>",
      cls,
      .html_chrome_slot_text(
        band$left,
        reverse = reverse,
        total_pages = total_pages
      )
    ),
    sprintf(
      "  <div class=\"%s-center\">%s</div>",
      cls,
      .html_chrome_slot_text(
        band$center,
        reverse = reverse,
        total_pages = total_pages
      )
    ),
    sprintf(
      "  <div class=\"%s-right\">%s</div>",
      cls,
      .html_chrome_slot_text(
        band$right,
        reverse = reverse,
        total_pages = total_pages
      )
    ),
    sprintf("</%s>", tag)
  )
}

# Flatten one band slot (list of N inline_asts, one per row) to
# an HTML fragment with rows joined by `<br>`. `{page}` /
# `{npages}` tokens resolve statically (page = 1, npages = total).
# `reverse = TRUE` flips row order to match the pagehead growth
# convention (index 1 = body edge -> visually closest to the table).
.html_chrome_slot_text <- function(slot_asts, reverse, total_pages) {
  if (length(slot_asts) == 0L) {
    return("")
  }
  order <- if (reverse) rev(seq_along(slot_asts)) else seq_along(slot_asts)
  parts <- vapply(
    order,
    function(i) {
      txt <- .html_band_row_content(slot_asts[[i]])
      # `.html_band_row_content` quotes its output for CSS `content:`
      # use (`"text"` with quotes / counter() calls). Unwrap for
      # plain-HTML emission.
      .html_chrome_unquote_band_text(txt, total_pages = total_pages)
    },
    character(1L)
  )
  parts[!nzchar(parts)] <- ""
  paste(parts, collapse = "<br>")
}

# Strip the CSS-quoting that `.html_band_row_content` applies for
# @page `content:` strings, leaving plain text suitable for DOM
# emission. Substitutes `counter(page)` / `counter(pages)` to
# static "1" and total-pages digits respectively (CSS counters
# don't fire outside @page context, so on-screen we render the
# best static approximation).
.html_chrome_unquote_band_text <- function(s, total_pages) {
  if (!is.character(s) || length(s) != 1L) {
    return("")
  }
  # `s` is the @page-style `content:` value: a sequence of
  # `"text"` literals and `counter(...)` calls joined by spaces.
  # Convert counter calls to static digits first, then convert
  # the CSS newline literal `"\\A"` to a <br>, then strip ALL
  # double-quote and inter-fragment spaces — the only quotes in
  # the source are the CSS delimiters around plain-text fragments
  # (any `"` inside the user's input was already &quot;-escaped by
  # `.html_band_row_content` -> `.html_escape`).
  s <- gsub("counter(page)", "1", s, fixed = TRUE)
  s <- gsub("counter(pages)", as.character(total_pages), s, fixed = TRUE)
  s <- gsub("\"\\A\"", "<br>", s, fixed = TRUE)
  # Collapse `" <fragment> "` -> `<fragment>` by removing the
  # CSS string delimiters and the single space that joins
  # adjacent CSS tokens.
  s <- gsub("\"", "", s, fixed = TRUE)
  # Collapse double spaces that fall out of the join.
  s <- gsub("  +", " ", s)
  trimws(s)
}

# Resolve the blank-line count for a chrome surface side. chrome_style
# wins when the user set `style(blank_above = N, at = cells_title())`;
# otherwise the legacy preset `*_pad_*` scalar fills in.
.html_blank_count <- function(cs, surface, side, legacy) {
  node <- .chrome_surface_at(cs, surface)
  prop <- if (identical(side, "above")) node@blank_above else node@blank_below
  if (length(prop) == 1L && !is.na(prop)) {
    return(max(0L, as.integer(prop)))
  }
  max(0L, as.integer(legacy))
}

# Render the run-level inline-style declarations from a chrome
# surface style_node. Returns a `style="..."` attribute fragment
# when any prop is set, else an empty string. Backends append this
# to the surface element's open tag (`<h1>`, `<p>`, `<th>` etc.).
.html_chrome_inline_style <- function(node) {
  if (!is_style_node(node)) {
    return("")
  }
  decls <- character()
  if (isTRUE(node@bold)) {
    decls <- c(decls, "font-weight: bold")
  }
  if (isTRUE(node@italic)) {
    decls <- c(decls, "font-style: italic")
  }
  if (isTRUE(node@underline)) {
    decls <- c(decls, "text-decoration: underline")
  }
  fs <- node@font_size
  if (length(fs) == 1L && !is.na(fs) && is.numeric(fs)) {
    decls <- c(decls, sprintf("font-size: %spt", format(fs, trim = TRUE)))
  }
  ff <- node@font_family
  if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
    decls <- c(decls, sprintf("font-family: %s", ff))
  }
  col <- node@color
  if (length(col) == 1L && !is.na(col) && nzchar(col)) {
    decls <- c(decls, sprintf("color: %s", col))
  }
  bg <- node@background
  if (length(bg) == 1L && !is.na(bg) && nzchar(bg)) {
    decls <- c(decls, sprintf("background-color: %s", bg))
  }
  if (length(decls) == 0L) {
    return("")
  }
  sprintf(" style=\"%s\"", paste(decls, collapse = "; "))
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line becomes an `<h1 class="tabular-
# title">`. Per-line horizontal alignment from
# `chrome_style$surfaces$title@halign` (scalar broadcasts; vector zips
# 1:1 then pads with last). Empty title list returns an empty
# character vector so the caller can skip the surrounding spacing.
.render_html_title_block <- function(titles_ast, preset = NULL, cs = NULL) {
  n <- length(titles_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  surface_style <- .html_chrome_inline_style(surface_node)
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
        .effective_title_halign(preset, line_index = i, n_lines = n)
      }
      cls <- "tabular-title"
      if (length(halign) == 1L && !is.na(halign)) {
        extra <- .html_align_class(halign)
        if (nzchar(extra)) {
          cls <- c(cls, extra)
        }
      }
      sprintf(
        "<h1 class=\"%s\"%s>%s</h1>",
        paste(cls, collapse = " "),
        surface_style,
        .render_html_inline(titles_ast[[i]])
      )
    },
    character(1L)
  )
}

# Footnote block: each footnote line becomes a `<p class="tabular-
# footnote">`. Per-line horizontal alignment from
# `chrome_style$surfaces$footer@halign` (scalar broadcasts; vector zips
# 1:1 then pads with last). Empty list returns an empty character
# vector. Footnote CSS baseline: text-align: left (browser default);
# emit override class only when the cascade differs.
.render_html_footnote_block <- function(
  footnotes_ast,
  preset = NULL,
  cs = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  surface_style <- .html_chrome_inline_style(surface_node)
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
        .effective_footnote_halign(
          preset,
          line_index = i,
          n_lines = n
        )
      }
      cls <- "tabular-footnote"
      if (length(halign) == 1L && !is.na(halign)) {
        extra <- .html_align_class(halign)
        if (nzchar(extra)) {
          cls <- c(cls, extra)
        }
      }
      sprintf(
        "<p class=\"%s\"%s>%s</p>",
        paste(cls, collapse = " "),
        surface_style,
        .render_html_inline(footnotes_ast[[i]])
      )
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Table assembly: <table> / <thead> / <tbody>
# ---------------------------------------------------------------------

# Assemble one panel's `<table>` block: one `<colgroup>` carrying
# engine-resolved column widths, one `<thead>` (header bands +
# column-labels row), one `<tbody>` whose rows concatenate every
# vertical page of the panel with `<tr class="tabular-page-break-
# row">` markers between vertical pages. The marker rows render as
# `display: none` on screen and as a hard `page-break-before` under
# `@media print` — browsers natively repeat `<thead>` across the
# resulting printed page breaks.
#
# `panel_pages` is a list of page records that share `col_indices`
# (every horizontal panel pins one column set; only row indices
# vary across vertical pages).
.render_html_table <- function(panel_pages, meta, cs = NULL) {
  preset <- meta$preset
  cols <- meta$cols %||% list()
  col_names_visible <- panel_pages[[1L]]$col_names
  ncols <- length(col_names_visible)
  col_specs <- lapply(col_names_visible, function(nm) cols[[nm]])

  out <- c(
    "<div class=\"tabular-table-wrap\">",
    .html_table_open_tag(col_specs, preset)
  )
  out <- c(out, .html_colgroup(col_names_visible, cols))
  thead <- .render_html_thead(
    headers = meta$headers,
    col_labels_ast = meta$col_labels_ast,
    col_names_visible = col_names_visible,
    cols = cols,
    preset = preset,
    cs = cs
  )
  out <- c(out, thead)

  # `<tbody>` body — walk panel pages, concat their row blocks
  # (subgroup banner if any, then data rows), insert an invisible
  # page-break marker between vertical pages.
  break_row <- sprintf(
    "<tr class=\"tabular-page-break-row\" aria-hidden=\"true\"><td colspan=\"%d\"></td></tr>",
    ncols
  )
  body_lines <- character()
  for (i in seq_along(panel_pages)) {
    if (i > 1L) {
      body_lines <- c(body_lines, break_row)
    }
    body_lines <- c(
      body_lines,
      .render_html_page_body_rows(
        page = panel_pages[[i]],
        col_names_visible = col_names_visible,
        col_specs = col_specs,
        preset = preset,
        cs = cs
      )
    )
  }
  out <- c(out, "<tbody>", body_lines, "</tbody>", "</table>", "</div>")
  out
}

# Render one page slice's body `<tr>` lines: an optional subgroup
# banner `<tr class="tabular-subgroup">` followed by one `<tr>` per
# data row. Returns character(0) when the page is empty.
.render_html_page_body_rows <- function(
  page,
  col_names_visible,
  col_specs,
  preset = NULL,
  cs = NULL
) {
  out <- character()
  banner_row <- .render_html_subgroup_banner_row(
    page$subgroup_line_ast,
    n_cols = length(col_names_visible),
    preset = preset,
    cs = cs
  )
  if (length(banner_row) > 0L) {
    out <- c(out, banner_row)
  }
  cells_text <- page$cells_text
  cells_style <- page$cells_style
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(out)
  }
  rows <- vapply(
    seq_len(nrow_data),
    function(i) {
      cells <- vapply(
        seq_along(col_names_visible),
        function(j) {
          text <- .html_escape_cell(cells_text[i, j])
          spec <- col_specs[[j]]
          sn <- .cell_style_at(cells_style, i, col_names_visible[[j]])
          halign <- .effective_body_halign(sn, spec, preset)
          valign <- .effective_body_valign(sn, spec, preset)
          class_attr <- .html_cell_class_attr(halign, valign)
          style_attr <- .html_cell_inline_style_attr(sn)
          paste0("<td", class_attr, style_attr, ">", text, "</td>")
        },
        character(1L)
      )
      paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    },
    character(1L)
  )
  c(out, rows)
}

# Compose the `<thead>` block: zero or more band rows (one per
# header-tree depth) plus the column-labels row.
.render_html_thead <- function(
  headers,
  col_labels_ast,
  col_names_visible,
  cols,
  preset = NULL,
  cs = NULL
) {
  out <- "<thead>"
  band_rows <- .render_html_header_bands(headers, col_names_visible, cs)
  out <- c(out, band_rows)
  out <- c(
    out,
    .render_html_col_labels_row(
      col_labels_ast,
      col_names_visible,
      cols,
      preset = preset,
      cs = cs
    )
  )
  c(out, "</thead>")
}

# Render multi-level header bands using real `colspan`. For each
# band-row depth we walk visible columns left-to-right and group
# contiguous runs sharing the same band label (or no band); each
# run emits one `<th colspan="N">`. Returns a character vector of
# zero or more rows (zero when no bands exist).
.render_html_header_bands <- function(headers, col_names_visible, cs = NULL) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "header")
  surface_style <- .html_chrome_inline_style(surface_node)
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
              "<th colspan=\"%d\" class=\"tabular-band\"%s>%s</th>",
              span,
              surface_style,
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
# alignment from the header cascade (col_spec@align / @valign
# > chrome_style$surfaces$header@halign / header_valign > baked
# defaults). Label pulled from `col_labels_ast`; falls back to
# the column name when the spec did not set a label.
.render_html_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols,
  preset = NULL,
  cs = NULL
) {
  surface_node <- .chrome_surface_at(cs, "header")
  surface_style <- .html_chrome_inline_style(surface_node)
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      label <- if (is.null(ast)) {
        .html_escape(nm)
      } else {
        .render_html_inline(ast)
      }
      col <- cols[[nm]]
      # col_spec wins over chrome surface for header halign (per-
      # column override); fall back to chrome surface, then preset.
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
      } else {
        .effective_header_valign(col, preset)
      }
      attr <- .html_cell_class_attr(halign, valign)
      paste0("<th", attr, surface_style, ">", label, "</th>")
    },
    character(1L)
  )
  paste0("<tr>", paste(cells, collapse = ""), "</tr>")
}

# Look up the style_node for cell (row_idx, col_name) on a
# `cells_style` list-matrix. Returns a default `style_node()` when
# the matrix is NULL (no style spec attached) or the column /
# row is missing. Defensive — the resolver helpers handle NA
# fields gracefully.
.cell_style_at <- function(cells_style, row_idx, col_name) {
  if (is.null(cells_style)) {
    return(style_node())
  }
  cn <- colnames(cells_style)
  if (is.null(cn) || !(col_name %in% cn)) {
    return(style_node())
  }
  if (row_idx < 1L || row_idx > nrow(cells_style)) {
    return(style_node())
  }
  sn <- cells_style[[row_idx, col_name]]
  if (!is_style_node(sn)) {
    return(style_node())
  }
  sn
}

# Render the subgroup banner `<tr>` — one bold cell spanning every
# visible column, aligned per `chrome_style$surfaces$subgroup@halign`
# (default centre). Returns character(0) when the page has no
# subgroup runtime so the caller can skip cleanly.
.render_html_subgroup_banner_row <- function(
  subgroup_line_ast,
  n_cols,
  preset = NULL,
  cs = NULL
) {
  if (
    is.null(subgroup_line_ast) ||
      !is_inline_ast(subgroup_line_ast) ||
      length(subgroup_line_ast@runs) == 0L
  ) {
    return(character())
  }
  inner <- .render_html_inline(subgroup_line_ast)
  surface_node <- .chrome_surface_at(cs, "subgroup")
  surface_style <- .html_chrome_inline_style(surface_node)
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    .effective_subgroup_halign(preset)
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
  attr <- .html_cell_class_attr(
    halign,
    valign,
    extra_classes = "tabular-subgroup-label"
  )
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "<strong>"
  }
  bold_close <- if (identical(bold_open, "")) "" else "</strong>"
  sprintf(
    paste0(
      "<tr class=\"tabular-subgroup\">",
      "<td colspan=\"%d\"%s%s>",
      "%s%s%s",
      "</td></tr>"
    ),
    n_cols,
    attr,
    surface_style,
    bold_open,
    inner,
    bold_close
  )
}

# Emit the opening `<table>` tag carrying width-mode-aware inline
# style. Reads `preset@width_mode` and the resolved column widths
# stored on each `col_spec@width` (engine-resolved inches via
# `.distribute_widths()` in R/col_width.R). Brings HTML into parity
# with the paginated backends — RTF / LaTeX / PDF / DOCX honour
# `width_mode` via the engine's distribution math; HTML now honours
# it at emit time so the on-screen preview matches what the
# paginated output will look like.
#
#   "content" / "fixed" -> style="width:<sum>in"
#   "window"            -> style="width:100%"
#
# Falls back to the bare `<table class="tabular-table">` when no
# visible column has a resolved numeric width (rare — only when a
# spec bypasses engine resolution). Keeps the document additive-
# only against the natural-fit fallback, mirroring `.html_colgroup`.
#
# No `table-layout: fixed` is emitted. The engine's AFM-measured
# widths slightly under-count the browser's rendered content width
# (CSS `.tabular-table` font-size is `.9rem` ≈ 10.8pt vs AFM at
# `preset@font_size` ≈ 10pt; CSS `padding: .35rem .6rem` ≈ 19pt
# total vs AFM's 12pt). Under `table-layout: fixed` that gap caused
# header / cell content to wrap inside too-narrow columns. With the
# default `table-layout: auto`, the engine widths become hints; the
# browser expands columns to fit content when needed. Any overflow
# is absorbed by `.tabular-table-wrap { overflow-x: auto; }`.
.html_table_open_tag <- function(col_specs, preset) {
  widths <- vapply(
    col_specs,
    function(cs) {
      w <- if (is_col_spec(cs)) cs@width else NA_real_
      if (is.numeric(w) && length(w) == 1L && !is.na(w)) {
        as.numeric(w)
      } else {
        NA_real_
      }
    },
    numeric(1L)
  )
  if (!any(!is.na(widths))) {
    return("<table class=\"tabular-table\">")
  }
  mode <- if (is.null(preset)) "content" else preset@width_mode
  style <- if (identical(mode, "window")) {
    "width:100%"
  } else {
    sprintf("width:%fin", sum(widths, na.rm = TRUE))
  }
  sprintf("<table class=\"tabular-table\" style=\"%s\">", style)
}

# Emit a `<colgroup>` block carrying the engine-resolved column
# widths. The engine writes numeric inches into every visible
# `col_spec@width` (auto / pct / dim string -> inches) so the HTML
# backend matches RTF (`\cellx`) and LaTeX (`Q[<a>,wd=...in]`)
# byte-for-byte on the resolved widths.
#
# A column with no resolved width (rare — only synthesised columns
# that bypassed engine resolution) emits a bare `<col/>` so the
# child count still equals the visible-column count for any CSS
# `nth-child` targeting. If no visible column has a numeric width
# at all, return character(0) — emit no `<colgroup>`, keeping the
# document additive-only against the natural-fit fallback.
.html_colgroup <- function(col_names_visible, cols) {
  widths <- vapply(
    col_names_visible,
    function(nm) {
      cs <- cols[[nm]]
      w <- if (is_col_spec(cs)) cs@width else NA_real_
      if (is.numeric(w) && length(w) == 1L && !is.na(w)) {
        as.numeric(w)
      } else {
        NA_real_
      }
    },
    numeric(1L)
  )
  if (!any(!is.na(widths))) {
    return(character())
  }
  cells <- vapply(
    widths,
    function(w) {
      if (is.na(w)) {
        "<col/>"
      } else {
        sprintf("<col style=\"width:%fin\"/>", w)
      }
    },
    character(1L)
  )
  c("<colgroup>", cells, "</colgroup>")
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

# Map a `valign` value to a CSS vertical-align class. Defaults to
# the empty string (inherit) when unset / NA so the browser applies
# the CSS default (baseline / `.tabular-table` `vertical-align: top`)
# without us emitting a redundant class.
.html_valign_class <- function(valign) {
  if (is.null(valign) || length(valign) == 0L || is.na(valign)) {
    return("")
  }
  switch(
    valign,
    top = "valign-top",
    middle = "valign-middle",
    bottom = "valign-bottom",
    ""
  )
}

# Map one resolved border triple to the CSS `border-<side>: ...`
# declaration text. `currentColor` is left as the CSS keyword so
# the cell inherits the surrounding text color; explicit colours
# pass through verbatim (hex or CSS name). `solid` / `dashed` /
# `dotted` / `double` map 1:1 to CSS; `dashdot` falls back to
# `dashed` (CSS has no native dash-dot stroke).
.html_border_decl <- function(side, brd) {
  if (is.null(brd) || identical(brd$style, "none")) {
    return(NULL)
  }
  css_style <- switch(
    brd$style,
    solid = "solid",
    dashed = "dashed",
    dotted = "dotted",
    double = "double",
    dashdot = "dashed",
    "solid"
  )
  sprintf("border-%s: %gpt %s %s;", side, brd$width, css_style, brd$color)
}

# Compose an inline `style="..."` fragment for one cell covering
# any explicit borders set on the cascade. Returns `""` when no
# side carries an override. Used in addition to the class attribute
# so the CSS baseline still drives non-overridden cells.
.html_cell_border_style_attr <- function(cell_style) {
  decls <- .html_cell_border_decls(cell_style)
  if (length(decls) == 0L) {
    return("")
  }
  sprintf(" style=\"%s\"", paste(decls, collapse = " "))
}

# Sub-helper: the CSS border declarations alone (no `style=`
# wrapper). Sits behind both the border-only and the combined inline-
# style attribute paths so callers can merge decls without re-
# parsing emitted attribute strings.
.html_cell_border_decls <- function(cell_style) {
  if (!is_style_node(cell_style)) {
    return(character())
  }
  decls <- character()
  for (side in c("top", "right", "bottom", "left")) {
    brd <- .effective_border(side, cell_style)
    if (is.null(brd)) {
      next
    }
    if (identical(brd$style, "none")) {
      # Explicit clear -> CSS `border-<side>: none` overrides any
      # inherited baseline so the user's intent wins over the
      # stylesheet's default rule.
      decls <- c(decls, sprintf("border-%s: none;", side))
      next
    }
    decl <- .html_border_decl(side, brd)
    if (!is.null(decl)) {
      decls <- c(decls, decl)
    }
  }
  decls
}

# CSS declarations for the seven text properties on a style_node:
# font_family, font_size, bold, italic, underline, color, background.
# Returns a character vector of `prop: value;` strings (zero or more);
# the empty case means the cascade carried no explicit text style for
# this cell.
.html_cell_text_decls <- function(cell_style) {
  if (!is_style_node(cell_style)) {
    return(character())
  }
  decls <- character()
  ff <- cell_style@font_family
  if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
    decls <- c(decls, sprintf("font-family: %s;", ff))
  }
  fs <- cell_style@font_size
  if (length(fs) == 1L && !is.na(fs) && is.numeric(fs)) {
    decls <- c(decls, sprintf("font-size: %spt;", format(fs, trim = TRUE)))
  }
  if (isTRUE(cell_style@bold)) {
    decls <- c(decls, "font-weight: bold;")
  }
  if (isTRUE(cell_style@italic)) {
    decls <- c(decls, "font-style: italic;")
  }
  if (isTRUE(cell_style@underline)) {
    decls <- c(decls, "text-decoration: underline;")
  }
  col <- cell_style@color
  if (length(col) == 1L && !is.na(col) && nzchar(col)) {
    decls <- c(decls, sprintf("color: %s;", col))
  }
  bg <- cell_style@background
  if (length(bg) == 1L && !is.na(bg) && nzchar(bg)) {
    decls <- c(decls, sprintf("background-color: %s;", bg))
  }
  pad <- cell_style@padding
  if (length(pad) == 1L && !is.na(pad)) {
    decls <- c(decls, sprintf("padding: %spt;", format(pad, trim = TRUE)))
  }
  decls
}

# Combined inline `style="..."` attribute: border decls + text decls
# in one attribute (HTML allows only one `style` attribute per
# element). Returns `""` when both subhelpers return empty so the
# rendered `<td>` stays minimal.
.html_cell_inline_style_attr <- function(cell_style) {
  decls <- c(
    .html_cell_border_decls(cell_style),
    .html_cell_text_decls(cell_style)
  )
  if (length(decls) == 0L) {
    return("")
  }
  sprintf(" style=\"%s\"", paste(decls, collapse = " "))
}

# Compose a combined `class="..."` attribute for one cell. Emits
# alignment classes only when the cascade resolver returned a
# non-NA value (i.e. some layer of style / col_spec / preset
# explicitly set the alignment); leaves the cell bare otherwise so
# the CSS stylesheet's per-surface baseline takes over. Extra
# `extra_classes` (e.g. "tabular-subgroup-label") are always
# included.
.html_cell_class_attr <- function(
  halign,
  valign,
  extra_classes = character()
) {
  classes <- extra_classes
  if (
    !is.null(halign) &&
      length(halign) == 1L &&
      !is.na(halign)
  ) {
    cls <- .html_align_class(halign)
    if (nzchar(cls)) {
      classes <- c(classes, cls)
    }
  }
  if (
    !is.null(valign) &&
      length(valign) == 1L &&
      !is.na(valign)
  ) {
    cls <- .html_valign_class(valign)
    if (nzchar(cls)) {
      classes <- c(classes, cls)
    }
  }
  classes <- classes[nzchar(classes)]
  if (length(classes) == 0L) {
    return("")
  }
  sprintf(" class=\"%s\"", paste(classes, collapse = " "))
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
#
# Page bands — when `pagehead_ast` / `pagefoot_ast` are populated,
# emit CSS `@page` margin-box rules so browsers that print to PDF
# (Chrome, Edge, Firefox) render the band per page with live
# `counter(page)` / `counter(pages)` substitution for `{page}` /
# `{npages}` tokens. Note: `@page` margin boxes are PRINT-ONLY —
# on-screen browser viewing does not render them. Inline AST
# formatting (bold / italic) is flattened to plain text since CSS
# `content` does not support inline tags.
.html_inline_style <- function(
  preset = NULL,
  pagehead_ast = NULL,
  pagefoot_ast = NULL
) {
  body_css <- c(
    sprintf(
      ".tabular-doc { font-family: %s; color: #212529; margin: 1.5rem; }",
      .html_font_family_css(preset)
    ),
    ".tabular-title { font-size: 1.1rem; font-weight: 600; text-align: center; margin: .2rem 0; }",
    # Wrapper around each `<table>` panel. The table's own inline
    # `width:<N>in` / `width:100%` rides on the `<table>` itself (see
    # `.html_table_open_tag()` in this file). The wrapper provides
    # the screen-only horizontal-scroll fallback when the viewport
    # is narrower than a content-fitted table, so the surrounding
    # chrome (titles, page bands, footnotes) stays at viewport width
    # while only the table scrolls. Print mode resets to
    # `overflow-x: visible` (further below) — paginated output has
    # paper geometry and never needs scroll behaviour.
    ".tabular-table-wrap { overflow-x: auto; margin: .75rem 0; }",
    # `margin: 0 auto` horizontally centres the content-fitted
    # table inside `.tabular-table-wrap` — without it, a block-
    # level `<table style="width:Nin">` sits flush-left even though
    # the title block above is centred. Under `width_mode = "window"`
    # the table is already 100% of the wrapper, so the auto margins
    # are no-ops; only the content-fitted modes benefit.
    ".tabular-table { border-collapse: collapse; font-size: .9rem; margin: 0 auto; }",
    ".tabular-table th, .tabular-table td { padding: .35rem .6rem; }",
    ".tabular-table td { text-align: left; vertical-align: top; }",
    ".tabular-table thead th { border-top: 1px solid #212529; border-bottom: 1px solid #212529; font-weight: 600; text-align: center; vertical-align: bottom; }",
    ".tabular-table thead tr:not(:last-child) th { border-bottom: 1px solid #adb5bd; }",
    ".tabular-table tbody tr td { border-top: none; }",
    ".tabular-table tbody tr:last-child td { border-bottom: 1px solid #212529; }",
    ".tabular-band { text-align: center; }",
    ".tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }",
    ".tabular-subgroup-label { font-weight: 600; }",
    ".text-left { text-align: left; }",
    ".text-center { text-align: center; }",
    ".text-right { text-align: right; }",
    ".valign-top { vertical-align: top; }",
    ".valign-middle { vertical-align: middle; }",
    ".valign-bottom { vertical-align: bottom; }",
    ".tabular-footnote { font-size: .85rem; color: #495057; margin: .25rem 0; }",
    ".tabular-empty { font-style: italic; color: #6c757d; }",
    # Print-only page-break marker `<tr>` — invisible on screen,
    # forces a hard page break under `@media print` so a single
    # `<table>` still paginates cleanly across printed pages.
    ".tabular-page-break-row { display: none; }",
    # On-screen chrome bands — semantic <header>/<footer> with
    # three flex slots; matches the @page margin-box layout for
    # visual parity between screen and print. Hidden in print so
    # the @page rules (further below) take over without duplicate
    # bands.
    ":root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }",
    ".tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: .85rem; color: var(--tabular-chrome-color); }",
    ".tabular-page-header { border-bottom: 1px solid var(--tabular-border-color-muted); margin-bottom: 1rem; }",
    ".tabular-page-footer { border-top:    1px solid var(--tabular-border-color-muted); margin-top:    1rem; }",
    ".tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }",
    ".tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }",
    ".tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }",
    "@media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }"
  )
  page_rules <- .html_render_page_band_rules(pagehead_ast, pagefoot_ast)
  # Per-cell colour / background / padding ride on cells_style[r,c]
  # now (set by `style(at = cells_body(), ...)` and the lowered
  # `preset(colors = ..., padding = ...)` knobs). They land as inline
  # `style="..."` attributes on each `<td>` via `.html_cell_style_attr()`,
  # so the table-wide CSS block has nothing to emit on their behalf —
  # the per-cell stamps already carry the visual.
  c("<style>", body_css, page_rules, "</style>")
}

# Render the CSS `@page { @top-* / @bottom-* }` margin-box rules
# from resolved page bands. Returns an empty character vector when
# both bands are empty (so the surrounding stylesheet stays
# unchanged for the common case). pagehead rows emit in REVERSE
# order (index 1 = body edge; visually closest to the table) so
# the rendered header reads bottom-up; pagefoot rows emit in
# FORWARD order so the rendered footer reads top-down.
.html_render_page_band_rules <- function(pagehead_ast, pagefoot_ast) {
  ph_pop <- .page_band_is_populated(pagehead_ast)
  pf_pop <- .page_band_is_populated(pagefoot_ast)
  if (!ph_pop && !pf_pop) {
    return(character())
  }
  rules <- character()
  if (ph_pop) {
    rules <- c(rules, .html_one_page_band_rules(pagehead_ast, zone = "top"))
  }
  if (pf_pop) {
    rules <- c(
      rules,
      .html_one_page_band_rules(pagefoot_ast, zone = "bottom")
    )
  }
  c("@page {", "  white-space: pre-line;", rules, "}")
}

# Render one band's three slot rules (@top-left / @top-center /
# @top-right OR @bottom-left / etc.). `zone` is "top" (pagehead)
# or "bottom" (pagefoot). Multi-row content collapses to a single
# `content:` string with `\A` (CSS newline escape) between rows;
# pagehead reverses index order so index 1 (body-edge) ends up
# last (closest to the body), pagefoot keeps index order so
# index 1 ends up first (closest to the body).
.html_one_page_band_rules <- function(band, zone) {
  reverse <- identical(zone, "top")
  c(
    sprintf(
      "  @%s-left { content: %s; }",
      zone,
      .html_band_slot_content(band$left, reverse = reverse)
    ),
    sprintf(
      "  @%s-center { content: %s; }",
      zone,
      .html_band_slot_content(band$center, reverse = reverse)
    ),
    sprintf(
      "  @%s-right { content: %s; }",
      zone,
      .html_band_slot_content(band$right, reverse = reverse)
    )
  )
}

# Compose the CSS `content:` value for one slot column (N rows
# stacked vertically). Each row's inline_ast is flattened to plain
# text; `{page}` and `{npages}` tokens become `counter(page)` /
# `counter(pages)` counter calls in the concatenation. Empty rows
# collapse to "". Multi-row content joins with `\A` (CSS escape for
# newline). When `reverse = TRUE`, the row order flips so the
# index-1 row ends up at the bottom of the band zone (matches the
# growth-direction contract for pageheaders).
.html_band_slot_content <- function(slot_asts, reverse) {
  if (length(slot_asts) == 0L) {
    return("\"\"")
  }
  order <- if (reverse) rev(seq_along(slot_asts)) else seq_along(slot_asts)
  parts <- vapply(
    order,
    function(i) .html_band_row_content(slot_asts[[i]]),
    character(1L)
  )
  # Sentinel "" for rows that flattened to nothing.
  parts[!nzchar(parts)] <- "\"\""
  if (length(parts) == 1L) {
    return(parts)
  }
  # Join rows with " \"\\A\" " — a CSS newline literal between
  # adjacent string fragments. Browsers with `white-space: pre-line`
  # turn that into a hard line break.
  paste(parts, collapse = " \"\\A\" ")
}

# Flatten one cell's inline_ast to a CSS content fragment string.
# Returns "" for an empty AST. `{page}` and `{npages}` plain-text
# runs split the string and splice in `counter(page)` /
# `counter(pages)` keywords (CSS concatenation: string + counter +
# string). Inline formatting (bold / italic) is flattened to plain
# text because CSS content does not accept tags.
.html_band_row_content <- function(ast) {
  if (!is_inline_ast(ast) || length(ast@runs) == 0L) {
    return("")
  }
  text <- .html_flatten_ast_to_text(ast)
  if (!nzchar(text)) {
    return("")
  }
  .html_content_with_page_counters(text)
}

# Walk an inline_ast and concatenate plain text, ignoring tag
# semantics. Newline runs become literal "\n" (so the CSS
# fragment writer can `\A`-split if it wants); other run types
# recurse through children.
.html_flatten_ast_to_text <- function(ast) {
  out <- character()
  walk <- function(runs) {
    for (r in runs) {
      type <- r$type
      if (identical(type, "plain")) {
        out[length(out) + 1L] <<- r$text %||% ""
      } else if (identical(type, "newline")) {
        out[length(out) + 1L] <<- "\n"
      } else if (identical(type, "link")) {
        # Render the link text, not the href (CSS content can't
        # carry hyperlinks anyway).
        walk(r$children %||% list())
      } else if (!is.null(r$children)) {
        walk(r$children)
      } else if (!is.null(r$text)) {
        out[length(out) + 1L] <<- r$text
      }
    }
  }
  walk(ast@runs)
  paste(out, collapse = "")
}

# Convert a flat text string into a CSS content concatenation,
# splitting on `{page}` and `{npages}` tokens and splicing in
# `counter(page)` / `counter(pages)` keywords. Returns a single
# string like `"Page " counter(page) " of " counter(pages)`.
.html_content_with_page_counters <- function(text) {
  parts <- character()
  remaining <- text
  pattern <- "\\{(page|npages)\\}"
  repeat {
    m <- regexpr(pattern, remaining, perl = TRUE)
    if (m == -1L) {
      if (nzchar(remaining)) {
        parts <- c(parts, .html_css_quote(remaining))
      }
      break
    }
    start <- as.integer(m)
    len <- attr(m, "match.length")
    before <- substr(remaining, 1L, start - 1L)
    token <- substr(remaining, start, start + len - 1L)
    if (nzchar(before)) {
      parts <- c(parts, .html_css_quote(before))
    }
    parts <- c(
      parts,
      if (token == "{page}") "counter(page)" else "counter(pages)"
    )
    remaining <- substr(remaining, start + len, nchar(remaining))
  }
  if (length(parts) == 0L) {
    return("\"\"")
  }
  paste(parts, collapse = " ")
}

# Escape a literal string for safe insertion as a CSS `content`
# quoted-string. Doubles backslashes and quotes; newlines become
# `\A` escapes; control characters use the `\NN ` form. Wraps the
# whole thing in double quotes.
.html_css_quote <- function(text) {
  text <- gsub("\\", "\\\\", text, fixed = TRUE)
  text <- gsub("\"", "\\\"", text, fixed = TRUE)
  text <- gsub("\n", "\\A ", text, fixed = TRUE)
  paste0("\"", text, "\"")
}

# Compose the CSS `font-family` value from the spec's preset.
# Routes through `.resolve_font_stack` (R/fonts.R) so the chain
# logic (generic family / single name / explicit stack) is
# shared with every other backend.
.html_font_family_css <- function(preset) {
  fam <- .effective_font_family(preset)
  chain <- .resolve_font_stack(fam, "html")
  paste(vapply(chain, .html_quote_font, character(1L)), collapse = ", ")
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("html", backend_html)
