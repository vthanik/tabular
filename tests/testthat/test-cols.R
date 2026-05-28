# cols() variadic per-column DSL: 11 edge cases from plan 2.2 plus
# the merge-semantics tests for repeated cols() calls.

mk_spec <- function() {
  tabular(data.frame(
    param = c("Age", "Sex"),
    drug_a = c("60", "30"),
    drug_b = c("62", "28"),
    stringsAsFactors = FALSE
  ))
}

# Happy path -----------------------------------------------------------

test_that("cols() attaches col_specs keyed by input name", {
  s <- mk_spec() |>
    cols(
      param = col_spec(usage = "group", label = "Parameter"),
      drug_a = col_spec(label = "Drug A", align = "decimal")
    )
  expect_named(s@cols, c("param", "drug_a"))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$param@name, "param")
  expect_identical(s@cols$drug_a@align, "decimal")
  expect_identical(s@cols$drug_a@name, "drug_a")
})

# Edge case 1: name not in data — reject ------------------------------

test_that("cols() rejects a name not in data", {
  expect_error(
    mk_spec() |> cols(missing_col = col_spec(usage = "display")),
    class = "tabular_error_input"
  )
})

# Edge case 2: empty ... is a no-op ------------------------------------

test_that("cols() with no args returns the spec unchanged", {
  s0 <- mk_spec()
  s1 <- cols(s0)
  expect_identical(s1@cols, s0@cols)
  expect_length(s1@cols, 0L)
})

# Edge case 3: duplicate name in same call — warn, last wins ----------

test_that("cols() warns on duplicate names and keeps the last", {
  expect_warning(
    s <- mk_spec() |>
      cols(
        param = col_spec(label = "First"),
        param = col_spec(label = "Second")
      ),
    "duplicate"
  )
  expect_identical(s@cols$param@label, "Second")
})

# Edge case 4: missing column gets no entry (engine_validate later) ----

test_that("cols() leaves un-mentioned columns out of @cols", {
  s <- mk_spec() |> cols(param = col_spec(usage = "group"))
  expect_named(s@cols, "param")
  expect_false("drug_a" %in% names(s@cols))
})

# Edge case 5: repeat cols() merges field-by-field ---------------------

test_that("cols() merges across two calls (non-default wins)", {
  s <- mk_spec() |>
    cols(param = col_spec(usage = "group", label = "Parameter")) |>
    cols(param = col_spec(width = 1.5))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$param@label, "Parameter")
  expect_identical(s@cols$param@width, 1.5)
})

test_that("cols() second-call default does not erase first-call non-default", {
  s <- mk_spec() |>
    cols(param = col_spec(label = "Parameter")) |>
    cols(param = col_spec(usage = "group"))
  expect_identical(s@cols$param@label, "Parameter")
  expect_identical(s@cols$param@usage, "group")
})

test_that("cols() second-call non-default overrides first-call", {
  s <- mk_spec() |>
    cols(param = col_spec(label = "Old")) |>
    cols(param = col_spec(label = "New"))
  expect_identical(s@cols$param@label, "New")
})

# Edge case 8: across with high cardinality — not checked here --------
# That check belongs to engine_validate (not cols()).

# Edge case 9: malformed sprintf — already caught by col_spec() -------
# Engine doesn't see it. Covered in test-col_spec.R.

# Edge case 10: width <= 0 — caught at col_spec() ---------------------
# Covered in test-col_spec.R.

# Spec input validation ------------------------------------------------

test_that("cols() rejects non-spec first argument", {
  expect_error(
    cols(list(), param = col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects unnamed entries", {
  expect_error(
    mk_spec() |> cols(col_spec(usage = "group")),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects partially named entries", {
  expect_error(
    mk_spec() |> cols(param = col_spec(), col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects non-col_spec values", {
  expect_error(
    mk_spec() |> cols(param = "not a spec"),
    class = "tabular_error_input"
  )
})

# Merge: format / visible / align / na_text ----------------------------

test_that("cols() merges format (non-NULL second call overrides)", {
  fn <- function(x) format(x, nsmall = 2)
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(format = fn))
  expect_identical(s@cols$drug_a@format, fn)
  expect_identical(s@cols$drug_a@label, "Drug A")
})

test_that("cols() merges format = NULL leaves prior format alone", {
  fn <- function(x) format(x, nsmall = 2)
  s <- mk_spec() |>
    cols(drug_a = col_spec(format = fn)) |>
    cols(drug_a = col_spec(label = "Drug A"))
  expect_identical(s@cols$drug_a@format, fn)
  expect_identical(s@cols$drug_a@label, "Drug A")
})

test_that("cols() merges visible = FALSE (non-default overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(visible = FALSE))
  expect_false(s@cols$drug_a@visible)
})

test_that("cols() merges align (non-NA overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(align = "right")) |>
    cols(drug_a = col_spec(align = "decimal"))
  expect_identical(s@cols$drug_a@align, "decimal")
})

test_that("cols() merges na_text (non-empty second call overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(na_text = "-"))
  expect_identical(s@cols$drug_a@na_text, "-")
})

# Dynamic names: rlang `:=` and `!!!` splice --------------------------
# Programmatic column names (built from a variable, looped, or spliced
# from a list) must work the way they do in dplyr. Regression for the
# bare `list(...)` capture that swallowed injection operators.

test_that("cols() accepts a dynamic name via :=", {
  nm <- "drug_a"
  s <- mk_spec() |> cols(!!nm := col_spec(label = "Programmatic"))
  expect_identical(s@cols$drug_a@label, "Programmatic")
  expect_identical(s@cols$drug_a@name, "drug_a")
})

test_that("cols() accepts a named list spliced with !!!", {
  specs <- list(
    param = col_spec(usage = "group"),
    drug_a = col_spec(label = "A")
  )
  s <- mk_spec() |> cols(!!!specs)
  expect_named(s@cols, c("param", "drug_a"))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$drug_a@label, "A")
})

test_that("cols() still rejects an unnamed !!! splice", {
  expect_error(
    mk_spec() |> cols(!!!list(col_spec(usage = "group"))),
    class = "tabular_error_input"
  )
})
