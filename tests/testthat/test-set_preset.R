# set_preset() — session-default preset. Tests cover storage in the
# package-internal env, merge / reset semantics, NULL-clear with
# `reset = TRUE` and no knobs, knob-name validation, and the cascade
# integration with engine_paginate (session preset visible when the
# spec carries no per-spec override).
#
# Every test uses withr::defer to clear the session env so tests are
# self-contained — otherwise an early set_preset() would leak into
# every subsequent test in the file.

clear_session_preset <- function(env = parent.frame()) {
  withr::defer(set_preset(.reset = TRUE), envir = env)
}

test_that("set_preset() stores a preset_spec in the session env", {
  clear_session_preset()
  set_preset(font_size = 8)
  active <- get_preset()
  expect_true(is_preset_spec(active))
  expect_identical(active@font_size, 8)
})

test_that("set_preset() merges knobs across repeat calls", {
  clear_session_preset()
  set_preset(font_size = 8)
  set_preset(orientation = "landscape")
  active <- get_preset()
  expect_identical(active@font_size, 8)
  expect_identical(active@orientation, "landscape")
})

test_that("set_preset(.reset = TRUE) replaces the session preset", {
  clear_session_preset()
  set_preset(font_size = 8, orientation = "landscape")
  set_preset(.reset = TRUE, font_size = 10)
  active <- get_preset()
  expect_identical(active@font_size, 10)
  # orientation reverts to factory default
  expect_identical(active@orientation, "portrait")
})

test_that("set_preset(.reset = TRUE) with no knobs clears to NULL", {
  clear_session_preset()
  set_preset(font_size = 8)
  expect_true(is_preset_spec(get_preset()))
  set_preset(.reset = TRUE)
  expect_null(get_preset())
})

test_that("set_preset() returns the new preset invisibly", {
  clear_session_preset()
  ret <- set_preset(font_size = 8)
  expect_true(is_preset_spec(ret))
  expect_identical(ret@font_size, 8)
})

test_that("set_preset(.reset = TRUE) with no knobs returns NULL invisibly", {
  clear_session_preset()
  ret <- set_preset(.reset = TRUE)
  expect_null(ret)
})

test_that("set_preset() rejects unknown knob names", {
  clear_session_preset()
  expect_error(
    set_preset(font_zize = 8),
    class = "tabular_error_input"
  )
})

test_that("set_preset() rejects unnamed knobs", {
  clear_session_preset()
  expect_error(set_preset(8), class = "tabular_error_input")
})

test_that("set_preset() rejects bad enum values", {
  clear_session_preset()
  expect_error(
    set_preset(orientation = "diagonal"),
    class = "tabular_error_input"
  )
})

test_that("set_preset() rejects non-scalar reset", {
  clear_session_preset()
  expect_error(
    set_preset(.reset = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(
    set_preset(.reset = NA),
    class = "tabular_error_input"
  )
})

test_that("set_preset() is visible to engine_paginate when spec has no per-spec preset", {
  clear_session_preset()
  spec <- tabular(data.frame(x = 1:5))
  plan_default <- tabular:::engine_paginate(spec)

  set_preset(orientation = "landscape")
  plan_landscape <- tabular:::engine_paginate(spec)
  expect_gt(plan_default$rows_per_page, plan_landscape$rows_per_page)
})

test_that("per-spec preset() wins over session set_preset()", {
  clear_session_preset()
  set_preset(orientation = "landscape")

  # Per-spec override forces portrait; cascade should pick the spec's
  # preset over the session default, so rpp matches a fresh portrait
  # spec rather than the session's landscape default.
  spec_portrait <- tabular(data.frame(x = 1:5)) |>
    preset(orientation = "portrait")
  spec_no_override <- tabular(data.frame(x = 1:5))

  plan_portrait <- tabular:::engine_paginate(spec_portrait)
  plan_landscape <- tabular:::engine_paginate(spec_no_override)

  # The portrait per-spec override should yield more rows per page
  # than the landscape session default at the same font / paper.
  expect_gt(plan_portrait$rows_per_page, plan_landscape$rows_per_page)
})

test_that("set_preset() snapshot errors", {
  clear_session_preset()
  expect_snapshot(
    error = TRUE,
    set_preset(font_zize = 8)
  )
  expect_snapshot(
    error = TRUE,
    set_preset(orientation = "diagonal")
  )
})
