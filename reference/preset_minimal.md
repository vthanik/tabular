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
    sprintf("Safety Population (N=%d)", demo_n["Total"])
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
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_OVPPQurPAx" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title" style="font-weight: normal">Table 14.3.1</h1>
#> <h1 class="tabular-title" style="font-weight: normal">Overall Summary of Adverse Events</h1>
#> <h1 class="tabular-title" style="font-weight: normal">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th style="font-weight: normal">Total<br/>N=254</th><th style="font-weight: normal">Placebo<br/>N=86</th><th style="font-weight: normal">Drug 100<br/>N=72</th><th style="font-weight: normal">Drug 50<br/>N=96</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">Any TEAE</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">217 (85.4)</td><td style="border-left: none;">65 (75.6)</td><td style="border-left: none;">68 (94.4)</td><td style="border-left: none;">84 (87.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">Any Serious AE (SAE)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">3 (1.2)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (2.1)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">Any AE Related to Study Drug</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">184 (72.4)</td><td style="border-top: none; border-left: none;">43 (50.0)</td><td style="border-top: none; border-left: none;">64 (88.9)</td><td style="border-top: none; border-left: none;">77 (80.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">Any AE Leading to Death</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">3 (1.2)</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">Any AE Recovered / Resolved</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">157 (61.8)</td><td style="border-top: none; border-left: none;">47 (54.7)</td><td style="border-top: none; border-left: none;">49 (68.1)</td><td style="border-top: none; border-left: none;">61 (63.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">  Maximum severity: Mild</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">77 (30.3)</td><td style="border-top: none; border-left: none;">36 (41.9)</td><td style="border-top: none; border-left: none;">20 (27.8)</td><td style="border-top: none; border-left: none;">21 (21.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">  Maximum severity: Moderate</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">111 (43.7)</td><td style="border-top: none; border-left: none;">24 (27.9)</td><td style="border-top: none; border-left: none;">40 (55.6)</td><td style="border-top: none; border-left: none;">47 (49.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4" style="font-weight: normal">  Maximum severity: Severe</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none; border-bottom: none;">29 (11.4)</td><td style="border-top: none; border-bottom: none; border-left: none;">5 (5.8)</td><td style="border-top: none; border-bottom: none; border-left: none;">8 (11.1)</td><td style="border-top: none; border-bottom: none; border-left: none;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-pad">&nbsp;</p>
#> <p class="tabular-footnote">Subjects counted once per category.</p>
#> </div></div>

# ---- Example 2: Section headers normal, then re-bold the title ----
#
# AE by SOC / PT with the SOC as a section-header row. Under
# `preset_minimal()` the SOC section labels render in normal weight
# (not the default bold); a trailing `style()` re-bolds only the
# title (last verb wins), and `font_size` forwards through `...`.
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))

tabular(
  ae,
  titles = c("Table 14.3.2", "Adverse Events by SOC and Preferred Term"),
  footnotes = "Subjects counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(usage = "group", group_display = "header_row"),
    row_type = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
  ) |>
  preset_minimal(font_size = 8) |>
  style(bold = TRUE, .at = cells_title())
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 8pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 8pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 8pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 7pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_Hte9lRwSZt" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title" style="font-weight: bold">Table 14.3.2</h1>
#> <h1 class="tabular-title" style="font-weight: bold">Adverse Events by SOC and Preferred Term</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th style="font-weight: normal">SOC / PT</th><th style="font-weight: normal">n_total</th><th style="font-weight: normal">soc_n</th><th style="font-weight: normal">Placebo<br/>N=86</th><th style="font-weight: normal">Drug 50<br/>N=96</th><th style="font-weight: normal">Drug 100<br/>N=72</th><th style="font-weight: normal">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">TOTAL SUBJECTS WITH AN EVENT</td></tr>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td style="border-left: none;">199</td><td style="border-left: none;">199</td><td style="border-left: none;">52 (60.5)</td><td style="border-left: none;">81 (84.4)</td><td style="border-left: none;">66 (91.7)</td><td style="border-left: none;">199 (78.3)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td></tr>
#> <tr><td style="border-top: none;">SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">19 (22.1)</td><td style="border-top: none; border-left: none;">36 (37.5)</td><td style="border-top: none; border-left: none;">35 (48.6)</td><td style="border-top: none; border-left: none;">90 (35.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">PRURITUS</td><td style="border-top: none; border-left: none;">54</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">8 (9.3)</td><td style="border-top: none; border-left: none;">21 (21.9)</td><td style="border-top: none; border-left: none;">25 (34.7)</td><td style="border-top: none; border-left: none;">54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ERYTHEMA</td><td style="border-top: none; border-left: none;">36</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">8 (9.3)</td><td style="border-top: none; border-left: none;">14 (14.6)</td><td style="border-top: none; border-left: none;">14 (19.4)</td><td style="border-top: none; border-left: none;">36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">RASH</td><td style="border-top: none; border-left: none;">26</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">5 (5.8)</td><td style="border-top: none; border-left: none;">13 (13.5)</td><td style="border-top: none; border-left: none;">8 (11.1)</td><td style="border-top: none; border-left: none;">26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">HYPERHIDROSIS</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">4 (4.2)</td><td style="border-top: none; border-left: none;">8 (11.1)</td><td style="border-top: none; border-left: none;">14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SKIN IRRITATION</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">90</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">6 (6.2)</td><td style="border-top: none; border-left: none;">5 (6.9)</td><td style="border-top: none; border-left: none;">14 (5.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td></tr>
#> <tr><td style="border-top: none;">GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">15 (17.4)</td><td style="border-top: none; border-left: none;">36 (37.5)</td><td style="border-top: none; border-left: none;">30 (41.7)</td><td style="border-top: none; border-left: none;">81 (31.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">APPLICATION SITE PRURITUS</td><td style="border-top: none; border-left: none;">50</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">6 (7.0)</td><td style="border-top: none; border-left: none;">23 (24.0)</td><td style="border-top: none; border-left: none;">21 (29.2)</td><td style="border-top: none; border-left: none;">50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">APPLICATION SITE ERYTHEMA</td><td style="border-top: none; border-left: none;">30</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">13 (13.5)</td><td style="border-top: none; border-left: none;">14 (19.4)</td><td style="border-top: none; border-left: none;">30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">APPLICATION SITE DERMATITIS</td><td style="border-top: none; border-left: none;">21</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">5 (5.8)</td><td style="border-top: none; border-left: none;">9 (9.4)</td><td style="border-top: none; border-left: none;">7 (9.7)</td><td style="border-top: none; border-left: none;">21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">APPLICATION SITE IRRITATION</td><td style="border-top: none; border-left: none;">21</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">9 (9.4)</td><td style="border-top: none; border-left: none;">9 (12.5)</td><td style="border-top: none; border-left: none;">21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">APPLICATION SITE VESICLES</td><td style="border-top: none; border-left: none;">11</td><td style="border-top: none; border-left: none;">81</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">5 (5.2)</td><td style="border-top: none; border-left: none;">5 (6.9)</td><td style="border-top: none; border-left: none;">11 (4.3)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">GASTROINTESTINAL DISORDERS</td></tr>
#> <tr><td style="border-top: none;">GASTROINTESTINAL DISORDERS</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">13 (15.1)</td><td style="border-top: none; border-left: none;">12 (12.5)</td><td style="border-top: none; border-left: none;">17 (23.6)</td><td style="border-top: none; border-left: none;">42 (16.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">DIARRHOEA</td><td style="border-top: none; border-left: none;">17</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">9 (10.5)</td><td style="border-top: none; border-left: none;">5 (5.2)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">VOMITING</td><td style="border-top: none; border-left: none;">13</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">4 (4.2)</td><td style="border-top: none; border-left: none;">6 (8.3)</td><td style="border-top: none; border-left: none;">13 (5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">NAUSEA</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">6 (8.3)</td><td style="border-top: none; border-left: none;">12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ABDOMINAL PAIN</td><td style="border-top: none; border-left: none;">5</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SALIVARY HYPERSECRETION</td><td style="border-top: none; border-left: none;">4</td><td style="border-top: none; border-left: none;">42</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">4 (5.6)</td><td style="border-top: none; border-left: none;">4 (1.6)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">NERVOUS SYSTEM DISORDERS</td></tr>
#> <tr><td style="border-top: none;">NERVOUS SYSTEM DISORDERS</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">6 (7.0)</td><td style="border-top: none; border-left: none;">18 (18.8)</td><td style="border-top: none; border-left: none;">17 (23.6)</td><td style="border-top: none; border-left: none;">41 (16.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">DIZZINESS</td><td style="border-top: none; border-left: none;">21</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">9 (9.4)</td><td style="border-top: none; border-left: none;">10 (13.9)</td><td style="border-top: none; border-left: none;">21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">HEADACHE</td><td style="border-top: none; border-left: none;">11</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">5 (6.9)</td><td style="border-top: none; border-left: none;">11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SYNCOPE</td><td style="border-top: none; border-left: none;">7</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">5 (5.2)</td><td style="border-top: none; border-left: none;">2 (2.8)</td><td style="border-top: none; border-left: none;">7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SOMNOLENCE</td><td style="border-top: none; border-left: none;">6</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">TRANSIENT ISCHAEMIC ATTACK</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">41</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">CARDIAC DISORDERS</td></tr>
#> <tr><td style="border-top: none;">CARDIAC DISORDERS</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">7 (8.1)</td><td style="border-top: none; border-left: none;">12 (12.5)</td><td style="border-top: none; border-left: none;">14 (19.4)</td><td style="border-top: none; border-left: none;">33 (13.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SINUS BRADYCARDIA</td><td style="border-top: none; border-left: none;">17</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">7 (7.3)</td><td style="border-top: none; border-left: none;">8 (11.1)</td><td style="border-top: none; border-left: none;">17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">MYOCARDIAL INFARCTION</td><td style="border-top: none; border-left: none;">10</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">4 (4.7)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">4 (5.6)</td><td style="border-top: none; border-left: none;">10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ATRIAL FIBRILLATION</td><td style="border-top: none; border-left: none;">5</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">2 (2.8)</td><td style="border-top: none; border-left: none;">5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SUPRAVENTRICULAR EXTRASYSTOLES</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">VENTRICULAR EXTRASYSTOLES</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">33</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">INFECTIONS AND INFESTATIONS</td></tr>
#> <tr><td style="border-top: none;">INFECTIONS AND INFESTATIONS</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">12 (14.0)</td><td style="border-top: none; border-left: none;">6 (6.2)</td><td style="border-top: none; border-left: none;">11 (15.3)</td><td style="border-top: none; border-left: none;">29 (11.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">NASOPHARYNGITIS</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">4 (4.2)</td><td style="border-top: none; border-left: none;">6 (8.3)</td><td style="border-top: none; border-left: none;">12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">UPPER RESPIRATORY TRACT INFECTION</td><td style="border-top: none; border-left: none;">10</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">6 (7.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">INFLUENZA</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">URINARY TRACT INFECTION</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">CYSTITIS</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">29</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="7"></td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td></tr>
#> <tr><td style="border-top: none;">RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">5 (5.8)</td><td style="border-top: none; border-left: none;">8 (8.3)</td><td style="border-top: none; border-left: none;">9 (12.5)</td><td style="border-top: none; border-left: none;">22 (8.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">COUGH</td><td style="border-top: none; border-left: none;">11</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">5 (5.2)</td><td style="border-top: none; border-left: none;">5 (6.9)</td><td style="border-top: none; border-left: none;">11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">NASAL CONGESTION</td><td style="border-top: none; border-left: none;">7</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">DYSPNOEA</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">EPISTAXIS</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">2 (2.8)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">PHARYNGOLARYNGEAL PAIN</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">22</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">PSYCHIATRIC DISORDERS</td></tr>
#> <tr><td style="border-top: none;">PSYCHIATRIC DISORDERS</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">7 (8.1)</td><td style="border-top: none; border-left: none;">9 (9.4)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">19 (7.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">CONFUSIONAL STATE</td><td style="border-top: none; border-left: none;">6</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">AGITATION</td><td style="border-top: none; border-left: none;">5</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">INSOMNIA</td><td style="border-top: none; border-left: none;">4</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">2 (2.8)</td><td style="border-top: none; border-left: none;">4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ANXIETY</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">3 (3.1)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">DELUSION</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">19</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td></tr>
#> <tr><td style="border-top: none;">MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">3 (3.5)</td><td style="border-top: none; border-left: none;">6 (6.2)</td><td style="border-top: none; border-left: none;">5 (6.9)</td><td style="border-top: none; border-left: none;">14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">BACK PAIN</td><td style="border-top: none; border-left: none;">5</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ARTHRALGIA</td><td style="border-top: none; border-left: none;">4</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">SHOULDER PAIN</td><td style="border-top: none; border-left: none;">3</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">2 (2.1)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">MUSCLE SPASMS</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ARTHRITIS</td><td style="border-top: none; border-left: none;">1</td><td style="border-top: none; border-left: none;">14</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">1 (0.4)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="7">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="7" style="font-weight: normal">INVESTIGATIONS</td></tr>
#> <tr><td style="border-top: none;">INVESTIGATIONS</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">5 (5.8)</td><td style="border-top: none; border-left: none;">4 (4.2)</td><td style="border-top: none; border-left: none;">3 (4.2)</td><td style="border-top: none; border-left: none;">12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td style="border-top: none; border-left: none;">5</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">4 (4.7)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ELECTROCARDIOGRAM T WAVE INVERSION</td><td style="border-top: none; border-left: none;">4</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">2 (2.3)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">BLOOD GLUCOSE INCREASED</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none;">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td style="border-top: none; border-left: none;">2</td><td style="border-top: none; border-left: none;">12</td><td style="border-top: none; border-left: none;">1 (1.2)</td><td style="border-top: none; border-left: none;">1 (1.0)</td><td style="border-top: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-left: none;">2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-top: none; border-bottom: none;">BIOPSY</td><td style="border-top: none; border-bottom: none; border-left: none;">1</td><td style="border-top: none; border-bottom: none; border-left: none;">12</td><td style="border-top: none; border-bottom: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-bottom: none; border-left: none;">0 (0.0)</td><td style="border-top: none; border-bottom: none; border-left: none;">1 (1.4)</td><td style="border-top: none; border-bottom: none; border-left: none;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-pad">&nbsp;</p>
#> <p class="tabular-footnote">Subjects counted once per SOC and once per PT.</p>
#> </div></div>
```
