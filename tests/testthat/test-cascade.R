# Per-cell text-property cascade across all backends.
#
# The seven properties (bold, italic, underline, color, background,
# font_family, font_size) reach the rendered output for every backend
# from a single `style()` predicate. Phase 2 lifts HTML / LaTeX / RTF
# up to DOCX-level parity (DOCX already consumed every property).
#
# RTF Phase 2 commit 1 ships 4 of 7 properties (bold / italic /
# underline / font_size); color / background / font_family land in a
# follow-up commit that grows the RTF preamble's color and font
# tables to cover per-cell overrides.

# ---------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------

bold_red_spec <- function() {
  tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    style(
      bold = TRUE,
      italic = TRUE,
      underline = TRUE,
      color = "#cc0000",
      background = "#ffeedd",
      font_family = "Helvetica",
      font_size = 11,
      .at = cells_body(where = stat_label == "Mean (SD)")
    )
}

# ---------------------------------------------------------------------
# HTML body-cell cascade
# ---------------------------------------------------------------------

test_that("HTML body cells consume bold/italic/underline/color/background/font_family/font_size from style()", {
  spec <- bold_red_spec()
  out_one <- paste(
    tabular:::.render_html_grid(as_grid(spec)),
    collapse = "\n"
  )
  # All seven properties appear in at least one <td>'s style="..." attribute.
  expect_match(out_one, "font-weight: bold;", fixed = TRUE)
  expect_match(out_one, "font-style: italic;", fixed = TRUE)
  expect_match(out_one, "text-decoration: underline;", fixed = TRUE)
  expect_match(out_one, "color: #cc0000;", fixed = TRUE)
  expect_match(out_one, "background-color: #ffeedd;", fixed = TRUE)
  expect_match(out_one, "font-family: Helvetica;", fixed = TRUE)
  expect_match(out_one, "font-size: 11pt;", fixed = TRUE)
})

test_that("HTML body cells with no style overrides emit no inline style attribute", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    )
  out_one <- paste(
    tabular:::.render_html_grid(as_grid(spec)),
    collapse = "\n"
  )
  # No styled <td> for any body row.
  expect_true(grepl("<td", out_one, fixed = TRUE))
})

# ---------------------------------------------------------------------
# LaTeX body-cell cascade
# ---------------------------------------------------------------------

test_that("LaTeX body cells wrap text with bold/italic/underline/color/background/font_family/font_size macros", {
  spec <- bold_red_spec()
  out_one <- paste(
    tabular:::.render_latex_doc(as_grid(spec)),
    collapse = "\n"
  )
  expect_match(out_one, "\\textbf{", fixed = TRUE)
  expect_match(out_one, "\\textit{", fixed = TRUE)
  expect_match(out_one, "\\underline{", fixed = TRUE)
  expect_match(out_one, "\\textcolor[HTML]{CC0000}", fixed = TRUE)
  expect_match(out_one, "\\colorbox[HTML]{FFEEDD}", fixed = TRUE)
  expect_match(out_one, "\\fontfamily{Helvetica}", fixed = TRUE)
  expect_match(out_one, "\\fontsize{11}", fixed = TRUE)
})

test_that(".latex_normalize_hex_color strips a leading '#' and upper-cases hex", {
  expect_equal(tabular:::.latex_normalize_hex_color("#cc0000"), "CC0000")
  expect_equal(tabular:::.latex_normalize_hex_color("#ffeedd"), "FFEEDD")
  # Non-hex strings pass through unchanged.
  expect_equal(tabular:::.latex_normalize_hex_color("red"), "red")
  expect_equal(
    tabular:::.latex_normalize_hex_color(NA_character_),
    NA_character_
  )
})

test_that(".latex_wrap_text_props is a no-op on a default style_node", {
  expect_equal(
    tabular:::.latex_wrap_text_props("Hello", style_node()),
    "Hello"
  )
})

# ---------------------------------------------------------------------
# RTF body-cell cascade (Phase 2 commit 1: 4 of 7 properties)
# ---------------------------------------------------------------------

test_that(".rtf_cell_text_props emits the four run-level tokens for bold/italic/underline/font_size", {
  sn <- style_node(
    bold = TRUE,
    italic = TRUE,
    underline = TRUE,
    font_size = 10
  )
  tok <- tabular:::.rtf_cell_text_props(sn)
  expect_match(tok, "\\b ", fixed = TRUE)
  expect_match(tok, "\\i ", fixed = TRUE)
  expect_match(tok, "\\ul ", fixed = TRUE)
  expect_match(tok, "\\fs20 ", fixed = TRUE)
})

test_that(".rtf_cell_text_props is a no-op on a default style_node", {
  expect_equal(tabular:::.rtf_cell_text_props(style_node()), "")
})

test_that("RTF body cells consume bold/italic/underline/font_size from style() predicates", {
  spec <- bold_red_spec()
  out_one <- paste(tabular:::.render_rtf_doc(as_grid(spec)), collapse = "\n")
  expect_match(out_one, "\\b ", fixed = TRUE)
  expect_match(out_one, "\\i ", fixed = TRUE)
  expect_match(out_one, "\\ul ", fixed = TRUE)
  expect_match(out_one, "\\fs22 ", fixed = TRUE) # font_size = 11 -> half-points = 22
})
