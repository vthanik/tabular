# engine_sort() — applies sort_spec to spec@data. Tests cover
# ascending/descending, multi-key, mixed direction, NA-last, factor
# ordering by level, empty / zero-row passthrough.

# ---- no-op cases ----------------------------------------------------

test_that("engine_sort() returns spec unchanged when no sort set", {
  spec <- tabular(saf_demo)
  out <- engine_sort(spec)
  expect_identical(out@data, spec@data)
})

test_that("engine_sort() returns spec unchanged for length-0 by", {
  spec <- tabular(saf_demo) |> sort_rows(by = character())
  out <- engine_sort(spec)
  expect_identical(out@data, spec@data)
})

test_that("engine_sort() returns spec unchanged for zero-row data", {
  empty <- data.frame(
    variable = character(),
    stat_label = character(),
    placebo = character()
  )
  spec <- tabular(empty) |> sort_rows(by = "variable")
  out <- engine_sort(spec)
  expect_identical(out@data, spec@data)
})

# ---- ascending single key -------------------------------------------

test_that("engine_sort() ascends on a character column", {
  d <- data.frame(
    k = c("c", "a", "b"),
    v = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |> sort_rows(by = "k")
  out <- engine_sort(spec)
  expect_identical(out@data$k, c("a", "b", "c"))
  expect_identical(out@data$v, c(2L, 3L, 1L))
})

# ---- descending single key ------------------------------------------

test_that("engine_sort() descends on a numeric column", {
  d <- data.frame(x = c(2, 1, 3, 0))
  spec <- tabular(d) |> sort_rows(by = "x", descending = TRUE)
  expect_identical(engine_sort(spec)@data$x, c(3, 2, 1, 0))
})

# ---- multi-key mixed directions -------------------------------------

test_that("engine_sort() handles per-key mixed directions", {
  d <- data.frame(
    g = c("a", "a", "b", "b"),
    v = c(2, 1, 4, 3),
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |>
    sort_rows(by = c("g", "v"), descending = c(FALSE, TRUE))
  out <- engine_sort(spec)
  expect_identical(out@data$g, c("a", "a", "b", "b"))
  expect_identical(out@data$v, c(2, 1, 4, 3))
})

# ---- factor sort uses levels, not character order -------------------

test_that("engine_sort() respects factor levels", {
  d <- data.frame(
    bor = factor(
      c("PD", "CR", "SD", "PR"),
      levels = c("CR", "PR", "SD", "PD")
    ),
    n = c(10L, 1L, 5L, 3L)
  )
  spec <- tabular(d) |> sort_rows(by = "bor")
  out <- engine_sort(spec)
  expect_identical(as.character(out@data$bor), c("CR", "PR", "SD", "PD"))
  expect_identical(out@data$n, c(1L, 3L, 5L, 10L))
})

test_that("engine_sort() factor descending reverses level order", {
  d <- data.frame(
    bor = factor(c("PD", "CR", "SD"), levels = c("CR", "SD", "PD")),
    n = 1:3
  )
  spec <- tabular(d) |> sort_rows(by = "bor", descending = TRUE)
  out <- engine_sort(spec)
  expect_identical(as.character(out@data$bor), c("PD", "SD", "CR"))
})

# ---- NA-last regardless of direction --------------------------------

test_that("engine_sort() places NA values last when ascending", {
  d <- data.frame(x = c(2, NA, 1, NA, 3))
  spec <- tabular(d) |> sort_rows(by = "x")
  out <- engine_sort(spec)
  expect_identical(out@data$x, c(1, 2, 3, NA, NA))
})

test_that("engine_sort() places NA values last when descending", {
  d <- data.frame(x = c(2, NA, 1, NA, 3))
  spec <- tabular(d) |> sort_rows(by = "x", descending = TRUE)
  out <- engine_sort(spec)
  expect_identical(out@data$x, c(3, 2, 1, NA, NA))
})

# ---- real demo data round-trip --------------------------------------

test_that("engine_sort() orders eff_resp's stat_label alphabetically", {
  spec <- tabular(eff_resp) |> sort_rows(by = "stat_label")
  out <- engine_sort(spec)
  labels <- out@data$stat_label
  expect_identical(labels, sort(labels))
})

test_that("engine_sort() is stable for tied keys", {
  d <- data.frame(
    g = c("a", "a", "a", "b"),
    pos = 1:4
  )
  spec <- tabular(d) |> sort_rows(by = "g")
  out <- engine_sort(spec)
  expect_identical(out@data$pos, 1:4)
})
