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

test_that("set_preset() returns the prior session preset invisibly", {
  clear_session_preset()

  # First call into a fresh session: prior was NULL.
  first <- set_preset(font_size = 8)
  expect_null(first)

  # Second call: prior is the preset that the first call installed.
  second <- set_preset(orientation = "landscape")
  expect_true(is_preset_spec(second))
  expect_identical(second@font_size, 8)
  expect_identical(second@orientation, "portrait") # before this call
})

test_that("set_preset(.reset = TRUE) returns the prior preset invisibly", {
  clear_session_preset()

  # Empty session: clearing returns NULL.
  expect_null(set_preset(.reset = TRUE))

  # Populated session: clearing returns the prior preset.
  set_preset(font_size = 8, orientation = "landscape")
  ret <- set_preset(.reset = TRUE)
  expect_true(is_preset_spec(ret))
  expect_identical(ret@font_size, 8)
  expect_identical(ret@orientation, "landscape")
  expect_null(get_preset())
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

# ---------------------------------------------------------------------
# Positional `new` arg — wholesale install + save/restore round-trip
# ---------------------------------------------------------------------

test_that("set_preset(<preset_spec>) installs the spec wholesale", {
  clear_session_preset()
  house <- preset_spec(
    font_size = 7,
    paper_size = "a4",
    orientation = "landscape"
  )
  prior <- set_preset(house)
  expect_null(prior)
  expect_identical(get_preset(), house)
})

test_that("set_preset(<preset_spec>) returns the prior session preset", {
  clear_session_preset()
  set_preset(font_size = 8)
  house <- preset_spec(font_size = 11, paper_size = "a4")
  prior <- set_preset(house)
  expect_true(is_preset_spec(prior))
  expect_identical(prior@font_size, 8)
  # And get_preset() now reflects the wholesale install.
  expect_identical(get_preset(), house)
})

test_that("set_preset() round-trips via the positional `new` arg", {
  clear_session_preset()
  set_preset(font_size = 8, paper_size = "letter")
  baseline <- get_preset()

  old <- set_preset(
    font_size = 10,
    paper_size = "a4",
    orientation = "landscape"
  )
  expect_identical(old, baseline)

  # Restore — `old` is a preset_spec so the positional path applies.
  set_preset(old)
  expect_identical(get_preset(), baseline)
})

test_that("set_preset(<preset_spec>, font_size = ...) errors mutex", {
  clear_session_preset()
  house <- preset_spec(font_size = 9)
  expect_error(
    set_preset(house, font_size = 8),
    class = "tabular_error_input"
  )
})

test_that("set_preset(<preset_spec>, .template = ...) errors mutex", {
  clear_session_preset()
  house <- preset_spec(font_size = 9)
  base <- preset_spec(paper_size = "a4")
  expect_error(
    set_preset(house, .template = base),
    class = "tabular_error_input"
  )
})

test_that("set_preset(<preset_spec>, .reset = TRUE) errors mutex", {
  clear_session_preset()
  house <- preset_spec(font_size = 9)
  expect_error(
    set_preset(house, .reset = TRUE),
    class = "tabular_error_input"
  )
})

test_that("set_preset(<non-preset_spec>) errors with type message", {
  clear_session_preset()
  expect_error(
    set_preset("not a preset_spec"),
    class = "tabular_error_input"
  )
  expect_error(
    set_preset(list(font_size = 9)),
    class = "tabular_error_input"
  )
})

test_that("set_preset() new-arg error messages snapshot", {
  clear_session_preset()
  house <- preset_spec(font_size = 9)
  expect_snapshot(
    error = TRUE,
    set_preset(house, font_size = 8)
  )
  expect_snapshot(
    error = TRUE,
    set_preset("not a preset_spec")
  )
})
