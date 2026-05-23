# style() — verb that accumulates style_predicates on a tabular_spec.
# Covers all 9 plan edge cases plus argument-shape errors.

# ---- happy path -----------------------------------------------------

test_that("style() stores one style_predicate per call", {
  spec <- tabular(saf_demo) |>
    style(where = TRUE, bold = TRUE)
  expect_true(is_style_spec(spec@styles))
  expect_length(spec@styles@predicates, 1L)
  expect_true(is_style_predicate(spec@styles@predicates[[1]]))
})

test_that("style() captures where as an rlang quosure", {
  spec <- tabular(saf_demo) |> style(where = TRUE, bold = TRUE)
  expect_true(rlang::is_quosure(spec@styles@predicates[[1]]@where))
})

test_that("style() builds a style_node from variadic attrs", {
  spec <- tabular(saf_demo) |>
    style(where = TRUE, bold = TRUE, color = "red", font_size = 8)
  node <- spec@styles@predicates[[1]]@style
  expect_true(is_style_node(node))
  expect_identical(node@bold, TRUE)
  expect_identical(node@color, "red")
  expect_identical(node@font_size, 8)
})

# ---- edge case 7: multiple style() calls accumulate -----------------

test_that("style() called twice accumulates predicates", {
  spec <- tabular(saf_demo) |>
    style(where = TRUE, bold = TRUE) |>
    style(where = TRUE, italic = TRUE)
  expect_length(spec@styles@predicates, 2L)
})

# ---- edge case 6: .scope enum --------------------------------------

test_that("style() default scope is 'cell'", {
  spec <- tabular(saf_demo) |> style(where = TRUE, bold = TRUE)
  expect_identical(spec@styles@predicates[[1]]@scope, "cell")
})

test_that("style() accepts .scope = 'row'", {
  spec <- tabular(saf_demo) |>
    style(where = TRUE, bold = TRUE, .scope = "row")
  expect_identical(spec@styles@predicates[[1]]@scope, "row")
})

test_that("style() accepts .scope = 'col'", {
  spec <- tabular(saf_demo) |>
    style(where = TRUE, bold = TRUE, .scope = "col")
  expect_identical(spec@styles@predicates[[1]]@scope, "col")
})

test_that("style() rejects invalid .scope value", {
  expect_error(
    tabular(saf_demo) |> style(where = TRUE, bold = TRUE, .scope = "block"),
    class = "tabular_error_input"
  )
})

# ---- edge case 4: no style attrs -----------------------------------

test_that("style() errors when no attributes supplied", {
  expect_error(
    tabular(saf_demo) |> style(where = TRUE),
    class = "tabular_error_input"
  )
})

# ---- edge case 5: unknown attr name --------------------------------

test_that("style() warns on an unknown attribute name", {
  expect_warning(
    tabular(saf_demo) |> style(where = TRUE, jiggle = TRUE),
    "jiggle"
  )
})

test_that("style() drops unknown attrs from the constructed node", {
  withr::local_options(list(rlang_warning_verbosity = "quiet"))
  suppressWarnings({
    spec <- tabular(saf_demo) |>
      style(where = TRUE, bold = TRUE, jiggle = TRUE)
  })
  node <- spec@styles@predicates[[1]]@style
  expect_identical(node@bold, TRUE)
})

# ---- argument-shape errors -----------------------------------------

test_that("style() rejects non-spec first argument", {
  expect_error(
    style(data.frame(x = 1), where = TRUE, bold = TRUE),
    class = "tabular_error_input"
  )
})

test_that("style() errors when where is missing", {
  expect_error(
    tabular(saf_demo) |> style(bold = TRUE),
    class = "tabular_error_input"
  )
})

test_that("style() rejects unnamed attribute args", {
  expect_error(
    tabular(saf_demo) |> style(where = TRUE, TRUE),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("style() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> style(where = TRUE)
  )
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> style(where = TRUE, bold = TRUE, .scope = "block")
  )
})
