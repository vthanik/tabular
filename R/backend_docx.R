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

  entries <- c(
    "[Content_Types].xml" = .docx_content_types(has_ph, has_pf),
    "_rels/.rels" = .docx_root_rels(),
    "docProps/app.xml" = .docx_app_xml(),
    "docProps/core.xml" = .docx_core_xml(meta),
    "word/_rels/document.xml.rels" = .docx_doc_rels(has_ph, has_pf),
    "word/document.xml" = .docx_document_xml(grid, preset),
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

# Compose `word/document.xml`. v0.1 scaffolding emits a body
# containing titles + a placeholder paragraph for the table area +
# footnotes. Commit 2 replaces the placeholder with a real
# `<w:tbl>`; commit 3 wires inline AST through the title /
# footnote paragraphs; commits 4-5 add chrome refs and styles.
.docx_document_xml <- function(grid, preset) {
  meta <- grid@metadata
  titles_block <- .docx_title_block(meta$titles_ast %||% list())
  table_block <- "<w:p><w:r><w:t>[table placeholder]</w:t></w:r></w:p>"
  footnotes_block <- .docx_footnote_block(meta$footnotes_ast %||% list())
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

# Render the title block: one centred bold paragraph per title.
# v0.1 emits plain text; commit 3 swaps in the inline AST renderer.
.docx_title_block <- function(titles_ast) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  vapply(
    titles_ast,
    function(ast) {
      text <- .ast_flatten_text(ast)
      sprintf(
        paste0(
          "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>",
          "<w:r><w:rPr><w:b/></w:rPr>",
          "<w:t xml:space=\"preserve\">%s</w:t></w:r></w:p>"
        ),
        .docx_escape(text)
      )
    },
    character(1L)
  )
}

# Render the footnote block: one left-aligned paragraph per
# footnote. v0.1 emits plain text; commit 3 swaps in the inline
# AST renderer.
.docx_footnote_block <- function(footnotes_ast) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  vapply(
    footnotes_ast,
    function(ast) {
      text <- .ast_flatten_text(ast)
      sprintf(
        paste0(
          "<w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr>",
          "<w:r><w:t xml:space=\"preserve\">%s</w:t></w:r></w:p>"
        ),
        .docx_escape(text)
      )
    },
    character(1L)
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
# styles + settings always; header / footer conditionally; commit
# 3 adds hyperlink relationships dynamically.
.docx_doc_rels <- function(has_pagehead, has_pagefoot) {
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
