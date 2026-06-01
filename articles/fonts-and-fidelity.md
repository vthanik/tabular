# Fonts & fidelity

``` r

library(tabular)
#> 
#> Attaching package: 'tabular'
#> The following object is masked from 'package:stats':
#> 
#>     pt
```

A submission table is a *typeset* artefact. Two facts follow from that,
and they shape how `tabular` renders: clinical tables are monospace, and
the deliverable is the paginated print output, not the screen preview.

## Why monospace

Reviewers scan a column of numbers by eye, so the digits must line up on
the decimal point. That only works reliably when every character has the
**same advance width** — a monospace font. In a proportional font, `1`
is narrower than `8`, and a column of `11.1` over `88.8` drifts out of
alignment.

`tabular` therefore renders table cells in a monospace family and aligns
`align = "decimal"` columns using the backend’s **real font metrics**,
not guessed spaces. The alignment computed at Resolve time is the
alignment you get on the page.

``` r

tabular(saf_aeoverall) |>
  cols(
    stat_label = col_spec(label = "Category"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  )
```

| Category                     | Total      | Placebo   | Drug 100  | Drug 50   |
|------------------------------|------------|-----------|-----------|-----------|
| Any TEAE                     | 217 (85.4) | 65 (75.6) | 68 (94.4) | 84 (87.5) |
| Any Serious AE (SAE)         |   3 ( 1.2) |  0        |  1 ( 1.4) |  2 ( 2.1) |
| Any AE Related to Study Drug | 184 (72.4) | 43 (50.0) | 64 (88.9) | 77 (80.2) |
| Any AE Leading to Death      |   3 ( 1.2) |  2 ( 2.3) |  0        |  1 ( 1.0) |
| Any AE Recovered / Resolved  | 157 (61.8) | 47 (54.7) | 49 (68.1) | 61 (63.5) |
| Maximum severity: Mild       |  77 (30.3) | 36 (41.9) | 20 (27.8) | 21 (21.9) |
| Maximum severity: Moderate   | 111 (43.7) | 24 (27.9) | 40 (55.6) | 47 (49.0) |
| Maximum severity: Severe     |  29 (11.4) |  5 ( 5.8) |  8 (11.1) | 16 (16.7) |

## Choosing a font

Regulatory tables are conventionally set in **Courier New** or **Times
New Roman** at 8–9 pt; agency style guidance (FDA, EMA, PMDA) drives the
exact choice per submission. Set the family and size on
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md):

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  preset(font_family = "Courier New", font_size = 9)
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

## Auditing availability with `check_fonts()`

Each backend resolves a font through a fallback stack.
[`check_fonts()`](https://vthanik.github.io/tabular/reference/check_fonts.md)
reports which fonts in the active stack are actually installed on the
machine and returns the per-backend stacks, so you can confirm the
submission font is present before a batch run:

``` r

sp <- tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(align = "decimal"),
    drug_50    = col_spec(align = "decimal"),
    drug_100   = col_spec(align = "decimal"),
    Total      = col_spec(align = "decimal")
  )

stacks <- check_fonts(sp)
#> 
#> ── Font resolution for `font_family = mono`
#> backend: html
#> x Liberation Mono (not on this machine)
#> v Courier New
#> x Courier (not on this machine)
#> o monospace (generic, always available)
#> backend: latex
#> x Liberation Mono (not on this machine)
#> v Courier New
#> x Courier (not on this machine)
#> x TeX Gyre Cursor (not on this machine)
#> x Latin Modern Mono (not on this machine)
#> backend: rtf
#> x Liberation Mono (not on this machine)
#> v Courier New
#> x Courier (not on this machine)
stacks$rtf
#> [1] "Liberation Mono" "Courier New"     "Courier"
```

A missing font is not fatal — the backend falls through the stack — but
for a submission you want the named font present so the rendered metrics
match the agency’s expectation.

## The preview is not the deliverable

This site shows a **live HTML preview** of every table, which is
invaluable while you build. But the artefact you ship is the paginated
**RTF, PDF, or DOCX**:

|  | HTML preview | RTF / PDF / DOCX deliverable |
|----|----|----|
| Pages | one continuous document | real, paginated |
| Repeated chrome | n/a | titles / headers / footnotes per page |
| Font metrics | browser CSS monospace | backend’s real font metrics |
| Page layout | scrollable | the four-section submission layout |
| Role | build & eyeball | the artefact of record |

Both come from the **same resolved grid**, so the numbers and structure
cannot drift between them — but pagination, repeated chrome, and exact
metrics only exist in the print backends. Build and check in HTML, then:

``` r

sp |> emit("t_14_1_1.rtf")     # the deliverable
sp |> emit("t_14_1_1.pdf")     # paginated PDF via tinytex
sp |> emit("t_14_1_1.docx")    # native Word
```

## Where to next

- **[Architecture](https://vthanik.github.io/tabular/articles/architecture.md)**
  — how Resolve computes the metrics-aware grid that every backend
  consumes.
- **[Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md)**
  — the recipes you would emit to these formats. \`\`\`
