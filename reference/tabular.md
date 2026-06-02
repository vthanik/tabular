# Start a tabular display

Wrap a pre-summarised data frame into a `tabular_spec` ready for the
verb chain. `tabular()` is the entry verb — it owns the `data`,
`titles`, and `footnotes` slots; every downstream verb
([`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md))
returns an updated spec for further chaining, terminating in
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (write
to file) or
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
(resolve without writing).

## Usage

``` r
tabular(data, titles = NULL, footnotes = NULL)
```

## Arguments

- data:

  *The display rows.* `<data.frame>: required`. Pre-summarised
  wide-format data; tibbles, data.tables, and arrow tables are coerced
  via [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).
  Factor columns are preserved (their levels drive
  [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)).

  **Restriction:** At least one column; column names must be unique.
  Zero rows is accepted (engine renders a "No data" stub).
  **Interaction:** The `cards`-format counterparts (`saf_demo_card`,
  `saf_aesocpt_card`) are NOT accepted directly; pipe through
  [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
  first.

- titles:

  *Page-title block, one element per row.*
  `<character> | NULL: default NULL`. Each element renders on its own
  centred line; embedded `\n` wraps within that row. The backend
  collapses unused rows so the column-header band sits flush against the
  lowest used title.

  **Restriction:** No NAs.

      # Canonical 3-line title block with BigN-qualified population.
      n <- stats::setNames(saf_n$n, saf_n$arm_short)
      titles = c(
        "Table 14.3.1",
        "Adverse Events by System Organ Class and Preferred Term",
        sprintf("Safety Population (N=%d)", n["Total"])
      )

- footnotes:

  *Page-footnote block, one element per row.*
  `<character> | NULL: default NULL`. User-supplied prose rows only; the
  backend appends its own program-path / program-name / timestamp band
  below them at render time.

  **Restriction:** No NAs.

      # Canonical 3-line footnote block.
      footnotes = c(
        "Subjects are counted once per SOC and once per PT.",
        "Percentages based on N per treatment group.",
        "TEAE = treatment-emergent adverse event."
      )

## Value

*A `tabular_spec` S7 object.* Pipe it into
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
and [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
to build the display, then into
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) to
render or
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) to
resolve without writing.

## Details

**Pre-summarised input contract.** `data` is one row per displayed row
of the final table. `tabular()` does not aggregate, filter, weight, or
generate subtotal rows — those happen upstream in `cards`, `dplyr`, or
SAS. If the upstream is a long
[`cards::ard_stack()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack.html)
ARD, pipe through
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
first to land in the wide shape `tabular()` accepts.

**Multi-line titles and footnotes by contract.** Clinical tables
routinely carry 2-4 title rows and 1-4 user footnote rows. Pass each row
as one element of the character vector; the backend renders each element
on its own line, collapsing unused rows so the column-header band sits
flush against the lowest used title.

## See also

**Downstream build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Terminal verbs:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (write),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
(resolve without I/O).

**Input helper:**
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
(cards ARD -\> wide).

**Demo data:** `saf_demo`, `saf_aesocpt`, `eff_resp`, `saf_n`, `eff_n`.

## Examples

``` r
# ---- Example 1: Adverse-event table by SOC and Preferred Term ----
#
# The regulatory work-horse layout: AE-by-SOC/PT with the
# canonical 3-line title block (table number, description,
# population qualifier with BigN drawn inline from `saf_n`) and a
# two-line footnote block explaining the denominator. The
# downstream pipeline hides the hierarchy markers (`row_type`,
# `n_total`) but keeps them in the data so `sort_rows()` can
# arrange SOCs and PTs in descending order of subject count.
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
  footnotes = c(
    "Subjects are counted once per SOC and once per PT.",
    "Percentages based on N per treatment group."
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))

#tabular-4c9afc481b { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#tabular-4c9afc481b .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-4c9afc481b .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-4c9afc481b .tabular-pad { margin: 0; }
#tabular-4c9afc481b .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-4c9afc481b .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-4c9afc481b .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-4c9afc481b .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-4c9afc481b .tabular-table th, #tabular-4c9afc481b .tabular-table td { padding: .35rem .6rem; }
#tabular-4c9afc481b .tabular-table td { text-align: left; vertical-align: top; }
#tabular-4c9afc481b .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-4c9afc481b .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-4c9afc481b .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-4c9afc481b .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-4c9afc481b .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-4c9afc481b .tabular-table tbody tr td { border-top: none; }
#tabular-4c9afc481b .tabular-band { text-align: center; }
#tabular-4c9afc481b .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-4c9afc481b .tabular-subgroup-label { font-weight: 600; }
#tabular-4c9afc481b .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-4c9afc481b .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-4c9afc481b .text-left { text-align: left; }
#tabular-4c9afc481b .text-center { text-align: center; }
#tabular-4c9afc481b .text-right { text-align: right; }
#tabular-4c9afc481b .tabular-table thead th.text-left { text-align: left; }
#tabular-4c9afc481b .tabular-table thead th.text-center { text-align: center; }
#tabular-4c9afc481b .tabular-table thead th.text-right { text-align: right; }
#tabular-4c9afc481b .valign-top { vertical-align: top; }
#tabular-4c9afc481b .valign-middle { vertical-align: middle; }
#tabular-4c9afc481b .valign-bottom { vertical-align: bottom; }
#tabular-4c9afc481b .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-4c9afc481b .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-4c9afc481b .tabular-page-break-row { display: none; }
#tabular-4c9afc481b { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-4c9afc481b .tabular-page-header, #tabular-4c9afc481b .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-4c9afc481b .tabular-page-header { margin-bottom: 1rem; }
#tabular-4c9afc481b .tabular-page-footer { margin-top: 1rem; }
#tabular-4c9afc481b .tabular-page-header-left, #tabular-4c9afc481b .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-4c9afc481b .tabular-page-header-center, #tabular-4c9afc481b .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-4c9afc481b .tabular-page-header-right, #tabular-4c9afc481b .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-4c9afc481b .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-4c9afc481b .tabular-table tr { page-break-inside: avoid; } #tabular-4c9afc481b .tabular-page-header, #tabular-4c9afc481b .tabular-page-footer { display: none; } #tabular-4c9afc481b .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-4c9afc481b .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-4c9afc481b .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population (N=254)
 



SOC / PT
```
