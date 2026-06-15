# backend_docx.R — DOCX (Office Open XML, ECMA-376) backend.
# Consumes a resolved `tabular_grid` and writes a regulatory-grade
# `.docx` ZIP package whose page chrome, header bands, decimal
# alignment, multi-page pagination, inline formatting, and per-cell
# styling all honour the canonical submission layout contract. Output
# renders identically in Microsoft Word and LibreOffice Writer;
# no JVM, no `pandoc`, no `officer`.
#
# Architecture. The `.docx` is a ZIP archive with this fixed file
# set (see ECMA-376 Part 1 §11):
#
#   [Content_Types].xml          MIME map for the manifest
#   _rels/.rels                  top-level relationships
#   docProps/app.xml             creator = "tabular", version
#   docProps/core.xml            title = spec@titles[1], created
#   word/document.xml            body content: titles + table + footnotes
#   word/_rels/document.xml.rels document-level rels (styles + chrome)
#   word/footer1.xml             pagefoot_ast (only if populated)
#   word/header1.xml             pagehead_ast (only if populated)
#   word/settings.xml            compat mode + default tab stops
#   word/styles.xml              Default style: font_family + font_size
#
# Byte-determinism. Two `emit()` calls with the same input produce
# byte-identical .docx output (FDA reproducibility requirement).
# Two guarantees:
#   (1) Fixed mtime per zip entry — every file is `Sys.setFileTime()`d
#       to `.docx_fixed_mtime` (1980-01-01 00:00:00 UTC, the FAT
#       epoch floor) before zipping.
#   (2) Stable entry order — `[Content_Types].xml` pinned first per
#       OPC §11, remainder sorted alphabetically. No randomness.
#
# Width consumption. DOCX uses twips (1/1440 inch) for table grids.
# `<w:tblGrid><w:gridCol w:w="...">` reads `meta$cols` numeric
# inches (engine-resolved) and rounds to integer twips. The same
# unit conversion table feeds RTF, so cross-backend width parity
# is byte-for-byte (asserted in tests/testthat/test-backend_html.R).
#
# Inline ASTs render through `.render_docx_inline()` — a recursive
# walker over the `inline_ast@runs` list:
#
#   plain    -> <w:r><w:t xml:space="preserve">TEXT</w:t></w:r>
#   bold     -> <w:r><w:rPr><w:b/></w:rPr><w:t>...</w:t></w:r>
#   italic   -> <w:r><w:rPr><w:i/></w:rPr>...</w:r>
#   sup      -> <w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr>...
#   sub      -> <w:r><w:rPr><w:vertAlign w:val="subscript"/></w:rPr>...
#   code     -> <w:r><w:rPr><w:rFonts w:ascii="Liberation Mono".../>...
#   link     -> <w:hyperlink r:id="rIdN">...</w:hyperlink> + rels entry
#   span     -> children only
#   newline  -> <w:r><w:br/></w:r>
#
# Per-cell style cascade. DOCX is the first backend to fully consume
# `pages[[i]]$cells_style` — `.docx_tcPr_from_style()` translates
# `style_node@background / rule_above / rule_below / border_*` to
# `<w:tcPr>`; `.docx_rPr_from_style()` translates `@bold / italic /
# underline / color / font_family / font_size` to `<w:rPr>`.

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------

# OOXML namespace declarations needed on every `<w:document>` /
# `<w:hdr>` / `<w:ftr>` root. Pandoc and officer both declare the
# full nine-namespace prologue (w / m / r / o / v / w10 / a / pic /
# wp) even when the document body uses only `w:` elements; Word
# on macOS schema-validates the prologue and rejects documents
# that omit any of them. Kept in one place so all roots emit the
# identical prologue and byte-determinism stays trivial.
.docx_ns_decls <- paste(
  "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"",
  "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\"",
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"",
  "xmlns:o=\"urn:schemas-microsoft-com:office:office\"",
  "xmlns:v=\"urn:schemas-microsoft-com:vml\"",
  "xmlns:w10=\"urn:schemas-microsoft-com:office:word\"",
  "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"",
  "xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"",
  "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"",
  sep = " "
)

# Bare XML prologue. Pandoc omits `standalone="yes"`; Word on macOS
# rejects standalone-declared OOXML when the package references
# external relationships (which every OOXML doc does). Match
# pandoc's prologue exactly.
.docx_xml_prologue <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

# Fixed mtime for every zip entry. The FAT filesystem epoch floor
# (1980-01-01 00:00:00 UTC) — anything earlier is invalid in a zip
# central directory. This is the OOXML reproducibility convention.
.docx_fixed_mtime <- as.POSIXct("1980-01-01 00:00:00", tz = "UTC")

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a `.docx` ZIP at `file`. Called by `emit()` via
# the backend registry. Returns the file path invisibly.
backend_docx <- function(grid, file) {
  entries <- if (identical(grid@metadata$content_type, "figure")) {
    .docx_figure_zip_entries(grid)
  } else {
    .docx_zip_entries(grid)
  }
  .docx_write_zip(entries, file)
  invisible(file)
}

# ---------------------------------------------------------------------
# Figure rendering (metadata$content_type == "figure")
# ---------------------------------------------------------------------

# Build the full OPC part set for a figure. Returns a named LIST whose
# text parts are UTF-8 strings and whose `word/media/image*` parts are raw
# image bytes (`.docx_write_zip` branches on `is.raw`). One image per page;
# footnotes trail each image in the body, the pagefoot band rides the page
# footer. This is the one DOCX path that embeds binary media + DrawingML.
.docx_figure_zip_entries <- function(grid) {
  meta <- grid@metadata
  pages <- grid@pages
  preset <- .docx_resolve_preset(meta$preset)
  cs <- meta$chrome_style %||% chrome_style()
  has_ph <- .page_band_is_populated(meta$pagehead_ast)
  has_footer <- .page_band_is_populated(meta$pagefoot_ast)

  n_img <- length(pages)
  rid_map <- .docx_figure_rid_map(has_ph, has_footer, n_img)
  exts <- vapply(pages, function(p) p$image_ext %||% "png", character(1))
  media_names <- sprintf("image%d.%s", seq_len(n_img), exts)

  doc_xml <- .docx_figure_document_xml(grid, preset, rid_map, media_names, cs)

  entries <- list(
    "[Content_Types].xml" = .docx_figure_content_types(
      has_ph,
      has_footer,
      unique(exts)
    ),
    "_rels/.rels" = .docx_root_rels(),
    "docProps/app.xml" = .docx_app_xml(),
    "docProps/core.xml" = .docx_core_xml(meta),
    "word/_rels/document.xml.rels" = .docx_figure_doc_rels(
      rid_map,
      media_names
    ),
    "word/document.xml" = doc_xml,
    "word/fontTable.xml" = .docx_font_table(preset),
    "word/settings.xml" = .docx_settings_xml(),
    "word/styles.xml" = .docx_styles_xml(preset),
    "word/theme/theme1.xml" = .docx_theme_xml(preset),
    "word/webSettings.xml" = .docx_web_settings_xml()
  )
  if (has_ph) {
    entries[["word/header1.xml"]] <- .docx_header_xml(
      meta$pagehead_ast,
      preset,
      cs = cs
    )
  }
  if (has_footer) {
    entries[["word/footer1.xml"]] <- .docx_footer_xml(
      meta$pagefoot_ast,
      preset,
      footnote_block = "",
      cs = cs
    )
  }
  # Raw media parts.
  for (i in seq_len(n_img)) {
    entries[[paste0("word/media/", media_names[[i]])]] <- pages[[
      i
    ]]$image_bytes
  }

  # OPC: [Content_Types].xml first, remainder alphabetical for determinism.
  ct_name <- "[Content_Types].xml"
  rest <- setdiff(names(entries), ct_name)
  entries[c(ct_name, sort(rest))]
}

# rId registry for a figure: the five fixed XML parts, optional header /
# footer, then one image rId per page.
.docx_figure_rid_map <- function(has_pagehead, has_pagefoot, n_images) {
  m <- list(
    styles = "rId1",
    settings = "rId2",
    theme = "rId3",
    fontTable = "rId4",
    webSettings = "rId5",
    header = NULL,
    footer = NULL,
    images = character()
  )
  next_id <- 6L
  if (has_pagehead) {
    m$header <- sprintf("rId%d", next_id)
    next_id <- next_id + 1L
  }
  if (has_pagefoot) {
    m$footer <- sprintf("rId%d", next_id)
    next_id <- next_id + 1L
  }
  if (n_images > 0L) {
    m$images <- sprintf("rId%d", seq.int(next_id, length.out = n_images))
  }
  m
}

# Document rels for a figure: the base part rels (reusing the table
# builder, no hyperlinks) plus one image relationship per page.
.docx_figure_doc_rels <- function(rid_map, media_names) {
  base <- .docx_doc_rels(character(), rid_map)
  img_rels <- vapply(
    seq_along(media_names),
    function(i) {
      sprintf(
        "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/%s\"/>",
        rid_map$images[[i]],
        media_names[[i]]
      )
    },
    character(1L)
  )
  sub(
    "</Relationships>",
    paste0(paste(img_rels, collapse = ""), "</Relationships>"),
    base,
    fixed = TRUE
  )
}

# Content types for a figure: the base set plus a `<Default>` per image
# extension so Word knows the media MIME type.
.docx_figure_content_types <- function(has_pagehead, has_pagefoot, exts) {
  ct <- .docx_content_types(has_pagehead, has_pagefoot)
  defaults <- character()
  if ("png" %in% exts) {
    defaults <- c(
      defaults,
      "<Default Extension=\"png\" ContentType=\"image/png\"/>"
    )
  }
  if (any(exts %in% c("jpeg", "jpg"))) {
    defaults <- c(
      defaults,
      "<Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/>",
      "<Default Extension=\"jpg\" ContentType=\"image/jpeg\"/>"
    )
  }
  if (length(defaults) == 0L) {
    return(ct)
  }
  sub(
    "</Types>",
    paste0(paste(defaults, collapse = ""), "</Types>"),
    ct,
    fixed = TRUE
  )
}

# Compose word/document.xml for a figure: per page, the title paragraphs,
# the image (a single-cell table sized to the body content box so the cell
# `<w:vAlign>` places it vertically and the paragraph `<w:jc>` horizontally),
# and the footnote paragraphs. A page break separates pages; the trailing
# `<w:sectPr>` carries page geometry + header / footer refs.
.docx_figure_document_xml <- function(
  grid,
  preset,
  rid_map,
  media_names,
  cs
) {
  pages <- grid@pages
  meta <- grid@metadata
  # Inter-section blank-line pads, resolved once from the spacing gaps
  # (`style()` per-surface override wins, else the preset `spacing` gap).
  # Footnotes follow the exact-height image table, so they bottom in the
  # content flow (the single shared footer1.xml cannot carry per-page
  # figure footnotes, so they are not routed through it).
  blank_p <- "<w:p/>"
  pad_above_title <- .docx_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_to_body <- .docx_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )
  pad_body_to_foot <- .docx_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )
  body_parts <- character()
  for (i in seq_along(pages)) {
    pg <- pages[[i]]
    if (i > 1L) {
      body_parts <- c(
        body_parts,
        "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
      )
    }
    title_block <- .docx_title_block(
      pg$titles_ast,
      character(),
      rid_map,
      preset = preset,
      cs = cs
    )
    titles <- if (length(pg$titles_ast) > 0L) {
      c(
        rep(blank_p, pad_above_title),
        title_block,
        rep(blank_p, pad_title_to_body)
      )
    } else {
      character()
    }
    drawing <- .docx_figure_drawing(
      rid_map$images[[i]],
      pg$draw_w_in,
      pg$draw_h_in,
      i
    )
    foot_block <- .docx_footnote_block(
      pg$footnotes_ast %||% list(),
      character(),
      rid_map,
      preset = preset,
      cs = cs
    )
    foot <- if (length(pg$footnotes_ast %||% list()) > 0L) {
      c(rep(blank_p, pad_body_to_foot), foot_block)
    } else {
      character()
    }
    body_parts <- c(
      body_parts,
      titles,
      .docx_figure_image_table(pg, drawing),
      foot
    )
  }
  body <- paste0(
    paste(body_parts, collapse = ""),
    .docx_section_pr(preset, rid_map)
  )
  paste0(
    .docx_xml_prologue,
    "<w:document ",
    .docx_ns_decls,
    "><w:body>",
    body,
    "</w:body></w:document>"
  )
}

# One image as an inline DrawingML `<w:drawing>`. EMU = inches * 914400.
# The blip's `r:embed` points at the page's image relationship.
.docx_figure_drawing <- function(rid, draw_w_in, draw_h_in, idx) {
  cx <- .docx_emu(draw_w_in)
  cy <- .docx_emu(draw_h_in)
  name <- sprintf("Figure %d", idx)
  paste0(
    "<w:drawing>",
    "<wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">",
    sprintf("<wp:extent cx=\"%d\" cy=\"%d\"/>", cx, cy),
    "<wp:effectExtent l=\"0\" t=\"0\" r=\"0\" b=\"0\"/>",
    sprintf("<wp:docPr id=\"%d\" name=\"%s\"/>", idx, name),
    "<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect=\"1\"/></wp:cNvGraphicFramePr>",
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">",
    "<pic:pic>",
    sprintf(
      "<pic:nvPicPr><pic:cNvPr id=\"%d\" name=\"%s\"/><pic:cNvPicPr/></pic:nvPicPr>",
      idx,
      name
    ),
    sprintf(
      "<pic:blipFill><a:blip r:embed=\"%s\"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>",
      rid
    ),
    sprintf(
      "<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"%d\" cy=\"%d\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr>",
      cx,
      cy
    ),
    "</pic:pic>",
    "</a:graphicData></a:graphic>",
    "</wp:inline></w:drawing>"
  )
}

# Single-cell table sized to the body content box, holding one figure's
# drawing. `<w:trHeight w:hRule="exact">` pins the row to the box height so
# the cell `<w:vAlign>` (valign) is exact; the paragraph `<w:jc>` (halign)
# positions the image horizontally within the cell.
.docx_figure_image_table <- function(pg, drawing) {
  place <- pg$place %||% list(halign = "center", valign = "middle")
  box_w <- as.integer(round(
    place$width_twips %||% .inches_to_twips(pg$draw_w_in)
  ))
  box_h <- as.integer(round(place$height_twips %||% 0))
  trheight <- if (box_h > 0L) {
    sprintf("<w:trHeight w:hRule=\"exact\" w:val=\"%d\"/>", box_h)
  } else {
    ""
  }
  valign_tok <- .docx_valign_token(place$valign %||% "middle")
  jc_tok <- .docx_align_token(place$halign %||% "center")
  paste0(
    "<w:tbl><w:tblPr>",
    sprintf("<w:tblW w:w=\"%d\" w:type=\"dxa\"/>", box_w),
    "<w:tblLayout w:type=\"fixed\"/>",
    "</w:tblPr>",
    sprintf("<w:tblGrid><w:gridCol w:w=\"%d\"/></w:tblGrid>", box_w),
    "<w:tr><w:trPr>",
    trheight,
    "</w:trPr>",
    "<w:tc><w:tcPr>",
    sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", box_w),
    valign_tok,
    "</w:tcPr>",
    "<w:p><w:pPr>",
    jc_tok,
    "</w:pPr>",
    "<w:r>",
    drawing,
    "</w:r>",
    "</w:p>",
    "</w:tc></w:tr></w:tbl>"
  )
}

# Inches -> EMU (English Metric Units). 1 inch = 914400 EMU.
.docx_emu <- function(inches) as.integer(round(inches * 914400))

# ---------------------------------------------------------------------
# Document assembly
# ---------------------------------------------------------------------

# Build the full set of OOXML files for this grid. Returns a named
# character vector (names = relative zip paths, values = file
# contents as UTF-8 strings). Pure — no I/O.
.docx_zip_entries <- function(grid) {
  meta <- grid@metadata
  preset <- .docx_resolve_preset(meta$preset)
  cs <- meta$chrome_style %||% chrome_style()
  has_ph <- .page_band_is_populated(meta$pagehead_ast)
  has_pf_band <- .page_band_is_populated(meta$pagefoot_ast)

  # Footnote placement (RTF parity): `repeat_footnotes` (the
  # `paginate(repeat_content)` "footnotes" member, default TRUE) puts
  # the footnote block into the repeating `footer1.xml` so Word renders
  # it at the foot of EVERY page; FALSE trails it in the body (final
  # page only). The page footer therefore exists whenever a `pagefoot`
  # band is set OR footnotes ride the footer.
  rep_footnotes <- meta$repeat_footnotes %||% TRUE
  has_footnotes <- length(meta$footnotes_ast %||% list()) > 0L
  footer_footnotes <- has_footnotes && isTRUE(rep_footnotes)
  has_footer <- has_pf_band || footer_footnotes

  # One-pass hyperlink walk over every AST surface so the rels file
  # and the inline renderer agree on rId numbering. First-encounter
  # order is deterministic given the walk order in
  # `.docx_collect_hyperlinks()`.
  hyperlinks <- .docx_collect_hyperlinks(grid)
  rid_map <- .docx_rid_map(has_ph, has_footer, length(hyperlinks))

  # Build the footnote section once. It lands in the body when
  # trailing, or in `footer1.xml` when repeating; never both.
  foot_section <- if (has_footnotes) {
    .docx_footnote_section(grid, preset, hyperlinks, rid_map, cs)
  } else {
    ""
  }
  body_footnotes <- if (footer_footnotes) "" else foot_section
  footer_foot_block <- if (footer_footnotes) foot_section else ""

  entries <- c(
    "[Content_Types].xml" = .docx_content_types(has_ph, has_footer),
    "_rels/.rels" = .docx_root_rels(),
    "docProps/app.xml" = .docx_app_xml(),
    "docProps/core.xml" = .docx_core_xml(meta),
    "word/_rels/document.xml.rels" = .docx_doc_rels(
      hyperlinks,
      rid_map
    ),
    "word/document.xml" = .docx_document_xml(
      grid,
      preset,
      hyperlinks,
      rid_map,
      body_footnotes = body_footnotes
    ),
    "word/fontTable.xml" = .docx_font_table(preset),
    "word/settings.xml" = .docx_settings_xml(),
    "word/styles.xml" = .docx_styles_xml(preset),
    "word/theme/theme1.xml" = .docx_theme_xml(preset),
    "word/webSettings.xml" = .docx_web_settings_xml()
  )
  if (has_ph) {
    entries[["word/header1.xml"]] <- .docx_header_xml(
      meta$pagehead_ast,
      preset,
      cs = cs
    )
  }
  if (has_footer) {
    entries[["word/footer1.xml"]] <- .docx_footer_xml(
      meta$pagefoot_ast,
      preset,
      footnote_block = footer_foot_block,
      cs = cs
    )
  }
  # OPC (Open Packaging Conventions) MANDATES that `[Content_Types].xml`
  # is the FIRST part in the ZIP central directory. Word and many
  # OOXML parsers reject the archive otherwise. We pin it first
  # explicitly, then sort the remainder alphabetically for
  # determinism.
  ct_name <- "[Content_Types].xml"
  rest <- setdiff(names(entries), ct_name)
  ordered <- c(ct_name, sort(rest))
  entries[ordered]
}

# Resolve the active preset, falling back to factory defaults when
# the grid carries no preset attachment (matches every other
# backend's pattern).
.docx_resolve_preset <- function(preset) {
  if (is.null(preset) || !is_preset_spec(preset)) preset_spec() else preset
}

# Compute the per-document rId registry. Word on macOS schema-
# validates relationship IDs against the conventional `rId<N>`
# (1-indexed integers) pattern; semantic IDs like `rIdH` /
# `rIdLink1` parse-fail. Numeric rIds are assigned in a fixed
# order:
#
#   rId1 styles | rId2 settings | rId3 theme | rId4 fontTable | rId5 webSettings
#   rId6  header   (only when pagehead populated)
#   rId7  footer   (only when pagefoot populated; rId6 if header absent)
#   rId(next..)    one per unique external hyperlink, in first-
#                  encounter order from `.docx_collect_hyperlinks()`.
#
# Returns a list:
#   $styles / $settings / $theme / $fontTable / $webSettings  one rId each
#   $header / $footer    one rId each (NULL when absent)
#   $hyperlinks          character() of rIds, parallel to the URL vector
.docx_rid_map <- function(has_pagehead, has_pagefoot, n_hyperlinks) {
  m <- list(
    styles = "rId1",
    settings = "rId2",
    theme = "rId3",
    fontTable = "rId4",
    webSettings = "rId5",
    header = NULL,
    footer = NULL,
    hyperlinks = character()
  )
  next_id <- 6L
  if (has_pagehead) {
    m$header <- sprintf("rId%d", next_id)
    next_id <- next_id + 1L
  }
  if (has_pagefoot) {
    m$footer <- sprintf("rId%d", next_id)
    next_id <- next_id + 1L
  }
  if (n_hyperlinks > 0L) {
    m$hyperlinks <- sprintf(
      "rId%d",
      seq.int(next_id, length.out = n_hyperlinks)
    )
  }
  m
}

# Compose `word/document.xml`. Body is: title block (page-1
# centred + bold) -> table (one `<w:tbl>` containing header bands +
# column labels + all body rows from grid@pages, with `<w:tblHeader/>`
# on header rows so Word naturally repeats them on page-break) ->
# footnote block -> trailing `<w:sectPr>` carrying page geometry.
# Inline AST runs through `.render_docx_inline()` everywhere user
# content appears (titles, footnotes, col labels, body cells).
# Commits 4-5 wire page chrome refs and per-cell styling.
.docx_document_xml <- function(
  grid,
  preset,
  hyperlinks,
  rid_map,
  body_footnotes = ""
) {
  meta <- grid@metadata
  cs <- meta$chrome_style %||% chrome_style()
  blank_p <- "<w:p/>"
  pad_title_top <- .docx_blank_count(
    cs,
    "title",
    "above",
    .meta_gap(meta, "above_title", 1L)
  )
  pad_title_bottom <- .docx_blank_count(
    cs,
    "title",
    "below",
    .meta_gap(meta, "title_to_body", 1L)
  )

  # Title placement (RTF parity): `repeat_titles` (the
  # `paginate(repeat_content)` "titles" member, default TRUE) renders
  # titles as merged `<w:tblHeader/>` rows at the top of the table, so
  # Word repeats them at every page break; FALSE renders them as
  # paragraphs above the table (page 1 only). Either way the toprule
  # still rides the column-header block, below the titles.
  rep_titles <- meta$repeat_titles %||% TRUE
  titles_ast <- meta$titles_ast %||% list()
  title_in_table <- length(titles_ast) > 0L && isTRUE(rep_titles)

  titles_block <- character()
  if (length(titles_ast) > 0L && !isTRUE(rep_titles)) {
    titles_block <- c(
      rep(blank_p, pad_title_top),
      .docx_title_block(
        titles_ast,
        hyperlinks,
        rid_map,
        preset = preset,
        cs = cs
      ),
      rep(blank_p, pad_title_bottom)
    )
  }
  # One `<w:tbl>` per horizontal panel: each panel pins its own column
  # set, so panel 2's body rows can no longer render under panel 1's
  # grid/header. Word paginates the body within a panel via
  # `<w:tblHeader/>` + `<w:cantSplit/>`; subgroups stay inline within a
  # panel's table (the banner rows in `.render_docx_body_rows`). Panels
  # are separated by a next-page section break (see below). When
  # `repeat_titles` is set
  # (the `repeat_content` default), the title block rides EVERY panel's
  # table as `<w:tblHeader/>` rows so it repeats on every panel page,
  # matching RTF; otherwise it renders once as paragraphs above panel 1
  # (`titles_block`). An empty grid falls through one call so the
  # "(no rows)" marker still appears.
  # Any active subgroup (not only the per-page BigN case) renders one
  # `<w:tbl>` per subgroup so its banner can lead ABOVE the column-header
  # band (anatomy), matching RTF / PDF. Inline body banners landed below
  # the header and duplicated as repeating `<w:tblHeader/>` rows.
  sg_active <- any(vapply(
    grid@pages,
    function(p) !is.null(p$subgroup_index),
    logical(1L)
  ))
  panel_groups <- .group_pages_into_panels(
    grid@pages,
    by_subgroup = isTRUE(grid@metadata$subgroup_big_n_active) || sg_active
  )
  if (length(panel_groups) <= 1L) {
    table_block <- .render_docx_table(
      grid,
      preset,
      hyperlinks,
      rid_map,
      cs = cs,
      title_ast = if (title_in_table) titles_ast else list(),
      pad_title_top = pad_title_top,
      pad_title_bottom = pad_title_bottom
    )
  } else {
    # Separate panels with a next-page SECTION break (a paragraph
    # carrying the section's `<w:sectPr>`), placed AFTER each panel
    # except the last. The section mark forces the next panel onto a
    # fresh page AND keeps Word from merging the two `<w:tbl>`
    # elements, with no visible blank line above the next panel's
    # title -- an empty `pageBreakBefore` paragraph would render as a
    # leading blank line. Mirrors RTF's `\sect` per panel; the final
    # panel is closed by the body-level `sect_pr` appended downstream.
    sect_break <- paste0(
      "<w:p><w:pPr>",
      .docx_section_pr(preset, rid_map),
      "</w:pPr></w:p>"
    )
    n_panels <- length(panel_groups)
    panel_tables <- vapply(
      seq_along(panel_groups),
      function(gi) {
        panel_grid <- S7::set_props(grid, pages = panel_groups[[gi]])
        tbl <- .render_docx_table(
          panel_grid,
          preset,
          hyperlinks,
          rid_map,
          cs = cs,
          title_ast = if (title_in_table) titles_ast else list(),
          pad_title_top = pad_title_top,
          pad_title_bottom = pad_title_bottom
        )
        if (gi < n_panels) paste0(tbl, sect_break) else tbl
      },
      character(1L)
    )
    table_block <- paste(panel_tables, collapse = "")
  }
  sect_pr <- .docx_section_pr(preset, rid_map)

  body <- paste0(
    paste(titles_block, collapse = ""),
    table_block,
    body_footnotes,
    sect_pr
  )
  paste0(
    .docx_xml_prologue,
    "<w:document ",
    .docx_ns_decls,
    "><w:body>",
    body,
    "</w:body></w:document>"
  )
}

# Render the title block: one paragraph per title, each tagged
# with the `TabularTitle` named style (centred + bold; defined in
# styles.xml). Inline AST flows through `.render_docx_inline()`.
# The style supplies bold so we don't need a `default_rpr`; nested
# bold/italic/sup runs still compound via inline `<w:rPr>` tokens.
.docx_title_block <- function(
  titles_ast,
  hyperlinks,
  rid_map = NULL,
  preset = NULL,
  cs = NULL
) {
  n <- length(titles_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  title_rpr <- .docx_rPr_from_style(surface_node, preset = preset)
  vapply(
    seq_len(n),
    function(i) {
      runs <- .render_docx_inline(
        titles_ast[[i]],
        hyperlinks,
        default_rpr = title_rpr,
        rid_map = rid_map
      )
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        .effective_title_halign(preset, line_index = i, n_lines = n)
      }
      jc_override <- if (length(halign) == 1L && !is.na(halign)) {
        .docx_align_token(halign)
      } else {
        ""
      }
      paste0(
        "<w:p><w:pPr><w:pStyle w:val=\"TabularTitle\"/>",
        jc_override,
        "</w:pPr>",
        runs,
        "</w:p>"
      )
    },
    character(1L)
  )
}

# Render the title block as merged full-width table rows for the
# repeating-titles path. Each title is one `<w:tr>` carrying
# `<w:tblHeader/>` (so Word repeats it at every page break) and a
# single `<w:gridSpan>` cell spanning all visible columns, centred +
# bold via the `TabularTitle` paragraph style. `pad_top` / `pad_bottom`
# blank `<w:tblHeader/>` rows reproduce the title block's vertical
# spacing inside the table. Mirrors RTF's `.rtf_title_header_rows` +
# `.rtf_blank_trhdr_rows`. Returns "" when there are no titles.
.docx_title_header_rows <- function(
  titles_ast,
  total_twips,
  n_cols,
  pad_top = 0L,
  pad_bottom = 0L,
  hyperlinks = character(),
  rid_map = NULL,
  preset = NULL,
  cs = NULL
) {
  n <- length(titles_ast)
  if (n == 0L) {
    return("")
  }
  blank_row <- .docx_full_width_row(total_twips, n_cols, "<w:p/>")
  surface_node <- .chrome_surface_at(cs, "title")
  title_rpr <- .docx_rPr_from_style(surface_node, preset = preset)
  title_rows <- vapply(
    seq_len(n),
    function(i) {
      # Reuse the TabularTitle paragraph style (centred + bold) so the
      # repeating title rows render identically to the paragraph path
      # (`.docx_title_block`); the per-line halign cascade overrides it.
      runs <- .render_docx_inline(
        titles_ast[[i]],
        hyperlinks,
        default_rpr = title_rpr,
        rid_map = rid_map
      )
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        .effective_title_halign(preset, line_index = i, n_lines = n)
      }
      jc_override <- if (length(halign) == 1L && !is.na(halign)) {
        .docx_align_token(halign)
      } else {
        ""
      }
      para <- paste0(
        "<w:p><w:pPr><w:pStyle w:val=\"TabularTitle\"/>",
        jc_override,
        "</w:pPr>",
        runs,
        "</w:p>"
      )
      # Title border (block edges) + background from the title surface
      # node. No region channel for the title, so the surface node is the
      # only path; no double-emission.
      tc_extra <- .docx_chrome_row_tc_extra(surface_node, i, n)
      .docx_full_width_row(total_twips, n_cols, para, tc_extra = tc_extra)
    },
    character(1L)
  )
  paste0(
    paste(rep(blank_row, pad_top), collapse = ""),
    paste(title_rows, collapse = ""),
    paste(rep(blank_row, pad_bottom), collapse = "")
  )
}

# One full-width `<w:tr>` carrying `<w:tblHeader/>` and a single
# `<w:gridSpan>` cell spanning every visible column. Used for the
# repeating title rows and their blank spacing rows. `tc_extra` injects
# additional `<w:tcPr>` children (borders + shading) AFTER `gridSpan`
# in canonical CT_TcPr order; default "" keeps blank spacing rows bare.
.docx_full_width_row <- function(
  total_twips,
  n_cols,
  content,
  tc_extra = ""
) {
  span <- if (n_cols > 1L) {
    sprintf("<w:gridSpan w:val=\"%d\"/>", n_cols)
  } else {
    ""
  }
  paste0(
    "<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:tcPr>",
    sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", total_twips),
    span,
    tc_extra,
    "</w:tcPr>",
    content,
    "</w:tc></w:tr>"
  )
}

# Build the `<w:tcBorders>` + `<w:shd>` `<w:tcPr>` children (canonical
# order) for a merged full-width chrome row (e.g. a title row) from its
# surface `style_node`. Block-edge semantics: `top` rides the first row
# (i == 1), `bottom` the last (i == n); `left` / `right` ride every row.
# `skip` names sides already drawn by a region channel. Returns "" when
# the node carries no border or background (byte-identical default).
.docx_chrome_row_tc_extra <- function(node, i, n, skip = character()) {
  if (!is_style_node(node)) {
    return("")
  }
  want <- function(side) {
    !(side %in% skip) &&
      (side != "top" || i == 1L) &&
      (side != "bottom" || i == n)
  }
  edge <- function(side) {
    if (!want(side)) {
      return("")
    }
    brd <- .effective_border(side, node)
    if (is.null(brd) || identical(brd$style, "none")) {
      return("")
    }
    sprintf("<w:%s w:space=\"0\" %s/>", side, .docx_border_attrs(brd))
  }
  borders <- .docx_tcborders(
    edge("top"),
    edge("left"),
    edge("bottom"),
    edge("right")
  )
  paste0(borders, .docx_shd_from_style(node))
}

# Resolve the blank-line count for a chrome surface side. chrome_style
# wins when the user set `style(blank_above = N, at = cells_title())`;
# otherwise the legacy preset `*_pad_*` scalar fills in.
.docx_blank_count <- function(cs, surface, side, legacy) {
  node <- .chrome_surface_at(cs, surface)
  prop <- if (identical(side, "above")) node@blank_above else node@blank_below
  if (length(prop) == 1L && !is.na(prop)) {
    return(max(0L, as.integer(prop)))
  }
  max(0L, as.integer(legacy))
}

# Render the footnote block: one paragraph per footnote, each
# tagged with the `TabularFoot` named style (left-aligned; defined
# in styles.xml). Per-line horizontal alignment from the cascade
# (chrome_style$surfaces$footer@halign) overrides the style default
# when set. Inline AST flows through `.render_docx_inline()` so
# bold / italic / sup / link markup all surface in the .docx.
.docx_footnote_block <- function(
  footnotes_ast,
  hyperlinks,
  rid_map = NULL,
  preset = NULL,
  cs = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  foot_rpr <- .docx_rPr_from_style(surface_node, preset = preset)
  vapply(
    seq_len(n),
    function(i) {
      runs <- .render_docx_inline(
        footnotes_ast[[i]],
        hyperlinks,
        default_rpr = foot_rpr,
        rid_map = rid_map
      )
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
      jc_override <- if (length(halign) == 1L && !is.na(halign)) {
        .docx_align_token(halign)
      } else {
        ""
      }
      paste0(
        "<w:p><w:pPr><w:pStyle w:val=\"TabularFoot\"/>",
        jc_override,
        "</w:pPr>",
        runs,
        "</w:p>"
      )
    },
    character(1L)
  )
}

# Build the footnote-section opening rule (`footnoterule`) as a
# table-width single-cell `<w:tbl>` carrying a top border, placed just
# above the footnote paragraphs. OFF by default (the body `bottomrule`
# is the mutually-exclusive default closer). A paragraph border
# (`<w:pBdr>`) would span the full page text column (margin to margin);
# a 1-cell table sized to the table grid keeps the rule at TABLE width,
# matching the LaTeX foot-template rule and the RTF merged-row rule.
# NULL / "none" triple, or a non-positive width -> no rule.
.docx_foot_rule_table <- function(triple, total_twips) {
  if (
    is.null(triple) ||
      identical(triple$style, "none") ||
      total_twips <= 0L
  ) {
    return(character())
  }
  attrs <- .docx_border_attrs(triple)
  paste0(
    "<w:tbl>",
    "<w:tblPr><w:tblW w:w=\"",
    total_twips,
    "\" w:type=\"dxa\"/></w:tblPr>",
    "<w:tblGrid><w:gridCol w:w=\"",
    total_twips,
    "\"/></w:tblGrid>",
    "<w:tr><w:tc><w:tcPr><w:tcW w:w=\"",
    total_twips,
    "\" w:type=\"dxa\"/>",
    "<w:tcBorders><w:top w:space=\"0\" ",
    attrs,
    "/></w:tcBorders></w:tcPr><w:p/></w:tc></w:tr>",
    "</w:tbl>"
  )
}

# Build the footnote section as one XML string: an optional
# table-width separator rule (chrome `footer_top`, opt-in) above the
# footnote paragraphs. "" when no footnotes. The SAME section lands in
# the body (`trailing_footnotes`) or in `footer1.xml`
# (`footer_footnotes`), so both placements render identically. Mirrors
# RTF's `.render_rtf_footnote_block`.
.docx_footnote_section <- function(grid, preset, hyperlinks, rid_map, cs) {
  meta <- grid@metadata
  paras <- .docx_footnote_block(
    meta$footnotes_ast %||% list(),
    hyperlinks,
    rid_map,
    preset = preset,
    cs = cs
  )
  if (length(paras) == 0L) {
    return("")
  }
  pages <- grid@pages
  rule_tbl <- character()
  if (length(pages) > 0L) {
    foot_triple <- .chrome_border_at(cs, "footer_top")
    widths <- .docx_col_widths_twips(
      pages[[1L]]$col_names,
      meta$cols %||% list(),
      preset
    )
    rule_tbl <- .docx_foot_rule_table(foot_triple, sum(widths))
  }
  # Blank line(s) above the footnote block: the footer surface's
  # `blank_above` (set via `style(blank_above = N, .at =
  # cells_footnotes())`) wins, else the `body_to_footnote` spacing gap.
  # Lets `preset_minimal()` separate the footnotes from the body once
  # the bottomrule is gone.
  blank_above <- .docx_blank_count(
    cs,
    "footer",
    "above",
    .meta_gap(meta, "body_to_footnote", 0L)
  )
  paste0(
    paste(rep("<w:p/>", blank_above), collapse = ""),
    paste(rule_tbl, collapse = ""),
    paste(paras, collapse = "")
  )
}

# ---------------------------------------------------------------------
# Table emission
# ---------------------------------------------------------------------

# Page grouping uses the shared `.group_pages_into_panels()`
# (R/as_grid.R). DOCX passes `by_subgroup = FALSE` normally (subgroups
# stay inline in one table per panel) and `TRUE` under per-page BigN
# (each subgroup gets its own `<w:tbl>` so its `(N=x)` header leads the
# table and Word repeats it on every page).

# Compose one `<w:tbl>` for the pages in `grid` (one horizontal panel
# after grouping). Renders: multi-level header bands -> column-labels
# row -> body rows concatenated across this panel's `grid@pages`
# entries. Header rows carry `<w:tblHeader/>` so Word repeats them
# after every page break it computes on its own. Caller emits one
# table per panel and inserts the inter-panel page break.
#
# Width consumption: every visible col_spec@width (numeric inches,
# engine-resolved) -> twips via `.tabular_unit_twips[["in"]] = 1440`.
# Fallback for any column lacking a resolved width: equal share of
# the printable area (so the document still renders rather than
# emitting `<w:gridCol w:w="0">`).
#
# Empty grid (zero pages): emit a left-aligned "(no rows)" paragraph
# instead of an empty table. Matches the RTF backend's `\plain\qc`
# behaviour and avoids Word's empty-table-row glitch.
.render_docx_table <- function(
  grid,
  preset,
  hyperlinks = character(),
  rid_map = NULL,
  cs = NULL,
  title_ast = list(),
  pad_title_top = 0L,
  pad_title_bottom = 0L
) {
  meta <- grid@metadata
  pages <- grid@pages
  if (
    length(pages) == 0L ||
      (isTRUE(pages[[1L]]$is_empty_page) &&
        length(pages[[1L]]$col_names) == 0L)
  ) {
    # No column structure (a hand-built zero-page grid, or every column
    # hidden): the empty message stands alone as a centred paragraph.
    msg_runs <- if (is.null(meta$empty_text_ast)) {
      "<w:r><w:t xml:space=\"preserve\">No data available to report</w:t></w:r>"
    } else {
      .render_docx_inline(meta$empty_text_ast)
    }
    jc <- .docx_align_token(meta$empty_place$halign %||% "center")
    return(paste0("<w:p><w:pPr>", jc, "</w:pPr>", msg_runs, "</w:p>"))
  }
  col_names_vis <- pages[[1L]]$col_names
  cols <- meta$cols %||% list()
  widths <- .docx_col_widths_twips(col_names_vis, cols, preset)
  # Frame outer LEFT / RIGHT edges, applied structurally to the first /
  # last cell of every table-proper row (`<w:tblBorders>` is out: the
  # title rows live inside this same `<w:tbl>` and must stay outside the
  # box). The manifest is the SSOT; NULL when the frame is off.
  body_borders <- meta$body_borders %||% list()

  # Repeating titles: merged `<w:tblHeader/>` rows at the top of the
  # table (RTF's `\trhdr` title rows), so Word repeats the title block
  # at every page break. Empty when `repeat_titles` is FALSE (titles
  # then render as paragraphs above the table in `.docx_document_xml`).
  title_rows <- .docx_title_header_rows(
    title_ast,
    sum(widths),
    length(widths),
    pad_title_top,
    pad_title_bottom,
    hyperlinks,
    rid_map,
    preset = preset,
    cs = cs
  )

  # Structural rules from the SSOT chrome regions (RTF parity): the
  # toprule (`header_top`) rides the first row of the column-header
  # block; the midrule (`header_bottom`) closes the column-label band.
  # Both default solid and are suppressed only on an explicit "none".
  # The outer-frame `outer_top` triple wins over the chrome `header_top`
  # rule, so `cells_table(side = "outer")` thickens the column-header band's
  # top (the table top) rather than a body row.
  outer_top_triple <- if (is.list(body_borders)) {
    body_borders[["outer_top"]]
  } else {
    NULL
  }
  top_el <- if (!is.null(outer_top_triple)) {
    .docx_border_seg_from_triple(outer_top_triple, "top")
  } else {
    .docx_chrome_border_seg(cs, "header_top", "top")
  }
  mid_el <- .docx_chrome_border_seg(cs, "header_bottom", "bottom")

  # Resolve the header source once via the shared per-page resolver:
  # under per-page BigN it returns this segment's SUFFIXED bands + leaf
  # labels (each `<w:tbl>` is one subgroup), otherwise the global base
  # header. `.page_header_for_render` returns the global metadata when
  # big_n is off, so the non-big_n path is byte-identical.
  big_n_active <- isTRUE(meta$subgroup_big_n_active)
  first_page <- pages[[1L]]
  # A subgroup is active for this table when its lead page carries a
  # banner AST. Such tables lead with the banner above the header band
  # (RTF / PDF parity) even without per-page BigN; only the `(N=x)`
  # header suffix is BigN-specific.
  subgroup_active <- !is.null(first_page$subgroup_line_ast)
  hdr <- .page_header_for_render(meta, first_page)
  has_bands <- is.data.frame(hdr$headers) && nrow(hdr$headers) > 0L

  # Per-page BigN: lead the table with the SUFFIXED header in canonical
  # order (banner, then spanner bands, then column labels). Because the
  # block leads the table, Word repeats it on every continuation page,
  # so the `(N=x)` header and its banner reprint on every page, matching
  # RTF / PDF. The next-page section break between segments owns the
  # page break, so the lead banner must not also force one, and the body
  # drops the banner (`emit_banner = FALSE`) to avoid duplicating it.
  banner_lead <- if (big_n_active || subgroup_active) {
    banner <- .render_docx_subgroup_banner_row(
      first_page$subgroup_line_ast,
      n_cols = length(col_names_vis),
      widths_twips = widths,
      page_break_before = FALSE,
      preset = preset,
      cs = cs,
      body_borders = body_borders
    )
    # Blank rows above and below the banner (anatomy). `.docx_full_width_row`
    # carries `<w:tblHeader/>`, so they repeat per page with the banner. The
    # counts come from the `subgroup` spacing gaps (default 1/1, so output is
    # unchanged; a `spacing` knob now tunes the banner gap).
    blank <- .docx_full_width_row(
      sum(widths),
      length(col_names_vis),
      "<w:p/>"
    )
    c(
      rep(blank, .meta_gap(meta, "subgroup_above", 1L)),
      banner,
      rep(blank, .meta_gap(meta, "subgroup_to_body", 1L))
    )
  } else {
    character()
  }
  band_rows <- .render_docx_header_bands(
    hdr$headers,
    col_names_vis,
    widths,
    cs = cs,
    top_border = top_el,
    body_borders = body_borders
  )
  label_row <- .render_docx_col_labels_row(
    hdr$col_labels_ast,
    col_names_vis,
    cols,
    widths,
    hyperlinks,
    rid_map,
    preset = preset,
    cs = cs,
    top_border = if (has_bands) "" else top_el,
    bottom_border = mid_el,
    body_borders = body_borders
  )
  body_rows <- .render_docx_body_rows(
    pages,
    col_names_vis,
    cols,
    widths,
    preset = preset,
    cs = cs,
    body_borders = body_borders,
    emit_banner = !(big_n_active || subgroup_active)
  )

  # Zero-row page with visible columns: the header band above is intact;
  # the body is one full-span message row sized to the content-box for
  # exact vertical centering (see `.render_docx_empty_row`).
  empty_row <- if (isTRUE(pages[[1L]]$is_empty_page)) {
    .render_docx_empty_row(
      meta$empty_text_ast,
      meta$empty_place,
      length(col_names_vis),
      widths,
      preset = preset,
      body_borders = body_borders
    )
  } else {
    character()
  }

  paste0(
    "<w:tbl>",
    .docx_tbl_pr(sum(widths)),
    .docx_tbl_grid(widths),
    title_rows,
    paste(banner_lead, collapse = ""),
    paste(band_rows, collapse = ""),
    label_row,
    paste(body_rows, collapse = ""),
    paste(empty_row, collapse = ""),
    "</w:tbl>"
  )
}

# Resolve every visible column to a positive integer twips width.
# Engine pre-resolves `col_spec@width` to numeric inches; we
# convert to twips here. Fallback (column without a resolved
# col_spec or width): equal share of printable area, floored at
# 720 twips (0.5 in) so the column doesn't collapse to a sliver.
#
# **Boundary-snapping for cross-backend parity.** Each column's
# final twip width is the diff of cumulative-then-rounded boundary
# positions, NOT a per-column round. This matches RTF's
# `.rtf_cellx_positions()` exactly, so the same engine inches
# produce byte-for-byte equal widths across RTF (\cellx) and DOCX
# (<w:gridCol>). Per-column rounding would diverge by +/- 1 twip on
# any column whose cumulative boundary crosses a 0.5-twip mark.
.docx_col_widths_twips <- function(col_names_vis, cols, preset) {
  paper <- .docx_paper_twips(preset@paper_size, preset@orientation)
  margins <- .docx_margins_twips(preset@margins)
  printable <- paper$width - margins$left - margins$right
  n <- length(col_names_vis)
  if (n == 0L) {
    return(integer(0L))
  }
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
  # Boundary-snap to match RTF: cumsum -> round -> diff yields each
  # column's twip width as the difference of integer boundary
  # positions, so cumulative drift never exceeds 0.5 twips.
  positions <- as.integer(round(cumsum(widths)))
  as.integer(diff(c(0L, positions)))
}

# Compose the `<w:tblPr>` block: fixed-width layout (so engine
# widths are honoured verbatim, not auto-resized by Word) + table
# total width in twips + centred on the page (`<w:jc w:val="center"/>`,
# the OOXML twin of RTF's `\trqc`). `<w:tblBorders>` is omitted; rules
# live on individual cells (per-cell rule_above / rule_below + the
# chrome toprule / midrule / bottomrule).
.docx_tbl_pr <- function(total_twips) {
  paste0(
    "<w:tblPr>",
    sprintf("<w:tblW w:w=\"%d\" w:type=\"dxa\"/>", total_twips),
    "<w:jc w:val=\"center\"/>",
    "<w:tblLayout w:type=\"fixed\"/>",
    "</w:tblPr>"
  )
}

# Compose the `<w:tblGrid>` block carrying one `<w:gridCol>` per
# visible column. Widths are twips integers (engine-resolved).
.docx_tbl_grid <- function(widths_twips) {
  cols <- vapply(
    widths_twips,
    function(w) sprintf("<w:gridCol w:w=\"%d\"/>", w),
    character(1L)
  )
  paste0("<w:tblGrid>", paste(cols, collapse = ""), "</w:tblGrid>")
}

# Render multi-level header bands. For each band depth we walk
# visible columns left-to-right, group contiguous runs sharing the
# same band label (or no band), and emit one `<w:tc>` per run with
# `<w:gridSpan w:val="N"/>` for runs wider than one column. Returns
# a character vector of `<w:tr>` strings (one per depth).
.render_docx_header_bands <- function(
  headers,
  col_names_vis,
  widths_twips,
  cs = NULL,
  top_border = "",
  body_borders = NULL
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  out <- character()
  # Band underline = the SSOT `spanrule` (chrome region `header_between`,
  # muted by default), so band overrides + the "none" clear take effect
  # and DOCX matches the LaTeX / HTML muted band. NULL / "none" -> the
  # band cells stay borderless. Held as the bare `<w:bottom>` element so
  # it composes with the toprule top element in one `<w:tcBorders>`.
  span_triple <- .chrome_border_at(cs, "header_between")
  span_bottom <- if (
    is.null(span_triple) || identical(span_triple$style, "none")
  ) {
    ""
  } else {
    sprintf("<w:bottom w:space=\"0\" %s/>", .docx_border_attrs(span_triple))
  }
  for (d in depths) {
    # Toprule (chrome `header_top`) rides every cell of the topmost band
    # row across the full table width, including blank flanking cells.
    is_first_depth <- d == depths[[1L]]
    labels <- .band_labels_for_depth(headers, d, col_names_vis)
    runs <- .group_contiguous_runs(labels)
    cells <- character(length(runs))
    cursor <- 1L
    for (i in seq_along(runs)) {
      run <- runs[[i]]
      span <- run$length
      end <- cursor + span - 1L
      cell_w <- sum(widths_twips[cursor:end])
      label <- run$value
      # Band cells carry the span-rule bottom border (cmidrule(lr) cell
      # semantics); blank flanking cells over unmapped columns omit it so
      # the rule does not extend across the full width. The toprule top
      # rides every cell of the first band row.
      top_part <- if (is_first_depth) top_border else ""
      bottom_part <- if (!is.na(label)) span_bottom else ""
      # Outer frame edges: left on the first run, right on the last run,
      # placed in canonical CT_TcBorders order (top, left, bottom, right).
      left_part <- if (i == 1L) .docx_frame_edge("left", body_borders) else ""
      right_part <- if (i == length(runs)) {
        .docx_frame_edge("right", body_borders)
      } else {
        ""
      }
      tc_borders <- .docx_tcborders(
        top_part,
        left_part,
        bottom_part,
        right_part
      )
      # Header surface drives the band background (so a coloured band
      # reads end-to-end, including the empty flanking cells) and the
      # header padding override. `<w:shd>` follows `<w:tcBorders>` and
      # precedes `<w:tcMar>` in CT_TcPr order. preset = NULL on tcMar so
      # only the header padding override emits (no body-padding bleed).
      header_surface <- .chrome_surface_at(cs, "header")
      band_shd <- .docx_shd_from_style(header_surface)
      band_rpr <- .docx_rPr_from_style(header_surface, bold_default = TRUE)
      tc_mar <- .docx_tcMar_from_style(header_surface, NULL)
      tc_pr <- paste0(
        "<w:tcPr>",
        sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", cell_w),
        if (span > 1L) sprintf("<w:gridSpan w:val=\"%d\"/>", span) else "",
        tc_borders,
        band_shd,
        tc_mar,
        "</w:tcPr>"
      )
      content <- if (is.na(label)) {
        "<w:p/>"
      } else {
        # Split on embedded newlines so a multi-line band label (e.g. a
        # per-page BigN `\n(N=x)` suffix) breaks inside the cell via
        # `<w:br/>`. A single-line label yields exactly one run, byte-
        # identical to the prior output (and footnote-sentinel-agnostic,
        # unlike `.docx_body_runs`).
        parts <- strsplit(
          gsub("\r\n", "\n", label, fixed = TRUE),
          "\n",
          fixed = TRUE
        )[[1L]]
        if (length(parts) == 0L) {
          parts <- ""
        }
        # NB: not named `runs` — the enclosing band loop owns a `runs`
        # list it iterates via `runs[[i]]`.
        label_runs <- paste0(
          vapply(
            parts,
            function(p) {
              paste0(
                "<w:r><w:rPr>",
                band_rpr,
                "</w:rPr>",
                "<w:t xml:space=\"preserve\">",
                .docx_escape(p),
                "</w:t></w:r>"
              )
            },
            character(1L),
            USE.NAMES = FALSE
          ),
          collapse = "<w:r><w:br/></w:r>"
        )
        paste0(
          "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>",
          label_runs,
          "</w:p>"
        )
      }
      cells[[i]] <- paste0("<w:tc>", tc_pr, content, "</w:tc>")
      cursor <- end + 1L
    }
    out <- c(
      out,
      paste0(
        "<w:tr><w:trPr><w:tblHeader/></w:trPr>",
        paste(cells, collapse = ""),
        "</w:tr>"
      )
    )
  }
  out
}

# Render the column-labels row: one `<w:tc>` per visible column,
# alignment via the header cascade (col_spec@align / @valign >
# chrome_style$surfaces$header@halign / header_valign > Word default).
# Label flow from the inline AST through `.render_docx_inline()`.
# Default run formatting is bold (clinical header convention).
# Header row carries `<w:tblHeader/>` for Word's auto-repeat across
# pagination.
.render_docx_col_labels_row <- function(
  col_labels_ast,
  col_names_vis,
  cols,
  widths_twips,
  hyperlinks,
  rid_map = NULL,
  preset = NULL,
  cs = NULL,
  top_border = "",
  bottom_border = "",
  body_borders = NULL
) {
  surface_node <- .chrome_surface_at(cs, "header")
  # Column labels are bold by default; a `style(.at = cells_headers())`
  # override adds colour / font / size and can turn bold off.
  hdr_rpr <- .docx_rPr_from_style(
    surface_node,
    preset = preset,
    bold_default = TRUE
  )
  cells <- vapply(
    seq_along(col_names_vis),
    function(j) {
      nm <- col_names_vis[[j]]
      ast <- col_labels_ast[[nm]]
      runs <- if (is_inline_ast(ast)) {
        .render_docx_inline(
          ast,
          hyperlinks,
          default_rpr = hdr_rpr,
          rid_map = rid_map
        )
      } else {
        paste0(
          "<w:r><w:rPr>",
          hdr_rpr,
          "</w:rPr>",
          "<w:t xml:space=\"preserve\">",
          .docx_escape(nm),
          "</w:t></w:r>"
        )
      }
      col <- cols[[nm]]
      # Per-column halign wins; surface halign fills in.
      halign <- if (
        is_col_spec(col) &&
          length(col@align) == 1L &&
          !is.na(col@align)
      ) {
        # Decimal column header centres over the column (HTML parity);
        # the body stays decimal / right-aligned.
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
      # Valign cascade mirrors RTF: col_spec > surface > preset, then a
      # bottom default (HTML parity) when nothing set one. (Adding the
      # surface tier also closes a prior gap where
      # `preset(alignment = list(header_valign = ...))` was ignored here.)
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
      jc <- .docx_align_token(halign)
      valign_tok <- .docx_valign_token(valign)
      # Toprule rides the label row only when no band rows preceded it
      # (caller passes "" otherwise); the midrule (chrome `header_bottom`)
      # always closes the column-label band, full table width.
      # Outer frame edges: left on the first column, right on the last,
      # in canonical CT_TcBorders order (top, left, bottom, right).
      left_border <- if (j == 1L) {
        .docx_frame_edge("left", body_borders)
      } else {
        ""
      }
      right_border <- if (j == length(col_names_vis)) {
        .docx_frame_edge("right", body_borders)
      } else {
        ""
      }
      tc_borders <- .docx_tcborders(
        top_border,
        left_border,
        bottom_border,
        right_border
      )
      # Header surface drives the column-label background (RTF / HTML
      # parity) and the header padding override (preset = NULL: header
      # override only, no body-padding bleed). Canonical CT_TcPr order is
      # tcW -> tcBorders -> shd -> tcMar -> vAlign.
      col_shd <- .docx_shd_from_style(surface_node)
      tc_mar <- .docx_tcMar_from_style(surface_node, NULL)
      tc_pr <- sprintf(
        "<w:tcPr><w:tcW w:w=\"%d\" w:type=\"dxa\"/>%s%s%s%s</w:tcPr>",
        widths_twips[[j]],
        tc_borders,
        col_shd,
        tc_mar,
        valign_tok
      )
      paste0(
        "<w:tc>",
        tc_pr,
        "<w:p><w:pPr>",
        jc,
        "</w:pPr>",
        runs,
        "</w:p></w:tc>"
      )
    },
    character(1L)
  )
  paste0(
    "<w:tr><w:trPr><w:tblHeader/></w:trPr>",
    paste(cells, collapse = ""),
    "</w:tr>"
  )
}

# Render the body rows for every page in `grid@pages`. Returns a
# character vector of `<w:tr>` strings. Cell text is the post-
# engine_decimal flat string (`cells_text`). Per-cell alignment
# goes through the three-layer cascade:
#
#   style_node@halign / @valign  >  col_spec@align / @valign
#                                  >  cells_style[r,c]@halign / body_valign
#
# Per-cell style cascade (`cells_style[i, j]`) drives `<w:tcPr>`
# (background, borders, vAlign) and `<w:rPr>` (bold, italic, color,
# font, size).
.render_docx_body_rows <- function(
  pages,
  col_names_vis,
  cols,
  widths_twips,
  preset = NULL,
  cs = NULL,
  body_borders = NULL,
  emit_banner = TRUE
) {
  col_specs <- lapply(col_names_vis, function(nm) cols[[nm]])
  n_cols_vis <- length(col_names_vis)
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_twips_per_level <- .indent_native_twips_per_level(preset)
  out <- character()
  prev_subgroup_index <- NULL
  for (page in pages) {
    sg_index <- page$subgroup_index
    # `emit_banner` is FALSE under per-page BigN: each subgroup is its
    # own table whose leading `<w:tblHeader/>` block already carries the
    # banner above the header (rendered by `.render_docx_table`), so the
    # body must not repeat it. Otherwise (subgroups inline in one table)
    # the banner rides the body at each subgroup boundary.
    if (
      isTRUE(emit_banner) &&
        !is.null(sg_index) &&
        !identical(sg_index, prev_subgroup_index)
    ) {
      page_break_before <- !is.null(prev_subgroup_index)
      banner_row <- .render_docx_subgroup_banner_row(
        page$subgroup_line_ast,
        n_cols = n_cols_vis,
        widths_twips = widths_twips,
        page_break_before = page_break_before,
        preset = preset,
        cs = cs,
        body_borders = body_borders
      )
      if (length(banner_row) > 0L) {
        out <- c(out, banner_row)
      }
      prev_subgroup_index <- sg_index
    }
    ct <- page$cells_text
    cs_mat <- page$cells_style
    cells_indent <- page$cells_indent
    nrows <- nrow(ct)
    if (is.null(nrows) || nrows == 0L) {
      next
    }
    if (is.null(cells_indent)) {
      cells_indent <- matrix(0L, nrow = nrows, ncol = n_cols_vis)
    }
    is_header_row_vec <- page$is_header_row %||% rep(FALSE, nrows)
    is_blank_row_vec <- page$is_blank_row %||% rep(FALSE, nrows)
    span_total_twips <- sum(as.integer(widths_twips))
    for (i in seq_len(nrows)) {
      if (isTRUE(is_blank_row_vec[[i]])) {
        # Merged full-width cell: both frame edges ride this single cell,
        # plus the stripe fill stamped onto the row's node (so the zebra
        # band stays continuous across the gap). `<w:shd>` follows
        # `<w:tcBorders>` in CT_TcPr order.
        merged_edges <- .docx_tcborders(
          .docx_frame_edge("left", body_borders),
          .docx_frame_edge("right", body_borders)
        )
        blank_shd <- .docx_shd_from_style(
          tryCatch(cs_mat[[i, 1L]], error = function(e) NULL)
        )
        out <- c(
          out,
          paste0(
            "<w:tr><w:trPr><w:cantSplit/></w:trPr>",
            "<w:tc><w:tcPr>",
            sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", span_total_twips),
            sprintf("<w:gridSpan w:val=\"%d\"/>", n_cols_vis),
            merged_edges,
            blank_shd,
            "</w:tcPr>",
            "<w:p><w:pPr></w:pPr><w:r><w:t xml:space=\"preserve\"> </w:t></w:r></w:p>",
            "</w:tc></w:tr>"
          )
        )
        next
      }
      if (isTRUE(is_header_row_vec[[i]])) {
        host_text <- ""
        host_idx <- NA_integer_
        for (jj in seq_along(col_names_vis)) {
          val <- page$cells_text[i, jj]
          if (!is.na(val) && nzchar(val)) {
            host_text <- val
            host_idx <- jj
            break
          }
        }
        # Band-depth padding on the header paragraph via
        # `<w:ind w:left="N"/>` (twips) BEFORE `<w:jc>`. Band-1
        # (depth 0) emits no `<w:ind>`; band-2+ stamps the cell-side
        # left indent so the band-N header sits visibly nested under
        # band-(N-1).
        header_ind_tok <- ""
        if (!is.na(host_idx)) {
          header_depth <- cells_indent[i, host_idx]
          if (
            isTRUE(header_depth > 0L) &&
              indent_twips_per_level > 0L
          ) {
            header_ind_tok <- sprintf(
              "<w:ind w:left=\"%d\"/>",
              indent_twips_per_level * header_depth
            )
          }
        }
        # Group-header weight + text props from the host cell's stamped
        # style_node: NA bold == bold (default), `isFALSE` == off. The
        # run-property builder is shared with the subgroup banner.
        host_node <- if (!is.null(page$cells_style) && !is.na(host_idx)) {
          page$cells_style[[i, host_idx]]
        } else {
          NULL
        }
        rpr_inner <- .docx_rPr_from_style(
          host_node,
          preset,
          bold_default = TRUE
        )
        header_rpr <- if (nzchar(rpr_inner)) {
          paste0("<w:rPr>", rpr_inner, "</w:rPr>")
        } else {
          ""
        }
        # Merged full-width group-header cell: the host node's per-side
        # borders (from `style(border_*, .at = cells_group_headers())`)
        # ride it, composing with the outer frame edges. A user border
        # wins over the frame on left / right; top / bottom come from the
        # host node only (the row has no region channel). An explicit
        # `brdr("none")` clears. No border set => frame edges only (byte-
        # identical to the prior output). `<w:shd>` follows
        # `<w:tcBorders>` in CT_TcPr order.
        gh_edge <- function(side, frame) {
          brd <- .effective_border(side, host_node)
          if (is.null(brd)) {
            return(frame)
          }
          if (identical(brd$style, "none")) {
            return("")
          }
          sprintf(
            "<w:%s w:space=\"0\" %s/>",
            side,
            .docx_border_attrs(brd)
          )
        }
        merged_edges <- .docx_tcborders(
          gh_edge("top", ""),
          gh_edge("left", .docx_frame_edge("left", body_borders)),
          gh_edge("bottom", ""),
          gh_edge("right", .docx_frame_edge("right", body_borders))
        )
        group_shd <- .docx_shd_from_style(host_node)
        # Group-header halign cascade: an explicit `style(halign,
        # .at = cells_group_headers())` lands on the host node; fall
        # back to "left" (the historical default) when unset. Mirrors
        # the subgroup-banner resolution below.
        header_halign <- if (
          is_style_node(host_node) &&
            length(host_node@halign) == 1L &&
            !is.na(host_node@halign)
        ) {
          host_node@halign
        } else {
          "left"
        }
        header_jc_tok <- .docx_align_token(header_halign)
        out <- c(
          out,
          paste0(
            "<w:tr><w:trPr><w:cantSplit/></w:trPr>",
            "<w:tc><w:tcPr>",
            sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", span_total_twips),
            sprintf("<w:gridSpan w:val=\"%d\"/>", n_cols_vis),
            merged_edges,
            group_shd,
            "</w:tcPr>",
            "<w:p><w:pPr>",
            header_ind_tok,
            header_jc_tok,
            "</w:pPr>",
            .docx_body_runs(host_text, header_rpr),
            "</w:p>",
            "</w:tc></w:tr>"
          )
        )
        next
      }
      # Word-side keep-with-next: `<w:keepNext/>` is a paragraph
      # property that glues a paragraph to the next paragraph on the
      # same page. The engine `page$keep_with_next` mask (shared with
      # the RTF / LaTeX backends) says which rows must NOT break apart:
      # keep_together groups glue fully, section headers glue to their
      # following row, blanks break freely. Only those rows get the
      # token, so an un-paginated table flows and breaks naturally
      # instead of Word forcing the whole body onto one page. Fallback
      # (NULL mask, e.g. a hand-built grid) glues every row but the
      # last, the legacy single-page behaviour.
      kwn <- page$keep_with_next
      keep_row <- if (is.null(kwn) || length(kwn) < i) {
        i < nrows
      } else {
        isTRUE(kwn[[i]])
      }
      keep_next_tok <- if (keep_row) "<w:keepNext/>" else ""
      cells <- vapply(
        seq_along(col_names_vis),
        function(j) {
          style <- if (is.matrix(cs_mat) || is.list(cs_mat)) {
            tryCatch(cs_mat[[i, j]], error = function(e) NULL)
          } else {
            NULL
          }
          cs <- col_specs[[j]]
          halign <- .effective_body_halign(style, cs, preset)
          valign <- .effective_body_valign(style, cs, preset)
          align_tok <- .docx_align_token(halign)
          valign_tok <- .docx_valign_token(valign)
          tc_pr <- .docx_tcPr_inject_valign(
            .docx_tcPr_from_style(
              style,
              widths_twips[[j]],
              preset = preset,
              frame_left = if (j == 1L) {
                .docx_frame_edge("left", body_borders)
              } else {
                ""
              },
              frame_right = if (j == n_cols_vis) {
                .docx_frame_edge("right", body_borders)
              } else {
                ""
              }
            ),
            valign_tok
          )
          r_pr_inner <- .docx_rPr_from_style(style, preset = preset)
          r_pr <- if (nzchar(r_pr_inner)) {
            paste0("<w:rPr>", r_pr_inner, "</w:rPr>")
          } else {
            ""
          }
          # Per-cell native left indent from the engine sidecar. Strip
          # the engine-baked leading spaces and emit
          # `<w:ind w:left="N"/>` inside `<w:pPr>` BEFORE `<w:jc>` so
          # Word honours the cell-side left indent (wrapped continuation
          # lines align with the indented baseline).
          raw <- ct[i, j]
          depth <- cells_indent[i, j]
          ind_tok <- ""
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
              ind_tok <- sprintf(
                "<w:ind w:left=\"%d\"/>",
                indent_twips_per_level * depth
              )
            }
          }
          paste0(
            "<w:tc>",
            tc_pr,
            "<w:p><w:pPr>",
            keep_next_tok,
            ind_tok,
            align_tok,
            "</w:pPr>",
            .docx_body_runs(raw, r_pr),
            "</w:p></w:tc>"
          )
        },
        character(1L)
      )
      # `<w:cantSplit/>` on every row prevents Word from splitting
      # a single row's content across two pages (e.g. a multi-line
      # cell value). Applies to every body row regardless of
      # position; the paragraph-level `<w:keepNext/>` above handles
      # the row-to-row glue.
      tr_pr <- "<w:trPr><w:cantSplit/></w:trPr>"
      out <- c(
        out,
        paste0("<w:tr>", tr_pr, paste(cells, collapse = ""), "</w:tr>")
      )
    }
  }
  out
}

# Inject a `<w:vAlign .../>` element into an existing `<w:tcPr>...
# </w:tcPr>` string just before the closing tag. Returns the input
# unchanged when `valign_tok` is empty. Used by the body / header /
# subgroup-banner row renderers so the per-cell vertical alignment
# rides alongside the existing tcPr properties (width, borders,
# shading, gridSpan) without churning the original helper.
.docx_tcPr_inject_valign <- function(tcpr_xml, valign_tok) {
  if (!nzchar(valign_tok)) {
    return(tcpr_xml)
  }
  sub("</w:tcPr>$", paste0(valign_tok, "</w:tcPr>"), tcpr_xml)
}

# Subgroup banner row — a single `<w:tc>` with `<w:gridSpan w:val="N"/>`
# spanning every visible column, centred + bold. `<w:trPr>` carries
# `<w:tblHeader/>` so Word repeats the banner if the table spills
# inside the group, and `<w:pageBreakBefore/>` on the paragraph
# when transitioning into a non-initial group so each subgroup
# value starts on a fresh page (the canonical submission contract). Returns
# character(0) when the page has no subgroup runtime.
.render_docx_subgroup_banner_row <- function(
  subgroup_line_ast,
  n_cols,
  widths_twips,
  page_break_before,
  preset = NULL,
  cs = NULL,
  body_borders = NULL
) {
  if (
    is.null(subgroup_line_ast) ||
      !is_inline_ast(subgroup_line_ast) ||
      length(subgroup_line_ast@runs) == 0L ||
      n_cols < 1L
  ) {
    return(character())
  }
  span_w <- sum(as.integer(widths_twips))
  surface_node <- .chrome_surface_at(cs, "subgroup")
  # Subgroup banner weight + text props from the resolved surface node:
  # NA bold == bold (default), `isFALSE` == off. Shares the run-property
  # builder with the group-header rows; previously hardcoded `<w:b/>`,
  # ignoring an overriding bold / italic / color / font on the node.
  default_rpr <- .docx_rPr_from_style(
    surface_node,
    preset,
    bold_default = TRUE
  )
  inner_runs <- .render_docx_inline(
    subgroup_line_ast,
    default_rpr = default_rpr
  )
  page_break <- if (isTRUE(page_break_before)) {
    "<w:pageBreakBefore/>"
  } else {
    ""
  }
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    h <- .effective_subgroup_halign(preset)
    # Paged backends left-align the banner by default (anatomy); an
    # explicit cells_subgroup_labels() halign override still wins.
    if (is.na(h)) "left" else h
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
  valign_tok <- .docx_valign_token(valign)
  jc_tok <- .docx_align_token(halign)
  # Merged full-width cell: both frame edges ride it, plus the subgroup
  # surface background (RTF parity). `<w:tcBorders>` then `<w:shd>` then
  # `<w:vAlign>` in CT_TcPr order.
  # Frame L/R edges plus the subgroup top / bottom rules from
  # `style(border_*, .at = cells_subgroup_labels())` (chrome subgroup_top /
  # subgroup_bottom regions, RTF parity). CT_TcBorders order: top, left,
  # bottom, right.
  merged_edges <- .docx_tcborders(
    .docx_border_seg_from_triple(
      .chrome_border_at(cs, "subgroup_top"),
      "top",
      "none"
    ),
    .docx_frame_edge("left", body_borders),
    .docx_border_seg_from_triple(
      .chrome_border_at(cs, "subgroup_bottom"),
      "bottom",
      "none"
    ),
    .docx_frame_edge("right", body_borders)
  )
  banner_shd <- .docx_shd_from_style(surface_node)
  paste0(
    "<w:tr><w:trPr><w:tblHeader/></w:trPr>",
    "<w:tc><w:tcPr>",
    sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", span_w),
    sprintf("<w:gridSpan w:val=\"%d\"/>", n_cols),
    merged_edges,
    banner_shd,
    valign_tok,
    "</w:tcPr>",
    "<w:p><w:pPr>",
    page_break,
    jc_tok,
    "</w:pPr>",
    inner_runs,
    "</w:p>",
    "</w:tc></w:tr>"
  )
}

# Full-span empty-state message row for a zero-row page. A single
# `<w:gridSpan>` cell spans the band; the row height is the body
# content-box (`<w:trHeight w:hRule="exact">`) so the cell `<w:vAlign>`
# (from empty_valign, OOXML "center" for middle) centres the message
# vertically -- exact valign on the paged DOCX medium. The paragraph
# `<w:jc>` carries empty_halign. CT_TcPr child order: tcW, gridSpan,
# tcBorders, vAlign.
.render_docx_empty_row <- function(
  empty_text_ast,
  empty_place,
  n_cols,
  widths_twips,
  preset = NULL,
  body_borders = NULL
) {
  if (n_cols < 1L) {
    return(character())
  }
  span_w <- sum(as.integer(widths_twips))
  jc_tok <- .docx_align_token(empty_place$halign %||% "center")
  valign_tok <- .docx_valign_token(empty_place$valign %||% "middle")
  box_twips <- if (is.null(empty_place)) {
    0L
  } else {
    as.integer(round(empty_place$height_twips))
  }
  trheight <- if (box_twips > 0L) {
    sprintf("<w:trHeight w:hRule=\"exact\" w:val=\"%d\"/>", box_twips)
  } else {
    ""
  }
  default_rpr <- .docx_rPr_from_style(NULL, preset, bold_default = FALSE)
  inner_runs <- if (is.null(empty_text_ast)) {
    paste0(
      "<w:r>",
      default_rpr,
      "<w:t xml:space=\"preserve\">No data available to report</w:t></w:r>"
    )
  } else {
    .render_docx_inline(empty_text_ast, default_rpr = default_rpr)
  }
  merged_edges <- .docx_tcborders(
    .docx_border_seg_from_triple(NULL, "top", "none"),
    .docx_frame_edge("left", body_borders),
    .docx_border_seg_from_triple(NULL, "bottom", "none"),
    .docx_frame_edge("right", body_borders)
  )
  paste0(
    "<w:tr><w:trPr>",
    trheight,
    "</w:trPr>",
    "<w:tc><w:tcPr>",
    sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", span_w),
    sprintf("<w:gridSpan w:val=\"%d\"/>", n_cols),
    merged_edges,
    valign_tok,
    "</w:tcPr>",
    "<w:p><w:pPr>",
    jc_tok,
    "</w:pPr>",
    inner_runs,
    "</w:p>",
    "</w:tc></w:tr>"
  )
}

# Map an `align` value to a `<w:pPr><w:jc w:val="...">` token.
# Defaults to left when align is unset / NA. `decimal` -> right
# (engine_decimal has already padded with NBSP for visual alignment).
.docx_align_token <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("<w:jc w:val=\"left\"/>")
  }
  switch(
    align,
    left = "<w:jc w:val=\"left\"/>",
    center = "<w:jc w:val=\"center\"/>",
    right = "<w:jc w:val=\"right\"/>",
    decimal = "<w:jc w:val=\"right\"/>",
    "<w:jc w:val=\"left\"/>"
  )
}

# Map a `valign` value to a `<w:tcPr><w:vAlign w:val="..."/>` token.
# Returns "" when valign is NA / NULL so the caller can drop the
# element (Word defaults to vertical-align: top per OOXML spec).
# OOXML uses "center" for visual middle (not "middle"); we translate.
.docx_valign_token <- function(valign) {
  if (is.null(valign) || length(valign) == 0L || is.na(valign)) {
    return("")
  }
  switch(
    valign,
    top = "<w:vAlign w:val=\"top\"/>",
    middle = "<w:vAlign w:val=\"center\"/>",
    bottom = "<w:vAlign w:val=\"bottom\"/>",
    ""
  )
}

# ---------------------------------------------------------------------
# Section properties (page geometry)
# ---------------------------------------------------------------------

# Compose the trailing `<w:sectPr>` carrying paper size, orientation,
# margins, and (when chrome is populated) header / footer references.
# Lives at the end of `<w:body>` so it applies to the document body.
.docx_section_pr <- function(preset, rid_map = NULL) {
  paper <- .docx_paper_twips(preset@paper_size, preset@orientation)
  margins <- .docx_margins_twips(preset@margins)

  pg_sz <- sprintf(
    "<w:pgSz w:w=\"%d\" w:h=\"%d\"%s/>",
    paper$width,
    paper$height,
    if (identical(preset@orientation, "landscape")) {
      " w:orient=\"landscape\""
    } else {
      ""
    }
  )
  # Header / footer placement mirrors RTF's `.rtf_section_def`
  # (`\headery` / `\footery`). Margins stay EXACTLY the preset values,
  # never enlarged: the header sits one body line above the top margin
  # and flows upward (row 1 = body edge), the footer sits at the
  # bottom-margin line and flows downward (footnotes near the body,
  # program-path below). Word auto-expands the footer upward INTO the
  # body when the footnote block is tall, so extra footnotes eat body
  # space instead of growing the page (galley's model) -- never
  # reserve margin, never overlap.
  head_line <- as.integer(round(preset@font_size * 28))
  header_dist <- max(360L, margins$top - head_line)
  footer_dist <- margins$bottom
  pg_mar <- sprintf(
    "<w:pgMar w:top=\"%d\" w:right=\"%d\" w:bottom=\"%d\" w:left=\"%d\" w:header=\"%d\" w:footer=\"%d\" w:gutter=\"0\"/>",
    margins$top,
    margins$right,
    margins$bottom,
    margins$left,
    header_dist,
    footer_dist
  )
  refs <- character()
  if (!is.null(rid_map) && !is.null(rid_map$header)) {
    refs <- c(
      refs,
      sprintf(
        "<w:headerReference r:id=\"%s\" w:type=\"default\"/>",
        rid_map$header
      )
    )
  }
  if (!is.null(rid_map) && !is.null(rid_map$footer)) {
    refs <- c(
      refs,
      sprintf(
        "<w:footerReference r:id=\"%s\" w:type=\"default\"/>",
        rid_map$footer
      )
    )
  }
  paste0(
    "<w:sectPr>",
    paste(refs, collapse = ""),
    pg_sz,
    pg_mar,
    "</w:sectPr>"
  )
}

# Paper dimensions in twips. Letter, legal, a4; orientation swaps
# w/h for landscape. Mirrors `.rtf_paper_twips`.
.docx_paper_twips <- function(paper, orientation) {
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

# Resolve `preset@margins` (CSS shorthand: length 1, 2, or 4) into
# twips for each of the four sides. Mirrors `.rtf_margins_twips`.
.docx_margins_twips <- function(margins) {
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
# Page chrome — header1.xml / footer1.xml with L/C/R slot tables +
# PAGE / NUMPAGES dynamic fields
# ---------------------------------------------------------------------

# Render `word/header1.xml`. Each populated page-band row emits as
# a one-row borderless `<w:tbl>` with up to three cells (Left /
# Center / Right slots; empty slots collapse). Rows emit in
# REVERSE index order so row 1 (body edge) ends up at the bottom of
# the header zone, closest to the table body — matches the RTF
# header convention.
.docx_header_xml <- function(pagehead_ast, preset, cs = NULL) {
  nrow_band <- .page_band_nrow(pagehead_ast)
  rows <- character()
  for (i in rev(seq_len(nrow_band))) {
    row_ast <- .page_band_row(pagehead_ast, i)
    rows <- c(
      rows,
      .docx_chrome_row(row_ast, preset, cs = cs, surface = "pagehead")
    )
  }
  paste0(
    .docx_xml_prologue,
    "<w:hdr ",
    .docx_ns_decls,
    ">",
    paste(rows, collapse = ""),
    "</w:hdr>"
  )
}

# Render `word/footer1.xml`. Each populated page-band row emits as
# a one-row borderless `<w:tbl>` with up to three cells (Left /
# Center / Right slots; empty slots collapse). Rows emit in
# FORWARD index order so row 1 (body edge) ends up at the top of
# the footer zone — matches the RTF footer convention.
# `footnote_block` (when `repeat_footnotes` is on) is placed ABOVE the
# pagefoot chrome rows, so the footer reads footnotes-then-program-path
# top to bottom, repeating on every page. Mirrors RTF's `{\footer}`
# (footnote lines above the program-path band).
.docx_footer_xml <- function(
  pagefoot_ast,
  preset,
  footnote_block = "",
  cs = NULL
) {
  nrow_band <- .page_band_nrow(pagefoot_ast)
  rows <- character()
  for (i in seq_len(nrow_band)) {
    row_ast <- .page_band_row(pagefoot_ast, i)
    rows <- c(
      rows,
      .docx_chrome_row(row_ast, preset, cs = cs, surface = "pagefoot")
    )
  }
  paste0(
    .docx_xml_prologue,
    "<w:ftr ",
    .docx_ns_decls,
    ">",
    footnote_block,
    paste(rows, collapse = ""),
    "</w:ftr>"
  )
}

# Render one band row as a borderless 3-cell table. Cells COLLAPSE
# for NULL / empty slot ASTs — no blank-padded cells. Each cell
# alignment matches its slot (L = left, C = center, R = right).
# Page tokens (`{page}` / `{npages}`) inside any cell's inline AST
# resolve to Word `<w:fldSimple>` PAGE / NUMPAGES fields at view
# time. No borders, no shading; chrome cells stay visually
# transparent against the page background.
.docx_chrome_row <- function(
  row_slots_ast,
  preset,
  cs = NULL,
  surface = NULL
) {
  slots <- c("left", "center", "right")
  alignments <- c(left = "left", center = "center", right = "right")
  cells_data <- list()
  for (s in slots) {
    ast <- row_slots_ast[[s]]
    if (is_inline_ast(ast) && length(ast@runs) > 0L) {
      # Per-slot text props (bold/italic/color/font) from
      # cells_pagehead(slot = s) ride as the cell runs' default rPr
      # (Thread G); .render_docx_inline merges + canonically orders them.
      slot_node <- if (!is.null(surface)) {
        .chrome_surface_at_slot(cs, surface, slot = s)
      } else {
        NULL
      }
      slot_rpr <- if (is_style_node(slot_node)) {
        .docx_rPr_from_style(slot_node)
      } else {
        ""
      }
      runs_xml <- .render_docx_inline(
        ast,
        hyperlinks = character(),
        default_rpr = slot_rpr
      )
      runs_with_fields <- .docx_resolve_page_tokens(runs_xml)
      slot_shd <- if (is_style_node(slot_node)) {
        .docx_shd_from_style(slot_node)
      } else {
        ""
      }
      cells_data[[length(cells_data) + 1L]] <- list(
        align = alignments[[s]],
        body = runs_with_fields,
        shd = slot_shd
      )
    }
  }
  if (length(cells_data) == 0L) {
    return(character())
  }

  paper <- .docx_paper_twips(preset@paper_size, preset@orientation)
  margins <- .docx_margins_twips(preset@margins)
  printable <- paper$width - margins$left - margins$right
  per_cell <- as.integer(printable %/% length(cells_data))

  # Band rule (Thread G): `style(border_bottom = brdr(), .at =
  # cells_pagehead())` draws a rule on the header band's bottom edge
  # (`border_top` on the footer's top edge), from the chrome border
  # region. The other three edges, and the default (no region), stay nil.
  band_edge <- if (identical(surface, "pagefoot")) "top" else "bottom"
  region <- if (identical(surface, "pagehead")) {
    "pagehead_bottom"
  } else if (identical(surface, "pagefoot")) {
    "pagefoot_top"
  } else {
    NULL
  }
  edge_el <- if (is.null(region)) {
    ""
  } else {
    .docx_chrome_border_seg(cs, region, band_edge, "none")
  }
  border_el <- function(side) {
    if (identical(side, band_edge) && nzchar(edge_el)) {
      edge_el
    } else {
      sprintf("<w:%s w:val=\"nil\"/>", side)
    }
  }
  nil_borders <- paste0(
    "<w:tcBorders>",
    border_el("top"),
    border_el("left"),
    border_el("bottom"),
    border_el("right"),
    "</w:tcBorders>"
  )

  cells_xml <- vapply(
    seq_along(cells_data),
    function(i) {
      c <- cells_data[[i]]
      width <- if (i == length(cells_data)) {
        printable - per_cell * (length(cells_data) - 1L)
      } else {
        per_cell
      }
      tc_pr <- paste0(
        "<w:tcPr>",
        sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", width),
        nil_borders,
        c$shd %||% "",
        "</w:tcPr>"
      )
      paste0(
        "<w:tc>",
        tc_pr,
        sprintf(
          "<w:p><w:pPr><w:jc w:val=\"%s\"/></w:pPr>%s</w:p>",
          c$align,
          c$body
        ),
        "</w:tc>"
      )
    },
    character(1L)
  )

  grid_cols <- paste0(
    rep(
      sprintf("<w:gridCol w:w=\"%d\"/>", per_cell),
      length(cells_data) - 1L
    ),
    collapse = ""
  )
  last_w <- printable - per_cell * (length(cells_data) - 1L)
  grid_cols <- paste0(
    grid_cols,
    sprintf("<w:gridCol w:w=\"%d\"/>", last_w)
  )

  tbl_pr <- paste0(
    "<w:tblPr>",
    sprintf("<w:tblW w:w=\"%d\" w:type=\"dxa\"/>", printable),
    "<w:tblLayout w:type=\"fixed\"/>",
    "<w:tblBorders>",
    "<w:top w:val=\"nil\"/><w:left w:val=\"nil\"/>",
    "<w:bottom w:val=\"nil\"/><w:right w:val=\"nil\"/>",
    "<w:insideH w:val=\"nil\"/><w:insideV w:val=\"nil\"/>",
    "</w:tblBorders>",
    "</w:tblPr>"
  )

  paste0(
    "<w:tbl>",
    tbl_pr,
    "<w:tblGrid>",
    grid_cols,
    "</w:tblGrid>",
    "<w:tr>",
    paste(cells_xml, collapse = ""),
    "</w:tr></w:tbl>"
  )
}

# Substitute the user-typed `{page}` / `{npages}` tokens in a
# rendered OOXML chrome fragment for Word `<w:fldSimple>` field
# codes. The tokens live verbatim inside `<w:t xml:space="preserve">`
# elements after `.render_docx_inline()` runs. We split the
# enclosing `<w:r>` / `<w:t>` so the field element lands at the
# correct paragraph level (fields are not legal inside `<w:t>`).
# Word and LibreOffice both auto-update the placeholder digit
# ("1") on view / print, so the value shown matches the real page
# number even though the static fallback is "1".
.docx_resolve_page_tokens <- function(xml) {
  page_repl <- paste0(
    "</w:t></w:r>",
    "<w:fldSimple w:instr=\"PAGE \\* MERGEFORMAT\">",
    "<w:r><w:t>1</w:t></w:r></w:fldSimple>",
    "<w:r><w:t xml:space=\"preserve\">"
  )
  npages_repl <- paste0(
    "</w:t></w:r>",
    "<w:fldSimple w:instr=\"NUMPAGES \\* MERGEFORMAT\">",
    "<w:r><w:t>1</w:t></w:r></w:fldSimple>",
    "<w:r><w:t xml:space=\"preserve\">"
  )
  xml <- gsub("{page}", page_repl, xml, fixed = TRUE)
  xml <- gsub("{npages}", npages_repl, xml, fixed = TRUE)
  xml
}

# ---------------------------------------------------------------------
# Manifest files (static-ish OOXML scaffolding)
# ---------------------------------------------------------------------

# `[Content_Types].xml` — MIME type map. Defaults cover rels + XML;
# overrides nail down each document part. Header / footer overrides
# are conditional on chrome presence.
.docx_content_types <- function(has_pagehead, has_pagefoot) {
  overrides <- c(
    "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>",
    "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>",
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
    "<Override PartName=\"/word/fontTable.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml\"/>",
    "<Override PartName=\"/word/settings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/>",
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>",
    "<Override PartName=\"/word/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>",
    "<Override PartName=\"/word/webSettings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.webSettings+xml\"/>"
  )
  if (has_pagehead) {
    overrides <- c(
      overrides,
      "<Override PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"/>"
    )
  }
  if (has_pagefoot) {
    overrides <- c(
      overrides,
      "<Override PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"/>"
    )
  }
  paste0(
    .docx_xml_prologue,
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>",
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>",
    paste(overrides, collapse = ""),
    "</Types>"
  )
}

# `_rels/.rels` — top-level relationships. Points at the main
# document, the core properties, and the extended properties.
.docx_root_rels <- function() {
  paste0(
    .docx_xml_prologue,
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>",
    "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>",
    "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>",
    "</Relationships>"
  )
}

# `word/_rels/document.xml.rels` — document-level relationships:
# styles + settings + theme + fontTable + webSettings always;
# header / footer conditionally; one hyperlink relationship per
# unique URL collected from the grid's inline ASTs.
# `TargetMode="External"` is mandatory on every hyperlink rel.
# Numeric rIds are assigned by `.docx_rid_map()` so the format
# matches the convention Word's relationship resolver expects.
.docx_doc_rels <- function(hyperlinks, rid_map) {
  rels <- c(
    sprintf(
      "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
      rid_map$styles
    ),
    sprintf(
      "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
      rid_map$settings
    ),
    sprintf(
      "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>",
      rid_map$theme
    ),
    sprintf(
      "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable\" Target=\"fontTable.xml\"/>",
      rid_map$fontTable
    ),
    sprintf(
      "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/webSettings\" Target=\"webSettings.xml\"/>",
      rid_map$webSettings
    )
  )
  if (!is.null(rid_map$header)) {
    rels <- c(
      rels,
      sprintf(
        "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>",
        rid_map$header
      )
    )
  }
  if (!is.null(rid_map$footer)) {
    rels <- c(
      rels,
      sprintf(
        "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>",
        rid_map$footer
      )
    )
  }
  for (i in seq_along(hyperlinks)) {
    rels <- c(
      rels,
      sprintf(
        "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"%s\" TargetMode=\"External\"/>",
        rid_map$hyperlinks[[i]],
        .docx_escape_attr(hyperlinks[[i]])
      )
    )
  }
  paste0(
    .docx_xml_prologue,
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
    paste(rels, collapse = ""),
    "</Relationships>"
  )
}

# `word/styles.xml` — style definitions, pandoc-shaped. The default
# run font is the resolved `preset@font_family` primary face (e.g.
# `Liberation Mono` for the `"mono"` default), pinned directly into
# `<w:rFonts w:ascii=>` and declared in `word/fontTable.xml` with a
# metric-compatible substitute (RTF's `\*\falt` discipline). This is
# the SSOT principle: the body font comes from the preset, not from
# the Office theme. The earlier `asciiTheme="minorHAnsi"` form let
# Word substitute Aptos/Calibri and silently dropped the user's font
# choice. Naming an installed face with a declared fallback is safe;
# the "Word rejects unknown fonts" hazard applies only to CSS generic
# names (`serif` / `sans`), which `.resolve_font_stack()` never emits.
#
# Three named styles are declared so other parts of `document.xml`
# can reference them via `<w:pStyle>` instead of repeating inline
# direct formatting on every paragraph:
#
#   Normal       — Word's default; we attach docDefaults to it.
#   TabularTitle — centred bold, used by the title block.
#   TabularFoot  — left-aligned, used by the footnote block.
.docx_styles_xml <- function(preset) {
  half_pts <- as.integer(round(preset@font_size * 2))
  face <- .docx_escape_attr(
    .docx_primary_font(.resolve_font_stack(preset@font_family, "docx"))
  )
  paste0(
    .docx_xml_prologue,
    "<w:styles ",
    .docx_ns_decls,
    ">",
    "<w:docDefaults><w:rPrDefault><w:rPr>",
    sprintf(
      "<w:rFonts w:ascii=\"%s\" w:hAnsi=\"%s\" w:cs=\"%s\"/>",
      face,
      face,
      face
    ),
    sprintf("<w:sz w:val=\"%d\"/><w:szCs w:val=\"%d\"/>", half_pts, half_pts),
    "<w:lang w:val=\"en-US\" w:eastAsia=\"en-US\" w:bidi=\"ar-SA\"/>",
    "</w:rPr></w:rPrDefault>",
    "<w:pPrDefault><w:pPr><w:spacing w:after=\"0\" w:line=\"240\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault>",
    "</w:docDefaults>",
    "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\">",
    "<w:name w:val=\"Normal\"/><w:qFormat/>",
    "</w:style>",
    "<w:style w:type=\"character\" w:default=\"1\" w:styleId=\"DefaultParagraphFont\">",
    "<w:name w:val=\"Default Paragraph Font\"/><w:uiPriority w:val=\"1\"/>",
    "<w:semiHidden/><w:unhideWhenUsed/>",
    "</w:style>",
    "<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"TabularTitle\">",
    "<w:name w:val=\"Tabular Title\"/><w:basedOn w:val=\"Normal\"/><w:qFormat/>",
    "<w:pPr><w:jc w:val=\"center\"/></w:pPr>",
    "<w:rPr><w:b/></w:rPr>",
    "</w:style>",
    "<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"TabularFoot\">",
    "<w:name w:val=\"Tabular Footnote\"/><w:basedOn w:val=\"Normal\"/><w:qFormat/>",
    "<w:pPr><w:jc w:val=\"left\"/></w:pPr>",
    "</w:style>",
    "<w:style w:type=\"character\" w:styleId=\"Hyperlink\">",
    "<w:name w:val=\"Hyperlink\"/><w:basedOn w:val=\"DefaultParagraphFont\"/>",
    "<w:uiPriority w:val=\"99\"/><w:unhideWhenUsed/>",
    "<w:rPr><w:color w:val=\"0563C1\"/><w:u w:val=\"single\"/></w:rPr>",
    "</w:style>",
    "</w:styles>"
  )
}

# `word/theme/theme1.xml` — Office Theme bundled at
# `inst/templates/theme1.xml`. Carries `minorHAnsi` (body font) /
# `majorHAnsi` (heading font) plus the standard Office colour
# scheme. We ship the verbatim pandoc-equivalent Office Theme so
# Word / LibreOffice / Pages all resolve our `asciiTheme`
# references identically. The user's `preset@font_family` does NOT
# influence the theme today (theme fonts are fixed to Office
# defaults); a future plan can swap in a user-customised theme.
.docx_theme_xml <- function(preset) {
  path <- system.file("templates", "theme1.xml", package = "tabular")
  if (!nzchar(path) || !file.exists(path)) {
    # devtools::load_all() path — inst/templates is at the repo
    # root in that case.
    path <- file.path("inst", "templates", "theme1.xml")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

# OOXML font fingerprints keyed by family class. Word uses
# panose1 / charset / family / pitch / sig to find a metric-
# compatible substitute when a named face is absent. The three
# classes cover every face `.resolve_font_stack()` can emit:
# `modern` (mono, Courier-metric), `roman` (serif, Times-metric),
# `swiss` (sans, Arial-metric).
.docx_font_fingerprint <- list(
  modern = paste0(
    "<w:panose1 w:val=\"02070309020205020404\"/>",
    "<w:charset w:val=\"00\"/><w:family w:val=\"modern\"/><w:pitch w:val=\"fixed\"/>",
    "<w:sig w:usb0=\"E0002AFF\" w:usb1=\"C0007843\" w:usb2=\"00000009\" w:usb3=\"00000000\" w:csb0=\"000001FF\" w:csb1=\"00000000\"/>"
  ),
  roman = paste0(
    "<w:panose1 w:val=\"02020603050405020304\"/>",
    "<w:charset w:val=\"00\"/><w:family w:val=\"roman\"/><w:pitch w:val=\"variable\"/>",
    "<w:sig w:usb0=\"E0002EFF\" w:usb1=\"C000785B\" w:usb2=\"00000009\" w:usb3=\"00000000\" w:csb0=\"000001FF\" w:csb1=\"00000000\"/>"
  ),
  swiss = paste0(
    "<w:panose1 w:val=\"020B0604020202020204\"/>",
    "<w:charset w:val=\"00\"/><w:family w:val=\"swiss\"/><w:pitch w:val=\"variable\"/>",
    "<w:sig w:usb0=\"E0002AFF\" w:usb1=\"C000247B\" w:usb2=\"00000009\" w:usb3=\"00000000\" w:csb0=\"000001FF\" w:csb1=\"00000000\"/>"
  )
)

# Classify a resolved font stack into one OOXML family class by
# membership in the shared cores from `R/fonts.R`. Mono wins first
# (the `"mono"` default), then serif, then sans; an unrecognised
# named face defaults to `swiss` (the safe variable-pitch class).
.docx_font_class <- function(stack) {
  if (any(stack %in% .stack_mono)) {
    return("modern")
  }
  if (any(stack %in% .stack_serif)) {
    return("roman")
  }
  "swiss"
}

# `word/fontTable.xml` — declares the resolved `preset@font_family`
# stack so the consuming app can substitute a metric-compatible face
# when the primary is absent. The primary face (e.g. `Liberation
# Mono`) leads; the stack tail (e.g. `Courier New`, `Courier`) are
# the declared substitutes, the OOXML form of RTF's `\*\falt`. Every
# face in one stack shares the class fingerprint, since the stack is
# metric-compatible by construction.
.docx_font_table <- function(preset) {
  stack <- .resolve_font_stack(preset@font_family, "docx")
  fp <- .docx_font_fingerprint[[.docx_font_class(stack)]]
  decls <- vapply(
    unique(stack),
    function(face) {
      sprintf(
        "<w:font w:name=\"%s\">%s</w:font>",
        .docx_escape_attr(face),
        fp
      )
    },
    character(1L)
  )
  paste0(
    .docx_xml_prologue,
    "<w:fonts ",
    .docx_ns_decls,
    ">",
    paste(decls, collapse = ""),
    "</w:fonts>"
  )
}

# `word/webSettings.xml` — minimum Word web-compatibility settings.
# `allowPNG` lets Word save embedded images as PNG;
# `doNotSaveAsSingleFile` keeps multi-file output. Both are
# Office-template defaults pandoc emits verbatim.
.docx_web_settings_xml <- function() {
  paste0(
    .docx_xml_prologue,
    "<w:webSettings ",
    .docx_ns_decls,
    "><w:allowPNG/><w:doNotSaveAsSingleFile/></w:webSettings>"
  )
}

# `word/settings.xml` — minimum settings: compatibility mode
# (Word 2013+), default tab stop. Determinism: no `<w:rsids>`
# block, which would otherwise carry random revision-save IDs.
.docx_settings_xml <- function() {
  paste0(
    .docx_xml_prologue,
    "<w:settings ",
    .docx_ns_decls,
    "><w:defaultTabStop w:val=\"720\"/>",
    "<w:compat><w:compatSetting w:name=\"compatibilityMode\" w:uri=\"http://schemas.microsoft.com/office/word\" w:val=\"15\"/></w:compat>",
    "</w:settings>"
  )
}

# `docProps/app.xml` — application metadata. Static so the output
# stays byte-deterministic. `Application` names the creator;
# `AppVersion` MUST be the Office `MM.mmmm` form (major.minor4) per
# ECMA-376 Part 1 (and Word's strict macOS parser enforces it). A
# multi-dot version like `0.0.0.9000` (the R package version, which
# we used originally) parses as invalid and Word refuses to open
# the whole `.docx`. We fix the value at `16.0000` (Office 2019 +
# 2021 + 2024 use this) — it's a tombstone for "OOXML-compliant
# Office-compatible writer", not a literal claim of being Word.
.docx_app_xml <- function() {
  paste0(
    .docx_xml_prologue,
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">",
    "<Application>tabular (R package)</Application>",
    "<AppVersion>16.0000</AppVersion>",
    "</Properties>"
  )
}

# `docProps/core.xml` — Dublin Core metadata. `title` is the
# first non-empty title; `creator` is "tabular"; `created` /
# `modified` are fixed at the FAT-epoch floor for byte-
# determinism. Customising creator from preset is a v0.2 knob.
.docx_core_xml <- function(meta) {
  titles <- meta$titles %||% character()
  title <- if (length(titles) > 0L) titles[[1L]] else ""
  fixed_ts <- "1980-01-01T00:00:00Z"
  paste0(
    .docx_xml_prologue,
    "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">",
    sprintf("<dc:title>%s</dc:title>", .docx_escape(title)),
    "<dc:creator>tabular</dc:creator>",
    sprintf(
      "<dcterms:created xsi:type=\"dcterms:W3CDTF\">%s</dcterms:created>",
      fixed_ts
    ),
    sprintf(
      "<dcterms:modified xsi:type=\"dcterms:W3CDTF\">%s</dcterms:modified>",
      fixed_ts
    ),
    "</cp:coreProperties>"
  )
}

# Pick the primary font face from a resolved preset@font_family
# chain. The chain is already the resolved cross-backend stack
# (e.g. c("Liberation Serif", "Times New Roman", "Times")); we
# name the first entry in OOXML and let Word's font-fallback
# table handle substitution at render time. Mirrors RTF's
# decision in `.rtf_font_table()`.
.docx_primary_font <- function(font_family) {
  if (length(font_family) == 0L) {
    return("Liberation Serif")
  }
  family <- font_family[[1L]]
  if (is.na(family) || !nzchar(family)) "Liberation Serif" else family
}

# ---------------------------------------------------------------------
# Zip writer — byte-deterministic
# ---------------------------------------------------------------------

# Write `entries` (a named character vector of zip-relative paths
# -> UTF-8 string contents) to `file` as an OPC-compliant ZIP.
#
# Why `utils::zip()` over `zip::zip()`: the `zip` package emits ZIP
# entries with the **data-descriptor flag** (bit 3 of the local-file-
# header flags). The OOXML / OPC spec allows it, but Microsoft
# Word's parser is intolerant of it on macOS and refuses to open
# the archive ("Word experienced an error trying to open the file").
# The system `zip` binary used by `utils::zip(flags = "-X9q")`
# stores pre-computed CRCs in the local header (no descriptor),
# matching pandoc's output and what Word expects.
#
# Determinism is preserved by (a) writing each file with a fixed
# mtime (`.docx_fixed_mtime`, 1980-01-01 00:00:00 UTC) BEFORE
# zipping, and (b) passing files to `utils::zip()` in a stable
# order (caller sorted `entries`, with `[Content_Types].xml` pinned
# first per the OPC spec). The `-X` flag strips host metadata
# (UID/GID/extra fields); `-9` is max compression; `-q` is quiet.
.docx_write_zip <- function(entries, file) {
  tmp <- tempfile("tabular_docx_")
  dir.create(tmp, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  rels <- names(entries)
  for (rel in rels) {
    abs_path <- file.path(tmp, rel)
    dir.create(dirname(abs_path), recursive = TRUE, showWarnings = FALSE)
    content <- entries[[rel]]
    # Binary parts (figure images in word/media) carry raw bytes;
    # everything else is UTF-8 XML text. `entries` is a named list when
    # any raw part is present, a named character vector otherwise.
    if (is.raw(content)) {
      writeBin(content, abs_path)
    } else {
      writeLines(content, abs_path, useBytes = TRUE)
    }
    Sys.setFileTime(abs_path, .docx_fixed_mtime)
  }

  # utils::zip writes in the order `files` is given. Caller pinned
  # `[Content_Types].xml` first per OPC.
  if (file.exists(file)) {
    unlink(file)
  }
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(tmp)
  status <- utils::zip(
    zipfile = file,
    files = rels,
    flags = "-X9q"
  )
  setwd(old_wd)
  if (!identical(status, 0L)) {
    cli::cli_abort(
      c(
        "DOCX zip write failed.",
        "x" = "utils::zip returned status {.val {status}}.",
        "i" = "Ensure a {.code zip} binary is on PATH or {.envvar R_ZIPCMD} is set."
      ),
      class = "tabular_error_backend",
      call = rlang::caller_env()
    )
  }
  invisible(file)
}

# ---------------------------------------------------------------------
# Per-cell style cascade — style_node -> OOXML
# ---------------------------------------------------------------------

# Translate a `style_node` to a `<w:tcPr>` XML fragment carrying
# cell-level properties: cell width, shading (background), borders
# (rule_above / rule_below / border_left / border_right), and any
# `<w:gridSpan>` for banded headers. Returns a complete `<w:tcPr>`
# element ready for insertion at the head of a `<w:tc>`.
#
# Property mapping (style_node -> OOXML):
#   @background = "#RRGGBB"   -> <w:shd w:val="clear" w:color="auto" w:fill="RRGGBB"/>
#   @rule_above  = TRUE       -> <w:tcBorders><w:top w:val="single" w:sz="4"/></w:tcBorders>
#   @rule_below  = TRUE       -> <w:tcBorders><w:bottom .../></w:tcBorders>
#   @border_left  = TRUE      -> <w:tcBorders><w:left .../></w:tcBorders>
#   @border_right = TRUE      -> <w:tcBorders><w:right .../></w:tcBorders>
#
# Border properties merge into a single `<w:tcBorders>` element.
# Properties are emitted in stable order (alphabetical by element
# tag) so byte-determinism is trivial.
.docx_tcPr_from_style <- function(
  style,
  width_twips,
  gridspan = NA_integer_,
  preset = NULL,
  frame_left = "",
  frame_right = ""
) {
  parts <- character()
  parts <- c(
    parts,
    sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", width_twips)
  )
  if (!is.na(gridspan) && gridspan > 1L) {
    parts <- c(parts, sprintf("<w:gridSpan w:val=\"%d\"/>", gridspan))
  }
  tc_mar <- .docx_tcMar_from_style(style, preset)
  if (nzchar(tc_mar)) {
    parts <- c(parts, tc_mar)
  }
  if (is_style_node(style)) {
    # Per-side border resolution via the shared cascade helper —
    # explicit border_<side>_style/width/color win over the legacy
    # Boolean knobs (rule_above / rule_below / border_left /
    # border_right), which map to ("solid", 0.5pt, default) when
    # TRUE. The helper returns NULL when the side carries no
    # border; the corresponding `<w:top>` / `<w:left>` etc. is then
    # omitted. OOXML cell-border emission order is top -> left ->
    # bottom -> right (stable for byte determinism).
    border_inners <- character()
    border_entries <- list(
      list(side = "top", tag = "w:top"),
      list(side = "left", tag = "w:left"),
      list(side = "bottom", tag = "w:bottom"),
      list(side = "right", tag = "w:right")
    )
    for (entry in border_entries) {
      brd <- .effective_border(entry$side, style)
      tok <- if (!is.null(brd) && !identical(brd$style, "none")) {
        sprintf("<%s %s/>", entry$tag, .docx_border_attrs(brd))
      } else if (entry$side == "left") {
        # Structural outer-frame LEFT edge (retired from the per-cell
        # stamp; see .apply_table_layer). Slots into the canonical
        # top -> left -> bottom -> right order. A real per-cell border
        # still wins (the branch above).
        frame_left
      } else if (entry$side == "right") {
        frame_right
      } else {
        ""
      }
      if (nzchar(tok)) {
        border_inners <- c(border_inners, tok)
      }
    }
    if (length(border_inners) > 0L) {
      parts <- c(
        parts,
        paste0(
          "<w:tcBorders>",
          paste(border_inners, collapse = ""),
          "</w:tcBorders>"
        )
      )
    }
    bg <- style@background
    if (!is.na(bg) && nzchar(bg)) {
      hex <- .docx_normalize_color(bg)
      parts <- c(
        parts,
        sprintf(
          "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"%s\"/>",
          hex
        )
      )
    }
  }
  paste0("<w:tcPr>", paste(parts, collapse = ""), "</w:tcPr>")
}

# Map one resolved border triple (style, width pt, color) to the
# OOXML `<w:top|left|bottom|right>` attribute string. Width emits
# in eighths-of-a-point (w:sz unit), capped to >= 2 so very thin
# values still render in Word. Color "currentColor" surfaces as
# w:color="auto" (the OOXML "inherit from theme" sentinel).
.docx_border_attrs <- function(brd) {
  val <- switch(
    brd$style,
    solid = "single",
    dashed = "dashed",
    dotted = "dotted",
    double = "double",
    dashdot = "dotDash",
    "single"
  )
  sz <- max(2L, as.integer(round(brd$width * 8)))
  color_attr <- if (
    identical(brd$color, "currentColor") ||
      .is_default_ink(brd$color) ||
      is.na(brd$color)
  ) {
    "auto"
  } else {
    .docx_normalize_color(brd$color)
  }
  sprintf(
    "w:val=\"%s\" w:sz=\"%d\" w:color=\"%s\"",
    val,
    sz,
    color_attr
  )
}

# Resolve a chrome border region into one OOXML cell-side element
# (e.g. `<w:top w:space="0" w:val="single" .../>`) or "" when the
# region carries no rule. The OOXML twin of `.rtf_chrome_border_seg`:
# the resolved `chrome_style$borders` triple wins; a NULL region
# falls back to `backend_default` ("solid" -> 0.5pt ink, else no
# rule); an explicit "none" triple suppresses the side. `side` is
# the cell side this region writes to ("top" for `header_top`,
# "bottom" for `header_bottom`).
.docx_chrome_border_seg <- function(
  cs,
  region,
  side,
  backend_default = "solid"
) {
  .docx_border_seg_from_triple(
    .chrome_border_at(cs, region),
    side,
    backend_default
  )
}

# Build a `<w:top>` / `<w:bottom>` ... border element from a resolved
# (style, width, color) triple. NULL with a "solid" backend default emits
# the 0.5pt rule; an explicit "none" (or NULL with a non-solid default)
# emits nothing.
.docx_border_seg_from_triple <- function(
  triple,
  side,
  backend_default = "solid"
) {
  if (is.null(triple)) {
    if (!identical(backend_default, "solid")) {
      return("")
    }
    triple <- list(style = "solid", width = 0.5, color = .tabular_ink)
  } else if (identical(triple$style, "none")) {
    return("")
  }
  sprintf("<w:%s w:space=\"0\" %s/>", side, .docx_border_attrs(triple))
}

# Wrap an ordered set of cell-side border elements into a single
# `<w:tcBorders>`. Empty entries drop out; an all-empty set yields ""
# (no element emitted). OOXML side order is top -> left -> bottom ->
# right, so callers pass elements already in that order.
.docx_tcborders <- function(...) {
  sides <- c(...)
  sides <- sides[nzchar(sides)]
  if (length(sides) == 0L) {
    return("")
  }
  paste0("<w:tcBorders>", paste(sides, collapse = ""), "</w:tcBorders>")
}

# Outer frame edge element (`<w:left>` / `<w:right>`) for a DOCX table-
# proper cell, read from the body-border manifest. Applied to the first
# (left) and last (right) cell of every table-proper row, and to BOTH
# sides of a merged blank / group-header cell, so the vertical frame
# spans the whole table region (`<w:tblBorders>` cannot be used: the
# title rows share the same `<w:tbl>` and must stay outside the box).
# Returns "" when the frame is off. The caller MUST place the result in
# canonical CT_TcBorders order (top, left, bottom, right) inside
# `.docx_tcborders()`.
.docx_frame_edge <- function(side, body_borders) {
  if (!is.list(body_borders)) {
    return("")
  }
  triple <- body_borders[[paste0("outer_", side)]]
  if (is.null(triple) || identical(triple$style, "none")) {
    return("")
  }
  sprintf("<w:%s w:space=\"0\" %s/>", side, .docx_border_attrs(triple))
}

# `<w:shd>` cell-shading element from a style_node's @background, or ""
# when no background is set. Mirrors the inline block in
# `.docx_tcPr_from_style()` so the special-row renderers (header band,
# blank separator, group-header, subgroup banner) can colour their cells
# from the resolved node (the stripe fill or the header surface colour),
# matching the body cell path. `<w:shd>` follows `<w:tcBorders>` and
# precedes `<w:tcMar>` / `<w:vAlign>` in CT_TcPr order.
.docx_shd_from_style <- function(style) {
  if (!is_style_node(style)) {
    return("")
  }
  bg <- style@background
  if (length(bg) != 1L || is.na(bg) || !nzchar(bg)) {
    return("")
  }
  sprintf(
    "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"%s\"/>",
    .docx_normalize_color(bg)
  )
}

# Translate a `style_node` to a `<w:rPr>` XML fragment carrying
# run-level properties: bold, italic, underline, color, font
# family, font size. Returns the fragment WITHOUT the outer
# `<w:rPr>` tag — callers concatenate with an inherited default
# run-property string to build the final element.
#
# Property mapping:
#   @bold = TRUE              -> <w:b/>
#   @italic = TRUE            -> <w:i/>
#   @underline = TRUE         -> <w:u w:val="single"/>
#   @color = "#RRGGBB"        -> <w:color w:val="RRGGBB"/>
#   @font_family = "Arial"    -> <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
#   @font_size = 10           -> <w:sz w:val="20"/>  (half-points)
#
# Emission order is stable (declaration order in style_node) so
# byte-determinism is trivial.
.docx_rPr_from_style <- function(style, preset = NULL, bold_default = FALSE) {
  if (!is_style_node(style)) {
    style <- style_node()
  }
  parts <- character()
  if (!is.na(style@font_family) && nzchar(style@font_family)) {
    family <- .docx_escape_attr(style@font_family)
    parts <- c(
      parts,
      sprintf(
        "<w:rFonts w:ascii=\"%s\" w:hAnsi=\"%s\"/>",
        family,
        family
      )
    )
  }
  # `bold_default = TRUE` (group-header / subgroup surfaces): bold unless
  # explicitly turned off (NA == bold). Otherwise (body cells): bold only
  # when explicitly set TRUE.
  bold_on <- if (bold_default) {
    !isFALSE(style@bold)
  } else {
    isTRUE(style@bold)
  }
  if (bold_on) {
    parts <- c(parts, "<w:b/>")
  }
  if (isTRUE(style@italic)) {
    parts <- c(parts, "<w:i/>")
  }
  # After the Task 4/5 cut, the lowered `preset(colors = list(text = ...))`
  # knob stamps `@color` onto every body cell via the cells_body()
  # layer cascade. So `style@color` already carries the theme
  # default — no preset slot to fall through to.
  if (!is.na(style@color) && nzchar(style@color)) {
    parts <- c(
      parts,
      sprintf(
        "<w:color w:val=\"%s\"/>",
        .docx_normalize_color(style@color)
      )
    )
  }
  if (!is.na(style@font_size) && is.numeric(style@font_size)) {
    parts <- c(
      parts,
      sprintf(
        "<w:sz w:val=\"%d\"/>",
        as.integer(round(style@font_size * 2))
      )
    )
  }
  if (isTRUE(style@underline)) {
    parts <- c(parts, "<w:u w:val=\"single\"/>")
  }
  paste(parts, collapse = "")
}

# Emit a `<w:tcMar>` block from the cell's per-side padding. Word's
# tcMar uses twentieths-of-a-point (dxa) per side. Per-cell
# `padding_<side>` overrides (lowered from `preset(padding =
# list(body = ...))` / `style(at = cells_body(), padding = ...)`) win;
# unset sides fall back to the `preset@cell_padding` shorthand. A
# default-zero vertical margin is omitted (Word's own default applies),
# so the common case emits only left / right and matches the measured
# column width; an explicit per-cell vertical padding emits a 0 too.
.docx_tcMar_from_style <- function(style, preset = NULL) {
  base <- if (is_preset_spec(preset)) {
    .cell_padding_sides(preset)
  } else {
    c(top = NA_real_, right = NA_real_, bottom = NA_real_, left = NA_real_)
  }
  over <- c(
    top = NA_real_,
    right = NA_real_,
    bottom = NA_real_,
    left = NA_real_
  )
  if (is_style_node(style)) {
    over <- vapply(
      c("top", "right", "bottom", "left"),
      function(s) {
        v <- S7::prop(style, paste0("padding_", s))
        if (length(v) == 1L) as.numeric(v) else NA_real_
      },
      numeric(1L)
    )
  }
  inner <- character()
  # OOXML cell-margin order: top -> left -> bottom -> right.
  for (s in c("top", "left", "bottom", "right")) {
    overridden <- !is.na(over[[s]])
    val <- if (overridden) over[[s]] else base[[s]]
    if (is.na(val)) {
      next
    }
    # Skip a default-zero vertical margin (no per-cell override) to keep
    # the common case lean; emit it when explicitly set.
    if (val == 0 && !overridden && s %in% c("top", "bottom")) {
      next
    }
    inner <- c(
      inner,
      sprintf(
        "<w:%s w:w=\"%d\" w:type=\"dxa\"/>",
        s,
        as.integer(round(val * 20))
      )
    )
  }
  if (length(inner) == 0L) {
    return("")
  }
  paste0("<w:tcMar>", paste(inner, collapse = ""), "</w:tcMar>")
}

# Normalize a hex color to the OOXML `RRGGBB` form (no leading "#",
# uppercase letters). Accepts "#RRGGBB", "#rrggbb", "RRGGBB", or
# "rrggbb" inputs. Defaults to "000000" on malformed input so the
# document never carries an invalid color attribute.
.docx_normalize_color <- function(color) {
  s <- toupper(sub("^#", "", as.character(color)))
  if (!grepl("^[0-9A-F]{6}$", s)) {
    return("000000")
  }
  s
}

# ---------------------------------------------------------------------
# Inline AST -> <w:r> runs
# ---------------------------------------------------------------------

# Render an inline_ast to an OOXML run sequence (zero or more
# `<w:r>` elements, possibly wrapped by `<w:hyperlink>` for links).
# Returns "" when `ast` is not an inline_ast (defensive — keeps
# callers terse).
#
# `default_rpr` is an `<w:rPr>` fragment applied to every otherwise-
# unstyled plain run. Callers use this to set a paragraph-wide
# default (e.g. bold for titles + column labels).
.render_docx_inline <- function(
  ast,
  hyperlinks = character(),
  default_rpr = "",
  rid_map = NULL
) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(
      ast@runs,
      function(run) .render_docx_run(run, hyperlinks, default_rpr, rid_map),
      character(1L)
    ),
    collapse = ""
  )
}

# Render one inline_ast run record to its OOXML markup. Recurses
# through `children` for wrapping types via `.render_docx_children()`.
# The dispatch table mirrors `.render_rtf_run()` 1:1 so AST behaviour
# is consistent across backends — only the markup differs.
.render_docx_run <- function(
  run,
  hyperlinks,
  default_rpr = "",
  rid_map = NULL
) {
  type <- run$type
  switch(
    type,
    plain = .docx_run_plain(run$text %||% "", default_rpr),
    bold = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:b/>",
      default_rpr,
      rid_map
    ),
    italic = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:i/>",
      default_rpr,
      rid_map
    ),
    sup = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:vertAlign w:val=\"superscript\"/>",
      default_rpr,
      rid_map
    ),
    sub = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:vertAlign w:val=\"subscript\"/>",
      default_rpr,
      rid_map
    ),
    code = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:rFonts w:ascii=\"Liberation Mono\" w:hAnsi=\"Liberation Mono\" w:cs=\"Liberation Mono\"/>",
      default_rpr,
      rid_map
    ),
    link = .render_docx_link(run, hyperlinks, default_rpr, rid_map),
    span = .render_docx_children(
      run$children,
      hyperlinks,
      default_rpr,
      rid_map
    ),
    newline = "<w:r><w:br/></w:r>",
    .docx_run_plain(run$text %||% "", default_rpr)
  )
}

# Canonical OOXML CT_RPr child order (ECMA-376-1:2016 17.3.2.7),
# restricted to the run-property elements tabular emits. The inline
# markup path accumulates rPr fragments in nesting order
# (`.docx_run_wrap()` appends each wrap token to the inherited string),
# which is arbitrary relative to the schema sequence: bold-inside-italic
# lands as `<w:i/><w:b/>` and a hyperlink inside bold as
# `<w:b/><w:rStyle/>`. That is well-formed XML but schema-invalid, and
# Word rejects it as "unreadable content". `.docx_sort_rpr()` reorders
# the accumulated self-closing fragments into canonical order at the one
# point where they become a `<w:rPr>` element. (`.docx_rPr_from_style()`
# already emits in canonical order, so single-property cell runs are
# unaffected; the sort is idempotent on an already-ordered string.)
.docx_rpr_order <- c(
  rStyle = 1L,
  rFonts = 2L,
  b = 3L,
  bCs = 4L,
  i = 5L,
  iCs = 6L,
  strike = 7L,
  color = 8L,
  sz = 9L,
  szCs = 10L,
  u = 11L,
  vertAlign = 12L
)

.docx_sort_rpr <- function(rpr) {
  if (!nzchar(rpr)) {
    return(rpr)
  }
  frags <- regmatches(
    rpr,
    gregexpr("<w:[A-Za-z]+(?: [^>]*)?/>", rpr, perl = TRUE)
  )[[1L]]
  # Reorder only when the string is cleanly a run of self-closing tags
  # (it always is in practice). If the regex did not account for every
  # byte, something unexpected is present, so leave it untouched rather
  # than risk dropping content. A single fragment needs no sorting.
  if (length(frags) < 2L || sum(nchar(frags)) != nchar(rpr)) {
    return(rpr)
  }
  local <- sub("^<w:([A-Za-z]+).*$", "\\1", frags)
  rank <- unname(.docx_rpr_order[local])
  rank[is.na(rank)] <- 999L
  # `order(rank, seq_along)` is a stable sort: equal-rank and unknown
  # elements keep their original relative position.
  paste0(frags[order(rank, seq_along(frags))], collapse = "")
}

# Render a plain text run with an optional `<w:rPr>` block. The
# `xml:space="preserve"` attribute is non-negotiable: cell text
# arrives with leading / trailing NBSP padding from engine_decimal,
# and Word collapses unprotected whitespace at render time.
.docx_run_plain <- function(text, default_rpr) {
  rpr <- if (nzchar(default_rpr)) {
    paste0("<w:rPr>", .docx_sort_rpr(default_rpr), "</w:rPr>")
  } else {
    ""
  }
  paste0(
    "<w:r>",
    rpr,
    "<w:t xml:space=\"preserve\">",
    .docx_escape(text),
    "</w:t></w:r>"
  )
}

# Emit a body / section-header cell's text as one or more runs,
# splitting embedded newlines (`\n`, `\r\n`) into `<w:br/>` breaks so a
# multi-line cell value renders as separate lines instead of a single
# space-joined line. `rpr` is the ready `<w:rPr>...</w:rPr>` block (or
# ""), reused on every text run; the break run carries no props.
# Significant spaces ride verbatim via `xml:space="preserve"`, so DOCX
# needs no non-breaking token. A single-line value yields exactly the
# prior one-run markup (byte-identical), so only multi-line cells move.
.docx_body_runs <- function(text, rpr) {
  if (is.null(text) || length(text) != 1L || is.na(text)) {
    text <- ""
  }
  # Peel any auto-footnote marker sentinel off the cell end; it becomes
  # a superscript run appended after the body runs.
  peeled <- .fn_peel(as.character(text))
  text <- gsub("\r\n", "\n", peeled$base, fixed = TRUE)
  parts <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (length(parts) == 0L) {
    parts <- ""
  }
  run <- function(p) {
    paste0(
      "<w:r>",
      rpr,
      "<w:t xml:space=\"preserve\">",
      .docx_escape(p),
      "</w:t></w:r>"
    )
  }
  body <- paste0(
    vapply(parts, run, character(1L), USE.NAMES = FALSE),
    collapse = "<w:r><w:br/></w:r>"
  )
  if (isTRUE(peeled$has)) {
    body <- paste0(body, .docx_fn_sup_run(peeled$marker, rpr))
  }
  body
}

# Emit a footnote-marker superscript run: the cell's inherited run
# properties plus `<w:vertAlign w:val="superscript"/>`, canonically
# ordered. `rpr` is the cell's full `<w:rPr>...</w:rPr>` block (or "").
#' @noRd
.docx_fn_sup_run <- function(marker, rpr) {
  inner <- sub("^<w:rPr>(.*)</w:rPr>$", "\\1", rpr)
  if (identical(inner, rpr)) {
    inner <- "" # rpr was "" (no wrapper present)
  }
  inner <- paste0(inner, "<w:vertAlign w:val=\"superscript\"/>")
  paste0(
    "<w:r><w:rPr>",
    .docx_sort_rpr(inner),
    "</w:rPr><w:t xml:space=\"preserve\">",
    .docx_escape(marker),
    "</w:t></w:r>"
  )
}

# Render a wrapping run (`bold` / `italic` / `sup` / `sub` / `code`).
# Each child is rendered with the wrap's `<w:rPr>` token MERGED with
# the inherited `default_rpr` so nested formatting compounds
# correctly (e.g. bold inside italic -> both `<w:b/>` and `<w:i/>`
# inside the same `<w:rPr>`).
.docx_run_wrap <- function(
  children,
  hyperlinks,
  rpr_token,
  default_rpr,
  rid_map = NULL
) {
  inherited <- paste0(default_rpr, rpr_token)
  .render_docx_children(children, hyperlinks, inherited, rid_map)
}

# Render the children of a wrapping run.
.render_docx_children <- function(
  children,
  hyperlinks,
  default_rpr,
  rid_map = NULL
) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(
      children,
      function(run) .render_docx_run(run, hyperlinks, default_rpr, rid_map),
      character(1L)
    ),
    collapse = ""
  )
}

# Render a link run as `<w:hyperlink r:id="rIdLinkN">...</w:hyperlink>`,
# where N is the 1-indexed position of the link's URL in the
# pre-walked `hyperlinks` registry. The link's child runs render
# inside the wrapper with hyperlink visual styling
# (`<w:rStyle w:val="Hyperlink"/>` plus inherited default_rpr).
# Unknown / missing URL falls back to plain rendering with the
# link text so the document never carries a dangling `r:id`.
.render_docx_link <- function(run, hyperlinks, default_rpr, rid_map = NULL) {
  href <- run$href %||% ""
  if (!nzchar(href)) {
    return(.render_docx_children(
      run$children,
      hyperlinks,
      default_rpr,
      rid_map
    ))
  }
  idx <- match(href, hyperlinks)
  if (is.na(idx) || is.null(rid_map) || length(rid_map$hyperlinks) < idx) {
    # Defensive — shouldn't happen since the registry was built by
    # walking the same AST. Fall back to plain text rendering.
    return(.render_docx_children(
      run$children,
      hyperlinks,
      default_rpr,
      rid_map
    ))
  }
  link_rpr <- paste0(
    default_rpr,
    "<w:rStyle w:val=\"Hyperlink\"/>"
  )
  inner <- .render_docx_children(run$children, hyperlinks, link_rpr, rid_map)
  sprintf(
    "<w:hyperlink r:id=\"%s\">%s</w:hyperlink>",
    rid_map$hyperlinks[[idx]],
    inner
  )
}

# Walk every inline_ast in the grid that may carry hyperlinks
# (titles, footnotes, column labels, body cell ASTs from any page)
# and return a deduplicated, first-encounter-ordered character
# vector of URLs. Used by `.docx_zip_entries()` to assign rIds
# once, before either the document XML or the rels file is built.
.docx_collect_hyperlinks <- function(grid) {
  meta <- grid@metadata
  urls <- character()
  walk <- function(ast) {
    if (!is_inline_ast(ast)) {
      return(invisible(NULL))
    }
    for (run in ast@runs) {
      urls <<- c(urls, .docx_link_urls_in_run(run))
    }
  }
  for (ast in (meta$titles_ast %||% list())) {
    walk(ast)
  }
  for (ast in (meta$footnotes_ast %||% list())) {
    walk(ast)
  }
  for (ast in (meta$col_labels_ast %||% list())) {
    walk(ast)
  }
  for (page in grid@pages) {
    cells_ast <- page$cells_ast
    if (is.list(cells_ast)) {
      for (ast in cells_ast) {
        walk(ast)
      }
    }
  }
  unique(urls[nzchar(urls)])
}

# Recursive helper: return every `href` reachable from one run,
# walking through `children` for wrapping runs. Returns
# `character(0)` when no link is present.
.docx_link_urls_in_run <- function(run) {
  if (!is.list(run) || is.null(run$type)) {
    return(character())
  }
  if (identical(run$type, "link")) {
    href <- run$href %||% ""
    return(c(
      href,
      unlist(lapply(run$children %||% list(), .docx_link_urls_in_run))
    ))
  }
  unlist(lapply(run$children %||% list(), .docx_link_urls_in_run))
}

# ---------------------------------------------------------------------
# XML escaping
# ---------------------------------------------------------------------

# Escape XML text content: &, <, >. " and ' are left alone (legal
# in text nodes). NULL / NA / character(0) coerce to "" for safety.
.docx_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  if (length(text) > 1L) {
    return(unname(vapply(text, .docx_escape, character(1L))))
  }
  if (is.na(text)) {
    return("")
  }
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text
}

# Escape XML attribute content: text-escape rules plus " (the
# attribute delimiter). Use whenever a value is placed inside
# w:val="..." / w:ascii="..." / w:fill="..." etc.
.docx_escape_attr <- function(text) {
  out <- .docx_escape(text)
  gsub("\"", "&quot;", out, fixed = TRUE)
}

# ---------------------------------------------------------------------
# Self-registration
# ---------------------------------------------------------------------

.register_backend("docx", backend_docx)
