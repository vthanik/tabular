# engine_derive() — applies spec@derives to spec@data via topo-sorted
# quosure evaluation. Covers all 9 plan edge cases for derive eval.

# ---- happy path ------------------------------------------------------

test_that("engine_derive() materialises a simple arithmetic derive", {
  resp <- data.frame(
    stat_label = c("R", "NR"),
    placebo = c(3L, 83L),
    drug = c(12L, 72L)
  )
  out <- tabular(resp) |>
    derive(diff = drug - placebo) |>
    tabular:::engine_derive()
  expect_true("diff" %in% names(out@data))
  expect_equal(out@data$diff, c(9L, -11L))
})

test_that("engine_derive() leaves spec unchanged when no derives", {
  spec <- tabular(saf_demo)
  expect_identical(tabular:::engine_derive(spec), spec)
})

test_that("engine_derive() recycles a length-1 result to nrow", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  out <- tabular(resp) |>
    derive(k = 99L) |>
    tabular:::engine_derive()
  expect_equal(out@data$k, c(99L, 99L))
})

# ---- edge case 4: circular dependency detection ---------------------

test_that("engine_derive() catches a direct self-cycle", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(x = x + 1)
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

test_that("engine_derive() catches an indirect 2-node cycle", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |>
    derive(a = b + 1) |>
    derive(b = a + 1)
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 7: derive may reference an earlier derive ------------

test_that("engine_derive() resolves a chain of two derives via topo sort", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(3L, 7L))
  out <- tabular(resp) |>
    derive(
      twice = n * 2L,
      thrice = twice + n
    ) |>
    tabular:::engine_derive()
  expect_equal(out@data$twice, c(6L, 14L))
  expect_equal(out@data$thrice, c(9L, 21L))
})

test_that("engine_derive() handles topo order independent of declaration order", {
  resp <- data.frame(stat_label = "R", n = 4L)
  out <- tabular(resp) |>
    derive(b = a + 1) |>
    derive(a = n * 2) |>
    tabular:::engine_derive()
  expect_equal(out@data$a, 8)
  expect_equal(out@data$b, 9)
})

# ---- edge case 2: <col>.<stat> aggregation pattern is rejected ------

test_that("engine_derive() rejects aggregation-style symbols", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(bad = n.mean + 1)
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 3: .c[[n]] access ------------------------------------

test_that("engine_derive() exposes .c as a list of column values", {
  resp <- data.frame(stat_label = "R", n = 5L, m = 7L)
  out <- tabular(resp) |>
    derive(sum_first = .c[[2]] + .c[[3]]) |>
    tabular:::engine_derive()
  expect_equal(out@data$sum_first, 12)
})

test_that("engine_derive() supports .c[['name']] access", {
  resp <- data.frame(stat_label = "R", n = 5L, m = 7L)
  out <- tabular(resp) |>
    derive(s = .c[["n"]] + .c[["m"]]) |>
    tabular:::engine_derive()
  expect_equal(out@data$s, 12)
})

# ---- edge case 5: result-length validation --------------------------

test_that("engine_derive() rejects a result of wrong length", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  spec <- tabular(resp) |> derive(bad = c(1, 2, 3))
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

test_that("engine_derive() rejects a NULL result", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(bad = NULL)
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

test_that("engine_derive() rejects a list / data.frame result", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(bad = list(1, 2))
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

# ---- edge case 9: non-deterministic functions allowed ---------------

test_that("engine_derive() allows non-deterministic expressions", {
  withr::local_seed(42)
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  out <- tabular(resp) |>
    derive(noise = runif(2)) |>
    tabular:::engine_derive()
  expect_type(out@data$noise, "double")
  expect_length(out@data$noise, 2L)
})

# ---- eval error rewrapping ------------------------------------------

test_that("engine_derive() rewraps eval errors as tabular_error_input", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(bad = stop("boom"))
  expect_error(
    tabular:::engine_derive(spec),
    class = "tabular_error_input"
  )
})

# ---- expression environment is preserved by the quosure -------------

test_that("engine_derive() resolves names from the calling environment", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  scale <- 10
  out <- tabular(resp) |>
    derive(scaled = n * scale) |>
    tabular:::engine_derive()
  expect_equal(out@data$scaled, c(10, 20))
})

# ---- character output via as.character() ----------------------------

test_that("engine_derive() preserves character output type", {
  resp <- data.frame(stat_label = c("R", "NR"), n = c(1L, 2L))
  out <- tabular(resp) |>
    derive(tag = sprintf("n=%d", n)) |>
    tabular:::engine_derive()
  expect_type(out@data$tag, "character")
  expect_identical(out@data$tag, c("n=1", "n=2"))
})

# ---- snapshot for engine error message coherence --------------------

test_that("engine_derive() error snapshots", {
  resp <- data.frame(stat_label = "R", n = 1L)
  spec <- tabular(resp) |> derive(bad = n.mean + 1)
  expect_snapshot(error = TRUE, tabular:::engine_derive(spec))

  spec2 <- tabular(resp) |>
    derive(a = b + 1) |>
    derive(b = a + 1)
  expect_snapshot(error = TRUE, tabular:::engine_derive(spec2))
})
