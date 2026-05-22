# sort_rows() — verb that attaches a sort_spec to a tabular_spec.
# Covers all 8 plan edge cases (plus argument-shape errors).

# ---- happy path ------------------------------------------------------

test_that("sort_rows() stores a sort_spec on the spec", {
  spec <- tabular(saf_demo) |>
    sort_rows(by = c("variable", "stat_label"))

  expect_true(is_sort_spec(spec@sort))
  expect_identical(spec@sort@by, c("variable", "stat_label"))
  expect_identical(spec@sort@descending, c(FALSE, FALSE))
})

test_that("sort_rows() recycles length-1 descending across keys", {
  spec <- tabular(saf_demo) |>
    sort_rows(by = c("variable", "stat_label"), descending = TRUE)

  expect_identical(spec@sort@descending, c(TRUE, TRUE))
})

test_that("sort_rows() accepts per-key descending vector", {
  spec <- tabular(saf_demo) |>
    sort_rows(
      by = c("variable", "stat_label"),
      descending = c(TRUE, FALSE)
    )
  expect_identical(spec@sort@descending, c(TRUE, FALSE))
})

# ---- edge case 2: by length 0 ---------------------------------------

test_that("sort_rows() with length-0 by is accepted (no-op sort)", {
  spec <- tabular(saf_demo) |> sort_rows(by = character())
  expect_true(is_sort_spec(spec@sort))
  expect_identical(spec@sort@by, character())
})

test_that("sort_rows() default arguments are a no-op", {
  spec <- tabular(saf_demo) |> sort_rows()
  expect_true(is_sort_spec(spec@sort))
  expect_length(spec@sort@by, 0L)
})

# ---- edge case 5: repeat call replaces -------------------------------

test_that("sort_rows() called twice replaces (not stacks)", {
  spec <- tabular(saf_demo) |>
    sort_rows(by = "variable") |>
    sort_rows(by = "stat_label", descending = TRUE)

  expect_identical(spec@sort@by, "stat_label")
  expect_identical(spec@sort@descending, TRUE)
})

# ---- edge case 6: sort-only column (not in cols()) ------------------

test_that("sort_rows() accepts a column not declared in cols()", {
  # row_type is in eff_resp's data but not in any cols() call.
  spec <- tabular(eff_resp) |>
    sort_rows(by = "row_type")
  expect_identical(spec@sort@by, "row_type")
})

# ---- edge case 1: by references a column not in data ----------------

test_that("sort_rows() errors when by references unknown column", {
  expect_error(
    tabular(saf_demo) |> sort_rows(by = "missing_col"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() error names the missing column", {
  err <- tryCatch(
    tabular(saf_demo) |>
      sort_rows(by = c("variable", "no_such_col")),
    tabular_error_input = function(e) e
  )
  expect_s3_class(err, "tabular_error_input")
  expect_match(conditionMessage(err), "no_such_col")
})

# ---- edge case 3: by references an across column --------------------

test_that("sort_rows() rejects sort by an across-usage column", {
  spec <- tabular(saf_demo) |>
    cols(variable = col_spec(usage = "across"))
  expect_error(
    spec |> sort_rows(by = "variable"),
    class = "tabular_error_input"
  )
})

# ---- edge case 4: descending length mismatch ------------------------

test_that("sort_rows() errors when descending length neither 1 nor length(by)", {
  expect_error(
    tabular(saf_demo) |>
      sort_rows(
        by = c("variable", "stat_label"),
        descending = c(TRUE, FALSE, TRUE)
      ),
    class = "tabular_error_input"
  )
})

# ---- spec/argument-shape errors -------------------------------------

test_that("sort_rows() rejects non-spec first argument", {
  expect_error(
    sort_rows(data.frame(x = 1), by = "x"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects non-character by", {
  expect_error(
    tabular(saf_demo) |> sort_rows(by = 1:3),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects NA in by", {
  expect_error(
    tabular(saf_demo) |> sort_rows(by = c("variable", NA)),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects non-logical descending", {
  expect_error(
    tabular(saf_demo) |>
      sort_rows(by = "variable", descending = "yes"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects NA descending", {
  expect_error(
    tabular(saf_demo) |>
      sort_rows(by = "variable", descending = NA),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("sort_rows() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> sort_rows(by = "no_such_col")
  )
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |>
      sort_rows(
        by = c("variable", "stat_label"),
        descending = c(TRUE, FALSE, TRUE)
      )
  )
})
