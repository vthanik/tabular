# sort_rows() — verb that attaches a sort_spec to a tabular_spec.
# Covers all 8 plan edge cases (plus argument-shape errors).

# ---- happy path ------------------------------------------------------

test_that("sort_rows() stores a sort_spec on the spec", {
  spec <- tabular(cdisc_saf_demo) |>
    sort_rows(by = c("variable", "stat_label"))

  expect_true(is_sort_spec(spec@sort))
  expect_identical(spec@sort@by, c("variable", "stat_label"))
  expect_identical(spec@sort@descending, c(FALSE, FALSE))
})

test_that("sort_rows() recycles length-1 descending across keys", {
  spec <- tabular(cdisc_saf_demo) |>
    sort_rows(by = c("variable", "stat_label"), descending = TRUE)

  expect_identical(spec@sort@descending, c(TRUE, TRUE))
})

test_that("sort_rows() accepts per-key descending vector", {
  spec <- tabular(cdisc_saf_demo) |>
    sort_rows(
      by = c("variable", "stat_label"),
      descending = c(TRUE, FALSE)
    )
  expect_identical(spec@sort@descending, c(TRUE, FALSE))
})

# ---- edge case 2: by length 0 ---------------------------------------

test_that("sort_rows() with length-0 by is accepted (no-op sort)", {
  spec <- tabular(cdisc_saf_demo) |> sort_rows(by = character())
  expect_true(is_sort_spec(spec@sort))
  expect_identical(spec@sort@by, character())
})

test_that("sort_rows() default arguments are a no-op", {
  spec <- tabular(cdisc_saf_demo) |> sort_rows()
  expect_true(is_sort_spec(spec@sort))
  expect_length(spec@sort@by, 0L)
})

# ---- edge case 5: repeat call replaces -------------------------------

test_that("sort_rows() called twice replaces (not stacks)", {
  spec <- tabular(cdisc_saf_demo) |>
    sort_rows(by = "variable") |>
    sort_rows(by = "stat_label", descending = TRUE)

  expect_identical(spec@sort@by, "stat_label")
  expect_identical(spec@sort@descending, TRUE)
})

# ---- edge case 6: sort-only column (not in cols()) ------------------

test_that("sort_rows() accepts a column not declared in cols()", {
  # row_type is in cdisc_eff_resp's data but not in any cols() call.
  spec <- tabular(cdisc_eff_resp) |>
    sort_rows(by = "row_type")
  expect_identical(spec@sort@by, "row_type")
})

# ---- edge case 1: by references a column not in data ----------------

test_that("sort_rows() errors when by references unknown column", {
  expect_error(
    tabular(cdisc_saf_demo) |> sort_rows(by = "missing_col"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() error names the missing column", {
  err <- tryCatch(
    tabular(cdisc_saf_demo) |>
      sort_rows(by = c("variable", "no_such_col")),
    tabular_error_input = function(e) e
  )
  expect_s3_class(err, "tabular_error_input")
  expect_match(conditionMessage(err), "no_such_col")
})

# ---- edge case 3: by references an arm column from pivot_across() ---

test_that("sort_rows() rejects sort by an arm column stamped by pivot_across()", {
  d <- cdisc_saf_demo
  attr(d, "across_cols") <- "drug_50"
  spec <- tabular(d)
  expect_error(
    spec |> sort_rows(by = "drug_50"),
    class = "tabular_error_input"
  )
})

# ---- edge case 4: descending length mismatch ------------------------

test_that("sort_rows() errors when descending length neither 1 nor length(by)", {
  expect_error(
    tabular(cdisc_saf_demo) |>
      sort_rows(
        by = c("variable", "stat_label"),
        descending = c(TRUE, FALSE, TRUE)
      ),
    class = "tabular_error_input"
  )
})

# ---- spec/argument-shape errors -------------------------------------

test_that("sort_rows() rejects non-spec first argument", {
  expect_error(
    sort_rows(data.frame(x = 1), by = "x"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects non-character by", {
  expect_error(
    tabular(cdisc_saf_demo) |> sort_rows(by = 1:3),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects NA in by", {
  expect_error(
    tabular(cdisc_saf_demo) |> sort_rows(by = c("variable", NA)),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects non-logical descending", {
  expect_error(
    tabular(cdisc_saf_demo) |>
      sort_rows(by = "variable", descending = "yes"),
    class = "tabular_error_input"
  )
})

test_that("sort_rows() rejects NA descending", {
  expect_error(
    tabular(cdisc_saf_demo) |>
      sort_rows(by = "variable", descending = NA),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("sort_rows() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(cdisc_saf_demo) |> sort_rows(by = "no_such_col")
  )
  expect_snapshot(
    error = TRUE,
    tabular(cdisc_saf_demo) |>
      sort_rows(
        by = c("variable", "stat_label"),
        descending = c(TRUE, FALSE, TRUE)
      )
  )
})

# ---------------------------------------------------------------------
# Regression: cards-style hierarchical sort on cdisc_saf_aesocpt
#
# Bug: `sort_rows(by = c("row_type", "n_total"), descending = c(FALSE,
# TRUE))` flattened the SOC -> PT hierarchy because the engine sort is
# pure lexicographic (no group awareness). Fix bakes a parent-broadcast
# `soc_n` + per-row `n_total` into `cdisc_saf_aesocpt` so the two-key sort
# `(desc(soc_n), desc(n_total))` keeps PTs clustered under their parent
# SOC and orders both levels by descending count.
# ---------------------------------------------------------------------

test_that("cdisc_saf_aesocpt body is cards-sorted: SOC clusters intact, PT desc within", {
  ae <- cdisc_saf_aesocpt

  # Overall row floats to the top (carries overall TEAE count on both
  # keys).
  expect_identical(ae$row_type[1L], "overall")

  # Every PT row's `soc_n` equals its parent SOC row's `soc_n` -- the
  # broadcast that keeps clusters from interleaving under a flat sort.
  for (s in unique(ae$soc[ae$row_type == "soc"])) {
    soc_row_n <- ae$soc_n[ae$row_type == "soc" & ae$soc == s]
    pt_rows_n <- ae$soc_n[ae$row_type == "pt" & ae$soc == s]
    expect_identical(unique(pt_rows_n), soc_row_n)
  }

  # Within each SOC cluster, PT rows are sorted by `n_total` desc.
  for (s in unique(ae$soc[ae$row_type == "pt"])) {
    pt_n <- ae$n_total[ae$row_type == "pt" & ae$soc == s]
    expect_identical(pt_n, sort(pt_n, decreasing = TRUE))
  }

  # SOC clusters themselves are ordered by `soc_n` desc.
  soc_n_vec <- ae$soc_n[ae$row_type == "soc"]
  expect_identical(soc_n_vec, sort(soc_n_vec, decreasing = TRUE))
})

test_that("sort_rows(soc_n, n_total) on cdisc_saf_aesocpt preserves cards order", {
  # The render-time sort using the two new keys must reproduce the
  # baked order (it does because the engine's `order()` is stable and
  # the data ships in the canonical sort already).
  spec <- tabular(cdisc_saf_aesocpt) |>
    sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))
  sorted <- engine_sort(spec)@data
  expect_identical(sorted$row_type[1L], "overall")
  # The first SOC cluster is immediately followed by its PT rows, not
  # by another SOC row -- the cards-style hierarchy is preserved.
  first_soc_idx <- which(sorted$row_type == "soc")[1L]
  expect_identical(sorted$row_type[first_soc_idx + 1L], "pt")
})
