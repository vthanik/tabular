# paginate() — verb that attaches a pagination_spec to a tabular_spec.
# Tests cover argument validation, replacement semantics, keep_together
# column checks, and edge cases on the floors / scalars.
# The verb does NOT take a rows_per_page argument; the engine computes
# the row budget from preset + chrome lines.

make_spec <- function(n = 10L, with_group = TRUE) {
  df <- data.frame(
    soc = rep(c("A", "B"), length.out = n),
    val = seq_len(n)
  )
  spec <- tabular(df)
  if (with_group) {
    spec <- cols(spec, soc = col_spec(label = "SOC")) |>
      group_rows(by = "soc")
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
  expect_identical(pag@repeat_content, c("titles", "headers", "footnotes"))
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

test_that("paginate() accepts keep_together on a non-group column", {
  # A block key often rides along hidden (col_spec(visible = FALSE)) —
  # e.g. an AE table whose SOC lives in the label text, keyed by a
  # hidden soc column. The engine only needs runs of values in data.
  spec <- make_spec(10L, with_group = FALSE)
  out <- paginate(spec, keep_together = "soc")
  expect_identical(out@pagination@keep_together, "soc")
})

test_that("paginate() accepts keep_together on a hidden column", {
  spec <- make_spec(10L, with_group = FALSE) |>
    cols(soc = col_spec(visible = FALSE))
  out <- paginate(spec, keep_together = "soc")
  expect_identical(out@pagination@keep_together, "soc")
})

test_that("paginate() accepts keep_together referencing a group column", {
  spec <- make_spec(10L)
  out <- paginate(spec, keep_together = "soc")
  expect_identical(out@pagination@keep_together, "soc")
})

test_that('paginate() rejects panels = "auto" (removed no-op)', {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, panels = "auto"),
    class = "tabular_error_input"
  )
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

test_that("paginate() rejects unknown repeat_content values", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, repeat_content = "header"), # typo for "headers"
    class = "tabular_error_input"
  )
})

test_that("paginate() accepts a repeat_content subset and character()", {
  spec <- make_spec(10L)
  sub <- paginate(spec, repeat_content = c("headers", "footnotes"))
  expect_identical(sub@pagination@repeat_content, c("headers", "footnotes"))

  none <- paginate(spec, repeat_content = character())
  expect_identical(none@pagination@repeat_content, character())

  # NULL is accepted and means "repeat nothing".
  null_rc <- paginate(spec, repeat_content = NULL)
  expect_identical(null_rc@pagination@repeat_content, character())
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
    paginate(spec, keep_together = "nope")
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

# repeat_cols — the explicit panel stub -------------------------------

test_that("paginate() stores validated repeat_cols and derives the default stub", {
  spec <- make_spec(10L) |> group_rows(by = "soc", display = "column")
  # NULL default: stub derives from the group_rows keys.
  p_default <- paginate(spec, panels = 2L)
  expect_null(p_default@pagination@repeat_cols)
  expect_identical(tabular:::.stub_col_names(p_default), "soc")
  # Explicit vector REPLACES the default (deduplicated).
  p_explicit <- paginate(spec, panels = 2L, repeat_cols = c("val", "val"))
  expect_identical(p_explicit@pagination@repeat_cols, "val")
  expect_identical(tabular:::.stub_col_names(p_explicit), "val")
  # character() = no stub at all.
  p_none <- paginate(spec, panels = 2L, repeat_cols = character())
  expect_identical(tabular:::.stub_col_names(p_none), character())
})

test_that("paginate() default stub excludes display = 'none' break-only keys", {
  spec <- make_spec(10L) |>
    group_rows(by = c("soc", "val"), display = c("none", "column")) |>
    paginate(panels = 2L)
  expect_identical(tabular:::.stub_col_names(spec), "val")
})

test_that("paginate() rejects repeat_cols not in data", {
  spec <- make_spec(10L)
  expect_error(
    paginate(spec, repeat_cols = "nope"),
    class = "tabular_error_input"
  )
  expect_snapshot(error = TRUE, paginate(spec, repeat_cols = "nope"))
})
