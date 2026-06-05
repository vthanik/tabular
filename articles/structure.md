# Structure: columns, headers, and pagination

This article is about *shape*: which column does what, multi-level
headers, and how a table that is too long or too wide is split across
pages. It assumes you already have a wide frame (see [Data
in](https://vthanik.github.io/tabular/articles/data-in.md)) and does not
cover cosmetics (see
[Presentation](https://vthanik.github.io/tabular/articles/presentation.md)).

## The column model: `usage`

Every column gets a role via `col_spec(usage = …)`. Picking the right
one is the single most important structural decision:

| `usage` | Use it for | Behaviour |
|----|----|----|
| `"display"` *(default)* | data cells (the arm columns) | one value per row |
| `"group"` | section variable (e.g. parameter) | each value becomes a **section-header row**; the column is hidden |
| `"indent"` | nested row labels under a section | prefixes one indent level; pairs with a `group` column |
| `"id"` | the row label that must stay visible | like `display`, but **joins the stub and repeats on every horizontal panel** |

``` r

data(cdisc_saf_demo, package = "tabular")
arms <- c("placebo", "drug_50", "drug_100", "Total")

tabular(cdisc_saf_demo, titles = "Demographics") |>
  cols(
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(usage = "indent", label = "")
  ) |>
  cols_apply(arms, col_spec(align = "decimal"))
```

|  | placebo | drug_100 | drug_50 | Total |
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
|  |  |  |  |  |
| Overweight (25-29.9) |  20 (23.3)    |  23 (31.9)    |  32 (33.3)    |  75 (29.5)    |
| Obese (\>=30) |   6 ( 7.0)    |   9 (12.5)    |  13 (13.5)    |  28 (11.0)    |

 

Demographics

 

[`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
attaches one shared `col_spec` to **all** the arm columns at once — use
it instead of repeating `cols(placebo = …, drug_50 = …)` for a variable
number of arms.

> **[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
> already indents nested levels.** Categorical level labels come out of
> [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
> with a leading indent baked into the string. If you *also* set
> `usage = "indent"` you get a double indent — either keep the labels
> as-is (`usage = "display"`/`"id"`) or
> [`trimws()`](https://rdrr.io/r/base/trimws.html) them first and let
> the engine indent. Don’t do both.

## BigN in the column headers

The `(N=…)` denominator goes in each arm’s header label. Build it from a
BigN table and interpolate with glue:

``` r

data(cdisc_saf_n, package = "tabular")
N <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(cdisc_saf_demo, titles = "Demographics") |>
  cols(
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(usage = "indent", label = ""),
    placebo = col_spec(
      label = "Placebo\n(N={N['placebo']})",
      align = "decimal"
    ),
    drug_50 = col_spec(
      label = "Drug 50\n(N={N['drug_50']})",
      align = "decimal"
    ),
    drug_100 = col_spec(
      label = "Drug 100\n(N={N['drug_100']})",
      align = "decimal"
    ),
    Total = col_spec(label = "Total\n(N={N['Total']})", align = "decimal")
  )
```

[TABLE]

 

Demographics

 

> **Clinical convention:** BigN is the population denominator (from
> ADSL), **not** the number of rows in the domain dataset — compute it
> from the population, not from the summarised data.

For a **variable** number of arms, the per-arm label is one
[`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
call instead of a hand-written line each: the `{.name}` token resolves
to each matched column’s name, and the rest of the `{…}` evaluates in
the calling environment, so the BigN looks itself up:

``` r

arm_cols <- c("placebo", "drug_50", "drug_100", "Total")

tabular(cdisc_saf_demo, titles = "Demographics") |>
  cols(
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(usage = "indent", label = "")
  ) |>
  cols_apply(
    arm_cols,
    col_spec(label = "{.name}\n(N={N[.name]})", align = "decimal")
  )
```

[TABLE]

 

Demographics

 

## Multi-level headers and widths

[`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
builds spanning bands over groups of columns:

``` r

tabular(cdisc_saf_demo, titles = "Demographics") |>
  cols(
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(usage = "indent", label = "", width = "2.2in")
  ) |>
  cols_apply(arms, col_spec(align = "decimal", width = "1in")) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total"))
```

|  | Treatment Group |  |  |  |
|----|----|----|----|----|
|  | placebo | drug_100 | drug_50 | Total |
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
|  |  |  |  |  |
| Normal (18.5-24.9) |  57 (66.3)    |  39 (54.2)    |  46 (47.9)    | 142 (55.9)    |
| Overweight (25-29.9) |  20 (23.3)    |  23 (31.9)    |  32 (33.3)    |  75 (29.5)    |
| Obese (\>=30) |   6 ( 7.0)    |   9 (12.5)    |  13 (13.5)    |  28 (11.0)    |

 

Demographics

 

Widths: `"auto"` (default) sizes to content; a pinned value (`"1in"`,
`1.0`, `"20%"`) wraps within that width. **Set the shared arm width via
[`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
last** — its non-default `width` then wins the field-merge; a later
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) call
carrying the default `width = "auto"` would otherwise be ambiguous.

## Pagination — long tables

[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
derives the rows-per-page budget from the preset (paper, font, margins)
and the title/footnote/header line counts — you never set rows-per-page
by hand. `keep_together` stops a page break landing inside a section’s
run:

``` r

data(cdisc_saf_aesocpt, package = "tabular")
ae_pages <- tabular(cdisc_saf_aesocpt, titles = "AEs by SOC and PT") |>
  cols(
    label = col_spec(
      label = "SOC / Preferred Term",
      indent_by = "indent_level"
    ),
    soc = col_spec(
      usage = "group",
      visible = FALSE,
      group_display = "column_repeat"
    ),
    row_type = col_spec(visible = FALSE),
    n_total = col_spec(visible = FALSE),
    soc_n = col_spec(visible = FALSE)
  ) |>
  cols_apply(
    c("placebo", "drug_50", "drug_100", "Total"),
    col_spec(align = "decimal")
  ) |>
  paginate(
    keep_together = "soc",
    orphan_floor = 4,
    widow_floor = 2,
    continuation = "(continued)"
  )
ae_pages
```

| SOC / Preferred Term | placebo | drug_50 | drug_100 | Total |
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
| DIARRHOEA |  9 (10.5) |  5 ( 5.2) |  3 ( 4.2) |  17 ( 6.7) |
| VOMITING |  3 ( 3.5) |  4 ( 4.2) |  6 ( 8.3) |  13 ( 5.1) |
| NAUSEA |  3 ( 3.5) |  3 ( 3.1) |  6 ( 8.3) |  12 ( 4.7) |
| ABDOMINAL PAIN |  1 ( 1.2) |  3 ( 3.1) |  1 ( 1.4) |   5 ( 2.0) |
| SALIVARY HYPERSECRETION |  0        |  0        |  4 ( 5.6) |   4 ( 1.6) |
| NERVOUS SYSTEM DISORDERS |  6 ( 7.0) | 18 (18.8) | 17 (23.6) |  41 (16.1) |
| DIZZINESS |  2 ( 2.3) |  9 ( 9.4) | 10 (13.9) |  21 ( 8.3) |
| HEADACHE |  3 ( 3.5) |  3 ( 3.1) |  5 ( 6.9) |  11 ( 4.3) |
| SYNCOPE |  0        |  5 ( 5.2) |  2 ( 2.8) |   7 ( 2.8) |
| SOMNOLENCE |  2 ( 2.3) |  3 ( 3.1) |  1 ( 1.4) |   6 ( 2.4) |
| TRANSIENT ISCHAEMIC ATTACK |  0        |  2 ( 2.1) |  1 ( 1.4) |   3 ( 1.2) |
| CARDIAC DISORDERS |  7 ( 8.1) | 12 (12.5) | 14 (19.4) |  33 (13.0) |
| SINUS BRADYCARDIA |  2 ( 2.3) |  7 ( 7.3) |  8 (11.1) |  17 ( 6.7) |
| MYOCARDIAL INFARCTION |  4 ( 4.7) |  2 ( 2.1) |  4 ( 5.6) |  10 ( 3.9) |
| ATRIAL FIBRILLATION |  1 ( 1.2) |  2 ( 2.1) |  2 ( 2.8) |   5 ( 2.0) |
| SUPRAVENTRICULAR EXTRASYSTOLES |  1 ( 1.2) |  1 ( 1.0) |  1 ( 1.4) |   3 ( 1.2) |
| VENTRICULAR EXTRASYSTOLES |  0        |  2 ( 2.1) |  1 ( 1.4) |   3 ( 1.2) |
|  |  |  |  |  |
| INFECTIONS AND INFESTATIONS | 12 (14.0) |  6 ( 6.2) | 11 (15.3) |  29 (11.4) |
| NASOPHARYNGITIS |  2 ( 2.3) |  4 ( 4.2) |  6 ( 8.3) |  12 ( 4.7) |
| UPPER RESPIRATORY TRACT INFECTION |  6 ( 7.0) |  1 ( 1.0) |  3 ( 4.2) |  10 ( 3.9) |
| INFLUENZA |  1 ( 1.2) |  1 ( 1.0) |  1 ( 1.4) |   3 ( 1.2) |
| URINARY TRACT INFECTION |  2 ( 2.3) |  0        |  1 ( 1.4) |   3 ( 1.2) |
| CYSTITIS |  1 ( 1.2) |  0        |  1 ( 1.4) |   2 ( 0.8) |
| RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS |  5 ( 5.8) |  8 ( 8.3) |  9 (12.5) |  22 ( 8.7) |
| COUGH |  1 ( 1.2) |  5 ( 5.2) |  5 ( 6.9) |  11 ( 4.3) |
| NASAL CONGESTION |  3 ( 3.5) |  1 ( 1.0) |  3 ( 4.2) |   7 ( 2.8) |
| DYSPNOEA |  1 ( 1.2) |  1 ( 1.0) |  1 ( 1.4) |   3 ( 1.2) |
| EPISTAXIS |  0        |  1 ( 1.0) |  2 ( 2.8) |   3 ( 1.2) |
| PHARYNGOLARYNGEAL PAIN |  0        |  1 ( 1.0) |  1 ( 1.4) |   2 ( 0.8) |
| PSYCHIATRIC DISORDERS |  7 ( 8.1) |  9 ( 9.4) |  3 ( 4.2) |  19 ( 7.5) |
| CONFUSIONAL STATE |  2 ( 2.3) |  3 ( 3.1) |  1 ( 1.4) |   6 ( 2.4) |
| AGITATION |  2 ( 2.3) |  3 ( 3.1) |  0        |   5 ( 2.0) |
| INSOMNIA |  2 ( 2.3) |  0        |  2 ( 2.8) |   4 ( 1.6) |
| ANXIETY |  0        |  3 ( 3.1) |  0        |   3 ( 1.2) |
| DELUSION |  1 ( 1.2) |  0        |  1 ( 1.4) |   2 ( 0.8) |
| MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS |  3 ( 3.5) |  6 ( 6.2) |  5 ( 6.9) |  14 ( 5.5) |
| BACK PAIN |  1 ( 1.2) |  1 ( 1.0) |  3 ( 4.2) |   5 ( 2.0) |
| ARTHRALGIA |  1 ( 1.2) |  2 ( 2.1) |  1 ( 1.4) |   4 ( 1.6) |
| SHOULDER PAIN |  1 ( 1.2) |  2 ( 2.1) |  0        |   3 ( 1.2) |
| MUSCLE SPASMS |  0        |  1 ( 1.0) |  1 ( 1.4) |   2 ( 0.8) |
| ARTHRITIS |  0        |  0        |  1 ( 1.4) |   1 ( 0.4) |
| INVESTIGATIONS |  5 ( 5.8) |  4 ( 4.2) |  3 ( 4.2) |  12 ( 4.7) |
| ELECTROCARDIOGRAM ST SEGMENT DEPRESSION |  4 ( 4.7) |  1 ( 1.0) |  0        |   5 ( 2.0) |
| ELECTROCARDIOGRAM T WAVE INVERSION |  2 ( 2.3) |  1 ( 1.0) |  1 ( 1.4) |   4 ( 1.6) |
| BLOOD GLUCOSE INCREASED |  0        |  1 ( 1.0) |  1 ( 1.4) |   2 ( 0.8) |
| ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED |  1 ( 1.2) |  1 ( 1.0) |  0        |   2 ( 0.8) |
| BIOPSY |  0        |  0        |  1 ( 1.4) |   1 ( 0.4) |

 

AEs by SOC and PT

 

The preview above is one continuous table: row pagination,
`keep_together`, and the `continuation` marker materialise only in the
**paged backends** (RTF, PDF, DOCX), not in HTML. Emit to one of those
to see the page breaks:

``` r

emit(ae_pages, "ae_soc_pt.pdf") # continuation marker repeats on each continued page
```

## Panels — wide tables

When the columns don’t fit one page, `paginate(panels = N)` splits the
**non-group** columns into `N` chunks and repeats every `group`/`id`
column on each panel (so the row labels reappear). Make the row label
`usage = "id"` so it rides every panel:

``` r

wide_split <- tabular(cdisc_saf_demo, titles = "Demographics (wide split)") |>
  cols(
    variable = col_spec(
      usage = "group",
      group_display = "header_row",
      label = ""
    ),
    stat_label = col_spec(usage = "id", label = "") # repeats on every panel
  ) |>
  cols_apply(arms, col_spec(align = "decimal")) |>
  paginate(panels = 2, continuation = "(continued)")
wide_split
```

|  | Panel 1 |  | Panel 2 |  |
|----|----|----|----|----|
|  | placebo | drug_100 | drug_50 | Total |
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
|  |  |  |  |  |
| Overweight (25-29.9) |  20 (23.3)    |  23 (31.9)    |  32 (33.3)    |  75 (29.5)    |
| Obese (\>=30) |   6 ( 7.0)    |   9 (12.5)    |  13 (13.5)    |  28 (11.0)    |

 

Demographics (wide split)

 

Panels are a paged-backend feature: in HTML and Markdown the table stays
one continuous block (the preview above), while RTF, PDF, and DOCX place
each panel on its own page with the `id` / `group` columns repeated.
Emit to a paged backend to see the split:

``` r

emit(wide_split, "demographics_wide.pdf") # panel 2 carries the (continued) marker
```

Two things to know:

- **`panels = N` splits into `N` *equal* chunks** — there is no explicit
  split position (no “first 5, then the rest”). Equal split is fine for
  page-fit; if you need a specific boundary, that is a known limitation.
- **`panels = "auto"` is currently a no-op** (treated as `1`): it does
  *not* auto-fit, it just leaves every column on one page (and the table
  may overflow with a warning). Always pass an explicit integer.

## Subgroups and per-page BigN

[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
partitions the table — one page block per value, with a banner and a
hard page break. A partition-constant column can ride into the banner:

``` r

data(cdisc_saf_subgroup, package = "tabular")
tabular(cdisc_saf_subgroup, titles = "Vital signs by sex") |>
  cols(
    sex = col_spec(visible = FALSE),
    sex_n = col_spec(visible = FALSE),
    agegr = col_spec(visible = FALSE),
    agegr_n = col_spec(visible = FALSE),
    paramcd = col_spec(visible = FALSE),
    param = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(usage = "id", label = "Statistic")
  ) |>
  cols_apply(
    c("placebo", "drug_50", "drug_100", "Total"),
    col_spec(align = "decimal")
  ) |>
  subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})") # page total in banner
```

| Statistic               | placebo      | drug_50      | drug_100     | Total        |
|-------------------------|--------------|--------------|--------------|--------------|
| **Sex: F (N = 106)**    |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  24          |   9          |   9          |  42          |
| Mean (SD)               |  73.9 (10.5) |  79.9 (8.3)  |  81.6 (8.5)  |  76.8 (10.0) |
| Median                  |  78.0        |  80.0        |  84.0        |  79.5        |
| Min, Max                |  49  , 88    |  68  , 90    |  68  , 90    |  49  , 90    |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  24          |   9          |   9          |  42          |
| Mean (SD)               | 129.9 (11.2) | 132.1 (4.3)  | 121.8 (13.6) | 128.6 (11.1) |
| Median                  | 130.0        | 130.0        | 128.0        | 130.0        |
| Min, Max                | 113  , 156   | 128  , 140   | 100  , 140   | 100  , 156   |
|                         |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       | 105          |  99          |  72          | 276          |
| Mean (SD)               |  74.0 (10.8) |  76.9 (12.2) |  75.9 (11.9) |  75.5 (11.7) |
| Median                  |  72.0        |  79.0        |  80.0        |  76.0        |
| Min, Max                |  50  , 100   |  50  , 100   |  56  , 98    |  50  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       | 105          |  99          |  72          | 276          |
| Mean (SD)               | 137.1 (15.8) | 137.5 (16.7) | 140.1 (16.8) | 138.0 (16.4) |
| Median                  | 134.0        | 134.0        | 142.0        | 138.0        |
| Min, Max                |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|                         |              |              |              |              |
| **Sex: M (N = 83)**     |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  12          |   3          |  12          |  27          |
| Mean (SD)               |  83.0 (13.3) |  80.7 (3.1)  |  77.1 (7.0)  |  80.1 (10.2) |
| Median                  |  80.0        |  80.0        |  79.0        |  80.0        |
| Min, Max                |  68  , 104   |  78  , 84    |  68  , 87    |  68  , 104   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  12          |   3          |  12          |  27          |
| Mean (SD)               | 134.4 (8.3)  | 122.7 (4.6)  | 124.8 (12.0) | 128.9 (10.9) |
| Median                  | 131.0        | 120.0        | 127.0        | 130.0        |
| Min, Max                | 123  , 150   | 120  , 128   | 107  , 146   | 107  , 150   |
|                         |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
| Mean (SD)               |  73.9 (9.7)  |  73.7 (9.7)  |  75.3 (7.9)  |  74.4 (9.2)  |
| Median                  |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max                |  58  , 100   |  52  , 94    |  57  , 90    |  52  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
| Mean (SD)               | 127.6 (15.3) | 127.0 (17.1) | 127.4 (11.5) | 127.3 (14.7) |
| Median                  | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max                |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

 

Vital signs by sex

 

For a **different `(N=)` per arm on each page** (the column headers
re-resolving per subgroup), pass `big_n` — a small table of N per page ×
arm. No bundled dataset carries per-arm-per-page counts, so build it
inline (this is also the shape `big_n` expects):

``` r

big_n <- data.frame(
  sex = c("F", "M"),
  placebo = c(53L, 33L),
  drug_50 = c(50L, 46L),
  drug_100 = c(40L, 32L),
  Total = c(143L, 111L)
)

tabular(cdisc_saf_subgroup, titles = "Vital signs by sex") |>
  cols(
    sex_n = col_spec(visible = FALSE),
    agegr = col_spec(visible = FALSE),
    agegr_n = col_spec(visible = FALSE),
    paramcd = col_spec(visible = FALSE),
    param = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(usage = "id", label = "Statistic")
  ) |>
  cols_apply(
    c("placebo", "drug_50", "drug_100", "Total"),
    col_spec(align = "decimal")
  ) |>
  subgroup(by = "sex", label = "Sex: {sex}", big_n = big_n) # per-page (N=) per arm
```

| Statistic               | placebo      | drug_50      | drug_100     | Total        |
|-------------------------|--------------|--------------|--------------|--------------|
| **Sex: F**              |              |              |              |              |
|                         | (N=53)       | (N=50)       | (N=40)       | (N=143)      |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  24          |   9          |   9          |  42          |
| Mean (SD)               |  73.9 (10.5) |  79.9 (8.3)  |  81.6 (8.5)  |  76.8 (10.0) |
| Median                  |  78.0        |  80.0        |  84.0        |  79.5        |
| Min, Max                |  49  , 88    |  68  , 90    |  68  , 90    |  49  , 90    |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  24          |   9          |   9          |  42          |
| Mean (SD)               | 129.9 (11.2) | 132.1 (4.3)  | 121.8 (13.6) | 128.6 (11.1) |
| Median                  | 130.0        | 130.0        | 128.0        | 130.0        |
| Min, Max                | 113  , 156   | 128  , 140   | 100  , 140   | 100  , 156   |
|                         |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       | 105          |  99          |  72          | 276          |
| Mean (SD)               |  74.0 (10.8) |  76.9 (12.2) |  75.9 (11.9) |  75.5 (11.7) |
| Median                  |  72.0        |  79.0        |  80.0        |  76.0        |
| Min, Max                |  50  , 100   |  50  , 100   |  56  , 98    |  50  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       | 105          |  99          |  72          | 276          |
| Mean (SD)               | 137.1 (15.8) | 137.5 (16.7) | 140.1 (16.8) | 138.0 (16.4) |
| Median                  | 134.0        | 134.0        | 142.0        | 138.0        |
| Min, Max                |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|                         |              |              |              |              |
| **Sex: M**              |              |              |              |              |
|                         | (N=33)       | (N=46)       | (N=32)       | (N=111)      |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  12          |   3          |  12          |  27          |
| Mean (SD)               |  83.0 (13.3) |  80.7 (3.1)  |  77.1 (7.0)  |  80.1 (10.2) |
| Median                  |  80.0        |  80.0        |  79.0        |  80.0        |
| Min, Max                |  68  , 104   |  78  , 84    |  68  , 87    |  68  , 104   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  12          |   3          |  12          |  27          |
| Mean (SD)               | 134.4 (8.3)  | 122.7 (4.6)  | 124.8 (12.0) | 128.9 (10.9) |
| Median                  | 131.0        | 120.0        | 127.0        | 130.0        |
| Min, Max                | 123  , 150   | 120  , 128   | 107  , 146   | 107  , 150   |
|                         |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
| Mean (SD)               |  73.9 (9.7)  |  73.7 (9.7)  |  75.3 (7.9)  |  74.4 (9.2)  |
| Median                  |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max                |  58  , 100   |  52  , 94    |  57  , 90    |  52  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
| Mean (SD)               | 127.6 (15.3) | 127.0 (17.1) | 127.4 (11.5) | 127.3 (14.7) |
| Median                  | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max                |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

 

Vital signs by sex

 

`big_n` accepts this wide shape (page column + one column per arm) or a
long `count()`-style table (page, arm, n).
