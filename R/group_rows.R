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
#' `group_rows()` names the **structural** columns whose runs of
#' identical values define the table's row hierarchy, ordered outer to
#' inner. List only the keys that drive the structure — the section
#' headers and any hidden break keys; the visible row-label column
#' (e.g. the statistic stub) stays an ordinary [`cols()`] column and is
#' indented automatically. It is the row-structure counterpart of
#' [`sort_rows()`]: one declaration per table, replaced wholesale on
#' a repeat call.
#'
#' @details
#' **One plan per table.** A second `group_rows()` call replaces the
#' first (the [`sort_rows()`] contract); levels never accumulate
#' across calls.
#'
#' **Structural keys only.** Nesting is just listing the header keys:
#' `by = c("param", "visit")` renders `param` as the outer section
#' header and `visit` as the indented sub-header, and the first visible
#' column beneath (the label stub) is auto-indented one level per
#' header. You do not put the label column in `by`.
#'
#' **Break-only keys use `visible = FALSE`.** A key you mark
#' `col_spec(visible = FALSE)` renders nothing and contributes only
#' group transitions — the blank spacer between blocks (`skip`) and the
#' decimal-alignment reset — exactly what a hidden sort/break key needs.
#' There is no separate display mode for it.
#'
#' @param .spec *The `tabular_spec` to attach the grouping plan to.*
#'   `<tabular_spec>: required`.
#'
#' @param by *Structural grouping key columns, ordered outer to inner.*
#'   `<character>: required`. Names at least one column of `data`;
#'   duplicates are rejected. List only the section-header and
#'   break-only keys, not the visible label column.
#'
#'   **Interaction:** A [`subgroup()`]`(by = )` partition column may
#'   also be a grouping key; within each partition the key is
#'   constant and auto-hidden, so the combination composes.
#'
#' @param display *How the keys' values render in the body.*
#'   `<character(1)>: default "section"`. One value, applied to
#'   every key:
#'
#'   * `"section"` (default) — each unique value emits a section
#'     header row spanning the visible columns; the key column is
#'     hidden from the body. The canonical submission shape.
#'   * `"collapse"` — the key column stays visible; repeated values
#'     are suppressed so only the first row of each run shows the
#'     label. The classic listing shape.
#'   * `"repeat"` — the key column stays visible and every row
#'     repeats the value. The export / QC shape, where every row must
#'     be self-describing.
#'
#'   **Tip:** for a hidden break-only key, set `col_spec(visible =
#'   FALSE)` on it rather than a display mode.
#'
#' @param skip *Which keys get a blank spacer row between their
#'   groups.* `<TRUE | FALSE | character>: default TRUE`. A logical
#'   flag or an explicit character set (the `readr::read_csv(col_names
#'   = )` pattern):
#'
#'   * `TRUE` (default) — derive: a `"section"` key or a break-only
#'     (`visible = FALSE`) key breaks with a blank line; a visible
#'     `"collapse"` / `"repeat"` key runs continuous.
#'   * `FALSE` — no spacer rows anywhere.
#'   * `<character>` — exactly these `by` keys break, e.g. `skip =
#'     "param"` (blank line between params, none between visits).
#'     Every name must be in `by`; `character(0)` is equivalent to
#'     `FALSE`.
#'
#' @return *`<tabular_spec>`.* A new spec with `@row_groups` replaced;
#'   pipe into the remaining build verbs or [`emit()`].
#'
#' @examples
#' # ---- Example 1: Demographics with section headers and a stat column ----
#' #
#' # The canonical demographics shape: `variable` is the one structural
#' # key. The defaults do all the work -- `display = "section"` renders
#' # one section header row per parameter (Age, Sex, ...) and hides the
#' # key column; `skip = TRUE` derives a blank spacer between sections.
#' # `stat_label` is NOT a grouping key -- it stays an ordinary column
#' # and is auto-indented one level under each section header.
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
#'   group_rows(by = "variable")
#'
#' # ---- Example 2: Nested parameter / visit with a hidden break key ----
#' #
#' # `param` and `visit` nest as section headers (outer then indented
#' # sub-header) just by listing both -- no per-key modes. `paramcd`
#' # never renders: col_spec(visible = FALSE) makes it a break-only key
#' # whose transitions reset the decimal-alignment sections. `skip =
#' # "param"` puts a blank line between parameters but not between
#' # visits within a parameter.
#' tabular(cdisc_saf_vital, titles = "Vital Signs by Parameter and Visit") |>
#'   cols(
#'     paramcd = col_spec(visible = FALSE),
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
#'   group_rows(by = c("param", "visit"), skip = "param")
#'
#' # ---- Example 3: Listing shape with a visible, collapsed key column ----
#' #
#' # The same vitals data as a continuous listing: `display = "collapse"`
#' # keeps `param` and `visit` as visible columns and suppresses repeated
#' # values, so only the first row of each run shows the label; `skip =
#' # FALSE` removes every blank spacer. Use `display = "repeat"` instead
#' # to print the value on every row -- the export / QC shape.
#' tabular(cdisc_saf_vital, titles = "Vital Signs Listing") |>
#'   cols(
#'     paramcd = col_spec(visible = FALSE),
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
#'   group_rows(by = c("param", "visit"), display = "collapse", skip = FALSE)
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
group_rows <- function(.spec, by, display = "section", skip = TRUE) {
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
  modes <- .col_group_display_values
  if (
    !is.character(display) ||
      length(display) != 1L ||
      anyNA(display) ||
      !nzchar(display)
  ) {
    cli::cli_abort(
      c(
        "{.arg display} must be a single string, one of {.val {modes}}.",
        "x" = "You supplied {.obj_type_friendly {display}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!display %in% modes) {
    cli::cli_abort(
      c(
        "{.arg display} must be one of {.val {modes}}.",
        "x" = "You supplied {.val {display}}.",
        "i" = "For a hidden break-only key use {.code col_spec(visible = FALSE)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  display <- rep(display, length(by))

  # `skip` follows the readr `col_names` pattern: TRUE derives (the NA
  # sentinel per key, resolved at engine time from display + column
  # visibility -- break-only status is not knowable here because
  # cols(visible = FALSE) may be declared after this verb); FALSE
  # inserts no spacers; a character vector is the explicit set of
  # skipping keys, so unnamed keys do NOT skip.
  if (rlang::is_bool(skip)) {
    skip_vec <- if (skip) rep(NA, length(by)) else rep(FALSE, length(by))
  } else if (is.character(skip)) {
    check_chr(skip, call = call)
    bad_skip <- setdiff(skip, by)
    if (length(bad_skip) > 0L) {
      cli::cli_abort(
        c(
          "{.arg skip} must name columns listed in {.arg by}.",
          "x" = "Not in {.arg by}: {.val {bad_skip}}.",
          "i" = "Grouping keys: {.val {by}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    skip_vec <- by %in% skip
  } else {
    cli::cli_abort(
      c(
        "{.arg skip} must be TRUE, FALSE, or a character vector of {.arg by} keys.",
        "x" = "You supplied {.obj_type_friendly {skip}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  new_groups <- row_group_spec(by = by, display = display, skip = skip_vec)
  S7::set_props(.spec, row_groups = new_groups)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Effective per-key skip: resolve the NA "derive" sentinel. A
# "section" key or a break-only (visible = FALSE) key reads with a
# blank line between blocks by default; the visible column modes run
# continuous. `break_keys` is the set of break-only grouping keys
# (resolved from column visibility by the caller, which knows @cols).
.effective_row_group_skip <- function(row_groups, break_keys = character()) {
  skip <- row_groups@skip
  follows <- is.na(skip)
  derived <- row_groups@display == "section" |
    row_groups@by %in% break_keys
  skip[follows] <- derived[follows]
  skip
}

# Break-only grouping keys: keys the user marked col_spec(visible =
# FALSE). They render nothing, contributing only group transitions
# (skip spacers, decimal sections). Resolved from @cols visibility,
# replacing the former display = "none" mode.
.row_group_break_keys <- function(row_groups, cols) {
  if (is.null(row_groups) || length(row_groups@by) == 0L) {
    return(character())
  }
  by <- row_groups@by
  is_break <- vapply(
    by,
    function(nm) {
      cs <- cols[[nm]]
      is_col_spec(cs) && isFALSE(cs@visible)
    },
    logical(1L)
  )
  by[is_break]
}

# The grouping keys the plan pulls out of the body into synthesised
# section-header rows: the "section" keys. Break-only (visible =
# FALSE) keys are already excluded by the normal visibility check at
# the call site, so they need no entry here.
.row_group_hidden_keys <- function(row_groups) {
  if (is.null(row_groups)) {
    return(character())
  }
  row_groups@by[row_groups@display == "section"]
}

# The grouping keys that join the default panel stub: every key that is
# not break-only (a break-only key is hidden and never repeats). Header
# keys ride each panel via their section rows anyway.
.row_group_stub_keys <- function(row_groups, cols) {
  if (is.null(row_groups)) {
    return(character())
  }
  setdiff(row_groups@by, .row_group_break_keys(row_groups, cols))
}
