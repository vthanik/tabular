# engine_decimal() — decimal-mark alignment with cross-shape support.
#
# Tests are organised in three layers:
#   1. Pure single-shape columns       — every clinical-canonical shape
#                                         alone in a column.
#   2. Cross-shape mixing              — the bug class galley shipped
#                                         broken; integer rows mixed
#                                         with float / n_pct rows.
#   3. Edge cases + engine_decimal()   — degenerate inputs and the
#                                         matrix-level public entry.
#
# Visual outputs are pinned with `expect_snapshot()` so the column-
# wise alignment can be inspected at review time without trusting the
# test asserts alone.

# Helper: the per-column workhorse is internal; call it through
# triple-colon. The top-level `engine_decimal()` is also internal.
#
# The helper defaults `pad = " "` (ASCII space) so existing
# `expect_equal()` assertions stay readable; the public
# `engine_decimal()` defaults to U+00A0 NBSP for production
# rendering. Likewise `zero_suppress` and `edge_trim` default OFF
# in the helper so Layer 1 - 7 tests are byte-stable; Layer 10
# tests opt them in explicitly.
align <- function(
  values,
  sections = NULL,
  not_considered = character(),
  pad = " ",
  zero_suppress = FALSE,
  edge_trim = FALSE
) {
  tabular:::.align_decimal_column(
    values,
    sections = sections,
    not_considered = not_considered,
    pad = pad,
    zero_suppress = zero_suppress,
    edge_trim = edge_trim
  )
}

# ---------------------------------------------------------------------
# Layer 1 — single-shape columns
# ---------------------------------------------------------------------

test_that("integer-only column right-aligns within int slot", {
  v <- c("1", "12", "123", "1234")
  out <- align(v)
  expect_equal(out, c("   1", "  12", " 123", "1234"))
  expect_true(all(nchar(out) == 4L))
})

test_that("float-only column aligns at the decimal mark", {
  v <- c("0.5", "12.34", "100.0", "0.123")
  out <- align(v)
  # int slot width 3 (max "100"); dec slot width 3 (max "123" or "34")
  expect_equal(
    out,
    c(
      "  0.5  ",
      " 12.34 ",
      "100.0  ",
      "  0.123"
    )
  )
  # Decimal point sits at the same column in every row.
  dot_pos <- regexpr("\\.", out)
  expect_true(all(dot_pos == dot_pos[[1L]]))
})

test_that("pvalue column aligns the comparator prefix", {
  v <- c("<0.001", "0.045", ">0.999", "=0.500")
  out <- align(v)
  # All rendered to the same width with prefix slot consuming 1 col.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # Comparators (or padding space for the unprefixed value) sit in
  # the leftmost column.
  expect_equal(
    substr(out, 1L, 1L),
    c("<", " ", ">", "=")
  )
})

test_that("n_pct column aligns on the n decimal anchor", {
  v <- c("85 (98.8)", "78 (90.7)", "8 (9.3)")
  out <- align(v)
  expect_equal(
    out,
    c(
      "85 (98.8)",
      "78 (90.7)",
      " 8 ( 9.3)"
    )
  )
  expect_true(all(nchar(out) == 9L))
})

test_that("n_over_n column aligns at the slash", {
  v <- c("5/86", "12/86", "100/86")
  out <- align(v)
  # Slash positions align.
  slash_pos <- regexpr("/", out)
  expect_true(all(slash_pos == slash_pos[[1L]]))
  expect_true(all(nchar(out) == nchar(out[[1L]])))
})

test_that("est_spread column aligns both primary and secondary floats", {
  v <- c("75.2 (8.59)", "76.0 (12.3)", "100.5 (0.1)")
  out <- align(v)
  expect_equal(
    out,
    c(
      " 75.2 ( 8.59)",
      " 76.0 (12.3 )",
      "100.5 ( 0.1 )"
    )
  )
})

test_that("est_ci column aligns three floats and the bracket positions", {
  v <- c("1.45 (1.20, 1.70)", "10.0 (8.5, 11.5)", "0.95 (0.50, 1.40)")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # est_ci has one comma per row (between lo and hi); it sits at the
  # same column position in every row.
  comma_pos <- regexpr(",", out)
  expect_true(all(comma_pos == comma_pos[[1L]]))
  # The opening paren also aligns.
  paren_pos <- regexpr("\\(", out)
  expect_true(all(paren_pos == paren_pos[[1L]]))
})

test_that("est_ci_bracket renders [ ] not ( )", {
  v <- c("1.45 [1.20, 1.70]", "0.95 [0.50, 1.40]")
  out <- align(v)
  expect_true(all(grepl("\\[", out)))
  expect_true(all(grepl("\\]", out)))
  expect_false(any(grepl("\\(", out)))
})

test_that("range_pair (paren form) aligns inside the parens", {
  v <- c("(69.2, 81.8)", "(0.5, 100.0)", "(1.0, 1.5)")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # Open parens align in the first column.
  expect_equal(substr(out, 1L, 1L), rep("(", 3))
})

test_that("range_pair (bare form) aligns at the comma split", {
  v <- c("69.2, 81.8", "0.5, 100.0", "1.0, 1.5")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[1L]])))
})

# ---------------------------------------------------------------------
# Layer 2 — cross-shape mixing (the bug class)
# ---------------------------------------------------------------------

test_that("integer N row aligns with the decimal of float rows (Total Duration scenario)", {
  # The canonical bug from the user's image: a stats block where the
  # first row is just an integer N=86 and the rest are floats with
  # one or two decimal places. The integer's units digit must sit at
  # the column position of the floats' int-slot right edge (i.e. one
  # column left of the decimal point).
  v <- c("86", "147.8", "62.13", "182.0", "0.0", "210.0")
  out <- align(v)
  expect_equal(
    out,
    c(
      " 86   ",
      "147.8 ",
      " 62.13",
      "182.0 ",
      "  0.0 ",
      "210.0 "
    )
  )
  # The decimal of every float row sits at the same column position.
  is_float <- grepl("\\.", v)
  dot_pos <- regexpr("\\.", out[is_float])
  expect_true(all(dot_pos == dot_pos[[1L]]))
  # The integer N=86 has its units digit "6" exactly one column to
  # the LEFT of the float decimal column.
  six_pos <- regexpr("6", out[[1L]])
  expect_equal(as.integer(six_pos), as.integer(dot_pos[[1L]]) - 1L)
})

test_that("integer N row aligns with n column of n (pct) rows (Duration Categories scenario)", {
  v <- c(
    "72",
    "72 (100.0)",
    "67 (93.1)",
    "49 (68.1)",
    "38 (52.8)",
    "26 (36.1)"
  )
  out <- align(v)
  expect_equal(
    out,
    c(
      "72        ",
      "72 (100.0)",
      "67 ( 93.1)",
      "49 ( 68.1)",
      "38 ( 52.8)",
      "26 ( 36.1)"
    )
  )
  # The 2-digit "n" portion ("72" through "26") all sits at column 1-2
  # in every row, including the standalone integer at row 1.
  n_substr <- substr(out, 1L, 2L)
  expect_equal(n_substr, c("72", "72", "67", "49", "38", "26"))
  # Inside the parens, the pct integer is right-aligned to 3 chars so
  # "100" and " 93" / " 68" / " 52" / " 36" line up at the decimal.
  open_paren_idx <- regexpr("\\(", out[-1L])
  dot_in_paren <- regexpr("\\.", out[-1L])
  # Decimal sits a fixed offset right of the open paren in every
  # parenthesised row.
  offset <- as.integer(dot_in_paren) - as.integer(open_paren_idx)
  expect_true(all(offset == offset[[1L]]))
})

test_that("saf_demo Age (years) column mixes 4 shapes and aligns on primary", {
  # n (integer), Mean (SD) (est_spread), Median (float), Q1, Q3
  # (range_pair), Min (integer), Max (integer). Dominant signature
  # = est_spread (first 2-float row encountered).
  v <- c("86", "75.2 (8.59)", "76.0", "69.2, 81.8", "61", "88")
  out <- align(v)
  expect_equal(
    out,
    c(
      "86         ",
      "75.2 (8.59)",
      "76.0       ",
      "69.2, 81.8 ",
      "61         ",
      "88         "
    )
  )
  # Primary decimal anchor: every cell with own dec has "." at the
  # same column; integer-only cells have a space at that column.
  has_dot <- grepl("\\.", out)
  dot_pos <- regexpr("\\.", out[has_dot])
  # Slot 1 dec position is consistent for all float rows.
  slot1_dot <- as.integer(regexpr("\\.", c("75.2", "76.0", "69.2")))
  expect_equal(
    slot1_dot[[1L]],
    slot1_dot[[2L]]
  )
})

test_that("non-dominant cell's leading literal (e.g. opening paren of a CI line) survives", {
  # Regression: when a cell's signature differs from the section's
  # dominant signature, .render_cell_primary_only() used to prepend
  # the dominant's leading literal — silently dropping the cell's
  # own opening punctuation. For a column mixing n (pct) responders
  # with a (low, high) CI row, the CI cell would render as
  # " 0.3, 8.1) " (NBSP-padded where the "(" used to be). The fix
  # preserves the cell's own leading literal.
  v <- c("13 (45.0)", "8 (28.0)", "9 (31.0)", "(0.3, 8.1)")
  out <- align(v)
  expect_equal(
    out,
    c(
      "13   (45.0)",
      " 8   (28.0)",
      " 9   (31.0)",
      "( 0.3, 8.1)"
    )
  )
  # The opening paren of the CI line is the first character — the
  # bug used to swallow it and leave a leading space.
  expect_equal(substr(out[[4L]], 1L, 1L), "(")
  # All rows are the same column width.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
})

test_that("integer N row aligns with both est_spread and float rows in the same column", {
  # A stats block where the very first row is the N (integer), then
  # Mean (SD), then a few SD/Median/Min/Max rows that are floats.
  # All integer cells must have their units digit one column left
  # of the floats' decimal point.
  v <- c("254", "75.1 (8.25)", "77.0", "67.0", "84.0")
  out <- align(v)
  # First row: " 254 (    )" int-pad to 3 + space + raw remainder
  # spaces. Float rows render normally.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # Decimal positions match between all 2nd-onward rows that have
  # a decimal at slot 1.
  dot_pos <- regexpr("\\.", out[2L:5L])
  expect_true(all(dot_pos == dot_pos[[1L]]))
})

test_that("p-value column with mixed comparator prefixes aligns the prefix slot", {
  v <- c("<0.001", "0.045", "0.500", ">0.999")
  out <- align(v)
  # All width-equal; prefix column either holds the comparator or a
  # leading space for rows without one.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  expect_equal(substr(out, 1L, 1L), c("<", " ", " ", ">"))
})

test_that("negative numbers align via the sign slot expansion", {
  v <- c("1.5", "-2.5", "100.0", "-50.0")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # The sign and digit cluster together; max width includes the
  # minus sign for the longest negative.
  dot_pos <- regexpr("\\.", out)
  expect_true(all(dot_pos == dot_pos[[1L]]))
})

test_that("float column with trailing text tail keeps tail unaligned", {
  v <- c("1.5", "1.5 footnote")
  out <- align(v)
  # Both rows have the same primary slot. Tail "footnote" is left
  # raw on row 2; right-pad brings row 1 to the same total width.
  expect_true(all(nchar(out) == nchar(out[[2L]])))
  # Decimals align.
  dot_pos <- regexpr("\\.", out)
  expect_true(all(dot_pos == dot_pos[[1L]]))
})

# ---------------------------------------------------------------------
# Layer 3 — edge cases
# ---------------------------------------------------------------------

test_that("empty column passes through unchanged", {
  expect_equal(align(character()), character())
})

test_that("single-cell column returns the cell padded to its own width", {
  out <- align("86")
  expect_equal(out, "86")
})

test_that("all-NA column preserves NA in every position", {
  v <- c(NA_character_, NA_character_)
  out <- align(v)
  expect_true(all(is.na(out)))
  expect_equal(length(out), 2L)
})

test_that("mixed NA + numeric preserves NA and aligns the numeric rows", {
  v <- c(NA_character_, "86", "147.8", NA_character_)
  out <- align(v)
  expect_true(is.na(out[[1L]]))
  expect_true(is.na(out[[4L]]))
  # Numeric rows are aligned among themselves.
  dot_pos <- regexpr("\\.", out[[3L]])
  six_pos <- regexpr("6", out[[2L]])
  expect_equal(as.integer(six_pos), as.integer(dot_pos) - 1L)
})

test_that("all-empty-string column returns empty strings", {
  v <- c("", "", "")
  out <- align(v)
  expect_equal(out, c("", "", ""))
})

test_that("text-only column passes through with right-pad", {
  v <- c("Yes", "No", "Maybe")
  out <- align(v)
  # No floats anywhere; column has no dominant. Every cell is just
  # its raw text right-padded to max width.
  expect_true(all(nchar(out) == nchar("Maybe")))
  expect_equal(trimws(out), c("Yes", "No", "Maybe"))
})

test_that("numeric column with one text outlier aligns the numerics and right-pads the outlier", {
  v <- c("Total", "86", "100")
  out <- align(v)
  # All cells right-padded to max width.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # Numeric cells right-align in their slot (int_w = 3 from "100").
  expect_true(grepl("100", out[[3L]]))
})

test_that("zero-valued cells align like any other float", {
  v <- c("0.0", "0.00", "12.34")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  dot_pos <- regexpr("\\.", out)
  expect_true(all(dot_pos == dot_pos[[1L]]))
})

test_that("whitespace input is trimmed before alignment", {
  v <- c("  86  ", "147.8")
  out <- align(v)
  expect_true(all(nchar(out) == nchar(out[[2L]])))
  # No leading whitespace beyond what padding adds.
  expect_true(grepl("86", out[[1L]]))
})

# ---------------------------------------------------------------------
# Layer 4 — engine_decimal() top-level matrix entry
# ---------------------------------------------------------------------

test_that("engine_decimal() rewrites columns whose col_spec has align='decimal'", {
  m <- matrix(
    c(
      "86",
      "147.8",
      "62.13",
      "X",
      "Y",
      "Z"
    ),
    nrow = 3L,
    dimnames = list(NULL, c("num", "lab"))
  )
  cols <- list(
    num = col_spec(align = "decimal"),
    lab = col_spec(align = "left")
  )
  out <- tabular:::engine_decimal(m, cols)
  expect_equal(dim(out), dim(m))
  expect_equal(colnames(out), colnames(m))
  # Decimal column has been rewritten.
  expect_false(identical(out[, "num"], m[, "num"]))
  # Non-decimal column passes through unchanged.
  expect_identical(out[, "lab"], m[, "lab"])
})

test_that("engine_decimal() leaves matrices untouched when no col is decimal-aligned", {
  m <- matrix(
    c("1", "2", "3", "a", "b", "c"),
    nrow = 3L,
    dimnames = list(NULL, c("n", "lab"))
  )
  cols <- list(
    n = col_spec(align = "right"),
    lab = col_spec(align = "left")
  )
  out <- tabular:::engine_decimal(m, cols)
  expect_identical(out, m)
})

test_that("engine_decimal() handles a column with no col_spec by passing through", {
  m <- matrix(
    c("1.0", "2.5"),
    nrow = 2L,
    dimnames = list(NULL, "n")
  )
  out <- tabular:::engine_decimal(m, list())
  expect_identical(out, m)
})

test_that("engine_decimal() rewrites multiple decimal columns independently", {
  m <- matrix(
    c(
      "86",
      "147.8",
      "62.13",
      "5 (12.5)",
      "10 (25.0)",
      "8 (20.0)",
      "row A",
      "row B",
      "row C"
    ),
    nrow = 3L,
    dimnames = list(NULL, c("dur", "n_pct", "lab"))
  )
  cols <- list(
    dur = col_spec(align = "decimal"),
    n_pct = col_spec(align = "decimal"),
    lab = col_spec(align = "left")
  )
  out <- tabular:::engine_decimal(m, cols)
  expect_true(all(nchar(out[, "dur"]) == nchar(out[1L, "dur"])))
  expect_true(all(nchar(out[, "n_pct"]) == nchar(out[1L, "n_pct"])))
  expect_identical(out[, "lab"], m[, "lab"])
})

test_that("engine_decimal() preserves NA cells in decimal-aligned columns", {
  m <- matrix(
    c("86", NA_character_, "147.8"),
    nrow = 3L,
    dimnames = list(NULL, "x")
  )
  cols <- list(x = col_spec(align = "decimal"))
  out <- tabular:::engine_decimal(m, cols)
  expect_true(is.na(out[2L, "x"]))
  expect_false(is.na(out[1L, "x"]))
  expect_false(is.na(out[3L, "x"]))
})

# ---------------------------------------------------------------------
# Layer 5 — snapshot pinning of the user's image scenarios
# ---------------------------------------------------------------------

test_that("snapshot: Extent of Exposure / Total Duration (days) Placebo", {
  v <- c("86", "147.8", "62.13", "182.0", "0.0", "210.0")
  out <- align(v)
  expect_snapshot(cat(out, sep = "\n"))
})

test_that("snapshot: Duration Categories / Xanomeline High Dose", {
  v <- c(
    "72",
    "72 (100.0)",
    "67 (93.1)",
    "49 (68.1)",
    "38 (52.8)",
    "26 (36.1)"
  )
  out <- align(v)
  expect_snapshot(cat(out, sep = "\n"))
})

test_that("snapshot: saf_demo Age (years) Placebo column", {
  v <- c(
    "86",
    "75.2 (8.59)",
    "76.0",
    "69.2, 81.8",
    "61",
    "88"
  )
  out <- align(v)
  expect_snapshot(cat(out, sep = "\n"))
})

test_that("snapshot: full saf_demo Placebo column end-to-end", {
  # Real bundled-data integration: the entire Placebo column of
  # saf_demo, which contains the canonical multi-shape mix that
  # broke galley.
  v <- saf_demo$placebo
  out <- align(v)
  expect_snapshot(cat(out, sep = "\n"))
})

# ---------------------------------------------------------------------
# Layer 6 — per-section alignment
# ---------------------------------------------------------------------

test_that("sections vector splits a column into independent alignment units", {
  # Two sections in one column: a stats block (integer N + float
  # Mean / SD) and an n_pct block (integer N + n_pct cells). Without
  # sections, the float rows force a slot-1 decimal slot that the
  # n_pct rows must space-fill. With sections, each block aligns
  # independently and the n_pct rows render tight.
  v <- c("86", "75.2 (8.59)", "76.0", "14 (16.3)", "72 (83.7)")
  sec <- c("stats", "stats", "stats", "n_pct", "n_pct")
  out <- align(v, sections = sec)
  # Stats section: int_w=2, dec_w=1; "86" is right-padded with the
  # decimal-slot space; floats render tight.
  expect_match(out[[2L]], "75\\.2 \\(8\\.59\\)")
  # n_pct section renders tight (no slot-1 dec slot reservation):
  expect_match(out[[4L]], "^14 \\(16\\.3\\)")
  expect_match(out[[5L]], "^72 \\(83\\.7\\)")
  # All rows share the same nchar after column-wide right-pad.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
})

test_that("sections vector preserves row order across sections", {
  v <- c("86", "75.2", "14 (16.3)", "147", "9.5")
  sec <- c("A", "A", "B", "A", "A")
  out <- align(v, sections = sec)
  # Row 4 ("147") belongs to section A even though section B
  # intervenes; A-section widths must include "147" in int_w.
  expect_match(out[[4L]], "147")
  # Section B has only one row — renders with its own minimal width.
  expect_match(out[[3L]], "14 \\(16\\.3\\)")
})

test_that("sections vector rejects length mismatch", {
  v <- c("1", "2", "3")
  expect_error(
    align(v, sections = c("A", "B")),
    class = "tabular_error_input"
  )
})

test_that("sections vector tolerates a section consisting entirely of NAs", {
  v <- c("86", "147.8", NA_character_, NA_character_, "9.5")
  sec <- c("A", "A", "B", "B", "A")
  out <- align(v, sections = sec)
  # NA rows pass through; section B has no numeric content to align.
  expect_true(is.na(out[[3L]]))
  expect_true(is.na(out[[4L]]))
  expect_false(is.na(out[[1L]]))
})

test_that("engine_decimal() forwards sections to the per-column workhorse", {
  m <- matrix(
    c(
      "86",
      "75.2 (8.59)",
      "14 (16.3)",
      "72 (83.7)"
    ),
    nrow = 4L,
    dimnames = list(NULL, "placebo")
  )
  cols <- list(placebo = col_spec(align = "decimal"))
  sec <- c("Age", "Age", "AgeGrp", "AgeGrp")
  out <- tabular:::engine_decimal(m, cols, sections = sec)
  # Section "Age" int_w = 2, slot1 dec_w = 1; stats render tight.
  expect_match(out[2L, "placebo"], "75\\.2 \\(8\\.59\\)")
  # Section "AgeGrp" is its own n_pct block; render tight.
  expect_match(out[3L, "placebo"], "^14 \\(16\\.3\\)")
})

# ---------------------------------------------------------------------
# Layer 7 — snapshot pinning the user's "DM expectation" image
# ---------------------------------------------------------------------

test_that("snapshot: per-section saf_demo Placebo column (Demographics image)", {
  # The user-reported expectation for "Summary of Demographic and
  # Baseline Characteristics" Placebo column. Sections derive from
  # the `variable` row-label column: Age (years), Age Group n (%),
  # Sex n (%), Race n (%), Ethnicity n (%). Each section aligns
  # independently; the column-wide right-pad makes the final block
  # uniform.
  v <- saf_demo$placebo
  sec <- saf_demo$variable
  out <- align(v, sections = sec)
  expect_snapshot(cat(out, sep = "\n"))
})

test_that("snapshot: per-section all four arm columns (full saf_demo)", {
  # Same Demographics scenario for every arm column. Confirms cross-
  # arm consistency.
  sec <- saf_demo$variable
  for (arm in c("placebo", "drug_100", "drug_50", "Total")) {
    out <- align(saf_demo[[arm]], sections = sec)
    expect_snapshot(
      cat(sprintf("=== %s ===\n", arm), out, sep = "\n"),
      variant = arm
    )
  }
})

# ---------------------------------------------------------------------
# Layer 8 — 18 format families reference (galley decimal-formats.txt)
# ---------------------------------------------------------------------

# Pin every input/expected pair from galley's published decimal-
# formats.txt. The snapshot captures BOTH my engine's output AND
# galley's expected output side-by-side; divergences are visible as
# the snapshot file's "actual" vs "expected" markers. Several galley
# features (missing-token NR/BLQ handling, zero-suppression in
# n_pct, sibling type sharing across literal-different signatures,
# compound-shape gap padding) are deferred to v0.2.0+; the snapshot
# documents the current gap.

test_that("snapshot: 18 format families vs galley reference", {
  cases <- list(
    list(
      name = "01 missing",
      input = c("", "-", "NR", "BLQ", "INF", "-INF"),
      galley = c("", "", "", "", "", "")
    ),
    list(
      name = "02 n_only",
      input = c("0", "42", "135"),
      galley = c("  0", " 42", "135")
    ),
    list(
      name = "03 scalar_float",
      input = c("12.3", "135.20", "-2.5", "0.07"),
      galley = c(" 12.3 ", "135.20", " -2.5 ", "  0.07")
    ),
    list(
      name = "04 pvalue",
      input = c("<0.001", "=0.500", ">0.999"),
      galley = c("<0.001", "=0.500", ">0.999")
    ),
    list(
      name = "05 n_pct",
      input = c("0", "1 (2.2)", "42 (50.0%)", "100 (100.0%)"),
      galley = c(
        "  0         ",
        "  1 (  2.2 )",
        " 42 ( 50.0%)",
        "100 (100.0%)"
      )
    ),
    list(
      name = "06 n_over_N_pct",
      input = c("3/45 (6.7)", "42/84 (50.0%)", "120/120 (100.0)"),
      galley = c(
        "  3/45  (  6.7 )",
        " 42/84  ( 50.0%)",
        "120/120 (100.0 )"
      )
    ),
    list(
      name = "07 n_over_N",
      input = c("0/120", "1/120", "108/120"),
      galley = c("  0/120", "  1/120", "108/120")
    ),
    list(
      name = "08 n_over_float",
      input = c("0/234.6", "12/234.6", "108/234.6"),
      galley = c("  0/234.6", " 12/234.6", "108/234.6")
    ),
    list(
      name = "09 est_spread",
      input = c("75.0 (6.75)", "136.8 (17.61)", "-0.0 (1.47)"),
      galley = c(" 75.0 ( 6.75)", "136.8 (17.61)", " -0.0 ( 1.47)")
    ),
    list(
      name = "10 est_spread_pct",
      input = c("0.10 (8.7%)", "52.43 (23.4%)", "1240.40 (23.4%)"),
      galley = c(
        "   0.10 ( 8.7%)",
        "  52.43 (23.4%)",
        "1240.40 (23.4%)"
      )
    ),
    list(
      name = "11 est_ci",
      input = c(
        "168.0 (152.4, 183.6)",
        "14.3 (11.2, NR)",
        "0.087 (0.034, NR)",
        "NR (NR, NR)"
      ),
      galley = c(
        "168.0   (152.4  , 183.6)",
        " 14.3   ( 11.2  ,  NR  )",
        "  0.087 (  0.034,  NR  )",
        " NR     ( NR    ,  NR  )"
      )
    ),
    list(
      name = "12 est_ci_bracket",
      input = c(
        "0.0 [0.0, 0.0]",
        "53.0 [45.0, 60.0]",
        "102.0 [88.4, 116.2]"
      ),
      galley = c(
        "  0.0 [ 0.0,   0.0]",
        " 53.0 [45.0,  60.0]",
        "102.0 [88.4, 116.2]"
      )
    ),
    list(
      name = "13 range_pair",
      input = c("2.0, 45.0", "65.0, 88.0", "-5.3, 12.1"),
      galley = c(" 2.0, 45.0", "65.0, 88.0", "-5.3, 12.1")
    ),
    list(
      name = "14 int_range",
      input = c("1 - 180", "10 - 365"),
      galley = c(" 1 - 180", "10 - 365")
    ),
    list(
      name = "15 est_ci_pval",
      input = c(
        "-0.08 (-0.21, 0.05) 0.194",
        "12.40 (9.80, 15.00) <0.001"
      ),
      galley = c(
        "-0.08 (-0.21,  0.05)     0.194",
        "12.40 ( 9.80, 15.00)    <0.001"
      )
    ),
    list(
      name = "16 n_pct_rate",
      input = c("0 (0.0) 0.00", "3 (2.5) 1.28", "42 (35.0) 17.94"),
      galley = c(
        " 0                ",
        " 3 ( 2.5)     1.28",
        "42 (35.0)    17.94"
      )
    ),
    list(
      name = "17 n_over_N_pct_ci",
      input = c(
        "0/120 (0.0) [0.0, 3.0]",
        "12/120 (10.0) [5.6, 16.9]",
        "120/120 (100.0) [97.0, 100.0]"
      ),
      galley = c(
        "  0/120 (  0.0) [ 0.0,   3.0]",
        " 12/120 ( 10.0) [ 5.6,  16.9]",
        "120/120 (100.0) [97.0, 100.0]"
      )
    ),
    list(
      name = "18 est_spread_pct_ci",
      input = c(
        "8.1 (24.2%) (7.3, 8.9)",
        "1240.4 (23.4%) (1124.2, 1368.8)"
      ),
      galley = c(
        "   8.1 (24.2%)    (   7.3,    8.9)",
        "1240.4 (23.4%)    (1124.2, 1368.8)"
      )
    )
  )

  out_lines <- character()
  match_count <- 0L
  total_count <- 0L
  for (case in cases) {
    mine <- align(case$input)
    out_lines <- c(out_lines, sprintf("=== %s ===", case$name))
    for (i in seq_along(case$input)) {
      total_count <- total_count + 1L
      same <- identical(mine[[i]], case$galley[[i]])
      if (same) {
        match_count <- match_count + 1L
      }
      out_lines <- c(
        out_lines,
        sprintf("  input:  %s", case$input[[i]]),
        sprintf("  mine:   |%s|", mine[[i]]),
        sprintf(
          "  galley: |%s|%s",
          case$galley[[i]],
          if (same) "  [match]" else "  [GAP]"
        )
      )
    }
    out_lines <- c(out_lines, "")
  }
  out_lines <- c(
    out_lines,
    sprintf(
      "=== summary: %d / %d match galley (%.1f%%) ===",
      match_count,
      total_count,
      100 * match_count / total_count
    )
  )
  expect_snapshot(cat(out_lines, sep = "\n"))
})

# ---------------------------------------------------------------------
# Layer 9 — column-wide slot-1 floor with section-scoped tail
# ---------------------------------------------------------------------

test_that("slot-1 sign+int width is column-wide across sections", {
  # Section A has single-digit ints; section B has three-digit ints.
  # Without the column-wide floor, A's "1" would pad-left to 1 char
  # (its own section's int_w) and B's "100" would pad to 3 — so the
  # units-digit columns wouldn't align. With the floor, A's "1" pads
  # to 3 chars too.
  v <- c("1", "2", "3", "100", "200")
  sec <- c("A", "A", "A", "B", "B")
  out <- align(v, sections = sec)
  expect_equal(out, c("  1", "  2", "  3", "100", "200"))
})

test_that("slot-1 has_dec / dec_w stays section-scoped", {
  # Section A has decimals at slot 1 (the floats are 75.2 / 76.0);
  # section B is integer-only n_pct cells with NO slot-1 decimal.
  # Section A reserves a dot-slot; section B does not.
  v <- c("86", "75.2", "76.0", "14 (16.3)", "72 (83.7)")
  sec <- c("A", "A", "A", "B", "B")
  out <- align(v, sections = sec)
  # Section A's "86" has a reserved dot-slot space (no own dec).
  # Section B's "14 (16.3)" should NOT have a reserved dot-slot.
  expect_true(grepl("86", out[[1L]]))
  # Verify section B rows render their n portion tight (no phantom
  # space between "14" and " (").
  expect_match(out[[4L]], "^14 \\(16\\.3\\)")
  expect_match(out[[5L]], "^72 \\(83\\.7\\)")
})

test_that("comparator prefix aligns column-wide across sections", {
  # Section A has p-values "<0.001" / "0.045"; section B has plain
  # floats. The comparator slot should be reserved across both
  # sections so the comparator column is consistent.
  v <- c("<0.001", "0.045", "1.5", "2.5")
  sec <- c("A", "A", "B", "B")
  out <- align(v, sections = sec)
  # The "<" of row 1 sits at the same column as the leading space
  # of row 2 (the empty comparator).
  expect_equal(substr(out[[1L]], 1L, 1L), "<")
  # Row 2 has no comparator; the prefix slot is a leading space.
  expect_equal(substr(out[[2L]], 1L, 1L), " ")
})

# ---------------------------------------------------------------------
# Layer 10 — aligngen-inspired enhancements
# ---------------------------------------------------------------------

test_that("engine_decimal() defaults to NBSP padding", {
  m <- matrix(c("86", "147.8"), nrow = 2L, dimnames = list(NULL, "x"))
  cols <- list(x = col_spec(align = "decimal"))
  out <- tabular:::engine_decimal(m, cols)
  # The padding character on the integer row is U+00A0 NBSP, not
  # ASCII space.
  nbsp <- " "
  # Inspect code points directly rather than grepl, whose
  # fixed-pattern matching has encoding-dependent behaviour on
  # multi-byte characters across locales.
  chars <- strsplit(out[1L, "x"], "")[[1L]]
  codes <- vapply(chars, utf8ToInt, integer(1L))
  expect_true(0xA0 %in% codes)
  expect_false(0x20 %in% codes)
})

test_that("engine_decimal() pad arg overrides to ASCII space", {
  m <- matrix(c("86", "147.8"), nrow = 2L, dimnames = list(NULL, "x"))
  cols <- list(x = col_spec(align = "decimal"))
  out <- tabular:::engine_decimal(m, cols, pad = " ")
  chars <- strsplit(out[1L, "x"], "")[[1L]]
  codes <- vapply(chars, utf8ToInt, integer(1L))
  expect_true(0x20 %in% codes)
  expect_false(0xA0 %in% codes)
})

test_that("not_considered cells bypass alignment and contribute no slot width", {
  # "NR" and "BLQ" should pass through as raw text; they should not
  # widen int_w or dec_w. With them removed from the width
  # computation, "86" and "147.8" align normally.
  v <- c("86", "NR", "147.8", "BLQ", "0.0")
  out <- align(v, not_considered = c("NR", "BLQ"))
  # All cells share the same column-wide nchar.
  expect_true(all(nchar(out) == nchar(out[[1L]])))
  # The opaque cells contain only their raw token + right-pad.
  expect_match(out[[2L]], "^NR")
  expect_match(out[[4L]], "^BLQ")
  # Numeric cells decimal-align among themselves.
  num_idx <- c(1L, 3L, 5L)
  dot_pos <- regexpr("\\.", out[num_idx])
  # Rows with own dec ("147.8", "0.0") share dot position.
  has_dot <- dot_pos > 0
  expect_true(all(dot_pos[has_dot] == dot_pos[has_dot][[1L]]))
})

test_that("not_considered is empty by default and nothing is treated opaque", {
  v <- c("86", "NR", "147.8")
  out <- align(v)
  # "NR" with no `not_considered` is just a non-numeric cell; its
  # raw text is preserved but no special opacity.
  expect_match(out[[2L]], "NR")
})

test_that("zero_suppress=TRUE collapses 0 in an n_pct column", {
  v <- c("85 (98.8)", "0 (0.0)", "42 (50.0)")
  out <- align(v, zero_suppress = TRUE)
  # Row 2 renders only the "0" portion; the paren tail is replaced
  # by pad characters of equal width so column nchar stays uniform.
  expect_match(out[[2L]], "^ 0\\s+$")
  expect_true(all(nchar(out) == nchar(out[[1L]])))
})

test_that("zero_suppress=FALSE keeps the (0.0) paren rendered", {
  v <- c("85 (98.8)", "0 (0.0)", "42 (50.0)")
  out <- align(v, zero_suppress = FALSE)
  # Row 2 keeps its parenthesised tail.
  expect_match(out[[2L]], "0.*\\(.*0\\.0.*\\)")
})

test_that("zero_suppress ignores non-paren shapes", {
  # The dominant shape here is "F" (single float), not an n_pct.
  # Even though "0.0" parses as zero, no suppression should fire.
  v <- c("0.0", "12.3", "100.5")
  out <- align(v, zero_suppress = TRUE)
  expect_match(out[[1L]], "0\\.0")
})

test_that("edge_trim preserves output when no shared edge pad exists", {
  # Real rendering rarely produces column-wide leading / trailing
  # pad because at least one row in any non-trivial column has its
  # full int_w used at the left and a non-pad rightmost char. The
  # trim is a defensive cleanup; here we confirm it does NOT
  # mangle a valid column.
  v <- c("86", "147.8")
  out_no <- align(v, edge_trim = FALSE)
  out_trim <- align(v, edge_trim = TRUE)
  # Output unchanged because leading chars (" ", "1") and trailing
  # chars (" ", "8") differ across rows.
  expect_identical(out_no, out_trim)
})

test_that(".trim_symmetric strips a column-wide leading pad", {
  # Direct exercise of the helper. Input where every cell shares a
  # leading and trailing pad character.
  out <- c("  abc ", "  def ", "  ghi ")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_equal(trimmed, c(" abc", " def", " ghi"))
})

test_that(".trim_symmetric stops when one cell breaks the shared edge", {
  out <- c("  abc", " xdef", "  ghi")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  # All cells share one leading pad; second has "x" at col 2 so
  # only one column of leading pad gets stripped.
  expect_equal(trimmed, c(" abc", "xdef", " ghi"))
})

test_that(".trim_symmetric is a no-op when no shared edge exists", {
  out <- c("abc", "def", "ghi")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_identical(trimmed, out)
})

test_that(".trim_symmetric tolerates NA rows", {
  out <- c("  abc", NA_character_, "  def")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_true(is.na(trimmed[[2L]]))
  expect_equal(trimmed[c(1L, 3L)], c(" abc", " def"))
})

test_that(".trim_symmetric won't shrink any cell below 1 character", {
  out <- c(" ", " ", " ")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  # All cells are 1-char pad; can't trim further.
  expect_equal(trimmed, out)
})

test_that(".trim_symmetric accepts a multi-character pad as a no-op", {
  # Defensive: if the caller passes a non-single-character pad,
  # leave the input untouched rather than risking partial
  # truncation.
  out <- c("ab abc", "ab def")
  trimmed <- tabular:::.trim_symmetric(out, pad = "ab")
  expect_identical(trimmed, out)
})

test_that(".trim_symmetric early-returns on all-NA input", {
  out <- c(NA_character_, NA_character_)
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_true(all(is.na(trimmed)))
})

test_that(".trim_symmetric stops between left and right when row becomes single char", {
  # 2-char rows where every cell starts with pad. After one left
  # strip, every cell is 1-char — function returns early before
  # the right-strip pass.
  out <- c(" a", " b", " c")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_equal(trimmed, c("a", "b", "c"))
})

test_that(".is_zero_n returns FALSE when float has prefix or sign", {
  # Prefix present -> never zero-suppressed.
  expect_false(tabular:::.is_zero_n(
    list(prefix = "<", sign = "", int = "0", dec = "001")
  ))
  # Sign present -> never zero-suppressed.
  expect_false(tabular:::.is_zero_n(
    list(prefix = "", sign = "-", int = "0", dec = "0")
  ))
})

test_that(".compute_column_floor returns NULL when no cells have floats", {
  # All cells are non-numeric text.
  floor <- tabular:::.compute_column_floor(c("Total", "Yes", "No"))
  expect_null(floor)
})

test_that("column floor is NULL doesn't break section render in sections mode", {
  # Sections mode with all-text section A and a numeric section B.
  # The column floor should account only for section B.
  v <- c("Total", "Yes", "86", "147.8")
  sec <- c("A", "A", "B", "B")
  out <- align(v, sections = sec)
  # Section A rows pass through as text right-padded.
  expect_match(out[[1L]], "Total")
  expect_match(out[[2L]], "Yes")
  # Section B aligns its numbers.
  expect_true(grepl("147\\.8", out[[4L]]))
})

test_that("edge_trim runs both passes (left + right) via the trim helper", {
  # Direct exercise: input where every cell has leading AND
  # trailing pad. Both passes fire.
  out <- c("  abc  ", "  def  ", "  ghi  ")
  trimmed <- tabular:::.trim_symmetric(out, pad = " ")
  expect_equal(trimmed, c(" abc ", " def ", " ghi "))
})

test_that("engine_decimal() threads not_considered through to columns", {
  m <- matrix(c("86", "NR", "147.8"), nrow = 3L, dimnames = list(NULL, "x"))
  cols <- list(x = col_spec(align = "decimal"))
  out <- tabular:::engine_decimal(
    m,
    cols,
    not_considered = c("NR"),
    pad = " "
  )
  expect_match(out[2L, "x"], "^NR")
})

test_that("engine_decimal() threads zero_suppress + edge_trim", {
  m <- matrix(
    c("85 (98.8)", "0 (0.0)", "42 (50.0)"),
    nrow = 3L,
    dimnames = list(NULL, "x")
  )
  cols <- list(x = col_spec(align = "decimal"))
  out <- tabular:::engine_decimal(
    m,
    cols,
    zero_suppress = TRUE,
    edge_trim = TRUE,
    pad = " "
  )
  # Row 2 is zero-suppressed; trim removed any column-wide leading
  # / trailing pads.
  expect_match(out[2L, "x"], "^0|^ 0")
})

# ---------------------------------------------------------------------
# Layer 11 — combined: sections + opaque + zero-suppress on the
# saf_demo Total column. The Total column has "0 (0.0)" rows in
# Race / Ethnicity that should now zero-suppress, and "NR" — though
# absent here — could be opaque in a future fixture.
# ---------------------------------------------------------------------

test_that("snapshot: per-section + zero-suppress + edge-trim on saf_demo Total", {
  v <- saf_demo$Total
  sec <- saf_demo$variable
  out <- align(
    v,
    sections = sec,
    zero_suppress = TRUE,
    edge_trim = TRUE
  )
  expect_snapshot(cat(out, sep = "\n"))
})

# ---------------------------------------------------------------------
# Layer 4 — decimal_metrics = "afm" (em-aware alignment)
# ---------------------------------------------------------------------

test_that(".build_measure default falls back to nchar", {
  m <- tabular:::.build_measure("chars", NA_character_, " ")
  expect_equal(m("hello"), 5L)
  expect_equal(m(""), 0L)
})

test_that(".build_measure with metrics='afm' returns NBSP-equivalent units", {
  m <- tabular:::.build_measure(
    "afm",
    "Times-Roman",
    tabular:::.nbsp
  )
  # Times-Roman digits are all 500 em, NBSP (space) is 250 em -> 2 units per digit.
  expect_equal(m("12345"), 10L)
  # AE ligature: 889 em / 250 em = round(3.556) = 4 units.
  expect_equal(m("Æ"), 4L)
})

test_that("engine_decimal in afm mode keeps uniform column widths in proportional font", {
  m <- tabular:::.build_measure(
    "afm",
    "Times-Roman",
    tabular:::.nbsp
  )
  out <- tabular:::.align_decimal_column(
    c("12.3", "1.45", "100.5"),
    pad = tabular:::.nbsp,
    measure = m,
    zero_suppress = FALSE,
    edge_trim = FALSE
  )
  widths <- m(out)
  expect_true(all(widths == widths[[1L]]))
  expect_true(all(grepl(".", out, fixed = TRUE)))
})

test_that("as_grid threads preset@decimal_metrics='afm' end-to-end", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo", align = "decimal"),
      drug_50 = col_spec(label = "Drug 50", align = "decimal"),
      drug_100 = col_spec(label = "Drug 100", align = "decimal"),
      Total = col_spec(label = "Total", align = "decimal")
    ) |>
    preset(decimal_metrics = "afm")
  grid <- as_grid(spec)
  expect_true(is.matrix(grid@pages[[1]]$cells_text))
  expect_type(grid@pages[[1]]$cells_text, "character")
})

test_that("preset_spec default for decimal_metrics is 'chars'", {
  expect_equal(preset_spec()@decimal_metrics, "chars")
})

test_that("preset_spec accepts all three decimal_metrics values", {
  for (m in c("chars", "afm", "systemfonts")) {
    ps <- preset_spec(decimal_metrics = m)
    expect_equal(ps@decimal_metrics, m, info = m)
  }
})
