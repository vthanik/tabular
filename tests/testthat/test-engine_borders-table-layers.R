# engine_borders() — cells_table() layer routing. Walks the same
# 4-tier cascade as engine_style, but stamps per-side border triples
# onto the body cells_style matrix.

build_grid <- function() {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp)
  list(spec = spec, cells_style = tabular:::engine_style(spec))
}

test_that("cells_table(side = 'outer_top') is structural via the manifest, not per-cell", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_top = brdr("thick"), .at = cells_table(side = "outer_top"))
  cs <- tabular:::engine_style(spec)
  cs <- tabular:::engine_borders(spec, cs)
  # Outer top is drawn structurally at the header band's top rule (above
  # the body), which a per-cell body stamp cannot reach, so no per-cell
  # top stamp lands; the manifest carries the resolved triple.
  expect_true(is.na(cs[[1L, 1L]]@border_top_style))
  man <- tabular:::.body_border_manifest(spec)
  expect_identical(man$outer_top$style, "solid")
  expect_true(man$outer_top$width > 0)
})

test_that("cells_table(side = 'outer_bottom') stamps the last row's bottom border", {
  g <- build_grid()
  spec <- g$spec |>
    style(
      border_bottom = brdr("thin"),
      .at = cells_table(side = "outer_bottom")
    )
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
  expect_true(is.na(cs[[1L, 1L]]@border_bottom_style))
})

test_that("cells_table(side = 'outer') stamps bottom per-cell, top/L/R via manifest", {
  g <- build_grid()
  spec <- g$spec |>
    style(border = brdr("thin"), .at = cells_table(side = "outer"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  # Bottom is stamped per-cell (the last body row's bottom IS the table
  # bottom, coinciding with the chrome bottomrule).
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
  # Top / left / right are NOT stamped per-cell; they are drawn
  # structurally from the manifest so the edges span the synthesised
  # special rows (top rides the header band). The per-cell scalars stay NA.
  expect_true(is.na(cs[[1L, 1L]]@border_top_style))
  expect_true(is.na(cs[[1L, 1L]]@border_left_style))
  expect_true(is.na(cs[[1L, 2L]]@border_right_style))
  man <- tabular:::.body_border_manifest(spec)
  expect_identical(man$outer_top$style, "solid")
  expect_identical(man$outer_left$style, "solid")
  expect_identical(man$outer_right$style, "solid")
})

test_that("cells_table(side = 'rows') stamps every row except first on the top side", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_top = brdr("thin"), .at = cells_table(side = "rows"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_true(is.na(cs[[1L, 1L]]@border_top_style))
  expect_identical(cs[[2L, 1L]]@border_top_style, "solid")
})

test_that("cells_table(side = 'cols') stamps every visible col except first on the left side", {
  g <- build_grid()
  spec <- g$spec |>
    style(border_left = brdr("thin"), .at = cells_table(side = "cols"))
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_true(is.na(cs[[1L, 1L]]@border_left_style))
  expect_identical(cs[[1L, 2L]]@border_left_style, "solid")
})

test_that("cells_table() layers compose in cascade order (last write wins)", {
  g <- build_grid()
  # First layer says outer_top is "double"; the later layer overrides
  # to thin solid (layer order is precedence within the cascade).
  spec <- g$spec |>
    style(
      border_top = brdr("thick", "double"),
      .at = cells_table(side = "outer_top")
    ) |>
    style(
      border_top = brdr("thin", "solid"),
      .at = cells_table(side = "outer_top")
    )
  # outer_top is manifest-routed; the later layer's "solid" wins.
  man <- tabular:::.body_border_manifest(spec)
  expect_identical(man$outer_top$style, "solid")
})

test_that("session preset(.style = template) flows through engine_borders", {
  withr::defer(set_preset(.reset = TRUE))
  g <- build_grid()
  tmpl <- style_template() |>
    style(border = brdr("thin"), .at = cells_table(side = "outer"))
  set_preset(.style = tmpl)
  cs <- tabular:::engine_borders(g$spec, tabular:::engine_style(g$spec))
  # Bottom stamps per-cell; top rides the manifest.
  expect_identical(cs[[2L, 1L]]@border_bottom_style, "solid")
  man <- tabular:::.body_border_manifest(g$spec)
  expect_identical(man$outer_top$style, "solid")
})

test_that("rules='frame' draws L/R structurally via the manifest, not per-cell (#frame-left)", {
  # `variable` is a section group host: engine_group_display() pulls it
  # out of the body into synthesised section rows AFTER engine_borders()
  # runs. The frame's vertical edges are drawn structurally by each
  # backend from the manifest (so they span the synthesised spanner /
  # blank / group-header rows), NOT as per-cell stamps that would only
  # reach data rows. So no per-cell L/R stamp lands at all.
  spec <- tabular(cdisc_saf_demo, titles = "t", footnotes = "f") |>
    cols(
      variable = col_spec(),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    group_rows(by = "variable") |>
    preset(rules = "frame")
  cs <- tabular:::engine_borders(spec, tabular:::engine_style(spec))
  expect_true(is.na(cs[[1L, "stat_label"]]@border_left_style))
  expect_true(is.na(cs[[1L, "Total"]]@border_right_style))
  # The resolved L/R edges live in the manifest for the backends.
  man <- tabular:::.body_border_manifest(spec)
  expect_false(is.null(man$outer_left))
  expect_false(is.null(man$outer_right))
})
