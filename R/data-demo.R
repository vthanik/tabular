#' Demo datasets bundled with tabular
#'
#' Five small, pre-summarised wide-format datasets used as the canonical
#' inputs for every roxygen `@examples` block, vignette, and test in
#' `tabular`. The values are derived from `pharmaverseadam` (synthetic
#' CDISC Pilot 03 data) via `data-raw/bundle-demo.R`; they are not real
#' patient data. Each dataset is shaped to exercise a different cluster
#' of verbs.
#'
#' @details
#' ## Lazy-loaded datasets
#'
#' Available directly after `library(tabular)`:
#'
#' | Object | What it represents | Verbs exercised |
#' |--------|--------------------|-----------------|
#' | [saf_demo] | Demographics, Safety Pop | [tb_table], [tb_cols], [tb_rows] (95% case) |
#' | [saf_aeoverall] | High-level AE flags | [tb_table] minimal first-look |
#' | [saf_aesocpt] | AEs by SOC and PT | [tb_spans] + [tb_rows] page_by/indent_by |
#' | [saf_vital] | Vital signs at 2 visits | decimal alignment + multi-key group_by |
#' | [eff_resp] | BOR + derived ORR/DCR | derived rows, response taxonomies |
#'
#' ## Shared conventions
#'
#' All five share these column / attribute conventions so the demo
#' programs in `@examples` blocks read uniformly:
#'
#' * Arm columns named `placebo`, `drug_50`, `drug_100`; `Total` where
#'   applicable.
#' * `attr(x, "n")` is a named integer vector of BigN per arm
#'   (e.g. `c(placebo = 86L, drug_50 = 84L, drug_100 = 89L, Total = 259L)`).
#'
#' @source Pre-summarised, illustrative values built by
#'   `data-raw/bundle-demo.R` from `pharmaverseadam::adsl` /
#'   `::adae` / `::advs` / `::adrs_onco`. See the individual dataset
#'   topics for the specific filters and summary statistics applied.
#'
#' @seealso [saf_demo], [saf_aeoverall], [saf_aesocpt], [saf_vital],
#'   [eff_resp]
#' @family demo-data
#'
#' @examples
#' # All five datasets are available immediately after library(tabular)
#' head(saf_demo)
#' attr(saf_demo, "n")
#'
#' # Each is shaped for a specific verb scenario
#' nrow(saf_aeoverall)   # ~8 rows -- simple
#' nrow(saf_aesocpt)     # ~20 rows -- nested SOC/PT
#'
#' @name demo-data
NULL
