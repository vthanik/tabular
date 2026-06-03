# Tests for verbatim whitespace preservation (R/util_ws.R) and its
# wiring into every backend.

# ---------------------------------------------------------------------
# .preserve_ws / .preserve_ws_one truth table
# ---------------------------------------------------------------------

test_that(".preserve_ws rewrites leading, trailing, and 2+ interior runs", {
  nb <- "@" # visible stand-in token for the test
  # leading run
  expect_equal(tabular:::.preserve_ws("  ab", nb), "@@ab")
  # trailing run
  expect_equal(tabular:::.preserve_ws("ab  ", nb), "ab@@")
  # interior run of 2 -> one non-breaking + one breakable space
  expect_equal(tabular:::.preserve_ws("a  b", nb), "a@ b")
  # interior run of 3 -> two non-breaking + one breakable
  expect_equal(tabular:::.preserve_ws("a   b", nb), "a@@ b")
})

test_that(".preserve_ws leaves a single interior space breakable", {
  expect_equal(tabular:::.preserve_ws("a b", "@"), "a b")
  expect_equal(tabular:::.preserve_ws("one two three", "@"), "one two three")
})

test_that(".preserve_ws never touches U+00A0 (decimal padding) or tabs", {
  # NBSP padding stays verbatim (decimal alignment is safe by construction)
  expect_equal(tabular:::.preserve_ws("12   ", "@"), "12   ")
  # a tab is a non-space token, kept whole
  expect_equal(tabular:::.preserve_ws("a\t\tb", "@"), "a\t\tb")
})

test_that(".preserve_ws handles all-spaces, empty, and NA cells", {
  expect_equal(tabular:::.preserve_ws("   ", "@"), "@@@") # leading == trailing
  expect_equal(tabular:::.preserve_ws("", "@"), "")
  expect_equal(tabular:::.preserve_ws(NA_character_, "@"), NA_character_)
  expect_equal(tabular:::.preserve_ws(character(), "@"), character())
})

test_that(".preserve_ws lead/trail flags gate line-edge single spaces only", {
  nb <- "@"
  # not a line edge: a single boundary space stays breakable both sides
  expect_equal(
    tabular:::.preserve_ws(" of ", nb, lead = FALSE, trail = FALSE),
    " of "
  )
  # lead only: leading single space preserved, trailing stays breakable
  expect_equal(
    tabular:::.preserve_ws(" x ", nb, lead = TRUE, trail = FALSE),
    "@x "
  )
  # trail only: symmetric
  expect_equal(
    tabular:::.preserve_ws(" x ", nb, lead = FALSE, trail = TRUE),
    " x@"
  )
  # a 2+ run that is NOT a line edge still gets interior treatment
  # ((k-1) non-breaking + 1 breakable), regardless of lead / trail.
  expect_equal(
    tabular:::.preserve_ws("a  b", nb, lead = FALSE, trail = FALSE),
    "a@ b"
  )
  expect_equal(
    tabular:::.preserve_ws("  x", nb, lead = FALSE, trail = FALSE),
    "@ x"
  )
})

test_that(".preset_ws_preserve defaults to preserve and honours collapse", {
  expect_true(tabular:::.preset_ws_preserve(NULL))
  expect_true(tabular:::.preset_ws_preserve(preset_spec()))
  expect_false(tabular:::.preset_ws_preserve(preset_spec(
    whitespace = "collapse"
  )))
})

# ---------------------------------------------------------------------
# .ws_wrap_segments (column-width measurement)
# ---------------------------------------------------------------------

test_that(".ws_wrap_segments keeps a leading indent as one non-breaking unit", {
  expect_equal(tabular:::.ws_wrap_segments("     Placebo"), "     Placebo")
})

test_that(".ws_wrap_segments wraps a normal single-spaced header word-by-word", {
  expect_equal(
    tabular:::.ws_wrap_segments("Adverse Event Term"),
    c("Adverse", "Event", "Term")
  )
})

test_that(".ws_wrap_segments splits a 2+ interior run, keeping (k-1) attached", {
  # "Mean  (SD)" (2 interior spaces) -> "Mean " is one non-breaking unit
  # (keeps k-1 = 1 trailing space), then a breakable split before "(SD)".
  expect_equal(
    tabular:::.ws_wrap_segments("Mean  (SD)"),
    c("Mean ", "(SD)")
  )
})

test_that(".ws_wrap_segments handles empty / NA", {
  expect_equal(tabular:::.ws_wrap_segments(""), character())
  expect_equal(tabular:::.ws_wrap_segments(NA_character_), character())
})

# ---------------------------------------------------------------------
# preset knob validation
# ---------------------------------------------------------------------

test_that("preset(whitespace=) rejects an unknown value", {
  expect_snapshot(
    error = TRUE,
    preset(tabular(data.frame(x = 1)), whitespace = "nope")
  )
  # S7 property validator is the last-line defence when engine / backend
  # code sets the slot directly.
  expect_error(preset_spec(whitespace = "nope"), "whitespace")
})

# ---------------------------------------------------------------------
# Per-backend integration: a hand-built leading indent in a col label
# ---------------------------------------------------------------------

mk_ws_spec <- function() {
  df <- data.frame(grp = "x", placebo = "1", stringsAsFactors = FALSE)
  tabular(df) |> cols(placebo = col_spec(label = "     Placebo"))
}

test_that("HTML preserves a hand-built label indent as &nbsp; and collapse reverts it", {
  out <- withr::local_tempfile(fileext = ".html")
  emit(mk_ws_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Placebo", fixed = TRUE)

  out2 <- withr::local_tempfile(fileext = ".html")
  emit(mk_ws_spec() |> preset(whitespace = "collapse"), out2)
  txt2 <- paste(readLines(out2, warn = FALSE), collapse = "\n")
  expect_false(grepl(
    "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Placebo",
    txt2,
    fixed = TRUE
  ))
  expect_match(txt2, "     Placebo", fixed = TRUE)
})

test_that("md preserves a hand-built label indent as &nbsp;", {
  out <- withr::local_tempfile(fileext = ".md")
  emit(mk_ws_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Placebo", fixed = TRUE)
})

test_that("LaTeX preserves a hand-built label indent as ~ ties", {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(mk_ws_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "~~~~~Placebo", fixed = TRUE)
})

test_that("RTF preserves a hand-built label indent as backslash-tilde", {
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(mk_ws_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  tok <- paste0(strrep(paste0("\\", "~"), 5), "Placebo")
  expect_true(grepl(tok, txt, fixed = TRUE))
})

test_that("inter-run boundary spaces stay breakable (not made non-breaking)", {
  # "Page **{page}** of {npages}" splits "Page " | bold | " of " | ... .
  # The single spaces at the run boundaries must NOT become &nbsp;.
  ast <- parse_inline(md("a **b** c d"))
  expect_equal(tabular:::.render_html_inline(ast), "a <strong>b</strong> c d")
})

# ---------------------------------------------------------------------
# DOCX: \n -> <w:br/> body fix + xml:space leading-space preservation
# ---------------------------------------------------------------------

docx_document_xml <- function(spec) {
  zf <- withr::local_tempfile(fileext = ".docx")
  emit(spec, zf)
  td <- withr::local_tempdir()
  utils::unzip(zf, exdir = td)
  paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
}

test_that("DOCX splits a multi-line body cell on <w:br/>", {
  df <- data.frame(grp = "x", v = "a\nb", stringsAsFactors = FALSE)
  doc <- docx_document_xml(tabular(df))
  expect_match(doc, "<w:br/>", fixed = TRUE)
})

test_that("DOCX keeps a hand-built label indent via xml:space", {
  doc <- docx_document_xml(mk_ws_spec())
  expect_match(doc, "     Placebo", fixed = TRUE)
})
