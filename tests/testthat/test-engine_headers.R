# engine_headers() — flattens the header tree to a band-grid
# data.frame. Validates contiguity and computes per-node (col_start,
# col_end) positions for backends.

# ---- empty tree -----------------------------------------------------

test_that("engine_headers() returns an empty schema when no headers set", {
  spec <- tabular(saf_demo)
  out <- tabular:::engine_headers(spec)
  expect_s3_class(out, "data.frame")
  expect_named(
    out,
    c("depth", "label", "col_start", "col_end", "leaf", "span_cols")
  )
  expect_equal(nrow(out), 0L)
})

# ---- flat one-band tree --------------------------------------------

test_that("engine_headers() flattens a single flat band", {
  spec <- tabular(saf_demo) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100", "Total"))
  out <- tabular:::engine_headers(spec)
  expect_equal(nrow(out), 1L)
  expect_equal(out$depth, 1L)
  expect_equal(out$label, "Arms")
  # saf_demo column order: variable, stat_label, placebo, drug_100, drug_50, Total
  # placebo at 3, drug_100 at 4, drug_50 at 5, Total at 6 -- but our span lists
  # them in declaration order which doesn't have to be data order. After sort,
  # positions are 3..6 contiguous.
  expect_equal(out$col_start, 3L)
  expect_equal(out$col_end, 6L)
  expect_true(out$leaf)
})

# ---- nested tree, depth ordering -----------------------------------

test_that("engine_headers() rows are ordered by depth then col_start", {
  spec <- tabular(saf_demo) |>
    headers(
      "Treatment Group" = list(
        "Control" = "placebo",
        "Active" = c("drug_100", "drug_50", "Total")
      )
    )
  out <- tabular:::engine_headers(spec)
  expect_equal(nrow(out), 3L)
  expect_equal(out$depth, c(1L, 2L, 2L))
  expect_equal(out$label, c("Treatment Group", "Control", "Active"))
  expect_equal(out$leaf, c(FALSE, TRUE, TRUE))
  expect_equal(out$col_start[[1]], 3L)
  expect_equal(out$col_end[[1]], 6L)
})

# ---- non-contiguous span: error ------------------------------------

test_that("engine_headers() errors when a band's leaves are non-contiguous", {
  # saf_demo column order: variable, stat_label, placebo, drug_100, drug_50, Total
  # Spanning c("placebo", "Total") leaves drug_100 and drug_50 between them.
  spec <- tabular(saf_demo) |>
    headers("Bad" = c("placebo", "Total"))
  expect_error(
    tabular:::engine_headers(spec),
    class = "tabular_error_input"
  )
})

test_that("engine_headers() error names the intruder column", {
  spec <- tabular(saf_demo) |>
    headers("Bad" = c("placebo", "Total"))
  err <- tryCatch(
    tabular:::engine_headers(spec),
    tabular_error_input = function(e) e
  )
  msg <- conditionMessage(err)
  expect_true(grepl("drug_100", msg) || grepl("drug_50", msg))
})

# ---- arbitrary nesting depth ---------------------------------------

test_that("engine_headers() preserves depth across arbitrary nesting", {
  spec <- tabular(saf_demo) |>
    headers(
      "L1" = list(
        "L2" = list(
          "L3" = list(
            "L4" = c("placebo", "drug_100", "drug_50", "Total")
          )
        )
      )
    )
  out <- tabular:::engine_headers(spec)
  expect_equal(nrow(out), 4L)
  expect_equal(out$depth, 1:4)
  expect_equal(out$label, c("L1", "L2", "L3", "L4"))
  expect_equal(out$leaf, c(FALSE, FALSE, FALSE, TRUE))
})

# ---- two top-level bands at depth 1 --------------------------------

test_that("engine_headers() handles two top-level bands at same depth", {
  spec <- tabular(saf_demo) |>
    headers(
      "Left" = c("variable", "stat_label"),
      "Right" = c("placebo", "drug_100", "drug_50", "Total")
    )
  out <- tabular:::engine_headers(spec)
  expect_equal(nrow(out), 2L)
  expect_equal(out$depth, c(1L, 1L))
  expect_equal(out$label, c("Left", "Right"))
  expect_equal(out$col_start, c(1L, 3L))
  expect_equal(out$col_end, c(2L, 6L))
})

# ---- span_cols preserved -------------------------------------------

test_that("engine_headers() preserves the spanned column names", {
  spec <- tabular(saf_demo) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100", "Total"))
  out <- tabular:::engine_headers(spec)
  expect_identical(
    out$span_cols[[1]],
    c("placebo", "drug_50", "drug_100", "Total")
  )
})

# ---- snapshot for engine error message coherence -------------------

# ---- passthrough leaves in the flattened output --------------------

test_that("engine_headers() emits NA label for a passthrough leaf", {
  # saf_demo column order: variable, stat_label, placebo, drug_100, drug_50, Total
  spec <- tabular(saf_demo) |>
    headers(
      "Top" = list(
        "Inner" = c("placebo", "drug_100"),
        "drug_50"
      )
    )
  out <- tabular:::engine_headers(spec)
  # 3 rows: Top (depth 1), Inner (depth 2), passthrough (depth 2 NA)
  expect_equal(nrow(out), 3L)
  expect_equal(out$depth, c(1L, 2L, 2L))
  expect_identical(out$label, c("Top", "Inner", NA_character_))
  # Passthrough leaf at "drug_50" position 5
  passthrough <- out[is.na(out$label), ]
  expect_equal(passthrough$col_start, 5L)
  expect_equal(passthrough$col_end, 5L)
  expect_true(passthrough$leaf)
})

test_that("engine_headers() error snapshot", {
  spec <- tabular(saf_demo) |>
    headers("Bad" = c("placebo", "Total"))
  expect_snapshot(error = TRUE, tabular:::engine_headers(spec))
})
