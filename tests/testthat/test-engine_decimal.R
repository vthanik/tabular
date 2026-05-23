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
align <- function(values, sections = NULL) {
  tabular:::.align_decimal_column(values, sections = sections)
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
# Layer 6 -- per-section alignment
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
  # Section B has only one row -- renders with its own minimal width.
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
# Layer 7 -- snapshot pinning the user's "DM expectation" image
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
# Layer 8 -- 18 format families reference (galley decimal-formats.txt)
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
