# engine_chrome_borders() — chrome-surface layer routing. Layers
# whose location is cells_headers / cells_title / cells_footnotes
# / cells_subgroup_labels / cells_pagehead / cells_pagefoot
# populate chrome_style$surfaces (text props) and the matching
# chrome_style$borders region (border triple).

# ---------------------------------------------------------------------
# Text properties merge onto chrome_style$surfaces[<key>]
# ---------------------------------------------------------------------

test_that("cells_headers() text props land on chrome_style$surfaces$header", {
  spec <- tabular(saf_demo) |>
    style(bold = TRUE, color = "navy", .at = cells_headers())
  cs <- tabular:::engine_chrome_borders(spec)
  node <- cs$surfaces$header
  expect_identical(node@bold, TRUE)
  expect_identical(node@color, "navy")
})

test_that("cells_title() text props land on chrome_style$surfaces$title", {
  spec <- tabular(saf_demo) |>
    style(halign = "left", font_size = 12, .at = cells_title())
  cs <- tabular:::engine_chrome_borders(spec)
  node <- cs$surfaces$title
  expect_identical(node@halign, "left")
  expect_identical(node@font_size, 12)
})

test_that("cells_footnotes() text props land on chrome_style$surfaces$footer", {
  spec <- tabular(saf_demo) |>
    style(italic = TRUE, font_size = 8, .at = cells_footnotes())
  cs <- tabular:::engine_chrome_borders(spec)
  node <- cs$surfaces$footer
  expect_identical(node@italic, TRUE)
  expect_identical(node@font_size, 8)
})

test_that("cells_pagehead() text props land on chrome_style$surfaces$pagehead", {
  spec <- tabular(saf_demo) |>
    style(font_family = "Inter", .at = cells_pagehead())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$surfaces$pagehead@font_family, "Inter")
})

test_that("cells_pagefoot() text props land on chrome_style$surfaces$pagefoot", {
  spec <- tabular(saf_demo) |>
    style(font_size = 7, .at = cells_pagefoot())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$surfaces$pagefoot@font_size, 7)
})

test_that("cells_subgroup_labels() text props land on chrome_style$surfaces$subgroup", {
  spec <- tabular(saf_demo) |>
    style(background = "#eef", .at = cells_subgroup_labels())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$surfaces$subgroup@background, "#eef")
})

# ---------------------------------------------------------------------
# Borders land on the matching chrome border region
# ---------------------------------------------------------------------

test_that("cells_headers(border_top = brdr) writes header_top region", {
  spec <- tabular(saf_demo) |>
    style(border_top = brdr("thick", "double"), .at = cells_headers())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$header_top$style, "double")
  expect_true(cs$borders$header_top$width > 0)
})

test_that("cells_headers(border_bottom = brdr) writes header_bottom region", {
  spec <- tabular(saf_demo) |>
    style(border_bottom = brdr("thin"), .at = cells_headers())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$header_bottom$style, "solid")
})

test_that("cells_pagehead(border_bottom = brdr) writes pagehead_bottom", {
  spec <- tabular(saf_demo) |>
    style(border_bottom = brdr("thin"), .at = cells_pagehead())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$pagehead_bottom$style, "solid")
})

test_that("cells_pagefoot(border_top = brdr) writes pagefoot_top", {
  spec <- tabular(saf_demo) |>
    style(border_top = brdr("thin"), .at = cells_pagefoot())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$pagefoot_top$style, "solid")
})

test_that("cells_footnotes(border_top = brdr) writes footer_top", {
  spec <- tabular(saf_demo) |>
    style(border_top = brdr("thin"), .at = cells_footnotes())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$footer_top$style, "solid")
})

test_that("cells_subgroup_labels(border_bottom = brdr) writes subgroup_bottom", {
  spec <- tabular(saf_demo) |>
    style(border_bottom = brdr("thin"), .at = cells_subgroup_labels())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$subgroup_bottom$style, "solid")
})

# ---------------------------------------------------------------------
# Cascade composition
# ---------------------------------------------------------------------

test_that("multiple layers on the same surface compose (later wins per attr)", {
  spec <- tabular(saf_demo) |>
    style(bold = TRUE, color = "red", .at = cells_headers()) |>
    style(color = "blue", .at = cells_headers())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$surfaces$header@bold, TRUE)
  expect_identical(cs$surfaces$header@color, "blue")
})

test_that("session preset style template flows into chrome_style", {
  withr::defer(set_preset(.reset = TRUE))
  set_preset(
    .style = style_template() |>
      style(bold = TRUE, .at = cells_headers())
  )
  cs <- tabular:::engine_chrome_borders(tabular(saf_demo))
  expect_identical(cs$surfaces$header@bold, TRUE)
})

test_that("layer over legacy preset@borders chrome region wins", {
  spec <- tabular(saf_demo) |>
    preset(borders = list(header_top = brdr("thick", "double"))) |>
    style(border_top = brdr("thin", "solid"), .at = cells_headers())
  cs <- tabular:::engine_chrome_borders(spec)
  expect_identical(cs$borders$header_top$style, "solid")
})
