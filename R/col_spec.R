# col_spec.R — user-facing per-column DSL constructor.
#
# Wraps .col_spec_class (the S7 class in aaa_class.R) with cli-friendly
# tabular_error_input messages instead of bare S7 validator strings.
# Sets `name` to NA_character_; cols() assigns the input column name
# from the named argument position.

#' Per-column display specification
#'
#' Build a column specification used inside `cols()`. Each col_spec
#' carries the seven display attributes for one column of the input
#' data frame; `cols()` then attaches it to a `tabular_spec` keyed by
#' the input column name.
#'
#' `col_spec()` is a constructor only — it does not know which input
#' column it belongs to until `cols()` stamps the name via its
#' named-argument position. That separation lets you build a library
#' of reusable column specs (e.g. `arm_col <- col_spec(align = "decimal")`)
#' and apply them to multiple inputs without restating the name.
#'
#' @param usage One of `"display"`, `"group"`, `"across"`,
#'   `"computed"`, or `NULL` (auto-default in `cols()`). Drives how
#'   the engine treats the column: pass-through, row-label with
#'   repeat-suppression, pivot source, or derived display column.
#'
#'   Accepts:
#'
#'   *   **`"display"`** — pass-through column; rendered as-is.
#'   *   **`"group"`** — row-label column; repeat-suppression at
#'       render time and continuation-page repeat keys to this
#'       column. Use for `variable`, `soc`, `stat_label`, and any
#'       column whose value spans multiple consecutive rows.
#'   *   **`"across"`** — column whose unique values pivot into new
#'       output columns. The pivot happens upstream of `tabular()`
#'       via `pivot_across()`; the `"across"` tag marks the source
#'       column so the engine knows not to render it directly.
#'   *   **`"computed"`** — derived display column produced by a
#'       later `derive_spec`. The column name does not need to
#'       exist in `spec@data` at `cols()` time.
#'   *   **`NULL`** (default) — inferred in `cols()` (always
#'       `"display"`). Pass `NULL` when you only want to override
#'       label / align / width and accept the default usage.
#'
#'   ```r
#'   # The four canonical roles, each on the demographics frame.
#'   tabular(saf_demo) |>
#'     cols(
#'       variable   = col_spec(usage = "group"),     # row-label
#'       stat_label = col_spec(usage = "group"),     # second-level row-label
#'       placebo    = col_spec(),                    # display (default)
#'       drug_50    = col_spec(),
#'       drug_100   = col_spec(),
#'       Total      = col_spec()
#'     )
#'   ```
#' @param label Display label for the column header. Single character
#'   string; `NA_character_` (default) means use the input column
#'   name verbatim.
#'
#'   Embed `\n` for line breaks (multi-line headers are clinical
#'   convention — the arm name on row 1, the BigN denominator on
#'   row 2). Embed BigN inline via `paste()` / `sprintf()` against
#'   the bundled `saf_n` / `eff_n` data frames; there is no
#'   dedicated BigN field on the col_spec because the denominator
#'   already lives in a discoverable data frame upstream.
#'
#'   ```r
#'   # Two-line header with arm name and BigN; matches the BMS /
#'   # GSK convention of placing N=xx on a dedicated second row.
#'   n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'   col_spec(
#'     label = sprintf("Placebo\nN=%d", n["placebo"]),
#'     align = "decimal"
#'   )
#'   ```
#' @param format Post-cell formatter applied at `engine_format` time.
#'   Three accepted shapes:
#'
#'   *   **character** — a single `sprintf()` template applied to
#'       each cell of the column. Validated at construction time
#'       with a probe call (`sprintf(x, 0)`), so a malformed
#'       template fails fast rather than at render.
#'   *   **function** — a unary function taking one column of
#'       values and returning a character vector of the same
#'       length. Use for non-`sprintf` formatting (locale-aware
#'       numbers, thousand separators, conditional symbols).
#'   *   **`NULL`** (default) — backend-default formatting.
#'       Character columns are passed through; numeric columns
#'       are rendered with the preset's default precision.
#'
#'   ```r
#'   # sprintf template: one-decimal numerics.
#'   col_spec(format = "%.1f")
#'
#'   # Function: thousands separator + dynamic precision.
#'   col_spec(format = function(x) {
#'     formatC(x, format = "f", digits = 1, big.mark = ",")
#'   })
#'   ```
#' @param visible Logical, length 1, non-NA. `FALSE` hides the column
#'   from rendered output but keeps it in `spec@data` so the engine
#'   can read it for sort keys, derive expressions, group breaks,
#'   and style predicates. Default `TRUE`.
#'
#'   Use this when your pre-summarised input carries auxiliary
#'   columns (numeric rank, hierarchy markers, raw counts behind
#'   formatted percentages) that drive the engine but should not
#'   appear in the final table.
#'
#'   ```r
#'   # Hide the integer rank column used as a sort key.
#'   col_spec(visible = FALSE)
#'   ```
#' @param width Column width in inches. `NA_real_` (default) leaves
#'   widths to backend auto-fit. Must be positive and finite when set.
#'
#'   Use to fix the width of a wide row-label column (e.g. SOC /
#'   PT spans two lines) so the table fits inside a landscape
#'   submission page without horizontal pagination kicking in.
#'
#'   ```r
#'   # Pin the SOC / PT label column to 2.5 inches.
#'   col_spec(usage = "group", width = 2.5, label = "SOC / PT")
#'   ```
#' @param align One of `"left"`, `"center"`, `"right"`, `"decimal"`,
#'   or `NULL` (backend default).
#'
#'   *   **`"left"`** — character columns; row labels.
#'   *   **`"center"`** — column headers band; rarely on data cells.
#'   *   **`"right"`** — numeric content without decimals.
#'   *   **`"decimal"`** — numeric content with mixed decimal
#'       widths. The engine aligns each cell on its decimal mark
#'       via the active preset's `decimal_metrics`. This is the
#'       clinical convention for any column carrying mixed-format
#'       cells like `"5 (3.2%)"` next to `"54 (32.1%)"`.
#'   *   **`NULL`** (default) — backend default (right for numeric,
#'       left for character).
#'
#'   ```r
#'   # Decimal alignment on every treatment column; row label left.
#'   tabular(saf_demo) |>
#'     cols(
#'       variable = col_spec(usage = "group", align = "left"),
#'       placebo  = col_spec(align = "decimal"),
#'       drug_50  = col_spec(align = "decimal"),
#'       drug_100 = col_spec(align = "decimal")
#'     )
#'   ```
#' @param na_text Single non-NA character string substituted for `NA`
#'   cells before the `format` step. Default `""` (empty cell).
#'
#'   Use to render `NA` as a non-blank token when blank would be
#'   ambiguous (`"-"`, `"NR"` for not-reported, `"."` for SAS-style
#'   missing).
#'
#'   ```r
#'   # Render NA as "NR" (not reported) — typical for safety tables
#'   # where blank means "not applicable" but NR means "applicable
#'   # but unavailable".
#'   col_spec(na_text = "NR")
#'   ```
#' @return A `col_spec` S7 object. Use it inside `cols()`; the
#'   constructor itself does not stamp a column name onto the spec
#'   (that happens inside `cols()` from the named-argument position).
#'
#' @examples
#' # 95% safety pattern: demographics table with every col_spec
#' # field exercised in a single complete pipeline.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter", width = 2.0, align = "left"),
#'     stat_label = col_spec(label = "Statistic", align = "left"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     Total      = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal", na_text = "-"
#'     )
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # 95% AE pattern: hidden helper columns (row_type, n_total)
#' # drive the sort while staying off the rendered page.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   )
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "SOC / Preferred Term", width = 2.5),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50  = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100 = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal"
#'     ),
#'     Total    = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal"
#'     )
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' @export
col_spec <- function(
  usage = NULL,
  label = NA_character_,
  format = NULL,
  visible = TRUE,
  width = NA_real_,
  align = NULL,
  na_text = ""
) {
  call <- rlang::caller_env()

  usage_val <- .check_col_usage(usage, call = call)
  align_val <- .check_col_align(align, call = call)
  .check_col_label(label, call = call)
  .check_col_visible(visible, call = call)
  .check_col_width(width, call = call)
  .check_col_na_text(na_text, call = call)
  .check_col_format(format, call = call)

  .col_spec_class(
    name = NA_character_,
    label = label,
    usage = usage_val,
    format = format,
    visible = visible,
    width = width,
    align = align_val,
    na_text = na_text
  )
}

# ---------------------------------------------------------------------
# Per-argument validators (internal)
# ---------------------------------------------------------------------

.check_col_usage <- function(x, call) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .col_usage_values
  ) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg usage} must be one of {.val {(.col_usage_values)}} or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_align <- function(x, call) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .align_values
  ) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg align} must be one of {.val {(.align_values)}} or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_label <- function(x, call) {
  if (is.character(x) && length(x) == 1L) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg label} must be a single character string (NA allowed).",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_visible <- function(x, call) {
  if (is.logical(x) && length(x) == 1L && !is.na(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg visible} must be a single non-NA logical.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_width <- function(x, call) {
  if (
    is.numeric(x) &&
      length(x) == 1L &&
      (is.na(x) || (is.finite(x) && x > 0))
  ) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg width} must be a positive finite number or {.code NA}.",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_na_text <- function(x, call) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg na_text} must be a single non-NA character string (length 1).",
      "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.check_col_format <- function(x, call) {
  if (is.null(x) || is.function(x)) {
    return(invisible(x))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    # Probe the sprintf template with a representative numeric so
    # malformed format strings fail at build time instead of at render.
    probe <- tryCatch(
      sprintf(x, 0),
      error = function(e) e,
      warning = function(w) w
    )
    if (inherits(probe, "condition")) {
      cli::cli_abort(
        c(
          "{.arg format} sprintf template is invalid.",
          "x" = "Test call {.code sprintf({.val {x}}, 0)} failed: {conditionMessage(probe)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg format} must be a sprintf string, a function, or {.code NULL}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}
