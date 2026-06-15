# Tests for R/theme.R — the styling SSOT resolvers.

# ---- resolve_rules: string sugar ------------------------------------

test_that("resolve_rules booktabs turns on the clinical baseline rules", {
  r <- tabular:::resolve_rules("booktabs")
  expect_named(r, tabular:::.tabular_rule_keys)
  # Top / mid / bottom closers + spanner on. `bottomrule` and
  # `footnoterule` are mutually exclusive at the data -> footnote
  # boundary; the default closer is `bottomrule`, so `footnoterule`
  # is OFF (opt-in only). Row + verticals off.
  expect_false(is.null(r$toprule))
  expect_false(is.null(r$midrule))
  expect_false(is.null(r$bottomrule))
  expect_false(is.null(r$spanrule))
  expect_null(r$footnoterule)
  expect_null(r$rowrule)
  expect_null(r$leftrule)
  expect_null(r$rightrule)
  expect_null(r$colrule)
})

test_that("resolve_rules booktabs spanrule is muted, others ink", {
  r <- tabular:::resolve_rules("booktabs")
  expect_identical(r$toprule$color, tabular:::.tabular_ink)
  expect_identical(r$midrule$color, tabular:::.tabular_ink)
  expect_identical(r$bottomrule$color, tabular:::.tabular_ink)
  expect_identical(r$spanrule$color, tabular:::.tabular_muted)
  expect_identical(r$toprule$width, tabular:::.tabular_rule_width)
})

test_that("resolve_rules grid turns on all nine rules", {
  r <- tabular:::resolve_rules("grid")
  for (k in tabular:::.tabular_rule_keys) {
    expect_false(is.null(r[[k]]), info = k)
  }
})

test_that("resolve_rules frame turns on only the four outer edges", {
  r <- tabular:::resolve_rules("frame")
  expect_false(is.null(r$toprule))
  expect_false(is.null(r$bottomrule))
  expect_false(is.null(r$leftrule))
  expect_false(is.null(r$rightrule))
  expect_null(r$midrule)
  expect_null(r$spanrule)
  expect_null(r$rowrule)
  expect_null(r$colrule)
  expect_null(r$footnoterule)
})

test_that("resolve_rules none turns off every rule", {
  r <- tabular:::resolve_rules("none")
  for (k in tabular:::.tabular_rule_keys) {
    expect_null(r[[k]], info = k)
  }
})

test_that("resolve_rules rejects an unknown preset", {
  expect_error(
    tabular:::resolve_rules("booktab"),
    class = "tabular_error_input"
  )
})

# ---- resolve_rules: single-brdr broadcast ---------------------------

test_that("resolve_rules broadcasts a single brdr to active rules only", {
  r <- tabular:::resolve_rules(brdr(color = "black", width = 0.75))
  # Active baseline rules are recoloured / reweighted.
  expect_identical(r$toprule$color, "black")
  expect_identical(r$toprule$width, 0.75)
  expect_identical(r$spanrule$color, "black")
  expect_identical(r$bottomrule$width, 0.75)
  # Off baseline rules stay off (footnoterule is off by default).
  expect_null(r$footnoterule)
  expect_null(r$rowrule)
  expect_null(r$colrule)
})

# ---- resolve_rules: named-list overlay ------------------------------

test_that("resolve_rules overlays a named list onto the baseline", {
  r <- tabular:::resolve_rules(list(midrule = brdr(width = 0.75)))
  expect_identical(r$midrule$width, 0.75)
  # Unlisted rules keep their baseline default.
  expect_identical(r$toprule$width, tabular:::.tabular_rule_width)
  expect_false(is.null(r$bottomrule))
})

test_that("resolve_rules rowrule on reproduces the old hlines='all'", {
  r <- tabular:::resolve_rules(list(rowrule = brdr()))
  expect_false(is.null(r$rowrule))
  expect_identical(r$rowrule$style, "solid")
})

test_that("each of the nine rules is individually droppable", {
  for (k in tabular:::.tabular_rule_keys) {
    spec <- stats::setNames(list(brdr(style = "none")), k)
    r <- tabular:::resolve_rules(spec)
    expect_null(r[[k]], info = k)
  }
})

test_that("resolve_rules drops a rule via the 'none' string too", {
  r <- tabular:::resolve_rules(list(midrule = "none"))
  expect_null(r$midrule)
})

test_that("resolve_rules rejects an unknown rule name", {
  expect_error(
    tabular:::resolve_rules(list(notarule = brdr())),
    class = "tabular_error_input"
  )
})

test_that("resolve_rules rejects a non-rule input", {
  expect_error(
    tabular:::resolve_rules(42),
    class = "tabular_error_input"
  )
})

# ---- resolve_spacing ------------------------------------------------

test_that("resolve_spacing returns the title defaults", {
  sp <- tabular:::resolve_spacing(NULL)
  expect_identical(sp$title[["above"]], 1L)
  expect_identical(sp$title[["below"]], 1L)
  expect_identical(sp$body[["above"]], 0L)
  expect_identical(sp$footnote[["above"]], 0L)
})

test_that("resolve_spacing overlays a partial spec", {
  sp <- tabular:::resolve_spacing(list(body = c(above = 2)))
  expect_identical(sp$body[["above"]], 2L)
  expect_identical(sp$body[["below"]], 0L)
  expect_identical(sp$title[["above"]], 1L)
})

test_that("resolve_spacing rejects an unknown region", {
  expect_error(
    tabular:::resolve_spacing(list(header = c(above = 1))),
    class = "tabular_error_input"
  )
})

test_that("resolve_spacing rejects a below side on footnote", {
  expect_error(
    tabular:::resolve_spacing(list(footnote = c(below = 1))),
    class = "tabular_error_input"
  )
})

test_that("resolve_spacing rejects a negative or non-integer gap", {
  expect_error(
    tabular:::resolve_spacing(list(body = c(above = -1))),
    class = "tabular_error_input"
  )
  expect_error(
    tabular:::resolve_spacing(list(body = c(above = 1.5))),
    class = "tabular_error_input"
  )
})

# ---- gap_counts: max-adjacency --------------------------------------

test_that("gap_counts resolves adjoining sides to the max, not the sum", {
  # title.below = 1 and body.above = 1 target the same physical gap.
  g <- tabular:::gap_counts(list(
    title = c(below = 1),
    body = c(above = 1)
  ))
  expect_identical(unname(g[["title_to_body"]]), 1L)
})

test_that("gap_counts body_to_footnote takes the larger contributor", {
  g <- tabular:::gap_counts(list(
    body = c(below = 1),
    footnote = c(above = 3)
  ))
  expect_identical(unname(g[["body_to_footnote"]]), 3L)
})

test_that("gap_counts default has one blank gap above and below title", {
  g <- tabular:::gap_counts(NULL)
  expect_identical(unname(g[["above_title"]]), 1L)
  expect_identical(unname(g[["title_to_body"]]), 1L)
})

# ---- resolve_stripe -------------------------------------------------

test_that("resolve_stripe NULL is off", {
  expect_null(tabular:::resolve_stripe(NULL))
})

test_that("resolve_stripe single fill stripes even rows only", {
  s <- tabular:::resolve_stripe("#f6f6f6")
  expect_true(is.na(s[["odd"]]))
  expect_identical(unname(s[["even"]]), "#f6f6f6")
})

test_that("resolve_stripe named vector keeps both fills", {
  s <- tabular:::resolve_stripe(c(odd = "#fff", even = "#f6f6f6"))
  expect_identical(unname(s[["odd"]]), "#fff")
  expect_identical(unname(s[["even"]]), "#f6f6f6")
})

test_that("resolve_stripe rejects an unknown name", {
  expect_error(
    tabular:::resolve_stripe(c(top = "#fff")),
    class = "tabular_error_input"
  )
})

# ---- .fidelity_warn dedup -------------------------------------------

test_that(".fidelity_warn warns once per (feature, backend) per render", {
  tabular:::.fidelity_warn_reset()
  expect_warning(
    tabular:::.fidelity_warn("vertical padding", "latex"),
    class = "tabular_warning_fidelity"
  )
  # Second identical call is silent.
  expect_silent(tabular:::.fidelity_warn("vertical padding", "latex"))
  # A different feature warns again.
  expect_warning(
    tabular:::.fidelity_warn("decimal align", "latex"),
    class = "tabular_warning_fidelity"
  )
  tabular:::.fidelity_warn_reset()
})

# ---- resolver edge branches (coverage) ------------------------------

test_that(".resolve_rule_color passes NA / NULL / non-token through", {
  expect_true(is.na(tabular:::.resolve_rule_color(NA_character_)))
  expect_null(tabular:::.resolve_rule_color(NULL))
  expect_identical(tabular:::.resolve_rule_color("#abcdef"), "#abcdef")
  expect_identical(
    tabular:::.resolve_rule_color("ink"),
    tabular:::.tabular_ink
  )
})

test_that(".rule_entry_to_triple accepts a bare list(style, width, color)", {
  out <- tabular:::.rule_entry_to_triple(
    list(style = "solid", width = 0.5, color = "ink")
  )
  expect_identical(out$style, "solid")
  # A bare list whose style is 'none' clears the rule.
  expect_null(
    tabular:::.rule_entry_to_triple(
      list(style = "none", width = 0.5, color = "ink")
    )
  )
})

test_that("resolve_spacing rejects a non-list spacing", {
  expect_error(
    tabular:::resolve_spacing(1L),
    class = "tabular_error_input"
  )
})

test_that("resolve_stripe rejects a non-character / NA stripe", {
  expect_error(tabular:::resolve_stripe(1L), class = "tabular_error_input")
  expect_error(
    tabular:::resolve_stripe(NA_character_),
    class = "tabular_error_input"
  )
})

test_that("gap_counts treats a missing region side as a zero gap", {
  # A pre-resolved spacing list with `body` missing its `above` side:
  # the `g()` lookup returns NULL and collapses to 0L.
  # `body` as an empty list -> the `g()` lookup returns NULL (not an
  # out-of-bounds error) and collapses to a 0L gap.
  sp <- list(
    title = c(above = 1L, below = 1L),
    body = list(),
    subgroup = c(above = 0L, below = 0L),
    footnote = c(above = 0L)
  )
  g <- gap_counts(sp)
  expect_identical(unname(g[["above_title"]]), 1L)
  expect_identical(unname(g[["title_to_body"]]), 1L)
})

# ---- subgroup default gap (F3) --------------------------------------

test_that("gap_counts default has one blank gap above and below subgroup", {
  g <- tabular:::gap_counts(NULL)
  expect_identical(unname(g[["subgroup_above"]]), 1L)
  expect_identical(unname(g[["subgroup_to_body"]]), 1L)
})

test_that("resolve_spacing subgroup defaults are 1/1", {
  sp <- tabular:::resolve_spacing(NULL)
  expect_identical(sp$subgroup[["above"]], 1L)
  expect_identical(sp$subgroup[["below"]], 1L)
})
