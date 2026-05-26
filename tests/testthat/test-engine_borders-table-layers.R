# engine_borders() — cells_table() layer routing. Walks the same
# 4-tier cascade as engine_style, but stamps per-side border triples
# onto the body cells_style matrix.

build_grid <- function() {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp)
  list(spec = spec, cells_style = tabular:::engine_style(spec))
}

test_that("cells_table(side = 'outer_top') stamps the top row's top border", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_top = brdr("thick"), at = cells_table(side = "outer_top"))
  cs <- tabular:::engine_style(spec)
  cs <- tabular:::engine_borders(spec, cs)
  expect_identical(cs[[1L, 1L]]@border_top_style, "solid")
  expect_true(cs[[1L, 1L]]@border_top_width > 0)
  expect_true(is.na(cs[[2L, 1L]]@border_top_style))
})

test_that("cells_table(side = 'outer_bottom') stamps the last row's bottom border", {
  g <- build_grid()
  spec <- g$spec |>
    style(
      border_bottom = brdr("thin"),
      at = cells_table(side = "outer_bottom")
    )
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
  expect_true(is.na(cs[[1L, 1L]]@border_bottom_style))
})

test_that("cells_table(side = 'outer') paints all four outer edges", {
  g <- build_grid()
  spec <- g$spec |>
    style(border = brdr("thin"), at = cells_table(side = "outer"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_identical(cs[[1L, 1L]]@border_top_style, "solid")
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
  expect_identical(cs[[1L, 1L]]@border_left_style, "solid")
  expect_identical(cs[[1L, 2L]]@border_right_style, "solid")
})

test_that("cells_table(side = 'rows') stamps every row except first on the top side", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_top = brdr("thin"), at = cells_table(side = "rows"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_true(is.na(cs[[1L, 1L]]@border_top_style))
  expect_identical(cs[[2L, 1L]]@border_top_style, "solid")
})

test_that("cells_table(side = 'cols') stamps every visible col except first on the left side", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_left = brdr("thin"), at = cells_table(side = "cols"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_true(is.na(cs[[1L, 1L]]@border_left_style))
  expect_identical(cs[[1L, 2L]]@border_left_style, "solid")
})

test_that("preset@borders and cells_table() layers compose in cascade order", {
  g <- build_grid()
  # Preset says outer_top is "double"; per-spec layer overrides to thick solid.
  spec <- g$spec |>
    preset(borders = list(outer_top = brdr("thick", "double"))) |>
    style(
      border_top = brdr("thin", "solid"),
      at = cells_table(side = "outer_top")
    )
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_identical(cs[[1L, 1L]]@border_top_style, "solid")
})

test_that("session preset(style = template) flows through engine_borders", {
  withr::defer(set_preset(reset = TRUE))
  g <- build_grid()
  tmpl <- style_template() |>
    style(border = brdr("thin"), at = cells_table(side = "outer"))
  set_preset(style = tmpl)
  cs <- tabular:::engine_borders(g$spec, tabular:::engine_style(g$spec))
  expect_identical(cs[[1L, 1L]]@border_top_style, "solid")
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
})
