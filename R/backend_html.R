# backend_html.R — HTML backend. Consumes a resolved
# `tabular_grid` and writes a self-contained UTF-8 .html file
# whose visual style mirrors a Bootstrap-5-light table (no CDN
# dependency — the minimum CSS is inlined inside a `<style>`
# block so the file renders identically online, offline, in
# email, and in `file://` previews).
#
# Output layout — one continuous document. Titles emit as
# `<p class="tabular-title">` above the table (once). HTML is a
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

# Wrap the page chrome (running header / footer bands) plus the body in
# one `width: fit-content; margin: 0 auto` container so the bands align to
# the body's width instead of spanning the full document. The bands carry
# `width: 100%` (see `.html_inline_style`), so they fill this container,
# whose width is the widest child (normally the table). Only wraps when at
# least one chrome band is present: a table or figure with NO running chrome
# keeps the prior structure exactly, so its snapshot stays byte-identical.
.html_chrome_wrap <- function(header, body, footer) {
  if (length(header) == 0L && length(footer) == 0L) {
    return(c(header, body, footer))
  }
  c(
    "<div class=\"tabular-chrome-wrap\">",
    header,
    body,
    footer,
    "</div>"
  )
}

# Compose the full HTML document: doctype, head (charset, title,
# inline stylesheet), then a continuous body — chrome header,
# titles (once), one `<table>` per horizontal panel concatenating
# every vertical page's rows inside a single `<tbody>` (with
# print-only `<tr class="tabular-page-break-row">` markers between
# them), footnotes (once), chrome footer. Returns a character
# vector of lines ready for `writeLines()`. Pure — no I/O.
.render_html_grid <- function(grid) {
  if (identical(grid@metadata$content_type, "figure")) {
    return(.render_html_figure(grid))
  }
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

  # On-screen chrome — semantic HTML5 `<header>` above the document
  # body and `<footer>` below. The CSS `@page` rules at
  # `.html_inline_style()` still drive print-time chrome (so
  # printed output continues to match the canonical submission
  # per-page). `chrome_onscreen = "off"` on the preset
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
      "<figcaption class=\"tabular-caption\">",
      rep(blank_p, pad_title_top),
      titles,
      rep(blank_p, pad_title_bottom),
      "</figcaption>"
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

  # `.tabular-content` is a semantic `<figure>` that wraps the title
  # `<figcaption>` + tables + footnotes in one centred container sized
  # to the widest table (`width: fit-content; margin: 0 auto`) -- the
  # gt / flextable / tinytable model. The titles ride in a real
  # `<figcaption>` (a caption, not a heading, so pkgdown's "On this
  # page" outline stays clean); the gap above the table is the engine's
  # `title_to_body` blank-line count (rendered by the pad spacers,
  # screen and paper alike, never a hardcoded margin). Footnote sits
  # flush to the table's left edge; the whole block centres on the
  # page. The table
  # carries no inline width, so it renders at the same intrinsic
  # size in every host (viewer pane / browser viewport / Quarto
  # chunk / Shiny UI cell); only the surrounding whitespace
  # differs. The CSS rules live in `.html_inline_style()`. One code
  # path regardless of `col_spec(width)` units.
  content_open <- "<figure class=\"tabular-content\">"

  # Wrap the rendered body in the document shell. The CSS scope id (gt /
  # flextable model: every rule prefixed `#<id>`, the container carries
  # the id, so the host page's Bootstrap / pkgdown / Quarto CSS cannot
  # cascade over the table) is hashed from the rendered body TEXT, not the
  # S7 grid object. Text is byte-identical under `load_all` and an
  # installed package (an S7 object's class carries namespace-environment
  # refs that hash differently between the two), so snapshots stay stable;
  # it is still unique per table, so two tables on one page never collide.
  assemble <- function(body_inner) {
    doc_body <- .html_chrome_wrap(
      onscreen_header,
      body_inner,
      onscreen_footer
    )
    scope_id <- paste0("tabular-", substr(rlang::hash(doc_body), 1L, 10L))
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
        body_borders = body_borders,
        scope_id = scope_id
      ),
      "</head>",
      sprintf("<body class=\"tabular-doc\" id=\"%s\">", scope_id)
    )
    c(head, doc_body, "</body>", "</html>")
  }

  # Empty-state. Both shapes carry one message (`meta$empty_text_ast`,
  # default "No data available to report"): a zero-row page WITH visible
  # columns rides a full-span message row inside the table (so the
  # column-header band still renders) and is handled in the normal path
  # below; a page with NO column structure (a hand-built zero-page grid,
  # or every column hidden) stands alone under the titles here. The
  # `total == 0L` short-circuit guards the `pages[[1L]]` access.
  empty_no_cols <- total == 0L ||
    (isTRUE(pages[[1L]]$is_empty_page) &&
      length(pages[[1L]]$col_names) == 0L)
  if (empty_no_cols) {
    body_inner <- c(
      content_open,
      title_block,
      sprintf(
        "<p class=\"tabular-empty\">%s</p>",
        .html_empty_message(meta$empty_text_ast, preset)
      ),
      footnote_block,
      "</figure>"
    )
    return(assemble(body_inner))
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
    "</figure>"
  )
  assemble(body_inner)
}

# ---------------------------------------------------------------------
# Figure rendering (metadata$content_type == "figure")
# ---------------------------------------------------------------------

# Compose a figure document: the same self-contained HTML shell + on-screen
# chrome + title / footnote blocks as a table, but each page emits a
# data-URI `<img>` placed in a flex content box (halign -> justify-content,
# valign -> align-items). HTML is continuous, so shared chrome (no `meta`)
# renders once around N stacked images in one `<figure>`, like a table;
# per-page chrome (`meta` drove distinct titles) keeps one `<figure>` per
# page. A print-only page-break marker sits between plots either way.
.render_html_figure <- function(grid) {
  meta <- grid@metadata
  pages <- grid@pages
  preset <- meta$preset
  cs <- meta$chrome_style %||% chrome_style()
  doc_title <- .html_doc_title(meta)

  chrome_mode <- if (is_preset_spec(preset)) {
    preset@chrome_onscreen
  } else {
    "auto"
  }
  total_for_chrome <- max(length(pages), 1L)
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

  n <- length(pages)

  # Inter-section blank-line pads, resolved once from the spacing gaps
  # (`style()` per-surface override wins, else the preset `spacing` gap).
  # Title pads ride INSIDE the <figcaption> (mirror the table title block);
  # the footnote pad leads the footnote block.
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
  pad_foot_above <- .html_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )

  # Wrap a resolved title AST in a <figcaption>, or nothing when empty.
  caption_block <- function(titles_ast) {
    titles <- .render_html_title_block(titles_ast, preset = preset, cs = cs)
    if (length(titles) > 0L) {
      c(
        "<figcaption class=\"tabular-caption\">",
        rep(blank_p, pad_title_top),
        titles,
        rep(blank_p, pad_title_bottom),
        "</figcaption>"
      )
    } else {
      character()
    }
  }

  # Render the footnote block with its leading blank-line pad, or nothing.
  foot_block <- function(footnotes_ast) {
    fn <- .render_html_footnote_block(footnotes_ast, preset = preset, cs = cs)
    if (length(fn) > 0L) {
      c(rep(blank_p, pad_foot_above), fn)
    } else {
      character()
    }
  }

  body_inner <- if (isTRUE(meta$shared_chrome)) {
    # Shared chrome: identical on every page, so the caption and footnotes
    # render once around the N stacked images inside one <figure>. Page-break
    # rows still sit between images so print pagination splits the plots.
    images <- lapply(seq_len(n), function(i) {
      brk <- if (i < n) {
        "<div class=\"tabular-page-break-row\"></div>"
      } else {
        NULL
      }
      c(.html_figure_image(pages[[i]]), brk)
    })
    c(
      "<figure class=\"tabular-content\">",
      caption_block(meta$titles_ast),
      unlist(images, use.names = FALSE),
      foot_block(meta$footnotes_ast),
      "</figure>"
    )
  } else {
    # Per-page chrome (`meta`): one <figure> per plot, each with its own
    # caption and footnote.
    sections <- lapply(seq_len(n), function(i) {
      pg <- pages[[i]]
      foot <- foot_block(pg$footnotes_ast)
      brk <- if (i < n) {
        "<div class=\"tabular-page-break-row\"></div>"
      } else {
        NULL
      }
      c(
        "<figure class=\"tabular-content\">",
        caption_block(pg$titles_ast),
        .html_figure_image(pg),
        foot,
        "</figure>",
        brk
      )
    })
    unlist(sections, use.names = FALSE)
  }

  doc_body <- .html_chrome_wrap(onscreen_header, body_inner, onscreen_footer)
  scope_id <- paste0("tabular-", substr(rlang::hash(doc_body), 1L, 10L))
  head <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    paste0("<title>", .html_escape(doc_title), "</title>"),
    .html_inline_style(
      preset = preset,
      pagehead_ast = meta$pagehead_ast,
      pagefoot_ast = meta$pagefoot_ast,
      cs = cs,
      body_borders = list(),
      scope_id = scope_id
    ),
    "</head>",
    sprintf("<body class=\"tabular-doc\" id=\"%s\">", scope_id)
  )
  c(head, doc_body, "</body>", "</html>")
}

# One figure page's image as a responsive data-URI `<img>`. HTML is a
# continuous, responsive medium: the image renders at its drawn width but
# is capped to the container (`max-width: 100%`), so a full-page-width
# figure scales down to the viewport instead of overflowing. No fixed box
# height -- the figure is contained to its own space rather than stretched
# over the page content-box. `justify-content` carries `halign`; valign is
# a no-op here (only the paged backends place a figure vertically; see
# `figure()` docs).
.html_figure_image <- function(pg) {
  place <- pg$place %||% list(halign = "center")
  mime <- if (identical(pg$image_ext, "jpeg")) "image/jpeg" else "image/png"
  b64 <- .base64_encode_raw(pg$image_bytes)
  justify <- .html_flex_justify(place$halign %||% "center")
  c(
    sprintf(
      "<div class=\"tabular-figure\" style=\"display:flex; justify-content:%s;\">",
      justify
    ),
    sprintf(
      "<img alt=\"Figure\" src=\"data:%s;base64,%s\" style=\"width:%.2fin; max-width:100%%; height:auto;\">",
      mime,
      b64,
      pg$draw_w_in
    ),
    "</div>"
  )
}

.html_flex_justify <- function(halign) {
  switch(halign, left = "flex-start", right = "flex-end", "center")
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
# to the surface element's open tag (`<p>`, `<th>`, `<td>` etc.).
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

# Title block: each title line becomes a `<p class="tabular-title">`.
# (Not `<h1>`: a table carries several title lines, so headings would
# emit multiple `<h1>` per table, inherit the host's heading margins,
# and pollute pkgdown's "On this page" outline. `<p>` is neutral chrome
# and the scoped `.tabular-title` rule fully controls its look.)
# Per-line horizontal alignment from
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
        .effective_title_halign(preset, line_index = i, n_lines = n)
      }
      cls <- "tabular-title"
      if (length(halign) == 1L && !is.na(halign)) {
        extra <- .html_align_class(halign)
        if (nzchar(extra)) {
          cls <- c(cls, extra)
        }
      }
      # Title borders ride the block edges (top on line 1, bottom on
      # line n). The title surface has no region channel, so the
      # surface-node border is the only path -- no double-emission.
      line_style <- .html_merge_style_attr(
        surface_style,
        .html_chrome_block_border_decls(surface_node, i, n)
      )
      sprintf(
        "<p class=\"%s\"%s>%s</p>",
        paste(cls, collapse = " "),
        line_style,
        .render_html_inline(titles_ast[[i]], preserve = ws_preserve)
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
      # Footnote borders ride the block edges. `top` is already drawn by
      # the `footer_top` region (the separator rule above the block), so
      # it is skipped here to keep that side single-channel; `bottom` /
      # `left` / `right` come from the surface node.
      line_style <- .html_merge_style_attr(
        surface_style,
        .html_chrome_block_border_decls(
          surface_node,
          i,
          n,
          skip = "top"
        )
      )
      sprintf(
        "<p class=\"%s\"%s>%s</p>",
        paste(cls, collapse = " "),
        line_style,
        .render_html_inline(footnotes_ast[[i]], preserve = ws_preserve)
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
        cs = cs,
        headers = meta$headers,
        empty_text_ast = meta$empty_text_ast,
        empty_place = meta$empty_place
      )
    )
  }
  out <- c(out, "<tbody>", body_lines, "</tbody>", "</table>", "</div>")
  out
}

# Render the empty-state message to inline HTML. `empty_text_ast` is the
# parsed `tabular_spec@empty_text`; a NULL (hand-built grid without the
# metadata) falls back to the canonical default text.
.html_empty_message <- function(empty_text_ast, preset = NULL) {
  if (is.null(empty_text_ast)) {
    return(.html_escape(.tabular_empty_text_default))
  }
  .render_html_inline(empty_text_ast, preserve = .preset_ws_preserve(preset))
}

# Full-span empty-state message row for a zero-row page that still has a
# column structure. The host cell's `height` is the body content-box, so
# the native `vertical-align` centres the message (top/middle/bottom from
# `empty_valign`); `text-align` carries `empty_halign`. Reuses the
# `.tabular-empty` muted style shared with the no-column standalone block.
.render_html_empty_row <- function(
  empty_text_ast,
  empty_place,
  ncols,
  preset
) {
  halign <- empty_place$halign %||% "center"
  valign <- empty_place$valign %||% "middle"
  height_css <- if (
    !is.null(empty_place) &&
      is.finite(empty_place$height_in) &&
      empty_place$height_in > 0
  ) {
    sprintf("height:%.2fin;", empty_place$height_in)
  } else {
    ""
  }
  sprintf(
    paste0(
      "<tr><td colspan=\"%d\" class=\"tabular-empty\" ",
      "style=\"%svertical-align:%s;text-align:%s;\">%s</td></tr>"
    ),
    ncols,
    height_css,
    valign,
    halign,
    .html_empty_message(empty_text_ast, preset)
  )
}

# Render one page slice's body `<tr>` lines: an optional subgroup
# banner `<tr class="tabular-subgroup">` followed by one `<tr>` per
# data row. Returns character(0) when the page is empty.
.render_html_page_body_rows <- function(
  page,
  col_names_visible,
  col_specs,
  preset = NULL,
  cs = NULL,
  headers = NULL,
  empty_text_ast = NULL,
  empty_place = NULL
) {
  out <- character()
  has_bign <- !is.null(page$subgroup_bign) && length(page$subgroup_bign) > 0L
  banner_row <- .render_html_subgroup_banner_row(
    page$subgroup_line_ast,
    n_cols = length(col_names_visible),
    preset = preset,
    cs = cs,
    # No per-arm N row to carry the closing rule -> the banner carries it.
    closing = !has_bign
  )
  if (length(banner_row) > 0L) {
    out <- c(out, banner_row)
    # Per-subgroup BigN: the continuous layout cannot vary the single
    # header, so the per-arm `(N=x)` rides a dedicated row directly under
    # the banner. Gated on the banner being present and the page carrying
    # records, so non-big_n tables emit nothing here.
    if (has_bign) {
      out <- c(
        out,
        .render_html_subgroup_bign_row(
          page$subgroup_bign,
          headers,
          col_names_visible
        )
      )
    }
  }
  cells_text <- page$cells_text
  cells_style <- page$cells_style
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    # Empty-state placeholder: a zero-row page renders the chrome + the
    # column-header band (the `<thead>` emitted by `.render_html_table`)
    # + one full-span message row here. The host cell's `height` is the
    # body content-box, so the native table-cell `vertical-align`
    # (top/middle/bottom maps 1:1 to `empty_valign`) centres the message
    # exactly; `text-align` carries `empty_halign`. A non-`is_empty_page`
    # zero-row page (e.g. an all-blank synthetic slice) keeps the historic
    # empty return.
    if (isTRUE(page$is_empty_page) && length(col_names_visible) > 0L) {
      out <- c(
        out,
        .render_html_empty_row(
          empty_text_ast = empty_text_ast,
          empty_place = empty_place,
          ncols = length(col_names_visible),
          preset = preset
        )
      )
    }
    return(out)
  }
  # Per-cell indent depth comes from the engine sidecar (`col_spec@indent`
  # plus any `group_display = "header_row"` auto-indent). Default to a
  # zero matrix so fixtures that bypass the engine (older tests, ad-hoc
  # page synthesis) still work.
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
  ws_preserve <- .preset_ws_preserve(preset)
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
        # Group-header borders: the row is a single merged `<td>` with no
        # region channel, so the stamped host node's border props are the
        # only path. Emit all four sides here (uniform with body cells);
        # `.html_chrome_inline_style` deliberately carries no borders.
        decls <- c(decls, sub(";$", "", .html_cell_border_decls(host_node)))
        header_style <- if (length(decls) > 0L) {
          sprintf(" style=\"%s\"", paste(decls, collapse = "; "))
        } else {
          ""
        }
        inner <- if (is_bold) {
          paste0(
            "<strong>",
            .html_escape_cell(host_text, preserve = ws_preserve),
            "</strong>"
          )
        } else {
          .html_escape_cell(host_text, preserve = ws_preserve)
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
            # { padding: .18rem .6rem }` left slot via CSS `calc()`
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
          text <- .html_escape_cell(raw, preserve = ws_preserve)
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
      n_cols <- length(col_names_visible)
      pos <- 0L
      cells <- vapply(
        runs,
        function(run) {
          lbl <- run$value
          span <- run$length
          start_col <- pos + 1L
          end_col <- pos + span
          pos <<- end_col
          if (is.na(lbl)) {
            # Empty flanking cell over unmapped columns: it must carry the
            # header surface style (background) too, so a coloured band
            # reads end-to-end instead of leaving white flanks.
            sprintf("<th colspan=\"%d\"%s></th>", span, surface_style)
          } else {
            # Edge rule (LaTeX parity): a spanner touching column 1 or the
            # last column keeps that outer end flush (un-inset) so its rule
            # runs to the table edge; interior ends stay trimmed.
            flush_l <- start_col == 1L
            flush_r <- end_col == n_cols
            modifier <- if (flush_l && flush_r) {
              " tabular-band-flush-both"
            } else if (flush_l) {
              " tabular-band-flush-left"
            } else if (flush_r) {
              " tabular-band-flush-right"
            } else {
              ""
            }
            sprintf(
              "<th colspan=\"%d\" class=\"tabular-band%s\"%s>%s</th>",
              span,
              modifier,
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
  ws_preserve <- .preset_ws_preserve(preset)
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      label <- if (is.null(ast)) {
        .html_escape(nm)
      } else {
        .render_html_inline(ast, preserve = ws_preserve)
      }
      col <- cols[[nm]]
      # col_spec wins over chrome surface for header halign (per-
      # column override); fall back to chrome surface, then preset.
      # `decimal` is the ONE carve-out: engine_decimal pads every body
      # cell to a uniform column width with NBSP that aligns decimal
      # points across rows, so BOTH the body block and its header centre
      # in the column (rather than hugging the right edge) -- the dominant
      # clinical-TFL convention, and parity with LaTeX / RTF / DOCX. Other
      # body alignments (left / center / right) map straight through to the
      # same value on the header.
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
  cs = NULL,
  closing = FALSE
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
  # `closing` adds the closing-rule class when no per-arm (N=x) row will
  # follow, so the banner is not left without any separator from the data.
  row_class <- if (isTRUE(closing)) {
    "tabular-subgroup tabular-subgroup-closed"
  } else {
    "tabular-subgroup"
  }
  sprintf(
    paste0(
      "<tr class=\"%s\">",
      "<td colspan=\"%d\"%s%s>",
      "%s%s%s",
      "</td></tr>"
    ),
    row_class,
    n_cols,
    attr,
    surface_style,
    bold_open,
    inner,
    bold_close
  )
}

# Per-arm BigN row for a subgroup banner (continuous backends only).
# Builds the visible-column span map via the shared `.subgroup_bign_spans`,
# coalesces equal-target runs into colspans, and emits one centred
# `<td>` per run. The `text-align: center` is inline on purpose: the
# stylesheet is emitted inline in every output, so adding a CSS rule
# would churn every HTML snapshot, and the body-`td` baseline
# (`text-align:left`, specificity 0,1,1) would outrank a utility class
# anyway. Inline always wins and touches no shared rule, so non-big_n
# output stays byte-identical. The `tabular-subgroup-bign` row class is
# a structural marker, no rule attached. Not bold (mirrors the paged
# header's `(N=x)` line, which is plain under the bold arm name).
.render_html_subgroup_bign_row <- function(
  records,
  headers,
  col_names_visible
) {
  sp <- .subgroup_bign_spans(records, headers, col_names_visible)
  runs <- .group_contiguous_runs(sp$key)
  cells <- character(length(runs))
  pos <- 1L
  for (i in seq_along(runs)) {
    run <- runs[[i]]
    colspan_attr <- if (run$length > 1L) {
      sprintf(" colspan=\"%d\"", run$length)
    } else {
      ""
    }
    cells[[i]] <- sprintf(
      "<td%s style=\"text-align: center;\">%s</td>",
      colspan_attr,
      .html_escape(sp$text[[pos]])
    )
    pos <- pos + run$length
  }
  paste0(
    "<tr class=\"tabular-subgroup-bign\">",
    paste(cells, collapse = ""),
    "</tr>"
  )
}

# Emit the opening `<table>` tag. The table carries NO inline width:
# it sizes to its natural content width and is centred on the page
# by the `fit-content` / `margin: 0 auto` `.tabular-content` wrapper
# (the gt / flextable model). Per-column widths the user set ship in
# `<colgroup>` via `.html_colgroup()`; `preset@width_mode` drives the
# paper backends (RTF / LaTeX / PDF / DOCX) only, not the on-screen
# table width.
#
# No `table-layout: fixed` is emitted. The engine's AFM-measured
# widths slightly under-count the browser's rendered content width
# (CSS `.tabular-table` font-size is `.9rem` ≈ 10.8pt vs AFM at
# `preset@font_size` ≈ 10pt; CSS `padding: .18rem .6rem` ≈ 19pt
# total vs AFM's 12pt). Under `table-layout: fixed` that gap caused
# header / cell content to wrap inside too-narrow columns. With the
# default `table-layout: auto`, the engine widths become hints; the
# browser expands columns to fit content when needed. Any overflow
# is absorbed by `.tabular-table-wrap { overflow-x: auto; }`.
.html_table_open_tag <- function(col_specs, preset) {
  # gt / flextable model: the table sizes to its content (natural
  # width) and is centred on the page via `.tabular-table { margin:
  # 0 auto }` inside a `width: fit-content` `.tabular-content`
  # wrapper. The table therefore carries NO inline width -- a
  # hardcoded `width:100%` made the same table look different in
  # every host (wide in a viewer pane, narrow in a pkgdown article
  # column) and left no room to centre it. Per-column widths (when
  # the user set them) still ship in `<colgroup>` via
  # `.html_colgroup()`. `col_specs` and `preset` are ignored here --
  # kept on the signature for call-site stability.
  "<table class=\"tabular-table\">"
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
    # decimal: the engine_decimal phase pads every cell to a uniform column
    # width with NBSP, so the block centres under the (centred) decimal
    # header rather than hugging the right edge (LaTeX / RTF / DOCX parity).
    decimal = "text-center",
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
  sprintf(
    "border-%s: %gpt %s %s;",
    side,
    brd$width,
    css_style,
    .resolve_rule_color(brd$color)
  )
}

# `.tabular-table th/td` padding CSS. The default `cell_padding` keeps the
# responsive rem-based padding (comfortable on screen and the baseline the
# indent `calc(.6rem + ...)` builds on); an explicit `preset(cell_padding
# = ...)` override emits the four sides in pt so the knob reaches HTML like
# the paged backends. Compared against the factory default so the common
# case is byte-unchanged.
.html_cell_padding_css <- function(preset) {
  rem_default <- ".tabular-table th, .tabular-table td { padding: .18rem .6rem; }"
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

# Spanner band underline, trimmed at both ends (booktabs `\cmidrule(lr)`
# parity with the LaTeX backend). A `border-bottom` spans the full cell
# width, so adjacent spanners' underlines abut into one continuous line.
# Instead we paint the rule as an inset `background` gradient: a
# horizontal stripe at the cell bottom, COLOUR only between `<inset>` and
# `100% - <inset>`, transparent at the ends. Each band cell insets by
# `<inset>` on both sides, so adjacent spanners are separated by a
# `2 * <inset>` gap and the outer ends sit inside the column edge.
# Returns NULL when the rule is off (so `rules = list(spanrule = "none")`
# still clears it).
.html_band_rule_trimmed <- function(selector, triple, inset = "0.5em") {
  if (is.null(triple) || identical(triple$style, "none")) {
    return(NULL)
  }
  colour <- .resolve_rule_color(triple$color)
  common <- sprintf(
    "background-repeat: no-repeat; background-position: left bottom; background-size: 100%% %gpt;",
    triple$width
  )
  grad <- function(left, right) {
    # Stops as (start, end) of the painted segment. left/right are the
    # insets (a CSS length or "0"); the rule is `colour` between them.
    sprintf(
      "background-image: linear-gradient(to right, transparent %s, %s %s, %s calc(100%% - %s), transparent calc(100%% - %s));",
      left,
      colour,
      left,
      colour,
      right,
      right
    )
  }
  # Default: inset both ends (interior spanners). The `flush-*` modifiers
  # keep the table's OUTER edge un-inset so a spanner touching column 1
  # or the last column runs to the table edge (parity with the LaTeX
  # leftpos/rightpos=1 edge rule). `flush-both` = a spanner over the whole
  # width: no inset at all.
  c(
    sprintf("%s { %s %s }", selector, grad(inset, inset), common),
    sprintf(
      "%s.tabular-band-flush-left { %s %s }",
      selector,
      grad("0px", inset),
      common
    ),
    sprintf(
      "%s.tabular-band-flush-right { %s %s }",
      selector,
      grad(inset, "0px"),
      common
    ),
    sprintf(
      "%s.tabular-band-flush-both { %s %s }",
      selector,
      grad("0px", "0px"),
      common
    )
  )
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

# Block-edge border declarations for a multi-line chrome block (title /
# footnote). The block renders one `<p>` per line, so a border on the
# surface maps to the BLOCK edges: `top` rides the first line, `bottom`
# the last line, `left` / `right` ride every line (stacking into a
# continuous vertical edge). `skip` names sides already emitted through
# the chrome region channel (e.g. footnote `top` == `footer_top`), so
# they are not re-emitted here -- the single-channel guarantee.
.html_chrome_block_border_decls <- function(node, i, n, skip = character()) {
  if (!is_style_node(node)) {
    return(character())
  }
  sides <- character()
  if (i == 1L && !("top" %in% skip)) {
    sides <- c(sides, "top")
  }
  if (i == n && !("bottom" %in% skip)) {
    sides <- c(sides, "bottom")
  }
  if (!("left" %in% skip)) {
    sides <- c(sides, "left")
  }
  if (!("right" %in% skip)) {
    sides <- c(sides, "right")
  }
  out <- character()
  for (side in sides) {
    brd <- .effective_border(side, node)
    if (is.null(brd)) {
      next
    }
    if (identical(brd$style, "none")) {
      out <- c(out, sprintf("border-%s: none;", side))
      next
    }
    decl <- .html_border_decl(side, brd)
    if (!is.null(decl)) {
      out <- c(out, decl)
    }
  }
  out
}

# Merge extra CSS declarations into an existing ` style="..."` attribute
# fragment (or build one when the fragment is empty). Mirrors the fold
# the subgroup banner uses so chrome border decls compose with the
# text-prop inline style without re-parsing.
.html_merge_style_attr <- function(style_attr, extra_decls) {
  if (length(extra_decls) == 0L) {
    return(style_attr)
  }
  extra <- paste(extra_decls, collapse = " ")
  if (nzchar(style_attr)) {
    sub("\"$", paste0("; ", extra, "\""), style_attr)
  } else {
    sprintf(" style=\"%s\"", extra)
  }
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
.render_html_inline <- function(ast, preserve = TRUE) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  .render_html_children(ast@runs, preserve, lead = TRUE, trail = TRUE)
}

# Render one AST run record to its HTML markup. Recurses through
# `children` for wrapping types. `preserve` rewrites significant
# whitespace in plain-text leaves (labels with hand-built indent),
# never inside structural markup. `lead` / `trail` say whether the run
# sits at the start / end of its visual line, so only true line-edge
# whitespace is made non-breaking (inter-run spaces stay breakable).
.render_html_run <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  type <- run$type
  switch(
    type,
    plain = .html_escape_text_run(run$text %||% "", preserve, lead, trail),
    bold = paste0(
      "<strong>",
      .render_html_children(run$children, preserve, lead, trail),
      "</strong>"
    ),
    italic = paste0(
      "<em>",
      .render_html_children(run$children, preserve, lead, trail),
      "</em>"
    ),
    sup = paste0(
      "<sup>",
      .render_html_children(run$children, preserve, lead, trail),
      "</sup>"
    ),
    sub = paste0(
      "<sub>",
      .render_html_children(run$children, preserve, lead, trail),
      "</sub>"
    ),
    code = paste0(
      "<code>",
      .render_html_children(run$children, preserve, lead, trail),
      "</code>"
    ),
    link = .render_html_link(run, preserve, lead, trail),
    span = paste0(
      "<span>",
      .render_html_children(run$children, preserve, lead, trail),
      "</span>"
    ),
    newline = "<br/>",
    .html_escape_text_run(run$text %||% "", preserve, lead, trail)
  )
}

# Escape a plain-text run and, when preserving, rewrite significant
# whitespace runs into `&nbsp;`. The single chokepoint for inline
# plain text so labels / titles / footnotes preserve hand-built
# indent identically to body cells.
.html_escape_text_run <- function(text, preserve, lead = TRUE, trail = TRUE) {
  .escape_text_run(text, .html_escape, "&nbsp;", preserve, lead, trail)
}

# Render the children of a wrapping run. Each child's line-edge flags
# are derived from its position: a child is line-leading only if it is
# the first child (or follows a newline) AND the parent is line-leading;
# symmetric for trailing.
.render_html_children <- function(
  children,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  .render_ast_children(children, .render_html_run, preserve, lead, trail)
}

# Render a link run as `<a href="..." title="...">text</a>`. The
# title attribute is optional and emitted only when set per
# CommonMark; .parse_inline emits a character NA when the source
# markdown carried no title, so we guard against NA + empty
# string both. `href` and `title` are attribute-escaped.
.render_html_link <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  text <- .render_html_children(run$children, preserve, lead, trail)
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
.html_escape_cell <- function(text, preserve = TRUE) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  # Peel any auto-footnote marker sentinel off the cell end before
  # escaping; it is re-attached as a `<sup>` after the base is escaped.
  peeled <- .fn_peel(text)
  text <- peeled$base
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub("\"", "&quot;", text, fixed = TRUE)
  text <- gsub("'", "&#39;", text, fixed = TRUE)
  text <- gsub("\r\n", "<br/>", text, fixed = TRUE)
  text <- gsub("\n", "<br/>", text, fixed = TRUE)
  # Preserve significant ASCII whitespace LAST -- after the indent
  # strip at the call site and after `\n` -> `<br/>` -- so only
  # residual user spaces become `&nbsp;`, never the engine indent.
  if (isTRUE(preserve)) {
    text <- .preserve_ws(text, "&nbsp;")
  }
  if (any(peeled$has)) {
    text[peeled$has] <- paste0(
      text[peeled$has],
      "<sup>",
      .html_escape(peeled$marker[peeled$has]),
      "</sup>"
    )
  }
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
  body_borders = NULL,
  scope_id = NULL
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
    .html_band_rule_trimmed(
      ".tabular-table thead .tabular-band",
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
    # are <p> outside <table>, so they stay outside the box.
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
    # The container pins the table's own font-size and a tight
    # line-height as the baseline for the whole fragment, so titles,
    # footnotes, and the blank-line pad spacers inherit the table scale
    # instead of the host's body text metrics (pkgdown / Bootstrap use a
    # 16px / 1.65 base, which otherwise inflated every gap between the
    # title lines, around footnotes, and between body rows).
    sprintf(
      ".tabular-doc { font-family: %s; color: #212529; margin: 1.5rem; font-size: %gpt; line-height: 1.3; }",
      .html_font_family_css(preset),
      fs
    ),
    # `.tabular-content` wraps title + tables + footnote in one
    # block that shrinks to the widest table (`width: fit-content`)
    # and is centred on the page (`margin: 0 auto`) -- the gt /
    # flextable model. The table keeps its natural content width
    # (no inline `width:100%`), so the same spec renders at the
    # same intrinsic size in every host (viewer pane, pkgdown
    # article column, Quarto chunk); only the surrounding
    # whitespace differs. Titles centre over the table; footnotes
    # sit flush to the table's left edge. `max-width: 100%` caps an
    # over-wide table to the host so `.tabular-table-wrap`'s
    # horizontal scroll can take over rather than overflowing.
    ".tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }",
    # Host-CSS neutralisation for `<p>` line spacing. pkgdown / tidytemplate
    # ship `main p, main li { line-height: 1.65 }` (selector specificity
    # 0,0,1,1), which beats the container's inherited `line-height` and
    # inflates every title / footnote line on a reference or article page
    # (the standalone emit has no such host rule, so it stayed tight). This
    # scoped `#<id> p` rule (0,1,0,1) outranks `main p` and re-inherits the
    # container line-height, so titles render at the table scale in every
    # host. The pad spacer keeps its own `line-height: 1` (its `.tabular-pad`
    # rule is more specific, 0,1,1,0).
    "p { line-height: inherit; }",
    sprintf(
      ".tabular-title { font-size: %gpt; font-weight: 600; text-align: center; margin: .2rem 0; }",
      fs
    ),
    # `<figcaption>` groups the title lines (and their pad spacers)
    # into a semantic caption above the table. The bare `<figure>` UA
    # margin is neutralised by `.tabular-content { margin: 0 auto }`.
    # The caption adds NO spacing of its own; the title-to-body gap is
    # the engine's blank-line count, rendered by the pad spacers below
    # (so screen and paper share one source of truth, never a hardcoded
    # margin).
    ".tabular-caption { margin: 0; padding: 0; }",
    # `<p class="tabular-pad">&nbsp;</p>` spacers carry the blank lines
    # the engine resolved from the preset / chrome_style gaps
    # (`above_title` -> `pad_title_top`, `title_to_body` ->
    # `pad_title_bottom`, `body_to_footnote` -> the footnote gap). They
    # render identically on screen and paper -- one clean line each at
    # the table font-size (`line-height: 1`, zeroing the browser-default
    # `<p>` margin), so the title-to-table gap is whatever the spec
    # says, not a backend-invented constant.
    ".tabular-pad { margin: 0; line-height: 1; }",
    # Wrapper around each `<table>` panel. The table itself carries
    # no inline width (it is content-fitted; see
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
    # pkgdown / Bootstrap 5 neutralisation. pkgdown injects
    # `class="table"` onto every `<table>` on a reference page, and
    # Bootstrap's `.table` rules then paint a `border-bottom` on every
    # cell, tint cell backgrounds, and cast a box-shadow via the
    # `--bs-table-*` custom properties, fighting tabular's clinical look
    # (header rule + table-bottom rule only, no per-row lines). Zero the
    # Bootstrap variables and the blanket cell border / box-shadow so
    # tabular's own scoped rules stay authoritative; they are more
    # specific (id + class + pseudo) than this `(1,1,1)` reset, so the
    # explicit header / bottom / band borders re-add the wanted lines.
    # Harmless standalone (the `--bs-*` vars are unknown and ignored; the
    # cell-border reset matches tabular's own no-body-border baseline).
    # `width: auto` undoes Bootstrap's `.table { width: 100% }` so the
    # table stays content-fitted + centred on pkgdown (matching gt /
    # flextable), not stretched edge-to-edge.
    ".tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }",
    ".tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }",
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
    ".tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }",
    ".tabular-subgroup-label { font-weight: 600; }",
    # The closing rule rides the BOTTOM of the per-arm (N=x) row (when
    # present), so the banner + its N read as one header block above the
    # data rather than being boxed on their own.
    ".tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }",
    # When there is no per-arm (N=x) row (no big_n, or a constant big_n
    # folded into the column header), the banner carries the closing rule
    # itself so it stays separated from the data block.
    ".tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }",
    # Synthesised section-header rows (col_spec(usage = "group",
    # group_display = "header_row")) — bold, flush-left, slight extra
    # padding above so each band reads as a unit. Blank-gap rows: a
    # thin spacer (no borders) between consecutive sections.
    ".tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }",
    # Blank-gap row: exactly one tight blank line, sized in `em` so it
    # tracks the table font size (preset@font_size) rather than the root
    # font. `line-height: 1em` (vs the inherited 1.5) and zero padding
    # keep it to a single line height; the previous full 1.5-line `&nbsp;`
    # plus the following group-header `padding-top` stacked into an
    # oversized gap.
    ".tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }",
    ".text-left { text-align: left; }",
    ".text-center { text-align: center; }",
    ".text-right { text-align: right; }",
    # Specificity bump for `<th>` and `<td>` cells. The baseline rules
    # `.tabular-table thead th { ... text-align: center }` and
    # `.tabular-table td { text-align: left }` have selector specificity
    # (0,1,2) / (0,1,1), both of which outrank the plain `.text-*`
    # classes (0,1,0) -- so without these prefixed copies the per-cell
    # alignment class is silently defeated and EVERY body cell (decimal,
    # centre, right) falls back to the baseline left. Repeating each
    # class under the `thead th` / `td` prefix lifts specificity to
    # (0,2,2) / (0,2,1) so the per-cell alignment class actually wins.
    ".tabular-table thead th.text-left { text-align: left; }",
    ".tabular-table thead th.text-center { text-align: center; }",
    ".tabular-table thead th.text-right { text-align: right; }",
    ".tabular-table td.text-left { text-align: left; }",
    ".tabular-table td.text-center { text-align: center; }",
    ".tabular-table td.text-right { text-align: right; }",
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
    # The chrome wrapper shrinks to its widest child (normally the table),
    # centred on the page; the bands fill it at width:100% so a running
    # header / footer aligns to the body's width, not the full document.
    ".tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }",
    sprintf(
      ".tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%%; padding: .5rem 0; font-size: %gpt; color: var(--tabular-chrome-color); }",
      max(fs - 1, 6)
    ),
    ".tabular-page-header { margin-bottom: 1rem; }",
    ".tabular-page-footer { margin-top: 1rem; }",
    ".tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }",
    ".tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }",
    ".tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }",
    "@media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }"
  )
  # Scope every selector to `#<scope_id>` so the host page (pkgdown /
  # Quarto / Bootstrap) cannot cascade over the table: the container-level
  # selectors (`.tabular-doc`, `:root`) collapse to `#<id>` and every
  # descendant rule gains the `#<id> ` prefix. The `@page` margin boxes
  # below are print-only and page-global, so they stay unscoped.
  if (!is.null(scope_id)) {
    body_css <- .scope_selectors(body_css, scope_id)
  }
  page_rules <- .html_render_page_band_rules(pagehead_ast, pagefoot_ast)
  # Per-cell colour / background / padding ride on cells_style[r,c]
  # now (set by `style(at = cells_body(), ...)` and the lowered
  # `preset(colors = ..., padding = ...)` knobs). They land as inline
  # `style="..."` attributes on each `<td>` via `.html_cell_style_attr()`,
  # so the table-wide CSS block has nothing to emit on their behalf —
  # the per-cell stamps already carry the visual.
  c("<style>", body_css, page_rules, "</style>")
}

# Prefix every CSS selector in `lines` with `#<id>` so the stylesheet is
# scoped to one container (gt/flextable model). Container-level selectors
# (`.tabular-doc`, the `:root` custom-property block) collapse to `#<id>`
# itself; every other selector becomes a descendant `#<id> <selector>`.
# Comma-separated selector lists are prefixed per part. The single
# `@media print { ... }` line is handled specially: its inner rules are
# scoped, the `@media` wrapper is preserved. Other at-rules pass through.
.scope_selectors <- function(lines, id) {
  hook <- paste0("#", id)

  scope_one_selector <- function(sel) {
    parts <- trimws(strsplit(sel, ",", fixed = TRUE)[[1L]])
    out <- vapply(
      parts,
      function(p) {
        if (p %in% c(".tabular-doc", ":root")) {
          hook
        } else if (startsWith(p, ".tabular-doc ")) {
          paste0(hook, sub("^\\.tabular-doc", "", p))
        } else {
          paste0(hook, " ", p)
        }
      },
      character(1L),
      USE.NAMES = FALSE
    )
    paste(out, collapse = ", ")
  }

  # Scope each `selector { decls }` rule inside a brace block (used for
  # the inner content of `@media print { ... }`).
  scope_rule_block <- function(block) {
    pat <- "([^{}]+)\\{([^{}]*)\\}"
    pieces <- regmatches(block, gregexpr(pat, block, perl = TRUE))[[1L]]
    if (length(pieces) == 0L) {
      return(block)
    }
    scoped <- vapply(
      pieces,
      function(rule) {
        sel <- trimws(sub(pat, "\\1", rule, perl = TRUE))
        decls <- sub(pat, "\\2", rule, perl = TRUE)
        paste0(scope_one_selector(sel), " {", decls, "}")
      },
      character(1L),
      USE.NAMES = FALSE
    )
    paste(scoped, collapse = " ")
  }

  vapply(
    lines,
    function(line) {
      line <- trimws(line)
      if (!nzchar(line)) {
        return(line)
      }
      if (startsWith(line, "@media")) {
        head <- sub("\\{.*$", "{", line)
        inner <- sub("^@media[^{]*\\{(.*)\\}\\s*$", "\\1", line, perl = TRUE)
        paste0(head, " ", scope_rule_block(trimws(inner)), " }")
      } else if (startsWith(line, "@")) {
        line
      } else if (grepl("{", line, fixed = TRUE)) {
        sel <- sub("\\{.*$", "", line)
        rest <- sub("^[^{]*", "", line)
        paste0(scope_one_selector(trimws(sel)), " ", rest)
      } else {
        line
      }
    },
    character(1L),
    USE.NAMES = FALSE
  )
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
