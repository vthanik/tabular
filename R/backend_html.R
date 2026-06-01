# backend_html.R — HTML backend. Consumes a resolved
# `tabular_grid` and writes a self-contained UTF-8 .html file
# whose visual style mirrors a Bootstrap-5-light table (no CDN
# dependency — the minimum CSS is inlined inside a `<style>`
# block so the file renders identically online, offline, in
# email, and in `file://` previews).
#
# Output layout — one continuous document. Titles emit as
# `<h1 class="tabular-title">` above the table (once). HTML is a
# continuous, scrollable medium with no page width, so a
# `paginate(panels = N)` request never splits: the engine collapses
# it to ONE `<table class="tabular-table">` (all columns, original
# order, stub once), and the would-be panel boundaries surface as a
# `<th class="tabular-panel-note">` spanner row at the top of the
# `<thead>` (`.render_html_panel_note_row`). The table carries one
# `<colgroup>`, one `<thead>` (optional panel-note row + multi-row
# band stack + column-labels row), and one `<tbody>` whose rows
# concatenate every vertical page slice. Between vertical pages, an
# invisible `<tr class="tabular-page-break-row">` rides in the
# `<tbody>` — `display: none` on screen, `page-break-before: always`
# under `@media print`. Browsers natively repeat `<thead>` across
# printed page breaks of a single `<table>`, so no per-page header
# plumbing is needed. Footnotes emit as `<p class="tabular-footnote">`
# once below the table. The `@media print` rule on `.tabular-table +
# .tabular-table` is now dead for the common single-table case (kept;
# harmless adjacent-sibling selector with no match).
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
  # HTML is continuous (no separate footnote section), so it folds
  # `footnoterule` into the `bottomrule`: whichever is active becomes
  # the table's bottom edge. bottomrule wins; when it is off and
  # footnoterule is on, footnoterule supplies the bottom rule so a
  # closing rule still appears.
  body_borders <- meta$body_borders %||% list()
  .bottom <- body_borders[["outer_bottom"]]
  .foot <- .chrome_border_at(cs, "footer_top")
  if (
    (is.null(.bottom) || identical(.bottom$style, "none")) &&
      !is.null(.foot) &&
      !identical(.foot$style, "none")
  ) {
    body_borders[["outer_bottom"]] <- .foot
    # Stamp the folded rule onto the last data row's cells so the
    # per-cell inline border agrees with the `tbody tr:last-child` CSS
    # rule; otherwise the `bottomrule = "none"` clear leaves inline
    # `border-bottom: none`, and inline specificity defeats the fold.
    pages <- .html_stamp_last_row_bottom(pages, .foot)
  }

  head <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    paste0("<title>", .html_escape(doc_title), "</title>"),
    .html_inline_style(
      preset = meta$preset,
      pagehead_ast = meta$pagehead_ast,
      pagefoot_ast = meta$pagefoot_ast,
      cs = cs,
      body_borders = body_borders
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
    chrome_mode = chrome_mode,
    cs = cs
  )
  onscreen_footer <- .html_render_chrome_band(
    meta$pagefoot_ast,
    zone = "footer",
    total_pages = total_for_chrome,
    chrome_mode = chrome_mode,
    cs = cs
  )

  # Title block — emitted once above the table, with optional
  # blank-paragraph padding from `chrome_style$surfaces$title`
  # (blank_above / blank_below).
  blank_p <- "<p class=\"tabular-pad\">&nbsp;</p>"
  pad_title_top <- .html_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_bottom <- .html_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )
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
  # Blank line(s) above the footnotes: the footer surface's
  # `blank_above` (via `style(.at = cells_footnotes())`) wins, else the
  # `body_to_footnote` spacing gap. Stands in for the bottomrule when
  # `preset_minimal()` drops it.
  if (length(footnote_block) > 0L) {
    foot_blank_above <- .html_blank_count(
      cs,
      "footer",
      "above",
      .meta_gap(meta, "body_to_footnote", 0L)
    )
    footnote_block <- c(rep(blank_p, foot_blank_above), footnote_block)
  }

  # `.tabular-content` wraps title + tables + footnotes in one
  # centred container sized to the widest table (`width:
  # fit-content`). Title text centres above; footnote sits flush
  # to the table's left edge. The `--window` BEM modifier flips
  # the wrapper to full width so `width_mode = "window"` tables
  # fill the viewport. The CSS rules live in `.html_inline_style()`.
  # HTML is unconditionally responsive: the content wrapper
  # always fills its parent (viewer pane / browser viewport /
  # Quarto chunk / Shiny UI cell) via the base `.tabular-content`
  # rule (`width: 100%`). No `--window` modifier; no `width_mode`
  # branch; one code path regardless of `col_spec(width)` units.
  content_open <- "<div class=\"tabular-content\">"

  if (total == 0L) {
    body_inner <- c(
      content_open,
      title_block,
      "<p class=\"tabular-empty\">(no rows)</p>",
      footnote_block,
      "</div>"
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
    content_open,
    title_block,
    unlist(tables, use.names = FALSE),
    footnote_block,
    "</div>"
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
  chrome_mode,
  cs = NULL
) {
  if (identical(chrome_mode, "off") || !.page_band_is_populated(band)) {
    return(character())
  }
  reverse <- identical(zone, "header")
  cls <- sprintf("tabular-page-%s", zone)
  tag <- if (identical(zone, "header")) "header" else "footer"
  surface <- if (identical(zone, "header")) "pagehead" else "pagefoot"
  region <- if (identical(zone, "header")) {
    "pagehead_bottom"
  } else {
    "pagefoot_top"
  }
  band_edge <- if (identical(zone, "header")) "bottom" else "top"
  # Emit a slot <div> only when that slot is populated, so a band with
  # only `left` + `right` set splits 50/50 (justify-content:
  # space-between) instead of reserving a blank centre third that wraps
  # the left content (Thread E). Per-slot alignment classes
  # (`-left/-center/-right`) are kept. Each populated slot also carries
  # its own text-prop style from `cells_pagehead(slot = ...)` (Thread G).
  slot_divs <- character()
  for (slot_name in .page_band_slots) {
    slot_asts <- band[[slot_name]]
    if (!.page_band_slot_populated(slot_asts)) {
      next
    }
    slot_style <- .html_chrome_inline_style(
      .chrome_surface_at_slot(cs, surface, slot = slot_name)
    )
    slot_divs <- c(
      slot_divs,
      sprintf(
        "  <div class=\"%s-%s\"%s>%s</div>",
        cls,
        slot_name,
        slot_style,
        .html_chrome_slot_text(
          slot_asts,
          reverse = reverse,
          total_pages = total_pages
        )
      )
    )
  }
  # Band rule: `style(border_bottom = brdr(), .at = cells_pagehead())`
  # (or `border_top` on the footer) draws a rule under the page header /
  # above the page footer, from the chrome border region (Thread G). Off
  # by default (galley parity), so the default band stays borderless.
  band_border <- .html_border_decl(band_edge, .chrome_border_at(cs, region))
  band_style <- if (is.null(band_border)) {
    ""
  } else {
    sprintf(" style=\"%s\"", band_border)
  }
  c(
    sprintf("<%s class=\"%s\"%s>", tag, cls, band_style),
    slot_divs,
    sprintf("</%s>", tag)
  )
}

# Render one band slot (list of N inline_asts, one per row) to an HTML
# fragment with rows joined by `<br>`. Each row's AST is rendered with
# the full inline renderer, so `md()` / `html()` markup (bold, italic,
# sup / sub, code, raw HTML) survives in the on-screen DOM band (Thread
# F). `{page}` / `{npages}` tokens resolve statically (page = 1, npages =
# total). `reverse = TRUE` flips row order to match the pagehead growth
# convention (index 1 = body edge -> visually closest to the table). The
# `@page { content: }` CSS print fragment keeps the flat
# `.html_band_row_content()` path (CSS content strings can't hold markup).
.html_chrome_slot_text <- function(slot_asts, reverse, total_pages) {
  if (length(slot_asts) == 0L) {
    return("")
  }
  order <- if (reverse) rev(seq_along(slot_asts)) else seq_along(slot_asts)
  parts <- vapply(
    order,
    function(i) {
      .html_render_slot_ast_with_tokens(
        slot_asts[[i]],
        total_pages = total_pages
      )
    },
    character(1L)
  )
  parts[!nzchar(parts)] <- ""
  paste(parts, collapse = "<br>")
}

# Render one slot-row AST to rich HTML (preserving md()/html() markup),
# then substitute the static `{page}` / `{npages}` tokens AFTER rendering
# so any markup wrapping the token survives (e.g. `md("Page **{page}**")`
# -> `Page <strong>1</strong>`). On-screen DOM path only.
.html_render_slot_ast_with_tokens <- function(ast, total_pages) {
  if (!is_inline_ast(ast) || length(ast@runs) == 0L) {
    return("")
  }
  html <- .render_html_inline(ast)
  if (!nzchar(html)) {
    return("")
  }
  html <- gsub("{page}", "1", html, fixed = TRUE)
  gsub("{npages}", as.character(total_pages), html, fixed = TRUE)
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
  # Emit an explicit weight whenever the user set bold either way, so it
  # overrides the class-level default (`.tabular-title` etc. carry
  # `font-weight: 600`). An unset (`NA`) bold emits nothing and inherits
  # the class default.
  if (isTRUE(node@bold)) {
    decls <- c(decls, "font-weight: bold")
  } else if (isFALSE(node@bold)) {
    decls <- c(decls, "font-weight: normal")
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
  # Per-side padding overrides (e.g. `preset(padding = list(header =
  # c(top = 6, bottom = 6)))`). Emit only the sides explicitly set; unset
  # sides inherit the `.tabular-table td/th` baseline. This is the one
  # shared chrome helper, so completing it here fixes header / title /
  # footnote / subgroup / group-header padding in a single place.
  for (side in c("top", "right", "bottom", "left")) {
    pad <- S7::prop(node, paste0("padding_", side))
    if (length(pad) == 1L && !is.na(pad)) {
      decls <- c(
        decls,
        sprintf("padding-%s: %spt", side, format(pad, trim = TRUE))
      )
    }
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
    cs = cs,
    panel_spans = meta$panel_spans
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
  # Per-cell indent depth comes from the engine sidecar -- both
  # `indent_by` and `usage = "indent"` contribute additively. Default
  # to a zero matrix so fixtures that bypass the engine (older tests,
  # ad-hoc page synthesis) still work.
  cells_indent <- page$cells_indent %||%
    matrix(
      0L,
      nrow = nrow_data,
      ncol = length(col_names_visible),
      dimnames = list(NULL, col_names_visible)
    )
  # One indent level = N space-widths of the active body font, in CSS
  # `em` units. `.indent_em_per_level()` is the single source of truth
  # (R/font_metrics.R) -- the leading-space strip below uses the same
  # `indent_size` to recover N for trimming the engine-baked prefix.
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_em_per_level <- .indent_em_per_level(preset)
  # Synthesised section-header rows + blank-gap rows from the engine
  # `group_display = "header_row"` plan. The host column carries the
  # group value; other cells are blank. Render as a single colspan'd
  # cell so the header band reads as a unit, not a row of empty cells.
  is_header_row <- page$is_header_row %||% rep(FALSE, nrow_data)
  is_blank_row <- page$is_blank_row %||% rep(FALSE, nrow_data)
  ncols_vis <- length(col_names_visible)
  rows <- vapply(
    seq_len(nrow_data),
    function(i) {
      if (isTRUE(is_blank_row[[i]])) {
        # The blank separator carries a resolved style_node too (the
        # stripe fill, stamped uniformly across the row). Emit its
        # background so the zebra band stays continuous across the gap
        # instead of leaving a white stripe.
        blank_node <- if (!is.null(page$cells_style)) {
          page$cells_style[[i, 1L]]
        } else {
          NULL
        }
        return(sprintf(
          "<tr class=\"tabular-blank-row\"><td colspan=\"%d\"%s>&nbsp;</td></tr>",
          ncols_vis,
          .html_chrome_inline_style(blank_node)
        ))
      }
      if (isTRUE(is_header_row[[i]])) {
        # The engine placed the group value in the host column; every
        # other cell is blank. Pull the first non-empty cell as the
        # header text — robust whether the host column ships verbatim
        # or with the dimname-attribute quirk. Track the cell's
        # column index so we can read the per-band depth from
        # cells_indent[i, host_idx] (band-2 header sits one level
        # indented under band-1 etc.).
        host_text <- ""
        host_idx <- NA_integer_
        for (jj in seq_along(col_names_visible)) {
          val <- cells_text[i, jj]
          if (!is.na(val) && nzchar(val)) {
            host_text <- val
            host_idx <- jj
            break
          }
        }
        # Group-header weight + text props come from the host cell's
        # resolved style_node (stamped by `.stamp_group_headers()`):
        # NA bold == bold (keep `<strong>`), `isFALSE` == off (drop
        # `<strong>` and emit `font-weight: normal`, which beats the
        # `.tabular-group-header td { 600 }` class). The chrome inline
        # decls (`.html_chrome_inline_style`, the subgroup-banner helper)
        # are merged with the band-depth padding into one `style=`.
        host_node <- if (!is.null(page$cells_style) && !is.na(host_idx)) {
          page$cells_style[[i, host_idx]]
        } else {
          NULL
        }
        is_bold <- !(is_style_node(host_node) && isFALSE(host_node@bold))
        decls <- character()
        if (!is.na(host_idx)) {
          header_depth <- cells_indent[i, host_idx]
          if (isTRUE(header_depth > 0L) && indent_em_per_level > 0) {
            decls <- c(
              decls,
              sprintf(
                "padding-left: calc(.6rem + %gem)",
                indent_em_per_level * header_depth
              )
            )
          }
        }
        chrome_frag <- .html_chrome_inline_style(host_node)
        if (nzchar(chrome_frag)) {
          decls <- c(decls, sub('^ style="(.*)"$', "\\1", chrome_frag))
        }
        header_style <- if (length(decls) > 0L) {
          sprintf(" style=\"%s\"", paste(decls, collapse = "; "))
        } else {
          ""
        }
        inner <- if (is_bold) {
          paste0("<strong>", .html_escape_cell(host_text), "</strong>")
        } else {
          .html_escape_cell(host_text)
        }
        return(sprintf(
          "<tr class=\"tabular-group-header\"><td colspan=\"%d\"%s>%s</td></tr>",
          ncols_vis,
          header_style,
          inner
        ))
      }
      cells <- vapply(
        seq_along(col_names_visible),
        function(j) {
          raw <- cells_text[i, j]
          spec <- col_specs[[j]]
          # Read per-cell depth from the engine sidecar. Browsers
          # collapse runs of whitespace inside `<td>`, so re-express
          # the engine-baked indent as CSS `padding-left` and strip
          # the leading spaces from the cell text.
          depth <- cells_indent[i, j]
          indent_decl <- NULL
          if (
            isTRUE(depth > 0L) &&
              indent_unit > 0L &&
              !is.na(raw)
          ) {
            n_leading <- indent_unit * depth
            # Strip the engine's leading-space prefix iff present.
            # `startsWith()` ignores attributes (matrix `[i, j]` access
            # carries the column dimname onto the scalar, which would
            # spuriously break `identical()`).
            if (
              nchar(raw) >= n_leading &&
                startsWith(raw, strrep(" ", n_leading))
            ) {
              raw <- substr(raw, n_leading + 1L, nchar(raw))
            }
            # ADDITIVE over the baseline `.tabular-table td
            # { padding: .35rem .6rem }` left slot via CSS `calc()`
            # -- a bare `padding-left: Xem` would REPLACE the .6rem
            # baseline. `calc(.6rem + Xem)` puts the indent ON TOP.
            # `%g` trims trailing zeros (1.2 stays 1.2). Caveat: the
            # .6rem literal mirrors the value in `.html_inline_style()`;
            # keep in sync.
            indent_decl <- sprintf(
              "padding-left: calc(.6rem + %gem);",
              indent_em_per_level * depth
            )
          }
          text <- .html_escape_cell(raw)
          sn <- .cell_style_at(cells_style, i, col_names_visible[[j]])
          halign <- .effective_body_halign(sn, spec, preset)
          valign <- .effective_body_valign(sn, spec, preset)
          class_attr <- .html_cell_class_attr(halign, valign)
          style_attr <- .html_cell_inline_style_attr(
            sn,
            extra_decls = indent_decl
          )
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
  cs = NULL,
  panel_spans = NULL
) {
  out <- "<thead>"
  # Panel-spanner note (continuous backends, multi-panel only): one cell
  # per panel over its data columns, blank over the stub. Sits ABOVE the
  # user header bands. character(0) for single-panel / non-continuous.
  out <- c(
    out,
    .render_html_panel_note_row(panel_spans, col_names_visible, cs)
  )
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

# Render the panel-spanner note row for a collapsed continuous table.
# `panel_spans` (from the engine) lists each would-be panel's non-stub
# columns; we paint "Panel i" over those columns and leave the stub
# columns blank, then collapse to `<th colspan>` runs exactly like
# `.render_html_header_bands`. Returns character(0) when `panel_spans`
# is NULL/empty (single-panel or non-continuous render), so the
# `<thead>` is byte-identical to today in the common case.
.render_html_panel_note_row <- function(
  panel_spans,
  col_names_visible,
  cs = NULL
) {
  if (is.null(panel_spans) || length(panel_spans) == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "header")
  surface_style <- .html_chrome_inline_style(surface_node)
  labels <- rep(NA_character_, length(col_names_visible))
  for (span in panel_spans) {
    pos <- match(span$col_names, col_names_visible)
    pos <- pos[!is.na(pos)]
    labels[pos] <- span$label
  }
  runs <- .group_contiguous_runs(labels)
  cells <- vapply(
    runs,
    function(run) {
      lbl <- run$value
      span <- run$length
      if (is.na(lbl)) {
        sprintf("<th colspan=\"%d\"%s></th>", span, surface_style)
      } else {
        sprintf(
          "<th colspan=\"%d\" class=\"tabular-band tabular-panel-note\"%s>%s</th>",
          span,
          surface_style,
          .html_escape(lbl)
        )
      }
    },
    character(1L)
  )
  paste0("<tr>", paste(cells, collapse = ""), "</tr>")
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
      labels <- .band_labels_for_depth(headers, d, col_names_visible)
      runs <- .group_contiguous_runs(labels)
      cells <- vapply(
        runs,
        function(run) {
          lbl <- run$value
          span <- run$length
          if (is.na(lbl)) {
            # Empty flanking cell over unmapped columns: it must carry the
            # header surface style (background) too, so a coloured band
            # reads end-to-end instead of leaving white flanks.
            sprintf("<th colspan=\"%d\"%s></th>", span, surface_style)
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
      # `decimal` is the ONE carve-out: body cells render
      # `text-right` with engine_decimal NBSP padding that aligns
      # decimal points across rows, so the visible content's
      # centre of mass sits INSIDE the cell (at the decimal point),
      # not flush against the cell border. A CENTERED header sits
      # over that centroid -- the dominant clinical-TFL convention
      # and gt's default for numeric columns. Other body alignments
      # (left / center / right) map straight through to the same
      # value on the header.
      halign <- if (
        is_col_spec(col) &&
          length(col@align) == 1L &&
          !is.na(col@align)
      ) {
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
  # `style(border_*, .at = cells_subgroup_labels())` lowers to the chrome
  # subgroup_top / subgroup_bottom regions (RTF reads these); fold their
  # decls into the banner cell's inline style.
  border_decls <- c(
    .html_border_decl("top", .chrome_border_at(cs, "subgroup_top")),
    .html_border_decl("bottom", .chrome_border_at(cs, "subgroup_bottom"))
  )
  if (length(border_decls) > 0L) {
    border_str <- paste(border_decls, collapse = " ")
    surface_style <- if (nzchar(surface_style)) {
      sub("\"$", paste0("; ", border_str, "\""), surface_style)
    } else {
      sprintf(" style=\"%s\"", border_str)
    }
  }
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
  # HTML is unconditionally responsive: table always fills 100% of
  # its wrapper, regardless of `col_spec(width)` units or
  # `preset@width_mode`. Per-column widths (when the user set
  # them) ship in `<colgroup>` via `.html_colgroup()`; the table
  # itself never carries an inch-based width style. Width is the
  # viewport's concern, not paper's. `col_specs` and `preset` are
  # ignored here -- kept on the signature for call-site stability.
  "<table class=\"tabular-table\" style=\"width:100%\">"
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
  if (length(col_names_visible) == 0L) {
    return(character())
  }
  # gt convention: emit whatever the user supplied via
  # `col_spec(width = ...)` verbatim. Read `col@width_user` (the
  # immutable mirror of the constructor input), not `col@width`
  # (which `.resolve_col_widths()` overwrites with inch-resolved
  # numeric for paper backends). CSS accepts every dimension unit
  # natively (px / % / in / em / pt / cm / mm); the browser
  # parses, the package doesn't validate.
  cells <- vapply(
    col_names_visible,
    function(nm) {
      .html_col_tag(cols[[nm]])
    },
    character(1L)
  )
  # When the user wrote no widths at all, every cell is `<col/>`
  # and we suppress the whole `<colgroup>` to keep the document
  # bare -- the browser auto-sizes from cell content (gt's
  # default responsive behaviour).
  if (all(cells == "<col/>")) {
    return(character())
  }
  c("<colgroup>", cells, "</colgroup>")
}

# Format one `<col>` tag from a `col_spec` per gt's emit
# convention. Reads `width_user` (the immutable user-supplied
# spec); auto / NA / unknown yield bare `<col/>` so the browser
# auto-sizes. Mirrors gt's `validate_css_lengths()` pass-through
# at `inst/gt/utils_render_html.R::create_columns_component_h`.
.html_col_tag <- function(cs) {
  if (!is_col_spec(cs)) {
    return("<col/>")
  }
  uw <- cs@width_user
  if (length(uw) != 1L) {
    return("<col/>")
  }
  if (is.numeric(uw)) {
    if (is.na(uw)) {
      return("<col/>")
    }
    # Bare numeric -> inches (matches `.parse_dim()` default).
    return(sprintf("<col style=\"width:%fin\"/>", uw))
  }
  if (
    is.character(uw) &&
      !is.na(uw) &&
      nzchar(uw) &&
      !identical(uw, "auto")
  ) {
    return(sprintf("<col style=\"width:%s\"/>", uw))
  }
  "<col/>"
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

# `.tabular-table th/td` padding CSS. The default `cell_padding` keeps the
# responsive rem-based padding (comfortable on screen and the baseline the
# indent `calc(.6rem + ...)` builds on); an explicit `preset(cell_padding
# = ...)` override emits the four sides in pt so the knob reaches HTML like
# the paged backends. Compared against the factory default so the common
# case is byte-unchanged.
.html_cell_padding_css <- function(preset) {
  rem_default <- ".tabular-table th, .tabular-table td { padding: .35rem .6rem; }"
  if (!is_preset_spec(preset)) {
    return(rem_default)
  }
  cp <- as.numeric(preset@cell_padding)
  default_cp <- as.numeric(preset_spec()@cell_padding)
  if (length(cp) == length(default_cp) && isTRUE(all.equal(cp, default_cp))) {
    return(rem_default)
  }
  s <- .cell_padding_sides(preset)
  sprintf(
    ".tabular-table th, .tabular-table td { padding: %gpt %gpt %gpt %gpt; }",
    s[["top"]],
    s[["right"]],
    s[["bottom"]],
    s[["left"]]
  )
}

# Build one structural CSS rule (`<selector> { border-<side>: ... }`)
# from a resolved border triple, or NULL when the rule is off
# (NULL / style "none"). Drives the thead toprule / midrule / spanrule
# and the body bottomrule from the SSOT instead of hardcoded literals,
# so `preset(rules = ...)` overrides (including the "none" clear) take
# effect on the HTML backend.
.html_structural_rule <- function(selector, side, triple) {
  decl <- .html_border_decl(side, triple)
  if (is.null(decl)) {
    return(NULL)
  }
  sprintf("%s { %s }", selector, decl)
}

# Stamp `triple` as the bottom border of every cell in the LAST data
# row of the LAST page. Used by the HTML footnoterule -> bottomrule
# fold: when `bottomrule = "none"` clears the per-cell bottom border,
# the cells emit inline `border-bottom: none`, which (inline > class
# specificity) would defeat the folded `tbody tr:last-child` CSS rule.
# Overwriting the per-cell bottom with the folded triple makes inline
# and CSS agree, so the rule renders full width.
.html_stamp_last_row_bottom <- function(pages, triple) {
  if (length(pages) == 0L) {
    return(pages)
  }
  li <- length(pages)
  mat <- pages[[li]]$cells_style
  if (is.null(mat) || nrow(mat) == 0L || ncol(mat) == 0L) {
    return(pages)
  }
  r <- nrow(mat)
  for (cn in colnames(mat)) {
    sn <- mat[[r, cn]]
    if (!is_style_node(sn)) {
      sn <- style_node()
    }
    sn <- S7::set_props(
      sn,
      border_bottom_style = triple$style,
      border_bottom_width = triple$width,
      border_bottom_color = triple$color
    )
    mat[[r, cn]] <- sn
  }
  pages[[li]]$cells_style <- mat
  pages
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
  # Per-side padding overrides. Emit only the sides explicitly set;
  # unset sides inherit the table-level `.tabular-table td` baseline.
  for (side in c("top", "right", "bottom", "left")) {
    pad <- S7::prop(cell_style, paste0("padding_", side))
    if (length(pad) == 1L && !is.na(pad)) {
      decls <- c(
        decls,
        sprintf("padding-%s: %spt;", side, format(pad, trim = TRUE))
      )
    }
  }
  decls
}

# Combined inline `style="..."` attribute: border decls + text decls
# in one attribute (HTML allows only one `style` attribute per
# element). Returns `""` when both subhelpers return empty so the
# rendered `<td>` stays minimal.
.html_cell_inline_style_attr <- function(cell_style, extra_decls = NULL) {
  decls <- c(
    extra_decls,
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
  pagefoot_ast = NULL,
  cs = NULL,
  body_borders = NULL
) {
  cs <- cs %||% chrome_style()
  # Structural rules driven from the SSOT (chrome_style + the body
  # bottomrule manifest) rather than hardcoded `1px solid #212529`.
  # An off rule (NULL / "none") drops out, so `rules = list(... = "none")`
  # clears the rule here too. `header_between` carries the muted spanrule.
  structural_rules <- c(
    .html_structural_rule(
      ".tabular-table thead tr:first-child th",
      "top",
      # The outer-frame top rides the table top = the column-header band's
      # top rule, so `style(.at = cells_table(side = "outer"))` thickens the
      # true top edge. Falls back to the chrome `header_top` rule when no
      # outer frame is set.
      (if (is.list(body_borders)) body_borders[["outer_top"]] else NULL) %||%
        .chrome_border_at(cs, "header_top")
    ),
    .html_structural_rule(
      ".tabular-table thead tr:last-child th",
      "bottom",
      .chrome_border_at(cs, "header_bottom")
    ),
    .html_structural_rule(
      ".tabular-table thead .tabular-band",
      "bottom",
      .chrome_border_at(cs, "header_between")
    ),
    .html_structural_rule(
      ".tabular-table tbody tr:last-child td",
      "bottom",
      if (is.list(body_borders)) body_borders[["outer_bottom"]] else NULL
    ),
    # Outer LEFT / RIGHT frame edges ride the table element itself. Under
    # `border-collapse: collapse` a table border spans <thead> + every
    # <tbody> row and beats a conflicting cell `border: none`, so the
    # vertical edge is continuous over the spanner band, the column-label
    # row, and every body row including the synthesised blank-separator
    # and group-header rows (the original `rules = "frame"` gap). Titles
    # are <h1> outside <table>, so they stay outside the box.
    .html_structural_rule(
      ".tabular-table",
      "left",
      if (is.list(body_borders)) body_borders[["outer_left"]] else NULL
    ),
    .html_structural_rule(
      ".tabular-table",
      "right",
      if (is.list(body_borders)) body_borders[["outer_right"]] else NULL
    )
  )
  # `fs` drives every font-size emitted in pt below — title,
  # table, footnote. Sourcing the size from one local keeps the
  # three rules trivially in sync and lets `preset(font_size = N)`
  # cascade across the whole document. The NULL-preset fallback
  # reads the factory default from the SSOT so it never drifts from
  # `preset_spec@font_size` (`R/aaa_class.R`).
  fs <- .effective_font_size(preset)

  body_css <- c(
    sprintf(
      ".tabular-doc { font-family: %s; color: #212529; margin: 1.5rem; }",
      .html_font_family_css(preset)
    ),
    # `.tabular-content` wraps title + tables + footnote in one
    # full-width container that always fills its parent (viewer
    # pane / browser viewport / Quarto chunk / Shiny UI cell).
    # The inner `<table style="width:100%">` (from
    # `.html_table_open_tag()`) fills the wrapper; per-column
    # `<col style="width:X">` widths flow through verbatim per
    # the gt convention. HTML is unconditionally responsive --
    # no `--window` modifier, no `width_mode` branch.
    ".tabular-content { width: 100%; }",
    sprintf(
      ".tabular-title { font-size: %gpt; font-weight: 600; text-align: center; margin: .2rem 0; }",
      fs
    ),
    # `<p class="tabular-pad">&nbsp;</p>` spacers around the title
    # block carry only one line of preset-driven line-height. Zero
    # the browser-default `<p>` margin (16px 0) so each pad collapses
    # to exactly the blank-line count set in
    # `preset@title_pad_top` / `preset@title_pad_bottom`.
    ".tabular-pad { margin: 0; }",
    # Wrapper around each `<table>` panel. The table's own inline
    # `width:<N>in` / `width:100%` rides on the `<table>` itself (see
    # `.html_table_open_tag()` in this file). The wrapper provides
    # the screen-only horizontal-scroll fallback when the viewport
    # is narrower than a content-fitted table, so the surrounding
    # chrome (titles, page bands, footnotes) stays at viewport width
    # while only the table scrolls. Print mode resets to
    # `overflow-x: visible` (further below) — paginated output has
    # paper geometry and never needs scroll behaviour.
    ".tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }",
    # `margin: 0 auto` is a no-op in the single-panel case (the
    # `.tabular-content` wrapper already shrinks to the table
    # width) but matters for multi-panel layouts (`paginate(panels
    # = N)`) where narrower panels sit centred inside a wrapper
    # sized to the widest panel.
    #
    # `font-size` is emitted in pt from `preset@font_size` (default
    # 9pt) so the browser renders at the same size the engine's AFM
    # measurement used (`R/col_width.R::.compute_col_width()`). Any
    # other unit (rem, em, %) introduces a scaling factor against
    # the browser's 16px base that the AFM doesn't know about, so
    # `<col style="width:Nin"/>` widths under-shoot the rendered
    # content width and cells wrap. pt-units align the two ends of
    # the pipeline and keep HTML in parity with RTF / LaTeX / PDF /
    # DOCX, which render literally at `preset@font_size`.
    sprintf(
      ".tabular-table { border-collapse: collapse; font-size: %gpt; margin: 0 auto; }",
      fs
    ),
    .html_cell_padding_css(preset),
    ".tabular-table td { text-align: left; vertical-align: top; }",
    # Top rule sits above the entire thead block — scoped to the
    # FIRST thead row only. A blanket `thead th { border-top }` would
    # also paint a heavy rule above the col-labels row (second thead
    # row when bands exist), masking the scoped .tabular-band underline
    # and making the band appear to span the full table width.
    # Heavy bottom rule sits above tbody (on the col-labels row, i.e.
    # the LAST thead row). Band underline applies ONLY to .tabular-band
    # cells so blank flanking cells over unmapped columns do not extend
    # the rule full width — cmidrule(lr) cell-border semantics.
    ".tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }",
    # Structural toprule / midrule / spanrule (thead) + bottomrule
    # (tbody) -- generated from the SSOT just above; off rules drop out.
    structural_rules,
    ".tabular-table tbody tr td { border-top: none; }",
    ".tabular-band { text-align: center; }",
    ".tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }",
    ".tabular-subgroup-label { font-weight: 600; }",
    # Synthesised section-header rows (col_spec(usage = "group",
    # group_display = "header_row")) — bold, flush-left, slight extra
    # padding above so each band reads as a unit. Blank-gap rows: a
    # thin spacer (no borders) between consecutive sections.
    ".tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }",
    ".tabular-blank-row td { padding: .25rem .6rem; border: none; }",
    ".text-left { text-align: left; }",
    ".text-center { text-align: center; }",
    ".text-right { text-align: right; }",
    # Specificity bump for `<th>` cells. The baseline rule
    # `.tabular-table thead th { ... text-align: center }` has
    # selector specificity (0,1,2), which outranks the plain
    # `.text-*` classes (0,1,0). Repeating each class under the
    # `thead th` prefix lifts specificity to (0,2,2) so per-cell
    # alignment classes actually win on header cells. Body `<td>`
    # cells do not need this because their baseline is the same
    # specificity as `.text-*` and class source order wins.
    ".tabular-table thead th.text-left { text-align: left; }",
    ".tabular-table thead th.text-center { text-align: center; }",
    ".tabular-table thead th.text-right { text-align: right; }",
    ".valign-top { vertical-align: top; }",
    ".valign-middle { vertical-align: middle; }",
    ".valign-bottom { vertical-align: bottom; }",
    sprintf(
      ".tabular-footnote { font-size: %gpt; color: #495057; margin: .25rem 0; }",
      fs
    ),
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
    # Chrome font tracks the body font one point smaller (floored at
    # 6pt), matching galley, so the page bands never out-size the table.
    # Bands are borderless by default (galley parity); the spacing
    # margins stay so the header/footer keep their breathing room.
    sprintf(
      ".tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: %gpt; color: var(--tabular-chrome-color); }",
      max(fs - 1, 6)
    ),
    ".tabular-page-header { margin-bottom: 1rem; }",
    ".tabular-page-footer { margin-top: 1rem; }",
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
# semantics. USED ONLY for the `@page { content: }` CSS print fragment,
# where markup cannot be expressed; the on-screen DOM band renders rich
# markup via `.html_render_slot_ast_with_tokens()` -> `.render_html_inline()`
# (Thread F). Newline runs become literal "\n" (so the CSS fragment
# writer can `\A`-split if it wants); other run types recurse through
# children.
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
