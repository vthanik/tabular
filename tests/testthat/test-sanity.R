# Validators in R/sanity.R.

test_that("check_tabular_spec accepts a tabular_spec", {
  s <- tabular_spec(data = data.frame(x = 1))
  expect_invisible(check_tabular_spec(s))
})

test_that("check_tabular_spec rejects non-spec input", {
  expect_error(check_tabular_spec(NULL), class = "tabular_error_input")
  expect_error(
    check_tabular_spec(data.frame()),
    class = "tabular_error_input"
  )
  expect_error(
    check_tabular_spec("not a spec"),
    class = "tabular_error_input"
  )
})

test_that("check_data_frame accepts a data.frame", {
  expect_invisible(check_data_frame(data.frame(x = 1)))
})

test_that("check_data_frame rejects vectors / lists / NULL", {
  expect_error(check_data_frame(1:5), class = "tabular_error_input")
  expect_error(check_data_frame(list(a = 1)), class = "tabular_error_input")
  expect_error(check_data_frame(NULL), class = "tabular_error_input")
})

test_that("check_chr accepts empty character()", {
  expect_invisible(check_chr(character()))
})

test_that("check_chr accepts non-NA character", {
  expect_invisible(check_chr(c("a", "b")))
})

test_that("check_chr rejects NA-containing character", {
  expect_error(
    check_chr(c("a", NA_character_)),
    class = "tabular_error_input"
  )
})

test_that("check_chr rejects non-character", {
  expect_error(check_chr(1:3), class = "tabular_error_input")
})

test_that("check_lgl accepts non-NA logical", {
  expect_invisible(check_lgl(c(TRUE, FALSE)))
})

test_that("check_lgl rejects NA / non-logical", {
  expect_error(check_lgl(c(TRUE, NA)), class = "tabular_error_input")
  expect_error(check_lgl("yes"), class = "tabular_error_input")
})

test_that("check_pos_int accepts a positive whole number", {
  expect_invisible(check_pos_int(3))
  expect_identical(check_pos_int(40L), 40L)
})

test_that("check_pos_int rejects zero / negative / fractional / Inf / multi / NA / non-numeric", {
  expect_error(check_pos_int(0), class = "tabular_error_input")
  expect_error(check_pos_int(-1), class = "tabular_error_input")
  expect_error(check_pos_int(2.5), class = "tabular_error_input")
  expect_error(check_pos_int(Inf), class = "tabular_error_input")
  expect_error(check_pos_int(c(1, 2)), class = "tabular_error_input")
  expect_error(check_pos_int(NA_integer_), class = "tabular_error_input")
  expect_error(check_pos_int("3"), class = "tabular_error_input")
})

test_that("check_enum accepts values in choices", {
  expect_invisible(check_enum("left", choices = c("left", "right")))
})

test_that("check_enum rejects values outside choices", {
  expect_error(
    check_enum("up", choices = c("left", "right")),
    class = "tabular_error_input"
  )
})

test_that("check_enum rejects non-character / multi / NA", {
  expect_error(
    check_enum(1L, choices = "left"),
    class = "tabular_error_input"
  )
  expect_error(
    check_enum(c("left", "right"), choices = c("left", "right")),
    class = "tabular_error_input"
  )
  expect_error(
    check_enum(NA_character_, choices = "left"),
    class = "tabular_error_input"
  )
})
