# data-raw/bundle-demo.R
# Build 12 demo datasets for tabular's examples, tests, vignettes.
# Source data: pharmaverseadam (adsl, adae, advs, adrs_onco).
# Five pre-summarised wide tables that tabular consumes directly,
# five long-format Analysis Results Data (ARD) companions showing
# the upstream cards::ard_stack() output users would convert to wide
# before piping into tabular(), plus two BigN denominator tables —
# one per analysis population — for joining inline into row labels
# or column headers:
#   saf_demo           — demographics (continuous + categorical)
#   saf_aeoverall      — high-level AE flag counts
#   saf_aesocpt        — AEs by SOC and PT (2-level nesting)
#   saf_vital          — vital-signs summary
#   eff_resp           — best overall response + ORR / DCR
#   saf_demo_card      — cards ARD for saf_demo
#   saf_aeoverall_card — cards ARD for saf_aeoverall
#   saf_aesocpt_card   — cards ARD for saf_aesocpt (hierarchical)
#   saf_vital_card     — cards ARD for saf_vital
#   eff_resp_card      — cards ARD for eff_resp
#   saf_n              — safety-population BigN per arm
#   eff_n              — efficacy-population BigN per arm
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
  "Placebo"              = "placebo",
  "Xanomeline Low Dose"  = "drug_50",
  "Xanomeline High Dose" = "drug_100"
)
arm_levels <- names(arm_rename)

# NA-blank helper: convert empty-string character cells to NA.
blank_to_na <- function(df) {
  df[] <- lapply(df, function(x) {
    if (is.character(x)) x[x == ""] <- NA_character_
    x
  })
  df
}

# Rename columns from arframe-arm names to tabular column convention.
rename_arms <- function(df) {
  for (old in names(arm_rename)) {
    new <- arm_rename[[old]]
    if (old %in% names(df)) names(df)[names(df) == old] <- new
  }
  df
}

# ── Common Safety-pop ADSL ───────────────────────────────────────────────
adsl_saf <- pharmaverseadam::adsl |>
  blank_to_na() |>
  filter(SAFFL == "Y", TRT01A %in% arm_levels)

arm_n_int <- adsl_saf |> count(TRT01A) |> pull(n, name = TRT01A)
arm_n_int <- arm_n_int[arm_levels]
N_total   <- as.integer(sum(arm_n_int))

# ────────────────────────────────────────────────────────────────────────
# saf_demo — demographics (continuous AGE + categorical AGEGR1/SEX/RACE/ETHNIC)
# ────────────────────────────────────────────────────────────────────────
demog_data <- adsl_saf |>
  mutate(
    AGEGR1 = factor(AGEGR1, levels = c("18-64", ">64")),
    SEX    = factor(SEX,    levels = c("F", "M")),
    RACE   = factor(RACE,   levels = c(
      "WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN",
      "AMERICAN INDIAN OR ALASKA NATIVE"
    )),
    ETHNIC = factor(ETHNIC, levels = c(
      "HISPANIC OR LATINO", "NOT HISPANIC OR LATINO", "NOT REPORTED"
    ))
  )

cont_summary <- function(data, var, var_label) {
  by_arm <- data |>
    group_by(TRT01A) |>
    summarise(
      n           = as.character(n()),
      `Mean (SD)` = sprintf("%.1f (%.2f)", mean(.data[[var]]), sd(.data[[var]])),
      Median      = sprintf("%.1f", median(.data[[var]])),
      `Q1, Q3`    = sprintf(
        "%.1f, %.1f",
        quantile(.data[[var]], 0.25), quantile(.data[[var]], 0.75)
      ),
      `Min, Max`  = sprintf("%.0f, %.0f", min(.data[[var]]), max(.data[[var]])),
      .groups     = "drop"
    ) |>
    pivot_longer(-TRT01A, names_to = "stat_label", values_to = "value") |>
    pivot_wider(names_from = TRT01A, values_from = value) |>
    mutate(variable = var_label, .before = 1)

  total <- data |>
    summarise(
      n           = as.character(n()),
      `Mean (SD)` = sprintf("%.1f (%.2f)", mean(.data[[var]]), sd(.data[[var]])),
      Median      = sprintf("%.1f", median(.data[[var]])),
      `Q1, Q3`    = sprintf(
        "%.1f, %.1f",
        quantile(.data[[var]], 0.25), quantile(.data[[var]], 0.75)
      ),
      `Min, Max`  = sprintf("%.0f, %.0f", min(.data[[var]]), max(.data[[var]]))
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

saf_demo <- bind_rows(
  cont_summary(demog_data, "AGE",    "Age (years)"),
  cat_summary (demog_data, "AGEGR1", "Age Group, n (%)"),
  cat_summary (demog_data, "SEX",    "Sex, n (%)"),
  cat_summary (demog_data, "RACE",   "Race, n (%)"),
  cat_summary (demog_data, "ETHNIC", "Ethnicity, n (%)")
) |>
  rename_arms() |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# saf_aeoverall — high-level AE flag counts + per-severity rows
# ────────────────────────────────────────────────────────────────────────
adae <- pharmaverseadam::adae |>
  blank_to_na() |>
  filter(SAFFL == "Y", TRTEMFL == "Y", TRT01A %in% arm_levels)

ae_flag_row <- function(ae_data, adsl_data, condition, row_label,
                        arm_levels, N_total) {
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
      Total      = sprintf("%d (%.1f)", total_n, total_n / N_total * 100),
      .before    = 1
    )
}

severity_rows <- function(ae_data, adsl_data, arm_levels, N_total) {
  sev_order <- c("MILD", "MODERATE", "SEVERE")

  max_sev <- ae_data |>
    mutate(sev_n = match(AESEV, sev_order)) |>
    group_by(USUBJID, TRT01A) |>
    summarise(max_sev = sev_order[max(sev_n, na.rm = TRUE)], .groups = "drop")

  do.call(rbind, lapply(sev_order, function(s) {
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
        stat_label = paste0("  Maximum severity: ",
                            tools::toTitleCase(tolower(s))),
        Total      = sprintf("%d (%.1f)", total_n, total_n / N_total * 100),
        .before    = 1
      ) |>
      as.data.frame()
  }))
}

saf_aeoverall <- bind_rows(
  ae_flag_row(adae, adsl_saf, TRUE,
              "Any TEAE", arm_levels, N_total),
  ae_flag_row(adae, adsl_saf, AESER == "Y",
              "Any Serious AE (SAE)", arm_levels, N_total),
  ae_flag_row(adae, adsl_saf, AEREL %in% c("POSSIBLE", "PROBABLE"),
              "Any AE Related to Study Drug", arm_levels, N_total),
  severity_rows(adae, adsl_saf, arm_levels, N_total)
) |>
  mutate(across(
    all_of(c(arm_levels, "Total")),
    ~ tidyr::replace_na(.x, "0 (0.0)")
  )) |>
  rename_arms() |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# saf_aesocpt — AEs by SOC and PT; top SOCs only to fit <50KB
# ────────────────────────────────────────────────────────────────────────
n_pct <- function(n, denom) sprintf("%d (%.1f)", n, n / denom * 100)

# Use top SOCs by total event count to control size
top_socs <- adae |>
  distinct(USUBJID, AEBODSYS) |>
  count(AEBODSYS, sort = TRUE) |>
  head(5) |>
  pull(AEBODSYS)

adae_top <- adae |> filter(AEBODSYS %in% top_socs)

# Top PTs per SOC (3 per SOC)
top_pts <- adae_top |>
  distinct(USUBJID, AEBODSYS, AEDECOD) |>
  count(AEBODSYS, AEDECOD, sort = TRUE) |>
  group_by(AEBODSYS) |>
  slice_head(n = 3) |>
  ungroup() |>
  select(AEBODSYS, AEDECOD)

adae_trim <- adae_top |>
  semi_join(top_pts, by = c("AEBODSYS", "AEDECOD"))

# Any TEAE overall
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
    soc      = "TOTAL SUBJECTS WITH AN EVENT",
    pt       = "TOTAL SUBJECTS WITH AN EVENT",
    row_type = "overall"
  ),
  any_arm,
  tibble(Total = n_pct(any_total, N_total))
)

# SOC level (one subject per SOC)
soc_arm <- adae_trim |>
  distinct(USUBJID, TRT01A, AEBODSYS) |>
  count(TRT01A, AEBODSYS) |>
  complete(TRT01A = arm_levels, AEBODSYS = top_socs, fill = list(n = 0L)) |>
  mutate(value = mapply(n_pct, n, arm_n_int[as.character(TRT01A)])) |>
  select(TRT01A, AEBODSYS, value) |>
  pivot_wider(names_from = TRT01A, values_from = value)

soc_total <- adae_trim |>
  distinct(USUBJID, AEBODSYS) |>
  count(AEBODSYS) |>
  mutate(Total = n_pct(n, N_total)) |>
  select(AEBODSYS, Total)

soc_wide <- left_join(soc_arm, soc_total, by = "AEBODSYS") |>
  mutate(soc = AEBODSYS, pt = AEBODSYS, row_type = "soc", .before = 1) |>
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

pt_total <- adae_trim |>
  distinct(USUBJID, AEBODSYS, AEDECOD) |>
  count(AEBODSYS, AEDECOD) |>
  mutate(Total = n_pct(n, N_total)) |>
  select(AEBODSYS, AEDECOD, Total)

pt_wide <- left_join(pt_arm, pt_total, by = c("AEBODSYS", "AEDECOD")) |>
  mutate(soc = AEBODSYS, pt = AEDECOD, row_type = "pt", .before = 1) |>
  select(-AEBODSYS, -AEDECOD)

# Interleave: any-row, then per-SOC (soc-row + its PTs), sorted by SOC freq
soc_freq <- adae_trim |>
  distinct(USUBJID, AEBODSYS) |>
  count(AEBODSYS, sort = TRUE) |>
  pull(AEBODSYS)

saf_aesocpt <- bind_rows(
  any_row,
  bind_rows(lapply(soc_freq, function(s) {
    bind_rows(
      filter(soc_wide, soc == s),
      filter(pt_wide,  soc == s)
    )
  }))
) |>
  rename_arms() |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# saf_vital — vital-signs continuous-stat summary (BP/Pulse/Temp at 2 visits)
# ────────────────────────────────────────────────────────────────────────
advs_saf <- pharmaverseadam::advs |>
  blank_to_na() |>
  filter(
    SAFFL == "Y",
    TRT01A %in% arm_levels,
    PARAMCD %in% c("SYSBP", "DIABP", "PULSE", "TEMP"),
    AVISIT %in% c("Baseline", "End of Treatment")
  ) |>
  mutate(
    AVISIT = factor(AVISIT, levels = c("Baseline", "End of Treatment")),
    TRT01A = factor(TRT01A, levels = arm_levels)
  )

fmt1 <- function(x) ifelse(is.na(x) | is.nan(x), "", sprintf("%.1f", x))
fmt0 <- function(x) ifelse(is.na(x) | is.nan(x), "", sprintf("%.0f", x))

vs_summary <- advs_saf |>
  group_by(PARAM, PARAMCD, AVISIT, TRT01A) |>
  summarise(
    n          = as.character(sum(!is.na(AVAL))),
    `Mean (SD)` = sprintf("%s (%s)",
                          fmt1(mean(AVAL, na.rm = TRUE)),
                          fmt1(sd(AVAL, na.rm = TRUE))),
    Median     = fmt1(median(AVAL, na.rm = TRUE)),
    `Min, Max` = sprintf("%s, %s",
                          fmt0(min(AVAL, na.rm = TRUE)),
                          fmt0(max(AVAL, na.rm = TRUE))),
    .groups    = "drop"
  ) |>
  pivot_longer(c(n, `Mean (SD)`, Median, `Min, Max`),
               names_to = "stat_label", values_to = "value") |>
  pivot_wider(names_from = TRT01A, values_from = value) |>
  arrange(PARAMCD, AVISIT)

saf_vital <- vs_summary |>
  mutate(across(all_of(arm_levels), ~ tidyr::replace_na(.x, "")),
         PARAM  = as.character(PARAM),
         AVISIT = as.character(AVISIT)) |>
  rename(paramcd = PARAMCD, param = PARAM, visit = AVISIT) |>
  rename_arms() |>
  as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# eff_resp — best overall response counts + derived ORR / DCR rows
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
  mutate(row_type = "category", .after = AVALC)

derive_rate <- function(data, categories, label) {
  data |>
    filter(AVALC %in% categories) |>
    group_by(ARM) |>
    summarise(n = sum(n), N = dplyr::first(N), .groups = "drop") |>
    mutate(value = sprintf("%d (%.1f)", n, n / N * 100)) |>
    select(ARM, value) |>
    pivot_wider(names_from = ARM, values_from = value) |>
    mutate(AVALC = label, row_type = "derived", .before = 1)
}

orr_wide <- derive_rate(bor_counts, c("CR", "PR"),
                        "Objective Response Rate (CR + PR)")
dcr_wide <- derive_rate(bor_counts, c("CR", "PR", "SD", "NON-CR/NON-PD"),
                        "Disease Control Rate (CR + PR + SD)")

# Adopt arms set actually present in adrs_onco (subset of full arm_levels)
bor_arms_present <- intersect(arm_levels, names(bor_wide))

eff_resp <- bind_rows(bor_wide, orr_wide, dcr_wide) |>
  rename(stat_label = AVALC) |>
  mutate(stat_label = as.character(stat_label)) |>
  select(stat_label, row_type, all_of(bor_arms_present))

# Add any missing arm columns as "" so all 5 datasets share placebo/drug_*/...
for (a in setdiff(arm_levels, bor_arms_present)) eff_resp[[a]] <- ""
eff_resp <- eff_resp[, c("stat_label", "row_type", arm_levels)]
eff_resp <- rename_arms(eff_resp) |> as.data.frame()

# ────────────────────────────────────────────────────────────────────────
# Cards Analysis Results Data (ARD) companions
#
# Long-format counterparts to the five pre-summarised wide datasets
# above. Shipped purely as teaching material so users can see the
# upstream `cards` output and the wide shape tabular() expects side
# by side. tabular itself does NOT accept the long ARD format —
# users convert with cards::pivot_wider_ard() (or their own pivot)
# before piping into tabular().
# ────────────────────────────────────────────────────────────────────────

# Helper: drop list-columns that bloat the .rda without informing
# the demo. `fmt_fun` is a function-valued list-column (~3 kB
# closures); `warning` / `error` are almost always NULL.
strip_card_cols <- function(ard) {
  for (col in c("fmt_fun", "warning", "error")) {
    if (col %in% names(ard)) ard[[col]] <- NULL
  }
  ard
}

# saf_demo_card — demographics ARD
saf_demo_card <- ard_stack(
  data = adsl_saf,
  .by = "TRT01A",
  ard_continuous(variables = "AGE"),
  ard_categorical(variables = c("SEX", "RACE")),
  .overall = TRUE
) |> strip_card_cols()

# saf_aeoverall_card — AE flag + max-severity ARD.
# Built from a per-subject flag table so denominators are adsl-level
# (subjects with no TEAE are still counted in the "N" denominator).
sev_levels <- c("MILD", "MODERATE", "SEVERE")
ae_flags <- adsl_saf |>
  left_join(
    adae |>
      group_by(USUBJID) |>
      summarise(
        ANY_TEAE = "Y",
        ANY_SAE = if (any(AESER == "Y", na.rm = TRUE)) "Y" else "N",
        ANY_REL = if (any(AEREL %in% c("POSSIBLE", "PROBABLE"))) "Y" else "N",
        MAX_SEV = sev_levels[max(match(AESEV, sev_levels), na.rm = TRUE)],
        .groups = "drop"
      ),
    by = "USUBJID"
  ) |>
  mutate(
    ANY_TEAE = factor(tidyr::replace_na(ANY_TEAE, "N"), levels = c("Y", "N")),
    ANY_SAE = factor(tidyr::replace_na(ANY_SAE, "N"), levels = c("Y", "N")),
    ANY_REL = factor(tidyr::replace_na(ANY_REL, "N"), levels = c("Y", "N")),
    MAX_SEV = factor(MAX_SEV, levels = sev_levels)
  )

saf_aeoverall_card <- ard_stack(
  data = ae_flags,
  .by = "TRT01A",
  ard_categorical(variables = c("ANY_TEAE", "ANY_SAE", "ANY_REL", "MAX_SEV")),
  .overall = TRUE
) |> strip_card_cols()

# saf_aesocpt_card — hierarchical AE ARD (SOC / PT).
# Trimmed to the same top-5 SOC, top-3 PT subset as saf_aesocpt so
# the two datasets describe the same slice of the data.
saf_aesocpt_card <- ard_stack_hierarchical(
  data = adae_trim,
  variables = c(AEBODSYS, AEDECOD),
  by = TRT01A,
  denominator = adsl_saf,
  id = USUBJID,
  over_variables = TRUE
) |>
  sort_ard_hierarchical(sort = "descending") |>
  strip_card_cols()

# saf_vital_card — vital-signs continuous ARD.
# AVAL stats grouped by (paramcd, visit, treatment); same population
# slice as saf_vital.
saf_vital_card <- ard_stack(
  data = advs_saf,
  .by = c("PARAMCD", "AVISIT", "TRT01A"),
  ard_continuous(variables = "AVAL")
) |> strip_card_cols()

# eff_resp_card — best overall response categorical ARD.
# Counts per AVALC per ARM, matching the eff_resp wide table.
eff_resp_card <- ard_stack(
  data = adrs_bor |> mutate(AVALC = factor(AVALC, levels = bor_levels)),
  .by = "ARM",
  ard_categorical(variables = "AVALC")
) |> strip_card_cols()

# ────────────────────────────────────────────────────────────────────────
# BigN per analysis population — discoverable data frames so users
# can join them into row labels / column headers and so a downstream
# `dplyr::mutate()` doesn't silently strip the denominator (which
# attribute-based BigN does). Long-format with both arm-name styles
# side by side: `arm` matches the raw pharmaverseadam labels carried
# by the `_card` ARDs; `arm_short` matches the renamed columns of
# the wide datasets.
# ────────────────────────────────────────────────────────────────────────

saf_n <- data.frame(
  arm = c(arm_levels, "Total"),
  arm_short = c(unname(arm_rename[arm_levels]), "Total"),
  n = c(as.integer(arm_n_int[arm_levels]), N_total),
  stringsAsFactors = FALSE
)

eff_arm_n_int <- bor_counts |>
  distinct(ARM, N) |>
  arrange(match(as.character(ARM), arm_levels))
eff_arms <- as.character(eff_arm_n_int$ARM)
eff_n <- data.frame(
  arm = c(eff_arms, "Total"),
  arm_short = c(unname(arm_rename[eff_arms]), "Total"),
  n = c(as.integer(eff_arm_n_int$N), as.integer(sum(eff_arm_n_int$N))),
  stringsAsFactors = FALSE
)

# ────────────────────────────────────────────────────────────────────────
# Save (xz compressed)
# ────────────────────────────────────────────────────────────────────────
usethis::use_data(
  saf_demo, saf_aeoverall, saf_aesocpt, saf_vital, eff_resp,
  saf_demo_card, saf_aeoverall_card, saf_aesocpt_card,
  saf_vital_card, eff_resp_card,
  saf_n, eff_n,
  overwrite = TRUE, compress = "xz"
)

# Size guard
files <- file.path(
  "data",
  c(
    "saf_demo.rda", "saf_aeoverall.rda", "saf_aesocpt.rda",
    "saf_vital.rda", "eff_resp.rda",
    "saf_demo_card.rda", "saf_aeoverall_card.rda",
    "saf_aesocpt_card.rda", "saf_vital_card.rda",
    "eff_resp_card.rda",
    "saf_n.rda", "eff_n.rda"
  )
)
sizes <- vapply(files, function(f) file.info(f)$size, numeric(1))
cat(sprintf(
  "Sizes (bytes): %s\n",
  paste(basename(files), formatC(sizes, big.mark = ","),
        sep = "=", collapse = "  ")
))
stopifnot(
  "Any demo dataset exceeds 50 KB — trim columns/rows" =
    all(sizes <= 50 * 1024)
)

cat("Done.\n")
