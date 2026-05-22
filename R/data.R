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
#' Pre-summarised vital-signs results -- systolic / diastolic BP,
#' pulse, weight, height, BMI -- one row per stat label per
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
