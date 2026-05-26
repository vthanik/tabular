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

test_that(".effective_border with legacy bool TRUE returns solid 0.5pt default", {
  sn <- style_node(rule_above = TRUE)
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "solid")
  expect_identical(brd$width, 0.5)
  expect_identical(brd$color, "currentColor")
})

test_that(".effective_border with explicit triple overrides legacy bool", {
  sn <- style_node(
    rule_above = TRUE,
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
  expect_identical(brd$color, "currentColor")
})

test_that(".effective_border explicit 'none' returns clear sentinel", {
  sn <- style_node(border_top_style = "none")
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "none")
})

test_that(".effective_border explicit 'none' overrides legacy bool", {
  sn <- style_node(rule_above = TRUE, border_top_style = "none")
  brd <- tabular:::.effective_border("top", sn)
  expect_identical(brd$style, "none")
})

test_that(".effective_border maps left/right legacy bools to the right side", {
  sn <- style_node(border_left = TRUE)
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
  expect_true(tabular:::.cell_has_any_border(style_node(rule_above = TRUE)))
  expect_false(tabular:::.cell_has_any_border(NULL))
})

test_that(".effective_borders returns the 4-slot map", {
  brds <- tabular:::.effective_borders(style_node(rule_above = TRUE))
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

test_that("DOCX legacy rule_above retains back-compat single border", {
  spec <- tabular(data.frame(x = 1L)) |>
    style(rule_above = TRUE, .at = cells_body(where = TRUE))
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
      rule_above = TRUE,
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
  expect_false(grepl("<w:top ", doc, fixed = TRUE))
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
  expect_true(grepl(
    "border-bottom: 1pt dashed currentColor;",
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
  sn <- style_node(rule_above = TRUE, border_top_style = "none")
  out <- tabular:::.html_cell_border_style_attr(sn)
  expect_true(grepl("border-top: none;", out, fixed = TRUE))
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
  expect_true(grepl(
    "style=\"border-left: 1pt solid #123456;\"",
    txt,
    fixed = TRUE
  ))
})
