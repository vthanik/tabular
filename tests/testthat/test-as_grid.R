# as_grid() — engine pipeline composition + per-page slicing.

# ---------------------------------------------------------------------
# Public predicate / shape
# ---------------------------------------------------------------------

test_that("as_grid() rejects non-spec input", {
  expect_error(
    as_grid(1L),
    class = "tabular_error_input"
  )
})

test_that("as_grid() returns a tabular_grid", {
  spec <- tabular(data.frame(x = 1:3))
  g <- as_grid(spec)
  expect_true(is_tabular_grid(g))
})

test_that("as_grid() metadata carries spec shape", {
  spec <- tabular(
    data.frame(x = 1:3, y = letters[1:3]),
    titles = c("Title A", "Title B"),
    footnotes = "Foot 1"
  )
  g <- as_grid(spec)
  meta <- g@metadata
  expect_identical(meta$format, NA_character_)
  expect_identical(meta$nrow_data, 3L)
  expect_identical(meta$ncol_data, 2L)
  expect_identical(meta$col_names, c("x", "y"))
  expect_identical(meta$titles, c("Title A", "Title B"))
  expect_identical(meta$footnotes, "Foot 1")
  expect_length(meta$titles_ast, 2L)
  expect_length(meta$footnotes_ast, 1L)
  expect_named(meta$col_labels_ast, c("x", "y"))
})

test_that("as_grid() leaves pagehead_ast / pagefoot_ast NULL when preset omits them", {
  spec <- tabular(data.frame(x = 1:3))
  g <- as_grid(spec)
  expect_null(g@metadata$pagehead_ast)
  expect_null(g@metadata$pagefoot_ast)
})

test_that("as_grid() populates pagehead_ast for single-row pagehead", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      )
    )
  g <- as_grid(spec)
  band <- g@metadata$pagehead_ast
  expect_true(is.list(band))
  expect_named(band, c("left", "center", "right"))
  expect_length(band$left, 1L)
  expect_true(is_inline_ast(band$left[[1L]]))
  expect_true(is_inline_ast(band$right[[1L]]))
})

test_that("as_grid() populates pagefoot_ast multi-row with index 1 at body edge", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(
        left = c("Body edge row", "Far from body row"),
        right = "{datetime}"
      )
    )
  g <- as_grid(spec)
  band <- g@metadata$pagefoot_ast
  expect_length(band$left, 2L)
  expect_length(band$right, 2L)
  # Index 1 has user content; index 2 of right is padding (empty AST)
  expect_gt(length(band$left[[1L]]@runs), 0L)
  expect_gt(length(band$left[[2L]]@runs), 0L)
  expect_gt(length(band$right[[1L]]@runs), 0L)
  expect_length(band$right[[2L]]@runs, 0L)
})

test_that("as_grid() honours session-default pagehead via cascade", {
  withr::defer(set_preset(reset = TRUE))
  set_preset(pagehead = list(left = "Session protocol"))
  spec <- tabular(data.frame(x = 1:3)) # no per-spec preset
  g <- as_grid(spec)
  expect_false(is.null(g@metadata$pagehead_ast))
  expect_length(g@metadata$pagehead_ast$left, 1L)
})

# ---------------------------------------------------------------------
# Page descriptors
# ---------------------------------------------------------------------

test_that("as_grid() one-page default carries full data slice", {
  spec <- tabular(data.frame(x = 1:3, y = letters[1:3]))
  g <- as_grid(spec)
  expect_length(g@pages, 1L)
  p <- g@pages[[1L]]
  expect_identical(p$page_index, 1L)
  expect_identical(p$panel_index, 1L)
  expect_false(p$is_continuation)
  expect_identical(dim(p$cells_text), c(3L, 2L))
  expect_identical(dim(p$cells_ast), c(3L, 2L))
  expect_identical(dim(p$cells_style), c(3L, 2L))
  expect_identical(p$col_names, c("x", "y"))
  expect_named(p$col_labels_ast, c("x", "y"))
})

test_that("as_grid() honours sort_rows() before formatting", {
  d <- data.frame(x = c(3L, 1L, 2L), y = c("c", "a", "b"))
  spec <- tabular(d) |> sort_rows("x")
  g <- as_grid(spec)
  expect_identical(g@pages[[1L]]$cells_text[, "x"], c("1", "2", "3"))
})

test_that("as_grid() materialises derives", {
  d <- data.frame(a = c(1, 2, 3), b = c(10, 20, 30))
  spec <- tabular(d) |> derive(sum = a + b)
  g <- as_grid(spec)
  expect_identical(g@metadata$col_names, c("a", "b", "sum"))
  expect_identical(g@pages[[1L]]$cells_text[, "sum"], c("11", "22", "33"))
})

test_that("as_grid() applies col_spec decimal alignment", {
  d <- data.frame(x = c("1.5", "10.25", "100.125"))
  spec <- tabular(d) |> cols(x = col_spec(align = "decimal"))
  g <- as_grid(spec)
  out <- g@pages[[1L]]$cells_text[, "x"]
  # Every cell must end at the same column position after alignment.
  widths <- nchar(out, type = "chars")
  expect_true(length(unique(widths)) == 1L)
})

test_that("as_grid() returns empty list-matrices for zero-row data", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  g <- as_grid(spec)
  p <- g@pages[[1L]]
  expect_identical(nrow(p$cells_text), 0L)
  expect_identical(nrow(p$cells_ast), 0L)
  expect_identical(nrow(p$cells_style), 0L)
  expect_identical(p$col_names, c("x", "y"))
})

# ---------------------------------------------------------------------
# Headers + style trace into metadata
# ---------------------------------------------------------------------

test_that("as_grid() carries the resolved header band grid in metadata", {
  d <- data.frame(
    grp = letters[1:3],
    placebo = c(1, 2, 3),
    active = c(4, 5, 6)
  )
  spec <- tabular(d) |>
    headers("Treatment" = c("placebo", "active"))
  g <- as_grid(spec)
  hdrs <- g@metadata$headers
  expect_s3_class(hdrs, "data.frame")
  expect_true("Treatment" %in% hdrs$label)
})

test_that("as_grid() emits a populated style grid when a predicate fires", {
  d <- data.frame(x = c(1L, 2L, 3L), y = c(10L, 20L, 30L))
  spec <- tabular(d) |> style(where = x > 1, bold = TRUE)
  g <- as_grid(spec)
  styles <- g@pages[[1L]]$cells_style
  expect_true(isTRUE(styles[[2L, 1L]]@bold))
  expect_true(isTRUE(styles[[3L, 1L]]@bold))
  expect_true(is.na(styles[[1L, 1L]]@bold))
})

# ---------------------------------------------------------------------
# Pagination splits pages and slices matrices accordingly
# ---------------------------------------------------------------------

test_that("as_grid() splits across pages when pagination forces it", {
  # Use a tiny font + many rows to force the engine to chunk.
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L, paper_size = "letter", orientation = "portrait")
  g <- as_grid(spec)
  expect_gt(g@metadata$total_pages, 1L)
  # Concatenating every page's row indices must reconstruct seq_len(24).
  all_rows <- unlist(lapply(g@pages, function(p) p$row_indices))
  expect_setequal(all_rows, seq_len(24L))
})
