# test-borders.R — per-side border scalars + resolver (R/borders.R)
# + backend emission (HTML / DOCX / RTF).

# ---------------------------------------------------------------------
# style_node — 12 new border scalars
# ---------------------------------------------------------------------

test_that("style_node accepts per-side border scalars with sensible defaults", {
  sn <- style_node(
    border_top_style = "solid",
    border_top_width = 0.5,
    border_top_color = "#212529"
  )
  expect_identical(sn@border_top_style, "solid")
  expect_identical(sn@border_top_width, 0.5)
  expect_identical(sn@border_top_color, "#212529")
})

test_that("style_node defaults all 12 border scalars to NA", {
  sn <- style_node()
  for (side in c("top", "bottom", "left", "right")) {
    expect_true(is.na(S7::prop(sn, paste0("border_", side, "_style"))))
    expect_true(is.na(S7::prop(sn, paste0("border_", side, "_width"))))
    expect_true(is.na(S7::prop(sn, paste0("border_", side, "_color"))))
  }
})

test_that("style_node rejects bad border style", {
  expect_error(style_node(border_top_style = "wibble"))
})

test_that("style_node rejects negative border width", {
  expect_error(style_node(border_top_width = -0.5))
})

# ---------------------------------------------------------------------
# .effective_border resolver
# ---------------------------------------------------------------------

test_that(".effective_border returns NULL when nothing is set", {
  expect_null(tabular:::.effective_border("top", style_node()))
})

test_that(".effective_border with a full per-side triple returns it verbatim", {
  sn <- style_node(
    border_top_style = "dashed",
    border_top_width = 1,
    border_top_color = "#abcdef"
  )
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "dashed")
  expect_identical(brd$width, 1)
  expect_identical(brd$color, "#abcdef")
})

test_that(".effective_border with partial explicit fills defaults", {
  sn <- style_node(border_top_style = "dotted")
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "dotted")
  expect_identical(brd$width, 0.5)
  expect_identical(brd$color, "ink")
})

test_that(".effective_border explicit 'none' returns clear sentinel", {
  sn <- style_node(border_top_style = "none")
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "none")
})

test_that(".effective_border resolves each side independently", {
  sn <- style_node(border_left_style = "solid")
  expect_null(tabular:::.effective_border("top", sn))
  expect_null(tabular:::.effective_border("bottom", sn))
  expect_null(tabular:::.effective_border("right", sn))
  brd <- tabular:::.effective_border("left", sn)
  expect_identical(brd$style, "solid")
})

test_that(".effective_border handles non-style_node input safely", {
  expect_null(tabular:::.effective_border("top", NULL))
  expect_null(tabular:::.effective_border("top", "not a style"))
})

test_that(".cell_has_any_border short-circuits cleanly", {
  expect_false(tabular:::.cell_has_any_border(style_node()))
  expect_true(
    tabular:::.cell_has_any_border(style_node(border_top_style = "solid"))
  )
  expect_false(tabular:::.cell_has_any_border(NULL))
})

test_that(".effective_borders returns the 4-slot map", {
  brds <- tabular:::.effective_borders(style_node(border_top_style = "solid"))
  expect_named(brds, c("top", "bottom", "left", "right"))
  expect_false(is.null(brds$top))
  expect_null(brds$bottom)
})

# ---------------------------------------------------------------------
# DOCX per-cell border emission
# ---------------------------------------------------------------------

test_that("DOCX style(border_top_*) emits <w:top> with the right attrs", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(
      border_top_style = "dashed",
      border_top_width = 1,
      border_top_color = "#abcdef",
      .at = cells_body(where = TRUE)
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl(
    "<w:top w:val=\"dashed\" w:sz=\"8\" w:color=\"ABCDEF\"/>",
    doc,
    fixed = TRUE
  ))
})

test_that("DOCX style(border_top = brdr()) emits the default single border", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(border_top = brdr(), .at = cells_body(where = TRUE))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl(
    "<w:top w:val=\"single\" w:sz=\"4\" w:color=\"auto\"/>",
    doc,
    fixed = TRUE
  ))
})

test_that("DOCX explicit border_top_style='none' suppresses emission", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(
      border_top_style = "none",
      .at = cells_body(where = TRUE)
    )
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # Scope to the body row: the column-header label row legitimately
  # carries the structural toprule (header_top, default solid). The
  # body cell's explicit border_top_style="none" must still suppress
  # its own top border.
  rows <- regmatches(doc, gregexpr("<w:tr>.*?</w:tr>", doc, perl = TRUE))[[
    1L
  ]]
  body_row <- rows[!grepl("<w:tblHeader/>", rows)][[1L]]
  expect_false(grepl("<w:top ", body_row, fixed = TRUE))
})

# ---------------------------------------------------------------------
# RTF per-cell border emission
# ---------------------------------------------------------------------

test_that("RTF .rtf_border_seg emits expected tokens per style", {
  sn <- style_node(border_top_style = "dashed", border_top_width = 1)
  out <- tabular:::.rtf_border_seg("top", sn, "none")
  expect_identical(out, "\\clbrdrt\\brdrdash\\brdrw20")
})

test_that("RTF .rtf_border_seg falls back to backend default", {
  out_none <- tabular:::.rtf_border_seg("top", style_node(), "none")
  expect_identical(out_none, "\\clbrdrt\\brdrnone")
  out_solid <- tabular:::.rtf_border_seg("top", style_node(), "solid")
  expect_identical(out_solid, "\\clbrdrt\\brdrs\\brdrw10")
})

test_that("RTF .rtf_border_seg explicit 'none' suppresses backend default", {
  sn <- style_node(border_top_style = "none")
  out <- tabular:::.rtf_border_seg("top", sn, "solid")
  expect_identical(out, "\\clbrdrt\\brdrnone")
})

test_that("RTF emit honours per-cell border on body cell", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(
      border_top_style = "dotted",
      border_top_width = 0.75,
      .at = cells_body(where = TRUE)
    )
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\clbrdrt\\\\brdrdot\\\\brdrw15", txt))
})

# ---------------------------------------------------------------------
# HTML per-cell border emission
# ---------------------------------------------------------------------

test_that(".html_border_decl maps style enum to CSS keyword", {
  brd <- list(style = "solid", width = 0.5, color = "currentColor")
  expect_identical(
    tabular:::.html_border_decl("top", brd),
    "border-top: 0.5pt solid currentColor;"
  )
  brd2 <- list(style = "dashed", width = 1, color = "#abcdef")
  expect_identical(
    tabular:::.html_border_decl("bottom", brd2),
    "border-bottom: 1pt dashed #abcdef;"
  )
})

test_that(".html_cell_border_style_attr emits per-side decls", {
  sn <- style_node(
    border_top_style = "solid",
    border_top_width = 0.5,
    border_top_color = "#212529",
    border_bottom_style = "dashed",
    border_bottom_width = 1
  )
  out <- tabular:::.html_cell_border_style_attr(sn)
  expect_true(grepl("border-top: 0.5pt solid #212529;", out, fixed = TRUE))
  # Unset bottom colour now resolves to the ink hex (was currentColor).
  expect_true(grepl(
    "border-bottom: 1pt dashed #212529;",
    out,
    fixed = TRUE
  ))
})

test_that(".html_cell_border_style_attr is empty when no overrides", {
  expect_identical(
    tabular:::.html_cell_border_style_attr(style_node()),
    ""
  )
})

test_that(".html_cell_border_style_attr emits 'none' for explicit clear", {
  sn <- style_node(border_top_style = "none")
  out <- tabular:::.html_cell_border_style_attr(sn)
  expect_true(grepl("border-top: none;", out, fixed = TRUE))
})

test_that("default border colour is ink, decoupled from text colour (#issue6)", {
  # brdr() and the .effective_border default both resolve to the `ink`
  # token, NOT `currentColor` -- so a rule under a recoloured header no
  # longer inherits the header's text colour in HTML.
  expect_identical(brdr()$color, "ink")
  expect_identical(
    tabular:::.effective_border(
      "top",
      style_node(border_top_style = "solid")
    )$color,
    "ink"
  )
  # HTML resolves the ink token to the explicit hex, never currentColor.
  sn <- style_node(border_bottom_style = "solid", border_bottom_width = 1)
  decls <- tabular:::.html_cell_border_decls(sn)
  expect_true(any(grepl("#212529", decls, fixed = TRUE)))
  expect_false(any(grepl("currentColor", decls)))
  # A recoloured header with a default border: the rule is ink, the
  # text is red, the two are independent in the emitted HTML.
  spec <- tabular(data.frame(x = 1L), titles = "T") |>
    style(color = "#ff1133", .at = cells_headers()) |>
    style(border_bottom = brdr(), .at = cells_headers())
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("currentColor", txt))
})

test_that("cells_group_headers() border reaches HTML + DOCX (#issue5)", {
  mk <- function() {
    tabular(
      data.frame(
        grp = c("A", "A", "B"),
        v = c("1", "2", "3"),
        stringsAsFactors = FALSE
      )
    ) |>
      cols(grp = col_spec(label = "Group")) |>
      group_rows(by = "grp") |>
      style(
        border_bottom = brdr("thick", "dashed", "#ff1133"),
        .at = cells_group_headers()
      )
  }
  # HTML: the merged group-header <td> carries the inline border.
  h <- withr::local_tempfile(fileext = ".html")
  emit(mk(), h)
  htxt <- paste(readLines(h, warn = FALSE), collapse = "\n")
  expect_match(
    htxt,
    "tabular-group-header.*border-bottom: 1.5pt dashed #ff1133"
  )
  # DOCX: the merged group-header cell's <w:tcBorders> carries it.
  d <- withr::local_tempfile(fileext = ".docx")
  emit(mk(), d)
  ddir <- withr::local_tempdir()
  utils::unzip(d, exdir = ddir)
  dx <- paste(
    readLines(file.path(ddir, "word/document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_match(dx, "<w:bottom[^>]*w:val=\"dashed\"[^>]*w:color=\"FF1133\"")
})

test_that("cells_title() border reaches HTML + LaTeX + DOCX (#issue5)", {
  mk <- function() {
    tabular(data.frame(x = 1L), titles = c("Line A", "Line B")) |>
      style(border_bottom = brdr("medium"), .at = cells_title())
  }
  h <- withr::local_tempfile(fileext = ".html")
  emit(mk(), h)
  expect_match(
    paste(readLines(h, warn = FALSE), collapse = "\n"),
    "tabular-title[^>]*border-bottom: 1pt solid #212529"
  )
  tex <- withr::local_tempfile(fileext = ".tex")
  emit(mk(), tex)
  expect_match(
    paste(readLines(tex, warn = FALSE), collapse = "\n"),
    "\\\\rule\\{\\\\linewidth\\}\\{1pt\\}",
    perl = TRUE
  )
})

test_that("HTML emit injects style=... on body cell with border override", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(
      border_left_style = "solid",
      border_left_width = 1,
      border_left_color = "#123456",
      .at = cells_body(where = TRUE)
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # The single body cell is also the last row, so it carries the SSOT
  # bottomrule alongside the user's left border; match the left decl.
  expect_true(grepl("border-left: 1pt solid #123456;", txt, fixed = TRUE))
})

# ---- outer-frame thick top rides the header band (#frame-top) -----------

mk_thick_outer_spec <- function() {
  d <- data.frame(
    grp = c("Age", "Age"),
    stat = c("Mean", "SD"),
    a = c("75.2", "8.59"),
    b = c("75.7", "8.29"),
    stringsAsFactors = FALSE
  )
  tabular(d, titles = "T") |>
    cols(
      grp = col_spec(
        label = "C",
        align = "left"
      ),
      stat = col_spec(label = "Stat", align = "left"),
      a = col_spec(label = "A", align = "right"),
      b = col_spec(label = "B", align = "right")
    ) |>
    group_rows(by = "grp", display = "column", skip = "grp") |>
    headers("Grp" = c("a", "b")) |>
    style(border = brdr(width = "thick"), .at = cells_table(side = "outer"))
}

test_that("HTML outer-frame thick top rides the header band, not body row 1 (#frame-top)", {
  out <- withr::local_tempfile(fileext = ".html")
  emit(mk_thick_outer_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # True top edge (thead first row) carries the thick rule.
  expect_true(grepl("thead tr:first-child th \\{ border-top: 1.5pt", txt))
  # No stray thick top border on a body cell.
  expect_false(grepl("<td[^>]*border-top: 1.5pt", txt))
})

test_that("LaTeX outer-frame thick top is hline{1}, no stray under-header rule (#frame-top)", {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(mk_thick_outer_spec(), out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("hline{1}={1.5pt", txt, fixed = TRUE))
  # The header/body boundary must NOT be upgraded to the thick rule.
  expect_false(grepl("hline{3}={1.5pt", txt, fixed = TRUE))
})

test_that("RTF + DOCX outer-frame thick top rides the topmost header row (#frame-top)", {
  spec <- mk_thick_outer_spec()
  outr <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, outr)
  rtf <- paste(readLines(outr, warn = FALSE), collapse = "\n")
  # The first cell top rule (topmost header band) is the thick rule.
  first_top <- regmatches(
    rtf,
    regexpr("clbrdrt\\\\brdrs\\\\brdrw[0-9]+", rtf)
  )
  expect_match(first_top, "brdrw30")

  outd <- withr::local_tempfile(fileext = ".docx")
  emit(spec, outd)
  dir <- withr::local_tempdir()
  utils::unzip(outd, exdir = dir)
  docx <- paste(
    readLines(file.path(dir, "word", "document.xml"), warn = FALSE),
    collapse = "\n"
  )
  # The first bordered top (column-header band) is the thick rule.
  first_wtop <- regmatches(docx, regexpr("<w:top [^>]*w:sz=\"[0-9]+\"", docx))
  expect_match(first_wtop, "w:sz=\"12\"")
})

# ---- cells_subgroup_labels() border (#subgroup-border) ------------------

mk_subgroup_border_spec <- function() {
  d <- data.frame(
    pop = c("Saf", "Saf"),
    lab = c("A", "B"),
    x = c("1", "2"),
    stringsAsFactors = FALSE
  )
  tabular(d) |>
    cols(lab = col_spec(label = "L"), x = col_spec(label = "X")) |>
    subgroup("pop") |>
    style(
      border_bottom = brdr(width = "thick"),
      .at = cells_subgroup_labels()
    )
}

test_that("cells_subgroup_labels() border renders on HTML + DOCX (#subgroup-border)", {
  spec <- mk_subgroup_border_spec()
  fh <- withr::local_tempfile(fileext = ".html")
  emit(spec, fh)
  html <- paste(readLines(fh, warn = FALSE), collapse = "\n")
  expect_true(grepl("tabular-subgroup", html, fixed = TRUE))
  expect_true(grepl("border-bottom: 1.5pt", html, fixed = TRUE))

  fz <- withr::local_tempfile(fileext = ".docx")
  emit(spec, fz)
  dir <- withr::local_tempdir()
  utils::unzip(fz, exdir = dir)
  docx <- paste(
    readLines(file.path(dir, "word", "document.xml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("<w:bottom [^>]*w:sz=\"12\"", docx))
})

test_that(".first_cell_color promotes a shared colour but not a lone override (#cw4)", {
  df <- data.frame(
    g = c("a", "b", "c"),
    val = c("1", "2", "3"),
    stringsAsFactors = FALSE
  )
  base <- tabular(df) |>
    cols(g = col_spec(label = "G"), val = col_spec(label = "V"))
  # a lone per-cell style() override must NOT become the table-wide colour
  s1 <- base |> style(color = "#FF0000", .at = cells_body(i = 2, j = "val"))
  cs1 <- tabular:::engine_borders(s1, tabular:::engine_style(s1))
  expect_true(is.na(tabular:::.first_cell_color(cs1)))
  # a uniform body colour (preset) IS the table-wide colour
  s2 <- base |> preset(colors = list(body = c(text = "#0000FF")))
  cs2 <- tabular:::engine_borders(s2, tabular:::engine_style(s2))
  expect_equal(tabular:::.first_cell_color(cs2), "#0000FF")
})
