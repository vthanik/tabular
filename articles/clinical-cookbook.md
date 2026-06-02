# Clinical cookbook

``` r

library(tabular)

saf <- stats::setNames(saf_n$n, saf_n$arm_short)   # safety BigN
eff <- stats::setNames(eff_n$n, eff_n$arm_short)    # efficacy BigN
```

Each recipe is a full pipeline on bundled demo data. The table you see
is the live HTML preview; in practice you would end the chain with
`emit(tab, "t_x.rtf")` to produce the submission deliverable. Swap the
demo dataset for your own pre-summarised wide frame and the recipe
holds.

## 1. Demographics and baseline characteristics

The canonical safety-population summary: a group column for the
characteristic, decimal-aligned arm columns with BigN, a treatment-group
spanner, and a denominator footnote.

``` r

demo <- saf_demo[c("variable", "stat_label", "placebo", "drug_50", "drug_100", "Total")]

tabular(
  demo,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    sprintf("Safety Population (N=%d)", saf["Total"])
  ),
  footnotes = c(
    "Percentages are based on the number of subjects per treatment group.",
    "BMI = body mass index (kg/m^2)."
  )
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo\n(N=%d)",  saf["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\n(N=%d)",  saf["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\n(N=%d)", saf["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total\n(N=%d)",    saf["Total"]),    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total"))
```

 

Table 14.1.1

Demographic and Baseline Characteristics

Safety Population (N=254)

 

[TABLE]

Percentages are based on the number of subjects per treatment group.

BMI = body mass index (kg/m^2).

## 2. Overall adverse-event summary

A compact high-level AE table, ordered by descending total frequency so
the most common categories lead.

``` r

ae0 <- saf_aeoverall[c("stat_label", "placebo", "drug_50", "drug_100", "Total")]

tabular(
  ae0,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    sprintf("Safety Population (N=%d)", saf["Total"])
  ),
  footnotes = "n (%) of subjects with at least one event in each category."
) |>
  cols(
    stat_label = col_spec(label = "Category"),
    placebo    = col_spec(label = sprintf("Placebo\n(N=%d)",  saf["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\n(N=%d)",  saf["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\n(N=%d)", saf["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total\n(N=%d)",    saf["Total"]),    align = "decimal")
  ) |>
  sort_rows(by = "Total", descending = TRUE)
```

 

Table 14.3.1

Overall Summary of Adverse Events

Safety Population (N=254)

 

[TABLE]

n (%) of subjects with at least one event in each category.

## 3. Adverse events by system organ class and preferred term

The hierarchical AE table. Preferred terms indent under their
system-organ-class header via `indent_by`, and the columns that drive
the hierarchy and sort order are hidden. The data arrives in canonical
descending-frequency order, which `tabular` preserves.

``` r

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.2",
    "Adverse Events by System Organ Class and Preferred Term",
    sprintf("Safety Population (N=%d)", saf["Total"])
  ),
  footnotes = c(
    "Subjects are counted once within each system organ class and preferred term.",
    "MedDRA version 26.0."
  )
) |>
  cols(
    soc          = col_spec(visible = FALSE),
    label        = col_spec(usage = "group", indent_by = "indent_level",
                            label = "System Organ Class / Preferred Term"),
    row_type     = col_spec(visible = FALSE),
    indent_level = col_spec(visible = FALSE),
    n_total      = col_spec(visible = FALSE),
    soc_n        = col_spec(visible = FALSE),
    placebo      = col_spec(label = sprintf("Placebo\n(N=%d)",  saf["placebo"]),  align = "decimal"),
    drug_50      = col_spec(label = sprintf("Drug 50\n(N=%d)",  saf["drug_50"]),  align = "decimal"),
    drug_100     = col_spec(label = sprintf("Drug 100\n(N=%d)", saf["drug_100"]), align = "decimal"),
    Total        = col_spec(label = sprintf("Total\n(N=%d)",    saf["Total"]),    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total"))
```

 

Table 14.3.2

Adverse Events by System Organ Class and Preferred Term

Safety Population (N=254)

 

[TABLE]

Subjects are counted once within each system organ class and preferred
term.

MedDRA version 26.0.

> **Keep a SOC with its terms in print**
>
> In a paginated backend, add
> `paginate(repeat_content = c("titles", "headers", "footnotes"))` so
> the column band and footnotes repeat on every page of this long table.

## 4. Vital signs by parameter and visit

Each vital-sign parameter is a section; visit is an ordinary column so a
reader scans across timepoints within a parameter.

``` r

tabular(
  saf_vital,
  titles = c(
    "Table 14.2.1",
    "Vital Signs by Parameter and Visit",
    sprintf("Safety Population (N=%d)", saf["Total"])
  ),
  footnotes = "Summary statistics of observed values at each visit."
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group"),
    visit      = col_spec(label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo\n(N=%d)",  saf["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\n(N=%d)",  saf["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\n(N=%d)", saf["drug_100"]), align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100"))
```

 

Table 14.2.1

Vital Signs by Parameter and Visit

Safety Population (N=254)

 

[TABLE]

Summary statistics of observed values at each visit.

## 5. Best overall response and response rates

An efficacy table on the efficacy population: response categories
grouped under section labels (Best Overall Response, then derived
rates), with the efficacy BigN in the headers.

``` r

tabular(
  eff_resp,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Population (N=%d)", sum(eff[c("placebo", "drug_50", "drug_100")]))
  ),
  footnotes = c(
    "Response assessed per RECIST 1.1.",
    "CI = confidence interval; ORR = objective response rate."
  )
) |>
  cols(
    row_type    = col_spec(visible = FALSE),
    groupid     = col_spec(visible = FALSE),
    group_label = col_spec(usage = "group"),
    stat_label  = col_spec(label = "Response"),
    placebo     = col_spec(label = sprintf("Placebo\n(N=%d)",  eff["placebo"]),  align = "decimal"),
    drug_50     = col_spec(label = sprintf("Drug 50\n(N=%d)",  eff["drug_50"]),  align = "decimal"),
    drug_100    = col_spec(label = sprintf("Drug 100\n(N=%d)", eff["drug_100"]), align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100"))
```

 

Table 14.2.1

Best Overall Response and Response Rates

Efficacy Population (N=254)

 

[TABLE]

Response assessed per RECIST 1.1.

CI = confidence interval; ORR = objective response rate.

## 6. Subgrouped vital signs (Sex × Age group)

The same vitals analysis, partitioned into Sex × Age-group panels with
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md).
Each combination becomes its own banner-labelled partition that starts a
new page in the print backends.

``` r

tabular(
  saf_subgroup,
  titles = c(
    "Table 14.2.4",
    "Vital Signs by Sex and Age Group",
    "Safety Population"
  ),
  footnotes = "Summary statistics of observed values within each subgroup."
) |>
  cols(
    sex        = col_spec(visible = FALSE),
    agegr      = col_spec(visible = FALSE),
    sex_n      = col_spec(visible = FALSE),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  ) |>
  subgroup(by = c("sex", "agegr"), label = "{sex}, {agegr}")
```

 

Table 14.2.4

Vital Signs by Sex and Age Group

Safety Population

 

| Statistic    | Placebo      | Drug 50      | Drug 100     | Total        |
|--------------|--------------|--------------|--------------|--------------|
| **F, \<65**  |              |              |              |              |
| n            |  24          |   9          |   9          |  42          |
| Mean (SD)    |  73.9 (10.5) |  79.9 (8.3)  |  81.6 (8.5)  |  76.8 (10.0) |
| Median       |  78.0        |  80.0        |  84.0        |  79.5        |
| Min, Max     |  49  , 88    |  68  , 90    |  68  , 90    |  49  , 90    |
|              |              |              |              |              |
| n            |  24          |   9          |   9          |  42          |
| Mean (SD)    | 129.9 (11.2) | 132.1 (4.3)  | 121.8 (13.6) | 128.6 (11.1) |
| Median       | 130.0        | 130.0        | 128.0        | 130.0        |
| Min, Max     | 113  , 156   | 128  , 140   | 100  , 140   | 100  , 156   |
|              |              |              |              |              |
| **F, \>=65** |              |              |              |              |
| n            | 105          |  99          |  72          | 276          |
| Mean (SD)    |  74.0 (10.8) |  76.9 (12.2) |  75.9 (11.9) |  75.5 (11.7) |
| Median       |  72.0        |  79.0        |  80.0        |  76.0        |
| Min, Max     |  50  , 100   |  50  , 100   |  56  , 98    |  50  , 100   |
|              |              |              |              |              |
| n            | 105          |  99          |  72          | 276          |
| Mean (SD)    | 137.1 (15.8) | 137.5 (16.7) | 140.1 (16.8) | 138.0 (16.4) |
| Median       | 134.0        | 134.0        | 142.0        | 138.0        |
| Min, Max     |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|              |              |              |              |              |
| **M, \<65**  |              |              |              |              |
| n            |  12          |   3          |  12          |  27          |
| Mean (SD)    |  83.0 (13.3) |  80.7 (3.1)  |  77.1 (7.0)  |  80.1 (10.2) |
| Median       |  80.0        |  80.0        |  79.0        |  80.0        |
| Min, Max     |  68  , 104   |  78  , 84    |  68  , 87    |  68  , 104   |
|              |              |              |              |              |
| n            |  12          |   3          |  12          |  27          |
| Mean (SD)    | 134.4 (8.3)  | 122.7 (4.6)  | 124.8 (12.0) | 128.9 (10.9) |
| Median       | 131.0        | 120.0        | 127.0        | 130.0        |
| Min, Max     | 123  , 150   | 120  , 128   | 107  , 146   | 107  , 150   |
|              |              |              |              |              |
| **M, \>=65** |              |              |              |              |
| n            |  81          |  66          |  75          | 222          |
| Mean (SD)    |  73.9 (9.7)  |  73.7 (9.7)  |  75.3 (7.9)  |  74.4 (9.2)  |
| Median       |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max     |  58  , 100   |  52  , 94    |  57  , 90    |  52  , 100   |
|              |              |              |              |              |
| n            |  81          |  66          |  75          | 222          |
| Mean (SD)    | 127.6 (15.3) | 127.0 (17.1) | 127.4 (11.5) | 127.3 (14.7) |
| Median       | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max     |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

Summary statistics of observed values within each subgroup.

## Shipping the deliverable

Every recipe ends the same way in production — pick a backend by file
extension and
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md):

``` r

tab |> emit("t_14_1_1.rtf")     # RTF for the submission
tab |> emit("t_14_1_1.docx")    # native Word
tab |> emit("t_14_1_1.pdf")     # paginated PDF (via tinytex)
```

See [Fonts &
fidelity](https://vthanik.github.io/tabular/articles/fonts-and-fidelity.md)
for why the paginated RTF/PDF/DOCX, not the HTML preview, is the
artefact of record. \`\`\`
