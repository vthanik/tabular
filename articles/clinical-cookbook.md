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
    "Safety Population"
  ),
  footnotes = c(
    "Percentages are based on the number of subjects per treatment group.",
    "BMI = body mass index (kg/m^2)."
  )
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal"),
    Total      = col_spec(label = "Total\n(N={saf['Total']})",    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total"))
```

[TABLE]

Percentages are based on the number of subjects per treatment group.

BMI = body mass index (kg/m^2).

 

Table 14.1.1

Demographic and Baseline Characteristics

Safety Population

 

## 2. Overall adverse-event summary

A compact high-level AE table, ordered by descending total frequency so
the most common categories lead. The `Total` cells are formatted strings
(`"217 (85.4)"`), which sort *lexically* (`"157"` before `"3"`), so we
derive a hidden integer key from the count and sort on that instead –
the canonical “sort on a numeric key, never on display text” idiom.

``` r

ae0 <- saf_aeoverall[c("stat_label", "placebo", "drug_50", "drug_100", "Total")]
ae0$total_n <- as.integer(sub(" .*", "", ae0$Total))   # 217 (85.4) -> 217

tabular(
  ae0,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    "Safety Population"
  ),
  footnotes = "n (%) of subjects with at least one event in each category."
) |>
  cols(
    stat_label = col_spec(label = "Category"),
    total_n    = col_spec(visible = FALSE),
    placebo    = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal"),
    Total      = col_spec(label = "Total\n(N={saf['Total']})",    align = "decimal")
  ) |>
  sort_rows(by = "total_n", descending = TRUE)
```

[TABLE]

n (%) of subjects with at least one event in each category.

 

Table 14.3.1

Overall Summary of Adverse Events

Safety Population

 

## 3. Adverse events by system organ class and preferred term

The hierarchical AE table. A single `label` column carries both levels:
system-organ-class text sits flush, preferred terms indent beneath it
via `indent_by = "indent_level"`. The columns that drive the hierarchy
and the sort order ride along hidden (`visible = FALSE`), and a
[`style()`](https://vthanik.github.io/tabular/reference/style.md) layer
bolds the overall and SOC summary rows so the structure reads at a
glance. The data arrives in canonical descending-frequency order, which
`tabular` preserves.

``` r

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.2",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = c(
    "Subjects are counted once within each system organ class and preferred term.",
    "MedDRA version 26.0."
  )
) |>
  cols(
    soc          = col_spec(visible = FALSE),
    row_type     = col_spec(visible = FALSE),
    indent_level = col_spec(visible = FALSE),
    n_total      = col_spec(visible = FALSE),
    soc_n        = col_spec(visible = FALSE),
    label        = col_spec(label = "System Organ Class / Preferred Term",
                            indent_by = "indent_level"),
    placebo      = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50      = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100     = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal"),
    Total        = col_spec(label = "Total\n(N={saf['Total']})",    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  style(bold = TRUE, .at = cells_body(where = row_type %in% c("overall", "soc")))
```

[TABLE]

Subjects are counted once within each system organ class and preferred
term.

MedDRA version 26.0.

 

Table 14.3.2

Adverse Events by System Organ Class and Preferred Term

Safety Population

 

> **Keep a SOC with its terms in print**
>
> In a paginated backend, add
> `paginate(repeat_content = c("titles", "headers", "footnotes"))` so
> the column band and footnotes repeat on every page of this long table.

### Auto-numbered footnotes

The `footnotes =` lines above are fixed text. When a note needs to point
at a *specific* cell, reach for
\[[`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md)\]:
it anchors a marker to any `cells_*()` location, and the engine assigns
the glyph once, in reading order, deduped by `id`. The marker is
allocated *after* decimal alignment, so it never disturbs a column, and
it is byte-identical across every backend and page. Here a denominator
note rides the `Total` header and a shared-`id` note marks every
preferred term reported in at least 50 subjects overall.

``` r

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.2",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  )
) |>
  cols(
    soc          = col_spec(visible = FALSE),
    row_type     = col_spec(visible = FALSE),
    indent_level = col_spec(visible = FALSE),
    n_total      = col_spec(visible = FALSE),
    soc_n        = col_spec(visible = FALSE),
    label        = col_spec(label = "System Organ Class / Preferred Term",
                            indent_by = "indent_level"),
    placebo      = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50      = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100     = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal"),
    Total        = col_spec(label = "Total\n(N={saf['Total']})",    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  style(bold = TRUE, .at = cells_body(where = row_type %in% c("overall", "soc"))) |>
  footnote(
    "Safety population: all randomised subjects who took study drug.",
    .at = cells_headers(j = "Total")
  ) |>
  footnote(
    md("Reported in at least 50 subjects overall."),
    .at = cells_body(where = n_total >= 50, j = "label"),
    id = "highfreq"
  )
```

[TABLE]

a Safety population: all randomised subjects who took study drug.

b Reported in at least 50 subjects overall.

 

Table 14.3.2

Adverse Events by System Organ Class and Preferred Term

Safety Population

 

The header marker is lettered before the body marker because headers
precede the body in reading order. To control hand-built leading
whitespace in a label rather than an engine-managed marker, see the
*Verbatim whitespace* section of the [styling
article](https://vthanik.github.io/tabular/articles/styling.md).

## 4. Vital signs by parameter and visit

A two-level row hierarchy: each vital-sign parameter holds its four
visits, and each visit holds the summary statistics. Both `param` and
`visit` are `usage = "group"` with `group_display = "column"`, so each
name prints once at the top of its block and the repeats blank out – the
reader scans `Parameter`, then `Visit`, then `Statistic` down a clean
stair, never re-reading a label.

``` r

tabular(
  saf_vital,
  titles = c(
    "Table 14.2.1",
    "Vital Signs by Parameter and Visit",
    "Safety Population"
  ),
  footnotes = "Summary statistics of observed values at each visit."
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", group_display = "column",
                          label = "Parameter"),
    visit      = col_spec(usage = "group", group_display = "column",
                          label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100"))
```

[TABLE]

Summary statistics of observed values at each visit.

 

Table 14.2.1

Vital Signs by Parameter and Visit

Safety Population

 

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
    "Efficacy Population"
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
    placebo     = col_spec(label = "Placebo\n(N={eff['placebo']})",  align = "decimal"),
    drug_50     = col_spec(label = "Drug 50\n(N={eff['drug_50']})",  align = "decimal"),
    drug_100    = col_spec(label = "Drug 100\n(N={eff['drug_100']})", align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100"))
```

[TABLE]

Response assessed per RECIST 1.1.

CI = confidence interval; ORR = objective response rate.

 

Table 14.2.1

Best Overall Response and Response Rates

Efficacy Population

 

## 6. Subgrouped vital signs (Sex × Age group)

The same vitals analysis, partitioned into Sex × Age-group panels with
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md).
Each `{sex}, {agegr}` combination becomes its own banner-labelled
partition that starts a new page in the print backends. Within every
panel the two parameters are kept distinct by a `Parameter` column:
`usage = "group"` with `group_display = "column"` prints each parameter
name once at the top of its block and blanks the repeats, so a reader
sees `Diastolic BP (mmHg)` then `Systolic BP (mmHg)` without the label
repeating on every statistic row.

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
    param      = col_spec(usage = "group", group_display = "column",
                          label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo\n(N={saf['placebo']})",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50\n(N={saf['drug_50']})",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100\n(N={saf['drug_100']})", align = "decimal"),
    Total      = col_spec(label = "Total\n(N={saf['Total']})",    align = "decimal")
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  subgroup(by = c("sex", "agegr"), label = "{sex}, {agegr}")
```

[TABLE]

Summary statistics of observed values within each subgroup.

 

Table 14.2.4

Vital Signs by Sex and Age Group

Safety Population

 

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
artefact of record.
