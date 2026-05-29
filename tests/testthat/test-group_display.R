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
  # Multi-band shape: `bands` is a list, outer at index 1. Single
  # header_row column -> one band at depth 0.
  expect_length(out$header_row_plan$bands, 1L)
  expect_equal(out$header_row_plan$bands[[1L]]$group_col, "var")
  expect_equal(out$header_row_plan$bands[[1L]]$transitions, c(1L, 4L))
  expect_identical(out$header_row_plan$bands[[1L]]$depth, 0L)
  expect_identical(out$header_row_plan$data_depth, 1L)
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
# Per-row indent via `col_spec(indent_by = "<depth_col>")`
# ---------------------------------------------------------------------
#
# A target column declares `indent_by = "<column_name>"` to point at
# a hidden depth column carrying per-row integer values. The engine
# prefixes the target column's text + AST with
# `strrep(" ", preset@indent_size * depth)`. Depth 0 rows stay flush;
# depth N rows carry N indents. Synthetic header rows (from
# `group_display = "header_row"`) are NEVER indented — they're the
# parent at depth 0.

mk_soc_pt_spec <- function(indent = NULL) {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "CARDIAC", "GI", "GI"),
    label = c("CARDIAC", "Atrial fib", "Tachycardia", "GI", "Nausea"),
    row_type = c("soc", "pt", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 1L, 0L, 1L),
    n = c(5L, 3L, 2L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE", footnotes = "") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Category", indent_by = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  if (!is.null(indent)) {
    spec <- preset(spec, indent_size = indent)
  }
  spec
}

test_that("indent_by depth 0 rows stay flush; depth 1 rows carry '  '", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  # SOC summary rows have indent_level = 0L -> flush.
  soc_rows <- page1$cells_text[
    !page1$is_header_row &
      !page1$is_blank_row &
      page1$cells_text[, "label"] %in% c("CARDIAC", "GI"),
    "label"
  ]
  # PT rows have indent_level = 1L -> "  " prefix.
  pt_rows <- page1$cells_text[
    !page1$is_header_row &
      !page1$is_blank_row &
      !(page1$cells_text[, "label"] %in% c("CARDIAC", "GI")),
    "label"
  ]
  expect_true(all(!startsWith(soc_rows, "  ")))
  expect_true(all(startsWith(pt_rows, "  ")))
})

test_that("indent_by prefix lands on cells_ast as a leading plain run", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  # First PT row (depth 1) — find it by matching one of the PT labels.
  pt_idx <- which(
    !page1$is_header_row &
      !page1$is_blank_row &
      page1$cells_text[, "label"] == "  Atrial fib"
  )[[1L]]
  ast <- page1$cells_ast[[pt_idx, "label"]]
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

test_that("indent_by depth-0 cells_ast carries NO leading prefix run", {
  g <- as_grid(mk_soc_pt_spec())
  page1 <- g@pages[[1L]]
  # SOC summary row (depth 0) — first run should be the SOC label,
  # not an empty plain run injected by the indent helper.
  soc_idx <- which(
    !page1$is_header_row &
      !page1$is_blank_row &
      page1$cells_text[, "label"] == "CARDIAC"
  )[[1L]]
  ast <- page1$cells_ast[[soc_idx, "label"]]
  expect_equal(ast@runs[[1L]]$text, "CARDIAC")
})

test_that("preset(indent_size = 0L) disables the indent prefix", {
  g <- as_grid(mk_soc_pt_spec(indent = 0L))
  page1 <- g@pages[[1L]]
  indented <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "label"
  ]
  expect_true(all(!startsWith(indented, "  ")))
})

test_that("preset(indent_size = 4L) honours custom indent width on PT rows", {
  g <- as_grid(mk_soc_pt_spec(indent = 4L))
  page1 <- g@pages[[1L]]
  pt_rows <- page1$cells_text[
    !page1$is_header_row &
      !page1$is_blank_row &
      !(page1$cells_text[, "label"] %in% c("    ", "CARDIAC", "GI")),
    "label"
  ]
  expect_true(all(startsWith(pt_rows, "    ")))
  # SOC rows (depth 0) stay flush even with a 4-space indent_size.
  soc_rows <- page1$cells_text[
    !page1$is_header_row &
      !page1$is_blank_row &
      page1$cells_text[, "label"] %in% c("CARDIAC", "GI"),
    "label"
  ]
  expect_true(all(!startsWith(soc_rows, " ")))
})

test_that("preset(indent_size = 3L) honours an odd indent width on PT rows", {
  # The new integer knob accepts any non-negative count; odd values
  # (1, 3, 5, ...) work the same as even ones. The "> " prefix-marker
  # form is no longer expressible — non-space prefixes were dropped
  # together with the character-typed knob.
  g <- as_grid(mk_soc_pt_spec(indent = 3L))
  page1 <- g@pages[[1L]]
  pt_idx <- which(
    !page1$is_header_row &
      !page1$is_blank_row &
      page1$cells_text[, "label"] == "   Atrial fib"
  )[[1L]]
  ast <- page1$cells_ast[[pt_idx, "label"]]
  expect_equal(ast@runs[[1L]]$text, "   ")
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
  # HTML re-expresses the engine-prepended indent as CSS
  # `padding-left` so the indent actually renders (browsers
  # collapse runs of leading whitespace inside `<td>`). Width is
  # AFM-derived from the active body font, ADDITIVE over the
  # baseline `.6rem` cell pad via CSS `calc()`. Default preset uses
  # Liberation Mono → Courier AFM; `"  "` at Courier is 1200/1000-
  # em → 1.2em per depth level.
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Atrial fib</td>",
    txt,
    fixed = TRUE
  ))
  expect_true(grepl(
    "<td style=\"padding-left: calc(.6rem + 1.2em);\">Nausea</td>",
    txt,
    fixed = TRUE
  ))
  # The synthetic CARDIAC / GI header rows DO NOT carry the prefix.
  expect_true(grepl("<td>CARDIAC</td>", txt, fixed = TRUE))
  expect_true(grepl("<td>GI</td>", txt, fixed = TRUE))
})

test_that("LaTeX emit indents data-row host-col cells under header_row mode", {
  # The engine bakes a leading-space prefix into cells_text AND ships
  # an integer depth on `page$cells_indent`. The LaTeX backend reads
  # the sidecar, strips the prefix, and emits the indent as a per-cell
  # `\leftskip` group so wrapped continuation lines align with the
  # indented baseline (SAS PADDINGLEFT contract). `\leftskip` is used
  # rather than the column key `leftsep`, which tabularray rejects
  # inside a cell and which broke the PDF compile.
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "{\\leftskip=", fixed = TRUE)
  expect_true(grepl("Atrial fib", txt, fixed = TRUE))
  expect_true(grepl("Nausea", txt, fixed = TRUE))
  # Engine-baked leading-space prefix must NOT survive into the cell
  # body — it's been re-expressed as native padding.
  expect_false(grepl("  Atrial fib", txt, fixed = TRUE))
  expect_false(grepl("  Nausea", txt, fixed = TRUE))
})

test_that("RTF emit indents data-row host-col cells under header_row mode", {
  spec <- mk_soc_pt_spec()
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "\\\\li\\d+", perl = TRUE)
  expect_true(grepl("Atrial fib", txt, fixed = TRUE))
  expect_true(grepl("Nausea", txt, fixed = TRUE))
  expect_false(grepl("  Atrial fib", txt, fixed = TRUE))
  expect_false(grepl("  Nausea", txt, fixed = TRUE))
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
  # OOXML `<w:ind w:left="N"/>` inside `<w:pPr>` carries the indent
  # natively; the leading-space prefix is stripped from `<w:t>`.
  expect_match(doc, "<w:ind w:left=\"\\d+\"/>", perl = TRUE)
  expect_true(grepl(
    "<w:t xml:space=\"preserve\">Atrial fib</w:t>",
    doc,
    fixed = TRUE
  ))
  expect_true(grepl(
    "<w:t xml:space=\"preserve\">Nausea</w:t>",
    doc,
    fixed = TRUE
  ))
  expect_false(grepl(
    "<w:t xml:space=\"preserve\">  Atrial fib</w:t>",
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

test_that(".indent_host_asts is a no-op on empty / zero-size input", {
  expect_identical(
    tabular:::.indent_host_asts(list(), 2L),
    list()
  )
  expect_identical(
    tabular:::.indent_host_asts(
      list(tabular:::parse_inline("foo")),
      0L
    ),
    list(tabular:::parse_inline("foo"))
  )
})

test_that(".indent_host_asts skips entries that are not inline_ast", {
  asts <- list("not an ast", tabular:::parse_inline("foo"))
  out <- tabular:::.indent_host_asts(asts, 2L)
  expect_identical(out[[1L]], "not an ast")
  expect_true(tabular::is_inline_ast(out[[2L]]))
  expect_equal(out[[2L]]@runs[[1L]]$text, "  ")
})

# ---------------------------------------------------------------------
# col_spec(indent_by = ...) — argument validation
# ---------------------------------------------------------------------

test_that("col_spec(indent_by = '<col>') accepts a single character", {
  cs <- col_spec(indent_by = "depth")
  expect_equal(cs@indent_by, "depth")
})

test_that("col_spec(indent_by = NA) is the no-op default", {
  cs <- col_spec(indent_by = NA_character_)
  expect_true(is.na(cs@indent_by))
})

test_that("col_spec(indent_by = NULL) coerces to NA", {
  cs <- col_spec(indent_by = NULL)
  expect_true(is.na(cs@indent_by))
})

test_that("col_spec(indent_by = '') is rejected (use NA to clear)", {
  expect_error(
    col_spec(indent_by = ""),
    class = "tabular_error_input"
  )
})

test_that("col_spec(indent_by = c('a','b')) is rejected (length must be 1)", {
  expect_error(
    col_spec(indent_by = c("a", "b")),
    class = "tabular_error_input"
  )
})

test_that("col_spec(indent_by = 1L) is rejected (must be character)", {
  expect_error(
    col_spec(indent_by = 1L),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# .resolve_indent_targets — depth column resolution + coercion
# ---------------------------------------------------------------------

mk_indent_call_args <- function(
  data,
  target_col,
  by,
  indent_size = 2L
) {
  cols <- stats::setNames(
    list(
      col_spec(label = "X", indent_by = by),
      col_spec(visible = FALSE)
    ),
    c(target_col, by)
  )
  list(
    cols = cols,
    col_names = names(data),
    data = data,
    nrow_data = nrow(data),
    indent_size = indent_size
  )
}

test_that(".resolve_indent_targets coerces logical depth to integer 0/1", {
  d <- data.frame(x = c("a", "b"), depth = c(TRUE, FALSE))
  args <- mk_indent_call_args(d, "x", "depth")
  out <- do.call(
    tabular:::.resolve_indent_targets,
    c(args, list(call = environment()))
  )
  expect_length(out$targets, 1L)
  expect_equal(out$targets[[1L]]$prefixes, c("  ", ""))
})

test_that(".resolve_indent_targets handles NA depths as 0", {
  d <- data.frame(x = c("a", "b"), depth = c(NA_integer_, 1L))
  args <- mk_indent_call_args(d, "x", "depth")
  out <- do.call(
    tabular:::.resolve_indent_targets,
    c(args, list(call = environment()))
  )
  expect_equal(out$targets[[1L]]$prefixes, c("", "  "))
})

test_that(".resolve_indent_targets clamps negative depths to 0 with a warn", {
  d <- data.frame(x = c("a", "b"), depth = c(-1L, 1L))
  args <- mk_indent_call_args(d, "x", "depth")
  expect_warning(
    out <- do.call(
      tabular:::.resolve_indent_targets,
      c(args, list(call = environment()))
    ),
    "clamped"
  )
  expect_equal(out$targets[[1L]]$prefixes, c("", "  "))
})

test_that(".resolve_indent_targets floors fractional depths with a warn", {
  d <- data.frame(x = c("a", "b", "c"), depth = c(1.5, 2.9, 0.4))
  args <- mk_indent_call_args(d, "x", "depth")
  expect_warning(
    out <- do.call(
      tabular:::.resolve_indent_targets,
      c(args, list(call = environment()))
    ),
    "fractional"
  )
  expect_equal(out$targets[[1L]]$prefixes, c("  ", "    ", ""))
})

test_that(".resolve_indent_targets multi-depth produces N copies of the space unit", {
  # The integer knob is fixed to monospace spaces — non-space prefix
  # markers are no longer expressible. With indent_size = 1L the
  # prefix is one space per depth level.
  d <- data.frame(x = c("a", "b", "c"), depth = c(0L, 1L, 3L))
  args <- mk_indent_call_args(d, "x", "depth", indent_size = 1L)
  out <- do.call(
    tabular:::.resolve_indent_targets,
    c(args, list(call = environment()))
  )
  expect_equal(out$targets[[1L]]$prefixes, c("", " ", "   "))
})

test_that(".resolve_indent_targets errors when indent_by points at a missing column", {
  d <- data.frame(x = c("a", "b"), real_depth = c(0L, 1L))
  args <- mk_indent_call_args(d, "x", "depth") # `depth` not in data
  expect_error(
    do.call(
      tabular:::.resolve_indent_targets,
      c(args, list(call = environment()))
    ),
    class = "tabular_error_input"
  )
})

test_that(".resolve_indent_targets errors on character depth column", {
  d <- data.frame(x = c("a", "b"), depth = c("foo", "bar"))
  args <- mk_indent_call_args(d, "x", "depth")
  expect_error(
    do.call(
      tabular:::.resolve_indent_targets,
      c(args, list(call = environment()))
    ),
    class = "tabular_error_input"
  )
})

test_that(".resolve_indent_targets errors when depth column length != nrow_data", {
  d <- data.frame(x = c("a", "b"), depth = c(0L, 1L))
  args <- mk_indent_call_args(d, "x", "depth")
  # Force a nrow_data mismatch — the engine guards against the
  # depth column not aligning with the cells_text grid.
  args$nrow_data <- 5L
  expect_error(
    do.call(
      tabular:::.resolve_indent_targets,
      c(args, list(call = environment()))
    ),
    class = "tabular_error_input"
  )
})

test_that(".resolve_indent_targets is a no-op when data is NULL", {
  out <- tabular:::.resolve_indent_targets(
    cols = list(),
    col_names = character(0L),
    data = NULL,
    nrow_data = 0L,
    indent_size = 2L,
    call = environment()
  )
  expect_length(out$targets, 0L)
  expect_length(out$hide_cols, 0L)
})

test_that(".resolve_indent_targets auto-hides the depth column", {
  d <- data.frame(x = c("a", "b"), depth = c(0L, 1L))
  spec <- tabular(d) |>
    cols(
      x = col_spec(label = "X", indent_by = "depth"),
      depth = col_spec(visible = TRUE) # user explicitly set TRUE
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # Even though the user said `visible = TRUE` on the depth col,
  # the engine auto-hides it. Justification: the depth col is
  # semantically a controller, not a render target. If a user
  # genuinely wants to debug-render it, they remove the indent_by
  # reference instead.
  expect_false("depth" %in% page1$col_names)
})

# ---------------------------------------------------------------------
# .indent_host_asts_per_row — per-row prefix variant
# ---------------------------------------------------------------------

test_that(".indent_host_asts_per_row applies different prefix per row", {
  asts <- list(
    tabular:::parse_inline("foo"),
    tabular:::parse_inline("bar"),
    tabular:::parse_inline("baz")
  )
  prefixes <- c("", "  ", ">> ")
  out <- tabular:::.indent_host_asts_per_row(asts, prefixes)
  # Row 1 (empty prefix): no leading run added.
  expect_equal(out[[1L]]@runs[[1L]]$text, "foo")
  # Row 2 (two-space prefix): leading plain run.
  expect_equal(out[[2L]]@runs[[1L]]$text, "  ")
  expect_equal(out[[2L]]@runs[[2L]]$text, "bar")
  # Row 3 (custom marker).
  expect_equal(out[[3L]]@runs[[1L]]$text, ">> ")
})

test_that(".indent_host_asts_per_row returns input on length mismatch", {
  asts <- list(tabular:::parse_inline("foo"))
  out <- tabular:::.indent_host_asts_per_row(asts, c("  ", "  "))
  expect_identical(out, asts)
})

test_that(".indent_host_asts_per_row passes through NA / non-character prefix slots", {
  asts <- list(
    tabular:::parse_inline("a"),
    tabular:::parse_inline("b")
  )
  prefixes <- c(NA_character_, "  ")
  out <- tabular:::.indent_host_asts_per_row(asts, prefixes)
  # Row 1 (NA prefix): no prefix run added.
  expect_equal(out[[1L]]@runs[[1L]]$text, "a")
  # Row 2: prefix applied.
  expect_equal(out[[2L]]@runs[[1L]]$text, "  ")
})

test_that(".indent_host_asts_per_row is a no-op on empty input", {
  expect_identical(
    tabular:::.indent_host_asts_per_row(list(), character()),
    list()
  )
})

# ---------------------------------------------------------------------
# Composability — indent_by + group_display = "header_row" + sort_rows
# ---------------------------------------------------------------------

test_that("indent_by composes with sort_rows() — depths follow their rows", {
  df <- data.frame(
    label = c("CARDIAC", "Atrial fib", "GI", "Nausea"),
    depth = c(0L, 1L, 0L, 1L),
    sort_key = c(3L, 1L, 4L, 2L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  # Sort by sort_key ascending. After sort:
  #   Atrial fib (depth 1), Nausea (depth 1), CARDIAC (depth 0), GI (depth 0)
  spec <- tabular(df) |>
    cols(
      label = col_spec(label = "C", indent_by = "depth"),
      depth = col_spec(visible = FALSE),
      sort_key = col_spec(visible = FALSE)
    ) |>
    sort_rows(by = "sort_key")
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # Row 1 post-sort = Atrial fib (depth 1) — indented.
  expect_equal(unname(page1$cells_text[1L, "label"]), "  Atrial fib")
  # Row 3 post-sort = CARDIAC (depth 0) — flush.
  expect_equal(unname(page1$cells_text[3L, "label"]), "CARDIAC")
})

test_that("indent_by composes with group_display='header_row'", {
  spec <- mk_soc_pt_spec()
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # Synthetic SOC headers (flush) + data rows mixed in order.
  # CARDIAC synthetic header appears before CARDIAC SOC data row
  # (both flush), then PTs (indented), then GI synthetic header
  # (flush), then GI data row (flush), then Nausea PT (indented).
  expect_true(any(page1$is_header_row))
  syn_text <- page1$cells_text[page1$is_header_row, "label"]
  expect_true("CARDIAC" %in% syn_text)
  expect_true("GI" %in% syn_text)
})

# ---------------------------------------------------------------------
# Error path coverage
# ---------------------------------------------------------------------

test_that("indent_by referencing a missing column raises a tabular_error_input", {
  df <- data.frame(label = "A", x = 1L, stringsAsFactors = FALSE)
  spec <- tabular(df) |>
    cols(label = col_spec(label = "L", indent_by = "nonexistent"))
  expect_error(as_grid(spec), class = "tabular_error_input")
})

test_that("indent_by referencing a character column raises a tabular_error_input", {
  df <- data.frame(
    label = "A",
    bad_depth = "foo",
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      label = col_spec(label = "L", indent_by = "bad_depth"),
      bad_depth = col_spec(visible = FALSE)
    )
  expect_error(as_grid(spec), class = "tabular_error_input")
})

# ---------------------------------------------------------------------
# Listing without `group_display = "header_row"` — indent_by works
# in a plain flat listing too.
# ---------------------------------------------------------------------

test_that("indent_by works without group_display='header_row' (flat listing)", {
  df <- data.frame(
    usubjid = c("01", "02", "03"),
    aedecod = c("Headache", "Dizziness", "Nausea"),
    depth = c(0L, 1L, 2L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      usubjid = col_spec(label = "USUBJID"),
      aedecod = col_spec(label = "AEDECOD", indent_by = "depth"),
      depth = col_spec(visible = FALSE)
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  expect_false(any(page1$is_header_row))
  expect_equal(
    unname(page1$cells_text[, "aedecod"]),
    c("Headache", "  Dizziness", "    Nausea")
  )
})

# ---------------------------------------------------------------------
# cols() merge propagation — indent_by survives second-call merge
# ---------------------------------------------------------------------

test_that("cols() second-call merge propagates indent_by", {
  df <- data.frame(label = "A", depth = 0L, stringsAsFactors = FALSE)
  spec <- tabular(df) |>
    cols(label = col_spec(label = "Cat")) |>
    cols(label = col_spec(indent_by = "depth"))
  cs <- spec@cols[["label"]]
  expect_equal(cs@label, "Cat")
  expect_equal(cs@indent_by, "depth")
})

test_that("engine_group_display() skips indent when indent_size is non-positive", {
  # Direct call confirms the guard in engine_group_display rejects
  # zero / NA / negative integer values without raising.
  # Row 1: soc="CARDIAC", label="Atrial fib". Row 2: same SOC,
  # label="Tachycardia". Matrix fill is column-major, so the values
  # vector lists col1 (soc) values then col2 (label) values.
  cells_text <- matrix(
    c("CARDIAC", "CARDIAC", "Atrial fib", "Tachycardia"),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cells_ast <- matrix(
    list(
      tabular:::parse_inline("CARDIAC"),
      tabular:::parse_inline("CARDIAC"),
      tabular:::parse_inline("Atrial fib"),
      tabular:::parse_inline("Tachycardia")
    ),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cells_style <- matrix(
    list(style_node(), style_node(), style_node(), style_node()),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(NULL, c("soc", "label"))
  )
  cols <- list(
    soc = col_spec(usage = "group", group_display = "header_row"),
    label = col_spec(label = "Category")
  )
  # Zero indent — text passes through verbatim, no leading whitespace.
  out_zero <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_size = 0L
  )
  expect_identical(
    unname(out_zero$cells_text[, "label"]),
    c("Atrial fib", "Tachycardia")
  )
  # NA indent — same passthrough.
  out_na <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_size = NA_integer_
  )
  expect_identical(
    unname(out_na$cells_text[, "label"]),
    c("Atrial fib", "Tachycardia")
  )
  # Negative indent — same passthrough.
  out_neg <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = cols,
    indent_size = -1L
  )
  expect_identical(
    unname(out_neg$cells_text[, "label"]),
    c("Atrial fib", "Tachycardia")
  )
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
    indent_size = 2L
  )
  expect_null(out$header_row_plan)
  expect_identical(dim(out$cells_text), c(0L, 0L))
})

test_that("engine_group_display() short-circuits when no group columns are declared", {
  cells_text <- matrix(
    c("a", "b"),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  cells_ast <- matrix(
    list(tabular:::parse_inline("a"), tabular:::parse_inline("b")),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  cells_style <- matrix(
    list(style_node(), style_node()),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  out <- tabular:::engine_group_display(
    cells_text = cells_text,
    cells_ast = cells_ast,
    cells_style = cells_style,
    cols = list(x = col_spec(label = "X")),
    indent_size = 2L
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
    nrow = 3L,
    ncol = 2L,
    dimnames = list(NULL, c("g", "v"))
  )
  cells_ast <- matrix(
    list(
      tabular:::parse_inline("A"),
      tabular:::parse_inline("A"),
      tabular:::parse_inline("B"),
      tabular:::parse_inline("x"),
      tabular:::parse_inline("y"),
      tabular:::parse_inline("z")
    ),
    nrow = 3L,
    ncol = 2L,
    dimnames = list(NULL, c("g", "v"))
  )
  cells_style <- matrix(
    rep(list(style_node()), 6L),
    nrow = 3L,
    ncol = 2L,
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
    indent_size = 2L
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
  ast <- matrix(
    list(tabular:::parse_inline("a")),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
  st <- matrix(
    list(style_node()),
    nrow = 1L,
    ncol = 1L,
    dimnames = list(NULL, "x")
  )
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
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "v")
  )
  ast <- matrix(
    list(tabular:::parse_inline("A"), tabular:::parse_inline("B")),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "v")
  )
  st <- matrix(
    list(style_node(), style_node()),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "v")
  )
  plan <- list(
    bands = list(
      list(
        group_col = "g",
        group_values = c("A", "B"),
        group_asts = list(
          tabular:::parse_inline("A"),
          tabular:::parse_inline("B")
        ),
        transitions = c(1L, 2L),
        depth = 0L
      )
    ),
    host_col = "ghost", # not in visible_col_names
    data_depth = 1L
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
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "soc")
  )
  cells_ast <- matrix(
    list(tabular:::parse_inline("A"), tabular:::parse_inline("B")),
    nrow = 2L,
    ncol = 1L,
    dimnames = list(NULL, "soc")
  )
  cells_style <- matrix(
    list(style_node(), style_node()),
    nrow = 2L,
    ncol = 1L,
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
    indent_size = 2L
  )
  expect_true(is.na(out$header_row_plan$host_col))
  # Text passes through untouched (no host column to prefix).
  expect_identical(unname(out$cells_text[, "soc"]), c("A", "B"))
})

# ---------------------------------------------------------------------
# `usage = "indent"` engine phase — fixed depth-1 prefix
# ---------------------------------------------------------------------

mk_indent_usage_spec <- function(indent_size = 2L, with_indent_by = FALSE) {
  df <- data.frame(
    group_label = c("A", "A", "B", "B"),
    stat_label = c("x1", "x2", "y1", "y2"),
    depth = c(0L, 1L, 0L, 2L),
    placebo = c("1", "2", "3", "4"),
    stringsAsFactors = FALSE
  )
  stat_spec <- if (with_indent_by) {
    col_spec(usage = "indent", label = "Stat", indent_by = "depth")
  } else {
    col_spec(usage = "indent", label = "Stat")
  }
  spec <- tabular(df, titles = "T", footnotes = "") |>
    cols(
      group_label = col_spec(usage = "group", group_display = "header_row"),
      stat_label = stat_spec,
      depth = col_spec(visible = FALSE),
      placebo = col_spec(label = "Placebo")
    )
  preset(spec, indent_size = indent_size)
}

test_that("usage='indent' prefixes every body cell of the column with one indent level", {
  g <- as_grid(mk_indent_usage_spec())
  page1 <- g@pages[[1L]]
  body <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "stat_label"
  ]
  # Every body row gets the 2-space prefix.
  expect_true(all(startsWith(body, "  ")))
})

test_that("usage='indent' is additive with indent_by (depth_by + 1 per row)", {
  g <- as_grid(mk_indent_usage_spec(indent_size = 2L, with_indent_by = TRUE))
  page1 <- g@pages[[1L]]
  body_rows <- which(!page1$is_header_row & !page1$is_blank_row)
  body <- page1$cells_text[body_rows, "stat_label"]
  # depths c(0, 1, 0, 2) + 1 -> c(1, 2, 1, 3) levels of 2 spaces each.
  expected_lead <- c(2L, 4L, 2L, 6L)
  observed_lead <- nchar(body) - nchar(sub("^ +", "", body))
  expect_identical(observed_lead, expected_lead)
})

test_that("usage='indent' synthetic header rows are NOT indented", {
  g <- as_grid(mk_indent_usage_spec())
  page1 <- g@pages[[1L]]
  header_rows <- which(page1$is_header_row)
  expect_true(length(header_rows) >= 1L)
  for (i in header_rows) {
    # Walk the visible columns; the header host cell carries the
    # group_label text verbatim with no leading-space prefix.
    for (nm in colnames(page1$cells_text)) {
      cell <- page1$cells_text[i, nm]
      if (nzchar(cell)) {
        expect_false(
          startsWith(cell, " "),
          info = sprintf("header row %d col %s", i, nm)
        )
      }
    }
  }
})

test_that("usage='indent' prefix lands on cells_ast as a leading plain run", {
  g <- as_grid(mk_indent_usage_spec())
  page1 <- g@pages[[1L]]
  body_idx <- which(!page1$is_header_row & !page1$is_blank_row)[[1L]]
  ast <- page1$cells_ast[[body_idx, "stat_label"]]
  expect_true(tabular::is_inline_ast(ast))
  expect_equal(ast@runs[[1L]]$type, "plain")
  expect_equal(ast@runs[[1L]]$text, "  ")
})

test_that("usage='indent' with indent_size = 0L is a no-op", {
  g <- as_grid(mk_indent_usage_spec(indent_size = 0L))
  page1 <- g@pages[[1L]]
  body <- page1$cells_text[
    !page1$is_header_row & !page1$is_blank_row,
    "stat_label"
  ]
  expect_true(all(!startsWith(body, " ")))
})

test_that(".indent_usage_columns picks every usage='indent' column in declaration order", {
  cols <- list(
    a = col_spec(usage = "display"),
    b = col_spec(usage = "indent"),
    c = col_spec(usage = "group"),
    d = col_spec(usage = "indent")
  )
  expect_identical(
    tabular:::.indent_usage_columns(cols, c("a", "b", "c", "d")),
    c("b", "d")
  )
})

# ---------------------------------------------------------------------
# Change D: multi-level `usage = "group" + group_display = "header_row"`
# auto-indent. Outer band at depth 0, inner band at depth 1, etc. Body
# rows under N bands get N levels added to cells_indent[, host_col]
# UNLESS the host column declares `indent_by` (saf_aesocpt regression).
# ---------------------------------------------------------------------

mk_nested_band_spec <- function(host_indent_by = FALSE) {
  df <- data.frame(
    section = c(
      "Safety",
      "Safety",
      "Safety",
      "Safety",
      "Efficacy",
      "Efficacy"
    ),
    subsection = c(
      "AE Overall",
      "AE Overall",
      "AE by SOC",
      "AE by SOC",
      "ORR",
      "ORR"
    ),
    label = c(
      "Any TEAE",
      "Serious TEAE",
      "Cardiac",
      "GI",
      "Confirmed",
      "Unconfirmed"
    ),
    indent_lv = c(0L, 0L, 0L, 0L, 0L, 0L),
    n = c("100", "10", "5", "8", "20", "15"),
    stringsAsFactors = FALSE
  )
  label_spec <- if (host_indent_by) {
    col_spec(label = "Item", indent_by = "indent_lv")
  } else {
    col_spec(label = "Item")
  }
  tabular(df, titles = "Nested") |>
    cols(
      section = col_spec(usage = "group", group_display = "header_row"),
      subsection = col_spec(usage = "group", group_display = "header_row"),
      label = label_spec,
      indent_lv = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
}

test_that("nested header_row bands: header_row_plan$bands has correct depth + transitions", {
  g <- as_grid(mk_nested_band_spec())
  plan <- g@metadata$header_row_plan
  # When user-facing `as_grid` doesn't surface header_row_plan we read
  # off the engine directly via a fixture call (cleaner: introspect
  # the page).
  p1 <- g@pages[[1L]]
  # Two header_row cols -> two bands.
  expect_true(any(p1$is_header_row))
  # Count band-1 rows (depth 0 on host_col) vs band-2 rows (depth 1).
  host_idx <- match("label", p1$col_names)
  header_idx <- which(p1$is_header_row)
  depths <- vapply(
    header_idx,
    function(i) p1$cells_indent[i, host_idx],
    integer(1L)
  )
  # Section "Safety" emits both band-1 (Safety) and band-2 (AE Overall)
  # on the first row; band-2 "AE by SOC" re-emits at row 3; section
  # "Efficacy" emits both band-1 + band-2 again at row 5.
  # Expect at least one depth-0 header and one depth-1 header.
  expect_true(any(depths == 0L))
  expect_true(any(depths == 1L))
})

test_that("nested bands: body rows get cells_indent = N when host has no indent_by", {
  g <- as_grid(mk_nested_band_spec(host_indent_by = FALSE))
  p1 <- g@pages[[1L]]
  host_idx <- match("label", p1$col_names)
  body_idx <- which(!p1$is_header_row & !p1$is_blank_row)
  body_depths <- vapply(
    body_idx,
    function(i) p1$cells_indent[i, host_idx],
    integer(1L)
  )
  # data_depth = length(bands) = 2; no indent_by on host -> body
  # rows carry exactly 2 levels of indent.
  expect_true(all(body_depths == 2L))
})

test_that("nested bands: indent_by on host SUPPRESSES data_depth (saf_aesocpt invariant)", {
  g <- as_grid(mk_nested_band_spec(host_indent_by = TRUE))
  p1 <- g@pages[[1L]]
  host_idx <- match("label", p1$col_names)
  body_idx <- which(!p1$is_header_row & !p1$is_blank_row)
  body_depths <- vapply(
    body_idx,
    function(i) p1$cells_indent[i, host_idx],
    integer(1L)
  )
  # indent_lv is 0L on every body row, so cells_indent is 0L on every
  # body row -- data_depth (2) suppressed because host declares
  # indent_by. saf_aesocpt's depth-0 SOC + depth-1 PT pattern works
  # the same way: indent_by wins.
  expect_true(all(body_depths == 0L))
})

test_that("nested bands inject in OUTER->INNER order at stacked transitions", {
  g <- as_grid(mk_nested_band_spec())
  p1 <- g@pages[[1L]]
  host_idx <- match("label", p1$col_names)
  # First two rows of the page are both header rows (band 1 -> band 2)
  # at the page start, because section AND subsection both transition
  # at row 1.
  expect_true(p1$is_header_row[[1L]])
  expect_true(p1$is_header_row[[2L]])
  # Band 1 (outer) is depth 0; band 2 (inner) is depth 1. Outer
  # emits first. Matrix subset carries a dimname attribute; unname
  # for identical().
  expect_identical(unname(p1$cells_indent[1L, host_idx]), 0L)
  expect_identical(unname(p1$cells_indent[2L, host_idx]), 1L)
  # Outer band carries "Safety"; inner carries "AE Overall".
  expect_match(unname(p1$cells_text[1L, host_idx]), "Safety", fixed = TRUE)
  expect_match(
    unname(p1$cells_text[2L, host_idx]),
    "AE Overall",
    fixed = TRUE
  )
})

test_that(".header_row_columns returns ordered header_row group cols", {
  cols <- list(
    a = col_spec(usage = "display"),
    b = col_spec(usage = "group", group_display = "column"),
    c = col_spec(usage = "group", group_display = "header_row"),
    d = col_spec(usage = "group", group_display = "header_row"),
    e = col_spec(usage = "display")
  )
  group_names <- c("b", "c", "d")
  expect_identical(
    tabular:::.header_row_columns(cols, group_names),
    c("c", "d")
  )
})
