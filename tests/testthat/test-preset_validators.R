# preset_validators.R — pure shape-error helpers behind the lowered
# `preset()` knobs. Each returns NULL when the value is well-formed (or
# empty / NULL, which `.validate_lowered_knobs()` skips) and an error
# string otherwise. Tested directly: the empty-input early returns are
# unreachable through `preset()` (the caller skips zero-length knobs),
# so a direct call is the only way to exercise them.

# ---- rules ----------------------------------------------------------

test_that(".preset_rules_shape_error covers every branch", {
  expect_null(tabular:::.preset_rules_shape_error(list())) # empty -> NULL
  expect_null(tabular:::.preset_rules_shape_error("booktabs")) # valid sugar
  expect_match(
    tabular:::.preset_rules_shape_error("nope"),
    "unknown"
  )
  expect_null(tabular:::.preset_rules_shape_error(brdr())) # single brdr
  expect_match(
    tabular:::.preset_rules_shape_error(1L),
    "must be a preset name"
  )
  expect_match(
    tabular:::.preset_rules_shape_error(list(1)),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_rules_shape_error(list(bogusrule = brdr())),
    "unknown rule"
  )
  expect_match(
    tabular:::.preset_rules_shape_error(list(toprule = 42L)),
    "must be a brdr"
  )
  expect_null(tabular:::.preset_rules_shape_error(list(toprule = "none")))
})

# ---- spacing --------------------------------------------------------

test_that(".spacing_shape_error covers every branch", {
  expect_null(tabular:::.spacing_shape_error(list())) # empty
  expect_match(tabular:::.spacing_shape_error(1L), "named list")
  expect_match(tabular:::.spacing_shape_error(list(1)), "must all be named")
  expect_match(
    tabular:::.spacing_shape_error(list(nope = c(above = 1))),
    "unknown region"
  )
  expect_match(
    tabular:::.spacing_shape_error(list(title = "x")),
    "named numeric"
  )
  expect_match(
    tabular:::.spacing_shape_error(list(title = c(sideways = 1))),
    "accepts only"
  )
  expect_match(
    tabular:::.spacing_shape_error(list(title = c(above = -1))),
    "non-negative integers"
  )
  expect_null(tabular:::.spacing_shape_error(list(title = c(above = 2))))
})

# ---- stripe ---------------------------------------------------------

test_that(".stripe_shape_error covers every branch", {
  expect_null(tabular:::.stripe_shape_error(NULL))
  expect_match(tabular:::.stripe_shape_error(1L), "colour string")
  expect_null(tabular:::.stripe_shape_error("#eee")) # single fill
  expect_match(
    tabular:::.stripe_shape_error(c("#a", "#b")),
    "must be named"
  )
  expect_match(
    tabular:::.stripe_shape_error(c(weird = "#a")),
    "odd"
  )
  expect_null(tabular:::.stripe_shape_error(c(odd = "#a", even = "#b")))
})

# ---- fonts ----------------------------------------------------------

test_that(".preset_fonts_shape_error covers the empty + non-list branches", {
  expect_null(tabular:::.preset_fonts_shape_error(list()))
  expect_match(tabular:::.preset_fonts_shape_error(1L), "named list")
})

# ---- colors ---------------------------------------------------------

test_that(".preset_colors_shape_error covers every branch", {
  expect_null(tabular:::.preset_colors_shape_error(list())) # empty
  expect_match(tabular:::.preset_colors_shape_error(1L), "named list")
  expect_match(
    tabular:::.preset_colors_shape_error(list(1)),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(nope = list(text = "#a"))),
    "unknown surface"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = "x")),
    "named list"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = list("#a"))),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = list(bogus = "#a"))),
    "unknown token"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = list(text = 1L))),
    "single non-empty character"
  )
  # NULL surface + NULL token both skip cleanly.
  expect_null(
    tabular:::.preset_colors_shape_error(list(body = list(text = NULL)))
  )
  expect_null(tabular:::.preset_colors_shape_error(list(body = NULL)))
})

# ---- padding --------------------------------------------------------

test_that(".preset_padding_shape_error covers the empty + non-list branches", {
  expect_null(tabular:::.preset_padding_shape_error(list()))
  expect_match(tabular:::.preset_padding_shape_error(1L), "named list")
})
