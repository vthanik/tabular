# test-empty-state.R — the zero-row "no data" page renders EXACTLY like a normal
# short table: chrome (title, column header), then the `empty_text` message in a
# SINGLE full-span, horizontally centred row in the BODY (where the first data
# row would sit), then the footnote trailing immediately, flowing compactly at
# the top of the body with blank space below. No vertical centring, no margin
# chrome (DOCX header / footer parts + <w:vAlign>, RTF \vertal*, LaTeX \vfill),
# no gap. The message line is centred via each backend's native cell alignment
# (\qc / <w:jc> / \SetCell), not via placement knobs. These are cross-backend
# regression tests for the revert of 74f1aa5 (code in backend_rtf / backend_docx
# / backend_latex / backend_html / backend_md + as_grid).

# A zero-row spec carrying a header band + title + footnote, plus whatever
# preset knobs a test exercises.
mk_empty <- function(...) {
  spec <- tabular(
    data.frame(grp = character(), x = character(), y = character()),
    titles = "T",
    footnotes = "F",
    empty_text = "No data."
  ) |>
    cols(grp = col_spec()) |>
    group_rows(by = "grp")
  if (...length() > 0L) {
    spec <- preset(spec, ...)
  }
  spec
}

# A subgroup spec with a zero-N crossing between data crossings (data -> empty
# -> data under keep_empty = TRUE): the F x first-visit crossing is removed so
# that section renders as an empty page while the others carry data.
mk_empty_subgroup <- function() {
  d <- cdisc_saf_subgroup
  vis <- unique(as.character(d$visit))[[1L]]
  d <- d[!(as.character(d$sex) == "F" & as.character(d$visit) == vis), ]
  tabular(d, titles = "T", footnotes = "F", empty_text = "No data here.") |>
    cols(
      sex_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(),
      stat_label = col_spec(),
      placebo = col_spec(),
      drug_50 = col_spec(),
      drug_100 = col_spec(),
      Total = col_spec()
    ) |>
    group_rows(by = "param") |>
    subgroup(
      by = c("sex", "visit"),
      label = "Sex: {sex} / Visit: {visit}",
      keep_empty = TRUE
    )
}

# Emit + read back. For DOCX concatenate document.xml with every header / footer
# part: a positive assertion finds a token wherever it lands, and the absence
# checks confirm the chrome did NOT relocate into a header / footer part.
emit_read <- function(spec, ext, fmt = NULL) {
  f <- withr::local_tempfile(fileext = ext, .local_envir = parent.frame())
  emit(spec, f, format = fmt)
  if (identical(ext, ".docx")) {
    ex <- withr::local_tempdir(.local_envir = parent.frame())
    utils::unzip(f, exdir = ex)
    parts <- list.files(
      file.path(ex, "word"),
      pattern = "^(document|header|footer).*\\.xml$",
      full.names = TRUE
    )
    return(paste(
      vapply(
        parts,
        function(p) paste(readLines(p, warn = FALSE), collapse = ""),
        character(1L)
      ),
      collapse = ""
    ))
  }
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# Unzip a DOCX and return both the word/ file list and document.xml, so a test
# can assert the absence of empty header / footer parts and the message landing
# in the body.
emit_docx_parts <- function(spec) {
  f <- withr::local_tempfile(fileext = ".docx", .local_envir = parent.frame())
  emit(spec, f)
  ex <- withr::local_tempdir(.local_envir = parent.frame())
  utils::unzip(f, exdir = ex)
  list(
    files = list.files(file.path(ex, "word")),
    document = paste(
      readLines(file.path(ex, "word", "document.xml"), warn = FALSE),
      collapse = ""
    )
  )
}

# Count fixed-pattern occurrences in a string.
n_match <- function(s, p) {
  lengths(regmatches(s, gregexpr(p, s, fixed = TRUE)))
}

# ---------------------------------------------------------------------
# Normal-table shape — the message is a centred BODY row, not margin chrome
# ---------------------------------------------------------------------

test_that("empty-state renders the message as a centred body row, not native-centred", {
  spec <- mk_empty()

  # RTF: a \qc-centred merged message row in the table body; NO native section
  # vertical centring (\vertal*) and NO exact-height row (\trrh-).
  rtf <- emit_read(spec, ".rtf")
  expect_match(rtf, "\\qc No data.", fixed = TRUE)
  expect_no_match(rtf, "\\vertal", fixed = TRUE)
  expect_no_match(rtf, "\\trrh-", fixed = TRUE)

  # LaTeX: a \SetCell[c=N]{c} full-span centred message row inside the NORMAL
  # longtblr (not a plain tblr); NO \vfill placement.
  tex <- emit_read(spec, ".tex", "latex")
  expect_match(tex, "\\begin{longtblr}", fixed = TRUE)
  expect_no_match(tex, "\\begin{tblr}", fixed = TRUE)
  expect_match(tex, "\\SetCell[c=3]{c} No data.", fixed = TRUE)
  expect_no_match(tex, "\\vfill", fixed = TRUE)

  # HTML: a full-span colspan message row, centred in flow under the column
  # header -- text-align only, NO vertical-align on the message cell.
  html <- emit_read(spec, ".html")
  expect_match(
    html,
    "<td colspan=\"3\" class=\"tabular-empty\" style=\"text-align:center;\">No data.</td>",
    fixed = TRUE
  )

  # Markdown: the message rides a centred <div align> below the (closed) table.
  md <- emit_read(spec, ".md")
  expect_match(md, "<div align=\"center\">No data.</div>", fixed = TRUE)
})

test_that("empty-state DOCX renders the message in the body, no header / footer parts", {
  parts <- emit_docx_parts(mk_empty())

  # No relocated chrome: the standalone empty doc carries ONLY the shared
  # header1 / footer1 (or none), never a second header02 / footer02 part.
  expect_false("header02.xml" %in% parts$files)
  expect_false("footer02.xml" %in% parts$files)

  # The message is a centred gridSpan body row in document.xml.
  expect_match(parts$document, "No data.", fixed = TRUE)
  expect_match(parts$document, "<w:gridSpan w:val=\"3\"/>", fixed = TRUE)
  expect_match(parts$document, "<w:jc w:val=\"center\"/>", fixed = TRUE)

  # No native vertical centring: the section has no <w:vAlign>, and the message
  # row has no exact-height trHeight.
  sect <- regmatches(
    parts$document,
    regexpr("<w:sectPr>.*</w:sectPr>", parts$document)
  )
  expect_no_match(sect, "vAlign", fixed = TRUE)
  expect_no_match(parts$document, "w:hRule=\"exact\"", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Borders / grid / colour — the message row carries the body bottom rule
# ---------------------------------------------------------------------

test_that("empty-state closes the data region with the default body bottom rule", {
  spec <- mk_empty()
  # RTF: the closer rides the message row as its BOTTOM border -- canonical
  # solid 0.5pt (\brdrw10).
  expect_match(
    emit_read(spec, ".rtf"),
    "\\clbrdrb\\brdrs\\brdrw10",
    fixed = TRUE
  )
  # DOCX: a 0.5pt (sz=4) bottom border on the message row's merged cell.
  expect_match(
    emit_read(spec, ".docx"),
    "<w:bottom w:space=\"0\" w:val=\"single\" w:sz=\"4\"",
    fixed = TRUE
  )
  # LaTeX: the normal outer_bottom hline directive, default solid 0.5pt.
  expect_match(emit_read(spec, ".tex", "latex"), "0.5pt, solid", fixed = TRUE)
})

test_that("empty-state honours a custom bottomrule width + colour (rules knob)", {
  spec <- mk_empty(
    rules = list(bottomrule = brdr("thick", color = "#FF0000"))
  )
  # RTF: thick = 1.5pt = \brdrw30 on the message-row bottom border.
  expect_match(
    emit_read(spec, ".rtf"),
    "\\clbrdrb\\brdrs\\brdrw30",
    fixed = TRUE
  )
  # DOCX: 1.5pt = sz=12, red, on the message-row bottom border.
  expect_match(
    emit_read(spec, ".docx"),
    "<w:bottom w:space=\"0\" w:val=\"single\" w:sz=\"12\" w:color=\"FF0000\"/>",
    fixed = TRUE
  )
  # LaTeX: 1.5pt rule in the red colour on the outer_bottom hline.
  tex <- emit_read(spec, ".tex", "latex")
  expect_match(tex, "1.5pt, solid", fixed = TRUE)
  expect_match(tex, "FF0000", fixed = TRUE)
})

test_that("empty-state honours bottomrule = 'none' (drops the closer)", {
  # The header band keeps its own rules, so assert the closer specifically
  # disappears: one fewer bottom-border on RTF / DOCX, and one fewer hline
  # directive on LaTeX.
  rtf_d <- emit_read(mk_empty(), ".rtf")
  rtf_n <- emit_read(mk_empty(rules = list(bottomrule = "none")), ".rtf")
  expect_lt(
    n_match(rtf_n, "\\clbrdrb\\brdrs"),
    n_match(rtf_d, "\\clbrdrb\\brdrs")
  )

  docx_d <- emit_read(mk_empty(), ".docx")
  docx_n <- emit_read(mk_empty(rules = list(bottomrule = "none")), ".docx")
  expect_lt(
    n_match(docx_n, "<w:bottom w:space=\"0\" w:val=\"single\""),
    n_match(docx_d, "<w:bottom w:space=\"0\" w:val=\"single\"")
  )

  tex_d <- emit_read(mk_empty(), ".tex", "latex")
  tex_n <- emit_read(
    mk_empty(rules = list(bottomrule = "none")),
    ".tex",
    "latex"
  )
  expect_lt(n_match(tex_n, "hline{"), n_match(tex_d, "hline{"))
})

# ---------------------------------------------------------------------
# Font — the message + chrome follow preset@font_family
# ---------------------------------------------------------------------

test_that("empty-state honours font_family", {
  spec <- mk_empty(font_family = "serif")
  expect_match(emit_read(spec, ".rtf"), "\\f0\\froman", fixed = TRUE)
  expect_match(
    emit_read(spec, ".tex", "latex"),
    "Liberation Serif",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Spacing — the title spacing gap reserves more room in the chrome
# ---------------------------------------------------------------------

test_that("empty-state honours the title spacing gap", {
  # A larger above-title gap injects more blank title rows into the chrome,
  # raising the total \row count.
  rows <- function(spec) {
    lines <- strsplit(emit_read(spec, ".rtf"), "\n")[[1L]]
    sum(grepl("^\\\\row$", lines))
  }
  expect_gt(
    rows(mk_empty(spacing = list(title = c(above = 4)))),
    rows(mk_empty(spacing = list(title = c(above = 1))))
  )
})

# ---------------------------------------------------------------------
# One page — the standalone empty page is a single section (no phantom page)
# ---------------------------------------------------------------------

test_that("empty-state stays a single RTF section (no phantom page)", {
  rtf <- strsplit(emit_read(mk_empty(), ".rtf"), "\n")[[1L]]
  expect_length(grep("^\\\\sect$", rtf), 0L)
})

# ---------------------------------------------------------------------
# Per-subgroup — an empty crossing between data crossings renders as one
# message row in its own panel, with no relocated chrome
# ---------------------------------------------------------------------

test_that("per-subgroup empty crossing renders one message row", {
  spec <- mk_empty_subgroup()
  # Exactly one empty crossing -> one empty page in the grid.
  g <- as_grid(spec)
  n_empty <- sum(vapply(
    g@pages,
    function(p) isTRUE(p$is_empty_page),
    logical(1L)
  ))
  expect_equal(n_empty, 1L)

  # DOCX: the empty crossing renders its message in the body (document.xml),
  # with no relocated header02 / footer02 part and no section <w:vAlign>.
  parts <- emit_docx_parts(spec)
  expect_false("header02.xml" %in% parts$files)
  expect_false("footer02.xml" %in% parts$files)
  expect_match(parts$document, "No data here.", fixed = TRUE)
  expect_no_match(
    parts$document,
    "<w:vAlign w:val=\"center\"/>",
    fixed = TRUE
  )

  # RTF: the message appears once; no native centring.
  rtf <- emit_read(spec, ".rtf")
  expect_match(rtf, "No data here.", fixed = TRUE)
  expect_no_match(rtf, "\\vertal", fixed = TRUE)
})

test_that("per-subgroup empty emits on every backend without error", {
  spec <- mk_empty_subgroup()
  for (ext in c(".rtf", ".docx", ".html", ".md")) {
    expect_no_error(emit(spec, withr::local_tempfile(fileext = ext)))
  }
  expect_no_error(emit(
    spec,
    withr::local_tempfile(fileext = ".tex"),
    format = "latex"
  ))
})

# ---------------------------------------------------------------------
# Coverage: the default (no `empty_text`) message branch on every backend,
# and the all-columns-hidden degenerate (n_panels == 0). (#cov)
# ---------------------------------------------------------------------

test_that("empty-state default message (no empty_text) renders on every backend (#cov)", {
  spec <- tabular(
    data.frame(grp = character(), x = character()),
    titles = "T"
  ) |>
    cols(
      grp = col_spec(),
      x = col_spec()
    ) |>
    group_rows(by = "grp")
  msg <- tabular:::.tabular_empty_text_default
  for (ext in c(".rtf", ".tex", ".html", ".md")) {
    expect_match(emit_read(spec, ext), msg, fixed = TRUE)
  }
  expect_match(emit_docx_parts(spec)$document, msg, fixed = TRUE)
})

test_that("empty-state with every column hidden renders a standalone message (#cov)", {
  # No visible columns -> n_panels == 0 (DOCX bare-paragraph path) and the
  # n_cols <= 1 single-cell branch (LaTeX); the default message still shows.
  spec <- tabular(
    data.frame(a = character(), b = character()),
    titles = "T"
  ) |>
    cols(a = col_spec(visible = FALSE), b = col_spec(visible = FALSE))
  msg <- tabular:::.tabular_empty_text_default
  expect_match(emit_read(spec, ".tex"), msg, fixed = TRUE)
  expect_match(emit_docx_parts(spec)$document, msg, fixed = TRUE)
})

# ---------------------------------------------------------------------
# Coverage: the empty-text DEFAULT-literal fallback each backend uses when a
# grid carries no parsed empty_text_ast (a hand-built grid; emit() always
# parses one). A single visible column also drives the LaTeX <=1-column
# single-cell message branch. (#cov)
# ---------------------------------------------------------------------

test_that("empty-state backends fall back to the default literal when empty_text_ast is NULL (#cov)", {
  spec <- tabular(data.frame(x = character()), titles = "T") |>
    cols(x = col_spec())
  g <- as_grid(spec)
  m <- g@metadata
  m["empty_text_ast"] <- list(NULL)
  g2 <- S7::set_props(g, metadata = m)
  for (be in c(
    "backend_rtf",
    "backend_latex",
    "backend_html",
    "backend_md"
  )) {
    f <- withr::local_tempfile(fileext = ".out")
    fn <- get(be, asNamespace("tabular"))
    expect_no_error(fn(g2, f))
    expect_match(
      paste(readLines(f, warn = FALSE), collapse = "\n"),
      tabular:::.tabular_empty_text_default,
      fixed = TRUE
    )
  }
  fd <- withr::local_tempfile(fileext = ".docx")
  expect_no_error(get("backend_docx", asNamespace("tabular"))(g2, fd))
})

test_that("zero-page grid renders the no-panel degenerate on each paged backend (#cov)", {
  # A hand-built grid with no pages (no visible columns / no body at all):
  # backends fall through to the bare-paragraph empty path. emit() never
  # produces this, but the degenerate guard must hold for hand-built grids.
  spec <- tabular(data.frame(x = character()), titles = "T") |>
    cols(x = col_spec())
  g <- as_grid(spec)
  m <- g@metadata
  m["empty_text_ast"] <- list(NULL) # also hit the default-literal fallback
  g0 <- S7::set_props(g, pages = list(), metadata = m)
  for (be in c("backend_rtf", "backend_latex", "backend_docx")) {
    f <- withr::local_tempfile(fileext = ".out")
    expect_no_error(get(be, asNamespace("tabular"))(g0, f))
  }
})
