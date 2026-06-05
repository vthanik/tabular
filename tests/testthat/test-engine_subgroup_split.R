# engine_subgroup_split() — partition phase. Returns a list of
# (sub_spec, runtime) pairs; one entry when no subgroup, N entries
# when set. Each runtime carries a pre-rendered banner_text built
# from the (possibly defaulted) label template against the group's
# first row.

# ---- no subgroup: single-entry passthrough ---------------------------

test_that("engine_subgroup_split() with no subgroup returns one entry", {
  spec <- tabular(cdisc_saf_demo)
  out <- tabular:::engine_subgroup_split(spec)
  expect_length(out, 1L)
  expect_null(out[[1L]]$runtime)
  expect_identical(out[[1L]]$spec@data, spec@data)
})

# ---- subgroup set: factor ordering by levels -------------------------

test_that("engine_subgroup_split() orders factor groups by level", {
  d <- data.frame(
    g = factor(c("B", "A", "B", "A", "B"), levels = c("A", "B")),
    x = 1:5
  )
  spec <- tabular(d) |> subgroup("g")
  out <- tabular:::engine_subgroup_split(spec)
  expect_length(out, 2L)
  # Factor level order wins, so "A" comes first.
  expect_identical(
    vapply(
      out,
      function(g) as.character(g$runtime$values[[1L]]),
      character(1L)
    ),
    c("A", "B")
  )
  expect_equal(nrow(out[[1L]]$spec@data), 2L)
  expect_equal(nrow(out[[2L]]$spec@data), 3L)
})

# ---- non-factor uses first-appearance order --------------------------

test_that("engine_subgroup_split() respects first-appearance for non-factor", {
  d <- data.frame(g = c("B", "A", "B"), x = 1:3, stringsAsFactors = FALSE)
  spec <- tabular(d) |> subgroup("g")
  out <- tabular:::engine_subgroup_split(spec)
  expect_identical(
    vapply(out, function(g) g$runtime$values[[1L]], character(1L)),
    c("B", "A")
  )
})

# ---- runtime: index, total, banner_text ------------------------------

test_that("engine_subgroup_split() stamps index/total + default banner", {
  d <- data.frame(g = c("X", "Y", "X"), x = 1:3, stringsAsFactors = FALSE)
  spec <- tabular(d) |> subgroup("g")
  out <- tabular:::engine_subgroup_split(spec)
  expect_identical(out[[1L]]$runtime$index, 1L)
  expect_identical(out[[1L]]$runtime$total, 2L)
  # Default template generates "<var>: {var>}"; X comes first.
  expect_identical(out[[1L]]$runtime$banner_text, "g: X")
  expect_identical(out[[2L]]$runtime$banner_text, "g: Y")
})

# ---- attr(col, "label") feeds the default template ------------------

test_that("engine_subgroup_split() default uses attr(col, 'label')", {
  d <- data.frame(g = c("X", "Y"), x = 1:2, stringsAsFactors = FALSE)
  attr(d$g, "label") <- "My Group"
  spec <- tabular(d) |> subgroup("g")
  out <- tabular:::engine_subgroup_split(spec)
  expect_identical(out[[1L]]$runtime$banner_text, "My Group: X")
})

# ---- explicit template referencing another column -------------------

test_that("engine_subgroup_split() resolves multi-column template", {
  d <- data.frame(
    cohort = c("A", "A", "B", "B"),
    n = c(50L, 50L, 75L, 75L),
    x = 1:4,
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |>
    subgroup("cohort", label = "Cohort: {cohort} (N = {n})")
  out <- tabular:::engine_subgroup_split(spec)
  expect_identical(out[[1L]]$runtime$banner_text, "Cohort: A (N = 50)")
  expect_identical(out[[2L]]$runtime$banner_text, "Cohort: B (N = 75)")
})

# ---- edge case: factor with NA value gets its own group --------------

test_that("engine_subgroup_split() handles NA in the subgroup column", {
  d <- data.frame(
    g = c("A", NA, "A", NA, "B"),
    v = 1:5,
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |> subgroup("g")
  out <- tabular:::engine_subgroup_split(spec)
  # Three groups: A, B, NA (first-appearance for non-factor + NA last).
  expect_length(out, 3L)
  # NA group is last regardless.
  last <- out[[length(out)]]$runtime$values[[1L]]
  expect_true(is.na(last))
})

# ---- multi-var crossing ---------------------------------------------

test_that("engine_subgroup_split() crosses two factor cols in level order", {
  d <- data.frame(
    g = factor(c("B", "A", "B", "A"), levels = c("A", "B")),
    h = factor(c("Y", "X", "X", "Y"), levels = c("X", "Y")),
    n = c(10L, 20L, 30L, 40L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |>
    subgroup(c("g", "h"), label = "{g}/{h} (N={n})")
  out <- tabular:::engine_subgroup_split(spec)
  # Cartesian: A/X, A/Y, B/X, B/Y — all present.
  expect_length(out, 4L)
  banners <- vapply(out, function(g) g$runtime$banner_text, character(1L))
  expect_identical(
    banners,
    c("A/X (N=20)", "A/Y (N=40)", "B/X (N=30)", "B/Y (N=10)")
  )
})

test_that("engine_subgroup_split() multi-var drops empty crossings", {
  d <- data.frame(
    g = c("A", "A", "B"),
    h = c("X", "Y", "X"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |>
    subgroup(c("g", "h"), label = "{g}/{h}")
  out <- tabular:::engine_subgroup_split(spec)
  # Only 3 of the 4 crossings have data (B/Y is absent).
  expect_length(out, 3L)
  expect_identical(
    vapply(out, function(g) g$runtime$banner_text, character(1L)),
    c("A/X", "A/Y", "B/X")
  )
})

test_that("engine_subgroup_split() multi-var runtime$by + values list", {
  d <- data.frame(g = c("A", "B"), h = c("X", "Y"), stringsAsFactors = FALSE)
  spec <- tabular(d) |>
    subgroup(c("g", "h"), label = "{g}/{h}")
  out <- tabular:::engine_subgroup_split(spec)
  expect_identical(out[[1L]]$runtime$by, c("g", "h"))
  expect_length(out[[1L]]$runtime$values, 2L)
})

# ---- integration: grid merge keeps per-group page_index --------------

test_that("as_grid() with subgroup concatenates per-group pages", {
  d <- data.frame(
    g = c("A", "A", "B", "B"),
    x = 1:4,
    stringsAsFactors = FALSE
  )
  spec <- tabular(d) |> subgroup("g")
  grid <- as_grid(spec)
  expect_true(is_tabular_grid(grid))
  page_indices <- vapply(grid@pages, function(p) p$page_index, integer(1L))
  expect_true(all(page_indices == 1L))
  expect_true(all(vapply(
    grid@pages,
    function(p) is_inline_ast(p$subgroup_line_ast %||% NULL),
    logical(1L)
  )))
})

test_that("as_grid() with no subgroup returns single un-annotated grid", {
  spec <- tabular(cdisc_saf_demo)
  grid <- suppressWarnings(as_grid(spec)) # incidental overflow warn
  expect_length(grid@pages, 1L)
  expect_null(grid@pages[[1L]]$subgroup_line_ast)
  expect_null(grid@pages[[1L]]$subgroup_index)
})
