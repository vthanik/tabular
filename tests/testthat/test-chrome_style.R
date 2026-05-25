# chrome_style() — parallel sidecar for non-body styling decisions.
#
# Phase 1 scope: chrome_style$borders is populated from
# preset@borders by engine_chrome_borders(); chrome_style$surfaces
# stays at default no-op style_nodes (Phase 2 reserved).

test_that("chrome_style() returns a list with borders + surfaces slots", {
  cs <- tabular:::chrome_style()
  expect_type(cs, "list")
  expect_named(cs, c("borders", "surfaces"))
})

test_that("chrome_style()$borders carries every chrome region key with NULL default", {
  cs <- tabular:::chrome_style()
  expect_named(
    cs$borders,
    c(
      "pagehead_bottom",
      "header_top",
      "header_bottom",
      "header_between",
      "subgroup_top",
      "subgroup_bottom",
      "footer_top",
      "footer_bottom",
      "pagefoot_top"
    )
  )
  expect_true(all(vapply(cs$borders, is.null, logical(1L))))
})

test_that("chrome_style()$surfaces carries every chrome surface key with default style_node", {
  cs <- tabular:::chrome_style()
  expect_named(
    cs$surfaces,
    c("pagehead", "title", "header", "subgroup", "footer", "pagefoot")
  )
  expect_true(all(vapply(cs$surfaces, is_style_node, logical(1L))))
})

test_that(".chrome_border_at() returns NULL on missing region or non-list input", {
  cs <- tabular:::chrome_style()
  expect_null(tabular:::.chrome_border_at(cs, "header_bottom"))
  expect_null(tabular:::.chrome_border_at(cs, "nonexistent_region"))
  expect_null(tabular:::.chrome_border_at(NULL, "header_bottom"))
})

test_that(".chrome_surface_at() returns a default style_node on missing surface or non-list input", {
  cs <- tabular:::chrome_style()
  expect_true(is_style_node(tabular:::.chrome_surface_at(cs, "header")))
  expect_true(is_style_node(tabular:::.chrome_surface_at(
    cs,
    "missing_surface"
  )))
  expect_true(is_style_node(tabular:::.chrome_surface_at(NULL, "header")))
})

# ---------------------------------------------------------------------
# engine_chrome_borders() — preset@borders -> chrome_style$borders
# ---------------------------------------------------------------------

test_that("engine_chrome_borders() returns an empty chrome_style when preset@borders is empty", {
  spec <- tabular(saf_demo)
  cs <- tabular:::engine_chrome_borders(spec)
  expect_true(all(vapply(cs$borders, is.null, logical(1L))))
})

test_that("engine_chrome_borders() resolves every chrome region key", {
  # Each chrome region carries a distinct triple so we can pin which
  # key landed where.
  rule <- brdr(width = 0.5, style = "solid", color = "#000000")
  spec <- tabular(saf_demo) |>
    preset(
      borders = list(
        pagehead_bottom = rule,
        header_top = rule,
        header_bottom = rule,
        header_between = rule,
        subgroup_top = rule,
        subgroup_bottom = rule,
        footer_top = rule,
        footer_bottom = rule,
        pagefoot_top = rule
      )
    )
  cs <- tabular:::engine_chrome_borders(spec)
  for (region in tabular:::.chrome_border_regions) {
    triple <- cs$borders[[region]]
    expect_false(is.null(triple), info = region)
    expect_equal(triple$style, "solid", info = region)
    expect_equal(triple$width, 0.5, info = region)
    expect_equal(triple$color, "#000000", info = region)
  }
})

test_that("engine_chrome_borders() legacy `subgroup` key resolves to `subgroup_bottom`", {
  spec <- tabular(saf_demo) |>
    preset(
      borders = list(
        subgroup = brdr(width = 0.75, style = "solid", color = "#cc0000")
      )
    )
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$subgroup_bottom$color, "#cc0000")
  expect_equal(cs$borders$subgroup_bottom$width, 0.75)
})

test_that("engine_chrome_borders() explicit subgroup_bottom wins over legacy `subgroup`", {
  spec <- tabular(saf_demo) |>
    preset(
      borders = list(
        subgroup = brdr(width = 0.5, style = "solid", color = "#aaaaaa"),
        subgroup_bottom = brdr(
          width = 1.0,
          style = "dashed",
          color = "#cc0000"
        )
      )
    )
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$subgroup_bottom$style, "dashed")
  expect_equal(cs$borders$subgroup_bottom$color, "#cc0000")
})

test_that("engine_chrome_borders() honours the 'none' explicit-clear sentinel", {
  spec <- tabular(saf_demo) |>
    preset(borders = list(header_bottom = "none"))
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$header_bottom$style, "none")
})

# ---------------------------------------------------------------------
# as_grid() exposes chrome_style on @metadata
# ---------------------------------------------------------------------

test_that("as_grid() puts chrome_style on grid@metadata", {
  spec <- tabular(saf_demo) |>
    preset(
      borders = list(
        header_bottom = brdr(width = 1, style = "solid", color = "#000000")
      )
    )
  grid <- as_grid(spec)
  cs <- grid@metadata$chrome_style
  expect_type(cs, "list")
  expect_named(cs, c("borders", "surfaces"))
  expect_equal(cs$borders$header_bottom$width, 1)
})
