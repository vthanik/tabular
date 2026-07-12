# group_rows() skip + blank-row injection. PROC REPORT
# `BREAK AFTER var / SKIP` semantics, lifted to per-key control.
#
# `skip` is TRUE / FALSE / a character subset of `by` (the readr
# `col_names` pattern):
#   skip = "grp"          — blank before each transition of `grp`.
#   skip = FALSE          — never insert a blank (character() ditto).
#   skip = TRUE (default) — derive: a "section" key or a break-only
#                  (visible = FALSE) key breaks, a visible column does not.
# The NA-resolution unit tests live in test-aaa_class.R
# (.effective_row_group_skip).

# ---------------------------------------------------------------------
# End-to-end: default behavior matches section mode
# ---------------------------------------------------------------------

test_that("as_grid() default section group injects blanks between sections", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "variable")
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_equal(sum(page1$is_blank_row), sum(page1$is_header_row) - 1L)
  # Last row is NOT a blank (no trailing separator).
  last <- nrow(page1$cells_text)
  expect_false(page1$is_blank_row[[last]])
})

test_that("empty skip on a section key suppresses blanks", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(
        label = "Characteristic"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "variable", skip = character())
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_false(any(page1$is_blank_row))
  # Header rows still inject.
  expect_true(any(page1$is_header_row))
})

test_that("naming a 'column' key in skip injects blanks too", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(
        label = "Characteristic"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "variable", display = "collapse", skip = "variable")
  g <- suppressWarnings(as_grid(spec)) # incidental overflow warn
  page1 <- g@pages[[1L]]
  # Variable visible (column mode); blanks between variable transitions.
  expect_true("variable" %in% page1$col_names)
  expect_true(any(page1$is_blank_row))
  expect_false(any(page1$is_header_row))
  # Every blank must sit immediately before a NEW variable's first row
  # (a non-empty `variable` cell). A column-mode phantom blank would
  # land after a group's first row, before a suppressed "" cell.
  blank_idx <- which(page1$is_blank_row)
  expect_true(all(page1$cells_text[blank_idx + 1L, "variable"] != ""))
})

test_that("blank row sits BEFORE the header row of the next group", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "variable")
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  blank_idx <- which(page1$is_blank_row)
  # Every blank row must be immediately followed by a header row.
  expect_true(all(page1$is_header_row[blank_idx + 1L]))
})

# ---------------------------------------------------------------------
# Multi-group coincident transitions → ONE blank row (union dedupe)
# ---------------------------------------------------------------------

test_that("two group columns ending on the same row produce ONE blank, not two", {
  # Fixture: 6-row synthetic where outer and inner group columns
  # both transition between rows 3 and 4. Without union() dedupe
  # in engine_group_display, the two coincident transitions would
  # inject two blank rows back-to-back at the same boundary.
  df <- data.frame(
    outer = c("A", "A", "A", "B", "B", "B"),
    inner = c("X", "X", "X", "Y", "Y", "Y"),
    stat = c("n", "mean", "sd", "n", "mean", "sd"),
    val = c("3", "12.1", "1.2", "3", "11.4", "0.9"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      outer = col_spec(label = "Outer"),
      inner = col_spec(label = "Inner"),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    ) |>
    group_rows(by = c("outer", "inner"))
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]

  # Exactly ONE blank row across the entire page (the coincident
  # outer + inner transition). Two would mean union() failed.
  expect_equal(sum(page1$is_blank_row), 1L)

  # And it sits immediately before a header row — no orphan blanks.
  blank_idx <- which(page1$is_blank_row)
  expect_true(page1$is_header_row[blank_idx + 1L])
})

test_that("non-coincident transitions across two group columns each emit a blank", {
  # Fixture: outer transitions at row 4 (A → B), inner transitions
  # at rows 3 (X → Y), 5 (Y → Z), and 4 (Z → X under B). Three
  # distinct transition rows, three blank rows.
  df <- data.frame(
    outer = c("A", "A", "A", "B", "B", "B"),
    inner = c("X", "X", "Y", "Z", "Z", "X"),
    stat = c("n", "mean", "n", "n", "mean", "n"),
    val = c("3", "12.1", "5", "3", "11.4", "2"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      outer = col_spec(label = "Outer"),
      inner = col_spec(label = "Inner"),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    ) |>
    group_rows(by = c("outer", "inner"))
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]

  # Three distinct transitions (rows 3, 4, 5 of source data) →
  # three blanks once group_skip is active for both columns.
  expect_equal(sum(page1$is_blank_row), 3L)
})

# ---------------------------------------------------------------------
# Column-mode group_skip: blank only BETWEEN groups, never after a
# group's first row (the phantom-blank regression).
# ---------------------------------------------------------------------

test_that("column-mode group_skip blanks between groups, not after first row", {
  # 2 groups x 3 rows. The bug injected a blank after each group's
  # first row because skip transitions were read AFTER column-mode
  # suppression blanked the repeated label ("A","","" -> phantom run
  # boundary at row 2).
  df <- data.frame(
    grp = c("A", "A", "A", "B", "B", "B"),
    stat = c("n", "mean", "sd", "n", "mean", "sd"),
    val = c("10", "5.2", "1.1", "12", "6.3", "1.4"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(
        label = "Group"
      ),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    ) |>
    group_rows(by = "grp", display = "collapse", skip = "grp")
  page1 <- as_grid(spec)@pages[[1L]]

  # n_groups - 1 = 1 blank (between A and B). The bug produced 3.
  expect_equal(sum(page1$is_blank_row), 1L)
  expect_false(any(page1$is_header_row))
  # The lone blank precedes B's first row (a non-empty group cell).
  blank_idx <- which(page1$is_blank_row)
  expect_true(all(page1$cells_text[blank_idx + 1L, "grp"] != ""))
})

# ---------------------------------------------------------------------
# A break-only key -- col_spec(visible = FALSE) on a grouping key --
# renders no header rows and no in-column text; only its skip breaks.
# ---------------------------------------------------------------------

test_that("break-only (visible = FALSE) group key injects breaks but no headers", {
  # `blk` flips c -> g inside the single "Age" characteristic. It is
  # the clinical "spacer between sub-blocks" marker. Marking it
  # col_spec(visible = FALSE) makes it a break-only key: hidden, no
  # section headers, only its transitions inject a spacer.
  df <- data.frame(
    grp = c("Age", "Age", "Age", "Age"),
    blk = c("c", "c", "g", "g"),
    stat = c("n", "mean", "<65", ">=65"),
    val = c("10", "5.2", "4 (40%)", "6 (60%)"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(
        label = "Characteristic"
      ),
      blk = col_spec(visible = FALSE),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    ) |>
    group_rows(by = c("grp", "blk"), display = "collapse")
  page1 <- as_grid(spec)@pages[[1L]]

  # No section-header rows; the marker column is hidden and its values
  # never leak into the body.
  expect_false(any(page1$is_header_row))
  expect_false("blk" %in% page1$col_names)
  expect_false(any(page1$cells_text %in% c("c", "g")))
  # Exactly one blank at the c -> g flip; the break-only blk skips by
  # default (derive), the visible column grp does not, and grp is
  # constant "Age" so it contributes no transition anyway.
  expect_equal(sum(page1$is_blank_row), 1L)
  # Outer label printed once (column-mode suppression resets on the
  # real group column, not on the now-hidden marker).
  expect_equal(sum(page1$cells_text[, "grp"] == "Age"), 1L)
})

test_that("a break-only key stays out of the body and drives only its breaks", {
  # A grouping key marked visible = FALSE contributes its skip plan but
  # never renders -- no column, no header row.
  df <- data.frame(
    grp = c("Age", "Age", "Age", "Age"),
    blk = c("c", "c", "g", "g"),
    stat = c("n", "mean", "<65", ">=65"),
    val = c("10", "5.2", "4 (40%)", "6 (60%)"),
    stringsAsFactors = FALSE
  )
  break_form <- tabular(df) |>
    cols(
      grp = col_spec(label = "Characteristic"),
      blk = col_spec(visible = FALSE),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    ) |>
    group_rows(by = c("grp", "blk"), display = "collapse") |>
    as_grid()
  page <- break_form@pages[[1L]]
  expect_false("blk" %in% page$col_names)
  # One blank row where blk transitions c -> g (row 3 of the data).
  expect_true(any(page$is_blank_row))
  expect_false(any(page$is_header_row))
})
