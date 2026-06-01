# Get started with tabular

`tabular` turns a **pre-summarised data frame** into a regulatory
**table, listing, or figure** (a “TFL”) and renders it natively to RTF,
PDF, HTML, LaTeX, and DOCX. This article gets you from raw numbers to a
finished table in about ten minutes.

> **New to clinical tables?**
>
> A *TFL* is the formatted output that goes into a clinical study report
> or a regulatory submission — for example, a demographics summary or an
> adverse-event table. The numbers are computed upstream (by `cards`,
> `gtsummary`, `dplyr`, or SAS); `tabular`’s job is to *present* them to
> the exacting layout standards reviewers expect.

### The one rule: bring summarised data

`tabular` does **no** statistics. You hand it a wide data frame where
**one row is one display row** and the columns are already the values
you want to show. The bundled `saf_demo` dataset is exactly this shape:

``` r

library(tabular)
#> 
#> Attaching package: 'tabular'
#> The following object is masked from 'package:stats':
#> 
#>     pt

head(saf_demo, 8)
#>           variable stat_label     placebo    drug_100     drug_50       Total
#> 1      Age (years)          n          86          72          96         254
#> 2      Age (years)  Mean (SD) 75.2 (8.59) 73.8 (7.94) 76.0 (8.11) 75.1 (8.25)
#> 3      Age (years)     Median        76.0        75.5        78.0        77.0
#> 4      Age (years)     Q1, Q3  69.2, 81.8  70.5, 79.0  71.0, 82.0  70.0, 81.0
#> 5      Age (years)   Min, Max      52, 89      56, 88      51, 88      51, 89
#> 6 Age Group, n (%)      18-64   14 (16.3)   11 (15.3)     8 (8.3)   33 (13.0)
#> 7 Age Group, n (%)        >64   72 (83.7)   61 (84.7)   88 (91.7)  221 (87.0)
#> 8       Sex, n (%)          F   53 (61.6)   35 (48.6)   55 (57.3)  143 (56.3)
```

Each row is a statistic for one characteristic (`variable`), with one
column per treatment arm. That is all `tabular` needs.

### Your first table

Wrap the data in
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
then describe each column with
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) and
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md).
End the chain with the spec itself to see a live preview:

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo"),
    drug_50    = col_spec(label = "Drug 50"),
    drug_100   = col_spec(label = "Drug 100"),
    Total      = col_spec(label = "Total")
  )
```

| Statistic | Placebo | Drug 100 | Drug 50 | Total |
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
|   |  |  |  |  |
| **BMI Category, n (%)** |  |  |  |  |
| Underweight (\<18.5) | 3 (3.5) | 1 (1.4) | 4 (4.2) | 8 (3.1) |
| Normal (18.5-24.9) | 57 (66.3) | 39 (54.2) | 46 (47.9) | 142 (55.9) |
| Overweight (25-29.9) | 20 (23.3) | 23 (31.9) | 32 (33.3) | 75 (29.5) |
| Obese (\>=30) | 6 (7.0) | 9 (12.5) | 13 (13.5) | 28 (11.0) |

Two things already happened for free: `usage = "group"` turned the
`variable` column into **bold section headers** (Age, Sex, Race, …)
instead of a repeated column, and the table rendered as live HTML right
here in the page.

> **What is that object?**
>
> Every verb returns a `tabular_spec` — an immutable description of the
> table, not the table itself. Nothing is rendered until you print it
> (as above) or call
> [`emit()`](https://vthanik.github.io/tabular/reference/emit.md). You
> can inspect a spec at any point in the pipe with
> [`print()`](https://rdrr.io/r/base/print.html); piping further never
> mutates the previous spec.

### Align the numbers

Clinical tables align numbers on the decimal point. Set
`align = "decimal"` on the value columns and `tabular` pads with real
font metrics so the columns stay aligned in print, not just on screen:

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  )
```

| Statistic | Placebo | Drug 100 | Drug 50 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| n |  86           |  72           |  96           | 254           |
| Mean (SD) |  75.2 (8.59)  |  73.8 (7.94)  |  76.0 (8.11)  |  75.1 (8.25)  |
| Median |  76.0         |  75.5         |  78.0         |  77.0         |
| Q1, Q3 |  69.2, 81.8   |  70.5, 79.0   |  71.0, 82.0   |  70.0, 81.0   |
| Min, Max |  52  , 89     |  56  , 88     |  51  , 88     |  51  , 89     |
|   |  |  |  |  |
| **Age Group, n (%)** |  |  |  |  |
| 18-64 |  14 (16.3)    |  11 (15.3)    |   8 ( 8.3)    |  33 (13.0)    |
| \>64 |  72 (83.7)    |  61 (84.7)    |  88 (91.7)    | 221 (87.0)    |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F |  53 (61.6)    |  35 (48.6)    |  55 (57.3)    | 143 (56.3)    |
| M |  33 (38.4)    |  37 (51.4)    |  41 (42.7)    | 111 (43.7)    |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE |  78 (90.7)    |  62 (86.1)    |  90 (93.8)    | 230 (90.6)    |
| BLACK OR AFRICAN AMERICAN |   8 ( 9.3)    |   9 (12.5)    |   6 ( 6.2)    |  23 ( 9.1)    |
| ASIAN |   0           |   0           |   0           |   0           |
| AMERICAN INDIAN OR ALASKA NATIVE |   0           |   1 ( 1.4)    |   0           |   1 ( 0.4)    |
|   |  |  |  |  |
| **Ethnicity, n (%)** |  |  |  |  |
| HISPANIC OR LATINO |   3 ( 3.5)    |   3 ( 4.2)    |   6 ( 6.2)    |  12 ( 4.7)    |
| NOT HISPANIC OR LATINO |  83 (96.5)    |  69 (95.8)    |  90 (93.8)    | 242 (95.3)    |
| NOT REPORTED |   0           |   0           |   0           |   0           |
|   |  |  |  |  |
| **Weight (kg)** |  |  |  |  |
| n |  86           |  72           |  95           | 253           |
| Mean (SD) |  62.8 (12.77) |  69.5 (14.35) |  68.0 (14.50) |  66.6 (14.13) |
| Median |  60.6         |  69.0         |  66.7         |  66.7         |
| Q1, Q3 |  53.6, 74.2   |  56.9,  80.3  |  56.0,  78.2  |  55.3,  77.1  |
| Min, Max |  34  , 86     |  44  , 108    |  42  , 106    |  34  , 108    |
|   |  |  |  |  |
| **Height (cm)** |  |  |  |  |
| n |  86           |  72           |  96           | 254           |
| Mean (SD) | 162.6 (11.52) | 165.9 (10.28) | 163.7 (10.30) | 163.9 (10.76) |
| Median | 162.6         | 165.1         | 162.6         | 162.8         |
| Q1, Q3 | 154.0, 171.1  | 157.5, 172.8  | 157.5, 170.2  | 156.2, 171.4  |
| Min, Max | 137  , 185    | 146  , 190    | 136  , 196    | 136  , 196    |
|   |  |  |  |  |
| **BMI (kg/m^2)** |  |  |  |  |
| n |  86           |  72           |  95           | 253           |
| Mean (SD) |  23.6 (3.67)  |  25.2 (3.97)  |  25.2 (4.40)  |  24.7 (4.09)  |
| Median |  23.4         |  24.8         |  24.8         |  24.2         |
| Q1, Q3 |  21.2, 25.6   |  22.7, 27.6   |  22.3, 28.2   |  21.9, 27.3   |
| Min, Max |  15  , 33     |  14  , 35     |  15  , 40     |  14  , 40     |
|   |  |  |  |  |
| **BMI Category, n (%)** |  |  |  |  |
| Underweight (\<18.5) |   3 ( 3.5)    |   1 ( 1.4)    |   4 ( 4.2)    |   8 ( 3.1)    |
| Normal (18.5-24.9) |  57 (66.3)    |  39 (54.2)    |  46 (47.9)    | 142 (55.9)    |
| Overweight (25-29.9) |  20 (23.3)    |  23 (31.9)    |  32 (33.3)    |  75 (29.5)    |
| Obese (\>=30) |   6 ( 7.0)    |   9 (12.5)    |  13 (13.5)    |  28 (11.0)    |

### Add the submission chrome

Real tables carry a title block, BigN denominators in the column
headers, a spanning header over the treatment arms, and footnotes. Add
titles and footnotes in
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md), a
spanner with
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
and pull the per-arm denominators from the bundled `saf_n`:

``` r

n <- stats::setNames(saf_n$n, saf_n$arm_short)

tab <- tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = c(
    "Percentages are based on the number of subjects per treatment group.",
    "BMI = body mass index."
  )
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo\n(N=%d)",  n["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\n(N=%d)",  n["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\n(N=%d)", n["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total\n(N=%d)",    n["Total"]),    align = "decimal")
  ) |>
  headers(
    "Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")
  )

tab
```

 

## Table 14.1.1

## Demographic and Baseline Characteristics

## Safety Population (N=254)

 

[TABLE]

Percentages are based on the number of subjects per treatment group.

BMI = body mass index.

That is a submission-shaped demographics table, built from one pipe.

### Render to five formats

The same `tab` emits to any backend.
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md)
dispatches on the file extension (or pass `format =` explicitly):

``` r

out <- file.path(tempdir(), "t_14_1_1")

emit(tab, paste0(out, ".rtf"))    # RTF 1.9.1
emit(tab, paste0(out, ".docx"))   # native OOXML
emit(tab, paste0(out, ".html"))   # self-contained HTML
emit(tab, paste0(out, ".tex"))    # tabularray LaTeX
```

    #>            file bytes
    #> 1 t_14_1_1.docx  8648
    #> 2 t_14_1_1.html 14676
    #> 3  t_14_1_1.rtf 42959
    #> 4  t_14_1_1.tex  7337

> **The preview is not the deliverable**
>
> The live HTML above is a faithful *preview*. The artefact you ship is
> the paginated RTF, PDF, or DOCX — same spec, same numbers, but laid
> out for the page with repeated headers, footnotes, and the
> four-section submission layout. See [Fonts &
> fidelity](https://vthanik.github.io/tabular/articles/fonts-and-fidelity.md)
> for why the print backends are the source of truth.

### Where to next

- **[Core
  concepts](https://vthanik.github.io/tabular/articles/core-concepts.md)**
  — the mental model the rest of the guide assumes (the wide-data
  contract, the page anatomy, the three-phase pipeline).
- **[Columns &
  headers](https://vthanik.github.io/tabular/articles/columns-and-headers.md)**
  — every
  [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
  option and multi-level header bands.
- **[Rows, grouping &
  pagination](https://vthanik.github.io/tabular/articles/rows-grouping-pagination.md)**
  — sort order, section groups, subgroups, and page splits.
- **[Styling](https://vthanik.github.io/tabular/articles/styling.md)** —
  [`style()`](https://vthanik.github.io/tabular/reference/style.md),
  presets, and house styles.
- **[Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md)**
  — six complete production tables end to end. \`\`\`
