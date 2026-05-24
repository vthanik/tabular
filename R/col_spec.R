# col_spec.R — user-facing per-column DSL constructor.
#
# Wraps .col_spec_class (the S7 class in aaa_class.R) with cli-friendly
# tabular_error_input messages instead of bare S7 validator strings.
# Sets `name` to NA_character_; cols() assigns the input column name
# from the named argument position.

#' Per-column display specification
#'
#' Build a single column's display attributes — usage, label, format,
#' visibility, width, alignment, NA text. The result feeds [`cols()`],
#' which stamps the input column name onto the spec from its named-
#' argument position and attaches it to the parent `tabular_spec`.
#'
#' @details
#'
#' **Constructor-only.** `col_spec()` does not know which input
#' column it belongs to until [`cols()`] stamps the name. Build
#' reusable specs as ordinary R objects (e.g.
#' `arm_col <- col_spec(align = "decimal")`) and apply them to
#' multiple inputs without restating the name.
#'
#' **Merge semantics across repeated `cols()` calls.** When
#' [`cols()`] is called twice for the same column, the engine merges
#' field-by-field: a non-default value on the new spec overrides;
#' a default-valued field (NA / NULL / "" / `TRUE`) leaves the
#' existing field intact. Build a column's spec in stages without
#' re-stating earlier attributes.
#'
#' **Validation timing.** Argument shapes are validated eagerly —
#' a malformed `sprintf` template is probed at construction
#' (`sprintf(format, 0)`) and fails fast at write time, not at
#' render time.
#'
#' @param usage *Engine role.*
#'   `<character(1) | NULL>: default NULL`. One of:
#'
#'   *   **`"display"`** (default in [`cols()`]) — pass-through.
#'   *   **`"group"`** — row-label with repeat-suppression and
#'       continuation-page repeat keys. Use for `variable`, `soc`,
#'       `stat_label`.
#'   *   **`"across"`** — pivot source. Pair with [`pivot_across()`].
#'   *   **`"computed"`** — derived column; pair with a [`derive()`]
#'       entry. The column need not exist in `data` yet at
#'       [`cols()`] time.
#'   *   **`NULL`** — inferred as `"display"` in [`cols()`].
#'
#'   **Interaction:** `"computed"` requires a matching [`derive()`]
#'   entry by engine_validate time. `"across"` requires the pivot
#'   to have happened upstream via [`pivot_across()`].
#'
#'   ```r
#'   # Two row-label columns and four arm columns.
#'   cols(
#'     variable   = col_spec(usage = "group"),
#'     stat_label = col_spec(usage = "group"),
#'     placebo    = col_spec(),
#'     drug_50    = col_spec()
#'   )
#'   ```
#'
#' @param label *Display label for the column header.*
#'   `<character(1)>: default NA_character_`. Embed `\n` for
#'   multi-line headers (arm name on row 1, BigN denominator on
#'   row 2 is the clinical convention). `NA_character_` means use
#'   the input column name verbatim.
#'
#'   **Restriction:** Empty string and whitespace-only labels are
#'   accepted here, unlike [`headers()`] band labels which are
#'   strict.
#'
#'   ```r
#'   # Two-line header with arm name and BigN from saf_n.
#'   n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'   col_spec(
#'     label = sprintf("Placebo\nN=%d", n["placebo"]),
#'     align = "decimal"
#'   )
#'   ```
#'
#' @param format *Post-cell formatter.*
#'   `<character(1) | function | NULL>: default NULL`. A `sprintf`
#'   template applied per cell, OR a unary `function(x) -> character`
#'   of the same length, OR `NULL` for backend default.
#'
#'   **Restriction:** Character templates are probed with
#'   `sprintf(format, 0)` at construction; malformed templates fail
#'   fast.
#'   **Tip:** Use a function for non-`sprintf` formatting (locale-
#'   aware numbers, thousand separators, conditional symbols).
#'
#'   ```r
#'   # sprintf template vs. function form.
#'   col_spec(format = "%.1f")
#'   col_spec(format = function(x) formatC(x, format = "f", digits = 1, big.mark = ","))
#'   ```
#'
#' @param visible *Whether the column renders.*
#'   `<logical(1)>: default TRUE`. `FALSE` hides the column from
#'   output but keeps it in `spec@data` so [`sort_rows()`],
#'   [`derive()`], and [`style()`] predicates can still reference it.
#'
#'   **Interaction:** Hidden columns are the standard pattern for
#'   sort-key helpers (`row_type`, `n_total`) and for the numeric
#'   counts behind formatted-text percentage cells.
#'
#' @param width *Column width — auto-sized, pinned, or proportional.*
#'   `<character(1) | numeric(1)>: default "auto"`.
#'
#'   *   **`"auto"`** *(default)* — engine measures the widest
#'       cell (header + body) using bundled Adobe AFM Core 13
#'       glyph metrics and distributes against the available
#'       content width. No wrapping: a wide cell produces a wide
#'       column. Pin a numeric width to force wrap inside.
#'   *   **`<number>`** — pinned in inches. Backends wrap content
#'       inside the pinned width (tabularray `Q[wd=...]`, HTML
#'       `style="width:..."`, RTF / DOCX after twips conversion).
#'   *   **`"2.5in"` / `"60mm"` / `"4cm"` / `"30pt"` / `"5pc"`** —
#'       pinned dimension with an explicit TeX unit. Same
#'       behaviour as a bare numeric.
#'   *   **`"30%"`** — proportional width, percent of available
#'       content width. Resolved at engine time against the
#'       printable area.
#'
#'   **Tip:** Mix freely. Pinned and percent widths take priority;
#'   `"auto"` columns distribute whatever space remains. If pinned
#'   widths together exceed the available content width, the
#'   engine warns and leaves `"auto"` columns at their natural fit
#'   (layout may overflow).
#'
#'   **Restriction:** Must be positive. Percent values must fall
#'   in `[0, 100]`. Font-relative units (`em`, `ex`, `rem`) and
#'   screen-relative `px` are rejected — column widths live in
#'   print geometry, not text flow.
#'
#'   **Note:** `NA` and `NULL` are rejected. In pre-v0.1.0
#'   tabular `NA` deferred to backend auto-fit; that path was
#'   inconsistent across backends and is replaced by the `"auto"`
#'   default, which produces identical widths across RTF / LaTeX
#'   / HTML.
#'
#' @param align *Horizontal alignment within the column.*
#'   `<character(1) | NULL>: default NULL`. One of:
#'
#'   *   **`"left"`** — character columns; row labels.
#'   *   **`"center"`** — column-header band; rarely on data cells.
#'   *   **`"right"`** — numeric content without decimals.
#'   *   **`"decimal"`** — numeric or mixed-format cells aligned on
#'       the decimal mark. Use for `"5 (3.2%)"` next to
#'       `"54 (32.1%)"`.
#'   *   **`NULL`** (default) — falls through to
#'       `preset(alignment = list(body_halign = ...))` and then to
#'       the baked default `"left"`.
#'
#'   **Tip:** `"decimal"` pads numerics with non-breaking spaces
#'   so the decimal mark falls on a single column-wide anchor.
#'   The active preset's `decimal_metrics` knob is reserved for
#'   future em-aware padding refinement (see [`preset()`]); the
#'   current engine pads by character count.
#'
#' @param valign *Vertical alignment within the cell.*
#'   `<character(1) | NULL>: default NULL`. One of `"top"`,
#'   `"middle"`, `"bottom"`. `NULL` falls through to
#'   `preset(alignment = list(body_valign = ...))` (baked default
#'   `"top"`). Per-cell overrides via `style(valign = ...)` still
#'   win over the column setting.
#'
#'   **Tip:** Set `"middle"` on the row-label column of a banded-
#'   row table so the label stays centred against the multi-line
#'   stat-block in the adjacent cell.
#'
#' @param na_text *Text substituted for `NA` cells.*
#'   `<character(1)>: default ""`. Substituted BEFORE the `format`
#'   step, so `format` does not need to anticipate `NA`.
#'
#'   **Tip:** Use a sentinel (`"-"`, `"NR"`, `"."`) when blank cells
#'   would be ambiguous, e.g. when "not applicable" and "not
#'   reported" both render blank.
#'
#' @return *A `col_spec` S7 object.* Pass it to [`cols()`] keyed by
#'   the input column name; the constructor itself does not stamp
#'   a name.
#'
#' @examples
#' # ---- Example 1: Demographics with every col_spec field exercised ----
#' #
#' # Demographics table where every `col_spec` field is in play:
#' # the row-label columns are pinned to a fixed width and aligned
#' # left, the four arm columns embed BigN inline in the header,
#' # decimal-align numeric content, and render `NA` cells as "-".
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
#'     variable   = col_spec(
#'       usage = "group", label = "Parameter",
#'       width = 2.0,     align = "left"
#'     ),
#'     stat_label = col_spec(label = "Statistic", align = "left"),
#'     placebo  = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_50  = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_100 = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal", na_text = "-"
#'     ),
#'     Total    = col_spec(
#'       label = sprintf("Total\nN=%d", n["Total"]),
#'       align = "decimal", na_text = "-"
#'     )
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # ---- Example 2: AE table with hidden helper columns ----
#' #
#' # AE-by-SOC/PT table where hidden helper columns (`row_type`,
#' # `n_total`) drive the sort while staying off the rendered page.
#' # Demonstrates `visible = FALSE` for sort-only columns, fixed
#' # width on the wide SOC label column, and decimal alignment on
#' # all four arm columns.
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
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' @seealso
#' **Companion verb:** [`cols()`] attaches `col_spec` entries to a
#' `tabular_spec` keyed by input column name.
#'
#' **Sibling build verbs:** [`headers()`], [`sort_rows()`],
#' [`derive()`], [`style()`], [`paginate()`], [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' **Inline label formatting:** [`md()`], [`html()`].
#'
#' @export
col_spec <- function(
  usage = NULL,
  label = NA_character_,
  format = NULL,
  visible = TRUE,
  width = "auto",
  align = NULL,
  valign = NULL,
  na_text = ""
) {
  call <- rlang::caller_env()

  usage_val <- .check_col_usage(usage, call = call)
  align_val <- .check_col_align(align, call = call)
  valign_val <- .check_col_valign(valign, call = call)
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
    valign = valign_val,
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

.check_col_valign <- function(x, call) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .valign_values
  ) {
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg valign} must be one of {.val {(.valign_values)}} or {.code NULL}.",
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
  # The "auto" sentinel is the default. Engine resolves it at
  # render time via .compute_col_width() / .distribute_widths().
  if (identical(x, "auto")) {
    return(invisible(x))
  }
  # NA / NULL: rejected. Pre-v0.1.0 these meant "defer to backend
  # auto-fit", which is what "auto" now does consistently.
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    cli::cli_abort(
      c(
        "{.arg width} cannot be {.code NA} or {.code NULL}.",
        "i" = "Use {.val auto} (default) for engine-measured width.",
        "i" = "Use a numeric like {.code 2.5} or a dim string like {.val 2.5in} to pin."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # Delegate to the units parser so error semantics match
  # `preset(margins = ...)`. Numeric (inches), character with
  # TeX unit suffix (in/cm/mm/pt/pc), or percent are all accepted.
  parsed <- tryCatch(
    .parse_dim(x, allow_percent = TRUE, call = call),
    tabular_error_input = function(e) e
  )
  if (inherits(parsed, "tabular_error_input")) {
    cli::cli_abort(
      c(
        "{.arg width} is not a valid dimension.",
        "i" = conditionMessage(parsed)
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # Column widths must be strictly positive — a zero-width column
  # is nonsensical (use `visible = FALSE` to hide instead).
  if (parsed$value <= 0) {
    cli::cli_abort(
      c(
        "{.arg width} must be positive when set.",
        "i" = "Use {.code visible = FALSE} to hide a column."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(x)
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
