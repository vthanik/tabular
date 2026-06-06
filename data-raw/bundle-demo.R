# data-raw/bundle-demo.R
# Build 9 demo datasets for tabular's examples, tests, vignettes.
# Source data: pharmaverseadam (adsl, adae, advs, adrs_onco).
#
# This is a from-scratch rebuild (2026-05): the datasets are richer
# than the v0.0.x originals and no longer constrained by a hard 50 KB
# ceiling. Every dataset is designed to make the canonical clinical
# table from the SAP / shell renderable with one tabular() pipeline.
#
# Five pre-summarised wide tables (the tabular() input shape):
#   cdisc_saf_demo           — demographics (continuous + categorical), 8 panels
#   cdisc_saf_ae      — high-level AE flag counts, 10 rows
#   cdisc_saf_aesocpt        — AEs by SOC (top 10) and PT (top 5 per SOC)
#   cdisc_saf_vital          — vital-signs summary, 4 visits × 4 parameters
#   cdisc_eff_resp           — best overall response + ORR / DCR / CBR + 95% CI
#
# Two long Analysis Results Data (ARD) companions for pivot_across() —
# one flat (continuous + categorical mix), one hierarchical (SOC / PT):
#   cdisc_saf_demo_ard      — flat ARD: continuous + categorical mix
#   cdisc_saf_aesocpt_ard   — hierarchical ARD: SOC / PT nested
#
# Two BigN denominator tables (one per analysis population):
#   cdisc_saf_n              — safety-population BigN per arm
#   cdisc_eff_n              — efficacy-population BigN per arm
#
# Run from package root:
#   Rscript data-raw/bundle-demo.R
#
# Build-time deps: pharmaverseadam, dplyr, tidyr, tibble, cards,
#                  usethis, devtools.
# Runtime package has NO dependency on these (.rda files are
# self-contained).

suppressPackageStartupMessages({
  library(pharmaverseadam)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(cards)
})

# Shared arm rename: pharmaverseadam labels -> tabular column convention
arm_rename <- c(
  "Placebo" = "placebo",
  "Xanomeline Low Dose" = "drug_50",
  "Xanomeline High Dose" = "drug_100"
)
arm_levels <- names(arm_rename)

# NA-blank helper: convert empty-string character cells to NA.
blank_to_na <- function(df) {
  df[] <- lapply(df, function(x) {
    if (is.character(x)) {
      x[x == ""] <- NA_character_
    }
    x
  })
  df
}

# Rename columns from pharmaverseadam-arm names to tabular convention.
rename_arms <- function(df) {
  for (old in names(arm_rename)) {
    new <- arm_rename[[old]]
    if (old %in% names(df)) names(df)[names(df) == old] <- new
  }
  df
}

# Common Safety-pop ADSL
adsl_saf <- pharmaverseadam::adsl |>
  blank_to_na() |>
  filter(SAFFL == "Y", TRT01A %in% arm_levels)

arm_n_int <- adsl_saf |> count(TRT01A) |> pull(n, name = TRT01A)
arm_n_int <- arm_n_int[arm_levels]
N_total <- as.integer(sum(arm_n_int))

# ────────────────────────────────────────────────────────────────────────
# cdisc_saf_demo — demographics: continuous (Age, Weight, Height, BMI) +
# categorical (Age Group, Sex, Race, Ethnicity, BMI Category).
# ────────────────────────────────────────────────────────────────────────
demog_data <- adsl_saf |>
  mutate(
    AGEGR1 = factor(AGEGR1, levels = c("18-64", ">64")),
    SEX = factor(SEX, levels = c("F", "M")),
    RACE = factor(
      RACE,
      levels = c(
        "WHITE",
        "BLACK OR AFRICAN AMERICAN",
        "ASIAN",
        "AMERICAN INDIAN OR ALASKA NATIVE"
      )
    ),
    ETHNIC = factor(
      ETHNIC,
      levels = c(
        "HISPANIC OR LATINO",
        "NOT HISPANIC OR LATINO",
        "NOT REPORTED"
      )
    )
  )

# Join baseline anthropometrics (Weight, Height, BMI) from advs
adsl_anthro <- pharmaverseadam::advs |>
  filter(
    TRT01A %in% arm_levels,
    PARAMCD %in% c("WEIGHT", "HEIGHT", "BMI"),
    AVISIT == "Baseline" | (PARAMCD == "HEIGHT" & is.na(AVISIT)),
    !is.na(AVAL)
  ) |>
  group_by(USUBJID, PARAMCD) |>
  summarise(AVAL = dplyr::first(AVAL), .groups = "drop") |>
  pivot_wider(names_from = PARAMCD, values_from = AVAL)

demog_data <- demog_data |>
  left_join(adsl_anthro, by = "USUBJID") |>
  mutate(
    BMI_CAT = cut(
      BMI,
      breaks = c(-Inf, 18.5, 25, 30, Inf),
      labels = c(
        "Underweight (<18.5)",
        "Normal (18.5-24.9)",
        "Overweight (25-29.9)",
        "Obese (>=30)"
      ),
      right = FALSE
    )
  )

cont_summary <- function(data, var, var_label) {
  by_arm <- data |>
    group_by(TRT01A) |>
    summarise(
      n = as.character(sum(!is.na(.data[[var]]))),
      `Mean (SD)` = sprintf(
        "%.1f (%.2f)",
        mean(.data[[var]], na.rm = TRUE),
        sd(.data[[var]], na.rm = TRUE)
      ),
      Median = sprintf("%.1f", median(.data[[var]], na.rm = TRUE)),
      `Q1, Q3` = sprintf(
        "%.1f, %.1f",
        quantile(.data[[var]], 0.25, na.rm = TRUE),
        quantile(.data[[var]], 0.75, na.rm = TRUE)
      ),
      `Min, Max` = sprintf(
        "%.0f, %.0f",
        min(.data[[var]], na.rm = TRUE),
        max(.data[[var]], na.rm = TRUE)
      ),
      .groups = "drop"
    ) |>
    pivot_longer(-TRT01A, names_to = "stat_label", values_to = "value") |>
    pivot_wider(names_from = TRT01A, values_from = value) |>
    mutate(variable = var_label, .before = 1)

  total <- data |>
    summarise(
      n = as.character(sum(!is.na(.data[[var]]))),
      `Mean (SD)` = sprintf(
        "%.1f (%.2f)",
        mean(.data[[var]], na.rm = TRUE),
        sd(.data[[var]], na.rm = TRUE)
      ),
      Median = sprintf("%.1f", median(.data[[var]], na.rm = TRUE)),
      `Q1, Q3` = sprintf(
        "%.1f, %.1f",
        quantile(.data[[var]], 0.25, na.rm = TRUE),
        quantile(.data[[var]], 0.75, na.rm = TRUE)
      ),
      `Min, Max` = sprintf(
        "%.0f, %.0f",
        min(.data[[var]], na.rm = TRUE),
        max(.data[[var]], na.rm = TRUE)
      )
    ) |>
    pivot_longer(everything(), names_to = "stat_label", values_to = "Total")

  left_join(by_arm, total, by = "stat_label")
}

cat_summary <- function(data, var, var_label) {
  N_arm <- data |> count(TRT01A, name = "N")
  by_arm <- data |>
    count(TRT01A, .data[[var]], .drop = FALSE) |>
    left_join(N_arm, by = "TRT01A") |>
    mutate(pct = sprintf("%d (%.1f)", n, n / N * 100)) |>
    select(TRT01A, stat_label = all_of(var), pct) |>
    mutate(stat_label = as.character(stat_label)) |>
    pivot_wider(names_from = TRT01A, values_from = pct)

  N_total_local <- nrow(data)
  total <- data |>
    count(.data[[var]], .drop = FALSE) |>
    mutate(Total = sprintf("%d (%.1f)", n, n / N_total_local * 100)) |>
    select(stat_label = all_of(var), Total) |>
    mutate(stat_label = as.character(stat_label))

  left_join(by_arm, total, by = "stat_label") |>
    mutate(variable = var_label, .before = 1)
}

# Bare-minimum demographics: one continuous variable (Age) and two
# categorical variables (Sex, Race). This is the most-used demo dataset;
# keeping it to three blocks demonstrates both summary shapes (n / Mean
# (SD) / Median / Q1, Q3 / Min, Max and per-level n (%)) without the
# noise of a full nine-block table.
cdisc_saf_demo <- bind_rows(
  cont_summary(demog_data, "AGE", "Age (years)"),
  cat_summary(demog_data, "SEX", "Sex, n (%)"),
  cat_summary(demog_data, "RACE", "Race, n (%)")
) |>
  rename_arms() |>
  as.data.frame()

# Drop the NA factor level rows that cat_summary emits with .drop = FALSE
# when a category is unused (e.g. BMI < 18.5 may be empty in this slice).
cdisc_saf_demo <- cdisc_saf_demo[!is.na(cdisc_saf_demo$stat_label), , drop = FALSE]
rownames(cdisc_saf_demo) <- NULL

# Canonical arm order: placebo, dose-ascending, then Total (the pivot
# above leaves them in factor/appearance order). Mirrors the explicit
# reorder that cdisc_saf_aesocpt / cdisc_saf_vital / cdisc_eff_resp apply.
cdisc_saf_demo <- cdisc_saf_demo[, c(
  "variable",
  "stat_label",
  "placebo",
  "drug_50",
  "drug_100",
  "Total"
)]

# ────────────────────────────────────────────────────────────────────────
# cdisc_saf_ae — high-level AE flag counts + per-severity rows.
# Adds AE-leading-to-death and AE-resolved rows on top of the v0 set.
# ────────────────────────────────────────────────────────────────────────
adae <- pharmaverseadam::adae |>
  blank_to_na() |>
  filter(SAFFL == "Y", TRTEMFL == "Y", TRT01A %in% arm_levels)

ae_flag_row <- function(
  ae_data,
  adsl_data,
  condition,
  row_label,
  arm_levels,
  N_total
) {
  condition <- rlang::enquo(condition)

  flag_subjs <- ae_data |>
    filter(!!condition) |>
    distinct(USUBJID, TRT01A)

  by_arm <- flag_subjs |>
    count(TRT01A) |>
    complete(TRT01A = arm_levels, fill = list(n = 0L)) |>
    left_join(adsl_data |> count(TRT01A, name = "N"), by = "TRT01A") |>
    mutate(pct = sprintf("%d (%.1f)", n, n / N * 100)) |>
    select(TRT01A, pct) |>
    pivot_wider(names_from = TRT01A, values_from = pct)

  total_n <- dplyr::n_distinct(flag_subjs$USUBJID)
  by_arm |>
    mutate(
      stat_label = row_label,
      Total = sprintf("%d (%.1f)", total_n, total_n / N_total * 100),
      .before = 1
    )
}

severity_rows <- function(ae_data, adsl_data, arm_levels, N_total) {
  sev_order <- c("MILD", "MODERATE", "SEVERE")

  max_sev <- ae_data |>
    mutate(sev_n = match(AESEV, sev_order)) |>
    group_by(USUBJID, TRT01A) |>
    summarise(max_sev = sev_order[max(sev_n, na.rm = TRUE)], .groups = "drop")

  do.call(
    rbind,
    lapply(sev_order, function(s) {
      subjs <- max_sev |> filter(max_sev == s) |> distinct(USUBJID, TRT01A)

      by_arm <- subjs |>
        count(TRT01A) |>
        complete(TRT01A = arm_levels, fill = list(n = 0L)) |>
        left_join(adsl_data |> count(TRT01A, name = "N"), by = "TRT01A") |>
        mutate(pct = sprintf("%d (%.1f)", n, n / N * 100)) |>
        select(TRT01A, pct) |>
        pivot_wider(names_from = TRT01A, values_from = pct)

      total_n <- dplyr::n_distinct(subjs$USUBJID)
      by_arm |>
        mutate(
          stat_label = paste0(
            "  Maximum severity: ",
            tools::toTitleCase(tolower(s))
          ),
          Total = sprintf("%d (%.1f)", total_n, total_n / N_total * 100),
          .before = 1
        ) |>
        as.data.frame()
    })
  )
}

cdisc_saf_ae <- bind_rows(
  ae_flag_row(adae, adsl_saf, TRUE, "Any TEAE", arm_levels, N_total),
  ae_flag_row(
    adae,
    adsl_saf,
    AESER == "Y",
    "Any Serious AE (SAE)",
    arm_levels,
    N_total
  ),
  ae_flag_row(
    adae,
    adsl_saf,
    AEREL %in% c("POSSIBLE", "PROBABLE"),
    "Any AE Related to Study Drug",
    arm_levels,
    N_total
  ),
  ae_flag_row(
    adae,
    adsl_saf,
    AEOUT == "FATAL",
    "Any AE Leading to Death",
    arm_levels,
    N_total
  ),
  ae_flag_row(
    adae,
    adsl_saf,
    AEOUT == "RECOVERED/RESOLVED",
    "Any AE Recovered / Resolved",
    arm_levels,
    N_total
  ),
  severity_rows(adae, adsl_saf, arm_levels, N_total)
) |>
  mutate(across(
    all_of(c(arm_levels, "Total")),
    ~ tidyr::replace_na(.x, "0 (0.0)")
  )) |>
  rename_arms() |>
  as.data.frame()

# Canonical arm order: placebo, dose-ascending, then Total (the pivot
# above leaves Total first and the doses in factor order). Mirrors the
# explicit reorder that cdisc_saf_aesocpt / cdisc_saf_vital / cdisc_eff_resp apply.
cdisc_saf_ae <- cdisc_saf_ae[, c(
  "stat_label",
  "placebo",
  "drug_50",
  "drug_100",
  "Total"
)]

# ────────────────────────────────────────────────────────────────────────
# cdisc_saf_aesocpt — AEs by SOC (top 10) and PT (top 5 per SOC).
# Richer than the v0 top-5-SOC × top-3-PT trim; demonstrates a realistic
# AE-by-SOC/PT submission shell that exercises paginate() and engine_panel.
# ────────────────────────────────────────────────────────────────────────
n_pct <- function(n, denom) sprintf("%d (%.1f)", n, n / denom * 100)

top_socs <- adae |>
  distinct(USUBJID, AEBODSYS) |>
  count(AEBODSYS, sort = TRUE) |>
  head(10) |>
  pull(AEBODSYS)

adae_top <- adae |> filter(AEBODSYS %in% top_socs)

top_pts <- adae_top |>
  distinct(USUBJID, AEBODSYS, AEDECOD) |>
  count(AEBODSYS, AEDECOD, sort = TRUE) |>
  group_by(AEBODSYS) |>
  slice_head(n = 5) |>
  ungroup() |>
  select(AEBODSYS, AEDECOD)

adae_trim <- adae_top |>
  semi_join(top_pts, by = c("AEBODSYS", "AEDECOD"))

# Any TEAE overall (in the trimmed slice)
any_arm <- adae_trim |>
  distinct(USUBJID, TRT01A) |>
  count(TRT01A) |>
  complete(TRT01A = arm_levels, fill = list(n = 0L)) |>
  mutate(value = mapply(n_pct, n, arm_n_int[as.character(TRT01A)])) |>
  select(TRT01A, value) |>
  pivot_wider(names_from = TRT01A, values_from = value)

any_total <- adae_trim |> distinct(USUBJID) |> nrow()
any_row <- bind_cols(
  tibble(
    soc = "TOTAL SUBJECTS WITH AN EVENT",
    label = "TOTAL SUBJECTS WITH AN EVENT",
    row_type = "overall"
  ),
  any_arm,
  tibble(
    Total = n_pct(any_total, N_total),
    n_total = any_total,
    soc_n = any_total
  )
)

# SOC level (one subject per SOC)
soc_arm <- adae_trim |>
  distinct(USUBJID, TRT01A, AEBODSYS) |>
  count(TRT01A, AEBODSYS) |>
  complete(TRT01A = arm_levels, AEBODSYS = top_socs, fill = list(n = 0L)) |>
  mutate(value = mapply(n_pct, n, arm_n_int[as.character(TRT01A)])) |>
  select(TRT01A, AEBODSYS, value) |>
  pivot_wider(names_from = TRT01A, values_from = value)

# `n_total` is the SOC's own subject count; `soc_n` is the same
# value, kept as a separate column so it can be broadcast onto the
# child PT rows below (the cards `sort_ard_hierarchical()` pattern).
soc_total <- adae_trim |>
  distinct(USUBJID, AEBODSYS) |>
  count(AEBODSYS, name = "n_total") |>
  mutate(
    Total = n_pct(n_total, N_total),
    soc_n = n_total
  )

soc_wide <- left_join(soc_arm, soc_total, by = "AEBODSYS") |>
  mutate(soc = AEBODSYS, label = AEBODSYS, row_type = "soc", .before = 1) |>
  select(-AEBODSYS)

# PT level (one subject per SOC/PT)
pt_arm <- adae_trim |>
  distinct(USUBJID, TRT01A, AEBODSYS, AEDECOD) |>
  count(TRT01A, AEBODSYS, AEDECOD) |>
  complete(
    TRT01A = arm_levels,
    nesting(AEBODSYS, AEDECOD),
    fill = list(n = 0L)
  ) |>
  mutate(value = mapply(n_pct, n, arm_n_int[as.character(TRT01A)])) |>
  select(TRT01A, AEBODSYS, AEDECOD, value) |>
  pivot_wider(names_from = TRT01A, values_from = value)

# `n_total` is the PT's own subject count; `soc_n` will be filled
# from the parent SOC below so every PT row carries the broadcast
# parent count that the render-time sort keys on.
pt_total <- adae_trim |>
  distinct(USUBJID, AEBODSYS, AEDECOD) |>
  count(AEBODSYS, AEDECOD, name = "n_total") |>
  mutate(Total = n_pct(n_total, N_total))

pt_wide <- pt_arm |>
  left_join(pt_total, by = c("AEBODSYS", "AEDECOD")) |>
  left_join(select(soc_total, AEBODSYS, soc_n), by = "AEBODSYS") |>
  mutate(soc = AEBODSYS, label = AEDECOD, row_type = "pt", .before = 1) |>
  select(-AEBODSYS, -AEDECOD)

# Cards-style two-level hierarchical sort baked into the body:
# outer key `soc_n` clusters PTs under their parent SOC and orders
# clusters by SOC frequency descending; inner key `n_total` orders
# rows within a cluster. The SOC row carries `n_total == soc_n`, so
# it always sits at the top of its own cluster (highest n_total in
# the cluster). `soc` is the tertiary tiebreaker between two SOCs
# whose subject counts happen to tie. The overall row is bound on
# top so it sits above the body without competing on the keys.
body_sorted <- bind_rows(soc_wide, pt_wide) |>
  arrange(desc(soc_n), soc, desc(n_total))

cdisc_saf_aesocpt <- bind_rows(any_row, body_sorted) |>
  rename_arms() |>
  as.data.frame()

# Ship the canonical depth column so users do not reconstruct it in
# every cdisc_saf_aesocpt example. Integer values: 0 on overall and SOC
# rows, 1 on PT rows. Use as `col_spec(label, indent_by = "indent_level")`.
cdisc_saf_aesocpt$indent_level <- as.integer(cdisc_saf_aesocpt$row_type == "pt")
cdisc_saf_aesocpt <- cdisc_saf_aesocpt[, c(
  "soc",
  "label",
  "row_type",
  "indent_level",
  "n_total",
  "soc_n",
  "placebo",
  "drug_50",
  "drug_100",
  "Total"
)]

# ────────────────────────────────────────────────────────────────────────
# cdisc_saf_vital — vital-signs continuous summary at 4 visits × 4 parameters.
# Richer than the v0 2-visit × 4-param shape; supports paginate() and
# pivot_across() examples that need a multi-panel structure.
# ────────────────────────────────────────────────────────────────────────
vital_visits <- c("Baseline", "Week 8", "Week 16", "End of Treatment")

advs_saf <- pharmaverseadam::advs |>
  blank_to_na() |>
  filter(
    SAFFL == "Y",
    TRT01A %in% arm_levels,
    PARAMCD %in% c("SYSBP", "DIABP", "PULSE", "TEMP"),
    AVISIT %in% vital_visits
  ) |>
  mutate(
    AVISIT = factor(AVISIT, levels = vital_visits),
    TRT01A = factor(TRT01A, levels = arm_levels)
  )

fmt1 <- function(x) ifelse(is.na(x) | is.nan(x), "", sprintf("%.1f", x))
fmt0 <- function(x) ifelse(is.na(x) | is.nan(x), "", sprintf("%.0f", x))

vs_summary <- advs_saf |>
  group_by(PARAM, PARAMCD, AVISIT, TRT01A) |>
  summarise(
    n = as.character(sum(!is.na(AVAL))),
    `Mean (SD)` = sprintf(
      "%s (%s)",
      fmt1(mean(AVAL, na.rm = TRUE)),
      fmt1(sd(AVAL, na.rm = TRUE))
    ),
    Median = fmt1(median(AVAL, na.rm = TRUE)),
    `Min, Max` = sprintf(
      "%s, %s",
      fmt0(min(AVAL, na.rm = TRUE)),
      fmt0(max(AVAL, na.rm = TRUE))
    ),
    .groups = "drop"
  ) |>
  pivot_longer(
    c(n, `Mean (SD)`, Median, `Min, Max`),
    names_to = "stat_label",
    values_to = "value"
  ) |>
  pivot_wider(names_from = TRT01A, values_from = value) |>
  arrange(PARAMCD, AVISIT)

cdisc_saf_vital <- vs_summary |>
  mutate(
    across(all_of(arm_levels), ~ tidyr::replace_na(.x, "")),
    PARAM = as.character(PARAM),
    AVISIT = as.character(AVISIT)
  ) |>
  rename(paramcd = PARAMCD, param = PARAM, visit = AVISIT) |>
  rename_arms() |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# cdisc_eff_resp — best overall response + ORR / DCR / CBR + 95% CI rows.
# Exact binomial 95% CI on each derived rate. CBR (Clinical Benefit Rate)
# is CR + PR + SD (broader than ORR, narrower than DCR's full-set inclusion
# of NON-CR/NON-PD).
# ────────────────────────────────────────────────────────────────────────
adrs_bor <- pharmaverseadam::adrs_onco |>
  blank_to_na() |>
  filter(PARAMCD == "BOR", ARM %in% arm_levels)

bor_levels <- c("CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING")

bor_counts <- adrs_bor |>
  mutate(AVALC = factor(AVALC, levels = bor_levels)) |>
  count(ARM, AVALC, .drop = FALSE) |>
  group_by(ARM) |>
  mutate(N = sum(n)) |>
  ungroup() |>
  mutate(value = if_else(n == 0, "0", sprintf("%d (%.1f)", n, n / N * 100)))

bor_wide <- bor_counts |>
  select(ARM, AVALC, value) |>
  pivot_wider(names_from = ARM, values_from = value) |>
  mutate(
    row_type = "category",
    groupid = 1L,
    group_label = "Best Overall Response",
    .after = AVALC
  )

# Exact (Clopper-Pearson) 95% CI on a binomial rate.
ci95_chr <- function(x, n) {
  if (n == 0L) {
    return("(NE, NE)")
  }
  ci <- stats::binom.test(x, n)$conf.int
  sprintf("(%.1f, %.1f)", ci[1] * 100, ci[2] * 100)
}

# Derive an ORR / CBR / DCR rate row + its paired 95% CI row. The
# `groupid` integer is the engine sort key; `group_label` repeats across
# both rows in the group so `usage = "group"` synthesises one section
# header per groupid block. `stat_label` carries the short rate label on
# the derived row and the full CI prose on the CI row -- no leading-
# space indent, since `usage = "indent"` on stat_label at render time
# adds the depth uniformly via native padding-left.
derive_rate <- function(data, categories, label, groupid, group_label) {
  by_arm <- data |>
    filter(AVALC %in% categories) |>
    group_by(ARM) |>
    summarise(x = sum(n), N = dplyr::first(N), .groups = "drop") |>
    mutate(
      rate_value = sprintf("%d (%.1f)", x, x / N * 100),
      ci_value = mapply(ci95_chr, x, N)
    )

  rate_row <- by_arm |>
    select(ARM, rate_value) |>
    pivot_wider(names_from = ARM, values_from = rate_value) |>
    mutate(
      AVALC = label,
      row_type = "derived",
      groupid = groupid,
      group_label = group_label,
      .before = 1
    )

  ci_row <- by_arm |>
    select(ARM, ci_value) |>
    pivot_wider(names_from = ARM, values_from = ci_value) |>
    mutate(
      AVALC = "95% CI (Clopper-Pearson)",
      row_type = "ci",
      groupid = groupid,
      group_label = group_label,
      .before = 1
    )

  bind_rows(rate_row, ci_row)
}

orr <- derive_rate(
  bor_counts,
  c("CR", "PR"),
  "ORR (CR + PR)",
  2L,
  "Objective Response Rate"
)
cbr <- derive_rate(
  bor_counts,
  c("CR", "PR", "SD"),
  "CBR (CR + PR + SD)",
  3L,
  "Clinical Benefit Rate"
)
dcr <- derive_rate(
  bor_counts,
  c("CR", "PR", "SD", "NON-CR/NON-PD"),
  "DCR (CR + PR + SD + NON-CR/NON-PD)",
  4L,
  "Disease Control Rate"
)

# Adopt arms set actually present in adrs_onco (subset of full arm_levels)
bor_arms_present <- intersect(arm_levels, names(bor_wide))

cdisc_eff_resp <- bind_rows(bor_wide, orr, cbr, dcr) |>
  rename(stat_label = AVALC) |>
  mutate(stat_label = as.character(stat_label)) |>
  select(
    stat_label,
    row_type,
    all_of(bor_arms_present),
    groupid,
    group_label
  )

# Add any missing arm columns as "" so all 5 datasets share placebo/drug_*/...
for (a in setdiff(arm_levels, bor_arms_present)) {
  cdisc_eff_resp[[a]] <- ""
}
cdisc_eff_resp <- cdisc_eff_resp[, c(
  "stat_label",
  "row_type",
  arm_levels,
  "groupid",
  "group_label"
)]
cdisc_eff_resp <- rename_arms(cdisc_eff_resp) |> as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# cdisc_saf_subgroup — vital-signs summary partitioned by sex × age group.
# Designed for subgroup() / as_grid() examples: ships partition-constant
# BigN columns (sex_n, agegr_n) so banners can inline the denominator
# via `subgroup(label = "Sex: {sex} (N = {sex_n})")`. Two parameters
# (Systolic BP, Diastolic BP) at End of Treatment keep the dataset
# small while exercising the multi-variable partition cross.
# ────────────────────────────────────────────────────────────────────────
subgroup_params <- c(
  SYSBP = "Systolic BP (mmHg)",
  DIABP = "Diastolic BP (mmHg)"
)

advs_subgroup <- pharmaverseadam::advs |>
  blank_to_na() |>
  filter(
    SAFFL == "Y",
    TRT01A %in% arm_levels,
    PARAMCD %in% names(subgroup_params),
    AVISIT == "End of Treatment",
    SEX %in% c("F", "M"),
    !is.na(AGEGR1)
  ) |>
  mutate(
    sex = factor(SEX, levels = c("F", "M")),
    agegr = factor(
      ifelse(AGEGR1 == "18-64", "<65", ">=65"),
      levels = c("<65", ">=65")
    ),
    TRT01A = factor(TRT01A, levels = arm_levels)
  )

sex_n_int <- advs_subgroup |>
  distinct(USUBJID, sex) |>
  count(sex) |>
  pull(n, name = sex)

agegr_n_int <- advs_subgroup |>
  distinct(USUBJID, agegr) |>
  count(agegr) |>
  pull(n, name = agegr)

vs_subgroup_arm <- advs_subgroup |>
  group_by(sex, agegr, PARAMCD, TRT01A) |>
  summarise(
    n = as.character(sum(!is.na(AVAL))),
    `Mean (SD)` = sprintf(
      "%s (%s)",
      fmt1(mean(AVAL, na.rm = TRUE)),
      fmt1(sd(AVAL, na.rm = TRUE))
    ),
    Median = fmt1(median(AVAL, na.rm = TRUE)),
    `Min, Max` = sprintf(
      "%s, %s",
      fmt0(min(AVAL, na.rm = TRUE)),
      fmt0(max(AVAL, na.rm = TRUE))
    ),
    .groups = "drop"
  ) |>
  pivot_longer(
    c(n, `Mean (SD)`, Median, `Min, Max`),
    names_to = "stat_label",
    values_to = "value"
  ) |>
  pivot_wider(names_from = TRT01A, values_from = value)

vs_subgroup_total <- advs_subgroup |>
  group_by(sex, agegr, PARAMCD) |>
  summarise(
    n = as.character(sum(!is.na(AVAL))),
    `Mean (SD)` = sprintf(
      "%s (%s)",
      fmt1(mean(AVAL, na.rm = TRUE)),
      fmt1(sd(AVAL, na.rm = TRUE))
    ),
    Median = fmt1(median(AVAL, na.rm = TRUE)),
    `Min, Max` = sprintf(
      "%s, %s",
      fmt0(min(AVAL, na.rm = TRUE)),
      fmt0(max(AVAL, na.rm = TRUE))
    ),
    .groups = "drop"
  ) |>
  pivot_longer(
    c(n, `Mean (SD)`, Median, `Min, Max`),
    names_to = "stat_label",
    values_to = "Total"
  )

cdisc_saf_subgroup <- left_join(
  vs_subgroup_arm,
  vs_subgroup_total,
  by = c("sex", "agegr", "PARAMCD", "stat_label")
) |>
  mutate(
    sex_n = as.integer(sex_n_int[as.character(sex)]),
    agegr_n = as.integer(agegr_n_int[as.character(agegr)]),
    paramcd = as.character(PARAMCD),
    param = unname(subgroup_params[paramcd]),
    .before = "stat_label"
  ) |>
  select(-PARAMCD) |>
  rename_arms() |>
  mutate(across(
    all_of(c("placebo", "drug_50", "drug_100", "Total")),
    ~ tidyr::replace_na(.x, "")
  )) |>
  select(
    sex,
    agegr,
    sex_n,
    agegr_n,
    paramcd,
    param,
    stat_label,
    placebo,
    drug_50,
    drug_100,
    Total
  ) |>
  arrange(sex, agegr, paramcd) |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# cdisc_eff_estimates — model-based treatment-effect estimates. Lifted from
# the arframe-examples tte-summary / efficacy-bor pattern: four
# competing models, point estimate, 95% CI bounds, nominal p. One row
# carries NA CI bounds to exercise col_spec(na_text = ...) in examples.
# ────────────────────────────────────────────────────────────────────────
cdisc_eff_estimates <- data.frame(
  model = c("ANCOVA", "MMRM", "Cox PH", "Bootstrap (1000 reps)"),
  estimate = c(-2.31, -2.45, 0.81, -2.29),
  lower_ci = c(-3.42, NA_real_, 0.68, -3.50),
  upper_ci = c(-1.20, NA_real_, 0.97, -1.10),
  p_value = c(0.0042, 0.0061, 0.0087, 0.0050),
  stringsAsFactors = FALSE
)

# ────────────────────────────────────────────────────────────────────────
# Cards Analysis Results Data (ARD) companions
#
# Two long-format datasets covering the two distinct ARD shapes that
# pivot_across() must handle: a flat ARD (cdisc_saf_demo_ard) and a
# hierarchical ARD (cdisc_saf_aesocpt_ard). Other clinical patterns
# (overall AE flags, vital signs, BOR) reduce to one of these two
# shapes once pivoted, so we don't ship redundant per-domain ARDs.
# ────────────────────────────────────────────────────────────────────────
strip_card_cols <- function(ard) {
  for (col in c("fmt_fun", "warning", "error")) {
    if (col %in% names(ard)) ard[[col]] <- NULL
  }
  ard
}

# cdisc_saf_demo_ard — flat ARD with continuous + categorical mix.
# Covers the canonical demographics pivot: AGE / WEIGHT / HEIGHT / BMI
# as continuous summaries plus AGEGR1 / SEX / RACE / ETHNIC / BMI_CAT
# as categorical counts, all grouped by treatment arm with .overall.
demog_data_ard <- demog_data |>
  mutate(
    BMI_CAT = factor(
      BMI_CAT,
      levels = c(
        "Underweight (<18.5)",
        "Normal (18.5-24.9)",
        "Overweight (25-29.9)",
        "Obese (>=30)"
      )
    )
  )

cdisc_saf_demo_ard <- ard_stack(
  data = demog_data_ard,
  .by = "TRT01A",
  ard_continuous(variables = c("AGE", "WEIGHT", "HEIGHT", "BMI")),
  ard_categorical(
    variables = c("AGEGR1", "SEX", "RACE", "ETHNIC", "BMI_CAT")
  ),
  .overall = TRUE
) |>
  strip_card_cols()

# cdisc_saf_aesocpt_ard — hierarchical ARD (SOC / PT) matching the
# top-10 SOC × top-5 PT slice in cdisc_saf_aesocpt. Covers the harder
# pivot case where pivot_across() must emit soc / label / row_type
# columns and preserve the SOC -> PT nesting under sort.
cdisc_saf_aesocpt_ard <- ard_stack_hierarchical(
  data = adae_trim,
  variables = c(AEBODSYS, AEDECOD),
  by = TRT01A,
  denominator = adsl_saf,
  id = USUBJID,
  over_variables = TRUE
) |>
  sort_ard_hierarchical(sort = "descending") |>
  strip_card_cols()

# ────────────────────────────────────────────────────────────────────────
# BigN per analysis population.
# cdisc_saf_n is built from the safety population (preserved at the same
# 86 / 96 / 72 / 254 split that the test suite depends on).
# cdisc_eff_n reflects the adrs_onco BOR population.
# ────────────────────────────────────────────────────────────────────────
cdisc_saf_n <- data.frame(
  arm = c(arm_levels, "Total"),
  arm_short = c(unname(arm_rename[arm_levels]), "Total"),
  n = c(as.integer(arm_n_int[arm_levels]), N_total),
  stringsAsFactors = FALSE
)

eff_arm_n_int <- bor_counts |>
  distinct(ARM, N) |>
  arrange(match(as.character(ARM), arm_levels))
eff_arms <- as.character(eff_arm_n_int$ARM)
cdisc_eff_n <- data.frame(
  arm = c(eff_arms, "Total"),
  arm_short = c(unname(arm_rename[eff_arms]), "Total"),
  n = c(as.integer(eff_arm_n_int$N), as.integer(sum(eff_arm_n_int$N))),
  stringsAsFactors = FALSE
)

# ────────────────────────────────────────────────────────────────────────
# Save (xz compressed). No size guard — datasets are deliberately
# richer than v0 and the ~50 KB ceiling was retired with this rebuild.
# ────────────────────────────────────────────────────────────────────────
usethis::use_data(
  cdisc_saf_demo,
  cdisc_saf_ae,
  cdisc_saf_aesocpt,
  cdisc_saf_vital,
  cdisc_saf_subgroup,
  cdisc_eff_resp,
  cdisc_eff_estimates,
  cdisc_saf_demo_ard,
  cdisc_saf_aesocpt_ard,
  cdisc_saf_n,
  cdisc_eff_n,
  overwrite = TRUE,
  compress = "xz"
)

files <- file.path(
  "data",
  c(
    "cdisc_saf_demo.rda",
    "cdisc_saf_ae.rda",
    "cdisc_saf_aesocpt.rda",
    "cdisc_saf_vital.rda",
    "cdisc_saf_subgroup.rda",
    "cdisc_eff_resp.rda",
    "cdisc_eff_estimates.rda",
    "cdisc_saf_demo_ard.rda",
    "cdisc_saf_aesocpt_ard.rda",
    "cdisc_saf_n.rda",
    "cdisc_eff_n.rda"
  )
)
sizes <- vapply(files, function(f) file.info(f)$size, numeric(1))
cat(sprintf(
  "Sizes (bytes): %s\n",
  paste(
    basename(files),
    formatC(sizes, big.mark = ","),
    sep = "=",
    collapse = "  "
  )
))

cat("Done.\n")
