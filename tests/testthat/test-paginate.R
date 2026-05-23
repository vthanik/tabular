# paginate() — verb that attaches a pagination_spec to a tabular_spec.
# Tests cover argument validation, replacement semantics, group-column
# enforcement on keep_together, and edge cases on the floors / scalars.
# The verb does NOT take a rows_per_page argument; the engine computes
# the row budget from preset + chrome lines.

make_spec <- function(n = 10L, with_group = TRUE) {
  df <- data.frame(
    soc = rep(c("A", "B"), length.out = n),
    val = seq_len(n)
  )
  spec <- tabular(df)
  if (with_group) {
    spec <- cols(spec, soc = col_spec(usage = "group", label = "SOC"))
  }
  spec
}

test_that("paginate() returns a tabular_spec with pagination_spec attached", {
  spec <- make_spec(10L)
  out <- paginate(spec, keep_together = "soc")
  expect_true(is_tabular_spec(out))
  expect_true(is_pagination_spec(out@pagination))
  expect_identical(out@pagination@keep_together, "soc")
})

test_that("paginate() with all defaults stores defaults", {
  spec <- make_spec(10L)
  out <- paginate(spec)
  pag <- out@pagination
  expect_identical(pag@keep_together, character())
  expect_identical(pag@panels, 1L)
  expect_identical(pag@orphan_floor, 3L)
  expect_identical(pag@widow_floor, 2L)
  expect_true(pag@repeat_headers)
  expect_identical(pag@continuation, character())
})

test_that("paginate() replaces a prior pagination_spec (single-slot)", {
  spec <- make_spec(10L) |>
    paginate(panels = 2L) |>
    paginate(panels = 3L)
  expect_identical(spec@pagination@panels, 3L)
})

test_that("paginate() rejects keep_together referencing missing columns", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, keep_together = "nope"),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects keep_together referencing non-group columns", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, keep_together = "val"),
    class = "tabular_error_input"
  )
})

test_that("paginate() accepts keep_together referencing a group column", {
  spec <- make_spec(10L)
  out <- paginate(spec, keep_together = "soc")
  expect_identical(out@pagination@keep_together, "soc")
})

test_that('paginate() accepts panels = "auto"', {
  spec <- make_spec(10L)
  out <- paginate(spec, panels = "auto")
  expect_identical(out@pagination@panels, "auto")
})

test_that("paginate() accepts panels as a positive integer", {
  spec <- make_spec(10L)
  out <- paginate(spec, panels = 3L)
  expect_identical(out@pagination@panels, 3L)
})

test_that("paginate() rejects panels = 0", {
  spec <- make_spec(10L)
  expect_error(paginate(spec, panels = 0), class = "tabular_error_input")
})

test_that("paginate() rejects panels = -1", {
  spec <- make_spec(10L)
  expect_error(paginate(spec, panels = -1), class = "tabular_error_input")
})

test_that("paginate() rejects panels = 2.5", {
  spec <- make_spec(10L)
  expect_error(paginate(spec, panels = 2.5), class = "tabular_error_input")
})

test_that('paginate() rejects panels = "foo"', {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, panels = "foo"),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects orphan_floor = 0", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, orphan_floor = 0),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects widow_floor = -1", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, widow_floor = -1),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects non-scalar repeat_headers", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, repeat_headers = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects NA repeat_headers", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, repeat_headers = NA),
    class = "tabular_error_input"
  )
})

test_that("paginate() rejects non-scalar continuation", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, continuation = c("a", "b")),
    class = "tabular_error_input"
  )
})

test_that('paginate() accepts continuation = "" (literal empty marker)', {
  spec <- make_spec(10L)
  out <- paginate(spec, continuation = "")
  expect_identical(out@pagination@continuation, "")
})

test_that("paginate() default continuation is empty (no marker)", {
  spec <- make_spec(10L)
  out <- paginate(spec)
  expect_identical(out@pagination@continuation, character())
})

test_that("paginate() stores a user-supplied continuation marker", {
  spec <- make_spec(10L)
  out <- paginate(spec, continuation = "(continued)")
  expect_identical(out@pagination@continuation, "(continued)")
})

test_that("paginate() rejects non-spec first arg", {
  expect_error(paginate("not a spec"), class = "tabular_error_input")
})

test_that("paginate() snapshot errors", {
  spec <- make_spec(10L)
  expect_snapshot(
    error = TRUE,
    paginate(spec, keep_together = "val")
  )
  expect_snapshot(
    error = TRUE,
    paginate(spec, panels = "weird")
  )
  expect_snapshot(
    error = TRUE,
    paginate(spec, continuation = c("a", "b"))
  )
})
