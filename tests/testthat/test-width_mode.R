# L3 width_mode on preset_spec — table-level column-sizing policy.
#
# Mirrors Word's Table Layout menu (Auto-fit Contents / Auto-fit
# Window / Fixed Column Width). Single knob per table; per-column
# pinning happens via col_spec(width = ...) and is layered on top.

# ---------------------------------------------------------------------
# preset_spec validator
# ---------------------------------------------------------------------

test_that("preset_spec defaults width_mode to 'content' (today's behavior)", {
  ps <- preset_spec()
  expect_equal(ps@width_mode, "content")
})

test_that("preset_spec accepts every value in the enum", {
  for (mode in c("content", "window", "fixed")) {
    ps <- preset_spec(width_mode = mode)
    expect_equal(ps@width_mode, mode, info = mode)
  }
})

test_that("preset_spec rejects an unknown width_mode", {
  expect_error(preset_spec(width_mode = "nope"))
})

test_that("preset() user verb accepts width_mode and passes it through", {
  spec <- tabular(saf_demo) |> preset(width_mode = "window")
  eff <- tabular:::.effective_preset(spec)
  expect_equal(eff@width_mode, "window")
})

# ---------------------------------------------------------------------
# .distribute_widths() dispatch on mode
# ---------------------------------------------------------------------

test_that(".distribute_widths() default mode='content' preserves natural-fit (no expansion)", {
  widths <- list(
    a = list(kind = "auto", value = 1.0),
    b = list(kind = "auto", value = 1.5)
  )
  out <- tabular:::.distribute_widths(
    widths,
    available = 8.0,
    mode = "content"
  )
  # Auto cols sum to 2.5 in; remaining is 8 in. Natural fit -> don't expand.
  expect_equal(unname(out["a"]), 1.0)
  expect_equal(unname(out["b"]), 1.5)
})

test_that(".distribute_widths() mode='window' expands auto cols to share the residual equally", {
  widths <- list(
    a = list(kind = "pin", value = 2.0),
    b = list(kind = "auto", value = 1.0),
    c = list(kind = "auto", value = 1.5)
  )
  out <- tabular:::.distribute_widths(
    widths,
    available = 8.0,
    mode = "window"
  )
  expect_equal(unname(out["a"]), 2.0)
  # Remaining = 8 - 2 = 6 in; split equally across 2 auto cols -> 3 each.
  expect_equal(unname(out["b"]), 3.0)
  expect_equal(unname(out["c"]), 3.0)
})

test_that(".distribute_widths() mode='window' with single auto col claims entire residual", {
  widths <- list(
    a = list(kind = "pin", value = 1.5),
    b = list(kind = "auto", value = 0.5)
  )
  out <- tabular:::.distribute_widths(
    widths,
    available = 6.5,
    mode = "window"
  )
  expect_equal(unname(out["b"]), 5.0)
})

test_that(".distribute_widths() mode='fixed' collapses auto cols to the minimum width", {
  widths <- list(
    a = list(kind = "pin", value = 2.0),
    b = list(kind = "auto", value = 1.0)
  )
  out <- tabular:::.distribute_widths(widths, available = 8.0, mode = "fixed")
  expect_equal(unname(out["a"]), 2.0)
  expect_equal(unname(out["b"]), tabular:::.min_auto_width_in)
})

test_that(".distribute_widths() mode='content' keeps natural width on overflow + warns", {
  # Word AutoFit-to-Contents: auto columns are NEVER silently shrunk.
  # When the natural total overflows the page, columns keep their
  # measured width and a tabular_warn_layout fires so the user can
  # set explicit widths or switch width_mode.
  widths <- list(
    a = list(kind = "pin", value = 3.0),
    b = list(kind = "auto", value = 4.0),
    c = list(kind = "auto", value = 6.0)
  )
  expect_warning(
    tabular:::.distribute_widths(widths, available = 10.0, mode = "content"),
    class = "tabular_warn_layout"
  )
  out <- suppressWarnings(
    tabular:::.distribute_widths(widths, available = 10.0, mode = "content")
  )
  # No shrink: auto columns keep their natural widths; the table
  # overflows (3 + 4 + 6 = 13 > 10).
  expect_equal(unname(out["a"]), 3.0)
  expect_equal(unname(out["b"]), 4.0)
  expect_equal(unname(out["c"]), 6.0)
})

# ---------------------------------------------------------------------
# Boundary cases
# ---------------------------------------------------------------------

test_that(".distribute_widths() with no auto cols returns pin + pct unchanged regardless of mode", {
  widths <- list(
    a = list(kind = "pin", value = 2.0),
    b = list(kind = "pct", value = 25)
  )
  for (mode in c("content", "window", "fixed")) {
    out <- tabular:::.distribute_widths(widths, available = 8.0, mode = mode)
    expect_equal(unname(out["a"]), 2.0, info = mode)
    expect_equal(unname(out["b"]), 2.0, info = mode) # 25% of 8
  }
})

test_that(".distribute_widths() warns when pinned widths overflow regardless of mode", {
  widths <- list(
    a = list(kind = "pin", value = 10.0),
    b = list(kind = "auto", value = 1.0)
  )
  expect_warning(
    tabular:::.distribute_widths(widths, available = 8.0, mode = "window"),
    class = "tabular_warn_layout"
  )
})

# ---------------------------------------------------------------------
# End-to-end: as_grid() respects preset@width_mode
# ---------------------------------------------------------------------

test_that("as_grid() under preset(width_mode='window') expands auto columns to fill the page", {
  spec <- tabular(saf_demo) |> preset(width_mode = "window")
  grid <- as_grid(spec)
  cols_resolved <- grid@metadata$cols
  total <- sum(vapply(cols_resolved, function(cs) cs@width, numeric(1L)))
  available <- tabular:::.available_content_width(
    tabular:::.effective_preset(spec)
  )
  # In window mode, auto cols fill the residual; total ~= available.
  expect_equal(total, available, tolerance = 1e-6)
})

test_that("as_grid() under preset(width_mode='fixed') collapses auto cols to the minimum", {
  # Use group_display='column' so the variable column stays visible;
  # otherwise header_row mode hides it and the test's expectation
  # about variable@width going to .min_auto_width_in is moot.
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo", width = 1.5)
    ) |>
    preset(width_mode = "fixed")
  grid <- as_grid(spec)
  cols_resolved <- grid@metadata$cols
  # The pinned column survives; the two auto cols collapse to min.
  expect_equal(cols_resolved$placebo@width, 1.5)
  expect_equal(
    cols_resolved$variable@width,
    tabular:::.min_auto_width_in
  )
  expect_equal(
    cols_resolved$stat_label@width,
    tabular:::.min_auto_width_in
  )
})

test_that("as_grid() under default preset(width_mode='content') matches today's behavior", {
  spec_default <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  spec_explicit <- tabular(saf_demo) |>
    cols(
      variable = col_spec(
        usage = "group",
        label = "Characteristic",
        group_display = "column"
      ),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    preset(width_mode = "content")
  g1 <- as_grid(spec_default)
  g2 <- as_grid(spec_explicit)
  # Resolved widths byte-identical between default and explicit content.
  w1 <- vapply(g1@metadata$cols, function(cs) cs@width, numeric(1L))
  w2 <- vapply(g2@metadata$cols, function(cs) cs@width, numeric(1L))
  expect_equal(w1, w2)
})
