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

# ---- per-page BigN (B2): big_n + big_n_fmt -------------------------------

# Flatten an inline_ast to its concatenated text (helper for label checks).
.bign_flat <- function(ast) {
  paste(
    vapply(ast@runs, function(r) r$text %||% r$value %||% "", character(1L)),
    collapse = ""
  )
}

# Base safety/vitals spec used across the BigN tests. Leaf arm columns
# placebo / drug_50 / drug_100 / Total; `sex` is the partition.
.bign_base <- function(data = saf_subgroup) {
  tabular(data, titles = "Vital Signs") |>
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
    )
}

.bign_arms <- function() {
  data.frame(
    sex = factor(c("F", "M"), levels = c("F", "M")),
    placebo = c(24L, 18L),
    drug_50 = c(9L, 15L),
    drug_100 = c(9L, 14L),
    Total = c(42L, 47L)
  )
}

test_that("big_n suffixes each subgroup's leaf labels; base stays clean", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  g <- as_grid(spec)
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  m1 <- g@pages[[which(idx == 2L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["placebo"]]),
    "(N=24)",
    fixed = TRUE
  )
  expect_match(
    .bign_flat(m1$col_labels_ast[["placebo"]]),
    "(N=18)",
    fixed = TRUE
  )
  # The base/global label is un-suffixed (continuous backends read it).
  expect_match(
    .bign_flat(g@metadata$col_labels_ast[["placebo"]]),
    "^Placebo$"
  )
  expect_true(isTRUE(g@metadata$subgroup_big_n_active))
})

test_that("big_n keyed by a spanner band label suffixes the band", {
  d <- saf_subgroup
  d$placebo_pct <- d$placebo
  spec <- tabular(d, titles = "t") |>
    cols(
      agegr = col_spec(usage = "group", label = "Age"),
      agegr_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "Param"),
      stat_label = col_spec(label = "Stat"),
      placebo = col_spec(label = "n"),
      placebo_pct = col_spec(label = "n(%)"),
      drug_50 = col_spec(visible = FALSE),
      drug_100 = col_spec(visible = FALSE),
      Total = col_spec(visible = FALSE)
    ) |>
    headers("Placebo" = c("placebo", "placebo_pct")) |>
    subgroup(
      "sex",
      label = "Sex: {sex}",
      big_n = data.frame(
        sex = factor(c("F", "M"), levels = c("F", "M")),
        Placebo = c(24L, 18L)
      )
    )
  g <- as_grid(spec)
  sh <- g@metadata$subgroup_headers
  expect_true(any(grepl("(N=24)", sh[[1L]]$label, fixed = TRUE)))
  expect_true(any(grepl("(N=18)", sh[[2L]]$label, fixed = TRUE)))
  # Base bands clean; leaf labels under the band untouched.
  expect_false(any(grepl("(N=", g@metadata$headers$label, fixed = TRUE)))
})

test_that("big_n leaf keying leaves a covering spanner band untouched", {
  spec <- .bign_base() |>
    headers(
      "TREATMENT GROUP" = c("placebo", "drug_50", "drug_100", "Total")
    ) |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  g <- as_grid(spec)
  sh <- g@metadata$subgroup_headers
  # The band label never gains an N (the leaves do).
  expect_false(any(grepl("(N=", sh[[1L]]$label, fixed = TRUE)))
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["placebo"]]),
    "(N=24)",
    fixed = TRUE
  )
})

test_that("big_n per-page N renders in RTF and LaTeX, in distinct segments", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  rtf_f <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, rtf_f)
  rtf <- paste(readLines(rtf_f, warn = FALSE), collapse = "\n")
  expect_true(grepl("(N=24)", rtf, fixed = TRUE))
  expect_true(grepl("(N=18)", rtf, fixed = TRUE))
  # Per-subgroup placement: RTF emits one table per subgroup (F then M),
  # each with its own header band, so F's (N=24) precedes M's (N=18) in
  # document order and each appears exactly once.
  expect_lt(
    regexpr("(N=24)", rtf, fixed = TRUE),
    regexpr("(N=18)", rtf, fixed = TRUE)
  )
  expect_length(gregexpr("(N=24)", rtf, fixed = TRUE)[[1L]], 1L)
  expect_length(gregexpr("(N=18)", rtf, fixed = TRUE)[[1L]], 1L)

  tex_f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, tex_f)
  tex <- paste(readLines(tex_f, warn = FALSE), collapse = "\n")
  expect_true(grepl("(N=24)", tex, fixed = TRUE))
  expect_true(grepl("(N=18)", tex, fixed = TRUE))
})

test_that("big_n per-page N renders in DOCX; top header stays clean", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  f <- withr::local_tempfile(fileext = ".docx")
  emit(spec, f)
  tmp <- withr::local_tempdir()
  utils::unzip(f, files = "word/document.xml", exdir = tmp)
  xml <- paste(
    readLines(file.path(tmp, "word", "document.xml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("N=24", xml, fixed = TRUE))
  expect_true(grepl("N=18", xml, fixed = TRUE))
})

test_that("big_n honours a custom big_n_fmt", {
  spec <- .bign_base() |>
    subgroup("sex", big_n = .bign_arms(), big_n_fmt = " [n={n}]")
  g <- as_grid(spec)
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["placebo"]]),
    "Placebo [n=24]",
    fixed = TRUE
  )
})

test_that("big_n applies to a leaf with no explicit col_spec", {
  # `Total` has no col_spec here; big_n still suffixes its default label.
  spec <- tabular(saf_subgroup, titles = "t") |>
    cols(
      agegr = col_spec(usage = "group", label = "Age"),
      agegr_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "Param"),
      stat_label = col_spec(label = "Stat"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(visible = FALSE),
      drug_100 = col_spec(visible = FALSE)
    ) |>
    subgroup(
      "sex",
      big_n = data.frame(
        sex = factor(c("F", "M"), levels = c("F", "M")),
        Total = c(42L, 47L)
      )
    )
  g <- as_grid(spec)
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["Total"]]),
    "Total(N=42)",
    fixed = TRUE
  )
})

test_that("big_n matches a character by-col against factor data", {
  arms <- .bign_arms()
  arms$sex <- as.character(arms$sex)
  spec <- .bign_base() |> subgroup("sex", big_n = arms)
  g <- as_grid(spec)
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["placebo"]]),
    "(N=24)",
    fixed = TRUE
  )
})

test_that("big_n tolerates an extra combo absent from the data", {
  arms <- rbind(
    .bign_arms(),
    data.frame(
      sex = "X",
      placebo = 1L,
      drug_50 = 1L,
      drug_100 = 1L,
      Total = 1L
    )
  )
  arms$sex <- factor(arms$sex, levels = c("F", "M", "X"))
  expect_no_error(.bign_base() |> subgroup("sex", big_n = arms))
})

# ---- big_n validation: one error per branch ------------------------------

test_that("big_n requires a non-empty by", {
  expect_error(
    tabular(saf_subgroup) |> subgroup(character(), big_n = .bign_arms()),
    class = "tabular_error_input"
  )
})

test_that("big_n validation rejects every malformed input", {
  base <- .bign_base()
  arms <- .bign_arms()

  # (1) not a data frame
  expect_error(
    base |> subgroup("sex", big_n = list(placebo = 24)),
    class = "tabular_error_input"
  )
  # (2) zero rows
  expect_error(
    base |> subgroup("sex", big_n = arms[0, ]),
    class = "tabular_error_input"
  )
  # (3) big_n_fmt not a scalar string
  expect_error(
    base |> subgroup("sex", big_n = arms, big_n_fmt = c("a", "b")),
    class = "tabular_error_input"
  )
  # (4) big_n_fmt missing {n}
  expect_error(
    base |> subgroup("sex", big_n = arms, big_n_fmt = "(N=)"),
    class = "tabular_error_input"
  )
  # (5) big_n_fmt has a token other than {n}
  expect_error(
    base |> subgroup("sex", big_n = arms, big_n_fmt = "\n(N={N})"),
    class = "tabular_error_input"
  )
  # (6) missing a by column
  expect_error(
    base |> subgroup("sex", big_n = arms[, -1, drop = FALSE]),
    class = "tabular_error_input"
  )
  # (7) no value column
  expect_error(
    base |> subgroup("sex", big_n = arms[, "sex", drop = FALSE]),
    class = "tabular_error_input"
  )
  # (8a) unknown target (typo)
  bad <- arms
  names(bad)[names(bad) == "placebo"] <- "placeboo"
  expect_error(
    base |> subgroup("sex", big_n = bad),
    class = "tabular_error_input"
  )
  # (9) negative / fractional / non-numeric value
  neg <- arms
  neg$placebo <- c(-1L, 18L)
  expect_error(
    base |> subgroup("sex", big_n = neg),
    class = "tabular_error_input"
  )
  frac <- arms
  frac$placebo <- c(24.5, 18)
  expect_error(
    base |> subgroup("sex", big_n = frac),
    class = "tabular_error_input"
  )
  # (9b) leaf target is a hidden column
  expect_error(
    base |>
      subgroup(
        "sex",
        big_n = data.frame(
          sex = factor(c("F", "M"), levels = c("F", "M")),
          agegr_n = c(1L, 2L)
        )
      ),
    class = "tabular_error_input"
  )
  # (10) duplicate by-combo
  dup <- rbind(arms, arms[1, ])
  expect_error(
    base |> subgroup("sex", big_n = dup),
    class = "tabular_error_input"
  )
  # (11) missing combo
  expect_error(
    base |> subgroup("sex", big_n = arms[1, , drop = FALSE]),
    class = "tabular_error_input"
  )
})

test_that("big_n ambiguous target (data col and band label collide) errors", {
  d <- saf_subgroup
  d$placebo_pct <- d$placebo
  spec <- tabular(d, titles = "t") |>
    cols(
      agegr = col_spec(usage = "group", label = "Age"),
      agegr_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "Param"),
      stat_label = col_spec(label = "Stat"),
      placebo = col_spec(label = "n"),
      placebo_pct = col_spec(label = "n(%)"),
      drug_50 = col_spec(visible = FALSE),
      drug_100 = col_spec(visible = FALSE),
      Total = col_spec(visible = FALSE)
    ) |>
    headers("placebo" = c("placebo", "placebo_pct")) # band label == data col
  expect_error(
    spec |>
      subgroup(
        "sex",
        big_n = data.frame(
          sex = factor(c("F", "M"), levels = c("F", "M")),
          placebo = c(24L, 18L)
        )
      ),
    class = "tabular_error_input"
  )
})

# ---- big_n long format (count()-style) -----------------------------------

.bign_long <- function() {
  data.frame(
    sex = factor(rep(c("F", "M"), each = 4L), levels = c("F", "M")),
    drug = rep(c("placebo", "drug_50", "drug_100", "Total"), 2L),
    n = c(24L, 9L, 9L, 42L, 18L, 15L, 14L, 47L)
  )
}

test_that("big_n accepts a long (by, arm, n) table, pivoted internally", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_long())
  g <- as_grid(spec)
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  m1 <- g@pages[[which(idx == 2L)[1L]]]
  expect_match(
    .bign_flat(f1$col_labels_ast[["placebo"]]),
    "(N=24)",
    fixed = TRUE
  )
  expect_match(
    .bign_flat(m1$col_labels_ast[["drug_50"]]),
    "(N=15)",
    fixed = TRUE
  )
  # The stored big_n is the pivoted wide form.
  expect_setequal(
    names(spec@subgroup@big_n),
    c("sex", "placebo", "drug_50", "drug_100", "Total")
  )
})

test_that("long and wide big_n give identical per-page labels", {
  fl <- function(spec) {
    g <- as_grid(spec)
    idx <- vapply(
      g@pages,
      function(p) p$subgroup_index %||% NA_integer_,
      integer(1L)
    )
    vapply(
      sort(unique(idx)),
      function(i) {
        p <- g@pages[[which(idx == i)[1L]]]
        .bign_flat(p$col_labels_ast[["placebo"]])
      },
      character(1L)
    )
  }
  wide <- fl(.bign_base() |> subgroup("sex", big_n = .bign_arms()))
  long <- fl(.bign_base() |> subgroup("sex", big_n = .bign_long()))
  expect_identical(wide, long)
})

test_that("big_n long rejects a duplicate (by, arm) row", {
  dup <- rbind(.bign_long(), .bign_long()[1L, ])
  expect_error(
    .bign_base() |> subgroup("sex", big_n = dup),
    class = "tabular_error_input"
  )
})

test_that("big_n long rejects a missing (arm, combo) cell", {
  # Drop the (M, placebo) row -> NA after pivot -> non-NA value check.
  long <- .bign_long()
  long <- long[!(long$sex == "M" & long$drug == "placebo"), ]
  expect_error(
    .bign_base() |> subgroup("sex", big_n = long),
    class = "tabular_error_input"
  )
})

test_that("big_n rejects an unrecognised shape (two key columns)", {
  amb <- data.frame(
    sex = factor(c("F", "M"), levels = c("F", "M")),
    a = c("x", "y"),
    b = c("p", "q"),
    n = c(1L, 2L)
  )
  expect_error(
    .bign_base() |> subgroup("sex", big_n = amb),
    class = "tabular_error_input"
  )
})

# ---- subgroup_spec validator backstops for big_n / big_n_fmt --------------

test_that("subgroup_spec() rejects a non-data-frame big_n directly", {
  expect_error(
    tabular:::subgroup_spec(by = "a", big_n = 1L),
    regexp = "@big_n"
  )
})

test_that("subgroup_spec() rejects a non-scalar big_n_fmt directly", {
  expect_error(
    tabular:::subgroup_spec(by = "a", big_n_fmt = c("x", "y")),
    regexp = "@big_n_fmt"
  )
})

test_that("subgroup_spec() rejects a big_n_fmt without the {n} token", {
  expect_error(
    tabular:::subgroup_spec(by = "a", big_n_fmt = "(N=)"),
    regexp = "n.*placeholder|placeholder"
  )
})
