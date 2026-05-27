# test-util_runs.R — coverage for the shared run-grouping primitive
# at R/util_runs.R. Backends consume the records to compute colspan /
# `\SetCell[c=N]` / `<w:gridSpan>` / `\cellx` widths; correctness of
# the primitive is load-bearing across every backend's header band.

test_that(".group_contiguous_runs() returns empty list for empty input", {
  expect_identical(tabular:::.group_contiguous_runs(character()), list())
})

test_that(".group_contiguous_runs() single-element input is one run of length 1", {
  out <- tabular:::.group_contiguous_runs("x")
  expect_length(out, 1L)
  expect_identical(out[[1L]]$value, "x")
  expect_identical(out[[1L]]$length, 1L)
})

test_that(".group_contiguous_runs() all-NA collapses to one NA run", {
  out <- tabular:::.group_contiguous_runs(rep(NA_character_, 4L))
  expect_length(out, 1L)
  expect_true(is.na(out[[1L]]$value))
  expect_identical(out[[1L]]$length, 4L)
})

test_that(".group_contiguous_runs() alternating values produce length-1 runs", {
  out <- tabular:::.group_contiguous_runs(c("a", "b", "a", "b"))
  expect_length(out, 4L)
  expect_identical(
    vapply(out, function(r) r$length, integer(1L)),
    rep(1L, 4L)
  )
})

test_that(".group_contiguous_runs() detects NA-to-value and value-to-NA boundaries", {
  x <- c(NA, NA, "a", "a", NA, "b")
  out <- tabular:::.group_contiguous_runs(x)
  expect_length(out, 4L)
  expect_identical(
    vapply(out, function(r) r$length, integer(1L)),
    c(2L, 2L, 1L, 1L)
  )
  expect_true(is.na(out[[1L]]$value))
  expect_identical(out[[2L]]$value, "a")
  expect_true(is.na(out[[3L]]$value))
  expect_identical(out[[4L]]$value, "b")
})

test_that(".group_contiguous_runs() collapses contiguous duplicates including final run", {
  out <- tabular:::.group_contiguous_runs(c("x", "x", "x"))
  expect_length(out, 1L)
  expect_identical(out[[1L]]$length, 3L)
})

test_that(".group_contiguous_runs() preserves the last run when input ends mid-change", {
  out <- tabular:::.group_contiguous_runs(c("a", "a", "b"))
  expect_length(out, 2L)
  expect_identical(out[[1L]]$length, 2L)
  expect_identical(out[[2L]]$length, 1L)
})
