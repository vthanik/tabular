# paginate.R -- attach a pagination_spec to a tabular_spec. The verb
# stores ONLY policy knobs (which groups stay together, how many
# horizontal panels, orphan / widow floors, continuation marker). It
# does NOT take a rows-per-page argument. The engine computes the
# available row budget at render time from the active preset (paper
# size, orientation, margins, font_size) and the chrome rows
# consumed by titles, column headers, and footnotes.
#
# This mirrors galley's twips-based budget model: orientation changes
# the page height, font_size changes the row height, and titles /
# footnotes / multi-line column-header labels eat into the body
# rectangle. A repeat call REPLACES the prior spec (single-slot,
# like sort_rows() / headers()).

#' Configure pagination
#'
#' Attach a `pagination_spec` to a `tabular_spec`. The engine uses the
#' spec at render time to decide where page breaks fall, how wide
#' tables split into horizontal panels, and what continuation marker
#' (if any) prints on continued pages. The row budget per page is
#' computed by the engine from the active preset (paper, orientation,
#' margins, font size) and the chrome rows consumed by titles, column
#' headers, and footnotes -- you do not set rows-per-page directly.
#'
#' @details
#'
#' **Replace, not stack.** A second `paginate()` call REPLACES the
#' prior spec -- pagination is a single configuration block, not a
#' stackable list. Call with all defaults to clear back to the
#' engine's auto behaviour.
#'
#' **Rows per page are computed, not configured.** The engine takes
#' the paper height for the active orientation (`letter`, `a4`) and
#' subtracts the top + bottom margins, the title block height
#' (number of title lines + a blank separator), the column-header
#' band height (max embedded `\n` line count across visible column
#' labels, plus any spanning header levels), and the footnote block
#' height (number of footnote lines + a blank separator). The
#' remainder, divided by the row height for the active font size,
#' gives the body-row budget per page. Landscape pages naturally
#' carry fewer rows than portrait at the same paper size; smaller
#' fonts carry more.
#'
#' **`keep_together` protects group runs.** When a page break would
#' fall in the middle of a contiguous run of identical values in a
#' `usage = "group"` column listed in `keep_together`, the engine
#' moves the break BACK to the start of the run so the whole run
#' rides on the next page. Single rule of escape: if moving the
#' break back would leave fewer than `orphan_floor` rows on the
#' current page, the engine splits the run anyway (a single group
#' too tall to fit on one page cannot be kept together).
#'
#' **`panels` and group stickiness.** With `panels > 1`, the engine
#' splits the NON-group columns into approximately equal slices and
#' repeats every `usage = "group"` column on every panel for row
#' context. `panels = "auto"` defers the decision to preset-aware
#' width computation; until column-width metrics land (Step 13) the
#' engine treats `"auto"` as `1`.
#'
#' @param spec *The `tabular_spec` to attach pagination to.*
#'   `<tabular_spec>: required`.
#'
#' @param keep_together *Group columns whose runs of identical values
#'   must not be split across a page break.*
#'   `<character>: default character()`. Every entry must be a
#'   `usage = "group"` column declared in [`cols()`].
#'
#'   **Interaction:** A run too tall to fit in the computed row
#'   budget less `orphan_floor` is split anyway; pagination is
#'   best-effort, not a hard contract.
#'
#'   ```r
#'   # Protect the SOC-level grouping in an AE-by-SOC/PT table.
#'   paginate(keep_together = "soc")
#'   ```
#'
#' @param panels *Number of horizontal panels for wide tables.*
#'   `<integer(1) | "auto">: default 1`. With `1`, every column is on
#'   every page (single vertical scroll). With `N > 1`, the engine
#'   splits non-group columns into `N` chunks and repeats every group
#'   column on every panel.
#'
#'   **Note:** `"auto"` is accepted but treated as `1` until
#'   preset-aware column-width metrics land; once they do, `"auto"`
#'   will split when the total table width exceeds the printable
#'   area.
#'
#' @param orphan_floor *Minimum rows on a continued-from page.*
#'   `<integer(1)>: default 3`. When `keep_together` would move a
#'   page break back so far that fewer than `orphan_floor` rows would
#'   ride on the current page, the engine splits the protected run
#'   anyway. Acts as the escape valve for groups too tall to fit.
#'
#' @param widow_floor *Minimum rows on the final page.*
#'   `<integer(1)>: default 2`. If the last page would carry fewer
#'   than `widow_floor` rows, the engine merges those rows back onto
#'   the previous page (page overflow accepted). Avoids the
#'   "one-row-orphaned-on-page-N" look without complicating the
#'   primary split rule.
#'
#' @param repeat_headers *Repeat the column-header band on every
#'   continuation page.* `<logical(1)>: default TRUE`. `FALSE` shows
#'   the header band on page 1 only; submission-grade tables almost
#'   always want `TRUE`.
#'
#' @param continuation *Marker text appended after a continuing
#'   table's title block.* `<character(1) | NULL>: default NULL`.
#'   `NULL` (the default) renders no marker -- pick the wording your
#'   submission style guide expects (e.g. `"(continued)"`,
#'   `"(Cont'd)"`, `"Page %d of %d"`) and pass it explicitly.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`style()`] or hand off to the eventual `emit()`.
#'
#' @examples
#' # ---- Example 1: AE table paginated by SOC ----
#' #
#' # AE-by-SOC/PT table that may run several pages. The SOC column is
#' # protected by `keep_together` so a page break never lands in the
#' # middle of one SOC's PT rows. The engine derives the row budget
#' # from the preset's orientation + font_size + paper size and from
#' # the title / footnote / header line counts on the spec -- no
#' # manual rows-per-page knob to keep in sync.
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
#'   footnotes = "Subjects are counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "SOC / PT"),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
#'   ) |>
#'   headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   paginate(
#'     keep_together = "soc",
#'     repeat_headers = TRUE,
#'     continuation = "(continued)"
#'   )
#'
#' # ---- Example 2: Wide ACROSS-style efficacy table split across 2 panels ----
#' #
#' # BOR table where the four-arm column block is too wide for portrait
#' # paper. Split into 2 horizontal panels; the group column
#' # (`stat_label`) repeats on every panel for row context. Vertical
#' # pagination still applies, so on a tall table you would see panel A
#' # pages 1-2, then panel B pages 1-2.
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
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
#'   ) |>
#'   sort_rows(by = "stat_label") |>
#'   paginate(panels = 2, repeat_headers = TRUE)
#'
#' @seealso
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`derive()`], [`style()`].
#'
#' **Entry verb:** [`tabular()`].
#'
#' @export
paginate <- function(
  spec,
  keep_together = character(),
  panels = 1,
  orphan_floor = 3,
  widow_floor = 2,
  repeat_headers = TRUE,
  continuation = NULL
) {
  call <- rlang::caller_env()
  check_tabular_spec(spec, call = call)

  check_chr(keep_together, arg = "keep_together", call = call)
  panels_val <- .check_panels(panels, call = call)
  of <- check_pos_int(orphan_floor, arg = "orphan_floor", call = call)
  wf <- check_pos_int(widow_floor, arg = "widow_floor", call = call)
  rh <- .check_scalar_lgl(
    repeat_headers,
    arg = "repeat_headers",
    call = call
  )
  cont <- .check_continuation(continuation, call = call)

  if (length(keep_together) > 0L) {
    data_cols <- names(spec@data)
    missing <- setdiff(keep_together, data_cols)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "{.arg keep_together} references {length(missing)} column{?s} not in {.arg data}.",
          "x" = "Missing: {.val {missing}}.",
          "i" = "Available: {.val {data_cols}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    group_cols <- .group_col_names(spec@cols)
    not_group <- setdiff(keep_together, group_cols)
    if (length(not_group) > 0L) {
      cli::cli_abort(
        c(
          "{.arg keep_together} entries must be {.code usage = \"group\"} columns.",
          "x" = "Not declared as group: {.val {not_group}}.",
          "i" = "Set {.code usage = \"group\"} in {.fn cols} for the protected column(s)."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  new_pag <- pagination_spec(
    keep_together = keep_together,
    panels = panels_val,
    orphan_floor = of,
    widow_floor = wf,
    repeat_headers = rh,
    continuation = cont
  )
  S7::set_props(spec, pagination = new_pag)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Validate `panels`. Accepts a positive whole number or the literal
# string "auto". Returns the value coerced to integer or "auto".
.check_panels <- function(x, call) {
  if (is.character(x) && length(x) == 1L && !is.na(x) && x == "auto") {
    return("auto")
  }
  if (
    is.numeric(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      is.finite(x) &&
      x == trunc(x) &&
      x >= 1
  ) {
    return(as.integer(x))
  }
  cli::cli_abort(
    c(
      "{.arg panels} must be a positive whole number or {.val auto}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Length-1 logical, no NA.
.check_scalar_lgl <- function(x, arg, call) {
  if (is.logical(x) && length(x) == 1L && !is.na(x)) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be a single {.code TRUE} or {.code FALSE}.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# `continuation`: NULL (no marker) or a length-1 non-NA string.
# Stored on the spec as character() of length 0 in the NULL case so
# the S7 property type (class_character) is respected; the engine
# reads `length(cont) == 0L` as "no marker".
.check_continuation <- function(x, call) {
  if (is.null(x)) {
    return(character())
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg continuation} must be a single character string or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Return the names of `usage = "group"` columns from a cols list.
# Mirrors `.across_col_names()` in R/sort_rows.R.
.group_col_names <- function(cols) {
  if (length(cols) == 0L) {
    return(character())
  }
  is_group <- vapply(
    cols,
    function(c) !is.na(c@usage) && c@usage == "group",
    logical(1)
  )
  names(cols)[is_group]
}
