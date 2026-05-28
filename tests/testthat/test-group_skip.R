# col_spec@group_skip + blank-row injection. PROC REPORT
# `BREAK AFTER var / SKIP` semantics, lifted to per-column control.
#
# Per-column `group_skip`:
#   TRUE  — insert a blank row before each value transition.
#   FALSE — never insert a blank.
#   NA (default) — follow `group_display`: TRUE for header_row,
#                  FALSE for column / column_repeat.

# ---------------------------------------------------------------------
# col_spec validator + default semantics
# ---------------------------------------------------------------------

test_that("col_spec defaults group_skip to NA (follow group_display)", {
  expect_true(is.na(col_spec()@group_skip))
})

test_that("col_spec accepts TRUE / FALSE / NA explicitly", {
  expect_true(col_spec(group_skip = TRUE)@group_skip)
  expect_false(col_spec(group_skip = FALSE)@group_skip)
  expect_true(is.na(col_spec(group_skip = NA)@group_skip))
})

test_that("col_spec rejects non-logical / length>1 group_skip", {
  expect_error(col_spec(group_skip = "yes"), class = "tabular_error_input")
  expect_error(
    col_spec(group_skip = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(col_spec(group_skip = 1), class = "tabular_error_input")
})

test_that(".effective_group_skip() follows group_display when group_skip is NA", {
  expect_true(
    tabular:::.effective_group_skip(
      col_spec(usage = "group", group_display = "header_row")
    )
  )
  expect_false(
    tabular:::.effective_group_skip(
      col_spec(usage = "group", group_display = "column")
    )
  )
  expect_false(
    tabular:::.effective_group_skip(
      col_spec(usage = "group", group_display = "column_repeat")
    )
  )
})

test_that(".effective_group_skip() honours explicit TRUE / FALSE", {
  expect_true(
    tabular:::.effective_group_skip(
      col_spec(usage = "group", group_display = "column", group_skip = TRUE)
    )
  )
  expect_false(
    tabular:::.effective_group_skip(
      col_spec(
        usage = "group",
        group_display = "header_row",
        group_skip = FALSE
      )
    )
  )
})

# ---------------------------------------------------------------------
# End-to-end: default behavior matches header_row mode
# ---------------------------------------------------------------------

test_that("as_grid() default header_row group injects blanks between sections", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_equal(sum(page1$is_blank_row), sum(page1$is_header_row) - 1L)
  # Last row is NOT a blank (no trailing separator).
  last <- nrow(page1$cells_text)
  expect_false(page1$is_blank_row[[last]])
})

test_that("explicit group_skip = FALSE on a header_row column suppresses blanks", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        group_display = "header_row",
        group_skip = FALSE,
        label = "Characteristic"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_false(any(page1$is_blank_row))
  # Header rows still inject.
  expect_true(any(page1$is_header_row))
})

test_that("explicit group_skip = TRUE on a 'column' group injects blanks too", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        group_display = "column",
        group_skip = TRUE,
        label = "Characteristic"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
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
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
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
      outer = col_spec(usage = "group", label = "Outer"),
      inner = col_spec(usage = "group", label = "Inner"),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    )
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
      outer = col_spec(usage = "group", label = "Outer"),
      inner = col_spec(usage = "group", label = "Inner"),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    )
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
        usage = "group",
        group_display = "column",
        group_skip = TRUE,
        label = "Group"
      ),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    )
  page1 <- as_grid(spec)@pages[[1L]]

  # n_groups - 1 = 1 blank (between A and B). The bug produced 3.
  expect_equal(sum(page1$is_blank_row), 1L)
  expect_false(any(page1$is_header_row))
  # The lone blank precedes B's first row (a non-empty group cell).
  blank_idx <- which(page1$is_blank_row)
  expect_true(all(page1$cells_text[blank_idx + 1L, "grp"] != ""))
})

# ---------------------------------------------------------------------
# A user-hidden usage = "group" column is break-only: no header rows,
# no in-column text, only its group_skip breaks.
# ---------------------------------------------------------------------

test_that("hidden group column injects breaks but no header rows", {
  # `blk` flips c -> g inside the single "Age" characteristic. It is
  # the clinical "spacer between sub-blocks" marker. With the default
  # group_display ("header_row"), the bug surfaced "c"/"g" as section
  # headers; the fix makes a user-hidden group column break-only.
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
        usage = "group",
        group_display = "column",
        group_skip = TRUE,
        label = "Characteristic"
      ),
      blk = col_spec(usage = "group", group_skip = TRUE, visible = FALSE),
      stat = col_spec(label = "Statistic"),
      val = col_spec(label = "Value")
    )
  page1 <- as_grid(spec)@pages[[1L]]

  # No section-header rows; the marker column is hidden and its values
  # never leak into the body.
  expect_false(any(page1$is_header_row))
  expect_false("blk" %in% page1$col_names)
  expect_false(any(page1$cells_text %in% c("c", "g")))
  # Exactly one blank at the c -> g flip (grp is constant -> no break).
  expect_equal(sum(page1$is_blank_row), 1L)
  # Outer label printed once (column-mode suppression resets on the
  # real group column, not on the now-hidden marker).
  expect_equal(sum(page1$cells_text[, "grp"] == "Age"), 1L)
})

test_that("hidden group spacer renders identically to the column_repeat idiom", {
  # Backward compatibility: the pre-existing 4-property idiom
  # (column_repeat + visible = FALSE + group_skip) and the new
  # 3-property form must produce byte-identical grids.
  df <- data.frame(
    grp = c("Age", "Age", "Age", "Age"),
    blk = c("c", "c", "g", "g"),
    stat = c("n", "mean", "<65", ">=65"),
    val = c("10", "5.2", "4 (40%)", "6 (60%)"),
    stringsAsFactors = FALSE
  )
  mk <- function(blk_spec) {
    tabular(df) |>
      cols(
        grp = col_spec(
          usage = "group",
          group_display = "column",
          group_skip = TRUE,
          label = "Characteristic"
        ),
        blk = blk_spec,
        stat = col_spec(label = "Statistic"),
        val = col_spec(label = "Value")
      ) |>
      as_grid()
  }
  new_form <- mk(col_spec(
    usage = "group",
    group_skip = TRUE,
    visible = FALSE
  ))@pages[[1L]]
  old_form <- mk(col_spec(
    usage = "group",
    group_display = "column_repeat",
    group_skip = TRUE,
    visible = FALSE
  ))@pages[[1L]]

  expect_equal(new_form$cells_text, old_form$cells_text)
  expect_equal(new_form$is_blank_row, old_form$is_blank_row)
  expect_equal(new_form$is_header_row, old_form$is_header_row)
})
