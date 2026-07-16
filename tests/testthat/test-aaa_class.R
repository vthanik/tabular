# Constructor + predicate + validator tests for the 10 S7 classes
# whose construction is not user-facing. col_spec() has its own
# test file (test-col_spec.R) since it is the only user-facing S7
# wrapper.

# .col_spec_class S7 validator (last-line-of-defense; user-facing
# col_spec() validates first, so these direct calls exist to ensure
# the S7 validator still catches bad input from set_props() in
# engine code).

test_that(".col_spec_class rejects unknown align", {
  expect_error(tabular:::.col_spec_class(align = "justify"), "must be one of")
})

test_that(".col_spec_class rejects zero / negative / infinite width", {
  expect_error(tabular:::.col_spec_class(width = 0), "positive")
  expect_error(tabular:::.col_spec_class(width = -1), "non-negative")
  expect_error(tabular:::.col_spec_class(width = Inf), "finite")
})

test_that(".col_spec_class rejects multi-element na_text", {
  expect_error(
    tabular:::.col_spec_class(na_text = c("a", "b")),
    "length 1"
  )
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

# style_spec ----------------------------------------------------------

test_that("style_spec() builds with empty containers", {
  s <- style_spec()
  expect_true(is_style_spec(s))
  expect_length(s@layers, 0L)
})

# pagination_spec -----------------------------------------------------

test_that("pagination_spec() defaults", {
  p <- pagination_spec()
  expect_true(is_pagination_spec(p))
  expect_identical(p@keep_together, character())
  expect_identical(p@panels, 1L)
  expect_identical(p@orphan_floor, 3L)
  expect_identical(p@widow_floor, 2L)
  expect_identical(p@repeat_content, c("titles", "headers", "footnotes"))
  expect_identical(p@continuation, character())
})

# preset_spec ---------------------------------------------------------

test_that("preset_spec() defaults", {
  p <- preset_spec()
  expect_true(is_preset_spec(p))
  expect_identical(p@orientation, "landscape")
  expect_identical(p@paper_size, "letter")
  expect_identical(p@decimal_metrics, "afm")
  expect_identical(as.numeric(p@cell_padding), c(0, 5.4))
  expect_identical(p@spacing$title, c(above = 1L, below = 1L))
  expect_null(p@stripe)
})

test_that("preset_spec() rejects unknown orientation", {
  expect_error(preset_spec(orientation = "diagonal"), "must be one of")
})

test_that("preset_spec() rejects unknown paper_size", {
  expect_error(preset_spec(paper_size = "letterA"), "must be one of")
})

test_that("preset_spec() rejects bad cell_padding length", {
  expect_error(preset_spec(cell_padding = c(1, 2, 3)), "length 1")
})

test_that("preset_spec() rejects unknown decimal_metrics", {
  expect_error(preset_spec(decimal_metrics = "truetype"), "must be one of")
})

test_that("preset_spec() rejects margin length other than 1, 2, or 4", {
  expect_error(preset_spec(margins = c(1, 2, 3)), "length 1")
  expect_error(preset_spec(margins = c(1, 2, 3, 4, 5)), "length 1")
})

test_that("preset_spec() accepts margins of length 1, 2, and 4", {
  expect_true(is_preset_spec(preset_spec(margins = 0.75)))
  expect_true(is_preset_spec(preset_spec(margins = c(1, 0.5))))
  expect_true(is_preset_spec(preset_spec(margins = c(1, 0.5, 1.25, 0.75))))
})

test_that("preset_spec() rejects negative or NA margins", {
  expect_error(preset_spec(margins = -1), "non-negative")
  expect_error(preset_spec(margins = NA_real_), "non-negative")
})

test_that("preset_spec() rejects malformed spacing / stripe", {
  expect_error(
    preset_spec(spacing = list(footnote = c(below = 1))),
    "accepts only"
  )
  expect_error(
    preset_spec(stripe = c(top = "#fff")),
    "odd"
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
  expect_false(is_sort_spec("not a spec"))
  expect_false(is_pagination_spec(42L))
  expect_false(is_preset_spec(NA))
})

# ---------------------------------------------------------------------
# S7 validator branches (last-line-of-defense, reached by constructing
# the raw classes directly; the user-facing verbs cli-check first).
# ---------------------------------------------------------------------

test_that(".col_spec_class validator rejects malformed width", {
  expect_error(tabular:::.col_spec_class(width = NA), "cannot be NA or NULL")
  expect_error(
    tabular:::.col_spec_class(width = NULL),
    "cannot be NA or NULL"
  )
  expect_error(
    tabular:::.col_spec_class(width = "bogus"),
    "object is invalid"
  )
  expect_error(
    tabular:::.col_spec_class(width = "0pt"),
    "must be positive when set"
  )
})

test_that(".col_spec_class validator rejects malformed scalar props", {
  expect_error(
    tabular:::.col_spec_class(na_text = c("a", "b")),
    "@na_text must be length 1"
  )
  expect_error(
    tabular:::.col_spec_class(indent = c("a", "b")),
    "@indent must be length 1"
  )
})

test_that("pagination_spec validator rejects unknown repeat_content", {
  expect_error(
    pagination_spec(repeat_content = "bogus"),
    "@repeat_content must be a subset of"
  )
})

test_that("preset_spec validator surfaces a malformed pagefoot shape", {
  expect_error(
    preset_spec(pagefoot = list(1, 2)),
    "@pagefoot"
  )
})

# ---- S7 last-line-defense validators (new properties) ---------------

test_that("subgroup_spec() rejects a non-scalar / NA keep_empty", {
  expect_error(
    subgroup_spec(by = "sex", keep_empty = NA),
    "single TRUE or FALSE"
  )
  expect_error(
    subgroup_spec(by = "sex", keep_empty = c(TRUE, FALSE)),
    "single TRUE or FALSE"
  )
})

test_that("subgroup_spec() accepts a logical keep_empty", {
  sg <- subgroup_spec(by = "sex", keep_empty = TRUE)
  expect_true(sg@keep_empty)
})

test_that("preset_spec() rejects an empty or multi-element empty_text", {
  expect_error(preset_spec(empty_text = ""), "non-empty string")
  expect_error(preset_spec(empty_text = c("a", "b")), "non-empty string")
})

test_that("preset_spec() accepts NA (unset) and a string empty_text", {
  expect_identical(preset_spec()@empty_text, NA_character_)
  expect_identical(preset_spec(empty_text = "x")@empty_text, "x")
})


# ---------------------------------------------------------------------
# row_group_spec — the group_rows() plan (S7 validator last-line checks)
# ---------------------------------------------------------------------

test_that("row_group_spec stores by/display/skip and satisfies its predicate", {
  rg <- tabular:::row_group_spec(
    by = c("soc", "pt"),
    display = c("section", "collapse"),
    skip = c(NA, FALSE)
  )
  expect_true(is_row_group_spec(rg))
  expect_identical(rg@by, c("soc", "pt"))
  expect_false(is_row_group_spec(list()))
})

test_that("row_group_spec validator rejects malformed plans", {
  expect_error(
    tabular:::row_group_spec(by = "a", display = character(), skip = NA),
    "one value per"
  )
  expect_error(
    tabular:::row_group_spec(by = "a", display = "banner", skip = NA),
    "must be one of"
  )
  expect_error(
    tabular:::row_group_spec(
      by = c("a", "a"),
      display = rep("collapse", 2L),
      skip = rep(NA, 2L)
    ),
    "duplicated"
  )
  expect_error(
    tabular:::row_group_spec(
      by = "a",
      display = "collapse",
      skip = logical()
    ),
    "one value per"
  )
  expect_error(
    tabular:::row_group_spec(
      by = c("a", ""),
      display = rep("collapse", 2L),
      skip = rep(NA, 2L)
    ),
    "empty"
  )
})

test_that(".effective_row_group_skip resolves the NA derive sentinel", {
  # A "section" key or a break-only key (in break_keys, from
  # visible = FALSE) derives TRUE; visible column modes derive FALSE.
  rg <- tabular:::row_group_spec(
    by = c("a", "b", "c", "d"),
    display = c("section", "collapse", "repeat", "collapse"),
    skip = rep(NA, 4L)
  )
  expect_identical(
    tabular:::.effective_row_group_skip(rg, break_keys = "d"),
    c(TRUE, FALSE, FALSE, TRUE)
  )
  # No break keys, all explicit FALSE -> stays FALSE.
  rg2 <- tabular:::row_group_spec(
    by = c("a", "b"),
    display = c("section", "collapse"),
    skip = c(FALSE, FALSE)
  )
  expect_identical(tabular:::.effective_row_group_skip(rg2), c(FALSE, FALSE))
})

test_that(".row_group_hidden_keys / break_keys / stub_keys split the plan", {
  rg <- tabular:::row_group_spec(
    by = c("a", "b", "c", "d"),
    display = c("section", "collapse", "repeat", "collapse"),
    skip = rep(NA, 4L)
  )
  # `d` is a visible-column key marked col_spec(visible = FALSE):
  # break-only.
  cols <- list(
    a = col_spec(),
    b = col_spec(),
    c = col_spec(),
    d = col_spec(visible = FALSE)
  )
  # Hidden (pulled into section headers) = the section keys only.
  expect_identical(tabular:::.row_group_hidden_keys(rg), "a")
  # Break-only = the visible = FALSE grouping keys.
  expect_identical(tabular:::.row_group_break_keys(rg, cols), "d")
  # Stub (default panel repeat) = every key that is not break-only.
  expect_identical(tabular:::.row_group_stub_keys(rg, cols), c("a", "b", "c"))
  expect_identical(tabular:::.row_group_hidden_keys(NULL), character())
  expect_identical(tabular:::.row_group_break_keys(NULL, cols), character())
  expect_identical(tabular:::.row_group_stub_keys(NULL, cols), character())
})
