# backend_md() — GFM pipe-table backend.
#
# The backend self-registers at package-load time, so every test
# here can rely on `tabular:::.has_backend("md")` returning TRUE
# without setup.

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("md backend is registered at package load", {
  expect_true(tabular:::.has_backend("md"))
})

# ---------------------------------------------------------------------
# End-to-end via emit()
# ---------------------------------------------------------------------

test_that("emit(.md) writes a non-empty .md file", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_gt(length(lines), 0L)
  expect_true(any(grepl("^# T", lines)))
  expect_true(any(grepl("^\\| x \\| y \\|", lines)))
  expect_true(any(grepl("^F", lines)))
})

test_that("emit(.md) renders saf_demo golden pipeline end to end", {
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
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("# Demographics", lines, fixed = TRUE)))
  expect_true(any(grepl("Placebo<br/>N=86", lines, fixed = TRUE)))
  expect_true(any(grepl("Source: ADSL.", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

test_that("titles render as level-1 headings preserving order", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First", "Second", "Third")
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  headings <- lines[grepl("^# ", lines)]
  expect_identical(headings, c("# First", "# Second", "# Third"))
})

test_that("footnotes render as paragraphs separated by blank lines", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c("Foot A", "Foot B")
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  fa <- which(lines == "Foot A")
  fb <- which(lines == "Foot B")
  expect_length(fa, 1L)
  expect_length(fb, 1L)
  expect_identical(lines[(fa + 1L):(fb - 1L)], "")
})

test_that("no titles -> no top heading; no footnotes -> no trailing block", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_false(any(grepl("^# ", lines)))
})

# ---------------------------------------------------------------------
# Inline AST rendering (md() / html() input)
# ---------------------------------------------------------------------

test_that("bold / italic / code marks survive into the .md output", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
      md("**Bold title**"),
      md("*italic title*"),
      md("`code title`")
    )
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("**Bold title**", lines, fixed = TRUE)))
  expect_true(any(grepl("*italic title*", lines, fixed = TRUE)))
  expect_true(any(grepl("`code title`", lines, fixed = TRUE)))
})

test_that("superscript / subscript / link survive in the .md output", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(
      md("^a^ Marker"),
      md("~sub~ Marker"),
      md("[link](https://example.com)")
    )
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("^a^ Marker", lines, fixed = TRUE)))
  expect_true(any(grepl("~sub~ Marker", lines, fixed = TRUE)))
  expect_true(any(grepl("[link](https://example.com)", lines, fixed = TRUE)))
})

test_that("embedded \\n in cell text becomes <br/>", {
  spec <- tabular(
    data.frame(x = "line1\nline2"),
    titles = "T"
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("line1<br/>line2", lines, fixed = TRUE)))
})

test_that("pipe in cell text is escaped as \\|", {
  spec <- tabular(data.frame(x = "a|b|c"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("a\\|b\\|c", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Alignment row mapping
# ---------------------------------------------------------------------

test_that("alignment row maps every align value to its GFM token", {
  spec <- tabular(data.frame(L = "x", C = "x", R = "x", D = "x", U = "x")) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
      # U intentionally left without a col_spec -> default :---
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  sep <- lines[grepl("^\\| :", lines)][1L]
  expect_true(grepl(":---", sep, fixed = TRUE))
  expect_true(grepl(":---:", sep, fixed = TRUE))
  expect_true(grepl("---:", sep, fixed = TRUE))
})

test_that(".md_align_token defaults to left for unknown / NA", {
  expect_identical(tabular:::.md_align_token(NA_character_), ":---")
  expect_identical(tabular:::.md_align_token(NULL), ":---")
  expect_identical(tabular:::.md_align_token("garbage"), ":---")
})

# ---------------------------------------------------------------------
# Multi-level headers
# ---------------------------------------------------------------------

test_that("header band labels appear on their own table row above the column-labels row", {
  spec <- tabular(
    data.frame(
      grp = "x",
      placebo = "1",
      active_low = "2",
      active_high = "3"
    )
  ) |>
    headers("Treatment Arm" = c("placebo", "active_low", "active_high"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # Band label must appear before the alignment row.
  band_row <- which(grepl("Treatment Arm", lines, fixed = TRUE))[1L]
  sep_row <- which(grepl("^\\| :", lines))[1L]
  expect_lt(band_row, sep_row)
})

# ---------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------

test_that("multi-page emit includes page-marker comments + horizontal rules", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("<!-- page 2", lines, fixed = TRUE)))
  expect_true(any(grepl("^----$", lines)))
})

# ---- Faux page chrome (pagehead / pagefoot bands) ------------------

test_that("pagehead renders as faux chrome at top of document", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: XYZ",
        center = "Draft",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # First non-empty line is the chrome row.
  expect_match(
    lines[[1L]],
    "Protocol: XYZ \\| Draft \\| Page 1 of 1"
  )
  # Followed by `----` rule before the title block.
  expect_true(any(grepl("^----$", lines[1:5])))
})

test_that("pagefoot renders as faux chrome at bottom of document", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(left = "Program: tool.R", right = "24MAY2026")
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # Last non-empty line is the chrome row.
  tail_lines <- tail(lines[nzchar(lines)], 2L)
  expect_true(any(grepl("Program: tool.R", tail_lines, fixed = TRUE)))
  expect_true(any(grepl("24MAY2026", tail_lines, fixed = TRUE)))
})

test_that("empty pagehead / pagefoot emits no chrome bands", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("Protocol", txt, fixed = TRUE))
  expect_false(grepl("Program:", txt, fixed = TRUE))
})

test_that("continuation marker renders on pages 2+ when set", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp", continuation = "(continued)") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("(continued)", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Edge: zero-row data
# ---------------------------------------------------------------------

test_that("empty grid renders titles + (no rows) marker + footnotes", {
  fake <- tabular_grid(
    pages = list(),
    metadata = list(
      titles_ast = list(parse_inline("Title")),
      footnotes_ast = list(parse_inline("Foot"))
    )
  )
  lines <- tabular:::.render_md_grid(fake)
  expect_true("(no rows)" %in% lines)
  expect_true("# Title" %in% lines)
  expect_true("Foot" %in% lines)
})

test_that("zero-row spec renders header + alignment with no body rows", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("^\\| x \\| y \\|", lines)))
  expect_true(any(grepl("^\\| :---", lines)))
})

# ---------------------------------------------------------------------
# Cell escape helpers
# ---------------------------------------------------------------------

test_that(".md_escape_cell handles NA / NULL", {
  expect_identical(tabular:::.md_escape_cell(NA), "")
  expect_identical(tabular:::.md_escape_cell(NULL), "")
  expect_identical(tabular:::.md_escape_cell("plain"), "plain")
})

test_that(".md_escape_cell escapes pipes and CRLF / LF newlines", {
  expect_identical(tabular:::.md_escape_cell("a|b"), "a\\|b")
  expect_identical(tabular:::.md_escape_cell("a\r\nb"), "a<br/>b")
  expect_identical(tabular:::.md_escape_cell("a\nb"), "a<br/>b")
})

test_that(".render_md_inline returns '' on non-inline_ast input", {
  expect_identical(tabular:::.render_md_inline("not an ast"), "")
})

test_that(".render_md_run falls through to text for unknown types", {
  # Unknown run types are filtered by the inline_ast validator at
  # construction, but the renderer keeps a fallback in case a
  # backend hands one in directly.
  fake_run <- list(type = "totally_unknown_type", text = "fallback")
  expect_identical(tabular:::.render_md_run(fake_run), "fallback")
})

test_that("backend_md() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".md")
  tabular:::backend_md(grid, out)
  expect_true(file.exists(out))
  expect_true(any(grepl("^# T", readLines(out))))
})

test_that(".render_md_run handles span (drops wrapper, keeps children)", {
  ast <- parse_inline(html("<span style='color:red'>red</span>"))
  expect_identical(tabular:::.render_md_inline(ast), "red")
})

test_that(".render_md_children returns '' on empty children list", {
  expect_identical(tabular:::.render_md_children(list()), "")
})

test_that(".md_escape_inline handles NA / NULL", {
  expect_identical(tabular:::.md_escape_inline(NA), "")
  expect_identical(tabular:::.md_escape_inline(NULL), "")
  expect_identical(tabular:::.md_escape_inline("a|b"), "a\\|b")
})

test_that(".render_md_col_labels_row falls back to column name on missing AST", {
  out <- tabular:::.render_md_col_labels_row(
    col_labels_ast = list(),
    col_names_visible = c("x", "y")
  )
  expect_identical(out, "| x | y |")
})

test_that(".render_md_link emits the optional title attribute when set", {
  run <- list(
    type = "link",
    href = "https://x.com",
    title = "Tip",
    children = list(list(type = "plain", text = "hi"))
  )
  expect_identical(
    tabular:::.render_md_link(run),
    '[hi](https://x.com "Tip")'
  )
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline
# ---------------------------------------------------------------------

test_that("saf_demo golden pipeline matches the pinned .md snapshot", {
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
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  expect_snapshot_file(out, "saf_demo_golden.md")
})
