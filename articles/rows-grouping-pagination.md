# Rows, grouping & pagination

``` r

library(tabular)
```

[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) shapes
the columns; three more verbs shape the rows.
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
orders them,
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
partitions the table into labelled blocks, and
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
decides how it breaks across pages.

## Ordering rows with `sort_rows()`

[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
sets the display order. Sort by any column — including hidden ones — and
the engine applies it during Resolve.

``` r

# Display cells are formatted text ("217 (85.4)"), which would sort
# lexically. Derive a hidden numeric key upstream and sort on that.
ae <- saf_aeoverall
ae$total_n <- as.integer(sub(" .*", "", ae$Total))

tabular(
  ae,
  titles = "Adverse-event categories, ordered by total frequency"
) |>
  cols(
    stat_label = col_spec(label = "Category"),
    total_n    = col_spec(visible = FALSE),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  sort_rows(by = "total_n", descending = TRUE)
```

| Category                     | Total      | Placebo   | Drug 100  | Drug 50   |
|------------------------------|------------|-----------|-----------|-----------|
| Any TEAE                     | 217 (85.4) | 65 (75.6) | 68 (94.4) | 84 (87.5) |
| Any AE Related to Study Drug | 184 (72.4) | 43 (50.0) | 64 (88.9) | 77 (80.2) |
| Any AE Recovered / Resolved  | 157 (61.8) | 47 (54.7) | 49 (68.1) | 61 (63.5) |
|   Maximum severity: Moderate | 111 (43.7) | 24 (27.9) | 40 (55.6) | 47 (49.0) |
|   Maximum severity: Mild     |  77 (30.3) | 36 (41.9) | 20 (27.8) | 21 (21.9) |
|   Maximum severity: Severe   |  29 (11.4) |  5 ( 5.8) |  8 (11.1) | 16 (16.7) |
| Any Serious AE (SAE)         |   3 ( 1.2) |  0        |  1 ( 1.4) |  2 ( 2.1) |
| Any AE Leading to Death      |   3 ( 1.2) |  2 ( 2.3) |  0        |  1 ( 1.0) |

 

Adverse-event categories, ordered by total frequency

 

> **Per-key direction and hidden sort keys**
>
> `descending` can be a vector matching `by`, so you can sort one key
> down and another up —
> `sort_rows(by = c("soc_n", "label"), descending = c(TRUE, FALSE))`
> gives the canonical “system organ classes by descending frequency,
> then preferred terms alphabetically”. Sort keys are frequently
> `visible = FALSE` columns that exist only to drive the order.

Sorting is factor-aware: a factor column sorts by its level order, not
alphabetically, and `NA`s sort last. That is how a CDISC best-overall-
response column comes out in CR, PR, SD, PD order rather than
alphabetical.

## Section groups, revisited

A `usage = "group"` column turns into bold section-header rows
(`group_display = "header_row"`). That is the row-grouping you already
saw in [Columns &
headers](https://vthanik.github.io/tabular/articles/columns-and-headers.md):
each distinct group value introduces its block of rows.

``` r

tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group"),
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

### When the section label is also a row

A `usage = "group"` column lifts every distinct value into its own
**header row**. That is exactly what you want when the group label
(*Skin and Subcutaneous Tissue Disorders*) is structurally separate from
the rows beneath it. But some clinical tables carry a label that is
*itself* a meaningful data row — the AE table’s overall *Total Subjects
With An Event* line, which has its own counts and sits flush at the left
margin, not above a block.

If you forced that pattern through `group_display = "header_row"`, a
value that equals its own row label would surface twice: once as the
bold section header, once as the indented data row underneath. The
cleaner pattern keeps every label in **one ordinary column** and drives
section depth with `indent_by` — one row per label, no duplication:

``` r

# saf_aesocpt already carries label / row_type / indent_level columns.
# indent_level is 0 for the overall row and each SOC, 1 for preferred
# terms. indent_by reads it and indents the PTs; the overall row and the
# SOC labels stay flush -- no synthetic header rows, no duplicates.
ae <- saf_aesocpt[1:8, ]

tabular(ae) |>
  cols(
    soc          = col_spec(visible = FALSE),
    row_type     = col_spec(visible = FALSE),
    n_total      = col_spec(visible = FALSE),
    soc_n        = col_spec(visible = FALSE),
    indent_level = col_spec(visible = FALSE),
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

The bold weight that visually separates the *overall* and *SOC* rows
from the preferred terms comes from a
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
predicate, not from a group column — so the *Total Subjects With An
Event* row reads as the single flush row it is.

## Partitioning with `subgroup()`

Where a group column stacks blocks *within* one table,
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
splits the table into separate, banner-labelled partitions — each begins
on its own page in the print backends. Pass the partitioning column(s)
and a glue-style `label` template referencing those columns:

``` r

tabular(
  saf_subgroup,
  titles = "Table 14.2.3  Vital Signs by Sex and Age Group"
) |>
  cols(
    sex        = col_spec(visible = FALSE),
    agegr      = col_spec(visible = FALSE),
    sex_n      = col_spec(visible = FALSE),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", group_display = "column",
                          label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(by = c("sex", "agegr"), label = "{sex}, {agegr}")
```

| Parameter | Statistic | Placebo | Drug 50 | Drug 100 | Total |
|----|----|----|----|----|----|
| **F, \<65** |  |  |  |  |  |
| Diastolic BP (mmHg) | n |  24          |   9         |   9          |  42          |
|  | Mean (SD) |  73.9 (10.5) |  79.9 (8.3) |  81.6 ( 8.5) |  76.8 (10.0) |
|  | Median |  78.0        |  80.0       |  84.0        |  79.5        |
|  | Min, Max |  49  , 88    |  68  , 90   |  68  , 90    |  49  , 90    |
| Systolic BP (mmHg) | n |  24          |   9         |   9          |  42          |
|  | Mean (SD) | 129.9 (11.2) | 132.1 (4.3) | 121.8 (13.6) | 128.6 (11.1) |
|  | Median | 130.0        | 130.0       | 128.0        | 130.0        |
|  | Min, Max | 113  , 156   | 128  , 140  | 100  , 140   | 100  , 156   |
|  |  |  |  |  |  |
| **F, \>=65** |  |  |  |  |  |
| Diastolic BP (mmHg) | n | 105          |  99          |  72          | 276          |
|  | Mean (SD) |  74.0 (10.8) |  76.9 (12.2) |  75.9 (11.9) |  75.5 (11.7) |
|  | Median |  72.0        |  79.0        |  80.0        |  76.0        |
|  | Min, Max |  50  , 100   |  50  , 100   |  56  , 98    |  50  , 100   |
| Systolic BP (mmHg) | n | 105          |  99          |  72          | 276          |
|  | Mean (SD) | 137.1 (15.8) | 137.5 (16.7) | 140.1 (16.8) | 138.0 (16.4) |
|  | Median | 134.0        | 134.0        | 142.0        | 138.0        |
|  | Min, Max |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|  |  |  |  |  |  |
| **M, \<65** |  |  |  |  |  |
| Diastolic BP (mmHg) | n |  12          |   3         |  12          |  27          |
|  | Mean (SD) |  83.0 (13.3) |  80.7 (3.1) |  77.1 ( 7.0) |  80.1 (10.2) |
|  | Median |  80.0        |  80.0       |  79.0        |  80.0        |
|  | Min, Max |  68  , 104   |  78  , 84   |  68  , 87    |  68  , 104   |
| Systolic BP (mmHg) | n |  12          |   3         |  12          |  27          |
|  | Mean (SD) | 134.4 ( 8.3) | 122.7 (4.6) | 124.8 (12.0) | 128.9 (10.9) |
|  | Median | 131.0        | 120.0       | 127.0        | 130.0        |
|  | Min, Max | 123  , 150   | 120  , 128  | 107  , 146   | 107  , 150   |
|  |  |  |  |  |  |
| **M, \>=65** |  |  |  |  |  |
| Diastolic BP (mmHg) | n |  81          |  66          |  75          | 222          |
|  | Mean (SD) |  73.9 ( 9.7) |  73.7 ( 9.7) |  75.3 ( 7.9) |  74.4 ( 9.2) |
|  | Median |  73.0        |  74.0        |  76.0        |  74.0        |
|  | Min, Max |  58  , 100   |  52  , 94    |  57  , 90    |  52  , 100   |
| Systolic BP (mmHg) | n |  81          |  66          |  75          | 222          |
|  | Mean (SD) | 127.6 (15.3) | 127.0 (17.1) | 127.4 (11.5) | 127.3 (14.7) |
|  | Median | 130.0        | 124.0        | 130.0        | 130.0        |
|  | Min, Max |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

 

Table 14.2.3  Vital Signs by Sex and Age Group

 

Each `sex × agegr` combination becomes its own partition with a centred
banner like *F, \<65*. The columns named in `by` and in the `label`
template are hidden automatically.

> **Group vs subgroup**
>
> A **group** (`usage = "group"`) stacks blocks within one continuous
> table. A **subgroup**
> ([`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md))
> cuts the table into independent partitions that each start a new page.
> Use a group for “Age, then Sex, then Race”; use a subgroup for “the
> whole table, repeated per sex”.

## Pagination with `paginate()`

[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
governs how the resolved table breaks across printed pages. You do not
set rows-per-page directly — the engine computes the row budget from the
active preset (paper size, orientation, margins, font size) and the
table’s chrome (titles, headers, footnotes).

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
  paginate(
    keep_together  = "variable",                          # never split a characteristic
    repeat_content = c("titles", "headers", "footnotes"), # repeat chrome each page
    orphan_floor   = 3,
    widow_floor    = 2
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

What the arguments do:

- **`keep_together`** — names `usage = "group"` columns whose blocks
  must not be split across a page break (keep a system-organ class with
  its preferred terms).
- **`repeat_content`** — which chrome repeats at the top/bottom of every
  page; titles, headers, and footnotes by default.
- **`orphan_floor` / `widow_floor`** — minimum rows left at the bottom
  of a page / carried to the next, to avoid stranded single rows.
- **`panels`** — split a too-wide table into horizontal panels (groups
  of columns) stacked down the page.
- **`continuation`** — an optional “(continued)” marker on carried-over
  blocks.

> **Pagination is a print concept**
>
> The HTML backend is a single continuous document, so
> [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
> has no visible effect in the live previews above — it shapes the
> **RTF, PDF, and DOCX** output, where pages are real. Build and preview
> in HTML, then emit to a paginated backend to see the splits.

## Running headers and footers

Every page of a submission table carries chrome outside the table body —
the *Protocol: xxx* / *Page x of y* band a reviewer expects, and the
program path and run timestamp at the foot. Set them on the preset with
`pagehead` and `pagefoot`. Each is a named list of slots — `left`,
`center`, `right` — and each slot is text (or a character vector for
multiple rows):

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
  preset(
    pagehead = list(
      left  = "Protocol: ABC-12345",
      right = "Page {page} of {npages}"
    ),
    pagefoot = list(
      left  = "{program_path}",
      right = "{datetime}"
    )
  )
```

Protocol: ABC-12345

Page 1 of 1

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

/opt/quarto/share/rmd/rmd.R

05JUN2026 07:54:30

### Substitution tokens

Slot text may carry `{...}` tokens that the engine or backend fills in:

| Token            | Filled with                                      |
|------------------|--------------------------------------------------|
| `{page}`         | the current page number                          |
| `{npages}`       | the total page count                             |
| `{program}`      | the calling script’s base name                   |
| `{program_path}` | the calling script’s full path                   |
| `{datetime}`     | the render timestamp (`DDMMMYYYY HH:MM:SS`, UTC) |

`{page}` and `{npages}` resolve per page in the paper backends (they map
to native field codes), so *Page 1 of 7* counts correctly as the table
flows. `{program}`, `{program_path}`, and `{datetime}` resolve once,
when the spec is rendered.

### Stacking direction

A slot can hold several rows — pass a character vector. Index 1 is
always the row **closest to the table body**. A `pagehead` stacks
**upward** away from the table; a `pagefoot` stacks **downward**.
Shorter slots pad with blank rows at the *far* end, so a one-line slot
naturally lands on the body-edge row next to its multi-line neighbour:

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
  preset(
    pagehead = list(
      left  = c("Protocol: ABC-12345", "Analysis Set: Safety"),
      right = "Page {page} of {npages}"   # scalar -> body-edge row
    )
  )
```

Analysis Set: Safety  
Protocol: ABC-12345

  
Page 1 of 1

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

> **Page chrome is a print concept**
>
> Like pagination, `pagehead` / `pagefoot` shape the **RTF, PDF, and
> DOCX** deliverables, where pages and field codes are real. They have
> no visible effect in the continuous HTML preview, and `{page}` /
> `{npages}` only mean something once a table spans more than one page.

## Where to next

- **[Styling](https://vthanik.github.io/tabular/articles/styling.md)** —
  target rows, groups, and subgroup banners with
  [`style()`](https://vthanik.github.io/tabular/reference/style.md).
- **[Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.html)**
  — full AE-by-SOC/PT and subgrouped vitals tables, sorted and paginated
  end to end.
