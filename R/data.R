# Per-dataset roxygen blocks for the 5 demo tables.
# Generated .Rd files: saf_demo.Rd, saf_aeoverall.Rd, saf_aesocpt.Rd,
# saf_vital.Rd, eff_resp.Rd. Source: data-raw/bundle-demo.R derives
# all five from `pharmaverseadam`.

#' Demographics summary, Safety Population
#'
#' Pre-summarised wide-format demographics. One row per displayed
#' statistic (continuous: `n`, `Mean (SD)`, `Median`, `Q1, Q3`,
#' `Min, Max`; categorical: `n (%)` per level). Shaped for the
#' display-only contract: every cell is the final string that will
#' appear in the rendered table.
#'
#' @format A data frame. Columns: row-label columns plus one column
#'   per treatment arm.
#' @source Derived in `data-raw/bundle-demo.R` from `pharmaverseadam`.
"saf_demo"

#' Overall adverse-event summary, Safety Population
#'
#' One row per top-level AE summary statistic
#' (any AE, related AE, serious AE, leading-to-discontinuation),
#' columns per treatment arm.
#'
#' @format A data frame.
#' @source Derived in `data-raw/bundle-demo.R` from `pharmaverseadam`.
"saf_aeoverall"

#' Adverse events by System Organ Class and Preferred Term
#'
#' One row per (SOC, PT) combination plus SOC-level total rows
#' and overall any-AE row. Columns: row labels + one column per
#' treatment arm (count, percentage).
#'
#' @format A data frame.
#' @source Derived in `data-raw/bundle-demo.R` from `pharmaverseadam`.
"saf_aesocpt"

#' Vital signs summary
#'
#' Pre-summarised vital-signs results — systolic / diastolic BP,
#' pulse, weight, height, BMI — one row per stat label per
#' parameter.
#'
#' @format A data frame.
#' @source Derived in `data-raw/bundle-demo.R` from `pharmaverseadam`.
"saf_vital"

#' Best overall response (efficacy demo)
#'
#' One row per ORR / DCR endpoint, columns per treatment arm.
#'
#' @format A data frame.
#' @source Derived in `data-raw/bundle-demo.R` from `pharmaverseadam`.
"eff_resp"

#' Cards ARD for demographics (long-format companion)
#'
#' The same demographics summary as `saf_demo`, but in the long
#' Analysis Results Data (ARD) format produced by
#' `cards::ard_stack()`. One row per (treatment arm, variable,
#' statistic). Shipped as a teaching dataset: it shows the upstream
#' shape users typically have when they start from `cards`. Convert
#' it to wide (via `cards::pivot_wider_ard()` or a custom pivot)
#' before passing to `tabular()` — tabular itself does **not** accept
#' the long ARD format; pre-summarised wide data is the package
#' boundary.
#'
#' @format A `card`-classed tibble with columns `group1`,
#'   `group1_level`, `variable`, `variable_level`, `context`,
#'   `stat_name`, `stat_label`, `stat`.
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over `pharmaverseadam::adsl`.
"saf_demo_card"

#' Cards ARD for the AE-overall summary
#'
#' Long-format companion to `saf_aeoverall`. Per-subject AE flags
#' (`ANY_TEAE`, `ANY_SAE`, `ANY_REL`) and maximum severity (`MAX_SEV`)
#' summarised by treatment arm via `cards::ard_stack()`. Denominators
#' are adsl-level so subjects with zero TEAEs are still counted in
#' the "N" row.
#'
#' @format A `card`-classed tibble.
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over a per-subject flag table built from
#'   `pharmaverseadam::adsl` and `pharmaverseadam::adae`.
"saf_aeoverall_card"

#' Cards hierarchical ARD for AEs by SOC and PT
#'
#' Long-format companion to `saf_aesocpt`. Produced by
#' `cards::ard_stack_hierarchical()` over `(AEBODSYS, AEDECOD)` with
#' adsl-level denominators, sorted by descending overall incidence
#' via `sort_ard_hierarchical()`. Limited to the same top-5 SOC,
#' top-3 PT subset as `saf_aesocpt` so the two datasets describe
#' the same slice of the data.
#'
#' @format A `card`-classed tibble.
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack_hierarchical()` over
#'   `pharmaverseadam::adae`.
"saf_aesocpt_card"

#' Cards ARD for vital signs
#'
#' Long-format companion to `saf_vital`. Continuous statistics on
#' `AVAL` grouped by `(PARAMCD, AVISIT, TRT01A)` from
#' `cards::ard_stack()`. Parameters: SYSBP, DIABP, PULSE, TEMP at
#' Baseline and End of Treatment.
#'
#' @format A `card`-classed tibble.
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over `pharmaverseadam::advs`.
"saf_vital_card"

#' Cards ARD for best overall response
#'
#' Long-format companion to `eff_resp`. Categorical counts of `AVALC`
#' (CR, PR, SD, NON-CR/NON-PD, PD, NE, MISSING) by treatment arm via
#' `cards::ard_stack()`. The wide `eff_resp` adds derived ORR and DCR
#' rows on top of these category counts.
#'
#' @format A `card`-classed tibble.
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over `pharmaverseadam::adrs_onco`.
"eff_resp_card"

#' Safety-population BigN per arm
#'
#' Per-arm subject counts (BigN) for the safety population, plus a
#' `Total` row. Use this when joining BigN into a column header or
#' embedding it inline via `sprintf` / `paste` —
#' `paste0("Drug A\nN=", saf_n$n[saf_n$arm_short == "drug_50"])`.
#' Two arm-naming columns are shipped side by side so the same table
#' can serve both the `_card` ARDs (raw pharmaverseadam labels) and
#' the renamed wide datasets.
#'
#' @format A data frame with one row per arm plus a `Total` row.
#'   Columns:
#'   *   `arm` — raw pharmaverseadam arm label
#'       (`"Placebo"`, `"Xanomeline Low Dose"`,
#'       `"Xanomeline High Dose"`, `"Total"`); matches `group1_level`
#'       in the `_card` ARDs.
#'   *   `arm_short` — renamed label
#'       (`"placebo"`, `"drug_50"`, `"drug_100"`, `"Total"`); matches
#'       the column names of `saf_demo` / `saf_aeoverall` / etc.
#'   *   `n` — integer subject count.
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adsl` filtered to `SAFFL == "Y"` and the three
#'   CDISCPILOT01 arms.
#' @seealso [eff_n] for the efficacy-population counterpart.
"saf_n"

#' Efficacy-population BigN per arm
#'
#' Per-arm subject counts (BigN) for the efficacy population used by
#' `eff_resp` / `eff_resp_card` — subjects with a `BOR` record in
#' `pharmaverseadam::adrs_onco`. Same two-column naming convention
#' as `saf_n`; the totals differ from `saf_n` because not every
#' safety-pop subject contributes a best-overall-response record.
#'
#' @format A data frame with one row per arm plus a `Total` row.
#'   Columns: `arm`, `arm_short`, `n` — same schema as `saf_n`.
#' @source Derived in `data-raw/bundle-demo.R` from the per-arm BOR
#'   denominator computed inside the `eff_resp` pipeline.
#' @seealso [saf_n] for the safety-population counterpart.
"eff_n"
