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
#'   *   **`"across"`** — pivot-source tag. Mark every column that
#'       originated as a treatment arm in [`pivot_across()`]'s wide
#'       output. The tag is informational — [`sort_rows()`] uses it
#'       to reject sort keys on arm columns (pivot upstream of the
#'       sort instead), and downstream introspection tools walk the
#'       spec to find which columns came from an ARD pivot.
#'   *   **`"computed"`** — derived column; pair with a [`derive()`]
#'       entry. The column need not exist in `data` yet at
#'       [`cols()`] time.
#'   *   **`NULL`** — inferred as `"display"` in [`cols()`].
#'
#'   **Interaction:** `"computed"` requires a matching [`derive()`]
#'   entry by engine_validate time. `"across"` requires the pivot
#'   to have happened upstream via [`pivot_across()`]; sorting by an
#'   `"across"` column is a `tabular_error_input`.
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
#'   ```r
#'   # End-to-end ARD → wide → tabular pipeline with usage = "across"
#'   # tagging every arm column. The cards ARD `saf_demo_card` is
#'   # the long upstream input; `pivot_across()` widens to one column
#'   # per arm; `cols()` then attaches per-column display rules.
#'   wide <- pivot_across(
#'     saf_demo_card,
#'     statistic = list(
#'       continuous  = c(N = "{N}", "Mean (SD)" = "{mean} ({sd})"),
#'       categorical = "{n} ({p}%)"
#'     )
#'   )
#'   tabular(wide, titles = "Demographics") |>
#'     cols(
#'       variable                 = col_spec(
#'         usage = "group", label = "Characteristic"
#'       ),
#'       stat_label               = col_spec(
#'         usage = "group", label = "Statistic"
#'       ),
#'       Placebo                  = col_spec(
#'         usage = "across", align = "decimal"
#'       ),
#'       `Xanomeline High Dose`   = col_spec(
#'         usage = "across", label = "High Dose", align = "decimal"
#'       ),
#'       `Xanomeline Low Dose`    = col_spec(
#'         usage = "across", label = "Low Dose", align = "decimal"
#'       ),
#'       Total                    = col_spec(
#'         usage = "across", align = "decimal"
#'       )
#'     )
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
#' @param group_display *How `usage = "group"` values render in the body.*
#'   `<character(1)>: default "header_row"`. Active only when
#'   `usage = "group"`; ignored otherwise.
#'
#'   *   **`"header_row"`** *(default)* — each unique value emits as
#'       a section header row above its block of data rows. The
#'       source column is hidden from the visible body. Matches the
#'       canonical submission Appendix I shape used by clinical TFL
#'       house templates (Disposition, Demographics, Statistical
#'       Report sections).
#'   *   **`"column"`** — column stays visible; repeated values are
#'       suppressed (only the first row of each value shows the
#'       label). PROC REPORT's default for grouping variables.
#'   *   **`"column_repeat"`** — column stays visible; every row
#'       repeats the value (no suppression). The shape `R`'s
#'       `print.data.frame` produces.
#'
#'   **Composition under multiple group columns.** When more than
#'   one `usage = "group"` column is declared, the FIRST one
#'   encountered in `cols()` order is the outer group; subsequent
#'   group columns nest inside it. Each column's `group_display`
#'   choice is independent — a common clinical pattern is the outer
#'   `variable` as `"header_row"` plus the inner `stat_label` as
#'   `"column"` (visible row labels under each section header).
#'
#'   ```r
#'   # Demographics layout: variable as section header, stat_label
#'   # as visible suppressed column.
#'   cols(
#'     variable   = col_spec(usage = "group", group_display = "header_row"),
#'     stat_label = col_spec(usage = "group", group_display = "column"),
#'     placebo    = col_spec(label = "Placebo", align = "decimal")
#'   )
#'   ```
#'
#' @param group_skip *Insert a blank row between consecutive groups.*
#'   `<logical(1)>: default NA`. Active only when `usage = "group"`;
#'   ignored otherwise. Three values:
#'
#'   *   **`TRUE`** — engine injects one blank row immediately before
#'       each value transition on this column (PROC REPORT's `BREAK
#'       AFTER var / SKIP` semantics, lifted to per-column control).
#'       Never trails the final group.
#'   *   **`FALSE`** — never insert a blank row for this column.
#'   *   **`NA`** *(default)* — follow `group_display`: `TRUE` when
#'       `group_display = "header_row"`, `FALSE` when `"column"` or
#'       `"column_repeat"`. Picks the canonical Appendix-I shape
#'       without an extra knob to set.
#'
#'   **Interaction:** When two or more columns have an effective
#'   `group_skip = TRUE` and their value transitions coincide on the
#'   same row, the engine emits ONE blank row at that boundary, not
#'   one per column. Transition row indices are unioned across all
#'   contributing group columns.
#'
#'   ```r
#'   # Default: header_row mode auto-injects blanks between sections.
#'   col_spec(usage = "group", group_display = "header_row")
#'
#'   # Override: keep the column visible (suppressed-value mode) but
#'   # still insert blank-row separators between value changes.
#'   col_spec(usage = "group", group_display = "column", group_skip = TRUE)
#'
#'   # Override: section headers without the blank-row separator
#'   # (denser layout, used when vertical space is tight).
#'   col_spec(usage = "group", group_display = "header_row", group_skip = FALSE)
#'   ```
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
#'     label       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' # ---- Example 3: Format string + na_text for clean numeric display ----
#' #
#' # A column that carries pre-computed numeric values (rather than
#' # the typical pre-formatted "12 (5.8)" string) uses `format =`
#' # to pin the printed precision and `na_text` to render missing
#' # values as a dash rather than a literal "NA". `valign = "top"`
#' # keeps the multi-line cell text aligned to the top.
#' fit <- data.frame(
#'   model     = c("ANCOVA", "MMRM", "Cox PH", "Bootstrap"),
#'   estimate  = c(-2.31, -2.45, 0.81, -2.29),
#'   lower_ci  = c(-3.42, NA,    0.68, -3.50),
#'   upper_ci  = c(-1.20, NA,    0.97, -1.10)
#' )
#' tabular(fit, titles = "Treatment-effect estimates by model") |>
#'   cols(
#'     model    = col_spec(usage = "group",  label = "Model",   valign = "top"),
#'     estimate = col_spec(label = "Estimate", align = "decimal", format = "%.2f"),
#'     lower_ci = col_spec(
#'       label   = "Lower\n95% CI",
#'       align   = "decimal",
#'       format  = "%.2f",
#'       na_text = "--"
#'     ),
#'     upper_ci = col_spec(
#'       label   = "Upper\n95% CI",
#'       align   = "decimal",
#'       format  = "%.2f",
#'       na_text = "--"
#'     )
#'   )
#'
#' # ---- Example 4: Per-column width + halign override for vitals ----
#' #
#' # `width` accepts a numeric (inches), a CSS-style string ("1.5in",
#' # "20%"), or `"auto"`. Centering the visit column under a wider
#' # group-column setup demonstrates the alignment cascade —
#' # col_spec@align beats the engine default but yields to a more
#' # specific style() rule downstream.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_vital,
#'   titles = "Vital Signs at Baseline and End of Treatment"
#' ) |>
#'   cols(
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter",
#'                           width = "1.6in"),
#'     visit      = col_spec(usage = "group", label = "Visit",
#'                           width = "1.2in", align = "center"),
#'     stat_label = col_spec(label = "Statistic", width = "1.0in"),
#'     placebo    = col_spec(
#'       label = sprintf("Placebo\nN=%d", n["placebo"]),
#'       align = "decimal", width = "0.9in"
#'     ),
#'     drug_50    = col_spec(
#'       label = sprintf("Drug 50\nN=%d", n["drug_50"]),
#'       align = "decimal", width = "0.9in"
#'     ),
#'     drug_100   = col_spec(
#'       label = sprintf("Drug 100\nN=%d", n["drug_100"]),
#'       align = "decimal", width = "0.9in"
#'     )
#'   )
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
  group_display = "header_row",
  group_skip = NA,
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
  group_display_val <- .check_col_group_display(group_display, call = call)
  group_skip_val <- .check_col_group_skip(group_skip, call = call)
  .check_col_na_text(na_text, call = call)
  .check_col_format(format, call = call)

  .col_spec_class(
    name = NA_character_,
    label = label,
    usage = usage_val,
    format = format,
    visible = visible,
    width = width,
    group_display = group_display_val,
    group_skip = group_skip_val,
    align = align_val,
    valign = valign_val,
    na_text = na_text
  )
}

.check_col_group_skip <- function(x, call) {
  if (length(x) == 1L && (is.logical(x) || is.na(x))) {
    return(as.logical(x))
  }
  cli::cli_abort(
    c(
      "Bad {.arg group_skip}.",
      "x" = "Got {.obj_type_friendly {x}}.",
      "i" = "Use TRUE, FALSE, or NA (default: follow {.arg group_display})."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Resolve the effective group_skip for a col_spec. NA means "follow
# group_display": TRUE for header_row mode (visible section
# separator), FALSE for column / column_repeat (no separator
# between rows of a column-mode group).
.effective_group_skip <- function(cs) {
  if (!is_col_spec(cs)) {
    return(FALSE)
  }
  if (is.na(cs@group_skip)) {
    return(identical(cs@group_display, "header_row"))
  }
  isTRUE(cs@group_skip)
}

.check_col_group_display <- function(x, call) {
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      x %in% .col_group_display_values
  ) {
    return(x)
  }
  modes <- .col_group_display_values
  cli::cli_abort(
    c(
      "Bad {.arg group_display}.",
      "x" = "Got {.obj_type_friendly {x}}.",
      "i" = "Use one of {.val {modes}}."
    ),
    class = "tabular_error_input",
    call = call
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
