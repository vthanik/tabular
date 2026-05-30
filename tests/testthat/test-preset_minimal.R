# preset_minimal() — the one named theme helper: midrule-only rules +
# normal weight on every bold-by-default surface (title, headers,
# subgroup banner, group-header section rows).

# A two-band table with `usage = "group"` section-header rows on every
# backend-facing surface (title, column headers, group headers).
mk_group_spec <- function() {
  d <- data.frame(
    soc = c("Infections", "Infections", "Cardiac", "Cardiac"),
    label = c("Pneumonia", "Sepsis", "MI", "AF"),
    placebo = c("1", "2", "3", "4")
  )
  tabular(d, titles = "Adverse Events", footnotes = "Note 1.") |>
    cols(
      label = col_spec(label = "PT"),
      soc = col_spec(usage = "group", group_display = "header_row"),
      placebo = col_spec(label = "Placebo")
    )
}

render_str <- function(spec, ext) {
  f <- withr::local_tempfile(fileext = ext, .local_envir = parent.frame())
  suppressWarnings(emit(spec, f))
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# ---------------------------------------------------------------------
# Shape + knob contract
# ---------------------------------------------------------------------

test_that("preset_minimal() returns a tabular_spec", {
  expect_true(is_tabular_spec(preset_minimal(mk_group_spec())))
})

test_that("preset_minimal() rejects a user-supplied rules / borders knob (#edge14)", {
  expect_error(
    preset_minimal(mk_group_spec(), rules = "grid"),
    class = "tabular_error_input"
  )
  expect_error(
    preset_minimal(mk_group_spec(), borders = "all"),
    class = "tabular_error_input"
  )
  expect_snapshot(
    error = TRUE,
    preset_minimal(mk_group_spec(), rules = "grid")
  )
})

test_that("preset_minimal() forwards geometry knobs to preset() (#edge15)", {
  spec <- preset_minimal(mk_group_spec(), font_size = 8, paper_size = "a4")
  expect_identical(spec@preset@font_size, 8)
  expect_identical(spec@preset@paper_size, "a4")
})

# ---------------------------------------------------------------------
# Midrule-only rules + all-normal weight, cross-backend
# ---------------------------------------------------------------------

test_that("preset_minimal() keeps the midrule (and spanrule) but drops the frame (LaTeX)", {
  tex <- render_str(preset_minimal(mk_group_spec()), ".tex")
  hlines <- regmatches(tex, gregexpr("hline\\{[0-9]+\\}", tex))[[1]]
  # `mk_group_spec()` has no column spanner, so the kept spanrule draws
  # nothing here: exactly one horizontal rule, the midrule under the
  # column labels (no toprule / bottomrule frame).
  expect_length(hlines, 1L)
})

test_that("preset_minimal() inserts one blank line above the footnotes (replaces the dropped bottomrule)", {
  # The minimal theme drops the bottomrule, so a blank line above the
  # footnote block stands in to keep it separated from the body.
  min_html <- render_str(preset_minimal(mk_group_spec()), ".html")
  def_html <- render_str(mk_group_spec(), ".html")
  pad_before_foot <- "<p class=\"tabular-pad\">&nbsp;</p>\\s*<p class=\"tabular-footnote"
  expect_match(min_html, pad_before_foot)
  # The default theme (with its bottomrule) inserts no footnote pad.
  expect_no_match(def_html, pad_before_foot)
})

test_that("the `spacing` knob footnote gap renders a blank above the footnotes (cross-backend)", {
  # Regression: `body_to_footnote` (max of body.below / footnote.above)
  # was computed in meta$gaps but consumed by no backend. Now wired.
  base <- mk_group_spec()
  spaced <- base |> preset(spacing = list(footnote = c(above = 1L)))
  pad_before_foot <- "<p class=\"tabular-pad\">&nbsp;</p>\\s*<p class=\"tabular-footnote"
  expect_match(render_str(spaced, ".html"), pad_before_foot)
  expect_no_match(render_str(base, ".html"), pad_before_foot)
})

test_that("preset_minimal() renders every surface in normal weight, cross-backend", {
  m <- preset_minimal(mk_group_spec())
  # LaTeX: no \textbf anywhere (title rides a separate path; headers +
  # group rows are the in-table surfaces).
  expect_false(grepl("\\textbf", render_str(m, ".tex"), fixed = TRUE))
  # HTML: no <strong> on the group-header rows; the title / header
  # surfaces carry an inline font-weight: normal that beats the class.
  html <- render_str(m, ".html")
  expect_false(grepl("<strong>", html, fixed = TRUE))
  expect_match(html, "font-weight: normal")
  # RTF: no bold group on the section rows.
  expect_false(grepl("{\\b ", render_str(m, ".rtf"), fixed = TRUE))
  # Markdown: no ** emphasis.
  expect_false(grepl("**", render_str(m, ".md"), fixed = TRUE))
})

# ---------------------------------------------------------------------
# Theme precedence — last verb wins (#edge6)
# ---------------------------------------------------------------------

test_that("an explicit style() after preset_minimal() re-bolds a surface (#edge6)", {
  m <- preset_minimal(mk_group_spec()) |>
    style(bold = TRUE, .at = cells_group_headers())
  # The group-header section rows are bold again (later layer wins).
  expect_true(grepl(
    "\\textbf{Infections}",
    render_str(m, ".tex"),
    fixed = TRUE
  ))
})

# ---------------------------------------------------------------------
# No group column — no header rows, no error (#edge8)
# ---------------------------------------------------------------------

test_that("preset_minimal() is a no-op-safe theme on a table with no group column (#edge8)", {
  spec <- tabular(data.frame(x = 1:2, y = c("a", "b")), titles = "T") |>
    preset_minimal()
  expect_true(is_tabular_spec(spec))
  html <- render_str(spec, ".html")
  # Title rendered in normal weight; no group-header rows present.
  expect_match(html, "font-weight: normal")
  # No group-header ROW present (the `.tabular-group-header` CSS class
  # definition always ships in the stylesheet, so match the row tag).
  expect_false(grepl(
    "<tr class=\"tabular-group-header\">",
    html,
    fixed = TRUE
  ))
})
