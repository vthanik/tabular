# col_spec@group_display + engine_group_display + per-page header
# row injection. Three modes:
#
#   "header_row" (default) — promote group values to section headers
#   "column"               — keep column visible; suppress repeats
#   "column_repeat"        — keep column visible; every row repeats

# ---------------------------------------------------------------------
# col_spec() constructor
# ---------------------------------------------------------------------

test_that("col_spec() default group_display is 'header_row'", {
  cs <- col_spec()
  expect_equal(cs@group_display, "header_row")
})

test_that("col_spec() accepts every value in the enum", {
  for (mode in c("header_row", "column", "column_repeat")) {
    cs <- col_spec(group_display = mode)
    expect_equal(cs@group_display, mode, info = mode)
  }
})

test_that("col_spec() rejects an unknown group_display", {
  expect_error(
    col_spec(group_display = "nope"),
    class = "tabular_error_input"
  )
})

test_that("col_spec() rejects a non-character group_display", {
  expect_error(
    col_spec(group_display = 1L),
    class = "tabular_error_input"
  )
  expect_error(
    col_spec(group_display = NA),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# engine_group_display() — three modes
# ---------------------------------------------------------------------

mk_grid_input <- function(modes) {
  # 6 rows, 3 cols: var (group), stat (group), val.
  cells_text <- matrix(
    c(
      "Age",
      "n",
      "86",
      "Age",
      "Mean",
      "75.2",
      "Age",
      "Median",
      "76.0",
      "Sex",
      "n",
      "86",
      "Sex",
      "F",
      "53",
      "Sex",
      "M",
      "33"
    ),
    nrow = 6,
    byrow = TRUE,
    dimnames = list(NULL, c("var", "stat", "val"))
  )
  cells_ast <- matrix(
    list(parse_inline("")),
    nrow = 6,
    ncol = 3
  )
  for (i in seq_len(6)) {
    for (j in seq_len(3)) {
      cells_ast[[i, j]] <- parse_inline(cells_text[i, j])
    }
  }
  colnames(cells_ast) <- colnames(cells_text)
  cells_style <- matrix(
    list(style_node()),
    nrow = 6,
    ncol = 3
  )
  colnames(cells_style) <- colnames(cells_text)
  cols <- list(
    var = col_spec(usage = "group", group_display = modes[[1L]]),
    stat = col_spec(usage = "group", group_display = modes[[2L]]),
    val = col_spec()
  )
  for (nm in names(cols)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], name = nm)
  }
  list(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols
  )
}

test_that("engine_group_display 'header_row' on outer group flips visibility + builds header_row_plan", {
  inp <- mk_grid_input(c("header_row", "column"))
  out <- engine_group_display(
    inp$cells_text,
    inp$cells_ast,
    inp$cells_style,
    inp$cols
  )
  expect_false(isTRUE(out$cols$var@visible))
  expect_true(isTRUE(out$cols$stat@visible))
  expect_false(is.null(out$header_row_plan))
  expect_equal(out$header_row_plan$group_col, "var")
  expect_equal(out$header_row_plan$transitions, c(1L, 4L))
})

test_that("engine_group_display 'column' mode suppresses repeats within outer-group block", {
  inp <- mk_grid_input(c("header_row", "column"))
  out <- engine_group_display(
    inp$cells_text,
    inp$cells_ast,
    inp$cells_style,
    inp$cols
  )
  # `stat` is column mode under "Age" / "Sex" blocks. Both blocks
  # have unique stat values ("n", "Mean", "Median" / "n", "F", "M"),
  # so suppression doesn't trigger — every stat cell keeps its
  # value.
  expect_equal(
    out$cells_text[, "stat"],
    c("n", "Mean", "Median", "n", "F", "M")
  )
})

test_that("engine_group_display 'column_repeat' mode is a no-op", {
  inp <- mk_grid_input(c("column_repeat", "column_repeat"))
  out <- engine_group_display(
    inp$cells_text,
    inp$cells_ast,
    inp$cells_style,
    inp$cols
  )
  expect_identical(out$cells_text, inp$cells_text)
  # Both columns still visible.
  expect_true(isTRUE(out$cols$var@visible))
  expect_true(isTRUE(out$cols$stat@visible))
  expect_null(out$header_row_plan)
})

test_that("engine_group_display 'column' mode actually suppresses when values repeat", {
  # Two-block "var" with stat values repeating.
  text <- matrix(
    c(
      "Age",
      "n",
      "Age",
      "n",
      "Sex",
      "n",
      "Sex",
      "n"
    ),
    nrow = 4,
    byrow = TRUE,
    dimnames = list(NULL, c("var", "stat"))
  )
  ast <- matrix(list(parse_inline("")), nrow = 4, ncol = 2)
  for (i in seq_len(4L)) {
    for (j in seq_len(2L)) {
      ast[[i, j]] <- parse_inline(text[i, j])
    }
  }
  colnames(ast) <- colnames(text)
  style <- matrix(list(style_node()), nrow = 4, ncol = 2)
  colnames(style) <- colnames(text)
  cols <- list(
    var = col_spec(usage = "group", group_display = "column_repeat"),
    stat = col_spec(usage = "group", group_display = "column")
  )
  for (nm in names(cols)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], name = nm)
  }
  out <- engine_group_display(text, ast, style, cols)
  # stat = "n" suppresses on row 2 (same as row 1, same outer block).
  # Row 3 starts a new outer block, so "n" reappears. Row 4
  # suppresses (same as row 3).
  expect_equal(out$cells_text[, "stat"], c("n", "", "n", ""))
})

# ---------------------------------------------------------------------
# End-to-end: as_grid() default header_row promotes variable
# ---------------------------------------------------------------------

test_that("as_grid() with default usage='group' promotes the variable column to header rows", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # variable column hidden from visible body.
  expect_false("variable" %in% page1$col_names)
  expect_true("stat_label" %in% page1$col_names)
  # First row is a header row carrying "Age (years)" in the first
  # visible column (stat_label position).
  expect_true(page1$is_header_row[[1L]])
  expect_equal(unname(page1$cells_text[1L, "stat_label"]), "Age (years)")
  # Header row carries blank elsewhere.
  expect_equal(unname(page1$cells_text[1L, "placebo"]), "")
})

test_that("as_grid() with explicit group_display='column_repeat' keeps the variable column visible", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column_repeat"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # Variable column visible; every row repeats the value.
  expect_true("variable" %in% page1$col_names)
  expect_equal(unname(page1$cells_text[1L, "variable"]), "Age (years)")
  expect_equal(unname(page1$cells_text[2L, "variable"]), "Age (years)")
  # No header rows injected.
  expect_false(any(page1$is_header_row))
})

test_that("as_grid() with explicit group_display='column' keeps column + suppresses repeats", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_true("variable" %in% page1$col_names)
  # Row 1 shows the value; row 2+ in the same block is blank.
  expect_equal(unname(page1$cells_text[1L, "variable"]), "Age (years)")
  expect_equal(unname(page1$cells_text[2L, "variable"]), "")
  # No header rows injected under "column" mode.
  expect_false(any(page1$is_header_row))
})
