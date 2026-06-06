# col_spec() user-facing constructor: 7-arg signature, cli wrapping,
# 6 edge cases from plan section 2.12.

# Happy path -----------------------------------------------------------

test_that("col_spec() with no args returns an S7 col_spec", {
  c1 <- col_spec()
  expect_true(is_col_spec(c1))
})

test_that("col_spec() sets all 7 properties via named args", {
  fn <- function(x) format(x)
  c1 <- col_spec(
    usage = "group",
    label = "Parameter",
    format = fn,
    visible = TRUE,
    width = 1.5,
    align = "decimal",
    na_text = "-"
  )
  expect_identical(c1@usage, "group")
  expect_identical(c1@label, "Parameter")
  expect_identical(c1@format, fn)
  expect_true(c1@visible)
  expect_identical(c1@width, 1.5)
  expect_identical(c1@align, "decimal")
  expect_identical(c1@na_text, "-")
})

test_that("col_spec() leaves @name as NA (set by cols())", {
  expect_true(is.na(col_spec()@name))
})

# Edge case 1: usage = NULL --------------------------------------------

test_that("col_spec(usage = NULL) is allowed and stored as NA_character_", {
  c1 <- col_spec(usage = NULL)
  expect_true(is.na(c1@usage))
})

# Edge case 2: bad usage -----------------------------------------------

test_that("col_spec(usage = bad) raises tabular_error_input", {
  expect_error(
    col_spec(usage = "analysis"),
    class = "tabular_error_input"
  )
  expect_error(col_spec(usage = "analysis"), "must be one of")
})

test_that("col_spec(usage = c('display', 'group')) rejects vectors", {
  expect_error(
    col_spec(usage = c("display", "group")),
    class = "tabular_error_input"
  )
})

test_that("col_spec(usage = NA_character_) is rejected", {
  expect_error(col_spec(usage = NA_character_), class = "tabular_error_input")
})

# Edge case 3: format is character or function -------------------------

test_that("col_spec(format = sprintf string) accepts valid templates", {
  expect_silent(col_spec(format = "%.2f"))
  expect_silent(col_spec(format = "%5d"))
})

test_that("col_spec(format = function) accepts a unary function", {
  expect_silent(col_spec(format = function(x) format(x, nsmall = 2)))
})

test_that("col_spec(format = bad sprintf) raises tabular_error_input", {
  expect_error(
    col_spec(format = "%.2z"),
    class = "tabular_error_input"
  )
})

test_that("col_spec(format = integer) rejects non-string non-function", {
  expect_error(
    col_spec(format = 42L),
    class = "tabular_error_input"
  )
})

# Edge case 4: width = 0 -----------------------------------------------

test_that("col_spec(width = 0) raises tabular_error_input", {
  expect_error(col_spec(width = 0), class = "tabular_error_input")
  expect_error(col_spec(width = 0), "positive")
})

test_that("col_spec(width = -1) raises tabular_error_input", {
  expect_error(col_spec(width = -1), class = "tabular_error_input")
})

test_that("col_spec(width = Inf) raises tabular_error_input", {
  expect_error(col_spec(width = Inf), class = "tabular_error_input")
})

test_that("col_spec() default width is 'auto'", {
  cs <- col_spec()
  expect_identical(cs@width, "auto")
})

test_that("col_spec(width = NA_real_) rejects with a hint", {
  expect_error(
    col_spec(width = NA_real_),
    class = "tabular_error_input"
  )
})

test_that("col_spec(width = NA) rejects with a hint", {
  expect_error(
    col_spec(width = NA),
    class = "tabular_error_input"
  )
})

test_that("col_spec(width = NULL) rejects with a hint", {
  expect_error(
    col_spec(width = NULL),
    class = "tabular_error_input"
  )
})

test_that("col_spec(width = 'auto') round-trips", {
  cs <- col_spec(width = "auto")
  expect_identical(cs@width, "auto")
})

test_that("col_spec(width = c(1, 2)) rejects length > 1", {
  expect_error(col_spec(width = c(1, 2)), class = "tabular_error_input")
})

# Edge case 5: align = 'decimal' for any column (warn at engine, not here)

test_that("col_spec(align = 'decimal') accepts at construction", {
  expect_silent(col_spec(align = "decimal"))
})

test_that("col_spec(align = NULL) maps to NA_character_", {
  expect_true(is.na(col_spec(align = NULL)@align))
})

test_that("col_spec(align = 'justify') raises tabular_error_input", {
  expect_error(col_spec(align = "justify"), class = "tabular_error_input")
})

# Edge case 6: na_text length > 1 --------------------------------------

test_that("col_spec(na_text = c('a', 'b')) raises tabular_error_input", {
  expect_error(col_spec(na_text = c("a", "b")), class = "tabular_error_input")
  expect_error(col_spec(na_text = c("a", "b")), "length 1")
})

test_that("col_spec(na_text = NA_character_) is the inherit sentinel (#cw7)", {
  # NA_character_ now means "inherit the preset na_text" (the default),
  # so it is accepted rather than rejected.
  expect_silent(col_spec(na_text = NA_character_))
  expect_true(is.na(col_spec(na_text = NA_character_)@na_text))
  expect_identical(col_spec()@na_text, NA_character_)
})

test_that("an explicit na_text='' overrides a non-empty preset na_text (#cw7)", {
  # nzchar('') was FALSE, so an explicit blank could not win over the
  # preset token; the NA-vs-set distinction fixes that.
  df <- data.frame(x = NA_real_, stringsAsFactors = FALSE)
  blank <- tabular(df) |>
    cols(x = col_spec(na_text = "")) |>
    preset(na_text = "NR")
  inherit <- tabular(df) |>
    cols(x = col_spec()) |>
    preset(na_text = "NR")
  fmt_blank <- tabular:::engine_format(blank)
  fmt_inherit <- tabular:::engine_format(inherit)
  expect_identical(unname(fmt_blank$cells_text[1L, "x"]), "")
  expect_identical(unname(fmt_inherit$cells_text[1L, "x"]), "NR")
})

test_that("col_spec(na_text = '') is an accepted explicit override", {
  expect_silent(col_spec(na_text = ""))
  expect_identical(col_spec(na_text = "")@na_text, "")
})

# Label / visible validation ------------------------------------------

test_that("col_spec(label = NA_character_) is allowed (default)", {
  expect_true(is.na(col_spec()@label))
})

test_that("col_spec(label = c('a', 'b')) raises tabular_error_input", {
  expect_error(col_spec(label = c("a", "b")), class = "tabular_error_input")
})

test_that("col_spec(label = 1) raises tabular_error_input", {
  expect_error(col_spec(label = 1), class = "tabular_error_input")
})

test_that("col_spec(visible = NA) is the unset sentinel (accepted)", {
  # NA = unset (mergeable); resolved to TRUE at engine finalize.
  cs <- col_spec(visible = NA)
  expect_true(is.na(cs@visible))
  expect_true(tabular:::.finalize_col_spec(cs)@visible)
})

test_that("col_spec(visible = c(TRUE, FALSE)) raises tabular_error_input", {
  expect_error(
    col_spec(visible = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
})

test_that("col_spec(visible = 'TRUE') rejects non-logical", {
  expect_error(col_spec(visible = "TRUE"), class = "tabular_error_input")
})

# ---- empty / whitespace labels are ALLOWED on col_spec --------------
# This is the asymmetry with headers(): a band must always carry
# visible text, but a column header may be intentionally blank (row-
# label columns in some clinical layouts render no header text).

test_that("col_spec(label = '') is accepted", {
  cs <- col_spec(label = "")
  expect_identical(cs@label, "")
})

test_that("col_spec(label = '   ') (whitespace-only) is accepted", {
  cs <- col_spec(label = "   ")
  expect_identical(cs@label, "   ")
})

# ---------------------------------------------------------------------
# Coverage — col_spec validator branches
# ---------------------------------------------------------------------

test_that("col_spec(width = '0in') is rejected (must be positive)", {
  expect_error(col_spec(width = "0in"), class = "tabular_error_input")
})

test_that("col_spec(width = '-1in') is rejected via parse_dim error", {
  expect_error(col_spec(width = "-1in"), class = "tabular_error_input")
})

test_that("col_spec(na_text = c('a','b')) is rejected (must be length 1)", {
  expect_error(col_spec(na_text = c("a", "b")), class = "tabular_error_input")
})

test_that("col_spec(group_display = 'bogus') is rejected", {
  expect_error(
    col_spec(group_display = "bogus"),
    class = "tabular_error_input"
  )
})

test_that("col_spec(group_skip = c(TRUE, FALSE)) is rejected (length 1)", {
  expect_error(
    col_spec(group_skip = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# `indent` — polymorphic depth (fixed count or per-row column)
# ---------------------------------------------------------------------

test_that("col_spec(indent = <n>) stores a non-negative integer count", {
  expect_identical(col_spec(indent = 1)@indent, 1L)
  expect_identical(col_spec(indent = 2L)@indent, 2L)
  expect_identical(col_spec(indent = 0)@indent, 0L)
})

test_that("col_spec(indent = '<col>') stores a column name", {
  expect_identical(col_spec(indent = "depth")@indent, "depth")
})

test_that("col_spec() defaults indent to NA", {
  expect_true(is.na(col_spec()@indent))
  expect_true(is.na(col_spec(indent = NA)@indent))
  expect_true(is.na(col_spec(indent = NULL)@indent))
})

test_that("col_spec(indent = ...) rejects malformed values", {
  expect_error(col_spec(indent = -1), class = "tabular_error_input")
  expect_error(col_spec(indent = 1.5), class = "tabular_error_input")
  expect_error(col_spec(indent = Inf), class = "tabular_error_input")
  expect_error(col_spec(indent = ""), class = "tabular_error_input")
  expect_error(col_spec(indent = c(1, 2)), class = "tabular_error_input")
  expect_error(col_spec(indent = TRUE), class = "tabular_error_input")
})

# ---------------------------------------------------------------------
# `usage = "id"` — fourth enum value, non-collapsing panel stub
# ---------------------------------------------------------------------

test_that("col_spec(usage = 'id') stores the new enum value", {
  cs <- col_spec(usage = "id")
  expect_identical(cs@usage, "id")
})
