# A submission table, end to end

``` r

library(tabular)
```

The other articles take one verb at a time. This one builds a single
deliverable — *Vital Signs by Sex*, the kind of safety table a
programmer assembles from a shell on a Monday morning — and walks it
from the pre-summarised frame all the way to the RTF you would hand to a
reviewer. Each step adds one verb; the last few add the submission
chrome that turns a table into a page.

## 1. The pre-summarised frame

`tabular` does no statistics. The summary is already computed: one row
per display row, one column per arm. `saf_subgroup` is a vital-signs
summary, split by sex and age group, with hidden columns that drive the
display.

``` r

str(saf_subgroup, vec.len = 2)
#> 'data.frame':    32 obs. of  11 variables:
#>  $ sex       : Factor w/ 2 levels "F","M": 1 1 1 1 1 ...
#>  $ agegr     : Factor w/ 2 levels "<65",">=65": 1 1 1 1 1 ...
#>  $ sex_n     : int  106 106 106 106 106 ...
#>  $ agegr_n   : int  23 23 23 23 23 ...
#>  $ paramcd   : chr  "DIABP" "DIABP" ...
#>  $ param     : chr  "Diastolic BP (mmHg)" "Diastolic BP (mmHg)" ...
#>  $ stat_label: chr  "n" "Mean (SD)" ...
#>  $ placebo   : chr  "24" "73.9 (10.5)" ...
#>  $ drug_50   : chr  "9" "79.9 (8.3)" ...
#>  $ drug_100  : chr  "9" "81.6 (8.5)" ...
#>  $ Total     : chr  "42" "76.8 (10.0)" ...
```

`sex` and `agegr` are the partitioning factors; `paramcd` orders the
parameters; `param` and `stat_label` are the visible row labels; the
four arm columns hold the formatted cells. The `*_n` columns carry
denominators we will pull in later.

## 2. Columns and nested sections

[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) names
every column. Hide the machinery (`sex`, `agegr`, the `*_n`
denominators, the `paramcd` sort key); make `agegr` and `param` section
groups so the body reads *age group → parameter → statistics*; align the
arm columns on the decimal point.

``` r

vitals <- tabular(
  saf_subgroup,
  titles = c(
    "Table 14.2.1",
    "Vital Signs Summary by Sex",
    "Safety Population"
  ),
  footnotes = "Mean (SD) unless otherwise stated. Based on observed cases."
) |>
  cols(
    sex        = col_spec(visible = FALSE),
    sex_n      = col_spec(visible = FALSE),
    agegr_n    = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    agegr      = col_spec(usage = "group", label = "Age Group"),
    param      = col_spec(usage = "group", label = "Parameter"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal"),
    Total      = col_spec(label = "Total",    align = "decimal")
  )

vitals
```

| Statistic               | Placebo      | Drug 50      | Drug 100     | Total        |
|-------------------------|--------------|--------------|--------------|--------------|
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
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
|                         |              |              |              |              |
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
| Mean (SD)               |  73.9 (9.7)  |  73.7 (9.7)  |  75.3 (7.9)  |  74.4 (9.2)  |
| Median                  |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max                |  58  , 100   |  52  , 94    |  57  , 90    |  52  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| n                       |  81          |  66          |  75          | 222          |
|                         |              |              |              |              |
| Mean (SD)               | 127.6 (15.3) | 127.0 (17.1) | 127.4 (11.5) | 127.3 (14.7) |
| Median                  | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max                |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

Mean (SD) unless otherwise stated. Based on observed cases.

 

Table 14.2.1

Vital Signs Summary by Sex

Safety Population

 

The two `usage = "group"` columns nest: each age group introduces its
block, and each parameter introduces its statistics within that block.

## 3. Split by sex with `subgroup()`

The table should repeat *per sex*, each partition starting its own page
in the print backends.
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
cuts it, and a glue-style `label` template names each banner:

``` r

vitals <- vitals |>
  subgroup(by = "sex", label = "Sex: {sex}")

vitals
```

| Statistic               | Placebo      | Drug 50      | Drug 100     | Total        |
|-------------------------|--------------|--------------|--------------|--------------|
| **Sex: F**              |              |              |              |              |
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
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
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
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

Mean (SD) unless otherwise stated. Based on observed cases.

 

Table 14.2.1

Vital Signs Summary by Sex

Safety Population

 

`F` and `M` now head their own partitions. The `sex` column named in
`by` is hidden automatically.

## 4. Per-page BigN

Each sex partition needs its *own* denominators — the *(N=)* on the
column headers must count the subjects in *that* page, not the whole
study. Hand
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
a `big_n` table: one row per subgroup level, one column per arm. (These
come from your ADSL counts upstream; here they sum to the overall
`saf_n` totals.)

``` r

sex_n <- data.frame(
  sex      = factor(c("F", "M"), levels = c("F", "M")),
  placebo  = c(50L, 36L),
  drug_50  = c(52L, 44L),
  drug_100 = c(38L, 34L),
  Total    = c(140L, 114L)
)

vitals <- vitals |>
  subgroup(
    by        = "sex",
    label     = "Sex: {sex}",
    big_n     = sex_n,
    big_n_fmt = "\n(N={n})"
  )

vitals
```

| Statistic               | Placebo      | Drug 50      | Drug 100     | Total        |
|-------------------------|--------------|--------------|--------------|--------------|
| **Sex: F**              |              |              |              |              |
|                         | (N=50)       | (N=52)       | (N=38)       | (N=140)      |
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
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
|                         | (N=36)       | (N=44)       | (N=34)       | (N=114)      |
| **\<65**                |              |              |              |              |
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
| **\>=65**               |              |              |              |              |
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

Mean (SD) unless otherwise stated. Based on observed cases.

 

Table 14.2.1

Vital Signs Summary by Sex

Safety Population

 

Now the *Sex: F* page carries *Placebo (N=50)* while the *Sex: M* page
carries *Placebo (N=36)*. In the paper backends (RTF / PDF / DOCX) the
`(N=)` rides the repeating column header on every page of the partition;
in this continuous HTML preview it shows as an *(N=)* row under each
banner.

## 5. A running header and footer

Submission pages carry chrome outside the table — the protocol and page
number at the top, the program path and run time at the foot. Set them
on the preset; `{page}` / `{npages}` resolve per page, and
`{program_path}` / `{datetime}` resolve at render time.

``` r

vitals <- vitals |>
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

## 6. Group-aware pagination

[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
governs the page breaks. You do not set rows-per-page — the engine sizes
the budget from the preset and chrome. Keep each parameter’s statistics
together, and repeat the titles, headers, and footnotes on every page.

``` r

vitals <- vitals |>
  paginate(
    keep_together  = "param",
    repeat_content = c("titles", "headers", "footnotes")
  )
```

## 7. Emit, with a QC sidecar

The spec is complete.
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md)
dispatches on the file extension. Pass `data_file` to drop the resolved
wide frame beside the render — the QC programmer reads it back and
checks the numbers independently.

``` r

out <- tempfile(fileext = ".rtf")
qc  <- tempfile(fileext = ".csv")

emit(vitals, out, data_file = qc)

file.exists(out)   # the submission deliverable
#> [1] TRUE
file.exists(qc)    # the post-engine wide frame, for double programming
#> [1] TRUE
```

The **same** `vitals` spec emits to every backend — swap the extension
and the per-page BigN, the running header, and the pagination all carry
across unchanged:

``` r

for (ext in c(".rtf", ".html", ".tex", ".docx")) {
  cat(ext, "->", basename(emit(vitals, tempfile(fileext = ext))), "\n")
}
#> .rtf -> file323447e539e1.rtf 
#> .html -> file32344d63d97c.html 
#> .tex -> file323475bb4997.tex 
#> .docx -> file32344a99a760.docx
```

`.pdf` works the same way; it compiles through `xelatex`, so it needs a
TeX install
([`check_latex()`](https://vthanik.github.io/tabular/reference/check_latex.md)
reports readiness — see the
[README](https://vthanik.github.io/tabular/#installation)).

## Where this fits

This is the whole pipeline in one place:
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) to
start, [`cols()`](https://vthanik.github.io/tabular/reference/cols.md)
to shape,
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
to partition and carry per-page BigN,
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md) for
the running chrome,
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
for the breaks, and
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) to ship
— with `data_file` leaving a QC trail. From here:

- [Columns &
  headers](https://vthanik.github.io/tabular/articles/columns-and-headers.md)
  — the full
  [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
  toolbox and multi-level header bands.
- [Rows, grouping &
  pagination](https://vthanik.github.io/tabular/articles/rows-grouping-pagination.md)
  — section groups, the running-header API, and pagination in depth.
- [Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md)
  — more complete production tables, sorted and paginated end to end.
