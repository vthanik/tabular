# group_rows.R — the table-level row-grouping verb.
#
# Row grouping is a row-structure fact about the whole table (which
# columns define the hierarchy, how each level renders, where the
# blank spacers go), so it is declared once here and stored as a
# row_group_spec on spec@row_groups — not smeared across per-column
# col_spec properties. The engine (engine_group_display.R) is the
# sole consumer of the plan; paginate()'s default panel stub and the
# decimal sectioning derive from it.

#' Declare the row-grouping structure of the table
#'
#' `group_rows()` names the columns whose runs of identical values
#' define the table's row hierarchy, ordered outer to inner, and how
#' each level renders — as a section header row, as a
#' repeat-suppressed column, as a fully repeated column, or as an
#' invisible break-only key. It is the row-structure counterpart of
#' [`sort_rows()`]: one declaration per table, replaced wholesale on
#' a repeat call.
#'
#' @details
#' **One plan per table.** A second `group_rows()` call replaces the
#' first (the [`sort_rows()`] contract); levels never accumulate
#' across calls.
#'
#' **Grouping drives more than display.** The keys feed the section
#' header synthesis and repeat suppression in the body, the blank
#' spacer rows between groups (`skip`), the decimal-alignment
#' sections (each skip block aligns in isolation), and the default
#' column stub repeated on every horizontal panel from
#' [`paginate()`]`(panels = )`.
#'
#' @param .spec *The `tabular_spec` to attach the grouping plan to.*
#'   `<tabular_spec>: required`.
#'
#' @param by *Grouping key columns, ordered outer to inner.*
#'   `<character(>= 1)>: required`. Every entry must be a column of
#'   `data`; duplicates are rejected.
#'
#'   **Interaction:** A [`subgroup()`]`(by = )` partition column may
#'   also be a grouping key; within each partition the key is
#'   constant and auto-hidden, so the combination composes.
#'
#' @param display *How each key's values render in the body.*
#'   `<character>: default "header_row"`. Length 1 (applied to every
#'   key) or `length(by)` (one mode per key):
#'
#'   * `"header_row"` (default) — each unique value emits a section
#'     header row spanning the visible columns; the key column is
#'     hidden from the body. The canonical submission shape.
#'   * `"column"` — the key column stays visible; repeated values are
#'     suppressed so only the first row of each run shows the label.
#'   * `"column_repeat"` — the key column stays visible and every row
#'     repeats the value.
#'   * `"none"` — break-only key: no header row, the column is
#'     hidden, and the key contributes only group transitions (skip
#'     spacers, decimal sections). Use for a hidden block key, e.g.
#'     an AE table whose SOC lives in the row text.
#'
#' @param skip *Whether a blank spacer row separates consecutive
#'   groups of each key.* `<logical>: default NA`. Length 1 or
#'   `length(by)`. `NA` follows `display`: `TRUE` for `"header_row"`
#'   and `"none"`, `FALSE` for the column modes.
#'
#' @return *`<tabular_spec>`.* A new spec with `@row_groups` replaced;
#'   pipe into the remaining build verbs or [`emit()`].
#'
#' @examples
#' # ---- Example 1: Demographics with section headers and a stat column ----
#' #
#' # The canonical demographics shape: `variable` renders as a section
#' # header row per parameter (Age, Sex, ...), and `stat_label` stays
#' # visible as a repeat-suppressed statistic column. The outer key is
#' # declared first.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   cdisc_saf_demo,
#'   titles = c("Table 14.1.1", "Demographics", "Safety Population")
#' ) |>
#'   cols(
#'     variable = "Parameter",
#'     stat_label = "Statistic",
#'     placebo = "Placebo\nN={n['placebo']}",
#'     drug_50 = "Drug 50\nN={n['drug_50']}",
#'     drug_100 = "Drug 100\nN={n['drug_100']}",
#'     Total = "Total\nN={n['Total']}"
#'   ) |>
#'   cols_apply(
#'     c("placebo", "drug_50", "drug_100", "Total"),
#'     col_spec(align = "decimal")
#'   ) |>
#'   group_rows(by = c("variable", "stat_label"), display = c("header_row", "column"))
#'
#' # ---- Example 2: Vitals with a break-only key and visible parameter ----
#' #
#' # `paramcd` never renders — display = "none" makes it a break-only
#' # key whose transitions insert the blank spacer between parameter
#' # blocks and reset the decimal-alignment sections. The visible
#' # `param` column shows each parameter once per block.
#' tabular(cdisc_saf_vital, titles = "Vital Signs by Parameter and Visit") |>
#'   cols(
#'     param = "Parameter",
#'     visit = "Visit",
#'     stat_label = "Statistic",
#'     placebo = "Placebo\nN={n['placebo']}",
#'     drug_50 = "Drug 50\nN={n['drug_50']}",
#'     drug_100 = "Drug 100\nN={n['drug_100']}"
#'   ) |>
#'   cols_apply(
#'     c("placebo", "drug_50", "drug_100"),
#'     col_spec(align = "decimal")
#'   ) |>
#'   group_rows(by = c("paramcd", "param"), display = c("none", "column"))
#'
#' @seealso
#' **Column display:** [`cols()`] / [`col_spec()`] for labels,
#' alignment, and visibility of the key columns.
#'
#' **Row order:** [`sort_rows()`] — sort so each key's runs are
#' contiguous before grouping.
#'
#' **Pagination:** [`paginate()`] — the grouping keys form the
#' default panel stub; `keep_together` protects runs across page
#' breaks independently of grouping.
#'
#' @export
group_rows <- function(.spec, by, display = "header_row", skip = NA) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  check_chr(by, call = call)

  if (length(by) == 0L) {
    cli::cli_abort(
      c(
        "{.arg by} must name at least one grouping column.",
        "i" = "Drop the {.fn group_rows} call for an ungrouped table."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
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
  dup <- unique(by[duplicated(by)])
  if (length(dup) > 0L) {
    cli::cli_abort(
      c(
        "{.arg by} must not repeat a grouping column.",
        "x" = "Duplicated: {.val {dup}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  check_chr(display, call = call)
  modes <- .col_group_display_values
  bad_display <- setdiff(display, modes)
  if (length(bad_display) > 0L) {
    cli::cli_abort(
      c(
        "{.arg display} values must be one of {.val {modes}}.",
        "x" = "You supplied: {.val {bad_display}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(display) == 1L) {
    display <- rep(display, length(by))
  } else if (length(display) != length(by)) {
    cli::cli_abort(
      c(
        "{.arg display} must be length 1 or length {length(by)} (= length of {.arg by}).",
        "x" = "You supplied length {length(display)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (!is.logical(skip)) {
    cli::cli_abort(
      c(
        "{.arg skip} must be a logical vector (TRUE / FALSE / NA).",
        "x" = "You supplied {.obj_type_friendly {skip}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(skip) == 1L) {
    skip <- rep(skip, length(by))
  } else if (length(skip) != length(by)) {
    cli::cli_abort(
      c(
        "{.arg skip} must be length 1 or length {length(by)} (= length of {.arg by}).",
        "x" = "You supplied length {length(skip)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  new_groups <- row_group_spec(by = by, display = display, skip = skip)
  S7::set_props(.spec, row_groups = new_groups)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Effective per-key skip: resolve the NA "follow display" sentinel.
# "header_row" and "none" sections read with a blank line between
# blocks by default; the column modes run continuous.
.effective_row_group_skip <- function(row_groups) {
  skip <- row_groups@skip
  follows <- is.na(skip)
  skip[follows] <- row_groups@display[follows] %in% c("header_row", "none")
  skip
}

# The grouping keys the plan hides from the body: "header_row"
# sources (their values become section header rows) and "none"
# break-only keys. The column modes stay body-visible.
.row_group_hidden_keys <- function(row_groups) {
  if (is.null(row_groups)) {
    return(character())
  }
  row_groups@by[row_groups@display %in% c("header_row", "none")]
}

# The grouping keys that join the default panel stub: every key the
# reader can see plus header_row hosts (their section rows ride each
# panel anyway); "none" keys are hidden and never repeat.
.row_group_stub_keys <- function(row_groups) {
  if (is.null(row_groups)) {
    return(character())
  }
  row_groups@by[row_groups@display != "none"]
}
