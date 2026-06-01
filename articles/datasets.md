# Demo datasets

``` r

library(tabular)
#> 
#> Attaching package: 'tabular'
#> The following object is masked from 'package:stats':
#> 
#>     pt
```

Eleven pre-summarised datasets ship with `tabular`. They power every
example, vignette, and test, and they are the fastest way to prototype a
table without preparing your own data. All are synthetic, derived from
the CDISC pilot compounds (Xanomeline and placebo).

## Safety tables

### `saf_demo` — demographics

The canonical demographics summary: one row per statistic per
characteristic, columns per arm. The `variable` column is the section
grouping; `stat_label` the statistic.

``` r

dim(saf_demo)
#> [1] 35  6
names(saf_demo)
#> [1] "variable"   "stat_label" "placebo"    "drug_100"   "drug_50"   
#> [6] "Total"

tabular(saf_demo[1:7, ]) |>
  cols(
    variable   = col_spec(usage = "group"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  )
```

| Statistic            | Placebo     | Drug 100    | Drug 50     | Total        |
|----------------------|-------------|-------------|-------------|--------------|
| **Age (years)**      |             |             |             |              |
| n                    | 86          | 72          | 96          | 254          |
| Mean (SD)            | 75.2 (8.59) | 73.8 (7.94) | 76.0 (8.11) |  75.1 (8.25) |
| Median               | 76.0        | 75.5        | 78.0        |  77.0        |
| Q1, Q3               | 69.2, 81.8  | 70.5, 79.0  | 71.0, 82.0  |  70.0, 81.0  |
| Min, Max             | 52  , 89    | 56  , 88    | 51  , 88    |  51  , 89    |
|                      |             |             |             |              |
| **Age Group, n (%)** |             |             |             |              |
| 18-64                | 14 (16.3)   | 11 (15.3)   |  8 ( 8.3)   |  33 (13.0)   |
| \>64                 | 72 (83.7)   | 61 (84.7)   | 88 (91.7)   | 221 (87.0)   |

### `saf_aeoverall` — high-level AE summary

A compact overall adverse-event table: one row per AE category, columns
per arm.

``` r

dim(saf_aeoverall)
#> [1] 8 5

tabular(saf_aeoverall[c("stat_label", "placebo", "drug_50", "drug_100", "Total")]) |>
  cols(
    stat_label = col_spec(label = "Category"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  )
```

| Category                     | Placebo   | Drug 50   | Drug 100  | Total      |
|------------------------------|-----------|-----------|-----------|------------|
| Any TEAE                     | 65 (75.6) | 84 (87.5) | 68 (94.4) | 217 (85.4) |
| Any Serious AE (SAE)         |  0        |  2 ( 2.1) |  1 ( 1.4) |   3 ( 1.2) |
| Any AE Related to Study Drug | 43 (50.0) | 77 (80.2) | 64 (88.9) | 184 (72.4) |
| Any AE Leading to Death      |  2 ( 2.3) |  1 ( 1.0) |  0        |   3 ( 1.2) |
| Any AE Recovered / Resolved  | 47 (54.7) | 61 (63.5) | 49 (68.1) | 157 (61.8) |
| Maximum severity: Mild       | 36 (41.9) | 21 (21.9) | 20 (27.8) |  77 (30.3) |
| Maximum severity: Moderate   | 24 (27.9) | 47 (49.0) | 40 (55.6) | 111 (43.7) |
| Maximum severity: Severe     |  5 ( 5.8) | 16 (16.7) |  8 (11.1) |  29 (11.4) |

### `saf_aesocpt` — AEs by SOC and preferred term

A hierarchical AE table. `label` carries both the system-organ-class and
preferred-term text; `indent_level`, `row_type`, and the sort keys
(`soc_n`, `n_total`) are hidden columns that drive the display.

``` r

dim(saf_aesocpt)
#> [1] 61 10
names(saf_aesocpt)
#>  [1] "soc"          "label"        "row_type"     "indent_level" "n_total"     
#>  [6] "soc_n"        "placebo"      "drug_50"      "drug_100"     "Total"
```

### `saf_vital` — vital signs by parameter and visit

Four parameters × four visits × summary statistics. `param` is the
section; `visit` an ordinary column.

``` r

dim(saf_vital)
#> [1] 64  7
levels(factor(saf_vital$visit))
#> [1] "Baseline"         "End of Treatment" "Week 16"          "Week 8"
```

### `saf_subgroup` — vitals by Sex × Age group

The subgrouped vitals analysis. `sex` and `agegr` partition the table
(with per-partition BigN in `sex_n` / `agegr_n`); use them with
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md).

``` r

dim(saf_subgroup)
#> [1] 32 11
names(saf_subgroup)
#>  [1] "sex"        "agegr"      "sex_n"      "agegr_n"    "paramcd"   
#>  [6] "param"      "stat_label" "placebo"    "drug_50"    "drug_100"  
#> [11] "Total"
```

## Efficacy tables

### `eff_resp` — best overall response and rates

Response categories grouped under section labels (`group_label`): Best
Overall Response, then derived Objective Response / Clinical Benefit /
Disease Control rates.

``` r

dim(eff_resp)
#> [1] 13  7
unique(eff_resp$group_label)
#> [1] "Best Overall Response"   "Objective Response Rate"
#> [3] "Clinical Benefit Rate"   "Disease Control Rate"
```

### `eff_estimates` — treatment-effect estimates

Raw **numeric** estimates (not pre-formatted strings) from several
models — a fixture for exercising `col_spec(format =)` and numeric
rounding at render time.

``` r

eff_estimates
#>                   model estimate lower_ci upper_ci p_value
#> 1                ANCOVA    -2.31    -3.42    -1.20  0.0042
#> 2                  MMRM    -2.45       NA       NA  0.0061
#> 3                Cox PH     0.81     0.68     0.97  0.0087
#> 4 Bootstrap (1000 reps)    -2.29    -3.50    -1.10  0.0050
```

## Bridge and denominator data

### `saf_demo_card`, `saf_aesocpt_card` — cards ARDs

Long-format Analysis Results Data in the `cards` shape, the input to
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md).
`saf_aesocpt_card` is hierarchical (SOC within PT). See [From a cards
ARD](https://vthanik.github.io/tabular/articles/from-ard.md).

``` r

dim(saf_demo_card)
#> [1] 317   8
head(saf_demo_card, 4)
#>   group1 group1_level variable variable_level    context stat_name stat_label
#> 1 TRT01A      Placebo      AGE           NULL continuous         N          N
#> 2 TRT01A      Placebo      AGE           NULL continuous      mean       Mean
#> 3 TRT01A      Placebo      AGE           NULL continuous        sd         SD
#> 4 TRT01A      Placebo      AGE           NULL continuous    median     Median
#>       stat
#> 1       86
#> 2  75.2093
#> 3 8.590167
#> 4       76
```

### `saf_n`, `eff_n` — BigN denominators

Per-arm subject counts for the safety and efficacy populations. Key the
column-header `(N=…)` labels off `arm_short` rather than carrying the
counts as a fragile attribute.

``` r

saf_n
#>                    arm arm_short   n
#> 1              Placebo   placebo  86
#> 2  Xanomeline Low Dose   drug_50  96
#> 3 Xanomeline High Dose  drug_100  72
#> 4                Total     Total 254
eff_n
#>                    arm arm_short   n
#> 1              Placebo   placebo  86
#> 2  Xanomeline Low Dose   drug_50  84
#> 3 Xanomeline High Dose  drug_100  84
#> 4                Total     Total 254
```

## Quick reference

| Dataset            | Rows × Cols | Represents                           |
|--------------------|-------------|--------------------------------------|
| `saf_demo`         | 35 × 6      | Demographics, Safety Population      |
| `saf_aeoverall`    | 8 × 5       | Overall AE summary                   |
| `saf_aesocpt`      | 61 × 10     | AEs by SOC / preferred term          |
| `saf_vital`        | 64 × 7      | Vital signs by parameter and visit   |
| `saf_subgroup`     | 32 × 11     | Vitals by Sex × Age group            |
| `eff_resp`         | 13 × 7      | Best overall response and rates      |
| `eff_estimates`    | 4 × 5       | Treatment-effect estimates (numeric) |
| `saf_demo_card`    | 317 × 8     | Demographics ARD (long)              |
| `saf_aesocpt_card` | 558 × 10    | AE ARD, hierarchical (long)          |
| `saf_n`            | 4 × 3       | Safety BigN per arm                  |
| `eff_n`            | 4 × 3       | Efficacy BigN per arm                |

\`\`\`
