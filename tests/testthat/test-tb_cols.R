demo_df <- function() {
  data.frame(
    stat = c("n (%)", "Mean (SD)"),
    placebo = c("14 (66.7)", "56.3 (12.7)"),
    drug_50 = c("12 (57.1)", "54.8 (11.9)"),
    stringsAsFactors = FALSE
  )
}

demo_spec <- function() tb_table(demo_df())

# Happy paths --------------------------------------------------------------

test_that("tb_cols() seeds one column_spec per data column on first call", {
  spec <- demo_spec() |> tb_cols(labels = c(stat = "Statistic"))

  expect_true(is_tabular_spec(spec))
  expect_length(spec@columns, 3L)
  expect_named(spec@columns, c("stat", "placebo", "drug_50"))
  for (col in spec@columns) {
    expect_true(S7::S7_inherits(col, column_spec))
  }
  expect_equal(spec@columns$stat@label, "Statistic")
  expect_true(is.na(spec@columns$placebo@label))
})

test_that("tb_cols() applies labels, width, align, visible, n together", {
  spec <- demo_spec() |>
    tb_cols(
      labels = c(stat = "Statistic", placebo = "Placebo"),
      width = c(stat = 2.5, placebo = 1.5),
      align = c(stat = "left", placebo = "decimal"),
      visible = c(drug_50 = FALSE),
      n = c(placebo = 86L, drug_50 = 84L)
    )

  expect_equal(spec@columns$stat@label, "Statistic")
  expect_equal(spec@columns$stat@width, 2.5)
  expect_equal(spec@columns$stat@align, "left")
  expect_equal(spec@columns$placebo@align, "decimal")
  expect_equal(spec@columns$placebo@n, 86L)
  expect_false(spec@columns$drug_50@visible)
})

test_that("tb_cols(align = c('*' = ...)) sets default for unnamed columns", {
  spec <- demo_spec() |>
    tb_cols(align = c(stat = "left", "*" = "decimal"))

  expect_equal(spec@columns$stat@align, "left")
  expect_equal(spec@columns$placebo@align, "decimal")
  expect_equal(spec@columns$drug_50@align, "decimal")
})

test_that("tb_cols() wildcard does not overwrite an explicit prior align", {
  spec <- demo_spec() |>
    tb_cols(align = c(stat = "left")) |>
    tb_cols(align = c("*" = "right"))

  expect_equal(spec@columns$stat@align, "left")
  expect_equal(spec@columns$placebo@align, "right")
})

test_that("tb_cols() chained calls merge fields (do not reset earlier work)", {
  spec <- demo_spec() |>
    tb_cols(labels = c(stat = "Statistic")) |>
    tb_cols(width = c(stat = 2.5)) |>
    tb_cols(align = c(stat = "left"))

  expect_equal(spec@columns$stat@label, "Statistic")
  expect_equal(spec@columns$stat@width, 2.5)
  expect_equal(spec@columns$stat@align, "left")
})

test_that("tb_cols() with no field args returns a seeded spec", {
  spec <- demo_spec() |> tb_cols()
  expect_length(spec@columns, 3L)
  expect_true(all(vapply(
    spec@columns,
    function(c) is.na(c@label),
    logical(1)
  )))
})

test_that("tb_cols() integrates with saf_demo end-to-end", {
  spec <- tb_table(saf_demo) |>
    tb_cols(
      labels = stats::setNames(
        paste0("col_", names(saf_demo)),
        names(saf_demo)
      )
    )
  expect_length(spec@columns, ncol(saf_demo))
  expect_named(spec@columns, names(saf_demo))
})

# Error paths --------------------------------------------------------------

test_that("tb_cols() rejects non-tabular_spec input", {
  expect_error(
    tb_cols(data.frame(x = 1)),
    class = "tabular_error_input"
  )
  expect_error(tb_cols(NULL), class = "tabular_error_input")
  expect_error(tb_cols("not a spec"), class = "tabular_error_input")
})

test_that("tb_cols() rejects unnamed vectors", {
  expect_error(
    demo_spec() |> tb_cols(labels = c("Placebo", "Drug")),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c(1.5, 2.0)),
    class = "tabular_error_input"
  )
})

test_that("tb_cols() rejects partially named vectors", {
  partial <- c("Placebo", drug_50 = "Drug")
  expect_error(
    demo_spec() |> tb_cols(labels = partial),
    class = "tabular_error_input"
  )
})

test_that("tb_cols() rejects names not in spec@data", {
  expect_error(
    demo_spec() |> tb_cols(labels = c(not_a_col = "X")),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(visible = c(typo_col = FALSE)),
    class = "tabular_error_input"
  )
})

test_that("tb_cols() rejects duplicate names", {
  dup <- c(stat = "A", stat = "B")
  expect_error(
    demo_spec() |> tb_cols(labels = dup),
    class = "tabular_error_input"
  )
})

test_that("tb_cols() rejects '*' wildcard outside align", {
  expect_error(
    demo_spec() |> tb_cols(labels = c("*" = "Default")),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c("*" = 1.5)),
    class = "tabular_error_input"
  )
})

test_that("tb_cols(labels = ...) rejects non-character / NA", {
  expect_error(
    demo_spec() |> tb_cols(labels = c(stat = 1L)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(labels = c(stat = NA_character_)),
    class = "tabular_error_input"
  )
})

test_that("tb_cols(width = ...) rejects non-positive / non-finite / NA", {
  expect_error(
    demo_spec() |> tb_cols(width = c(stat = 0)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c(stat = -1)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c(stat = Inf)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c(stat = NA_real_)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(width = c(stat = "wide")),
    class = "tabular_error_input"
  )
})

test_that("tb_cols(align = ...) rejects invalid values", {
  expect_error(
    demo_spec() |> tb_cols(align = c(stat = "justify")),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(align = c(stat = "LEFT")),
    class = "tabular_error_input"
  )
})

test_that("tb_cols(visible = ...) rejects non-logical / NA", {
  expect_error(
    demo_spec() |> tb_cols(visible = c(stat = "yes")),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(visible = c(stat = NA)),
    class = "tabular_error_input"
  )
})

test_that("tb_cols(n = ...) rejects non-positive / fractional / NA", {
  expect_error(
    demo_spec() |> tb_cols(n = c(stat = 0L)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(n = c(stat = -5L)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(n = c(stat = 2.5)),
    class = "tabular_error_input"
  )
  expect_error(
    demo_spec() |> tb_cols(n = c(stat = NA_integer_)),
    class = "tabular_error_input"
  )
})

# Edge cases ---------------------------------------------------------------

test_that("tb_cols() on a single-column spec works", {
  one_col <- data.frame(x = c("a", "b"), stringsAsFactors = FALSE)
  spec <- tb_table(one_col) |> tb_cols(labels = c(x = "X"))
  expect_length(spec@columns, 1L)
  expect_equal(spec@columns$x@label, "X")
})

test_that("tb_cols(n = numeric()) coerces to integer", {
  spec <- demo_spec() |> tb_cols(n = c(stat = 5))
  expect_identical(spec@columns$stat@n, 5L)
})
