# units.R — page-geometry unit parsing + conversion. Exercise
# every branch of `.parse_dim`, `.dim_to_twips`, `.dim_format`,
# and `.parse_margins`.

# ---------------------------------------------------------------------
# Numeric input (interpreted as inches, back-compat)
# ---------------------------------------------------------------------

test_that(".parse_dim accepts non-negative numeric as inches", {
  expect_identical(
    tabular:::.parse_dim(0.75),
    list(value = 0.75, unit = "in")
  )
  expect_identical(
    tabular:::.parse_dim(0),
    list(value = 0, unit = "in")
  )
  expect_identical(
    tabular:::.parse_dim(2L),
    list(value = 2, unit = "in")
  )
})

test_that(".parse_dim rejects bad numeric input", {
  expect_error(tabular:::.parse_dim(-1), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(NA_real_), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(Inf), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(c(1, 2)), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(numeric()), class = "tabular_error_input")
})

# ---------------------------------------------------------------------
# Character input with unit suffix
# ---------------------------------------------------------------------

test_that(".parse_dim parses every accepted unit suffix", {
  expect_identical(
    tabular:::.parse_dim("2in"),
    list(value = 2, unit = "in")
  )
  expect_identical(
    tabular:::.parse_dim("2cm"),
    list(value = 2, unit = "cm")
  )
  expect_identical(
    tabular:::.parse_dim("25mm"),
    list(value = 25, unit = "mm")
  )
  expect_identical(
    tabular:::.parse_dim("30pt"),
    list(value = 30, unit = "pt")
  )
  expect_identical(
    tabular:::.parse_dim("5pc"),
    list(value = 5, unit = "pc")
  )
})

test_that(".parse_dim normalises case + tolerates whitespace", {
  expect_identical(
    tabular:::.parse_dim("2CM"),
    list(value = 2, unit = "cm")
  )
  expect_identical(
    tabular:::.parse_dim("  2.5in  "),
    list(value = 2.5, unit = "in")
  )
  expect_identical(
    tabular:::.parse_dim("2.5 in"),
    list(value = 2.5, unit = "in")
  )
})

test_that(".parse_dim rejects empty / NA / length-mismatched character", {
  expect_error(tabular:::.parse_dim(""), class = "tabular_error_input")
  expect_error(
    tabular:::.parse_dim(NA_character_),
    class = "tabular_error_input"
  )
  expect_error(
    tabular:::.parse_dim(c("1in", "2in")),
    class = "tabular_error_input"
  )
  expect_error(
    tabular:::.parse_dim(character()),
    class = "tabular_error_input"
  )
})

test_that(".parse_dim rejects unparseable strings", {
  expect_error(tabular:::.parse_dim("foo"), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim("in2"), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim("--1in"), class = "tabular_error_input")
})

test_that(".parse_dim rejects unsupported units without allow_percent", {
  expect_error(tabular:::.parse_dim("30%"), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim("5em"), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim("10px"), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim("2rem"), class = "tabular_error_input")
})

test_that(".parse_dim with allow_percent accepts percent + still rejects em/px", {
  expect_identical(
    tabular:::.parse_dim("30%", allow_percent = TRUE),
    list(value = 30, unit = "%")
  )
  expect_error(
    tabular:::.parse_dim("5em", allow_percent = TRUE),
    class = "tabular_error_input"
  )
  expect_error(
    tabular:::.parse_dim("10px", allow_percent = TRUE),
    class = "tabular_error_input"
  )
})

test_that(".parse_dim rejects percent > 100", {
  expect_error(
    tabular:::.parse_dim("150%", allow_percent = TRUE),
    class = "tabular_error_input"
  )
  # 100% is OK
  expect_identical(
    tabular:::.parse_dim("100%", allow_percent = TRUE),
    list(value = 100, unit = "%")
  )
})

test_that(".parse_dim rejects non-numeric / non-character input", {
  expect_error(tabular:::.parse_dim(TRUE), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(list(1)), class = "tabular_error_input")
  expect_error(tabular:::.parse_dim(NULL), class = "tabular_error_input")
})

# ---------------------------------------------------------------------
# Twips conversion
# ---------------------------------------------------------------------

test_that(".dim_to_twips matches the canonical conversion factors", {
  expect_equal(
    tabular:::.dim_to_twips(list(value = 1, unit = "in")),
    1440
  )
  expect_equal(
    tabular:::.dim_to_twips(list(value = 1, unit = "cm")),
    1440 / 2.54
  )
  expect_equal(
    tabular:::.dim_to_twips(list(value = 1, unit = "mm")),
    1440 / 25.4
  )
  expect_equal(tabular:::.dim_to_twips(list(value = 1, unit = "pt")), 20)
  expect_equal(tabular:::.dim_to_twips(list(value = 1, unit = "pc")), 240)
})

test_that(".dim_to_inches inverts .dim_to_twips for inches", {
  expect_equal(
    tabular:::.dim_to_inches(list(value = 2.5, unit = "in")),
    2.5
  )
  expect_equal(
    tabular:::.dim_to_inches(list(value = 2.54, unit = "cm")),
    1
  )
})

# ---------------------------------------------------------------------
# Format round-trip
# ---------------------------------------------------------------------

test_that(".dim_format round-trips a parsed dimension to its string form", {
  expect_identical(
    tabular:::.dim_format(list(value = 2.5, unit = "in")),
    "2.5in"
  )
  expect_identical(
    tabular:::.dim_format(list(value = 30, unit = "%")),
    "30%"
  )
})

# ---------------------------------------------------------------------
# .parse_margins (vector input)
# ---------------------------------------------------------------------

test_that(".parse_margins parses length-1 numeric", {
  out <- tabular:::.parse_margins(0.75)
  expect_length(out, 1L)
  expect_identical(out[[1L]], list(value = 0.75, unit = "in"))
})

test_that(".parse_margins parses length-2 character with mixed units", {
  out <- tabular:::.parse_margins(c("2cm", "0.5in"))
  expect_length(out, 2L)
  expect_identical(out[[1L]], list(value = 2, unit = "cm"))
  expect_identical(out[[2L]], list(value = 0.5, unit = "in"))
})

test_that(".parse_margins parses length-4 numeric", {
  out <- tabular:::.parse_margins(c(1, 0.5, 1.25, 0.75))
  expect_length(out, 4L)
  expect_identical(out[[3L]], list(value = 1.25, unit = "in"))
})

# ---------------------------------------------------------------------
# .is_percent_dim predicate
# ---------------------------------------------------------------------

test_that(".is_percent_dim distinguishes percent from fixed dims", {
  expect_true(
    tabular:::.is_percent_dim(list(value = 30, unit = "%"))
  )
  expect_false(
    tabular:::.is_percent_dim(list(value = 2, unit = "in"))
  )
  expect_false(
    tabular:::.is_percent_dim(list(value = 2, unit = "cm"))
  )
})
