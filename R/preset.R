# preset.R — attach a per-spec `preset_spec` (override) or stash a
# session-default `preset_spec` consulted by every subsequent
# `tabular()` chain. The preset carries page geometry: paper size,
# orientation, margins, body font_size + family, header / footer rows,
# horizontal-rule policy, decimal-alignment metric, and a handful of
# typography defaults. The render-engine geometry helpers consult the
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
  "hlines",
  "indent_chars",
  "title_align",
  "footnote_align",
  "na_text",
  "decimal_metrics",
  "chrome_onscreen",
  "alignment",
  "borders",
  "fonts",
  "colors",
  "padding"
)

# List-valued knobs on `preset_spec` that should SHALLOW-MERGE across
# successive `preset()` / `set_preset()` calls (last-write-wins per
# key), rather than the default whole-value replace. Each entry in
# `knobs[[name]]` is merged onto `prior[[name]]` so a user can layer
# `preset(alignment = list(title_halign = "left"))` on top of an
# existing alignment list without erasing the other keys.
.preset_list_merged_knobs <- c(
  "alignment",
  "borders",
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
#' **Merge, not replace.** A second `preset()` call merges its knobs
#' onto the spec's existing preset; unspecified knobs keep their prior
#' value. Pass `reset = TRUE` to discard the existing knobs and start
#' from `preset_spec()` defaults. `preset(spec, reset = TRUE)` with no
#' knobs clears the per-spec override entirely (the spec then falls
#' through to [`set_preset()`] or `preset_spec()` defaults at render
#' time).
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
#'       Default `"serif"`. Three accepted shapes:
#'
#'       1. **Generic family** — `"serif"` (default), `"sans"`,
#'          `"mono"` (CSS aliases `"sans-serif"` / `"monospace"`
#'          also recognised). The resolver expands to a per-backend
#'          chain that leads with the Linux-installed
#'          **Liberation** face (Posit Workbench / Domino / Citrix
#'          / RStudio Server), then the Microsoft Office face
#'          (Times New Roman / Arial / Courier New) for desktop
#'          Win / Mac consumers, then TeX Gyre for LaTeX compile,
#'          then the CSS generic for HTML. Liberation Serif /
#'          Sans / Mono are metric-compatible with TNR / Arial /
#'          Courier New, so layout, line breaks, and decimal
#'          alignment hold across every render context.
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
#'       *requested* face — `"Liberation Serif"` by default
#'       (the Linux-server-installed face). The rendered text on
#'       screen is whatever Word's `\\*\\falt` substitution
#'       resolved to — typically Times New Roman on macOS /
#'       Windows. This is correct: Liberation Serif and Times
#'       New Roman are metric-compatible by design, so the
#'       rendered layout (line breaks, decimal alignment, page
#'       breaks) is identical regardless of which face Word
#'       actually used to render. The same `\\*\\falt`
#'       substitution model applies to sans (Liberation Sans -> Arial)
#'       and mono (Liberation Mono -> Courier New).
#'
#'       **How to force Office names as the primary.** If
#'       reviewers will be confused by seeing `"Liberation Serif"`
#'       in the Word font dropdown (cosmetic concern; doesn't
#'       affect rendering), pass an explicit length>1 stack with
#'       the Office name first. The resolver returns the vector
#'       verbatim — no alias lookup, no chain expansion — so the
#'       RTF file then names the Office face as primary and your
#'       chosen alternate as `\\*\\falt`:
#'
#'       ```r
#'       preset(font_family = c("Times New Roman", "Times", "Liberation Serif"))
#'       ```
#'
#'       This is the canonical escape hatch for authors who know
#'       their consumer audience is Mac / Windows Word users and
#'       want the dropdown to show the Office face directly.
#'   *   **`orientation`** — page orientation.
#'       `<character(1)>`. One of `"portrait"` (default),
#'       `"landscape"`.
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
#'   *   **`hlines`** — horizontal-rule policy.
#'       `<character(1)>`. One of `"header"` (default), `"none"`,
#'       `"all"`.
#'   *   **`indent_chars`** — row-label indent prefix.
#'       `<character(1)>`. Default `"  "`.
#'   *   **`title_align`**, **`footnote_align`** — block alignment.
#'       `<character(1)>`. One of `"left"`, `"center"`, `"right"`.
#'   *   **`na_text`** — global NA fallback. `<character(1)>`.
#'   *   **`decimal_metrics`** *(experimental)* — reserved knob
#'       for future em-aware decimal-padding refinement.
#'       `<character(1)>`. One of `"afm"` *(default)* or
#'       `"systemfonts"`. Currently neither value affects
#'       rendering; the engine pads decimal columns by character
#'       count regardless. Roadmapped for em-unit prefix
#'       measurement in a later release.
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
#' @param template *A `preset_spec` to bulk-apply before `...`.*
#'   `<preset_spec | NULL>: default NULL`. When supplied, every knob
#'   the template has set away from its factory default feeds in as
#'   the base layer; user-supplied `...` knobs then merge on top.
#'   List-valued knobs (`borders`, `fonts`, `colors`, `padding`,
#'   `alignment`) shallow-merge per key; scalars replace. Use this
#'   to layer a house-style `preset_spec` onto a chain without
#'   restating its knobs.
#'
#' @param reset *Discard the spec's existing preset before applying
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
#'     soc      = col_spec(usage = "group", label = "SOC / PT"),
#'     pt       = col_spec(visible = FALSE),
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
#' set_preset(reset = TRUE)
#'
#' @seealso
#' **Session-scope partners:** [`set_preset()`], [`get_preset()`].
#'
#' **Render-geometry consumer:** [`paginate()`] derives the per-page
#' row budget from the active preset's paper, orientation, margins,
#' and font size.
#'
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`derive()`], [`style()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
preset <- function(.spec, ..., template = NULL, reset = FALSE) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  reset <- .check_scalar_lgl(reset, arg = "reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)
  template_knobs <- .extract_template_knobs(template, call = call)

  if (
    reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L
  ) {
    return(S7::set_props(.spec, preset = NULL))
  }
  if (
    !reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L
  ) {
    return(.spec)
  }

  prior <- .spec@preset
  base <- if (reset || !is_preset_spec(prior)) preset_spec() else prior

  # Two-pass application so list-valued knobs (borders / fonts /
  # colors / padding / alignment) merge cleanly:
  #
  #   1. template -> base   (shallow-merge each list-valued knob;
  #                          scalars replace)
  #   2. user ...  -> base  (same semantics; user wins for keys
  #                          they touched, template values for the
  #                          rest survive)
  #
  # This is the ggplot2 `theme(... ) + theme(panel.grid = ...)`
  # composition pattern: each call adds to what the prior layer
  # built up, and `borders = list(...)` callers can layer one-off
  # region overrides onto a house-style template without restating
  # the others.
  if (length(template_knobs) > 0L) {
    base <- .apply_preset_knobs(base, template_knobs, call = call)
  }
  new_preset <- if (length(knobs) > 0L) {
    .apply_preset_knobs(base, knobs, call = call)
  } else {
    base
  }
  S7::set_props(.spec, preset = new_preset)
}

#' Set or clear the session default preset
#'
#' Stash a `preset_spec` in the package-internal session environment.
#' Every subsequent `tabular()` chain that does not attach its own
#' [`preset()`] inherits these knobs at render time. Mirrors ggplot2's
#' [`ggplot2::theme_set()`]: one call up front, many tables downstream.
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
#' their prior value. Pass `reset = TRUE` to discard the existing
#' session preset and start from `preset_spec()` defaults.
#' `set_preset(reset = TRUE)` with no knobs clears the session
#' default back to NULL.
#'
#' **Cascade with `preset()`.** A per-spec [`preset()`] always wins
#' over the session default. The session default fills in only when
#' the spec carries no preset of its own.
#'
#' @param ... *Named preset knobs.* Same shape as [`preset()`]; see
#'   that verb for the full list of 13 recognised knobs. Unknown
#'   names raise `tabular_error_input`.
#'
#' @param template *A `preset_spec` to bulk-apply before `...`.*
#'   `<preset_spec | NULL>: default NULL`. Same semantics as
#'   [`preset()`]'s `template`: every knob set away from its factory
#'   default feeds in as the base layer; user-supplied `...` knobs
#'   then merge on top with shallow-merge per list-valued knob.
#'
#' @param reset *Discard the existing session preset before applying
#'   `...`.* `<logical(1)>: default FALSE`. With no knobs, clears
#'   the session default back to NULL.
#'
#' @return Invisibly returns the new session `preset_spec` (or NULL
#'   when the call cleared the default).
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
#' # single `set_preset(reset = TRUE, ...)` resets the cascade before
#' # the second batch starts.
#' set_preset(font_size = 9, paper_size = "letter")
#' get_preset()@font_size  # 9
#'
#' set_preset(
#'   reset       = TRUE,
#'   font_size   = 10,
#'   orientation = "landscape",
#'   paper_size  = "a4"
#' )
#' get_preset()@orientation  # "landscape"
#'
#' # Reset the session default so subsequent examples / R sessions
#' # are not affected.
#' set_preset(reset = TRUE)
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
set_preset <- function(..., template = NULL, reset = FALSE) {
  call <- rlang::caller_env()
  reset <- .check_scalar_lgl(reset, arg = "reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)
  template_knobs <- .extract_template_knobs(template, call = call)

  if (
    reset &&
      length(knobs) == 0L &&
      length(template_knobs) == 0L
  ) {
    .tabular_session$preset <- NULL
    return(invisible(NULL))
  }

  prior <- .tabular_session$preset
  base <- if (reset || !is_preset_spec(prior)) preset_spec() else prior

  if (length(template_knobs) > 0L) {
    base <- .apply_preset_knobs(base, template_knobs, call = call)
  }
  new_preset <- if (length(knobs) > 0L) {
    .apply_preset_knobs(base, knobs, call = call)
  } else {
    base
  }
  .tabular_session$preset <- new_preset
  invisible(new_preset)
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
#' tabular(data.frame(x = 1:3)) |>
#'   preset(
#'     font_size   = base_knobs@font_size,
#'     paper_size  = base_knobs@paper_size,
#'     orientation = "landscape"
#'   )
#'
#' # Reset the session default so subsequent examples / R sessions
#' # are not affected.
#' set_preset(reset = TRUE)
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

# Merge `knobs` onto a base preset_spec via S7::set_props. Callers
# only invoke this when `knobs` is non-empty; the no-knobs case is
# short-circuited upstream. The S7 property validators run on the
# constructed object; any bad value (wrong enum, wrong length, wrong
# type) raises a base R error that we re-throw as tabular_error_input
# with the underlying message.
#
# List-valued knobs in `.preset_list_merged_knobs` (e.g. `alignment`)
# shallow-merge onto the prior list rather than wholesale replace.
# A value of NULL inside the user's list clears that one key on the
# merged result without touching the other keys.
.apply_preset_knobs <- function(base, knobs, call) {
  knobs <- .preset_merge_list_knobs(base, knobs)
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

# Convert a `preset_spec` template (or NULL) into a named-list of
# knob values that DIFFER from `preset_spec()` factory defaults.
# This is what makes `preset(template = ...)` non-destructive: only
# the template author's deliberate overrides feed into the cascade;
# factory-default knobs on the template (e.g. `font_size = 9` when
# the user never customised it) leave the prior preset's value
# alone.
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
  out <- list()
  for (nm in .preset_knob_names) {
    v <- S7::prop(template, nm)
    f <- S7::prop(factory, nm)
    if (!identical(v, f)) {
      out[[nm]] <- v
    }
  }
  out
}

# Memoised factory preset_spec — used by `.extract_template_knobs`
# to decide which template knobs are deliberate overrides. The
# `.preset_factory_defaults_env` env is shared with `align.R`'s
# `.preset_factory_default()` helper.
.preset_factory_default_spec <- function() {
  if (is.null(.preset_factory_defaults_env$preset)) {
    .preset_factory_defaults_env$preset <- preset_spec()
  }
  .preset_factory_defaults_env$preset
}

# For each list-valued knob present in `knobs`, replace the incoming
# value with `modifyList(prior, incoming)` so the existing keys
# survive an additive call. Passing NULL inside the user's list
# removes that key from the merged result (modifyList drops it).
.preset_merge_list_knobs <- function(base, knobs) {
  for (nm in intersect(names(knobs), .preset_list_merged_knobs)) {
    incoming <- knobs[[nm]]
    if (is.null(incoming)) {
      next
    }
    if (!is.list(incoming)) {
      # Let S7::set_props raise the type error via the validator.
      next
    }
    prior <- S7::prop(base, nm)
    if (!is.list(prior)) {
      prior <- list()
    }
    knobs[[nm]] <- utils::modifyList(prior, incoming, keep.null = FALSE)
  }
  knobs
}

# ---------------------------------------------------------------------
# Effective-value helpers for the Phase 6 named-list knobs
# (`@fonts`, `@colors`, `@padding`). Each returns the surface- or
# token-specific value when set, falling back to the legacy scalar
# (`@font_family`, `@font_size`) or a sentinel (`NA_character_`,
# `NULL`) when unset. Backend renderers consume these so the new
# knobs override the legacy scalars without any backend caring about
# the named-list structure.

.effective_font_family <- function(preset, surface = "body") {
  if (!is_preset_spec(preset)) {
    preset <- preset_spec()
  }
  fonts <- preset@fonts
  if (
    is.list(fonts) &&
      !is.null(fonts[[surface]]) &&
      !is.null(fonts[[surface]]$family)
  ) {
    return(fonts[[surface]]$family)
  }
  preset@font_family
}

.effective_font_size <- function(preset, surface = "body") {
  if (!is_preset_spec(preset)) {
    preset <- preset_spec()
  }
  fonts <- preset@fonts
  if (
    is.list(fonts) &&
      !is.null(fonts[[surface]]) &&
      !is.null(fonts[[surface]]$size)
  ) {
    return(fonts[[surface]]$size)
  }
  preset@font_size
}

.effective_color <- function(preset, token) {
  if (!is_preset_spec(preset)) {
    return(NA_character_)
  }
  colors <- preset@colors
  if (is.list(colors) && !is.null(colors[[token]])) {
    return(colors[[token]])
  }
  NA_character_
}

# Returns either NULL (no padding override), a single non-negative
# numeric (uniform padding in points), or a named list with any of
# top / right / bottom / left (per-side padding in points).
.effective_padding <- function(preset, surface = "body") {
  if (!is_preset_spec(preset)) {
    return(NULL)
  }
  padding <- preset@padding
  if (is.list(padding) && !is.null(padding[[surface]])) {
    return(padding[[surface]])
  }
  NULL
}
