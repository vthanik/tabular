# engine_style() body-layer routing — `cells_body()` location
# with `where` predicate, `i` row indices, `j` column indices.

# ---------------------------------------------------------------------
# cells_body() — no filter applies to every cell
# ---------------------------------------------------------------------

test_that("cells_body() with no filter applies to every cell", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |> style(bold = TRUE, at = cells_body())
  grid <- tabular:::engine_style(spec)
  for (i in 1:2) {
    for (j in 1:2) {
      expect_identical(grid[[i, j]]@bold, TRUE)
    }
  }
})

# ---------------------------------------------------------------------
# cells_body(i = ...) — row index filter
# ---------------------------------------------------------------------

test_that("cells_body(i = 1) applies to row 1 only", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |> style(bold = TRUE, at = cells_body(i = 1L))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 2L]]@bold, TRUE)
  expect_true(is.na(grid[[2L, 1L]]@bold))
  expect_true(is.na(grid[[2L, 2L]]@bold))
})

test_that("cells_body(i = logical-mask) applies to TRUE rows", {
  resp <- data.frame(stat_label = c("R", "NR", "PD"), n = c(1L, 2L, 3L))
  spec <- tabular(resp) |>
    style(bold = TRUE, at = cells_body(i = c(TRUE, FALSE, TRUE)))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_true(is.na(grid[[2L, 1L]]@bold))
  expect_identical(grid[[3L, 1L]]@bold, TRUE)
})

# ---------------------------------------------------------------------
# cells_body(j = ...) — column index filter
# ---------------------------------------------------------------------

test_that("cells_body(j = 'n') applies to that column only", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |> style(bold = TRUE, at = cells_body(j = "n"))
  grid <- tabular:::engine_style(spec)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_identical(grid[[1L, 2L]]@bold, TRUE)
  expect_true(is.na(grid[[2L, 1L]]@bold))
  expect_identical(grid[[2L, 2L]]@bold, TRUE)
})

test_that("cells_body(i, j) combines row + column filters", {
  resp <- data.frame(stat_label = c("R", "NR", "PD"), n = c(1L, 2L, 3L))
  spec <- tabular(resp) |>
    style(bold = TRUE, at = cells_body(i = 2L, j = "n"))
  grid <- tabular:::engine_style(spec)
  for (i in 1:3) {
    for (j in 1:2) {
      if (i == 2L && j == 2L) {
        expect_identical(grid[[i, j]]@bold, TRUE)
      } else {
        expect_true(is.na(grid[[i, j]]@bold))
      }
    }
  }
})

# ---------------------------------------------------------------------
# cells_body(where = ...) — predicate filter
# ---------------------------------------------------------------------

test_that("cells_body(where = ...) applies to matching rows, all cols", {
  resp <- data.frame(stat_label = c("R", "NR", "PD"), n = c(1L, 5L, 3L))
  spec <- tabular(resp) |>
    style(bold = TRUE, at = cells_body(where = n > 2))
  grid <- tabular:::engine_style(spec)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 2L]]@bold, TRUE)
  expect_identical(grid[[3L, 1L]]@bold, TRUE)
  expect_identical(grid[[3L, 2L]]@bold, TRUE)
})

# ---------------------------------------------------------------------
# multiple layers accumulate, declaration-order wins
# ---------------------------------------------------------------------

test_that("multiple layers accumulate, last writer wins per attribute", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, color = "red", at = cells_body()) |>
    style(color = "blue", at = cells_body(i = 2L))
  grid <- tabular:::engine_style(spec)
  # Row 1: bold + red (first layer only)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 1L]]@color, "red")
  # Row 2: bold (carried from layer 1) + blue (layer 2 overrides red)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@color, "blue")
})

# ---------------------------------------------------------------------
# Non-body layers are ignored (routed by other engines)
# ---------------------------------------------------------------------

test_that("non-body layers do not affect the body grid", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, at = cells_headers()) |>
    style(italic = TRUE, at = cells_title())
  grid <- tabular:::engine_style(spec)
  for (i in 1:2) {
    for (j in 1:2) {
      expect_true(is.na(grid[[i, j]]@bold))
      expect_true(is.na(grid[[i, j]]@italic))
    }
  }
})

# ---------------------------------------------------------------------
# Predicate + layer mix: both apply
# ---------------------------------------------------------------------

test_that("legacy predicate path and layer path both contribute", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = n > 1, bold = TRUE, .scope = "row") |>
    style(color = "red", at = cells_body())
  grid <- tabular:::engine_style(spec)
  # Row 1: only red (predicate didn't match)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_identical(grid[[1L, 1L]]@color, "red")
  # Row 2: bold (predicate) + red (layer)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@color, "red")
})

# ---------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------

test_that("out-of-bounds i raises tabular_error_input", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |> style(bold = TRUE, at = cells_body(i = 5L))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that("unknown j raises tabular_error_input", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, at = cells_body(j = "nope"))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})
