# Per-dataset roxygen blocks for the 5 demo tables.
# Generated .Rd files: saf_demo.Rd, saf_aeoverall.Rd, saf_aesocpt.Rd,
# saf_vital.Rd, eff_resp.Rd.  Family landing topic: demo-data.Rd
# (see R/data-demo.R).

#' Demographics summary, Safety Population
#'
#' Pre-summarised wide-format demographics for the Safety Population.
#' One row per displayed statistic (continuous: `n`, `Mean (SD)`,
#' `Median`, `Q1, Q3`, `Min, Max`; categorical: `n (%)` per level).
#' Shaped to drive the canonical 95% verb chain
#' `tb_table |> tb_cols |> tb_rows |> tb_render`.
#'
#' @format A data frame.
#' \describe{
#'   \item{`variable`}{*character* -- variable group label
#'     (e.g. `"Age (years)"`, `"Sex, n (%)"`). Used by
#'     [tb_rows()]'s `group_by`.}
#'   \item{`stat_label`}{*character* -- displayed row label inside the
#'     group (e.g. `"Mean (SD)"`, `"WHITE"`).}
#'   \item{`placebo`}{*character* -- pre-formatted cell text for the
#'     Placebo arm.}
#'   \item{`drug_50`}{*character* -- cell text for the Xanomeline 50mg
#'     arm.}
#'   \item{`drug_100`}{*character* -- cell text for the Xanomeline
#'     100mg arm.}
#'   \item{`Total`}{*character* -- cell text combining all arms.}
#' }
#'
#' BigN per arm is attached as `attr(saf_demo, "n")` -- a named integer
#' vector intended for [tb_cols()]'s `n` argument.
#'
#' @source Pre-summarised illustrative values built by
#'   `data-raw/bundle-demo.R` from `pharmaverseadam::adsl`. Continuous
#'   variables collapsed to `n / Mean (SD) / Median / Q1, Q3 / Min, Max`;
#'   categorical to `n (%)` per factor level. Not real subjects.
#' @family demo-data
#' @seealso [saf_aeoverall], [saf_aesocpt], [saf_vital], [eff_resp],
#'   [demo-data]
#'
#' @examples
#' head(saf_demo)
#' attr(saf_demo, "n")
"saf_demo"

#' Overall AE summary, Safety Population
#'
#' Pre-summarised AE overview, one row per high-level flag (Any TEAE,
#' Serious AE, Related, plus per-severity counts). Each cell carries
#' `n (%)` as a pre-formatted string. The smallest of the five demo
#' datasets -- ideal for first-look [tb_table()] examples.
#'
#' @format A data frame.
#' \describe{
#'   \item{`stat_label`}{*character* -- displayed row label
#'     (e.g. `"Any TEAE"`, `"Any Serious AE (SAE)"`).}
#'   \item{`placebo`,`drug_50`,`drug_100`,`Total`}{*character* -- cell
#'     text per arm; `n (%)` for the flag.}
#' }
#'
#' BigN as `attr(saf_aeoverall, "n")`.
#'
#' @source Built from `pharmaverseadam::adae` filtered to
#'   `TRTEMFL == "Y"` and Safety Population. Each flag row counts
#'   distinct subjects (one per subject per flag); the per-severity
#'   rows count distinct subjects at their maximum reported severity.
#' @family demo-data
#' @seealso [saf_demo], [saf_aesocpt], [saf_vital], [eff_resp],
#'   [demo-data]
#'
#' @examples
#' saf_aeoverall
#' attr(saf_aeoverall, "n")
"saf_aeoverall"

#' AEs by SOC and PT, Safety Population
#'
#' Two-level nested AE summary -- one SOC header row followed by its PT
#' rows, repeated per System Organ Class. Shaped to exercise
#' [tb_spans()] (spanning column headers) and [tb_rows()] with
#' `group_by = "soc"` + `indent_by = "pt"`. Limited to the top SOCs and
#' top PTs per SOC to keep the dataset under 50 KB.
#'
#' @format A data frame.
#' \describe{
#'   \item{`soc`}{*character* -- System Organ Class label; repeats
#'     across each SOC's header and its PT rows.}
#'   \item{`pt`}{*character* -- Preferred Term; equal to `soc` on the
#'     SOC header row.}
#'   \item{`row_type`}{*character* -- one of `"overall"`, `"soc"`,
#'     `"pt"`; used to drive [tb_styles()] (`bold = TRUE` for
#'     `"overall"` / `"soc"`).}
#'   \item{`placebo`,`drug_50`,`drug_100`,`Total`}{*character* -- cell
#'     text per arm; `n (%)`.}
#' }
#'
#' @source Built from `pharmaverseadam::adae` filtered to
#'   `TRTEMFL == "Y"`. Each SOC row counts distinct subjects per SOC;
#'   each PT row counts distinct subjects per SOC/PT. Limited to the
#'   top 5 SOCs by subject count and top 3 PTs per SOC.
#' @family demo-data
#' @seealso [saf_demo], [saf_aeoverall], [saf_vital], [eff_resp],
#'   [demo-data]
#'
#' @examples
#' head(saf_aesocpt, 8)
#' table(saf_aesocpt$row_type)
"saf_aesocpt"

#' Vital-signs summary, Safety Population
#'
#' Continuous-stat vital-signs summary -- `n / Mean (SD) / Median /
#' Min, Max` per parameter, visit, and arm. Shaped to exercise decimal
#' alignment across mixed-format cells and multi-key grouping
#' (`group_by = c("param", "visit")`). Limited to four parameters
#' (SYSBP, DIABP, PULSE, TEMP) and two visits (Baseline, End of
#' Treatment).
#'
#' @format A data frame.
#' \describe{
#'   \item{`paramcd`}{*character* -- parameter code (`"SYSBP"`,
#'     `"DIABP"`, `"PULSE"`, `"TEMP"`).}
#'   \item{`param`}{*character* -- parameter label
#'     (e.g. `"Systolic Blood Pressure (mmHg)"`).}
#'   \item{`visit`}{*character* -- visit label
#'     (`"Baseline"`, `"End of Treatment"`).}
#'   \item{`stat_label`}{*character* -- displayed stat row
#'     (`"n"`, `"Mean (SD)"`, `"Median"`, `"Min, Max"`).}
#'   \item{`placebo`,`drug_50`,`drug_100`}{*character* -- cell text
#'     per arm.}
#' }
#'
#' @source Built from `pharmaverseadam::advs` filtered to safety pop,
#'   PARAMCD in {SYSBP, DIABP, PULSE, TEMP}, AVISIT in {Baseline,
#'   End of Treatment}. AVAL summarised to `n / Mean (SD) / Median /
#'   Min, Max` per parameter, visit, and arm.
#' @family demo-data
#' @seealso [saf_demo], [saf_aeoverall], [saf_aesocpt], [eff_resp],
#'   [demo-data]
#'
#' @examples
#' head(saf_vital)
#' unique(saf_vital$paramcd)
"saf_vital"

#' Best Overall Response + ORR / DCR
#'
#' Efficacy table: per-arm counts for each BOR category (CR, PR, SD,
#' NON-CR/NON-PD, PD, NE, MISSING), followed by two derived rows
#' (Objective Response Rate, Disease Control Rate). Demonstrates the
#' derived-row pattern -- categories vs. derived rates marked via
#' `row_type`.
#'
#' @format A data frame.
#' \describe{
#'   \item{`stat_label`}{*character* -- response category or derived
#'     rate label.}
#'   \item{`row_type`}{*character* -- `"category"` for raw response
#'     counts, `"derived"` for ORR / DCR.}
#'   \item{`placebo`,`drug_50`,`drug_100`}{*character* -- cell text
#'     per arm; `n (%)`.}
#' }
#'
#' @source Built from `pharmaverseadam::adrs_onco` filtered to
#'   `PARAMCD == "BOR"`. Per-arm `n (%)` for each BOR category
#'   (denominator: total BOR-evaluable subjects per arm), plus two
#'   derived rates: ORR = CR + PR, DCR = CR + PR + SD + NON-CR/NON-PD.
#' @family demo-data
#' @seealso [saf_demo], [saf_aeoverall], [saf_aesocpt], [saf_vital],
#'   [demo-data]
#'
#' @examples
#' eff_resp
#' eff_resp[eff_resp$row_type == "derived", ]
"eff_resp"
