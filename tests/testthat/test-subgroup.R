# subgroup() — verb attaches a subgroup_spec to a tabular_spec.
# Phase 1 covers single-var partitioning with glue-style label
# templates. Edge cases: clear via empty vars, factor NA, unknown
# var, template unknown col, bad label, multi-var rejected in v0.1.

# ---- happy path ------------------------------------------------------

test_that("subgroup() stores a subgroup_spec on the spec", {
  spec <- tabular(cdisc_saf_demo) |> subgroup("variable")
  expect_true(is_subgroup_spec(spec@subgroup))
  expect_identical(spec@subgroup@by, "variable")
  expect_null(spec@subgroup@label)
})

test_that("subgroup() accepts a template label", {
  spec <- tabular(cdisc_saf_demo) |>
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
  spec <- tabular(cdisc_saf_demo) |>
    subgroup("variable") |>
    subgroup(character(0))
  expect_null(spec@subgroup)
})

test_that("subgroup() with NULL vars clears the slot", {
  spec <- tabular(cdisc_saf_demo) |>
    subgroup("variable") |>
    subgroup(by = NULL)
  expect_null(spec@subgroup)
})

# ---- edge case: repeat call replaces ---------------------------------

test_that("subgroup() called twice replaces (not stacks)", {
  spec <- tabular(cdisc_saf_demo) |>
    subgroup("variable") |>
    subgroup("stat_label")
  expect_identical(spec@subgroup@by, "stat_label")
})

# ---- error: unknown variable -----------------------------------------

test_that("subgroup() rejects unknown columns in vars", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup("not_a_column"),
    class = "tabular_error_subgroup_unknown_var"
  )
})

# ---- error: unknown column in template -------------------------------

test_that("subgroup() rejects templates that reference unknown columns", {
  expect_error(
    tabular(cdisc_saf_demo) |>
      subgroup("variable", label = "Cohort: {nonexistent}"),
    class = "tabular_error_subgroup_template_unknown_col"
  )
})

# ---- multi-var: requires explicit label, accepts when provided -------

test_that("subgroup() multi-var requires an explicit label", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup(c("variable", "stat_label")),
    class = "tabular_error_subgroup_label_required"
  )
})

test_that("subgroup() multi-var with explicit label is accepted", {
  spec <- tabular(cdisc_saf_demo) |>
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
    tabular(cdisc_saf_demo) |>
      subgroup(c("variable", "variable"), label = "{variable}"),
    class = "tabular_error_input"
  )
})

# ---- error: bad arg types --------------------------------------------

test_that("subgroup() rejects non-character vars", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup(by = 1L),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects NA in vars", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup(by = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects empty-string vars", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup(by = ""),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects non-character label", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup("variable", label = 1L),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects length-N label vector", {
  # label is now a single template string, not a per-var vector.
  expect_error(
    tabular(cdisc_saf_demo) |>
      subgroup("variable", label = c("Too", "Many")),
    class = "tabular_error_input"
  )
})

test_that("subgroup() rejects NA label", {
  expect_error(
    tabular(cdisc_saf_demo) |> subgroup("variable", label = NA_character_),
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
    tabular(cdisc_saf_demo) |> subgroup("not_a_column")
  )
})

test_that("subgroup() template-unknown-col error message names the bad ref", {
  expect_snapshot(
    error = TRUE,
    tabular(cdisc_saf_demo) |>
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
  spec <- tabular(cdisc_saf_subgroup) |> subgroup(by = "sex")
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort("sex")
  )
})

test_that(".subgroup_auto_hide_cols unions `by` with template-ref columns", {
  spec <- tabular(cdisc_saf_subgroup) |>
    subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort(c("sex", "sex_n"))
  )
})

test_that(".subgroup_auto_hide_cols covers multi-var partition + multi-ref label", {
  spec <- tabular(cdisc_saf_subgroup) |>
    subgroup(
      by = c("sex", "visit"),
      label = "Sex: {sex} / Visit: {visit} (N total {sex_n})"
    )
  expect_identical(
    sort(tabular:::.subgroup_auto_hide_cols(spec)),
    sort(c("sex", "visit", "sex_n"))
  )
})

test_that("subgroup auto-hide flips partition + template-ref cols from the body", {
  spec <- tabular(cdisc_saf_subgroup) |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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
  spec <- tabular(cdisc_saf_subgroup) |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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
.bign_base <- function(data = cdisc_saf_subgroup) {
  tabular(data, titles = "Vital Signs") |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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

# Same denominators for every subgroup: N does not vary, so the engine
# folds it into the column header instead of emitting a per-subgroup row.
.bign_arms_constant <- function() {
  data.frame(
    sex = factor(c("F", "M"), levels = c("F", "M")),
    placebo = c(24L, 24L),
    drug_50 = c(9L, 9L),
    drug_100 = c(9L, 9L),
    Total = c(42L, 42L)
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
  d <- cdisc_saf_subgroup
  d$placebo_pct <- d$placebo
  spec <- tabular(d, titles = "t") |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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
  # Each subgroup's SUFFIXED band frame rides its page descriptors.
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f_bands <- g@pages[[which(idx == 1L)[1L]]]$headers
  m_bands <- g@pages[[which(idx == 2L)[1L]]]$headers
  expect_true(any(grepl("(N=24)", f_bands$label, fixed = TRUE)))
  expect_true(any(grepl("(N=18)", m_bands$label, fixed = TRUE)))
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
  idx <- vapply(
    g@pages,
    function(p) p$subgroup_index %||% NA_integer_,
    integer(1L)
  )
  f1 <- g@pages[[which(idx == 1L)[1L]]]
  # The band label never gains an N (the leaves do).
  expect_false(any(grepl("(N=", f1$headers$label, fixed = TRUE)))
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

test_that("big_n DOCX: one table per subgroup, N header repeats per page", {
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
  # One `<w:tbl>` per subgroup so each table's header is a LEADING
  # tblHeader block that Word repeats on every continuation page.
  expect_length(gregexpr("<w:tbl>", xml, fixed = TRUE)[[1L]], 2L)
  # Canonical order: the Sex banner sits above its (N=x) header.
  expect_lt(
    regexpr("Sex: F", xml, fixed = TRUE),
    regexpr("N=24", xml, fixed = TRUE)
  )
  # The N header is in the lead block (before the table's first body
  # row), which is what makes Word repeat it.
  t1 <- strsplit(xml, "<w:tbl>", fixed = TRUE)[[1L]]
  t1 <- t1[grepl("N=24", t1)][[1L]]
  expect_lt(
    regexpr("N=24", t1, fixed = TRUE),
    regexpr("Mean|Median|Diastolic", t1)
  )
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

# ---- big_n collapses when the N does not vary across subgroups -----------

test_that(".subgroup_bign_constant detects identical-vs-varying denominators", {
  vary <- .bign_base() |> subgroup("sex", big_n = .bign_arms())
  same <- .bign_base() |> subgroup("sex", big_n = .bign_arms_constant())
  none <- .bign_base() |> subgroup("sex")
  expect_false(tabular:::.subgroup_bign_constant(vary))
  expect_true(tabular:::.subgroup_bign_constant(same))
  expect_false(tabular:::.subgroup_bign_constant(none))

  # Table reuse: big_n carries an extra row (M, N=18) for a subgroup
  # absent from the data; the decision must look only at the DISPLAYED
  # subgroup (F), which has a single N, and still fold.
  reuse_data <- cdisc_saf_subgroup[
    cdisc_saf_subgroup$sex == "F",
    ,
    drop = FALSE
  ]
  reuse <- .bign_base(reuse_data) |> subgroup("sex", big_n = .bign_arms())
  expect_true(tabular:::.subgroup_bign_constant(reuse))
})

test_that("constant big_n: DOCX keeps the banner above the header band", {
  # The constant fold disables the per-arm N row but must NOT collapse the
  # paged backends to the inline body banner. DOCX must keep one table per
  # subgroup with the banner above the column-header band, matching RTF /
  # LaTeX (not the below-header body path used for no-big_n tables).
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms_constant())
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, files = "word/document.xml", exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  banner <- regexpr("Sex: F", doc, fixed = TRUE)
  header <- regexpr("Statistic", doc, fixed = TRUE)
  expect_gt(banner, 0L)
  expect_lt(banner, header) # banner ABOVE the column-header band
  # One <w:tbl> per subgroup (F, M), not a single collapsed inline table.
  expect_length(gregexpr("<w:tbl>", doc, fixed = TRUE)[[1L]], 2L)
})

test_that("HTML banner keeps a closing rule when there is no per-arm N row", {
  # No big_n and constant big_n both emit no `.tabular-subgroup-bign` row,
  # so the banner itself must carry the closing rule (the unboxed banner
  # would otherwise float into the data block with no separator).
  expect_closed <- function(spec) {
    out <- withr::local_tempfile(fileext = ".html")
    emit(spec, out)
    html <- paste(readLines(out, warn = FALSE), collapse = "\n")
    expect_no_match(html, "<tr class=\"tabular-subgroup-bign\"", fixed = TRUE)
    expect_match(
      html,
      "<tr class=\"tabular-subgroup tabular-subgroup-closed\">",
      fixed = TRUE
    )
    expect_match(
      html,
      ".tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }",
      fixed = TRUE
    )
  }
  expect_closed(.bign_base() |> subgroup("sex", label = "Sex: {sex}"))
  expect_closed(
    .bign_base() |>
      subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms_constant())
  )
})

test_that("varying big_n: HTML banner is unclosed (the N row carries the rule)", {
  # With a per-arm N row present, the banner must NOT also carry the closing
  # rule, so banner + N read as one block with a single rule below the N.
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_no_match(html, "tabular-subgroup-closed\"", fixed = TRUE)
  expect_match(html, "<tr class=\"tabular-subgroup-bign\"", fixed = TRUE)
})

test_that("constant big_n: HTML folds N into the column header, no per-subgroup row", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms_constant())
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # No repeated per-subgroup (N=x) row; N rides the single column header.
  expect_no_match(html, "<tr class=\"tabular-subgroup-bign\"", fixed = TRUE)
  expect_match(html, "Placebo<br/>(N=24)", fixed = TRUE)
  # The N appears once per arm (in the header), not once per subgroup.
  expect_length(gregexpr("(N=24)", html, fixed = TRUE)[[1L]], 1L)
})

test_that("varying big_n: HTML keeps the per-subgroup (N=x) row", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # F (N=24) and M (N=18) differ, so each subgroup carries its own N row.
  expect_match(html, "<tr class=\"tabular-subgroup-bign\"", fixed = TRUE)
  expect_match(html, "(N=24)", fixed = TRUE)
  expect_match(html, "(N=18)", fixed = TRUE)
})

test_that("no big_n: HTML emits no per-subgroup N row", {
  spec <- .bign_base() |> subgroup("sex", label = "Sex: {sex}")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_no_match(html, "<tr class=\"tabular-subgroup-bign\"", fixed = TRUE)
})

test_that("constant big_n: MD folds N into the column header, paged keeps it inline", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms_constant())
  md_f <- withr::local_tempfile(fileext = ".md")
  emit(spec, md_f)
  md <- readLines(md_f, warn = FALSE)
  # N is on the column-header row, not a separate per-subgroup pipe row.
  expect_match(md[grep("Statistic", md)[1L]], "(N=24)", fixed = TRUE)
  # Paged (RTF) still prints N once per arm in the (repeating) header.
  rtf_f <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, rtf_f)
  rtf <- paste(readLines(rtf_f, warn = FALSE), collapse = "\n")
  expect_match(rtf, "(N=24)", fixed = TRUE)
  expect_match(rtf, "Sex: F", fixed = TRUE)
})

# ---- subgroup banner layout: above the header band, left-aligned --------

test_that("RTF/LaTeX place the subgroup banner above the header band, left", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  rtf_f <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, rtf_f)
  rtf <- readLines(rtf_f, warn = FALSE)
  banner <- grep("Sex: F", rtf)[[1L]]
  header <- grep("Statistic", rtf)[[1L]]
  expect_lt(banner, header) # banner ABOVE the column-header band
  expect_match(rtf[[banner]], "\\ql", fixed = TRUE) # left-aligned

  tex_f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, tex_f)
  tex <- readLines(tex_f, warn = FALSE)
  t_banner <- grep("Sex: F", tex)[[1L]]
  t_header <- grep("Statistic", tex)[[1L]]
  expect_lt(t_banner, t_header)
  expect_match(tex[[t_banner]], "{l}", fixed = TRUE) # \SetCell[c=N]{l}
})

test_that("HTML banner is unboxed; the closing rule rides the (N=x) row", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # The banner row carries no border of its own (no boxed look)...
  expect_match(
    html,
    ".tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }",
    fixed = TRUE
  )
  # ...and the closing rule sits on the per-arm N row instead.
  expect_match(
    html,
    ".tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }",
    fixed = TRUE
  )
})

test_that("big_n applies to a leaf with no explicit col_spec", {
  # `Total` has no col_spec here; big_n still suffixes its default label.
  spec <- tabular(cdisc_saf_subgroup, titles = "t") |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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
    tabular(cdisc_saf_subgroup) |>
      subgroup(character(), big_n = .bign_arms()),
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
          paramcd = c(1L, 2L)
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
  d <- cdisc_saf_subgroup
  d$placebo_pct <- d$placebo
  spec <- tabular(d, titles = "t") |>
    cols(
      visit = col_spec(usage = "group", label = "Visit"),
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

# ---- big_n: arm/by clash, contiguity message, continuous backends --------

test_that("big_n long rejects an arm name that clashes with a by column", {
  # Partition by `param`; a long arm literally named "param".
  base <- tabular(cdisc_saf_subgroup, titles = "t") |>
    cols(
      sex = col_spec(visible = FALSE),
      sex_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(label = "P"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(visible = FALSE),
      drug_100 = col_spec(visible = FALSE),
      Total = col_spec(visible = FALSE)
    )
  params <- unique(cdisc_saf_subgroup$param)
  long <- data.frame(
    param = rep(params, 2L),
    arm = rep(c("param", "placebo"), each = length(params)),
    n = seq_len(2L * length(params))
  )
  expect_error(
    base |> subgroup("param", label = "P: {param}", big_n = long),
    class = "tabular_error_input"
  )
})

test_that("non-contiguous band + big_n names the ORIGINAL band label", {
  # placebo and placebo_pct are NOT adjacent (drug_50 between) -> the band
  # is non-contiguous; the error must name "Placebo", not "Placebo (N=24)".
  d <- cdisc_saf_subgroup
  d$placebo_pct <- d$placebo
  d <- d[, c(
    "sex",
    "sex_n",
    "paramcd",
    "param",
    "stat_label",
    "placebo",
    "drug_50",
    "placebo_pct"
  )]
  spec <- tabular(d, titles = "t") |>
    cols(
      sex = col_spec(visible = FALSE),
      sex_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group", label = "P"),
      stat_label = col_spec(label = "S"),
      placebo = col_spec(label = "n"),
      drug_50 = col_spec(label = "d"),
      placebo_pct = col_spec(label = "%")
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
  err <- tryCatch(as_grid(spec), error = function(e) conditionMessage(e))
  expect_true(any(grepl("Placebo", err, fixed = TRUE)))
  expect_false(any(grepl("(N=24)", err, fixed = TRUE)))
})

test_that("big_n: HTML emits a per-arm N row under each banner; base header stays clean", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  f <- withr::local_tempfile(fileext = ".html")
  emit(spec, f)
  lines <- readLines(f)
  bign_rows <- grep(
    "<tr class=\"tabular-subgroup-bign\"",
    lines,
    value = TRUE,
    fixed = TRUE
  )
  # One per-arm N row per subgroup banner (F page, M page).
  expect_length(bign_rows, 2L)
  expect_match(bign_rows[[1L]], "(N=24)", fixed = TRUE)
  expect_match(bign_rows[[1L]], "(N=42)", fixed = TRUE)
  # The M page carries its own population.
  expect_match(bign_rows[[2L]], "(N=18)", fixed = TRUE)
  # The single base header is the un-suffixed one: the per-page N never
  # leaks into <thead>.
  thead <- lines[seq_len(grep("</thead>", lines, fixed = TRUE)[[1L]])]
  expect_false(any(grepl("(N=24)", thead, fixed = TRUE)))
  expect_true(any(grepl("Placebo", thead, fixed = TRUE)))
})

test_that("big_n HTML: adjacent equal Ns render as two cells, never one colspan", {
  # The F page has drug_50 = 9 next to drug_100 = 9. Keying spans on the
  # arm name (not the rendered text) must keep them two distinct cells.
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  f <- withr::local_tempfile(fileext = ".html")
  emit(spec, f)
  f_row <- grep(
    "<tr class=\"tabular-subgroup-bign\"",
    readLines(f),
    value = TRUE,
    fixed = TRUE
  )[[1L]]
  # Both Ns land in their own plain (colspan-free) cell. (The leading
  # empty stub columns legitimately coalesce into one colspan cell; only
  # the equal-N arms must stay separate.)
  plain_n9 <- gregexpr(
    "<td style=\"text-align: center;\">(N=9)</td>",
    f_row,
    fixed = TRUE
  )[[1L]]
  expect_identical(length(plain_n9), 2L)
  expect_false(grepl(
    "colspan=\"2\" style=\"text-align: center;\">(N=9)",
    f_row,
    fixed = TRUE
  ))
})

test_that("big_n: Markdown emits a per-arm N pipe row under each banner", {
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms())
  f <- withr::local_tempfile(fileext = ".md")
  emit(spec, f)
  lines <- readLines(f)
  expect_true(any(grepl(
    "| (N=24) | (N=9) | (N=9) | (N=42) |",
    lines,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "| (N=18) | (N=15) | (N=14) | (N=47) |",
    lines,
    fixed = TRUE
  )))
})

test_that("big_n band-keyed: HTML colspans the band; Markdown repeats the N", {
  big_n <- data.frame(
    sex = factor(c("F", "M"), levels = c("F", "M")),
    placebo = c(24L, 18L),
    Active = c(18L, 29L),
    Total = c(42L, 47L)
  )
  spec <- .bign_base() |>
    headers(Active = c("drug_50", "drug_100")) |>
    subgroup("sex", label = "Sex: {sex}", big_n = big_n)
  fh <- withr::local_tempfile(fileext = ".html")
  emit(spec, fh)
  h_row <- grep(
    "<tr class=\"tabular-subgroup-bign\"",
    readLines(fh),
    value = TRUE,
    fixed = TRUE
  )[[1L]]
  # One colspan=2 cell over the band's two leaves, carrying the band N.
  expect_match(
    h_row,
    "colspan=\"2\" style=\"text-align: center;\">(N=18)",
    fixed = TRUE
  )
  fm <- withr::local_tempfile(fileext = ".md")
  emit(spec, fm)
  # GFM has no colspan, so the band N repeats across its columns (the
  # same convention header bands already follow).
  expect_true(any(grepl(
    "| (N=24) | (N=18) | (N=18) | (N=42) |",
    readLines(fm),
    fixed = TRUE
  )))
})

test_that("big_n: the per-arm N row repeats with the banner across vertical page splits", {
  # A large font shrinks the per-page row budget so each subgroup splits
  # across vertical pages. The N row is gated on the banner being
  # present, so it must repeat in lockstep with the banner after each
  # break, never drifting.
  spec <- .bign_base() |>
    subgroup("sex", label = "Sex: {sex}", big_n = .bign_arms()) |>
    preset(font_size = 24L, width_mode = "fixed")
  f <- withr::local_tempfile(fileext = ".html")
  emit(spec, f)
  lines <- readLines(f)
  break_ct <- length(grep("tabular-page-break-row", lines, fixed = TRUE))
  banner_ct <- length(grep("class=\"tabular-subgroup\"", lines, fixed = TRUE))
  bign_ct <- length(grep(
    "class=\"tabular-subgroup-bign\"",
    lines,
    fixed = TRUE
  ))
  expect_gt(break_ct, 0L) # a split actually happened
  expect_gt(banner_ct, 2L) # banner repeated beyond the two subgroups
  expect_identical(bign_ct, banner_ct) # N row tracks the banner exactly
})

# ---------------------------------------------------------------------
# Subgroup banner spacing gap (F3)
# ---------------------------------------------------------------------

# The banner blank rows are a paged-medium primitive, so the subgroup
# `spacing` gap moves RTF / LaTeX / DOCX. HTML is continuous: the banner
# separation is a fixed CSS margin (like valign / pagination, paged-only),
# so HTML output is unchanged by the knob, by design.
test_that("subgroup banner gap responds to preset(spacing=) on paged backends", {
  base_spec <- tabular(cdisc_saf_subgroup) |>
    preset(width_mode = "fixed") |>
    subgroup(by = "sex")
  wide_spec <- tabular(cdisc_saf_subgroup) |>
    preset(
      width_mode = "fixed",
      spacing = list(subgroup = c(above = 3, below = 3))
    ) |>
    subgroup(by = "sex")
  read_docx <- function(p) {
    td <- withr::local_tempdir()
    utils::unzip(p, files = "word/document.xml", exdir = td)
    readLines(file.path(td, "word", "document.xml"), warn = FALSE)
  }
  for (ext in c(".rtf", ".tex", ".docx")) {
    b <- emit(base_spec, withr::local_tempfile(fileext = ext))
    w <- emit(wide_spec, withr::local_tempfile(fileext = ext))
    if (identical(ext, ".docx")) {
      expect_false(identical(read_docx(b), read_docx(w)), info = ext)
    } else {
      expect_false(
        identical(readLines(b, warn = FALSE), readLines(w, warn = FALSE)),
        info = ext
      )
    }
  }
})

test_that("subgroup gap leaves continuous HTML byte-identical (by design)", {
  base_spec <- tabular(cdisc_saf_subgroup) |>
    preset(width_mode = "fixed") |>
    subgroup(by = "sex")
  wide_spec <- tabular(cdisc_saf_subgroup) |>
    preset(
      width_mode = "fixed",
      spacing = list(subgroup = c(above = 3, below = 3))
    ) |>
    subgroup(by = "sex")
  b <- emit(base_spec, withr::local_tempfile(fileext = ".html"))
  w <- emit(wide_spec, withr::local_tempfile(fileext = ".html"))
  expect_identical(
    readLines(b, warn = FALSE),
    readLines(w, warn = FALSE)
  )
})

# ---------------------------------------------------------------------
# keep_empty (Part 6 / N1)
# ---------------------------------------------------------------------

# A multi-variable partition with one crossing deliberately absent.
.sg_gapped_data <- function() {
  d <- cdisc_saf_subgroup
  vis <- unique(as.character(d$visit))[[1L]]
  d[!(as.character(d$sex) == "F" & as.character(d$visit) == vis), ]
}

.sg_gapped_spec <- function(keep_empty) {
  tabular(.sg_gapped_data()) |>
    cols(
      sex_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group"),
      stat_label = col_spec(),
      placebo = col_spec(),
      drug_50 = col_spec(),
      drug_100 = col_spec(),
      Total = col_spec()
    ) |>
    subgroup(
      by = c("sex", "visit"),
      label = "Sex: {sex} / Visit: {visit}",
      keep_empty = keep_empty
    )
}

test_that("keep_empty=TRUE retains a zero-N crossing as an empty page", {
  drop <- as_grid(.sg_gapped_spec(FALSE))
  keep <- as_grid(.sg_gapped_spec(TRUE))
  expect_equal(keep@metadata$total_pages, drop@metadata$total_pages + 1L)
  n_empty <- sum(vapply(
    keep@pages,
    function(p) isTRUE(p$is_empty_page),
    logical(1L)
  ))
  expect_equal(n_empty, 1L)
})

test_that("keep_empty=FALSE (default) drops zero-N crossings", {
  keep <- as_grid(.sg_gapped_spec(TRUE))
  drop <- as_grid(.sg_gapped_spec(FALSE))
  expect_lt(drop@metadata$total_pages, keep@metadata$total_pages)
})

test_that("subgroup() rejects a non-logical keep_empty", {
  expect_error(
    tabular(cdisc_saf_subgroup) |> subgroup(by = "sex", keep_empty = "yes"),
    class = "tabular_error_input"
  )
  expect_error(
    tabular(cdisc_saf_subgroup) |> subgroup(by = "sex", keep_empty = NA),
    class = "tabular_error_input"
  )
})

test_that("keep_empty empty-group banner renders the by-column values", {
  keep <- as_grid(.sg_gapped_spec(TRUE))
  empty_pg <- Filter(function(p) isTRUE(p$is_empty_page), keep@pages)[[1L]]
  banner <- paste(
    vapply(
      empty_pg$subgroup_line_ast@runs,
      function(r) r$text %||% "",
      character(1L)
    ),
    collapse = ""
  )
  expect_match(banner, "Sex: F")
})

test_that("keep_empty=TRUE composes with big_n without index misalignment", {
  # Regression: the BigN record helpers iterated present-only combos while
  # the split (and the per-page merge) index by the keep_empty-aware combo
  # position, so a zero-N crossing shifted/overran the records list and the
  # continuous backends hit `subscript out of bounds`.
  d <- .sg_gapped_data()
  present <- unique(d[, c("sex", "visit")])
  present <- present[order(present$sex, present$visit), ]
  bn <- present
  bn$placebo <- seq_len(nrow(present)) * 10L
  bn$drug_50 <- seq_len(nrow(present)) * 5L
  bn$drug_100 <- seq_len(nrow(present)) * 3L
  bn$Total <- bn$placebo + bn$drug_50 + bn$drug_100
  spec <- tabular(d) |>
    cols(
      sex_n = col_spec(visible = FALSE),
      paramcd = col_spec(visible = FALSE),
      param = col_spec(usage = "group"),
      stat_label = col_spec(),
      placebo = col_spec(),
      drug_50 = col_spec(),
      drug_100 = col_spec(),
      Total = col_spec()
    ) |>
    subgroup(
      by = c("sex", "visit"),
      label = "Sex: {sex} / Visit: {visit}",
      big_n = bn,
      keep_empty = TRUE
    )
  for (ext in c(".html", ".md", ".rtf", ".docx")) {
    expect_no_error(emit(spec, withr::local_tempfile(fileext = ext)))
  }
})
