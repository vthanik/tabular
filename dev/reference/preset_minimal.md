# Minimal theme: one header rule, normal weight throughout

Apply the stripped-down table look in one verb. The column-label divider
(`midrule`) becomes the only rule drawn, and every bold-by-default
surface renders in normal weight: the title block, the column-header
band, the subgroup banner, and the section-header rows synthesized for
`usage = "group"` columns. The analogue of ggplot2's `theme_minimal()`,
composable on the pipe between the build verbs and the terminal
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) /
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

## Usage

``` r
preset_minimal(.spec, ...)
```

## Arguments

- .spec:

  *The `tabular_spec` to apply the minimal theme to.*
  `<tabular_spec>: required`. Dot-prefixed so partial matching cannot
  bind a `...` knob to the spec slot.

- ...:

  *Named preset knobs.* Forwarded verbatim to
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
  (e.g. `font_size`, `font_family`, `orientation`, `paper_size`,
  `margins`), so a single call sets both the minimal look and the page
  geometry.

  **Restriction:** the `rules` (and legacy `borders`) knob is owned by
  this helper and may not be passed here; call
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
  directly for a custom rule set.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
/ [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)).

## Details

**What it sets**, both at theme (lowest) precedence so an explicit later
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
wins:

1.  **Rules.** Drops the booktabs `toprule` and `bottomrule` (the outer
    frame), keeping the `midrule` under the column labels and the muted
    column-spanner `spanrule`. Equivalent to
    `preset(rules = list(toprule = "none", bottomrule = "none"))`.

2.  **Weight.** Sets `bold = FALSE` on the title, column-header,
    subgroup-label, and group-header surfaces. The HTML backend
    overrides its `font-weight: 600` class default with an inline
    `font-weight: normal`; the paginated backends (RTF / LaTeX / PDF /
    DOCX) suppress the surface's bold run.

**Last verb wins.** Because the weight layers ride the theme tier, a
later explicit `style(bold = TRUE, .at = cells_title())` (or any
surface) re-bolds it. Treat `preset_minimal()` as the theme baseline and
override individual surfaces afterwards.

**Markdown.** GFM cannot represent colour / background / font on a
surface; rendering a styled surface to `.md` emits a one-time
`tabular_warning_fidelity` and degrades gracefully. Weight (bold) and
italic carry through.

## See also

**Underlying verbs:**
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
(the rule presets `"booktabs"` / `"grid"` / `"frame"` / `"none"` live
there as `rules` string sugar),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md).

**Target the surfaces it touches:**
[`cells_title()`](https://vthanik.github.io/tabular/dev/reference/cells.md),
[`cells_headers()`](https://vthanik.github.io/tabular/dev/reference/cells.md),
[`cells_subgroup_labels()`](https://vthanik.github.io/tabular/dev/reference/cells.md),
[`cells_group_headers()`](https://vthanik.github.io/tabular/dev/reference/cells.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Minimal AE overall summary ----
#
# The overall adverse-event summary with a single rule under the
# column labels and no bold anywhere. `preset_minimal()` is the theme
# baseline; the page stays at the session default geometry.
demo_n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_ae,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(label = "Category"),
    placebo    = col_spec(label = "Placebo\nN={demo_n['placebo']}"),
    drug_50    = col_spec(label = "Drug 50\nN={demo_n['drug_50']}"),
    drug_100   = col_spec(label = "Drug 100\nN={demo_n['drug_100']}"),
    Total      = col_spec(label = "Total\nN={demo_n['Total']}")
  ) |>
  preset_minimal()

#tabular-e0179cf22d { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-e0179cf22d .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-e0179cf22d p { line-height: inherit; }
#tabular-e0179cf22d .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-e0179cf22d .tabular-caption { margin: 0; padding: 0; }
#tabular-e0179cf22d .tabular-pad { margin: 0; line-height: 1; }
#tabular-e0179cf22d .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-e0179cf22d .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-e0179cf22d .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-e0179cf22d .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-e0179cf22d .tabular-table th, #tabular-e0179cf22d .tabular-table td { padding: .18rem .6rem; }
#tabular-e0179cf22d .tabular-table td { text-align: left; vertical-align: top; }
#tabular-e0179cf22d .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-e0179cf22d .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-e0179cf22d .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e0179cf22d .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e0179cf22d .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e0179cf22d .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e0179cf22d .tabular-table tbody tr td { border-top: none; }
#tabular-e0179cf22d .tabular-band { text-align: center; }
#tabular-e0179cf22d .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-e0179cf22d .tabular-subgroup-label { font-weight: 600; }
#tabular-e0179cf22d .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-e0179cf22d .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-e0179cf22d .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-e0179cf22d .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-e0179cf22d .text-left { text-align: left; }
#tabular-e0179cf22d .text-center { text-align: center; }
#tabular-e0179cf22d .text-right { text-align: right; }
#tabular-e0179cf22d .tabular-table thead th.text-left { text-align: left; }
#tabular-e0179cf22d .tabular-table thead th.text-center { text-align: center; }
#tabular-e0179cf22d .tabular-table thead th.text-right { text-align: right; }
#tabular-e0179cf22d .valign-top { vertical-align: top; }
#tabular-e0179cf22d .valign-middle { vertical-align: middle; }
#tabular-e0179cf22d .valign-bottom { vertical-align: bottom; }
#tabular-e0179cf22d .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-e0179cf22d .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-e0179cf22d .tabular-page-break-row { display: none; }
#tabular-e0179cf22d { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-e0179cf22d .tabular-page-header, #tabular-e0179cf22d .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-e0179cf22d .tabular-page-header { margin-bottom: 1rem; }
#tabular-e0179cf22d .tabular-page-footer { margin-top: 1rem; }
#tabular-e0179cf22d .tabular-page-header-left, #tabular-e0179cf22d .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-e0179cf22d .tabular-page-header-center, #tabular-e0179cf22d .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-e0179cf22d .tabular-page-header-right, #tabular-e0179cf22d .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-e0179cf22d .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-e0179cf22d .tabular-table tr { page-break-inside: avoid; } #tabular-e0179cf22d .tabular-page-header, #tabular-e0179cf22d .tabular-page-footer { display: none; } #tabular-e0179cf22d .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-e0179cf22d .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-e0179cf22d .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Overall Summary of Adverse Events
Safety Population
 



Category
```
