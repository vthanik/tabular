# group_rows() — verb that attaches the table-level row-grouping plan
# (a row_group_spec) to a tabular_spec. Tests cover argument
# validation, scalar-display broadcast, character-skip resolution, and
# replacement semantics. Display semantics themselves (header rows,
# repeat suppression, skip spacers, break-only via visible = FALSE) are
# engine concerns tested in test-group_display / test-group_skip.

make_gr_spec <- function() {
  df <- data.frame(
    variable = rep(c("Age", "Sex"), each = 3L),
    stat_label = rep(c("n", "Mean", "SD"), 2L),
    placebo = as.character(1:6),
    stringsAsFactors = FALSE
  )
  tabular(df)
}

test_that("group_rows() attaches a row_group_spec, broadcasting display", {
  spec <- make_gr_spec() |> group_rows(by = "variable")
  rg <- spec@row_groups
  expect_true(is_row_group_spec(rg))
  expect_identical(rg@by, "variable")
  expect_identical(rg@display, "header_row")
  expect_identical(rg@skip, NA)

  spec2 <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"), display = "column")
  rg2 <- spec2@row_groups
  # Scalar display is broadcast to one value per key.
  expect_identical(rg2@display, c("column", "column"))
  expect_identical(rg2@skip, c(NA, NA))
})

test_that("group_rows() skip names the keys that break; unnamed keys do not", {
  spec <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"), skip = "variable")
  # "variable" breaks (TRUE), unnamed "stat_label" does not (FALSE) --
  # an explicit character set, no NA-derive for the unnamed key.
  expect_identical(spec@row_groups@skip, c(TRUE, FALSE))

  none <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"), skip = character())
  expect_identical(none@row_groups@skip, c(FALSE, FALSE))
})

test_that("group_rows() replaces a prior declaration wholesale", {
  spec <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label")) |>
    group_rows(by = "variable", display = "column")
  rg <- spec@row_groups
  expect_identical(rg@by, "variable")
  expect_identical(rg@display, "column")
})

test_that("group_rows() rejects a non-spec first argument", {
  expect_error(
    group_rows(data.frame(x = 1), by = "x"),
    class = "tabular_error_input"
  )
})

test_that("group_rows() rejects missing, duplicated, and empty by keys", {
  spec <- make_gr_spec()
  expect_error(group_rows(spec, by = "nope"), class = "tabular_error_input")
  expect_error(
    group_rows(spec, by = c("variable", "variable")),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = character()),
    class = "tabular_error_input"
  )
  expect_error(group_rows(spec, by = 1L), class = "tabular_error_input")
})

test_that("group_rows() rejects a non-scalar or unknown display", {
  spec <- make_gr_spec()
  # Unknown value.
  expect_error(
    group_rows(spec, by = "variable", display = "banner"),
    class = "tabular_error_input"
  )
  # display is scalar now -- a per-key vector is rejected.
  expect_error(
    group_rows(spec, by = "variable", display = c("header_row", "column")),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = "variable", display = NA_character_),
    class = "tabular_error_input"
  )
  # The former "none" mode is gone (use visible = FALSE instead).
  expect_error(
    group_rows(spec, by = "variable", display = "none"),
    class = "tabular_error_input"
  )
})

test_that("group_rows() rejects a non-character skip or an unknown key", {
  spec <- make_gr_spec()
  # skip is a character set of by keys now, not a logical.
  expect_error(
    group_rows(spec, by = "variable", skip = TRUE),
    class = "tabular_error_input"
  )
  # Naming a column that is not a grouping key.
  expect_error(
    group_rows(spec, by = "variable", skip = "stat_label"),
    class = "tabular_error_input"
  )
})

test_that("group_rows() snapshot errors", {
  spec <- make_gr_spec()
  expect_snapshot(error = TRUE, group_rows(spec, by = "nope"))
  expect_snapshot(
    error = TRUE,
    group_rows(spec, by = "variable", display = "none")
  )
  expect_snapshot(
    error = TRUE,
    group_rows(spec, by = "variable", skip = "stat_label")
  )
})
