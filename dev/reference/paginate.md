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
  .spec,
  keep_together = character(),
  panels = 1,
  orphan_floor = 3,
  widow_floor = 2,
  repeat_content = c("titles", "headers", "footnotes"),
  continuation = NULL
)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach pagination to.*
  `<tabular_spec>: required`.

- keep_together:

  *Group columns whose runs of identical values must not be split across
  a page break.* `<character>: default character()`. Every entry must be
  a `usage = "group"` column declared in
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md).

  **Interaction:** A run too tall to fit in the computed row budget less
  `orphan_floor` is split anyway; pagination is best-effort, not a hard
  contract.

      # Protect the SOC-level grouping in an AE-by-SOC/PT table.
      paginate(keep_together = "soc")

- panels:

  *Number of horizontal panels for wide tables.*
  `<integer(1)>: default 1`. With `1`, every column is on every page
  (single vertical scroll). With `N > 1`, the engine splits non-group
  columns into `N` chunks and repeats every group column on every panel.

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
  explicitly.

  **Backend support is uneven** — verify against your render target:

  - **PDF / LaTeX** — full: the marker prints on every continuation page
    (both vertical page overflow and horizontal panels).

  - **RTF** — horizontal continuation *panels* only
    (`paginate(panels = N)`); the marker does NOT appear on vertical
    page-overflow continuations.

  - **DOCX** — not marked. DOCX paginates natively but emits no
    continuation marker.

  - **HTML / MD** — ignored. With one continuous document on screen
    there is no continuing-page boundary to mark.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)).

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

## See also

**Render-geometry partner:**
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
/
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
— the preset's paper, orientation, margins, and font size feed the
per-page row budget this verb depends on.

**Sibling build verbs:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

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
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(usage = "group", visible = FALSE,
                        group_display = "column_repeat"),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
    Total    = col_spec(label = "Total\nN={n['Total']}")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE)) |>
  paginate(
    keep_together = "soc",
    repeat_content = c("titles", "headers", "footnotes"),
    continuation = "(continued)"
  )

#tabular-11fb8f5e9f { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-11fb8f5e9f .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-11fb8f5e9f p { line-height: inherit; }
#tabular-11fb8f5e9f .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-11fb8f5e9f .tabular-caption { margin: 0; padding: 0; }
#tabular-11fb8f5e9f .tabular-pad { margin: 0; line-height: 1; }
#tabular-11fb8f5e9f .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-11fb8f5e9f .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-11fb8f5e9f .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-11fb8f5e9f .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-11fb8f5e9f .tabular-table th, #tabular-11fb8f5e9f .tabular-table td { padding: .18rem .6rem; }
#tabular-11fb8f5e9f .tabular-table td { text-align: left; vertical-align: top; }
#tabular-11fb8f5e9f .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-11fb8f5e9f .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-11fb8f5e9f .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-11fb8f5e9f .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-11fb8f5e9f .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-11fb8f5e9f .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-11fb8f5e9f .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-11fb8f5e9f .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-11fb8f5e9f .tabular-table tbody tr td { border-top: none; }
#tabular-11fb8f5e9f .tabular-band { text-align: center; }
#tabular-11fb8f5e9f .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-11fb8f5e9f .tabular-subgroup-label { font-weight: 600; }
#tabular-11fb8f5e9f .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-11fb8f5e9f .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-11fb8f5e9f .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-11fb8f5e9f .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-11fb8f5e9f .text-left { text-align: left; }
#tabular-11fb8f5e9f .text-center { text-align: center; }
#tabular-11fb8f5e9f .text-right { text-align: right; }
#tabular-11fb8f5e9f .tabular-table thead th.text-left { text-align: left; }
#tabular-11fb8f5e9f .tabular-table thead th.text-center { text-align: center; }
#tabular-11fb8f5e9f .tabular-table thead th.text-right { text-align: right; }
#tabular-11fb8f5e9f .tabular-table td.text-left { text-align: left; }
#tabular-11fb8f5e9f .tabular-table td.text-center { text-align: center; }
#tabular-11fb8f5e9f .tabular-table td.text-right { text-align: right; }
#tabular-11fb8f5e9f .valign-top { vertical-align: top; }
#tabular-11fb8f5e9f .valign-middle { vertical-align: middle; }
#tabular-11fb8f5e9f .valign-bottom { vertical-align: bottom; }
#tabular-11fb8f5e9f .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-11fb8f5e9f .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-11fb8f5e9f .tabular-page-break-row { display: none; }
#tabular-11fb8f5e9f { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-11fb8f5e9f .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-11fb8f5e9f .tabular-page-header, #tabular-11fb8f5e9f .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-11fb8f5e9f .tabular-page-header { margin-bottom: 1rem; }
#tabular-11fb8f5e9f .tabular-page-footer { margin-top: 1rem; }
#tabular-11fb8f5e9f .tabular-page-header-left, #tabular-11fb8f5e9f .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-11fb8f5e9f .tabular-page-header-center, #tabular-11fb8f5e9f .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-11fb8f5e9f .tabular-page-header-right, #tabular-11fb8f5e9f .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-11fb8f5e9f .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-11fb8f5e9f .tabular-table tr { page-break-inside: avoid; } #tabular-11fb8f5e9f .tabular-page-header, #tabular-11fb8f5e9f .tabular-page-footer { display: none; } #tabular-11fb8f5e9f .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-11fb8f5e9f .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-11fb8f5e9f .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



```
