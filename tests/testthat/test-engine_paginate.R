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

test_that("engine_paginate() aborts when chrome is taller than the page", {
  # Huge font + many titles -> chrome alone exceeds the printable
  # height, so no data row fits. The engine aborts rather than
  # printing data on top of the chrome.
  spec <- make_paginated_spec(
    1L,
    font_size = 72,
    titles = rep("T", 50L)
  )
  expect_error(
    tabular:::engine_paginate(spec),
    class = "tabular_error_layout"
  )
})

test_that("engine_paginate() floors rows_per_page at the minimum on a tight budget", {
  # Large font with minimal chrome (header only) leaves a small but
  # positive budget; the engine floors at the documented minimum (5).
  spec <- make_paginated_spec(1L, font_size = 120)
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
  preset <- preset_spec(font_size = 72, orientation = "portrait")
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

test_that("engine_paginate() default (panels = 1) is a single panel", {
  df <- data.frame(g = 1:3, x = 4:6, y = 7:9)
  spec <- tabular(df) |>
    cols(g = col_spec(usage = "group", label = "G")) |>
    paginate(panels = 1)
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

test_that("engine_paginate() repeats usage = 'id' columns on every panel", {
  # A non-group stub (the "Statistic" column) must repeat per panel
  # like a group column, but it never collapses in the body.
  df <- data.frame(
    g = 1:4,
    stat = 5:8,
    x1 = 1:4,
    x2 = 1:4,
    x3 = 1:4,
    x4 = 1:4
  )
  spec <- tabular(df) |>
    cols(
      g = col_spec(usage = "group", group_display = "column"),
      stat = col_spec(usage = "id")
    ) |>
    paginate(panels = 2L)
  plan <- tabular:::engine_paginate(spec)
  expect_identical(plan$total_panels, 2L)
  # Stub = g (1) + stat (2) repeats on both panels; data 3..6 split.
  expect_identical(plan$pages[[1]]$col_indices, c(1L, 2L, 3L, 4L))
  expect_identical(plan$pages[[2]]$col_indices, c(1L, 2L, 5L, 6L))
})

test_that("engine_paginate() records panel_spans excluding the stub", {
  df <- data.frame(
    g = 1:4,
    stat = 5:8,
    x1 = 1:4,
    x2 = 1:4,
    x3 = 1:4,
    x4 = 1:4
  )
  spec <- tabular(df) |>
    cols(
      g = col_spec(usage = "group", group_display = "column"),
      stat = col_spec(usage = "id")
    ) |>
    paginate(panels = 2L)
  plan <- tabular:::engine_paginate(spec)
  expect_length(plan$panel_spans, 2L)
  expect_identical(plan$panel_spans[[1L]]$label, "Panel 1")
  expect_identical(plan$panel_spans[[1L]]$col_names, c("x1", "x2"))
  expect_identical(plan$panel_spans[[2L]]$label, "Panel 2")
  expect_identical(plan$panel_spans[[2L]]$col_names, c("x3", "x4"))
})

test_that("engine_paginate(continuous = TRUE) collapses to one all-columns page", {
  df <- data.frame(
    g = 1:4,
    stat = 5:8,
    x1 = 1:4,
    x2 = 1:4,
    x3 = 1:4,
    x4 = 1:4
  )
  spec <- tabular(df) |>
    cols(
      g = col_spec(usage = "group", group_display = "column"),
      stat = col_spec(usage = "id")
    ) |>
    paginate(panels = 2L)
  plan <- tabular:::engine_paginate(spec, continuous = TRUE)
  # One panel page, full column set in original order.
  panel_idx <- vapply(plan$pages, function(p) p$panel_index, integer(1L))
  expect_identical(length(unique(panel_idx)), 1L)
  expect_identical(plan$pages[[1L]]$col_indices, 1:6)
  # total_panels still reports the logical (requested) count, and
  # panel_spans is retained for the continuous-backend header note.
  expect_identical(plan$total_panels, 2L)
  expect_length(plan$panel_spans, 2L)
})

test_that("engine_paginate() reports panel_spans = NULL for a single panel", {
  df <- data.frame(g = 1:3, x = 4:6, y = 7:9)
  spec <- tabular(df) |>
    cols(g = col_spec(usage = "group")) |>
    paginate(panels = 1L)
  plan <- tabular:::engine_paginate(spec, continuous = TRUE)
  expect_null(plan$panel_spans)
  expect_identical(plan$total_panels, 1L)
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

test_that("engine_paginate() derives per-page chrome booleans from repeat_content", {
  # Drop "headers" -> repeat_headers FALSE on every page; "titles"
  # and "footnotes" still in the set so their per-page flags stay TRUE
  # on every page.
  spec <- make_paginated_spec(
    30L,
    font_size = 24,
    repeat_content = c("titles", "footnotes")
  )
  plan <- tabular:::engine_paginate(spec)
  for (p in plan$pages) {
    expect_false(p$repeat_headers)
    expect_true(p$show_titles)
    expect_true(p$show_footnotes_here)
  }
})

test_that("engine_paginate() with repeat_content=character() restricts chrome to edges", {
  spec <- make_paginated_spec(
    30L,
    font_size = 24,
    repeat_content = character()
  )
  plan <- tabular:::engine_paginate(spec)
  n <- length(plan$pages)
  expect_gt(n, 1L)
  # Titles only on the first page; footnotes only on the last; headers
  # never repeat.
  expect_true(plan$pages[[1L]]$show_titles)
  expect_false(plan$pages[[2L]]$show_titles)
  expect_false(plan$pages[[1L]]$repeat_headers)
  expect_true(plan$pages[[n]]$show_footnotes_here)
  expect_false(plan$pages[[1L]]$show_footnotes_here)
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

test_that("engine_paginate() excludes col_spec(visible = FALSE) columns from page panels", {
  spec <- tabular(data.frame(x = 1:3, y = 11:13, z = 21:23)) |>
    cols(
      x = col_spec(label = "X"),
      y = col_spec(visible = FALSE),
      z = col_spec(label = "Z")
    )
  plan <- tabular:::engine_paginate(spec)
  # The single panel should carry only the data-frame indices for
  # visible columns (x and z, indices 1 and 3); index 2 (y) is
  # filtered out.
  expect_identical(plan$pages[[1]]$col_indices, c(1L, 3L))
})

test_that("emit() does not render col_spec(visible = FALSE) columns across backends", {
  spec <- tabular(data.frame(x = 1:2, y = 11:12, z = 21:22)) |>
    cols(
      x = col_spec(label = "X"),
      y = col_spec(label = "Y hidden", visible = FALSE),
      z = col_spec(label = "Z")
    )
  out_html <- withr::local_tempfile(fileext = ".html")
  emit(spec, out_html)
  txt_html <- paste(readLines(out_html, warn = FALSE), collapse = "\n")
  expect_false(grepl("Y hidden", txt_html, fixed = TRUE))
  expect_false(grepl(">11<", txt_html, fixed = TRUE))

  out_rtf <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out_rtf)
  txt_rtf <- paste(readLines(out_rtf, warn = FALSE), collapse = "\n")
  expect_false(grepl("Y hidden", txt_rtf, fixed = TRUE))

  out_tex <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out_tex)
  txt_tex <- paste(readLines(out_tex, warn = FALSE), collapse = "\n")
  expect_false(grepl("Y hidden", txt_tex, fixed = TRUE))

  out_docx <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out_docx)
  td <- withr::local_tempdir()
  utils::unzip(out_docx, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_false(grepl("Y hidden", doc, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Keep-with-next mask (galley parity for RTF / PDF / LaTeX)
# ---------------------------------------------------------------------

test_that("engine_paginate() emits keep_with_next FALSE when keep_together is unset", {
  df <- data.frame(grp = c("A", "A", "B", "B", "B"), val = 1:5)
  spec <- tabular(df) |>
    cols(grp = col_spec(usage = "group", label = "Group"))
  plan <- tabular:::engine_paginate(spec)
  expect_type(plan$keep_with_next, "logical")
  expect_length(plan$keep_with_next, 5L)
  expect_false(any(plan$keep_with_next))
})

test_that("engine_paginate() glues a small group fully via keep_with_next", {
  # 3-row group "A", 2-row group "B"; both fit on one page. Mask
  # glues rows 1-2 (within A), and rows 4-5 are flagged FALSE on
  # row 5 (last of B; nothing to glue forward to).
  df <- data.frame(grp = c("A", "A", "A", "B", "B"), val = 1:5)
  spec <- tabular(df) |>
    cols(grp = col_spec(usage = "group", label = "Group")) |>
    paginate(keep_together = "grp")
  plan <- tabular:::engine_paginate(spec)
  expect_equal(plan$keep_with_next, c(TRUE, TRUE, FALSE, TRUE, FALSE))
})

test_that("engine_paginate() applies edge protection on an oversized group", {
  # 12-row group at rpp=4 (force via 72pt body font on letter
  # portrait). Top orphan_floor-1 = 2 rows + bottom widow_floor-1
  # = 1 row glue; middle rows free to split.
  df <- data.frame(grp = rep("A", 12L), val = 1:12)
  spec <- tabular(df) |>
    cols(grp = col_spec(usage = "group", label = "Group")) |>
    paginate(keep_together = "grp", orphan_floor = 3L, widow_floor = 2L)
  spec <- S7::set_props(spec, preset = preset_spec(font_size = 72))
  plan <- tabular:::engine_paginate(spec)
  expect_lt(plan$rows_per_page, 12L)
  m <- plan$keep_with_next
  # Top 2 rows glue forward; bottom widow_floor-1 = 1 row (row 11)
  # glues forward; row 12 is the last row of the group and the
  # data — never glues forward.
  expect_true(m[[1L]])
  expect_true(m[[2L]])
  expect_false(m[[3L]])
  expect_false(m[[10L]])
  expect_true(m[[11L]])
  expect_false(m[[12L]])
})

test_that("engine_paginate(native = TRUE) emits one vertical page per panel", {
  # 40 rows that would split across many pages at 24pt; native skips the
  # vertical split so the single panel rides ONE page covering all rows
  # (Word paginates the body).
  df <- data.frame(grp = rep(c("A", "B"), each = 20L), val = 1:40)
  spec <- tabular(df) |>
    cols(grp = col_spec(usage = "group", label = "Group")) |>
    preset(orientation = "portrait", font_size = 24)

  split <- tabular:::engine_paginate(spec, native = FALSE)
  native <- tabular:::engine_paginate(spec, native = TRUE)

  expect_gt(split$total_pages, 1L) # non-native splits vertically
  expect_identical(native$total_pages, 1L) # native: one page per panel
  expect_length(native$pages[[1L]]$row_indices, 40L)
  # rpp and the keep mask are still computed from the physical budget.
  expect_identical(native$rows_per_page, split$rows_per_page)
  expect_identical(native$keep_with_next, split$keep_with_next)
})

test_that("engine_paginate() returns repeat_titles/headers/footnotes flags", {
  df <- data.frame(grp = c("A", "B"), val = 1:2)
  spec <- tabular(df) |>
    cols(grp = col_spec(usage = "group", label = "Group")) |>
    paginate(repeat_content = c("titles", "headers"))
  plan <- tabular:::engine_paginate(spec)
  expect_true(plan$repeat_titles)
  expect_true(plan$repeat_headers)
  expect_false(plan$repeat_footnotes)
})

test_that(".compute_rows_per_page(native = TRUE) floors instead of aborting", {
  # Chrome taller than the page: non-native aborts; native floors to the
  # minimum so the keep mask still has a budget (Word paginates).
  df <- data.frame(x = 1:3)
  spec <- tabular(
    df,
    titles = rep("t", 40L),
    footnotes = rep("f", 10L)
  ) |>
    preset(orientation = "portrait", font_size = 24)
  expect_error(
    tabular:::.compute_rows_per_page(spec, native = FALSE),
    class = "tabular_error_layout"
  )
  expect_identical(
    tabular:::.compute_rows_per_page(spec, native = TRUE),
    tabular:::.min_rows_per_page
  )
})

test_that(".content_box reserves wrapped footnote lines (#26)", {
  # A long footnote wraps to several physical lines at the printable width.
  # The content box must reserve by rendered lines, not element count, or
  # the body box (and the empty-state message sized from it) is too tall and
  # the wrapped overflow runs off the page.
  long_fn <- paste(
    "Note: Progression-free survival (PFS) is calculated from the date of",
    "first dose to the date of disease progression or death, whichever",
    "occurs first. Estimated with the Kaplan-Meier method; tick marks",
    "denote censored observations; shaded band is the 95% CI."
  )
  short <- tabular(data.frame(x = 1:3), footnotes = "Note: short.")
  long <- tabular(data.frame(x = 1:3), footnotes = long_fn)

  short_box <- tabular:::.content_box(short)
  long_box <- tabular:::.content_box(long)

  # The long footnote reserves more chrome rows, so its body box is shorter.
  expect_gt(long_box$chrome_rows, short_box$chrome_rows)
  expect_lt(long_box$height_in, short_box$height_in)
})

test_that("RTF backend emits \\trkeep + \\keepn on non-last body rows", {
  df <- data.frame(grp = c("A", "A", "B"), val = c("1", "2", "3"))
  spec <- tabular(df) |>
    cols(
      grp = col_spec(usage = "group", label = "Group"),
      val = col_spec(label = "Value")
    )
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # At least one \trkeep + \keepn must appear (the non-last body
  # rows of the only page).
  expect_match(txt, "\\\\trkeep", fixed = FALSE)
  expect_match(txt, "\\\\keepn", fixed = FALSE)
})

test_that("LaTeX backend emits \\\\* (no-page-break terminator) on non-last rows", {
  df <- data.frame(grp = c("A", "A", "B"), val = c("1", "2", "3"))
  spec <- tabular(df) |>
    cols(
      grp = col_spec(usage = "group", label = "Group"),
      val = col_spec(label = "Value")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # At least one row terminator with the no-page-break modifier.
  expect_match(txt, "\\\\\\\\\\*", fixed = FALSE)
})

# ---------------------------------------------------------------------
# No-data multi-page collapse (Part 5)
# ---------------------------------------------------------------------

test_that("a zero-row table collapses to a single empty page under panels", {
  d <- cdisc_saf_demo[0, , drop = FALSE]
  g <- as_grid(tabular(d) |> paginate(panels = 3))
  expect_equal(g@metadata$total_pages, 1L)
  expect_equal(g@metadata$total_panels, 1L)
  n_empty <- sum(vapply(
    g@pages,
    function(p) isTRUE(p$is_empty_page),
    logical(1L)
  ))
  expect_equal(n_empty, 1L)
})

test_that("a non-empty table still splits into horizontal panels", {
  g <- as_grid(tabular(cdisc_saf_demo) |> paginate(panels = 3))
  expect_equal(g@metadata$total_panels, 3L)
  expect_gt(g@metadata$total_pages, 1L)
})

# ---------------------------------------------------------------------
# Blank spacer lines count as physical rows (#fig-blank)
# ---------------------------------------------------------------------

test_that(".wrapped_line_count counts an empty spacer element as one line (#fig-blank)", {
  # A "" element is a blank display line per the one-element-one-line
  # contract for titles / footnotes (it renders as an empty paragraph that
  # occupies a row), so it must reserve a row. The removed .count_lines
  # dropped it (strsplit("", "\n") is character(0)); reserving zero left the
  # content box one row too tall and the blank line spilled off the page.
  spec <- tabular(data.frame(x = 1L))
  preset <- tabular:::.effective_preset(spec)
  expect_equal(tabular:::.wrapped_line_count("", preset, 6), 1L)
  expect_equal(tabular:::.wrapped_line_count(c("a", "", "b"), preset, 6), 3L)
  expect_equal(tabular:::.wrapped_line_count(character(0), preset, 6), 0L)
  # An embedded blank line ("\n\n") splits to an empty sub-line, which still
  # counts as one physical row (the inner all-whitespace branch).
  expect_equal(tabular:::.wrapped_line_count("a\n\nb", preset, 6), 3L)
})
