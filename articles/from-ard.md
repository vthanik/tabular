# From a cards ARD

``` r

library(tabular)
```

`tabular` renders a **wide** frame – one row per display row, one column
per arm. But most modern analysis pipelines emit **long** Analysis
Results Data (an *ARD*) in the `cards` format: one row per statistic.
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
is the bridge between the two. This article walks a demographics ARD and
a hierarchical adverse-event ARD all the way from their long form to a
rendered table.

> **What is an ARD?**
>
> An *Analysis Results Data* frame is the tidy, long representation of a
> table’s contents: each row carries one statistic, for one group level,
> of one variable. It is produced upstream by `cards::ard_stack()` and
> friends. `tabular` does not compute it – it consumes it. The division
> of labour is deliberate: `cards` (or `gtsummary`, `dplyr`, SAS)
> *computes* the numbers;
> [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
> *reshapes* them;
> [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
> *renders*.

## 1. Inspect the ARD

The bundled `saf_demo_card` is a demographics ARD. One row is one
statistic, so it is far too long to render directly – the first six rows
cover just the start of one arm’s age summary:

``` r

head(saf_demo_card, 6)
#>   group1 group1_level variable variable_level    context stat_name stat_label
#> 1 TRT01A      Placebo      AGE           NULL continuous         N          N
#> 2 TRT01A      Placebo      AGE           NULL continuous      mean       Mean
#> 3 TRT01A      Placebo      AGE           NULL continuous        sd         SD
#> 4 TRT01A      Placebo      AGE           NULL continuous    median     Median
#> 5 TRT01A      Placebo      AGE           NULL continuous       p25         Q1
#> 6 TRT01A      Placebo      AGE           NULL continuous       p75         Q3
#>       stat
#> 1       86
#> 2  75.2093
#> 3 8.590167
#> 4       76
#> 5       69
#> 6       82
```

The columns that matter to
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
are:

- **`group1_level`** – the treatment arm (`Placebo`,
  `Xanomeline Low Dose`, …). These become the table’s columns.
- **`variable`** – the characteristic (`AGE`, `SEX`, …). These become
  the row sections.
- **`context`** – `continuous` or `categorical`, which selects the
  formatting template.
- **`stat_name` / `stat_label` / `stat`** – the statistic’s code, its
  display name (`Mean`, `SD`, `n`, `%`), and its raw numeric value.

## 2. Pivot to wide

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
spreads `group1_level` across columns and formats each statistic into
one display string:

``` r

wide <- pivot_across(saf_demo_card)
head(wide, 8)
#>   variable stat_label       Placebo Xanomeline High Dose Xanomeline Low Dose
#> 1      AGE        AGE   75.2 (8.59)          73.8 (7.94)         76.0 (8.11)
#> 2   WEIGHT     WEIGHT  62.8 (12.77)         69.5 (14.35)        68.0 (14.50)
#> 3   HEIGHT     HEIGHT 162.6 (11.52)        165.9 (10.28)       163.7 (10.30)
#> 4      BMI        BMI   23.6 (3.67)          25.2 (3.97)         25.2 (4.40)
#> 5   AGEGR1      18-64      14 (16%)             11 (15%)              8 (8%)
#> 6   AGEGR1        >64      72 (84%)             61 (85%)            88 (92%)
#> 7      SEX          F      53 (62%)             35 (49%)            55 (57%)
#> 8      SEX          M      33 (38%)             37 (51%)            41 (43%)
#>           Total
#> 1   75.1 (8.25)
#> 2  66.6 (14.13)
#> 3 163.9 (10.76)
#> 4   24.7 (4.09)
#> 5      33 (13%)
#> 6     221 (87%)
#> 7     143 (56%)
#> 8     111 (44%)
```

By default continuous rows format as `"{mean} ({sd})"`, categorical rows
as `"{n} ({p}%)"`, and an `overall = "Total"` column is appended. The
arm columns take their names verbatim from `group1_level`, so spaces
survive (`Xanomeline Low Dose`) and need backticks when you name them in
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md).

## 3. Render it

The pivot leaves `variable` as the raw upstream codes (`AGE`, `SEX`).
Pass a `label` map to
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
to rename them to display labels in one place – it rewrites the
`variable` (and, for hierarchical ARDs, the `soc` / `label`) values. The
wide frame is then an ordinary
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
input:

``` r

wide <- pivot_across(
  saf_demo_card,
  label = c(
    AGE     = "Age (years)",
    WEIGHT  = "Weight (kg)",
    HEIGHT  = "Height (cm)",
    BMI     = "BMI (kg/m²)",
    AGEGR1  = "Age Group, n (%)",
    SEX     = "Sex, n (%)",
    RACE    = "Race, n (%)",
    ETHNIC  = "Ethnicity, n (%)",
    BMI_CAT = "BMI Category, n (%)"
  )
)

tabular(
  wide,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Built from a cards ARD via pivot_across()."
) |>
  cols(
    variable               = col_spec(usage = "group", label = "Characteristic"),
    stat_label             = col_spec(label = "Statistic"),
    Placebo                = col_spec(label = "Placebo",  align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(label = "Drug 50",  align = "decimal"),
    `Xanomeline High Dose` = col_spec(label = "Drug 100", align = "decimal"),
    Total                  = col_spec(label = "Total",    align = "decimal")
  )
```

| Statistic | Placebo | Drug 100 | Drug 50 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| AGE |  75.2 (8.59)  |  73.8 (7.94)  |  76.0 (8.11)  |  75.1 (8.25)  |
|   |  |  |  |  |
| **Weight (kg)** |  |  |  |  |
| WEIGHT |  62.8 (12.77) |  69.5 (14.35) |  68.0 (14.50) |  66.6 (14.13) |
|   |  |  |  |  |
| **Height (cm)** |  |  |  |  |
| HEIGHT | 162.6 (11.52) | 165.9 (10.28) | 163.7 (10.30) | 163.9 (10.76) |
|   |  |  |  |  |
| **BMI (kg/m²)** |  |  |  |  |
| BMI |  23.6 (3.67)  |  25.2 (3.97)  |  25.2 (4.40)  |  24.7 (4.09)  |
|   |  |  |  |  |
| **Age Group, n (%)** |  |  |  |  |
|   18-64 |  14 (16%)     |  11 (15%)     |   8 ( 8%)     |  33 (13%)     |
|   \>64 |  72 (84%)     |  61 (85%)     |  88 (92%)     | 221 (87%)     |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
|   F |  53 (62%)     |  35 (49%)     |  55 (57%)     | 143 (56%)     |
|   M |  33 (38%)     |  37 (51%)     |  41 (43%)     | 111 (44%)     |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
|   WHITE |  78 (91%)     |  62 (86%)     |  90 (94%)     | 230 (91%)     |
|   BLACK OR AFRICAN AMERICAN |   8 ( 9%)     |   9 (12%)     |   6 ( 6%)     |  23 ( 9%)     |
|   ASIAN |   0           |   0           |   0           |   0           |
|   AMERICAN INDIAN OR ALASKA NATIVE |   0           |   1 ( 1%)     |   0           |   1 ( 0%)     |
|   |  |  |  |  |
| **Ethnicity, n (%)** |  |  |  |  |
|   HISPANIC OR LATINO |   3 ( 3%)     |   3 ( 4%)     |   6 ( 6%)     |  12 ( 5%)     |
|   NOT HISPANIC OR LATINO |  83 (97%)     |  69 (96%)     |  90 (94%)     | 242 (95%)     |
|   NOT REPORTED |   0           |   0           |   0           |   0           |
|   |  |  |  |  |
| **BMI Category, n (%)** |  |  |  |  |
|   Underweight (\<18.5) |   3 ( 3%)     |   1 ( 1%)     |   4 ( 4%)     |   8 ( 3%)     |
|   Normal (18.5-24.9) |  57 (66%)     |  39 (54%)     |  46 (48%)     | 142 (56%)     |
|   Overweight (25-29.9) |  20 (23%)     |  23 (32%)     |  32 (34%)     |  75 (30%)     |
|   Obese (\>=30) |   6 ( 7%)     |   9 (12%)     |  13 (14%)     |  28 (11%)     |

Built from a cards ARD via pivot_across().

 

Table 14.1.1

Demographic and Baseline Characteristics

Safety Population

 

`usage = "group"` on `variable` turns each characteristic into a bold
section-header row; `stat_label` carries the per-row statistic name.

## 4. Change the statistic format

The `statistic` argument takes one template per context. Swap in your
own to change how every row of that kind renders – here a mean carrying
its SD spelled out, and percentages without parentheses. Because the
result is still a wide frame, it renders the same way:

``` r

pivot_across(
  saf_demo_card,
  statistic = list(
    continuous  = "{mean} (SD {sd})",
    categorical = "{n} / {p}%"
  ),
  label = c(AGE = "Age (years)", SEX = "Sex, n (%)")
) |>
  tabular(titles = "Demographics with a custom statistic format") |>
  cols(
    variable               = col_spec(usage = "group", label = "Characteristic"),
    stat_label             = col_spec(label = "Statistic"),
    Placebo                = col_spec(label = "Placebo",  align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(label = "Drug 50",  align = "decimal"),
    `Xanomeline High Dose` = col_spec(label = "Drug 100", align = "decimal"),
    Total                  = col_spec(label = "Total",    align = "decimal")
  )
```

| Statistic | Placebo | Drug 100 | Drug 50 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| AGE |  75.2 (SD 8.59)  |  73.8 (SD 7.94)  |  76.0 (SD 8.11)  |  75.1 (SD 8.25)  |
|   |  |  |  |  |
| **WEIGHT** |  |  |  |  |
| WEIGHT |  62.8 (SD 12.77) |  69.5 (SD 14.35) |  68.0 (SD 14.50) |  66.6 (SD 14.13) |
|   |  |  |  |  |
| **HEIGHT** |  |  |  |  |
| HEIGHT | 162.6 (SD 11.52) | 165.9 (SD 10.28) | 163.7 (SD 10.30) | 163.9 (SD 10.76) |
|   |  |  |  |  |
| **BMI** |  |  |  |  |
| BMI |  23.6 (SD 3.67)  |  25.2 (SD 3.97)  |  25.2 (SD 4.40)  |  24.7 (SD 4.09)  |
|   |  |  |  |  |
| **AGEGR1** |  |  |  |  |
|   18-64 |  14 / 16%        |  11 / 15%        |   8 /  8%        |  33 / 13%        |
|   \>64 |  72 / 84%        |  61 / 85%        |  88 / 92%        | 221 / 87%        |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
|   F |  53 / 62%        |  35 / 49%        |  55 / 57%        | 143 / 56%        |
|   M |  33 / 38%        |  37 / 51%        |  41 / 43%        | 111 / 44%        |
|   |  |  |  |  |
| **RACE** |  |  |  |  |
|   WHITE |  78 / 91%        |  62 / 86%        |  90 / 94%        | 230 / 91%        |
|   BLACK OR AFRICAN AMERICAN |   8 /  9%        |   9 / 12%        |   6 /  6%        |  23 /  9%        |
|   ASIAN |   0              |   0              |   0              |   0              |
|   AMERICAN INDIAN OR ALASKA NATIVE |   0              |   1 /  1%        |   0              |   1 /  0%        |
|   |  |  |  |  |
| **ETHNIC** |  |  |  |  |
|   HISPANIC OR LATINO |   3 /  3%        |   3 /  4%        |   6 /  6%        |  12 /  5%        |
|   NOT HISPANIC OR LATINO |  83 / 97%        |  69 / 96%        |  90 / 94%        | 242 / 95%        |
|   NOT REPORTED |   0              |   0              |   0              |   0              |
|   |  |  |  |  |
| **BMI_CAT** |  |  |  |  |
|   Underweight (\<18.5) |   3 /  3%        |   1 /  1%        |   4 /  4%        |   8 /  3%        |
|   Normal (18.5-24.9) |  57 / 66%        |  39 / 54%        |  46 / 48%        | 142 / 56%        |
|   Overweight (25-29.9) |  20 / 23%        |  23 / 32%        |  32 / 34%        |  75 / 30%        |
|   Obese (\>=30) |   6 /  7%        |   9 / 12%        |  13 / 14%        |  28 / 11%        |

 

Demographics with a custom statistic format

 

`decimals` and `fmt` give finer control over rounding when a template
alone is not enough; `column` selects which grouping variable becomes
the columns when an ARD carries more than one.

### Integer percentages

`decimals` is a named vector keyed by statistic. Some sponsor shells
show percentages as whole numbers — pass `decimals = c(p = 0)` to drop
the decimal place on the `{p}` stat while leaving the others untouched:

``` r

pivot_across(
  saf_demo_card,
  decimals = c(p = 0),
  label = c(SEX = "Sex, n (%)", RACE = "Race, n (%)")
) |>
  tabular(titles = "Demographics with integer percentages") |>
  cols(
    variable               = col_spec(usage = "group", label = "Characteristic"),
    stat_label             = col_spec(label = "Statistic"),
    Placebo                = col_spec(label = "Placebo",  align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(label = "Drug 50",  align = "decimal"),
    `Xanomeline High Dose` = col_spec(label = "Drug 100", align = "decimal"),
    Total                  = col_spec(label = "Total",    align = "decimal")
  )
```

| Statistic | Placebo | Drug 100 | Drug 50 | Total |
|----|----|----|----|----|
| **AGE** |  |  |  |  |
| AGE |  75.2 (8.59)  |  73.8 (7.94)  |  76.0 (8.11)  |  75.1 (8.25)  |
|   |  |  |  |  |
| **WEIGHT** |  |  |  |  |
| WEIGHT |  62.8 (12.77) |  69.5 (14.35) |  68.0 (14.50) |  66.6 (14.13) |
|   |  |  |  |  |
| **HEIGHT** |  |  |  |  |
| HEIGHT | 162.6 (11.52) | 165.9 (10.28) | 163.7 (10.30) | 163.9 (10.76) |
|   |  |  |  |  |
| **BMI** |  |  |  |  |
| BMI |  23.6 (3.67)  |  25.2 (3.97)  |  25.2 (4.40)  |  24.7 (4.09)  |
|   |  |  |  |  |
| **AGEGR1** |  |  |  |  |
|   18-64 |  14 (16%)     |  11 (15%)     |   8 ( 8%)     |  33 (13%)     |
|   \>64 |  72 (84%)     |  61 (85%)     |  88 (92%)     | 221 (87%)     |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
|   F |  53 (62%)     |  35 (49%)     |  55 (57%)     | 143 (56%)     |
|   M |  33 (38%)     |  37 (51%)     |  41 (43%)     | 111 (44%)     |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
|   WHITE |  78 (91%)     |  62 (86%)     |  90 (94%)     | 230 (91%)     |
|   BLACK OR AFRICAN AMERICAN |   8 ( 9%)     |   9 (12%)     |   6 ( 6%)     |  23 ( 9%)     |
|   ASIAN |   0           |   0           |   0           |   0           |
|   AMERICAN INDIAN OR ALASKA NATIVE |   0           |   1 ( 1%)     |   0           |   1 (\<1%)     |
|   |  |  |  |  |
| **ETHNIC** |  |  |  |  |
|   HISPANIC OR LATINO |   3 ( 3%)     |   3 ( 4%)     |   6 ( 6%)     |  12 ( 5%)     |
|   NOT HISPANIC OR LATINO |  83 (97%)     |  69 (96%)     |  90 (94%)     | 242 (95%)     |
|   NOT REPORTED |   0           |   0           |   0           |   0           |
|   |  |  |  |  |
| **BMI_CAT** |  |  |  |  |
|   Underweight (\<18.5) |   3 ( 3%)     |   1 ( 1%)     |   4 ( 4%)     |   8 ( 3%)     |
|   Normal (18.5-24.9) |  57 (66%)     |  39 (54%)     |  46 (48%)     | 142 (56%)     |
|   Overweight (25-29.9) |  20 (23%)     |  23 (32%)     |  32 (34%)     |  75 (30%)     |
|   Obese (\>=30) |   6 ( 7%)     |   9 (12%)     |  13 (14%)     |  28 (11%)     |

 

Demographics with integer percentages

 

The pharma rounding threshold tracks the precision you ask for: at
`decimals = c(p = 0)` a non-zero percentage that would round to `0`
renders as `<1`, and one that would round to `100` renders as `>99`, so
a rare event never disappears into `0%`. Raise the precision and the
threshold follows — `decimals = c(p = 2)` gives `<0.01` / `>99.99`.

## 5. A hierarchical AE ARD

`saf_aesocpt_card` is a *hierarchical* AE ARD – preferred terms nested
inside system organ classes.
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
flattens it into a wide frame carrying `soc`, a combined `label`, and a
`row_type` (`overall` / `soc` / `pt`):

``` r

ae <- pivot_across(saf_aesocpt_card)
head(ae, 4)
#>                                      soc                                  label
#> 1           ..ard_hierarchical_overall..           ..ard_hierarchical_overall..
#> 2 SKIN AND SUBCUTANEOUS TISSUE DISORDERS SKIN AND SUBCUTANEOUS TISSUE DISORDERS
#> 3 SKIN AND SUBCUTANEOUS TISSUE DISORDERS                               PRURITUS
#> 4 SKIN AND SUBCUTANEOUS TISSUE DISORDERS                               ERYTHEMA
#>   row_type  Placebo Xanomeline High Dose Xanomeline Low Dose
#> 1  overall 52 (60%)             66 (92%)            81 (84%)
#> 2      soc 19 (22%)             35 (49%)            36 (38%)
#> 3       pt   8 (9%)             25 (35%)            21 (22%)
#> 4       pt   8 (9%)             14 (19%)            14 (15%)
```

Two small touches turn that into a submission-shaped table. The pivot
does not ship an indent key, so derive one from `row_type`; and the
all-subjects row arrives with an internal placeholder label, so give it
a real one:

``` r

ae$indent_level <- ifelse(ae$row_type == "pt", 1L, 0L)
ae$label[ae$row_type == "overall"] <- "Total subjects with an event"
```

Now it renders with the same indent-and-bold recipe as the [Clinical
cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md):
the `soc` / `row_type` columns ride along hidden, the single `label`
column indents preferred terms beneath their SOC via `indent_by`, and a
[`style()`](https://vthanik.github.io/tabular/reference/style.md) layer
bolds the overall and SOC summary rows:

``` r

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Built from a hierarchical cards ARD via pivot_across()."
) |>
  cols(
    soc                    = col_spec(visible = FALSE),
    row_type               = col_spec(visible = FALSE),
    indent_level           = col_spec(visible = FALSE),
    label                  = col_spec(label = "System Organ Class / Preferred Term",
                                      indent_by = "indent_level"),
    Placebo                = col_spec(label = "Placebo",  align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(label = "Drug 50",  align = "decimal"),
    `Xanomeline High Dose` = col_spec(label = "Drug 100", align = "decimal")
  ) |>
  style(bold = TRUE, .at = cells_body(where = row_type %in% c("overall", "soc")))
```

| System Organ Class / Preferred Term | Placebo | Drug 100 | Drug 50 |
|----|----|----|----|
| Total subjects with an event | 52 (60%) | 66 (92%) | 81 (84%) |
| SKIN AND SUBCUTANEOUS TISSUE DISORDERS | 19 (22%) | 35 (49%) | 36 (38%) |
| PRURITUS |  8 ( 9%) | 25 (35%) | 21 (22%) |
| ERYTHEMA |  8 ( 9%) | 14 (19%) | 14 (15%) |
| RASH |  5 ( 6%) |  8 (11%) | 13 (14%) |
| HYPERHIDROSIS |  2 ( 2%) |  8 (11%) |  4 ( 4%) |
| SKIN IRRITATION |  3 ( 3%) |  5 ( 7%) |  6 ( 6%) |
| GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS | 15 (17%) | 30 (42%) | 36 (38%) |
| APPLICATION SITE PRURITUS |  6 ( 7%) | 21 (29%) | 23 (24%) |
| APPLICATION SITE ERYTHEMA |  3 ( 3%) | 14 (19%) | 13 (14%) |
| APPLICATION SITE DERMATITIS |  5 ( 6%) |  7 (10%) |  9 ( 9%) |
| APPLICATION SITE IRRITATION |  3 ( 3%) |  9 (12%) |  9 ( 9%) |
| APPLICATION SITE VESICLES |  1 ( 1%) |  5 ( 7%) |  5 ( 5%) |
| GASTROINTESTINAL DISORDERS | 13 (15%) | 17 (24%) | 12 (12%) |
| DIARRHOEA |  9 (10%) |  3 ( 4%) |  5 ( 5%) |
| VOMITING |  3 ( 3%) |  6 ( 8%) |  4 ( 4%) |
| NAUSEA |  3 ( 3%) |  6 ( 8%) |  3 ( 3%) |
| ABDOMINAL PAIN |  1 ( 1%) |  1 ( 1%) |  3 ( 3%) |
| SALIVARY HYPERSECRETION |  0       |  4 ( 6%) |  0       |
| NERVOUS SYSTEM DISORDERS |  6 ( 7%) | 17 (24%) | 18 (19%) |
| DIZZINESS |  2 ( 2%) | 10 (14%) |  9 ( 9%) |
| HEADACHE |  3 ( 3%) |  5 ( 7%) |  3 ( 3%) |
| SYNCOPE |  0       |  2 ( 3%) |  5 ( 5%) |
| SOMNOLENCE |  2 ( 2%) |  1 ( 1%) |  3 ( 3%) |
| TRANSIENT ISCHAEMIC ATTACK |  0       |  1 ( 1%) |  2 ( 2%) |
| CARDIAC DISORDERS |  7 ( 8%) | 14 (19%) | 12 (12%) |
| SINUS BRADYCARDIA |  2 ( 2%) |  8 (11%) |  7 ( 7%) |
| MYOCARDIAL INFARCTION |  4 ( 5%) |  4 ( 6%) |  2 ( 2%) |
| ATRIAL FIBRILLATION |  1 ( 1%) |  2 ( 3%) |  2 ( 2%) |
|  |  |  |  |
| SUPRAVENTRICULAR EXTRASYSTOLES |  1 ( 1%) |  1 ( 1%) |  1 ( 1%) |
| VENTRICULAR EXTRASYSTOLES |  0       |  1 ( 1%) |  2 ( 2%) |
| INFECTIONS AND INFESTATIONS | 12 (14%) | 11 (15%) |  6 ( 6%) |
| NASOPHARYNGITIS |  2 ( 2%) |  6 ( 8%) |  4 ( 4%) |
| UPPER RESPIRATORY TRACT INFECTION |  6 ( 7%) |  3 ( 4%) |  1 ( 1%) |
| INFLUENZA |  1 ( 1%) |  1 ( 1%) |  1 ( 1%) |
| URINARY TRACT INFECTION |  2 ( 2%) |  1 ( 1%) |  0       |
| CYSTITIS |  1 ( 1%) |  1 ( 1%) |  0       |
| RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS |  5 ( 6%) |  9 (12%) |  8 ( 8%) |
| COUGH |  1 ( 1%) |  5 ( 7%) |  5 ( 5%) |
| NASAL CONGESTION |  3 ( 3%) |  3 ( 4%) |  1 ( 1%) |
| DYSPNOEA |  1 ( 1%) |  1 ( 1%) |  1 ( 1%) |
| EPISTAXIS |  0       |  2 ( 3%) |  1 ( 1%) |
| PHARYNGOLARYNGEAL PAIN |  0       |  1 ( 1%) |  1 ( 1%) |
| PSYCHIATRIC DISORDERS |  7 ( 8%) |  3 ( 4%) |  9 ( 9%) |
| CONFUSIONAL STATE |  2 ( 2%) |  1 ( 1%) |  3 ( 3%) |
| AGITATION |  2 ( 2%) |  0       |  3 ( 3%) |
| INSOMNIA |  2 ( 2%) |  2 ( 3%) |  0       |
| ANXIETY |  0       |  0       |  3 ( 3%) |
| DELUSION |  1 ( 1%) |  1 ( 1%) |  0       |
| MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS |  3 ( 3%) |  5 ( 7%) |  6 ( 6%) |
| BACK PAIN |  1 ( 1%) |  3 ( 4%) |  1 ( 1%) |
| ARTHRALGIA |  1 ( 1%) |  1 ( 1%) |  2 ( 2%) |
| SHOULDER PAIN |  1 ( 1%) |  0       |  2 ( 2%) |
| MUSCLE SPASMS |  0       |  1 ( 1%) |  1 ( 1%) |
| ARTHRITIS |  0       |  1 ( 1%) |  0       |
| INVESTIGATIONS |  5 ( 6%) |  3 ( 4%) |  4 ( 4%) |
| ELECTROCARDIOGRAM ST SEGMENT DEPRESSION |  4 ( 5%) |  0       |  1 ( 1%) |
| ELECTROCARDIOGRAM T WAVE INVERSION |  2 ( 2%) |  1 ( 1%) |  1 ( 1%) |
|  |  |  |  |
| BLOOD GLUCOSE INCREASED |  0       |  1 ( 1%) |  1 ( 1%) |
| ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED |  1 ( 1%) |  0       |  1 ( 1%) |
| BIOPSY |  0       |  1 ( 1%) |  0       |

Built from a hierarchical cards ARD via pivot_across().

 

Table 14.3.1

Adverse Events by System Organ Class and Preferred Term

Safety Population

 

## Where this fits

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
keeps the division of labour clean: an upstream tool *computes* the
summary as an ARD,
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
*reshapes* it to the wide frame, and
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
*renders* it to submission-grade RTF / PDF / DOCX / HTML. Nothing in the
rendering stack needs to know how the numbers were produced – only their
shape.

## Where to next

- **[Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md)**
  – six complete production tables, including the AE and demographics
  recipes this article feeds.
- **[Columns &
  headers](https://vthanik.github.io/tabular/articles/columns-and-headers.md)**
  – every
  [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
  option used above, in depth.
