# Configure pagination

Attach a `pagination_spec` to a `tabular_spec`. The engine uses the spec
at render time to decide where page breaks fall, how wide tables split
into horizontal panels, and what continuation marker (if any) prints on
continued pages. The row budget per page is computed by the engine from
the active preset (paper, orientation, margins, font size) and the
chrome rows consumed by titles, column headers, and footnotes — you do
not set rows-per-page directly.

## Usage

``` r
paginate(
  spec,
  keep_together = character(),
  panels = 1,
  orphan_floor = 3,
  widow_floor = 2,
  repeat_content = c("titles", "headers", "footnotes"),
  continuation = NULL
)
```

## Arguments

- spec:

  *The `tabular_spec` to attach pagination to.*
  `<tabular_spec>: required`.

- keep_together:

  *Group columns whose runs of identical values must not be split across
  a page break.* `<character>: default character()`. Every entry must be
  a `usage = "group"` column declared in
  [`cols()`](https://vthanik.github.io/tabular/reference/cols.md).

  **Interaction:** A run too tall to fit in the computed row budget less
  `orphan_floor` is split anyway; pagination is best-effort, not a hard
  contract.

      # Protect the SOC-level grouping in an AE-by-SOC/PT table.
      paginate(keep_together = "soc")

- panels:

  *Number of horizontal panels for wide tables.*
  `<integer(1) | "auto">: default 1`. With `1`, every column is on every
  page (single vertical scroll). With `N > 1`, the engine splits
  non-group columns into `N` chunks and repeats every group column on
  every panel.

  **Note:** `"auto"` is accepted but treated as `1` until preset-aware
  column-width metrics land; once they do, `"auto"` will split when the
  total table width exceeds the printable area.

- orphan_floor:

  *Minimum rows on a continued-from page.* `<integer(1)>: default 3`.
  When `keep_together` would move a page break back so far that fewer
  than `orphan_floor` rows would ride on the current page, the engine
  splits the protected run anyway. Acts as the escape valve for groups
  too tall to fit.

- widow_floor:

  *Minimum rows on the final page.* `<integer(1)>: default 2`. If the
  last page would carry fewer than `widow_floor` rows, the engine merges
  those rows back onto the previous page (page overflow accepted).
  Avoids the "one-row-orphaned-on-page-N" look without complicating the
  primary split rule.

- repeat_content:

  *Which page chrome repeats on every page.*
  `<character>: default c("titles", "headers", "footnotes")`. A subset
  of those three values; each is governed independently:

  - **`"titles"`** — title block on every page (else page 1 only).

  - **`"headers"`** — column-header band on every page (else page 1
    only).

  - **`"footnotes"`** — footnote block on every page (else last page
    only).

  The default repeats all three so each page is self-contained per the
  submission layout contract. Pass a subset to drop one (e.g.
  `c("headers", "footnotes")` keeps the title on page 1 only), or
  [`character()`](https://rdrr.io/r/base/character.html) to repeat
  nothing.

  **Note:** Footnotes are always anchored to the page foot when present;
  membership only chooses every-page vs last-page-only, never table-body
  placement.

  **HTML / MD:** ignored. HTML renders one continuous `<table>` and
  browsers natively repeat `<thead>` on print; MD has no print model.
  Effective only for the page-oriented backends (RTF, PDF, LaTeX, DOCX).

- continuation:

  *Marker text appended after a continuing table's title block.*
  `<character(1) | NULL>: default NULL`. `NULL` (the default) renders no
  marker — pick the wording your submission style guide expects (e.g.
  `"(continued)"`, `"(Cont'd)"`, `"Page %d of %d"`) and pass it
  explicitly. **HTML / MD:** ignored. With one continuous document on
  screen there is no continuing-page boundary to mark. Effective only
  for the page-oriented backends (RTF, PDF, LaTeX, DOCX).

## Value

*The updated `tabular_spec`.* Continue chaining with
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)).

## Details

**Replace, not stack.** A second `paginate()` call REPLACES the prior
spec — pagination is a single configuration block, not a stackable list.
Call with all defaults to clear back to the engine's auto behaviour.

**Rows per page are computed, not configured.** The engine takes the
paper height for the active orientation (`letter`, `a4`) and subtracts
the top + bottom margins, the title block height (number of title
lines + a blank separator), the column-header band height (max embedded
`\n` line count across visible column labels, plus any spanning header
levels), and the footnote block height (number of footnote lines + a
blank separator). The remainder, divided by the row height for the
active font size, gives the body-row budget per page. Landscape pages
naturally carry fewer rows than portrait at the same paper size; smaller
fonts carry more.

**`keep_together` protects group runs.** When a page break would fall in
the middle of a contiguous run of identical values in a
`usage = "group"` column listed in `keep_together`, the engine moves the
break BACK to the start of the run so the whole run rides on the next
page. Single rule of escape: if moving the break back would leave fewer
than `orphan_floor` rows on the current page, the engine splits the run
anyway (a single group too tall to fit on one page cannot be kept
together).

**`panels` and group stickiness.** With `panels > 1`, the engine splits
the NON-group columns into approximately equal slices and repeats every
`usage = "group"` column on every panel for row context.
`panels = "auto"` defers the decision to preset-aware column-width
metrics; until those metrics land in a future release the engine treats
`"auto"` as `1`.

## See also

**Render-geometry partner:**
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md) /
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
— the preset's paper, orientation, margins, and font size feed the
per-page row budget this verb depends on.

**Sibling build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: AE table paginated by SOC ----
#
# AE-by-SOC/PT table that may run several pages. The SOC column is
# protected by `keep_together` so a page break never lands in the
# middle of one SOC's PT rows. The engine derives the row budget
# from the preset's orientation + font_size + paper size and from
# the title / footnote / header line counts on the spec — no
# manual rows-per-page knob to keep in sync.
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total <- as.integer(sub(" .*", "", ae$Total))
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(usage = "group", visible = FALSE,
                        group_display = "column_repeat"),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
  paginate(
    keep_together = "soc",
    repeat_content = c("titles", "headers", "footnotes"),
    continuation = "(continued)"
  )
#> <style>
#> #tabular-d2836d3601 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-d2836d3601 .tabular-content { width: 100%; }
#> #tabular-d2836d3601 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-d2836d3601 .tabular-pad { margin: 0; }
#> #tabular-d2836d3601 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-d2836d3601 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-d2836d3601 .tabular-table th, #tabular-d2836d3601 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-d2836d3601 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-d2836d3601 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-d2836d3601 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-d2836d3601 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-d2836d3601 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-d2836d3601 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-d2836d3601 .tabular-table tbody tr td { border-top: none; }
#> #tabular-d2836d3601 .tabular-band { text-align: center; }
#> #tabular-d2836d3601 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-d2836d3601 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-d2836d3601 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-d2836d3601 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-d2836d3601 .text-left { text-align: left; }
#> #tabular-d2836d3601 .text-center { text-align: center; }
#> #tabular-d2836d3601 .text-right { text-align: right; }
#> #tabular-d2836d3601 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-d2836d3601 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-d2836d3601 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-d2836d3601 .valign-top { vertical-align: top; }
#> #tabular-d2836d3601 .valign-middle { vertical-align: middle; }
#> #tabular-d2836d3601 .valign-bottom { vertical-align: bottom; }
#> #tabular-d2836d3601 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-d2836d3601 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-d2836d3601 .tabular-page-break-row { display: none; }
#> #tabular-d2836d3601 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-d2836d3601 .tabular-page-header, #tabular-d2836d3601 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-d2836d3601 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-d2836d3601 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-d2836d3601 .tabular-page-header-left, #tabular-d2836d3601 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-d2836d3601 .tabular-page-header-center, #tabular-d2836d3601 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-d2836d3601 .tabular-page-header-right, #tabular-d2836d3601 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-d2836d3601 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-d2836d3601 .tabular-table tr { page-break-inside: avoid; } #tabular-d2836d3601 .tabular-page-header, #tabular-d2836d3601 .tabular-page-footer { display: none; } #tabular-d2836d3601 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-d2836d3601 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-d2836d3601 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-d2836d3601" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="2"></th><th colspan="4" class="tabular-band">Treatment Group</th></tr>
#> <tr><th>SOC / PT</th><th>soc_n</th><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=96</th><th>Drug 100<br/>N=72</th><th>Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td>52 (60.5)</td><td>81 (84.4)</td><td>66 (91.7)</td><td>199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td>19 (22.1)</td><td>36 (37.5)</td><td>35 (48.6)</td><td>90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td>15 (17.4)</td><td>36 (37.5)</td><td>30 (41.7)</td><td>81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td>13 (15.1)</td><td>12 (12.5)</td><td>17 (23.6)</td><td>42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td>6 (7.0)</td><td>18 (18.8)</td><td>17 (23.6)</td><td>41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td>7 (8.1)</td><td>12 (12.5)</td><td>14 (19.4)</td><td>33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td>12 (14.0)</td><td>6 (6.2)</td><td>11 (15.3)</td><td>29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td>5 (5.8)</td><td>8 (8.3)</td><td>9 (12.5)</td><td>22 (8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td>7 (8.1)</td><td>9 (9.4)</td><td>3 (4.2)</td><td>19 (7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td>5 (5.8)</td><td>4 (4.2)</td><td>3 (4.2)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td>8 (9.3)</td><td>21 (21.9)</td><td>25 (34.7)</td><td>54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td>6 (7.0)</td><td>23 (24.0)</td><td>21 (29.2)</td><td>50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td>8 (9.3)</td><td>14 (14.6)</td><td>14 (19.4)</td><td>36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td>3 (3.5)</td><td>13 (13.5)</td><td>14 (19.4)</td><td>30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td>5 (5.8)</td><td>13 (13.5)</td><td>8 (11.1)</td><td>26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td>5 (5.8)</td><td>9 (9.4)</td><td>7 (9.7)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td>3 (3.5)</td><td>9 (9.4)</td><td>9 (12.5)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td>2 (2.3)</td><td>9 (9.4)</td><td>10 (13.9)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td>9 (10.5)</td><td>5 (5.2)</td><td>3 (4.2)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td>2 (2.3)</td><td>7 (7.3)</td><td>8 (11.1)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td>2 (2.3)</td><td>4 (4.2)</td><td>8 (11.1)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td>3 (3.5)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>13 (5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td>3 (3.5)</td><td>3 (3.1)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td>2 (2.3)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td>3 (3.5)</td><td>3 (3.1)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td>4 (4.7)</td><td>2 (2.1)</td><td>4 (5.6)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td>6 (7.0)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td>0 (0.0)</td><td>5 (5.2)</td><td>2 (2.8)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td>3 (3.5)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td>1 (1.2)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td>1 (1.2)</td><td>2 (2.1)</td><td>2 (2.8)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td>1 (1.2)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td>4 (4.7)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td>0 (0.0)</td><td>0 (0.0)</td><td>4 (5.6)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td>2 (2.3)</td><td>0 (0.0)</td><td>2 (2.8)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td>2 (2.3)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>2 (2.8)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td>0 (0.0)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td>1 (1.2)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td>0 (0.0)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>1 (0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">1 (1.4)</td><td style="border-bottom: 0.5pt solid #212529;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects are counted once per SOC and once per PT.</p>
#> </div></div>

# ---- Example 2: Wide ACROSS-style efficacy table split across 2 panels ----
#
# BOR table where the four-arm column block is too wide for portrait
# paper. Split into 2 horizontal panels; the group column
# (`stat_label`) repeats on every panel for row context. Vertical
# pagination still applies, so on a tall table you would see panel A
# pages 1-2, then panel B pages 1-2.
bor_levels <- c(
  "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
  "Objective Response Rate (CR + PR)",
  "Disease Control Rate (CR + PR + SD)"
)
eff <- eff_resp
eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
ne <- stats::setNames(eff_n$n, eff_n$arm_short)

tabular(
  eff,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  ),
  footnotes = "Response per RECIST 1.1, investigator assessment."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Response"),
    row_type   = col_spec(visible = FALSE),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
  ) |>
  sort_rows(by = "stat_label") |>
  paginate(panels = 2, repeat_content = c("titles", "headers", "footnotes"))
#> <style>
#> #tabular-84bd7ecf20 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-84bd7ecf20 .tabular-content { width: 100%; }
#> #tabular-84bd7ecf20 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-84bd7ecf20 .tabular-pad { margin: 0; }
#> #tabular-84bd7ecf20 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-84bd7ecf20 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-84bd7ecf20 .tabular-table th, #tabular-84bd7ecf20 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-84bd7ecf20 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-84bd7ecf20 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-84bd7ecf20 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-84bd7ecf20 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-84bd7ecf20 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-84bd7ecf20 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-84bd7ecf20 .tabular-table tbody tr td { border-top: none; }
#> #tabular-84bd7ecf20 .tabular-band { text-align: center; }
#> #tabular-84bd7ecf20 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-84bd7ecf20 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-84bd7ecf20 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-84bd7ecf20 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-84bd7ecf20 .text-left { text-align: left; }
#> #tabular-84bd7ecf20 .text-center { text-align: center; }
#> #tabular-84bd7ecf20 .text-right { text-align: right; }
#> #tabular-84bd7ecf20 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-84bd7ecf20 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-84bd7ecf20 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-84bd7ecf20 .valign-top { vertical-align: top; }
#> #tabular-84bd7ecf20 .valign-middle { vertical-align: middle; }
#> #tabular-84bd7ecf20 .valign-bottom { vertical-align: bottom; }
#> #tabular-84bd7ecf20 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-84bd7ecf20 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-84bd7ecf20 .tabular-page-break-row { display: none; }
#> #tabular-84bd7ecf20 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-84bd7ecf20 .tabular-page-header, #tabular-84bd7ecf20 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-84bd7ecf20 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-84bd7ecf20 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-84bd7ecf20 .tabular-page-header-left, #tabular-84bd7ecf20 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-84bd7ecf20 .tabular-page-header-center, #tabular-84bd7ecf20 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-84bd7ecf20 .tabular-page-header-right, #tabular-84bd7ecf20 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-84bd7ecf20 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-84bd7ecf20 .tabular-table tr { page-break-inside: avoid; } #tabular-84bd7ecf20 .tabular-page-header, #tabular-84bd7ecf20 .tabular-page-footer { display: none; } #tabular-84bd7ecf20 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-84bd7ecf20 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-84bd7ecf20 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-84bd7ecf20" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="3" class="tabular-band tabular-panel-note">Panel 1</th><th colspan="2" class="tabular-band tabular-panel-note">Panel 2</th></tr>
#> <tr><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=84</th><th>Drug 100<br/>N=84</th><th>groupid</th><th>group_label</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>1 (1.2)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>1 (1.2)</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>83 (96.5)</td><td>82 (97.6)</td><td>81 (96.4)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>2 (2.3)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>(0.3, 8.1)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>(0.7, 9.9)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>2 (2.4)</td><td>4</td><td>Disease Control Rate</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">(0.7, 9.9)</td><td style="border-bottom: 0.5pt solid #212529;">(0.0, 6.5)</td><td style="border-bottom: 0.5pt solid #212529;">(0.3, 8.3)</td><td style="border-bottom: 0.5pt solid #212529;">4</td><td style="border-bottom: 0.5pt solid #212529;">Disease Control Rate</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Response per RECIST 1.1, investigator assessment.</p>
#> </div></div>

# ---- Example 3: Orphan / widow floors + continuation marker ----
#
# Long vital-signs table with two safeguards: orphan_floor = 4
# prevents fewer than 4 rows of a group landing alone at the
# bottom of a page; widow_floor = 2 prevents fewer than 2 rows of
# a group landing alone at the top of the next page; the
# continuation marker prints on every page after the first.
tabular(
  saf_vital,
  titles = c("Table 14.4.1", "Vital Signs Summary at Each Visit")
) |>
  cols(
    param      = col_spec(usage = "group", label = "Parameter"),
    paramcd    = col_spec(visible = FALSE),
    visit      = col_spec(usage = "group", label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal")
  ) |>
  paginate(
    keep_together = "param",
    orphan_floor  = 4L,
    widow_floor   = 2L,
    continuation  = "(continued)"
  )
#> <style>
#> #tabular-8d220eda5e { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-8d220eda5e .tabular-content { width: 100%; }
#> #tabular-8d220eda5e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-8d220eda5e .tabular-pad { margin: 0; }
#> #tabular-8d220eda5e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-8d220eda5e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-8d220eda5e .tabular-table th, #tabular-8d220eda5e .tabular-table td { padding: .35rem .6rem; }
#> #tabular-8d220eda5e .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-8d220eda5e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-8d220eda5e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-8d220eda5e .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-8d220eda5e .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-8d220eda5e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-8d220eda5e .tabular-table tbody tr td { border-top: none; }
#> #tabular-8d220eda5e .tabular-band { text-align: center; }
#> #tabular-8d220eda5e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-8d220eda5e .tabular-subgroup-label { font-weight: 600; }
#> #tabular-8d220eda5e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-8d220eda5e .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-8d220eda5e .text-left { text-align: left; }
#> #tabular-8d220eda5e .text-center { text-align: center; }
#> #tabular-8d220eda5e .text-right { text-align: right; }
#> #tabular-8d220eda5e .tabular-table thead th.text-left { text-align: left; }
#> #tabular-8d220eda5e .tabular-table thead th.text-center { text-align: center; }
#> #tabular-8d220eda5e .tabular-table thead th.text-right { text-align: right; }
#> #tabular-8d220eda5e .valign-top { vertical-align: top; }
#> #tabular-8d220eda5e .valign-middle { vertical-align: middle; }
#> #tabular-8d220eda5e .valign-bottom { vertical-align: bottom; }
#> #tabular-8d220eda5e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-8d220eda5e .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-8d220eda5e .tabular-page-break-row { display: none; }
#> #tabular-8d220eda5e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-8d220eda5e .tabular-page-header, #tabular-8d220eda5e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-8d220eda5e .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-8d220eda5e .tabular-page-footer { margin-top: 1rem; }
#> #tabular-8d220eda5e .tabular-page-header-left, #tabular-8d220eda5e .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-8d220eda5e .tabular-page-header-center, #tabular-8d220eda5e .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-8d220eda5e .tabular-page-header-right, #tabular-8d220eda5e .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-8d220eda5e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-8d220eda5e .tabular-table tr { page-break-inside: avoid; } #tabular-8d220eda5e .tabular-page-header, #tabular-8d220eda5e .tabular-page-footer { display: none; } #tabular-8d220eda5e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-8d220eda5e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-8d220eda5e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-8d220eda5e" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.4.1</h1>
#> <h1 class="tabular-title">Vital Signs Summary at Each Visit</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 77.1 (10.7)</td><td class="text-right"> 76.6 (9.8) </td><td class="text-right"> 78.2 (10.3)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 77.7       </td><td class="text-right"> 76.7       </td><td class="text-right"> 78.8       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 40  , 110  </td><td class="text-right"> 48  , 108  </td><td class="text-right"> 51  , 108  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (9.1) </td><td class="text-right"> 75.4 (10.6)</td><td class="text-right"> 77.4 (9.1) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 78.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 101  </td><td class="text-right"> 52  , 100  </td><td class="text-right"> 54  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.1 (10.9)</td><td class="text-right"> 75.2 (10.0)</td><td class="text-right"> 76.0 (9.0) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 75.7       </td><td class="text-right"> 77.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 98   </td><td class="text-right"> 55  , 98   </td><td class="text-right"> 50  , 92   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.4 (10.7)</td><td class="text-right"> 76.0 (11.2)</td><td class="text-right"> 76.0 (9.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.5       </td><td class="text-right"> 76.0       </td><td class="text-right"> 78.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.5 (11.6)</td><td class="text-right"> 72.1 (10.8)</td><td class="text-right"> 72.4 (9.7) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.3       </td><td class="text-right"> 70.0       </td><td class="text-right"> 71.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 134  </td><td class="text-right"> 50  , 104  </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 71.8 (9.0) </td><td class="text-right"> 72.6 (11.1)</td><td class="text-right"> 74.0 (8.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 72.0       </td><td class="text-right"> 73.2       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 52  , 102  </td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 70.6 (8.8) </td><td class="text-right"> 68.8 (9.4) </td><td class="text-right"> 73.2 (9.5) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 70.2       </td><td class="text-right"> 68.0       </td><td class="text-right"> 72.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 90   </td><td class="text-right"> 48  , 104  </td><td class="text-right"> 51  , 96   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (11.5)</td><td class="text-right"> 74.1 (9.4) </td><td class="text-right"> 73.6 (9.6) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 74.0       </td><td class="text-right"> 75.0       </td><td class="text-right"> 73.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 106  </td><td class="text-right"> 50  , 94   </td><td class="text-right"> 50  , 98   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.8 (17.6)</td><td class="text-right">137.9 (18.5)</td><td class="text-right">137.8 (17.2)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.3       </td><td class="text-right">138.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 80  , 184  </td><td class="text-right">100  , 194  </td><td class="text-right">100  , 192  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.3 (17.0)</td><td class="text-right">134.9 (17.8)</td><td class="text-right">135.1 (15.5)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.5       </td><td class="text-right">132.3       </td><td class="text-right">134.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 90  , 189  </td><td class="text-right"> 92  , 200  </td><td class="text-right"> 91  , 198  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.6 (18.3)</td><td class="text-right">132.5 (14.3)</td><td class="text-right">133.7 (16.0)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">130.0       </td><td class="text-right">132.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 76  , 190  </td><td class="text-right">100  , 168  </td><td class="text-right"> 99  , 186  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">132.7 (15.4)</td><td class="text-right">133.0 (17.1)</td><td class="text-right">132.3 (15.6)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">130.0       </td><td class="text-right">131.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 78  , 172  </td><td class="text-right"> 92  , 178  </td><td class="text-right">100  , 177  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">172         </td><td class="text-right">190         </td><td class="text-right">144         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.5 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.6       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 35  , 37   </td><td class="text-right"> 35  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">146         </td><td class="text-right">118         </td><td class="text-right">112         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">136         </td><td class="text-right"> 82         </td><td class="text-right"> 74         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.3) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 74         </td><td class="text-right"> 59         </td><td class="text-right"> 56         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.8       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 37   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 38   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 36  , 37   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Many-arm horizontal pagination via column-fit ----
#
# Wide AE-by-SOC/PT table where the column strip itself does not
# fit on a single page. The engine slices columns into groups
# (each group keeping the `usage = "group"` columns repeated on
# every horizontal page) so the SOC / PT label band re-appears
# alongside whichever arm columns land on each panel.
tabular(
  saf_aesocpt,
  titles = c("Table 14.3.1", "AEs by SOC and PT (wide-page split)")
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level",
                        width = "2.5in"),
    soc      = col_spec(usage = "group", visible = FALSE,
                        group_display = "column_repeat"),
    row_type = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo",  align = "decimal",
                        width = "2.0in"),
    drug_50  = col_spec(label = "Drug 50",  align = "decimal",
                        width = "2.0in"),
    drug_100 = col_spec(label = "Drug 100", align = "decimal",
                        width = "2.0in"),
    Total    = col_spec(label = "Total",    align = "decimal",
                        width = "2.0in")
  ) |>
  paginate(keep_together = "soc")
#> <style>
#> #tabular-2d10695410 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-2d10695410 .tabular-content { width: 100%; }
#> #tabular-2d10695410 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-2d10695410 .tabular-pad { margin: 0; }
#> #tabular-2d10695410 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-2d10695410 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-2d10695410 .tabular-table th, #tabular-2d10695410 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-2d10695410 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-2d10695410 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-2d10695410 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-2d10695410 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-2d10695410 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-2d10695410 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-2d10695410 .tabular-table tbody tr td { border-top: none; }
#> #tabular-2d10695410 .tabular-band { text-align: center; }
#> #tabular-2d10695410 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-2d10695410 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-2d10695410 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-2d10695410 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-2d10695410 .text-left { text-align: left; }
#> #tabular-2d10695410 .text-center { text-align: center; }
#> #tabular-2d10695410 .text-right { text-align: right; }
#> #tabular-2d10695410 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-2d10695410 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-2d10695410 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-2d10695410 .valign-top { vertical-align: top; }
#> #tabular-2d10695410 .valign-middle { vertical-align: middle; }
#> #tabular-2d10695410 .valign-bottom { vertical-align: bottom; }
#> #tabular-2d10695410 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-2d10695410 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-2d10695410 .tabular-page-break-row { display: none; }
#> #tabular-2d10695410 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-2d10695410 .tabular-page-header, #tabular-2d10695410 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-2d10695410 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-2d10695410 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-2d10695410 .tabular-page-header-left, #tabular-2d10695410 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-2d10695410 .tabular-page-header-center, #tabular-2d10695410 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-2d10695410 .tabular-page-header-right, #tabular-2d10695410 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-2d10695410 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-2d10695410 .tabular-table tr { page-break-inside: avoid; } #tabular-2d10695410 .tabular-page-header, #tabular-2d10695410 .tabular-page-footer { display: none; } #tabular-2d10695410 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-2d10695410 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-2d10695410 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-2d10695410" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">AEs by SOC and PT (wide-page split)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <colgroup>
#> <col style="width:2.5in"/>
#> <col/>
#> <col/>
#> <col style="width:2.0in"/>
#> <col style="width:2.0in"/>
#> <col style="width:2.0in"/>
#> <col style="width:2.0in"/>
#> </colgroup>
#> <thead>
#> <tr><th>SOC / PT</th><th>n_total</th><th>soc_n</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th><th class="text-center">Total</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td>199</td><td class="text-right">52 (60.5)</td><td class="text-right">81 (84.4)</td><td class="text-right">66 (91.7)</td><td class="text-right">199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td>90</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right"> 90 (35.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>54</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>36</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>26</td><td>90</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>14</td><td>90</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>14</td><td>90</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td>81</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right"> 81 (31.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>50</td><td>81</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>30</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>21</td><td>81</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>21</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>11</td><td>81</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td>42</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 42 (16.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>17</td><td>42</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>13</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>12</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>5</td><td>42</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>4</td><td>42</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td>41</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 41 (16.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>21</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>11</td><td>41</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>7</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>6</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>3</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td>33</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 33 (13.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>17</td><td>33</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>10</td><td>33</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>5</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="7"></td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td>29</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right"> 29 (11.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>12</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>10</td><td>29</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>3</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>3</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>2</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td>22</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 22 ( 8.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>11</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>7</td><td>22</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>3</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>3</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>2</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td>19</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 19 ( 7.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>6</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>5</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>4</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>3</td><td>19</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>2</td><td>19</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td>14</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>5</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>4</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>3</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>2</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>1</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td>12</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>5</td><td>12</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>4</td><td>12</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>2</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>2</td><td>12</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">1</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
