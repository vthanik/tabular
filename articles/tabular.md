# Get started with tabular

`tabular` turns one **pre-summarised, wide data frame** into a
publication-ready table and renders it natively to **RTF, HTML, DOCX,
PDF (LaTeX- or typst-compiled), LaTeX, Typst and Markdown** — from a
single spec, with no Java or Office dependency.

Two things to internalise up front:

1.  **tabular is display-only.** It never aggregates, filters, or
    computes statistics. You bring a summarised data frame (one input
    row = one display row); tabular lays it out and renders it.
    (Producing that frame from a cards ARD is the [*Data
    in*](https://vthanik.github.io/tabular/articles/data-in.html)
    article.)
2.  **One immutable spec, built with verbs.** You pipe a
    [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
    object through verbs
    ([`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
    [`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
    [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
    [`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
    …) and finish with
    [`emit()`](https://vthanik.github.io/tabular/reference/emit.md).
    Each verb returns a new spec; nothing renders until
    [`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Your first table

Start from a wide frame — here the bundled demographics summary, one row
per statistic, one column per treatment arm:

``` r

data(cdisc_saf_demo, package = "tabular")
head(cdisc_saf_demo)
#>      variable stat_label     placebo     drug_50    drug_100       Total
#> 1 Age (years)          n          86          96          72         254
#> 2 Age (years)  Mean (SD) 75.2 (8.59) 76.0 (8.11) 73.8 (7.94) 75.1 (8.25)
#> 3 Age (years)     Median        76.0        78.0        75.5        77.0
#> 4 Age (years)     Q1, Q3  69.2, 81.8  71.0, 82.0  70.5, 79.0  70.0, 81.0
#> 5 Age (years)   Min, Max      52, 89      51, 88      56, 88      51, 89
#> 6  Sex, n (%)          F   53 (61.6)   55 (57.3)   35 (48.6)  143 (56.3)
```

Describe the columns. The spec prints as a live HTML table — this is the
same render
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md)
produces, shown inline:

``` r

spec <- tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14-2.01",
    "Demographic and Baseline Characteristics",
    "ITT Population"
  )
) |>
  cols(
    variable = col_spec(label = ""),
    stat_label = col_spec(label = "")
  ) |>
  group_rows(by = "variable")

spec
```

|  | placebo | drug_50 | drug_100 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| n | 86 | 96 | 72 | 254 |
| Mean (SD) | 75.2 (8.59) | 76.0 (8.11) | 73.8 (7.94) | 75.1 (8.25) |
| Median | 76.0 | 78.0 | 75.5 | 77.0 |
| Q1, Q3 | 69.2, 81.8 | 71.0, 82.0 | 70.5, 79.0 | 70.0, 81.0 |
| Min, Max | 52, 89 | 51, 88 | 56, 88 | 51, 89 |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F | 53 (61.6) | 55 (57.3) | 35 (48.6) | 143 (56.3) |
| M | 33 (38.4) | 41 (42.7) | 37 (51.4) | 111 (43.7) |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE | 78 (90.7) | 90 (93.8) | 62 (86.1) | 230 (90.6) |
| BLACK OR AFRICAN AMERICAN | 8 (9.3) | 6 (6.2) | 9 (12.5) | 23 (9.1) |
| ASIAN | 0 (0.0) | 0 (0.0) | 0 (0.0) | 0 (0.0) |
| AMERICAN INDIAN OR ALASKA NATIVE | 0 (0.0) | 0 (0.0) | 1 (1.4) | 1 (0.4) |

 

Table 14-2.01

Demographic and Baseline Characteristics

ITT Population

 

To write a file, hand the spec to
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md); the
backend is chosen by the file extension (or an explicit `format =`):

``` r

out <- tempfile(fileext = ".rtf")
emit(spec, out) # RTF here; swap to .docx / .pdf / .html / .tex / .typ / .md
file.exists(out)
#> [1] TRUE
```

That is the whole loop: **wide frame →
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) →
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) →
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md)** — one
spec, any backend.

## The pipeline at a glance

Read it left to right. You **summarise upstream** — with cards/cardx,
dplyr, or SAS — into a long ARD, widen that to a display-ready frame
with
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md),
then hand it to tabular. Inside the package the work happens in three
phases (**Build → Resolve → Emit**), and the *same* resolved spec emits
to every backend, so the HTML you preview and the RTF you ship can never
disagree.

![An ADaM dataset is aggregated into a long ARD, widened by pivot_across
into a wide data frame, then Build, Resolve, and Emit render that one
spec to RTF, PDF, HTML, LaTeX, and
DOCX.](../reference/figures/workflow.svg)

tabular’s pipeline: summarise upstream into a long ARD, widen it with
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md),
then build, resolve, and emit one immutable spec to every backend.

## Anatomy of a clinical table page

A submission table is not just a grid of numbers — it is a page with
four stacked sections, and a reviewer expects each one in its place.
Every tabular verb maps onto a piece of this picture:

![A clinical table page split into header section, title lines, data
section, and footnote lines, each annotated with the tabular verb that
produces it.](../reference/figures/anatomy.svg)

The four-section clinical page and the verb that fills each section.

- **Header section** — the running protocol, optional status, and *page
  x of y*, set as page chrome with `preset(pagehead =, pagefoot =)`.
- **Title lines** — the table number and up to four centred titles,
  passed to `tabular(titles =)`.
- **Data section** — an optional
  [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
  banner, the column-header band built by
  [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) and
  [`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
  then the decimal-aligned data.
- **Footnote lines** — your static `footnotes =` plus any auto-numbered
  [`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md)
  markers, then the program path, name, and timestamp.

[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
frames all four by controlling the page geometry (paper, orientation,
margins, fonts).

## Where to next

The rest of the docs are task-oriented — read the one that matches what
you are doing:

- **[Data in](https://vthanik.github.io/tabular/articles/data-in.html)**
  — turn a cards/cardx ARD (or any long ARD) into the wide frame, with
  [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md).
- **[Structure](https://vthanik.github.io/tabular/articles/structure.html)**
  — columns, headers, BigN, and splitting wide or long tables across
  pages
  ([`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
  [`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
  [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
  [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)).
- **[Presentation](https://vthanik.github.io/tabular/articles/presentation.html)**
  — titles, footnotes, running headers, and cell styling
  ([`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md),
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
  [`style()`](https://vthanik.github.io/tabular/reference/style.md)).
- **[Recipes](https://vthanik.github.io/tabular/articles/recipes.html)**
  — the canonical CDISC-pilot safety and efficacy tables built end to
  end, each rendered live.
- **[Output &
  qualification](https://vthanik.github.io/tabular/articles/output.html)**
  — the backends, their system requirements, and the CDISC-pilot
  cross-backend validation.
