# tabular.R — entry verb. Wraps an input data.frame, titles, and
# footnotes into a tabular_spec. Subsequent verbs (cols, headers,
# sort_rows, ...) attach configuration to the returned spec.

#' Start a tabular display
#'
#' Wrap a pre-summarised data frame into a `tabular_spec` ready for
#' the rest of the verb chain. `tabular()` is the entry point of the
#' pipeline; it owns `data`, `titles`, and `footnotes`. Every other
#' verb returns an updated `tabular_spec` via `S7::set_props()`.
#'
#' `data` is expected to be already pre-summarised: one row per
#' display row of the final table. tabular does NOT aggregate,
#' filter, weight, or generate subtotal rows — do that upstream
#' with your data-prep tool of choice.
#'
#' @param data A data frame. Tibbles / data.tables / arrow tables are
#'   coerced via `as.data.frame()`. Must have at least one column;
#'   column names must be unique. Zero rows is allowed (engine emits
#'   a stub with title + footnote + "No data").
#' @param titles Character vector; one element per displayed title
#'   line. Embedded `\n` inside an element is allowed. `NULL`
#'   (default) is equivalent to no titles.
#' @param footnotes Character vector; one element per displayed
#'   footnote line. `NULL` (default) is equivalent to no footnotes.
#' @return A `tabular_spec` S7 object.
#'
#' @examples
#' # Realistic entry: wrap the demographics demo with title block
#' # and footnote. Use the safety-pop BigN table for the title row.
#' n_total <- saf_n$n[saf_n$arm_short == "Total"]
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n_total)
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' )
#'
#' # Minimal call — a zero-row data frame is allowed (rendered as
#' # a stub with titles and footnotes only).
#' tabular(data.frame(x = integer(), y = character()))
#'
#' @export
tabular <- function(data, titles = NULL, footnotes = NULL) {
  call <- rlang::caller_env()

  data <- .normalise_data(data, call = call)
  .check_data_columns(data, call = call)

  titles_val <- .normalise_text_block(titles, arg = "titles", call = call)
  footnotes_val <- .normalise_text_block(
    footnotes,
    arg = "footnotes",
    call = call
  )

  tabular_spec(
    data = data,
    titles = titles_val,
    footnotes = footnotes_val
  )
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
