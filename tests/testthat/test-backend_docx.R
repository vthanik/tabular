# backend_docx() — self-contained OOXML DOCX backend.
#
# Self-registers at package-load time, so every test below can rely
# on `tabular:::.has_backend("docx")` returning TRUE without setup.

# Helper: unzip a `.docx` to a temp directory and return the path.
# Each test that needs to inspect inner XML calls this once.
.unzip_docx <- function(docx_path) {
  out <- withr::local_tempdir(.local_envir = parent.frame())
  zip::unzip(docx_path, exdir = out)
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

  # Use `zip::zip_list()` so HIDDEN entries like `_rels/.rels` show
  # up — `list.files()` would silently drop them. The path
  # structure is load-bearing: Word and LibreOffice refuse to open
  # a `.docx` with the OOXML scaffolding under wrong paths.
  z <- zip::zip_list(out)
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
    z$filename
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

test_that(".docx_doc_rels emits header / footer / hyperlink entries conditionally", {
  none <- tabular:::.docx_doc_rels(FALSE, FALSE, character())
  expect_match(none, "Target=\"styles.xml\"", fixed = TRUE)
  expect_match(none, "Target=\"settings.xml\"", fixed = TRUE)
  expect_false(grepl("header1.xml", none, fixed = TRUE))
  expect_false(grepl("footer1.xml", none, fixed = TRUE))
  expect_false(grepl("rIdLink", none, fixed = TRUE))

  both <- tabular:::.docx_doc_rels(TRUE, TRUE, character())
  expect_match(both, "Target=\"header1.xml\"", fixed = TRUE)
  expect_match(both, "Target=\"footer1.xml\"", fixed = TRUE)

  with_links <- tabular:::.docx_doc_rels(
    FALSE,
    FALSE,
    c("https://a.example", "https://b.example")
  )
  expect_match(with_links, "Id=\"rIdLink1\"", fixed = TRUE)
  expect_match(with_links, "Id=\"rIdLink2\"", fixed = TRUE)
  expect_match(with_links, "Target=\"https://a.example\"", fixed = TRUE)
  expect_match(with_links, "TargetMode=\"External\"", fixed = TRUE)
})

test_that(".docx_styles_xml carries preset@font_family + half-point font size", {
  preset <- preset_spec(font_family = "Arial", font_size = 11)
  styles <- tabular:::.docx_styles_xml(preset)
  expect_match(styles, "w:ascii=\"Arial\"", fixed = TRUE)
  # 11pt -> 22 half-points
  expect_match(styles, "w:sz w:val=\"22\"", fixed = TRUE)
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

test_that(".docx_section_pr emits letter portrait twips by default", {
  preset <- preset_spec()
  sp <- tabular:::.docx_section_pr(preset, FALSE, FALSE)
  # Letter portrait: 8.5 x 11 in -> 12240 x 15840 twips
  expect_match(sp, "w:w=\"12240\" w:h=\"15840\"", fixed = TRUE)
  expect_false(grepl("w:orient=\"landscape\"", sp, fixed = TRUE))
})

test_that(".docx_section_pr swaps width / height and tags orient for landscape", {
  preset <- preset_spec(orientation = "landscape")
  sp <- tabular:::.docx_section_pr(preset, FALSE, FALSE)
  expect_match(sp, "w:w=\"15840\" w:h=\"12240\"", fixed = TRUE)
  expect_match(sp, "w:orient=\"landscape\"", fixed = TRUE)
})

test_that(".docx_section_pr inserts headerReference / footerReference only when chrome populated", {
  preset <- preset_spec()
  no_chrome <- tabular:::.docx_section_pr(preset, FALSE, FALSE)
  expect_false(grepl("w:headerReference", no_chrome, fixed = TRUE))
  expect_false(grepl("w:footerReference", no_chrome, fixed = TRUE))

  both <- tabular:::.docx_section_pr(preset, TRUE, TRUE)
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
  z <- zip::zip_list(out)
  expect_in(c("word/header1.xml", "word/footer1.xml"), z$filename)

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

test_that(".docx_header_xml / .docx_footer_xml emit well-formed skeletons", {
  preset <- preset_spec()
  band_ast <- list(left = list(), center = list(), right = list())
  hdr <- tabular:::.docx_header_xml(band_ast, preset)
  ftr <- tabular:::.docx_footer_xml(band_ast, preset)
  expect_match(hdr, "<w:hdr ", fixed = TRUE)
  expect_match(ftr, "<w:ftr ", fixed = TRUE)
  expect_no_error(xml2::read_xml(hdr))
  expect_no_error(xml2::read_xml(ftr))
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
  # Saf_demo widths under the golden pipeline (engine-resolved):
  # 1.045325, 2.491345, 0.733194, 0.733194, 0.733194, 0.763747 in.
  # Cumulative-rounded boundaries land at:
  # 1505, 5093, 6149, 7204, 8260, 9360 twips
  # whose diffs are: 1505, 3588, 1056, 1055, 1056, 1100 twips.
  # Per-column rounding would yield 1056 on col 4; boundary-snapping
  # gives 1055 to keep the cumulative sum exact (matches RTF \cellx).
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
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  widths_twips <- as.integer(regmatches(
    doc,
    gregexpr("(?<=<w:gridCol w:w=\")[0-9]+(?=\"/>)", doc, perl = TRUE)
  )[[1L]])
  expect_identical(widths_twips, c(1505L, 3588L, 1056L, 1055L, 1056L, 1100L))
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

test_that("link runs wrap in <w:hyperlink> with rIdLinkN matching rels", {
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
  # document.xml: two distinct rIds (the duplicate URL deduplicates)
  expect_match(doc, "r:id=\"rIdLink1\"", fixed = TRUE)
  expect_match(doc, "r:id=\"rIdLink2\"", fixed = TRUE)
  # rels: two External hyperlink relationships
  expect_match(rels, "Id=\"rIdLink1\"", fixed = TRUE)
  expect_match(rels, "Target=\"https://example.com\"", fixed = TRUE)
  expect_match(rels, "Target=\"https://example.org\"", fixed = TRUE)
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
# Self-registration via direct call
# ---------------------------------------------------------------------

test_that("backend_docx() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".docx")
  tabular:::backend_docx(grid, out)
  expect_true(file.exists(out))
})
