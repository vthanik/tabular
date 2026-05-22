# sort_rows.R — attach a sort_spec to a tabular_spec. Sorting is
# applied at engine time; the verb only stores the spec. A repeat
# call replaces the prior sort — sort is a single spec, not a
# stackable list.

#' Sort the display rows
#'
#' Attach a `sort_spec` to a `tabular_spec`. The engine applies the
#' sort after `derive()` runs and before pagination, so `by` may
#' reference any column in `spec@data` (or a column added later via
#' `derive()`), regardless of whether it appears in `cols()`.
#'
#' A second `sort_rows()` call REPLACES the prior sort — sort is a
#' single spec on the parent `tabular_spec`, not a stackable list.
#' Pass length-1 `descending` to apply one direction to every key;
#' pass length `length(by)` to set per-key directions.
#'
#' NA values in a sort key are placed at the end regardless of
#' direction. Factor columns sort by factor levels, not by the
#' character label — this is how clinical conventions like the
#' BOR ordering (`CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING`)
#' survive a tabular pipeline without an explicit `mutate()`.
#'
#' @param spec A `tabular_spec` built by `tabular()`.
#' @param by Character vector of column names to sort by, in order
#'   of precedence. May reference columns not present in `cols()`
#'   (sort-only columns ride along through the engine for ordering
#'   even when they will not be displayed). Length 0 is accepted
#'   and produces a no-op sort.
#' @param descending Logical. Length 1 (recycled to `length(by)`)
#'   or length equal to `by`. `TRUE` sorts the corresponding key
#'   in descending order. Defaults to `FALSE` (ascending on all
#'   keys).
#' @return The updated `tabular_spec`.
#'
#' @examples
#' # 95% clinical pattern: AE-by-SOC/PT table arranged so the
#' # SOCs and PTs with the highest subject counts appear first,
#' # with the SOC → PT hierarchy preserved. saf_aesocpt$Total
#' # cells are formatted text ("171 (67.3)"), so a lexical sort
#' # on Total would be wrong ("14" < "171" < "29") — attach a
#' # numeric rank column upstream and sort on (row_type, n_total).
#' # Complete pipeline through every landed verb: tabular() entry
#' # with TFL number and population qualifier, cols() with BigN
#' # joined inline from saf_n, sort_rows() as the focal verb.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = c(
#'     "Subjects are counted once per SOC and once per PT.",
#'     "Percentages based on N per treatment group."
#'   )
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "System Organ Class /\nPreferred Term"),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(
#'     by = c("row_type", "n_total"),
#'     descending = c(FALSE, TRUE)
#'   )
#'
#' # 95% clinical pattern: efficacy BOR table in CDISC response
#' # order (CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING,
#' # with derived ORR / DCR rows after). eff_resp$stat_label
#' # arrives as character, so coerce it to a factor carrying the
#' # canonical level order; sort_rows() then uses those levels
#' # instead of alphabetic order. Complete pipeline with the
#' # efficacy BigN denominator joined inline from eff_n.
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
#'   ),
#'   footnotes = "Response per RECIST 1.1, investigator assessment."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Response"),
#'     row_type   = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"]),  align = "decimal"),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"]),  align = "decimal"),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]), align = "decimal")
#'   ) |>
#'   sort_rows(by = "stat_label")
#'
#' @export
sort_rows <- function(spec, by = character(), descending = FALSE) {
  call <- rlang::caller_env()
  check_tabular_spec(spec, call = call)
  check_chr(by, call = call)
  check_lgl(descending, call = call)

  if (length(by) > 0L) {
    data_cols <- names(spec@data)
    missing <- setdiff(by, data_cols)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "{.arg by} references {length(missing)} column{?s} not in {.arg data}.",
          "x" = "Missing: {.val {missing}}.",
          "i" = "Available: {.val {data_cols}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }

    across_cols <- .across_col_names(spec@cols)
    bad_across <- intersect(by, across_cols)
    if (length(bad_across) > 0L) {
      cli::cli_abort(
        c(
          "{.arg by} cannot reference {length(bad_across)} {.code usage = \"across\"} column{?s}.",
          "x" = "Offending: {.val {bad_across}}.",
          "i" = "Across columns pivot into header bands; sort upstream of the pivot."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  if (length(descending) == 1L) {
    descending <- rep(descending, length(by))
  } else if (length(descending) != length(by)) {
    cli::cli_abort(
      c(
        "{.arg descending} must be length 1 or length {length(by)} (= length of {.arg by}).",
        "x" = "You supplied length {length(descending)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  new_sort <- sort_spec(by = by, descending = descending)
  S7::set_props(spec, sort = new_sort)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

.across_col_names <- function(cols) {
  if (length(cols) == 0L) {
    return(character())
  }
  is_across <- vapply(
    cols,
    function(c) !is.na(c@usage) && c@usage == "across",
    logical(1)
  )
  names(cols)[is_across]
}
