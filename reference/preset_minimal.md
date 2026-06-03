# Minimal theme: one header rule, normal weight throughout

Apply the stripped-down table look in one verb. The column-label divider
(`midrule`) becomes the only rule drawn, and every bold-by-default
surface renders in normal weight: the title block, the column-header
band, the subgroup banner, and the section-header rows synthesized for
`usage = "group"` columns. The analogue of ggplot2's `theme_minimal()`,
composable on the pipe between the build verbs and the terminal
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) /
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

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
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
  (e.g. `font_size`, `font_family`, `orientation`, `paper_size`,
  `margins`), so a single call sets both the minimal look and the page
  geometry.

  **Restriction:** the `rules` (and legacy `borders`) knob is owned by
  this helper and may not be passed here; call
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
  directly for a custom rule set.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
/ [`style()`](https://vthanik.github.io/tabular/reference/style.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)).

## Details

**What it sets**, both at theme (lowest) precedence so an explicit later
[`style()`](https://vthanik.github.io/tabular/reference/style.md) wins:

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
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md) (the
rule presets `"booktabs"` / `"grid"` / `"frame"` / `"none"` live there
as `rules` string sugar),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

**Target the surfaces it touches:**
[`cells_title()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_headers()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_subgroup_labels()`](https://vthanik.github.io/tabular/reference/cells.md),
[`cells_group_headers()`](https://vthanik.github.io/tabular/reference/cells.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Minimal AE overall summary ----
#
# The overall adverse-event summary with a single rule under the
# column labels and no bold anywhere. `preset_minimal()` is the theme
# baseline; the page stays at the session default geometry.
demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_aeoverall,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Category"),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
    Total      = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
  ) |>
  preset_minimal()

#tabular-4bdb0a2bfd { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-4bdb0a2bfd .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-4bdb0a2bfd p { line-height: inherit; }
#tabular-4bdb0a2bfd .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-4bdb0a2bfd .tabular-caption { margin: 0; padding: 0; }
#tabular-4bdb0a2bfd .tabular-pad { margin: 0; line-height: 1; }
#tabular-4bdb0a2bfd .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-4bdb0a2bfd .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-4bdb0a2bfd .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-4bdb0a2bfd .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-4bdb0a2bfd .tabular-table th, #tabular-4bdb0a2bfd .tabular-table td { padding: .18rem .6rem; }
#tabular-4bdb0a2bfd .tabular-table td { text-align: left; vertical-align: top; }
#tabular-4bdb0a2bfd .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-4bdb0a2bfd .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-4bdb0a2bfd .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-4bdb0a2bfd .tabular-table tbody tr td { border-top: none; }
#tabular-4bdb0a2bfd .tabular-band { text-align: center; }
#tabular-4bdb0a2bfd .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-4bdb0a2bfd .tabular-subgroup-label { font-weight: 600; }
#tabular-4bdb0a2bfd .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-4bdb0a2bfd .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-4bdb0a2bfd .text-left { text-align: left; }
#tabular-4bdb0a2bfd .text-center { text-align: center; }
#tabular-4bdb0a2bfd .text-right { text-align: right; }
#tabular-4bdb0a2bfd .tabular-table thead th.text-left { text-align: left; }
#tabular-4bdb0a2bfd .tabular-table thead th.text-center { text-align: center; }
#tabular-4bdb0a2bfd .tabular-table thead th.text-right { text-align: right; }
#tabular-4bdb0a2bfd .valign-top { vertical-align: top; }
#tabular-4bdb0a2bfd .valign-middle { vertical-align: middle; }
#tabular-4bdb0a2bfd .valign-bottom { vertical-align: bottom; }
#tabular-4bdb0a2bfd .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-4bdb0a2bfd .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-4bdb0a2bfd .tabular-page-break-row { display: none; }
#tabular-4bdb0a2bfd { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-4bdb0a2bfd .tabular-page-header, #tabular-4bdb0a2bfd .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-4bdb0a2bfd .tabular-page-header { margin-bottom: 1rem; }
#tabular-4bdb0a2bfd .tabular-page-footer { margin-top: 1rem; }
#tabular-4bdb0a2bfd .tabular-page-header-left, #tabular-4bdb0a2bfd .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-4bdb0a2bfd .tabular-page-header-center, #tabular-4bdb0a2bfd .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-4bdb0a2bfd .tabular-page-header-right, #tabular-4bdb0a2bfd .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-4bdb0a2bfd .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-4bdb0a2bfd .tabular-table tr { page-break-inside: avoid; } #tabular-4bdb0a2bfd .tabular-page-header, #tabular-4bdb0a2bfd .tabular-page-footer { display: none; } #tabular-4bdb0a2bfd .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-4bdb0a2bfd .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-4bdb0a2bfd .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Overall Summary of Adverse Events
Safety Population
 



Total
N=254
```
