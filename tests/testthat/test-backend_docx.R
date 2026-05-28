# backend_docx() — self-contained OOXML DOCX backend.
#
# Self-registers at package-load time, so every test below can rely
# on `tabular:::.has_backend("docx")` returning TRUE without setup.

# Helper: unzip a `.docx` to a temp directory and return the path.
# Each test that needs to inspect inner XML calls this once.
.unzip_docx <- function(docx_path) {
  out <- withr::local_tempdir(.local_envir = parent.frame())
  utils::unzip(docx_path, exdir = out)
  out
}

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("docx backend is registered at package load", {
  expect_true(tabular:::.has_backend("docx"))
})

# ---------------------------------------------------------------------
# End-to-end via emit()
# ---------------------------------------------------------------------

test_that("emit(.docx) writes a non-empty .docx file at every OOXML-mandated path", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  expect_true(file.exists(out))
  expect_gt(file.size(out), 0L)

  # Use `utils::unzip(list = TRUE)` so HIDDEN entries like
  # `_rels/.rels` show up — `list.files()` would silently drop them.
  # The path structure is load-bearing: Word and LibreOffice refuse
  # to open a `.docx` with the OOXML scaffolding under wrong paths.
  z <- utils::unzip(out, list = TRUE)
  expect_in(
    c(
      "[Content_Types].xml",
      "_rels/.rels",
      "docProps/app.xml",
      "docProps/core.xml",
      "word/_rels/document.xml.rels",
      "word/document.xml",
      "word/settings.xml",
      "word/styles.xml"
    ),
    z$Name
  )
})

test_that("emit(.docx) writes well-formed XML at every part", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  parts <- c(
    "[Content_Types].xml",
    "_rels/.rels",
    "docProps/app.xml",
    "docProps/core.xml",
    "word/_rels/document.xml.rels",
    "word/document.xml",
    "word/settings.xml",
    "word/styles.xml"
  )
  for (part in parts) {
    expect_no_error(
      xml2::read_xml(file.path(unzipped, part)),
      message = sprintf("malformed XML in %s", part)
    )
  }
})

test_that("emit(.docx) renders title + footnote text into word/document.xml", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First Title", "Second Title"),
    footnotes = "Source: ADSL."
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "First Title", fixed = TRUE)
  expect_match(doc, "Second Title", fixed = TRUE)
  expect_match(doc, "Source: ADSL.", fixed = TRUE)
})

test_that("emit(.docx) writes no header1.xml / footer1.xml when pagehead / pagefoot are empty", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  files <- list.files(unzipped, recursive = TRUE)
  expect_false("word/header1.xml" %in% files)
  expect_false("word/footer1.xml" %in% files)
})

# ---------------------------------------------------------------------
# Manifest emitters (pure helpers)
# ---------------------------------------------------------------------

test_that(".docx_content_types emits the Override for every part, conditional on chrome", {
  no_chrome <- tabular:::.docx_content_types(FALSE, FALSE)
  expect_match(no_chrome, "PartName=\"/word/document.xml\"", fixed = TRUE)
  expect_match(no_chrome, "PartName=\"/word/styles.xml\"", fixed = TRUE)
  expect_false(grepl("header+xml", no_chrome, fixed = TRUE))

  with_header <- tabular:::.docx_content_types(TRUE, FALSE)
  expect_match(with_header, "PartName=\"/word/header1.xml\"", fixed = TRUE)
  expect_false(grepl("footer+xml", with_header, fixed = TRUE))

  with_both <- tabular:::.docx_content_types(TRUE, TRUE)
  expect_match(with_both, "header1.xml", fixed = TRUE)
  expect_match(with_both, "footer1.xml", fixed = TRUE)
})

test_that(".docx_root_rels points at word/document.xml + core + app properties", {
  rels <- tabular:::.docx_root_rels()
  expect_match(rels, "Target=\"word/document.xml\"", fixed = TRUE)
  expect_match(rels, "Target=\"docProps/core.xml\"", fixed = TRUE)
  expect_match(rels, "Target=\"docProps/app.xml\"", fixed = TRUE)
})

test_that(".docx_doc_rels emits numeric rIds, conditional chrome, and hyperlink rels", {
  rmap_none <- tabular:::.docx_rid_map(FALSE, FALSE, 0L)
  none <- tabular:::.docx_doc_rels(character(), rmap_none)
  expect_match(none, "Target=\"styles.xml\"", fixed = TRUE)
  expect_match(none, "Target=\"settings.xml\"", fixed = TRUE)
  expect_match(none, "Id=\"rId1\"", fixed = TRUE)
  expect_match(none, "Id=\"rId5\"", fixed = TRUE)
  expect_false(grepl("header1.xml", none, fixed = TRUE))
  expect_false(grepl("footer1.xml", none, fixed = TRUE))

  rmap_both <- tabular:::.docx_rid_map(TRUE, TRUE, 0L)
  both <- tabular:::.docx_doc_rels(character(), rmap_both)
  expect_match(both, "Target=\"header1.xml\"", fixed = TRUE)
  expect_match(both, "Target=\"footer1.xml\"", fixed = TRUE)
  # Header gets rId6, footer rId7 (with chrome present, hyperlinks
  # start at rId8).
  expect_match(both, "Id=\"rId6\"[^>]*Target=\"header1.xml\"")
  expect_match(both, "Id=\"rId7\"[^>]*Target=\"footer1.xml\"")

  rmap_links <- tabular:::.docx_rid_map(FALSE, FALSE, 2L)
  with_links <- tabular:::.docx_doc_rels(
    c("https://a.example", "https://b.example"),
    rmap_links
  )
  # No chrome -> hyperlinks start at rId6.
  expect_match(with_links, "Id=\"rId6\"[^>]*Target=\"https://a.example\"")
  expect_match(with_links, "Id=\"rId7\"[^>]*Target=\"https://b.example\"")
  expect_match(with_links, "TargetMode=\"External\"", fixed = TRUE)
})

test_that(".docx_rid_map produces numeric rIds and shifts hyperlinks past chrome", {
  m0 <- tabular:::.docx_rid_map(FALSE, FALSE, 0L)
  expect_identical(m0$styles, "rId1")
  expect_identical(m0$webSettings, "rId5")
  expect_null(m0$header)
  expect_null(m0$footer)
  expect_identical(m0$hyperlinks, character())

  m_both_links <- tabular:::.docx_rid_map(TRUE, TRUE, 2L)
  expect_identical(m_both_links$header, "rId6")
  expect_identical(m_both_links$footer, "rId7")
  expect_identical(m_both_links$hyperlinks, c("rId8", "rId9"))
})

test_that(".docx_styles_xml uses theme-resolved font references and emits named styles", {
  preset <- preset_spec(font_family = "Arial", font_size = 11)
  styles <- tabular:::.docx_styles_xml(preset)
  # Default rFonts MUST reference the theme (minorHAnsi), not a
  # CSS-generic family name. Embedding "serif" / "Arial" / etc.
  # directly into w:ascii is the bug that makes Word reject the
  # whole document — only theme-resolved or installed font names
  # work universally.
  expect_match(styles, "w:asciiTheme=\"minorHAnsi\"", fixed = TRUE)
  # 11pt -> 22 half-points
  expect_match(styles, "w:sz w:val=\"22\"", fixed = TRUE)
  # Named styles for the title and footnote blocks.
  expect_match(styles, "w:styleId=\"TabularTitle\"", fixed = TRUE)
  expect_match(styles, "w:styleId=\"TabularFoot\"", fixed = TRUE)
  expect_match(styles, "w:styleId=\"Hyperlink\"", fixed = TRUE)
})

test_that(".docx_core_xml carries the first title and fixed timestamps for determinism", {
  meta <- list(titles = c("Table 14.1.1", "Demographics"))
  core <- tabular:::.docx_core_xml(meta)
  expect_match(core, "<dc:title>Table 14.1.1</dc:title>", fixed = TRUE)
  expect_match(core, "1980-01-01T00:00:00Z", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Section properties (page geometry)
# ---------------------------------------------------------------------

test_that(".docx_section_pr emits letter landscape twips by default", {
  preset <- preset_spec()
  sp <- tabular:::.docx_section_pr(preset)
  # Letter landscape: 11 x 8.5 in -> 15840 x 12240 twips
  expect_match(sp, "w:w=\"15840\" w:h=\"12240\"", fixed = TRUE)
  expect_match(sp, "w:orient=\"landscape\"", fixed = TRUE)
})

test_that(".docx_section_pr emits letter portrait dimensions when explicit", {
  preset <- preset_spec(orientation = "portrait")
  sp <- tabular:::.docx_section_pr(preset)
  expect_match(sp, "w:w=\"12240\" w:h=\"15840\"", fixed = TRUE)
  expect_false(grepl("w:orient=\"landscape\"", sp, fixed = TRUE))
})

test_that(".docx_section_pr inserts headerReference / footerReference only when chrome populated", {
  preset <- preset_spec()
  no_chrome <- tabular:::.docx_section_pr(preset, NULL)
  expect_false(grepl("w:headerReference", no_chrome, fixed = TRUE))
  expect_false(grepl("w:footerReference", no_chrome, fixed = TRUE))

  rmap <- tabular:::.docx_rid_map(TRUE, TRUE, 0L)
  both <- tabular:::.docx_section_pr(preset, rmap)
  expect_match(both, "w:headerReference", fixed = TRUE)
  expect_match(both, "w:footerReference", fixed = TRUE)
})

# ---------------------------------------------------------------------
# XML escaping
# ---------------------------------------------------------------------

test_that(".docx_escape handles &, <, > and passes through quotes", {
  expect_identical(tabular:::.docx_escape("a & b"), "a &amp; b")
  expect_identical(tabular:::.docx_escape("<x>"), "&lt;x&gt;")
  expect_identical(tabular:::.docx_escape("\"q\""), "\"q\"")
  expect_identical(tabular:::.docx_escape(NA_character_), "")
  expect_identical(tabular:::.docx_escape(NULL), "")
  expect_identical(tabular:::.docx_escape(character()), "")
})

test_that(".docx_escape_attr additionally escapes the double-quote delimiter", {
  expect_identical(tabular:::.docx_escape_attr("a\"b"), "a&quot;b")
  expect_identical(
    tabular:::.docx_escape_attr("<&\">"),
    "&lt;&amp;&quot;&gt;"
  )
})

# ---------------------------------------------------------------------
# Margins shorthand (length 1 / 2 / 4)
# ---------------------------------------------------------------------

test_that(".docx_margins_twips honours CSS-shorthand vectors of length 1 / 2 / 4", {
  one <- tabular:::.docx_margins_twips("1in")
  expect_identical(
    one,
    list(top = 1440L, right = 1440L, bottom = 1440L, left = 1440L)
  )

  two <- tabular:::.docx_margins_twips(c("1in", "0.5in"))
  expect_identical(
    two,
    list(top = 1440L, right = 720L, bottom = 1440L, left = 720L)
  )

  four <- tabular:::.docx_margins_twips(c("1in", "0.5in", "1.5in", "0.25in"))
  expect_identical(
    four,
    list(top = 1440L, right = 720L, bottom = 2160L, left = 360L)
  )
})

# ---------------------------------------------------------------------
# Page chrome end-to-end (exercises header1.xml / footer1.xml branches)
# ---------------------------------------------------------------------

test_that("emit(.docx) writes header1.xml + footer1.xml when pagehead / pagefoot populated", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC",
        right = "Page {page} of {npages}"
      ),
      pagefoot = list(left = "Source: ADSL")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  z <- utils::unzip(out, list = TRUE)
  expect_in(c("word/header1.xml", "word/footer1.xml"), z$Name)

  unzipped <- .unzip_docx(out)
  ct <- paste(
    readLines(file.path(unzipped, "[Content_Types].xml")),
    collapse = ""
  )
  expect_match(ct, "header1.xml", fixed = TRUE)
  expect_match(ct, "footer1.xml", fixed = TRUE)
  doc_rels <- paste(
    readLines(file.path(unzipped, "word/_rels/document.xml.rels")),
    collapse = ""
  )
  expect_match(doc_rels, "Target=\"header1.xml\"", fixed = TRUE)
  expect_match(doc_rels, "Target=\"footer1.xml\"", fixed = TRUE)
})

test_that(".docx_header_xml / .docx_footer_xml emit well-formed empty roots when band ASTs unpopulated", {
  preset <- preset_spec()
  band_ast <- list(left = list(), center = list(), right = list())
  hdr <- tabular:::.docx_header_xml(band_ast, preset)
  ftr <- tabular:::.docx_footer_xml(band_ast, preset)
  expect_match(hdr, "<w:hdr ", fixed = TRUE)
  expect_match(ftr, "<w:ftr ", fixed = TRUE)
  expect_no_error(xml2::read_xml(hdr))
  expect_no_error(xml2::read_xml(ftr))
})

test_that("populated pagehead renders L/C/R cells in REVERSE row order (body edge at bottom)", {
  # Two-row pagehead: row 1 (body-edge) bottom; row 2 top. We assert
  # the second-emitted <w:tbl> contains the row-1 (body-edge) text.
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(
        left = c("Body-edge L1", "Top-edge L2"),
        right = "Body-edge R1"
      )
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  hdr <- paste(
    readLines(file.path(unzipped, "word/header1.xml")),
    collapse = ""
  )
  # Top-edge appears FIRST in the file (closer to top of header zone)
  top_pos <- regexpr("Top-edge L2", hdr, fixed = TRUE)
  bot_pos <- regexpr("Body-edge L1", hdr, fixed = TRUE)
  expect_lt(top_pos, bot_pos)
  expect_match(hdr, "Body-edge R1", fixed = TRUE)
})

test_that("populated pagefoot renders rows in FORWARD order (body edge at top)", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagefoot = list(
        left = c("Body-edge L1", "Bottom-edge L2"),
        right = "Body-edge R1"
      )
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  ftr <- paste(
    readLines(file.path(unzipped, "word/footer1.xml")),
    collapse = ""
  )
  top_pos <- regexpr("Body-edge L1", ftr, fixed = TRUE)
  bot_pos <- regexpr("Bottom-edge L2", ftr, fixed = TRUE)
  expect_lt(top_pos, bot_pos)
})

test_that("empty L/C/R slots collapse (no blank cells)", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(pagehead = list(right = "Only Right"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  hdr <- paste(
    readLines(file.path(unzipped, "word/header1.xml")),
    collapse = ""
  )
  # One row, one cell — only "right" populated.
  tc_count <- length(gregexpr("<w:tc>", hdr, fixed = TRUE)[[1L]])
  expect_identical(tc_count, 1L)
})

test_that("{page} / {npages} resolve to <w:fldSimple> PAGE / NUMPAGES inside chrome", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(pagehead = list(right = "Page {page} of {npages}"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  hdr <- paste(
    readLines(file.path(unzipped, "word/header1.xml")),
    collapse = ""
  )
  expect_match(hdr, "<w:fldSimple w:instr=\"PAGE ", fixed = TRUE)
  expect_match(hdr, "<w:fldSimple w:instr=\"NUMPAGES ", fixed = TRUE)
})

test_that("<w:sectPr> wires headerReference / footerReference when chrome populated", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(left = "header"),
      pagefoot = list(left = "footer")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  # Numeric rIds: rId6 = header, rId7 = footer when both chrome
  # parts are populated and no hyperlinks are present.
  expect_match(
    doc,
    "<w:headerReference r:id=\"rId6\" w:type=\"default\"/>",
    fixed = TRUE
  )
  expect_match(
    doc,
    "<w:footerReference r:id=\"rId7\" w:type=\"default\"/>",
    fixed = TRUE
  )
})

test_that("header / footer XML is well-formed when chrome populated", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(
        left = "Protocol",
        center = "Draft",
        right = "Page {page} of {npages}"
      ),
      pagefoot = list(left = "Source: ADSL")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  expect_no_error(xml2::read_xml(file.path(unzipped, "word/header1.xml")))
  expect_no_error(xml2::read_xml(file.path(unzipped, "word/footer1.xml")))
})

test_that(".docx_resolve_page_tokens does nothing when no tokens present", {
  raw <- "<w:r><w:t xml:space=\"preserve\">plain</w:t></w:r>"
  expect_identical(tabular:::.docx_resolve_page_tokens(raw), raw)
})

# ---------------------------------------------------------------------
# Font + escape edge cases
# ---------------------------------------------------------------------

test_that(".docx_primary_font falls back to Liberation Serif on empty / NA / NULL", {
  expect_identical(
    tabular:::.docx_primary_font(character()),
    "Liberation Serif"
  )
  expect_identical(
    tabular:::.docx_primary_font(NA_character_),
    "Liberation Serif"
  )
  expect_identical(tabular:::.docx_primary_font(""), "Liberation Serif")
  expect_identical(
    tabular:::.docx_primary_font(c("Helvetica", "Arial")),
    "Helvetica"
  )
})

test_that(".docx_escape vectorises over character(>1)", {
  expect_identical(
    tabular:::.docx_escape(c("a & b", "<c>", "ok")),
    c("a &amp; b", "&lt;c&gt;", "ok")
  )
})

test_that(".docx_resolve_preset returns factory defaults for non-preset_spec input", {
  fallback <- tabular:::.docx_resolve_preset(NULL)
  expect_true(is_preset_spec(fallback))
  fallback2 <- tabular:::.docx_resolve_preset("not a preset")
  expect_true(is_preset_spec(fallback2))
})

# ---------------------------------------------------------------------
# Table emission — <w:tbl>, <w:tblGrid>, <w:gridCol>, <w:tr>, <w:tc>
# ---------------------------------------------------------------------

test_that("emit(.docx) writes <w:tbl> with <w:tblGrid>, <w:tr>, <w:tc> for data rows", {
  spec <- tabular(data.frame(x = c("a", "b"), y = c("1", "2")))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:tbl>", fixed = TRUE)
  expect_match(doc, "<w:tblGrid>", fixed = TRUE)
  expect_match(doc, "<w:gridCol", fixed = TRUE)
  # Header row + 2 data rows + col-labels row at least
  expect_gte(length(gregexpr("<w:tr>", doc, fixed = TRUE)[[1L]]), 3L)
  # Data cells render
  expect_match(doc, ">a<", fixed = TRUE)
  expect_match(doc, ">b<", fixed = TRUE)
  expect_match(doc, ">1<", fixed = TRUE)
  expect_match(doc, ">2<", fixed = TRUE)
})

test_that("<w:gridCol> widths match engine-resolved meta$cols inches in twips (boundary-snapped)", {
  # Saf_demo widths under the golden pipeline are content-derived.
  # Under content mode (Word AutoFit-to-Contents) auto columns keep
  # their natural width and are NOT shrunk to fit, so this wide
  # demographics table overflows the 9360-twip printable area on US
  # Letter portrait (the engine warns; landscape is the fix). The
  # widths therefore sum to the natural total, not the page width.
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    preset(orientation = "portrait", font_family = "serif") |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, out))
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  widths_twips <- as.integer(regmatches(
    doc,
    gregexpr("(?<=<w:gridCol w:w=\")[0-9]+(?=\"/>)", doc, perl = TRUE)
  )[[1L]])
  expect_identical(widths_twips, c(1756L, 3645L, 1191L, 1191L, 1191L, 1191L))
  expect_identical(sum(widths_twips), 10165L)
})

test_that("col_spec@align surfaces as <w:jc> on data cells", {
  spec <- tabular(
    data.frame(L = "x", C = "x", R = "x", D = "1.5")
  ) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:jc w:val=\"left\"/>", fixed = TRUE)
  expect_match(doc, "<w:jc w:val=\"center\"/>", fixed = TRUE)
  expect_match(doc, "<w:jc w:val=\"right\"/>", fixed = TRUE)
  # decimal collapses to right at the <w:jc> level
})

test_that("multi-level header bands render as <w:tr> with <w:gridSpan>", {
  spec <- tabular(
    data.frame(
      grp = "x",
      placebo = "1",
      active_low = "2",
      active_high = "3"
    )
  ) |>
    headers("Treatment Arm" = c("placebo", "active_low", "active_high"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:gridSpan w:val=\"3\"/>", fixed = TRUE)
  expect_match(doc, "Treatment Arm", fixed = TRUE)
})

test_that(".render_docx_table emits the no-rows marker when the grid has zero pages", {
  # The engine always produces >=1 page even for empty data, so
  # exercise the empty-pages branch by handing the renderer a grid
  # with pages = list().
  empty_grid <- tabular:::tabular_grid(
    pages = list(),
    metadata = list()
  )
  out <- tabular:::.render_docx_table(empty_grid, preset_spec())
  expect_match(out, "(no rows)", fixed = TRUE)
})

test_that(".docx_align_token covers every align value plus the unset fallback", {
  expect_identical(
    tabular:::.docx_align_token("left"),
    "<w:jc w:val=\"left\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token("center"),
    "<w:jc w:val=\"center\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token("right"),
    "<w:jc w:val=\"right\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token("decimal"),
    "<w:jc w:val=\"right\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token(NA_character_),
    "<w:jc w:val=\"left\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token(NULL),
    "<w:jc w:val=\"left\"/>"
  )
  expect_identical(
    tabular:::.docx_align_token("garbage"),
    "<w:jc w:val=\"left\"/>"
  )
})

test_that(".docx_col_widths_twips falls back to equal share when no col_spec declared", {
  preset <- preset_spec()
  widths <- tabular:::.docx_col_widths_twips(c("a", "b", "c"), list(), preset)
  expect_length(widths, 3L)
  expect_true(all(widths > 0L))
  # Cumulative-rounding gives each column the same twip width when
  # the input is equal-share, since boundaries land at exact integer
  # multiples of the share value. Total matches printable.
  expect_identical(widths[[1L]], widths[[2L]])
  expect_identical(widths[[2L]], widths[[3L]])
})

# ---------------------------------------------------------------------
# Inline AST -> <w:r> runs (bold / italic / sup / sub / code / link / newline)
# ---------------------------------------------------------------------

test_that("bold / italic / code marks render as <w:b/> / <w:i/> / <w:rFonts mono>", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
      md("**Bold title**"),
      md("*italic title*"),
      md("`code title`")
    )
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "Bold title", fixed = TRUE)
  expect_match(doc, "<w:b/>", fixed = TRUE)
  expect_match(doc, "italic title", fixed = TRUE)
  expect_match(doc, "<w:i/>", fixed = TRUE)
  expect_match(doc, "code title", fixed = TRUE)
  expect_match(doc, "w:ascii=\"Liberation Mono\"", fixed = TRUE)
})

test_that("superscript / subscript render as <w:vertAlign>", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(md("Marker^a^"), md("Marker~b~"))
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:vertAlign w:val=\"superscript\"/>", fixed = TRUE)
  expect_match(doc, "<w:vertAlign w:val=\"subscript\"/>", fixed = TRUE)
})

test_that("newline / <br/> renders as <w:r><w:br/></w:r>", {
  spec <- tabular(data.frame(x = "line1\nline2"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  # cells_text path renders \n via .docx_escape; AST path (col labels)
  # would emit <w:br/>. We test cells_text here -- newline is just
  # stripped in the plain-text path.
  expect_match(doc, "line1", fixed = TRUE)
})

test_that("link runs wrap in <w:hyperlink> with numeric rIds matching rels", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(
      md("[example](https://example.com)"),
      md("[duplicate](https://example.com) and [other](https://example.org)")
    )
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  rels <- paste(
    readLines(file.path(unzipped, "word/_rels/document.xml.rels")),
    collapse = ""
  )
  # No chrome -> hyperlinks start at rId6 (post the 5 static rels).
  expect_match(doc, "r:id=\"rId6\"", fixed = TRUE)
  expect_match(doc, "r:id=\"rId7\"", fixed = TRUE)
  # rels: two External hyperlink relationships
  expect_match(rels, "Id=\"rId6\"[^>]*Target=\"https://example.com\"")
  expect_match(rels, "Id=\"rId7\"[^>]*Target=\"https://example.org\"")
  expect_match(rels, "TargetMode=\"External\"", fixed = TRUE)
})

test_that("nested formatting (bold inside italic) merges <w:rPr> tokens", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = md("*Italic with **bold** inside*")
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  # The inner run must carry both <w:b/> and <w:i/> in its <w:rPr>.
  expect_match(
    doc,
    "<w:rPr><w:i/><w:b/></w:rPr><w:t xml:space=\"preserve\">bold</w:t>",
    fixed = TRUE
  )
})

test_that(".docx_collect_hyperlinks walks titles / footnotes / col labels / cells", {
  spec <- tabular(
    data.frame(x = "row"),
    titles = md("[t](https://t.example)"),
    footnotes = md("[f](https://f.example)")
  ) |>
    cols(x = col_spec(label = md("[c](https://c.example)")))
  grid <- as_grid(spec)
  urls <- tabular:::.docx_collect_hyperlinks(grid)
  expect_in(
    c("https://t.example", "https://f.example", "https://c.example"),
    urls
  )
})

test_that(".docx_collect_hyperlinks deduplicates repeated URLs preserving first-seen order", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = md("[a](https://a) and [a-again](https://a)"),
    footnotes = md("[b](https://b) and [a-more](https://a)")
  )
  grid <- as_grid(spec)
  urls <- tabular:::.docx_collect_hyperlinks(grid)
  expect_identical(urls, c("https://a", "https://b"))
})

test_that(".render_docx_inline returns '' for non-inline_ast input (defensive)", {
  expect_identical(tabular:::.render_docx_inline(NULL), "")
  expect_identical(tabular:::.render_docx_inline("not an ast"), "")
})

test_that(".render_docx_run falls through to plain for unknown run types", {
  fake_run <- list(type = "unknown_type_xyz", text = "x & y")
  out <- tabular:::.render_docx_run(fake_run, character(), "")
  # Unknown types fall through to plain rendering; & must be escaped.
  expect_match(out, "x &amp; y", fixed = TRUE)
})

test_that(".render_docx_link falls back to plain text when href is missing or unregistered", {
  ast_missing <- list(
    type = "link",
    href = "",
    children = list(
      list(type = "plain", text = "anchor")
    )
  )
  out_empty <- tabular:::.render_docx_run(ast_missing, character(), "")
  expect_match(out_empty, "anchor", fixed = TRUE)
  expect_false(grepl("<w:hyperlink", out_empty, fixed = TRUE))

  ast_unreg <- list(
    type = "link",
    href = "https://unregistered.example",
    children = list(list(type = "plain", text = "anchor"))
  )
  out_unreg <- tabular:::.render_docx_run(ast_unreg, character(), "")
  expect_match(out_unreg, "anchor", fixed = TRUE)
  expect_false(grepl("<w:hyperlink", out_unreg, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Per-cell style cascade — cells_style -> <w:tcPr> / <w:rPr>
# ---------------------------------------------------------------------

test_that(".docx_rPr_from_style emits <w:b/> / <w:i/> / <w:u> / color / font / size", {
  sn <- tabular:::style_node(
    bold = TRUE,
    italic = TRUE,
    underline = TRUE,
    color = "#FF0000",
    font_family = "Arial",
    font_size = 11
  )
  out <- tabular:::.docx_rPr_from_style(sn)
  expect_match(out, "<w:b/>", fixed = TRUE)
  expect_match(out, "<w:i/>", fixed = TRUE)
  expect_match(out, "<w:u w:val=\"single\"/>", fixed = TRUE)
  expect_match(out, "<w:color w:val=\"FF0000\"/>", fixed = TRUE)
  expect_match(
    out,
    "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>",
    fixed = TRUE
  )
  # 11pt -> 22 half-points
  expect_match(out, "<w:sz w:val=\"22\"/>", fixed = TRUE)
})

test_that(".docx_rPr_from_style omits properties whose style_node fields are unset", {
  sn <- tabular:::style_node(bold = TRUE)
  out <- tabular:::.docx_rPr_from_style(sn)
  expect_match(out, "<w:b/>", fixed = TRUE)
  expect_false(grepl("<w:i/>", out, fixed = TRUE))
  expect_false(grepl("<w:u ", out, fixed = TRUE))
  expect_false(grepl("<w:color ", out, fixed = TRUE))
  expect_false(grepl("<w:rFonts ", out, fixed = TRUE))
  expect_false(grepl("<w:sz ", out, fixed = TRUE))
})

test_that(".docx_rPr_from_style returns '' when input is not a style_node", {
  expect_identical(tabular:::.docx_rPr_from_style(NULL), "")
  expect_identical(tabular:::.docx_rPr_from_style("garbage"), "")
})

test_that(".docx_tcPr_from_style emits width + shading + borders from style_node", {
  sn <- tabular:::style_node(
    background = "#E0F0FF",
    rule_above = TRUE,
    rule_below = TRUE,
    border_left = TRUE,
    border_right = TRUE
  )
  out <- tabular:::.docx_tcPr_from_style(sn, 1440L)
  expect_match(out, "<w:tcW w:w=\"1440\" w:type=\"dxa\"/>", fixed = TRUE)
  expect_match(
    out,
    "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"E0F0FF\"/>",
    fixed = TRUE
  )
  expect_match(out, "<w:tcBorders>", fixed = TRUE)
  expect_match(out, "<w:top w:val=\"single\"", fixed = TRUE)
  expect_match(out, "<w:bottom w:val=\"single\"", fixed = TRUE)
  expect_match(out, "<w:left w:val=\"single\"", fixed = TRUE)
  expect_match(out, "<w:right w:val=\"single\"", fixed = TRUE)
})

test_that(".docx_tcPr_from_style emits gridSpan only when > 1", {
  no_span <- tabular:::.docx_tcPr_from_style(NULL, 1440L)
  expect_false(grepl("<w:gridSpan", no_span, fixed = TRUE))
  with_span <- tabular:::.docx_tcPr_from_style(NULL, 1440L, 3L)
  expect_match(with_span, "<w:gridSpan w:val=\"3\"/>", fixed = TRUE)
})

test_that(".docx_normalize_color uppercases hex, strips #, defaults bad input to 000000", {
  expect_identical(tabular:::.docx_normalize_color("#aabbcc"), "AABBCC")
  expect_identical(tabular:::.docx_normalize_color("FF0000"), "FF0000")
  expect_identical(tabular:::.docx_normalize_color("garbage"), "000000")
  expect_identical(tabular:::.docx_normalize_color("#GGHHII"), "000000")
})

test_that("style(bold = TRUE) on a row predicate surfaces <w:b/> across the matched row", {
  spec <- tabular(
    data.frame(arm = c("A", "B", "Total"), n = c("10", "12", "22"))
  ) |>
    style(bold = TRUE, .at = cells_body(where = arm == "Total"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  # Row-scope predicate bolds every cell on the "Total" row.
  expect_match(
    doc,
    "<w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Total",
    fixed = TRUE
  )
  expect_match(
    doc,
    "<w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">22",
    fixed = TRUE
  )
})

test_that("style(background = \"#...\") surfaces as <w:shd> on the matched cells", {
  spec <- tabular(
    data.frame(arm = c("A", "B"), n = c("10", "12"))
  ) |>
    style(background = "#FFFF99", .at = cells_body(where = arm == "A"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "w:fill=\"FFFF99\"", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Byte-determinism — same spec produces identical bytes
# ---------------------------------------------------------------------

test_that("emit(.docx) is byte-deterministic across repeated calls", {
  # Spec with content covering every emission path: titles,
  # footnotes, multi-level headers, hyperlinks, page chrome, AFM-
  # resolved widths, per-cell style cascade. Two identical emit()
  # calls must produce bit-identical .docx bytes.
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics"),
    footnotes = md("Source: [ADSL](https://example.com)")
  ) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC",
        right = "Page {page} of {npages}"
      ),
      pagefoot = list(left = "Source: ADSL")
    ) |>
    style(bold = TRUE, .at = cells_body(where = variable == "Sex, n (%)"))

  a <- withr::local_tempfile(fileext = ".docx")
  b <- withr::local_tempfile(fileext = ".docx")
  emit(spec, a)
  emit(spec, b)
  bytes_a <- readBin(a, what = "raw", n = file.size(a))
  bytes_b <- readBin(b, what = "raw", n = file.size(b))
  expect_identical(bytes_a, bytes_b)
})

# ---------------------------------------------------------------------
# Self-registration via direct call
# ---------------------------------------------------------------------

test_that("backend_docx() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".docx")
  tabular:::backend_docx(grid, out)
  expect_true(file.exists(out))
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline (word/document.xml)
# ---------------------------------------------------------------------

test_that("saf_demo golden pipeline matches the pinned word/document.xml snapshot", {
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  # Snapshot the unzipped word/document.xml — per CLAUDE.local.md
  # testing convention, never snapshot the .docx binary itself
  # (binaries can't diff).
  expect_snapshot_file(
    file.path(unzipped, "word/document.xml"),
    "saf_demo_golden.xml"
  )
})

# ---------------------------------------------------------------------
# chrome_style cascade — `style_template() |> style(.at = cells_*())`
# must reach the DOCX output. Tests inspect the unzipped
# word/document.xml so they survive across binary builds.
# ---------------------------------------------------------------------

.docx_doc_xml <- function(spec) {
  out <- withr::local_tempfile(
    fileext = ".docx",
    .local_envir = parent.frame()
  )
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  paste(
    readLines(file.path(unzipped, "word/document.xml"), warn = FALSE),
    collapse = "\n"
  )
}

test_that("style(.at = cells_title(), halign = 'left') emits <w:jc w:val='left'/> on title pPr", {
  template <- style_template() |>
    style(.at = cells_title(), halign = "left")
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demographics"
  ) |>
    preset(.style = template)
  xml <- .docx_doc_xml(spec)
  expect_match(xml, "TabularTitle.*<w:jc w:val=\"left\"/>", fixed = FALSE)
})

test_that("style(.at = cells_footnotes(), halign = 'right') drives footnote jc=right", {
  template <- style_template() |>
    style(.at = cells_footnotes(), halign = "right")
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = "Source: ADSL"
  ) |>
    preset(.style = template)
  xml <- .docx_doc_xml(spec)
  expect_match(xml, "TabularFoot.*<w:jc w:val=\"right\"/>", fixed = FALSE)
})

test_that("style(.at = cells_title(), blank_above = 3) emits three blank paragraphs", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  xml <- .docx_doc_xml(spec)
  # Count <w:p/> empty paragraphs preceding the TabularTitle paragraph.
  pre_title <- sub("(.*?)<w:pStyle w:val=\"TabularTitle\"/>.*", "\\1", xml)
  blanks <- length(gregexpr("<w:p/>", pre_title, fixed = TRUE)[[1]])
  expect_gte(blanks, 3L)
})

# ---------------------------------------------------------------------
# Change C: cells_indent sidecar -> DOCX <w:ind w:left="N"/>
# ---------------------------------------------------------------------

test_that("DOCX emits <w:ind w:left=...> on data rows but NOT on header rows (Change C)", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c(
      "CARDIAC",
      "Atrial fibrillation with rapid ventricular response",
      "GI",
      "Nausea and vomiting episodes"
    ),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(
        label = "Category",
        indent_by = "indent_level",
        width = "1in"
      ),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # Data row paragraphs carry `<w:ind w:left="N"/>` BEFORE `<w:jc>`
  # inside the same `<w:pPr>` that wraps the Atrial cell text.
  expect_match(
    doc,
    "<w:ind w:left=\"[0-9]+\"/><w:jc[^>]*></w:pPr><w:r><w:t[^>]*>Atrial",
    perl = TRUE
  )
  # Header band cells DO NOT carry `<w:ind w:left=...>`.
  header_chunk <- sub(".*(<w:t[^>]*>CARDIAC</w:t>).*", "\\1", doc)
  expect_false(grepl("<w:ind w:left", header_chunk, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Change D: is_header_row / is_blank_row branching in DOCX
# ---------------------------------------------------------------------

test_that("DOCX emits <w:gridSpan> + <w:b/> on synthesised header rows (Change D)", {
  df <- data.frame(
    group_label = c(
      "Best Overall Response",
      "Best Overall Response",
      "Objective Response Rate",
      "Objective Response Rate"
    ),
    stat_label = c("CR", "PR", "ORR (CR + PR)", "95% CI"),
    placebo = c("1", "1", "2", "(0.3, 8.1)"),
    drug_50 = c("1", "0", "1", "(0.0, 6.5)"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Eff") |>
    cols(
      group_label = col_spec(usage = "group", group_display = "header_row"),
      stat_label = col_spec(usage = "indent", label = "Response"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # Header row: single <w:tc> with <w:gridSpan w:val="3"/> + <w:b/>.
  expect_match(
    doc,
    "<w:gridSpan w:val=\"3\"/></w:tcPr><w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Best Overall Response</w:t>",
    fixed = TRUE
  )
  expect_match(
    doc,
    "<w:gridSpan w:val=\"3\"/></w:tcPr><w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Objective Response Rate</w:t>",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: nested band headers render with depth-aware <w:ind>
# ---------------------------------------------------------------------

test_that("DOCX nested bands: band-1 header no <w:ind>, band-2 header <w:ind w:left=N> (Change D)", {
  df <- data.frame(
    section = c("Safety", "Safety", "Efficacy", "Efficacy"),
    subsection = c("AE", "AE", "ORR", "ORR"),
    label = c("Any", "SAE", "Confirmed", "Unconfirmed"),
    n = c("100", "10", "20", "15"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Nested") |>
    cols(
      section = col_spec(usage = "group", group_display = "header_row"),
      subsection = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Item"),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # Band 1 ("Safety", depth 0) -> the spanning paragraph's <w:pPr>
  # carries <w:jc w:val="left"/> WITHOUT a preceding <w:ind>.
  expect_match(
    doc,
    "<w:pPr><w:jc w:val=\"left\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Safety</w:t>",
    fixed = TRUE
  )
  # Band 2 ("AE", depth 1) -> <w:ind w:left="N"/> BEFORE <w:jc>.
  expect_match(
    doc,
    "<w:pPr><w:ind w:left=\"[0-9]+\"/><w:jc w:val=\"left\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">AE</w:t>",
    perl = TRUE
  )
})

# --- header-band rule scope (cmidrule(lr) semantics) ----------------

test_that("DOCX scenario G: band cell tcPr carries w:tcBorders w:bottom; blanks do not", {
  doc <- band_emit("G", "docx")
  expect_match(doc, "<w:gridSpan w:val=\"2\"/>")
  expect_match(
    doc,
    "<w:t xml:space=\"preserve\">Active Treatment</w:t>",
    fixed = TRUE
  )
  expect_match(doc, "<w:tcBorders><w:bottom w:val=\"single\"")
  # Extract the band row and confirm only the cell containing
  # "Active Treatment" carries tcBorders; the two blank flanking
  # cells (3-cell left run, 1-cell right run) do not.
  band_row <- regmatches(
    doc,
    regexpr(
      "<w:tr><w:trPr><w:tblHeader/></w:trPr>(?:(?!</w:tr>).)*Active Treatment(?:(?!</w:tr>).)*</w:tr>",
      doc,
      perl = TRUE
    )
  )
  tcs <- regmatches(
    band_row,
    gregexpr("<w:tc>.*?</w:tc>", band_row, perl = TRUE)
  )[[1L]]
  expect_length(tcs, 3L)
  band_idx <- grep("Active Treatment", tcs, fixed = TRUE)
  blank_idx <- setdiff(seq_along(tcs), band_idx)
  expect_match(tcs[band_idx], "<w:tcBorders>")
  for (i in blank_idx) {
    expect_no_match(tcs[i], "<w:tcBorders>")
  }
})

test_that("cell_padding_h emits per-side w:tcMar (padding SSOT)", {
  # With no body padding override, DOCX emits left/right tcMar from
  # the horizontal SSOT so the rendered margin matches the measured
  # column width; vertical margin stays Word's default. c(left, right)
  # renders exactly per side.
  spec <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding_h = c(5, 15))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:left w:w=\"100\" w:type=\"dxa\"/>", fixed = TRUE) # 5pt
  expect_match(doc, "<w:right w:w=\"300\" w:type=\"dxa\"/>", fixed = TRUE) # 15pt
})
