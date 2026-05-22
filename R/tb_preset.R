#' Apply rendering defaults to a tabular spec
#'
#' `tb_preset()` is a pipe-chained verb: takes a `tabular_spec` and
#' returns a `tabular_spec` with its `@preset` property updated. The
#' new values are merged into any preset already on the spec (or the
#' session default set via [tb_set_preset()]) and override at render
#' time.
#'
#' For a session-wide default applied to every subsequent
#' [tb_table()] call, see [tb_set_preset()].
#'
#' @param spec A `tabular_spec` produced by [tb_table()] (or any
#'   later verb in the chain).
#' @param ... Named geometry / styling values. The package owns
#'   *render-time* concerns only -- cell formatting, percent precision,
#'   stat-label text, and similar shape decisions belong to the upstream
#'   data-prep step that builds the wide `data.frame`. Accepted keys:
#'
#'   *   **`font_size`** -- body font size in points.
#'   *   **`font_family`** -- body font name.
#'   *   **`orientation`** -- `"portrait"` or `"landscape"`.
#'   *   **`paper_size`** -- `"letter"` or `"a4"`.
#'   *   **`margins`** -- length-1 or length-4 numeric in inches.
#'   *   **`title_align`** -- `"left"` / `"center"` / `"right"`.
#'       Default `"center"` (BMS / GSK convention); set `"left"` for
#'       Lilly-style title blocks.
#'   *   **`footnote_align`** -- `"left"` / `"center"` / `"right"`.
#'       Default `"left"` (all surveyed submission standards).
#'   *   **`na_text`** -- string substituted for `NA` cells in the
#'       wide data at render time. Default `""` (blank cell).
#'       Common sponsor variants: `"-"`, `"NE"`, `"."`. Operates on
#'       cells only; titles and footnotes already reject `NA` at
#'       construction time.
#'   *   **`pagehead`** -- list of named lists, one per header row;
#'       each row is `list(left=, center=, right=)`. Token strings
#'       (`{thepage}`, `{total_pages}`, `{study}`, ...) are interpolated
#'       at render time.
#'   *   **`pagefoot`** -- same shape as `pagehead`, with an optional
#'       `rule_above` (logical) controlling the solid line above the
#'       footer block.
#'   *   **`hlines`** -- `"header"` / `"none"` / `"all"`.
#'   *   **`indent_chars`** -- prefix the backend prepends when
#'       [tb_rows()]'s `indent_by` is set.
#'   *   **`continuation`** -- continuation marker rendered on page 2+
#'       of paginated tables (e.g. `"(continued)"`, `"(suite)"`).
#'   *   **`rows_per_page`** -- default row-per-page count when
#'       `tb_table(rows_per_page = ...)` is unset.
#'
#' @param reset Logical. `TRUE` clears the spec's preset back to
#'   defaults (ignores the `...` values).
#'
#' @return The updated `tabular_spec`.
#'
#' @section Style profiles:
#' The package ships **no named style profiles**. Wrap `tb_preset()`
#' (or [tb_set_preset()]) in your own helper function for any house
#' style you need to reuse:
#'
#' ```r
#' custom_style <- function(spec) {
#'   spec |>
#'     tb_preset(
#'       font_size    = 8,
#'       orientation  = "landscape",
#'       hlines       = "header",
#'       indent_chars = "   "
#'     )
#' }
#'
#' saf_demo |>
#'   tb_table(titles = "Table 14.1.1") |>
#'   custom_style() |>
#'   tb_render(tempfile(fileext = ".rtf"))
#' ```
#'
#' Or set the same defaults session-wide so every `tb_table()` picks
#' them up automatically:
#'
#' ```r
#' tb_set_preset(font_size = 8, orientation = "landscape")
#'
#' saf_demo |>
#'   tb_table(titles = "Table 14.1.1") |>
#'   tb_render(tempfile(fileext = ".rtf"))
#' ```
#'
#' @section Errors:
#' Raises `tabular_error_runtime` while the implementation is still
#' stubbed. Phase 1b lifts the stub.
#'
#' @seealso [tb_set_preset()] for the session-scope default.
#' @family defaults
#' @export
tb_preset <- function(spec, ..., reset = FALSE) {
  cli::cli_abort(
    "{.fn tb_preset} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}

#' Set a session-wide rendering preset (ggplot2 `theme_set()` style)
#'
#' Sets a session-scope default preset that every subsequent
#' [tb_table()] call inherits at construction time. Per-table
#' overrides via [tb_preset()] (the pipe form) compose on top.
#'
#' The session preset lives in a package environment and persists for
#' the lifetime of the R session. It is **not** saved across sessions
#' and is not file-discovered -- the package has no YAML / config-file
#' magic.
#'
#' @param ... Named geometry / styling values. Same accepted keys as
#'   [tb_preset()].
#' @param reset Logical. `TRUE` clears the session default back to
#'   built-in defaults (ignores the `...` values).
#'
#' @return Invisibly returns the previous session preset, so you can
#'   restore it after a scoped change:
#'
#'   ```r
#'   old <- tb_set_preset(font_size = 8)
#'   on.exit(tb_set_preset(!!!old), add = TRUE)
#'   ```
#'
#' @section Inspecting the active default:
#' Call [tb_get_preset()] to retrieve the current session default.
#'
#' @section Errors:
#' Raises `tabular_error_runtime` while the implementation is still
#' stubbed. Phase 1b lifts the stub.
#'
#' @seealso [tb_preset()] for the per-table override.
#' @family defaults
#' @export
tb_set_preset <- function(..., reset = FALSE) {
  cli::cli_abort(
    "{.fn tb_set_preset} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}

#' Get the active session-wide preset
#'
#' Returns the session default set by the most recent
#' [tb_set_preset()] call, or an empty list when no session default
#' is active. Mostly useful for tests and introspection.
#'
#' @return A named list of preset values (possibly empty).
#'
#' @section Errors:
#' Raises `tabular_error_runtime` while the implementation is still
#' stubbed. Phase 1b lifts the stub.
#'
#' @seealso [tb_set_preset()], [tb_preset()].
#' @family defaults
#' @export
tb_get_preset <- function() {
  cli::cli_abort(
    "{.fn tb_get_preset} is not yet implemented.",
    class = "tabular_error_runtime",
    call = rlang::caller_env()
  )
}
