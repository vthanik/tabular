# group_rows() — verb that attaches the table-level row-grouping plan
# (a row_group_spec) to a tabular_spec. Tests cover argument
# validation, per-key display/skip recycling, replacement semantics,
# and the subgroup(by =) overlap guard. Display semantics themselves
# (header rows, repeat suppression, skip spacers) are engine concerns
# tested in test-engine and test-group_display files.

make_gr_spec <- function() {
  df <- data.frame(
    variable = rep(c("Age", "Sex"), each = 3L),
    stat_label = rep(c("n", "Mean", "SD"), 2L),
    placebo = as.character(1:6),
    stringsAsFactors = FALSE
  )
  tabular(df)
}

test_that("group_rows() attaches a row_group_spec with recycled display and skip", {
  spec <- make_gr_spec() |> group_rows(by = "variable")
  rg <- spec@row_groups
  expect_true(is_row_group_spec(rg))
  expect_identical(rg@by, "variable")
  expect_identical(rg@display, "header_row")
  expect_identical(rg@skip, NA)

  spec2 <- make_gr_spec() |>
    group_rows(
      by = c("variable", "stat_label"),
      display = "column",
      skip = FALSE
    )
  rg2 <- spec2@row_groups
  expect_identical(rg2@display, c("column", "column"))
  expect_identical(rg2@skip, c(FALSE, FALSE))
})

test_that("group_rows() accepts per-key display and skip vectors", {
  spec <- make_gr_spec() |>
    group_rows(
      by = c("variable", "stat_label"),
      display = c("header_row", "column"),
      skip = c(TRUE, FALSE)
    )
  rg <- spec@row_groups
  expect_identical(rg@display, c("header_row", "column"))
  expect_identical(rg@skip, c(TRUE, FALSE))
})

test_that("group_rows() accepts the break-only display value \"none\"", {
  spec <- make_gr_spec() |>
    group_rows(
      by = c("variable", "stat_label"),
      display = c("none", "column")
    )
  expect_identical(spec@row_groups@display, c("none", "column"))
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
  expect_error(
    group_rows(spec, by = "nope"),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = c("variable", "variable")),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = character()),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = 1L),
    class = "tabular_error_input"
  )
})

test_that("group_rows() rejects bad display values and lengths", {
  spec <- make_gr_spec()
  expect_error(
    group_rows(spec, by = "variable", display = "banner"),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(
      spec,
      by = "variable",
      display = c("header_row", "column")
    ),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = "variable", display = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("group_rows() rejects bad skip values and lengths", {
  spec <- make_gr_spec()
  expect_error(
    group_rows(spec, by = "variable", skip = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(
    group_rows(spec, by = "variable", skip = "yes"),
    class = "tabular_error_input"
  )
})

test_that("group_rows() rejects keys that overlap subgroup(by =)  ", {
  df <- data.frame(
    param = rep(c("SBP", "DBP"), each = 2L),
    visit = rep(c("Baseline", "Week 4"), 2L),
    val = as.character(1:4),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |> subgroup(by = "param")
  expect_error(
    group_rows(spec, by = "param"),
    class = "tabular_error_input"
  )
})

test_that("group_rows() snapshot errors", {
  spec <- make_gr_spec()
  expect_snapshot(error = TRUE, group_rows(spec, by = "nope"))
  expect_snapshot(
    error = TRUE,
    group_rows(spec, by = "variable", display = "banner")
  )
  expect_snapshot(
    error = TRUE,
    group_rows(spec, by = "variable", skip = c(TRUE, FALSE))
  )
})
