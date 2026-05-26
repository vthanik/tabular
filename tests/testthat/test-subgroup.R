# subgroup() — verb attaches a subgroup_spec to a tabular_spec.
# Phase 1 covers single-var partitioning with glue-style label
# templates. Edge cases: clear via empty vars, factor NA, unknown
# var, template unknown col, bad label, multi-var rejected in v0.1.

# ---- happy path ------------------------------------------------------

test_that("subgroup() stores a subgroup_spec on the spec", {
  spec <- tabular(saf_demo) |> subgroup("variable")
  expect_true(is_subgroup_spec(spec@subgroup))
  expect_identical(spec@subgroup@by, "variable")
  expect_null(spec@subgroup@label)
})

test_that("subgroup() accepts a template label", {
  spec <- tabular(saf_demo) |>
    subgroup("variable", label = "Characteristic: {variable}")
  expect_identical(spec@subgroup@label, "Characteristic: {variable}")
})

test_that("subgroup() accepts a multi-column template", {
  # Template can reference any column in spec@data, not just vars.
  df <- data.frame(g = c("A", "A", "B"), n = c(10, 10, 20), x = 1:3)
  spec <- tabular(df) |>
    subgroup("g", label = "Cohort: {g} (N = {n})")
  expect_identical(spec@subgroup@label, "Cohort: {g} (N = {n})")
})

# ---- edge case: empty vars clears the slot ---------------------------

test_that("subgroup() with character(0) clears the slot", {
  spec <- tabular(saf_demo) |>
    subgroup("variable") |>
    subgroup(character(0))
  expect_null(spec@subgroup)
})

test_that("subgroup() with NULL vars clears the slot", {
  spec <- tabular(saf_demo) |>
    subgroup("variable") |>
    subgroup(by = NULL)
  expect_null(spec@subgroup)
})

# ---- edge case: repeat call replaces ---------------------------------

test_that("subgroup() called twice replaces (not stacks)", {
  spec <- tabular(saf_demo) |>
    subgroup("variable") |>
    subgroup("stat_label")
  expect_identical(spec@subgroup@by, "stat_label")
})

# ---- error: unknown variable -----------------------------------------

test_that("subgroup() rejects unknown columns in vars", {
  expect_error(
    tabular(saf_demo) |> subgroup("not_a_column"),
    class = "tabular_error_subgroup_unknown_var"
  )
})

# ---- error: unknown column in template -------------------------------

test_that("subgroup() rejects templates that reference unknown columns", {
  expect_error(
    tabular(saf_demo) |>
      subgroup("variable", label = "Cohort: {nonexistent}"),
    class = "tabular_error_subgroup_template_unknown_col"
  )
})

# ---- multi-var: requires explicit label, accepts when provided -------

test_that("subgroup() multi-var requires an explicit label", {
  expect_error(
    tabular(saf_demo) |> subgroup(c("variable", "stat_label")),
    class = "tabular_error_subgroup_label_required"
  )
})

test_that("subgroup() multi-var with explicit label is accepted", {
  spec <- tabular(saf_demo) |>
    subgroup(
      c("variable", "stat_label"),
      label = "{variable} / {stat_label}"
    )
  expect_true(is_subgroup_spec(spec@subgroup))
  expect_identical(spec@subgroup@by, c("variable", "stat_label"))
  expect_identical(spec@subgroup@label, "{variable} / {stat_label}")
})

test_that("subgroup() rejects duplicate columns in by", {
  expect_error(
    tabular(saf_demo) |>
      subgroup(c("variable", "variable"), label = "{variable}"),
    class = "tabular_error_input"
  )
})

# ---- error: bad arg types --------------------------------------------

test_that("subgroup() rejects non-character vars", {
  expect_error(
    tabular(saf_demo) |> subgroup(by = 1L),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects NA in vars", {
  expect_error(
    tabular(saf_demo) |> subgroup(by = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects empty-string vars", {
  expect_error(
    tabular(saf_demo) |> subgroup(by = ""),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects non-character label", {
  expect_error(
    tabular(saf_demo) |> subgroup("variable", label = 1L),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects length-N label vector", {
  # label is now a single template string, not a per-var vector.
  expect_error(
    tabular(saf_demo) |>
      subgroup("variable", label = c("Too", "Many")),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects NA label", {
  expect_error(
    tabular(saf_demo) |> subgroup("variable", label = NA_character_),
    class = "tabular_error_input"
  )
})

# ---- template helpers ------------------------------------------------

test_that(".subgroup_template_refs() extracts {col} references", {
  expect_identical(
    tabular:::.subgroup_template_refs("Cohort: {g}"),
    "g"
  )
  expect_identical(
    tabular:::.subgroup_template_refs("Cohort: {g} (N = {n})"),
    c("g", "n")
  )
  expect_identical(
    tabular:::.subgroup_template_refs("no refs"),
    character()
  )
  expect_identical(
    tabular:::.subgroup_template_refs(NA_character_),
    character()
  )
})

test_that(".subgroup_render_label() substitutes from a one-row df", {
  row <- data.frame(g = "A", n = 50L, x = "ignored")
  expect_identical(
    tabular:::.subgroup_render_label("Cohort: {g}", row),
    "Cohort: A"
  )
  expect_identical(
    tabular:::.subgroup_render_label("Cohort: {g} (N = {n})", row),
    "Cohort: A (N = 50)"
  )
  # Factor values render via as.character() (level label, not int).
  row2 <- data.frame(
    g = factor("Low", levels = c("Low", "High")),
    stringsAsFactors = FALSE
  )
  expect_identical(
    tabular:::.subgroup_render_label("Cohort: {g}", row2),
    "Cohort: Low"
  )
})

# ---- snapshot: error message text ------------------------------------

test_that("subgroup() unknown-var error message names the bad column", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |> subgroup("not_a_column")
  )
})

test_that("subgroup() template-unknown-col error message names the bad ref", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |>
      subgroup("variable", label = "Cohort: {nonexistent}")
  )
})

# ---------------------------------------------------------------------
# Coverage — subgroup_spec validator branches
# ---------------------------------------------------------------------

test_that("subgroup_spec() rejects NA in @by directly", {
  expect_error(
    tabular:::subgroup_spec(by = c("a", NA_character_), label = NULL),
    regexp = "@by"
  )
})

test_that("subgroup_spec() rejects empty strings in @by", {
  expect_error(
    tabular:::subgroup_spec(by = c("a", ""), label = NULL),
    regexp = "@by"
  )
})

test_that("subgroup_spec() rejects non-character label values", {
  expect_error(
    tabular:::subgroup_spec(by = "a", label = 42)
  )
})

test_that("subgroup_spec() rejects multi-element character label", {
  expect_error(
    tabular:::subgroup_spec(by = "a", label = c("x", "y")),
    regexp = "@label"
  )
})

test_that("subgroup_spec() rejects NA character label", {
  expect_error(
    tabular:::subgroup_spec(by = "a", label = NA_character_),
    regexp = "@label"
  )
})

# ---------------------------------------------------------------------
# Auto-hide of partition `by` + template-ref columns at engine time
# ---------------------------------------------------------------------

test_that(".subgroup_auto_hide_cols returns character(0) when no subgroup", {
  spec <- tabular(data.frame(x = 1:3))
  expect_identical(tabular:::.subgroup_auto_hide_cols(spec), character(0L))
})

test_that(".subgroup_auto_hide_cols returns the by var for single-var partition", {
  spec <- tabular(saf_subgroup) |> subgroup(by = "sex")
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort("sex")
  )
})

test_that(".subgroup_auto_hide_cols unions `by` with template-ref columns", {
  spec <- tabular(saf_subgroup) |>
    subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort(c("sex", "sex_n"))
  )
})

test_that(".subgroup_auto_hide_cols covers multi-var partition + multi-ref label", {
  spec <- tabular(saf_subgroup) |>
    subgroup(
      by = c("sex", "agegr"),
      label = "Sex: {sex} / Age: {agegr} (N total {sex_n})"
    )
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort(c("sex", "agegr", "sex_n"))
  )
})

test_that("subgroup auto-hide flips partition + template-ref cols from the body", {
  spec <- tabular(saf_subgroup) |>
    cols(
      agegr = col_spec(usage = "group", label = "Age Group"),
      agegr_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "Parameter"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo", align = "decimal"),
      drug_50 = col_spec(label = "Drug 50", align = "decimal"),
      drug_100 = col_spec(label = "Drug 100", align = "decimal"),
      Total = col_spec(label = "Total", align = "decimal")
    ) |>
    subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")

  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # `sex` (partition) and `sex_n` (template ref) auto-hidden:
  expect_false("sex" %in% page1$col_names)
  expect_false("sex_n" %in% page1$col_names)
  # Body keeps the user-declared visible columns:
  expect_true("stat_label" %in% page1$col_names)
  expect_true("placebo" %in% page1$col_names)
})

test_that("subgroup auto-hide is a no-op when no subgroup is attached", {
  # Sanity: same spec, no subgroup → `sex` and `sex_n` should NOT
  # be auto-hidden (the user might want them visible in that case).
  spec <- tabular(saf_subgroup) |>
    cols(
      agegr = col_spec(usage = "group", label = "Age Group"),
      agegr_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "Parameter")
    )
  g <- as_grid(spec)
  page1 <- g@pages[[1L]]
  # `sex` and `sex_n` are visible by default when no subgroup is set:
  expect_true("sex" %in% page1$col_names)
  expect_true("sex_n" %in% page1$col_names)
})
