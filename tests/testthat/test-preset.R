# preset() — per-spec preset override. Tests cover argument
# validation, merge vs reset semantics, unknown-knob rejection, the
# cascade integration with engine_paginate (the verb's downstream
# effect), and the NULL-clear behaviour when reset = TRUE with no
# knobs.

test_that("preset() returns a tabular_spec with preset_spec attached", {
  spec <- tabular(data.frame(x = 1:3))
  out <- preset(spec, font_size = 8)
  expect_true(is_tabular_spec(out))
  expect_true(is_preset_spec(out@preset))
  expect_identical(out@preset@font_size, 8)
})

test_that("preset() with no knobs leaves the spec preset unset", {
  spec <- tabular(data.frame(x = 1:3))
  out <- preset(spec)
  expect_null(out@preset)
})

test_that("preset() merges knobs across repeat calls (no reset)", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_size = 8) |>
    preset(orientation = "landscape")
  expect_identical(spec@preset@font_size, 8)
  expect_identical(spec@preset@orientation, "landscape")
})

test_that("preset(.reset = TRUE) discards prior knobs", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_size = 8, orientation = "portrait") |>
    preset(font_size = 10, .reset = TRUE)
  expect_identical(spec@preset@font_size, 10)
  # orientation reverts to factory default
  expect_identical(spec@preset@orientation, "landscape")
})

test_that("preset(.reset = TRUE) with no knobs clears the per-spec preset", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_size = 8) |>
    preset(.reset = TRUE)
  expect_null(spec@preset)
})

test_that("preset() rejects unknown knob names", {
  spec <- tabular(data.frame(x = 1:3))
  expect_error(
    preset(spec, font_zize = 8),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects unnamed knobs in `...`", {
  spec <- tabular(data.frame(x = 1:3))
  expect_error(
    preset(spec, 8),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects bad enum values via the S7 validator", {
  spec <- tabular(data.frame(x = 1:3))
  expect_error(
    preset(spec, orientation = "diagonal"),
    class = "tabular_error_input"
  )
  expect_error(
    preset(spec, paper_size = "tabloid"),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects margins of unsupported length", {
  spec <- tabular(data.frame(x = 1:3))
  expect_error(
    preset(spec, margins = c(1, 0.5, 1)),
    class = "tabular_error_input"
  )
})

test_that("preset() accepts margins of length 1 or 4", {
  spec <- tabular(data.frame(x = 1:3))
  out1 <- preset(spec, margins = 0.75)
  expect_identical(out1@preset@margins, 0.75)
  out4 <- preset(spec, margins = c(1, 0.5, 1, 0.5))
  expect_identical(out4@preset@margins, c(1, 0.5, 1, 0.5))
})

test_that("preset() rejects non-scalar reset", {
  spec <- tabular(data.frame(x = 1:3))
  expect_error(
    preset(spec, .reset = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(
    preset(spec, .reset = NA),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-spec first arg", {
  expect_error(preset("not a spec"), class = "tabular_error_input")
})

test_that("preset() is visible to engine_paginate via .effective_preset", {
  # Force a tight font + landscape and confirm engine_paginate reads
  # the per-spec preset(smaller rpp than portrait at the same font).
  spec_p <- tabular(data.frame(x = 1:5)) |>
    preset(orientation = "portrait")
  spec_l <- tabular(data.frame(x = 1:5)) |>
    preset(orientation = "landscape")
  plan_p <- tabular:::engine_paginate(spec_p)
  plan_l <- tabular:::engine_paginate(spec_l)
  expect_gt(plan_p$rows_per_page, plan_l$rows_per_page)
})

test_that("preset() snapshot errors", {
  spec <- tabular(data.frame(x = 1:3))
  expect_snapshot(
    error = TRUE,
    preset(spec, font_zize = 8)
  )
  expect_snapshot(
    error = TRUE,
    preset(spec, orientation = "diagonal")
  )
  expect_snapshot(
    error = TRUE,
    preset(spec, margins = c(1, 0.5, 1))
  )
})

# ---------------------------------------------------------------------
# Title + body pad knobs — superseded. Title pad is now driven by
# `style(.at = cells_title(), blank_above = N)`; body pad is no
# longer a user-tunable surface (factory default 0 / 0 hardcoded
# per backend).
# ---------------------------------------------------------------------

test_that("style(.at = cells_title(), blank_above = N) reaches the title pad pipeline", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L, blank_below = 2L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  expect_silent(as_grid(spec))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  rtf <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # blank_above = 3 emits >= 3 leading `\pard\plain\par` paragraphs.
  blanks <- length(gregexpr("\\\\pard\\\\plain\\\\par", rtf)[[1L]])
  expect_gte(blanks, 3L)
})

test_that("preset() no longer accepts title_pad_top / body_pad_bottom (cut in v0.1.0)", {
  spec <- tabular(data.frame(x = 1L))
  expect_error(
    preset(spec, title_pad_top = 2L),
    class = "tabular_error_input"
  )
  expect_error(
    preset(spec, body_pad_bottom = 2L),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# `preset@indent_size` (integer rename of the old character `indent_chars`)
# ---------------------------------------------------------------------

test_that("preset_spec default indent_size is 2L", {
  expect_identical(preset_spec()@indent_size, 2L)
})

test_that("preset(indent_size = N) round-trips for valid non-negative integers", {
  spec <- tabular(data.frame(x = 1L))
  for (n in c(0L, 1L, 2L, 4L, 8L)) {
    out <- preset(spec, indent_size = n)
    expect_identical(out@preset@indent_size, n, info = paste0("n = ", n))
  }
})

test_that("preset_spec validator rejects NA indent_size", {
  expect_error(
    preset_spec(indent_size = NA_integer_),
    "indent_size"
  )
})

test_that("preset_spec validator rejects negative indent_size", {
  expect_error(
    preset_spec(indent_size = -1L),
    "indent_size"
  )
})

test_that("preset_spec validator rejects length>1 indent_size", {
  expect_error(
    preset_spec(indent_size = c(2L, 3L)),
    "indent_size"
  )
})

# `.indent_text_unit()` is the single source of truth for translating
# the integer knob into the monospace text-prefix unit; every guard in
# the engine + every backend leading-strip pass routes through it.
test_that(".indent_text_unit(0L) returns empty string", {
  expect_identical(tabular:::.indent_text_unit(0L), "")
})

test_that(".indent_text_unit(N) returns N spaces for positive N", {
  expect_identical(tabular:::.indent_text_unit(1L), " ")
  expect_identical(tabular:::.indent_text_unit(2L), "  ")
  expect_identical(tabular:::.indent_text_unit(4L), "    ")
})

test_that(".indent_text_unit() returns empty string for NA / negative / length>1", {
  expect_identical(tabular:::.indent_text_unit(NA_integer_), "")
  expect_identical(tabular:::.indent_text_unit(-1L), "")
  expect_identical(tabular:::.indent_text_unit(integer(0L)), "")
  expect_identical(tabular:::.indent_text_unit(c(2L, 3L)), "")
})

# ---------------------------------------------------------------------
# Indent-unit helpers in R/font_metrics.R (Change C)
# ---------------------------------------------------------------------

test_that(".indent_em_per_level returns 0 when indent_size is 0L", {
  expect_identical(
    tabular:::.indent_em_per_level(preset_spec(indent_size = 0L)),
    0
  )
})

test_that(".indent_em_per_level is positive at default 2L preset", {
  expect_gt(tabular:::.indent_em_per_level(preset_spec()), 0)
})

test_that(".indent_em_per_level reads default (NULL preset) as size 2L", {
  expect_gt(tabular:::.indent_em_per_level(NULL), 0)
})

test_that(".indent_native_pt_per_level returns 0 when indent_size is 0L", {
  expect_identical(
    tabular:::.indent_native_pt_per_level(preset_spec(indent_size = 0L)),
    0
  )
})

test_that(".indent_native_pt_per_level scales with font_size", {
  small <- tabular:::.indent_native_pt_per_level(
    preset_spec(font_size = 8)
  )
  large <- tabular:::.indent_native_pt_per_level(
    preset_spec(font_size = 16)
  )
  expect_gt(large, small)
})

test_that(".indent_native_twips_per_level returns 0L when indent_size is 0L", {
  expect_identical(
    tabular:::.indent_native_twips_per_level(preset_spec(indent_size = 0L)),
    0L
  )
})

test_that(".indent_native_twips_per_level returns an integer count", {
  out <- tabular:::.indent_native_twips_per_level(preset_spec())
  expect_type(out, "integer")
  expect_gt(out, 0L)
})
