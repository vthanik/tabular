# Get started with tabular

`tabular` turns one **pre-summarised, wide data frame** into a
publication-ready table and renders it natively to **RTF, HTML, DOCX,
PDF/LaTeX and Markdown** — from a single spec, with no Java or Office
dependency.

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
#>           variable stat_label     placebo    drug_100     drug_50       Total
#> 1      Age (years)          n          86          72          96         254
#> 2      Age (years)  Mean (SD) 75.2 (8.59) 73.8 (7.94) 76.0 (8.11) 75.1 (8.25)
#> 3      Age (years)     Median        76.0        75.5        78.0        77.0
#> 4      Age (years)     Q1, Q3  69.2, 81.8  70.5, 79.0  71.0, 82.0  70.0, 81.0
#> 5      Age (years)   Min, Max      52, 89      56, 88      51, 88      51, 89
#> 6 Age Group, n (%)      18-64   14 (16.3)   11 (15.3)     8 (8.3)   33 (13.0)
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
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(label = "")
  )

spec
```

|  | placebo | drug_100 | drug_50 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| n | 86 | 72 | 96 | 254 |
| Mean (SD) | 75.2 (8.59) | 73.8 (7.94) | 76.0 (8.11) | 75.1 (8.25) |
| Median | 76.0 | 75.5 | 78.0 | 77.0 |
| Q1, Q3 | 69.2, 81.8 | 70.5, 79.0 | 71.0, 82.0 | 70.0, 81.0 |
| Min, Max | 52, 89 | 56, 88 | 51, 88 | 51, 89 |
|   |  |  |  |  |
| **Age Group, n (%)** |  |  |  |  |
| 18-64 | 14 (16.3) | 11 (15.3) | 8 (8.3) | 33 (13.0) |
| \>64 | 72 (83.7) | 61 (84.7) | 88 (91.7) | 221 (87.0) |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F | 53 (61.6) | 35 (48.6) | 55 (57.3) | 143 (56.3) |
| M | 33 (38.4) | 37 (51.4) | 41 (42.7) | 111 (43.7) |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE | 78 (90.7) | 62 (86.1) | 90 (93.8) | 230 (90.6) |
| BLACK OR AFRICAN AMERICAN | 8 (9.3) | 9 (12.5) | 6 (6.2) | 23 (9.1) |
| ASIAN | 0 (0.0) | 0 (0.0) | 0 (0.0) | 0 (0.0) |
| AMERICAN INDIAN OR ALASKA NATIVE | 0 (0.0) | 1 (1.4) | 0 (0.0) | 1 (0.4) |
|   |  |  |  |  |
| **Ethnicity, n (%)** |  |  |  |  |
| HISPANIC OR LATINO | 3 (3.5) | 3 (4.2) | 6 (6.2) | 12 (4.7) |
| NOT HISPANIC OR LATINO | 83 (96.5) | 69 (95.8) | 90 (93.8) | 242 (95.3) |
| NOT REPORTED | 0 (0.0) | 0 (0.0) | 0 (0.0) | 0 (0.0) |
|   |  |  |  |  |
| **Weight (kg)** |  |  |  |  |
| n | 86 | 72 | 95 | 253 |
| Mean (SD) | 62.8 (12.77) | 69.5 (14.35) | 68.0 (14.50) | 66.6 (14.13) |
| Median | 60.6 | 69.0 | 66.7 | 66.7 |
| Q1, Q3 | 53.6, 74.2 | 56.9, 80.3 | 56.0, 78.2 | 55.3, 77.1 |
| Min, Max | 34, 86 | 44, 108 | 42, 106 | 34, 108 |
|   |  |  |  |  |
| **Height (cm)** |  |  |  |  |
| n | 86 | 72 | 96 | 254 |
| Mean (SD) | 162.6 (11.52) | 165.9 (10.28) | 163.7 (10.30) | 163.9 (10.76) |
| Median | 162.6 | 165.1 | 162.6 | 162.8 |
| Q1, Q3 | 154.0, 171.1 | 157.5, 172.8 | 157.5, 170.2 | 156.2, 171.4 |
| Min, Max | 137, 185 | 146, 190 | 136, 196 | 136, 196 |
|   |  |  |  |  |
| **BMI (kg/m^2)** |  |  |  |  |
| n | 86 | 72 | 95 | 253 |
| Mean (SD) | 23.6 (3.67) | 25.2 (3.97) | 25.2 (4.40) | 24.7 (4.09) |
| Median | 23.4 | 24.8 | 24.8 | 24.2 |
| Q1, Q3 | 21.2, 25.6 | 22.7, 27.6 | 22.3, 28.2 | 21.9, 27.3 |
| Min, Max | 15, 33 | 14, 35 | 15, 40 | 14, 40 |
|  |  |  |  |  |
| **BMI Category, n (%)** |  |  |  |  |
| Underweight (\<18.5) | 3 (3.5) | 1 (1.4) | 4 (4.2) | 8 (3.1) |
| Normal (18.5-24.9) | 57 (66.3) | 39 (54.2) | 46 (47.9) | 142 (55.9) |
| Overweight (25-29.9) | 20 (23.3) | 23 (31.9) | 32 (33.3) | 75 (29.5) |
| Obese (\>=30) | 6 (7.0) | 9 (12.5) | 13 (13.5) | 28 (11.0) |

 

Table 14-2.01

Demographic and Baseline Characteristics

ITT Population

 

To write a file, hand the spec to
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md); the
backend is chosen by the file extension (or an explicit `format =`):

``` r

out <- tempfile(fileext = ".rtf")
emit(spec, out) # RTF here; swap to .docx / .pdf / .html / .md
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
