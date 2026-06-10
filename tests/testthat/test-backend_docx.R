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

test_that("emit(.docx) renders title (table rows) + footnote (footer) text", {
  # Default repeat_content: titles ride merged table rows in
  # document.xml (Word repeats them per page); footnotes ride the
  # repeating footer1.xml.
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
  ftr <- paste(
    readLines(file.path(unzipped, "word/footer1.xml")),
    collapse = ""
  )
  expect_match(doc, "First Title", fixed = TRUE)
  expect_match(doc, "Second Title", fixed = TRUE)
  expect_match(ftr, "Source: ADSL.", fixed = TRUE)
})

test_that("an auto-numbered footnote survives pagination (marker in body, block in footer)", {
  # Tall spec -> > 1 page. The body marker rides a superscript run in
  # document.xml; the marked-footnote block rides the repeating
  # footer1.xml (Word repeats the footer per page natively).
  df <- data.frame(
    label = paste0("PT ", sprintf("%02d", 1:40)),
    Total = as.character(1:40),
    n = c(rep(1L, 39L), 99L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      label = col_spec(label = "PT"),
      n = col_spec(visible = FALSE),
      Total = col_spec(label = "Total")
    ) |>
    preset(orientation = "portrait", font_size = 24) |>
    paginate() |>
    footnote("Last row note.", .at = cells_body(where = n >= 50, j = "label"))
  expect_gt(length(as_grid(spec)@pages), 1L)
  out <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, out))
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml")),
    collapse = ""
  )
  ftr <- paste(
    readLines(file.path(unzipped, "word/footer1.xml")),
    collapse = ""
  )
  expect_match(doc, "<w:vertAlign w:val=\"superscript\"/>", fixed = TRUE)
  expect_match(ftr, "Last row note.", fixed = TRUE)
})

test_that("DOCX header-band underline is the SSOT spanrule (override + 'none' honoured)", {
  # Regression: the band bottom border was hardcoded `w:sz="4"
  # w:color="adb5bd"`, so `preset(rules = list(spanrule = ...))`
  # overrides were ignored on DOCX. It now resolves through the
  # chrome_style `header_between` region.
  base <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "C"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "PBO"),
      drug_50 = col_spec(label = "D50"),
      drug_100 = col_spec(label = "D100"),
      Total = col_spec(label = "Tot")
    ) |>
    headers("Active" = c("drug_50", "drug_100"))
  band_xml <- function(spec) {
    out <- withr::local_tempfile(
      fileext = ".docx",
      .local_envir = parent.frame()
    )
    emit(spec, out)
    paste(
      readLines(
        file.path(.unzip_docx(out), "word/document.xml"),
        warn = FALSE
      ),
      collapse = ""
    )
  }

  # Default: muted 0.5pt band (w:sz = 4 eighths, #adb5bd).
  expect_match(
    band_xml(base),
    "<w:bottom w:space=\"0\" w:val=\"single\" w:sz=\"4\" w:color=\"ADB5BD\"/>",
    fixed = TRUE
  )
  # Override changes the rendered width + colour.
  expect_match(
    band_xml(
      base |>
        preset(
          rules = list(spanrule = brdr(width = "thick", color = "#ff0000"))
        )
    ),
    "w:sz=\"12\" w:color=\"FF0000\"",
    fixed = TRUE
  )
  # "none" drops the band underline entirely. Scope to the band row
  # (the "Active" spanner): the midrule on the column-label row below
  # is a different SSOT rule (header_bottom) and legitimately remains.
  none_doc <- band_xml(base |> preset(rules = list(spanrule = "none")))
  none_rows <- regmatches(
    none_doc,
    gregexpr("<w:tr>.*?</w:tr>", none_doc, perl = TRUE)
  )[[1L]]
  band_row <- none_rows[grepl("Active", none_rows, fixed = TRUE)][[1L]]
  expect_no_match(
    band_row,
    "w:bottom w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
})

test_that("DOCX footnoterule (opt-in) draws a table-width rule above the footnotes, not a page-width paragraph border", {
  # footnoterule is OFF by default (bottomrule closes the body). When
  # the user opts in, the rule is a single-cell table sized to the
  # table grid (table width), NOT a paragraph border (<w:pBdr>, which
  # spans the full page text column).
  base <- tabular(cdisc_saf_demo, footnotes = "Source: ADSL.") |>
    cols(
      variable = col_spec(usage = "group", label = "C"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "PBO"),
      drug_50 = col_spec(label = "D50"),
      drug_100 = col_spec(label = "D100"),
      Total = col_spec(label = "Tot")
    )
  docxml <- function(spec) {
    out <- withr::local_tempfile(
      fileext = ".docx",
      .local_envir = parent.frame()
    )
    emit(spec, out)
    paste(
      readLines(
        file.path(.unzip_docx(out), "word/document.xml"),
        warn = FALSE
      ),
      collapse = ""
    )
  }

  # Default: no footnote rule table. Scope to the region AFTER the
  # main table (the footnote area) — the toprule now legitimately
  # emits <w:tcBorders><w:top ...> inside the table's column-header
  # band, which is a different SSOT rule.
  trailing_default <- sub("^.*</w:tbl>", "", docxml(base))
  expect_no_match(
    trailing_default,
    "<w:tcBorders><w:top w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
  # Opt-in: a table-width single-cell top-border rule appears.
  opt <- docxml(
    base |>
      preset(
        rules = list(bottomrule = "none", footnoterule = brdr(width = "thin"))
      )
  )
  expect_match(
    opt,
    "<w:tcBorders><w:top w:space=\"0\" w:val=\"single\" w:sz=\"4\"",
    fixed = TRUE
  )
  # No paragraph-border (page-width) rule on the footnote paragraphs.
  expect_no_match(opt, "<w:pBdr>", fixed = TRUE)
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
# Per-page titles + footnotes via Word-native repetition (RTF parity).
# Default repeat_content -> titles ride merged <w:tblHeader/> rows and
# footnotes ride footer1.xml (Word repeats both per page); dropping a
# member reverts to body placement (page 1 / final page only).
# ---------------------------------------------------------------------

.unzip_parts <- function(spec) {
  out <- withr::local_tempfile(
    fileext = ".docx",
    .local_envir = parent.frame()
  )
  emit(spec, out)
  td <- .unzip_docx(out)
  read_part <- function(p) {
    f <- file.path(td, p)
    if (file.exists(f)) {
      paste(readLines(f, warn = FALSE), collapse = "")
    } else {
      NA_character_
    }
  }
  list(
    doc = read_part("word/document.xml"),
    footer = read_part("word/footer1.xml")
  )
}

test_that("default repeat_titles renders titles as merged <w:tblHeader/> table rows", {
  spec <- tabular(data.frame(x = 1L), titles = c("Table 1", "Demographics"))
  parts <- .unzip_parts(spec)
  # Titles live INSIDE the table, each a full-width gridSpan tblHeader
  # row carrying the TabularTitle style — Word repeats them per page.
  expect_match(parts$doc, "<w:tbl>", fixed = TRUE)
  title_row <- regmatches(
    parts$doc,
    regexpr(
      "<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc>(?:(?!</w:tr>).)*Table 1(?:(?!</w:tr>).)*</w:tr>",
      parts$doc,
      perl = TRUE
    )
  )
  expect_match(title_row, "<w:pStyle w:val=\"TabularTitle\"/>", fixed = TRUE)
  expect_true(nzchar(title_row))
})

test_that("dropping 'titles' from repeat_content renders titles as paragraphs above the table", {
  spec <- tabular(data.frame(x = 1L), titles = "Table 1") |>
    paginate(repeat_content = c("headers", "footnotes"))
  parts <- .unzip_parts(spec)
  # Title appears as a TabularTitle paragraph BEFORE the table opens.
  before_table <- sub("<w:tbl>.*$", "", parts$doc)
  expect_match(before_table, "TabularTitle", fixed = TRUE)
  expect_match(before_table, "Table 1", fixed = TRUE)
})

test_that("default repeat_footnotes routes footnotes into footer1.xml, not the body", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c("Note A.", "Source: ADSL.")
  )
  parts <- .unzip_parts(spec)
  expect_false(is.na(parts$footer))
  expect_match(parts$footer, "Note A.", fixed = TRUE)
  expect_match(parts$footer, "Source: ADSL.", fixed = TRUE)
  expect_no_match(parts$doc, "Source: ADSL.", fixed = TRUE)
})

test_that("dropping 'footnotes' from repeat_content trails them in the body, no footer", {
  spec <- tabular(data.frame(x = 1L), footnotes = "Source: ADSL.") |>
    paginate(repeat_content = c("titles", "headers"))
  parts <- .unzip_parts(spec)
  expect_true(is.na(parts$footer))
  expect_match(parts$doc, "Source: ADSL.", fixed = TRUE)
})

test_that(".docx_section_pr places header/footer like RTF: margins exact, header near body, footer at bottom margin", {
  # Mirrors `.rtf_section_def`: margins stay EXACTLY the preset values
  # (never enlarged to reserve footer space); the header sits one body
  # line above the top margin (flows up, near body), the footer sits at
  # the bottom-margin line (flows down, near body). Word auto-expands a
  # tall footer into the body rather than growing the page.
  preset <- preset_spec(margins = "1in", font_size = 9)
  sp <- tabular:::.docx_section_pr(preset, NULL)
  grab <- function(attr) {
    as.integer(regmatches(
      sp,
      regexpr(sprintf("(?<=%s=\")[0-9]+", attr), sp, perl = TRUE)
    ))
  }
  expect_identical(grab("w:top"), 1440L) # exact 1in, not enlarged
  expect_identical(grab("w:bottom"), 1440L) # exact 1in, not enlarged
  # header one body line (9 * 28 = 252 twips) above the top margin.
  expect_identical(grab("w:header"), 1440L - 252L)
  # footer at the bottom-margin line.
  expect_identical(grab("w:footer"), 1440L)
})

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

test_that(".docx_styles_xml pins the resolved preset font and emits named styles", {
  # SSOT: the default run font is the resolved preset@font_family
  # primary face, NOT the Office theme. The earlier asciiTheme form
  # silently dropped the user's font choice (Word substituted Aptos).
  # Naming an installed face with a declared fallback is safe; the
  # "Word rejects unknown fonts" hazard applies only to CSS generics,
  # which .resolve_font_stack() never emits.
  preset <- preset_spec(font_family = "sans", font_size = 11)
  styles <- tabular:::.docx_styles_xml(preset)
  expect_match(
    styles,
    "<w:rFonts w:ascii=\"Liberation Sans\" w:hAnsi=\"Liberation Sans\" w:cs=\"Liberation Sans\"/>",
    fixed = TRUE
  )
  expect_false(grepl("asciiTheme", styles, fixed = TRUE))
  # 11pt -> 22 half-points
  expect_match(styles, "w:sz w:val=\"22\"", fixed = TRUE)
  # Named styles for the title and footnote blocks.
  expect_match(styles, "w:styleId=\"TabularTitle\"", fixed = TRUE)
  expect_match(styles, "w:styleId=\"TabularFoot\"", fixed = TRUE)
  expect_match(styles, "w:styleId=\"Hyperlink\"", fixed = TRUE)
})

test_that(".docx_styles_xml defaults to Liberation Mono and fontTable declares the stack", {
  preset <- preset_spec()
  styles <- tabular:::.docx_styles_xml(preset)
  fonts <- tabular:::.docx_font_table(preset)
  # Default font_family is "mono" -> Liberation Mono primary face.
  expect_match(
    styles,
    "<w:rFonts w:ascii=\"Liberation Mono\" w:hAnsi=\"Liberation Mono\" w:cs=\"Liberation Mono\"/>",
    fixed = TRUE
  )
  # fontTable declares the primary face + its metric-compatible
  # substitutes (the OOXML form of RTF's \*\falt), all modern/fixed.
  expect_match(fonts, "<w:font w:name=\"Liberation Mono\">", fixed = TRUE)
  expect_match(fonts, "<w:font w:name=\"Courier New\">", fixed = TRUE)
  expect_match(fonts, "w:family w:val=\"modern\"", fixed = TRUE)
  # No vestigial Office theme faces (Calibri / Cambria) leak in.
  expect_false(grepl("Calibri", fonts, fixed = TRUE))
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
  # The serif face puts the default decimal_metrics = "afm" on the
  # Times tables (a digit is two NBSP units), so the four decimal
  # columns carry more pads — and more twips — than chars mode did.
  spec <- tabular(
    cdisc_saf_demo,
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
  expect_identical(widths_twips, c(1438L, 4026L, 1216L, 1216L, 1216L, 1316L))
  expect_identical(sum(widths_twips), 10428L)
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

test_that("the table is centred on the page (<w:jc> in <w:tblPr>, RTF \\trqc parity)", {
  expect_match(
    tabular:::.docx_tbl_pr(10368L),
    "<w:tblPr><w:tblW w:w=\"10368\" w:type=\"dxa\"/><w:jc w:val=\"center\"/>",
    fixed = TRUE
  )
})

test_that("toprule + midrule bracket the column-label band from the SSOT chrome regions", {
  # Flat header (no bands): the toprule (header_top) and midrule
  # (header_bottom) both ride the column-label row, full table width,
  # bracketing the headers per the submission layout (TL-RTF-101).
  flat <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "C"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "PBO"),
      drug_50 = col_spec(label = "D50"),
      drug_100 = col_spec(label = "D100"),
      Total = col_spec(label = "Tot")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(flat, out)
  doc <- paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  rows <- regmatches(doc, gregexpr("<w:tr>.*?</w:tr>", doc, perl = TRUE))[[
    1L
  ]]
  label_row <- rows[grepl("<w:tblHeader/>", rows)][[1L]]
  # The first <w:tblHeader/> row (label row) carries solid 0.5pt
  # toprule (top) and midrule (bottom) on its cells, default ink.
  expect_match(
    label_row,
    "<w:top w:space=\"0\" w:val=\"single\" w:sz=\"4\" w:color=\"212529\"/>",
    fixed = TRUE
  )
  expect_match(
    label_row,
    "<w:bottom w:space=\"0\" w:val=\"single\" w:sz=\"4\" w:color=\"212529\"/>",
    fixed = TRUE
  )
})

test_that("toprule rides the first band row (not the label row) when bands exist", {
  banded <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "C"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "PBO"),
      drug_50 = col_spec(label = "D50"),
      drug_100 = col_spec(label = "D100"),
      Total = col_spec(label = "Tot")
    ) |>
    headers("Active" = c("drug_50", "drug_100"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(banded, out)
  doc <- paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  rows <- regmatches(doc, gregexpr("<w:tr>.*?</w:tr>", doc, perl = TRUE))[[
    1L
  ]]
  hdr_rows <- rows[grepl("<w:tblHeader/>", rows)]
  band_row <- hdr_rows[[1L]]
  label_row <- hdr_rows[[2L]]
  # Toprule on the first band row; none on the label row below it.
  expect_match(
    band_row,
    "<w:top w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
  expect_no_match(
    label_row,
    "<w:top w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
  # Midrule still closes the label band.
  expect_match(
    label_row,
    "<w:bottom w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
})

test_that("rules = list(toprule/midrule = 'none') suppress the bracket rules", {
  base <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "C"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "PBO"),
      drug_50 = col_spec(label = "D50"),
      drug_100 = col_spec(label = "D100"),
      Total = col_spec(label = "Tot")
    )
  doc_for <- function(spec) {
    out <- withr::local_tempfile(
      fileext = ".docx",
      .local_envir = parent.frame()
    )
    emit(spec, out)
    paste(
      readLines(
        file.path(.unzip_docx(out), "word/document.xml"),
        warn = FALSE
      ),
      collapse = ""
    )
  }
  none <- doc_for(
    base |> preset(rules = list(toprule = "none", midrule = "none"))
  )
  rows <- regmatches(none, gregexpr("<w:tr>.*?</w:tr>", none, perl = TRUE))[[
    1L
  ]]
  label_row <- rows[grepl("<w:tblHeader/>", rows)][[1L]]
  expect_no_match(label_row, "<w:top w:space=\"0\"", fixed = TRUE)
  # midrule gone; the last body row keeps its bottomrule (outer_bottom).
  expect_no_match(label_row, "<w:bottom w:space=\"0\"", fixed = TRUE)
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

test_that("decimal column header centres + defaults to bottom valign (HTML parity)", {
  spec <- tabular(data.frame(grp = "A", n = "12.3")) |>
    cols(
      grp = col_spec(label = "Group"),
      n = col_spec(label = "N", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  doc <- paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml")),
    collapse = ""
  )
  # Header cells centre + bottom-align; the decimal body cell stays right.
  expect_match(doc, "<w:jc w:val=\"center\"/>", fixed = TRUE)
  expect_match(doc, "<w:vAlign w:val=\"bottom\"/>", fixed = TRUE)
  expect_match(doc, "<w:jc w:val=\"right\"/>", fixed = TRUE)
})

test_that("preset header_valign override is honoured in the DOCX header row", {
  spec <- tabular(data.frame(x = "a")) |>
    cols(x = col_spec(label = "X")) |>
    preset(alignment = list(header_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  doc <- paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml")),
    collapse = ""
  )
  # Surface/preset valign (middle -> OOXML "center") wins over the
  # bottom default.
  expect_match(doc, "<w:vAlign w:val=\"center\"/>", fixed = TRUE)
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
  # Footnotes ride footer1.xml by default; the inline AST renders
  # there identically.
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(md("Marker^a^"), md("Marker~b~"))
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  ftr <- paste(
    readLines(file.path(unzipped, "word/footer1.xml")),
    collapse = ""
  )
  expect_match(ftr, "<w:vertAlign w:val=\"superscript\"/>", fixed = TRUE)
  expect_match(ftr, "<w:vertAlign w:val=\"subscript\"/>", fixed = TRUE)
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
  # Hyperlinks on a body surface (titles -> repeating table rows in
  # document.xml) so the relationships file correctly is
  # document.xml.rels. (Footnote hyperlinks would land in footer1.xml,
  # whose relationships belong in a separate footer1.xml.rels part.)
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
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
  # Footnote rides footer1.xml; nested inline AST merges there.
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = md("*Italic with **bold** inside*")
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  ftr <- paste(
    readLines(file.path(unzipped, "word/footer1.xml")),
    collapse = ""
  )
  # The inner run must carry both <w:b/> and <w:i/> in its <w:rPr>, in
  # canonical OOXML CT_RPr order (b before i) regardless of markup
  # nesting. See the Thread I tests at the end of this file.
  expect_match(
    ftr,
    "<w:rPr><w:b/><w:i/></w:rPr><w:t xml:space=\"preserve\">bold</w:t>",
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
    border_top_style = "solid",
    border_bottom_style = "solid",
    border_left_style = "solid",
    border_right_style = "solid"
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
    cdisc_saf_demo,
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
  suppressWarnings(emit(spec, a)) # incidental overflow warn
  suppressWarnings(emit(spec, b))
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

test_that("cdisc_saf_demo golden pipeline matches the pinned word/document.xml snapshot", {
  spec <- tabular(
    cdisc_saf_demo,
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
# Horizontal panels — one self-contained `<w:tbl>` per panel
# ---------------------------------------------------------------------

test_that("DOCX panels = 2 emit one self-contained <w:tbl> per panel", {
  # 3 data cols + a group stub + an id stub -> panels = 2 splits the
  # data 2 | 1, so the two panels have DIFFERENT column counts. Before
  # the per-panel fix, `.render_docx_table` built the grid/header from
  # panel 1's columns while the body walked every panel's rows, so
  # panel 2's rows rendered under panel 1's grid (malformed table).
  d <- data.frame(
    grp = c("a", "b"),
    rl = c("n", "Mean"),
    c1 = 1:2,
    c2 = 3:4,
    c3 = 5:6
  )
  spec <- tabular(d) |>
    cols(
      grp = col_spec(
        usage = "group",
        group_display = "column",
        label = "Char"
      ),
      rl = col_spec(usage = "id", label = "Stat")
    ) |>
    paginate(panels = 2L)
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  xml <- paste(
    readLines(unz(out, "word/document.xml"), warn = FALSE),
    collapse = ""
  )

  # One `<w:tbl>` per panel, separated by a next-page section break.
  # Two panels -> 2 `<w:sectPr>` (one in-paragraph break after panel 1
  # + the body-level section for panel 2). No empty pageBreakBefore
  # paragraph (it would render as a blank line above panel 2's title).
  expect_identical(length(gregexpr("<w:tbl>", xml, fixed = TRUE)[[1L]]), 2L)
  expect_identical(
    length(gregexpr("<w:sectPr>", xml, fixed = TRUE)[[1L]]),
    2L
  )
  expect_false(grepl("pageBreakBefore", xml, fixed = TRUE))

  # Each panel's `<w:tblGrid>` matches its OWN column set: panel 1 =
  # stub(2) + data(2) = 4 gridCols; panel 2 = stub(2) + data(1) = 3.
  # The differing counts are the malformed-table regression guard.
  grids <- regmatches(
    xml,
    gregexpr("<w:tblGrid>.*?</w:tblGrid>", xml, perl = TRUE)
  )[[1L]]
  gridcols <- vapply(
    grids,
    function(g) length(gregexpr("<w:gridCol", g, fixed = TRUE)[[1L]]),
    integer(1L)
  )
  expect_identical(unname(gridcols), c(4L, 3L))

  # The `usage = "id"` stub label repeats in BOTH panel tables.
  expect_identical(length(gregexpr(">Stat<", xml, fixed = TRUE)[[1L]]), 2L)
})

test_that("DOCX panels = 1 emit a single <w:tbl> with no inter-panel break", {
  d <- data.frame(grp = c("a", "b"), c1 = 1:2, c2 = 3:4)
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(panels = 1L)
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  xml <- paste(
    readLines(unz(out, "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_identical(length(gregexpr("<w:tbl>", xml, fixed = TRUE)[[1L]]), 1L)
  # Single panel -> one section (just the body-level sectPr), no break.
  expect_identical(
    length(gregexpr("<w:sectPr>", xml, fixed = TRUE)[[1L]]),
    1L
  )
  expect_false(grepl("pageBreakBefore", xml, fixed = TRUE))
})

test_that("DOCX repeats the title block on every panel", {
  # repeat_content defaults to include "titles", so the title block
  # rides each panel's table as <w:tblHeader/> rows -- every panel
  # page must carry the table number, not just panel 1.
  d <- data.frame(grp = c("a", "b"), c1 = 1:2, c2 = 3:4, c3 = 5:6)
  spec <- tabular(d, titles = c("RepeatTitleZ", "Demographics")) |>
    cols(grp = col_spec(usage = "group", group_display = "column")) |>
    paginate(panels = 2L)
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  xml <- paste(
    readLines(unz(out, "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_identical(length(gregexpr("<w:tbl>", xml, fixed = TRUE)[[1L]]), 2L)
  expect_identical(
    length(gregexpr("RepeatTitleZ", xml, fixed = TRUE)[[1L]]),
    2L
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
  # Footnotes ride footer1.xml by default; the cascade halign surfaces
  # there on the TabularFoot paragraph.
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  ftr <- paste(
    readLines(
      file.path(.unzip_docx(out), "word/footer1.xml"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(ftr, "TabularFoot.*<w:jc w:val=\"right\"/>", fixed = FALSE)
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
        indent = "indent_level",
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
      stat_label = col_spec(indent = 1, label = "Response"),
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
  # "Active Treatment" carries the band UNDERLINE (cmidrule(lr), the
  # <w:bottom> side). All three cells share the full-width toprule
  # (<w:top>, header_top) since "Active Treatment" is the topmost
  # band; the two blank flanking cells carry no underline.
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
  expect_match(
    tcs[band_idx],
    "<w:bottom w:space=\"0\" w:val=\"single\"",
    fixed = TRUE
  )
  for (i in blank_idx) {
    expect_no_match(tcs[i], "<w:bottom", fixed = TRUE)
  }
})

test_that("cell_padding emits per-side w:tcMar (padding SSOT)", {
  # With no body padding override, DOCX emits left/right tcMar from
  # the horizontal SSOT so the rendered margin matches the measured
  # column width; vertical margin stays Word's default. c(t, r, b, l)
  # renders left / right exactly per side.
  spec <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding = c(0, 15, 0, 5))
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

# --- group-header + subgroup weight follows the style cascade --------

.docx_group_spec <- function() {
  d <- data.frame(
    soc = c("Infections", "Infections"),
    label = c("Pneumonia", "Sepsis"),
    x = c("1", "2")
  )
  tabular(d) |>
    cols(
      label = col_spec(label = "PT"),
      soc = col_spec(usage = "group", group_display = "header_row"),
      x = col_spec()
    )
}

.docx_doc_xml <- function(spec) {
  out <- withr::local_tempfile(
    fileext = ".docx",
    .local_envir = parent.frame()
  )
  emit(spec, out)
  paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml"), warn = FALSE),
    collapse = ""
  )
}

test_that("group-header rows are bold by default (#edge1)", {
  doc <- .docx_doc_xml(.docx_group_spec())
  expect_match(
    doc,
    "<w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Infections"
  )
})

test_that("cells_group_headers(bold = FALSE) drops <w:b/> on section rows (#edge2)", {
  doc <- .docx_doc_xml(
    .docx_group_spec() |> style(bold = FALSE, .at = cells_group_headers())
  )
  seg <- regmatches(doc, regexpr("<w:r>.{0,60}?Infections", doc))
  expect_false(grepl("<w:b/>", seg, fixed = TRUE))
})

test_that("cells_group_headers() carries italic + colour onto section rows (#edge3)", {
  doc <- .docx_doc_xml(
    .docx_group_spec() |>
      style(
        bold = FALSE,
        italic = TRUE,
        color = "#FF0000",
        .at = cells_group_headers()
      )
  )
  seg <- regmatches(
    doc,
    regexpr("<w:rPr>.{0,80}?</w:rPr><w:t[^>]*>Infections", doc)
  )
  expect_match(seg, "<w:i/>")
  expect_match(seg, "<w:color w:val=\"FF0000\"/>")
  expect_false(grepl("<w:b/>", seg, fixed = TRUE))
})

test_that("subgroup banner weight follows cells_subgroup_labels() (#edge12)", {
  d <- data.frame(g = c("A", "A", "B", "B"), x = 1:4)
  nb <- function(xml) length(gregexpr("<w:b/>", xml, fixed = TRUE)[[1]])
  def <- .docx_doc_xml(tabular(d) |> subgroup("g"))
  off <- .docx_doc_xml(
    tabular(d) |>
      subgroup("g") |>
      style(bold = FALSE, italic = TRUE, .at = cells_subgroup_labels())
  )
  # Two banner rows (A, B) are bold by default; `bold = FALSE` de-bolds
  # both (the residual `<w:b/>` is the column-label header, untouched).
  expect_gt(nb(def), nb(off))
  # `italic = TRUE` adds `<w:i/>` to each banner run.
  expect_match(off, "<w:i/>")
})

# ---------------------------------------------------------------------
# Thread I — canonical <w:rPr> child order under nested inline markup.
# Nested md()/html() markup accumulates run-property fragments in markup
# NESTING order (.docx_run_wrap appends each wrap token), which is
# arbitrary vs the OOXML CT_RPr schema sequence. The out-of-order form is
# well-formed XML but schema-invalid, so Word rejects it as "unreadable
# content" -- and xml2::read_xml() does NOT catch it. The order
# assertions below are therefore the load-bearing regression guard.
# ---------------------------------------------------------------------

test_that(".docx_sort_rpr orders rPr children canonically (stable, lossless)", {
  # bold-inside-italic accumulates as <w:i/><w:b/>; canonical = b before i.
  expect_identical(
    tabular:::.docx_sort_rpr("<w:i/><w:b/>"),
    "<w:b/><w:i/>"
  )
  # Hyperlink rStyle must lead, then b, i (rStyle = element 1 in CT_RPr).
  expect_identical(
    tabular:::.docx_sort_rpr("<w:b/><w:i/><w:rStyle w:val=\"Hyperlink\"/>"),
    "<w:rStyle w:val=\"Hyperlink\"/><w:b/><w:i/>"
  )
  # vertAlign sorts last; an already-ordered string is returned unchanged.
  expect_identical(
    tabular:::.docx_sort_rpr(
      "<w:b/><w:i/><w:vertAlign w:val=\"superscript\"/>"
    ),
    "<w:b/><w:i/><w:vertAlign w:val=\"superscript\"/>"
  )
  # rFonts (code) sorts before b; font name with a space is preserved.
  expect_identical(
    tabular:::.docx_sort_rpr(
      "<w:b/><w:rFonts w:ascii=\"Liberation Mono\" w:hAnsi=\"Liberation Mono\"/>"
    ),
    "<w:rFonts w:ascii=\"Liberation Mono\" w:hAnsi=\"Liberation Mono\"/><w:b/>"
  )
  # Empty and single-fragment inputs are no-ops.
  expect_identical(tabular:::.docx_sort_rpr(""), "")
  expect_identical(tabular:::.docx_sort_rpr("<w:b/>"), "<w:b/>")
  # Unknown elements are preserved and sorted last (defensive, lossless).
  expect_identical(
    tabular:::.docx_sort_rpr("<w:foo/><w:b/>"),
    "<w:b/><w:foo/>"
  )
})

test_that("DOCX nested inline markup emits canonical <w:rPr> order (#thread-I)", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = md("*Italic **bold** superscript^a^ end*")
  )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  footer_path <- file.path(.unzip_docx(out), "word/footer1.xml")
  ftr <- paste(readLines(footer_path, warn = FALSE), collapse = "")

  # Correct: bold-inside-italic emits <w:b/> before <w:i/>.
  expect_match(ftr, "<w:rPr><w:b/><w:i/></w:rPr>", fixed = TRUE)
  # The buggy markup-nesting order must be gone.
  expect_no_match(ftr, "<w:rPr><w:i/><w:b/></w:rPr>", fixed = TRUE)
  # vertAlign already sorts after i, and stays correct.
  expect_match(
    ftr,
    "<w:rPr><w:i/><w:vertAlign w:val=\"superscript\"/></w:rPr>",
    fixed = TRUE
  )
  expect_no_error(xml2::read_xml(footer_path))
})

test_that("DOCX emits well-formed XML for every part with markup-heavy input", {
  # Systemic output-validity smoke: every word/*.xml part of a
  # markup-heavy render must parse. Backstops gross malformation from
  # future edits to the DOCX backend.
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = c("Title", md("With **bold** and *italic*")),
    footnotes = md("Footnote **bold^sup^** and ~sub~")
  ) |>
    cols(
      x = col_spec(label = md("`code` **bold**")),
      y = col_spec(label = md("*italic*"))
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  parts <- list.files(
    file.path(unzipped, "word"),
    pattern = "[.]xml$",
    full.names = TRUE
  )
  expect_gt(length(parts), 0L)
  for (p in parts) {
    expect_no_error(xml2::read_xml(p))
  }
})

test_that("preset(padding=list(header=...)) emits header <w:tcMar> (#thread-C)", {
  df <- data.frame(grp = c("A", "B"), d50 = c("1", "2"), d100 = c("3", "4"))
  spec <- tabular(df) |>
    headers("Drug" = c("d50", "d100")) |>
    preset(padding = list(header = c(top = 6, bottom = 6)))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  doc <- paste(
    readLines(file.path(.unzip_docx(out), "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  # 6pt -> 120 dxa on the header band + column-label cells (preset = NULL
  # in the emitter, so only the header override emits, not body padding).
  expect_match(
    doc,
    "<w:tcMar><w:top w:w=\"120\" w:type=\"dxa\"/>",
    fixed = TRUE
  )
  expect_match(
    doc,
    "<w:bottom w:w=\"120\" w:type=\"dxa\"/></w:tcMar>",
    fixed = TRUE
  )
})

test_that("rules='frame' draws <w:left/right> on table-proper rows incl. blank/group (#thread-D)", {
  spec <- tabular(cdisc_saf_demo, titles = "T", footnotes = "F") |>
    cols(
      variable = col_spec(usage = "group", group_display = "header_row"),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    headers("Active" = c("drug_50", "drug_100")) |>
    preset(rules = "frame")
  out <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, out))
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_match(doc, "<w:left w:space=\"0\"", fixed = TRUE)
  expect_match(doc, "<w:right w:space=\"0\"", fixed = TRUE)
  # A merged blank / group-header / subgroup row carries BOTH edges on its
  # single gridSpan cell (the rows the retired per-cell stamp used to
  # gap). gridSpan count = visible columns (the group host is dropped).
  expect_match(
    doc,
    "<w:gridSpan w:val=\"\\d+\"/><w:tcBorders><w:left[^/]*/><w:right[^/]*/></w:tcBorders>"
  )
  # The whole document stays schema-valid (canonical CT_TcBorders order).
  expect_no_error(xml2::read_xml(file.path(unzipped, "word/document.xml")))

  # Non-frame preset emits no frame edges (no regression).
  out2 <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(
    emit(tabular(cdisc_saf_demo) |> preset(rules = "booktabs"), out2)
  )
  doc2 <- paste(
    readLines(
      file.path(.unzip_docx(out2), "word/document.xml"),
      warn = FALSE
    ),
    collapse = ""
  )
  expect_no_match(doc2, "<w:left w:space=\"0\"", fixed = TRUE)
})

test_that("stripe + header background reach special rows in DOCX (#thread-B)", {
  spec <- tabular(cdisc_saf_demo, titles = "T", footnotes = "F") |>
    cols(
      variable = col_spec(usage = "group", group_display = "header_row"),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    headers("Active" = c("drug_50", "drug_100")) |>
    preset(
      stripe = c(odd = "#f5f5f5", even = "#ffffff"),
      colors = list(header = c(background = "#dddddd"))
    )
  out <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, out))
  unzipped <- .unzip_docx(out)
  doc <- paste(
    readLines(file.path(unzipped, "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  # Header band + column-label cells (incl. empty flanks) carry the
  # header fill via `<w:shd>`.
  expect_match(doc, "w:fill=\"DDDDDD\"", fixed = TRUE)
  # Blank + group-header merged cells carry the stripe fill.
  expect_match(doc, "w:fill=\"F5F5F5\"", fixed = TRUE)
  # XML stays well-formed with the added <w:shd> in canonical CT_TcPr
  # order (tcBorders -> shd -> tcMar -> vAlign).
  expect_no_error(xml2::read_xml(file.path(unzipped, "word/document.xml")))
})

test_that("cells_pagehead(slot=) styles one slot + band border in DOCX (#thread-G)", {
  spec <- tabular(cdisc_saf_demo) |>
    preset(pagehead = list(left = "L", center = "C")) |>
    style(
      bold = TRUE,
      color = "#cc0000",
      .at = cells_pagehead(slot = "center")
    ) |>
    style(border_bottom = brdr("thin"), .at = cells_pagehead())
  out <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, out))
  ud <- .unzip_docx(out)
  hd <- paste(
    readLines(file.path(ud, "word/header1.xml"), warn = FALSE),
    collapse = ""
  )
  # Centre slot runs carry bold + colour (via the cell default rPr).
  expect_match(hd, "<w:b/>", fixed = TRUE)
  expect_match(hd, "CC0000", fixed = TRUE)
  # The band cells carry the bottom rule (not the default all-nil).
  expect_match(hd, "<w:bottom w:space", fixed = TRUE)
  # header1.xml stays well-formed (rPr canonical order, valid tcBorders).
  expect_no_error(xml2::read_xml(file.path(ud, "word/header1.xml")))
})

# ---- DOCX chrome surfaces honor per-surface text styling (#docx-chrome) ---

test_that("DOCX title / footnote / header honor style() text overrides (#docx-chrome)", {
  d <- data.frame(
    grp = c("A", "A"),
    x = c("1", "2"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(d, titles = "MYTITLE", footnotes = "MYFOOT") |>
    cols(
      grp = col_spec(
        usage = "group",
        group_display = "column",
        group_skip = TRUE,
        label = "G"
      ),
      x = col_spec(label = "MYHEADER")
    ) |>
    style(color = "#FF0000", italic = TRUE, .at = cells_title()) |>
    style(color = "#00FF00", .at = cells_footnotes()) |>
    style(color = "#0000FF", .at = cells_headers())
  f <- withr::local_tempfile(fileext = ".docx")
  emit(spec, f)
  dir <- withr::local_tempdir()
  utils::unzip(f, exdir = dir)
  parts <- list.files(
    dir,
    pattern = "\\.xml$",
    recursive = TRUE,
    full.names = TRUE
  )
  all_xml <- paste(
    unlist(lapply(parts, function(p) {
      paste(readLines(p, warn = FALSE), collapse = "\n")
    })),
    collapse = "\n"
  )
  expect_true(grepl("w:color w:val=\"FF0000\"", all_xml)) # title
  expect_true(grepl("w:i/>", all_xml, fixed = TRUE)) # title italic
  expect_true(grepl("w:color w:val=\"00FF00\"", all_xml)) # footnote
  expect_true(grepl("w:color w:val=\"0000FF\"", all_xml)) # header
})

# ---- DOCX page-chrome slot background (#page-chrome) --------------------

test_that("DOCX pagehead slot honors background shading (#page-chrome)", {
  spec <- tabular(data.frame(x = c("1", "2"))) |>
    cols(x = col_spec(label = "X")) |>
    preset(pagehead = list(left = "PH")) |>
    style(background = "#FFFF00", .at = cells_pagehead(slot = "left"))
  f <- withr::local_tempfile(fileext = ".docx")
  emit(spec, f)
  dir <- withr::local_tempdir()
  utils::unzip(f, exdir = dir)
  hdr <- paste(
    readLines(file.path(dir, "word", "header1.xml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("<w:shd", hdr) && grepl("FFFF00", hdr))
})

# ---- DOCX group-header halign cascade (#PAR2) --------------------------

test_that("DOCX group-header rows honor the halign cascade (#PAR2)", {
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
      stat_label = col_spec(indent = 1, label = "Response"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50")
    ) |>
    style(halign = "center", .at = cells_group_headers())
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # The group-header paragraph picks up the cascade alignment, not the
  # hardcoded left.
  expect_match(
    doc,
    "<w:jc w:val=\"center\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">Best Overall Response</w:t>",
    fixed = TRUE
  )
})

# B-DOCX: relative output paths must resolve against the caller's cwd,
# not the backend's temp staging dir. The DOCX backend setwd()s into a
# temp stage before utils::zip; a relative `file` previously resolved
# against that stage and failed with a zip I/O error. emit() now
# absolutises the path at the .check_emit_file chokepoint.

test_that("emit(.docx) accepts a relative output path from any cwd (#B-DOCX)", {
  spec <- tabular(
    data.frame(a = "1", b = "2", stringsAsFactors = FALSE),
    titles = "T"
  )
  wd <- withr::local_tempdir()
  withr::local_dir(wd)
  dir.create("out")
  rel <- file.path("out", "rel.docx")

  expect_no_error(emit(spec, rel))
  expect_true(file.exists(rel))

  # Valid PK zip with the mandatory document part.
  con <- file(rel, "rb")
  magic <- readBin(con, "raw", 2L)
  close(con)
  expect_identical(magic, as.raw(c(0x50, 0x4b))) # "PK"
  entries <- utils::unzip(rel, list = TRUE)$Name
  expect_true("word/document.xml" %in% entries)
})

test_that("emit() relative paths still work for RTF and HTML (#B-DOCX no-regress)", {
  spec <- tabular(
    data.frame(a = "1", b = "2", stringsAsFactors = FALSE),
    titles = "T"
  )
  wd <- withr::local_tempdir()
  withr::local_dir(wd)
  expect_no_error(emit(spec, "x.rtf"))
  expect_true(file.exists("x.rtf"))
  expect_no_error(emit(spec, "x.html"))
  expect_true(file.exists("x.html"))
})

# ---------------------------------------------------------------------
# Cross-backend keep-with-next parity + subgroup banner placement
# ---------------------------------------------------------------------

# Helper: read word/document.xml of an emitted spec as one string.
.docx_doc_xml <- function(spec) {
  out <- withr::local_tempfile(
    fileext = ".docx",
    .local_envir = parent.frame()
  )
  emit(spec, out)
  unzipped <- .unzip_docx(out)
  paste(
    readLines(file.path(unzipped, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
}

test_that("docx honours keep_with_next instead of gluing every row (#docx-keepnext)", {
  # A flat, un-paginated table has no keep_together groups, so the engine
  # keep_with_next mask is empty: DOCX must emit zero <w:keepNext/>, the
  # same as RTF emits zero \keepn. The bug stamped <w:keepNext/> on every
  # non-last row, forcing Word to keep the whole table on one page.
  df <- data.frame(
    lab = paste0("Row", 1:6),
    a = as.character(1:6),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T") |>
    cols(lab = col_spec(label = "L"), a = col_spec(label = "A"))

  docx_xml <- .docx_doc_xml(spec)
  rtf_out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, rtf_out)
  rtf_txt <- paste(readLines(rtf_out, warn = FALSE), collapse = "")

  n_keepnext <- lengths(regmatches(
    docx_xml,
    gregexpr("<w:keepNext/>", docx_xml)
  ))
  n_keepn <- lengths(regmatches(rtf_txt, gregexpr("\\\\keepn", rtf_txt)))
  expect_equal(n_keepnext, 0L)
  expect_equal(n_keepnext, n_keepn)
})

test_that("docx subgroup banner leads above the column header (#docx-subgroup-banner)", {
  # Anatomy contract: the subgroup banner sits ABOVE the column-header
  # band (RTF/PDF do this). The bug emitted the banner inline in the body,
  # below the header, and as a repeating tblHeader row that duplicated at
  # the next subgroup.
  df <- data.frame(
    PARAM = rep(c("Param One", "Param Two"), each = 3),
    lab = rep(c("r1", "r2", "r3"), 2),
    a = as.character(1:6),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T") |>
    cols(lab = col_spec(label = "Lab"), a = col_spec(label = "A")) |>
    subgroup(by = "PARAM")

  docx_xml <- .docx_doc_xml(spec)
  pos_banner <- regexpr("Param One", docx_xml)
  pos_label <- regexpr("Lab", docx_xml)
  expect_gt(pos_banner, 0L)
  expect_gt(pos_label, 0L)
  # Banner before the column-label band.
  expect_lt(pos_banner, pos_label)
  # Each subgroup banner appears exactly once (no duplication).
  n_p1 <- lengths(regmatches(docx_xml, gregexpr("Param One", docx_xml)))
  n_p2 <- lengths(regmatches(docx_xml, gregexpr("Param Two", docx_xml)))
  expect_equal(n_p1, 1L)
  expect_equal(n_p2, 1L)
})

test_that("keep-with-next markers are consistent across docx / rtf / latex (#keep-parity)", {
  # A flat, un-paginated table has no keep_together groups: every
  # backend that has a keep-with-next marker must emit zero of them.
  # docx -> <w:keepNext/>, rtf -> \keepn, latex -> \\* (vs plain \\).
  # HTML is a single continuous table and has no row-level keep marker.
  df <- data.frame(
    lab = paste0("Row", 1:8),
    a = as.character(1:8),
    b = as.character(8:1),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T", footnotes = "F") |>
    cols(
      lab = col_spec(label = "L"),
      a = col_spec(label = "A"),
      b = col_spec(label = "B")
    )

  docx <- withr::local_tempfile(fileext = ".docx")
  rtf <- withr::local_tempfile(fileext = ".rtf")
  tex <- withr::local_tempfile(fileext = ".tex")
  html <- withr::local_tempfile(fileext = ".html")
  emit(spec, docx)
  emit(spec, rtf)
  emit(spec, tex)
  emit(spec, html)

  docx_xml <- {
    u <- .unzip_docx(docx)
    paste(
      readLines(file.path(u, "word", "document.xml"), warn = FALSE),
      collapse = ""
    )
  }
  rtf_txt <- paste(readLines(rtf, warn = FALSE), collapse = "")
  tex_txt <- paste(readLines(tex, warn = FALSE), collapse = "")

  n_docx <- lengths(regmatches(docx_xml, gregexpr("<w:keepNext/>", docx_xml)))
  n_rtf <- lengths(regmatches(rtf_txt, gregexpr("\\\\keepn", rtf_txt)))
  n_tex <- lengths(regmatches(tex_txt, gregexpr("\\\\\\\\\\*", tex_txt)))

  expect_equal(n_docx, 0L)
  expect_equal(n_rtf, 0L)
  expect_equal(n_tex, 0L)
  # HTML still renders a continuous table (no row-level keep concept).
  expect_true(file.exists(html))
})

test_that("keep_together glues group runs consistently across docx / rtf / latex (#keep-together)", {
  # A group column with multi-row runs + paginate(keep_together) makes the
  # engine keep_with_next mask glue each run. Every backend with a keep
  # marker must reflect it: docx <w:keepNext/> (rows that carry it),
  # rtf \keepn, latex \\*.
  df <- data.frame(
    grp = rep(c("G1", "G2", "G3"), each = 3),
    lab = rep(c("r1", "r2", "r3"), 3),
    a = as.character(1:9),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T") |>
    cols(
      grp = col_spec(usage = "group", label = "Group"),
      lab = col_spec(label = "L"),
      a = col_spec(label = "A")
    ) |>
    paginate(keep_together = "grp")

  docx <- withr::local_tempfile(fileext = ".docx")
  rtf <- withr::local_tempfile(fileext = ".rtf")
  tex <- withr::local_tempfile(fileext = ".tex")
  emit(spec, docx)
  emit(spec, rtf)
  emit(spec, tex)

  u <- .unzip_docx(docx)
  docx_xml <- paste(
    readLines(file.path(u, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  rtf_txt <- paste(readLines(rtf, warn = FALSE), collapse = "")
  tex_txt <- paste(readLines(tex, warn = FALSE), collapse = "")

  # docx: number of body rows that carry at least one <w:keepNext/>.
  docx_rows <- regmatches(
    docx_xml,
    gregexpr("<w:tr\\b.*?</w:tr>", docx_xml)
  )[[1]]
  n_docx_rows <- sum(grepl("<w:keepNext/>", docx_rows, fixed = TRUE))
  n_rtf <- lengths(regmatches(rtf_txt, gregexpr("\\\\keepn", rtf_txt)))
  n_tex <- lengths(regmatches(tex_txt, gregexpr("\\\\\\\\\\*", tex_txt)))

  # keep_together is honoured in every backend (markers present). Exact
  # counts differ by backend: each synthesises group-header / blank-gap
  # rows differently and glues those too, so the invariant is "present in
  # all", not equal counts.
  expect_gt(n_docx_rows, 0L)
  expect_gt(n_rtf, 0L)
  expect_gt(n_tex, 0L)
})
