# derive() — verb that attaches derive_spec entries to a tabular_spec.
# Covers all 9 plan edge cases (plus argument-shape errors).

# ---- happy path ------------------------------------------------------

test_that("derive() stores one derive_spec per named expression", {
  spec <- tabular(saf_demo) |>
    derive(twice = 2)
  expect_length(spec@derives, 1L)
  expect_true(is_derive_spec(spec@derives[["twice"]]))
  expect_identical(spec@derives[["twice"]]@name, "twice")
})

test_that("derive() captures expressions as rlang quosures", {
  spec <- tabular(saf_demo) |>
    derive(twice = 2)
  expect_true(rlang::is_quosure(spec@derives[["twice"]]@expr))
})

test_that("derive() with zero arguments is a no-op", {
  spec <- tabular(saf_demo)
  expect_identical(derive(spec), spec)
})

# ---- edge case 6: auto-attach col_spec(usage = "computed") ----------

test_that("derive() auto-attaches col_spec(usage = 'computed') when not declared", {
  spec <- tabular(saf_demo) |> derive(twice = 2)
  cs <- spec@cols[["twice"]]
  expect_true(is_col_spec(cs))
  expect_identical(cs@usage, "computed")
  expect_identical(cs@name, "twice")
})

test_that("derive() preserves label/format set in a prior cols() call", {
  spec <- tabular(saf_demo) |>
    cols(
      twice = col_spec(usage = "computed", label = "Twice", format = "%.1f")
    ) |>
    derive(twice = 2)
  cs <- spec@cols[["twice"]]
  expect_identical(cs@usage, "computed")
  expect_identical(cs@label, "Twice")
  expect_identical(cs@format, "%.1f")
})

# ---- edge case 8: multiple derive() calls accumulate ----------------

test_that("derive() called twice accumulates", {
  spec <- tabular(saf_demo) |>
    derive(a = 1) |>
    derive(b = 2)
  expect_named(spec@derives, c("a", "b"))
})

test_that("derive() same name across calls replaces", {
  spec <- tabular(saf_demo) |>
    derive(x = 1) |>
    derive(x = 99)
  # We cannot compare quosures directly; eval and check.
  val <- rlang::eval_tidy(spec@derives[["x"]]@expr)
  expect_equal(val, 99)
  expect_length(spec@derives, 1L)
})

# ---- duplicate-within-call error ------------------------------------

test_that("derive() rejects duplicate names within one call", {
  expect_error(
    tabular(saf_demo) |> derive(x = 1, x = 2),
    class = "tabular_error_input"
  )
})

# ---- conflict-with-data-column error --------------------------------

test_that("derive() rejects an output name that collides with a data column", {
  expect_error(
    tabular(saf_demo) |> derive(variable = 1),
    class = "tabular_error_input"
  )
})

# ---- spec/argument-shape errors -------------------------------------

test_that("derive() rejects non-spec first argument", {
  expect_error(
    derive(data.frame(x = 1), y = 1),
    class = "tabular_error_input"
  )
})

test_that("derive() rejects unnamed arguments", {
  expect_error(
    tabular(saf_demo) |> derive(1, 2),
    class = "tabular_error_input"
  )
})

test_that("derive() rejects partial-named arguments", {
  expect_error(
    tabular(saf_demo) |> derive(a = 1, 2),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("derive() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> derive(variable = 1)
  )
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> derive(x = 1, x = 2)
  )
})
