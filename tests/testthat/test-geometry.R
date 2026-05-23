# geometry.R — internal twips / inches / row-height helpers shared
# by engine_paginate (and the upcoming engine_decimal). Helpers are
# dot-prefixed and unexported; tests reach them via tabular:::.

test_that(".inches_to_twips converts 1in to 1440 twips", {
  expect_identical(tabular:::.inches_to_twips(1), 1440L)
  expect_identical(tabular:::.inches_to_twips(0.5), 720L)
  expect_identical(tabular:::.inches_to_twips(0), 0L)
})

test_that(".pt_to_twips converts 1pt to 20 twips", {
  expect_identical(tabular:::.pt_to_twips(1), 20L)
  expect_identical(tabular:::.pt_to_twips(9), 180L)
  expect_identical(tabular:::.pt_to_twips(72), 1440L)
})

test_that(".paper_dims_twips returns portrait letter by default", {
  d <- tabular:::.paper_dims_twips("letter", "portrait")
  expect_identical(unname(d[["width"]]), 12240L)
  expect_identical(unname(d[["height"]]), 15840L)
})

test_that(".paper_dims_twips swaps width and height for landscape", {
  p <- tabular:::.paper_dims_twips("letter", "portrait")
  l <- tabular:::.paper_dims_twips("letter", "landscape")
  expect_identical(unname(l[["width"]]), unname(p[["height"]]))
  expect_identical(unname(l[["height"]]), unname(p[["width"]]))
})

test_that(".paper_dims_twips supports a4 and legal", {
  expect_identical(
    unname(tabular:::.paper_dims_twips("a4", "portrait")[["width"]]),
    11906L
  )
  expect_identical(
    unname(tabular:::.paper_dims_twips("legal", "portrait")[["height"]]),
    20163L
  )
})

test_that(".paper_dims_twips aborts on unknown paper", {
  expect_error(
    tabular:::.paper_dims_twips("foo", "portrait"),
    class = "tabular_error_input"
  )
})

test_that(".row_height_twips scales with font size", {
  small <- tabular:::.row_height_twips(9)
  large <- tabular:::.row_height_twips(18)
  expect_gt(large, small)
})

test_that(".row_height_twips honours array_stretch", {
  one <- tabular:::.row_height_twips(9, array_stretch = 1.0)
  two <- tabular:::.row_height_twips(9, array_stretch = 2.0)
  expect_gt(two, one)
})

test_that(".margin_top_bottom_twips handles scalar margin", {
  m <- tabular:::.margin_top_bottom_twips(1)
  expect_identical(m[["top"]], 1440L)
  expect_identical(m[["bottom"]], 1440L)
})

test_that(".margin_top_bottom_twips handles length-4 margin", {
  m <- tabular:::.margin_top_bottom_twips(c(1, 0.5, 0.75, 0.5))
  expect_identical(m[["top"]], 1440L)
  expect_identical(m[["bottom"]], 1080L)
})

test_that(".effective_preset returns the spec's preset when set", {
  spec <- tabular(data.frame(x = 1))
  preset <- preset_spec(font_size = 14)
  spec <- S7::set_props(spec, preset = preset)
  out <- tabular:::.effective_preset(spec)
  expect_true(is_preset_spec(out))
  expect_identical(out@font_size, 14)
})

test_that(".effective_preset returns defaults when no preset attached", {
  spec <- tabular(data.frame(x = 1))
  out <- tabular:::.effective_preset(spec)
  expect_true(is_preset_spec(out))
  expect_identical(out@font_size, 9)
  expect_identical(out@orientation, "portrait")
})
