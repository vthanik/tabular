# style_template — composable container for accumulating
# `style_layer` records OUTSIDE a `tabular_spec`. Tests cover the
# constructor, class predicate, and print method (which is the only
# code path that previously had 0% coverage).

test_that("style_template() returns a tabular_style_template with empty layers", {
  t <- style_template()
  expect_true(is_style_template(t))
  expect_identical(t$layers, list())
})

test_that("is_style_template() returns FALSE on non-templates", {
  expect_false(is_style_template(list()))
  expect_false(is_style_template(NULL))
  expect_false(is_style_template("string"))
  expect_false(is_style_template(tabular(data.frame(x = 1L))))
})

test_that("print() on a 0-layer template shows the header line only", {
  t <- style_template()
  expect_snapshot(print(t))
})

test_that("print() on a 1-layer template shows '1 layer' and the surface", {
  t <- style_template() |>
    style(at = cells_headers(), bold = TRUE)
  expect_snapshot(print(t))
})

test_that("print() on a multi-layer template enumerates each surface", {
  t <- style_template() |>
    style(at = cells_headers(), bold = TRUE) |>
    style(at = cells_title(), halign = "left") |>
    style(at = cells_footnotes(), italic = TRUE)
  expect_snapshot(print(t))
})

test_that("style() on a template accumulates layers in declaration order", {
  t <- style_template() |>
    style(at = cells_headers(), bold = TRUE) |>
    style(at = cells_title(), halign = "left")
  expect_length(t$layers, 2L)
  expect_identical(t$layers[[1]]@location$surface, "headers")
  expect_identical(t$layers[[2]]@location$surface, "title")
})
