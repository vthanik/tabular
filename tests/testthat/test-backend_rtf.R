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
  # Default body is mono, so \f0 (body) and \f1 (mono fallback)
  # both carry \fmodern. Switch to serif to confirm \f0 carries
  # \froman while \f1 stays \fmodern.
  rtf_default <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl("{\\fonttbl", rtf_default, fixed = TRUE))
  expect_true(grepl("\\f0\\fmodern", rtf_default, fixed = TRUE))
  expect_true(grepl("\\f1\\fmodern", rtf_default, fixed = TRUE))

  rtf_serif <- .rtf_emit_text(
    tabular(data.frame(x = 1:3)) |> preset(font_family = "serif")
  )
  expect_true(grepl("\\f0\\froman", rtf_serif, fixed = TRUE))
  expect_true(grepl("\\f1\\fmodern", rtf_serif, fixed = TRUE))
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

test_that("default mono leads with Liberation Mono as \\f0 body", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl(
    "{\\f0\\fmodern\\fprq2 Liberation Mono",
    rtf,
    fixed = TRUE
  ))
})

test_that("default mono emits {\\*\\falt Courier New} in body font definition", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  expect_true(grepl(
    "Liberation Mono{\\*\\falt Courier New}",
    rtf,
    fixed = TRUE
  ))
})

test_that("explicit serif leads with Liberation Serif + Times New Roman fallback", {
  rtf <- .rtf_emit_text(
    tabular(data.frame(x = 1:3)) |> preset(font_family = "serif")
  )
  expect_true(grepl(
    "{\\f0\\froman\\fprq2 Liberation Serif",
    rtf,
    fixed = TRUE
  ))
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

test_that("section def emits letter landscape by default in twips", {
  rtf <- .rtf_emit_text(tabular(data.frame(x = 1:3)))
  # Letter landscape: 15840 x 12240 twips, with \lndscpsxn marker
  expect_true(grepl("\\pgwsxn15840\\pghsxn12240", rtf, fixed = TRUE))
  expect_true(grepl("\\lndscpsxn", rtf, fixed = TRUE))
})

test_that("section def emits letter portrait dimensions when explicit", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(orientation = "portrait")
  rtf <- .rtf_emit_text(spec)
  expect_false(grepl("\\lndscpsxn", rtf, fixed = TRUE))
  expect_true(grepl("\\pgwsxn12240\\pghsxn15840", rtf, fixed = TRUE))
})

test_that("section def emits A4 paper dimensions when paper_size = 'a4'", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(paper_size = "a4", orientation = "portrait")
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

# ---------------------------------------------------------------------
# Change C: cells_indent sidecar -> RTF \li<twips>
# ---------------------------------------------------------------------

test_that("RTF emits \\li on data rows but NOT on header rows (Change C)", {
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
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Data rows carry `\liN` on the paragraph BEFORE the alignment token.
  expect_match(rtf, "\\\\li[0-9]+[^A-Za-z][^N]*Atrial", perl = TRUE)
  # Header rows (CARDIAC / GI band cells) do NOT carry `\li`.
  header_chunk <- sub(".*(CARDIAC\\\\cell).*", "\\1", rtf)
  expect_false(grepl("\\li", header_chunk, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Change D: is_header_row / is_blank_row branching in RTF
# ---------------------------------------------------------------------

test_that("RTF emits single-\\cellx merged-cell row for section headers (Change D)", {
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
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Header rows render as a bolded merged cell `{\b ...}\cell` followed
  # by `\row` (newline between the two tokens — they're emitted on
  # separate output lines by the row builder).
  expect_match(
    rtf,
    "\\{\\\\b Best Overall Response\\}\\\\cell\\s*\\\\row",
    perl = TRUE
  )
  expect_match(
    rtf,
    "\\{\\\\b Objective Response Rate\\}\\\\cell\\s*\\\\row",
    perl = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: nested band headers render with depth-aware \li
# ---------------------------------------------------------------------

test_that("RTF nested bands: band-1 header has no \\li, band-2 header has \\liN (Change D)", {
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
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Band 1 ("Safety", depth 0) -> `\pard\plain\intbl\ql {\b Safety}`
  # (no \li before \ql).
  expect_match(
    rtf,
    "\\\\pard\\\\plain\\\\intbl\\\\ql \\{\\\\b Safety\\}",
    perl = TRUE
  )
  # Band 2 ("AE", depth 1) -> `\pard\plain\intbl\liN\ql {\b AE}`.
  expect_match(
    rtf,
    "\\\\pard\\\\plain\\\\intbl\\\\li[0-9]+\\\\ql \\{\\\\b AE\\}",
    perl = TRUE
  )
})

# --- header-band rule scope (cmidrule(lr) semantics) ----------------

test_that("RTF scenario G: band cells carry rule; blank flanking cells emit \\brdrnone", {
  rtf <- band_emit("G", "rtf")
  expect_match(rtf, "\\{\\\\b Active Treatment\\}", perl = TRUE)
  # Band cell (drug_50+drug_100 colspan) carries solid bottom border.
  expect_match(rtf, "\\\\clbrdrb\\\\brdrs", perl = TRUE)
  # Blank flanking cells (label+soc_n+placebo and Total) carry
  # \brdrnone on top and bottom.
  expect_match(
    rtf,
    "\\\\clbrdrt\\\\brdrnone\\\\clbrdrb\\\\brdrnone",
    perl = TRUE
  )
})

test_that("cell_padding_h drives RTF \\trgaph horizontal gap (padding SSOT)", {
  # The horizontal cell-padding SSOT preset@cell_padding_h feeds both
  # column-width measurement and the rendered \trgaph, so they agree.
  spec <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding_h = 10)
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "\\\\trgaph200") # 10pt * 20 = 200 twips
})

test_that("RTF renders asymmetric cell_padding_h as its symmetric average", {
  # RTF's \trgaph is one gap; c(left, right) renders as the average
  # (total width still matches measurement). c(4, 8) -> mean 6 -> 120.
  spec <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding_h = c(4, 8))
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "\\\\trgaph120")
})

test_that(".rtf_body_trgaph falls back to 5.4pt default when preset is NULL", {
  # Headless callers (no preset) get the legacy 108-twip default.
  cs <- matrix(list(tabular:::style_node()), nrow = 1L)
  expect_identical(tabular:::.rtf_body_trgaph(cs, preset = NULL), 108L)
})

test_that("repeat_content drops title + header repeat on continuation pages", {
  # Default repeat_content repeats titles + headers on every page;
  # excluding them shows titles + the header band on page 1 only.
  df <- data.frame(
    soc = rep(c("A", "B"), each = 20L),
    val = as.character(seq_len(40L))
  )
  spec <- tabular(df, titles = "Tbl X") |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    preset(orientation = "portrait", font_size = 24) |>
    paginate(repeat_content = character())
  txt <- .rtf_emit_text(spec)
  # Title text appears exactly once (page 1 only), not once per page.
  expect_equal(lengths(regmatches(txt, gregexpr("Tbl X", txt)))[[1L]], 1L)
})

test_that("repeat_content default repeats titles across pages", {
  df <- data.frame(
    soc = rep(c("A", "B"), each = 20L),
    val = as.character(seq_len(40L))
  )
  spec <- tabular(df, titles = "Tbl Y") |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    preset(orientation = "portrait", font_size = 24)
  txt <- .rtf_emit_text(spec)
  # Multi-page table -> title appears on more than one page by default.
  expect_gt(lengths(regmatches(txt, gregexpr("Tbl Y", txt)))[[1L]], 1L)
})

test_that("footnotes are page-anchored in the {\\footer} group, not the body", {
  # Footnotes ride the page footer (pinned to the page bottom) rather
  # than the body, and the bottom margin grows to hold the footer.
  spec <- tabular(
    data.frame(soc = rep(c("A", "B"), each = 20L), val = as.character(1:40)),
    footnotes = "Source: ADSL."
  ) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    preset(orientation = "portrait", font_size = 24)
  txt <- .rtf_emit_text(spec)
  # Footnote text appears inside a {\footer} group.
  expect_match(txt, "\\{\\\\footer[^}]*Source: ADSL")
  # Multi-page table -> footer repeats footnotes on more than one page.
  expect_gt(
    lengths(regmatches(txt, gregexpr("\\{\\\\footer", txt)))[[1L]],
    1L
  )
})

test_that("repeat_content without footnotes shows them on the last page only", {
  spec <- tabular(
    data.frame(soc = rep(c("A", "B"), each = 20L), val = as.character(1:40)),
    footnotes = "Source: ADSL."
  ) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    preset(orientation = "portrait", font_size = 24) |>
    paginate(repeat_content = c("titles", "headers"))
  txt <- .rtf_emit_text(spec)
  # Footnote appears exactly once (last page footer only).
  expect_equal(
    lengths(regmatches(txt, gregexpr("Source: ADSL", txt)))[[1L]],
    1L
  )
})

test_that("RTF backend renders an empty (zero-page) grid with a (no rows) marker", {
  # The zero-page branch (.render_rtf_empty) is defensive: a normal
  # spec always yields >= 1 page, so build a grid then blank its pages.
  g <- as_grid(
    tabular(
      data.frame(x = "a"),
      titles = "Empty Table",
      footnotes = "No data."
    )
  )
  g0 <- S7::set_props(g, pages = list())
  out <- withr::local_tempfile(fileext = ".rtf")
  tabular:::backend_rtf(g0, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "(no rows)", fixed = TRUE)
  expect_match(txt, "Empty Table", fixed = TRUE)
  expect_match(txt, "No data.", fixed = TRUE)
})

test_that("RTF backend emits the continuation marker on pages 2+ when titles do not repeat", {
  spec <- tabular(
    data.frame(soc = rep(c("A", "B"), each = 20L), val = as.character(1:40))
  ) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    preset(orientation = "portrait", font_size = 24) |>
    paginate(
      repeat_content = c("headers", "footnotes"),
      continuation = "(continued)"
    )
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "\\(continued\\)")
})

test_that("RTF backend renders inline sup / sub / code / link markup", {
  # md() markup is preserved on column labels (a data.frame column
  # would strip the class via c()); labels render through the same
  # inline path as every other surface.
  spec <- tabular(data.frame(a = "x", b = "y", c = "z", d = "w")) |>
    cols(
      a = col_spec(label = md("cm^2^")),
      b = col_spec(label = md("H~2~O")),
      c = col_spec(label = md("`ADSL`")),
      d = col_spec(label = md("[ref](https://example.org)"))
    )
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "{\\super ", fixed = TRUE)
  expect_match(txt, "{\\sub ", fixed = TRUE)
  expect_match(txt, "HYPERLINK", fixed = TRUE)
  expect_match(txt, "{\\f1 ", fixed = TRUE) # code -> mono font
})

test_that("RTF backend collects + emits per-cell colours", {
  spec <- tabular(data.frame(x = c("a", "b"))) |>
    style(color = "#FF0000", background = "#00FF00", .at = cells_body())
  txt <- .rtf_emit_text(spec)
  # Colour table + a foreground colour token on the coloured cells.
  expect_match(txt, "\\\\colortbl")
  expect_match(txt, "\\\\cf[0-9]")
})

test_that("RTF backend resolves an explicit multi-font family stack", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(font_family = c("Courier New", "mono"))
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "fmodern|froman|fswiss")
})

test_that("RTF backend honours 2- and 4-length margin shorthand", {
  spec2 <- tabular(data.frame(x = "a")) |> preset(margins = c(1, 0.5))
  spec4 <- tabular(data.frame(x = "a")) |>
    preset(margins = c(1, 0.5, 1.25, 0.75))
  # 2-length c(top/bottom, left/right): left = 0.5in = 720 twips.
  expect_match(.rtf_emit_text(spec2), "\\\\margl720")
  # 4-length c(top, right, bottom, left): bottom = 1.25in = 1800 twips,
  # left = 0.75in = 1080 twips.
  s4 <- .rtf_emit_text(spec4)
  expect_match(s4, "\\\\margb1800")
  expect_match(s4, "\\\\margl1080")
})

test_that("RTF backend renders pagehead + pagefoot bands with page tokens", {
  spec <- tabular(data.frame(x = c("a", "b"))) |>
    preset(
      pagehead = list(
        left = "Protocol: XYZ",
        right = "Page {page} of {npages}"
      ),
      pagefoot = list(left = "Program: t_demo.R")
    )
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "{\\header", fixed = TRUE)
  expect_match(txt, "{\\footer", fixed = TRUE)
  expect_match(txt, "Protocol: XYZ", fixed = TRUE)
  expect_match(txt, "Program: t_demo.R", fixed = TRUE)
})

test_that("RTF backend renders styled multi-level headers with per-column valign", {
  spec <- tabular(data.frame(a = "x", b = "y")) |>
    cols(
      a = col_spec(label = "A", valign = "top"),
      b = col_spec(label = "B", valign = "bottom")
    ) |>
    headers("Treatment Group" = c("a", "b")) |>
    style(bold = TRUE, halign = "center", .at = cells_headers())
  txt <- .rtf_emit_text(spec)
  expect_match(txt, "Treatment Group", fixed = TRUE)
})
