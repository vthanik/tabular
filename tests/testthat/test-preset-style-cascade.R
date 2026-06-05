# Tests for the house-style cascade: preset(.style = template) +
# set_preset(.style = template) feed layers into spec@preset@style
# and tabular_session$preset@style respectively, and engine_style
# applies them in cascade order (session preset -> spec preset ->
# per-spec layers).

# ---------------------------------------------------------------------
# preset(.style = template) attaches layers to the spec's preset
# ---------------------------------------------------------------------

test_that("preset(.style = template) writes layers to preset@style", {
  tmpl <- style_template() |>
    style(bold = TRUE, .at = cells_body()) |>
    style(italic = TRUE, .at = cells_headers())
  spec <- tabular(cdisc_saf_demo) |> preset(.style = tmpl, font_size = 10)
  expect_length(spec@preset@style, 2L)
  expect_identical(spec@preset@font_size, 10)
})

test_that("preset(.style = ...) rejects non-template input", {
  expect_error(
    tabular(cdisc_saf_demo) |> preset(.style = list(layers = list())),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(cdisc_saf_demo) |> preset(.style = "bold"),
    class = "tabular_error_input"
  )
})

test_that("preset(.style = NULL) is a no-op", {
  spec <- tabular(cdisc_saf_demo) |> preset(.style = NULL, font_size = 11)
  expect_length(spec@preset@style, 0L)
  expect_identical(spec@preset@font_size, 11)
})

test_that("preset(.style = template) layers cascade to body cells", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  tmpl <- style_template() |>
    style(bold = TRUE, .at = cells_body())
  spec <- tabular(resp) |> preset(.style = tmpl)
  grid <- tabular:::engine_style(spec)
  for (i in 1:2) {
    for (j in 1:2) {
      expect_identical(grid[[i, j]]@bold, TRUE)
    }
  }
})

# ---------------------------------------------------------------------
# Per-spec style() overrides preset@style per attribute
# ---------------------------------------------------------------------

test_that("per-spec style() overrides preset@style per attribute", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  tmpl <- style_template() |>
    style(bold = TRUE, color = "blue", .at = cells_body())
  spec <- tabular(resp) |>
    preset(.style = tmpl) |>
    style(color = "red", .at = cells_body(i = 2L))
  grid <- tabular:::engine_style(spec)
  # Row 1: bold + blue (preset only)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 1L]]@color, "blue")
  # Row 2: bold (preset) + red (per-spec overrides)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@color, "red")
})

# ---------------------------------------------------------------------
# set_preset(.style = template) flows through to every subsequent spec
# ---------------------------------------------------------------------

test_that("set_preset(.style = template) cascades to specs with no own preset", {
  withr::defer(set_preset(.reset = TRUE))
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  tmpl <- style_template() |>
    style(bold = TRUE, .at = cells_body())
  set_preset(.style = tmpl)
  spec <- tabular(resp)
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 2L]]@bold, TRUE)
})

test_that("session preset + spec preset + per-spec layers compose", {
  withr::defer(set_preset(.reset = TRUE))
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  set_preset(
    .style = style_template() |> style(bold = TRUE, .at = cells_body())
  )
  spec_tmpl <- style_template() |>
    style(italic = TRUE, .at = cells_body())
  spec <- tabular(resp) |>
    preset(.style = spec_tmpl) |>
    style(color = "red", .at = cells_body())
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE) # session preset
  expect_identical(grid[[1L, 1L]]@italic, TRUE) # spec preset
  expect_identical(grid[[1L, 1L]]@color, "red") # per-spec
})

# ---------------------------------------------------------------------
# set_preset(.reset = TRUE) clears style too
# ---------------------------------------------------------------------

test_that("set_preset(.reset = TRUE) clears @style", {
  withr::defer(set_preset(.reset = TRUE))
  tmpl <- style_template() |> style(bold = TRUE, .at = cells_body())
  set_preset(.style = tmpl, font_size = 8)
  expect_length(get_preset()@style, 1L)
  set_preset(.reset = TRUE)
  expect_null(get_preset())
})

# ---------------------------------------------------------------------
# Multiple preset(.style = ) calls append layers in declaration order
# ---------------------------------------------------------------------

test_that("multiple preset(.style = ...) calls accumulate", {
  tmpl1 <- style_template() |> style(bold = TRUE, .at = cells_body())
  tmpl2 <- style_template() |> style(italic = TRUE, .at = cells_headers())
  spec <- tabular(cdisc_saf_demo) |>
    preset(.style = tmpl1) |>
    preset(.style = tmpl2)
  expect_length(spec@preset@style, 2L)
})
