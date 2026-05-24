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

test_that(".docx_doc_rels emits header / footer entries only when chrome populated", {
  none <- tabular:::.docx_doc_rels(FALSE, FALSE)
  expect_match(none, "Target=\"styles.xml\"", fixed = TRUE)
  expect_match(none, "Target=\"settings.xml\"", fixed = TRUE)
  expect_false(grepl("header1.xml", none, fixed = TRUE))
  expect_false(grepl("footer1.xml", none, fixed = TRUE))

  both <- tabular:::.docx_doc_rels(TRUE, TRUE)
  expect_match(both, "Target=\"header1.xml\"", fixed = TRUE)
  expect_match(both, "Target=\"footer1.xml\"", fixed = TRUE)
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
# Self-registration via direct call
# ---------------------------------------------------------------------

test_that("backend_docx() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".docx")
  tabular:::backend_docx(grid, out)
  expect_true(file.exists(out))
})
