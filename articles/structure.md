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
| `"id"` | the row label that must stay visible | like `display`, but **joins the stub and repeats on every horizontal panel** |

Indentation is **not** a `usage` role — it is the separate
`col_spec(indent = …)` argument (a fixed integer level, or a column name
for per-row depth).

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
    stat_label = col_spec(label = "")
  ) |>
  cols_apply(arms, col_spec(align = "decimal"))
```

|  | placebo | drug_50 | drug_100 | Total |
|----|----|----|----|----|
| **Age (years)** |  |  |  |  |
| n | 86          | 96          | 72          | 254          |
| Mean (SD) | 75.2 (8.59) | 76.0 (8.11) | 73.8 (7.94) |  75.1 (8.25) |
| Median | 76.0        | 78.0        | 75.5        |  77.0        |
| Q1, Q3 | 69.2, 81.8  | 71.0, 82.0  | 70.5, 79.0  |  70.0, 81.0  |
| Min, Max | 52  , 89    | 51  , 88    | 56  , 88    |  51  , 89    |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F | 53 (61.6)   | 55 (57.3)   | 35 (48.6)   | 143 (56.3)   |
| M | 33 (38.4)   | 41 (42.7)   | 37 (51.4)   | 111 (43.7)   |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE | 78 (90.7)   | 90 (93.8)   | 62 (86.1)   | 230 (90.6)   |
| BLACK OR AFRICAN AMERICAN |  8 ( 9.3)   |  6 ( 6.2)   |  9 (12.5)   |  23 ( 9.1)   |
| ASIAN |  0          |  0          |  0          |   0          |
| AMERICAN INDIAN OR ALASKA NATIVE |  0          |  0          |  1 ( 1.4)   |   1 ( 0.4)   |

 

Demographics

 

[`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
attaches one shared `col_spec` to **all** the arm columns at once — use
it instead of repeating `cols(placebo = …, drug_50 = …)` for a variable
number of arms.

> **Indent from exactly one source.** `group_display = "header_row"`
> already indents its child rows one level, so the stub column (here
> `stat_label`) needs **no** `indent` — the section supplies it. (An
> explicit `indent` on the host *overrides* that auto-indent rather than
> stacking, so `indent = 1` there still yields a single level.) The same
> care applies to labels from
> [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md),
> which come out with a leading indent baked into the string: keep them
> as-is or [`trimws()`](https://rdrr.io/r/base/trimws.html) them and set
> `indent` yourself — don’t double up.

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
    stat_label = col_spec(label = ""),
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
    stat_label = col_spec(label = "")
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
    stat_label = col_spec(label = "", width = "2.2in")
  ) |>
  cols_apply(arms, col_spec(align = "decimal", width = "1in")) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total"))
```

|  | Treatment Group |  |  |  |
|----|----|----|----|----|
|  | placebo | drug_50 | drug_100 | Total |
| **Age (years)** |  |  |  |  |
| n | 86          | 96          | 72          | 254          |
| Mean (SD) | 75.2 (8.59) | 76.0 (8.11) | 73.8 (7.94) |  75.1 (8.25) |
| Median | 76.0        | 78.0        | 75.5        |  77.0        |
| Q1, Q3 | 69.2, 81.8  | 71.0, 82.0  | 70.5, 79.0  |  70.0, 81.0  |
| Min, Max | 52  , 89    | 51  , 88    | 56  , 88    |  51  , 89    |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F | 53 (61.6)   | 55 (57.3)   | 35 (48.6)   | 143 (56.3)   |
| M | 33 (38.4)   | 41 (42.7)   | 37 (51.4)   | 111 (43.7)   |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE | 78 (90.7)   | 90 (93.8)   | 62 (86.1)   | 230 (90.6)   |
| BLACK OR AFRICAN AMERICAN |  8 ( 9.3)   |  6 ( 6.2)   |  9 (12.5)   |  23 ( 9.1)   |
| ASIAN |  0          |  0          |  0          |   0          |
| AMERICAN INDIAN OR ALASKA NATIVE |  0          |  0          |  1 ( 1.4)   |   1 ( 0.4)   |

 

Demographics

 

Widths: `"auto"` (default) sizes to content; a pinned value (`"1in"`,
`1.0`, `"20%"`) wraps within that width. **Set the shared arm width via
[`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
last** — its non-default `width` then wins the field-merge; a later
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) call
carrying the default `width = "auto"` would otherwise be ambiguous.

## Sorting rows

Display cells are formatted strings — `"54 (21.3)"` sorts lexically, not
numerically. The idiom: carry one hidden **numeric key** per sort level,
hide it with `col_spec(visible = FALSE)`, and hand the keys to
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md).
`descending` takes one value per key, so mixed-direction sorts are a
single call.

The bundled AE table ships its keys precomputed: `soc_n` (events in the
parent SOC, constant down each SOC block) and `n_total` (events on the
row). Sorting on both, descending, clusters every preferred term under
its SOC and orders both levels by frequency — the standard SAP ordering:

``` r

data(cdisc_saf_aesocpt, package = "tabular")

tabular(cdisc_saf_aesocpt, titles = "AEs by SOC and PT, descending frequency") |>
  cols(
    label = col_spec(
      label = "SOC / Preferred Term",
      indent = "indent_level"
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
  cols_apply(arms, col_spec(align = "decimal")) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))
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
| INFECTIONS AND INFESTATIONS | 12 (14.0) |  6 ( 6.2) | 11 (15.3) |  29 (11.4) |
| NASOPHARYNGITIS |  2 ( 2.3) |  4 ( 4.2) |  6 ( 8.3) |  12 ( 4.7) |
|  |  |  |  |  |
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

 

AEs by SOC and PT, descending frequency

 

Because `soc_n` is constant within a SOC block and never smaller than
any PT’s `n_total` inside it, each SOC’s summary row sorts to the top of
its own block — no separate “parent first” switch needed.

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
      indent = "indent_level"
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
|  | placebo | drug_50 | drug_100 | Total |
| **Age (years)** |  |  |  |  |
| n | 86          | 96          | 72          | 254          |
| Mean (SD) | 75.2 (8.59) | 76.0 (8.11) | 73.8 (7.94) |  75.1 (8.25) |
| Median | 76.0        | 78.0        | 75.5        |  77.0        |
| Q1, Q3 | 69.2, 81.8  | 71.0, 82.0  | 70.5, 79.0  |  70.0, 81.0  |
| Min, Max | 52  , 89    | 51  , 88    | 56  , 88    |  51  , 89    |
|   |  |  |  |  |
| **Sex, n (%)** |  |  |  |  |
| F | 53 (61.6)   | 55 (57.3)   | 35 (48.6)   | 143 (56.3)   |
| M | 33 (38.4)   | 41 (42.7)   | 37 (51.4)   | 111 (43.7)   |
|   |  |  |  |  |
| **Race, n (%)** |  |  |  |  |
| WHITE | 78 (90.7)   | 90 (93.8)   | 62 (86.1)   | 230 (90.6)   |
| BLACK OR AFRICAN AMERICAN |  8 ( 9.3)   |  6 ( 6.2)   |  9 (12.5)   |  23 ( 9.1)   |
| ASIAN |  0          |  0          |  0          |   0          |
| AMERICAN INDIAN OR ALASKA NATIVE |  0          |  0          |  1 ( 1.4)   |   1 ( 0.4)   |

 

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
- **`panels` is a positive integer** (default `1` = no split).
  Width-aware automatic splitting is a planned future feature, not a
  current option.

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
    paramcd = col_spec(visible = FALSE),
    param = col_spec(usage = "group", label = "Parameter"),
    visit = col_spec(usage = "group", label = "Visit"),
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
| **Sex: F (N = 143)**    |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 208          | 220          | 140          | 568          |
| Mean (SD)               |  77.1 (11.2) |  76.3 (10.5) |  78.0 (10.8) |  77.0 (10.8) |
| Median                  |  78.0        |  77.3        |  78.3        |  78.0        |
| Min, Max                |  40  , 110   |  48  , 100   |  51  , 108   |  40  , 110   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 168          | 148          | 104          | 420          |
| Mean (SD)               |  75.1 (9.4)  |  77.1 (11.0) |  76.0 (10.0) |  76.0 (10.1) |
| Median                  |  76.0        |  79.7        |  78.0        |  78.0        |
| Min, Max                |  49  , 98    |  55  , 98    |  54  , 98    |  49  , 98    |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 156          | 100          |  68          | 324          |
| Mean (SD)               |  74.9 (11.1) |  75.6 (10.8) |  77.8 (8.9)  |  75.8 (10.6) |
| Median                  |  77.7        |  76.0        |  79.0        |  78.0        |
| Min, Max                |  49  , 98    |  55  , 98    |  56  , 92    |  49  , 98    |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       | 129          | 108          |  81          | 318          |
| Mean (SD)               |  74.0 (10.7) |  77.2 (11.9) |  76.5 (11.7) |  75.7 (11.5) |
| Median                  |  74.0        |  79.5        |  80.0        |  78.0        |
| Min, Max                |  49  , 100   |  50  , 100   |  56  , 98    |  49  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 208          | 220          | 140          | 568          |
| Mean (SD)               | 141.1 (16.9) | 139.2 (18.2) | 140.4 (19.5) | 140.2 (18.0) |
| Median                  | 141.8        | 140.0        | 140.0        | 140.0        |
| Min, Max                | 100  , 184   | 100  , 194   | 100  , 192   | 100  , 194   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 168          | 148          | 104          | 420          |
| Mean (SD)               | 138.1 (16.5) | 137.9 (17.8) | 139.6 (19.0) | 138.4 (17.6) |
| Median                  | 139.5        | 135.7        | 140.0        | 138.7        |
| Min, Max                | 100  , 184   |  92  , 200   |  91  , 198   |  91  , 200   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 156          | 100          |  68          | 324          |
| Mean (SD)               | 137.9 (17.4) | 134.8 (15.0) | 142.0 (15.3) | 137.8 (16.4) |
| Median                  | 139.5        | 130.5        | 140.0        | 138.0        |
| Min, Max                | 106  , 190   | 100  , 168   | 107  , 186   | 100  , 190   |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       | 129          | 108          |  81          | 318          |
| Mean (SD)               | 135.8 (15.3) | 137.0 (16.1) | 138.0 (17.4) | 136.8 (16.1) |
| Median                  | 133.0        | 133.0        | 140.0        | 136.0        |
| Min, Max                |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|                         |              |              |              |              |
| **Sex: M (N = 111)**    |              |              |              |              |
| **Diastolic BP (mmHg)** |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 132          | 164          | 148          | 444          |
| Mean (SD)               |  77.1 (10.0) |  77.1 (8.8)  |  78.5 (9.8)  |  77.6 (9.5)  |
| Median                  |  76.0        |  76.3        |  80.0        |  76.8        |
| Min, Max                |  54  , 102   |  58  , 108   |  58  , 100   |  54  , 108   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 124          |  92          | 120          | 336          |
| Mean (SD)               |  75.4 (8.8)  |  72.7 (9.3)  |  78.5 (8.1)  |  75.8 (9.0)  |
| Median                  |  76.0        |  72.0        |  79.7        |  76.0        |
| Min, Max                |  50  , 101   |  52  , 100   |  57  , 94    |  50  , 101   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 116          |  68          |  80          | 264          |
| Mean (SD)               |  75.4 (10.7) |  74.6 (8.7)  |  74.5 (8.8)  |  74.9 (9.7)  |
| Median                  |  76.0        |  73.7        |  75.5        |  75.3        |
| Min, Max                |  50  , 98    |  59  , 94    |  50  , 90    |  50  , 98    |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       |  93          |  69          |  87          | 249          |
| Mean (SD)               |  75.1 (10.6) |  74.0 (9.6)  |  75.6 (7.8)  |  75.0 (9.4)  |
| Median                  |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max                |  58  , 104   |  52  , 94    |  57  , 90    |  52  , 104   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 132          | 164          | 148          | 444          |
| Mean (SD)               | 130.0 (16.5) | 136.1 (18.7) | 135.3 (14.4) | 134.0 (16.9) |
| Median                  | 130.3        | 134.0        | 137.2        | 132.0        |
| Min, Max                |  80  , 170   | 100  , 188   | 104  , 170   |  80  , 188   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 124          |  92          | 120          | 336          |
| Mean (SD)               | 133.7 (17.5) | 130.1 (16.9) | 131.2 (10.3) | 131.8 (15.2) |
| Median                  | 131.0        | 131.0        | 131.2        | 131.0        |
| Min, Max                |  90  , 189   |  98  , 180   | 110  , 158   |  90  , 189   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 116          |  68          |  80          | 264          |
| Mean (SD)               | 130.2 (18.6) | 129.0 (12.5) | 126.5 (12.8) | 128.8 (15.6) |
| Median                  | 130.0        | 129.7        | 126.0        | 128.0        |
| Min, Max                |  76  , 178   | 100  , 158   |  99  , 154   |  76  , 178   |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       |  93          |  69          |  87          | 249          |
| Mean (SD)               | 128.5 (14.7) | 126.8 (16.8) | 127.0 (11.6) | 127.5 (14.3) |
| Median                  | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max                |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

 

Vital signs by sex

 

For a **different `(N=)` per arm on each page** (the column headers
re-resolving per subgroup), pass `big_n` — a small table of N per page ×
arm. No bundled dataset carries per-arm-per-page counts, so build it
inline (this is also the shape `big_n` expects):

``` r

big_n <- tibble::tribble(
  ~sex, ~placebo, ~drug_50, ~drug_100, ~Total,
  "F",       53L,      55L,       35L,    143L,
  "M",       33L,      41L,       37L,    111L
)

tabular(cdisc_saf_subgroup, titles = "Vital signs by sex") |>
  cols(
    sex_n = col_spec(visible = FALSE),
    paramcd = col_spec(visible = FALSE),
    param = col_spec(usage = "group", label = "Parameter"),
    visit = col_spec(usage = "group", label = "Visit"),
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
|                         | (N=53)       | (N=55)       | (N=35)       | (N=143)      |
| **Diastolic BP (mmHg)** |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 208          | 220          | 140          | 568          |
| Mean (SD)               |  77.1 (11.2) |  76.3 (10.5) |  78.0 (10.8) |  77.0 (10.8) |
| Median                  |  78.0        |  77.3        |  78.3        |  78.0        |
| Min, Max                |  40  , 110   |  48  , 100   |  51  , 108   |  40  , 110   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 168          | 148          | 104          | 420          |
| Mean (SD)               |  75.1 (9.4)  |  77.1 (11.0) |  76.0 (10.0) |  76.0 (10.1) |
| Median                  |  76.0        |  79.7        |  78.0        |  78.0        |
| Min, Max                |  49  , 98    |  55  , 98    |  54  , 98    |  49  , 98    |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 156          | 100          |  68          | 324          |
| Mean (SD)               |  74.9 (11.1) |  75.6 (10.8) |  77.8 (8.9)  |  75.8 (10.6) |
| Median                  |  77.7        |  76.0        |  79.0        |  78.0        |
| Min, Max                |  49  , 98    |  55  , 98    |  56  , 92    |  49  , 98    |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       | 129          | 108          |  81          | 318          |
| Mean (SD)               |  74.0 (10.7) |  77.2 (11.9) |  76.5 (11.7) |  75.7 (11.5) |
| Median                  |  74.0        |  79.5        |  80.0        |  78.0        |
| Min, Max                |  49  , 100   |  50  , 100   |  56  , 98    |  49  , 100   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 208          | 220          | 140          | 568          |
| Mean (SD)               | 141.1 (16.9) | 139.2 (18.2) | 140.4 (19.5) | 140.2 (18.0) |
| Median                  | 141.8        | 140.0        | 140.0        | 140.0        |
| Min, Max                | 100  , 184   | 100  , 194   | 100  , 192   | 100  , 194   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 168          | 148          | 104          | 420          |
| Mean (SD)               | 138.1 (16.5) | 137.9 (17.8) | 139.6 (19.0) | 138.4 (17.6) |
| Median                  | 139.5        | 135.7        | 140.0        | 138.7        |
| Min, Max                | 100  , 184   |  92  , 200   |  91  , 198   |  91  , 200   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 156          | 100          |  68          | 324          |
| Mean (SD)               | 137.9 (17.4) | 134.8 (15.0) | 142.0 (15.3) | 137.8 (16.4) |
| Median                  | 139.5        | 130.5        | 140.0        | 138.0        |
| Min, Max                | 106  , 190   | 100  , 168   | 107  , 186   | 100  , 190   |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       | 129          | 108          |  81          | 318          |
| Mean (SD)               | 135.8 (15.3) | 137.0 (16.1) | 138.0 (17.4) | 136.8 (16.1) |
| Median                  | 133.0        | 133.0        | 140.0        | 136.0        |
| Min, Max                |  95  , 172   |  98  , 178   | 100  , 177   |  95  , 178   |
|                         |              |              |              |              |
| **Sex: M**              |              |              |              |              |
|                         | (N=33)       | (N=41)       | (N=37)       | (N=111)      |
| **Diastolic BP (mmHg)** |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 132          | 164          | 148          | 444          |
| Mean (SD)               |  77.1 (10.0) |  77.1 (8.8)  |  78.5 (9.8)  |  77.6 (9.5)  |
| Median                  |  76.0        |  76.3        |  80.0        |  76.8        |
| Min, Max                |  54  , 102   |  58  , 108   |  58  , 100   |  54  , 108   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 124          |  92          | 120          | 336          |
| Mean (SD)               |  75.4 (8.8)  |  72.7 (9.3)  |  78.5 (8.1)  |  75.8 (9.0)  |
| Median                  |  76.0        |  72.0        |  79.7        |  76.0        |
| Min, Max                |  50  , 101   |  52  , 100   |  57  , 94    |  50  , 101   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 116          |  68          |  80          | 264          |
| Mean (SD)               |  75.4 (10.7) |  74.6 (8.7)  |  74.5 (8.8)  |  74.9 (9.7)  |
| Median                  |  76.0        |  73.7        |  75.5        |  75.3        |
| Min, Max                |  50  , 98    |  59  , 94    |  50  , 90    |  50  , 98    |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       |  93          |  69          |  87          | 249          |
| Mean (SD)               |  75.1 (10.6) |  74.0 (9.6)  |  75.6 (7.8)  |  75.0 (9.4)  |
| Median                  |  73.0        |  74.0        |  76.0        |  74.0        |
| Min, Max                |  58  , 104   |  52  , 94    |  57  , 90    |  52  , 104   |
|                         |              |              |              |              |
| **Systolic BP (mmHg)**  |              |              |              |              |
| **Baseline**            |              |              |              |              |
| n                       | 132          | 164          | 148          | 444          |
| Mean (SD)               | 130.0 (16.5) | 136.1 (18.7) | 135.3 (14.4) | 134.0 (16.9) |
| Median                  | 130.3        | 134.0        | 137.2        | 132.0        |
| Min, Max                |  80  , 170   | 100  , 188   | 104  , 170   |  80  , 188   |
|                         |              |              |              |              |
| **Week 8**              |              |              |              |              |
| n                       | 124          |  92          | 120          | 336          |
| Mean (SD)               | 133.7 (17.5) | 130.1 (16.9) | 131.2 (10.3) | 131.8 (15.2) |
| Median                  | 131.0        | 131.0        | 131.2        | 131.0        |
| Min, Max                |  90  , 189   |  98  , 180   | 110  , 158   |  90  , 189   |
|                         |              |              |              |              |
| **Week 16**             |              |              |              |              |
| n                       | 116          |  68          |  80          | 264          |
| Mean (SD)               | 130.2 (18.6) | 129.0 (12.5) | 126.5 (12.8) | 128.8 (15.6) |
| Median                  | 130.0        | 129.7        | 126.0        | 128.0        |
| Min, Max                |  76  , 178   | 100  , 158   |  99  , 154   |  76  , 178   |
|                         |              |              |              |              |
| **End of Treatment**    |              |              |              |              |
| n                       |  93          |  69          |  87          | 249          |
| Mean (SD)               | 128.5 (14.7) | 126.8 (16.8) | 127.0 (11.6) | 127.5 (14.3) |
| Median                  | 130.0        | 124.0        | 130.0        | 130.0        |
| Min, Max                |  78  , 164   |  92  , 162   | 100  , 156   |  78  , 164   |

 

Vital signs by sex

 

`big_n` accepts this wide shape (page column + one column per arm) or a
long `count()`-style table (page, arm, n).

## Empty tables: no data to report

A table whose data has zero rows still renders — the full page chrome
and the column headers stay intact, and an empty-data placeholder takes
the place of the body. This is the correct output for a population that
produced no records (a cohort with no subjects, a serious-AE table with
no events), rather than an error or a blank page. The per-table message
is `tabular(empty_text = ...)`; set a house default for every table with
`preset(empty_text = ...)`, and place the message in the body box with
`preset(empty_halign = ..., empty_valign = ...)`.

``` r

# Same demographics shell, but the population filter has left no rows.
empty_demo <- cdisc_saf_demo[0, ]

tabular(
  empty_demo,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "No subjects met the inclusion criteria for this cohort.",
  empty_text = "No data available to report"
) |>
  cols(
    variable = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo = col_spec(label = "Placebo", align = "decimal"),
    drug_50 = col_spec(label = "Drug 50 mg", align = "decimal"),
    drug_100 = col_spec(label = "Drug 100 mg", align = "decimal"),
    Total = col_spec(align = "decimal")
  )
```

|       Characteristic        | Statistic | Placebo | Drug 50 mg | Drug 100 mg | Total |
|:---------------------------:|:---------:|:-------:|:----------:|:-----------:|:-----:|
| No data available to report |           |         |            |             |       |

No subjects met the inclusion criteria for this cohort.

 

Table 14.1.1

Demographic and Baseline Characteristics

Safety Population

 

The same applies under
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md):
a zero-N crossing is dropped by default, but
`subgroup(..., keep_empty = TRUE)` keeps it and renders its banner above
the empty-data page — so every level in the shell appears even when one
has no data.
