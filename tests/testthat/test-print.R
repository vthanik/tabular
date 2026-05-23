# Tests for .tabular_spec_print() via testthat::capture_messages().
#
# We test the helper directly (not via S7::method dispatch) because
# covr does not instrument the dispatch path.

print_lines <- function(spec) {
  msgs <- testthat::capture_messages(
    invisible(.tabular_spec_print(spec))
  )
  paste(msgs, collapse = "")
}

test_that("print returns invisibly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  testthat::expect_invisible(.tabular_spec_print(s))
})

test_that("print shows data dimensions", {
  s <- tabular_spec(data = data.frame(x = 1:3, y = 1:3))
  out <- print_lines(s)
  expect_match(out, "Data: 3 rows x 2 columns")
})

test_that("print pluralises 1 row x 1 column correctly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_match(out, "1 row x 1 column")
})

test_that("print includes titles count and numbered list", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = c("Table 14.1.1", "Demographics", "Safety Pop")
  )
  out <- print_lines(s)
  expect_match(out, "Titles \\(3\\)")
  expect_match(out, "Table 14\\.1\\.1")
  expect_match(out, "Safety Pop")
})

test_that("print truncates very long titles", {
  long_title <- paste(rep("a", 100), collapse = "")
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = long_title
  )
  out <- print_lines(s)
  expect_match(out, "\\.\\.\\.")
})

test_that("print omits title section when no titles", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_false(grepl("Titles", out))
})

test_that("print shows footnote count", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    footnotes = c("Note 1", "Note 2")
  )
  out <- print_lines(s)
  expect_match(out, "Footnotes: 2 lines")
})

test_that("print shows config when cols / pivots / derives configured", {
  c1 <- col_spec(usage = "display")
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    cols = list(x = c1)
  )
  out <- print_lines(s)
  expect_match(out, "Config: cols \\(1\\)")
})

test_that("print shows sort spec when non-empty", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L, y = 1L)),
    sort = sort_spec(by = c("x", "y"))
  )
  out <- print_lines(s)
  expect_match(out, "Sort: x, y")
})

test_that("print shows pagination with keep_together", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(keep_together = "x")
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: keep_together=x")
})

test_that("print shows pagination with panels", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(panels = 2L)
  )
  out <- print_lines(s)
  expect_match(out, "Pagination:.*panels=2")
})

test_that("print shows pagination auto when all defaults", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec()
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: auto")
})
