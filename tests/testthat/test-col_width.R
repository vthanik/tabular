test_that(".available_content_width handles letter portrait + landscape", {
  # Letter portrait, 1in all sides -> 8.5 - 2 = 6.5
  p <- preset_spec(
    paper_size = "letter",
    orientation = "portrait",
    margins = 1
  )
  expect_equal(tabular:::.available_content_width(p), 6.5)

  # Letter landscape, 1in all sides -> 11 - 2 = 9
  p_land <- preset_spec(
    paper_size = "letter",
    orientation = "landscape",
    margins = 1
  )
  expect_equal(tabular:::.available_content_width(p_land), 9)
})

test_that(".available_content_width handles A4 + dim-string margins", {
  # A4 portrait, 2cm all sides -> 8.27 - 2 * (2/2.54) ≈ 6.69
  p <- preset_spec(
    paper_size = "a4",
    orientation = "portrait",
    margins = "2cm"
  )
  expect_equal(
    tabular:::.available_content_width(p),
    8.27 - 2 * (2 / 2.54),
    tolerance = 1e-6
  )
})

test_that(".available_content_width handles 2-length (vertical horizontal) margins", {
  # margins = c("1in", "0.5in") -> 1in top/bottom, 0.5in left/right.
  # Content width = 8.5 - 0.5 - 0.5 = 7.5.
  p <- preset_spec(
    paper_size = "letter",
    orientation = "portrait",
    margins = c("1in", "0.5in")
  )
  expect_equal(tabular:::.available_content_width(p), 7.5)
})

test_that(".available_content_width handles 4-length CSS-shorthand margins", {
  # c(top, right, bottom, left) = c("1in", "0.25in", "1in", "0.75in")
  # Content width = 8.5 - 0.25 - 0.75 = 7.5.
  p <- preset_spec(
    paper_size = "letter",
    orientation = "portrait",
    margins = c("1in", "0.25in", "1in", "0.75in")
  )
  expect_equal(tabular:::.available_content_width(p), 7.5)
})

test_that(".compute_col_width orders short < medium < long content", {
  p <- preset_spec(font_family = "serif", font_size = 10)
  short <- tabular:::.compute_col_width(c("n", "5", "10"), header = "N", p)
  medium <- tabular:::.compute_col_width(
    c("Placebo", "Active 50mg", "Active 100mg"),
    header = "Treatment",
    p
  )
  long <- tabular:::.compute_col_width(
    c("Cardiac disorders", "Skin and subcutaneous tissue disorders"),
    header = "System Organ Class",
    p
  )
  expect_true(short < medium)
  expect_true(medium < long)
})

test_that(".compute_col_width floors empty content at .min_auto_width_in", {
  p <- preset_spec(font_family = "serif", font_size = 10)
  expect_equal(
    tabular:::.compute_col_width(character(0L), header = "", p),
    tabular:::.min_auto_width_in
  )
  expect_equal(
    tabular:::.compute_col_width(c("", "", ""), header = "", p),
    tabular:::.min_auto_width_in
  )
})

test_that(".compute_col_width takes max line for multi-line cells", {
  p <- preset_spec(font_family = "serif", font_size = 10)
  # Multi-line cell with one long line and one short line —
  # column should be wide enough for the long line, not the sum.
  multi_line <- tabular:::.compute_col_width(
    c("short\nMuch longer line here"),
    header = "",
    p
  )
  long_only <- tabular:::.compute_col_width(
    c("Much longer line here"),
    header = "",
    p
  )
  expect_equal(multi_line, long_only)
})

test_that(".compute_col_width scales with font_size", {
  p10 <- preset_spec(font_family = "serif", font_size = 10)
  p14 <- preset_spec(font_family = "serif", font_size = 14)
  # Same content, larger font -> wider column. Padding contributes
  # a fixed offset (independent of font size), so the ratio is
  # less than 14/10, but width must be strictly greater.
  w10 <- tabular:::.compute_col_width(c("Hello"), header = "", p10)
  w14 <- tabular:::.compute_col_width(c("Hello"), header = "", p14)
  expect_true(w14 > w10)
})

test_that(".compute_col_width uses bold AFM for header", {
  # When body is empty and header is the only content, bold
  # variant width is used. Helvetica-Bold em widths exceed
  # Helvetica regular widths -> bold header is wider for the same
  # text. Use a long-enough string so the .min_auto_width_in
  # floor doesn't clamp both to the same value.
  p <- preset_spec(font_family = "sans", font_size = 10)
  txt <- "Treatment-Emergent Adverse Events"
  hdr_only <- tabular:::.compute_col_width(character(0L), header = txt, p)
  body_only <- tabular:::.compute_col_width(c(txt), header = "", p)
  expect_true(hdr_only > body_only)
})

test_that(".distribute_widths is no-op when sum of pinned fits", {
  widths <- list(
    a = list(kind = "pin", value = 2),
    b = list(kind = "pin", value = 1.5),
    c = list(kind = "pin", value = 1)
  )
  result <- tabular:::.distribute_widths(widths, available = 6.5)
  expect_equal(unname(result), c(2, 1.5, 1))
})

test_that(".distribute_widths is no-op when sum of auto fits", {
  widths <- list(
    a = list(kind = "auto", value = 2),
    b = list(kind = "auto", value = 1.5),
    c = list(kind = "auto", value = 1)
  )
  result <- tabular:::.distribute_widths(widths, available = 6.5)
  # No expansion to fill: natural-fit semantics.
  expect_equal(unname(result), c(2, 1.5, 1))
})

test_that(".distribute_widths shrinks auto proportionally on overflow", {
  widths <- list(
    a = list(kind = "auto", value = 4),
    b = list(kind = "auto", value = 4),
    c = list(kind = "auto", value = 2)
  )
  # Sum is 10, available 5 -> shrink by half.
  result <- tabular:::.distribute_widths(widths, available = 5)
  expect_equal(unname(result), c(2, 2, 1))
  expect_equal(sum(result), 5)
})

test_that(".distribute_widths preserves pinned + shrinks auto on remainder", {
  widths <- list(
    pinned = list(kind = "pin", value = 3),
    a = list(kind = "auto", value = 3),
    b = list(kind = "auto", value = 3)
  )
  # available = 5, pinned = 3, remaining = 2, auto sum = 6,
  # shrink autos to 1 each.
  result <- tabular:::.distribute_widths(widths, available = 5)
  expect_equal(unname(result), c(3, 1, 1))
})

test_that(".distribute_widths resolves percent against available", {
  widths <- list(
    a = list(kind = "pct", value = 50),
    b = list(kind = "pct", value = 30),
    c = list(kind = "auto", value = 1)
  )
  # 50% of 10 = 5, 30% of 10 = 3, auto fits in remaining 2.
  result <- tabular:::.distribute_widths(widths, available = 10)
  expect_equal(unname(result), c(5, 3, 1))
})

test_that(".distribute_widths warns on pinned overflow", {
  widths <- list(
    a = list(kind = "pin", value = 10),
    b = list(kind = "auto", value = 1)
  )
  expect_warning(
    result <- tabular:::.distribute_widths(widths, available = 5),
    class = "tabular_warn_layout"
  )
  # Auto-sized column left at natural width (1), pin honoured (10).
  expect_equal(unname(result), c(10, 1))
})

test_that(".distribute_widths handles empty input", {
  expect_equal(
    tabular:::.distribute_widths(list(), available = 6.5),
    numeric(0L)
  )
})

test_that(".ast_flatten_text drops markup, preserves text", {
  ast_plain <- tabular:::parse_inline("plain text")
  expect_equal(tabular:::.ast_flatten_text(ast_plain), "plain text")

  ast_md <- tabular:::parse_inline(tabular::md("**bold** and *italic*"))
  # Should yield bare "bold and italic" with no asterisks.
  flat <- tabular:::.ast_flatten_text(ast_md)
  expect_false(grepl("\\*", flat))
  expect_true(grepl("bold", flat))
  expect_true(grepl("italic", flat))
})

test_that(".ast_flatten_text returns empty string for non-AST input", {
  expect_equal(tabular:::.ast_flatten_text(NULL), "")
  expect_equal(tabular:::.ast_flatten_text("not an ast"), "")
})
