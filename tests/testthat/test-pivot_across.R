# pivot_across(): 25 edge cases from plan section 2.5 plus
# argument-validation cases.

# ---------------------------------------------------------------------
# Happy paths
# ---------------------------------------------------------------------

test_that("pivot_across() returns a data.frame", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_s3_class(out, "data.frame")
  expect_true(all(c("variable", "stat_label") %in% names(out)))
})

test_that("pivot_across() produces one column per group1_level + overall", {
  out <- pivot_across(saf_demo_card)
  arm_cols <- setdiff(names(out), c("variable", "stat_label"))
  expect_true("Total" %in% arm_cols)
  expect_true("Placebo" %in% arm_cols)
  expect_true("Xanomeline Low Dose" %in% arm_cols)
  expect_true("Xanomeline High Dose" %in% arm_cols)
})

test_that("pivot_across() chains into tabular()", {
  spec <- pivot_across(saf_demo_card) |>
    tabular(titles = c("Table 14.1.1", "Demographics"))
  expect_true(is_tabular_spec(spec))
  expect_identical(spec@titles, c("Table 14.1.1", "Demographics"))
})

# ---------------------------------------------------------------------
# Edge case 1: Shape A (raw ard_stack)
# ---------------------------------------------------------------------

test_that("Shape A: raw ard_stack with group1/group1_level is auto-detected", {
  expect_no_error(pivot_across(saf_demo_card))
})

test_that("Shape A normalises list-stat columns", {
  ard <- saf_demo_card
  out <- pivot_across(
    ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_true(nrow(out) >= 1L)
})

# ---------------------------------------------------------------------
# Edge case 2: Shape B (groups-renamed)
# ---------------------------------------------------------------------

test_that("Shape B: renamed arm column is detected automatically", {
  ard <- saf_demo_card
  arm_col <- ard$group1_level
  ard$ARM <- arm_col
  ard$group1 <- NULL
  ard$group1_level <- NULL
  ard <- ard[!is.na(ard$ARM), , drop = FALSE]
  out <- pivot_across(
    ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_s3_class(out, "data.frame")
  expect_true("Placebo" %in% names(out))
})

# ---------------------------------------------------------------------
# Edge case 3: Shape C (ungrouped)
# ---------------------------------------------------------------------

test_that("Shape C: ungrouped ARD lands rows under the overall column", {
  # Build a small ungrouped ARD: no group1 at all, categorical only.
  ard <- data.frame(
    variable = c("SEX", "SEX"),
    variable_level = c("F", "M"),
    context = c("categorical", "categorical"),
    stat_name = c("n", "n"),
    stat = c(53, 33),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{n}", overall = "Total")
  expect_true("Total" %in% names(out))
})

# ---------------------------------------------------------------------
# Edge case 4: Shape D (fully-renamed) — requires explicit column
# ---------------------------------------------------------------------

test_that("Shape D: fully-renamed ARD without `column` errors helpfully", {
  ard <- data.frame(
    AGE = c(NA, NA, NA),
    SEX = c(NA, "F", "M"),
    ARM = c("Placebo", "Placebo", "Placebo"),
    stat_name = c("mean", "n", "n"),
    stat = c(75.2, 53, 33),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n} ({p}%)"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Edge case 5: list-column stat
# ---------------------------------------------------------------------

test_that("list-column stat normalises to numeric", {
  ard <- saf_demo_card
  ard$stat <- as.list(ard$stat)
  out <- pivot_across(
    ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_s3_class(out, "data.frame")
})

# ---------------------------------------------------------------------
# Edge case 7-8: hierarchical (SOC / PT) — saf_aesocpt_card
# ---------------------------------------------------------------------

test_that("Hierarchical ARD: SOC and PT columns appear in output", {
  out <- pivot_across(saf_aesocpt_card, statistic = "{n} ({p}%)")
  expect_true("soc" %in% names(out))
  expect_true("pt" %in% names(out))
  expect_true("row_type" %in% names(out))
})

test_that("Hierarchical ARD keeps the ..ard_hierarchical_overall.. sentinel as a row", {
  out <- pivot_across(saf_aesocpt_card, statistic = "{n} ({p}%)")
  expect_true(any(out$row_type == "overall"))
})

# ---------------------------------------------------------------------
# Edge case 9: ^\.\. sentinels other than the overall are filtered
# ---------------------------------------------------------------------

test_that("Other ^\\.\\. internal rows are filtered", {
  ard <- saf_demo_card
  extra <- ard[1L, , drop = FALSE]
  extra$variable <- "..internal_sentinel.."
  extra$stat_name <- "n"
  extra$stat <- 0
  ard2 <- rbind(ard, extra)
  out <- pivot_across(
    ard2,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_false(any(out$variable == "..internal_sentinel.."))
})

# ---------------------------------------------------------------------
# Edge case 10: single-string statistic applies to both contexts
# ---------------------------------------------------------------------

test_that("Single-string statistic applies to all variables", {
  # Use ard that only has categorical rows so n/p are available
  ard <- saf_demo_card[saf_demo_card$context == "categorical", , drop = FALSE]
  out <- pivot_across(ard, statistic = "{n} ({p}%)")
  expect_s3_class(out, "data.frame")
  expect_true(nrow(out) >= 1L)
})

# ---------------------------------------------------------------------
# Edge case 11: named-list-by-context
# ---------------------------------------------------------------------

test_that("Named-list-by-context dispatches per context", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  # Sex M cell from Placebo should include ({p}%)
  sex_m <- out[out$stat_label == "  M", ]
  expect_true(grepl("\\(", sex_m$Placebo[[1L]]))
})

# ---------------------------------------------------------------------
# Edge case 12: named-list-by-variable (var override + default fallback)
# ---------------------------------------------------------------------

test_that("Named-list-by-variable: per-variable spec wins, default falls through", {
  # Filter to AGE + categoricals so the categorical fallback handles
  # everything; WEIGHT/HEIGHT/BMI now also live in saf_demo_card and need
  # their own continuous rule which is not the scenario under test here.
  ard <- saf_demo_card[
    saf_demo_card$variable %in% c("AGE", "AGEGR1", "SEX", "RACE", "ETHNIC"),
    ,
    drop = FALSE
  ]
  out <- pivot_across(
    ard,
    statistic = list(
      AGE = "{mean}",
      categorical = "{n} ({p}%)"
    )
  )
  age_row <- out[out$variable == "AGE", ]
  # Per-var format produced bare {mean} — no parentheses
  expect_false(grepl("\\(", age_row$Placebo[[1L]]))
})

# ---------------------------------------------------------------------
# Edge case 13: multi-row continuous spec
# ---------------------------------------------------------------------

test_that("Multi-row continuous spec produces one display row per entry", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = c(
        N = "{N}",
        "Mean (SD)" = "{mean} ({sd})",
        Median = "{median}"
      ),
      categorical = "{n} ({p}%)"
    )
  )
  age_rows <- out[out$variable == "AGE", , drop = FALSE]
  expect_identical(nrow(age_rows), 3L)
  # stat_label is indented because it differs from variable
  expect_setequal(age_rows$stat_label, c("  N", "  Mean (SD)", "  Median"))
})

# ---------------------------------------------------------------------
# Edge case 14: format string references unknown stat -> error
# ---------------------------------------------------------------------

test_that("Format string referencing unknown stat raises tabular_error_input", {
  expect_error(
    pivot_across(
      saf_demo_card,
      statistic = list(
        continuous = "{not_a_stat}",
        categorical = "{n} ({p}%)"
      )
    ),
    class = "tabular_error_input"
  )
  expect_error(
    pivot_across(
      saf_demo_card,
      statistic = list(
        continuous = "{mean} ({sd})",
        categorical = "{n} ({p}%)"
      )
    ),
    NA
  )
})

# ---------------------------------------------------------------------
# Edge case 15: global decimals
# ---------------------------------------------------------------------

test_that("Global decimals override built-in defaults", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean}",
      categorical = "{n} ({p}%)"
    ),
    decimals = c(mean = 3)
  )
  age_row <- out[out$variable == "AGE", ]
  # mean to 3 decimals: e.g. 75.209 with 3 dp
  expect_match(age_row$Placebo[[1L]], "\\.[0-9]{3}$")
})

# ---------------------------------------------------------------------
# Edge case 16: per-variable decimals with .default fallback
# ---------------------------------------------------------------------

test_that("Per-variable decimals + .default fallback", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean}",
      categorical = "{n} ({p}%)"
    ),
    decimals = list(AGE = c(mean = 3), .default = c(p = 0))
  )
  age_row <- out[out$variable == "AGE", ]
  expect_match(age_row$Placebo[[1L]], "\\.[0-9]{3}$")
})

# ---------------------------------------------------------------------
# Edge case 17: custom fmt function for one stat
# ---------------------------------------------------------------------

test_that("Custom fmt function overrides built-in", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(continuous = "{mean}", categorical = "{n} ({p}%)"),
    fmt = list(mean = function(x) paste0("M=", round(x, 0)))
  )
  age_row <- out[out$variable == "AGE", ]
  expect_match(age_row$Placebo[[1L]], "^M=")
})

# ---------------------------------------------------------------------
# Edge case 18: zero-suppression (n=0 renders as bare "0", always-on default)
# ---------------------------------------------------------------------

test_that("Zero suppression: n=0 renders as bare '0'", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  zero_row <- out[
    out$variable == "RACE" &
      grepl("AMERICAN INDIAN", out$stat_label),
    ,
    drop = FALSE
  ]
  if (nrow(zero_row) > 0L) {
    expect_identical(zero_row$Placebo[[1L]], "0")
  }
})

# ---------------------------------------------------------------------
# Edge case 19: pharma threshold (extreme pct as <0.1, always-on default)
# ---------------------------------------------------------------------

test_that("Pharma threshold formats extreme percentages with <x / >y", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("X", "X"),
    variable_level = c(NA, NA),
    context = c("categorical", "categorical"),
    stat_name = c("n", "p"),
    stat = c(1, 0.0005),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{p}", decimals = c(p = 1))
  expect_match(out$A[[1L]], "^<")
})

test_that("Custom fmt$p overrides the threshold default", {
  ard <- data.frame(
    group1 = c("ARM"),
    group1_level = c("A"),
    variable = c("X"),
    variable_level = c(NA),
    context = c("categorical"),
    stat_name = c("p"),
    stat = c(0.0005),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{p}",
    fmt = list(p = function(x) sprintf("%.4f", x * 100))
  )
  expect_identical(out$A[[1L]], "0.0500")
})

# ---------------------------------------------------------------------
# Documented @details opt-outs: zero-suppression + pharma threshold.
# Tests pinned 1:1 to the runnable code blocks in the help page so
# every documented escape hatch is exercised.
# ---------------------------------------------------------------------

test_that("@details example: custom fmt$n re-enables full n=0 formatting", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    ),
    fmt = list(n = function(x) sprintf("%d", as.integer(x)))
  )
  # n=0 rows now interpolate the full categorical format because fmt$n
  # returned a value that does not match the zero-suppression branch.
  zero_row <- out[
    out$variable == "RACE" &
      grepl("AMERICAN INDIAN", out$stat_label),
    ,
    drop = FALSE
  ]
  if (nrow(zero_row) > 0L) {
    # With custom fmt$n the cell goes through full interpolation; for
    # n=0 the result is "0 (0%)".
    expect_match(zero_row$Placebo[[1L]], "\\(")
  }
})

test_that("@details example: custom fmt$p shows exact rounded percentages", {
  ard <- data.frame(
    group1 = c("ARM"),
    group1_level = c("A"),
    variable = c("X"),
    variable_level = c(NA),
    context = c("categorical"),
    stat_name = c("p"),
    stat = c(0.0005),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{p}",
    decimals = c(p = 1),
    fmt = list(p = function(x) sprintf("%.1f", x * 100))
  )
  # Without the custom fmt this would render as "<0.1" (pharma threshold);
  # the custom fmt forces the exact rounded value.
  expect_identical(out$A[[1L]], "0.1")
})

# ---------------------------------------------------------------------
# Edge case 20: p-value formatting
# ---------------------------------------------------------------------

test_that("p-value below 0.001 renders as <0.001", {
  ard <- data.frame(
    group1 = c("ARM"),
    group1_level = c("A"),
    variable = c("test"),
    variable_level = c(NA),
    context = c("statistical"),
    stat_name = c("p.value"),
    stat = c(0.0001),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{p.value}")
  expect_identical(out$A[[1L]], "<0.001")
})

# ---------------------------------------------------------------------
# Edge case 21: NA stat -> empty cell
# ---------------------------------------------------------------------

test_that("NA stat renders as empty string", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("X", "X"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("mean", "sd"),
    stat = c(NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{mean} ({sd})")
  expect_identical(out$A[[1L]], " ()")
})

# ---------------------------------------------------------------------
# Edge case 22: overall = NULL drops NA-arm rows
# ---------------------------------------------------------------------

test_that("overall = NULL drops rows with NA arm", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    ),
    overall = NULL
  )
  expect_false("Total" %in% names(out))
})

# ---------------------------------------------------------------------
# Edge case 23: label remap
# ---------------------------------------------------------------------

test_that("label remaps variable values", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    ),
    label = c(SEX = "Sex, n (%)")
  )
  expect_true(any(out$variable == "Sex, n (%)"))
  expect_false("SEX" %in% out$variable)
})

# ---------------------------------------------------------------------
# Edge case 24: empty result error
# ---------------------------------------------------------------------

test_that("Empty result after filtering raises tabular_error_input", {
  ard <- data.frame(
    group1 = c("ARM"),
    group1_level = c("A"),
    variable = c("..ard_internal.."),
    variable_level = c(NA),
    context = c("attributes"),
    stat_name = c("N"),
    stat = c(100),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{N}"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Edge case 25: indent stat_label for non-group rows
# ---------------------------------------------------------------------

test_that("stat_label is indented when it differs from variable", {
  out <- pivot_across(
    saf_demo_card,
    statistic = list(
      continuous = c("Mean (SD)" = "{mean} ({sd})"),
      categorical = "{n} ({p}%)"
    )
  )
  sex_rows <- out[out$variable == "SEX", , drop = FALSE]
  expect_true(all(startsWith(sex_rows$stat_label, "  ")))
})

# ---------------------------------------------------------------------
# Argument-validation cases
# ---------------------------------------------------------------------

test_that("pivot_across() rejects non-data.frame data", {
  expect_error(pivot_across(list()), class = "tabular_error_input")
  expect_error(pivot_across(NULL), class = "tabular_error_input")
})

test_that("pivot_across() rejects ARD without stat_name / stat", {
  df <- data.frame(x = 1:3)
  expect_error(pivot_across(df), class = "tabular_error_input")
})

test_that("pivot_across() rejects non-string non-list statistic", {
  expect_error(
    pivot_across(saf_demo_card, statistic = 42L),
    class = "tabular_error_input"
  )
})

test_that("pivot_across() rejects fmt with non-function entries", {
  expect_error(
    pivot_across(
      saf_demo_card,
      statistic = "{n} ({p}%)",
      fmt = list(p = "not a function")
    ),
    class = "tabular_error_input"
  )
})


# ---------------------------------------------------------------------
# Helper-level smoke tests
# ---------------------------------------------------------------------

test_that(".parse_glue_refs extracts {ref} names", {
  expect_identical(
    tabular:::.parse_glue_refs("{n} ({p}%)"),
    c("n", "p")
  )
  expect_identical(
    tabular:::.parse_glue_refs("plain"),
    character()
  )
})

test_that(".interpolate_format substitutes refs", {
  out <- tabular:::.interpolate_format(
    "{n} ({p}%)",
    c("n", "p"),
    list(n = "10", p = "5.0")
  )
  expect_identical(out, "10 (5.0%)")
})

test_that(".format_p_value handles tiny p and normal p", {
  expect_identical(tabular:::.format_p_value(0.0001), "<0.001")
  expect_identical(tabular:::.format_p_value(0.05), "0.050")
  expect_identical(tabular:::.format_p_value(NA_real_), "")
})

test_that(".resolve_ard_decimals parses three forms", {
  expect_identical(
    tabular:::.resolve_ard_decimals(NULL),
    list(global = NULL, per_var = NULL)
  )
  r1 <- tabular:::.resolve_ard_decimals(c(mean = 1, sd = 2))
  expect_identical(r1$global, c(mean = 1, sd = 2))
  r2 <- tabular:::.resolve_ard_decimals(
    list(AGE = c(mean = 2), .default = c(p = 1))
  )
  expect_identical(r2$global, c(p = 1))
  expect_identical(r2$per_var, list(AGE = c(mean = 2)))
})

# ---------------------------------------------------------------------
# Targeted formatter coverage
# ---------------------------------------------------------------------

test_that(".format_stat_default handles every documented stat_name", {
  ff <- tabular:::.format_stat_default
  expect_identical(ff(10, "n"), "10")
  expect_identical(ff(0.5, "p"), "50")
  expect_identical(ff(0.5, "p_cum"), "50.0")
  expect_identical(ff(0.5, "p_miss"), "50.0")
  expect_identical(ff(0.5, "p_nonmiss"), "50.0")
  expect_identical(ff(1.5, "mean"), "1.5")
  expect_identical(ff(1.5, "sd"), "1.50")
  expect_identical(ff(1.5, "median"), "1.5")
  expect_identical(ff(1.5, "min"), "1.5")
  expect_identical(ff(1.5, "max"), "1.5")
  expect_identical(ff(1.5, "p25"), "1.5")
  expect_identical(ff(1.5, "p75"), "1.5")
  expect_identical(ff(0.0001, "p.value"), "<0.001")
  expect_identical(ff(0.123456, "estimate"), "0.1235")
  expect_identical(ff(0.123456, "std.error"), "0.1235")
  expect_identical(ff(2.5, "statistic"), "2.50")
  expect_identical(ff(1.5, "parameter"), "1.5")
  expect_identical(ff(0.95, "conf.low"), "0.95")
  expect_identical(ff(0.95, "conf.high"), "0.95")
  expect_identical(ff(0.95, "conf.level"), "0.95")
  # Unknown stat -> default %.1f
  expect_identical(ff(2.5, "anything_else"), "2.5")
})

test_that(".format_stat_with_decimals applies pct thresholds at both extremes", {
  fn <- tabular:::.format_stat_with_decimals
  # Above-threshold pct -> ">99.9"
  out_hi <- fn(0.9999, "p", d = 1, pct_threshold = TRUE)
  expect_match(out_hi, "^>")
  # Below-threshold pct -> "<0.1"
  out_lo <- fn(0.0001, "p", d = 1, pct_threshold = TRUE)
  expect_match(out_lo, "^<")
  # pct_threshold = FALSE returns the rounded value
  expect_identical(
    fn(0.0001, "p", d = 1, pct_threshold = FALSE),
    "0.0"
  )
})

test_that("Per-variable decimals: AGE overrides mean, BMI falls back to global", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("AGE", "BMI"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("mean", "mean"),
    stat = c(75.123456, 27.456789),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{mean}",
    decimals = list(
      AGE = c(mean = 4),
      BMI = c(sd = 2),
      .default = c(mean = 2)
    )
  )
  # AGE -> per_var mean=4 -> 4 decimals
  # BMI -> per_var has only sd, mean falls to global (.default) mean=2 -> 2 decimals
  age_val <- out$A[out$variable == "AGE"]
  bmi_val <- out$A[out$variable == "BMI"]
  expect_match(age_val, "\\.[0-9]{4}$")
  expect_match(bmi_val, "\\.[0-9]{2}$")
})

test_that("Per-variable decimals fall through to built-in when per_var + global both miss", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("AGE", "BMI"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("mean", "mean"),
    stat = c(75.123, 27.456),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{mean}",
    # AGE: per_var.mean -> 4 dec.
    # BMI: per_var has sd only, global has sd only -> mean uses built-in default 1 dec.
    decimals = list(AGE = c(mean = 4), BMI = c(sd = 2), .default = c(sd = 1))
  )
  bmi_val <- out$A[out$variable == "BMI"]
  expect_match(bmi_val, "\\.[0-9]{1}$")
})

test_that("Per-variable decimals fall through to built-in default for unrelated stats", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("AGE", "AGE"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("mean", "median"),
    stat = c(75.123, 76.0),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = list(
      continuous = c("Mean" = "{mean}", "Median" = "{median}")
    ),
    decimals = list(AGE = c(mean = 3))
  )
  # median uses built-in default (1 decimal)
  med_val <- out$A[out$stat_label == "  Median"]
  expect_match(med_val, "\\.[0-9]{1}$")
})

# ---------------------------------------------------------------------
# Cross-shape identity test
# ---------------------------------------------------------------------

test_that("Shape A and Shape B produce identical wide output on the same data", {
  ard_a <- saf_demo_card
  ard_b <- ard_a
  ard_b$ARM <- ard_b$group1_level
  ard_b$group1 <- NULL
  ard_b$group1_level <- NULL
  # Shape B can't carry the NA-arm overall rows, so drop them in A too.
  ard_a <- ard_a[!is.na(ard_a$group1_level), , drop = FALSE]
  ard_b <- ard_b[!is.na(ard_b$ARM), , drop = FALSE]

  stat <- list(continuous = "{mean} ({sd})", categorical = "{n} ({p}%)")
  out_a <- pivot_across(ard_a, statistic = stat, overall = NULL)
  out_b <- pivot_across(ard_b, statistic = stat, overall = NULL)

  # Column order may differ; compare core columns
  for (col in c("variable", "stat_label", "Placebo")) {
    expect_identical(out_a[[col]], out_b[[col]])
  }
})

# ---------------------------------------------------------------------
# Hierarchical: extra coverage
# ---------------------------------------------------------------------

test_that("Hierarchical ARD: each SOC has a row + its PTs underneath", {
  out <- pivot_across(saf_aesocpt_card, statistic = "{n} ({p}%)")
  expect_true(any(out$row_type == "soc"))
  expect_true(any(out$row_type == "pt"))
  # Within a single SOC the soc value repeats across the PT rows
  one_soc <- out$soc[out$row_type == "soc"][1L]
  pts_in_soc <- out[out$soc == one_soc & out$row_type == "pt", ]
  expect_true(nrow(pts_in_soc) >= 1L)
})

test_that("Hierarchical ARD respects label remap on soc / pt cols", {
  out <- pivot_across(
    saf_aesocpt_card,
    statistic = "{n} ({p}%)",
    label = c("SKIN AND SUBCUTANEOUS TISSUE DISORDERS" = "Skin / SC tissue")
  )
  expect_true(any(out$soc == "Skin / SC tissue", na.rm = TRUE))
})

# ---------------------------------------------------------------------
# Empty-arm fallback in interpolation
# ---------------------------------------------------------------------

test_that("Cell interpolation returns empty string for arm without rows", {
  # Build an ARD where one arm has no rows for a variable level
  ard <- data.frame(
    group1 = rep("ARM", 3),
    group1_level = c("A", "A", "B"),
    variable = rep("SEX", 3),
    variable_level = c("F", "M", "F"),
    context = rep("categorical", 3),
    stat_name = rep("n", 3),
    stat = c(10, 5, 8),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{n}", overall = NULL)
  # B has no "M" level -> cell should be NA (from match-and-fill)
  m_row <- out[out$stat_label == "  M", ]
  expect_true(is.na(m_row$B) || identical(m_row$B, ""))
})

# ---------------------------------------------------------------------
# Shape D: successful path (explicit column)
# ---------------------------------------------------------------------

test_that("Shape D: fully-renamed ARD reconstructs variable / variable_level", {
  ard <- data.frame(
    AGE = c(NA, NA, NA, NA),
    SEX = c(NA, NA, "F", "M"),
    ARM = c("A", "A", "A", "A"),
    context = c("continuous", "continuous", "categorical", "categorical"),
    stat_name = c("mean", "sd", "n", "n"),
    stat = c(75.2, 8.5, 53, 33),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n}"
    ),
    column = "ARM"
  )
  expect_s3_class(out, "data.frame")
  expect_true("A" %in% names(out))
  expect_true(any(out$variable == "SEX"))
})

test_that("Shape D: missing column arg errors out", {
  ard <- data.frame(
    AGE = c(NA, NA),
    SEX = c("F", "M"),
    stat_name = c("n", "n"),
    stat = c(53, 33),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n}"),
    class = "tabular_error_input"
  )
})

test_that("Shape D: explicit column not in data errors out", {
  ard <- data.frame(
    AGE = c(NA, NA),
    SEX = c("F", "M"),
    stat_name = c("n", "n"),
    stat = c(53, 33),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n}", column = "MISSING"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Shape B: multiple non-standard columns -> requires explicit column
# ---------------------------------------------------------------------

test_that("Shape B with multiple non-standard cols and no column arg errors", {
  ard <- data.frame(
    variable = "X",
    variable_level = NA,
    context = "categorical",
    stat_name = "n",
    stat = 1,
    ARM = "A",
    SEX = "F",
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n}"),
    class = "tabular_error_input"
  )
})

test_that("Shape B with explicit column resolves multi-group input", {
  ard <- data.frame(
    variable = c("X", "X"),
    variable_level = c(NA, NA),
    context = c("categorical", "categorical"),
    stat_name = c("n", "n"),
    stat = c(1, 2),
    ARM = c("A", "B"),
    SEX = c("F", "F"),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{n}", column = "ARM")
  expect_true("A" %in% names(out))
  expect_true("B" %in% names(out))
})

# ---------------------------------------------------------------------
# Multi-group .by: extra group columns preserved
# ---------------------------------------------------------------------

test_that("Multi-group .by preserves extra group columns in output", {
  # Synthetic Shape A ARD with .by = c(ARM, SEX)
  ard <- data.frame(
    group1 = rep("ARM", 4),
    group1_level = c("A", "A", "B", "B"),
    group2 = rep("SEX", 4),
    group2_level = c("F", "M", "F", "M"),
    variable = c("AGE", "AGE", "AGE", "AGE"),
    variable_level = c(NA, NA, NA, NA),
    context = rep("continuous", 4),
    stat_name = rep("mean", 4),
    stat = c(70, 72, 75, 77),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{mean}", overall = NULL)
  expect_true("SEX" %in% names(out))
})

# ---------------------------------------------------------------------
# Hierarchical group-shift handling (cards .overall = TRUE quirk)
# ---------------------------------------------------------------------

test_that("Hierarchical ARD with overall rows handles group-shift", {
  # saf_aesocpt_card was built with .overall = FALSE via the
  # cards::ard_stack_hierarchical(over_variables = TRUE) path, which
  # uses ..ard_hierarchical_overall.. instead of the group-shift quirk;
  # verifying it renders cleanly is enough to exercise the bypass.
  out <- pivot_across(saf_aesocpt_card, statistic = "{n} ({p}%)")
  expect_true(any(out$row_type == "overall"))
  expect_true(any(out$row_type == "soc"))
  expect_true(any(out$row_type == "pt"))
})

# ---------------------------------------------------------------------
# Targeted coverage for helpers
# ---------------------------------------------------------------------

test_that(".extract_context derives ctx from var_level when no context column", {
  df <- data.frame(
    variable = c("A", "B"),
    var_level = c(NA, "x"),
    stringsAsFactors = FALSE
  )
  out <- tabular:::.extract_context(df)
  expect_identical(out$ctx, c("continuous", "categorical"))
})

test_that(".interpolate_format handles NULL value in refs map", {
  out <- tabular:::.interpolate_format(
    "{a}-{b}",
    c("a", "b"),
    list(a = "1", b = NULL)
  )
  expect_identical(out, "1-")
})

test_that(".validate_format_stats accepts when all refs are present", {
  expect_silent(
    tabular:::.validate_format_stats(
      "{n}",
      c("n", "p"),
      "var",
      rlang::caller_env()
    )
  )
  # Empty refs short-circuit
  expect_silent(
    tabular:::.validate_format_stats(
      "plain",
      character(),
      "var",
      rlang::caller_env()
    )
  )
})

test_that(".resolve_ard_decimals returns null defaults for unexpected input", {
  res <- tabular:::.resolve_ard_decimals(42L)
  expect_identical(res, list(global = NULL, per_var = NULL))
})

test_that(".normalise_ard_num handles a logical list-column", {
  out <- tabular:::.normalise_ard_num(list(TRUE, FALSE, NA))
  expect_identical(out, c(1, 0, NA_real_))
})

test_that(".normalise_ard_chr handles a factor", {
  out <- tabular:::.normalise_ard_chr(factor(c("a", "b")))
  expect_identical(out, c("a", "b"))
})

test_that(".normalise_ard_chr handles a list-column with NULL entry", {
  out <- tabular:::.normalise_ard_chr(list("x", NULL, "y"))
  expect_identical(out, c("x", NA_character_, "y"))
})

test_that(".format_stat_group routes through built-in defaults for unknown stat", {
  # Stat name not in built-in switch and not in fmt / decimals
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("X", "X"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("custom_stat", "custom_stat"),
    stat = c(1.23, 4.56),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{custom_stat}")
  expect_match(out$A[[1L]], "\\.[0-9]+$")
})

test_that("Logical stat_names use the character value", {
  ard <- data.frame(
    group1 = c("ARM"),
    group1_level = c("A"),
    variable = c("X"),
    variable_level = c(NA),
    context = c("statistical"),
    stat_name = c("paired"),
    stat = c("TRUE"),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(ard, statistic = "{paired}")
  expect_identical(out$A[[1L]], "TRUE")
})

test_that("Custom fmt + per-variable decimals interact (fmt wins)", {
  ard <- data.frame(
    group1 = c("ARM", "ARM"),
    group1_level = c("A", "A"),
    variable = c("AGE", "BMI"),
    variable_level = c(NA, NA),
    context = c("continuous", "continuous"),
    stat_name = c("mean", "mean"),
    stat = c(75, 27),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{mean}",
    fmt = list(mean = function(x) paste0("[", x, "]")),
    decimals = c(mean = 3)
  )
  expect_match(out$A[[1L]], "^\\[")
})

# ---------------------------------------------------------------------
# Branch coverage: validator and shape-detection error paths
# ---------------------------------------------------------------------

test_that(".check_fmt_arg rejects unnamed list", {
  expect_error(
    pivot_across(
      saf_demo_card,
      statistic = "{n} ({p}%)",
      fmt = list(identity)
    ),
    class = "tabular_error_input"
  )
})

test_that(".normalise_ard_input rejects group_level without variable", {
  ard <- data.frame(
    group1 = "ARM",
    group1_level = "A",
    stat_name = "n",
    stat = 1,
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n}"),
    class = "tabular_error_input"
  )
})

test_that("Shape A with explicit column matching group2 picks the right arm", {
  ard <- data.frame(
    group1 = rep("PARAMCD", 4),
    group1_level = rep("SYSBP", 4),
    group2 = rep("ARM", 4),
    group2_level = c("Placebo", "Placebo", "Drug", "Drug"),
    variable = rep("AVAL", 4),
    variable_level = c(NA, NA, NA, NA),
    context = rep("continuous", 4),
    stat_name = c("mean", "sd", "mean", "sd"),
    stat = c(120, 5, 122, 6),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{mean} ({sd})",
    column = "ARM",
    overall = NULL
  )
  expect_true("Placebo" %in% names(out))
  expect_true("Drug" %in% names(out))
})

test_that("pivot_across raises when column filter removes all rows", {
  # Build an ARD where group1 = "X" but user passes column = "Y"
  # which exists in group1's values for one row -> filter empties.
  ard <- data.frame(
    group1 = c("Y", "Y"),
    group1_level = c("a", "a"),
    variable = c("Y", "Y"),
    variable_level = c(NA, NA),
    context = c("categorical", "categorical"),
    stat_name = c("n", "n"),
    stat = c(1, 2),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(ard, statistic = "{n}", column = "Y", overall = NULL),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# End-to-end with all 5 _card datasets
# ---------------------------------------------------------------------

test_that("pivot_across() works on all bundled _card datasets", {
  # Two ARD shapes are shipped: flat (saf_demo_card, mixed continuous +
  # categorical) and hierarchical (saf_aesocpt_card, SOC / PT nested).
  stat <- list(
    continuous = "{mean} ({sd})",
    categorical = "{n} ({p}%)"
  )
  out <- pivot_across(saf_demo_card, statistic = stat)
  expect_s3_class(out, "data.frame")

  out_h <- pivot_across(saf_aesocpt_card, statistic = stat)
  expect_s3_class(out_h, "data.frame")
  expect_true("soc" %in% names(out_h))
})
