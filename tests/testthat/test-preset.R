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

test_that("preset(reset = TRUE) discards prior knobs", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_size = 8, orientation = "landscape") |>
    preset(font_size = 10, reset = TRUE)
  expect_identical(spec@preset@font_size, 10)
  # orientation reverts to factory default
  expect_identical(spec@preset@orientation, "portrait")
})

test_that("preset(reset = TRUE) with no knobs clears the per-spec preset", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(font_size = 8) |>
    preset(reset = TRUE)
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
    preset(spec, reset = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(
    preset(spec, reset = NA),
    class = "tabular_error_input"
  )
})

test_that("preset() rejects non-spec first arg", {
  expect_error(preset("not a spec"), class = "tabular_error_input")
})

test_that("preset() is visible to engine_paginate via .effective_preset", {
  # Force a tight font + landscape and confirm engine_paginate reads
  # the per-spec preset (smaller rpp than portrait at the same font).
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
# Title + body pad knobs (Phase 7c)
# ---------------------------------------------------------------------

test_that("preset_spec() defaults all four pad knobs to 1L", {
  p <- preset_spec()
  expect_equal(p@title_pad_top, 1L)
  expect_equal(p@title_pad_bottom, 1L)
  expect_equal(p@body_pad_top, 1L)
  expect_equal(p@body_pad_bottom, 1L)
})

test_that("preset() accepts integer and numeric pad values", {
  spec <- tabular(data.frame(x = 1:3))
  out <- preset(
    spec,
    title_pad_top = 0L,
    title_pad_bottom = 2,
    body_pad_top = 0,
    body_pad_bottom = 3L
  )
  expect_equal(out@preset@title_pad_top, 0L)
  expect_equal(out@preset@title_pad_bottom, 2)
  expect_equal(out@preset@body_pad_top, 0)
  expect_equal(out@preset@body_pad_bottom, 3L)
})

test_that("preset() rejects negative / fractional / NA / length>1 pad values", {
  spec <- tabular(data.frame(x = 1:3))
  bad_inputs <- list(-1, 1.5, NA_real_, c(1, 2))
  for (bad in bad_inputs) {
    expect_error(
      preset(spec, title_pad_top = bad),
      class = "tabular_error_input"
    )
    expect_error(
      preset(spec, body_pad_bottom = bad),
      class = "tabular_error_input"
    )
  }
})
