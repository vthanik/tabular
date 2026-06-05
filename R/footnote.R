#' Attach an auto-numbered footnote to a table location
#'
#' Anchor a footnote to a cell, column header, title line, or any other
#' `cells_*()` location. The engine assigns the marker, places a
#' superscript at every matching anchor, and emits the marked-footnote
#' line at the foot of the table. Markers are assigned **once**, in
#' reading order, deduped by `id`, and are byte-identical across every
#' backend (RTF / LaTeX / PDF / HTML / DOCX) and every page, so the
#' marker at the anchor can never desynchronise from its note.
#'
#' @details
#' **Engine-assigned, never hand-typed.** Unlike a literal `^a^` typed
#' into both a cell and the `footnotes` argument, a `footnote()` marker
#' is allocated by the resolve engine after decimal alignment, so it
#' never disturbs column alignment and never drifts out of sync. The
#' scheme (`letters` / `numbers` / `symbols`) and the block-line format
#' come from the active preset (`footnote_markers`, `footnote_label`).
#'
#' **Dedup by id.** Give two anchors the same `id` to share one marker
#' and one note line. Without an `id`, each `footnote()` call is its own
#' note.
#'
#' **Coexists with `footnotes`.** Manual `footnotes` lines render first;
#' the auto-numbered block follows. The two systems do not cross-dedup,
#' so do not mix a hand-typed marker with an engine one for the same note.
#'
#' @param .spec *The `tabular_spec` to annotate.* `<tabular_spec>: required`.
#'
#' @param text *The footnote text.* `<character(1)> | md() | html()`.
#'   Wrap in [`md()`] / [`html()`] for inline markup; plain strings are
#'   shown verbatim. A plain string supports glue-style `{expr}`
#'   interpolation, evaluated as R code in the calling environment at
#'   build time (double a brace for a literal one); an `md()` / `html()`
#'   value is passed through without interpolation.
#'
#' @param .at *Where the marker is placed.* `<tabular_location>: default
#'   [`cells_body()`]`. Any `cells_*()` location: a body-cell predicate
#'   (`cells_body(where = ...)`), a column header (`cells_headers()`), a
#'   title line (`cells_title()`), and so on.
#'
#'   ```r
#'   # data-driven body anchor: mark every high-frequency preferred term
#'   footnote(spec, "Includes events of any severity.",
#'            .at = cells_body(where = n_total >= 50, j = "label"))
#'
#'   # column-header anchor: mark the analysis-population denominator
#'   footnote(spec, "Safety population.",
#'            .at = cells_headers(j = "Total"))
#'   ```
#'
#'   **Note:** the styling argument is `.at`, never `at`.
#'
#' @param id *Stable identifier for sharing one marker across anchors.*
#'   `<character(1)> | NULL`. Two `footnote()` calls with the same `id`
#'   share a single marker and a single note line. `NULL` (default)
#'   makes each call its own note.
#'
#' @param symbol *Pin an explicit marker glyph.* `<character(1)> | NULL`.
#'   Overrides the auto-allocated marker for this note (e.g. `"*"`). A
#'   pinned symbol is reserved and skipped by the auto-allocator, so it
#'   never collides. `NULL` (default) auto-allocates from the preset
#'   scheme.
#'
#' @return *A `tabular_spec`.* Pipe it onward to more verbs or to
#'   [`emit()`].
#'
#' @examples
#' # ---- Example 1: a denominator note on a column header ----
#' #
#' # AE-by-SOC/PT table whose Total column header carries the analysis-
#' # population note. The engine drops a superscript "a" on the header
#' # and prints "a <text>" beneath the table.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' tabular(cdisc_saf_aesocpt) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}")
#'   ) |>
#'   footnote(
#'     "Safety population: all randomised subjects who took study drug.",
#'     .at = cells_headers(j = "Total")
#'   )
#'
#' # ---- Example 2: a data-driven note shared across cells ----
#' #
#' # A single note marks every high-frequency preferred term (n >= 50 in
#' # the Total column) in the SOC/PT stub. Sharing one `id` keeps it to
#' # one marker and one line; the marker lands on each matching cell.
#' tabular(cdisc_saf_aesocpt) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo"),
#'     drug_100 = col_spec(label = "Drug 100"),
#'     Total    = col_spec(label = "Total")
#'   ) |>
#'   footnote(
#'     md("Includes events of *any* severity."),
#'     .at = cells_body(where = n_total >= 50, j = "label"),
#'     id = "anysev"
#'   )
#'
#' @seealso
#' **Manual footnote lines:** the `footnotes` argument to [`tabular()`].
#'
#' **Location helpers:** [`cells_body()`], [`cells_headers()`],
#' [`cells_title()`].
#'
#' **Inline markup:** [`md()`], [`html()`].
#'
#' @export
footnote <- function(
  .spec,
  text,
  .at = cells_body(),
  id = NULL,
  symbol = NULL
) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  .check_inline_input(text, arg = "text", call = call)
  text <- .interp_one(text, env = call, call = call)
  if (!is_tabular_location(.at)) {
    cli::cli_abort(
      c(
        "{.arg .at} must be a {.fn cells_*} location.",
        "i" = "e.g. {.code cells_body(where = grade == \"3\")} or {.code cells_headers(j = \"Total\")}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .check_fn_location(.at, call = call)
  .check_fn_opt(id, arg = "id", call = call)
  .check_fn_opt(symbol, arg = "symbol", call = call)
  rec <- list(text = text, id = id, symbol = symbol, location = .at)
  S7::set_props(.spec, footnote_refs = c(.spec@footnote_refs, list(rec)))
}

# Validate the anchor location. A footnote marker can only be injected
# on surfaces with a marker-injection path: body cells, a leaf column
# header addressed by `j`, or a title line. Spanner band labels
# (`cells_headers(labels=)`), header depth levels (`cells_headers(level=)`),
# and group-header rows (`cells_group_headers()`) have no injection
# surface yet, so reject them here at call time rather than silently
# dropping the note at render with only a warning.
#' @noRd
.check_fn_location <- function(loc, call) {
  surface <- loc$surface
  ok <- surface %in%
    c("body", "title") ||
    (identical(surface, "headers") &&
      !is.null(loc$j) &&
      is.null(loc$labels) &&
      is.null(loc$level))
  if (!ok) {
    cli::cli_abort(
      c(
        "Footnote anchor {.arg .at} is not supported.",
        "i" = "Anchor with {.code cells_body(...)}, {.code cells_headers(j = ...)}, or {.code cells_title()}.",
        "x" = "Spanner labels, header levels, and group headers cannot carry a footnote marker."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(NULL)
}

# Validate an optional scalar-character footnote argument (id / symbol):
# NULL, or a single non-NA, non-empty string.
#' @noRd
.check_fn_opt <- function(x, arg, call) {
  if (is.null(x)) {
    return(invisible(NULL))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single non-empty string or {.code NULL}.",
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(NULL)
}
