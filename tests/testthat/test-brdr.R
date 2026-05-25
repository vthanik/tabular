# test-brdr.R — brdr() constructor + tabular_brdr S3 class.

test_that("brdr() defaults to thin solid currentColor", {
  b <- brdr()
  expect_true(is_brdr(b))
  expect_identical(b$style, "solid")
  expect_identical(b$width, 0.5)
  expect_identical(b$color, "currentColor")
})

test_that("brdr() resolves width keywords to numeric points", {
  expect_identical(brdr(width = "hairline")$width, 0.25)
  expect_identical(brdr(width = "thin")$width, 0.5)
  expect_identical(brdr(width = "medium")$width, 1)
  expect_identical(brdr(width = "thick")$width, 1.5)
})

test_that("brdr() accepts numeric width directly", {
  expect_identical(brdr(width = 0.75)$width, 0.75)
  expect_identical(brdr(width = 0)$width, 0)
})

test_that("brdr() accepts every style enum", {
  for (sty in c("solid", "dashed", "dotted", "double", "dashdot", "none")) {
    expect_identical(brdr(style = sty)$style, sty)
  }
})

test_that("brdr() accepts hex, named, and currentColor", {
  expect_identical(brdr(color = "#abcdef")$color, "#abcdef")
  expect_identical(brdr(color = "slategray")$color, "slategray")
  expect_identical(brdr(color = "currentColor")$color, "currentColor")
})

test_that("brdr() rejects unknown width keyword", {
  expect_error(brdr(width = "ginormous"), class = "tabular_error_input")
})

test_that("brdr() rejects negative numeric width", {
  expect_error(brdr(width = -0.1), class = "tabular_error_input")
})

test_that("brdr() rejects non-numeric non-keyword width", {
  expect_error(brdr(width = TRUE), class = "tabular_error_input")
})

test_that("brdr() rejects unknown style", {
  expect_error(brdr(style = "wibble"), class = "tabular_error_input")
})

test_that("brdr() rejects non-character color", {
  expect_error(brdr(color = 0xff), class = "tabular_error_input")
})

test_that("is_brdr() rejects non-brdr", {
  expect_false(is_brdr(NULL))
  expect_false(is_brdr("solid"))
  expect_false(is_brdr(list(style = "solid", width = 0.5, color = "x")))
})

test_that(".as_brdr_triple unwraps brdr and passes bare triples", {
  b <- brdr("medium", "dashed", "#abc")
  triple <- tabular:::.as_brdr_triple(b)
  expect_false(is_brdr(triple))
  expect_identical(triple$style, "dashed")
  expect_identical(triple$width, 1)
  bare <- list(style = "solid", width = 0.5, color = "currentColor")
  expect_identical(tabular:::.as_brdr_triple(bare), bare)
  expect_null(tabular:::.as_brdr_triple(NULL))
  expect_null(tabular:::.as_brdr_triple("not a triple"))
})

test_that("print.tabular_brdr emits a compact single-line summary", {
  expect_output(print(brdr("medium", "dashed", "#000")), "<tabular_brdr>")
})
