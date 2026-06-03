# preset_minimal.R — the one named theme helper. A thin composite over
# `preset()` that applies the stripped-down "minimal" look: the
# column-label divider (`midrule`) is the only rule drawn, and every
# bold-by-default surface (title, column headers, subgroup banner, and
# the `usage = "group"` section-header rows) renders in normal weight.
# Deliberately the ONLY `preset_*()` theme constructor: the rule presets
# already ship as `rules = "booktabs" / "grid" / "frame" / "none"` string
# sugar, so there is no `preset_booktabs()` / `preset_grid()` /
# `preset_frame()` sibling.

#' Minimal theme: one header rule, normal weight throughout
#'
#' Apply the stripped-down table look in one verb. The column-label
#' divider (`midrule`) becomes the only rule drawn, and every
#' bold-by-default surface renders in normal weight: the title block,
#' the column-header band, the subgroup banner, and the section-header
#' rows synthesized for `usage = "group"` columns. The analogue of
#' ggplot2's `theme_minimal()`, composable on the pipe between the build
#' verbs and the terminal [`emit()`] / [`as_grid()`].
#'
#' @details
#' **What it sets**, both at theme (lowest) precedence so an explicit
#' later [`style()`] wins:
#'
#' 1. **Rules.** Drops the booktabs `toprule` and `bottomrule` (the
#'    outer frame), keeping the `midrule` under the column labels and the
#'    muted column-spanner `spanrule`. Equivalent to `preset(rules =
#'    list(toprule = "none", bottomrule = "none"))`.
#' 2. **Weight.** Sets `bold = FALSE` on the title, column-header,
#'    subgroup-label, and group-header surfaces. The HTML backend
#'    overrides its `font-weight: 600` class default with an inline
#'    `font-weight: normal`; the paginated backends (RTF / LaTeX / PDF /
#'    DOCX) suppress the surface's bold run.
#'
#' **Last verb wins.** Because the weight layers ride the theme tier, a
#' later explicit `style(bold = TRUE, .at = cells_title())` (or any
#' surface) re-bolds it. Treat `preset_minimal()` as the theme baseline
#' and override individual surfaces afterwards.
#'
#' **Markdown.** GFM cannot represent colour / background / font on a
#' surface; rendering a styled surface to `.md` emits a one-time
#' `tabular_warning_fidelity` and degrades gracefully. Weight (bold) and
#' italic carry through.
#'
#' @param .spec *The `tabular_spec` to apply the minimal theme to.*
#'   `<tabular_spec>: required`. Dot-prefixed so partial matching cannot
#'   bind a `...` knob to the spec slot.
#'
#' @param ... *Named preset knobs.* Forwarded verbatim to [`preset()`]
#'   (e.g. `font_size`, `font_family`, `orientation`, `paper_size`,
#'   `margins`), so a single call sets both the minimal look and the
#'   page geometry.
#'
#'   **Restriction:** the `rules` (and legacy `borders`) knob is owned by
#'   this helper and may not be passed here; call [`preset()`] directly
#'   for a custom rule set.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`paginate()`] / [`style()`], then render via [`emit()`] (or
#'   resolve without I/O via [`as_grid()`]).
#'
#' @examples
#' # ---- Example 1: Minimal AE overall summary ----
#' #
#' # The overall adverse-event summary with a single rule under the
#' # column labels and no bold anywhere. `preset_minimal()` is the theme
#' # baseline; the page stays at the session default geometry.
#' demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   saf_aeoverall,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Overall Summary of Adverse Events",
#'     "Safety Population"
#'   ),
#'   footnotes = "Subjects counted once per category."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Category"),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
#'     Total      = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
#'   ) |>
#'   preset_minimal()
#'
#' # ---- Example 2: Section headers normal, then re-bold the title ----
#' #
#' # AE by SOC / PT with the SOC as a section-header row. Under
#' # `preset_minimal()` the SOC section labels render in normal weight
#' # (not the default bold); a trailing `style()` re-bolds only the
#' # title (last verb wins), and `font_size` forwards through `...`.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#'
#' tabular(
#'   ae,
#'   titles = c("Table 14.3.2", "Adverse Events by SOC and Preferred Term"),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(usage = "group", group_display = "header_row"),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
#'   ) |>
#'   preset_minimal(font_size = 8) |>
#'   style(bold = TRUE, .at = cells_title())
#'
#' @seealso
#' **Underlying verbs:** [`preset()`] (the rule presets `"booktabs"` /
#' `"grid"` / `"frame"` / `"none"` live there as `rules` string sugar),
#' [`style()`].
#'
#' **Target the surfaces it touches:** [`cells_title()`],
#' [`cells_headers()`], [`cells_subgroup_labels()`],
#' [`cells_group_headers()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`], [`as_grid()`].
#'
#' @export
preset_minimal <- function(.spec, ...) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  knobs <- rlang::list2(...)
  owned <- intersect(names(knobs), c("rules", "borders"))
  if (length(owned) > 0L) {
    cli::cli_abort(
      c(
        "{.fn preset_minimal} owns the rule set.",
        "x" = "Drop {.arg {owned}}; the minimal theme owns the rule set (midrule + spanrule, no frame).",
        "i" = "For a custom rule set call {.fn preset} directly."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  # Normal weight on every bold-by-default surface, carried at theme
  # precedence so a later explicit style() overrides per surface. One
  # blank line above the footnotes stands in for the dropped bottomrule,
  # keeping the footnote block visually separated from the body.
  normal <- style_template() |>
    style(bold = FALSE, .at = cells_title()) |>
    style(bold = FALSE, .at = cells_headers()) |>
    style(bold = FALSE, .at = cells_subgroup_labels()) |>
    style(bold = FALSE, .at = cells_group_headers()) |>
    style(blank_above = 1L, .at = cells_footnotes())

  # Strip the outer frame (toprule + bottomrule) but KEEP the muted
  # column-spanner `spanrule` and the `midrule` under the column labels.
  # Overlays the two "off" sentinels onto the booktabs baseline (which
  # already leaves rowrule / footnoterule and the verticals off, midrule
  # + spanrule on). Forward the user's geometry knobs through the same
  # `preset()` call so they merge as usual.
  do.call(
    preset,
    c(
      list(
        .spec,
        rules = list(
          toprule = "none",
          bottomrule = "none"
        ),
        .style = normal
      ),
      knobs
    )
  )
}
