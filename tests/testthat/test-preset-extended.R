# test-preset-extended.R — Phase 6 additions to preset_spec: the
# four named-list knobs (borders / fonts / colors / padding), the
# template arg on preset() / set_preset(), and shallow-merge
# semantics across calls.

# ---------------------------------------------------------------------
# borders / fonts / colors / padding validators
# ---------------------------------------------------------------------

test_that("preset_spec accepts well-formed borders/fonts/colors/padding", {
  p <- preset_spec(
    borders = list(
      outer = brdr("medium"),
      body_rows = brdr("hairline", "dotted")
    ),
    fonts = list(
      body = list(family = "Inter", size = 10, weight = "normal")
    ),
    colors = list(
      border = "#212529",
      text = "#000000"
    ),
    padding = list(
      body = 3,
      titles = list(top = 2, bottom = 2)
    )
  )
  expect_identical(p@borders$outer$style, "solid")
  expect_identical(p@fonts$body$family, "Inter")
  expect_identical(p@colors$border, "#212529")
  expect_identical(p@padding$body, 3)
})

test_that("preset_spec rejects unknown border region", {
  expect_error(preset_spec(borders = list(diagonal = brdr())))
})

test_that("preset_spec rejects non-brdr border value", {
  expect_error(preset_spec(borders = list(outer = "not a brdr")))
})

test_that("preset_spec accepts 'none' as clear sentinel on borders", {
  p <- preset_spec(borders = list(outer = "none"))
  expect_identical(p@borders$outer, "none")
})

test_that("preset_spec rejects unknown font surface", {
  expect_error(preset_spec(fonts = list(legend = list(size = 9))))
})

test_that("preset_spec rejects unknown font sub-key", {
  expect_error(preset_spec(fonts = list(body = list(typeface = "Inter"))))
})

test_that("preset_spec rejects non-positive font size", {
  expect_error(preset_spec(fonts = list(body = list(size = -1))))
})

test_that("preset_spec rejects unknown color token", {
  expect_error(preset_spec(colors = list(neon = "#ff00ff")))
})

test_that("preset_spec rejects unknown padding surface", {
  expect_error(preset_spec(padding = list(legend = 3)))
})

test_that("preset_spec rejects negative padding", {
  expect_error(preset_spec(padding = list(body = -1)))
})

test_that("preset_spec rejects bad padding side", {
  expect_error(preset_spec(padding = list(body = list(diagonal = 1))))
})

# ---------------------------------------------------------------------
# Shallow-merge across preset() calls
# ---------------------------------------------------------------------

test_that("preset() shallow-merges borders across calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("thick"))) |>
    preset(borders = list(body_rows = brdr("hairline")))
  bs <- spec@preset@borders
  expect_identical(bs$outer$width, 1.5)
  expect_identical(bs$body_rows$width, 0.25)
})

test_that("preset() shallow-merges fonts and colors and padding", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      fonts = list(body = list(family = "Inter")),
      colors = list(border = "#212529"),
      padding = list(body = 3)
    ) |>
    preset(
      fonts = list(header = list(size = 11)),
      colors = list(text = "#000000"),
      padding = list(header = 4)
    )
  p <- spec@preset
  expect_identical(p@fonts$body$family, "Inter")
  expect_identical(p@fonts$header$size, 11)
  expect_identical(p@colors$border, "#212529")
  expect_identical(p@colors$text, "#000000")
  expect_identical(p@padding$body, 3)
  expect_identical(p@padding$header, 4)
})

# ---------------------------------------------------------------------
# template arg
# ---------------------------------------------------------------------

test_that("preset(template = preset_spec(...)) applies non-default knobs", {
  tmpl <- preset_spec(
    borders = list(outer = brdr("thick")),
    fonts = list(body = list(family = "Inter")),
    font_size = 8
  )
  spec <- tabular(data.frame(x = 1)) |>
    preset(template = tmpl)
  p <- spec@preset
  expect_identical(p@borders$outer$width, 1.5)
  expect_identical(p@fonts$body$family, "Inter")
  expect_identical(p@font_size, 8)
})

test_that("preset(template = ..., scalar = ...) lets explicit kwargs win", {
  tmpl <- preset_spec(font_size = 8)
  spec <- tabular(data.frame(x = 1)) |>
    preset(template = tmpl, font_size = 11)
  expect_identical(spec@preset@font_size, 11)
})

test_that("preset(template = ...) shallow-merges template borders with later call", {
  tmpl <- preset_spec(
    borders = list(outer = brdr("thick"), body_rows = brdr("thin"))
  )
  spec <- tabular(data.frame(x = 1)) |>
    preset(template = tmpl) |>
    preset(borders = list(body_rows = brdr("hairline", "dashed")))
  bs <- spec@preset@borders
  expect_identical(bs$outer$width, 1.5)
  expect_identical(bs$body_rows$style, "dashed")
  expect_identical(bs$body_rows$width, 0.25)
})

test_that("preset(template = NULL) is the same as no template", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(font_size = 10, template = NULL)
  expect_identical(spec@preset@font_size, 10)
})

test_that("preset(template = ...) rejects non-preset input", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(template = "not a preset"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# set_preset(template = ...)
# ---------------------------------------------------------------------

test_that("set_preset(template = ...) feeds the session default", {
  withr::defer(set_preset(reset = TRUE))
  set_preset(template = preset_spec(font_size = 7))
  expect_identical(get_preset()@font_size, 7)
})

# ---------------------------------------------------------------------
# .extract_template_knobs filters out factory defaults
# ---------------------------------------------------------------------

test_that(".extract_template_knobs drops factory-default knobs", {
  # An empty template returns nothing.
  out <- tabular:::.extract_template_knobs(
    preset_spec(),
    call = environment()
  )
  expect_identical(length(out), 0L)
})

test_that(".extract_template_knobs picks up deliberate overrides only", {
  tmpl <- preset_spec(font_size = 8, borders = list(outer = brdr()))
  out <- tabular:::.extract_template_knobs(tmpl, call = environment())
  expect_named(out, c("font_size", "borders"))
})

# ---------------------------------------------------------------------
# engine_borders -> per-cell stamping
# ---------------------------------------------------------------------

test_that("engine_borders stamps outer borders on body cells", {
  spec <- tabular(data.frame(x = 1, y = 2)) |>
    preset(borders = list(outer = brdr("thin", "solid", "#000")))
  grid <- as_grid(spec)
  page1 <- grid@pages[[1]]
  cs <- page1$cells_style
  # Row 1 cell 1: top + left + bottom + right all set (single row + single col -> outer covers all sides on the one cell of each visible col? actually outer_left only on first col, outer_right only on last col)
  c1 <- cs[[1, "x"]]
  c2 <- cs[[1, "y"]]
  expect_identical(c1@border_top_style, "solid")
  expect_identical(c1@border_bottom_style, "solid")
  expect_identical(c1@border_left_style, "solid")
  expect_true(is.na(c1@border_right_style))
  expect_identical(c2@border_right_style, "solid")
  expect_true(is.na(c2@border_left_style))
})

test_that("engine_borders stamps body_rows top between rows", {
  spec <- tabular(data.frame(x = c(1, 2, 3))) |>
    preset(borders = list(body_rows = brdr("hairline", "dotted")))
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  # Row 1 has no body_rows border (first row); rows 2..3 have top.
  expect_true(is.na(cs[[1, "x"]]@border_top_style))
  expect_identical(cs[[2, "x"]]@border_top_style, "dotted")
  expect_identical(cs[[3, "x"]]@border_top_style, "dotted")
})

test_that("engine_borders 'none' value clears the cell side", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    preset(borders = list(outer = brdr(), outer_right = "none"))
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  # outer_right cleared -> last col right side carries the
  # explicit "none" sentinel.
  expect_identical(cs[[1, "x"]]@border_right_style, "none")
})

test_that("engine_borders skips cells touched by a predicate border", {
  # Predicate border explicit -> survives region overlay.
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style(
      where = x == 1,
      border_top_style = "dashed",
      .scope = "row"
    ) |>
    preset(borders = list(outer = brdr("medium", "solid")))
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  # Row 1 carries the predicate's "dashed" top; outer_top NOT applied.
  expect_identical(cs[[1, "x"]]@border_top_style, "dashed")
})

# ---------------------------------------------------------------------
# Backend smoke
# ---------------------------------------------------------------------

test_that("preset@borders surfaces in HTML inline style", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("medium", "dashed", "#abcdef")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("border-top: 1pt dashed #abcdef;", txt, fixed = TRUE))
})

test_that("preset@borders surfaces in DOCX OOXML", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("medium")))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # Medium width = 1pt -> 8 eighths
  expect_true(grepl("w:val=\"single\" w:sz=\"8\"", doc, fixed = TRUE))
})

test_that("preset@borders surfaces in RTF", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("medium", "dashed")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\brdrdash\\\\brdrw20", txt))
})

test_that("preset@borders surfaces in LaTeX tabularray directives", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    preset(
      borders = list(
        outer = brdr("medium"),
        body_rows = brdr("hairline", "dotted")
      )
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("hline{2}={1pt, solid}", txt, fixed = TRUE))
  expect_true(grepl("vline{1}={1pt, solid}", txt, fixed = TRUE))
})
