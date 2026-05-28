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
  # text. Use a long single word (no ASCII space) so header-by-word
  # auto-fit measures the whole string against the full-line body, and
  # the string is long enough that the .min_auto_width_in floor doesn't
  # clamp both to the same value.
  p <- preset_spec(font_family = "sans", font_size = 10)
  txt <- "Treatment-Emergent-Adverse-Events"
  hdr_only <- tabular:::.compute_col_width(character(0L), header = txt, p)
  body_only <- tabular:::.compute_col_width(c(txt), header = "", p)
  expect_true(hdr_only > body_only)
})

# ---------------------------------------------------------------------
# Auto-fit "by word" (header) — HTML parity (wraps at ASCII spaces;
# NBSP non-breaking; body never wraps)
# ---------------------------------------------------------------------

test_that(".compute_col_width sizes the header to its widest WORD, not its line", {
  p <- preset_spec()
  # "n, median" wraps at the ASCII space, so the column sizes to the
  # widest word ("median"), letting Word/LaTeX wrap the header.
  w_phrase <- tabular:::.compute_col_width(c("12", "45.6"), "n, median", p)
  w_word <- tabular:::.compute_col_width(c("12", "45.6"), "median", p)
  expect_equal(w_phrase, w_word)
})

test_that(".compute_col_width keeps an NBSP header whole (non-breaking)", {
  p <- preset_spec()
  nbsp <- " "
  w_nbsp <- tabular:::.compute_col_width(
    "12",
    paste0("Mean", nbsp, "(SD)"),
    p
  )
  w_space <- tabular:::.compute_col_width("12", "Mean (SD)", p)
  # NBSP is not a break point, so the column must hold the full string;
  # the space-separated variant only needs its widest word.
  expect_gt(w_nbsp, w_space)
})

test_that(".compute_col_width never word-splits BODY cells (numerics never wrap)", {
  p <- preset_spec()
  # A body value with a space sizes the column to its full width (no
  # word-split), so it never wraps; the header is empty here.
  w_body <- tabular:::.compute_col_width("Active 100 mg", "", p)
  w_word <- tabular:::.compute_col_width("Active", "", p)
  expect_gt(w_body, w_word)
})

test_that(".compute_col_width floors an empty / whitespace-only header", {
  p <- preset_spec()
  w_empty <- tabular:::.compute_col_width("1", "", p)
  w_spaces <- tabular:::.compute_col_width("1", "   ", p)
  # Whitespace-only header contributes no word width; both fall back to
  # the body / floor and agree.
  expect_equal(w_empty, w_spaces)
})

test_that(".compute_col_width breaks a multi-line header on \\n (author break)", {
  p <- preset_spec()
  # "Difference\nN=12" -> author break -> widest word is "Difference",
  # narrower than the same characters as one unbroken word.
  w_ml <- tabular:::.compute_col_width("1", "Difference\nN=12", p)
  w_joined <- tabular:::.compute_col_width("1", "DifferenceN=12", p)
  expect_lt(w_ml, w_joined)
})

test_that("preset_spec carries cell_padding_h default 5.4 (padding SSOT)", {
  expect_equal(preset_spec()@cell_padding_h, 5.4)
})

test_that("cell_padding_h is settable via preset(), scalar or c(left, right)", {
  p1 <- preset(tabular(data.frame(x = 1)), cell_padding_h = 3)
  expect_equal(p1@preset@cell_padding_h, 3)
  p2 <- preset(tabular(data.frame(x = 1)), cell_padding_h = c(2, 4))
  expect_equal(p2@preset@cell_padding_h, c(2, 4))
})

test_that(".cell_padding_lr broadcasts a scalar and passes a pair through", {
  expect_equal(tabular:::.cell_padding_lr(preset_spec()), c(5.4, 5.4))
  expect_equal(
    tabular:::.cell_padding_lr(preset_spec(cell_padding_h = c(2, 4))),
    c(2, 4)
  )
})

test_that(".compute_col_width adds the total horizontal padding (padding SSOT)", {
  # Measurement adds left + right from cell_padding_h, not a hardcoded
  # constant. Width gains pad_h_pt / 72 inches.
  p <- preset_spec(font_family = "serif", font_size = 10)
  w_default <- tabular:::.compute_col_width(c("Placebo"), header = "", p)
  w_explicit <- tabular:::.compute_col_width(
    c("Placebo"),
    header = "",
    p,
    pad_h_pt = 10.8 # 2 * 5.4
  )
  expect_equal(w_default, w_explicit)

  # A c(left, right) preset sums to the same total as a scalar of the
  # average, so the measured width matches.
  p_pair <- preset_spec(
    font_family = "serif",
    font_size = 10,
    cell_padding_h = c(2, 4)
  )
  expect_equal(
    tabular:::.compute_col_width(c("Placebo"), header = "", p_pair),
    tabular:::.compute_col_width(c("Placebo"), header = "", p, pad_h_pt = 6)
  )
})

test_that(".resolve_col_widths measures with body padding override (padding SSOT)", {
  # A body @padding override (preset(padding = list(body = N)) or
  # style(at = cells_body(), padding = N)) must drive measurement, not just
  # render. `.resolve_col_widths` reads the resolved cells_style padding so
  # auto widths track the rendered cell margin.
  spec <- tabular(data.frame(grp = c("A", "B"), n = c("10", "20"))) |>
    cols(grp = col_spec(width = "auto"), n = col_spec(width = "auto"))
  cells_text <- matrix(
    c("A", "B", "10", "20"),
    nrow = 2,
    dimnames = list(NULL, c("grp", "n"))
  )
  labels <- list(
    grp = tabular:::parse_inline("grp"),
    n = tabular:::parse_inline("n")
  )

  none <- tabular:::.resolve_col_widths(spec, cells_text, labels)

  pad20 <- matrix(
    list(
      tabular:::style_node(padding = 20),
      tabular:::style_node(padding = 20),
      tabular:::style_node(padding = 20),
      tabular:::style_node(padding = 20)
    ),
    nrow = 2
  )
  widened <- tabular:::.resolve_col_widths(
    spec,
    cells_text,
    labels,
    cells_style = pad20
  )

  # 20pt/side vs 5.4pt default -> each auto col gains 2 * (20 - 5.4) / 72 in.
  expect_equal(
    widened[["grp"]]@width - none[["grp"]]@width,
    2 * (20 - 5.4) / 72,
    tolerance = 1e-9
  )
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

test_that(".distribute_widths keeps natural auto width on overflow + warns", {
  widths <- list(
    a = list(kind = "auto", value = 4),
    b = list(kind = "auto", value = 4),
    c = list(kind = "auto", value = 2)
  )
  # Sum 10 > available 5: Word AutoFit-to-Contents keeps natural
  # widths and warns instead of shrinking.
  expect_warning(
    tabular:::.distribute_widths(widths, available = 5),
    class = "tabular_warn_layout"
  )
  result <- suppressWarnings(
    tabular:::.distribute_widths(widths, available = 5)
  )
  expect_equal(unname(result), c(4, 4, 2))
})

test_that(".distribute_widths preserves pinned, keeps natural auto on remainder", {
  widths <- list(
    pinned = list(kind = "pin", value = 3),
    a = list(kind = "auto", value = 3),
    b = list(kind = "auto", value = 3)
  )
  # available = 5, pinned = 3, remaining = 2, auto sum = 6 > 2:
  # autos keep natural width (3 each) and the call warns.
  expect_warning(
    tabular:::.distribute_widths(widths, available = 5),
    class = "tabular_warn_layout"
  )
  result <- suppressWarnings(
    tabular:::.distribute_widths(widths, available = 5)
  )
  expect_equal(unname(result), c(3, 3, 3))
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

test_that("preset_spec validates cell_padding_h length + sign (padding SSOT)", {
  # Length 1 (both sides) and 2 (left, right) are valid.
  expect_true(is_preset_spec(preset_spec(cell_padding_h = 4)))
  expect_true(is_preset_spec(preset_spec(cell_padding_h = c(2, 4))))
  # Length 3, negative, or NA are rejected.
  expect_error(preset_spec(cell_padding_h = c(1, 2, 3)), "cell_padding_h")
  expect_error(preset_spec(cell_padding_h = -1), "cell_padding_h")
  expect_error(preset_spec(cell_padding_h = c(1, NA)), "cell_padding_h")
})
