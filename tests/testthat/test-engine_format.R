# engine_format() — per-column format application, NA
# substitution, and inline_ast parsing across cells / titles /
# footnotes / col labels.

# ---------------------------------------------------------------------
# Cells: format application
# ---------------------------------------------------------------------

test_that("engine_format() applies sprintf templates to numeric columns", {
  d <- data.frame(x = c(1.234, 5.6789, 10.0))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.2f"))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("1.23", "5.68", "10.00"))
})

test_that("engine_format() applies unary functions column-wide", {
  d <- data.frame(x = c(1.5, 2.5, 3.5))
  spec <- tabular(d) |>
    cols(x = col_spec(format = function(v) sprintf("%.1f%%", v * 100)))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("150.0%", "250.0%", "350.0%"))
})

test_that("engine_format() falls back to as.character when format is NULL", {
  d <- data.frame(x = c(1L, 2L, 3L))
  spec <- tabular(d)
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("1", "2", "3"))
})

test_that("engine_format() preserves character columns without modification", {
  d <- data.frame(lab = c("A", "B", "C"), stringsAsFactors = FALSE)
  spec <- tabular(d)
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "lab"], c("A", "B", "C"))
})

# ---------------------------------------------------------------------
# Cells: NA substitution
# ---------------------------------------------------------------------

test_that("engine_format() substitutes NA cells with col_spec@na_text", {
  d <- data.frame(x = c(1.5, NA_real_, 3.5))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.1f", na_text = "-"))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("1.5", "-", "3.5"))
})

test_that("engine_format() defaults NA substitution to empty string", {
  d <- data.frame(x = c(1.5, NA_real_, 3.5))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.1f"))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("1.5", "", "3.5"))
})

test_that("engine_format() handles all-NA columns by filling with na_text only", {
  d <- data.frame(x = c(NA_real_, NA_real_))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.1f", na_text = "NR"))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("NR", "NR"))
})

test_that("engine_format() skips format application entirely when every cell is NA", {
  # If sprintf saw NA it would emit "NA"; the engine avoids that by
  # substituting na_text BEFORE format runs. Here the format would
  # error if applied because the user passed a numeric template to
  # a character column, but since every cell is NA the format step
  # never runs.
  d <- data.frame(x = c(NA_real_, NA_real_))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.0d", na_text = "-"))
  out <- tabular:::engine_format(spec)
  expect_equal(out$cells_text[, "x"], c("-", "-"))
})

# ---------------------------------------------------------------------
# Cells: error paths
# ---------------------------------------------------------------------

test_that("engine_format() surfaces sprintf failures as tabular_error_runtime", {
  # Numeric template applied to a character column triggers a
  # sprintf warning / error. Coerced to tabular_error_runtime with
  # the offending column name.
  d <- data.frame(x = c("alpha", "beta"))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.2f"))
  expect_error(
    tabular:::engine_format(spec),
    class = "tabular_error_runtime"
  )
})

test_that("engine_format() raises tabular_error_runtime when format fn errors", {
  d <- data.frame(x = c(1, 2, 3))
  spec <- tabular(d) |>
    cols(
      x = col_spec(format = function(v) stop("intentional"))
    )
  expect_error(
    tabular:::engine_format(spec),
    class = "tabular_error_runtime"
  )
})

test_that("engine_format() raises tabular_error_runtime when format fn returns wrong length", {
  d <- data.frame(x = c(1, 2, 3))
  spec <- tabular(d) |>
    cols(
      x = col_spec(format = function(v) c("only one"))
    )
  expect_error(
    tabular:::engine_format(spec),
    class = "tabular_error_runtime"
  )
})

# ---------------------------------------------------------------------
# Cells: AST production
# ---------------------------------------------------------------------

test_that("engine_format() returns an inline_ast for every cell", {
  d <- data.frame(x = c(1.5, 2.5))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.1f"))
  out <- tabular:::engine_format(spec)
  expect_equal(dim(out$cells_ast), c(2L, 1L))
  for (i in seq_len(2L)) {
    expect_true(is_inline_ast(out$cells_ast[[i, 1L]]))
  }
})

test_that("engine_format() preserves cells_text and cells_ast dimnames", {
  d <- data.frame(x = c(1, 2), y = c("a", "b"))
  spec <- tabular(d)
  out <- tabular:::engine_format(spec)
  expect_equal(colnames(out$cells_text), c("x", "y"))
  expect_equal(colnames(out$cells_ast), c("x", "y"))
})

test_that("engine_format() handles zero-row data", {
  d <- data.frame(x = numeric(), y = character())
  spec <- tabular(d)
  out <- tabular:::engine_format(spec)
  expect_equal(nrow(out$cells_text), 0L)
  expect_equal(ncol(out$cells_text), 2L)
  expect_equal(dim(out$cells_ast), c(0L, 2L))
})

# ---------------------------------------------------------------------
# Titles + footnotes
# ---------------------------------------------------------------------

test_that("engine_format() parses every title line through parse_inline", {
  spec <- tabular(
    data.frame(x = 1),
    titles = c("Table 1", md("**Bold title**"), html("<i>Italic</i>"))
  )
  out <- tabular:::engine_format(spec)
  expect_length(out$titles_ast, 3L)
  for (ast in out$titles_ast) {
    expect_true(is_inline_ast(ast))
  }
  # Second title was wrapped in md("**...**") -> bold run.
  expect_equal(out$titles_ast[[2L]]@runs[[1L]]$type, "bold")
  # Third was wrapped in html("<i>...</i>") -> italic run.
  expect_equal(out$titles_ast[[3L]]@runs[[1L]]$type, "italic")
})

test_that("engine_format() parses every footnote line through parse_inline", {
  spec <- tabular(
    data.frame(x = 1),
    footnotes = c(
      "Plain footnote.",
      md("^a^ Footnote with superscript marker.")
    )
  )
  out <- tabular:::engine_format(spec)
  expect_length(out$footnotes_ast, 2L)
  # Second footnote has a Pandoc-style ^sup^ marker -> sup run.
  types <- vapply(
    out$footnotes_ast[[2L]]@runs,
    function(r) r$type,
    character(1L)
  )
  expect_true("sup" %in% types)
})

test_that("engine_format() returns empty title / footnote lists when none set", {
  spec <- tabular(data.frame(x = 1))
  out <- tabular:::engine_format(spec)
  expect_length(out$titles_ast, 0L)
  expect_length(out$footnotes_ast, 0L)
})

# ---------------------------------------------------------------------
# Column labels
# ---------------------------------------------------------------------

test_that("engine_format() builds a col_labels_ast keyed by column name", {
  d <- data.frame(placebo = 1, drug_100 = 2)
  spec <- tabular(d) |>
    cols(
      placebo = col_spec(label = "Placebo\nN=86"),
      drug_100 = col_spec(label = md("**Drug 100**"))
    )
  out <- tabular:::engine_format(spec)
  expect_equal(names(out$col_labels_ast), c("placebo", "drug_100"))
  expect_true(is_inline_ast(out$col_labels_ast$placebo))
  # drug_100 label was md()-wrapped; AST starts with a bold run.
  expect_equal(out$col_labels_ast$drug_100@runs[[1L]]$type, "bold")
})

test_that("engine_format() falls back to column name when col_spec@label is NA", {
  d <- data.frame(x = c(1, 2), y = c("a", "b"))
  # No cols() call -> implicit default col_spec with NA label.
  spec <- tabular(d)
  out <- tabular:::engine_format(spec)
  # AST first-run text is the column name.
  expect_equal(out$col_labels_ast$x@runs[[1L]]$text, "x")
  expect_equal(out$col_labels_ast$y@runs[[1L]]$text, "y")
})

test_that("engine_format() stamps the data column name on each col_spec", {
  # col_spec() leaves name = NA_character_; engine_format must
  # populate it so error messages can reference the offending col.
  d <- data.frame(x = c("alpha", "beta"))
  spec <- tabular(d) |>
    cols(x = col_spec(format = "%.2f"))
  # Trigger an error to confirm the message mentions the column.
  err <- tryCatch(tabular:::engine_format(spec), error = function(e) e)
  expect_s3_class(err, "tabular_error_runtime")
  expect_match(conditionMessage(err), "x")
})

# ---------------------------------------------------------------------
# Integration: cdisc_saf_demo end-to-end
# ---------------------------------------------------------------------

test_that("engine_format() handles the bundled cdisc_saf_demo without erroring", {
  spec <- tabular(
    cdisc_saf_demo,
    titles = c("Table 14.1", md("**Demographics**")),
    footnotes = c("Note: percentages by arm.")
  ) |>
    cols(
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_100 = col_spec(label = "Drug 100\nN=72")
    )
  out <- tabular:::engine_format(spec)
  expect_equal(
    dim(out$cells_text),
    c(nrow(cdisc_saf_demo), ncol(cdisc_saf_demo))
  )
  expect_length(out$titles_ast, 2L)
  expect_length(out$footnotes_ast, 1L)
  expect_equal(names(out$col_labels_ast), names(cdisc_saf_demo))
})

test_that("engine_format() output composes with engine_decimal()", {
  # The natural pipeline: engine_format gives cells_text, then
  # engine_decimal aligns decimal-marked columns.
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      placebo = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal")
    )
  out <- tabular:::engine_format(spec)
  aligned <- tabular:::engine_decimal(
    out$cells_text,
    spec@cols,
    sections = cdisc_saf_demo$variable
  )
  # Decimal-aligned columns rewritten; others passed through.
  expect_false(identical(aligned[, "placebo"], out$cells_text[, "placebo"]))
  expect_identical(aligned[, "variable"], out$cells_text[, "variable"])
})

# ---- preset(na_text=) fallback (#na-text) -------------------------------

test_that("preset(na_text=) fills NA cells when col_spec omits na_text (#na-text)", {
  d <- data.frame(x = c("a", NA), y = c(NA, "b"), stringsAsFactors = FALSE)
  spec <- tabular(d) |>
    cols(x = col_spec(), y = col_spec(na_text = "--")) |>
    preset(na_text = "MISSING")
  g <- as_grid(spec)@pages[[1L]]
  # x has no per-column na_text -> the preset default fills the NA cell.
  expect_true(g$cells_text[2L, "x"] == "MISSING")
  # y sets na_text explicitly -> the per-column value wins over the preset.
  expect_true(g$cells_text[1L, "y"] == "--")
})

test_that("preset(na_text=) renders on every backend (#na-text)", {
  d <- data.frame(x = c("a", NA), stringsAsFactors = FALSE)
  spec <- tabular(d) |> cols(x = col_spec()) |> preset(na_text = "MISSING")
  for (ext in c("html", "tex", "rtf")) {
    f <- withr::local_tempfile(fileext = paste0(".", ext))
    emit(spec, f)
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_true(grepl("MISSING", txt, fixed = TRUE), label = ext)
  }
})
