# sort_rows.R — attach a sort_spec to a tabular_spec. Sorting is
# applied at engine time; the verb only stores the spec. A repeat
# call replaces the prior sort — sort is a single spec, not a
# stackable list.

#' Sort the display rows
#'
#' Attach a `sort_spec` to a `tabular_spec`. The engine applies the
#' sort before pagination, so `by` may reference any column in
#' `spec@data` whether or not the column is declared in [`cols()`].
#'
#' @details
#'
#' **Replace, not stack.** A second `sort_rows()` call REPLACES the
#' prior sort — sort is a single spec, not a stackable list. Call
#' with no arguments to clear.
#'
#' **NA last, regardless of direction.** NA values in a sort key are
#' placed at the end whether the key is ascending or descending
#' (matching `order(..., na.last = TRUE)`).
#'
#' **Factor levels drive the order.** Factor columns sort by factor
#' levels, not by the character label. The CDISC BOR ordering
#' (`CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING`) survives a
#' tabular pipeline without an explicit `mutate()` — coerce
#' `stat_label` to a factor with the levels in clinical order
#' upstream, then `sort_rows(by = "stat_label")` does the rest.
#'
#' @param .spec *The `tabular_spec` to attach the sort to.*
#'   `<tabular_spec>: required`.
#'
#' @param by *Ordered column names to sort by, in precedence order.*
#'   `<character>: default character()`. Length 0 is accepted (no-op
#'   sort). May reference columns not declared in [`cols()`] —
#'   sort-only helper columns ride along through the engine.
#'
#'   **Restriction:** Every entry must be a column in `spec@data`.
#'   Cannot reference arm columns produced by [`pivot_across()`];
#'   pivot upstream of the sort instead. Arm cells hold rendered
#'   stat strings (e.g. `"75.2 (8.3)"`) that do not order
#'   meaningfully.
#'
#'   ```r
#'   # Two-key clinical sort: row_type ascending, n_total descending.
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'   ```
#'
#' @param descending *Per-key sort direction.*
#'   `<logical(1) | logical(length(by))>: default FALSE`. `TRUE`
#'   sorts the corresponding key descending; length 1 recycles to
#'   every key.
#'
#'   **Restriction:** No NAs. Length must be 1 or `length(by)`.
#'   **Tip:** For mixed-direction multi-key sorts, pass `length(by)`
#'   values; the engine inverts the `xtfrm` rank of each descending
#'   key and calls `order()` once on all keys.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`style()`], [`paginate()`], [`preset()`], then render via
#'   [`emit()`] (or resolve without I/O via [`as_grid()`]).
#'
#' @examples
#' # ---- Example 1: AE table sorted by SOC, then by descending subject count ----
#' #
#' # AE-by-SOC/PT table where the SOCs and PTs appear in descending
#' # order of subject count within the row-type hierarchy (overall
#' # first, then SOCs, then PTs). `saf_aesocpt$Total` cells are
#' # formatted text ("171 (67.3)"), so a lexical sort on `Total`
#' # would be wrong ("14" < "171" < "29") — attach a numeric rank
#' # column upstream and sort on (row_type, n_total).
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
#'     "Safety Population"
#'   ),
#'   footnotes = "Subjects are counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' # ---- Example 2: BOR table in CDISC factor order ----
#' #
#' # Efficacy BOR table that must appear in CDISC clinical order
#' # (CR < PR < SD < NON-CR/NON-PD < PD < NE < MISSING), then the
#' # derived ORR / CBR / DCR rate rows ordered by `groupid`,
#' # not alphabetical. `eff_resp$stat_label` arrives as character, so
#' # coerce to a factor with the canonical levels upstream and
#' # `sort_rows()` uses those levels directly.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "ORR (CR + PR)", "CBR (CR + PR + SD)",
#'   "DCR (CR + PR + SD + NON-CR/NON-PD)", "95% CI (Clopper-Pearson)"
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
#'     "Efficacy Evaluable Population"
#'   ),
#'   footnotes = "Response per RECIST 1.1, investigator assessment."
#' ) |>
#'   cols(
#'     stat_label  = col_spec(label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
#'   ) |>
#'   sort_rows(by = c("groupid", "stat_label"))
#'
#' # ---- Example 3: Mixed-direction multi-key sort with hidden helper ----
#' #
#' # Demographics-style table sorted by `variable` ascending and a
#' # hidden numeric key descending. The `descending` argument takes
#' # one value per `by` entry so each key can flip direction
#' # independently. The helper column rides in `spec@data` for the
#' # sort but never renders (visible = FALSE on its col_spec).
#' demo <- saf_demo
#' demo$display_order <- match(demo$variable, unique(demo$variable))
#'
#' tabular(demo, titles = "Demographics, ranked within section") |>
#'   cols(
#'     variable      = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label    = col_spec(label = "Statistic"),
#'     display_order = col_spec(visible = FALSE),
#'     placebo       = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50       = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100      = col_spec(label = "Drug 100", align = "decimal"),
#'     Total         = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   sort_rows(
#'     by         = c("display_order", "stat_label"),
#'     descending = c(FALSE, TRUE)
#'   )
#'
#' # ---- Example 4: Hierarchical SOC -> PT sort with factor outer key ----
#' #
#' # A factor outer key locks the SOC display order to the canonical
#' # interleaved sequence (`overall` first, then `soc` blocks, then
#' # `pt` detail rows inside each SOC) regardless of input order. The
#' # numeric inner key sorts PTs within each SOC by descending total
#' # subject count.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total  <- as.integer(sub(" .*", "", ae$Total))
#' tabular(ae, titles = "AE by SOC and PT, ranked within SOC") |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100", align = "decimal"),
#'     Total    = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   sort_rows(
#'     by         = c("row_type", "soc", "n_total"),
#'     descending = c(FALSE, FALSE, TRUE)
#'   )
#'
#' @seealso
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`style()`], [`paginate()`], [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
sort_rows <- function(.spec, by = character(), descending = FALSE) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  check_chr(by, call = call)
  check_lgl(descending, call = call)

  if (length(by) > 0L) {
    data_cols <- names(.spec@data)
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

    across_cols <- .across_col_names(.spec@data)
    bad_across <- intersect(by, across_cols)
    if (length(bad_across) > 0L) {
      cli::cli_abort(
        c(
          "{.arg by} cannot reference {length(bad_across)} arm column{?s} produced by {.fn pivot_across}.",
          "x" = "Offending: {.val {bad_across}}.",
          "i" = "Arm cells hold rendered stat strings; sort upstream of the pivot."
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
  S7::set_props(.spec, sort = new_sort)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Return the names of arm columns produced by `pivot_across()`.
# The reshaper stamps `attr(data, "across_cols")` on its return value;
# sort_rows() reads that attribute to reject sort keys whose cells
# hold rendered stat strings (e.g. "75.2 (8.3)"). NULL when the data
# did not pass through pivot_across().
.across_col_names <- function(data) {
  out <- attr(data, "across_cols", exact = TRUE)
  if (is.null(out)) {
    return(character())
  }
  as.character(out)
}
