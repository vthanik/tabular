# backend_docx.R — DOCX (Office Open XML, ECMA-376) backend.
# Consumes a resolved `tabular_grid` and writes a regulatory-grade
# `.docx` ZIP package whose page chrome, header bands, decimal
# alignment, multi-page pagination, inline formatting, and per-cell
# styling all honour the BMS Appendix I layout contract. Output
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
#   (1) Fixed mtime per zip entry — `zip::zip()` is called with
#       `mtime = .docx_fixed_mtime` (the FAT epoch floor,
#       1980-01-01 00:00:00 UTC).
#   (2) Sorted entry order — files passed to `zip::zip()` are sorted
#       alphabetically; no iteration-order randomness.
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

# OOXML namespace declarations needed on every <w:document> /
# <w:hdr> / <w:ftr> root. Kept in one place so all roots emit the
# same prologue and byte-determinism stays trivial.
.docx_ns_w <- "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\""
.docx_ns_r <- "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""

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
  entries <- .docx_zip_entries(grid)
  .docx_write_zip(entries, file)
  invisible(file)
}

# ---------------------------------------------------------------------
# Document assembly
# ---------------------------------------------------------------------

# Build the full set of OOXML files for this grid. Returns a named
# character vector (names = relative zip paths, values = file
# contents as UTF-8 strings). Pure — no I/O.
.docx_zip_entries <- function(grid) {
  meta <- grid@metadata
  preset <- .docx_resolve_preset(meta$preset)
  has_ph <- .page_band_is_populated(meta$pagehead_ast)
  has_pf <- .page_band_is_populated(meta$pagefoot_ast)

  # One-pass hyperlink walk over every AST surface so the rels file
  # and the inline renderer agree on rId numbering. First-encounter
  # order is deterministic given the walk order in
  # `.docx_collect_hyperlinks()`.
  hyperlinks <- .docx_collect_hyperlinks(grid)

  entries <- c(
    "[Content_Types].xml" = .docx_content_types(has_ph, has_pf),
    "_rels/.rels" = .docx_root_rels(),
    "docProps/app.xml" = .docx_app_xml(),
    "docProps/core.xml" = .docx_core_xml(meta),
    "word/_rels/document.xml.rels" = .docx_doc_rels(
      has_ph,
      has_pf,
      hyperlinks
    ),
    "word/document.xml" = .docx_document_xml(grid, preset, hyperlinks),
    "word/settings.xml" = .docx_settings_xml(),
    "word/styles.xml" = .docx_styles_xml(preset)
  )
  if (has_ph) {
    entries[["word/header1.xml"]] <- .docx_header_xml(
      meta$pagehead_ast,
      preset
    )
  }
  if (has_pf) {
    entries[["word/footer1.xml"]] <- .docx_footer_xml(
      meta$pagefoot_ast,
      preset
    )
  }
  entries[sort(names(entries))]
}

# Resolve the active preset, falling back to factory defaults when
# the grid carries no preset attachment (matches every other
# backend's pattern).
.docx_resolve_preset <- function(preset) {
  if (is.null(preset) || !is_preset_spec(preset)) preset_spec() else preset
}

# Compose `word/document.xml`. Body is: title block (page-1
# centred + bold) -> table (one `<w:tbl>` containing header bands +
# column labels + all body rows from grid@pages, with `<w:tblHeader/>`
# on header rows so Word naturally repeats them on page-break) ->
# footnote block -> trailing `<w:sectPr>` carrying page geometry.
# Inline AST runs through `.render_docx_inline()` everywhere user
# content appears (titles, footnotes, col labels, body cells).
# Commits 4-5 wire page chrome refs and per-cell styling.
.docx_document_xml <- function(grid, preset, hyperlinks) {
  meta <- grid@metadata
  titles_block <- .docx_title_block(
    meta$titles_ast %||% list(),
    hyperlinks
  )
  table_block <- .render_docx_table(grid, preset, hyperlinks)
  footnotes_block <- .docx_footnote_block(
    meta$footnotes_ast %||% list(),
    hyperlinks
  )
  sect_pr <- .docx_section_pr(
    preset,
    has_pagehead = FALSE,
    has_pagefoot = FALSE
  )

  body <- paste0(
    paste(titles_block, collapse = ""),
    table_block,
    paste(footnotes_block, collapse = ""),
    sect_pr
  )
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<w:document ",
    .docx_ns_w,
    " ",
    .docx_ns_r,
    "><w:body>",
    body,
    "</w:body></w:document>"
  )
}

# Render the title block: one centred paragraph per title with
# the title's inline AST rendered through `.render_docx_inline()`.
# An outer bold wrap (commit-2 default) is applied via the
# paragraph's run defaults inherited from word/styles.xml — we
# only set bold here when the AST has no explicit run styling.
.docx_title_block <- function(titles_ast, hyperlinks) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  vapply(
    titles_ast,
    function(ast) {
      runs <- .render_docx_inline(ast, hyperlinks, default_rpr = "<w:b/>")
      paste0(
        "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>",
        runs,
        "</w:p>"
      )
    },
    character(1L)
  )
}

# Render the footnote block: one left-aligned paragraph per
# footnote. Inline AST flows through `.render_docx_inline()` so
# bold / italic / sup / link markup all surface in the .docx.
.docx_footnote_block <- function(footnotes_ast, hyperlinks) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  vapply(
    footnotes_ast,
    function(ast) {
      runs <- .render_docx_inline(ast, hyperlinks)
      paste0(
        "<w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr>",
        runs,
        "</w:p>"
      )
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Table emission
# ---------------------------------------------------------------------

# Compose the `<w:tbl>` for this grid. Renders one table containing:
# multi-level header bands -> column-labels row -> body rows
# concatenated across all `grid@pages` entries. Header rows carry
# `<w:tblHeader/>` so Word repeats them after every page break it
# computes on its own.
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
.render_docx_table <- function(grid, preset, hyperlinks = character()) {
  meta <- grid@metadata
  pages <- grid@pages
  if (length(pages) == 0L) {
    return("<w:p><w:r><w:rPr><w:i/></w:rPr><w:t>(no rows)</w:t></w:r></w:p>")
  }
  col_names_vis <- pages[[1L]]$col_names
  cols <- meta$cols %||% list()
  widths <- .docx_col_widths_twips(col_names_vis, cols, preset)

  band_rows <- .render_docx_header_bands(
    meta$headers,
    col_names_vis,
    widths
  )
  label_row <- .render_docx_col_labels_row(
    meta$col_labels_ast,
    col_names_vis,
    cols,
    widths,
    hyperlinks
  )
  body_rows <- .render_docx_body_rows(pages, col_names_vis, cols, widths)

  paste0(
    "<w:tbl>",
    .docx_tbl_pr(sum(widths)),
    .docx_tbl_grid(widths),
    paste(band_rows, collapse = ""),
    label_row,
    paste(body_rows, collapse = ""),
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
# total width in twips. `<w:tblBorders>` is omitted; rules live on
# individual cells (commit 5 wires per-cell rule_above / rule_below).
.docx_tbl_pr <- function(total_twips) {
  paste0(
    "<w:tblPr>",
    sprintf("<w:tblW w:w=\"%d\" w:type=\"dxa\"/>", total_twips),
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
.render_docx_header_bands <- function(headers, col_names_vis, widths_twips) {
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
    runs <- .group_contiguous_runs(labels)
    cells <- character(length(runs))
    cursor <- 1L
    for (i in seq_along(runs)) {
      run <- runs[[i]]
      span <- run$length
      end <- cursor + span - 1L
      cell_w <- sum(widths_twips[cursor:end])
      label <- run$value
      tc_pr <- paste0(
        "<w:tcPr>",
        sprintf("<w:tcW w:w=\"%d\" w:type=\"dxa\"/>", cell_w),
        if (span > 1L) sprintf("<w:gridSpan w:val=\"%d\"/>", span) else "",
        "</w:tcPr>"
      )
      content <- if (is.na(label)) {
        "<w:p/>"
      } else {
        paste0(
          "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>",
          "<w:r><w:rPr><w:b/></w:rPr>",
          "<w:t xml:space=\"preserve\">",
          .docx_escape(label),
          "</w:t></w:r></w:p>"
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
# alignment from `col_spec@align`, label flow from the inline AST
# through `.render_docx_inline()`. Default run formatting is bold
# (clinical header convention). Header row carries `<w:tblHeader/>`
# for Word's auto-repeat across pagination.
.render_docx_col_labels_row <- function(
  col_labels_ast,
  col_names_vis,
  cols,
  widths_twips,
  hyperlinks
) {
  cells <- vapply(
    seq_along(col_names_vis),
    function(j) {
      nm <- col_names_vis[[j]]
      ast <- col_labels_ast[[nm]]
      runs <- if (is_inline_ast(ast)) {
        .render_docx_inline(ast, hyperlinks, default_rpr = "<w:b/>")
      } else {
        paste0(
          "<w:r><w:rPr><w:b/></w:rPr>",
          "<w:t xml:space=\"preserve\">",
          .docx_escape(nm),
          "</w:t></w:r>"
        )
      }
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      jc <- .docx_align_token(align)
      tc_pr <- sprintf(
        "<w:tcPr><w:tcW w:w=\"%d\" w:type=\"dxa\"/></w:tcPr>",
        widths_twips[[j]]
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
# engine_decimal flat string (`cells_text`); commit 3 swaps in the
# inline-AST renderer where appropriate. Per-cell alignment comes
# from `col_spec@align`.
.render_docx_body_rows <- function(pages, col_names_vis, cols, widths_twips) {
  align_tokens <- vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      .docx_align_token(if (is_col_spec(cs)) cs@align else NA_character_)
    },
    character(1L)
  )
  out <- character()
  for (page in pages) {
    ct <- page$cells_text
    nrows <- nrow(ct)
    if (is.null(nrows) || nrows == 0L) {
      next
    }
    for (i in seq_len(nrows)) {
      cells <- vapply(
        seq_along(col_names_vis),
        function(j) {
          tc_pr <- sprintf(
            "<w:tcPr><w:tcW w:w=\"%d\" w:type=\"dxa\"/></w:tcPr>",
            widths_twips[[j]]
          )
          paste0(
            "<w:tc>",
            tc_pr,
            "<w:p><w:pPr>",
            align_tokens[[j]],
            "</w:pPr><w:r>",
            "<w:t xml:space=\"preserve\">",
            .docx_escape(ct[i, j]),
            "</w:t></w:r></w:p></w:tc>"
          )
        },
        character(1L)
      )
      out <- c(out, paste0("<w:tr>", paste(cells, collapse = ""), "</w:tr>"))
    }
  }
  out
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

# ---------------------------------------------------------------------
# Section properties (page geometry)
# ---------------------------------------------------------------------

# Compose the trailing `<w:sectPr>` carrying paper size, orientation,
# margins, and (when chrome is populated) header / footer references.
# Lives at the end of `<w:body>` so it applies to the document body.
.docx_section_pr <- function(preset, has_pagehead, has_pagefoot) {
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
  pg_mar <- sprintf(
    "<w:pgMar w:top=\"%d\" w:right=\"%d\" w:bottom=\"%d\" w:left=\"%d\" w:header=\"720\" w:footer=\"720\" w:gutter=\"0\"/>",
    margins$top,
    margins$right,
    margins$bottom,
    margins$left
  )
  refs <- character()
  if (has_pagehead) {
    refs <- c(
      refs,
      "<w:headerReference r:id=\"rIdH\" w:type=\"default\"/>"
    )
  }
  if (has_pagefoot) {
    refs <- c(
      refs,
      "<w:footerReference r:id=\"rIdF\" w:type=\"default\"/>"
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
# Page chrome — placeholder for v0.1 (commit 4 wires real chrome)
# ---------------------------------------------------------------------

# Render `word/header1.xml`. v0.1 emits an empty header skeleton;
# commit 4 implements real L/C/R-slot chrome rows + PAGE / NUMPAGES
# field codes.
.docx_header_xml <- function(pagehead_ast, preset) {
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<w:hdr ",
    .docx_ns_w,
    " ",
    .docx_ns_r,
    "><w:p/></w:hdr>"
  )
}

# Render `word/footer1.xml`. v0.1 emits an empty footer skeleton;
# commit 4 implements real L/C/R-slot chrome rows + PAGE / NUMPAGES
# field codes.
.docx_footer_xml <- function(pagefoot_ast, preset) {
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<w:ftr ",
    .docx_ns_w,
    " ",
    .docx_ns_r,
    "><w:p/></w:ftr>"
  )
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
    "<Override PartName=\"/word/settings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/>",
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>"
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
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
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
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>",
    "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>",
    "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>",
    "</Relationships>"
  )
}

# `word/_rels/document.xml.rels` — document-level relationships:
# styles + settings always; header / footer conditionally; one
# hyperlink relationship per unique URL collected from the grid's
# inline ASTs (rId = `rIdLinkN`, 1-indexed, first-encounter order).
# `TargetMode="External"` is mandatory on every hyperlink rel.
.docx_doc_rels <- function(
  has_pagehead,
  has_pagefoot,
  hyperlinks = character()
) {
  rels <- c(
    "<Relationship Id=\"rIdS\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
    "<Relationship Id=\"rIdT\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>"
  )
  if (has_pagehead) {
    rels <- c(
      rels,
      "<Relationship Id=\"rIdH\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>"
    )
  }
  if (has_pagefoot) {
    rels <- c(
      rels,
      "<Relationship Id=\"rIdF\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>"
    )
  }
  for (i in seq_along(hyperlinks)) {
    rels <- c(
      rels,
      sprintf(
        "<Relationship Id=\"rIdLink%d\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"%s\" TargetMode=\"External\"/>",
        i,
        .docx_escape_attr(hyperlinks[[i]])
      )
    )
  }
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
    paste(rels, collapse = ""),
    "</Relationships>"
  )
}

# `word/styles.xml` — minimal style definitions. Default run +
# paragraph properties are set from `preset@font_family` (resolved
# via the cross-backend font stack) and `preset@font_size`
# (converted to half-points). Word inherits everything else from
# its built-in Normal style; we don't override paragraph spacing,
# indent, or numbering.
.docx_styles_xml <- function(preset) {
  family <- .docx_primary_font(preset@font_family)
  half_pts <- as.integer(round(preset@font_size * 2))
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<w:styles ",
    .docx_ns_w,
    "><w:docDefaults><w:rPrDefault><w:rPr>",
    sprintf(
      "<w:rFonts w:ascii=\"%s\" w:hAnsi=\"%s\" w:cs=\"%s\"/>",
      .docx_escape_attr(family),
      .docx_escape_attr(family),
      .docx_escape_attr(family)
    ),
    sprintf("<w:sz w:val=\"%d\"/><w:szCs w:val=\"%d\"/>", half_pts, half_pts),
    "</w:rPr></w:rPrDefault></w:docDefaults></w:styles>"
  )
}

# `word/settings.xml` — minimum settings: compatibility mode
# (Word 2013+), default tab stop. Determinism: no `<w:rsids>`
# block, which would otherwise carry random revision-save IDs.
.docx_settings_xml <- function() {
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<w:settings ",
    .docx_ns_w,
    "><w:defaultTabStop w:val=\"720\"/>",
    "<w:compat><w:compatSetting w:name=\"compatibilityMode\" w:uri=\"http://schemas.microsoft.com/office/word\" w:val=\"15\"/></w:compat>",
    "</w:settings>"
  )
}

# `docProps/app.xml` — application metadata. Static so the output
# stays byte-deterministic. `tabular` is the named creator; the
# version string is read from the installed package DESCRIPTION at
# the time of emission (and DESCRIPTION is also deterministic
# per-release).
.docx_app_xml <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("tabular")),
    error = function(e) "0.0.0"
  )
  paste0(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">",
    "<Application>tabular (R package)</Application>",
    sprintf("<AppVersion>%s</AppVersion>", .docx_escape(version)),
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
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n",
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
# -> UTF-8 string contents) to `file` as a deterministic ZIP.
# Uses `zip::zip()` for fixed mtime control; the base R
# `utils::zip()` would shell out to a system binary and bake in
# the host filesystem's mtimes, which breaks reproducibility.
.docx_write_zip <- function(entries, file) {
  tmp <- tempfile("tabular_docx_")
  dir.create(tmp, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  rels <- names(entries)
  for (rel in rels) {
    abs_path <- file.path(tmp, rel)
    dir.create(dirname(abs_path), recursive = TRUE, showWarnings = FALSE)
    writeLines(entries[[rel]], abs_path, useBytes = TRUE)
    Sys.setFileTime(abs_path, .docx_fixed_mtime)
  }

  # zip::zip() writes the central directory in the order files are
  # passed; we sorted alphabetically in `.docx_zip_entries()` so
  # the order is stable. `mode = "mirror"` stores each file with
  # its path RELATIVE TO root — critical for OOXML, where files
  # MUST live at exact paths (_rels/.rels, word/document.xml etc).
  # `mode = "cherry-pick"` would flatten everything to basenames
  # and the resulting .docx would not open in Word / LibreOffice.
  zip::zip(
    zipfile = file,
    files = rels,
    root = tmp,
    mode = "mirror",
    include_directories = FALSE
  )
  invisible(file)
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
  default_rpr = ""
) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(
      ast@runs,
      function(run) .render_docx_run(run, hyperlinks, default_rpr),
      character(1L)
    ),
    collapse = ""
  )
}

# Render one inline_ast run record to its OOXML markup. Recurses
# through `children` for wrapping types via `.render_docx_children()`.
# The dispatch table mirrors `.render_rtf_run()` 1:1 so AST behaviour
# is consistent across backends — only the markup differs.
.render_docx_run <- function(run, hyperlinks, default_rpr = "") {
  type <- run$type
  switch(
    type,
    plain = .docx_run_plain(run$text %||% "", default_rpr),
    bold = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:b/>",
      default_rpr
    ),
    italic = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:i/>",
      default_rpr
    ),
    sup = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:vertAlign w:val=\"superscript\"/>",
      default_rpr
    ),
    sub = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:vertAlign w:val=\"subscript\"/>",
      default_rpr
    ),
    code = .docx_run_wrap(
      run$children,
      hyperlinks,
      "<w:rFonts w:ascii=\"Liberation Mono\" w:hAnsi=\"Liberation Mono\" w:cs=\"Liberation Mono\"/>",
      default_rpr
    ),
    link = .render_docx_link(run, hyperlinks, default_rpr),
    span = .render_docx_children(run$children, hyperlinks, default_rpr),
    newline = "<w:r><w:br/></w:r>",
    .docx_run_plain(run$text %||% "", default_rpr)
  )
}

# Render a plain text run with an optional `<w:rPr>` block. The
# `xml:space="preserve"` attribute is non-negotiable: cell text
# arrives with leading / trailing NBSP padding from engine_decimal,
# and Word collapses unprotected whitespace at render time.
.docx_run_plain <- function(text, default_rpr) {
  rpr <- if (nzchar(default_rpr)) {
    paste0("<w:rPr>", default_rpr, "</w:rPr>")
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

# Render a wrapping run (`bold` / `italic` / `sup` / `sub` / `code`).
# Each child is rendered with the wrap's `<w:rPr>` token MERGED with
# the inherited `default_rpr` so nested formatting compounds
# correctly (e.g. bold inside italic -> both `<w:b/>` and `<w:i/>`
# inside the same `<w:rPr>`).
.docx_run_wrap <- function(children, hyperlinks, rpr_token, default_rpr) {
  inherited <- paste0(default_rpr, rpr_token)
  .render_docx_children(children, hyperlinks, inherited)
}

# Render the children of a wrapping run.
.render_docx_children <- function(children, hyperlinks, default_rpr) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(
      children,
      function(run) .render_docx_run(run, hyperlinks, default_rpr),
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
.render_docx_link <- function(run, hyperlinks, default_rpr) {
  href <- run$href %||% ""
  if (!nzchar(href)) {
    return(.render_docx_children(run$children, hyperlinks, default_rpr))
  }
  idx <- match(href, hyperlinks)
  if (is.na(idx)) {
    # Defensive — shouldn't happen since the registry was built by
    # walking the same AST. Fall back to plain text rendering.
    return(.render_docx_children(run$children, hyperlinks, default_rpr))
  }
  link_rpr <- paste0(
    default_rpr,
    "<w:rStyle w:val=\"Hyperlink\"/>"
  )
  inner <- .render_docx_children(run$children, hyperlinks, link_rpr)
  sprintf(
    "<w:hyperlink r:id=\"rIdLink%d\">%s</w:hyperlink>",
    idx,
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
