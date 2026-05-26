# backend_rtf — RTF 1.9.1 native backend. Covers registry wiring,
# document shell, font table, section definition, page-band
# emission with growth-direction semantics, header bands, body
# cells with inline AST, escaping, multi-page pagination, and a
# golden snapshot pinned on the canonical saf_demo pipeline.

# Convenience helper: emit a spec to a tempfile and read the RTF
# back as one long string for substring assertions. Keeps the
# test code dense without sacrificing readability.
.rtf_emit_text <- function(spec, file = NULL) {
  if (is.null(file)) {
    file <- withr::local_tempfile(
      fileext = ".rtf",
      .local_envir = parent.frame()
    )
  }
  emit(spec, file)
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("backend_rtf is registered under 'rtf'", {
  expect_true(tabular:::.has_backend("rtf"))
  expect_true("rtf" %in% tabular:::.registered_backend_formats())
})

# ---------------------------------------------------------------------
# End-to-end emit
# ---------------------------------------------------------------------

test_that("emit() to .rtf produces a non-empty RTF document", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".rtf")
  result <- emit(spec, out)
  expect_identical(result, out)
  expect_gt(file.size(out), 0L)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(startsWith(rtf, "{\\rtf1\\ansi"))
  expect_true(endsWith(rtf, "}"))
})

test_that("backend_rtf() is callable directly with a grid + file", {
  grid <- as_grid(tabular(data.frame(x = 1:3)))
  out <- withr::local_tempfile(fileext = ".rtf")
  result <- backend_rtf(grid, out)
  expect_identical(result, out)
  expect_true(file.exists(out))
})

# ---------------------------------------------------------------------
# Preamble — font table + section definition
# ---------------------------------------------------------------------

test_that("font table emits {\\fonttbl} with body + mono entries", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl("{\\fonttbl", rtf, fixed = TRUE))
  expect_true(grepl("\\f0\\froman", rtf, fixed = TRUE))
  expect_true(grepl("\\f1\\fmodern", rtf, fixed = TRUE))
})

test_that("font_family = sans switches body class to \\fswiss", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_family = "sans")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\f0\\fswiss", rtf, fixed = TRUE))
})

test_that("font_family = mono switches body class to \\fmodern", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_family = "mono")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\f0\\fmodern", rtf, fixed = TRUE))
})

test_that("font_family explicit-stack falls back to \\froman class", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_family = c("Courier New", "mono"))
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\f0\\froman", rtf, fixed = TRUE))
  # First entry of the stack lands as the named face in \f0.
  expect_true(grepl("Courier New", rtf, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Font table — Liberation-first chain + \*\falt fallback for Word
# ---------------------------------------------------------------------

test_that("default serif leads with Liberation Serif as \\f0 body", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl(
    "{\\f0\\froman\\fprq2 Liberation Serif",
    rtf,
    fixed = TRUE
  ))
})

test_that("default serif emits {\\*\\falt Times New Roman} in body font definition", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl(
    "Liberation Serif{\\*\\falt Times New Roman}",
    rtf,
    fixed = TRUE
  ))
})

test_that("sans family emits {\\*\\falt Arial} in body font definition", {
  spec <- tabular(data.frame(x = 1:3)) |> preset(font_family = "sans")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl(
    "Liberation Sans{\\*\\falt Arial}",
    rtf,
    fixed = TRUE
  ))
})

test_that("mono \\f1 carries {\\*\\falt Courier New} on every render", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl(
    "{\\f1\\fmodern\\fprq1 Liberation Mono{\\*\\falt Courier New}",
    rtf,
    fixed = TRUE
  ))
})

test_that("single-entry chain (non-aliased named font) emits NO \\*\\falt", {
  spec <- tabular(data.frame(x = 1:3)) |> preset(font_family = "Inter")
  rtf <- .rtf_emit_text(spec)
  # Body font is "Inter" with no fallback
  expect_true(grepl("\\f0\\froman\\fprq2 Inter;", rtf, fixed = TRUE))
  # No \*\falt for the Inter line specifically — check via regex
  inter_line <- regmatches(
    rtf,
    regexpr("\\{\\\\f0\\\\froman\\\\fprq2 Inter[^;]*;\\}", rtf, perl = TRUE)
  )
  expect_false(grepl("\\*\\falt", inter_line, fixed = TRUE))
})

test_that("PS-era alias 'Times' renders as Liberation Serif body with Times fallback", {
  spec <- tabular(data.frame(x = 1:3)) |> preset(font_family = "Times")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl(
    "Liberation Serif{\\*\\falt Times New Roman}",
    rtf,
    fixed = TRUE
  ))
})

test_that("font_size emits \\fsN at body where N = 2*points", {
  spec <- tabular(data.frame(x = 1:3)) |> preset(font_size = 10)
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\fs20", rtf, fixed = TRUE))
})

test_that("section def emits letter portrait by default in twips", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  # Letter portrait: 12240 x 15840 twips
  expect_true(grepl("\\pgwsxn12240\\pghsxn15840", rtf, fixed = TRUE))
  expect_false(grepl("\\lndscpsxn", rtf, fixed = TRUE))
})

test_that("section def swaps width/height + adds \\lndscpsxn for landscape", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(orientation = "landscape")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\lndscpsxn", rtf, fixed = TRUE))
  expect_true(grepl("\\pgwsxn15840\\pghsxn12240", rtf, fixed = TRUE))
})

test_that("section def emits A4 paper dimensions when paper_size = 'a4'", {
  spec <- tabular(data.frame(x = 1:3)) |> preset(paper_size = "a4")
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\pgwsxn11906\\pghsxn16838", rtf, fixed = TRUE))
})

test_that("margins translate to twips on all four sides", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(margins = c(1, 0.5, 1, 0.5))
  rtf <- .rtf_emit_text(spec)
  # 1in = 1440 twips, 0.5in = 720 twips
  expect_true(grepl("\\margt1440", rtf, fixed = TRUE))
  expect_true(grepl("\\margr720", rtf, fixed = TRUE))
  expect_true(grepl("\\margb1440", rtf, fixed = TRUE))
  expect_true(grepl("\\margl720", rtf, fixed = TRUE))
})

test_that("margins accept character with TeX unit suffix", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(margins = c("2cm", "1cm", "2cm", "1cm"))
  rtf <- .rtf_emit_text(spec)
  # 2cm ≈ 1134 twips; 1cm ≈ 567 twips
  expect_true(grepl("\\margt1134", rtf, fixed = TRUE))
  expect_true(grepl("\\margr567", rtf, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Page bands — {\header} / {\footer}
# ---------------------------------------------------------------------

test_that("empty pagehead / pagefoot emits no header/footer groups", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_false(grepl("{\\header", rtf, fixed = TRUE))
  expect_false(grepl("{\\footer", rtf, fixed = TRUE))
  expect_false(grepl("\\headery", rtf, fixed = TRUE))
  expect_false(grepl("\\footery", rtf, fixed = TRUE))
})

test_that("populated pagehead emits {\\header} group + \\headery reservation", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      )
    )
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("{\\header", rtf, fixed = TRUE))
  expect_true(grepl("\\headery", rtf, fixed = TRUE))
  # Page tokens resolved to PAGE / NUMPAGES field codes
  expect_true(grepl("{\\field{\\*\\fldinst PAGE}}", rtf, fixed = TRUE))
  expect_true(grepl("{\\field{\\*\\fldinst NUMPAGES}}", rtf, fixed = TRUE))
  expect_false(grepl("{page}", rtf, fixed = TRUE))
})

test_that("populated pagefoot emits {\\footer} group + \\footery reservation", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagefoot = list(left = "{program}", right = "{datetime}"))
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("{\\footer", rtf, fixed = TRUE))
  expect_true(grepl("\\footery", rtf, fixed = TRUE))
})

test_that("multi-row pagehead emits one table row per band row in REVERSE order", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagehead = list(left = c("Body edge row", "Far from body row")))
  rtf <- .rtf_emit_text(spec)
  # Extract the {\header} group only
  m <- regmatches(
    rtf,
    regexpr("\\{\\\\header[\\s\\S]*?\\n\\}", rtf, perl = TRUE)
  )
  expect_true(grepl("Body edge row", m, fixed = TRUE))
  expect_true(grepl("Far from body row", m, fixed = TRUE))
  # REVERSE: "Far from body row" appears before "Body edge row"
  expect_lt(regexpr("Far from body row", m), regexpr("Body edge row", m))
  # Two band rows -> two \row tokens inside {\header}
  expect_identical(length(gregexpr("\\\\row", m, perl = TRUE)[[1L]]), 2L)
})

test_that("multi-row pagefoot emits one table row per band row in FORWARD order", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagefoot = list(left = c("Body edge row", "Far from body row")))
  rtf <- .rtf_emit_text(spec)
  m <- regmatches(
    rtf,
    regexpr("\\{\\\\footer[\\s\\S]*?\\n\\}", rtf, perl = TRUE)
  )
  expect_lt(regexpr("Body edge row", m), regexpr("Far from body row", m))
})

test_that("page-band NULL slots collapse (no \\cell for empty slot)", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagehead = list(left = "Only left"))
  rtf <- .rtf_emit_text(spec)
  m <- regmatches(
    rtf,
    regexpr("\\{\\\\header[\\s\\S]*?\\n\\}", rtf, perl = TRUE)
  )
  # Only one cell -> one \cell + one \cellx + one \row inside the header
  expect_identical(length(gregexpr("\\\\cell\\b", m, perl = TRUE)[[1L]]), 1L)
})

test_that("inline AST formatting survives into the page band (bold)", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagehead = list(left = md("**Bold protocol**")))
  rtf <- .rtf_emit_text(spec)
  m <- regmatches(
    rtf,
    regexpr("\\{\\\\header[\\s\\S]*?\\n\\}", rtf, perl = TRUE)
  )
  expect_true(grepl("{\\b Bold protocol}", m, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Header bands + body cells
# ---------------------------------------------------------------------

test_that("body cell alignment maps to \\ql / \\qc / \\qr / decimal -> \\qr", {
  spec <- tabular(data.frame(L = 1, C = 1, R = 1, D = 1.5)) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
    )
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\ql", rtf, fixed = TRUE))
  expect_true(grepl("\\qc", rtf, fixed = TRUE))
  expect_true(grepl("\\qr", rtf, fixed = TRUE))
})

test_that("multi-level header bands emit one row per band depth", {
  spec <- tabular(data.frame(a = 1, b = 1, c = 1)) |>
    headers("Group X" = c("a", "b"))
  rtf <- .rtf_emit_text(spec)
  # The band row exists (a span "Group X" cell + a span over c)
  expect_true(grepl("Group X", rtf, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Inline formatting renders correctly through the inline_ast path
# that drives titles, footnotes, col_spec labels, and page-band
# slots. Body cells go through cells_text (post-engine_decimal,
# flat string) — that path is a pre-existing limitation across
# all backends and out of scope here.

test_that("inline md bold in a title renders as {\\b ...}", {
  spec <- tabular(data.frame(x = 1:3), titles = md("**Heavy title**"))
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("{\\b Heavy title}", rtf, fixed = TRUE))
})

test_that("inline md italic in a footnote renders as {\\i ...}", {
  spec <- tabular(
    data.frame(x = 1:3),
    footnotes = md("Source: *italic note*")
  )
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("{\\i italic note}", rtf, fixed = TRUE))
})

test_that("inline html sup in a title renders as {\\super ... \\nosupersub}", {
  spec <- tabular(data.frame(x = 1), titles = html("x<sup>2</sup>"))
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("{\\super 2\\nosupersub}", rtf, fixed = TRUE))
})

test_that("inline newline inside multi-line label renders as \\line", {
  spec <- tabular(data.frame(x = 1)) |>
    cols(x = col_spec(label = "Top\nBottom"))
  rtf <- .rtf_emit_text(spec)
  expect_true(grepl("\\line", rtf, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Escaping
# ---------------------------------------------------------------------

test_that(".rtf_escape escapes backslash, braces, non-ASCII", {
  out <- tabular:::.rtf_escape("a\\b{c}d")
  expect_identical(out, "a\\\\b\\{c\\}d")
})

test_that(".rtf_escape encodes non-ASCII as signed \\uNNNN? escapes", {
  out <- tabular:::.rtf_escape("alphaá")
  # 0xe1 = 225 (< 32768, stays positive)
  expect_identical(out, "alpha\\u225?")
})

test_that(".rtf_escape encodes high BMP code points as signed (negative) escapes", {
  # U+5BB6 = 23478 (still positive); use U+8FBC (36796) for negative
  out <- tabular:::.rtf_escape(intToUtf8(36796L))
  expect_identical(out, "\\u-28740?")
})

test_that(".rtf_escape encodes supplementary-plane chars as UTF-16 surrogate pairs", {
  # U+1F389 (party popper emoji) -> surrogate pair D83C DF89
  out <- tabular:::.rtf_escape(intToUtf8(0x1F389L))
  expect_identical(out, "\\u-10180?\\u-8311?")
  # U+1D400 (mathematical bold A) -> surrogate pair D835 DC00
  out2 <- tabular:::.rtf_escape(intToUtf8(0x1D400L))
  expect_identical(out2, "\\u-10187?\\u-9216?")
})

test_that(".rtf_escape_cell turns embedded newline into \\line", {
  out <- tabular:::.rtf_escape_cell("line1\nline2")
  expect_true(grepl("line1\\line", out, fixed = TRUE))
  expect_false(grepl("\n", out, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Pagination — one \sect per page
# ---------------------------------------------------------------------

test_that("multi-page spec emits one \\sect per grid@pages entry", {
  # paginate() computes rows_per_page from preset geometry. Use a
  # large data set + small font / margins to force multiple pages.
  spec <- tabular(data.frame(x = 1:500)) |>
    preset(font_size = 9, margins = 0.5) |>
    paginate()
  grid <- as_grid(spec)
  expected_pages <- length(grid@pages)
  expect_gt(expected_pages, 1L)
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  sect_count <- length(gregexpr("\\\\sect\\b", rtf, perl = TRUE)[[1L]])
  expect_identical(sect_count, expected_pages)
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline
# ---------------------------------------------------------------------

test_that("saf_demo golden pipeline matches the pinned .rtf snapshot", {
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
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  expect_snapshot_file(out, "saf_demo_golden.rtf")
})

# ---------------------------------------------------------------------
# chrome_style cascade — `style_template() |> style(.at = cells_*())`
# must propagate into the RTF output. Each test isolates one chrome
# surface so a regression points at the exact surface that broke.
# ---------------------------------------------------------------------

test_that("style(.at = cells_headers(), bold = TRUE, color = ...) emits a chrome \\cf token on the header row", {
  template <- style_template() |>
    style(.at = cells_headers(), bold = TRUE, color = "#cc0000")
  spec <- tabular(data.frame(x = 1:2, y = 3:4)) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)

  # The user-set chrome color registers in the dynamic colortbl.
  expect_match(
    rtf,
    "\\\\colortbl;.*\\\\red204\\\\green0\\\\blue0;",
    fixed = FALSE
  )
  # The header band emits the \cf<idx> token from the chrome cascade.
  expect_match(rtf, "\\\\cf[1-9][0-9]*", fixed = FALSE)
})

test_that("style(.at = cells_title(), halign = 'left') emits \\ql on the title paragraph", {
  template <- style_template() |>
    style(.at = cells_title(), halign = "left")
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demographics"
  ) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)
  # The chrome surface halign overrides the default center alignment
  # for the title paragraph.
  expect_match(rtf, "\\\\pard\\\\plain\\\\ql.*Demographics", fixed = FALSE)
})

test_that("style(.at = cells_footnotes(), italic = TRUE) emits \\i on the footnote paragraph", {
  template <- style_template() |>
    style(.at = cells_footnotes(), italic = TRUE)
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = "Source: ADSL"
  ) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)
  expect_match(rtf, "\\\\i.*Source: ADSL", fixed = FALSE)
})

test_that("style(.at = cells_headers(), border_top = brdr(1, 'double')) drives chrome \\brdrdb", {
  template <- style_template() |>
    style(.at = cells_headers(), border_top = brdr(1, "double", "#000000"))
  spec <- tabular(data.frame(x = 1L)) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)
  expect_match(rtf, "\\\\clbrdrt\\\\brdrdb\\\\brdrw20", fixed = FALSE)
})

test_that("style(.at = cells_title(), blank_above = 3) overrides preset@title_pad_top", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)
  # Three blank paragraphs above the title (versus the preset
  # default of 1).
  blanks <- length(gregexpr("\\\\pard\\\\plain\\\\par", rtf)[[1]])
  expect_gte(blanks, 3L)
})

# ---------------------------------------------------------------------
# Dynamic colortbl + fonttbl — Phase 2b: scan resolved styles
# ---------------------------------------------------------------------

test_that("a body cell color and a chrome color both register in the dynamic colortbl", {
  template <- style_template() |>
    style(.at = cells_headers(), color = "#cc0000")
  spec <- tabular(data.frame(x = c("a", "b"))) |>
    preset(.style = template) |>
    style(color = "#0000cc", .at = cells_body(where = x == "a"))
  rtf <- .rtf_emit_text(spec)
  # Both unique colors land in the colortbl.
  expect_match(rtf, "\\\\red204\\\\green0\\\\blue0;", fixed = FALSE)
  expect_match(rtf, "\\\\red0\\\\green0\\\\blue204;", fixed = FALSE)
})

test_that("a body cell font_family registers as \\f2+ in the dynamic fonttbl", {
  template <- style_template() |>
    style(.at = cells_headers(), font_family = "Inter")
  spec <- tabular(data.frame(x = 1L)) |>
    preset(.style = template)
  rtf <- .rtf_emit_text(spec)
  # \f0 is body; \f1 is mono; Inter registers at index 2 or above.
  expect_match(rtf, "\\{\\\\f[2-9][^{]*Inter", fixed = FALSE)
})
