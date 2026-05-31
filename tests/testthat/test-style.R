# style() — unified styling verb. Each call appends one `style_layer`
# to `spec@styles@layers`. Tests cover the verb's argument-shape
# contract; engine-level layer application is tested in
# test-engine_style.R / test-style-layers.R.

# ---- happy path -----------------------------------------------------

test_that("style() stores one style_layer per call", {
  spec <- tabular(saf_demo) |>
    style(bold = TRUE, .at = cells_body(where = TRUE))
  expect_true(is_style_spec(spec@styles))
  expect_length(spec@styles@layers, 1L)
  expect_true(is_style_layer(spec@styles@layers[[1]]))
})

test_that("style() captures `at` as a tabular_location", {
  spec <- tabular(saf_demo) |>
    style(bold = TRUE, .at = cells_body(where = TRUE))
  loc <- spec@styles@layers[[1]]@location
  expect_true(is_tabular_location(loc))
  expect_identical(loc$surface, "body")
})

test_that("style() builds a style_node from variadic attrs", {
  spec <- tabular(saf_demo) |>
    style(
      bold = TRUE,
      color = "red",
      font_size = 8,
      .at = cells_body(where = TRUE)
    )
  node <- spec@styles@layers[[1]]@style
  expect_true(is_style_node(node))
  expect_identical(node@bold, TRUE)
  expect_identical(node@color, "red")
  expect_identical(node@font_size, 8)
})

# ---- multiple calls accumulate --------------------------------------

test_that("style() called twice accumulates layers", {
  spec <- tabular(saf_demo) |>
    style(bold = TRUE, .at = cells_body(where = TRUE)) |>
    style(italic = TRUE, .at = cells_body(where = TRUE))
  expect_length(spec@styles@layers, 2L)
})

# ---- argument-shape errors -----------------------------------------

test_that("style() errors when no attributes supplied", {
  expect_error(
    tabular(saf_demo) |> style(.at = cells_body(where = TRUE)),
    class = "tabular_error_input"
  )
})

test_that("style() warns on an unknown attribute name", {
  expect_warning(
    tabular(saf_demo) |>
      style(jiggle = TRUE, .at = cells_body(where = TRUE)),
    "jiggle"
  )
})

test_that("style() drops unknown attrs from the constructed node", {
  withr::local_options(list(rlang_warning_verbosity = "quiet"))
  suppressWarnings({
    spec <- tabular(saf_demo) |>
      style(bold = TRUE, jiggle = TRUE, .at = cells_body(where = TRUE))
  })
  node <- spec@styles@layers[[1]]@style
  expect_identical(node@bold, TRUE)
})

test_that("style() rejects non-spec / non-template first argument", {
  expect_error(
    style(data.frame(x = 1), bold = TRUE, .at = cells_body(where = TRUE)),
    class = "tabular_error_input"
  )
})

test_that("style() errors when .at is not a tabular_location", {
  expect_error(
    tabular(saf_demo) |> style(bold = TRUE, .at = "not a location"),
    class = "tabular_error_input"
  )
})

test_that("style() rejects unnamed attribute args", {
  expect_error(
    tabular(saf_demo) |>
      style(TRUE, .at = cells_body(where = TRUE)),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("style() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> style(.at = cells_body(where = TRUE))
  )
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> style(bold = TRUE, .at = "not a location")
  )
})

test_that("a whole-number double blank_above is coerced to integer", {
  spec <- tabular(saf_demo, titles = "T") |>
    style(blank_above = 2, .at = cells_title())
  node <- spec@styles@layers[[1L]]@style
  expect_identical(node@blank_above, 2L)
})

test_that("a scalar padding broadcasts to all four per-side fields", {
  spec <- tabular(saf_demo) |>
    style(padding = 3, .at = cells_body())
  node <- spec@styles@layers[[1L]]@style
  expect_identical(node@padding_top, 3)
  expect_identical(node@padding_right, 3)
  expect_identical(node@padding_bottom, 3)
  expect_identical(node@padding_left, 3)
})

test_that("a named padding vector sets only the listed per-side fields", {
  spec <- tabular(saf_demo) |>
    style(padding = c(top = 1, left = 2), .at = cells_body())
  node <- spec@styles@layers[[1L]]@style
  expect_identical(node@padding_top, 1)
  expect_identical(node@padding_left, 2)
  expect_true(is.na(node@padding_right))
  expect_true(is.na(node@padding_bottom))
})

test_that("style() rejects the legacy nested-list padding form (#knob-shape)", {
  expect_error(
    tabular(saf_demo) |>
      style(padding = list(top = 5, bottom = 3), .at = cells_body()),
    class = "tabular_error_input"
  )
})
