# col_spec.R — user-facing per-column DSL constructor.
#
# Wraps .col_spec_class (the S7 class in aaa_class.R) with cli-friendly
# tabular_error_input messages instead of bare S7 validator strings.
# Sets `name` to NA_character_; cols() assigns the input column name
# from the named argument position.

#' Per-column display specification
#'
#' Build a single column's display attributes — label, format,
#' visibility, width, alignment, NA text, indent. The result feeds
#' [`cols()`], which stamps the input column name onto the spec from
#' its named-argument position and attaches it to the parent
#' `tabular_spec`. Row structure (section headers, repeat
#' suppression, blank spacers) is not a column attribute — declare it
#' once with [`group_rows()`].
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
#' field-by-field: any field set to a non-default value on the new spec
#' overrides; a field left at its "unset" sentinel (`NA` / `NULL` /
#' `"auto"`) leaves the existing value intact. Because every mergeable
#' field has a genuine unset sentinel, a later call can also *restore* a
#' default — e.g. `visible = TRUE` re-shows a column an earlier call
#' hid. Build a column's spec in stages without re-stating earlier
#' attributes.
#'
#' **Validation timing.** Argument shapes are validated eagerly —
#' a malformed `sprintf` template is probed at construction
#' (`sprintf(format, 0)`) and fails fast at write time, not at
#' render time.
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
#'   Supports glue-style `{expr}` interpolation: braces are evaluated
#'   as R code in the calling environment at build time, so a BigN
#'   value folds inline, `label = "Placebo (N={n['placebo']})"`.
#'   Double a brace (`{{` or `}}`) for a literal one. An `md()` /
#'   `html()` label is passed through without interpolation.
#'
#'   **Per-column token.** `{.name}` (alias `{.col}`) inside a `{expr}`
#'   is *deferred* and resolved to the matched column's name when the
#'   spec is stamped by [`cols()`] / [`cols_apply()`], so one spec can
#'   carry a variable-N arm header. See [`cols_apply()`] for the
#'   loop-free idiom.
#'
#'   ```r
#'   # Two-line header with arm name and BigN from cdisc_saf_n.
#'   n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'   col_spec(
#'     label = "Placebo\nN={n['placebo']}",
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
#'   `<logical(1)>: default NA`. `FALSE` hides the column from output
#'   but keeps it in `spec@data` so [`sort_rows()`] and [`style()`]
#'   predicates can still reference it. `NA` (default) is the merge
#'   "unset" sentinel — it resolves to visible at render and, crucially,
#'   is mergeable: a later [`cols()`] call with `visible = TRUE` can
#'   **re-show** a column an earlier call hid.
#'
#'   **Interaction:** Hidden columns are the standard pattern for
#'   sort-key helpers (`row_type`, `n_total`) and for the numeric
#'   counts behind formatted-text percentage cells.
#'
#'   **Auto-hide.** The depth column named by a character `indent` and
#'   every column named by [`subgroup(by = ...)`][subgroup()] or referenced
#'   via a `{col}` placeholder in the subgroup banner template are
#'   flipped to `visible = FALSE` automatically at engine time —
#'   restating it here is redundant.
#'
#'   **Break-only grouping key.** To drop a blank line wherever a
#'   hidden marker column changes (e.g. continuous stats vs.
#'   categorical groups inside one characteristic), set `visible =
#'   FALSE` here AND name the column in [`group_rows()`]`(by = )`. A
#'   hidden grouping key is break-only: it renders nothing and
#'   contributes only its group transitions (the blank spacer and the
#'   decimal-section reset).
#'
#' @param width *Column width — auto-sized, pinned, or proportional.*
#'   `<character(1) | numeric(1)>: default "auto"`.
#'
#'   *   **`"auto"`** *(default)* — engine measures the widest
#'       cell (header + body) using bundled Adobe AFM Core 13
#'       glyph metrics and distributes against the available
#'       content width. The **header** is sized to its widest
#'       *word*, so a multi-word header (e.g. `"n, median"`) wraps at
#'       spaces; a non-breaking space (` `) keeps a run whole. The
#'       **body** is sized to its widest *line* and never wraps, so
#'       numeric values stay intact. Pin a numeric width to wrap the
#'       body too.
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
#'   in `[0, 100]`. Font-relative units (`em`, `ex`, `rem`) are
#'   rejected (no font-size context at parse time).
#'
#'   **Cross-format semantics (gt convention).** The width value
#'   is the user's source-of-truth. HTML emits it verbatim into
#'   `<col style="width:...">` (CSS accepts every unit: `%`,
#'   `in`, `px`, `pt`, `cm`, `mm`). Paper backends (LaTeX / RTF /
#'   PDF / DOCX) convert to their native unit via the AFM /
#'   distribute-widths pipeline. HTML is unconditionally
#'   responsive: when `width = "auto"` (default), the browser
#'   auto-sizes the column and cells wrap when the viewport
#'   narrows.
#'
#'   **Note:** `NA` and `NULL` are rejected. In pre-v0.1.0
#'   tabular `NA` deferred to backend auto-fit; that path was
#'   inconsistent across backends and is replaced by the `"auto"`
#'   default, which produces identical widths across RTF / LaTeX
#'   / HTML.
#'
#'   **Merge sentinel.** For the field-merge across repeated [`cols()`]
#'   / [`cols_apply()`] calls, `"auto"` is treated as the default: a
#'   later call carrying `width = "auto"` leaves a previously pinned
#'   width intact, and only an explicit non-`"auto"` width overrides.
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
#'   Pad counts follow the active preset's `decimal_metrics` knob
#'   (see [`preset()`]): the default `"afm"` measures real glyph
#'   widths so the anchor holds in proportional fonts as well as
#'   monospace.
#'
#'   **Default behaviour.** When `align` is unset (`NULL` / `NA`),
#'   every column emits with body left-aligned and header centred,
#'   regardless of the column's R data type. tabular's canonical
#'   input is pre-summarised wide data frames where numeric content
#'   is already formatted as character strings (e.g. `"52 (60.5)"`),
#'   so `is.numeric()`-based auto-detection would mis-classify those
#'   columns as text and align them left — the opposite of intent.
#'   Use explicit `align = "decimal"` for NBSP-padded numeric
#'   columns (centred header over the padded centroid) or
#'   `align = "right"` for plain right-aligned numeric columns.
#'   The default cascade is body → `preset(alignment = list(
#'   body_halign = ...))` → CSS `text-align: left`; header →
#'   `preset(alignment = list(header_halign = ...))` → CSS
#'   `text-align: center`.
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
#'   `<character(1) | NA>: default NA`. Substituted BEFORE the `format`
#'   step, so `format` does not need to anticipate `NA`. `NA` (default)
#'   inherits the preset's table-wide `na_text`; any string overrides it
#'   for this column, including `""` to force blank cells even when the
#'   preset uses a non-empty token.
#'
#'   **Tip:** Use a sentinel (`"-"`, `"NR"`, `"."`) when blank cells
#'   would be ambiguous, e.g. when "not applicable" and "not
#'   reported" both render blank.
#'
#' @param indent *Cosmetic indent depth on this column.*
#'   `<numeric(1) | character(1) | NA>: default NA`. Two modes by type:
#'
#'   *   **A non-negative whole number** — every body row of this column
#'       is indented that many levels (each level is
#'       `preset@indent_size` space-widths). `indent = 1` is the common
#'       "nudge this stub in one level" case; `indent = 0` is a real
#'       value that flattens children under a `"header_row"` section.
#'   *   **A column name (character)** — per-row depth: the engine reads
#'       `spec@data[[indent]]`, coerces each row to a non-negative
#'       integer, and prefixes that row's text + AST with
#'       `strrep(" ", preset@indent_size * depth)`. The referenced depth
#'       column is auto-hidden — no need to set `visible = FALSE` on it.
#'
#'   `NA` (default) means no indent. Backends with native padding-left
#'   (HTML / LaTeX / RTF / DOCX / PDF) emit the depth as cell padding so
#'   wrapped continuation lines align with the indented baseline;
#'   Markdown carries the literal space-prefix. Synthesised group-header
#'   rows are never indented — they are the parent at depth 0.
#'
#'   **Interaction:** an explicit `indent` on the host column of a
#'   [`group_rows()`]`(display = "header_row")` section **suppresses**
#'   that section's automatic one-level child indent (you take control
#'   of the depth) — so a stub under a section needs no `indent` at
#'   all, and adding `indent = 1` there yields a single, not double,
#'   indent.
#'
#'   Per-row SOC / PT pattern (the bundled `cdisc_saf_aesocpt` ships the
#'   canonical depth column, so no upstream construction is needed):
#'
#'   ```r
#'   cols(
#'     label    = col_spec(label = "Category", indent = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE)
#'   )
#'   ```
#'
#'   Depth-column values `c(0L, 1L, 2L, …)` produce `0`, `1`, `2`, …
#'   levels. Negative values clamp to 0 (warn); fractional numerics
#'   floor (warn); NA → 0 (silent). Works in flat listings too — a
#'   character `indent` does not require any [`group_rows()`] keys.
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
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   cdisc_saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     "Safety Population"
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' ) |>
#'   cols(
#'     variable   = col_spec(
#'       label = "Parameter",
#'       width = 2.0, align = "left"
#'     ),
#'     stat_label = col_spec(label = "Statistic", align = "left"),
#'     placebo  = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_50  = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal", na_text = "-"
#'     ),
#'     drug_100 = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal", na_text = "-"
#'     ),
#'     Total    = col_spec(
#'       label = "Total\nN={n['Total']}",
#'       align = "decimal", na_text = "-"
#'     )
#'   ) |>
#'   group_rows(by = "variable") |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # ---- Example 2: AE table with indented label + hidden helpers ----
#' #
#' # AE-by-SOC/PT table where `label` carries both the SOC and the PT
#' # text in one column, each PT indented one level under its parent
#' # SOC via `indent_level`. The hidden numeric helpers `soc_n` (the
#' # parent SOC's count, broadcast across its PT children) and
#' # `n_total` (each row's own count) drive the sort: ordering by
#' # `soc_n` descending keeps every SOC cluster together, and the
#' # `n_total` descending tiebreak floats the SOC summary row above
#' # its PTs, so the table reads SOC then its PTs, next SOC then its
#' # PTs. Demonstrates `indent` plus `visible = FALSE` for sort-only
#' # columns, fixed width on the wide label column, and decimal
#' # alignment on all four arm columns.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   cdisc_saf_aesocpt,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     "Safety Population"
#'   )
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / Preferred Term",
#'                         indent = "indent_level", width = 2.5),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))
#'
#' # ---- Example 3: Format string + na_text for clean numeric display ----
#' #
#' # `cdisc_eff_estimates` ships four competing efficacy models with
#' # pre-computed numeric estimates, 95% CI bounds (NA on the MMRM
#' # row), and a nominal p-value. `format =` pins the printed
#' # precision; `na_text` renders the missing CI bounds as a dash
#' # rather than a literal "NA". `valign = "top"` keeps the multi-
#' # line cell text aligned to the top.
#' tabular(cdisc_eff_estimates, titles = "Treatment-effect estimates by model") |>
#'   group_rows(by = "model") |>
#'   cols(
#'     model    = col_spec(label = "Model", valign = "top"),
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
#'     ),
#'     p_value  = col_spec(
#'       label   = "p-value",
#'       align   = "decimal",
#'       format  = "%.4f"
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
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' tabular(
#'   cdisc_saf_vital,
#'   titles = "Vital Signs at Baseline and End of Treatment"
#' ) |>
#'   cols(
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(label = "Parameter", width = "1.6in"),
#'     visit      = col_spec(label = "Visit", width = "1.2in",
#'                           align = "center"),
#'     stat_label = col_spec(label = "Statistic", width = "1.0in"),
#'     placebo    = col_spec(
#'       label = "Placebo\nN={n['placebo']}",
#'       align = "decimal", width = "0.9in"
#'     ),
#'     drug_50    = col_spec(
#'       label = "Drug 50\nN={n['drug_50']}",
#'       align = "decimal", width = "0.9in"
#'     ),
#'     drug_100   = col_spec(
#'       label = "Drug 100\nN={n['drug_100']}",
#'       align = "decimal", width = "0.9in"
#'     )
#'   ) |>
#'   group_rows(by = c("param", "visit"))
#'
#' # ---- Example 5: Repeating stub columns on a panelled table ----
#' #
#' # `paginate(repeat_cols = )` names the stub that repeats on each
#' # horizontal panel created by `paginate(panels = 2)` — here the
#' # grouping key `variable` plus the per-row statistic label
#' # `stat_label`, so both stay legible on every panel. On HTML /
#' # Markdown (no page width) the panels collapse into one scrollable
#' # table with a "Panel 1 / Panel 2" header note; on RTF / Word each
#' # panel is its own page with the stub repeated.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#' tabular(
#'   cdisc_saf_demo,
#'   titles = c("Table 14.1.1", "Demographics", "Safety Population")
#' ) |>
#'   cols(
#'     variable   = col_spec(label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total      = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
#'   ) |>
#'   group_rows(by = "variable", display = "column") |>
#'   paginate(panels = 2, repeat_cols = c("variable", "stat_label"))
#'
#' @seealso
#' **Companion verb:** [`cols()`] attaches `col_spec` entries to a
#' `tabular_spec` keyed by input column name.
#'
#' **Row structure:** [`group_rows()`] declares the grouping keys and
#' section rendering at table level.
#'
#' **Sibling build verbs:** [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' **Inline label formatting:** [`md()`], [`html()`].
#'
#' @export
col_spec <- function(
  label = NA_character_,
  format = NULL,
  visible = NA,
  width = "auto",
  align = NULL,
  valign = NULL,
  na_text = NA_character_,
  indent = NA
) {
  call <- rlang::caller_env()

  align_val <- .check_col_align(align, call = call)
  valign_val <- .check_col_valign(valign, call = call)
  .check_col_label(label, call = call)
  # A label whose `{expr}` references the column-stamp tokens `.name` /
  # `.col` cannot interpolate here (the column name is bound later, at
  # the cols() / cols_apply() stamp). Defer it: keep the raw template
  # and let `.resolve_deferred_label()` fill it per column. Every other
  # label interpolates eagerly in the caller env, as before.
  label_deferred <- .label_defers_to_column(label)
  if (!label_deferred) {
    label <- .interp_one(label, env = call, call = call)
  }
  visible_val <- .check_col_visible(visible, call = call)
  .check_col_width(width, call = call)
  .check_col_na_text(na_text, call = call)
  .check_col_format(format, call = call)
  indent_val <- .check_col_indent(indent, call = call)

  .col_spec_class(
    name = NA_character_,
    label = label,
    label_deferred = label_deferred,
    format = format,
    visible = visible_val,
    width = width,
    # Immutable mirror of the user's width spec. Resolution in
    # `.resolve_col_widths()` (R/col_width.R) overwrites `width`
    # with inch-resolved numeric for paper backends; `width_user`
    # stays as the original string ("40%", "2.5in", "auto", ...)
    # so the HTML backend can detect percent intent at emit time.
    width_user = width,
    align = align_val,
    valign = valign_val,
    na_text = na_text,
    indent = indent_val
  )
}

# TRUE when `label` is a plain string carrying a `{expr}` chunk that
# references the per-column stamp tokens `.name` or `.col`. Such a label
# cannot interpolate at `col_spec()` time (those names are unbound until
# `cols()` / `cols_apply()` stamps the spec onto a column), so it is
# deferred. md() / html() labels and labels with no brace never defer; a
# malformed brace string returns FALSE so the eager `.interp_one()` path
# raises the real (column-context) parse error with the caller's `call`.
.label_defers_to_column <- function(x) {
  if (inherits(x, "from_markdown") || inherits(x, "from_html")) {
    return(FALSE)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    return(FALSE)
  }
  if (!grepl("{", x, fixed = TRUE)) {
    return(FALSE)
  }
  chunks <- tryCatch(.interp_scan(x, call = NULL), error = function(e) NULL)
  if (is.null(chunks)) {
    return(FALSE)
  }
  for (ch in chunks) {
    if (!identical(ch$type, "expr")) {
      next
    }
    vars <- tryCatch(
      all.vars(parse(text = ch$value)),
      error = function(e) character()
    )
    if (any(c(".name", ".col") %in% vars)) {
      return(TRUE)
    }
  }
  FALSE
}

# Validate the `indent` argument. Two modes by type:
#   * numeric scalar N >= 0 (whole number) — fixed depth on every row;
#   * character(1) non-empty — column name to look up at resolve time.
# `NA` / `NULL` (default) mean "no indent". Length != 1, fractional or
# negative counts, non-finite, empty strings, and other types are hard
# errors, since each would silently mis-route at resolve time.
.check_col_indent <- function(x, call) {
  if (is.null(x)) {
    return(NA)
  }
  if (length(x) != 1L) {
    cli::cli_abort(
      c(
        "Bad {.arg indent}.",
        "x" = "Must be length 1, a count or a column name.",
        "i" = "Got {.obj_type_friendly {x}} of length {length(x)}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (is.na(x)) {
    return(NA)
  }
  if (is.numeric(x)) {
    if (!is.finite(x) || x < 0 || x != as.integer(x)) {
      cli::cli_abort(
        c(
          "Bad {.arg indent}.",
          "x" = "A numeric {.arg indent} must be a non-negative whole number."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(as.integer(x))
  }
  if (is.character(x)) {
    if (!nzchar(x)) {
      cli::cli_abort(
        c(
          "Bad {.arg indent}.",
          "x" = "Empty string is not a valid column name; use {.code NA} to clear."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(x)
  }
  cli::cli_abort(
    c(
      "Bad {.arg indent}.",
      "x" = "Must be a non-negative count, a column name, or {.code NA}.",
      "i" = "Got {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# ---------------------------------------------------------------------
# Per-argument validators (internal)
# ---------------------------------------------------------------------

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
  # NA / NULL is the "unset" merge sentinel (resolved to TRUE at engine
  # finalize). TRUE / FALSE are explicit and mergeable.
  if (is.null(x) || (is.logical(x) && length(x) == 1L)) {
    return(if (is.null(x)) NA else x)
  }
  cli::cli_abort(
    c(
      "{.arg visible} must be a single logical (TRUE / FALSE / NA).",
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
  # NA_character_ is the "inherit the preset na_text" sentinel; any other
  # length-1 string (including "") is an explicit override.
  if (is.character(x) && length(x) == 1L) {
    return(invisible(x))
  }
  cli::cli_abort(
    c(
      "{.arg na_text} must be a single character string or {.code NA} (length 1).",
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
