# engine_paginate() — resolves pagination_spec into a list of page
# descriptors. The row budget per page is auto-computed (paper height
# for active orientation, less margins, less chrome rows for titles /
# headers / footnotes, divided by row height at active font size).
# Tests use small synthetic presets to force tight row budgets so
# splits and group-protection can be exercised at modest data sizes.

# Helper: build a spec with an attached preset_spec carrying the
# requested orientation / font_size / paper. Other slots default.
make_paginated_spec <- function(
  n_rows,
  font_size = 9,
  paper_size = "letter",
  orientation = "portrait",
  titles = character(),
  footnotes = character(),
  ...
) {
  df <- data.frame(
    soc = rep(LETTERS[1:5], each = ceiling(n_rows / 5))[seq_len(n_rows)],
    val = seq_len(n_rows)
  )
  spec <- tabular(df, titles = titles, footnotes = footnotes) |>
    cols(soc = col_spec(usage = "group", label = "SOC"))
  preset <- preset_spec(
    font_size = font_size,
    paper_size = paper_size,
    orientation = orientation
  )
  spec <- S7::set_props(spec, preset = preset)
  if (length(list(...)) > 0L) {
    spec <- paginate(spec, ...)
  }
  spec
}

test_that("engine_paginate() returns a one-page plan when data fits the budget", {
  spec <- tabular(data.frame(a = 1:3, b = 4:6))
  plan <- tabular:::engine_paginate(spec)
  expect_identical(length(plan$pages), 1L)
  expect_identical(plan$pages[[1]]$row_indices, 1:3)
  expect_identical(plan$pages[[1]]$col_indices, 1:2)
  expect_false(plan$pages[[1]]$is_continuation)
})

test_that("engine_paginate() returns a single integer() page for zero rows", {
  spec <- tabular(data.frame(a = integer(), b = integer()))
  plan <- tabular:::engine_paginate(spec)
  expect_identical(length(plan$pages), 1L)
  expect_identical(plan$pages[[1]]$row_indices, integer())
})

test_that("engine_paginate() row budget shrinks under landscape orientation", {
  spec_p <- make_paginated_spec(5L, orientation = "portrait")
  spec_l <- make_paginated_spec(5L, orientation = "landscape")
  plan_p <- tabular:::engine_paginate(spec_p)
  plan_l <- tabular:::engine_paginate(spec_l)
  # Landscape letter is shorter (8.5in tall vs 11in) so fewer rows
  # fit per page than portrait at the same font size.
  expect_gt(plan_p$rows_per_page, plan_l$rows_per_page)
})

test_that("engine_paginate() row budget shrinks at larger font size", {
  spec_9 <- make_paginated_spec(5L, font_size = 9)
  spec_14 <- make_paginated_spec(5L, font_size = 14)
  plan_9 <- tabular:::engine_paginate(spec_9)
  plan_14 <- tabular:::engine_paginate(spec_14)
  expect_gt(plan_9$rows_per_page, plan_14$rows_per_page)
})

test_that("engine_paginate() row budget shrinks as more titles / footnotes consume chrome", {
  spec_bare <- make_paginated_spec(5L)
  spec_heavy <- make_paginated_spec(
    5L,
    titles = c("T1", "T2", "T3", "T4"),
    footnotes = c("F1", "F2", "F3", "F4")
  )
  plan_bare <- tabular:::engine_paginate(spec_bare)
  plan_heavy <- tabular:::engine_paginate(spec_heavy)
  expect_gt(plan_bare$rows_per_page, plan_heavy$rows_per_page)
})

test_that("engine_paginate() floors at min rows per page even under extreme chrome", {
  # Huge font + many titles -> chrome would push budget negative, but
  # the engine floors at the documented minimum (5).
  spec <- make_paginated_spec(
    1L,
    font_size = 72,
    titles = rep("T", 50L)
  )
  plan <- tabular:::engine_paginate(spec)
  expect_gte(plan$rows_per_page, 5L)
})

test_that("engine_paginate() splits rows when nrow exceeds budget", {
  # Force a tight budget: a4 portrait, 36pt font (~14 rows of body
  # space minus chrome) AND a 15-row data table.
  spec <- make_paginated_spec(15L, font_size = 36)
  plan <- tabular:::engine_paginate(spec)
  expect_gte(plan$total_pages, 2L)
  expect_identical(
    sort(unlist(lapply(plan$pages, function(p) p$row_indices))),
    1:15
  )
})

test_that("engine_paginate() marks continuation pages correctly", {
  spec <- make_paginated_spec(30L, font_size = 24)
  plan <- tabular:::engine_paginate(spec)
  expect_false(plan$pages[[1]]$is_continuation)
  if (length(plan$pages) >= 2L) {
    for (i in seq.int(2L, length(plan$pages))) {
      expect_true(plan$pages[[i]]$is_continuation)
    }
  }
})

test_that("engine_paginate() respects keep_together on group runs", {
  # Group runs of length 2 each (A,A,B,B,C,C,...). Tight budget
  # forces multiple pages. Every page's last row should match the
  # next page's first row only if a group spans the break — which
  # we expect engine_paginate to prevent.
  spec <- make_paginated_spec(20L, font_size = 36, keep_together = "soc")
  plan <- tabular:::engine_paginate(spec)
  if (length(plan$pages) >= 2L) {
    for (i in seq.int(1L, length(plan$pages) - 1L)) {
      last_row_i <- tail(plan$pages[[i]]$row_indices, 1L)
      first_row_next <- plan$pages[[i + 1L]]$row_indices[[1L]]
      end_key <- spec@data$soc[last_row_i]
      next_key <- spec@data$soc[first_row_next]
      expect_false(identical(end_key, next_key))
    }
  }
})

test_that("engine_paginate() honours orphan_floor escape on tall groups", {
  # A single B-group spans rows 2..6; rpp will be tight enough that
  # walking the break all the way back to row 1 would yield 0 rows
  # on page 1. With orphan_floor = 3, engine refuses adjustment and
  # splits inside the B-run.
  df <- data.frame(
    soc = c("A", "B", "B", "B", "B", "B", "C"),
    val = 1:7
  )
  spec <- tabular(df) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    paginate(keep_together = "soc", orphan_floor = 3L)
  preset <- preset_spec(font_size = 60)
  spec <- S7::set_props(spec, preset = preset)
  plan <- tabular:::engine_paginate(spec)
  # Tight rpp from 60pt font: page 1 carries multiple rows even
  # though that means splitting the B-run, because the only
  # honoured break point (after row 1) leaves < orphan_floor rows.
  expect_gte(length(plan$pages[[1]]$row_indices), 3L)
})

test_that("engine_paginate() merges last page back when below widow_floor", {
  # Force exactly the widow scenario: 13 rows at 72pt body font on
  # letter portrait yields an rpp of ~6, so a naive split is
  # 6 + 6 + 1. The single-row final page is below widow_floor = 2
  # and must merge into the previous page (final: 6 + 7).
  df <- data.frame(
    soc = rep("A", 13L),
    val = 1:13
  )
  spec <- tabular(df) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    paginate(widow_floor = 2L)
  preset <- preset_spec(font_size = 72)
  spec <- S7::set_props(spec, preset = preset)
  plan <- tabular:::engine_paginate(spec)
  expect_identical(length(plan$pages), 2L)
  expect_gt(
    length(plan$pages[[2L]]$row_indices),
    plan$rows_per_page
  )
})

test_that("engine_paginate() splits columns into panels", {
  df <- data.frame(a = 1:3, b = 4:6, c = 7:9, d = 10:12, e = 13:15)
  spec <- tabular(df) |>
    cols(a = col_spec(usage = "group", label = "A")) |>
    paginate(panels = 2L)
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$total_panels, 2L)
  # Group col 'a' (idx 1) repeats on every panel; non-group cols
  # 2..5 split as 2,3 | 4,5.
  expect_identical(plan$pages[[1]]$col_indices, c(1L, 2L, 3L))
  expect_identical(plan$pages[[2]]$col_indices, c(1L, 4L, 5L))
})

test_that("engine_paginate() caps panels at non-group column count", {
  df <- data.frame(g = 1:3, x = 4:6)
  spec <- tabular(df) |>
    cols(g = col_spec(usage = "group", label = "G")) |>
    paginate(panels = 4L)
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$total_panels, 1L)
})

test_that('engine_paginate() treats panels = "auto" as single panel for now', {
  df <- data.frame(g = 1:3, x = 4:6, y = 7:9)
  spec <- tabular(df) |>
    cols(g = col_spec(usage = "group", label = "G")) |>
    paginate(panels = "auto")
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$total_panels, 1L)
})

test_that("engine_paginate() cross-product vertical x horizontal", {
  df <- data.frame(
    soc = rep(c("A", "B", "C"), each = 3L),
    x = 1:9,
    y = 11:19,
    z = 21:29
  )
  spec <- tabular(df) |>
    cols(soc = col_spec(usage = "group", label = "SOC")) |>
    paginate(panels = 2L)
  preset <- preset_spec(font_size = 36)
  spec <- S7::set_props(spec, preset = preset)
  plan <- tabular:::engine_paginate(spec)
  # 3 non-group cols / 2 panels = 2 horiz panels. Vert pages depend
  # on the computed budget; we only assert horizontal split.
  expect_identical(plan$total_panels, 2L)
  expect_gte(plan$total_pages, 2L)
})

test_that("engine_paginate() preserves a user continuation marker", {
  spec <- make_paginated_spec(
    30L,
    font_size = 24,
    continuation = "[next page]"
  )
  plan <- tabular:::engine_paginate(spec)
  for (p in plan$pages) {
    expect_identical(p$continuation, "[next page]")
  }
})

test_that("engine_paginate() preserves an empty continuation (no marker)", {
  spec <- make_paginated_spec(5L)
  plan <- tabular:::engine_paginate(spec)
  for (p in plan$pages) {
    expect_identical(p$continuation, character())
  }
})

test_that("engine_paginate() preserves repeat_headers", {
  spec <- make_paginated_spec(30L, font_size = 24, repeat_headers = FALSE)
  plan <- tabular:::engine_paginate(spec)
  for (p in plan$pages) {
    expect_false(p$repeat_headers)
  }
})

test_that("engine_paginate() works on a spec with no group columns", {
  df <- data.frame(a = 1:10, b = 11:20)
  spec <- tabular(df) |>
    paginate()
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$pages[[1]]$col_indices, 1:2)
})

test_that("engine_paginate() with panels > 1 and no non-group cols is single panel", {
  df <- data.frame(g = 1:3, h = c("x", "y", "z"))
  spec <- tabular(df) |>
    cols(
      g = col_spec(usage = "group", label = "G"),
      h = col_spec(usage = "group", label = "H")
    ) |>
    paginate(panels = 3L)
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$total_panels, 1L)
})

test_that("engine_paginate() row budget accounts for multi-line column labels", {
  df <- data.frame(a = 1:5, b = 6:10)
  spec_short <- tabular(df) |>
    cols(b = col_spec(label = "B"))
  spec_tall <- tabular(df) |>
    cols(b = col_spec(label = "Line1\nLine2\nLine3"))
  plan_short <- tabular:::engine_paginate(spec_short)
  plan_tall <- tabular:::engine_paginate(spec_tall)
  expect_gt(plan_short$rows_per_page, plan_tall$rows_per_page)
})

test_that("engine_paginate() row budget accounts for spanner header depth", {
  df <- data.frame(a = 1:3, b = 4:6, c = 7:9)
  spec_flat <- tabular(df)
  spec_spanned <- tabular(df) |>
    headers("Top" = list("Mid" = c("a", "b")))
  plan_flat <- tabular:::engine_paginate(spec_flat)
  plan_spanned <- tabular:::engine_paginate(spec_spanned)
  expect_gt(plan_flat$rows_per_page, plan_spanned$rows_per_page)
})
