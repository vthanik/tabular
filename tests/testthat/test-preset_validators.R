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

test_that(".preset_fonts_shape_error covers every branch", {
  expect_null(tabular:::.preset_fonts_shape_error(list()))
  expect_match(tabular:::.preset_fonts_shape_error(1L), "named list")
  expect_match(
    tabular:::.preset_fonts_shape_error(list(1)),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(legend = c(size = "9"))),
    "unknown surface"
  )
  # Legacy nested-list inner form is rejected outright.
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = list(family = "Inter"))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = c(typeface = "Inter"))),
    "unknown name"
  )
  # size must coerce to a positive finite numeric (character or numeric).
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = c(size = "not_numeric"))),
    "size must be a single positive finite numeric"
  )
  expect_match(
    tabular:::.preset_fonts_shape_error(list(body = c(size = "0"))),
    "size must be a single positive finite numeric"
  )
  # Valid named vectors (character or numeric) round-trip clean.
  expect_null(tabular:::.preset_fonts_shape_error(
    list(body = c(family = "Arial", size = "10", weight = "bold"))
  ))
  expect_null(tabular:::.preset_fonts_shape_error(list(
    header = c(size = 11)
  )))
  expect_null(tabular:::.preset_fonts_shape_error(list(body = NULL)))
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
    tabular:::.preset_colors_shape_error(list(nope = c(text = "#a"))),
    "unknown surface"
  )
  # Legacy nested-list inner form is rejected outright.
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = list(text = "#a"))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = "x")),
    "named character vector"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = c("#a"))),
    "named character vector"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = c(bogus = "#a"))),
    "unknown name"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(body = c(text = ""))),
    "non-empty character"
  )
  expect_match(
    tabular:::.preset_colors_shape_error(list(
      body = c(text = NA_character_)
    )),
    "non-empty character"
  )
  # Valid named vector + NULL surface both clean.
  expect_null(tabular:::.preset_colors_shape_error(
    list(body = c(text = "#000", background = "#fff"))
  ))
  expect_null(tabular:::.preset_colors_shape_error(list(body = NULL)))
})

# ---- padding --------------------------------------------------------

test_that(".preset_padding_shape_error covers every branch", {
  expect_null(tabular:::.preset_padding_shape_error(list()))
  expect_match(tabular:::.preset_padding_shape_error(1L), "named list")
  expect_match(
    tabular:::.preset_padding_shape_error(list(1)),
    "must all be named"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(legend = 3)),
    "unknown surface"
  )
  # Unnamed scalar broadcasts; named vector (incl. length-1) sets per-side.
  expect_null(tabular:::.preset_padding_shape_error(list(body = 4)))
  expect_null(tabular:::.preset_padding_shape_error(
    list(body = c(top = 10, bottom = 5))
  ))
  expect_null(tabular:::.preset_padding_shape_error(list(
    header = c(top = 2)
  )))
  # Legacy nested-list inner form is rejected outright.
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = list(top = 10))),
    "nested list"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = c(diagonal = 1))),
    "unknown side"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = -1)),
    "non-negative numeric"
  )
  expect_match(
    tabular:::.preset_padding_shape_error(list(body = c(top = -1))),
    "non-negative numeric"
  )
  expect_null(tabular:::.preset_padding_shape_error(list(body = NULL)))
})
