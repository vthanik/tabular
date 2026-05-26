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

# ---------------------------------------------------------------------
# Host-column indent on data rows under `group_display = "header_row"`
# ---------------------------------------------------------------------
#
# When at least one column declares `group_display = "header_row"`,
# every data row's host-column text is prefixed with
# `preset@indent_chars` (default "  ") so the data rows visually nest
# under their synthetic section header. The prefix lands on both
# `cells_text` (for plain-string backends like MD) and `cells_ast`
# (a leading `plain` run, so every backend honours it through the
# unified inline-AST pipeline). Synthetic header rows themselves are
# NOT indented — they're the parent at depth 0.

mk_soc_pt_spec <- function(indent = NULL) {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "CARDIAC", "GI", "GI"),
    label = c("CARDIAC", "Atrial fib", "Tachycardia", "GI", "Nausea"),
    row_type = c("soc", "pt", "pt", "soc", "pt"),
    n = c(5L, 3L, 2L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE", footnotes = "") |>
    cols(
      soc      = col_spec(usage = "group", group_display = "header_row"),
      label    = col_spec(label = "Category"),
      row_type = col_spec(visible = FALSE),
      n        = col_spec(label = "N")
    )
  if (!is.null(indent)) {
    spec <- preset(spec, indent_chars = indent)
  }
  spec
}

test_that("default indent ('  ') prefixes data-row host-col text", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  # Walk in render order: synthetic headers stay flush, data rows
  # carry the leading "  ".
  flush <- page1$cells_text[page1$is_header_row, "label"]
  indented <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "label"
  ]
  expect_true(all(!startsWith(flush, "  ")))
  expect_true(all(startsWith(indented, "  ")))
})

test_that("indent prefix lands on cells_ast as a leading plain run", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  data_row_idx <- which(
    !page1$is_header_row & !page1$is_blank_row
  )[[1L]]
  ast <- page1$cells_ast[[data_row_idx, "label"]]
  expect_true(tabular::is_inline_ast(ast))
  expect_equal(ast@runs[[1L]]$type, "plain")
  expect_equal(ast@runs[[1L]]$text, "  ")
})

test_that("synthetic header rows do NOT carry the indent prefix", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  syn_idx <- which(page1$is_header_row)[[1L]]
  ast <- page1$cells_ast[[syn_idx, "label"]]
  expect_true(tabular::is_inline_ast(ast))
  # First run is the group value (e.g. "CARDIAC"), not the indent.
  first <- ast@runs[[1L]]
  expect_equal(first$type, "plain")
  expect_false(startsWith(first$text %||% "", "  "))
})

test_that("preset(indent_chars = '') disables the indent prefix", {
  g <- as_grid(mk_soc_pt_spec(indent = ""))
  page1 <- g@pages[[1L]]
  indented <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "label"
  ]
  expect_true(all(!startsWith(indented, "  ")))
})

test_that("preset(indent_chars = '    ') honours custom indent width", {
  g <- as_grid(mk_soc_pt_spec(indent = "    "))
  page1 <- g@pages[[1L]]
  indented <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "label"
  ]
  expect_true(all(startsWith(indented, "    ")))
})

test_that("preset(indent_chars = '> ') honours custom prefix marker", {
  g <- as_grid(mk_soc_pt_spec(indent = "> "))
  page1 <- g@pages[[1L]]
  data_row_idx <- which(
    !page1$is_header_row & !page1$is_blank_row
  )[[1L]]
  ast <- page1$cells_ast[[data_row_idx, "label"]]
  expect_equal(ast@runs[[1L]]$text, "> ")
})

test_that("no indent applied when no column declares group_display='header_row'", {
  df <- data.frame(
    soc = c("CARDIAC", "GI"),
    n = c(5L, 10L),
    stringsAsFactors = FALSE
  )
  # Without usage="group", no header_row plan -> no indent.
  spec <- tabular(df, titles = "AE", footnotes = "") |>
    cols(soc = col_spec(label = "SOC"), n = col_spec(label = "N"))
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_false(any(page1$is_header_row))
  expect_equal(unname(page1$cells_text[1L, "soc"]), "CARDIAC")
})

test_that("no indent applied under group_display='column' mode", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI"),
    label = c("Atrial fib", "Tachycardia", "Nausea"),
    n = c(3L, 2L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE", footnotes = "") |>
    cols(
      soc = col_spec(usage = "group", group_display = "column"),
      label = col_spec(label = "PT"),
      n = col_spec(label = "N")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_false(any(page1$is_header_row))
  # No header_row plan active -> label column emits text verbatim
  # without the indent prefix.
  expect_false(any(startsWith(page1$cells_text[, "label"], "  ")))
})

# ---------------------------------------------------------------------
# End-to-end backend emission — every emit format must carry the
# indent on data-row host-col text.
# ---------------------------------------------------------------------

test_that("HTML emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("<td>  Atrial fib</td>", txt, fixed = TRUE))
  expect_true(grepl("<td>  Nausea</td>", txt, fixed = TRUE))
  # The synthetic CARDIAC / GI header rows DO NOT carry the prefix.
  expect_true(grepl("<td>CARDIAC</td>", txt, fixed = TRUE))
  expect_true(grepl("<td>GI</td>", txt, fixed = TRUE))
})

test_that("LaTeX emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("  Atrial fib", txt, fixed = TRUE))
  expect_true(grepl("  Nausea", txt, fixed = TRUE))
})

test_that("RTF emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("  Atrial fib", txt, fixed = TRUE))
  expect_true(grepl("  Nausea", txt, fixed = TRUE))
})

test_that("DOCX emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # OOXML <w:t xml:space="preserve">...</w:t> preserves the leading spaces.
  expect_true(grepl(
    "<w:t xml:space=\"preserve\">  Atrial fib</w:t>",
    doc,
    fixed = TRUE
  ))
  expect_true(grepl(
    "<w:t xml:space=\"preserve\">  Nausea</w:t>",
    doc,
    fixed = TRUE
  ))
})

test_that("MD emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("|   Atrial fib | 3 |", txt, fixed = TRUE))
  expect_true(grepl("|   Nausea | 6 |", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Edge-case coverage on `.indent_host_asts`
# ---------------------------------------------------------------------

test_that(".indent_host_asts is a no-op on empty / non-character input", {
  expect_identical(
    tabular:::.indent_host_asts(list(), "  "),
    list()
  )
  expect_identical(
    tabular:::.indent_host_asts(
      list(tabular:::parse_inline("foo")),
      NULL
    ),
    list(tabular:::parse_inline("foo"))
  )
})

test_that(".indent_host_asts skips entries that are not inline_ast", {
  asts <- list("not an ast", tabular:::parse_inline("foo"))
  out <- tabular:::.indent_host_asts(asts, "  ")
  expect_identical(out[[1L]], "not an ast")
  expect_true(tabular::is_inline_ast(out[[2L]]))
  expect_equal(out[[2L]]@runs[[1L]]$text, "  ")
})

test_that("engine_group_display() skips indent when indent_chars is empty", {
  # Direct call confirms the guard in engine_group_display rejects
  # zero-length / non-character / NA indent values without raising.
  # Row 1: soc="CARDIAC", label="Atrial fib". Row 2: same SOC,
  # label="Tachycardia". Matrix fill is column-major, so the values
  # vector lists col1 (soc) values then col2 (label) values.
  cells_text <- matrix(
    c("CARDIAC", "CARDIAC", "Atrial fib", "Tachycardia"),
    nrow = 2L, ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cells_ast <- matrix(
    list(
      tabular:::parse_inline("CARDIAC"),
      tabular:::parse_inline("CARDIAC"),
      tabular:::parse_inline("Atrial fib"),
      tabular:::parse_inline("Tachycardia")
    ),
    nrow = 2L, ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cells_style <- matrix(
    list(style_node(), style_node(), style_node(), style_node()),
    nrow = 2L, ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cols <- list(
    soc = col_spec(usage = "group", group_display = "header_row"),
    label = col_spec(label = "Category")
  )
  # Empty indent — text passes through verbatim, no leading whitespace.
  out_empty <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_chars = ""
  )
  expect_identical(unname(out_empty$cells_text[, "label"]),
                   c("Atrial fib", "Tachycardia"))
  # Non-character indent — same passthrough.
  out_null <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_chars = NULL
  )
  expect_identical(unname(out_null$cells_text[, "label"]),
                   c("Atrial fib", "Tachycardia"))
  # NA indent — same passthrough.
  out_na <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_chars = NA_character_
  )
  expect_identical(unname(out_na$cells_text[, "label"]),
                   c("Atrial fib", "Tachycardia"))
})

test_that("engine_group_display() short-circuits on zero-row / zero-col matrices", {
  empty_text <- matrix(character(), nrow = 0L, ncol = 0L)
  empty_ast <- matrix(list(), nrow = 0L, ncol = 0L)
  empty_style <- matrix(list(), nrow = 0L, ncol = 0L)
  out <- tabular:::engine_group_display(
    cells_text = empty_text,
    cells_ast = empty_ast,
    cells_style = empty_style,
    cols = list(),
    indent_chars = "  "
  )
  expect_null(out$header_row_plan)
  expect_identical(dim(out$cells_text), c(0L, 0L))
})

test_that("engine_group_display() short-circuits when no group columns are declared", {
  cells_text <- matrix(
    c("a", "b"),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "x")
  )
  cells_ast <- matrix(
    list(tabular:::parse_inline("a"), tabular:::parse_inline("b")),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "x")
  )
  cells_style <- matrix(
    list(style_node(), style_node()),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "x")
  )
  out <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = list(x = col_spec(label = "X")),
    indent_chars = "  "
  )
  expect_null(out$header_row_plan)
  # Text unchanged (no indent applied because no group cols).
  expect_identical(unname(out$cells_text[, "x"]), c("a", "b"))
})

test_that("engine_group_display() with group_display='column' only takes the no-header branch", {
  # Group col exists but none declare `header_row` — header_col is NULL,
  # outer_run_ids fall back to the first group column.
  cells_text <- matrix(
    c("A", "A", "B", "x", "y", "z"),
    nrow = 3L, ncol = 2L,
    dimnames = list(NULL, c("g", "v"))
  )
  cells_ast <- matrix(
    list(
      tabular:::parse_inline("A"), tabular:::parse_inline("A"),
      tabular:::parse_inline("B"), tabular:::parse_inline("x"),
      tabular:::parse_inline("y"), tabular:::parse_inline("z")
    ),
    nrow = 3L, ncol = 2L,
    dimnames = list(NULL, c("g", "v"))
  )
  cells_style <- matrix(
    rep(list(style_node()), 6L),
    nrow = 3L, ncol = 2L,
    dimnames = list(NULL, c("g", "v"))
  )
  cols <- list(
    g = col_spec(usage = "group", group_display = "column"),
    v = col_spec(label = "V")
  )
  out <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_chars = "  "
  )
  expect_null(out$header_row_plan)
  # Column-mode suppression — second "A" cell blanked.
  expect_identical(unname(out$cells_text[, "g"]), c("A", "", "B"))
  # `v` column not indented (no header_row plan).
  expect_identical(unname(out$cells_text[, "v"]), c("x", "y", "z"))
})

test_that(".runs_grouping() returns an empty integer vector for empty input", {
  expect_identical(tabular:::.runs_grouping(character(0L)), integer(0L))
})

test_that(".suppress_column_repeats() short-circuits on length-1 input", {
  expect_identical(
    tabular:::.suppress_column_repeats("only", 1L),
    "only"
  )
})

test_that(".suppress_column_repeats_ast() short-circuits on length-1 input", {
  one <- list(tabular:::parse_inline("only"))
  expect_identical(
    tabular:::.suppress_column_repeats_ast(one, 1L, call = environment()),
    one
  )
})

test_that(".inject_header_rows_for_page() falls through to identity when no plans active", {
  txt <- matrix("a", nrow = 1L, ncol = 1L, dimnames = list(NULL, "x"))
  ast <- matrix(list(tabular:::parse_inline("a")), nrow = 1L, ncol = 1L,
                dimnames = list(NULL, "x"))
  st <- matrix(list(style_node()), nrow = 1L, ncol = 1L,
               dimnames = list(NULL, "x"))
  # No header_row_plan, no skip_transitions -> identity return.
  out <- tabular:::.inject_header_rows_for_page(
    cells_text = txt,
    cells_ast = ast,
    cells_style = st,
    row_indices = 1L,
    visible_col_names = "x",
    header_row_plan = NULL,
    skip_transitions = integer(0L)
  )
  expect_identical(out$cells_text, txt)
  expect_false(any(out$is_header_row))
})

test_that(".inject_header_rows_for_page() disables header plan when host_col missing", {
  # host_col references a column that's not in visible_col_names —
  # the helper switches `has_header_plan` off and skips synthetic
  # injection, only the blank-row plan (if any) survives.
  txt <- matrix(
    c("A", "B"),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "v")
  )
  ast <- matrix(
    list(tabular:::parse_inline("A"), tabular:::parse_inline("B")),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "v")
  )
  st <- matrix(
    list(style_node(), style_node()),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "v")
  )
  plan <- list(
    group_col = "g",
    group_values = c("A", "B"),
    group_asts = list(tabular:::parse_inline("A"), tabular:::parse_inline("B")),
    host_col = "ghost",  # not in visible_col_names
    transitions = c(1L, 2L),
    indent_chars = ""
  )
  out <- tabular:::.inject_header_rows_for_page(
    cells_text = txt,
    cells_ast = ast,
    cells_style = st,
    row_indices = 1:2,
    visible_col_names = "v",
    header_row_plan = plan,
    skip_transitions = c(1L, 2L)
  )
  # No header rows injected (host missing), but blank rows still fire.
  expect_false(any(out$is_header_row))
  expect_true(any(out$is_blank_row))
})

test_that("engine_group_display() handles host_col == NA without indenting", {
  # When every visible column is hidden by group_display="header_row",
  # `.header_row_host_column()` returns NA. The indent guard checks
  # for that and the data rows fall through untouched.
  cells_text <- matrix(
    c("A", "B"),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "soc")
  )
  cells_ast <- matrix(
    list(tabular:::parse_inline("A"), tabular:::parse_inline("B")),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "soc")
  )
  cells_style <- matrix(
    list(style_node(), style_node()),
    nrow = 2L, ncol = 1L,
    dimnames = list(NULL, "soc")
  )
  cols <- list(
    soc = col_spec(usage = "group", group_display = "header_row")
  )
  out <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_chars = "  "
  )
  expect_true(is.na(out$header_row_plan$host_col))
  # Text passes through untouched (no host column to prefix).
  expect_identical(unname(out$cells_text[, "soc"]), c("A", "B"))
})
