# Tests for the cells_*() location constructors. Each constructor
# returns a `tabular_location` S3 list with a fixed shape; the
# `style()` verb downstream switches on `surface` and consumes the
# filter slots.

# ---------------------------------------------------------------------
# cells_body
# ---------------------------------------------------------------------

test_that("cells_body() returns a body location with no filters", {
  loc <- cells_body()
  expect_s3_class(loc, "tabular_location")
  expect_true(is_tabular_location(loc))
  expect_identical(loc$surface, "body")
  expect_null(loc$i)
  expect_null(loc$j)
  expect_null(loc$where)
})

test_that("cells_body(i, j) accepts integer / character indices", {
  loc <- cells_body(i = 1:3, j = "Total")
  expect_identical(loc$i, 1:3)
  expect_identical(loc$j, "Total")
})

test_that("cells_body(where = ...) captures a quosure", {
  loc <- cells_body(where = stat_label == "Mean (SD)")
  expect_true(rlang::is_quosure(loc$where))
  expect_match(rlang::quo_text(loc$where), "Mean")
})

test_that("cells_body rejects both i and where", {
  expect_error(
    cells_body(i = 1:3, where = stat_label == "Mean"),
    class = "tabular_error_input"
  )
})

test_that("cells_body rejects empty / NA index", {
  expect_error(cells_body(i = integer(0L)), class = "tabular_error_input")
  expect_error(cells_body(i = c(1L, NA)), class = "tabular_error_input")
  expect_error(cells_body(i = 0L), class = "tabular_error_input")
  expect_error(
    cells_body(j = c("a", "")),
    class = "tabular_error_input"
  )
})

test_that("cells_body coerces numeric to integer", {
  loc <- cells_body(i = c(1, 2, 3))
  expect_identical(loc$i, 1:3)
  expect_true(is.integer(loc$i))
})

test_that("cells_body accepts logical mask", {
  loc <- cells_body(i = c(TRUE, FALSE, TRUE))
  expect_identical(loc$i, c(TRUE, FALSE, TRUE))
})

# ---------------------------------------------------------------------
# cells_headers
# ---------------------------------------------------------------------

test_that("cells_headers() with no args targets every band", {
  loc <- cells_headers()
  expect_identical(loc$surface, "headers")
  expect_null(loc$level)
  expect_null(loc$labels)
  expect_null(loc$j)
})

test_that("cells_headers(level = 1 / -1) accepts depth integers", {
  expect_identical(cells_headers(level = 1)$level, 1L)
  expect_identical(cells_headers(level = -1)$level, -1L)
})

test_that("cells_headers rejects zero / non-whole level", {
  expect_error(cells_headers(level = 0), class = "tabular_error_input")
  expect_error(cells_headers(level = 1.5), class = "tabular_error_input")
  expect_error(
    cells_headers(level = c(1, 2)),
    class = "tabular_error_input"
  )
})

test_that("cells_headers(labels = ...) captures the label set", {
  loc <- cells_headers(labels = c("Treatment Group", "Visit 1"))
  expect_identical(loc$labels, c("Treatment Group", "Visit 1"))
})

test_that("cells_headers rejects both level and labels", {
  expect_error(
    cells_headers(level = 1, labels = "Treatment Group"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# cells_group_headers
# ---------------------------------------------------------------------

test_that("cells_group_headers() with no args targets every injected row", {
  loc <- cells_group_headers()
  expect_identical(loc$surface, "group_headers")
  expect_null(loc$where)
  expect_null(loc$j)
})

test_that("cells_group_headers captures a where predicate", {
  loc <- cells_group_headers(where = soc == "GENERAL DISORDERS")
  expect_true(rlang::is_quosure(loc$where))
})

# ---------------------------------------------------------------------
# Single-surface constructors
# ---------------------------------------------------------------------

test_that("cells_title / cells_subgroup_labels / cells_footnotes name their surface", {
  expect_identical(cells_title()$surface, "title")
  expect_identical(cells_subgroup_labels()$surface, "subgroup_labels")
  expect_identical(cells_footnotes()$surface, "footnotes")
})

# ---------------------------------------------------------------------
# cells_pagehead / cells_pagefoot
# ---------------------------------------------------------------------

test_that("cells_pagehead / cells_pagefoot accept the three slots", {
  for (slot in c("left", "center", "right")) {
    expect_identical(cells_pagehead(slot = slot)$slot, slot)
    expect_identical(cells_pagefoot(slot = slot)$slot, slot)
  }
})

test_that("cells_pagehead with NULL slot targets every slot", {
  expect_null(cells_pagehead()$slot)
})

test_that("cells_pagehead rejects bogus slot value", {
  expect_error(
    cells_pagehead(slot = "middle"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# cells_table
# ---------------------------------------------------------------------

test_that("cells_table() with NULL side defaults to whole body", {
  loc <- cells_table()
  expect_identical(loc$surface, "table")
  expect_null(loc$side)
})

test_that("cells_table(side = ...) accepts the seven enum values", {
  for (s in c(
    "outer",
    "outer_top",
    "outer_bottom",
    "outer_left",
    "outer_right",
    "rows",
    "cols"
  )) {
    expect_identical(cells_table(side = s)$side, s)
  }
})

test_that("cells_table rejects bogus side", {
  expect_error(
    cells_table(side = "diagonal"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# is_tabular_location
# ---------------------------------------------------------------------

test_that("is_tabular_location distinguishes location objects", {
  expect_true(is_tabular_location(cells_body()))
  expect_true(is_tabular_location(cells_table(side = "outer")))
  expect_false(is_tabular_location(list(surface = "body")))
  expect_false(is_tabular_location(NULL))
})

# ---------------------------------------------------------------------
# print
# ---------------------------------------------------------------------

test_that("print.tabular_location shows surface + filter summary", {
  out <- capture.output(print(cells_body(i = 1:2, j = "Total")))
  expect_match(out, "<tabular_location: body\\(", all = FALSE)
  expect_match(out, "i=1,2", all = FALSE)
  expect_match(out, "j=Total", all = FALSE)
})

# ---------------------------------------------------------------------
# Error-branch coverage — exercise every .check_location_index() abort
# path and the cells_headers() validators.
# ---------------------------------------------------------------------

test_that("cells_body() rejects logical i with NAs", {
  expect_error(
    cells_body(i = c(TRUE, NA)),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects numeric i with non-positive values", {
  expect_error(
    cells_body(i = c(1L, 0L)),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects numeric i with fractional values", {
  expect_error(
    cells_body(i = c(1.5, 2)),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects character i with NAs", {
  expect_error(
    cells_body(i = c("row1", NA_character_)),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects character i with empty strings", {
  expect_error(
    cells_body(i = c("row1", "")),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects unsupported i types", {
  expect_error(
    cells_body(i = list(1, 2)),
    class = "tabular_error_input"
  )
})

test_that("cells_body() rejects double-length-0 (empty character)", {
  expect_error(
    cells_body(i = character(0L)),
    class = "tabular_error_input"
  )
})

test_that("cells_headers() rejects level = 0 (must be non-zero whole)", {
  expect_error(
    cells_headers(level = 0),
    class = "tabular_error_input"
  )
})

test_that("cells_headers() rejects non-character labels", {
  expect_error(
    cells_headers(labels = 1L),
    class = "tabular_error_input"
  )
})

test_that("cells_headers() rejects labels with NAs", {
  expect_error(
    cells_headers(labels = c("Treatment", NA_character_)),
    class = "tabular_error_input"
  )
})

test_that("cells_headers() rejects empty character labels", {
  expect_error(
    cells_headers(labels = character(0L)),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# print.tabular_location — exercise every parts branch
# ---------------------------------------------------------------------

test_that("print.tabular_location renders i / j / where / level / labels / slot / side", {
  expect_snapshot({
    print(cells_body(i = 1:3, j = "Total"))
    print(cells_body(where = x > 0))
    print(cells_headers(level = 1L))
    print(cells_headers(labels = "Treatment Group"))
    print(cells_pagehead(slot = "left"))
    print(cells_table(side = "outer_top"))
  })
})

test_that(".format_filter truncates long index vectors", {
  expect_snapshot(print(cells_body(i = 1:10)))
})
