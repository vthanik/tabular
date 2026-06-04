# Columns & headers

``` r

library(tabular)
```

Two verbs shape the columns of a table.
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) names
each data column and hands it a
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md);
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
groups those columns under multi-level spanning bands. This article
covers both.

## Naming columns with `cols()`

[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) takes
one named argument per data-frame column. The name is the column in your
data; the value is a
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
describing how to show it. Columns you do not name keep their defaults.

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

> **Column order is the data frame’s, not the call’s**
>
> Columns render in the order they appear in the **data frame**, not the
> order you list them in
> [`cols()`](https://vthanik.github.io/tabular/reference/cols.md). To
> reorder, reorder the data first:
>
> ``` r
>
> demo <- saf_demo[c("variable", "stat_label", "placebo", "drug_50", "drug_100", "Total")]
> ```

## The `col_spec()` toolbox

Every column option lives on
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md):

| Argument | What it does |
|----|----|
| `label` | Column-header text (use `\n` for multi-line headers) |
| `align` | `"left"`, `"center"`, `"right"`, or `"decimal"` |
| `usage` | `"display"` (default), `"group"`, `"indent"`, or `"id"` |
| `group_display` | For a group column: `"header_row"`, `"column"`, `"column_repeat"` |
| `visible` | `FALSE` keeps the column in the data but off the page |
| `na_text` | String shown for `NA` cells (default `""`) |
| `width` | `"auto"`, a number (inches), or a unit string like `"3cm"` |
| `indent_by` | Name of a column holding per-row indent depth |
| `format` | A formatter applied to the column’s values |

### Decimal alignment

`align = "decimal"` lines numbers up on the decimal point using real
font metrics, so a column of `53 (62.1%)` and `8 (9.3%)` stays aligned
in print. It is the workhorse alignment for clinical value columns.

### Group columns: section headers or a repeated column

A `usage = "group"` column does not become an ordinary column. By
default (`group_display = "header_row"`) its values become **bold
section-header rows**:

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group"),                # bold section rows
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

Switch to `group_display = "column"` to keep the group label as a real
left-hand column instead of section rows — useful when each group has a
single row.

## Hiding the columns that drive the display

Many clinical tables carry columns that control sorting, indentation, or
styling but should not appear on the page. Set `visible = FALSE`: the
column stays in `spec@data` (so
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
`indent_by`, and
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
predicates can still use it) but is not rendered.

The AE-by-SOC/PT table is the canonical case. Its `row_type`,
`indent_level`, and sort-key columns are hidden, and the preferred terms
are indented under their system-organ-class header via `indent_by`:

``` r

# first two system-organ-class blocks, to keep the preview short
ae <- saf_aesocpt[1:14, ]

tabular(
  ae,
  titles = "Table 14.3.1  Adverse Events by System Organ Class and Preferred Term"
) |>
  cols(
    soc          = col_spec(visible = FALSE),
    row_type     = col_spec(visible = FALSE),
    indent_level = col_spec(visible = FALSE),
    n_total      = col_spec(visible = FALSE),
    soc_n        = col_spec(visible = FALSE),
    label        = col_spec(label = "System Organ Class / Preferred Term",
                            indent_by = "indent_level"),
    placebo      = col_spec(label = "Placebo",  align = "decimal"),
    drug_50      = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100     = col_spec(label = "Drug 100", align = "decimal"),
    Total        = col_spec(label = "Total",    align = "decimal")
  ) |>
  style(bold = TRUE, .at = cells_body(where = row_type %in% c("overall", "soc")))
```

| System Organ Class / Preferred Term | Placebo | Drug 50 | Drug 100 | Total |
|----|----|----|----|----|
| TOTAL SUBJECTS WITH AN EVENT | 52 (60.5) | 81 (84.4) | 66 (91.7) | 199 (78.3) |
| SKIN AND SUBCUTANEOUS TISSUE DISORDERS | 19 (22.1) | 36 (37.5) | 35 (48.6) |  90 (35.4) |
| PRURITUS |  8 ( 9.3) | 21 (21.9) | 25 (34.7) |  54 (21.3) |
| ERYTHEMA |  8 ( 9.3) | 14 (14.6) | 14 (19.4) |  36 (14.2) |
| RASH |  5 ( 5.8) | 13 (13.5) |  8 (11.1) |  26 (10.2) |
| HYPERHIDROSIS |  2 ( 2.3) |  4 ( 4.2) |  8 (11.1) |  14 ( 5.5) |
| SKIN IRRITATION |  3 ( 3.5) |  6 ( 6.2) |  5 ( 6.9) |  14 ( 5.5) |
| GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS | 15 (17.4) | 36 (37.5) | 30 (41.7) |  81 (31.9) |
| APPLICATION SITE PRURITUS |  6 ( 7.0) | 23 (24.0) | 21 (29.2) |  50 (19.7) |
| APPLICATION SITE ERYTHEMA |  3 ( 3.5) | 13 (13.5) | 14 (19.4) |  30 (11.8) |
| APPLICATION SITE DERMATITIS |  5 ( 5.8) |  9 ( 9.4) |  7 ( 9.7) |  21 ( 8.3) |
| APPLICATION SITE IRRITATION |  3 ( 3.5) |  9 ( 9.4) |  9 (12.5) |  21 ( 8.3) |
| APPLICATION SITE VESICLES |  1 ( 1.2) |  5 ( 5.2) |  5 ( 6.9) |  11 ( 4.3) |
| GASTROINTESTINAL DISORDERS | 13 (15.1) | 12 (12.5) | 17 (23.6) |  42 (16.5) |

 

Table 14.3.1  Adverse Events by System Organ Class and Preferred Term

 

## BigN in the header

Treatment-group denominators belong in the column headers. Pull them
from the bundled `saf_n` and interpolate them into the labels with a
glue-style `{expr}` template — the expression is evaluated when
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) runs, so
any object in scope (here the named vector `n`) is fair game:

``` r

n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\n(N={n['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={n['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={n['drug_100']})", align = "decimal"),
    Total      = col_spec(label = "Total\n(N={n['Total']})",    align = "decimal")
  )
```

[TABLE]

> **Why a data frame for BigN, not an attribute?**
>
> `saf_n` is a discoverable data frame, not an attribute on `saf_demo`,
> because attributes get silently stripped by `dplyr` and base-R
> subsetting. Keying the labels off `saf_n$arm_short` keeps the
> denominators robust to upstream data wrangling.

## Multi-level headers with `headers()`

[`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
builds spanning bands above the leaf columns. A named character vector
spans those columns under one label:

``` r

n <- stats::setNames(saf_n$n, saf_n$arm_short)

base <- tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\n(N={n['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={n['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={n['drug_100']})", align = "decimal"),
    Total      = col_spec(label = "Total\n(N={n['Total']})",    align = "decimal")
  )

base |>
  headers(
    "Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")
  )
```

[TABLE]

Nest a [`list()`](https://rdrr.io/r/base/list.html) to put a spanner
over a subset, leaving other columns as **passthrough leaves** (bare
strings, no band above them):

``` r

base |>
  headers(
    "Treatment Group" = list(
      "placebo",                                    # passthrough leaf
      "Active Drug" = c("drug_50", "drug_100"),     # sub-spanner
      "Total"                                       # passthrough leaf
    )
  )
```

[TABLE]

> **Spanned columns must be contiguous**
>
> A spanner sits above adjacent columns, so the columns named in one
> band must be next to each other in the data frame. If `drug_50` and
> `drug_100` are separated by another column, reorder the data first.

## Column widths and `width_mode`

Width has two layers: a **per-column** pin on `col_spec(width = ...)`,
and a **table-level** policy on `preset(width_mode = ...)` that decides
what happens to the columns you did not pin.

A
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
pin accepts `"auto"` (the engine measures the widest cell), a bare
number in inches (`width = 1.8`), or a unit string (`"3cm"`, `"30mm"`,
`"30pt"`, or a percent of the content width like `"25%"`):

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", width = "2.4in"),
    stat_label = col_spec(label = "Statistic", width = "1.2in"),
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

`width_mode` governs the columns left on `"auto"`. It mirrors Word’s
Table Layout menu:

| `width_mode` | Auto columns | Word equivalent |
|----|----|----|
| `"content"` *(default)* | sized to `max(body, header)`; table need not fill the page | Auto-fit Contents |
| `"window"` | expand to share the residual page width equally | Auto-fit Window |
| `"fixed"` | collapse to a minimum sliver; only pinned widths drive layout | Fixed Column Width |

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  preset(width_mode = "window")   # auto columns fill the page width
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

> **`width_mode` drives the paper backends, not HTML**
>
> `width_mode` shapes the **RTF, PDF, LaTeX, and DOCX** layouts. HTML is
> unconditionally responsive — the table always fills its parent and the
> columns wrap as the viewport narrows — so the preview above looks the
> same whatever `width_mode` you pick. Per-column `width` pins still
> emit verbatim into the HTML colgroup. Eyeball widths by emitting to a
> paper backend.

## Going deeper

- **Formatters.** `format` accepts a function applied to the column’s
  values before rendering — handy when the upstream data is numeric and
  you want display rounding at render time.
- **Where next.** [Rows, grouping &
  pagination](https://vthanik.github.io/tabular/articles/rows-grouping-pagination.md)
  covers row order and section groups;
  [Styling](https://vthanik.github.io/tabular/articles/styling.md)
  targets any header band or column with
  [`style()`](https://vthanik.github.io/tabular/reference/style.md) +
  [`cells_headers()`](https://vthanik.github.io/tabular/reference/cells.md).
