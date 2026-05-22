# cli output is environment-dependent (terminal width, unicode mode,
# styling). `local_reproducible_output()` neutralises most but not all,
# so cli snapshots are flaky across `devtools::test()` and R CMD check.
# These tests assert *content* via substring matches instead --
# stable across environments while still pinning the intent of each
# branch of `.tabular_spec_print()`.

print_lines <- function(spec) {
  out <- testthat::capture_messages(
    tabular:::.tabular_spec_print(spec)
  )
  paste(out, collapse = "")
}

test_that("print.tabular_spec returns the spec invisibly", {
  spec <- tb_table(data.frame(x = 1L))
  result <- withVisible(print(spec))
  expect_false(result$visible)
  expect_identical(result$value, spec)
})

test_that(".tabular_spec_print() emits class header and data dims", {
  spec <- tb_table(data.frame(stat = "n", trt = "10"))
  out <- print_lines(spec)
  expect_match(out, "tabular_spec")
  expect_match(out, "Data: 1 row x 2 columns")
})

test_that(".tabular_spec_print() pluralises rows/columns correctly", {
  spec <- tb_table(
    data.frame(stat = c("n", "Mean"), trt = c("10", "5.0"))
  )
  out <- print_lines(spec)
  expect_match(out, "2 rows x 2 columns")
})

test_that(".tabular_spec_print() emits titles when present", {
  spec <- tb_table(
    data.frame(x = 1L),
    titles = c("Table 14.1.1", "Demographics")
  )
  out <- print_lines(spec)
  expect_match(out, "Titles \\(2\\)")
  expect_match(out, "Table 14.1.1")
  expect_match(out, "Demographics")
})

test_that(".tabular_spec_print() truncates titles longer than 60 chars", {
  long <- paste(rep("X", 80L), collapse = "")
  spec <- tb_table(data.frame(x = 1L), titles = long)
  out <- print_lines(spec)
  expect_match(out, "X{50,}\\.\\.\\.")
  expect_false(grepl(long, out, fixed = TRUE))
})

test_that(".tabular_spec_print() emits footnote count", {
  spec <- tb_table(
    data.frame(x = 1L),
    footnotes = c("F1", "F2")
  )
  out <- print_lines(spec)
  expect_match(out, "Footnotes: 2 lines")
})

test_that(".tabular_spec_print() emits pagination line when set", {
  spec <- tb_table(data.frame(x = 1L), rows_per_page = 40L)
  out <- print_lines(spec)
  expect_match(out, "Pagination: every 40 rows")
})

test_that(".tabular_spec_print() omits optional sections when empty", {
  spec <- tb_table(data.frame(x = 1L))
  out <- print_lines(spec)
  expect_false(grepl("Titles", out))
  expect_false(grepl("Footnotes", out))
  expect_false(grepl("Pagination", out))
  expect_false(grepl("Config", out))
})

test_that(".tabular_spec_print() emits Config section when fields populated", {
  # No public verb yet populates @columns / @rows / @spans / @styles
  # / @markup (Phase 1b lifts the stubs), so exercise the Config
  # branch via S7::set_props() on a stub list.
  spec <- tb_table(data.frame(x = 1L))
  spec <- S7::set_props(spec, columns = list(c1 = list()))
  out <- print_lines(spec)
  expect_match(out, "Config:.*columns \\(1\\)")
})
