# From a cards ARD

``` r

library(tabular)
```

`tabular` renders a **wide** frame, but many analysis pipelines produce
**long** Analysis Results Data (ARD) — one row per statistic, in the
`cards` format.
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
is the bridge: it pivots an ARD into the wide, one-row-per-display-row
shape
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
expects.

> **What is an ARD?**
>
> An *Analysis Results Data* frame is the tidy, long representation of a
> table’s contents: each row carries one statistic for one group level,
> with columns like `group1_level`, `variable`, `stat_name`, and `stat`.
> It is produced upstream by
> [`cards::ard_stack()`](https://insightsengineering.github.io/cards/latest-tag/reference/ard_stack.html)
> (and friends). `tabular` does not compute it — it consumes it.

### A demographics ARD

The bundled `saf_demo_card` is a demographics ARD in `cards` format:

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

Each row is one statistic (`stat`) for one treatment arm
(`group1_level`) and characteristic (`variable`). That is too long to
render directly.

### Pivot to wide

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
spreads the treatment arms across columns and formats each statistic
into a display string:

``` r

wide <- pivot_across(saf_demo_card)

wide
#>    variable                         stat_label       Placebo
#> 1       AGE                                AGE   75.2 (8.59)
#> 2    WEIGHT                             WEIGHT  62.8 (12.77)
#> 3    HEIGHT                             HEIGHT 162.6 (11.52)
#> 4       BMI                                BMI   23.6 (3.67)
#> 5    AGEGR1                              18-64      14 (16%)
#> 6    AGEGR1                                >64      72 (84%)
#> 7       SEX                                  F      53 (62%)
#> 8       SEX                                  M      33 (38%)
#> 9      RACE                              WHITE      78 (91%)
#> 10     RACE          BLACK OR AFRICAN AMERICAN        8 (9%)
#> 11     RACE                              ASIAN             0
#> 12     RACE   AMERICAN INDIAN OR ALASKA NATIVE             0
#> 13   ETHNIC                 HISPANIC OR LATINO        3 (3%)
#> 14   ETHNIC             NOT HISPANIC OR LATINO      83 (97%)
#> 15   ETHNIC                       NOT REPORTED             0
#> 16  BMI_CAT                Underweight (<18.5)        3 (3%)
#> 17  BMI_CAT                 Normal (18.5-24.9)      57 (66%)
#> 18  BMI_CAT               Overweight (25-29.9)      20 (23%)
#> 19  BMI_CAT                       Obese (>=30)        6 (7%)
#>    Xanomeline High Dose Xanomeline Low Dose         Total
#> 1           73.8 (7.94)         76.0 (8.11)   75.1 (8.25)
#> 2          69.5 (14.35)        68.0 (14.50)  66.6 (14.13)
#> 3         165.9 (10.28)       163.7 (10.30) 163.9 (10.76)
#> 4           25.2 (3.97)         25.2 (4.40)   24.7 (4.09)
#> 5              11 (15%)              8 (8%)      33 (13%)
#> 6              61 (85%)            88 (92%)     221 (87%)
#> 7              35 (49%)            55 (57%)     143 (56%)
#> 8              37 (51%)            41 (43%)     111 (44%)
#> 9              62 (86%)            90 (94%)     230 (91%)
#> 10              9 (12%)              6 (6%)       23 (9%)
#> 11                    0                   0             0
#> 12               1 (1%)                   0        1 (0%)
#> 13               3 (4%)              6 (6%)       12 (5%)
#> 14             69 (96%)            90 (94%)     242 (95%)
#> 15                    0                   0             0
#> 16               1 (1%)              4 (4%)        8 (3%)
#> 17             39 (54%)            46 (48%)     142 (56%)
#> 18             23 (32%)            32 (34%)      75 (30%)
#> 19              9 (12%)            13 (14%)      28 (11%)
```

By default the `statistic` argument formats continuous rows as
`"{mean} ({sd})"` and categorical rows as `"{n} ({p}%)"`, and an
`overall = "Total"` column is appended. The arm columns take their names
from the ARD’s `group1_level` values.

### Render the pivoted frame

The result is an ordinary wide data frame, so it flows straight into the
usual pipeline. Arm columns whose names contain spaces are quoted with
backticks:

``` r

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
    Placebo                = col_spec(align = "decimal"),
    `Xanomeline Low Dose`  = col_spec(label = "Drug 50",  align = "decimal"),
    `Xanomeline High Dose` = col_spec(label = "Drug 100", align = "decimal"),
    Total                  = col_spec(align = "decimal")
  )
```

 

## Table 14.1.1

## Demographic and Baseline Characteristics

## Safety Population

 

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
| 18-64 |  14 (16%)     |  11 (15%)     |   8 ( 8%)     |  33 (13%)     |
| \>64 |  72 (84%)     |  61 (85%)     |  88 (92%)     | 221 (87%)     |
|   |  |  |  |  |
| **SEX** |  |  |  |  |
| F |  53 (62%)     |  35 (49%)     |  55 (57%)     | 143 (56%)     |
| M |  33 (38%)     |  37 (51%)     |  41 (43%)     | 111 (44%)     |
|   |  |  |  |  |
| **RACE** |  |  |  |  |
| WHITE |  78 (91%)     |  62 (86%)     |  90 (94%)     | 230 (91%)     |
| BLACK OR AFRICAN AMERICAN |   8 ( 9%)     |   9 (12%)     |   6 ( 6%)     |  23 ( 9%)     |
| ASIAN |   0           |   0           |   0           |   0           |
| AMERICAN INDIAN OR ALASKA NATIVE |   0           |   1 ( 1%)     |   0           |   1 ( 0%)     |
|   |  |  |  |  |
| **ETHNIC** |  |  |  |  |
| HISPANIC OR LATINO |   3 ( 3%)     |   3 ( 4%)     |   6 ( 6%)     |  12 ( 5%)     |
| NOT HISPANIC OR LATINO |  83 (97%)     |  69 (96%)     |  90 (94%)     | 242 (95%)     |
| NOT REPORTED |   0           |   0           |   0           |   0           |
|   |  |  |  |  |
| **BMI_CAT** |  |  |  |  |
| Underweight (\<18.5) |   3 ( 3%)     |   1 ( 1%)     |   4 ( 4%)     |   8 ( 3%)     |
| Normal (18.5-24.9) |  57 (66%)     |  39 (54%)     |  46 (48%)     | 142 (56%)     |
| Overweight (25-29.9) |  20 (23%)     |  23 (32%)     |  32 (34%)     |  75 (30%)     |
| Obese (\>=30) |   6 ( 7%)     |   9 (12%)     |  13 (14%)     |  28 (11%)     |

Built from a cards ARD via pivot_across().

### Customising the statistic format

Pass your own templates to `statistic` to change how each context
renders — for example, a mean with one extra decimal and percentages
without parentheses:

``` r

pivot_across(
  saf_demo_card,
  statistic = list(
    continuous  = "{mean} (SD {sd})",
    categorical = "{n} / {p}%"
  )
)
#>    variable                         stat_label          Placebo
#> 1       AGE                                AGE   75.2 (SD 8.59)
#> 2    WEIGHT                             WEIGHT  62.8 (SD 12.77)
#> 3    HEIGHT                             HEIGHT 162.6 (SD 11.52)
#> 4       BMI                                BMI   23.6 (SD 3.67)
#> 5    AGEGR1                              18-64         14 / 16%
#> 6    AGEGR1                                >64         72 / 84%
#> 7       SEX                                  F         53 / 62%
#> 8       SEX                                  M         33 / 38%
#> 9      RACE                              WHITE         78 / 91%
#> 10     RACE          BLACK OR AFRICAN AMERICAN           8 / 9%
#> 11     RACE                              ASIAN                0
#> 12     RACE   AMERICAN INDIAN OR ALASKA NATIVE                0
#> 13   ETHNIC                 HISPANIC OR LATINO           3 / 3%
#> 14   ETHNIC             NOT HISPANIC OR LATINO         83 / 97%
#> 15   ETHNIC                       NOT REPORTED                0
#> 16  BMI_CAT                Underweight (<18.5)           3 / 3%
#> 17  BMI_CAT                 Normal (18.5-24.9)         57 / 66%
#> 18  BMI_CAT               Overweight (25-29.9)         20 / 23%
#> 19  BMI_CAT                       Obese (>=30)           6 / 7%
#>    Xanomeline High Dose Xanomeline Low Dose            Total
#> 1        73.8 (SD 7.94)      76.0 (SD 8.11)   75.1 (SD 8.25)
#> 2       69.5 (SD 14.35)     68.0 (SD 14.50)  66.6 (SD 14.13)
#> 3      165.9 (SD 10.28)    163.7 (SD 10.30) 163.9 (SD 10.76)
#> 4        25.2 (SD 3.97)      25.2 (SD 4.40)   24.7 (SD 4.09)
#> 5              11 / 15%              8 / 8%         33 / 13%
#> 6              61 / 85%            88 / 92%        221 / 87%
#> 7              35 / 49%            55 / 57%        143 / 56%
#> 8              37 / 51%            41 / 43%        111 / 44%
#> 9              62 / 86%            90 / 94%        230 / 91%
#> 10              9 / 12%              6 / 6%          23 / 9%
#> 11                    0                   0                0
#> 12               1 / 1%                   0           1 / 0%
#> 13               3 / 4%              6 / 6%          12 / 5%
#> 14             69 / 96%            90 / 94%        242 / 95%
#> 15                    0                   0                0
#> 16               1 / 1%              4 / 4%           8 / 3%
#> 17             39 / 54%            46 / 48%        142 / 56%
#> 18             23 / 32%            32 / 34%         75 / 30%
#> 19              9 / 12%            13 / 14%         28 / 11%
```

The `column` argument selects which ARD grouping variable becomes the
columns (handy when an ARD carries more than one grouping dimension),
and `label` renames the `variable` values for display.

> **Hierarchical ARDs**
>
> `saf_aesocpt_card` is a *hierarchical* AE ARD (system organ class
> within preferred term). The same
> [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
> entry point handles it; the resulting wide frame then renders with the
> indent-and-group recipe from the [Clinical
> cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md).

### Where this fits

[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
keeps the division of labour clean: `cards` (or `gtsummary`, `dplyr`,
SAS) *computes* the summary;
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
reshapes it;
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
*renders* it to submission-grade output.
