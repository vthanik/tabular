# tabular.R — entry verb. Wraps an input data.frame, titles, and
# footnotes into a tabular_spec. Subsequent verbs (cols, headers,
# sort_rows, ...) attach configuration to the returned spec.

#' Start a tabular display
#'
#' Wrap a pre-summarised data frame into a `tabular_spec` ready for
#' the verb chain. `tabular()` is the entry verb — it owns the
#' `data`, `titles`, and `footnotes` slots; every downstream verb
#' ([`cols()`], [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`]) returns an updated
#' spec for further chaining, terminating in [`emit()`] (write to
#' file) or [`as_grid()`] (resolve without writing).
#'
#' @details
#'
#' **Pre-summarised input contract.** `data` is one row per displayed
#' row of the final table. `tabular()` does not aggregate, filter,
#' weight, or generate subtotal rows — those happen upstream in
#' `cards`, `dplyr`, or SAS. If the upstream is a long
#' `cards::ard_stack()` ARD, pipe through [`pivot_across()`] first
#' to land in the wide shape `tabular()` accepts.
#'
#' **Multi-line titles and footnotes by contract.** Clinical tables
#' routinely carry 2-4 title rows and 1-4 user footnote rows. Pass
#' each row as one element of the character vector; the backend
#' renders each element on its own line, collapsing unused rows so
#' the column-header band sits flush against the lowest used title.
#'
#' @param data *The display rows.*
#'   `<data.frame>: required`. Pre-summarised wide-format data;
#'   tibbles, data.tables, and arrow tables are coerced via
#'   `as.data.frame()`. Factor columns are preserved (their levels
#'   drive [`sort_rows()`]).
#'
#'   **Restriction:** At least one column; column names must be
#'   unique. Zero rows is accepted (engine renders a "No data" stub).
#'   **Interaction:** The `cards`-format counterparts
#'   (`cdisc_saf_demo_ard`, `cdisc_saf_aesocpt_ard`) are NOT accepted directly;
#'   pipe through [`pivot_across()`] first.
#'
#' @param titles *Page-title block, one element per row.*
#'   `<character> | NULL: default NULL`. Each element renders on
#'   its own centred line; embedded `\n` wraps within that row. The
#'   backend collapses unused rows so the column-header band sits
#'   flush against the lowest used title.
#'
#'   **Restriction:** No NAs.
#'
#'   Each element supports glue-style `{expr}` interpolation: braces
#'   are evaluated as R code in the calling environment at build time,
#'   e.g. `"N total = {sum(n)}"`. Double a brace (`{{` or `}}`) for a
#'   literal one. An `md()` / `html()` element is passed through
#'   without interpolation.
#'
#'   ```r
#'   # Canonical 3-line title block with BigN-qualified population.
#'   n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     "Safety Population"
#'   )
#'   ```
#'
#' @param footnotes *Page-footnote block, one element per row.*
#'   `<character> | NULL: default NULL`. User-supplied prose rows
#'   only; the backend appends its own program-path / program-name /
#'   timestamp band below them at render time.
#'
#'   **Restriction:** No NAs.
#'
#'   Each element supports glue-style `{expr}` interpolation (see
#'   `titles`).
#'
#'   ```r
#'   # Canonical 3-line footnote block.
#'   footnotes = c(
#'     "Subjects are counted once per SOC and once per PT.",
#'     "Percentages based on N per treatment group.",
#'     "TEAE = treatment-emergent adverse event."
#'   )
#'   ```
#'
#' @param empty_text *Placeholder shown when `data` has zero rows.*
#'   `<character(1)>: default "No data available to report"`. When the
#'   display resolves to no data rows, the backends still emit the full
#'   page chrome and — when a column structure is present — the column
#'   headers, then place this message in the body where the rows would
#'   sit. Override it with any sponsor or study wording (a localized
#'   string, "No subjects met the criteria for this table.", a
#'   protocol-qualified line); glue `{expr}` interpolation and `md()` /
#'   `html()` are honoured, exactly like a title line.
#'
#'   **Interaction:** placement within the body box is cosmetic and lives
#'   on the preset, `preset(empty_halign = ..., empty_valign = ...)`,
#'   defaulting to centre x middle.
#'
#' @return *A `tabular_spec` S7 object.* Pipe it into [`cols()`],
#'   [`headers()`], [`sort_rows()`], [`style()`],
#'   [`paginate()`], and [`preset()`] to build the display, then
#'   into [`emit()`] to render or [`as_grid()`] to resolve without
#'   writing.
#'
#' @examples
#' # ---- Example 1: Adverse-event table by SOC and Preferred Term ----
#' #
#' # The regulatory work-horse layout: AE-by-SOC/PT with the
#' # canonical 3-line title block (table number, description,
#' # population qualifier with BigN drawn inline from `cdisc_saf_n`) and a
#' # two-line footnote block explaining the denominator. The
#' # downstream pipeline hides the hierarchy markers (`row_type`,
#' # `soc_n`, `n_total`) but keeps them in the data so `sort_rows()`
#' # can arrange SOCs and PTs in descending order of subject count.
#' # The dataset already ships `n_total` and `soc_n`; here we slice to
#' # the overall row plus the two highest-incidence SOCs to keep the
#' # preview compact.
#' ae <- cdisc_saf_aesocpt
#' keep_soc <- head(unique(ae$soc[ae$row_type == "soc"]), 2L)
#' ae <- ae[ae$row_type == "overall" | ae$soc %in% keep_soc, ]
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     "Safety Population"
#'   ),
#'   footnotes = c(
#'     "Subjects are counted once per SOC and once per PT.",
#'     "Percentages based on N per treatment group."
#'   )
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}")
#'   ) |>
#'   sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))
#'
#' # ---- Example 2: Best overall response with CDISC factor ordering ----
#' #
#' # Efficacy table where response categories must appear in CDISC
#' # clinical order (CR < PR < SD < NON-CR/NON-PD < PD < NE <
#' # MISSING), then the derived ORR / CBR / DCR rate rows, not
#' # alphabetical. `groupid` keeps the four sections ordered while the
#' # `stat_label` factor orders the response block; `sort_rows()` does
#' # both in one pass. `groupid` / `group_label` ride along hidden.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "ORR (CR + PR)", "CBR (CR + PR + SD)",
#'   "DCR (CR + PR + SD + NON-CR/NON-PD)", "95% CI (Clopper-Pearson)"
#' )
#' eff <- cdisc_eff_resp
#' eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
#' ne <- stats::setNames(cdisc_eff_n$n, cdisc_eff_n$arm_short)
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
#'     placebo     = col_spec(label = "Placebo\nN={ne['placebo']}"),
#'     drug_50     = col_spec(label = "Drug 50\nN={ne['drug_50']}"),
#'     drug_100    = col_spec(label = "Drug 100\nN={ne['drug_100']}")
#'   ) |>
#'   sort_rows(by = c("groupid", "stat_label"))
#'
#' # ---- Example 3: Minimal three-line BigN table from cdisc_saf_n ----
#' #
#' # The smallest viable `tabular()` call: the bundled `cdisc_saf_n` 4-row
#' # BigN table, a single-line title, no footnotes. The default
#' # `col_spec` per column kicks in, giving sensible labels (the
#' # data frame's column names) and left-aligned text. Useful when
#' # teaching the core API shape without the clinical-context
#' # surface noise.
#' tabular(cdisc_saf_n, titles = "Safety-population BigN per arm")
#'
#' # ---- Example 4: Nested vital-signs panel — two group levels ----
#' #
#' # The canonical by-visit vitals shape: each `param` nests its
#' # `visit` blocks, and each visit nests the statistic rows. Two
#' # columns carry `usage = "group"` (`param` then `visit`), so the
#' # engine renders two levels of nested section headers above the
#' # `stat_label` stub. The CDISC `paramcd` rides along as the natural
#' # sort key but hides at render via `col_spec(visible = FALSE)`.
#' # Sliced to the two blood-pressure parameters for a compact preview;
#' # the full 4-parameter frame nests the same way.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' vs <- cdisc_saf_vital[cdisc_saf_vital$paramcd %in% c("DIABP", "SYSBP"), ]
#' tabular(
#'   vs,
#'   titles = c(
#'     "Table 14.4.1",
#'     "Summary of Vital Signs",
#'     "Safety Population"
#'   ),
#'   footnotes = "Statistics computed on observed cases."
#' ) |>
#'   cols(
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal"
#'     ),
#'     drug_50    = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal"
#'     ),
#'     drug_100   = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal"
#'     )
#'   )
#'
#' @seealso
#' **Downstream build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`style()`],
#' [`paginate()`], [`preset()`].
#'
#' **Terminal verbs:** [`emit()`] (write), [`as_grid()`] (resolve
#' without I/O).
#'
#' **Input helper:** [`pivot_across()`] (cards ARD -> wide).
#'
#' **Demo data:** `cdisc_saf_demo`, `cdisc_saf_aesocpt`, `cdisc_eff_resp`, `cdisc_saf_n`,
#' `cdisc_eff_n`.
#'
#' @export
tabular <- function(
  data,
  titles = NULL,
  footnotes = NULL,
  empty_text = NULL
) {
  call <- rlang::caller_env()

  data <- .normalise_data(data, call = call)
  .check_data_columns(data, call = call)

  titles_val <- .normalise_text_block(titles, arg = "titles", call = call)
  footnotes_val <- .normalise_text_block(
    footnotes,
    arg = "footnotes",
    call = call
  )

  titles_val <- .interpolate_vec(titles_val, env = call, call = call)
  footnotes_val <- .interpolate_vec(footnotes_val, env = call, call = call)

  spec <- tabular_spec(
    data = data,
    titles = titles_val,
    footnotes = footnotes_val
  )

  # empty_text NULL = inherit the slot default ("No data available to
  # report"), keeping a single source of truth. Supplied = validate,
  # interpolate like a title line, override the slot.
  if (!is.null(empty_text)) {
    empty_text_val <- .check_empty_text(empty_text, call = call)
    empty_text_val <- .interpolate_vec(
      empty_text_val,
      env = call,
      call = call
    )
    spec <- S7::set_props(spec, empty_text = empty_text_val)
  }

  spec
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

.normalise_data <- function(data, call) {
  if (is.data.frame(data)) {
    # Coerce tibble / data.table / arrow to plain data.frame so the
    # engine can assume base-R semantics everywhere.
    if (!identical(class(data), "data.frame")) {
      data <- as.data.frame(data, stringsAsFactors = FALSE)
    }
    return(data)
  }
  cli::cli_abort(
    c(
      "{.arg data} must be a data frame.",
      "x" = "You supplied {.obj_type_friendly {data}}.",
      "i" = "Pre-summarise upstream; tabular renders only."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_data_columns <- function(data, call) {
  if (ncol(data) == 0L) {
    cli::cli_abort(
      c(
        "{.arg data} must have at least one column.",
        "x" = "You supplied a data frame with 0 columns."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  nms <- names(data)
  if (anyDuplicated(nms)) {
    dups <- unique(nms[duplicated(nms)])
    cli::cli_abort(
      c(
        "{.arg data} has duplicate column names.",
        "x" = "Duplicate{?s}: {.val {dups}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(data)
}

.check_empty_text <- function(x, call) {
  # md() / html() return classed character, so is.character() is the
  # right gate (matches `.normalise_text_block`). Reject only a missing,
  # non-scalar, NA, or empty-string value.
  if (!is.character(x) || length(x) != 1L || anyNA(x) || !nzchar(x)) {
    cli::cli_abort(
      c(
        "{.arg empty_text} must be a single non-empty string.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  x
}

.normalise_text_block <- function(x, arg, call) {
  if (is.null(x)) {
    return(character())
  }
  if (is.character(x) && !anyNA(x)) {
    return(x)
  }
  if (is.character(x) && anyNA(x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must not contain {.code NA}.",
        "x" = "Found {sum(is.na(x))} NA entr{?y/ies}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a character vector or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}
