# paginate.R — attach a pagination_spec to a tabular_spec. The verb
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
#' headers, and footnotes — you do not set rows-per-page directly.
#'
#' @details
#'
#' **Replace, not stack.** A second `paginate()` call REPLACES the
#' prior spec — pagination is a single configuration block, not a
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
#' context.
#'
#' @param .spec *The `tabular_spec` to attach pagination to.*
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
#'   `<integer(1)>: default 1`. With `1`, every column is on every page
#'   (single vertical scroll). With `N > 1`, the engine splits non-group
#'   columns into `N` chunks and repeats every group column on every
#'   panel.
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
#' @param repeat_content *Which page chrome repeats on every page.*
#'   `<character>: default c("titles", "headers", "footnotes")`. A
#'   subset of those three values; each is governed independently:
#'
#'   *   **`"titles"`** — title block on every page (else page 1 only).
#'   *   **`"headers"`** — column-header band on every page (else
#'       page 1 only).
#'   *   **`"footnotes"`** — footnote block on every page (else last
#'       page only).
#'
#'   The default repeats all three so each page is self-contained per
#'   the submission layout contract. Pass a subset to drop one (e.g.
#'   `c("headers", "footnotes")` keeps the title on page 1 only), or
#'   `character()` to repeat nothing.
#'
#'   **Note:** Footnotes are always anchored to the page foot when
#'   present; membership only chooses every-page vs last-page-only,
#'   never table-body placement.
#'
#'   **HTML / MD:** ignored. HTML renders one continuous `<table>`
#'   and browsers natively repeat `<thead>` on print; MD has no print
#'   model. Effective only for the page-oriented backends (RTF, PDF,
#'   LaTeX, DOCX).
#'
#' @param continuation *Marker text appended after a continuing
#'   table's title block.* `<character(1) | NULL>: default NULL`.
#'   `NULL` (the default) renders no marker — pick the wording your
#'   submission style guide expects (e.g. `"(continued)"`,
#'   `"(Cont'd)"`, `"Page %d of %d"`) and pass it explicitly.
#'
#'   **Backend support is uneven** — verify against your render target:
#'
#'   *   **PDF / LaTeX** — full: the marker prints on every
#'       continuation page (both vertical page overflow and horizontal
#'       panels).
#'   *   **RTF** — horizontal continuation *panels* only
#'       (`paginate(panels = N)`); the marker does NOT appear on
#'       vertical page-overflow continuations.
#'   *   **DOCX** — not marked. DOCX paginates natively but emits no
#'       continuation marker.
#'   *   **HTML / MD** — ignored. With one continuous document on
#'       screen there is no continuing-page boundary to mark.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`style()`], [`preset()`], then render via [`emit()`] (or
#'   resolve without I/O via [`as_grid()`]).
#'
#' @examples
#' # ---- Example 1: AE table paginated by SOC ----
#' #
#' # AE-by-SOC/PT table that may run several pages. The SOC column is
#' # protected by `keep_together` so a page break never lands in the
#' # middle of one SOC's PT rows. The engine derives the row budget
#' # from the preset's orientation + font_size + paper size and from
#' # the title / footnote / header line counts on the spec — no
#' # manual rows-per-page knob to keep in sync.
#' ae <- cdisc_saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
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
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level"),
#'     soc      = col_spec(usage = "group", visible = FALSE,
#'                         group_display = "column_repeat"),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}")
#'   ) |>
#'   headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   paginate(
#'     keep_together = "soc",
#'     repeat_content = c("titles", "headers", "footnotes"),
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
#'     stat_label  = col_spec(usage = "id", label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = "Placebo\nN={ne['placebo']}"),
#'     drug_50    = col_spec(label = "Drug 50\nN={ne['drug_50']}"),
#'     drug_100   = col_spec(label = "Drug 100\nN={ne['drug_100']}")
#'   ) |>
#'   sort_rows(by = c("groupid", "stat_label")) |>
#'   paginate(panels = 2, repeat_content = c("titles", "headers", "footnotes"))
#'
#' # ---- Example 3: Orphan / widow floors + continuation marker ----
#' #
#' # Long vital-signs table with two safeguards: orphan_floor = 4
#' # prevents fewer than 4 rows of a group landing alone at the
#' # bottom of a page; widow_floor = 2 prevents fewer than 2 rows of
#' # a group landing alone at the top of the next page; the
#' # continuation marker prints on every page after the first.
#' tabular(
#'   cdisc_saf_vital,
#'   titles = c("Table 14.4.1", "Vital Signs Summary at Each Visit")
#' ) |>
#'   cols(
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     paramcd    = col_spec(visible = FALSE),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal")
#'   ) |>
#'   paginate(
#'     keep_together = "param",
#'     orphan_floor  = 4L,
#'     widow_floor   = 2L,
#'     continuation  = "(continued)"
#'   )
#'
#' # ---- Example 4: Many-arm horizontal pagination via column-fit ----
#' #
#' # Wide AE-by-SOC/PT table where the column strip itself does not
#' # fit on a single page. The engine slices columns into groups
#' # (each group keeping the `usage = "group"` columns repeated on
#' # every horizontal page) so the SOC / PT label band re-appears
#' # alongside whichever arm columns land on each panel.
#' tabular(
#'   cdisc_saf_aesocpt,
#'   titles = c("Table 14.3.1", "AEs by SOC and PT (wide-page split)")
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level",
#'                         width = "2.5in"),
#'     soc      = col_spec(usage = "group", visible = FALSE,
#'                         group_display = "column_repeat"),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo",  align = "decimal",
#'                         width = "2.0in"),
#'     drug_50  = col_spec(label = "Drug 50",  align = "decimal",
#'                         width = "2.0in"),
#'     drug_100 = col_spec(label = "Drug 100", align = "decimal",
#'                         width = "2.0in"),
#'     Total    = col_spec(label = "Total",    align = "decimal",
#'                         width = "2.0in")
#'   ) |>
#'   paginate(keep_together = "soc")
#'
#' @seealso
#' **Render-geometry partner:** [`preset()`] / [`set_preset()`]
#' — the preset's paper, orientation, margins, and font size feed
#' the per-page row budget this verb depends on.
#'
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`style()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
paginate <- function(
  .spec,
  keep_together = character(),
  panels = 1,
  orphan_floor = 3,
  widow_floor = 2,
  repeat_content = c("titles", "headers", "footnotes"),
  continuation = NULL
) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  check_chr(keep_together, arg = "keep_together", call = call)
  panels_val <- .check_panels(panels, call = call)
  of <- check_pos_int(orphan_floor, arg = "orphan_floor", call = call)
  wf <- check_pos_int(widow_floor, arg = "widow_floor", call = call)
  rc <- .check_repeat_content(repeat_content, call = call)
  cont <- .check_continuation(continuation, call = call)

  if (length(keep_together) > 0L) {
    data_cols <- names(.spec@data)
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
    group_cols <- .group_col_names(.spec@cols)
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
    repeat_content = rc,
    continuation = cont
  )
  S7::set_props(.spec, pagination = new_pag)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Validate `panels`. Accepts a positive whole number. Returns it as an
# integer.
.check_panels <- function(x, call) {
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
      "{.arg panels} must be a positive whole number.",
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

# Validate `repeat_content`: a character subset of
# c("titles", "headers", "footnotes"), deduplicated. `NULL` and
# `character()` both mean "repeat nothing". Order-insensitive.
.check_repeat_content <- function(x, call) {
  if (is.null(x)) {
    return(character())
  }
  check_chr(x, arg = "repeat_content", call = call)
  known <- .repeat_content_values
  bad <- setdiff(x, known)
  if (length(bad) > 0L) {
    cli::cli_abort(
      c(
        "{.arg repeat_content} must be a subset of {.val {known}}.",
        "x" = "Unknown value{?s}: {.val {bad}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  unique(x)
}

# Return the names of `usage = "group"` columns from a cols list.
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

# Stub columns: the columns that repeat on every horizontal panel and
# show once on the left of a collapsed continuous table. This is the
# `usage = "group"` set widened to include `usage = "id"` (the
# non-collapsing row-identifier). Distinct from `.group_col_names()`,
# which stays group-only for collapse / keep_together / group_skip /
# decimal sectioning. Used only on the panel-repeat path
# (`engine_paginate` -> `.compute_horizontal_panels` /
# `.panel_spans_from_panels`).
.stub_col_names <- function(cols) {
  if (length(cols) == 0L) {
    return(character())
  }
  is_stub <- vapply(
    cols,
    function(c) !is.na(c@usage) && c@usage %in% c("group", "id"),
    logical(1)
  )
  names(cols)[is_stub]
}
