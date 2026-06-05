# Tests for the new `at = cells_*()` layer path on the style() verb,
# the style_template() chain target, the brdr-shorthand expansion,
# and the new blank_above / blank_below style_node slots.

# ---------------------------------------------------------------------
# at = cells_body() — new layer path
# ---------------------------------------------------------------------

test_that("style(..., .at = cells_body()) appends a style_layer", {
  spec <- tabular(cdisc_saf_demo) |> style(bold = TRUE, .at = cells_body())
  expect_length(spec@styles@layers, 1L)
  layer <- spec@styles@layers[[1]]
  expect_true(is_style_layer(layer))
  expect_identical(layer@location$surface, "body")
  expect_identical(layer@style@bold, TRUE)
})

test_that("style(..., .at = cells_body(i = 1:3, j = 'Total')) keeps i/j on the location", {
  spec <- tabular(cdisc_saf_demo) |>
    style(bold = TRUE, .at = cells_body(i = 1:3, j = "Total"))
  loc <- spec@styles@layers[[1]]@location
  expect_identical(loc$i, 1:3)
  expect_identical(loc$j, "Total")
})

test_that("multiple at-style calls accumulate in declaration order", {
  spec <- tabular(cdisc_saf_demo) |>
    style(bold = TRUE, .at = cells_body()) |>
    style(italic = TRUE, .at = cells_headers()) |>
    style(blank_above = 1L, .at = cells_title())
  expect_length(spec@styles@layers, 3L)
  expect_identical(
    vapply(spec@styles@layers, function(l) l@location$surface, character(1)),
    c("body", "headers", "title")
  )
})

# ---------------------------------------------------------------------
# style_template() — house style composition
# ---------------------------------------------------------------------

test_that("style_template() returns an empty composable container", {
  tmpl <- style_template()
  expect_true(is_style_template(tmpl))
  expect_length(tmpl$layers, 0L)
})

test_that("style(template, ..., .at = ...) appends to template layers", {
  tmpl <- style_template() |>
    style(bold = TRUE, .at = cells_headers(level = -1)) |>
    style(bold = TRUE, .at = cells_group_headers())
  expect_true(is_style_template(tmpl))
  expect_length(tmpl$layers, 2L)
  expect_true(is_style_layer(tmpl$layers[[1]]))
  expect_identical(tmpl$layers[[1]]@location$surface, "headers")
  expect_identical(tmpl$layers[[1]]@location$level, -1L)
  expect_identical(tmpl$layers[[2]]@location$surface, "group_headers")
})

test_that("style(template, bold = TRUE) defaults `.at` to cells_body()", {
  tmpl <- style_template() |> style(bold = TRUE)
  expect_length(tmpl$layers, 1L)
  expect_identical(tmpl$layers[[1]]@location$surface, "body")
})

# ---------------------------------------------------------------------
# brdr-shorthand expansion
# ---------------------------------------------------------------------

test_that("border_top = brdr(...) expands to per-side scalars", {
  spec <- tabular(cdisc_saf_demo) |>
    style(
      border_top = brdr("thick", "double", "#000"),
      .at = cells_headers()
    )
  node <- spec@styles@layers[[1]]@style
  expect_identical(node@border_top_style, "double")
  expect_identical(node@border_top_color, "#000")
  expect_true(node@border_top_width > 0)
})

test_that("border = brdr(...) sets all four sides", {
  spec <- tabular(cdisc_saf_demo) |>
    style(border = brdr("thin", "solid", "#666"), .at = cells_table())
  node <- spec@styles@layers[[1]]@style
  for (side in c("top", "bottom", "left", "right")) {
    expect_identical(
      S7::prop(node, paste0("border_", side, "_style")),
      "solid"
    )
    expect_identical(
      S7::prop(node, paste0("border_", side, "_color")),
      "#666"
    )
  }
})

test_that("border_top = 'none' kills the border on that side", {
  spec <- tabular(cdisc_saf_demo) |>
    style(border_top = "none", .at = cells_footnotes())
  node <- spec@styles@layers[[1]]@style
  expect_identical(node@border_top_style, "none")
  expect_identical(node@border_top_width, 0)
})

# ---------------------------------------------------------------------
# blank_above / blank_below slots
# ---------------------------------------------------------------------

test_that("blank_above / blank_below land on style_node", {
  spec <- tabular(cdisc_saf_demo) |>
    style(blank_above = 1L, blank_below = 2L, .at = cells_title())
  node <- spec@styles@layers[[1]]@style
  expect_identical(node@blank_above, 1L)
  expect_identical(node@blank_below, 2L)
})

# ---------------------------------------------------------------------
# Argument-shape errors
# ---------------------------------------------------------------------

test_that("`where` passed at top level lands as an unknown style attribute warning", {
  # Legacy users who type `style(spec, where = pred, bold = TRUE)` get
  # the "unknown attribute" warning (where = is not a recognised
  # style_node field). Use `.at = cells_body(where = pred)` instead.
  withr::local_options(list(rlang_warning_verbosity = "quiet"))
  expect_warning(
    tabular(cdisc_saf_demo) |> style(bold = TRUE, where = TRUE),
    "where"
  )
})

test_that("style(spec, bold = TRUE) defaults `.at` to cells_body()", {
  spec <- tabular(cdisc_saf_demo) |> style(bold = TRUE)
  expect_length(spec@styles@layers, 1L)
  expect_identical(spec@styles@layers[[1]]@location$surface, "body")
})

test_that("at must be a tabular_location", {
  expect_error(
    tabular(cdisc_saf_demo) |> style(bold = TRUE, .at = "body"),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(cdisc_saf_demo) |> style(bold = TRUE, .at = list(surface = "body")),
    class = "tabular_error_input"
  )
})

test_that("style(.at = cells_body(where = ...)) appends one layer", {
  spec <- tabular(cdisc_saf_demo) |>
    style(bold = TRUE, .at = cells_body(where = TRUE))
  expect_length(spec@styles@layers, 1L)
})
