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

test_that("preset() accepts well-formed rules/fonts/colors/padding", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      rules = list(
        midrule = brdr("medium"),
        rowrule = brdr("hairline", "dotted")
      ),
      fonts = list(
        body = c(family = "Inter", size = 10, weight = "normal")
      ),
      colors = list(body = c(text = "#000000")),
      padding = list(body = 3)
    )
  expect_true(is_preset_spec(spec@preset))
  expect_true(length(spec@preset@style) > 0L)
})

test_that("preset_spec() rejects direct named-list arguments (slot cut)", {
  expect_error(
    suppressWarnings(preset_spec(rules = list(midrule = brdr()))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(fonts = list(body = list(size = 9)))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(colors = list(body = list(text = "#000")))),
    "unused argument"
  )
  expect_error(
    suppressWarnings(preset_spec(padding = list(body = 3))),
    "unused argument"
  )
})

test_that("preset() rejects unknown rule name", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(rules = list(diagonal = brdr())),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-brdr rule value", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(rules = list(midrule = "not a brdr")),
    class = "tabular_error_input"
  )
})

test_that("preset() accepts 'none' as clear sentinel on rules", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(rules = list(midrule = "none"))
  expect_true(is_preset_spec(spec@preset))
})

test_that("preset() rejects unknown font surface", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(legend = c(size = 9))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown font sub-key", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(body = c(typeface = "Inter"))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-positive font size", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(fonts = list(body = c(size = -1))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown color surface", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(colors = list(legend = c(text = "#ff00ff"))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unknown color token within a surface", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(colors = list(body = c(neon = "#ff00ff"))),
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
      preset(padding = list(body = c(diagonal = 1))),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects the legacy nested-list inner knob form (#knob-shape)", {
  tbl <- tabular(data.frame(x = 1))
  expect_error(
    preset(tbl, padding = list(body = list(top = 5))),
    class = "tabular_error_input"
  )
  expect_error(
    preset(tbl, colors = list(body = list(text = "#000"))),
    class = "tabular_error_input"
  )
  expect_error(
    preset(tbl, fonts = list(body = list(family = "Inter"))),
    class = "tabular_error_input"
  )
})

test_that("preset() accepts named-vector knob shapes incl. numeric font size (#knob-shape)", {
  tbl <- tabular(data.frame(x = 1))
  expect_silent(preset(tbl, padding = list(body = c(top = 5, bottom = 3))))
  expect_silent(
    preset(tbl, colors = list(body = c(text = "#000", background = "#fff")))
  )
  # fonts is the mixed-type knob: character size and numeric size both work.
  expect_silent(preset(
    tbl,
    fonts = list(body = c(family = "Inter", size = "9"))
  ))
  expect_silent(preset(tbl, fonts = list(body = c(size = 9))))
})

# ---------------------------------------------------------------------
# Successive preset() calls — layer-append (last-write wins per
# attribute at the cell)
# ---------------------------------------------------------------------

test_that("preset() rules knob lowers all nine rules per call", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(rules = list(midrule = brdr("thick")))
  # The rules knob fully specifies the nine-rule set every call.
  expect_length(spec@preset@style, 9L)
})

test_that("preset() appends font / color / padding layers across calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      fonts = list(body = c(family = "Inter")),
      colors = list(body = c(text = "#000000")),
      padding = list(body = 3)
    ) |>
    preset(
      fonts = list(header = c(size = 11)),
      colors = list(body = c(background = "#eee")),
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
  # preset() rules call) carry through.
  tmpl <- tabular(data.frame(z = 1)) |>
    preset(rules = list(midrule = brdr("thick")))
  template_preset <- tmpl@preset
  spec <- tabular(data.frame(x = 1)) |>
    preset(.template = template_preset) |>
    preset(rules = list(rowrule = brdr("hairline")))
  # Template's nine-rule layer set + the later nine-rule call = 18.
  expect_length(spec@preset@style, 18L)
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

test_that("engine_borders stamps outer bottom per-cell, top/L/R via manifest", {
  spec <- tabular(data.frame(x = 1, y = 2)) |>
    style(
      border = brdr("thin", "solid", "#000"),
      .at = cells_table(side = "outer")
    )
  grid <- as_grid(spec)
  page1 <- grid@pages[[1]]
  cs <- page1$cells_style
  c1 <- cs[[1, "x"]]
  c2 <- cs[[1, "y"]]
  # Bottom is stamped per-cell (last body row = table bottom).
  expect_identical(c1@border_bottom_style, "solid")
  # Top / left / right are structural (drawn by backends from the manifest
  # so the edges span the synthesised special rows + the header band),
  # not per-cell stamps.
  expect_true(is.na(c1@border_top_style))
  expect_true(is.na(c1@border_left_style))
  expect_true(is.na(c2@border_right_style))
  man <- tabular:::.body_border_manifest(spec)
  expect_identical(man$outer_top$style, "solid")
  expect_identical(man$outer_left$style, "solid")
  expect_identical(man$outer_right$style, "solid")
})

test_that("engine_borders stamps row separators top between rows", {
  spec <- tabular(data.frame(x = c(1, 2, 3))) |>
    style(
      border_top = brdr("hairline", "dotted"),
      .at = cells_table(side = "rows")
    )
  grid <- as_grid(spec)
  cs <- grid@pages[[1]]$cells_style
  expect_identical(cs[[2, "x"]]@border_top_style, "dotted")
  expect_identical(cs[[3, "x"]]@border_top_style, "dotted")
})

test_that("engine_borders 'none' clears the structural outer_right edge", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style(border = brdr(), .at = cells_table(side = "outer")) |>
    style(border_right = "none", .at = cells_table(side = "outer_right"))
  # The right edge is structural: the "none" clear lands in the manifest
  # (style "none" -> backends suppress emission). No per-cell stamp.
  man <- tabular:::.body_border_manifest(spec)
  expect_identical(man$outer_right$style, "none")
  cs <- as_grid(spec)@pages[[1]]$cells_style
  expect_true(is.na(cs[[1, "x"]]@border_right_style))
})

# ---------------------------------------------------------------------
# Backend smoke — each lowered knob produces a visible output token
# ---------------------------------------------------------------------

test_that("style(cells_table) borders surface in HTML inline style", {
  spec <- tabular(data.frame(x = 1)) |>
    style(
      border = brdr("medium", "dashed", "#abcdef"),
      .at = cells_table(side = "outer")
    )
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("border-top: 1pt dashed #abcdef;", txt, fixed = TRUE))
})

test_that("style(cells_table) borders surface in DOCX OOXML", {
  spec <- tabular(data.frame(x = 1)) |>
    style(border = brdr("medium"), .at = cells_table(side = "outer"))
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

test_that("style(cells_table) borders surface in RTF", {
  spec <- tabular(data.frame(x = 1)) |>
    style(
      border = brdr("medium", "dashed"),
      .at = cells_table(side = "outer")
    )
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\brdrdash\\\\brdrw20", txt))
})

test_that("style(cells_table) borders surface in LaTeX tabularray directives", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    style(border = brdr("medium"), .at = cells_table(side = "outer")) |>
    style(
      border_top = brdr("hairline", "dotted"),
      .at = cells_table(side = "rows")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("vline{1}={1pt, solid}", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Shape-validator helpers — direct-call coverage for each branch
# ---------------------------------------------------------------------

test_that(".preset_rules_shape_error rejects bad forms and unnamed entries", {
  expect_match(
    tabular:::.preset_rules_shape_error(42),
    "preset name, a single brdr"
  )
  expect_match(
    tabular:::.preset_rules_shape_error(list(brdr())),
    "must all be named"
  )
  expect_null(tabular:::.preset_rules_shape_error(list(toprule = brdr())))
})

test_that(".preset_rules_shape_error accepts string sugar, NULL, bare triples", {
  expect_null(tabular:::.preset_rules_shape_error("booktabs"))
  expect_null(tabular:::.preset_rules_shape_error(brdr()))
  expect_null(tabular:::.preset_rules_shape_error(list(midrule = NULL)))
  expect_null(
    tabular:::.preset_rules_shape_error(
      list(midrule = list(style = "dashed", width = 1, color = "#000"))
    )
  )
})

test_that(".preset_fonts_shape_error rejects non-list and unnamed entries", {
  expect_match(
    tabular:::.preset_fonts_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(c(size = "9"))),
    "must all be named"
  )
})

test_that(".preset_fonts_shape_error accepts NULL surface and rejects non-vector spec", {
  expect_null(tabular:::.preset_fonts_shape_error(list(body = NULL)))
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = list(family = "Inter"))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = "Inter")),
    "must be a named vector"
  )
})

test_that(".preset_fonts_shape_error rejects unknown name and bad family/size/weight", {
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = c(typeface = "Inter"))),
    "unknown name"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(
      body = c(family = NA_character_)
    )),
    "family must be a non-NA character"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = c(size = "huge"))),
    "size must be a single positive finite numeric"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(
      body = c(weight = NA_character_)
    )),
    "weight must be a single character"
  )
})

test_that(".preset_colors_shape_error rejects non-list, unnamed, unknown surface", {
  expect_match(
    tabular:::.preset_colors_shape_error("foo"),
    "must be a named list"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(c(text = "red"))),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(legend = c(text = "#000"))),
    "unknown surface"
  )
})

test_that(".preset_colors_shape_error accepts NULL surfaces and rejects bad tokens", {
  expect_null(tabular:::.preset_colors_shape_error(list(body = NULL)))
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = list(text = "#000"))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(
      body = c(text = NA_character_)
    )),
    "single non-empty character"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = c(neon = "#fff"))),
    "unknown name"
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
    tabular:::.preset_padding_shape_error(list(body = list(top = 3))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = c(top = NA_real_))),
    "must be a single non-negative numeric"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = c(top = -1))),
    "must be a single non-negative numeric"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = TRUE)),
    "non-negative numeric or a named vector"
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

test_that("engine_borders stamps the booktabs bottomrule by default", {
  # With no user rules, the injected booktabs baseline still stamps the
  # closing bottomrule on the last body row.
  spec <- tabular(data.frame(x = 1))
  m <- matrix(
    list(style_node()),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  out <- tabular:::engine_borders(spec, m)
  expect_identical(out[[1, "x"]]@border_bottom_style, "solid")
})

test_that("engine_borders short-circuits on zero-row matrix", {
  spec <- tabular(data.frame(x = 1)) |>
    style(border = brdr(), .at = cells_table(side = "outer"))
  empty <- matrix(list(), nrow = 0L, ncol = 1L, dimnames = list(NULL, "x"))
  expect_identical(tabular:::engine_borders(spec, empty), empty)
})

test_that("engine_borders stamps col separators left between visible columns", {
  spec <- tabular(data.frame(a = 1, b = 2, c = 3)) |>
    style(
      border_left = brdr("thin", "solid", "#000"),
      .at = cells_table(side = "cols")
    )
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
    style(border = brdr(), .at = cells_table(side = "outer"))
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
    preset(fonts = list(body = c(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Surface-specific fonts now ride on cells_body() layer stamps, so
  # the per-cell <td> carries `font-family: Inter` in inline style.
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

test_that("HTML emit per-cell color stamp for preset(colors = text)", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(body = c(text = "#ff0000")))
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
  expect_true(grepl("padding-top: 5pt", txt, fixed = TRUE))
})

test_that("DOCX emit consumes preset(colors = text) on body cells", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(body = c(text = "#ff0000")))
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
    preset(fonts = list(body = c(family = "Inter")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Inter", txt, fixed = TRUE))
})

test_that("RTF emit consumes preset(colors = text) via colortbl + cf token", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(colors = list(body = c(text = "#ff0000")))
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
    preset(colors = list(body = c(text = "#ff0000")))
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
    preset(fonts = list(body = c(family = "Inter")))
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
