# Tests for the footnote() verb (R/footnote.R).

mk_fn_spec <- function() {
  tabular(saf_aesocpt) |>
    cols(
      soc = col_spec(usage = "group"),
      label = col_spec(label = "PT"),
      Total = col_spec(label = "Total")
    )
}

test_that("footnote() appends a record to @footnote_refs", {
  spec <- mk_fn_spec() |>
    footnote("Safety population.", .at = cells_headers(j = "Total"))
  expect_length(spec@footnote_refs, 1L)
  rec <- spec@footnote_refs[[1L]]
  expect_equal(rec$text, "Safety population.")
  expect_true(is_tabular_location(rec$location))
  expect_null(rec$id)
  expect_null(rec$symbol)
})

test_that("footnote() accumulates and carries id / symbol", {
  spec <- mk_fn_spec() |>
    footnote("a", .at = cells_body(j = "label"), id = "x") |>
    footnote("b", .at = cells_headers(j = "Total"), symbol = "*")
  expect_length(spec@footnote_refs, 2L)
  expect_equal(spec@footnote_refs[[1L]]$id, "x")
  expect_equal(spec@footnote_refs[[2L]]$symbol, "*")
})

test_that("footnote() accepts md() / html() text", {
  spec <- mk_fn_spec() |>
    footnote(md("*italic* note"), .at = cells_body(j = "label"))
  expect_s3_class(spec@footnote_refs[[1L]]$text, "from_markdown")
})

test_that("footnote() rejects a non-location .at", {
  expect_snapshot(
    error = TRUE,
    footnote(mk_fn_spec(), "x", .at = "Total")
  )
  expect_error(
    footnote(mk_fn_spec(), "x", .at = "Total"),
    class = "tabular_error_input"
  )
})

test_that("footnote() rejects bad text / id / symbol", {
  expect_error(
    footnote(mk_fn_spec(), c("a", "b")),
    class = "tabular_error_input"
  )
  expect_error(
    footnote(mk_fn_spec(), "x", id = c("a", "b")),
    class = "tabular_error_input"
  )
  expect_error(
    footnote(mk_fn_spec(), "x", symbol = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("footnote() requires a tabular_spec", {
  expect_error(
    footnote(data.frame(x = 1), "note"),
    class = "tabular_error_input"
  )
})
