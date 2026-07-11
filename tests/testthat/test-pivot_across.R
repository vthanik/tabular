# pivot_across(): 25 edge cases from plan section 2.5 plus
# argument-validation cases.

# ---------------------------------------------------------------------
# Happy paths
# ---------------------------------------------------------------------

test_that("pivot_across() returns a data.frame", {
  out <- pivot_across(
    cdisc_saf_demo_ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  expect_s3_class(out, "data.frame")
  expect_true(all(c("variable", "stat_label") %in% names(out)))
})

test_that("pivot_across() produces one column per group1_level + overall", {
  out <- pivot_across(cdisc_saf_demo_ard)
  arm_cols <- setdiff(names(out), c("variable", "stat_label"))
  expect_true("Total" %in% arm_cols)
  expect_true("Placebo" %in% arm_cols)
  expect_true("Xanomeline Low Dose" %in% arm_cols)
  expect_true("Xanomeline High Dose" %in% arm_cols)
})

test_that("pivot_across() chains into tabular()", {
  spec <- pivot_across(cdisc_saf_demo_ard) |>
    tabular(titles = c("Table 14.1.1", "Demographics"))
  expect_true(is_tabular_spec(spec))
  expect_identical(spec@titles, c("Table 14.1.1", "Demographics"))
})

# ---------------------------------------------------------------------
# Edge case 1: Shape A (raw ard_stack)
# ---------------------------------------------------------------------

test_that("Shape A: raw ard_stack with group1/group1_level is auto-detected", {
  expect_no_error(pivot_across(cdisc_saf_demo_ard))
})

test_that("Shape A normalises list-stat columns", {
  ard <- cdisc_saf_demo_ard
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
  ard <- cdisc_saf_demo_ard
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
  ard <- cdisc_saf_demo_ard
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
# Edge case 7-8: hierarchical (SOC / PT) — cdisc_saf_aesocpt_ard
# ---------------------------------------------------------------------

test_that("Hierarchical ARD: SOC and PT columns appear in output", {
  out <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
  expect_true("soc" %in% names(out))
  expect_true("label" %in% names(out))
  expect_true("row_type" %in% names(out))
})

test_that("Hierarchical ARD keeps the ..ard_hierarchical_overall.. sentinel as a row", {
  out <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
  expect_true(any(out$row_type == "overall"))
})

test_that("keyed `hierarchical` statistic interpolates {p} on the hierarchical path", {
  # Regression: the hierarchical builder hardcoded context "categorical"
  # when resolving the format string, so a list keyed by the ARD's actual
  # `hierarchical` context fell through to the bare "{n}" default and
  # silently dropped the percent. A bare string still worked because it is
  # mirrored onto the `default` key. Both forms must now produce n (p%).
  keyed <- pivot_across(
    cdisc_saf_aesocpt_ard,
    statistic = list(hierarchical = "{n} ({p}%)")
  )
  bare <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
  col <- grep("[Pp]lacebo", names(keyed), value = TRUE)[1L]
  pruritus <- which(keyed$label == "PRURITUS")[1L]
  expect_match(keyed[[col]][pruritus], "^[0-9]+ \\([0-9.]+%\\)$")
  expect_identical(keyed[[col]], bare[[col]])
})

# ---------------------------------------------------------------------
# Edge case 9: ^\.\. sentinels other than the overall are filtered
# ---------------------------------------------------------------------

test_that("Other ^\\.\\. internal rows are filtered", {
  ard <- cdisc_saf_demo_ard
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
  ard <- cdisc_saf_demo_ard[
    cdisc_saf_demo_ard$context == "categorical",
    ,
    drop = FALSE
  ]
  out <- pivot_across(ard, statistic = "{n} ({p}%)")
  expect_s3_class(out, "data.frame")
  expect_true(nrow(out) >= 1L)
})

# ---------------------------------------------------------------------
# Edge case 11: named-list-by-context
# ---------------------------------------------------------------------

test_that("Named-list-by-context dispatches per context", {
  out <- pivot_across(
    cdisc_saf_demo_ard,
    statistic = list(
      continuous = "{mean} ({sd})",
      categorical = "{n} ({p}%)"
    )
  )
  # Sex M cell from Placebo should include ({p}%)
  sex_m <- out[out$stat_label == "M", ]
  expect_true(grepl("\\(", sex_m$Placebo[[1L]]))
})

# ---------------------------------------------------------------------
# Edge case 12: named-list-by-variable (var override + default fallback)
# ---------------------------------------------------------------------

test_that("Named-list-by-variable: per-variable spec wins, default falls through", {
  # Filter to AGE + categoricals so the categorical fallback handles
  # everything; WEIGHT/HEIGHT/BMI now also live in cdisc_saf_demo_ard and need
  # their own continuous rule which is not the scenario under test here.
  ard <- cdisc_saf_demo_ard[
    cdisc_saf_demo_ard$variable %in%
      c("AGE", "AGEGR1", "SEX", "RACE", "ETHNIC"),
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
    cdisc_saf_demo_ard,
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
  # stat_label is flush: the renderer owns indentation, not the pivot.
  expect_setequal(age_rows$stat_label, c("N", "Mean (SD)", "Median"))
})

# ---------------------------------------------------------------------
# Edge case 14: format string references unknown stat -> error
# ---------------------------------------------------------------------

test_that("Format string referencing unknown stat raises tabular_error_input", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      statistic = list(
        continuous = "{not_a_stat}",
        categorical = "{n} ({p}%)"
      )
    ),
    class = "tabular_error_input"
  )
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
    stat = c(0.0008),
    stringsAsFactors = FALSE
  )
  out <- pivot_across(
    ard,
    statistic = "{p}",
    decimals = c(p = 1),
    fmt = list(p = function(x) sprintf("%.1f", x * 100))
  )
  # Without the custom fmt this would render as "<0.1" (pharma threshold);
  # the custom fmt forces the exact rounded value. Use 0.0008 (= 0.08%)
  # rather than the rounding-boundary 0.0005 (= 0.05%) so the sprintf
  # rounds deterministically across platforms (Windows printf rounds
  # 0.05 to "0.0" while Unix rounds to "0.1").
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
    cdisc_saf_demo_ard,
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
    cdisc_saf_demo_ard,
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
# Edge case 25: stat_label is never pre-indented (renderer owns indent)
# ---------------------------------------------------------------------

test_that("stat_label carries no leading-space indent", {
  out <- pivot_across(
    cdisc_saf_demo_ard,
    statistic = list(
      continuous = c("Mean (SD)" = "{mean} ({sd})"),
      categorical = "{n} ({p}%)"
    )
  )
  # No baked-in indent: stat_label matches its trimmed form on every row.
  # Indentation is applied downstream via group_rows() /
  # group_display, never by pivot_across.
  expect_false(any(startsWith(out$stat_label, " "), na.rm = TRUE))
  expect_identical(out$stat_label, trimws(out$stat_label))
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
    pivot_across(cdisc_saf_demo_ard, statistic = 42L),
    class = "tabular_error_input"
  )
})

test_that("pivot_across() rejects fmt with non-function entries", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
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

  # Per-row-group: keyed by row_group levels -> per_group, never per_var.
  r3 <- tabular:::.resolve_ard_decimals(
    list(SYSBP = c(mean = 0), WEIGHT = c(mean = 1), .default = c(sd = 2)),
    row_group = "PARAM",
    rg_levels = c("SYSBP", "WEIGHT")
  )
  expect_null(r3$global)
  expect_null(r3$per_var)
  expect_identical(
    r3$per_group$map,
    list(SYSBP = c(mean = 0), WEIGHT = c(mean = 1))
  )
  expect_identical(r3$per_group$default, c(sd = 2))

  # row_group set but a key is not a level -> stays per-variable (no per_group).
  r4 <- tabular:::.resolve_ard_decimals(
    list(SYSBP = c(mean = 0), AGE = c(mean = 1)),
    row_group = "PARAM",
    rg_levels = c("SYSBP", "WEIGHT")
  )
  expect_null(r4$per_group)
  expect_identical(r4$per_var, list(SYSBP = c(mean = 0), AGE = c(mean = 1)))

  # row_group NULL but keys match no variable -> error.
  expect_error(
    tabular:::.resolve_ard_decimals(
      list(SYSBP = c(mean = 0)),
      variables = c("AVAL", "AGE")
    ),
    class = "tabular_error_input"
  )
})

# A by-PARAM continuous ARD (PARAM x TRTA, mean + sd) for per-row-group tests.
mk_keyed_meansd <- function() {
  spec <- list(
    c("SYSBP", "Exp", "mean", "133.27"),
    c("SYSBP", "Exp", "sd", "15.81"),
    c("SYSBP", "Ctl", "mean", "128.94"),
    c("SYSBP", "Ctl", "sd", "14.02"),
    c("WEIGHT", "Exp", "mean", "71.43"),
    c("WEIGHT", "Exp", "sd", "12.77"),
    c("WEIGHT", "Ctl", "mean", "73.06"),
    c("WEIGHT", "Ctl", "sd", "13.19")
  )
  do.call(
    rbind,
    lapply(spec, function(r) {
      data.frame(
        group1 = "PARAM",
        group1_level = r[[1L]],
        group2 = "TRTA",
        group2_level = r[[2L]],
        variable = "AVAL",
        variable_level = NA_character_,
        context = "continuous",
        stat_name = r[[3L]],
        stat_label = r[[3L]],
        stat = I(list(as.numeric(r[[4L]]))),
        stringsAsFactors = FALSE
      )
    })
  )
}

test_that("pivot_across: decimals vary by row_group", {
  out <- pivot_across(
    mk_keyed_meansd(),
    column = "TRTA",
    row_group = "PARAM",
    overall = NULL,
    statistic = list(continuous = "{mean} ({sd})"),
    decimals = list(
      SYSBP = c(mean = 0, sd = 1),
      WEIGHT = c(mean = 1, sd = 2)
    )
  )
  sysbp <- out[out$PARAM == "SYSBP", ]
  weight <- out[out$PARAM == "WEIGHT", ]
  # SYSBP: mean 0 dp, sd 1 dp -> "133 (15.8)".
  expect_identical(sysbp$Exp[[1L]], "133 (15.8)")
  # WEIGHT: mean 1 dp, sd 2 dp -> "71.4 (12.77)".
  expect_identical(weight$Exp[[1L]], "71.4 (12.77)")
})

test_that("pivot_across: per-row-group .default covers an unlisted group", {
  out <- pivot_across(
    mk_keyed_meansd(),
    column = "TRTA",
    row_group = "PARAM",
    overall = NULL,
    statistic = list(continuous = "{mean} ({sd})"),
    decimals = list(
      SYSBP = c(mean = 0, sd = 1),
      .default = c(mean = 2, sd = 3)
    )
  )
  # WEIGHT is unlisted -> .default: mean 2 dp, sd 3 dp.
  weight <- out[out$PARAM == "WEIGHT", ]
  expect_identical(weight$Exp[[1L]], "71.43 (12.770)")
})

test_that("pivot_across: per-group token falls back to group .default then built-in", {
  out <- pivot_across(
    mk_keyed_meansd(),
    column = "TRTA",
    row_group = "PARAM",
    overall = NULL,
    statistic = list(continuous = "{mean} ({sd})"),
    decimals = list(
      SYSBP = c(mean = 0),
      .default = c(sd = 4)
    )
  )
  # SYSBP mean -> group token (0 dp); SYSBP sd -> group .default token (4 dp).
  sysbp <- out[out$PARAM == "SYSBP", ]
  expect_identical(sysbp$Exp[[1L]], "133 (15.8100)")
})

test_that("pivot_across: per-group token with no spec or .default uses built-in", {
  out <- pivot_across(
    mk_keyed_meansd(),
    column = "TRTA",
    row_group = "PARAM",
    overall = NULL,
    statistic = list(continuous = "{mean} ({sd})"),
    decimals = list(SYSBP = c(mean = 0))
  )
  # SYSBP mean -> group token (0 dp); SYSBP sd -> no token, no .default ->
  # built-in sd default (2 dp). WEIGHT is unlisted, no .default -> built-in.
  sysbp <- out[out$PARAM == "SYSBP", ]
  weight <- out[out$PARAM == "WEIGHT", ]
  expect_identical(sysbp$Exp[[1L]], "133 (15.81)")
  expect_identical(weight$Exp[[1L]], "71.4 (12.77)")
})

test_that("pivot_across: a bare scalar per group applies to every token", {
  out <- pivot_across(
    mk_keyed_meansd(),
    column = "TRTA",
    row_group = "PARAM",
    overall = NULL,
    statistic = list(continuous = "{mean} ({sd})"),
    decimals = list(SYSBP = 0, WEIGHT = 3)
  )
  sysbp <- out[out$PARAM == "SYSBP", ]
  weight <- out[out$PARAM == "WEIGHT", ]
  expect_identical(sysbp$Exp[[1L]], "133 (16)")
  expect_identical(weight$Exp[[1L]], "71.430 (12.770)")
})

test_that(".format_stat_group: NA-group rows fall back, not blanked", {
  decimals <- list(
    global = NULL,
    per_var = NULL,
    per_group = list(default = c(mean = 2), map = list(SYSBP = c(mean = 0)))
  )
  out <- tabular:::.format_stat_group(
    values = c(133.27, 71.43),
    value_chrs = c(NA_character_, NA_character_),
    stat_name = "mean",
    variables = c("AVAL", "AVAL"),
    decimals = decimals,
    fmt = NULL,
    pct_threshold = TRUE,
    call = rlang::caller_env(),
    groups = c("SYSBP", NA_character_)
  )
  # SYSBP -> 0 dp; NA group -> per-group .default (2 dp), never blank.
  expect_identical(out, c("133", "71.43"))
})

test_that("pivot_across: per-row-group decimals with row_group = NULL errors", {
  expect_snapshot(
    error = TRUE,
    pivot_across(
      mk_keyed_meansd(),
      column = "TRTA",
      statistic = list(continuous = "{mean} ({sd})"),
      decimals = list(SYSBP = c(mean = 0), WEIGHT = c(mean = 1))
    )
  )
  expect_error(
    pivot_across(
      mk_keyed_meansd(),
      column = "TRTA",
      statistic = list(continuous = "{mean} ({sd})"),
      decimals = list(SYSBP = c(mean = 0), WEIGHT = c(mean = 1))
    ),
    class = "tabular_error_input"
  )
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
  med_val <- out$A[out$stat_label == "Median"]
  expect_match(med_val, "\\.[0-9]{1}$")
})

# ---------------------------------------------------------------------
# Cross-shape identity test
# ---------------------------------------------------------------------

test_that("Shape A and Shape B produce identical wide output on the same data", {
  ard_a <- cdisc_saf_demo_ard
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
  out <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
  expect_true(any(out$row_type == "soc"))
  expect_true(any(out$row_type == "pt"))
  # Within a single SOC the soc value repeats across the PT rows
  one_soc <- out$soc[out$row_type == "soc"][1L]
  pts_in_soc <- out[out$soc == one_soc & out$row_type == "pt", ]
  expect_true(nrow(pts_in_soc) >= 1L)
})

test_that("Hierarchical ARD respects label remap on soc / pt cols", {
  out <- pivot_across(
    cdisc_saf_aesocpt_ard,
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
  m_row <- out[out$stat_label == "M", ]
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
  # cdisc_saf_aesocpt_ard was built with .overall = FALSE via the
  # cards::ard_stack_hierarchical(over_variables = TRUE) path, which
  # uses ..ard_hierarchical_overall.. instead of the group-shift quirk;
  # verifying it renders cleanly is enough to exercise the bypass.
  out <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
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
      cdisc_saf_demo_ard,
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
  # Two ARD shapes are shipped: flat (cdisc_saf_demo_ard, mixed continuous +
  # categorical) and hierarchical (cdisc_saf_aesocpt_ard, SOC / PT nested).
  stat <- list(
    continuous = "{mean} ({sd})",
    categorical = "{n} ({p}%)"
  )
  out <- pivot_across(cdisc_saf_demo_ard, statistic = stat)
  expect_s3_class(out, "data.frame")

  out_h <- pivot_across(cdisc_saf_aesocpt_ard, statistic = stat)
  expect_s3_class(out_h, "data.frame")
  expect_true("soc" %in% names(out_h))
})

test_that(".hier_append_chunk fills the leaf with the current value, deeper keys NA (#cw10)", {
  # 3-level hierarchy out_cols = c("soc", "l2", "label"). A SOC (level-1)
  # row must NOT pollute the intermediate l2 key with the SOC name; the
  # leaf "label" column shows the row's own (deepest) value.
  out_cols <- c("soc", "l2", "label")
  cells <- stats::setNames("5", "armA")

  state <- new.env(parent = emptyenv())
  state$chunks <- list()
  state$chunk_idx <- 0L

  # level-1 SOC row: ancestors none, current = "Cardiac"
  tabular:::.hier_append_chunk(state, "Cardiac", "soc", cells, out_cols, 3L)
  soc_row <- state$chunks[[1L]]
  expect_identical(soc_row$soc[[1L]], "Cardiac")
  expect_true(is.na(soc_row$l2[[1L]])) # intermediate key not polluted
  expect_identical(soc_row$label[[1L]], "Cardiac") # leaf = current value

  # level-2 HLT row under Cardiac
  tabular:::.hier_append_chunk(
    state,
    c("Cardiac", "Arrhythmias"),
    "hlt",
    cells,
    out_cols,
    3L
  )
  hlt_row <- state$chunks[[2L]]
  expect_identical(hlt_row$soc[[1L]], "Cardiac")
  expect_identical(hlt_row$l2[[1L]], "Arrhythmias")
  expect_identical(hlt_row$label[[1L]], "Arrhythmias") # leaf = current value
})

# ---------------------------------------------------------------------
# Regression: mixed ard_summary + ard_tabulate stack keeps categorical
# rows; only the .by by-variable's own tabulation is dropped (B1)
# ---------------------------------------------------------------------

test_that("pivot_across keeps tabulate-context categorical rows (B1)", {
  # Relabel the bundled cards-like ARD so its data variables carry the
  # "summary" / "tabulate" contexts that ard_summary() / ard_tabulate()
  # emit, reproducing the B1 shape without a `cards` dependency.
  card_st <- cdisc_saf_demo_ard
  card_st$context[card_st$context == "continuous"] <- "summary"
  card_st$context[card_st$context == "categorical"] <- "tabulate"

  out <- pivot_across(
    card_st,
    statistic = list(
      summary = "{mean} ({sd})",
      tabulate = "{n} ({p}%)"
    )
  )

  # Genuine tabulate-context categorical variables survive the internal-row
  # filter; before the fix every "tabulate" row was dropped.
  expect_true(all(c("SEX", "RACE") %in% out$variable))
  # A summary-context continuous variable also survives.
  expect_true("AGE" %in% out$variable)
  # SEX levels appear in the output as flush stat_label values.
  sex_rows <- out[out$variable == "SEX", , drop = FALSE]
  expect_true(all(c("F", "M") %in% sex_rows$stat_label))
  # The by-variable's own tabulation (context "tabulate", no arm) is still
  # filtered out.
  expect_false("TRT01A" %in% out$variable)
})

test_that("pivot_across keeps the Total column for tabulate categoricals (B1)", {
  # Regression for the over-broad is_by_var_selfrow mask: a genuine
  # categorical variable's pooled/overall row (NA arm, tabulate context)
  # is the one `overall =` relabels to "Total". The old structural mask
  # `ctx == "tabulate" & is.na(arm)` dropped it, blanking the Total column
  # for every categorical variable. The by-variable self-row is removed by
  # NAME (variable == column) instead, leaving genuine Total rows intact.
  card_st <- cdisc_saf_demo_ard
  card_st$context[card_st$context == "continuous"] <- "summary"
  card_st$context[card_st$context == "categorical"] <- "tabulate"

  out <- pivot_across(
    card_st,
    statistic = list(
      summary = "{mean} ({sd})",
      tabulate = "{n} ({p}%)"
    )
  )

  # The pooled denominator column survives for a tabulate categorical.
  expect_true("Total" %in% names(out))
  sex_rows <- out[out$variable == "SEX", , drop = FALSE]
  expect_true(all(nzchar(trimws(sex_rows$Total))))
  # A continuous (summary) variable's Total is populated too (control).
  age_rows <- out[out$variable == "AGE", , drop = FALSE]
  expect_true(all(nzchar(trimws(age_rows$Total))))
})

test_that("pivot_across renders an arm-less tabulate ARD without aborting (B1)", {
  # Corollary of the same over-broad mask: a single-population ard_tabulate
  # ARD (no treatment split, every arm NA) had ALL rows match the mask and
  # errored with "No displayable rows remain". With no grouping column
  # (Shape C) the rows must be kept and pooled under `overall`.
  card <- cdisc_saf_demo_ard[
    cdisc_saf_demo_ard$context == "categorical",
    ,
    drop = FALSE
  ]
  # Drop the grouping dimension entirely so every row is single-population.
  card$group1 <- NULL
  card$group1_level <- NULL
  card$context <- "tabulate"

  out <- pivot_across(card, statistic = list(tabulate = "{n} ({p}%)"))
  expect_true(nrow(out) > 0L)
  expect_true("SEX" %in% out$variable)
})

test_that(".normalise_shape_d normalises a list-column arm to NA, not 'NULL' (B1)", {
  # Shape D (no `variable` column) reconstructs the ARD and previously used
  # as.character() on the arm column, stringifying a cards list-column NULL
  # element (the pooled / self row) to the literal "NULL". It must use
  # .normalise_ard_chr like the shape-B path, yielding NA.
  data <- data.frame(
    context = c("categorical", "categorical", "categorical"),
    stat_name = c("n", "n", "n"),
    stat_label = c("F", "M", "F"),
    stat = c(53, 33, NA_real_),
    stringsAsFactors = FALSE
  )
  data$SEX <- c("F", "M", "F")
  data$TRT <- I(list("Placebo", "Placebo", NULL))

  res <- tabular:::.normalise_shape_d(
    data,
    column = "TRT",
    call = rlang::current_env()
  )
  expect_identical(res$df$arm, c("Placebo", "Placebo", NA))
  expect_false(any(res$df$arm %in% "NULL"))
})

# B2: row_group — second non-column grouping dimension ---------------

# Mimics ard_stack(.by = c(ARM, SEX)): RACE counts crossed by ARM and
# SEX, plus the by-marginal SEX tabulate rows ard_stack injects (the
# rows that mis-trip hierarchy detection on the column-only path).
mk_2by_ard <- function() {
  arms <- c("Placebo", "Drug")
  sexes <- c("F", "M")
  races <- c("WHITE", "BLACK")
  rows <- list()
  for (a in arms) {
    for (s in sexes) {
      for (r in races) {
        rows[[length(rows) + 1L]] <- data.frame(
          group1 = "ARM",
          group1_level = a,
          group2 = "SEX",
          group2_level = s,
          variable = "RACE",
          variable_level = r,
          context = "categorical",
          stat_name = c("n", "p"),
          stat = I(list(10, 0.25)),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  for (a in arms) {
    for (s in sexes) {
      rows[[length(rows) + 1L]] <- data.frame(
        group1 = "ARM",
        group1_level = a,
        group2 = NA,
        group2_level = NA,
        variable = "SEX",
        variable_level = s,
        context = "tabulate",
        stat_name = c("n", "p"),
        stat = I(list(20, 0.5)),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

test_that("row_group widens a 2-variable .by cleanly with no phantom Total (#B2)", {
  out <- pivot_across(
    mk_2by_ard(),
    column = "ARM",
    row_group = "SEX",
    statistic = list(categorical = "{n} ({p}%)")
  )
  # SEX is a leading row-group column, not a hierarchy and not a column.
  expect_true("SEX" %in% names(out))
  expect_false("Total" %in% names(out))
  expect_false("soc" %in% names(out)) # not mis-read as a hierarchy
  expect_setequal(out$SEX, c("F", "M"))
  # Only the RACE content survives; the by-marginal SEX rows are dropped.
  expect_setequal(unique(out$variable), "RACE")
  expect_true(all(c("Placebo", "Drug") %in% names(out)))
})

test_that("row_group factor level order is preserved (#B2)", {
  ard <- mk_2by_ard()
  out <- pivot_across(
    ard,
    column = "ARM",
    row_group = "SEX",
    statistic = list(categorical = "{n}")
  )
  expect_identical(unique(out$SEX), c("F", "M"))
})

test_that("row_group output composes with subgroup() (#B2)", {
  out <- pivot_across(
    mk_2by_ard(),
    column = "ARM",
    row_group = "SEX",
    statistic = list(categorical = "{n} ({p}%)")
  )
  # The SEX column is an ordinary column the downstream verb can page on.
  spec <- tabular(out) |> subgroup(by = "SEX")
  expect_s3_class(spec, "tabular::tabular_spec")
})

test_that("row_group errors when not a second grouping variable (#B2)", {
  expect_error(
    pivot_across(
      mk_2by_ard(),
      column = "ARM",
      row_group = "NOPE",
      statistic = list(categorical = "{n}")
    ),
    class = "tabular_error_input"
  )
})

test_that("row_group errors when equal to column (#B2)", {
  expect_error(
    pivot_across(
      mk_2by_ard(),
      column = "ARM",
      row_group = "ARM",
      statistic = list(categorical = "{n}")
    ),
    class = "tabular_error_input"
  )
})

test_that("row_group errors on a non-character value (#B2)", {
  expect_error(
    pivot_across(
      mk_2by_ard(),
      column = "ARM",
      row_group = 1L,
      statistic = list(categorical = "{n}")
    ),
    class = "tabular_error_input"
  )
})

test_that("row_group errors when the ARD has no second grouping variable (#B2)", {
  # A single-.by ARD has no extra_groups; the error names that case.
  single_by <- data.frame(
    group1 = "ARM",
    group1_level = c("Placebo", "Drug"),
    variable = "SEX",
    variable_level = "F",
    context = "categorical",
    stat_name = "n",
    stat = I(list(40, 38)),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(
      single_by,
      column = "ARM",
      row_group = "SEX",
      statistic = list(categorical = "{n}")
    ),
    class = "tabular_error_input"
  )
})

test_that("a real SOC/PT hierarchy is still detected with no row_group (#B2 no-regress)", {
  out <- pivot_across(
    cdisc_saf_aesocpt_ard,
    statistic = list(continuous = "{mean} ({sd})", categorical = "{n} ({p}%)")
  )
  expect_true("soc" %in% names(out)) # hierarchy path intact (compat row F)
})

test_that("row_group on a genuine hierarchy errors instead of corrupting (#B2)", {
  # AEBODSYS is in extra_groups, so .check_row_group passes; the hierarchy
  # guard must catch the misuse before the flat path flattens the SOC/PT
  # nesting and leaks the ..ard_hierarchical_overall.. sentinel row.
  expect_error(
    pivot_across(
      cdisc_saf_aesocpt_ard,
      row_group = "AEBODSYS",
      statistic = "{n}"
    ),
    class = "tabular_error_input"
  )
})

# B1: warn on a totally mis-keyed statistic ---------------------------

mk_cat_ard <- function() {
  rows <- list()
  for (a in c("Placebo", "Drug")) {
    rows[[length(rows) + 1L]] <- data.frame(
      group1 = "ARM",
      group1_level = a,
      variable = "SEX",
      variable_level = "F",
      context = "categorical",
      stat_name = c("n", "p"),
      stat = I(list(40, 0.5)),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

test_that("an explicit statistic matching no context warns (#B1)", {
  expect_warning(
    pivot_across(
      mk_cat_ard(),
      column = "ARM",
      statistic = list(continuous = "{mean}")
    ),
    class = "tabular_warning_unmatched_context"
  )
})

test_that("the unmatched-context warning names the keys and contexts (#B1)", {
  w <- tryCatch(
    pivot_across(
      mk_cat_ard(),
      column = "ARM",
      statistic = list(summary = "{mean}")
    ),
    warning = function(w) conditionMessage(w)
  )
  expect_match(w, "summary")
  expect_match(w, "categorical")
})

test_that("a default (un-supplied) statistic never warns (#B1)", {
  # The {n} fallback is the correct output for a plain count ARD; a
  # default call must stay silent.
  expect_no_warning(
    pivot_across(mk_cat_ard(), column = "ARM")
  )
})

test_that("a partially-matching statistic does not warn (#B1)", {
  # categorical matches; the user is trusted for any other contexts.
  expect_no_warning(
    pivot_across(
      mk_cat_ard(),
      column = "ARM",
      statistic = list(categorical = "{n}")
    )
  )
})

test_that("a default = key suppresses the unmatched-context warning (#B1)", {
  expect_no_warning(
    pivot_across(
      mk_cat_ard(),
      column = "ARM",
      statistic = list(continuous = "{mean}", default = "{n}")
    )
  )
})

test_that("a hierarchical ARD never warns even when keys do not match (#B1)", {
  expect_no_warning(
    pivot_across(
      cdisc_saf_aesocpt_ard,
      statistic = list(continuous = "{mean}")
    )
  )
})

test_that("hierarchical overall row is relabelled, not the raw sentinel (#ard-overall)", {
  # Regression: pivot_across() on a cards ard_stack_hierarchical ARD leaked the
  # internal `..ard_hierarchical_overall..` sentinel into the overall row's
  # soc / label columns instead of giving it a readable label.
  wide <- pivot_across(cdisc_saf_aesocpt_ard, statistic = "{n} ({p}%)")
  stub <- unlist(wide[intersect(c("variable", "soc", "label"), names(wide))])
  expect_false(any(grepl("..", stub, fixed = TRUE)))
  ov <- wide[wide$row_type == "overall", , drop = FALSE]
  expect_equal(nrow(ov), 1L)
  expect_equal(ov$label, "Overall")
})

test_that("the `label` map overrides the overall sentinel default (#ard-overall)", {
  # The user can rename the sentinel via the same `label` map; the registry
  # default ("Overall") is only the fallback.
  wide <- pivot_across(
    cdisc_saf_aesocpt_ard,
    statistic = "{n} ({p}%)",
    label = c("..ard_hierarchical_overall.." = "TOTAL SUBJECTS WITH AN EVENT")
  )
  ov <- wide[wide$row_type == "overall", , drop = FALSE]
  expect_equal(ov$label, "TOTAL SUBJECTS WITH AN EVENT")
  expect_false(any(grepl("..", wide$label, fixed = TRUE)))
})

test_that("overall append leaves intermediate nesting columns NA at depth 3 (#ard-overall)", {
  # Pins the length-1 append contract: at >= 3 levels the leaf (label) and soc
  # carry the sentinel while the intermediate `l2` stays NA, so relabelling
  # soc/label alone cannot leave a sentinel behind in `l2`.
  state <- new.env(parent = emptyenv())
  state$chunks <- list()
  state$chunk_idx <- 0L
  tabular:::.hier_append_chunk(
    state,
    "..ard_hierarchical_overall..",
    "overall",
    stats::setNames(c("1", "2"), c("A", "B")),
    out_cols = c("soc", "l2", "label"),
    n_levels = 3L
  )
  chunk <- state$chunks[[1L]]
  expect_true(all(chunk$soc == "..ard_hierarchical_overall.."))
  expect_true(all(is.na(chunk$l2)))
  expect_true(all(chunk$label == "..ard_hierarchical_overall.."))
})

test_that("flat ARD path is unaffected by the always-run label map (#ard-overall)", {
  # Dropping the `if (!is.null(label))` guard must not perturb the flat path:
  # variable names stay verbatim and nothing leaks. (Default statistic: the
  # demo ARD mixes continuous + categorical variables.)
  wide <- pivot_across(cdisc_saf_demo_ard)
  expect_true("AGE" %in% wide$variable)
  expect_false(any(grepl("..", unlist(wide), fixed = TRUE)))
})

test_that("overall = NULL still relabels the hierarchical overall row (#ard-overall)", {
  # `overall` is the NA-arm COLUMN control, independent of the hierarchical
  # overall ROW; the sentinel relabel must not depend on it.
  wide <- pivot_across(
    cdisc_saf_aesocpt_ard,
    statistic = "{n} ({p}%)",
    overall = NULL
  )
  ov <- wide[wide$row_type == "overall", , drop = FALSE]
  expect_equal(ov$label, "Overall")
  expect_false(any(grepl("..", wide$label, fixed = TRUE)))
})

test_that("`overall` colliding with a real arm warns (collision guard) (#ard-overall)", {
  # A study arm literally named the same as `overall` collides with the
  # relabeled NA-arm pooled rows: both land in one column. Warn so the
  # silent merge is visible.
  df <- data.frame(
    arm = c("Drug", "Total", NA),
    stat = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  expect_warning(
    tabular:::.apply_overall_label(df, overall = "Total"),
    class = "tabular_warning_input"
  )
  # No NA rows -> nothing relabeled -> no collision, no warning.
  clean <- data.frame(arm = c("Drug", "Total"), stat = c(1, 2))
  expect_no_warning(tabular:::.apply_overall_label(clean, overall = "Total"))
})

test_that("every kept sentinel has a default label (registry drift guard) (#ard-overall)", {
  # If a future kept sentinel is added without a default label it would leak;
  # this pins names(sentinel_labels) == keep_sentinels.
  expect_setequal(
    names(tabular:::.tabular_ard_const$sentinel_labels),
    tabular:::.tabular_ard_const$keep_sentinels
  )
})

# ---------------------------------------------------------------------
# Variable bands + auxiliary columns (GAP 1 / GAP 2)
# ---------------------------------------------------------------------

# A 2-group continuous ARD: variables AVAL + PCHG by AVISIT x TRTA.
mk_valchg_ard <- function() {
  specs <- list(
    AVAL = c(N = 20, mean = 320, sd = 90, median = 318),
    PCHG = c(N = 20, mean = -15, sd = 5, median = -14)
  )
  rows <- list()
  i <- 0L
  for (v in names(specs)) {
    sn <- names(specs[[v]])
    for (av in c("DAY 1", "DAY 2")) {
      for (tr in c("Drug", "Placebo")) {
        i <- i + 1L
        rows[[i]] <- data.frame(
          group1 = "AVISIT",
          group1_level = av,
          group2 = "TRTA",
          group2_level = tr,
          variable = v,
          variable_level = NA_character_,
          context = "continuous",
          stat_name = sn,
          stat_label = sn,
          stat = I(as.list(unname(specs[[v]]))),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

# A continuous main ARD with one row per PARAM x TRTA (1:1 on PARAM).
mk_keyed_main <- function() {
  rows <- list()
  i <- 0L
  for (p in c("ORR", "DCR")) {
    for (tr in c("Exp", "Ctl")) {
      i <- i + 1L
      rows[[i]] <- data.frame(
        group1 = "PARAM",
        group1_level = p,
        group2 = "TRTA",
        group2_level = tr,
        variable = "AVAL",
        variable_level = NA_character_,
        context = "continuous",
        stat_name = "mean",
        stat_label = "mean",
        stat = I(list(2.0)),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# A single-group ARD keyed by PARAM only (an auxiliary comparison ARD).
mk_keyed_single <- function(varname, vals) {
  rows <- list()
  i <- 0L
  for (p in names(vals)) {
    i <- i + 1L
    rows[[i]] <- data.frame(
      group1 = "PARAM",
      group1_level = p,
      variable = varname,
      variable_level = NA_character_,
      context = "continuous",
      stat_name = "mean",
      stat_label = "mean",
      stat = I(list(unname(vals[[p]]))),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

# Two displayed rows per PARAM (a categorical with two levels).
mk_keyed_main_multi <- function() {
  rows <- list()
  i <- 0L
  for (p in c("ORR", "DCR")) {
    for (tr in c("Exp", "Ctl")) {
      for (l in c("Y", "N")) {
        i <- i + 1L
        rows[[i]] <- data.frame(
          group1 = "PARAM",
          group1_level = p,
          group2 = "TRTA",
          group2_level = tr,
          variable = "RESP",
          variable_level = l,
          context = "categorical",
          stat_name = c("n", "p"),
          stat_label = c("n", "p"),
          stat = I(list(10, 0.5)),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

test_that("column rejects two grouping variables with a classed error (#bands)", {
  # Pre-fix this raised a raw `the condition has length > 1` from an
  # unguarded `if`; it must now be a friendly tabular_error_input.
  expect_error(
    pivot_across(cdisc_saf_demo_ard, column = c("TRT01A", "SEX")),
    class = "tabular_error_input"
  )
  expect_error(
    pivot_across(cdisc_saf_demo_ard, column = c("TRT01A", "SEX")),
    regexp = "single grouping variable"
  )
})

test_that("column = .stat without .variable errors (#bands)", {
  expect_error(
    pivot_across(cdisc_saf_demo_ard, column = ".stat"),
    class = "tabular_error_input"
  )
})

test_that("column mixing .stat with a group var errors (#bands)", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      column = c(".variable", ".stat", "TRT01A")
    ),
    class = "tabular_error_input"
  )
})

test_that("duplicate column entries error (#bands)", {
  expect_error(
    pivot_across(cdisc_saf_demo_ard, column = c(".variable", ".variable")),
    class = "tabular_error_input"
  )
})

test_that("column = c('.variable', arm) bands variables, stats as rows (#bands)", {
  out <- pivot_across(
    mk_valchg_ard(),
    column = c(".variable", "TRTA"),
    row_group = "AVISIT",
    statistic = list(
      AVAL = c(N = "{N}", "Mean (SD)" = "{mean} ({sd})"),
      PCHG = c(N = "{N}", Mean = "{mean}")
    )
  )
  expect_true(all(
    c("AVAL..Drug", "AVAL..Placebo", "PCHG..Drug", "PCHG..Placebo") %in%
      names(out)
  ))
  expect_true("AVISIT" %in% names(out))
  expect_setequal(
    attr(out, "across_cols"),
    c("AVAL..Drug", "AVAL..Placebo", "PCHG..Drug", "PCHG..Placebo")
  )
})

test_that("ragged stat lists across bands stack with NA padding (#bands)", {
  out <- pivot_across(
    mk_valchg_ard(),
    column = c(".variable", "TRTA"),
    row_group = "AVISIT",
    statistic = list(
      AVAL = c("Mean (SD)" = "{mean} ({sd})"),
      PCHG = c(Mean = "{mean}")
    )
  )
  mean_sd <- out[out$stat_label == "Mean (SD)", , drop = FALSE]
  expect_true(all(is.na(mean_sd$`PCHG..Drug`)))
  mean_row <- out[out$stat_label == "Mean", , drop = FALSE]
  expect_true(all(is.na(mean_row$`AVAL..Drug`)))
})

test_that("per-variable decimals resolve inside each band (#bands)", {
  out <- pivot_across(
    mk_valchg_ard(),
    column = c(".variable", "TRTA"),
    row_group = "AVISIT",
    statistic = list(AVAL = c(Mean = "{mean}"), PCHG = c(Mean = "{mean}")),
    decimals = list(AVAL = c(mean = 0), PCHG = c(mean = 2))
  )
  expect_true("320" %in% out$`AVAL..Drug`)
  expect_true("-15.00" %in% out$`PCHG..Drug`)
})

test_that("column = c('.variable', '.stat') spreads stats as columns (#bands)", {
  out <- pivot_across(
    mk_valchg_ard(),
    column = c(".variable", ".stat"),
    row_group = "AVISIT",
    statistic = list(
      AVAL = c(N = "{N}", Mean = "{mean}", SD = "{sd}"),
      PCHG = c(N = "{N}", Mean = "{mean}")
    )
  )
  expect_true(all(
    c("AVAL..N", "AVAL..Mean", "AVAL..SD", "PCHG..N", "PCHG..Mean") %in%
      names(out)
  ))
  expect_true("TRTA" %in% names(out)) # arm drops to a leading row stub
  expect_setequal(out$TRTA, c("Drug", "Placebo"))
})

test_that(".variable band rejects a hierarchical ARD (#bands)", {
  expect_error(
    pivot_across(cdisc_saf_aesocpt_ard, column = c(".variable", "TRT01A")),
    class = "tabular_error_input"
  )
})

test_that("aux binds a comparison column joined on row_group (#aux)", {
  out <- pivot_across(
    mk_keyed_main(),
    column = "TRTA",
    row_group = "PARAM",
    statistic = list(continuous = "{mean}"),
    aux = list(
      "Difference" = list(
        ard = mk_keyed_single("d", c(ORR = 0.12, DCR = 0.20)),
        statistic = "{mean}",
        decimals = c(mean = 2)
      )
    )
  )
  expect_true("Difference" %in% names(out))
  expect_true("Difference" %in% attr(out, "across_cols"))
  expect_equal(out$Difference[out$PARAM == "ORR"], "0.12")
})

test_that("aux binds multiple comparison columns left to right (#aux)", {
  out <- pivot_across(
    mk_keyed_main(),
    column = "TRTA",
    row_group = "PARAM",
    statistic = list(continuous = "{mean}"),
    aux = list(
      "Difference" = list(
        ard = mk_keyed_single("d", c(ORR = 0.12, DCR = 0.20)),
        statistic = "{mean}"
      ),
      "p-value" = list(
        ard = mk_keyed_single("p", c(ORR = 0.03, DCR = 0.18)),
        statistic = "{mean}"
      )
    )
  )
  expect_true(all(c("Difference", "p-value") %in% names(out)))
  expect_lt(which(names(out) == "Difference"), which(names(out) == "p-value"))
})

test_that("aux errors when the main table is not 1:1 on the join key (#aux)", {
  expect_error(
    pivot_across(
      mk_keyed_main_multi(),
      column = "TRTA",
      row_group = "PARAM",
      statistic = list(categorical = "{n} ({p}%)"),
      aux = list(
        "Difference" = list(
          ard = mk_keyed_single("d", c(ORR = 0.12, DCR = 0.20)),
          statistic = "{mean}"
        )
      )
    ),
    class = "tabular_error_input"
  )
})

test_that("aux must be a named list of specs (#aux)", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      column = "TRT01A",
      aux = list(list(ard = mk_keyed_single("d", c(ORR = 1))))
    ),
    class = "tabular_error_input"
  )
})

test_that("aux entry must carry an ard (#aux)", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      column = "TRT01A",
      aux = list(X = list(statistic = "{n}"))
    ),
    class = "tabular_error_input"
  )
})

test_that("non-character column errors (#bands)", {
  expect_error(
    pivot_across(cdisc_saf_demo_ard, column = 1L),
    class = "tabular_error_input"
  )
})

test_that("column = c('.variable', arm1, arm2) errors (#bands)", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      column = c(".variable", "TRT01A", "SEX")
    ),
    class = "tabular_error_input"
  )
})

test_that("a variable band needs a variable column (#bands)", {
  nv <- data.frame(
    group1 = "TRTA",
    group1_level = c("A", "B"),
    context = "continuous",
    stat_name = "mean",
    stat_label = "mean",
    stat = I(list(1, 2)),
    stringsAsFactors = FALSE
  )
  expect_error(
    pivot_across(nv, column = c(".variable", "TRTA")),
    class = "tabular_error_input"
  )
})

test_that("aux requires a row_group (#aux)", {
  expect_error(
    pivot_across(
      cdisc_saf_demo_ard,
      column = "TRT01A",
      aux = list(
        "X" = list(
          ard = mk_keyed_single("d", c(ORR = 1)),
          statistic = "{mean}"
        )
      )
    ),
    class = "tabular_error_input"
  )
})
