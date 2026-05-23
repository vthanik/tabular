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
    style(where = n > 1, bold = TRUE, .scope = "row")
  grid <- tabular:::engine_style(spec)
  # Row 2 (n=2): both cells bold
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 2L]]@bold, TRUE)
  # Row 1: not bold (NA default)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_true(is.na(grid[[1L, 2L]]@bold))
})

# ---- scope = "cell" applies only to referenced columns ------------

test_that("engine_style() cell-scope applies only to columns referenced in where", {
  resp <- data.frame(
    stat_label = c("R", "NR"),
    pvalue = c(0.01, 0.5),
    other = c(10L, 20L)
  )
  spec <- tabular(resp) |>
    style(where = pvalue < 0.05, color = "red", .scope = "cell")
  grid <- tabular:::engine_style(spec)
  # Row 1 pvalue cell -- red
  expect_identical(grid[[1L, 2L]]@color, "red")
  # Row 1 other cell -- not red (predicate referenced only pvalue)
  expect_true(is.na(grid[[1L, 3L]]@color))
  # Row 1 stat_label -- not red
  expect_true(is.na(grid[[1L, 1L]]@color))
  # Row 2 -- not red anywhere
  expect_true(is.na(grid[[2L, 2L]]@color))
})

test_that("engine_style() cell-scope falls back to all cols when no data col referenced", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = TRUE, bold = TRUE, .scope = "cell")
  grid <- tabular:::engine_style(spec)
  # `where = TRUE` references no columns -> falls back to all
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 2L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
})

# ---- multi-predicate accumulation: later wins for overlaps --------

test_that("engine_style() later predicate overrides earlier for overlapping cells", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = TRUE, color = "blue", .scope = "row") |>
    style(where = n > 1, color = "red", .scope = "row")
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@color, "blue") # only first predicate matches
  expect_identical(grid[[2L, 1L]]@color, "red") # second predicate wins
})

test_that("engine_style() merge preserves non-overlapping fields", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |>
    style(where = TRUE, bold = TRUE, .scope = "row") |>
    style(where = TRUE, italic = TRUE, .scope = "row")
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[1L, 1L]]@italic, TRUE)
})

# ---- edge case 9: zero-match predicate is a no-op -----------------

test_that("engine_style() with zero-match predicate is a no-op", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = n > 999, bold = TRUE, .scope = "row")
  grid <- tabular:::engine_style(spec)
  expect_true(is.na(grid[[1L, 1L]]@bold))
  expect_true(is.na(grid[[2L, 1L]]@bold))
})

# ---- edge case 3: non-logical eval -> error -----------------------

test_that("engine_style() rejects a non-logical where result", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = n, bold = TRUE, .scope = "row")
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 1: where references unknown col --------------------

test_that("engine_style() rewraps eval errors as tabular_error_input", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = no_such_col == 1, bold = TRUE, .scope = "row")
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- length-1 recycling -------------------------------------------

test_that("engine_style() recycles a length-1 logical to nrow", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = TRUE, bold = TRUE, .scope = "row")
  grid <- tabular:::engine_style(spec)
  expect_identical(grid[[1L, 1L]]@bold, TRUE)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
})

test_that("engine_style() rejects a result with wrong length", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  # Construct via raw S7 to bypass the verb; predicate evaluates to length 3.
  pred <- style_predicate(
    where = rlang::quo(c(TRUE, FALSE, TRUE)),
    style = style_node(bold = TRUE),
    scope = "row"
  )
  ss <- style_spec(predicates = list(pred))
  spec <- S7::set_props(tabular(resp), styles = ss)
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 2: predicate references computed col ---------------

test_that("engine_style() allows predicates on derived columns", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    derive(twice = n * 2L) |>
    style(where = twice > 2L, bold = TRUE, .scope = "row")
  # After engine_derive, `twice` is in data; engine_style then runs.
  resolved <- tabular:::engine_derive(spec)
  grid <- tabular:::engine_style(resolved)
  expect_identical(grid[[2L, 1L]]@bold, TRUE)
  expect_true(is.na(grid[[1L, 1L]]@bold))
})

# ---- .scope = "col" not implemented yet ---------------------------

test_that("engine_style() errors on .scope = 'col' with a clear message", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = TRUE, bold = TRUE, .scope = "col")
  expect_error(
    tabular:::engine_style(spec),
    class = "tabular_error_input"
  )
})

# ---- snapshot for engine error message coherence ------------------

test_that("engine_style() error snapshots", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |>
    style(where = no_such_col == 1, bold = TRUE, .scope = "row")
  expect_snapshot(error = TRUE, tabular:::engine_style(spec))

  spec2 <- tabular(resp) |>
    style(where = TRUE, bold = TRUE, .scope = "col")
  expect_snapshot(error = TRUE, tabular:::engine_style(spec2))
})
