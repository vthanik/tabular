# group_rows() — verb that attaches the table-level row-grouping plan
# (a row_group_spec) to a tabular_spec. Tests cover argument
# validation, scalar-display broadcast, the TRUE / FALSE / character
# skip resolution (the readr `col_names` pattern), and replacement
# semantics. Display semantics themselves (header rows,
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
  expect_identical(rg@display, "section")
  expect_identical(rg@skip, NA)

  spec2 <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"), display = "collapse")
  rg2 <- spec2@row_groups
  # Scalar display is broadcast to one value per key.
  expect_identical(rg2@display, c("collapse", "collapse"))
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

test_that("group_rows() skip = TRUE derives and matches the default", {
  explicit <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"), skip = TRUE)
  # TRUE stores the NA "derive" sentinel per key -- resolution happens
  # at engine time, where column visibility is known.
  expect_identical(explicit@row_groups@skip, c(NA, NA))
  default <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label"))
  expect_identical(default@row_groups@skip, explicit@row_groups@skip)
})

test_that("group_rows() skip = FALSE inserts no spacers end to end", {
  spec <- make_gr_spec() |> group_rows(by = "variable", skip = FALSE)
  expect_identical(spec@row_groups@skip, FALSE)
  page1 <- as_grid(spec)@pages[[1L]]
  expect_false(any(page1$is_blank_row))
  # Section header rows still inject -- skip only controls blanks.
  expect_true(any(page1$is_header_row))
})

test_that("group_rows() replaces a prior declaration wholesale", {
  spec <- make_gr_spec() |>
    group_rows(by = c("variable", "stat_label")) |>
    group_rows(by = "variable", display = "collapse")
  rg <- spec@row_groups
  expect_identical(rg@by, "variable")
  expect_identical(rg@display, "collapse")
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
    group_rows(spec, by = "variable", display = c("section", "collapse")),
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

test_that("group_rows() rejects a skip outside TRUE / FALSE / character", {
  spec <- make_gr_spec()
  # NA is not a decision; is_bool() rejects it.
  expect_error(
    group_rows(spec, by = "variable", skip = NA),
    class = "tabular_error_input"
  )
  # A logical vector is not the per-key form anymore.
  expect_error(
    group_rows(spec, by = "variable", skip = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  # NULL was the old derive sentinel; TRUE replaced it (clean break).
  expect_error(
    group_rows(spec, by = "variable", skip = NULL),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = "variable", skip = 1L),
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
  expect_snapshot(
    error = TRUE,
    group_rows(spec, by = "variable", skip = NA)
  )
})

test_that("group_rows() accepts every display mode", {
  for (d in c("section", "collapse", "repeat")) {
    spec <- make_gr_spec() |> group_rows(by = "variable", display = d)
    expect_identical(spec@row_groups@display, d)
  }
  # The pre-rename values are gone (clean break, unreleased API).
  for (d in c("header_row", "column", "column_repeat")) {
    expect_error(
      group_rows(make_gr_spec(), by = "variable", display = d),
      class = "tabular_error_input"
    )
  }
})
