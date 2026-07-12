# Start a tabular display

Wrap a pre-summarised data frame into a `tabular_spec` ready for the
verb chain. `tabular()` is the entry verb — it owns the `data`,
`titles`, and `footnotes` slots; every downstream verb
([`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md))
returns an updated spec for further chaining, terminating in
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
(write to file) or
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
(resolve without writing).

## Usage

``` r
tabular(data, titles = NULL, footnotes = NULL, empty_text = NULL)
```

## Arguments

- data:

  *The display rows.* `<data.frame>: required`. Pre-summarised
  wide-format data; tibbles, data.tables, and arrow tables are coerced
  via [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).
  Factor columns are preserved (their levels drive
  [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)).

  **Restriction:** At least one column; column names must be unique.
  Zero rows is accepted (engine renders a "No data" stub).
  **Interaction:** The `cards`-format counterparts
  (`cdisc_saf_demo_ard`, `cdisc_saf_aesocpt_ard`) are NOT accepted
  directly; pipe through
  [`pivot_across()`](https://vthanik.github.io/tabular/dev/reference/pivot_across.md)
  first.

- titles:

  *Page-title block, one element per row.*
  `<character> | NULL: default NULL`. Each element renders on its own
  centred line; embedded `\n` wraps within that row. The backend
  collapses unused rows so the column-header band sits flush against the
  lowest used title.

  **Restriction:** No NAs.

  Each element supports glue-style `{expr}` interpolation: braces are
  evaluated as R code in the calling environment at build time, e.g.
  `"N total = {sum(n)}"`. Double a brace (`{{` or `}}`) for a literal
  one. An
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  element is passed through without interpolation.

      # Canonical 3-line title block with BigN-qualified population.
      n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
      titles = c(
        "Table 14.3.1",
        "Adverse Events by System Organ Class and Preferred Term",
        "Safety Population"
      )

- footnotes:

  *Page-footnote block, one element per row.*
  `<character> | NULL: default NULL`. User-supplied prose rows only; the
  backend appends its own program-path / program-name / timestamp band
  below them at render time.

  **Restriction:** No NAs.

  Each element supports glue-style `{expr}` interpolation (see
  `titles`).

      # Canonical 3-line footnote block.
      footnotes = c(
        "Subjects are counted once per SOC and once per PT.",
        "Percentages based on N per treatment group.",
        "TEAE = treatment-emergent adverse event."
      )

- empty_text:

  *Placeholder shown when `data` has zero rows.*
  `<character(1) | NULL>: default NULL`. When the display resolves to no
  data rows, the backends still emit the full page chrome and — when a
  column structure is present — the column headers, then place this
  message in the body where the rows would sit. `NULL` (the default)
  inherits the house-style wording from `preset(empty_text = ...)` when
  set, falling back to the built-in `"No data available to report"`.
  Pass any sponsor or study wording (a localized string, "No subjects
  met the criteria for this table.", a protocol-qualified line) to
  override per table; glue `{expr}` interpolation and
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  are honoured, exactly like a title line.

  The message renders as a single horizontally centred row in the table
  body, where the first data row would otherwise sit.

## Value

*A `tabular_spec` S7 object.* Pipe it into
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
and
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
to build the display, then into
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) to
render or
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
to resolve without writing.

## Details

**Pre-summarised input contract.** `data` is one row per displayed row
of the final table. `tabular()` does not aggregate, filter, weight, or
generate subtotal rows — those happen upstream in `cards`, `dplyr`, or
SAS. If the upstream is a long `cards::ard_stack()` ARD, pipe through
[`pivot_across()`](https://vthanik.github.io/tabular/dev/reference/pivot_across.md)
first to land in the wide shape `tabular()` accepts.

**Multi-line titles and footnotes by contract.** Clinical tables
routinely carry 2-4 title rows and 1-4 user footnote rows. Pass each row
as one element of the character vector; the backend renders each element
on its own line, collapsing unused rows so the column-header band sits
flush against the lowest used title.

## See also

**Downstream build verbs:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).

**Terminal verbs:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
(write),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
(resolve without I/O).

**Input helper:**
[`pivot_across()`](https://vthanik.github.io/tabular/dev/reference/pivot_across.md)
(cards ARD -\> wide).

**Demo data:** `cdisc_saf_demo`, `cdisc_saf_aesocpt`, `cdisc_eff_resp`,
`cdisc_saf_n`, `cdisc_eff_n`.

## Examples

``` r
# ---- Example 1: Adverse-event table by SOC and Preferred Term ----
#
# The regulatory work-horse layout: AE-by-SOC/PT with the
# canonical 3-line title block (table number, description,
# population qualifier with BigN drawn inline from `cdisc_saf_n`) and a
# two-line footnote block explaining the denominator. The
# downstream pipeline hides the hierarchy markers (`row_type`,
# `soc_n`, `n_total`) but keeps them in the data so `sort_rows()`
# can arrange SOCs and PTs in descending order of subject count.
# The dataset already ships `n_total` and `soc_n`; here we slice to
# the overall row plus the two highest-incidence SOCs to keep the
# preview compact.
ae <- cdisc_saf_aesocpt
keep_soc <- head(unique(ae$soc[ae$row_type == "soc"]), 2L)
ae <- ae[ae$row_type == "overall" | ae$soc %in% keep_soc, ]
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = c(
    "Subjects are counted once per SOC and once per PT.",
    "Percentages based on N per treatment group."
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
    Total    = col_spec(label = "Total\nN={n['Total']}")
  ) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))

#tabular-44ce677a75 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-44ce677a75 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-44ce677a75 p { line-height: inherit; }
#tabular-44ce677a75 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-44ce677a75 .tabular-caption { margin: 0; padding: 0; }
#tabular-44ce677a75 .tabular-pad { margin: 0; line-height: 1; }
#tabular-44ce677a75 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-44ce677a75 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-44ce677a75 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-44ce677a75 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-44ce677a75 .tabular-table th, #tabular-44ce677a75 .tabular-table td { padding: .18rem .6rem; }
#tabular-44ce677a75 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-44ce677a75 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-44ce677a75 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-44ce677a75 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-44ce677a75 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-44ce677a75 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-44ce677a75 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-44ce677a75 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-44ce677a75 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-44ce677a75 .tabular-table tbody tr td { border-top: none; }
#tabular-44ce677a75 .tabular-band { text-align: center; }
#tabular-44ce677a75 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-44ce677a75 .tabular-subgroup-label { font-weight: 600; }
#tabular-44ce677a75 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-44ce677a75 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-44ce677a75 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-44ce677a75 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-44ce677a75 .text-left { text-align: left; }
#tabular-44ce677a75 .text-center { text-align: center; }
#tabular-44ce677a75 .text-right { text-align: right; }
#tabular-44ce677a75 .tabular-table thead th.text-left { text-align: left; }
#tabular-44ce677a75 .tabular-table thead th.text-center { text-align: center; }
#tabular-44ce677a75 .tabular-table thead th.text-right { text-align: right; }
#tabular-44ce677a75 .tabular-table td.text-left { text-align: left; }
#tabular-44ce677a75 .tabular-table td.text-center { text-align: center; }
#tabular-44ce677a75 .tabular-table td.text-right { text-align: right; }
#tabular-44ce677a75 .valign-top { vertical-align: top; }
#tabular-44ce677a75 .valign-middle { vertical-align: middle; }
#tabular-44ce677a75 .valign-bottom { vertical-align: bottom; }
#tabular-44ce677a75 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-44ce677a75 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-44ce677a75 .tabular-page-break-row { display: none; }
#tabular-44ce677a75 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-44ce677a75 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-44ce677a75 .tabular-page-header, #tabular-44ce677a75 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-44ce677a75 .tabular-page-header { margin-bottom: 1rem; }
#tabular-44ce677a75 .tabular-page-footer { margin-top: 1rem; }
#tabular-44ce677a75 .tabular-page-header-left, #tabular-44ce677a75 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-44ce677a75 .tabular-page-header-center, #tabular-44ce677a75 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-44ce677a75 .tabular-page-header-right, #tabular-44ce677a75 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-44ce677a75 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-44ce677a75 .tabular-table tr { page-break-inside: avoid; } #tabular-44ce677a75 .tabular-page-header, #tabular-44ce677a75 .tabular-page-footer { display: none; } #tabular-44ce677a75 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-44ce677a75 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-44ce677a75 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



SOC / PT
```
