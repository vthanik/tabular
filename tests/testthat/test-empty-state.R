# test-empty-state.R — the zero-row "no data" page renders the message ALONE
# in the page body, centred by each backend's NATIVE vertical alignment (DOCX
# <w:vAlign>, RTF \vertalc, LaTeX \vfill), with the table chrome (titles,
# banner, column header) relocated into the page margins (header / footer
# parts) and the closing rule + footnotes in the footer. No predicted box
# height -> no recurring phantom page. These are cross-backend regression tests
# for the no-data state (code in backend_rtf / backend_docx / backend_latex /
# backend_html + the engine geometry in as_grid).

# A zero-row spec carrying a header band + title + footnote, plus whatever
# preset knobs a test exercises.
mk_empty <- function(...) {
  spec <- tabular(
    data.frame(grp = character(), x = character(), y = character()),
    titles = "T",
    footnotes = "F",
    empty_text = "No data."
  ) |>
    cols(grp = col_spec(usage = "group", group_display = "header_row"))
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
      param = col_spec(usage = "group"),
      stat_label = col_spec(),
      placebo = col_spec(),
      drug_50 = col_spec(),
      drug_100 = col_spec(),
      Total = col_spec()
    ) |>
    subgroup(
      by = c("sex", "visit"),
      label = "Sex: {sex} / Visit: {visit}",
      keep_empty = TRUE
    )
}

# Emit + read back. For DOCX the chrome / rule / footnotes ride header* /
# footer* parts, so concatenate document.xml with every header / footer part:
# assertions then find a token wherever the zone model places it.
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

# Count fixed-pattern occurrences in a string.
n_match <- function(s, p) {
  lengths(regmatches(s, gregexpr(p, s, fixed = TRUE)))
}

# ---------------------------------------------------------------------
# Native centring — the chrome leaves the body, the section centres the
# message (DOCX <w:vAlign>, RTF \vertalc), no exact-height box
# ---------------------------------------------------------------------

test_that("empty-state centres the message natively, chrome in the margins", {
  spec <- mk_empty()
  rtf <- emit_read(spec, ".rtf")
  expect_match(rtf, "\\vertalc", fixed = TRUE)
  expect_no_match(rtf, "\\trrh-", fixed = TRUE)
  expect_match(rtf, "No data.", fixed = TRUE)

  docx <- emit_read(spec, ".docx")
  expect_match(docx, "<w:vAlign w:val=\"center\"/>", fixed = TRUE)
  expect_no_match(docx, "<w:trHeight w:hRule=\"exact\"")
  expect_match(docx, "No data.", fixed = TRUE)
})

test_that("empty-state DOCX emits dedicated header / footer parts for the section", {
  f <- withr::local_tempfile(fileext = ".docx")
  emit(mk_empty(), f)
  ex <- withr::local_tempdir()
  utils::unzip(f, exdir = ex)
  files <- list.files(file.path(ex, "word"))
  expect_true("header02.xml" %in% files)
  expect_true("footer02.xml" %in% files)
  # The relocated chrome (a <w:tbl>) lives in the header part.
  hdr <- paste(
    readLines(file.path(ex, "word", "header02.xml"), warn = FALSE),
    collapse = ""
  )
  expect_match(hdr, "<w:tbl>", fixed = TRUE)
  # Every part is declared in [Content_Types].xml and related in the doc rels.
  ct <- paste(
    readLines(file.path(ex, "[Content_Types].xml"), warn = FALSE),
    collapse = ""
  )
  rels <- paste(
    readLines(
      file.path(ex, "word", "_rels", "document.xml.rels"),
      warn = FALSE
    ),
    collapse = ""
  )
  expect_match(ct, "/word/header02.xml", fixed = TRUE)
  expect_match(ct, "/word/footer02.xml", fixed = TRUE)
  expect_match(rels, "Target=\"header02.xml\"", fixed = TRUE)
  expect_match(rels, "Target=\"footer02.xml\"", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Borders / grid / colour — the body bottom rule closes the data region,
# now flush above the footnote in the footer zone
# ---------------------------------------------------------------------

test_that("empty-state closes the data region with the default body bottom rule", {
  spec <- mk_empty()
  # RTF: the closer rides the {\footer} as a merged row's TOP border --
  # canonical solid 0.5pt (\brdrw10).
  expect_match(
    emit_read(spec, ".rtf"),
    "\\clbrdrt\\brdrs\\brdrw10",
    fixed = TRUE
  )
  # DOCX: a 0.5pt (sz=4) top border on the footer-part rule table.
  expect_match(
    emit_read(spec, ".docx"),
    "<w:top w:space=\"0\" w:val=\"single\" w:sz=\"4\"",
    fixed = TRUE
  )
  # LaTeX: a table-width closing \rule above the footnote.
  expect_match(emit_read(spec, ".tex", "latex"), "\\rule{", fixed = TRUE)
})

test_that("empty-state honours a custom bottomrule width + colour (rules knob)", {
  spec <- mk_empty(
    rules = list(bottomrule = brdr("thick", color = "#FF0000"))
  )
  # RTF: thick = 1.5pt = \brdrw30 on the footer closer.
  expect_match(
    emit_read(spec, ".rtf"),
    "\\clbrdrt\\brdrs\\brdrw30",
    fixed = TRUE
  )
  # DOCX: 1.5pt = sz=12, red, on the footer rule table.
  expect_match(
    emit_read(spec, ".docx"),
    "<w:top w:space=\"0\" w:val=\"single\" w:sz=\"12\" w:color=\"FF0000\"/>",
    fixed = TRUE
  )
  # LaTeX: 1.5pt rule in the red colour.
  tex <- emit_read(spec, ".tex", "latex")
  expect_match(tex, "\\rule{", fixed = TRUE)
  expect_match(tex, "{1.5pt}", fixed = TRUE)
  expect_match(tex, "FF0000", fixed = TRUE)
})

test_that("empty-state honours bottomrule = 'none' (drops the closer)", {
  # The header band keeps its own top rule, so assert the closer specifically
  # disappears: one fewer top-border on RTF / DOCX, and no LaTeX \rule at all.
  rtf_d <- emit_read(mk_empty(), ".rtf")
  rtf_n <- emit_read(mk_empty(rules = list(bottomrule = "none")), ".rtf")
  expect_lt(
    n_match(rtf_n, "\\clbrdrt\\brdrs"),
    n_match(rtf_d, "\\clbrdrt\\brdrs")
  )

  docx_d <- emit_read(mk_empty(), ".docx")
  docx_n <- emit_read(mk_empty(rules = list(bottomrule = "none")), ".docx")
  expect_lt(
    n_match(docx_n, "<w:top w:space=\"0\" w:val=\"single\""),
    n_match(docx_d, "<w:top w:space=\"0\" w:val=\"single\"")
  )

  expect_no_match(
    emit_read(mk_empty(rules = list(bottomrule = "none")), ".tex", "latex"),
    "\\rule{",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Alignment — empty_halign / empty_valign place the message
# ---------------------------------------------------------------------

test_that("empty-state honours empty_halign across backends", {
  spec <- mk_empty(empty_halign = "left")
  expect_match(emit_read(spec, ".rtf"), "\\ql No data", fixed = TRUE)
  expect_match(
    emit_read(spec, ".docx"),
    "<w:jc w:val=\"left\"/>",
    fixed = TRUE
  )
  expect_match(
    emit_read(spec, ".tex", "latex"),
    "\\raggedright No data",
    fixed = TRUE
  )
})

test_that("empty_valign maps to native section alignment (top / middle / bottom)", {
  # RTF section control words.
  expect_match(
    emit_read(mk_empty(empty_valign = "top"), ".rtf"),
    "\\vertalt",
    fixed = TRUE
  )
  expect_match(
    emit_read(mk_empty(empty_valign = "middle"), ".rtf"),
    "\\vertalc",
    fixed = TRUE
  )
  expect_match(
    emit_read(mk_empty(empty_valign = "bottom"), ".rtf"),
    "\\vertalb",
    fixed = TRUE
  )
  # DOCX section <w:vAlign>.
  expect_match(
    emit_read(mk_empty(empty_valign = "top"), ".docx"),
    "<w:vAlign w:val=\"top\"/>",
    fixed = TRUE
  )
  expect_match(
    emit_read(mk_empty(empty_valign = "bottom"), ".docx"),
    "<w:vAlign w:val=\"bottom\"/>",
    fixed = TRUE
  )
})

test_that("empty_valign is honoured on LaTeX via \\vfill placement", {
  # top: message rides the top (message line then \vfill); middle (default)
  # centres it (\vfill message \vfill).
  top <- strsplit(
    emit_read(mk_empty(empty_valign = "top"), ".tex", "latex"),
    "\n"
  )[[1L]]
  i <- grep("No data", top, fixed = TRUE)[[1L]]
  expect_match(top[[i + 1L]], "\\vfill", fixed = TRUE)
  mid <- strsplit(
    emit_read(mk_empty(empty_valign = "middle"), ".tex", "latex"),
    "\n"
  )[[1L]]
  j <- grep("No data", mid, fixed = TRUE)[[1L]]
  expect_match(mid[[j - 1L]], "\\vfill", fixed = TRUE)
  expect_match(mid[[j + 1L]], "\\vfill", fixed = TRUE)
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
# Spacing — the title spacing gap reserves more room in the header chrome
# ---------------------------------------------------------------------

test_that("empty-state honours the title spacing gap", {
  # A larger above-title gap injects more blank \trhdr rows into the header
  # chrome table, raising the total \row count.
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
# Per-subgroup — an empty crossing between data crossings renders as its own
# centred empty section, with its own header / footer parts
# ---------------------------------------------------------------------

test_that("per-subgroup empty crossing renders one centred empty section", {
  spec <- mk_empty_subgroup()
  # Exactly one empty crossing -> one empty page in the grid.
  g <- as_grid(spec)
  n_empty <- sum(vapply(
    g@pages,
    function(p) isTRUE(p$is_empty_page),
    logical(1L)
  ))
  expect_equal(n_empty, 1L)

  # DOCX: one empty section -> one header / footer empty part + one centring
  # vAlign; the data sections are unaffected.
  f <- withr::local_tempfile(fileext = ".docx")
  emit(spec, f)
  ex <- withr::local_tempdir()
  utils::unzip(f, exdir = ex)
  files <- list.files(file.path(ex, "word"))
  expect_true("header02.xml" %in% files)
  expect_true("footer02.xml" %in% files)
  doc <- paste(
    readLines(file.path(ex, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_equal(n_match(doc, "<w:vAlign w:val=\"center\"/>"), 1L)
  expect_match(doc, "No data here.", fixed = TRUE)

  # RTF: the empty crossing is its own \vertalc section; the message appears.
  rtf <- emit_read(spec, ".rtf")
  expect_match(rtf, "\\vertalc", fixed = TRUE)
  expect_match(rtf, "No data here.", fixed = TRUE)
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
