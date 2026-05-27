# backend_html() — self-contained HTML backend.
#
# The backend self-registers at package-load time, so every test
# here can rely on `tabular:::.has_backend("html")` returning TRUE
# without setup.

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("html backend is registered at package load", {
  expect_true(tabular:::.has_backend("html"))
})

# ---------------------------------------------------------------------
# End-to-end via emit()
# ---------------------------------------------------------------------

test_that("emit(.html) writes a non-empty self-contained .html file", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_gt(length(lines), 0L)
  expect_true(any(grepl("^<!DOCTYPE html>", lines)))
  expect_true(any(grepl("<style>", lines, fixed = TRUE)))
  expect_true(any(grepl(
    "<h1 class=\"tabular-title\">T</h1>",
    lines,
    fixed = TRUE
  )))
  expect_true(any(grepl("<table class=\"tabular-table\"", lines)))
  expect_true(any(grepl(
    "<p class=\"tabular-footnote\">F</p>",
    lines,
    fixed = TRUE
  )))
})

test_that("emit(.htm) alias resolves to the html backend", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  out <- withr::local_tempfile(fileext = ".htm")
  emit(spec, out)
  expect_true(file.exists(out))
  expect_true(any(grepl(
    "<table class=\"tabular-table\"",
    readLines(out)
  )))
})

test_that("emit(.html) renders saf_demo golden pipeline end to end", {
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
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl(">Demographics<", lines, fixed = TRUE)))
  expect_true(any(grepl("Placebo<br/>N=86", lines, fixed = TRUE)))
  expect_true(any(grepl(">Source: ADSL.<", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

test_that("titles render as <h1 class=\"tabular-title\"> preserving order", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First", "Second", "Third")
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  headings <- lines[grepl(
    "<h1 class=\"tabular-title\">",
    lines,
    fixed = TRUE
  )]
  expect_identical(
    headings,
    c(
      "<h1 class=\"tabular-title\">First</h1>",
      "<h1 class=\"tabular-title\">Second</h1>",
      "<h1 class=\"tabular-title\">Third</h1>"
    )
  )
})

test_that("footnotes render as <p class=\"tabular-footnote\">", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c("Foot A", "Foot B")
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl(
    "<p class=\"tabular-footnote\">Foot A</p>",
    lines,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "<p class=\"tabular-footnote\">Foot B</p>",
    lines,
    fixed = TRUE
  )))
})

test_that("no titles -> no <h1>; no footnotes -> no .tabular-footnote", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_false(any(grepl(
    "<h1 class=\"tabular-title\">",
    lines,
    fixed = TRUE
  )))
  # `tabular-footnote` appears in the inlined <style> block; the
  # absence we care about is the actual <p ... tabular-footnote> tag.
  expect_false(any(grepl(
    "<p class=\"tabular-footnote\">",
    lines,
    fixed = TRUE
  )))
})

# ---------------------------------------------------------------------
# Inline AST rendering (md() / html() input)
# ---------------------------------------------------------------------

test_that("bold / italic / code marks map to <strong> / <em> / <code>", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
      md("**Bold title**"),
      md("*italic title*"),
      md("`code title`")
    )
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<strong>Bold title</strong>", txt, fixed = TRUE))
  expect_true(grepl("<em>italic title</em>", txt, fixed = TRUE))
  expect_true(grepl("<code>code title</code>", txt, fixed = TRUE))
})

test_that("superscript / subscript / link map to <sup> / <sub> / <a href>", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(
      md("^a^ Marker"),
      md("~sub~ Marker"),
      md("[link](https://example.com)")
    )
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<sup>a</sup>", txt, fixed = TRUE))
  expect_true(grepl("<sub>sub</sub>", txt, fixed = TRUE))
  expect_true(grepl(
    "<a href=\"https://example.com\">link</a>",
    txt,
    fixed = TRUE
  ))
})

test_that("embedded \\n in cell text becomes <br/>", {
  spec <- tabular(
    data.frame(x = "line1\nline2"),
    titles = "T"
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("line1<br/>line2", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# HTML escaping
# ---------------------------------------------------------------------

test_that(".html_escape_cell HTML-escapes and converts \\n / \\r\\n to <br/>", {
  expect_identical(tabular:::.html_escape_cell("a\nb"), "a<br/>b")
  expect_identical(tabular:::.html_escape_cell("a\r\nb"), "a<br/>b")
  expect_identical(tabular:::.html_escape_cell("<&>"), "&lt;&amp;&gt;")
  expect_identical(tabular:::.html_escape_cell(NA_character_), "")
  expect_identical(tabular:::.html_escape_cell(NULL), "")
  expect_identical(tabular:::.html_escape_cell(character()), "")
})

test_that(".html_escape handles &, <, >, \", ' and NA / NULL", {
  expect_identical(tabular:::.html_escape("a & b"), "a &amp; b")
  expect_identical(tabular:::.html_escape("<x>"), "&lt;x&gt;")
  expect_identical(tabular:::.html_escape("\"q\""), "&quot;q&quot;")
  expect_identical(tabular:::.html_escape("'apos'"), "&#39;apos&#39;")
  expect_identical(tabular:::.html_escape(NA_character_), "")
  expect_identical(tabular:::.html_escape(NULL), "")
  expect_identical(tabular:::.html_escape(character()), "")
})

test_that("ampersand and angle brackets in cells escape into entities", {
  spec <- tabular(data.frame(x = "a & <b>"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("a &amp; &lt;b&gt;", txt, fixed = TRUE))
  expect_false(grepl(">a & <b><", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Alignment classes
# ---------------------------------------------------------------------

test_that("alignment classes map every align value to its CSS class", {
  expect_identical(tabular:::.html_align_class("left"), "text-left")
  expect_identical(tabular:::.html_align_class("center"), "text-center")
  expect_identical(tabular:::.html_align_class("right"), "text-right")
  expect_identical(tabular:::.html_align_class("decimal"), "text-right")
  expect_identical(tabular:::.html_align_class(NA_character_), "")
  expect_identical(tabular:::.html_align_class(NULL), "")
  expect_identical(tabular:::.html_align_class("garbage"), "")
})

test_that("col_spec align surfaces as a CSS class on body cells", {
  spec <- tabular(data.frame(L = "x", C = "x", R = "x", D = "x")) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<td class=\"text-left\">x</td>", txt, fixed = TRUE))
  expect_true(grepl("<td class=\"text-center\">x</td>", txt, fixed = TRUE))
  # `text-right` covers both right + decimal
  expect_true(grepl("<td class=\"text-right\">x</td>", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Column widths (<colgroup>)
# ---------------------------------------------------------------------

test_that(".html_colgroup emits one <col> per visible column with resolved widths", {
  cols <- list(
    a = col_spec(width = 1.5),
    b = col_spec(width = 2.25),
    c = col_spec(width = 0.75)
  )
  out <- tabular:::.html_colgroup(c("a", "b", "c"), cols)
  expect_identical(out[[1L]], "<colgroup>")
  expect_identical(out[[length(out)]], "</colgroup>")
  expect_identical(out[[2L]], "<col style=\"width:1.500000in\"/>")
  expect_identical(out[[3L]], "<col style=\"width:2.250000in\"/>")
  expect_identical(out[[4L]], "<col style=\"width:0.750000in\"/>")
})

test_that(".html_colgroup emits a bare <col/> for columns with no col_spec entry", {
  # Defensive path — a visible column without an engine-resolved
  # col_spec (e.g. backend called outside the engine pipeline)
  # still gets a <col/> so the child count matches the visible-
  # column count for any CSS nth-child targeting.
  cols <- list(
    a = col_spec(width = 1.5),
    c = col_spec(width = 2.0)
  )
  out <- tabular:::.html_colgroup(c("a", "b", "c"), cols)
  expect_length(out, 5L)
  expect_identical(out[[2L]], "<col style=\"width:1.500000in\"/>")
  expect_identical(out[[3L]], "<col/>")
  expect_identical(out[[4L]], "<col style=\"width:2.000000in\"/>")
})

test_that(".html_colgroup returns character(0) when no column has a numeric width", {
  # Empty cols (e.g. no col_specs declared and engine resolution
  # skipped — defensive).
  expect_identical(
    tabular:::.html_colgroup(c("a", "b"), list()),
    character()
  )
})

test_that("HTML colgroup omits widths when the user wrote none (gt-style auto)", {
  # Per the gt convention: HTML only emits widths the user
  # explicitly set via `col_spec(width = ...)`. With no widths
  # set, no `<colgroup>` ships -- the browser auto-sizes columns
  # from cell content, and cells wrap responsively when the
  # viewport narrows. This is the "responsive by default"
  # guarantee that fixed the viewer-pane-not-reactive bug.
  spec <- tabular(data.frame(x = "x", y = "y"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  # No colgroup at all -- engine-computed widths must not leak.
  expect_no_match(txt, "<colgroup>", fixed = TRUE)
  expect_no_match(txt, "<col style=\"width:", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Table width — HTML is unconditionally responsive
# ---------------------------------------------------------------------

test_that(".html_table_open_tag is always width:100% regardless of widths or width_mode", {
  # HTML is unconditionally responsive: table always fills 100%
  # of its wrapper. width_mode is paper-backend-only.
  for (mode in c("content", "window", "fixed")) {
    ps <- tabular:::preset_spec(width_mode = mode)
    for (col_specs in list(
      list(col_spec(width = 1.5), col_spec(width = 2.25)),
      list(col_spec(width = "40%"), col_spec(width = "60%")),
      list(NULL, NULL)
    )) {
      tag <- tabular:::.html_table_open_tag(col_specs, ps)
      expect_identical(
        tag,
        "<table class=\"tabular-table\" style=\"width:100%\">",
        info = sprintf("mode = %s", mode)
      )
    }
  }
})

test_that("each <table> is wrapped in <div class=\"tabular-table-wrap\">", {
  spec <- tabular(data.frame(x = c(1L, 2L), y = c("a", "b")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  # one wrap open + one wrap close immediately surrounding the
  # single panel `<table>`.
  expect_identical(
    length(grep("<div class=\"tabular-table-wrap\">", lines, fixed = TRUE)),
    1L
  )
  # wrap closes match wrap opens (single panel here).
  txt <- paste(lines, collapse = "\n")
  opens <- length(gregexpr(
    "<div class=\"tabular-table-wrap\">",
    txt,
    fixed = TRUE
  )[[1L]])
  closes <- length(gregexpr(
    "</table>\n</div>",
    txt,
    fixed = TRUE
  )[[1L]])
  expect_identical(opens, closes)
})

test_that("horizontal panels each get their own scroll wrapper", {
  d <- data.frame(
    grp = c("a", "b"),
    c1 = 1:2,
    c2 = 3:4,
    c3 = 5:6,
    c4 = 7:8
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(panels = 2L)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_identical(
    length(grep("<div class=\"tabular-table-wrap\">", lines, fixed = TRUE)),
    2L
  )
})

test_that("default preset emits an always-responsive <table> end-to-end", {
  # HTML is unconditionally responsive: table always carries the
  # `width:100%` inline style regardless of preset @width_mode or
  # any per-column widths. width_mode drives paper backends only.
  spec <- tabular(
    saf_demo,
    titles = "Demographics",
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
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%\">",
    fixed = TRUE
  )
  # The previous engine-computed inch widths must not recur.
  expect_no_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:[0-9.]+in\">",
    perl = TRUE
  )
})

test_that("width_mode = 'window' preserves the always-100% table emit", {
  # width_mode is paper-backend-only; "window" doesn't change HTML
  # behaviour (HTML is unconditionally 100%).
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b"))
  ) |>
    preset(width_mode = "window")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%\">",
    fixed = TRUE
  )
})

test_that(".tabular-table CSS centres content-fitted tables and renders at preset@font_size", {
  # Default preset: font_size = 9pt. The CSS emits pt-units (not
  # rem / em / %) so the rendered cell width matches what the
  # engine's AFM measurement assumed — `<col>` widths land within
  # a pixel of the actual content box.
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    ".tabular-table { border-collapse: collapse; font-size: 9pt; margin: 0 auto; }",
    fixed = TRUE
  )
})

test_that(".tabular-table font-size tracks preset(font_size = N)", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(font_size = 12)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    ".tabular-table { border-collapse: collapse; font-size: 12pt; margin: 0 auto; }",
    fixed = TRUE
  )
})

test_that(".tabular-title + .tabular-footnote also render at preset@font_size", {
  # Title / footnote share the body's pt size so the preview reads
  # at submission-grade consistency (canonical: title bold, footnote
  # plain, both same pt as body).
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    ".tabular-title { font-size: 9pt; font-weight: 600; text-align: center; margin: .2rem 0; }",
    fixed = TRUE
  )
  expect_match(
    txt,
    ".tabular-footnote { font-size: 9pt; color: #495057; margin: .25rem 0; }",
    fixed = TRUE
  )
})

test_that("preset(font_size = N) cascades to title + footnote rules too", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(font_size = 12)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    ".tabular-title { font-size: 12pt; font-weight: 600; text-align: center; margin: .2rem 0; }",
    fixed = TRUE
  )
  expect_match(
    txt,
    ".tabular-footnote { font-size: 12pt; color: #495057; margin: .25rem 0; }",
    fixed = TRUE
  )
})

test_that("body content sits inside a single <div class=\"tabular-content\"> wrapper", {
  # title + table(s) + footnote share one centred container so the
  # footnote aligns with the table's left edge instead of the page
  # gutter.
  spec <- tabular(
    data.frame(x = 1L),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  # Exactly one wrapper open (no `--window` modifier at the default
  # `width_mode = "content"`).
  expect_identical(
    length(grep("<div class=\"tabular-content\">", lines, fixed = TRUE)),
    1L
  )
  # Wrapper open precedes the title; wrapper close follows the
  # footnote. Both inside the document body.
  i_open <- grep("<div class=\"tabular-content\">", lines, fixed = TRUE)
  i_title <- grep("<h1 class=\"tabular-title\">T</h1>", lines, fixed = TRUE)
  i_foot <- grep("<p class=\"tabular-footnote\">F</p>", lines, fixed = TRUE)
  i_close <- tail(grep("^</div>", lines), 1L)
  expect_true(i_open < i_title)
  expect_true(i_title < i_foot)
  expect_true(i_foot < i_close)
})

test_that("preset(width_mode = 'window') leaves the wrapper at the base .tabular-content (HTML always responsive)", {
  # width_mode is paper-backend-only; on HTML the wrapper is
  # always `.tabular-content` (which itself fills 100% width).
  # The `--window` modifier class no longer exists.
  spec <- tabular(data.frame(x = 1L)) |>
    preset(width_mode = "window")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(txt, "<div class=\"tabular-content\">", fixed = TRUE)
  expect_no_match(
    txt,
    "<div class=\"tabular-content tabular-content--window\">",
    perl = TRUE
  )
})

test_that(".tabular-content CSS rule is present and at width:100% (gt-style unconditional)", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    ".tabular-content { width: 100%; }",
    fixed = TRUE
  )
  # The legacy fit-content / --window modifier rules are gone.
  expect_no_match(txt, "fit-content", perl = TRUE)
  expect_no_match(txt, ".tabular-content--window", perl = TRUE)
})

test_that("empty-input emit still wraps content in .tabular-content", {
  # Zero-row data emits exactly one wrapper too — `total > 0` here
  # because a one-page empty table is still a page, but the wrapper
  # invariant must hold across both the early-return path and the
  # populated path.
  spec <- tabular(
    data.frame(x = integer()),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  expect_identical(
    length(grep("<div class=\"tabular-content\">", lines, fixed = TRUE)),
    1L
  )
})

test_that(".tabular-table-wrap CSS is present and resets under @media print", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  # Screen rule: horizontal scroll fallback for narrow viewports.
  # Margin matches `.tabular-title`'s `.2rem` so the title-pad gap is
  # symmetric above and below the pad (variant α).
  expect_match(
    txt,
    ".tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }",
    fixed = TRUE
  )
  # Print rule: reset to visible overflow so paper output is
  # untouched by the screen-only scroll behaviour.
  expect_match(
    txt,
    ".tabular-table-wrap { overflow-x: visible; margin: 0; }",
    fixed = TRUE
  )
})

test_that("LaTeX / RTF / DOCX widths agree byte-for-byte; HTML is responsive (no inches)", {
  # Engine-resolved widths render identically across the three
  # PAPER backends (LaTeX / RTF / DOCX). HTML opts out of the
  # inch-width path entirely per the gt convention -- it's
  # unconditionally responsive (no `<col style="width:Xin">`,
  # no `<table style="width:Yin">`). HTML's responsive emit is
  # asserted separately by `'HTML <table> is always width:100%'`
  # and `'HTML colgroup omits widths when user wrote none'`.
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    preset(orientation = "portrait") |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    )
  html_file <- withr::local_tempfile(fileext = ".html")
  tex_file <- withr::local_tempfile(fileext = ".tex")
  rtf_file <- withr::local_tempfile(fileext = ".rtf")
  docx_file <- withr::local_tempfile(fileext = ".docx")
  emit(spec, html_file)
  emit(spec, tex_file)
  emit(spec, rtf_file)
  emit(spec, docx_file)

  html_txt <- paste(readLines(html_file), collapse = "\n")
  tex_txt <- paste(readLines(tex_file), collapse = "\n")
  rtf_txt <- paste(readLines(rtf_file), collapse = "\n")
  docx_td <- withr::local_tempdir()
  utils::unzip(docx_file, files = "word/document.xml", exdir = docx_td)
  docx_txt <- paste(
    readLines(file.path(docx_td, "word/document.xml")),
    collapse = "\n"
  )

  # HTML: responsive, no inch widths anywhere.
  expect_no_match(
    html_txt,
    "<col style=\"width:[0-9.]+in\"/>",
    perl = TRUE
  )
  expect_no_match(
    html_txt,
    "<table[^>]*style=\"width:[0-9.]+in\"",
    perl = TRUE
  )

  # Paper-backend parity (LaTeX float vs RTF/DOCX twips).
  tex_in <- as.numeric(regmatches(
    tex_txt,
    gregexpr("(?<=wd=)[0-9.]+(?=in)", tex_txt, perl = TRUE)
  )[[1L]])
  rtf_cellx <- as.integer(regmatches(
    rtf_txt,
    gregexpr("(?<=\\\\cellx)[0-9]+", rtf_txt, perl = TRUE)
  )[[1L]])
  ncol_vis <- length(tex_in)
  rtf_in <- diff(c(0L, rtf_cellx[seq_len(ncol_vis)])) / 1440
  docx_tw <- as.integer(regmatches(
    docx_txt,
    gregexpr("(?<=<w:gridCol w:w=\")[0-9]+(?=\"/>)", docx_txt, perl = TRUE)
  )[[1L]])
  docx_in <- docx_tw / 1440

  expect_gt(length(tex_in), 0L)
  # RTF and DOCX both snap to integer twips at cumulative
  # boundaries so they are byte-for-byte identical as twip vectors.
  expect_identical(round(rtf_in * 1440), round(docx_in * 1440))
  # LaTeX (float-inch) agrees with RTF/DOCX to the twip granularity.
  expect_true(all(abs(tex_in - docx_in) <= 1 / 1440))
})

# ---------------------------------------------------------------------
# Multi-level headers (real HTML colspan)
# ---------------------------------------------------------------------

test_that("header band labels emit as <th colspan=\"N\"> above the column-labels row", {
  spec <- tabular(
    data.frame(
      grp = "x",
      placebo = "1",
      active_low = "2",
      active_high = "3"
    )
  ) |>
    headers("Treatment Arm" = c("placebo", "active_low", "active_high"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl(
    "<th colspan=\"3\" class=\"tabular-band\">Treatment Arm</th>",
    txt,
    fixed = TRUE
  ))
  # The leftmost unbanded column emits an empty <th colspan="1">.
  expect_true(grepl("<th colspan=\"1\"></th>", txt, fixed = TRUE))
  # Band row must come before the column-labels row (look for `grp`
  # column label coming after the band line).
  band_pos <- regexpr("Treatment Arm", txt, fixed = TRUE)
  label_pos <- regexpr(">grp<", txt, fixed = TRUE)
  expect_lt(band_pos, label_pos)
})

test_that(".group_contiguous_runs preserves order and handles NA", {
  out <- tabular:::.group_contiguous_runs(c("A", "A", NA, NA, "B"))
  expect_length(out, 3L)
  expect_identical(out[[1L]], list(value = "A", length = 2L))
  expect_true(is.na(out[[2L]]$value))
  expect_identical(out[[2L]]$length, 2L)
  expect_identical(out[[3L]], list(value = "B", length = 1L))
})

test_that(".group_contiguous_runs handles single-element and empty inputs", {
  expect_identical(tabular:::.group_contiguous_runs(character()), list())
  expect_identical(
    tabular:::.group_contiguous_runs("only"),
    list(list(value = "only", length = 1L))
  )
})

# ---------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------

test_that("multi-page emit produces a single continuous table with print-only page-break rows", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  txt <- paste(lines, collapse = "\n")
  # Exactly one continuous <table> / <thead> / <tbody>. Per gt
  # convention, no <colgroup> is emitted when the user wrote no
  # per-column widths (browser auto-sizes responsively).
  expect_identical(
    length(grep("<table class=\"tabular-table\"", lines)),
    1L
  )
  expect_identical(
    length(grep("<colgroup>", lines, fixed = TRUE)),
    0L
  )
  expect_identical(length(grep("<thead>", lines, fixed = TRUE)), 1L)
  expect_identical(length(grep("<tbody>", lines, fixed = TRUE)), 1L)
  # One or more invisible page-break rows between vertical pages.
  break_rows <- length(grep(
    "<tr class=\"tabular-page-break-row\"",
    lines,
    fixed = TRUE
  ))
  expect_gt(break_rows, 0L)
  # No per-page section wrappers, no <hr> separator, no page-N comment.
  expect_false(any(grepl(
    "<section class=\"tabular-page\">",
    lines,
    fixed = TRUE
  )))
  expect_false(grepl(
    "<hr class=\"tabular-page-break\"/>",
    txt,
    fixed = TRUE
  ))
  expect_false(any(grepl("<!-- page 2", lines, fixed = TRUE)))
})

test_that("continuation marker is a no-op for HTML output", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp", continuation = "(continued)") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_false(grepl("tabular-continuation", txt, fixed = TRUE))
  expect_false(grepl("(continued)", txt, fixed = TRUE))
})

test_that("horizontal panels emit one <table> per panel with its own <thead>", {
  d <- data.frame(
    grp = c("a", "b"),
    c1 = 1:2,
    c2 = 3:4,
    c3 = 5:6,
    c4 = 7:8
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(panels = 2L)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  txt <- paste(lines, collapse = "\n")
  # Two `<table>` blocks (one per panel), each with its own
  # `<thead>` and `<tbody>`.
  expect_identical(
    length(grep("<table class=\"tabular-table\"", lines)),
    2L
  )
  expect_identical(length(grep("<thead>", lines, fixed = TRUE)), 2L)
  expect_identical(length(grep("<tbody>", lines, fixed = TRUE)), 2L)
  # No `<section>` wrapper between panels — natural stacking.
  expect_false(any(grepl(
    "<section class=\"tabular-page\">",
    lines,
    fixed = TRUE
  )))
  # `@media print` carries the panel page-break rule.
  expect_true(grepl(
    ".tabular-table + .tabular-table { page-break-before: always",
    txt,
    fixed = TRUE
  ))
})

test_that(".tabular-page-break-row CSS hides on screen and breaks pages in print", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl(
    ".tabular-page-break-row { display: none; }",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl(
    ".tabular-page-break-row { display: table-row; page-break-before: always",
    txt,
    fixed = TRUE
  ))
})

test_that("removed CSS rules and elements do not appear", {
  spec <- tabular(data.frame(x = 1L), titles = "T", footnotes = "F")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  # Removed CSS rules
  expect_false(grepl(".tabular-page { margin-bottom", txt, fixed = TRUE))
  expect_false(grepl(
    ".tabular-page-break { border:",
    txt,
    fixed = TRUE
  ))
  expect_false(grepl(".tabular-continuation", txt, fixed = TRUE))
  # Removed DOM elements
  expect_false(grepl("<section class=\"tabular-page\"", txt, fixed = TRUE))
  expect_false(grepl(
    "<hr class=\"tabular-page-break\"/>",
    txt,
    fixed = TRUE
  ))
})

# ---------------------------------------------------------------------
# Targeted helper coverage — border / valign / chrome counters / link
# (these helpers exist in `backend_html.R` but were only weakly exercised
# by the existing tests; explicit coverage keeps them above the 95%
# coverage gate without leaning on integration paths)
# ---------------------------------------------------------------------

test_that(".html_border_decl maps style triples to border-<side> declarations", {
  brd <- list(style = "solid", width = 1, color = "#000")
  expect_identical(
    tabular:::.html_border_decl("top", brd),
    "border-top: 1pt solid #000;"
  )
  brd2 <- list(style = "dashed", width = 2, color = "red")
  expect_identical(
    tabular:::.html_border_decl("bottom", brd2),
    "border-bottom: 2pt dashed red;"
  )
  brd3 <- list(style = "dashdot", width = 1, color = "blue")
  expect_match(
    tabular:::.html_border_decl("left", brd3),
    "dashed",
    fixed = TRUE
  )
  # `none` style yields NULL
  expect_null(tabular:::.html_border_decl(
    "top",
    list(style = "none", width = 1, color = "#000")
  ))
  expect_null(tabular:::.html_border_decl("top", NULL))
})

test_that(".html_valign_class maps every valign value to its CSS class", {
  expect_identical(tabular:::.html_valign_class("top"), "valign-top")
  expect_identical(tabular:::.html_valign_class("middle"), "valign-middle")
  expect_identical(tabular:::.html_valign_class("bottom"), "valign-bottom")
  expect_identical(tabular:::.html_valign_class(NA_character_), "")
  expect_identical(tabular:::.html_valign_class(NULL), "")
  expect_identical(tabular:::.html_valign_class("garbage"), "")
})

test_that("cell border styling surfaces as inline style attribute on <td>", {
  template <- style_template() |>
    style(
      .at = cells_body(i = 1L),
      border_top = brdr(style = "solid", width = 1, color = "#cc0000")
    )
  spec <- tabular(data.frame(x = 1:3)) |> preset(.style = template)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "border-top: 1pt solid #cc0000", fixed = TRUE)
})

test_that("link without title emits the no-title <a href> branch", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = md("[link](https://example.com)")
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(
    html,
    "<a href=\"https://example.com\">link</a>",
    fixed = TRUE
  )
})

test_that("pagehead chrome with {page}/{npages} renders text + counter substitution", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # On-screen header substitutes {page} -> 1, {npages} -> 1.
  expect_match(html, "Page 1 of 1", fixed = TRUE)
  # @page rules carry CSS counter calls.
  expect_match(html, "counter(page)", fixed = TRUE)
  expect_match(html, "counter(pages)", fixed = TRUE)
})

test_that("subgroup banner row emits inline inside the single <tbody>", {
  d <- data.frame(
    g = c("A", "A", "B", "B"),
    x = 1:4
  )
  spec <- tabular(d) |> subgroup("g")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  lines <- readLines(out)
  txt <- paste(lines, collapse = "\n")
  # Each subgroup partition produces its own grid; emit handles the
  # first partition by default. The body must carry a banner <tr>.
  expect_true(grepl("tabular-subgroup", txt, fixed = TRUE))
  # The single-<tbody> contract still holds.
  expect_identical(length(grep("<tbody>", lines, fixed = TRUE)), 1L)
})

# ---------------------------------------------------------------------
# Edge: zero-row data + empty grid
# ---------------------------------------------------------------------

test_that("empty grid renders titles + (no rows) marker + footnotes", {
  fake <- tabular_grid(
    pages = list(),
    metadata = list(
      titles_ast = list(parse_inline("Title")),
      footnotes_ast = list(parse_inline("Foot"))
    )
  )
  lines <- tabular:::.render_html_grid(fake)
  expect_true(any(grepl(">Title<", lines, fixed = TRUE)))
  expect_true(any(grepl(">Foot<", lines, fixed = TRUE)))
  expect_true(any(grepl(">(no rows)<", lines, fixed = TRUE)))
  expect_false(any(grepl("<section", lines, fixed = TRUE)))
})

test_that("zero-row spec renders <thead> with no <tbody> rows", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<thead>", txt, fixed = TRUE))
  expect_true(grepl(">x</th>", txt, fixed = TRUE))
  expect_true(grepl("<tbody>", txt, fixed = TRUE))
  # No <tr> inside <tbody>.
  tbody_chunk <- regmatches(
    txt,
    regexpr("(?s)<tbody>.*?</tbody>", txt, perl = TRUE)
  )
  expect_false(grepl("<tr>", tbody_chunk, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Renderer fallbacks
# ---------------------------------------------------------------------

test_that(".render_html_inline returns '' on non-inline_ast input", {
  expect_identical(tabular:::.render_html_inline("not an ast"), "")
})

test_that(".render_html_run falls through to (escaped) text for unknown types", {
  fake_run <- list(type = "totally_unknown_type", text = "fall<back>")
  expect_identical(
    tabular:::.render_html_run(fake_run),
    "fall&lt;back&gt;"
  )
})

test_that(".render_html_run handles span (wraps children in <span>)", {
  ast <- parse_inline(html("<span style='color:red'>red</span>"))
  expect_identical(
    tabular:::.render_html_inline(ast),
    "<span>red</span>"
  )
})

test_that(".render_html_children returns '' on empty children list", {
  expect_identical(tabular:::.render_html_children(list()), "")
})

test_that(".render_html_col_labels_row falls back to column name on missing AST", {
  out <- tabular:::.render_html_col_labels_row(
    col_labels_ast = list(),
    col_names_visible = c("x", "y"),
    cols = list()
  )
  expect_identical(out, "<tr><th>x</th><th>y</th></tr>")
})

test_that(".render_html_link emits the title attribute when set", {
  run <- list(
    type = "link",
    href = "https://x.com",
    title = "Tip",
    children = list(list(type = "plain", text = "hi"))
  )
  expect_identical(
    tabular:::.render_html_link(run),
    "<a href=\"https://x.com\" title=\"Tip\">hi</a>"
  )
})

test_that(".html_doc_title falls back to 'tabular' when no titles", {
  expect_identical(tabular:::.html_doc_title(list()), "tabular")
  expect_identical(
    tabular:::.html_doc_title(list(titles_ast = list())),
    "tabular"
  )
})

test_that(".html_doc_title strips tags and entities from the first title", {
  meta <- list(titles_ast = list(parse_inline(md("**Bold &amp; Big**"))))
  out <- tabular:::.html_doc_title(meta)
  expect_false(grepl("<", out, fixed = TRUE))
  expect_false(grepl("&", out, fixed = TRUE))
})

test_that("backend_html() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".html")
  tabular:::backend_html(grid, out)
  expect_true(file.exists(out))
  expect_true(any(grepl(">T<", readLines(out), fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline
# ---------------------------------------------------------------------

test_that("saf_demo golden pipeline matches the pinned .html snapshot", {
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
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  expect_snapshot_file(out, "saf_demo_golden.html")
})

# ---------------------------------------------------------------------
# Page bands — @page margin-box rules
# ---------------------------------------------------------------------

test_that("empty pagehead / pagefoot emits no @page rules", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("@page", html, fixed = TRUE))
})

# ---- On-screen chrome (<header> / <footer>) ------------------------

test_that("populated pagehead emits on-screen <header> band", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: XYZ",
        center = "Draft",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    "<header class=\"tabular-page-header\">",
    html,
    fixed = TRUE
  ))
  expect_true(grepl("Protocol: XYZ", html, fixed = TRUE))
  expect_true(grepl("Page 1 of 1", html, fixed = TRUE))
  # @page rules still emitted for print parity.
  expect_true(grepl("@page", html, fixed = TRUE))
})

test_that("populated pagefoot emits on-screen <footer> band", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagefoot = list(left = "Footer left", right = "Footer right"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    "<footer class=\"tabular-page-footer\">",
    html,
    fixed = TRUE
  ))
  expect_true(grepl("Footer left", html, fixed = TRUE))
  expect_true(grepl("Footer right", html, fixed = TRUE))
})

test_that("chrome_onscreen = 'off' suppresses on-screen bands but keeps @page", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(left = "Protocol: XYZ"),
      chrome_onscreen = "off"
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl(
    "<header class=\"tabular-page-header\">",
    html,
    fixed = TRUE
  ))
  # @page rules still emitted for print parity.
  expect_true(grepl("@page", html, fixed = TRUE))
  expect_true(grepl("@top-left", html, fixed = TRUE))
})

test_that("CSS custom properties emitted in inline stylesheet", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("--tabular-border-color", html, fixed = TRUE))
  expect_true(grepl("--tabular-border-color-muted", html, fixed = TRUE))
})

test_that("populated pagehead emits @page top-* rules in REVERSE row order", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = c("Body edge", "Far row"),
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("@page", html, fixed = TRUE))
  expect_true(grepl("@top-left", html, fixed = TRUE))
  expect_true(grepl("@top-right", html, fixed = TRUE))
  # Reverse order: "Far row" appears before "Body edge" in the
  # @top-left content string (so visually "Body edge" ends up at
  # the bottom of the header zone, closest to the table).
  m <- regmatches(
    html,
    regexpr(
      "@top-left \\{ content: [^;]+; \\}",
      html
    )
  )
  expect_true(grepl("Far row", m, fixed = TRUE))
  expect_true(grepl("Body edge", m, fixed = TRUE))
  expect_lt(regexpr("Far row", m), regexpr("Body edge", m))
})

test_that("populated pagefoot emits @page bottom-* rules in FORWARD row order", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(left = c("Body edge", "Far row"))
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("@bottom-left", html, fixed = TRUE))
  m <- regmatches(
    html,
    regexpr(
      "@bottom-left \\{ content: [^;]+; \\}",
      html
    )
  )
  # Forward order: "Body edge" first, "Far row" second.
  expect_lt(regexpr("Body edge", m), regexpr("Far row", m))
})

test_that("{page} / {npages} become counter(page) / counter(pages)", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(pagehead = list(right = "Page {page} of {npages}"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("counter(page)", html, fixed = TRUE))
  expect_true(grepl("counter(pages)", html, fixed = TRUE))
})

# ---------------------------------------------------------------------
# chrome_style cascade — `style_template() |> style(.at = cells_*())`
# must reach the HTML output. Tests target the inline-style attribute
# emitted on the surface element.
# ---------------------------------------------------------------------

test_that("style(.at = cells_headers(), color = ...) emits inline color on header band cells", {
  template <- style_template() |>
    style(.at = cells_headers(), color = "#cc0000")
  spec <- tabular(data.frame(x = 1:2)) |>
    preset(.style = template)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "color: #cc0000", fixed = TRUE)
})

test_that("style(.at = cells_title(), halign = 'left') drives title h1 alignment", {
  template <- style_template() |>
    style(.at = cells_title(), halign = "left")
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demographics"
  ) |>
    preset(.style = template)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # The title h1 picks up the left-alignment class.
  expect_match(html, "tabular-title.*text-left.*Demographics", fixed = FALSE)
})

test_that("style(.at = cells_footnotes(), italic = TRUE) puts inline font-style on footnote", {
  template <- style_template() |>
    style(.at = cells_footnotes(), italic = TRUE)
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = "Source: ADSL"
  ) |>
    preset(.style = template)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "font-style: italic", fixed = TRUE)
})

test_that("style(.at = cells_title(), blank_above = 3) emits three pad paragraphs", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  pad_count <- length(gregexpr("tabular-pad", html, fixed = TRUE)[[1]])
  expect_gte(pad_count, 3L)
})

# ---------------------------------------------------------------------
# CSS scoping — body-level rules must bind to `.tabular-doc`, not the
# host page's <body>. Tabular fragments embed into Quarto chunks,
# Shiny UIs, pkgdown reference pages, and htmltools viewer-pane
# wrappers; a bare `body { ... }` selector would rewrite the host's
# font-family / color / margin.
# ---------------------------------------------------------------------

test_that(".html_inline_style scopes body-level rules to .tabular-doc", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  payload <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # No top-level `body { ... }` rule — tabular fragments must not
  # mutate the host page's body styling when embedded.
  expect_false(grepl("\\bbody\\s*\\{", payload, perl = TRUE))

  # The scoped rule is present.
  expect_match(
    payload,
    "\\.tabular-doc\\s*\\{[^}]*font-family",
    perl = TRUE
  )

  # The full-document body carries the scoping class.
  expect_match(payload, "<body class=\"tabular-doc\">", fixed = TRUE)
})

test_that("as.tags.tabular_spec wrapping div carries .tabular-doc class", {
  spec <- tabular(data.frame(x = 1:3))
  rendered <- htmltools::renderTags(htmltools::as.tags(spec))$html

  # No top-level `body { ... }` rule reaches the embedded fragment.
  expect_false(grepl("\\bbody\\s*\\{", rendered, perl = TRUE))

  # Wrapping div has the scoping class.
  expect_match(rendered, "class=\"tabular-doc\"", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Regression: title-block padding paragraph margin
#
# Bug: `<p class="tabular-pad">&nbsp;</p>` spacers around the title
# block had no CSS rule, so the browser default `<p>` margin (16px 0)
# applied -- stacking with the &nbsp; line-height to ~48 px per spacer.
# Fix zeroes the pad margin so each `<p class="tabular-pad">` collapses
# to exactly one preset-driven line of height.
# ---------------------------------------------------------------------

test_that(".tabular-pad has margin: 0 so title spacer is one line tall", {
  spec <- tabular(data.frame(x = 1L), titles = "Demo")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # CSS rule is present in the inline stylesheet.
  expect_match(
    html,
    "\\.tabular-pad\\s*\\{[^}]*margin:\\s*0",
    perl = TRUE
  )

  # The spacer paragraph still emits (preset blank-line count drives
  # how many appear); only its margin is collapsed.
  expect_match(html, "<p class=\"tabular-pad\">&nbsp;</p>", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Regression: visible indent on `indent_by` columns in HTML
#
# Bug: the engine prepends `preset@indent_size` spaces per depth level
# to cell text, but browsers collapse runs of leading whitespace inside
# `<td>` -- so the indent was invisible. Fix: HTML backend strips the
# engine prefix and re-expresses the indent as CSS `padding-left`.
# ---------------------------------------------------------------------

test_that("HTML indent_by cells emit padding-left and strip engine prefix", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c("CARDIAC", "Atrial fib", "GI", "Nausea"),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Category", indent_by = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # PT rows: padding-left present at depth-1, text de-prefixed. The
  # value is AFM-derived from the default body font (Liberation Mono
  # / Courier): "  " is 1200/1000-em -> 1.2em per depth level. The
  # CSS `calc(.6rem + 1.2em)` is ADDITIVE over the baseline
  # `.tabular-table td { padding: .35rem .6rem }` left slot so the
  # PT cell sits a full 1.2em beyond the SOC cell (not just
  # 1.2em - .6rem). `%g` format trims trailing zeros.
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Atrial fib</td>",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Nausea</td>",
    txt,
    fixed = TRUE
  ))

  # Bug condition (engine prefix surviving into the rendered cell)
  # must NOT recur.
  expect_false(grepl("<td>  Atrial fib", txt, fixed = TRUE))
  expect_false(grepl("<td>  Nausea", txt, fixed = TRUE))

  # Depth-0 rows do NOT get a padding-left style.
  expect_true(grepl("<td>CARDIAC</td>", txt, fixed = TRUE))
  expect_true(grepl("<td>GI</td>", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Regression: title-pad vertical symmetry
#
# Bug: the gap below the title's <p class="tabular-pad"> was visibly
# larger than the gap above it, because `.tabular-table-wrap` had a
# `.75rem` top margin while `.tabular-title` had only a `.2rem` bottom
# margin. Symmetry-around-the-pad requires `wrap.margin-top ==
# title.margin-bottom`, and the user constraint requires `wrap.margin-
# top == wrap.margin-bottom`. Variant α picks `.2rem` for all three.
# ---------------------------------------------------------------------

test_that(".tabular-table-wrap top + bottom margins are symmetric (variant α)", {
  spec <- tabular(data.frame(x = 1L), titles = "Demo")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Symmetric wrap margins (user constraint).
  expect_match(
    html,
    "\\.tabular-table-wrap \\{ overflow-x: auto; margin: \\.2rem 0; \\}",
    perl = TRUE
  )

  # Wrap top margin equals title bottom margin -> gap above and below
  # the title-pad is identical.
  expect_match(
    html,
    "\\.tabular-title \\{[^}]*margin:\\s*\\.2rem 0",
    perl = TRUE
  )

  # The old asymmetric .75rem top must not be re-emerging.
  expect_false(grepl(
    ".tabular-table-wrap { overflow-x: auto; margin: .75rem 0; }",
    html,
    fixed = TRUE
  ))
})

# ---------------------------------------------------------------------
# Regression: AFM-true padding-left for indented cells
#
# Bug: padding-left was hardcoded to `depth × 1.5em` — accurate for no
# font in particular. Fix: read the AFM glyph-advance width of
# `strrep(" ", preset@indent_size)` for the active body font and use
# that as the per-level em unit. Liberation Mono / Courier:
# space = 600/1000 em, so `indent_size = 2L` at depth 1 = 1.2em (not
# 1.5em). Helvetica: space = 278/1000 em, so the same at depth 1 is
# ~0.556em.
# ---------------------------------------------------------------------

test_that("indent padding-left is AFM-derived per preset font", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c("CARDIAC", "Atrial fib", "GI", "Nausea"),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  make_spec <- function(font_family) {
    tabular(df, titles = "AE") |>
      preset(font_family = font_family) |>
      cols(
        soc = col_spec(usage = "group", group_display = "header_row"),
        label = col_spec(label = "Category", indent_by = "indent_level"),
        indent_level = col_spec(visible = FALSE),
        row_type = col_spec(visible = FALSE),
        n = col_spec(label = "N")
      )
  }

  # Courier: "  " is 1200/1000-em -> 1.2em at depth 1, additive
  # over the baseline `.6rem` cell pad.
  out <- withr::local_tempfile(fileext = ".html")
  emit(make_spec("Courier"), out)
  txt_courier <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(
    txt_courier,
    "<td style=\"padding-left: calc\\(\\.6rem \\+ 1\\.2em\\);\">Atrial fib</td>",
    perl = TRUE
  )

  # Helvetica: "  " is 556/1000-em -> 0.556em at depth 1.
  out2 <- withr::local_tempfile(fileext = ".html")
  emit(make_spec("Helvetica"), out2)
  txt_helv <- paste(readLines(out2, warn = FALSE), collapse = "\n")
  expect_match(
    txt_helv,
    "<td style=\"padding-left: calc\\(\\.6rem \\+ 0\\.556em\\);\">Atrial fib</td>",
    perl = TRUE
  )

  # The old hardcoded 1.50em and the non-additive 1.2000em are
  # both gone from both renderings.
  expect_false(grepl("padding-left: 1.50em", txt_courier, fixed = TRUE))
  expect_false(grepl("padding-left: 1.50em", txt_helv, fixed = TRUE))
  expect_false(grepl("padding-left: 1.2000em", txt_courier, fixed = TRUE))
  expect_false(grepl("padding-left: 0.5560em", txt_helv, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Regression: header alignment via col_spec(align = ...) on <th>
#
# Bug: the baseline `.tabular-table thead th { text-align: center }`
# (specificity 0,1,2) was overriding the per-cell `.text-left` /
# `.text-right` classes (specificity 0,1,0) — so every `<th>` rendered
# centered regardless of what `col_spec.align` said. Fix:
#   (3a) Add `.tabular-table thead th.text-*` rules to bump specificity
#        to (0,2,2) so per-cell classes win.
#   (3b) Change the header-side projection for `decimal` from "right"
#        to "center" — decimal-aligned body has its visual centroid
#        around the decimal point, so the header centers (TFL
#        convention).
# ---------------------------------------------------------------------

test_that("col_spec(align) routes through to <th> per the convention rule", {
  df <- data.frame(
    L = "left body",
    C = "center body",
    R = "right body",
    D = "1.23",
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      L = col_spec(label = "L", align = "left"),
      C = col_spec(label = "C", align = "center"),
      R = col_spec(label = "R", align = "right"),
      D = col_spec(label = "D", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Specificity-bump CSS rules exist.
  expect_match(
    txt,
    "\\.tabular-table thead th\\.text-left\\s*\\{[^}]*text-align:\\s*left",
    perl = TRUE
  )
  expect_match(
    txt,
    "\\.tabular-table thead th\\.text-center\\s*\\{[^}]*text-align:\\s*center",
    perl = TRUE
  )
  expect_match(
    txt,
    "\\.tabular-table thead th\\.text-right\\s*\\{[^}]*text-align:\\s*right",
    perl = TRUE
  )

  # Header <th> classes match the rule table. The cells are emitted in
  # column order; pull each <th class="..."> by its label text.
  thead <- regmatches(txt, regexpr("<thead>.*?</thead>", txt))
  expect_match(thead, "<th[^>]*class=\"text-left[^\"]*\"[^>]*>L</th>")
  expect_match(thead, "<th[^>]*class=\"text-center[^\"]*\"[^>]*>C</th>")
  expect_match(thead, "<th[^>]*class=\"text-right[^\"]*\"[^>]*>R</th>")
  # decimal projects to CENTER on the header (clinical-TFL centroid
  # convention; matches gt's default for numeric columns). The body
  # cells are right-aligned with engine_decimal NBSP padding; the
  # visible content's centre of mass sits inside the cell, not at
  # the right edge. Centered header sits over that centroid.
  expect_match(thead, "<th[^>]*class=\"text-center[^\"]*\"[^>]*>D</th>")
  expect_no_match(thead, "<th[^>]*class=\"text-right[^\"]*\"[^>]*>D</th>")
})

# ---------------------------------------------------------------------
# Regression: indent padding-left is ADDITIVE over the baseline cell
# pad, and emits with `%g`-trimmed format (no trailing zeros).
#
# Bug: `padding-left: 1.2000em` REPLACED the `.tabular-table td
# { padding: .35rem .6rem }` left slot, so a PT cell visually sat
# only `1.2em - .6rem` (~4.8px in 12px Courier) further right than
# its parent SOC cell -- sub-character, basically invisible. Fix:
# emit `padding-left: calc(.6rem + Xem)` so the AFM-derived indent
# ADDS to the baseline. Also switch `%.4f` -> `%g` to strip noise.
# ---------------------------------------------------------------------

test_that("indent padding-left is additive via calc + uses %g format", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c("CARDIAC", "Atrial fib", "GI", "Nausea"),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    preset(font_family = "Courier") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Category", indent_by = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # PT cells now ADD the AFM indent on top of the baseline `.6rem`
  # left pad. `%g` trims trailing zeros: `1.2em`, not `1.2000em`.
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Atrial fib</td>",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Nausea</td>",
    txt,
    fixed = TRUE
  ))

  # The non-additive hardcoded variants must NOT recur.
  expect_false(grepl("padding-left: 1.2000em", txt, fixed = TRUE))
  expect_false(grepl("padding-left: 1.2em;\"", txt, fixed = TRUE))

  # Depth-0 SOC cells carry NO padding-left override (baseline wins).
  expect_true(grepl("<td>CARDIAC</td>", txt, fixed = TRUE))
  expect_true(grepl("<td>GI</td>", txt, fixed = TRUE))
})

test_that("indent calc trims trailing zeros for proportional fonts too", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC"),
    label = c("CARDIAC", "Atrial fib"),
    row_type = c("soc", "pt"),
    indent_level = c(0L, 1L),
    n = c(5L, 3L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    preset(font_family = "Helvetica") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Category", indent_by = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Helvetica space = 556/1000em -> `0.556em` per depth (NOT 0.5560).
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 0.556em);\">Atrial fib</td>",
    txt,
    fixed = TRUE
  ))
  expect_false(grepl("0.5560em", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Regression: width_user S7 property preserves the user's width spec
# through the engine pipeline.
#
# Bug: `.resolve_col_widths()` (R/col_width.R:240) mutates `col@width`
# from the user's string ("40%") to inch-resolved numeric via
# `S7::set_props()`, so by HTML emit time the percent intent is gone
# and `<col style="width:40%"/>` can never land. Fix: add a parallel
# S7 property `width_user` on `col_spec` that mirrors the constructor
# input and is never touched by resolve. HTML reads `width_user`;
# paper backends keep reading `width` (inch-resolved).
# ---------------------------------------------------------------------

test_that("col_spec.width_user survives .resolve_col_widths mutation", {
  spec <- tabular(data.frame(a = 1, b = 2)) |>
    cols(
      a = col_spec(width = "40%"),
      b = col_spec(width = "60%")
    )
  g <- as_grid(spec)
  cols_post <- g@metadata$cols
  # `width` is now numeric inches (engine resolved).
  expect_type(cols_post$a@width, "double")
  expect_type(cols_post$b@width, "double")
  # `width_user` retains the user's original string.
  expect_identical(cols_post$a@width_user, "40%")
  expect_identical(cols_post$b@width_user, "60%")
})

# ---------------------------------------------------------------------
# Regression: percent col widths trigger gt-style responsive layout.
#
# Bug: `col_spec(width = "X%")` was silently converted to inches by
# `.distribute_widths()`, so the rendered HTML was locked to fixed
# pixel widths and couldn't wrap or shrink with the viewport. Fix:
# HTML emit reads `col@width_user`; when any visible column is a
# percent, emit verbatim `<col style="width:X%"/>`, set table
# `width:100%`, and auto-promote the wrapper to the `--window`
# modifier (which the existing CSS already drives to 100% wide).
# ---------------------------------------------------------------------

test_that("percent widths emit verbatim in colgroup + always-100% table + plain wrapper", {
  spec <- tabular(data.frame(a = 1, b = 2)) |>
    cols(
      a = col_spec(width = "40%"),
      b = col_spec(width = "60%")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # <col> widths emit verbatim as percentages (gt convention).
  expect_match(txt, "<col style=\"width:40%\"/>", fixed = TRUE)
  expect_match(txt, "<col style=\"width:60%\"/>", fixed = TRUE)
  # No inch-resolved widths leak into the <colgroup>.
  expect_no_match(txt, "<col style=\"width:[0-9.]+in\"/>", perl = TRUE)

  # Table is always 100%, regardless of column units.
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%\">",
    fixed = TRUE
  )
  # Wrapper is always plain `.tabular-content` (no --window).
  expect_match(txt, "<div class=\"tabular-content\">", fixed = TRUE)
  expect_no_match(
    txt,
    "<div class=\"tabular-content tabular-content--window\">",
    perl = TRUE
  )
})

test_that("inch widths emit verbatim in HTML per gt convention", {
  # CSS supports `in` natively; HTML emits whatever the user wrote.
  # Same gt-style pass-through as percent / px / pt / cm / mm.
  spec <- tabular(data.frame(a = 1, b = 2)) |>
    cols(
      a = col_spec(width = "2.5in"),
      b = col_spec(width = "3.0in")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # User's inch values land in the <col> verbatim.
  expect_match(txt, "<col style=\"width:2.5in\"/>", fixed = TRUE)
  expect_match(txt, "<col style=\"width:3.0in\"/>", fixed = TRUE)
  # Table is always 100% (the old sum-of-inches `width:5.5in` is gone).
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%\">",
    fixed = TRUE
  )
  expect_no_match(
    txt,
    "<table[^>]*style=\"width:[0-9.]+in\"",
    perl = TRUE
  )
  # Wrapper plain (no --window modifier).
  expect_match(txt, "<div class=\"tabular-content\">", fixed = TRUE)
  expect_no_match(
    txt,
    "<div class=\"tabular-content tabular-content--window\">",
    perl = TRUE
  )
})

test_that("percent widths flow through to LaTeX as resolved INCHES, not %", {
  # Paper backends still need a concrete dimension. width_user is the
  # HTML-only channel; LaTeX (and RTF/PDF/DOCX) keep reading
  # col@width, which .resolve_col_widths() has converted to inches.
  spec <- tabular(data.frame(a = 1, b = 2)) |>
    cols(
      a = col_spec(width = "40%"),
      b = col_spec(width = "60%")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # No literal `%` width tokens leak into the .tex source.
  expect_no_match(txt, "40%", perl = TRUE)
  expect_no_match(txt, "60%", perl = TRUE)
  # Inch-resolved widths are present (tabularray uses `in` or
  # converts to pt; both forms are numeric, never `%`).
  expect_match(txt, "[0-9]\\.[0-9]+(in|pt)", perl = TRUE)
})

# ---------------------------------------------------------------------
# Regression: decimal header centers over the body's visible centroid
# (clinical-TFL convention; matches gt's default for numeric columns).
#
# Body cells in a decimal column render as `class="text-right"` PLUS
# engine_decimal NBSP padding that aligns decimal points across rows.
# The visible content occupies a fixed-width padded block; its centre
# sits INSIDE the cell, not at the cell's right edge. A centered
# header sits roughly over that visible centroid (matches the
# dominant clinical-TFL convention). A right-aligned header would
# match only the cell's right padding, not the visible centroid.
#
# This rule has flip-flopped across sessions. The current decision
# is "center"; both positive (text-center present) AND negative
# (text-right absent) assertions are pinned so any silent revert
# fails RED.
# ---------------------------------------------------------------------

test_that("decimal header projects to center (TFL centroid convention)", {
  spec <- tabular(data.frame(N = c(1.23, 4.56))) |>
    cols(N = col_spec(label = "N", align = "decimal"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Header <th> projects decimal -> center.
  expect_match(
    txt,
    "<th[^>]*class=\"text-center[^\"]*\"[^>]*>N</th>",
    perl = TRUE
  )
  # The previous (now-reverted) right projection must not recur.
  expect_no_match(
    txt,
    "<th[^>]*class=\"text-right[^\"]*\"[^>]*>N</th>",
    perl = TRUE
  )
  # Body <td>s still carry text-right -- only the header projection
  # changes; body alignment is unaffected.
  expect_match(
    txt,
    "<td[^>]*class=\"text-right[^\"]*\"[^>]*>",
    perl = TRUE
  )
})

# ---------------------------------------------------------------------
# Regression: HTML is unconditionally responsive, regardless of unit.
#
# Bug: previous design had `if (any_pct)` / `if (mode == "window")`
# branches that gated whether the wrapper / table emitted at 100%
# or at fixed engine-computed inches. That made HTML's responsive
# behaviour opt-in via percent widths only -- the user's
# `col_spec()` with no width fell through to inches and locked the
# viewer pane. Fix: HTML always emits `width:100%` table and
# `.tabular-content` wrapper, regardless of any column's unit.
#
# The tests below loop over EVERY CSS-supported unit so the
# guarantee is unit-agnostic; no special-casing of inches or pct.
# ---------------------------------------------------------------------

.test_html_for_width <- function(width_value) {
  spec <- tabular(data.frame(a = 1, b = 2)) |>
    cols(
      a = col_spec(width = width_value),
      b = col_spec(width = width_value)
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

.css_width_units <- c(
  "40%",
  "2.5in",
  "200px",
  "180pt",
  "5cm",
  "60mm"
)

test_that("HTML <table> is always width:100% across every CSS unit", {
  for (w in .css_width_units) {
    txt <- .test_html_for_width(w)
    expect_match(
      txt,
      "<table class=\"tabular-table\" style=\"width:100%\">",
      fixed = TRUE,
      info = sprintf("user width = %s", w)
    )
  }
  # And the same when the user wrote no widths at all.
  spec_blank <- tabular(data.frame(a = 1, b = 2))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec_blank, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%\">",
    fixed = TRUE
  )
})

test_that("HTML <col> emits user width verbatim across every CSS unit", {
  for (w in .css_width_units) {
    txt <- .test_html_for_width(w)
    expected <- sprintf("<col style=\"width:%s\"/>", w)
    expect_true(
      grepl(expected, txt, fixed = TRUE),
      info = sprintf("user width = %s; expected %s", w, expected)
    )
  }
})

test_that("HTML colgroup omits widths when user wrote none (responsive by default)", {
  spec <- tabular(data.frame(a = 1, b = 2, c = 3))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # No engine-computed inch widths leak into the colgroup.
  expect_no_match(txt, "<col style=\"width:[0-9.]+in\"/>", perl = TRUE)
  # And no other unit appears either (the "all bare" check
  # collapses the colgroup so nothing ships, OR bare <col/> only).
  expect_no_match(txt, "<col style=", fixed = TRUE)
})

test_that("HTML wrapper is always .tabular-content (no --window) across every CSS unit", {
  for (w in c(.css_width_units, NA_character_)) {
    spec <- if (is.na(w)) {
      tabular(data.frame(a = 1, b = 2))
    } else {
      tabular(data.frame(a = 1, b = 2)) |>
        cols(a = col_spec(width = w), b = col_spec(width = w))
    }
    out <- withr::local_tempfile(fileext = ".html")
    emit(spec, out)
    txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

    expect_match(
      txt,
      "<div class=\"tabular-content\">",
      fixed = TRUE,
      info = sprintf("user width = %s", w %||% "<none>")
    )
    # The --window modifier class must not appear on the wrapper
    # DIV anywhere in the emitted HTML.
    expect_no_match(
      txt,
      "<div class=\"tabular-content tabular-content--window\">",
      perl = TRUE,
      info = sprintf("user width = %s", w %||% "<none>")
    )
  }
})

test_that("CSS drops .tabular-content--window rule; .tabular-content is width:100%", {
  spec <- tabular(data.frame(a = 1, b = 2))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_match(
    txt,
    "\\.tabular-content\\s*\\{\\s*width:\\s*100%",
    perl = TRUE
  )
  expect_no_match(txt, "\\.tabular-content--window", perl = TRUE)
})

test_that("paper backend (LaTeX) cross-format check across every CSS unit", {
  # We don't pin specific output units (LaTeX backend owns its
  # conversion via gt-style convert_to_pt). Just confirm the
  # paper-side pipeline still produces a well-formed .tex file
  # regardless of what unit the user picked on the HTML side.
  for (w in .css_width_units) {
    spec <- tabular(data.frame(a = 1, b = 2)) |>
      cols(a = col_spec(width = w), b = col_spec(width = w))
    out <- withr::local_tempfile(fileext = ".tex")
    expect_silent(emit(spec, out))
    expect_true(
      file.exists(out) && file.info(out)$size > 0L,
      info = sprintf("user width = %s; .tex empty", w)
    )
  }
})

# ---------------------------------------------------------------------
# Change C: cells_indent sidecar -> CSS padding-left
#
# Shared 4-row fixture: 2 synthesised header rows (depth 0), 2 indented
# data rows (depth 1), narrow `width = "1in"` on the indented column +
# a wrapping label so the rendered cell wraps. Asserts the native
# padding marker lands on data rows only.
# ---------------------------------------------------------------------

mk_wrap_indent_spec <- function() {
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
  tabular(df, titles = "AE") |>
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
}

test_that("HTML emits padding-left on data rows but NOT on header rows (Change C)", {
  out <- withr::local_tempfile(fileext = ".html")
  emit(mk_wrap_indent_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Data rows (depth 1) carry `padding-left: calc(.6rem + Xem)`.
  expect_match(
    txt,
    "padding-left: calc\\(\\.6rem \\+ [0-9.]+em\\);[^>]*>Atrial",
    perl = TRUE
  )
  # Header rows (depth 0, the synthesised CARDIAC / GI rows) carry
  # the plain group value with NO padding-left declaration.
  header_cell <- sub(".*(<td[^>]*>CARDIAC</td>).*", "\\1", txt)
  expect_false(grepl("padding-left", header_cell, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Change D: is_header_row / is_blank_row branching in HTML
# ---------------------------------------------------------------------

test_that("HTML emits <tr class='tabular-group-header'> with bold spanning cell (Change D)", {
  df <- data.frame(
    group_label = c(
      "Best Overall Response",
      "Best Overall Response",
      "Objective Response Rate",
      "Objective Response Rate"
    ),
    stat_label = c("CR", "PR", "ORR (CR + PR)", "95% CI"),
    placebo = c("1 (1.2)", "1 (1.2)", "2 (2.3)", "(0.3, 8.1)"),
    drug_50 = c("1 (1.2)", "0", "1 (1.2)", "(0.0, 6.5)"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Eff") |>
    cols(
      group_label = col_spec(usage = "group", group_display = "header_row"),
      stat_label = col_spec(usage = "indent", label = "Response"),
      placebo = col_spec(label = "Placebo", align = "decimal"),
      drug_50 = col_spec(label = "Drug 50", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Section bands emit as `<tr class="tabular-group-header"><td colspan="N"><strong>...</strong></td></tr>`.
  expect_match(
    txt,
    "<tr class=\"tabular-group-header\"><td colspan=\"3\"><strong>Best Overall Response</strong></td></tr>",
    fixed = TRUE
  )
  expect_match(
    txt,
    "<tr class=\"tabular-group-header\"><td colspan=\"3\"><strong>Objective Response Rate</strong></td></tr>",
    fixed = TRUE
  )
  # Blank-gap row between sections.
  expect_match(
    txt,
    "<tr class=\"tabular-blank-row\"><td colspan=\"3\">&nbsp;</td></tr>",
    fixed = TRUE
  )
  # CSS rules for both classes ship in the inline stylesheet.
  expect_match(
    txt,
    ".tabular-group-header td { font-weight: 600;",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: nested band headers render with depth-aware padding-left
# ---------------------------------------------------------------------

test_that("HTML nested bands: band-1 header flush, band-2 header indented (Change D)", {
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
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Band 1 ("Safety", depth 0) has NO inline padding-left style on
  # the spanning cell.
  expect_match(
    html,
    "<tr class=\"tabular-group-header\"><td colspan=\"2\"><strong>Safety</strong>",
    fixed = TRUE
  )
  # Band 2 ("AE", depth 1) HAS padding-left calc on the spanning cell.
  expect_match(
    html,
    "<tr class=\"tabular-group-header\"><td colspan=\"2\" style=\"padding-left: calc\\(\\.6rem \\+ [0-9.]+em\\);\"><strong>AE</strong>",
    perl = TRUE
  )
})
