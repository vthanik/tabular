# engine_style() — resolves the predicate cascade into a per-cell
# style matrix. Covers all 9 plan edge cases for predicate eval.

# ---- empty spec -----------------------------------------------------

test_that("engine_style() returns a default-filled grid when no styles set", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp)
  grid <- tabular:::engine_style(spec)
  expect_equal(dim(grid), c(2L, 2L))
  expect_identical(colnames(grid), c("stat_label", "n"))
  # All cells are the default style_node (all-NA fields)
  for (i in seq_len(2)) {
    for (j in seq_len(2)) {
      expect_true(is_style_node(grid[[i, j]]))
      expect_true(is.na(grid[[i, j]]@bold))
    }
  }
})

# ---- scope = "row" applies to all cells in matching rows ----------

test_that("engine_style() row-scope applies to all cells in matching rows", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = n > 1))
  grid <- tabular:::engine_style(spec)
  # Row 2 (n=2): both cells bold
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 2L]]@bold, TRUE)
  # Row 1: not bold (NA default)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_true(is.na(grid[[1L, 2L]]@bold))
})

# ---- column targeting via `j = ...` ---------------------------------

test_that("engine_style() honours `j = <col>` to scope to a column", {
  resp <- data.frame(
    stat_label = c("R", "NR"),
    pvalue = c(0.01, 0.5),
    other = c(10L, 20L)
  )
  spec <- tabular(resp) |>
    style(
      color = "red",
      .at = cells_body(where = pvalue < 0.05, j = "pvalue")
    )
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 2L]]@color, "red")
  expect_true(is.na(grid[[1L, 3L]]@color))
  expect_true(is.na(grid[[1L, 1L]]@color))
  expect_true(is.na(grid[[2L, 2L]]@color))
})

test_that("engine_style() with `where = TRUE` (no `j`) paints every visible column", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = TRUE))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 2L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
})

# ---- multi-predicate accumulation: later wins for overlaps --------

test_that("engine_style() later predicate overrides earlier for overlapping cells", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(color = "blue", .at = cells_body(where = TRUE)) |>
    style(color = "red", .at = cells_body(where = n > 1))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@color, "blue") # only first predicate matches
  expect_identical(grid[[2L, 1L]]@color, "red") # second predicate wins
})

test_that("engine_style() merge preserves non-overlapping fields", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = TRUE)) |>
    style(italic = TRUE, .at = cells_body(where = TRUE))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 1L]]@italic, TRUE)
})

# ---- edge case 9: zero-match predicate is a no-op -----------------

test_that("engine_style() with zero-match predicate is a no-op", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = n > 999))
  grid <- tabular:::engine_style(spec)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_true(is.na(grid[[2L, 1L]]@bold))
})

# ---- edge case 3: non-logical eval -> error -----------------------

test_that("engine_style() rejects a non-logical where result", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = n))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 1: where references unknown col --------------------

test_that("engine_style() rewraps eval errors as tabular_error_input", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = no_such_col == 1))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- length-1 recycling -------------------------------------------

test_that("engine_style() recycles a length-1 logical to nrow", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = TRUE))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
})

test_that("engine_style() rejects a `where` result with wrong length", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  # Length-3 where on a 2-row data frame — covered by .resolve_layer_rows.
  spec <- tabular(resp) |>
    style(
      bold = TRUE,
      .at = cells_body(where = c(TRUE, FALSE, TRUE))
    )
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 2: predicate references upstream-derived column ----

test_that("engine_style() allows predicates on upstream-derived columns", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  resp$twice <- resp$n * 2L
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = twice > 2L))
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_true(is.na(grid[[1L, 1L]]@bold))
})

# ---- snapshot for engine error message coherence ------------------

test_that("engine_style() error snapshot on unknown column in predicate", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(bold = TRUE, .at = cells_body(where = no_such_col == 1))
  expect_snapshot(error = TRUE, tabular:::engine_style(spec))
})

# ---------------------------------------------------------------------
# Coverage — .resolve_layer_rows() + .resolve_layer_cols() error paths.
# Triggered via the public `style()` verb so the abort class is
# pinned at the engine layer where users actually hit it.
# ---------------------------------------------------------------------

test_that(".resolve_layer_rows aborts on non-logical `where` result", {
  spec <- tabular(data.frame(x = 1:3)) |>
    style(bold = TRUE, .at = cells_body(where = x))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that(".resolve_layer_rows aborts when `where` length is wrong", {
  # Use a `where` that returns a length-2 logical on a 3-row data
  # frame to trigger the length-mismatch branch.
  spec <- tabular(data.frame(x = 1:3)) |>
    style(bold = TRUE, .at = cells_body(where = c(TRUE, FALSE)))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that(".resolve_layer_rows aborts on numeric i out of bounds", {
  spec <- tabular(data.frame(x = 1:3)) |>
    style(bold = TRUE, .at = cells_body(i = 1:5))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that(".resolve_layer_rows aborts on logical i with wrong length", {
  spec <- tabular(data.frame(x = 1:3)) |>
    style(bold = TRUE, .at = cells_body(i = c(TRUE, FALSE)))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that(".resolve_layer_rows warns on character i and applies to every row", {
  spec <- tabular(data.frame(x = 1:3)) |>
    style(bold = TRUE, .at = cells_body(i = c("a", "b", "c")))
  expect_warning(
    tabular:::engine_style(spec),
    "Character row indices",
    class = "tabular_warning_input"
  )
})

test_that(".resolve_layer_cols aborts on unknown character j", {
  spec <- tabular(data.frame(x = 1:3, y = 4:6)) |>
    style(bold = TRUE, .at = cells_body(j = "nope"))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

test_that(".resolve_layer_cols aborts on numeric j out of bounds", {
  spec <- tabular(data.frame(x = 1:3, y = 4:6)) |>
    style(bold = TRUE, .at = cells_body(j = 5L))
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})
