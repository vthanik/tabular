# Constructor + predicate + validator tests for the 11 S7 classes.

# col_spec ------------------------------------------------------------

test_that("col_spec() builds with defaults", {
  c1 <- col_spec()
  expect_true(is_col_spec(c1))
  expect_true(is.na(c1@usage))
  expect_true(is.na(c1@label))
  expect_true(c1@visible)
  expect_identical(c1@na_text, "")
})

test_that("col_spec() accepts the 4 valid usage values", {
  for (u in c("display", "group", "across", "computed")) {
    expect_true(is_col_spec(col_spec(usage = u)))
  }
})

test_that("col_spec() rejects unknown usage", {
  expect_error(col_spec(usage = "analysis"), "must be one of")
})

test_that("col_spec() rejects unknown align", {
  expect_error(col_spec(align = "justify"), "must be one of")
})

test_that("col_spec() accepts decimal align", {
  expect_true(is_col_spec(col_spec(align = "decimal")))
})

test_that("col_spec() rejects zero or negative width", {
  expect_error(col_spec(width = 0), "positive finite")
  expect_error(col_spec(width = -1), "positive finite")
})

test_that("col_spec() rejects non-finite width", {
  expect_error(col_spec(width = Inf), "positive finite")
})

test_that("col_spec() rejects multi-element na_text", {
  expect_error(col_spec(na_text = c("a", "b")), "length 1")
})

# header_node ---------------------------------------------------------

test_that("header_node() builds with defaults", {
  h <- header_node(label = "Demographics")
  expect_true(is_header_node(h))
  expect_identical(h@label, "Demographics")
  expect_identical(h@span, character())
})

# sort_spec -----------------------------------------------------------

test_that("sort_spec() builds with defaults", {
  s <- sort_spec()
  expect_true(is_sort_spec(s))
  expect_identical(s@by, character())
  expect_false(s@descending)
})

# pivot_spec ----------------------------------------------------------

test_that("pivot_spec() builds with defaults", {
  p <- pivot_spec(by = "year", values = "sales")
  expect_true(is_pivot_spec(p))
  expect_identical(p@by, "year")
  expect_true(p@expand)
})

# derive_spec ---------------------------------------------------------

test_that("derive_spec() defaults to numeric type", {
  d <- derive_spec(name = "pct")
  expect_true(is_derive_spec(d))
  expect_identical(d@type, "numeric")
})

test_that("derive_spec() rejects unknown type", {
  expect_error(derive_spec(name = "x", type = "logical"), "must be one of")
})

# style_node ----------------------------------------------------------

test_that("style_node() builds with NA defaults", {
  s <- style_node()
  expect_true(is_style_node(s))
  expect_true(is.na(s@bold))
  expect_true(is.na(s@color))
})

test_that("style_node(bold = TRUE) holds the value", {
  s <- style_node(bold = TRUE)
  expect_true(s@bold)
})

# style_predicate -----------------------------------------------------

test_that("style_predicate() rejects unknown scope", {
  expect_error(style_predicate(scope = "page"), "must be one of")
})

test_that("style_predicate() accepts cell/row/col scope", {
  for (sc in c("cell", "row", "col")) {
    expect_true(is_style_predicate(style_predicate(scope = sc)))
  }
})

# style_spec ----------------------------------------------------------

test_that("style_spec() builds with empty containers", {
  s <- style_spec()
  expect_true(is_style_spec(s))
  expect_length(s@cols, 0L)
  expect_length(s@headers, 0L)
  expect_length(s@predicates, 0L)
})

# pagination_spec -----------------------------------------------------

test_that("pagination_spec() defaults", {
  p <- pagination_spec()
  expect_true(is_pagination_spec(p))
  expect_true(is.na(p@rows_per_page))
  expect_identical(p@orphan_floor, 3L)
  expect_identical(p@widow_floor, 2L)
  expect_true(p@repeat_headers)
  expect_identical(p@continuation, "(continued)")
})

# preset_spec ---------------------------------------------------------

test_that("preset_spec() defaults", {
  p <- preset_spec()
  expect_true(is_preset_spec(p))
  expect_identical(p@orientation, "portrait")
  expect_identical(p@paper_size, "letter")
  expect_identical(p@hlines, "header")
  expect_identical(p@decimal_metrics, "afm")
})

test_that("preset_spec() rejects unknown orientation", {
  expect_error(preset_spec(orientation = "diagonal"), "must be one of")
})

test_that("preset_spec() rejects unknown paper_size", {
  expect_error(preset_spec(paper_size = "letterA"), "must be one of")
})

test_that("preset_spec() rejects unknown hlines", {
  expect_error(preset_spec(hlines = "vertical"), "must be one of")
})

test_that("preset_spec() rejects unknown decimal_metrics", {
  expect_error(preset_spec(decimal_metrics = "truetype"), "afm")
})

test_that("preset_spec() rejects margin length other than 1 or 4", {
  expect_error(preset_spec(margins = c(1, 2)), "length 1")
  expect_error(preset_spec(margins = c(1, 2, 3)), "length 1")
})

test_that("preset_spec() accepts length-4 margins", {
  expect_true(is_preset_spec(preset_spec(margins = c(1, 1, 1, 1))))
})

test_that("preset_spec() rejects bad title_align / footnote_align", {
  expect_error(preset_spec(title_align = "decimal"), "left, center, or right")
  expect_error(
    preset_spec(footnote_align = "justify"),
    "left, center, or right"
  )
})

# tabular_spec --------------------------------------------------------

test_that("tabular_spec() builds with a data frame", {
  s <- tabular_spec(data = data.frame(x = 1:3))
  expect_true(is_tabular_spec(s))
  expect_identical(nrow(s@data), 3L)
  expect_identical(s@titles, character())
  expect_identical(s@footnotes, character())
})

# tabular_grid --------------------------------------------------------

test_that("tabular_grid() builds with empty pages", {
  g <- tabular_grid()
  expect_true(is_tabular_grid(g))
  expect_length(g@pages, 0L)
})

# Predicates return FALSE for unrelated objects -----------------------

test_that("predicates never error and return FALSE for non-matches", {
  expect_false(is_tabular_spec(NULL))
  expect_false(is_tabular_spec(data.frame()))
  expect_false(is_col_spec(list()))
  expect_false(is_pivot_spec("not a spec"))
  expect_false(is_pagination_spec(42L))
  expect_false(is_preset_spec(NA))
})
