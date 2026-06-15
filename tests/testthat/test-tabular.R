# tabular() entry verb: 10 edge cases from plan section 2.1.

# Happy path -----------------------------------------------------------

test_that("tabular(data) builds a tabular_spec", {
  s <- tabular(data.frame(x = 1:3, y = c("a", "b", "c")))
  expect_true(is_tabular_spec(s))
  expect_identical(nrow(s@data), 3L)
  expect_identical(ncol(s@data), 2L)
  expect_identical(s@titles, character())
  expect_identical(s@footnotes, character())
})

test_that("tabular(data, titles, footnotes) populates all three", {
  s <- tabular(
    data.frame(x = 1),
    titles = c("Table 1", "Demographics"),
    footnotes = c("Note: see SAP.")
  )
  expect_identical(s@titles, c("Table 1", "Demographics"))
  expect_identical(s@footnotes, "Note: see SAP.")
})

# Edge case 1: non-data.frame data -------------------------------------

test_that("tabular(list) raises tabular_error_input", {
  expect_error(tabular(list(x = 1:3)), class = "tabular_error_input")
})

test_that("tabular(NULL) raises tabular_error_input", {
  expect_error(tabular(NULL), class = "tabular_error_input")
})

test_that("tabular(matrix) raises tabular_error_input", {
  expect_error(tabular(matrix(1:4, 2, 2)), class = "tabular_error_input")
})

# Edge case 2: tibble / data.table — coerce to data.frame -------------

test_that("tabular() coerces tibble to data.frame", {
  skip_if_not_installed("tibble")
  tib <- tibble::tibble(x = 1:3, y = letters[1:3])
  s <- tabular(tib)
  expect_identical(class(s@data), "data.frame")
})

# Edge case 3: zero rows — accept -------------------------------------

test_that("tabular() accepts a 0-row data.frame", {
  s <- tabular(data.frame(x = integer(), y = character()))
  expect_true(is_tabular_spec(s))
  expect_identical(nrow(s@data), 0L)
})

# Edge case 4: zero columns — reject ----------------------------------

test_that("tabular() rejects a 0-column data.frame", {
  empty <- data.frame()
  expect_error(tabular(empty), class = "tabular_error_input")
  expect_error(tabular(empty), "at least one column")
})

# Edge case 5: duplicate column names — reject ------------------------

test_that("tabular() rejects duplicate column names", {
  df <- data.frame(x = 1, y = 2)
  names(df) <- c("a", "a")
  expect_error(tabular(df), class = "tabular_error_input")
  expect_error(tabular(df), "duplicate column names")
})

# Edge case 6: titles non-character — reject --------------------------

test_that("tabular() rejects numeric titles", {
  expect_error(
    tabular(data.frame(x = 1), titles = 1:2),
    class = "tabular_error_input"
  )
})

test_that("tabular() rejects list titles", {
  expect_error(
    tabular(data.frame(x = 1), titles = list("a")),
    class = "tabular_error_input"
  )
})

# Edge case 7: titles contains NA — reject ----------------------------

test_that("tabular() rejects titles containing NA", {
  expect_error(
    tabular(data.frame(x = 1), titles = c("a", NA_character_)),
    class = "tabular_error_input"
  )
})

# Edge case 8: titles length 0 — accept -------------------------------

test_that("tabular() accepts character() (length 0) titles", {
  s <- tabular(data.frame(x = 1), titles = character())
  expect_identical(s@titles, character())
})

# Edge case 9: footnotes non-character — reject -----------------------

test_that("tabular() rejects numeric footnotes", {
  expect_error(
    tabular(data.frame(x = 1), footnotes = 1.5),
    class = "tabular_error_input"
  )
})

test_that("tabular() rejects footnotes containing NA", {
  expect_error(
    tabular(data.frame(x = 1), footnotes = c("note", NA_character_)),
    class = "tabular_error_input"
  )
})

# Edge case 10: factor columns preserved -------------------------------

test_that("tabular() preserves factor columns", {
  df <- data.frame(
    grp = factor(c("A", "B", "C"), levels = c("C", "A", "B")),
    val = 1:3
  )
  s <- tabular(df)
  expect_true(is.factor(s@data$grp))
  expect_identical(levels(s@data$grp), c("C", "A", "B"))
})

# NULL titles / footnotes — default behaviour -------------------------

test_that("tabular() with NULL titles produces empty character()", {
  s <- tabular(data.frame(x = 1), titles = NULL, footnotes = NULL)
  expect_identical(s@titles, character())
  expect_identical(s@footnotes, character())
})

# ---------------------------------------------------------------------
# empty_text (zero-row placeholder wording)
# ---------------------------------------------------------------------

test_that("tabular(empty_text=) defaults, stores, and interpolates", {
  df <- data.frame(x = 1)
  # Unset is the NA sentinel; the built-in wording resolves at render
  # (spec arg -> preset knob -> .tabular_empty_text_default).
  expect_identical(tabular(df)@empty_text, NA_character_)
  expect_identical(
    tabular:::.resolve_empty_text(tabular(df)@empty_text, NULL),
    "No data available to report"
  )
  expect_identical(
    tabular(df, empty_text = "Total {1 + 1}")@empty_text,
    "Total 2"
  )
})

test_that("tabular(empty_text=) rejects non-scalar / NA / empty", {
  df <- data.frame(x = 1)
  expect_error(
    tabular(df, empty_text = ""),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(df, empty_text = c("a", "b")),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(df, empty_text = NA_character_),
    class = "tabular_error_input"
  )
  expect_snapshot(tabular(df, empty_text = ""), error = TRUE)
})
