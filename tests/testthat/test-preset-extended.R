# test-preset-extended.R — coverage for the five lowered named-list
# knobs (borders / fonts / colors / padding / alignment), the
# template arg on preset() / set_preset(), and end-to-end emission
# through each backend.
#
# After the Task 4/5 slot cut, every named-list knob enters through
# `preset()` / `set_preset()` and lowers to a `style_layer` on
# `preset@style` via `.preset_args_to_layers()`. There is no slot
# on `preset_spec` to inspect — the layer cascade is the source of
# truth, consumed by engine_style / engine_borders / engine_chrome_borders
# at resolve time.

# ---------------------------------------------------------------------
# preset() shape validators (call-time, see .validate_lowered_knobs)
# ---------------------------------------------------------------------

test_that("preset() accepts well-formed borders/fonts/colors/padding", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      borders = list(
        outer = brdr("medium"),
        body_rows = brdr("hairline", "dotted")
      ),
      fonts = list(
        body = list(family = "Inter", size = 10, weight = "normal")
      ),
      colors = list(text = "#000000"),
      padding = list(body = 3)
    )
  expect_true(is_preset_spec(spec@preset))
  expect_true(length(spec@preset@style) > 0L)
})

test_that("preset_spec() rejects direct named-list arguments (slot cut)", {
  expect_error(
    suppressWarnings(preset_spec(borders = list(outer = brdr()))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(fonts = list(body = list(size = 9)))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(colors = list(text = "#000"))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(padding = list(body = 3))),
    "unused argument"
  )
})

test_that("preset() rejects unknown border region", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(borders = list(diagonal = brdr())),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-brdr border value", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(borders = list(outer = "not a brdr")),
    class = "tabular_error_input"
  )
})

test_that("preset() accepts 'none' as clear sentinel on borders", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = "none"))
  expect_true(is_preset_spec(spec@preset))
})

test_that("preset() rejects unknown font surface", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(legend = list(size = 9))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown font sub-key", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(body = list(typeface = "Inter"))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-positive font size", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(body = list(size = -1))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown color token", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(colors = list(neon = "#ff00ff")),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects dropped color tokens (border / border_muted / text_muted)", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(colors = list(border = "#212529")),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(colors = list(border_muted = "#dee2e6")),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(colors = list(text_muted = "#6c757d")),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown padding surface", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(padding = list(legend = 3)),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects negative padding", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(padding = list(body = -1)),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects bad padding side", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(padding = list(body = list(diagonal = 1))),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Successive preset() calls — layer-append (last-write wins per
# attribute at the cell)
# ---------------------------------------------------------------------

test_that("preset() appends border layers across successive calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("thick"))) |>
    preset(borders = list(body_rows = brdr("hairline")))
  # 4 outer-side layers + 1 rows layer = 5 layers total.
  expect_length(spec@preset@style, 5L)
})

test_that("preset() appends font / color / padding layers across calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      fonts = list(body = list(family = "Inter")),
      colors = list(text = "#000000"),
      padding = list(body = 3)
    ) |>
    preset(
      fonts = list(header = list(size = 11)),
      colors = list(background = "#eee"),
      padding = list(header = 4)
    )
  # First call: 1 font family layer (body) + 1 color text layer (body)
  # + 1 padding body layer = 3 layers. Second call: 1 font size layer
  # (header) + 1 color background layer (body) + 1 padding header
  # layer = 3 layers. Total: 6 layers.
  expect_length(spec@preset@style, 6L)
})

# ---------------------------------------------------------------------
# template arg
# ---------------------------------------------------------------------

test_that("preset(.template = preset_spec(...)) applies non-default scalar knobs", {
  tmpl <- preset_spec(font_size = 8)
  spec <- tabular(data.frame(x = 1)) |>
    preset(.template = tmpl)
  expect_identical(spec@preset@font_size, 8)
})

test_that("preset(.template = ..., scalar = ...) lets explicit kwargs win", {
  tmpl <- preset_spec(font_size = 8)
  spec <- tabular(data.frame(x = 1)) |>
    preset(.template = tmpl, font_size = 11)
  expect_identical(spec@preset@font_size, 11)
})

test_that("preset(.template = ...) propagates template @style layers", {
  # The template's lowered layers (set via the template's own
  # preset() calls) carry through.
  tmpl <- tabular(data.frame(z = 1)) |>
    preset(borders = list(outer = brdr("thick")))
  template_preset <- tmpl@preset
  spec <- tabular(data.frame(x = 1)) |>
    preset(.template = template_preset) |>
    preset(borders = list(body_rows = brdr("hairline")))
  # Template's 4 outer-side layers + later body_rows layer = 5 total.
  expect_length(spec@preset@style, 5L)
})

test_that("preset(.template = NULL) is the same as no template", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(font_size = 10, .template = NULL)
  expect_identical(spec@preset@font_size, 10)
})

test_that("preset(.template = ...) rejects non-preset input", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(.template = "not a preset"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# set_preset(.template = ...)
# ---------------------------------------------------------------------

test_that("set_preset(.template = ...) feeds the session default", {
  withr::defer(set_preset(.reset = TRUE))
  set_preset(.template = preset_spec(font_size = 7))
  expect_identical(get_preset()@font_size, 7)
})

# ---------------------------------------------------------------------
# .extract_template_knobs filters out factory defaults
# ---------------------------------------------------------------------

test_that(".extract_template_knobs drops factory-default knobs", {
  out <- tabular:::.extract_template_knobs(
    preset_spec(),
    call = environment()
  )
  expect_identical(length(out), 0L)
})

test_that(".extract_template_knobs picks up deliberate scalar overrides only", {
  tmpl <- preset_spec(font_size = 8, paper_size = "a4")
  out <- tabular:::.extract_template_knobs(tmpl, call = environment())
  expect_setequal(names(out), c("font_size", "paper_size"))
})

# ---------------------------------------------------------------------
# engine_borders — body-region layer stamping onto cells_style
# ---------------------------------------------------------------------

test_that("engine_borders stamps outer borders on body cells", {
  spec <- tabular(data.frame(x = 1, y = 2)) |>
    preset(borders = list(outer = brdr("thin", "solid", "#000")))
  grid <- as_grid(spec)
  page1 <- grid@pages[[1]]
  cs <- page1$cells_style
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
  expect_true(is.na(cs[[1, "x"]]@border_top_style))
  expect_identical(cs[[2, "x"]]@border_top_style, "dotted")
  expect_identical(cs[[3, "x"]]@border_top_style, "dotted")
})

test_that("engine_borders 'none' value clears the cell side", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    preset(borders = list(outer = brdr(), outer_right = "none"))
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  expect_identical(cs[[1, "x"]]@border_right_style, "none")
})

# ---------------------------------------------------------------------
# Backend smoke — each lowered knob produces a visible output token
# ---------------------------------------------------------------------

test_that("preset(borders) surfaces in HTML inline style", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("medium", "dashed", "#abcdef")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("border-top: 1pt dashed #abcdef;", txt, fixed = TRUE))
})

test_that("preset(borders) surfaces in DOCX OOXML", {
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
  expect_true(grepl("w:val=\"single\" w:sz=\"8\"", doc, fixed = TRUE))
})

test_that("preset(borders) surfaces in RTF", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(borders = list(outer = brdr("medium", "dashed")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\brdrdash\\\\brdrw20", txt))
})

test_that("preset(borders) surfaces in LaTeX tabularray directives", {
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
# Shape-validator helpers — direct-call coverage for each branch
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
# engine_borders — early-return guards + visibility-aware stamping
# ---------------------------------------------------------------------

test_that("engine_borders short-circuits on non-matrix cells_style", {
  spec <- tabular(data.frame(x = 1))
  expect_null(tabular:::engine_borders(spec, NULL))
  expect_identical(
    tabular:::engine_borders(spec, "not a matrix"),
    "not a matrix"
  )
})

test_that("engine_borders short-circuits when no borders are set", {
  spec <- tabular(data.frame(x = 1))
  m <- matrix(
    list(style_node()),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
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

# ---------------------------------------------------------------------
# Effective font helpers — survive as table-wide fallbacks
# ---------------------------------------------------------------------

test_that(".effective_font_family reads the preset_spec scalar slot", {
  expect_identical(
    tabular:::.effective_font_family(preset_spec(font_family = "Inter")),
    "Inter"
  )
  # NULL falls back to factory default.
  expect_identical(
    tabular:::.effective_font_family(NULL),
    preset_spec()@font_family
  )
})

test_that(".effective_font_size reads the preset_spec scalar slot", {
  expect_identical(
    tabular:::.effective_font_size(preset_spec(font_size = 8)),
    8
  )
  expect_identical(
    tabular:::.effective_font_size(NULL),
    preset_spec()@font_size
  )
})

# ---------------------------------------------------------------------
# Backend smoke — each lowered knob produces a visible token
# ---------------------------------------------------------------------

test_that("HTML emit consumes preset(fonts) family", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Surface-specific fonts now ride on cells_body() layer stamps, so
  # the per-cell <td> carries `font-family: Inter` in inline style.
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

test_that("HTML emit per-cell color stamp for preset(colors = text)", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Per-cell inline style carries color.
  expect_true(grepl("color: #ff0000", txt, fixed = TRUE))
})

test_that("HTML emit per-cell padding stamp for preset(padding = body)", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("padding: 5pt", txt, fixed = TRUE))
})

test_that("DOCX emit consumes preset(colors = text) on body cells", {
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

test_that("DOCX emit consumes preset(padding = body) via <w:tcMar>", {
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

test_that("RTF emit consumes preset(fonts = body family) via the font table", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

test_that("RTF emit consumes preset(colors = text) via colortbl + cf token", {
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

test_that("RTF emit consumes preset(padding = body) via \\trgaph", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # 5pt -> 100 twips on the representative body cell.
  expect_true(grepl("\\trowd\\trgaph100", txt, fixed = TRUE))
})

test_that("LaTeX emit drops table-wide \\definecolor + AtBeginDocument (slot cut)", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(text = "#ff0000"))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Per-cell color still surfaces via cells_style stamp.
  expect_false(grepl(
    "\\definecolor{tabular_text}",
    txt,
    fixed = TRUE
  ))
  expect_false(grepl(
    "\\AtBeginDocument{\\color{tabular_text}}",
    txt,
    fixed = TRUE
  ))
  # The per-cell `\SetCell{...}` carries the color triple.
  expect_true(
    grepl("FF0000", txt, ignore.case = TRUE) ||
      grepl("ff0000", txt, ignore.case = TRUE)
  )
})

test_that("LaTeX emit consumes preset(padding = body) via tabularray rowsep", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(padding = list(body = 5))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("rowsep=5pt", txt, fixed = TRUE))
})

test_that("LaTeX emit consumes preset(fonts = body family) in the font preamble", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(fonts = list(body = list(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Coverage — preset_spec validator branches that earlier tests didn't
# trigger (chrome_onscreen, margin parse error).
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
# routes through `style(.at = cells_title(), blank_above = N)`; body
# pad is a hardcoded backend constant (0 / 0).
#
# preset_spec@alignment / @borders / @fonts / @colors / @padding
# slots were dropped in the Task 4/5 cut. The corresponding shape
# validators run at preset() / set_preset() call time via
# `.validate_lowered_knobs()`; the slot-level validator branches
# no longer exist.
