# preset.R — attach a per-spec `preset_spec` (override) or stash a
# session-default `preset_spec` consulted by every subsequent
# `tabular()` chain. The preset carries page geometry: paper size,
# orientation, margins, body font_size + family, header / footer rows,
# the rules / spacing / stripe styling knobs, decimal-alignment metric,
# and a handful of typography defaults. The render-engine geometry helpers consult the
# per-spec preset first, then the session default, then `preset_spec`
# defaults.
#
# `preset()` is per-spec and chains on the pipe (ggplot2 `theme()`
# analogue). `set_preset()` is session-scoped (ggplot2 `theme_set()`
# analogue) and is stored in `.tabular_session$preset`. The env is
# initialised once at namespace load and emptied when the namespace
# unloads — there is no on-disk persistence.

# Package-internal env holding the session default. NULL means "no
# session default attached"; engine_paginate / .effective_preset
# falls through to `preset_spec()` defaults when both the spec and
# this env are empty.
.tabular_session <- new.env(parent = emptyenv())
.tabular_session$preset <- NULL

# Knob list — mirrors the `preset_spec` S7 properties declared in
# R/aaa_class.R. Kept as a constant so the verb and the class agree
# on which knobs are first-class without a runtime introspection
# call. Matches the `.style_node_fields` pattern in R/style.R.
.preset_knob_names <- c(
  "font_size",
  "font_family",
  "orientation",
  "paper_size",
  "margins",
  "pagehead",
  "pagefoot",
  "indent_size",
  "na_text",
  "decimal_metrics",
  "decimal_markers",
  "chrome_onscreen",
  "width_mode",
  "cell_padding",
  "spacing",
  "stripe",
  "alignment",
  "rules",
  "fonts",
  "colors",
  "padding"
)

# The five named-list `preset()` knobs that lower to `style_layer`
# records on `preset_spec@style` (via `.preset_args_to_layers()`)
# rather than landing on a `preset_spec` slot. Successive calls
# append layers; layer order is precedence within the cascade
# (last-write wins per attribute at the cell). Splitting these out
# from the scalar knob set is the contract `.split_preset_knobs()`
# enforces; the lower-only flow is the post-Task-4/5 single source
# of truth for theme-level cell defaults.
.preset_lowered_knob_names <- c(
  "alignment",
  "rules",
  "fonts",
  "colors",
  "padding"
)

#' Override the render preset on a spec
#'
#' Attach a `preset_spec` to a `tabular_spec`, carrying page-geometry
#' knobs (paper, orientation, margins, body font_size + family, h-rule
#' policy, decimal metric, typography defaults). The engine consults
#' the per-spec preset first when computing the per-page row budget,
#' decimal-aligned column widths, and the chrome that the backend
#' renders around the body grid.
#'
#' @details
#'
#' **Per-spec, chained.** `preset()` is the per-spec override — a
#' verb that returns a modified spec, composable on the pipe alongside
#' [`cols()`] / [`headers()`] / [`paginate()`]. Use it when a single
#' table needs a one-off geometry (e.g. landscape A4 for one wide
#' efficacy summary inside a portfolio of portrait letter tables).
#'
#' **Merge, not replace.** A second `preset()` call merges its scalar
#' knobs onto the spec's existing preset; unspecified knobs keep
#' their prior value. The five named-list knobs (`alignment` /
#' `rules` / `fonts` / `colors` / `padding`) lower to `style_layer`
#' records on `preset@style` via `.preset_args_to_layers()`
#' (internal) and append in call order; layer order is precedence
#' within the engine cascade, so a later `preset()` call's lowered
#' attribute wins over an earlier one at the cell. Pass `.reset = TRUE`
#' to discard the existing knobs and start from `preset_spec()`
#' defaults. `preset(.spec, .reset = TRUE)` with no knobs clears the
#' per-spec override entirely (the spec then falls through to
#' [`set_preset()`] or `preset_spec()` defaults at render time).
#'
#' **Direct `preset_spec()` calls bypass lowering.** The five
#' named-list knobs are no longer slots on the `preset_spec` S7
#' class — they exist only as `preset()` / `set_preset()` arguments
#' that lower into `@style`. `preset_spec(rules = list(...))`
#' (and analogous direct calls) raise "unused argument". Wrap such
#' calls in `tabular(...) |> preset(...)` so the lowering helper
#' fires and the layers land on `@style`.
#'
#' **Cascade with `set_preset()`.** The engine resolves the active
#' preset in this order: (1) the spec's per-call preset (this verb),
#' (2) the session default attached via [`set_preset()`],
#' (3) `preset_spec()` factory defaults. The first non-NULL layer
#' wins; layers are not field-merged across the cascade.
#'
#' @param .spec *The `tabular_spec` to attach the preset to.*
#'   `<tabular_spec>: required`. Dot-prefixed so R's partial argument
#'   matching cannot accidentally bind a knob name in `...` to the
#'   spec slot.
#'
#' @param ... *Named preset knobs.* Any subset of the 13 knobs the
#'   `preset_spec` class carries. Knob values are validated against
#'   the class's enum / length / type rules; bad values raise
#'   `tabular_error_input`. Unknown knob names raise
#'   `tabular_error_input` with the recognised set listed.
#'
#'   Recognised knobs:
#'
#'   *   **`font_size`** — body point size. `<numeric(1)>`.
#'   *   **`font_family`** — body font family. `<character | character(1)>`.
#'       Default `"mono"`. Three accepted shapes:
#'
#'       1. **Generic family** — `"mono"` (default), `"serif"`,
#'          `"sans"` (CSS aliases `"monospace"` / `"sans-serif"`
#'          also recognised). The resolver expands to a per-backend
#'          chain that leads with the Linux-installed
#'          **Liberation** face (Posit Workbench / Domino / Citrix
#'          / RStudio Server), then the Microsoft Office face
#'          (Courier New / Times New Roman / Arial) for desktop
#'          Win / Mac consumers, then TeX Gyre for LaTeX compile,
#'          then the CSS generic for HTML. Liberation Mono / Serif
#'          / Sans are metric-compatible with Courier New / TNR /
#'          Arial, so layout, line breaks, and decimal alignment
#'          hold across every render context. The mono default
#'          matches the dominant submission-TFL convention where
#'          deterministic glyph widths drive `n (%)` cell alignment.
#'
#'       2. **Named alias** — `"Times"`, `"Times New Roman"`,
#'          `"Arial"`, `"Helvetica"`, `"Courier"`, `"Courier New"`.
#'          These PostScript-era names alias to the appropriate
#'          generic family (Times -> serif, Arial / Helvetica ->
#'          sans, Courier -> mono) and emit the same expanded chain.
#'          Honours the user's intent ("I want Times-like
#'          rendering") on every OS instead of hard-erroring on
#'          a Linux server with no TNR installed.
#'
#'       3. **Named font** — `"Inter"`, `"JetBrains Mono"`,
#'          `"Source Serif Pro"`, sponsor-specific face, etc.
#'          Emitted verbatim with no fallback fabricated. The
#'          consuming app (browser, xelatex, Word, LibreOffice)
#'          resolves the name against its own font matcher. RTF
#'          and DOCX fall back to the consuming app's substitution
#'          table when the name is missing; xelatex hard-errors at
#'          compile time; HTML browsers fall through to the
#'          browser's default font (not necessarily class-matched).
#'
#'       4. **Explicit stack** — `c("Inter", "Helvetica", "sans")`.
#'          User owns the chain. Returned verbatim — alias lookup
#'          is **bypassed**, so `c("Times", "Times")` honours the
#'          exact name with no chain expansion (escape hatch for
#'          users who genuinely want exact-name semantics).
#'
#'       **Note:** Adobe Source Pro is no longer the default lead.
#'       Source Pro is not pre-installed on production Linux
#'       servers, so leading with it walks through 2-3 missing
#'       names before resolving. Users who installed Source Pro
#'       can opt in via the explicit-stack form
#'       (`c("Source Serif Pro", "serif")`).
#'
#'       **What you see in Word's font dropdown vs. what renders.**
#'       When you open a tabular-generated `.rtf` in Word on
#'       macOS or Windows, the font dropdown displays the file's
#'       *requested* face — `"Liberation Mono"` by default
#'       (the Linux-server-installed face). The rendered text on
#'       screen is whatever Word's `\\*\\falt` substitution
#'       resolved to — typically Courier New on macOS /
#'       Windows. This is correct: Liberation Mono and Courier
#'       New are metric-compatible by design, so the rendered
#'       layout (line breaks, decimal alignment, page breaks) is
#'       identical regardless of which face Word actually used to
#'       render. The same `\\*\\falt` substitution model applies
#'       to serif (Liberation Serif -> Times New Roman) and sans
#'       (Liberation Sans -> Arial).
#'
#'       **How to force Office names as the primary.** If
#'       reviewers will be confused by seeing `"Liberation Mono"`
#'       in the Word font dropdown (cosmetic concern; doesn't
#'       affect rendering), pass an explicit length>1 stack with
#'       the Office name first. The resolver returns the vector
#'       verbatim — no alias lookup, no chain expansion — so the
#'       RTF file then names the Office face as primary and your
#'       chosen alternate as `\\*\\falt`:
#'
#'       ```r
#'       preset(font_family = c("Courier New", "Courier", "Liberation Mono"))
#'       ```
#'
#'       This is the canonical escape hatch for authors who know
#'       their consumer audience is Mac / Windows Word users and
#'       want the dropdown to show the Office face directly.
#'   *   **`orientation`** — page orientation.
#'       `<character(1)>`. One of `"landscape"` (default),
#'       `"portrait"`.
#'   *   **`paper_size`** — paper key.
#'       `<character(1)>`. One of `"letter"` (default), `"a4"`.
#'   *   **`margins`** — page margins in inches.
#'       `<numeric(1) | numeric(4)>`. Length 1 = all four sides;
#'       length 4 = top, right, bottom, left.
#'   *   **`pagehead`**, **`pagefoot`** — per-page header / footer
#'       band content. `<list>`. Each band is a named list with
#'       slots from `left` / `center` / `right`; every other slot
#'       name is rejected. Each slot accepts `NULL` (omit), a
#'       character scalar, a character vector (multi-row content),
#'       or an [`inline_ast`]. Empty `list()` (the default) -> no
#'       band emitted.
#'
#'       **Single-row form** (scalar slots):
#'
#'       ```r
#'       pagehead = list(
#'         left   = "Protocol: ABC-123",
#'         center = "Draft",
#'         right  = "Page {page} of {npages}"
#'       )
#'       ```
#'
#'       **Multi-row form** (vector slots, index-aligned):
#'
#'       ```r
#'       pagehead = list(
#'         left  = c("Protocol: ABC-123", "Analysis Set: Safety"),
#'         right = "Page {page} of {npages}"   # scalar -> body-edge row
#'       )
#'       ```
#'
#'       **Growth direction.** Vector index 1 = body edge; index N
#'       = far from body. `pagehead` rows stack **upward** away
#'       from the table (the row closest to the table is index 1).
#'       `pagefoot` rows stack **downward** away from the table
#'       (the row closest to the table is index 1). Shorter slots
#'       pad with `""` at the FAR end (high index), so a scalar
#'       slot naturally lands on the body-edge row.
#'
#'       **Token vocabulary** — substituted into slot text:
#'
#'       | Token            | Phase   | Expansion                              |
#'       |------------------|---------|----------------------------------------|
#'       | `{page}`         | backend | current page number (field code)       |
#'       | `{npages}`       | backend | total page count (field code)          |
#'       | `{program}`      | engine  | calling script's base name             |
#'       | `{program_path}` | engine  | calling script's full path             |
#'       | `{datetime}`     | engine  | `DDMMMYYYY HH:MM:SS` UTC (render time) |
#'
#'       `{program}`, `{program_path}`, and `{datetime}` resolve
#'       once per render (at [`as_grid()`] / [`emit()`]); `{page}`
#'       and `{npages}` resolve per page (filled in by Word /
#'       xelatex / the browser's print engine at view time). The
#'       program tokens walk a 5-mode detection chain — RStudio
#'       API, `source()` frame, Rscript / R CMD BATCH commandArgs
#'       (covers Domino + Linux batch + CI), knitr current_input,
#'       fallback `"<interactive>"`.
#'   *   **`rules`** — the single border vocabulary (replaces the old
#'       `borders` knob). String sugar `"booktabs"` (default, the
#'       clinical baseline), `"grid"`, `"frame"`, `"none"`; a single
#'       [`brdr()`] broadcast to every active rule; or a named list
#'       keyed by the nine rule names (`toprule`, `midrule`,
#'       `bottomrule`, `spanrule`, `rowrule`, `footnoterule`,
#'       `leftrule`, `rightrule`, `colrule`) — unlisted rules keep
#'       their default, and the bare string `"none"` drops one.
#'       `rules = list(rowrule = brdr())` reproduces the old
#'       `hlines = "all"`.
#'
#'       **`bottomrule` vs `footnoterule`.** These are mutually
#'       exclusive: exactly one rule sits at the data -> footnote
#'       boundary. The default is `bottomrule` (the table's bottom
#'       edge); `footnoterule` (a table-width rule opening the
#'       footnote section) is OFF by default. As a distinct
#'       footnote-section rule, `footnoterule` is drawn only by the
#'       paginated backends — **RTF, LaTeX / PDF, and DOCX**. The
#'       **HTML** backend is continuous (non-paginated) and has no
#'       separate footnote section, so it folds both into one rule:
#'       whichever of `bottomrule` / `footnoterule` is active becomes
#'       the table's bottom edge (`bottomrule` wins when both are
#'       set). Setting `footnoterule` therefore still draws a closing
#'       rule on HTML — rendered as the `bottomrule`.
#'   *   **`spacing`** — region-keyed blank-line control. A named list
#'       keyed by `title` / `body` / `subgroup` / `footnote`, each a
#'       named numeric `c(above = , below = )` (footnote: `above`
#'       only). Default is the Appendix-I one blank line above and
#'       below the title block. Two adjoining region-sides that target
#'       the same physical gap resolve to the MAX (never the sum), so a
#'       gap is never accidentally doubled.
#'   *   **`stripe`** — zebra body-row fills. A single colour (applied
#'       to even rows) or a named `c(odd = , even = )`; `NULL`
#'       (default) is off.
#'   *   **`indent_size`** — row-label indent width, in monospace-
#'       space units. `<integer(1)>`. Default `2L`. Each indent level
#'       adds this many space-widths of left padding to the cell.
#'       `0L` disables the indent prefix entirely. Backends with
#'       native padding-left semantics (HTML / LaTeX / RTF / DOCX /
#'       PDF) emit this as cell padding so wrapped continuation lines
#'       align with the indented baseline; Markdown carries the literal
#'       space-prefix.
#'       Block alignment for the title / footnote / header / subgroup /
#'       body surfaces is set via the `alignment` named-list knob
#'       (`alignment = list(title_halign = "left", ...)`), not a scalar
#'       knob; blank-line spacing is set via `spacing` (above).
#'   *   **`na_text`** — global NA fallback. `<character(1)>`.
#'   *   **`decimal_metrics`** — decimal-padding metric.
#'       `<character(1)>`. Only `"chars"` (default); the engine pads
#'       decimal columns by character count.
#'   *   **`decimal_markers`** — missing-value tokens recognised by
#'       `col_spec(align = "decimal")`. `<character>`. Default
#'       `c("NR", "NE", "NC", "ND", "BLQ")`. A cell whose trimmed
#'       value is one of these is treated as a non-numeric *marker*:
#'       it is shown and right-aligned in the column rather than
#'       parsed as a number, and a marker appearing inside a
#'       compound (e.g. the upper bound of `14.3 (11.2, NR)`) is
#'       preserved and slot-aligned. Excludes `"-"`, `"NA"`, and
#'       `"INF"`/`"-INF"` by default: `"-"` collides with range
#'       separators, `"NA"` is handled by `na_text`, and infinities
#'       are real values. Set to `character(0)` to disable marker
#'       handling.
#'   *   **`width_mode`** — table-level column-sizing policy. Mirrors
#'       Word's Table Layout menu. `<character(1)>`. One of:
#'
#'       *   **`"content"`** *(default)* — Each column auto-sized to
#'           `max(body, header)`. The table doesn't fill the page.
#'           Word's "Auto-fit Contents".
#'       *   **`"window"`** — Auto-sized columns expand to share the
#'           residual page width equally. Pinned and percent columns
#'           keep their pins. Word's "Auto-fit Window".
#'       *   **`"fixed"`** — Only explicit per-column widths drive
#'           the layout. Auto-sized columns collapse to a minimum
#'           sliver. Word's "Fixed Column Width".
#'
#'       **Interaction:** Pair with `col_spec(width = ...)` pins to
#'       drive the layout under `"window"` / `"fixed"`. Under
#'       `"content"`, pins still take priority over auto columns.
#'
#'       **HTML backend.** `width_mode` drives paper backends
#'       (LaTeX / RTF / PDF / DOCX) only. HTML is unconditionally
#'       responsive — the table always fills its parent and
#'       columns wrap when the viewport narrows, regardless of
#'       `width_mode`. Per-column widths (`col_spec(width)`) emit
#'       verbatim into the HTML colgroup per the gt convention.
#'
#'   *   **`cell_padding`** — cell padding in points, CSS shorthand of
#'       length 1 / 2 / 4 (`all` | `vertical horizontal` |
#'       `top right bottom left`), parsed by the same length rule as
#'       `margins`. `<numeric>: default c(0, 5.4)` (vertical 0,
#'       horizontal 5.4pt). The single source of truth for both auto
#'       column-width measurement (left + right) and every backend's
#'       cell margin, so measured and rendered widths agree.
#'
#'       **Interaction:** A body per-side padding override
#'       (`preset(padding = list(body = ...))` or
#'       `style(.at = cells_body(), padding = ...)`) takes precedence at
#'       both measurement and render.
#'
#'       **Note:** DOCX and LaTeX render left / right exactly; RTF
#'       (`\\trgaph` is one symmetric gap) renders the average, so the
#'       total width still matches but the two sides look equal.
#'
#'   ```r
#'   # Landscape A4, 8pt body, slim margins for one wide table.
#'   preset(
#'     orientation = "landscape",
#'     paper_size  = "a4",
#'     font_size   = 8,
#'     margins     = c(0.75, 0.5, 0.75, 0.5)
#'   )
#'   ```
#'
#' @param .template *A `preset_spec` to bulk-apply before `...`.*
#'   `<preset_spec | NULL>: default NULL`. When supplied, every knob
#'   the template has set away from its factory default feeds in as
#'   the base layer; user-supplied `...` knobs then merge on top.
#'   List-valued knobs (`rules`, `fonts`, `colors`, `padding`,
#'   `alignment`) shallow-merge per key; scalars replace. Use this
#'   to layer a house-style `preset_spec` onto a chain without
#'   restating its knobs.
#'
#' @param .style *A `style_template()` to layer onto the cascade.*
#'   `<style_template | NULL>: default NULL`. When supplied, every
#'   layer the template has accumulated via [`style()`] is replayed
#'   in order at engine time, after the per-spec [`style()`] layers
#'   on `.spec`. Use this to attach a sponsor's reusable house style
#'   to a chain without restating every per-region rule.
#'
#' @param .reset *Discard the spec's existing preset before applying
#'   `...`.* `<logical(1)>: default FALSE`. When `TRUE`, the spec's
#'   prior `preset_spec` (if any) is dropped and `...` knobs are
#'   merged onto fresh `preset_spec()` defaults. With no knobs, the
#'   per-spec preset is cleared back to NULL (the spec falls through
#'   to [`set_preset()`] or `preset_spec()` defaults).
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`paginate()`], [`style()`], then render via [`emit()`] (or
#'   resolve without I/O via [`as_grid()`]).
#'
#' @examples
#' # ---- Example 1: Landscape A4 for a wide efficacy table ----
#' #
#' # BOR table where the four-arm column block fits portrait letter
#' # with a smaller body font, but the sponsor wants A4 landscape at
#' # 8pt for visual breathing room. `preset()` attaches the geometry;
#' # `paginate()` reads it later to size the per-page row budget.
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
#'   preset(
#'     orientation = "landscape",
#'     paper_size  = "a4",
#'     font_size   = 8
#'   ) |>
#'   paginate()
#'
#' # ---- Example 2: Per-spec override with per-page chrome ----
#' #
#' # The submission session sets a portrait letter 9pt default (typical
#' # safety-table geometry). One particular AE table needs landscape
#' # for a long PT label band; the per-spec `preset()` overrides only
#' # orientation. The same per-spec call wires the canonical
#' # per-page header band (protocol on the left, page X of Y on the
#' # right) and a footer band that auto-resolves the calling
#' # script's name and the current render timestamp via the
#' # `{program}` and `{datetime}` tokens.
#' set_preset(font_size = 9, paper_size = "letter")
#'
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
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(usage = "group", visible = FALSE,
#'                         group_display = "column_repeat"),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
#'   ) |>
#'   headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   preset(
#'     orientation = "landscape",
#'     pagehead = list(
#'       left  = "Protocol: ABC-123",
#'       right = "Page {page} of {npages}"
#'     ),
#'     pagefoot = list(
#'       left  = "{program}",
#'       right = "{datetime}"
#'     )
#'   ) |>
#'   paginate(keep_together = "soc")
#'
#' # Reset the session default so subsequent examples / R sessions
#' # are not affected.
#' set_preset(.reset = TRUE)
#'
#' @seealso
#' **Session-scope partners:** [`set_preset()`], [`get_preset()`].
#'
#' **Render-geometry consumer:** [`paginate()`] derives the per-page
#' row budget from the active preset's paper, orientation, margins,
#' and font size.
#'
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`style()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
preset <- function(
  .spec,
  ...,
  .template = NULL,
  .style = NULL,
  .reset = FALSE
) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  .reset <- .check_scalar_lgl(.reset, arg = ".reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)
  .validate_lowered_knobs(knobs, call = call)
  template_knobs <- .extract_template_knobs(.template, call = call)
  template_style_layers <- .extract_template_style_layers(.template)
  style_layers <- .extract_style_template_layers(.style, call = call)

  if (
    .reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L &&
      length(template_style_layers) == 0L &&
      length(style_layers) == 0L
  ) {
    return(S7::set_props(.spec, preset = NULL))
  }
  if (
    !.reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L &&
      length(template_style_layers) == 0L &&
      length(style_layers) == 0L
  ) {
    return(.spec)
  }

  prior <- .spec@preset
  base <- if (.reset || !is_preset_spec(prior)) preset_spec() else prior

  # After the Task 4/5 slot cut, only the 15 scalar preset_spec
  # properties (font_size / paper_size / margins / pagehead / …)
  # survive as slots. The five named-list knobs (`alignment` /
  # `borders` / `fonts` / `colors` / `padding`) flow exclusively
  # through `.preset_args_to_layers()` and land on `@style` as
  # ordered `style_layer` records — there is no slot-side state to
  # merge anymore. Template knobs lower first so user knobs land
  # later and win per attribute (layer order is precedence within
  # the cascade).
  scalar_template_knobs <- .split_preset_knobs(template_knobs)$scalar
  scalar_user_knobs <- .split_preset_knobs(knobs)$scalar
  if (length(scalar_template_knobs) > 0L) {
    base <- .apply_preset_knobs(base, scalar_template_knobs, call = call)
  }
  new_preset <- if (length(scalar_user_knobs) > 0L) {
    .apply_preset_knobs(base, scalar_user_knobs, call = call)
  } else {
    base
  }
  lowered <- c(
    .preset_args_to_layers(template_knobs),
    .preset_args_to_layers(knobs)
  )
  appended <- c(template_style_layers, lowered, style_layers)
  if (length(appended) > 0L) {
    new_preset <- S7::set_props(
      new_preset,
      style = c(new_preset@style, appended)
    )
  }
  S7::set_props(.spec, preset = new_preset)
}

#' Set or clear the session default preset
#'
#' Stash a `preset_spec` in the package-internal session environment.
#' Every subsequent `tabular()` chain that does not attach its own
#' [`preset()`] inherits these knobs at render time. Mirrors ggplot2's
#' \link[ggplot2:theme_set]{\code{ggplot2::theme_set()}}: one call up front, many tables downstream.
#'
#' @details
#'
#' **Persistence.** The session preset lives in a package-internal
#' environment populated when `tabular` is loaded and emptied when the
#' namespace unloads. There is no on-disk persistence; set the
#' default at the top of each analysis script (or in a project-level
#' `.Rprofile`) when a sticky house style is needed.
#'
#' **Merge, not replace.** A second `set_preset()` call merges its
#' knobs onto the existing session preset; unspecified knobs keep
#' their prior value. Pass `.reset = TRUE` to discard the existing
#' session preset and start from `preset_spec()` defaults.
#' `set_preset(.reset = TRUE)` with no knobs clears the session
#' default back to NULL.
#'
#' **Save and restore.** Every call returns the *previous* session
#' preset invisibly, the same primitive ggplot2's
#' \link[ggplot2:theme_set]{\code{ggplot2::theme_set()}} ships. Capture it once, render, and
#' restore by passing the saved value back as the positional `new`
#' argument:
#'
#' ```r
#' old <- set_preset(font_size = 10, paper_size = "a4")
#' # ... one renegade render at 10pt A4 ...
#' set_preset(old)        # restore
#' ```
#'
#' When the prior was `NULL` (no session preset ever attached), the
#' restore is `set_preset(.reset = TRUE)` instead — `set_preset(NULL)`
#' is the same shape as `set_preset()` and falls through to factory
#' defaults rather than clearing the session.
#'
#' **Cascade with `preset()`.** A per-spec [`preset()`] always wins
#' over the session default. The session default fills in only when
#' the spec carries no preset of its own.
#'
#' @param new *A `preset_spec` to install wholesale.*
#'   `<preset_spec | NULL>: default NULL`. When non-`NULL`, replaces
#'   the session preset in one call without touching knobs. The
#'   primary use is the save/restore round-trip
#'   (`old <- set_preset(...); set_preset(old)`) — `new` accepts any
#'   `preset_spec` previously returned by `set_preset()` or
#'   [`get_preset()`].
#'
#'   Mutually exclusive with `...`, `.template`, `.style`, `.reset`:
#'   passing any of those alongside a non-`NULL` `new` raises
#'   `tabular_error_input`.
#'
#' @param ... *Named preset knobs.* Same shape as [`preset()`]; see
#'   that verb for the full list of 13 recognised knobs. Unknown
#'   names raise `tabular_error_input`. Mutually exclusive with
#'   a non-`NULL` `new`.
#'
#' @param .template *A `preset_spec` to bulk-apply before `...`.*
#'   `<preset_spec | NULL>: default NULL`. Same semantics as
#'   [`preset()`]'s `.template`: every knob set away from its factory
#'   default feeds in as the base layer; user-supplied `...` knobs
#'   then merge on top with shallow-merge per list-valued knob.
#'
#' @param .style *A `style_template()` to layer into the session
#'   default.* `<style_template | NULL>: default NULL`. Same
#'   semantics as [`preset()`]'s `.style`: the template's accumulated
#'   layers feed in as session-default style, layered before any
#'   per-spec [`style()`] calls.
#'
#' @param .reset *Discard the existing session preset before applying
#'   `...`.* `<logical(1)>: default FALSE`. With no knobs, clears
#'   the session default back to NULL.
#'
#' @return *The previous session `preset_spec` (invisible).* Returns
#'   `NULL` when no session preset was attached prior to the call.
#'   Capture it to round-trip a temporary override:
#'   `old <- set_preset(...); set_preset(old)`. Mirrors
#'   \link[ggplot2:theme_set]{\code{ggplot2::theme_set()}} and `base::options()` — the canonical
#'   tidyverse save/restore primitive.
#'
#' @examples
#' # ---- Example 1: Sticky session default for an analysis script ----
#' #
#' # The submission's safety tables all use portrait letter, 9pt
#' # Times New Roman with 1-inch margins. Set once at the top of the
#' # analysis script and every `tabular()` chain inherits it — no
#' # per-table `preset()` call needed unless one table deviates.
#' set_preset(
#'   font_size   = 9,
#'   font_family = "Times New Roman",
#'   orientation = "portrait",
#'   paper_size  = "letter",
#'   margins     = 1
#' )
#'
#' # Subsequent tabular() chains pick up the session preset at render.
#' demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_aeoverall,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Overall Summary of Adverse Events",
#'     sprintf("Safety Population (N=%d)", demo_n["Total"])
#'   ),
#'   footnotes = "Subjects counted once per category."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Category"),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
#'     Total      = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
#'   )
#'
#' # ---- Example 2: Reset the session default mid-script ----
#' #
#' # The first half of the script produces safety tables at 9pt; the
#' # second half produces efficacy tables at 10pt on landscape A4. A
#' # single `set_preset(.reset = TRUE, ...)` resets the cascade before
#' # the second batch starts.
#' set_preset(font_size = 9, paper_size = "letter")
#' get_preset()@font_size  # 9
#'
#' set_preset(
#'   .reset      = TRUE,
#'   font_size   = 10,
#'   orientation = "landscape",
#'   paper_size  = "a4"
#' )
#' get_preset()@orientation  # "landscape"
#'
#' # Reset the session default so subsequent examples / R sessions
#' # are not affected.
#' set_preset(.reset = TRUE)
#'
#' # ---- Example 3: Save and restore around a renegade table ----
#' #
#' # Most of the submission renders portrait letter at 9pt. One
#' # renegade efficacy table needs landscape A4 at 10pt. Capture
#' # the prior session preset, render the renegade, then restore.
#' set_preset(font_size = 9, paper_size = "letter")
#'
#' old <- set_preset(
#'   font_size   = 10,
#'   paper_size  = "a4",
#'   orientation = "landscape"
#' )
#' # ... one renegade render ...
#' if (is.null(old)) {
#'   set_preset(.reset = TRUE)   # was no prior — clear
#' } else {
#'   set_preset(old)              # round-trip via the positional `new` arg
#' }
#' get_preset()@paper_size  # "letter" — restored
#'
#' # ---- Example 4: Snapshot current preset, mutate, restore ----
#' #
#' # Capture whatever the session preset is right now (may be NULL),
#' # let a downstream helper mutate it, then put it back when done.
#' set_preset(font_size = 9, paper_size = "letter")
#' snapshot <- get_preset()
#'
#' # Simulate downstream code mutating session state.
#' set_preset(font_size = 11, orientation = "landscape")
#'
#' # Restore. The wholesale-install path of `set_preset(new)`
#' # accepts any `preset_spec` returned by `get_preset()` /
#' # `set_preset()`.
#' if (is.null(snapshot)) {
#'   set_preset(.reset = TRUE)
#' } else {
#'   set_preset(snapshot)
#' }
#' get_preset()@font_size    # 9 — restored
#'
#' # Reset for subsequent examples / R sessions.
#' set_preset(.reset = TRUE)
#'
#' @seealso
#' **Per-spec partner:** [`preset()`] — overrides the session
#' default on one chain.
#'
#' **Inspect:** [`get_preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
set_preset <- function(
  new = NULL,
  ...,
  .template = NULL,
  .style = NULL,
  .reset = FALSE
) {
  call <- rlang::caller_env()
  old <- .tabular_session$preset

  # ---- Wholesale-install path ----------------------------------
  # `set_preset(some_preset_spec)` swaps the session preset for a
  # prebuilt object in one call. This is the ggplot2 set_theme(new)
  # primitive that makes `set_preset(old)` the natural restore for
  # an `old <- set_preset(...)` save.
  if (!is.null(new)) {
    if (!is_preset_spec(new)) {
      cli::cli_abort(
        c(
          "{.arg new} must be a {.cls preset_spec} or {.code NULL}.",
          "x" = "You supplied {.obj_type_friendly {new}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    knobs <- rlang::list2(...)
    if (
      length(knobs) > 0L ||
        !is.null(.template) ||
        !is.null(.style) ||
        isTRUE(.reset)
    ) {
      cli::cli_abort(
        c(
          "Pass {.arg new} OR knobs / {.arg .template} / {.arg .style} / {.arg .reset}, not both.",
          "i" = "Wholesale install, {.code set_preset(spec)}.",
          "i" = "Knob update, {.code set_preset(font_size = 10)}.",
          "i" = "Restore saved, {.code set_preset(old)} after {.code old <- set_preset(...)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    .tabular_session$preset <- new
    return(invisible(old))
  }

  .reset <- .check_scalar_lgl(.reset, arg = ".reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)
  .validate_lowered_knobs(knobs, call = call)
  template_knobs <- .extract_template_knobs(.template, call = call)
  template_style_layers <- .extract_template_style_layers(.template)
  style_layers <- .extract_style_template_layers(.style, call = call)

  if (
    .reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L &&
      length(template_style_layers) == 0L &&
      length(style_layers) == 0L
  ) {
    .tabular_session$preset <- NULL
    return(invisible(old))
  }

  base <- if (.reset || !is_preset_spec(old)) preset_spec() else old

  # Mirrors `preset()`'s lower-only path for the five named-list
  # knobs — see the long comment there for the rationale.
  scalar_template_knobs <- .split_preset_knobs(template_knobs)$scalar
  scalar_user_knobs <- .split_preset_knobs(knobs)$scalar
  if (length(scalar_template_knobs) > 0L) {
    base <- .apply_preset_knobs(base, scalar_template_knobs, call = call)
  }
  new_preset <- if (length(scalar_user_knobs) > 0L) {
    .apply_preset_knobs(base, scalar_user_knobs, call = call)
  } else {
    base
  }
  lowered <- c(
    .preset_args_to_layers(template_knobs),
    .preset_args_to_layers(knobs)
  )
  appended <- c(template_style_layers, lowered, style_layers)
  if (length(appended) > 0L) {
    new_preset <- S7::set_props(
      new_preset,
      style = c(new_preset@style, appended)
    )
  }
  .tabular_session$preset <- new_preset
  invisible(old)
}

#' Get the active session-default preset
#'
#' Return the `preset_spec` last attached via [`set_preset()`], or
#' `NULL` when no session default has been set. The cascade resolver
#' calls this internally; users call it for diagnostics ("what is my
#' session inheriting?") or to copy the active default into a
#' per-spec override via [`preset()`].
#'
#' @return *A `preset_spec`*, or `NULL` when no session default is
#'   active.
#'
#' @examples
#' # ---- Example 1: Inspect after setting a session default ----
#' #
#' # `get_preset()` returns NULL before any session default has been
#' # attached, then returns the `preset_spec` after `set_preset()`.
#' get_preset()  # NULL
#'
#' set_preset(font_size = 8, orientation = "landscape")
#'
#' active <- get_preset()
#' is_preset_spec(active)     # TRUE
#' active@font_size            # 8
#' active@orientation          # "landscape"
#'
#' # ---- Example 2: Copy the session default into a per-spec override ----
#' #
#' # Read the session preset, tweak one knob for a single table, and
#' # attach as a per-spec override without disturbing the session.
#' set_preset(font_size = 9, paper_size = "letter")
#'
#' # Read-tweak-attach without mutating the session default.
#' base_knobs <- get_preset()
#' tabular(saf_n) |>
#'   preset(
#'     font_size   = base_knobs@font_size,
#'     paper_size  = base_knobs@paper_size,
#'     orientation = "landscape"
#'   )
#'
#' # Reset the session default so subsequent examples / R sessions
#' # are not affected.
#' set_preset(.reset = TRUE)
#'
#' @seealso
#' **Session-scope setter:** [`set_preset()`].
#'
#' **Per-spec partner:** [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
get_preset <- function() {
  .tabular_session$preset
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Validate that every name in `knobs` is a recognised preset_spec
# knob. Empty knobs list passes through; otherwise abort with the
# recognised set listed.
.check_preset_knob_names <- function(knobs, call) {
  if (length(knobs) == 0L) {
    return(invisible())
  }
  knob_names <- names(knobs)
  if (
    is.null(knob_names) ||
      any(!nzchar(knob_names)) ||
      anyNA(knob_names)
  ) {
    cli::cli_abort(
      c(
        "All preset knobs must be named.",
        "i" = "Use {.code knob = value} for every knob."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  unknown <- setdiff(knob_names, .preset_knob_names)
  if (length(unknown) > 0L) {
    known <- .preset_knob_names
    cli::cli_abort(
      c(
        "Unknown preset knob{?s}: {.val {unknown}}.",
        "i" = "Recognised knobs: {.val {known}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible()
}

# Merge scalar `knobs` onto a base preset_spec via S7::set_props.
# Callers must split named-list knobs (`alignment` / `borders` /
# `fonts` / `colors` / `padding`) out first via `.split_preset_knobs()`
# — those flow through `.preset_args_to_layers()` and never reach a
# slot. The S7 property validators run on the constructed object;
# any bad value (wrong enum, wrong length, wrong type) raises a
# base R error that we re-throw as tabular_error_input with the
# underlying message.
.apply_preset_knobs <- function(base, knobs, call) {
  tryCatch(
    do.call(S7::set_props, c(list(base), knobs)),
    error = function(e) {
      cli::cli_abort(
        c(
          "Invalid preset knob value.",
          "x" = "{conditionMessage(e)}"
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  )
}

# Partition a named knob list into the scalar half (slot-bound) and
# the lowered half (`alignment` / `borders` / `fonts` / `colors` /
# `padding`). Callers route each half through the matching
# downstream pipeline.
.split_preset_knobs <- function(knobs) {
  if (length(knobs) == 0L) {
    return(list(scalar = list(), lowered = list()))
  }
  is_lowered <- names(knobs) %in% .preset_lowered_knob_names
  list(
    scalar = knobs[!is_lowered],
    lowered = knobs[is_lowered]
  )
}

# Run the call-time shape validators for the five lowered knobs.
# After the Task 4/5 cut, the S7 validator on `preset_spec` no
# longer sees these values (they bypass the slot path entirely), so
# the same shape errors that used to surface from `S7::set_props`
# must be raised here before lowering touches the layer cascade.
.validate_lowered_knobs <- function(knobs, call) {
  if (length(knobs) == 0L) {
    return(invisible())
  }
  validators <- list(
    alignment = .preset_alignment_shape_error,
    rules = .preset_rules_shape_error,
    fonts = .preset_fonts_shape_error,
    colors = .preset_colors_shape_error,
    padding = .preset_padding_shape_error
  )
  for (knob in intersect(names(knobs), names(validators))) {
    v <- knobs[[knob]]
    if (is.null(v) || length(v) == 0L) {
      next
    }
    err <- validators[[knob]](v)
    if (!is.null(err)) {
      cli::cli_abort(
        c(
          "Invalid {.code {knob}} value for {.fn preset}.",
          "x" = "@{knob} {err}"
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  invisible()
}

# Convert a `preset_spec` template (or NULL) into a named-list of
# scalar knob values that DIFFER from `preset_spec()` factory
# defaults. This is what makes `preset(template = ...)`
# non-destructive: only the template author's deliberate overrides
# feed into the cascade; factory-default knobs on the template
# (e.g. `font_size = 9` when the user never customised it) leave
# the prior preset's value alone.
#
# After the Task 4/5 slot cut, the five named-list knobs
# (`alignment` / `borders` / `fonts` / `colors` / `padding`) have
# no slot on `preset_spec` to extract from — their template-side
# state lives entirely on `@style` (one `style_layer` per knob
# argument) and is propagated by `.extract_template_style_layers()`.
#
# Comparison memoises the factory `preset_spec()` once in the
# session env so we don't reconstruct it on every preset call.
.extract_template_knobs <- function(template, call) {
  if (is.null(template)) {
    return(list())
  }
  if (!is_preset_spec(template)) {
    cli::cli_abort(
      c(
        "{.arg template} must be a {.cls preset_spec} or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {template}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  factory <- .preset_factory_default_spec()
  scalar_names <- setdiff(.preset_knob_names, .preset_lowered_knob_names)
  out <- list()
  for (nm in scalar_names) {
    v <- S7::prop(template, nm)
    f <- S7::prop(factory, nm)
    if (!identical(v, f)) {
      out[[nm]] <- v
    }
  }
  out
}

# Extract a template `preset_spec`'s `@style` layers — already-lowered
# `style_layer` records carrying its named-list knob state and any
# attached `style_template()`. Returns an empty list for NULL.
# Callers append these onto the prior preset's `@style` before the
# user's own `...` knobs lower; that ordering preserves the
# "template defaults, user knobs win" semantics.
.extract_template_style_layers <- function(template) {
  if (is.null(template) || !is_preset_spec(template)) {
    return(list())
  }
  template@style
}

# Extract a list of `style_layer` records from a
# `tabular_style_template` (built by [`style_template()`]). Returns
# an empty list when `style` is NULL; aborts otherwise on a
# non-template input. Used by `preset()` and `set_preset()` to flow
# house-style layers into `preset_spec@style`.
.extract_style_template_layers <- function(style, call) {
  if (is.null(style)) {
    return(list())
  }
  if (!is_style_template(style)) {
    cli::cli_abort(
      c(
        "{.arg style} must be a {.cls tabular_style_template} or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {style}}.",
        "i" = "Build one with {.fn style_template} then chain through {.fn style}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  style$layers
}

# Memoised factory preset_spec — used by `.extract_template_knobs`
# to decide which template knobs are deliberate overrides.
.preset_factory_defaults_env <- new.env(parent = emptyenv())
.preset_factory_default_spec <- function() {
  if (is.null(.preset_factory_defaults_env$preset)) {
    .preset_factory_defaults_env$preset <- preset_spec()
  }
  .preset_factory_defaults_env$preset
}

# ---------------------------------------------------------------------
# Table-wide font defaults read from the scalar `preset_spec` slots.
# After the Task 4/5 cut, surface-specific font / colour / padding
# overrides live on `cells_style[r,c]` and `chrome_style$surfaces`
# (populated from the lowered layer cascade); these helpers exist
# only to give the backends a NULL-safe accessor for the table-wide
# default that flows into preamble / colortbl / `\fontsize` / CSS
# `<table>`-element-level emission.

.effective_font_family <- function(preset) {
  if (!is_preset_spec(preset)) {
    return(preset_spec()@font_family)
  }
  preset@font_family
}

.effective_font_size <- function(preset) {
  if (!is_preset_spec(preset)) {
    return(preset_spec()@font_size)
  }
  preset@font_size
}

# ---------------------------------------------------------------------
# .preset_args_to_layers — lower the five named-list `preset()` /
# `set_preset()` args (`alignment`, `borders`, `fonts`, `colors`,
# `padding`) to a list of `style_layer` records that flow through the
# unified `engine_style` / `engine_borders` / `engine_chrome_borders`
# cascade. Used by `preset()` / `set_preset()` to compose theme-level
# defaults into the same layer surface as `style(at = cells_*())`
# without parallel storage on `preset_spec`.
#
# Mapping summary (one layer per non-NULL entry; per-cell scope unless
# noted):
#
#   alignment$title_halign       -> cells_title()          halign
#   alignment$footnote_halign    -> cells_footnotes()      halign
#   alignment$subgroup_halign    -> cells_subgroup_labels()halign
#   alignment$header_halign      -> cells_headers()        halign
#   alignment$body_halign        -> cells_body()           halign
#   (same shape for *_valign)
#   borders$outer*               -> cells_table(side=...)  border_*_*
#   borders$body_top|body_bottom -> cells_table(side="outer_top|outer_bottom")
#   borders$body_rows            -> cells_table(side="rows")
#   borders$body_cols            -> cells_table(side="cols")
#   borders$pagehead_bottom      -> cells_pagehead()       border_bottom
#   borders$header_top|bottom    -> cells_headers()        border_top|bottom
#   borders$header_between       -> cells_headers()        border_top (alias)
#   borders$subgroup_top|bottom  -> cells_subgroup_labels()border_top|bottom
#   borders$subgroup (alias)     -> cells_subgroup_labels()border_bottom
#   borders$footer_top|bottom    -> cells_footnotes()      border_top|bottom
#   borders$pagefoot_top         -> cells_pagefoot()       border_top
#   fonts[<surface>]$family|size -> cells_<surface>()      font_family|font_size
#   colors$text                  -> cells_body()           color
#   colors$background            -> cells_body()           background
#   colors$border                -> cells_table(side="outer") + ("rows") + ("cols")
#   padding[<surface>]           -> cells_<surface>()      padding (scalar only)
#
# Per-side padding (`padding = list(body = c(top = 1, ...))`) lowers
# each named side to the matching `style_node@padding_<side>` scalar
# (the four-sided shape is fully expressible; no averaging). A bare
# scalar (`padding = list(body = 4)`) broadcasts to all four sides.
.preset_args_to_layers <- function(args) {
  layers <- list()
  for (knob in c("alignment", "rules", "fonts", "colors", "padding")) {
    val <- args[[knob]]
    if (is.null(val) || length(val) == 0L) {
      next
    }
    new <- switch(
      knob,
      alignment = .preset_alignment_to_layers(val),
      rules = .preset_rules_to_layers(val),
      fonts = .preset_fonts_to_layers(val),
      colors = .preset_colors_to_layers(val),
      padding = .preset_padding_to_layers(val)
    )
    if (length(new) > 0L) {
      layers <- c(layers, new)
    }
  }
  layers
}

# Surface -> `cells_*()` constructor for the per-surface knobs
# (fonts / padding). Keys mirror `.preset_font_surfaces` /
# `.preset_padding_surfaces` from `R/aaa_class.R`: body / header /
# titles / footnotes / subgroup. Alignment routes via its own
# key-to-surface map inside `.preset_alignment_to_layers()`.
.preset_surface_to_location <- function(surface) {
  switch(
    surface,
    body = cells_body(),
    header = cells_headers(),
    titles = cells_title(),
    footnotes = cells_footnotes(),
    subgroup = cells_subgroup_labels(),
    NULL
  )
}

# Build one style_layer with a single attribute set. Attribute names
# must match `style_node` properties (e.g. "halign", "font_family",
# "padding"). Returns NULL when `value` is NA / empty so callers can
# `c()` without filtering.
.preset_layer_one <- function(location, attr, value) {
  if (is.null(location) || is.null(value)) {
    return(NULL)
  }
  if (length(value) == 0L) {
    return(NULL)
  }
  # For halign/valign and font_family/color/background, NA / "" is
  # a no-op; for numerics (padding, font_size), NA is a no-op.
  if (is.character(value) && (anyNA(value) || all(!nzchar(value)))) {
    return(NULL)
  }
  if (is.numeric(value) && anyNA(value)) {
    return(NULL)
  }
  # Use the first element when a vector slipped through (vector-form
  # alignment); upstream lowering already documented this loss.
  v <- if (length(value) > 1L) value[[1L]] else value
  args <- list(style_node())
  args[[attr]] <- v
  node <- do.call(S7::set_props, args)
  style_layer(location = location, style = node)
}

# Build one style_layer carrying one border triple on a given side
# (`top` / `bottom` / `left` / `right`). `triple` is the unwrapped
# `list(style, width, color)` produced by `.as_brdr_triple()`.
.preset_layer_border <- function(location, side, triple) {
  if (is.null(location) || is.null(triple)) {
    return(NULL)
  }
  prop_style <- paste0("border_", side, "_style")
  prop_width <- paste0("border_", side, "_width")
  prop_color <- paste0("border_", side, "_color")
  args <- list(style_node())
  args[[prop_style]] <- if (is.null(triple$style) || is.na(triple$style)) {
    NA_character_
  } else {
    as.character(triple$style)
  }
  args[[prop_width]] <- if (is.null(triple$width) || is.na(triple$width)) {
    NA_real_
  } else {
    as.numeric(triple$width)
  }
  args[[prop_color]] <- if (is.null(triple$color) || is.na(triple$color)) {
    NA_character_
  } else {
    as.character(triple$color)
  }
  node <- do.call(S7::set_props, args)
  style_layer(location = location, style = node)
}

# alignment named-list -> per-surface halign/valign layers.
.preset_alignment_to_layers <- function(al) {
  if (!is.list(al)) {
    return(list())
  }
  surface_for_key <- c(
    title_halign = "title",
    title_valign = "title",
    footnote_halign = "footer",
    footnote_valign = "footer",
    subgroup_halign = "subgroup",
    subgroup_valign = "subgroup",
    header_halign = "header",
    header_valign = "header",
    body_halign = "body",
    body_valign = "body"
  )
  layers <- list()
  for (key in intersect(names(al), names(surface_for_key))) {
    surface <- surface_for_key[[key]]
    location <- switch(
      surface,
      title = cells_title(),
      footer = cells_footnotes(),
      subgroup = cells_subgroup_labels(),
      header = cells_headers(),
      body = cells_body()
    )
    attr <- if (endsWith(key, "_halign")) "halign" else "valign"
    layer <- .preset_layer_one(location, attr, al[[key]])
    if (!is.null(layer)) {
      layers <- c(layers, list(layer))
    }
  }
  layers
}

# rules knob -> per-rule border layers. The nine rules are the single
# border vocabulary; `resolve_rules()` expands the knob (string sugar /
# single-brdr broadcast / named-list overlay) into a fixed nine-entry
# list of resolved triples (or NULL = off). Each rule lowers to one
# layer: an ON rule carries its triple; an OFF rule carries the
# explicit-clear sentinel (style = "none") so it OVERRIDES the
# injected booktabs baseline (`.default_rule_layers()`).
#
# Rule -> (location, edge):
#   toprule      -> cells_headers   header_top      (border_top)
#   midrule      -> cells_headers   header_bottom   (border_bottom)
#   spanrule     -> cells_headers   header_between  (border_top)
#   footnoterule -> cells_footnotes footer_top      (border_top)
#   bottomrule   -> cells_table(outer_bottom)       (border_bottom)
#   rowrule      -> cells_table(rows)               (border_top)
#   leftrule     -> cells_table(outer_left)         (border_left)
#   rightrule    -> cells_table(outer_right)        (border_right)
#   colrule      -> cells_table(cols)               (border_left)
.preset_rules_to_layers <- function(ru, clear_off = TRUE) {
  resolved <- resolve_rules(ru)
  layers <- list()
  add <- function(layer) {
    if (!is.null(layer)) {
      layers[[length(layers) + 1L]] <<- layer
    }
  }
  # An ON rule carries its triple. An OFF rule carries an explicit-clear
  # sentinel ONLY when `clear_off` (the user-knob path), so it overrides
  # the injected booktabs default. The default-injection path passes
  # `clear_off = FALSE` and returns NULL for off rules, leaving those
  # cell sides untouched (NA) instead of stamping "none" everywhere.
  triple_of <- function(key) {
    r <- resolved[[key]]
    if (is.null(r)) {
      if (clear_off) {
        list(style = "none", width = 0, color = NA_character_)
      } else {
        NULL
      }
    } else {
      r
    }
  }
  # Body rules (cells_table edges / separators).
  add(.preset_layer_table_border("outer_bottom", triple_of("bottomrule")))
  add(.preset_layer_table_border("rows", triple_of("rowrule")))
  add(.preset_layer_table_border("outer_left", triple_of("leftrule")))
  add(.preset_layer_table_border("outer_right", triple_of("rightrule")))
  add(.preset_layer_table_border("cols", triple_of("colrule")))
  # Chrome rules (header / footnote bands), targeted by chrome_region.
  add(.preset_layer_chrome_rule(
    "headers",
    "header_top",
    "top",
    triple_of("toprule")
  ))
  add(.preset_layer_chrome_rule(
    "headers",
    "header_bottom",
    "bottom",
    triple_of("midrule")
  ))
  add(.preset_layer_chrome_rule(
    "headers",
    "header_between",
    "top",
    triple_of("spanrule")
  ))
  add(.preset_layer_chrome_rule(
    "footnotes",
    "footer_top",
    "top",
    triple_of("footnoterule")
  ))
  layers
}

# Build one chrome rule layer whose location carries an explicit
# `chrome_region` tag (so `.apply_chrome_layer()` writes that exact
# region, bypassing the border-side heuristic that conflates
# header_top / header_between).
.preset_layer_chrome_rule <- function(surface, region, side, triple) {
  .preset_layer_border(
    location = .new_location(surface = surface, chrome_region = region),
    side = side,
    triple = triple
  )
}

# The booktabs baseline lowered to layers. Injected as the lowest-
# precedence layer source by `.collect_table_layers()` /
# `.collect_chrome_layers()` so every table gets the clinical default
# rules even with no `rules` knob; a user `rules` knob or `style()`
# layer overrides via later cascade position.
.default_rule_layers <- function() {
  .preset_rules_to_layers("booktabs", clear_off = FALSE)
}

# Build one `cells_table(side = ...)` layer carrying a per-side
# border triple. The location surface uses the per-side `side` key
# (`outer_top` / `outer_bottom` / `outer_left` / `outer_right` /
# `rows` / `cols`) so engine_borders' `.apply_table_layer()` knows
# which edge / separator family to stamp. The style_node carries
# the matching `border_<scalar-side>_*` triple — the scalar side is
# `top` / `bottom` / `left` / `right` (rows/cols decay to top/left).
.preset_layer_table_border <- function(side, triple) {
  if (is.null(triple)) {
    return(NULL)
  }
  scalar_side <- switch(
    side,
    outer_top = "top",
    outer_bottom = "bottom",
    outer_left = "left",
    outer_right = "right",
    rows = "top",
    cols = "left",
    NULL
  )
  if (is.null(scalar_side)) {
    return(NULL)
  }
  .preset_layer_border(
    location = cells_table(side = side),
    side = scalar_side,
    triple = triple
  )
}

# fonts named-list -> per-surface font_family / font_size layers.
# `weight` is mapped to bold = TRUE when the value is "bold"; other
# weight keywords are dropped silently (style_node has no general
# weight slot).
.preset_fonts_to_layers <- function(fn) {
  if (!is.list(fn)) {
    return(list())
  }
  layers <- list()
  for (surface in names(fn)) {
    spec <- fn[[surface]]
    # Inner spec is a named ATOMIC vector c(family = , size = , weight = ).
    # `fonts` is the one mixed-type knob: a homogeneous vector cannot hold
    # character family/weight beside numeric size, so we accept either a
    # character vector (c(family = "Inter", size = "9")) or a numeric one
    # (c(size = 9)) and coerce each field at read. The shape validator
    # rejects the legacy nested-list form upstream.
    if (is.null(spec) || !is.atomic(spec) || is.null(names(spec))) {
      next
    }
    location <- .preset_surface_to_location(surface)
    if (is.null(location)) {
      next
    }
    family <- if ("family" %in% names(spec)) {
      as.character(spec[["family"]])
    } else {
      NULL
    }
    weight <- if ("weight" %in% names(spec)) {
      as.character(spec[["weight"]])
    } else {
      NULL
    }
    size <- NA_real_
    if ("size" %in% names(spec)) {
      size <- suppressWarnings(as.numeric(spec[["size"]]))
      if (!is.finite(size) || size <= 0) {
        size <- NA_real_
      }
    }
    fam_layer <- .preset_layer_one(location, "font_family", family)
    if (!is.null(fam_layer)) {
      layers <- c(layers, list(fam_layer))
    }
    sz_layer <- .preset_layer_one(location, "font_size", size)
    if (!is.null(sz_layer)) {
      layers <- c(layers, list(sz_layer))
    }
    if (
      is.character(weight) &&
        length(weight) == 1L &&
        !is.na(weight) &&
        identical(tolower(weight), "bold")
    ) {
      bold_layer <- .preset_layer_one(location, "bold", TRUE)
      if (!is.null(bold_layer)) {
        layers <- c(layers, list(bold_layer))
      }
    }
  }
  layers
}

# colors named-list -> per-surface color / background layers. Region-
# keyed for parity with the `fonts` / `padding` surface set; each inner
# spec is a named character vector:
# `colors = list(body = c(text = , background = ), header = c(...),
# titles = , footnotes = , subgroup = )`. Each surface lowers its
# `text` -> `color` and `background` to a `cells_<surface>()` layer.
.preset_colors_to_layers <- function(co) {
  if (!is.list(co)) {
    return(list())
  }
  layers <- list()
  for (surface in names(co)) {
    spec <- co[[surface]]
    # Inner spec is a named character vector c(text = , background = ).
    # The shape validator rejects the legacy nested-list form upstream;
    # this is the defensive skip for anything that slips past.
    if (is.null(spec) || !is.character(spec) || is.null(names(spec))) {
      next
    }
    location <- .preset_surface_to_location(surface)
    if (is.null(location)) {
      next
    }
    txt_val <- if ("text" %in% names(spec)) spec[["text"]] else NULL
    txt <- .preset_layer_one(location, "color", txt_val)
    if (!is.null(txt)) {
      layers <- c(layers, list(txt))
    }
    bg_val <- if ("background" %in% names(spec)) {
      spec[["background"]]
    } else {
      NULL
    }
    bg <- .preset_layer_one(location, "background", bg_val)
    if (!is.null(bg)) {
      layers <- c(layers, list(bg))
    }
  }
  layers
}

# Expand a padding knob value to a named numeric c(top, right, bottom,
# left); unset sides are NA (inherit). A scalar applies to all four.
.padding_sides <- function(val) {
  # Unnamed scalar broadcasts to all four sides.
  if (
    is.numeric(val) && length(val) == 1L && is.null(names(val)) && !is.na(val)
  ) {
    return(c(top = val, right = val, bottom = val, left = val))
  }
  # Named numeric vector c(top = , right = , bottom = , left = ); any
  # subset. Unset sides stay NA (inherit). `intersect` keeps the loop
  # to present names, so val[[s]] never indexes an absent key.
  out <- c(
    top = NA_real_,
    right = NA_real_,
    bottom = NA_real_,
    left = NA_real_
  )
  if (is.numeric(val) && !is.null(names(val))) {
    for (s in intersect(names(val), c("top", "right", "bottom", "left"))) {
      out[[s]] <- as.numeric(val[[s]])
    }
  }
  out
}

# Build one style_layer carrying per-side padding scalars. Returns
# NULL when every side is NA (nothing to set).
.preset_layer_padding <- function(location, sides) {
  if (is.null(location) || all(is.na(sides))) {
    return(NULL)
  }
  args <- list(style_node())
  for (s in c("top", "right", "bottom", "left")) {
    if (!is.na(sides[[s]])) {
      args[[paste0("padding_", s)]] <- as.numeric(sides[[s]])
    }
  }
  node <- do.call(S7::set_props, args)
  style_layer(location = location, style = node)
}

# padding named-list -> per-surface, per-side padding layers. A scalar
# expands to all four sides; a per-side list maps to the matching
# padding_<side> scalars WITHOUT averaging (the four-sided shape is now
# fully expressible on style_node).
.preset_padding_to_layers <- function(pa) {
  if (!is.list(pa)) {
    return(list())
  }
  layers <- list()
  for (surface in names(pa)) {
    val <- pa[[surface]]
    if (is.null(val)) {
      next
    }
    location <- .preset_surface_to_location(surface)
    if (is.null(location)) {
      next
    }
    layer <- .preset_layer_padding(location, .padding_sides(val))
    if (!is.null(layer)) {
      layers <- c(layers, list(layer))
    }
  }
  layers
}
