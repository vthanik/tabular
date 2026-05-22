#' Construct a tabular spec from pre-summarised wide data
#'
#' Entry point for the 95% case. Takes a pre-summarised wide
#' `data.frame` (one row per displayed table row, columns per treatment
#' arm) plus title and footnote strings. Returns a `tabular_spec` that
#' the remaining verbs ([tb_cols()], [tb_rows()], ...) update
#' functionally and that [tb_render()] emits to RTF / LaTeX / PDF /
#' HTML / DOCX.
#'
#' `tb_table()` is deliberately thin (4 args). Cell formatting,
#' percent precision, stat-label text, MISSING-row policy, and similar
#' shape decisions belong **upstream** in the data-preparation step
#' that builds the wide `data.frame`. The package boundary is
#' *pre-summarised data in, rendered file out.*
#'
#' @param data Pre-summarised wide `data.frame`. One row per displayed
#'   row; columns carry the row label, treatment arms, and optional
#'   `Total`. Every cell is the final character string that will appear
#'   in the output. Required.
#' @param titles `character()` of title lines. Rendered at the top of
#'   the table, centred, one line per element. Submission conventions
#'   typically use up to four lines (table number / description /
#'   population / qualifier); more is permitted but uncommon. `NULL`
#'   (default) means no title block.
#' @param footnotes `character()` of user footnote lines. Rendered
#'   left-aligned below the table, after the footer rule. `NULL`
#'   (default) means no user footnotes; the backend still emits the
#'   mandatory program-path / timestamp lines from the active preset.
#' @param rows_per_page Single whole number; the backend breaks to a
#'   new page after this many data rows. `NULL` (default) defers to
#'   the backend's pagination policy (typically driven by paper size,
#'   font size, and orphan / widow rules). Group-aware pagination
#'   (e.g. keep-with-next on SOC -> PT blocks) is handled by the
#'   engine regardless of this value.
#'
#' @return A `tabular_spec` S7 object.
#'
#' @section Layout map:
#' The four-section canonical page layout has fixed slots; `tb_table()`
#' populates two of them and the active preset populates the rest:
#'
#' *   **Header** -- protocol / draft-marker / page-number. Owned by
#'     [tb_preset()] (`pagehead`).
#' *   **Title block** -- `titles` lines, centred. Owned by this verb.
#' *   **Data section** -- `data`, column headers, optional subgroup
#'     banner. Column shape and headers are owned by [tb_cols()] /
#'     [tb_rows()]; the data itself comes from this verb.
#' *   **Footnote block** -- `footnotes` (user) plus program-path /
#'     timestamp (preset). Top-rule, blank line, then user footnotes.
#'     User portion owned by this verb; backend portion owned by
#'     [tb_preset()] (`pagefoot`).
#'
#' @section Style profile:
#' `tb_table()` does not take a `preset` argument. Style defaults flow
#' from the session preset set via [tb_set_preset()]; per-table
#' overrides compose in the pipe via [tb_preset()]. The continuation
#' marker for paginated tables (`"(continued)"`, `"(suite)"`, ...) is
#' a preset value, not a `tb_table()` argument.
#'
#' @section Errors:
#' Raises `tabular_error_input` when:
#'
#' *   `data` is not a data frame.
#' *   `titles` / `footnotes` are non-character or contain `NA`.
#' *   `rows_per_page` is not a single whole number (or `NULL`).
#'
#' @family entry_points
#' @seealso [tb_cols()], [tb_rows()], [tb_render()] for the rest of
#'   the verb chain. [tb_preset()] / [tb_set_preset()] for style
#'   defaults.
#' @export
#' @examples
#' # 95% case -- pre-summarised demographics
#' spec <- tb_table(
#'   saf_demo,
#'   titles    = c(
#'     "Table 14.1.1",
#'     "Summary of Demographics and Baseline Characteristics",
#'     "Safety Population"
#'   ),
#'   footnotes = "Percentages are based on the number of subjects per arm."
#' )
#' spec
#'
#' # With explicit pagination
#' tb_table(saf_demo, rows_per_page = 40L)
tb_table <- function(
  data,
  titles = NULL,
  footnotes = NULL,
  rows_per_page = NULL
) {
  caller <- rlang::caller_env()

  check_data_frame(data, call = caller)

  titles <- titles %||% character()
  footnotes <- footnotes %||% character()
  check_chr(titles, call = caller)
  check_chr(footnotes, call = caller)

  rows_per_page <- check_rows_per_page(rows_per_page, call = caller)

  tabular_spec(
    data = data,
    titles = titles,
    footnotes = footnotes,
    rows_per_page = rows_per_page
  )
}
