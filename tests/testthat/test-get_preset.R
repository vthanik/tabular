# get_preset() — introspect the session-default preset. Tests cover
# the NULL-when-unset baseline, the preset_spec-when-set behaviour,
# and the read-tweak-attach pattern (copying the session default into
# a per-spec preset() override).

clear_session_preset <- function(env = parent.frame()) {
  withr::defer(set_preset(.reset = TRUE), envir = env)
}

test_that("get_preset() returns NULL when no session default is set", {
  clear_session_preset()
  set_preset(.reset = TRUE)
  expect_null(get_preset())
})

test_that("get_preset() returns the active preset_spec after set_preset()", {
  clear_session_preset()
  set_preset(font_size = 8, orientation = "landscape")
  active <- get_preset()
  expect_true(is_preset_spec(active))
  expect_identical(active@font_size, 8)
  expect_identical(active@orientation, "landscape")
})

test_that("get_preset() reflects the most recent set_preset() merge", {
  clear_session_preset()
  set_preset(font_size = 8)
  expect_identical(get_preset()@font_size, 8)
  set_preset(font_size = 10)
  expect_identical(get_preset()@font_size, 10)
})

test_that("get_preset() returns NULL after set_preset(.reset = TRUE) with no knobs", {
  clear_session_preset()
  set_preset(font_size = 8)
  expect_true(is_preset_spec(get_preset()))
  set_preset(.reset = TRUE)
  expect_null(get_preset())
})

test_that("get_preset() supports the read-tweak-attach pattern", {
  clear_session_preset()
  set_preset(font_size = 9, paper_size = "letter")

  base <- get_preset()
  # Tweak one knob via per-spec preset() without mutating the session.
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      font_size = base@font_size,
      paper_size = base@paper_size,
      orientation = "landscape"
    )

  # Session default unchanged
  expect_identical(get_preset()@font_size, 9)
  expect_identical(get_preset()@paper_size, "letter")
  expect_identical(get_preset()@orientation, "portrait")
  # Per-spec preset carries the tweak
  expect_identical(spec@preset@orientation, "landscape")
})
