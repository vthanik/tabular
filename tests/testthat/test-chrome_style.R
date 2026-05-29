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
      "title_top",
      "title_bottom",
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

test_that("engine_chrome_borders() injects the booktabs chrome defaults", {
  # The booktabs baseline drives the header (top / bottom) chrome rules
  # even with no user `rules` knob. `footer_top` (footnoterule) is OFF
  # by default: the body `bottomrule` closes the data->footnote
  # boundary (the two are mutually exclusive). page-band and subgroup
  # regions stay NULL until set.
  spec <- tabular(saf_demo)
  cs <- tabular:::engine_chrome_borders(spec)
  expect_false(is.null(cs$borders$header_top))
  expect_false(is.null(cs$borders$header_bottom))
  expect_null(cs$borders$footer_top)
  expect_null(cs$borders$pagehead_bottom)
  expect_null(cs$borders$subgroup_bottom)
})

test_that("rules knob targets each header / footnote chrome region distinctly", {
  spec <- tabular(saf_demo) |>
    preset(
      rules = list(
        toprule = brdr(color = "#000000"),
        midrule = brdr(color = "#111111"),
        spanrule = brdr(color = "#222222"),
        footnoterule = brdr(color = "#333333")
      )
    )
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$header_top$color, "#000000")
  expect_equal(cs$borders$header_bottom$color, "#111111")
  expect_equal(cs$borders$header_between$color, "#222222")
  expect_equal(cs$borders$footer_top$color, "#333333")
})

test_that("style(cells_subgroup_labels) sets the subgroup chrome border", {
  spec <- tabular(saf_demo) |>
    style(
      border_bottom = brdr(width = 0.75, color = "#cc0000"),
      .at = cells_subgroup_labels()
    )
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$subgroup_bottom$color, "#cc0000")
  expect_equal(cs$borders$subgroup_bottom$width, 0.75)
})

test_that("rules knob honours the 'none' explicit-clear sentinel on midrule", {
  spec <- tabular(saf_demo) |>
    preset(rules = list(midrule = "none"))
  cs <- tabular:::engine_chrome_borders(spec)
  expect_equal(cs$borders$header_bottom$style, "none")
})

# ---------------------------------------------------------------------
# as_grid() exposes chrome_style on @metadata
# ---------------------------------------------------------------------

test_that("as_grid() puts chrome_style on grid@metadata", {
  spec <- tabular(saf_demo) |>
    preset(rules = list(midrule = brdr(width = 1, color = "#000000")))
  grid <- as_grid(spec)
  cs <- grid@metadata$chrome_style
  expect_type(cs, "list")
  expect_named(cs, c("borders", "surfaces"))
  expect_equal(cs$borders$header_bottom$width, 1)
})
