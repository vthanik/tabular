# Per-dataset roxygen blocks for the 9 demo tables:
# - 5 pre-summarised wide tables tabular() consumes directly
# - 2 cards ARD companions covering the flat + hierarchical shapes
# - 2 BigN denominator tables (safety / efficacy populations)
# Source: data-raw/bundle-demo.R derives all 9 from `pharmaverseadam`.

#' Demographics summary, Safety Population
#'
#' Pre-summarised wide-format demographics suitable for direct
#' passing into [tabular()]. One row per displayed statistic. Eight
#' parameter blocks:
#'
#' - continuous: `Age (years)`, `Weight (kg)`, `Height (cm)`,
#'   `BMI (kg/m^2)` — each emitted as `n`, `Mean (SD)`, `Median`,
#'   `Q1, Q3`, `Min, Max`
#' - categorical: `Age Group`, `Sex`, `Race`, `Ethnicity`,
#'   `BMI Category` — each level rendered as `n (%)`
#'
#' Shaped for the display-only contract: every cell is the final
#' string that will appear in the rendered table.
#'
#' @format A data frame with 35 rows and 6 columns:
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
#'   CDISCPILOT01 treatment arms. Baseline Weight / Height / BMI are
#'   joined in from `pharmaverseadam::advs`.
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
#' high-level flag rows (any TEAE, any SAE, any treatment-related,
#' any AE leading to death, any AE recovered / resolved) and
#' maximum-severity rows (mild / moderate / severe). Severity rows
#' are indented with two leading spaces so a single
#' `cols(stat_label = col_spec(usage = "group"))` declaration drives
#' both the block-header rows and the indented detail rows.
#'
#' @format A data frame with 8 rows and 5 columns:
#' \describe{
#'   \item{`stat_label`}{Row label
#'     (`"Any TEAE"`, `"Any Serious AE (SAE)"`,
#'     `"Any AE Related to Study Drug"`,
#'     `"Any AE Leading to Death"`,
#'     `"Any AE Recovered / Resolved"`,
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
#' @seealso [saf_n] for BigN denominators; [saf_aesocpt] for the
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
#' followed by its preferred-term detail rows. Top 10 SOCs and top
#' 5 PTs per SOC are kept; `row_type` marks the role of each row and
#' `indent_level` carries the canonical depth (0 for overall and SOC,
#' 1 for PT) so the downstream pipeline drives the SOC -> PT indent
#' via `col_spec(indent_by = "indent_level")` without reconstructing
#' it in every script. The richer SOC × PT slice exercises
#' [paginate()] and the engine's horizontal-panel splitter end-to-end
#' on a realistic submission shell.
#'
#' @format A data frame with 61 rows and 8 columns:
#' \describe{
#'   \item{`soc`}{System Organ Class label. Repeats across the SOC's
#'     PT rows; hide via `col_spec(visible = FALSE)` once `label`
#'     carries the same SOC text on SOC rows.}
#'   \item{`label`}{The row's display label. Equal to `soc` on the
#'     overall and SOC-summary rows; equal to the preferred-term name
#'     on PT detail rows. Promoted to the primary display column —
#'     pair with `indent_by = "indent_level"` to drive the SOC -> PT
#'     indent.}
#'   \item{`row_type`}{One of `"overall"`, `"soc"`, `"pt"`. Sort key
#'     and partition key; hide via `col_spec(visible = FALSE)`.}
#'   \item{`indent_level`}{Integer depth (0 on overall and SOC rows,
#'     1 on PT rows). Consumed by `col_spec(indent_by = "indent_level")`
#'     on the `label` column; the engine auto-hides this column at
#'     resolve time.}
#'   \item{`placebo`}{Placebo arm cell text (`"n (pct)"`).}
#'   \item{`drug_50`, `drug_100`}{Drug arms cell text.}
#'   \item{`Total`}{Pooled-across-arms cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adae`. Filtered to the top 10 SOCs by total
#'   incidence and the top 5 PTs per SOC.
#'
#' @seealso [saf_aesocpt_card] for the hierarchical long ARD;
#'   [saf_n] for BigN denominators.
#'
#' @examples
#' # 95% safety pattern: SOC/PT table where `label` carries SOC text
#' # on SOC rows and PT text on PT rows, indented by `indent_level`.
#' # `soc` and `row_type` ride along as hidden sort / partition keys;
#' # `n_total` is the numeric rank derived from `Total` cell text.
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
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
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
#' PULSE, TEMP) at four visits (Baseline, Week 8, Week 16, End of
#' Treatment), each producing four statistic rows (`n`, `Mean (SD)`,
#' `Median`, `Min, Max`). The 4 x 4 x 4 grid makes this dataset a
#' natural fit for [paginate()] examples — 64 rows comfortably exceed
#' a single page under typical clinical row-per-page settings.
#'
#' @format A data frame with 64 rows and 7 columns:
#' \describe{
#'   \item{`paramcd`}{CDISC parameter code (`SYSBP` / `DIABP` /
#'     `PULSE` / `TEMP`). Repeats across visit and statistic; use
#'     `col_spec(usage = "group")` to collapse.}
#'   \item{`param`}{Decoded parameter name.}
#'   \item{`visit`}{Analysis visit label (`"Baseline"` / `"Week 8"` /
#'     `"Week 16"` / `"End of Treatment"`).}
#'   \item{`stat_label`}{Statistic label.}
#'   \item{`placebo`, `drug_50`, `drug_100`}{Per-arm cell text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::advs`.
#'
#' @seealso [saf_n] for BigN denominators.
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

#' Vital-signs subgroup summary by Sex and Age Group
#'
#' Pre-summarised vital-signs stats partitioned by sex (`F` / `M`)
#' and age group (`<65` / `>=65`) at the End-of-Treatment visit. Two
#' parameters (Systolic BP, Diastolic BP) emit four statistic rows
#' each (`n`, `Mean (SD)`, `Median`, `Min, Max`). Partition-constant
#' BigN columns (`sex_n`, `agegr_n`) ride alongside so banners can
#' inline the denominator via
#' `subgroup(label = "Sex: {sex} (N = {sex_n})")` without reaching for
#' a separate lookup.
#'
#' Designed for [subgroup()] and [as_grid()] examples: the two
#' partition axes plus the partition-constant BigN columns cover both
#' single-variable cohort-style partitions and the multi-variable
#' (sex × agegr) crossing.
#'
#' @format A data frame with 32 rows and 11 columns:
#' \describe{
#'   \item{`sex`}{Factor (`F` / `M`).}
#'   \item{`agegr`}{Factor (`<65` / `>=65`).}
#'   \item{`sex_n`}{Integer BigN — number of subjects in the partition
#'     row's sex (partition-constant; rides into the banner via
#'     `{sex_n}` template tokens).}
#'   \item{`agegr_n`}{Integer BigN per age group.}
#'   \item{`paramcd`}{CDISC parameter code (`SYSBP` / `DIABP`).}
#'   \item{`param`}{Decoded parameter name (`"Systolic BP (mmHg)"`,
#'     `"Diastolic BP (mmHg)"`).}
#'   \item{`stat_label`}{Statistic label
#'     (`n`, `Mean (SD)`, `Median`, `Min, Max`).}
#'   \item{`placebo`, `drug_50`, `drug_100`, `Total`}{Per-arm cell
#'     text.}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::advs` filtered to `SAFFL == "Y"`, the three
#'   CDISCPILOT01 arms, the `SYSBP` / `DIABP` parameters, and the
#'   End-of-Treatment visit.
#'
#' @seealso [saf_n] for BigN denominators; [subgroup()] for the verb
#'   this dataset is designed for.
#'
#' @examples
#' # 95% pattern: subgroup partition by sex with inline BigN.
#' tabular(saf_subgroup, titles = "Vital Signs at End of Treatment") |>
#'   cols(
#'     sex        = col_spec(visible = FALSE),
#'     agegr      = col_spec(usage = "group", label = "Age Group"),
#'     sex_n      = col_spec(visible = FALSE),
#'     agegr_n    = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")
"saf_subgroup"

#' Best Overall Response and Response Rates
#'
#' Pre-summarised efficacy table. Per-arm counts of best overall
#' response (BOR) per CDISC category, plus derived ORR, CBR, and DCR
#' rate rows each followed by an exact (Clopper-Pearson) 95% CI row.
#' Order is naturally categorical-then-derived; coerce `stat_label`
#' to a factor with the CDISC level order before `sort_rows()` to
#' lock in the canonical display sequence.
#'
#' @format A data frame with 13 rows and 5 columns:
#' \describe{
#'   \item{`stat_label`}{Row label
#'     (`"CR"`, `"PR"`, `"SD"`, `"NON-CR/NON-PD"`, `"PD"`, `"NE"`,
#'     `"MISSING"`, `"Objective Response Rate (CR + PR)"`,
#'     `"  95% CI (Clopper-Pearson)"`,
#'     `"Clinical Benefit Rate (CR + PR + SD)"`,
#'     `"  95% CI (Clopper-Pearson)"`,
#'     `"Disease Control Rate (CR + PR + SD + NON-CR/NON-PD)"`,
#'     `"  95% CI (Clopper-Pearson)"`).}
#'   \item{`row_type`}{`"category"` for BOR categorical rows,
#'     `"derived"` for ORR / CBR / DCR rate rows, `"ci"` for the
#'     paired confidence-interval rows. Hide via
#'     `col_spec(visible = FALSE)` or use as a sort tie-breaker.}
#'   \item{`placebo`, `drug_50`, `drug_100`}{Per-arm cell text
#'     (`"n (pct)"` on rate rows, `"(lower, upper)"` on CI rows).}
#' }
#'
#' @source Derived in `data-raw/bundle-demo.R` from
#'   `pharmaverseadam::adrs_onco` filtered to `PARAMCD == "BOR"`.
#'
#' @seealso [eff_n] for BigN denominators.
#'
#' @examples
#' # 95% efficacy pattern: BOR categories in CDISC response order,
#' # followed by derived ORR / CBR / DCR rate rows each paired with
#' # an exact 95% CI row. The source already ships in the right
#' # display order, so no sort step is needed.
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#' tabular(
#'   eff_resp,
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
#'   )
"eff_resp"

#' Treatment-effect estimates by model
#'
#' Four competing efficacy models with their treatment-effect point
#' estimate, 95% confidence-interval bounds, and nominal p-value.
#' Shaped as a numeric-cell table (one row per model) rather than the
#' usual pre-formatted character cells, so it exercises the
#' `col_spec(format = ...)` + `col_spec(na_text = ...)` cascade. One
#' row (`MMRM`) carries `NA` CI bounds to demonstrate `na_text`.
#'
#' @format A data frame with 4 rows and 5 columns:
#' \describe{
#'   \item{`model`}{Model name (`"ANCOVA"`, `"MMRM"`, `"Cox PH"`,
#'     `"Bootstrap (1000 reps)"`).}
#'   \item{`estimate`}{Numeric point estimate.}
#'   \item{`lower_ci`, `upper_ci`}{Numeric 95% CI bounds. The MMRM
#'     row has `NA` bounds.}
#'   \item{`p_value`}{Nominal p-value (numeric).}
#' }
#'
#' @source Synthetic estimates following the
#'   `_archive/.../arframe-examples/tables/tte-summary.qmd` and
#'   `efficacy-bor.qmd` shapes. Not derived from any patient-level
#'   data — illustrative values only.
#'
#' @seealso [col_spec()] for the formatting cascade these values
#'   exercise.
#'
#' @examples
#' # Numeric-cell efficacy table — format = "%.2f" pins precision,
#' # na_text = "--" renders the MMRM row's NA bounds as dashes.
#' tabular(eff_estimates, titles = "Treatment-effect estimates by model") |>
#'   cols(
#'     model    = col_spec(usage = "group",  label = "Model", valign = "top"),
#'     estimate = col_spec(label = "Estimate", align = "decimal",
#'                         format = "%.2f"),
#'     lower_ci = col_spec(label = "Lower\n95% CI", align = "decimal",
#'                         format = "%.2f", na_text = "--"),
#'     upper_ci = col_spec(label = "Upper\n95% CI", align = "decimal",
#'                         format = "%.2f", na_text = "--"),
#'     p_value  = col_spec(label = "p-value",  align = "decimal",
#'                         format = "%.4f")
#'   )
"eff_estimates"

#' Cards ARD for demographics (flat ARD companion)
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
#' Continuous variables: `AGE`, `WEIGHT`, `HEIGHT`, `BMI` (each
#' emitting `N`, `mean`, `sd`, `median`, `p25`, `p75`, `min`, `max`).
#' Categorical variables: `AGEGR1`, `SEX`, `RACE`, `ETHNIC`,
#' `BMI_CAT` (each emitting `n`, `N`, `p`).
#'
#' This is the package's canonical **flat ARD** demo. Its hierarchical
#' counterpart is [saf_aesocpt_card]; together they cover both shapes
#' [pivot_across()] must handle.
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

#' Cards hierarchical ARD for AEs by SOC and PT
#'
#' Long-format companion to `saf_aesocpt`. Produced by
#' `cards::ard_stack_hierarchical()` over `(AEBODSYS, AEDECOD)` with
#' adsl-level denominators, sorted by descending overall incidence
#' via `cards::sort_ard_hierarchical()`. Limited to the same top-10
#' SOC, top-5 PT subset as `saf_aesocpt` so the two datasets describe
#' the same slice of the data.
#'
#' This is the package's canonical **hierarchical ARD** demo
#' (two grouping variables nested SOC -> PT). Its flat counterpart is
#' [saf_demo_card]; together they cover both shapes [pivot_across()]
#' must handle.
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
#' # ard_stack_hierarchical shape and emits soc / label / row_type.
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
