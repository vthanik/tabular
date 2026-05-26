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

test_that("auto-resolved widths land in <colgroup> end-to-end via emit()", {
  spec <- tabular(data.frame(x = "x", y = "y"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  # colgroup present, two col children with width:Xin
  expect_match(txt, "<colgroup>", fixed = TRUE)
  expect_match(txt, "</colgroup>", fixed = TRUE)
  cols_found <- regmatches(
    txt,
    gregexpr("<col style=\"width:[0-9.]+in\"/>", txt)
  )[[1L]]
  expect_length(cols_found, 2L)
})

# ---------------------------------------------------------------------
# Table width — width_mode dispatch + scroll wrapper
# ---------------------------------------------------------------------

test_that(".html_table_open_tag emits sum-of-widths under width_mode = 'content'", {
  col_specs <- list(
    col_spec(width = 1.5),
    col_spec(width = 2.25),
    col_spec(width = 0.75)
  )
  ps <- tabular:::preset_spec(width_mode = "content")
  tag <- tabular:::.html_table_open_tag(col_specs, ps)
  expect_identical(
    tag,
    "<table class=\"tabular-table\" style=\"width:4.500000in; table-layout:fixed\">"
  )
})

test_that(".html_table_open_tag emits width:100% under width_mode = 'window'", {
  col_specs <- list(
    col_spec(width = 1.5),
    col_spec(width = 2.25)
  )
  ps <- tabular:::preset_spec(width_mode = "window")
  tag <- tabular:::.html_table_open_tag(col_specs, ps)
  expect_identical(
    tag,
    "<table class=\"tabular-table\" style=\"width:100%; table-layout:fixed\">"
  )
})

test_that(".html_table_open_tag emits sum-of-widths under width_mode = 'fixed'", {
  # Same emission path as "content"; the distinction lives upstream
  # in `.distribute_widths()` which collapses auto cols to the
  # minimum sliver under "fixed".
  col_specs <- list(
    col_spec(width = 3),
    col_spec(width = 1)
  )
  ps <- tabular:::preset_spec(width_mode = "fixed")
  tag <- tabular:::.html_table_open_tag(col_specs, ps)
  expect_identical(
    tag,
    "<table class=\"tabular-table\" style=\"width:4.000000in; table-layout:fixed\">"
  )
})

test_that(".html_table_open_tag falls back to bare <table> when no widths resolved", {
  # Defensive fallback: when a spec bypasses engine resolution and
  # no visible column carries a numeric width, emit the unstyled
  # tag so the natural-fit browser layout still works.
  col_specs <- list(NULL, NULL)
  ps <- tabular:::preset_spec()
  tag <- tabular:::.html_table_open_tag(col_specs, ps)
  expect_identical(tag, "<table class=\"tabular-table\">")
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

test_that("default preset emits a content-fitted <table> end-to-end", {
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
  # Table opening carries an inline width:<N>in style with
  # table-layout:fixed (content mode is the preset default).
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:[0-9.]+in; table-layout:fixed\">",
    perl = TRUE
  )
  # No `width: 100%` on `.tabular-table` baseline rule.
  expect_false(grepl(".tabular-table { width: 100%", txt, fixed = TRUE))
})

test_that("width_mode = 'window' flips the <table> to width:100% end-to-end", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b"))
  ) |>
    preset(width_mode = "window")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_match(
    txt,
    "<table class=\"tabular-table\" style=\"width:100%; table-layout:fixed\">",
    fixed = TRUE
  )
})

test_that(".tabular-table-wrap CSS is present and resets under @media print", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  # Screen rule: horizontal scroll fallback for narrow viewports.
  expect_match(
    txt,
    ".tabular-table-wrap { overflow-x: auto; margin: .75rem 0; }",
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

test_that("HTML / LaTeX / RTF / DOCX widths agree byte-for-byte (cross-backend parity)", {
  # The quality-bar claim — engine-resolved widths render identically
  # across every backend. Build the golden saf_demo pipeline once,
  # emit all four widthful backends, parse widths, assert vector
  # equality (converted to a common unit: inches to 6 decimals).
  # Pinned to portrait so the cellx parsing finds the row boundary
  # at the expected position; the parity claim is geometry-agnostic
  # (verified separately under landscape via the golden snapshots).
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

  html_in <- as.numeric(regmatches(
    html_txt,
    gregexpr(
      "(?<=<col style=\"width:)[0-9.]+(?=in\"/>)",
      html_txt,
      perl = TRUE
    )
  )[[1L]])
  tex_in <- as.numeric(regmatches(
    tex_txt,
    gregexpr("(?<=wd=)[0-9.]+(?=in)", tex_txt, perl = TRUE)
  )[[1L]])
  # RTF carries cumulative \cellx positions in twips; diff to get
  # per-column widths, divide by 1440 -> inches.
  rtf_cellx <- as.integer(regmatches(
    rtf_txt,
    gregexpr("(?<=\\\\cellx)[0-9]+", rtf_txt, perl = TRUE)
  )[[1L]])
  # cellx repeats per row; first N entries = first row's columns.
  ncol_vis <- length(html_in)
  rtf_in <- diff(c(0L, rtf_cellx[seq_len(ncol_vis)])) / 1440
  # DOCX <w:gridCol w:w="..."> in twips
  docx_tw <- as.integer(regmatches(
    docx_txt,
    gregexpr("(?<=<w:gridCol w:w=\")[0-9]+(?=\"/>)", docx_txt, perl = TRUE)
  )[[1L]])
  docx_in <- docx_tw / 1440

  expect_gt(length(html_in), 0L)
  # HTML and LaTeX render the engine float at %f precision -- byte-
  # for-byte identical.
  expect_identical(round(html_in, 6L), round(tex_in, 6L))
  # RTF and DOCX both snap to integer twips at cumulative boundaries
  # so they are byte-for-byte identical as integer twip vectors.
  expect_identical(round(rtf_in * 1440), round(docx_in * 1440))
  # Across the float vs twip pair, agreement is tight to the twip
  # granularity (1/1440 in ~= 0.0007 in). Any larger drift would
  # signal an engine-resolution divergence between backends.
  expect_true(all(abs(html_in - docx_in) <= 1 / 1440))
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
  # Exactly one continuous <table> / <colgroup> / <thead> / <tbody>.
  expect_identical(
    length(grep("<table class=\"tabular-table\"", lines)),
    1L
  )
  expect_identical(
    length(grep("<colgroup>", lines, fixed = TRUE)),
    1L
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
