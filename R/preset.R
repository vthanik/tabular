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
  "decimal_metrics"
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
#'   *   **`font_family`** — body font family.
#'       `<character(1)>`. Default `"Times New Roman"`.
#'   *   **`orientation`** — page orientation.
#'       `<character(1)>`. One of `"portrait"` (default),
#'       `"landscape"`.
#'   *   **`paper_size`** — paper key.
#'       `<character(1)>`. One of `"letter"` (default), `"a4"`.
#'   *   **`margins`** — page margins in inches.
#'       `<numeric(1) | numeric(4)>`. Length 1 = all four sides;
#'       length 4 = top, right, bottom, left.
#'   *   **`pagehead`**, **`pagefoot`** — list of named lists for
#'       header / footer row content. `<list>`.
#'   *   **`hlines`** — horizontal-rule policy.
#'       `<character(1)>`. One of `"header"` (default), `"none"`,
#'       `"all"`.
#'   *   **`indent_chars`** — row-label indent prefix.
#'       `<character(1)>`. Default `"  "`.
#'   *   **`title_align`**, **`footnote_align`** — block alignment.
#'       `<character(1)>`. One of `"left"`, `"center"`, `"right"`.
#'   *   **`na_text`** — global NA fallback. `<character(1)>`.
#'   *   **`decimal_metrics`** — font-metric source for decimal
#'       alignment. `<character(1)>`. One of `"afm"` (PDF Core 14,
#'       public domain) or `"systemfonts"`.
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
#' # ---- Example 2: Per-spec override on top of a session default ----
#' #
#' # The submission session sets a portrait letter 9pt default (typical
#' # safety-table geometry). One particular AE table needs landscape
#' # for a long PT label band; the per-spec `preset()` overrides only
#' # orientation, leaving font / paper untouched via merge semantics.
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
#'   preset(orientation = "landscape") |>
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
preset <- function(.spec, ..., reset = FALSE) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)
  reset <- .check_scalar_lgl(reset, arg = "reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)

  if (reset && length(knobs) == 0L) {
    return(S7::set_props(.spec, preset = NULL))
  }
  if (!reset && length(knobs) == 0L) {
    return(.spec)
  }

  prior <- .spec@preset
  base <- if (reset || !is_preset_spec(prior)) preset_spec() else prior

  new_preset <- .apply_preset_knobs(base, knobs, call = call)
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
set_preset <- function(..., reset = FALSE) {
  call <- rlang::caller_env()
  reset <- .check_scalar_lgl(reset, arg = "reset", call = call)

  knobs <- rlang::list2(...)
  .check_preset_knob_names(knobs, call = call)

  if (reset && length(knobs) == 0L) {
    .tabular_session$preset <- NULL
    return(invisible(NULL))
  }

  prior <- .tabular_session$preset
  base <- if (reset || !is_preset_spec(prior)) preset_spec() else prior

  new_preset <- .apply_preset_knobs(base, knobs, call = call)
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
