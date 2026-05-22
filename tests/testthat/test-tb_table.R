# Minimal inline fixture for type-checking tests. Use saf_demo only
# where the test asserts integration with the package demo dataset
# (rules/tests.md prefers inline `data.frame()` literals for unit tests).
demo_df <- function() {
  data.frame(
    stat = c("n (%)", "Mean (SD)"),
    trt_a = c("14 (66.7)", "56.3 (12.7)"),
    trt_b = c("12 (57.1)", "54.8 (11.9)"),
    stringsAsFactors = FALSE
  )
}

test_that("tb_table() constructs a tabular_spec from valid input", {
  spec <- tb_table(
    demo_df(),
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Percentages based on N per treatment group."
  )

  expect_true(is_tabular_spec(spec))
  expect_s3_class(spec@data, "data.frame")
  expect_equal(
    spec@titles,
    c("Table 14.1.1", "Demographics", "Safety Population")
  )
  expect_equal(spec@footnotes, "Percentages based on N per treatment group.")
  expect_equal(spec@continuation, "(continued)")
  expect_true(is.na(spec@rows_per_page))
})

test_that("tb_table() integrates with the shipped saf_demo dataset", {
  spec <- tb_table(saf_demo)
  expect_true(is_tabular_spec(spec))
  expect_identical(spec@data, saf_demo)
})

test_that("tb_table() defaults NULL titles/footnotes to character(0)", {
  spec <- tb_table(demo_df())
  expect_identical(spec@titles, character())
  expect_identical(spec@footnotes, character())
})

test_that("tb_table() rejects non-data-frame data", {
  expect_snapshot(error = TRUE, tb_table(list(a = 1, b = 2)))
  expect_error(tb_table(1:5), class = "tabular_error_input")
  expect_error(tb_table("hello"), class = "tabular_error_input")
  expect_error(tb_table(NULL), class = "tabular_error_input")
})

test_that("tb_table() rejects non-character titles/footnotes", {
  expect_error(
    tb_table(demo_df(), titles = 1:3),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), footnotes = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("tb_table() handles empty data frame as an edge case", {
  spec <- tb_table(data.frame())
  expect_true(is_tabular_spec(spec))
  expect_equal(nrow(spec@data), 0L)
})

test_that("tb_table() accepts positive whole-number rows_per_page", {
  spec <- tb_table(demo_df(), rows_per_page = 40)
  expect_identical(spec@rows_per_page, 40L)

  spec_int <- tb_table(demo_df(), rows_per_page = 40L)
  expect_identical(spec_int@rows_per_page, 40L)
})

test_that("tb_table() rejects fractional, non-numeric, or non-finite rows_per_page", {
  expect_error(
    tb_table(demo_df(), rows_per_page = 2.5),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = "40"),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = c(10L, 20L)),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = NA_integer_),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = Inf),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = NaN),
    class = "tabular_error_input"
  )
})

test_that("tb_table() rejects zero and negative rows_per_page", {
  expect_error(
    tb_table(demo_df(), rows_per_page = 0L),
    class = "tabular_error_input"
  )
  expect_error(
    tb_table(demo_df(), rows_per_page = -1L),
    class = "tabular_error_input"
  )
})

test_that("tb_table() no longer accepts preset / continuation / paginate_at", {
  expect_error(
    tb_table(demo_df(), preset = "anything"),
    "unused argument"
  )
  expect_error(
    tb_table(demo_df(), continuation = "(cont.)"),
    "unused argument"
  )
  expect_error(
    tb_table(demo_df(), paginate_at = 40),
    "unused argument"
  )
})
