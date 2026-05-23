# Per-dataset roxygen blocks for the 12 demo tables:
# - 5 pre-summarised wide tables tabular() consumes directly
# - 5 cards ARD companions showing the upstream long shape
# - 2 BigN denominator tables (safety / efficacy populations)
# Source: data-raw/bundle-demo.R derives all 12 from `pharmaverseadam`.

#' Demographics summary, Safety Population
#'
#' Pre-summarised wide-format demographics suitable for direct
#' passing into [tabular()]. One row per displayed statistic, with
#' both continuous variables (AGE → `n`, `Mean (SD)`, `Median`,
#' `Q1, Q3`, `Min, Max`) and categorical variables (AGEGR1 / SEX /
#' RACE / ETHNIC, each level rendered as `n (%)`). Shaped for the
#' display-only contract: every cell is the final string that will
#' appear in the rendered table.
#'
#' @format A data frame with 21 rows and 6 columns:
#' \describe{
#'   \item{`variable`}{Display-block label (`"Age (years)"`,
#'     `"Age Group, n (%)"`, `"Sex, n (%)"`, `"Race, n (%)"`,
#'     `"Ethnicity, n (%)"`). Driven by `cols(usage = "group")` to
#'     collapse repeat values at render.}
#'   \item{`stat_label`}{Statistic or level label
#'     (`"n"`, `"Mean (SD)"`, `"Median"`, `"M"`, `"WHITE"`, ...).}
#'   \item{`placebo`}{Placebo arm cell text.}
#'   \item{`drug_50`}{Xanomeline Low Dose (50 mg) arm cell text.}
#'   \item{`drug_100`}{Xanomeline High Dose (100 mg) arm cell text.}
#'   \item{`Total`}{Pooled-across-arms cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adsl` filtered to `SAFFL == "Y"` and the three
#'   CDISCPILOT01 treatment arms.
#'
#' @seealso [saf_demo_card] for the long-format ARD companion;
#'   [saf_n] for the matching BigN denominators.
#'
#' @examples
#' # 95% safety pattern: demographics table with BigN-embedded
#' # column labels and CDISC-canonical statistic order.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   )
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total      = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   )
"saf_demo"

#' Overall adverse-event summary, Safety Population
#'
#' Pre-summarised wide-format AE overview. Two clinical blocks:
#' high-level flag rows (any TEAE, any SAE, any treatment-related)
#' and maximum-severity rows (mild / moderate / severe). Severity
#' rows are indented with two leading spaces so a single
#' `cols(stat_label = col_spec(usage = "group"))` declaration drives
#' both the block-header rows and the indented detail rows.
#'
#' @format A data frame with 6 rows and 5 columns:
#' \describe{
#'   \item{`stat_label`}{Row label
#'     (`"Any TEAE"`, `"Any Serious AE (SAE)"`,
#'     `"Any AE Related to Study Drug"`,
#'     `"  Maximum severity: Mild"`, `"  Maximum severity: Moderate"`,
#'     `"  Maximum severity: Severe"`).}
#'   \item{`placebo`}{Placebo arm cell text (`"n (pct)"`).}
#'   \item{`drug_50`}{Drug 50 arm cell text.}
#'   \item{`drug_100`}{Drug 100 arm cell text.}
#'   \item{`Total`}{Pooled-across-arms cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adae` filtered to `SAFFL == "Y"` and
#'   `TRTEMFL == "Y"`.
#'
#' @seealso [saf_aeoverall_card] for the long-format ARD companion;
#'   [saf_n] for BigN denominators; [saf_aesocpt] for the
#'   SOC / PT detail companion.
#'
#' @examples
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_aeoverall,
#'   titles = c(
#'     "Table 14.3.0",
#'     "Adverse Event Overview",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   )
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = ""),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total      = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   )
"saf_aeoverall"

#' Adverse events by System Organ Class and Preferred Term
#'
#' Pre-summarised AE-by-SOC/PT table. Interleaved row order: overall
#' "any TEAE" row first, then per-SOC blocks where each SOC row is
#' followed by its preferred-term detail rows. Top 5 SOCs and top 3
#' PTs per SOC are kept (size guard); `row_type` marks the role of
#' each row so a downstream pipeline can sort, indent, or hide
#' selectively.
#'
#' @format A data frame with 21 rows and 7 columns:
#' \describe{
#'   \item{`soc`}{System Organ Class label. Repeats across the SOC's
#'     PT rows so `cols(usage = "group")` collapses the run at
#'     render.}
#'   \item{`pt`}{Preferred Term label. Equal to `soc` on SOC-summary
#'     rows; the displayed value to render on PT detail rows.}
#'   \item{`row_type`}{One of `"overall"`, `"soc"`, `"pt"`. Use it
#'     as a sort key and / or hide it via
#'     `col_spec(visible = FALSE)`. Coerce to a factor with levels
#'     `c("overall", "soc", "pt")` to preserve the canonical
#'     interleaved order under sort.}
#'   \item{`placebo`}{Placebo arm cell text (`"n (pct)"`).}
#'   \item{`drug_100`, `drug_50`}{Drug arms cell text.}
#'   \item{`Total`}{Pooled-across-arms cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adae`. Filtered to the top 5 SOCs by total
#'   incidence and the top 3 PTs per SOC to keep the bundled `.rda`
#'   under 50 KB.
#'
#' @seealso [saf_aesocpt_card] for the hierarchical long ARD;
#'   [saf_n] for BigN denominators.
#'
#' @examples
#' # 95% safety pattern: SOC/PT table sorted by descending subject
#' # count, hierarchy preserved. `Total` cells are formatted text
#' # ("171 (67.3)"), so attach a numeric rank column for sort_rows().
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   )
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "SOC / PT"),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50  = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100 = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total    = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   ) |>
#'   sort_rows(
#'     by = c("row_type", "n_total"),
#'     descending = c(FALSE, TRUE)
#'   )
"saf_aesocpt"

#' Vital-signs summary
#'
#' Pre-summarised vital-signs stats. Four parameters (SYSBP, DIABP,
#' PULSE, TEMP) at two visits (Baseline, End of Treatment), each
#' producing four statistic rows (`n`, `Mean (SD)`, `Median`,
#' `Min, Max`).
#'
#' @format A data frame with 32 rows and 7 columns:
#' \describe{
#'   \item{`paramcd`}{CDISC parameter code (`SYSBP` / `DIABP` /
#'     `PULSE` / `TEMP`). Repeats across visit and statistic; use
#'     `col_spec(usage = "group")` to collapse.}
#'   \item{`param`}{Decoded parameter name.}
#'   \item{`visit`}{Analysis visit label (`"Baseline"` /
#'     `"End of Treatment"`).}
#'   \item{`stat_label`}{Statistic label.}
#'   \item{`placebo`, `drug_50`, `drug_100`}{Per-arm cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::advs`.
#'
#' @seealso [saf_vital_card] for the long-format ARD companion;
#'   [saf_n] for BigN denominators.
#'
#' @examples
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_vital,
#'   titles = c(
#'     "Table 14.4.1",
#'     "Vital Signs Summary at Baseline and End of Treatment",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   )
#' ) |>
#'   cols(
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     )
#'   )
"saf_vital"

#' Best Overall Response and Response Rates
#'
#' Pre-summarised efficacy table. Per-arm counts of best overall
#' response (BOR) per CDISC category, plus derived ORR and DCR
#' rate rows. Order is naturally categorical-then-derived; coerce
#' `stat_label` to a factor with the CDISC level order before
#' `sort_rows()` to lock in the canonical display sequence.
#'
#' @format A data frame with 9 rows and 5 columns:
#' \describe{
#'   \item{`stat_label`}{Row label
#'     (`"CR"`, `"PR"`, `"SD"`, `"NON-CR/NON-PD"`, `"PD"`, `"NE"`,
#'     `"MISSING"`, `"Objective Response Rate (CR + PR)"`,
#'     `"Disease Control Rate (CR + PR + SD)"`).}
#'   \item{`row_type`}{`"category"` for BOR categorical rows or
#'     `"derived"` for ORR / DCR rate rows. Hide via
#'     `col_spec(visible = FALSE)` or use as a sort tie-breaker.}
#'   \item{`placebo`, `drug_50`, `drug_100`}{Per-arm cell text
#'     (`"n (pct)"`).}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adrs_onco` filtered to `PARAMCD == "BOR"`.
#'
#' @seealso [eff_resp_card] for the long-format ARD companion;
#'   [eff_n] for BigN denominators.
#'
#' @examples
#' # 95% efficacy pattern: BOR table in CDISC response order with
#' # derived ORR/DCR rows after.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "Objective Response Rate (CR + PR)",
#'   "Disease Control Rate (CR + PR + SD)"
#' )
#' eff <- eff_resp
#' eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#'
#' tabular(
#'   eff,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Best Overall Response and Response Rates",
#'     sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
#'   )
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Response"),
#'     row_type   = col_spec(visible = FALSE),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", ne["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", ne["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", ne["drug_100"]),
#'       align = "decimal"
#'     )
#'   ) |>
#'   sort_rows(by = "stat_label")
"eff_resp"

#' Cards ARD for demographics (long-format companion)
#'
#' The same demographics summary as `saf_demo`, but in the long
#' Analysis Results Data (ARD) format produced by
#' `cards::ard_stack()`. One row per (treatment arm, variable,
#' statistic). Shipped as a teaching dataset that shows the upstream
#' shape users typically have when they start from `cards`. Convert
#' it to the wide form `tabular()` accepts via [pivot_across()] —
#' tabular itself does **not** consume the long ARD format, since
#' pre-summarised wide data is the package boundary.
#'
#' @format A `card`-classed tibble with columns `group1`,
#'   `group1_level`, `variable`, `variable_level`, `context`,
#'   `stat_name`, `stat_label`, `stat`. `group1 == "TRT01A"` and
#'   `group1_level` carries the original pharmaverseadam arm labels
#'   (`"Placebo"`, `"Xanomeline Low Dose"`, `"Xanomeline High Dose"`).
#'   `cards::ard_stack(.overall = TRUE)` adds overall rows with
#'   `group1_level = NA`; [pivot_across()] renders those into a
#'   `Total` column.
#'
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack(.by = "TRT01A", .overall = TRUE)` over
#'   `pharmaverseadam::adsl`.
#'
#' @seealso [pivot_across()] for the long-to-wide bridge;
#'   [saf_demo] for the wide companion.
#'
#' @examples
#' # 95% demographics pattern: cards ARD -> wide -> rendered table.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' saf_demo_card |>
#'   pivot_across(
#'     statistic = list(
#'       continuous  = "{mean} ({sd})",
#'       categorical = "{n} ({p}%)"
#'     ),
#'     label = c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
#'   ) |>
#'   tabular(
#'     titles = c(
#'       "Table 14.1.1",
#'       "Demographics",
#'       sprintf("Safety Population (N=%d)", n["Total"])
#'     )
#'   )
"saf_demo_card"

#' Cards ARD for the AE-overall summary
#'
#' Long-format companion to `saf_aeoverall`. Per-subject AE flags
#' (`ANY_TEAE`, `ANY_SAE`, `ANY_REL`) and maximum severity (`MAX_SEV`)
#' summarised by treatment arm via `cards::ard_stack()`. Denominators
#' are adsl-level so subjects with zero TEAEs are still counted in
#' the `N` row — matching the standard safety-table convention where
#' `0/254 (0.0%)` rows are kept rather than dropped.
#'
#' @format A `card`-classed tibble with the standard ARD columns
#'   plus per-arm and overall rows.
#'
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over a per-subject flag table built from
#'   `pharmaverseadam::adsl` joined to `pharmaverseadam::adae`.
#'
#' @seealso [pivot_across()] for the long-to-wide bridge;
#'   [saf_aeoverall] for the wide companion.
#'
#' @examples
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' saf_aeoverall_card |>
#'   pivot_across(statistic = "{n} ({p}%)") |>
#'   tabular(
#'     titles = c(
#'       "Table 14.3.0",
#'       "Adverse Event Overview",
#'       sprintf("Safety Population (N=%d)", n["Total"])
#'     )
#'   )
"saf_aeoverall_card"

#' Cards hierarchical ARD for AEs by SOC and PT
#'
#' Long-format companion to `saf_aesocpt`. Produced by
#' `cards::ard_stack_hierarchical()` over `(AEBODSYS, AEDECOD)` with
#' adsl-level denominators, sorted by descending overall incidence
#' via `cards::sort_ard_hierarchical()`. Limited to the same top-5
#' SOC, top-3 PT subset as `saf_aesocpt` so the two datasets describe
#' the same slice of the data.
#'
#' @format A `card`-classed tibble. Carries an
#'   `..ard_hierarchical_overall..` sentinel row that
#'   [pivot_across()] passes through as the table's "overall" row.
#'
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack_hierarchical()` over
#'   `pharmaverseadam::adae` filtered to the top SOC / PT subset.
#'
#' @seealso [pivot_across()] for the long-to-wide bridge;
#'   [saf_aesocpt] for the wide companion.
#'
#' @examples
#' # Hierarchical ARD pivot. pivot_across() recognises the
#' # ard_stack_hierarchical shape and emits soc / pt / row_type.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' saf_aesocpt_card |>
#'   pivot_across(statistic = "{n} ({p}%)") |>
#'   tabular(
#'     titles = c(
#'       "Table 14.3.1",
#'       "Adverse Events by SOC and PT",
#'       sprintf("Safety Population (N=%d)", n["Total"])
#'     )
#'   )
"saf_aesocpt_card"

#' Cards ARD for vital signs
#'
#' Long-format companion to `saf_vital`. Continuous statistics on
#' `AVAL` grouped by `(PARAMCD, AVISIT, TRT01A)` from
#' `cards::ard_stack()`. Parameters: SYSBP, DIABP, PULSE, TEMP at
#' Baseline and End of Treatment.
#'
#' @format A `card`-classed tibble. Multi-group (`.by = c(PARAMCD,
#'   AVISIT, TRT01A)`) so [pivot_across()] keeps PARAMCD and AVISIT
#'   as output columns and pivots only the arm dimension.
#'
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack()` over `pharmaverseadam::advs`.
#'
#' @seealso [pivot_across()] for the long-to-wide bridge;
#'   [saf_vital] for the wide companion.
#'
#' @examples
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' saf_vital_card |>
#'   pivot_across(
#'     statistic = list(
#'       continuous = c(
#'         N           = "{N}",
#'         "Mean (SD)" = "{mean} ({sd})"
#'       )
#'     ),
#'     decimals = c(mean = 1, sd = 2)
#'   ) |>
#'   tabular(
#'     titles = c(
#'       "Table 14.4.1",
#'       "Vital Signs Summary",
#'       sprintf("Safety Population (N=%d)", n["Total"])
#'     )
#'   )
"saf_vital_card"

#' Cards ARD for best overall response
#'
#' Long-format companion to `eff_resp`. Categorical counts of `AVALC`
#' (CR, PR, SD, NON-CR/NON-PD, PD, NE, MISSING) by treatment arm via
#' `cards::ard_stack()`. The wide `eff_resp` adds derived ORR and DCR
#' rate rows on top of these category counts — those derived rows do
#' not appear in this ARD and must be computed downstream.
#'
#' @format A `card`-classed tibble.
#'
#' @source Derived in `data-raw/bundle-demo.R` via
#'   `cards::ard_stack(.by = "ARM")` over
#'   `pharmaverseadam::adrs_onco` filtered to `PARAMCD == "BOR"`.
#'
#' @seealso [pivot_across()] for the long-to-wide bridge;
#'   [eff_resp] for the wide companion (which adds derived rate
#'   rows on top of the categorical counts).
#'
#' @examples
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#' eff_resp_card |>
#'   pivot_across(statistic = "{n} ({p}%)") |>
#'   tabular(
#'     titles = c(
#'       "Table 14.2.1",
#'       "Best Overall Response",
#'       sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
#'     )
#'   )
"eff_resp_card"

#' Safety-population BigN per arm
#'
#' Per-arm subject counts (BigN) for the safety population, plus a
#' `Total` row. Use this table to embed BigN inline in column headers
#' via `sprintf()` / `paste()` against `cols(col_spec(label = ...))`;
#' there is no dedicated BigN field on `col_spec` because the
#' denominator already lives here in a discoverable, joinable form.
#'
#' Two arm-naming columns are shipped side by side so the same table
#' can serve both the `_card` ARDs (raw pharmaverseadam labels in
#' `group1_level`) and the renamed wide datasets (snake-cased arm
#' column names).
#'
#' @format A data frame with 4 rows and 3 columns:
#' \describe{
#'   \item{`arm`}{Raw pharmaverseadam arm label
#'     (`"Placebo"`, `"Xanomeline Low Dose"`,
#'     `"Xanomeline High Dose"`, `"Total"`). Matches `group1_level`
#'     in the `_card` ARDs (so the pivot output's column names
#'     match a `setNames(saf_n$n, saf_n$arm)` lookup).}
#'   \item{`arm_short`}{Renamed label
#'     (`"placebo"`, `"drug_50"`, `"drug_100"`, `"Total"`). Matches
#'     the column names of `saf_demo`, `saf_aeoverall`,
#'     `saf_aesocpt`, and `saf_vital`.}
#'   \item{`n`}{Integer subject count.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adsl` filtered to `SAFFL == "Y"` and the three
#'   CDISCPILOT01 arms.
#'
#' @seealso [eff_n] for the efficacy-population counterpart.
#'
#' @examples
#' # Use saf_n$arm_short when joining into the wide datasets
#' # (saf_demo, saf_aeoverall, saf_aesocpt, saf_vital).
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' sprintf("Placebo\nN=%d", n["placebo"])
#'
#' # Use saf_n$arm when joining into pivot_across() output
#' # (column names match the raw pharmaverseadam arm labels).
#' n_arm <- stats::setNames(saf_n$n, saf_n$arm)
#' sprintf("Placebo\nN=%d", n_arm["Placebo"])
"saf_n"

#' Efficacy-population BigN per arm
#'
#' Per-arm subject counts (BigN) for the efficacy population used by
#' `eff_resp` / `eff_resp_card` — subjects with a `BOR` record in
#' `pharmaverseadam::adrs_onco`. Same two-column naming convention
#' as `saf_n`; the totals differ from `saf_n` because not every
#' safety-pop subject contributes a best-overall-response record.
#'
#' @format A data frame with 4 rows and 3 columns; same schema as
#'   [saf_n] (`arm`, `arm_short`, `n`).
#'
#' @source Derived in `data-raw/bundle-demo.R` from the per-arm BOR
#'   denominator computed inside the `eff_resp` pipeline.
#'
#' @seealso [saf_n] for the safety-population counterpart.
#'
#' @examples
#' # Efficacy BigN joined into column headers.
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#' sprintf("Placebo\nN=%d", ne["placebo"])
"eff_n"
