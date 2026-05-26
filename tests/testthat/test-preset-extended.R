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

# ---------------------------------------------------------------------
# Defensive branches in preset_validators.R — direct unit tests on the
# shape-error helpers. Some branches are unreachable through the S7
# `class_list` gate (non-list inputs); direct calls exercise them as
# part of the helper's standalone contract.
# ---------------------------------------------------------------------

test_that(".preset_borders_shape_error rejects non-list and unnamed entries", {
  expect_match(
    tabular:::.preset_borders_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_borders_shape_error(list(brdr())),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_borders_shape_error(list(outer = brdr(), brdr())),
    "must all be named"
  )
})

test_that(".preset_borders_shape_error accepts NULL values and bare triples", {
  expect_null(tabular:::.preset_borders_shape_error(list(outer = NULL)))
  expect_null(
    tabular:::.preset_borders_shape_error(
      list(outer = list(style = "dashed", width = 1, color = "#000"))
    )
  )
})

test_that(".preset_fonts_shape_error rejects non-list and unnamed entries", {
  expect_match(
    tabular:::.preset_fonts_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(list(size = 9))),
    "must all be named"
  )
})

test_that(".preset_fonts_shape_error accepts NULL surface and rejects non-list spec", {
  expect_null(tabular:::.preset_fonts_shape_error(list(body = NULL)))
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = "Inter")),
    "must be a named list with any of family / size / weight"
  )
})

test_that(".preset_fonts_shape_error rejects unnamed sub-keys and bad family/weight", {
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = list("Inter", size = 9))),
    "entries must all be named"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(
      body = list(family = NA_character_)
    )),
    "family must be a non-NA character"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = list(weight = 9))),
    "weight must be a single character"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(
      body = list(weight = NA_character_)
    )),
    "weight must be a single character"
  )
})

test_that(".preset_colors_shape_error rejects non-list and unnamed entries", {
  expect_match(
    tabular:::.preset_colors_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list("red")),
    "must all be named"
  )
})

test_that(".preset_colors_shape_error accepts NULL values and rejects bad strings", {
  expect_null(tabular:::.preset_colors_shape_error(list(text = NULL)))
  expect_match(
    tabular:::.preset_colors_shape_error(list(text = 1)),
    "single non-empty character"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(text = NA_character_)),
    "single non-empty character"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(text = "")),
    "single non-empty character"
  )
})

test_that(".preset_padding_shape_error rejects non-list and unnamed entries", {
  expect_match(
    tabular:::.preset_padding_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(3)),
    "must all be named"
  )
})

test_that(".preset_padding_shape_error accepts NULL and rejects bad side specs", {
  expect_null(tabular:::.preset_padding_shape_error(list(body = NULL)))
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = list(3, 4))),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = list(top = NA_real_))),
    "must be a single non-negative numeric"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = list(top = -1))),
    "must be a single non-negative numeric"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = TRUE)),
    "non-negative numeric or a list"
  )
})

# ---------------------------------------------------------------------
# Defensive branches in engine_borders.R — direct unit tests on the
# internal helpers. Covers early-return guards, body_cols stamping,
# the body_top / body_bottom aliases, and the non-style_node coercion
# in .set_border_triple.
# ---------------------------------------------------------------------

test_that("engine_borders short-circuits on non-matrix cells_style", {
  spec <- tabular(data.frame(x = 1))
  expect_null(tabular:::engine_borders(spec, NULL))
  expect_identical(
    tabular:::engine_borders(spec, "not a matrix"),
    "not a matrix"
  )
})

test_that("engine_borders short-circuits when borders is empty", {
  spec <- tabular(data.frame(x = 1))
  m <- matrix(
    list(style_node()),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  # No preset@borders -> identity on the matrix.
  expect_identical(tabular:::engine_borders(spec, m), m)
})

test_that("engine_borders short-circuits on zero-row matrix", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr()))
  empty <- matrix(list(), nrow = 0L, ncol = 1L, dimnames = list(NULL, "x"))
  expect_identical(tabular:::engine_borders(spec, empty), empty)
})

test_that("engine_borders stamps body_cols left between visible columns", {
  spec <- tabular(data.frame(a = 1, b = 2, c = 3)) |>
    preset(borders = list(body_cols = brdr("thin", "solid", "#000")))
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  expect_true(is.na(cs[[1, "a"]]@border_left_style))
  expect_identical(cs[[1, "b"]]@border_left_style, "solid")
  expect_identical(cs[[1, "c"]]@border_left_style, "solid")
})

test_that(".resolve_border_regions maps body_top / body_bottom onto outer_top / outer_bottom", {
  out <- tabular:::.resolve_border_regions(list(
    body_top = brdr("medium", "dotted"),
    body_bottom = brdr("hairline")
  ))
  expect_identical(out$outer_top$style, "dotted")
  expect_identical(out$outer_bottom$style, "solid")
})

test_that(".visible_col_indices treats unknown col names as visible by default", {
  spec <- tabular(data.frame(x = 1, y = 2))
  idx <- tabular:::.visible_col_indices(spec, c("ghost", "x"))
  expect_identical(unname(idx), c(1L, 2L))
})

test_that(".visible_col_indices honours col_spec@visible", {
  spec <- tabular(data.frame(x = 1, y = 2)) |>
    cols(x = col_spec(visible = TRUE), y = col_spec(visible = FALSE))
  idx <- tabular:::.visible_col_indices(spec, c("x", "y"))
  expect_identical(unname(idx), 1L)
})

test_that("engine_borders short-circuits when no columns are visible", {
  spec <- tabular(data.frame(x = 1, y = 2)) |>
    cols(x = col_spec(visible = FALSE), y = col_spec(visible = FALSE)) |>
    preset(borders = list(outer = brdr()))
  m <- matrix(
    list(style_node(), style_node()),
    nrow = 1L,
    ncol = 2L,
    dimnames = list(NULL, c("x", "y"))
  )
  expect_identical(tabular:::engine_borders(spec, m), m)
})

test_that(".stamp_body_cols short-circuits with fewer than 2 visible cols", {
  m <- matrix(
    list(style_node()),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  out <- tabular:::.stamp_body_cols(
    m,
    visible_idx = 1L,
    triple = list(style = "solid", width = 1, color = "#000")
  )
  expect_identical(out, m)
})

test_that(".stamp_outer_edge short-circuits on empty matrix", {
  empty <- matrix(list(), nrow = 0L, ncol = 0L)
  out <- tabular:::.stamp_outer_edge(
    empty,
    visible_idx = integer(),
    side = "top",
    triple = list(style = "solid", width = 1, color = "#000")
  )
  expect_identical(out, empty)
})

# ---------------------------------------------------------------------
# preset@fonts / @colors / @padding flow through each backend
# (Pass B wiring). One proof per knob per backend confirms that
# setting a knob produces a visible output token.
# ---------------------------------------------------------------------

test_that(".effective_font_family overlays fonts$body$family on @font_family", {
  p <- preset_spec(
    font_family = "serif",
    fonts = list(body = list(family = "Inter"))
  )
  expect_identical(tabular:::.effective_font_family(p, "body"), "Inter")
  # Falls back when the surface key is absent.
  p2 <- preset_spec(font_family = "sans")
  expect_identical(tabular:::.effective_font_family(p2, "body"), "sans")
  # NULL-preset path returns the factory default font_family.
  expect_identical(
    tabular:::.effective_font_family(NULL, "body"),
    preset_spec()@font_family
  )
})

test_that(".effective_font_size overlays fonts$body$size on @font_size", {
  p <- preset_spec(
    font_size = 9,
    fonts = list(body = list(size = 8))
  )
  expect_identical(tabular:::.effective_font_size(p, "body"), 8)
  p2 <- preset_spec(font_size = 11)
  expect_identical(tabular:::.effective_font_size(p2, "body"), 11)
})

test_that(".effective_color returns NA when token is unset or preset is NULL", {
  p <- preset_spec(colors = list(text = "#ff0000"))
  expect_identical(tabular:::.effective_color(p, "text"), "#ff0000")
  expect_true(is.na(tabular:::.effective_color(p, "background")))
  expect_true(is.na(tabular:::.effective_color(NULL, "text")))
})

test_that(".effective_padding returns NULL when surface is unset or preset is NULL", {
  p <- preset_spec(padding = list(body = 5))
  expect_identical(tabular:::.effective_padding(p, "body"), 5)
  expect_null(tabular:::.effective_padding(p, "header"))
  expect_null(tabular:::.effective_padding(NULL, "body"))
})

test_that("HTML emit consumes preset@fonts$body$family", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Single-name family without spaces is emitted unquoted by
  # .html_quote_font; presence of the literal family name is the
  # wire check.
  expect_true(grepl("font-family: Inter", txt, fixed = TRUE))
})

test_that("HTML emit consumes preset@colors$text", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    ".tabular-table td { color: #ff0000; }",
    txt,
    fixed = TRUE
  ))
})

test_that("HTML emit consumes preset@padding$body", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    ".tabular-table tbody td { padding: 5pt; }",
    txt,
    fixed = TRUE
  ))
})

test_that("DOCX emit consumes preset@colors$text on body cells", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl("<w:color w:val=\"FF0000\"/>", doc, fixed = TRUE))
})

test_that("DOCX emit consumes preset@padding$body via <w:tcMar>", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl("<w:tcMar>", doc, fixed = TRUE))
  expect_true(grepl(
    "<w:top w:w=\"100\" w:type=\"dxa\"/>",
    doc,
    fixed = TRUE
  ))
})

test_that("RTF emit consumes preset@fonts$body$family via the font table", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\f0\\froman\\fprq2 Inter", txt, fixed = TRUE))
})

test_that("RTF emit consumes preset@colors$text via colortbl + cf token", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    "{\\colortbl;\\red255\\green0\\blue0;}",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl("\\cf1 ", txt, fixed = TRUE))
})

test_that("RTF emit consumes preset@padding$body via \\trgaph", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # 5pt -> 100 twips
  expect_true(grepl("\\trowd\\trgaph100", txt, fixed = TRUE))
})

test_that("LaTeX emit consumes preset@colors$text via \\definecolor", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    "\\definecolor{tabular_text}{HTML}{FF0000}",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl(
    "\\AtBeginDocument{\\color{tabular_text}}",
    txt,
    fixed = TRUE
  ))
})

test_that("LaTeX emit consumes preset@padding$body via tabularray rowsep", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("rowsep=5pt", txt, fixed = TRUE))
})

test_that("LaTeX emit consumes preset@fonts$body$family in the font preamble", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # .latex_font_lines routes any non-generic family through fontspec /
  # pdftex packages; presence of the literal family name is the wire
  # check.
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

test_that(".set_border_triple coerces non-style_node input via style_node()", {
  out <- tabular:::.set_border_triple(
    node = NULL,
    prop_style = "border_top_style",
    prop_width = "border_top_width",
    prop_color = "border_top_color",
    triple = list(style = "solid", width = 0.5, color = "#000")
  )
  expect_true(tabular:::is_style_node(out))
  expect_identical(out@border_top_style, "solid")
  expect_identical(out@border_top_width, 0.5)
  expect_identical(out@border_top_color, "#000")
})

# ---------------------------------------------------------------------
# Coverage — preset_spec validator branches that earlier tests didn't
# trigger (chrome_onscreen, paginate dimension parse, body_pad_top
# negative, margin parse error).
# ---------------------------------------------------------------------

test_that("preset_spec(chrome_onscreen = 'bogus') is rejected", {
  expect_error(
    tabular:::preset_spec(chrome_onscreen = "bogus"),
    regexp = "@chrome_onscreen"
  )
})

test_that("preset_spec(margins = c(1, 2, 3)) is rejected (length must be 1/2/4)", {
  expect_error(
    tabular:::preset_spec(margins = c(1, 2, 3)),
    regexp = "@margins"
  )
})

test_that("preset_spec(margins = '50%') is rejected (percent not allowed)", {
  expect_error(
    tabular:::preset_spec(margins = "50%")
  )
})

# Note: preset_spec@title_pad_* / @body_pad_* slots were dropped in
# v0.1.0; their validator branches no longer exist. Title pad now
# routes through `style(at = cells_title(), blank_above = N)`; body
# pad is a hardcoded backend constant (0 / 0).
