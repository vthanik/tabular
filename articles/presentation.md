# Presentation: titles, footnotes, page chrome, and styling

This article is about the *look* — titles, footnotes, the running page
header / footer, and cell styling. It assumes the table’s shape is
already built (see
[Structure](https://vthanik.github.io/tabular/articles/structure.md))
and never explains data prep or pagination for its own sake.

## Titles and footnotes

Multi-line titles and static footnotes are arguments to
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md):

``` r

tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14-2.01",
    "Demographic and Baseline Characteristics",
    "ITT Population"
  ),
  footnotes = c(
    "Percentages are based on the number of ITT subjects per arm.",
    "BMI = body mass index."
  )
) |>
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

Percentages are based on the number of ITT subjects per arm.

BMI = body mass index.

 

Table 14-2.01

Demographic and Baseline Characteristics

ITT Population

 

For an **anchored** footnote (an auto-numbered superscript on a specific
cell or header) use
[`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md)
with a `cells_*()` location:

``` r

base |>
  footnote(
    "Excludes one subject withdrawn before dosing.",
    .at = cells_headers(j = "Total")
  )
```

|  | placebo | drug_50 | drug_100 | Total^(a) |
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

a Excludes one subject withdrawn before dosing.

## The running page header / footer

Regulatory TFLs carry a header on every page (protocol, page X of Y,
data-cut). That is preset page chrome, not a title. `pagehead` /
`pagefoot` each take `left` / `right` (and `center`) vectors; the tokens
`{page}`, `{npages}`, `{program}`, `{datetime}` resolve at render time:

``` r

chrome <- base |>
  preset(
    pagehead = list(
      left = c("Analysis Set: Safety", "Protocol: XYZ-123"),
      right = c("Data cut: 2026-01-15", "Page {page} of {npages}")
    )
  )
chrome
```

Protocol: XYZ-123\
Analysis Set: Safety

Page 1 of 1\
Data cut: 2026-01-15

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

The running header/footer is page chrome — it repeats on every page of
the **paged backends** (RTF, PDF, DOCX) and does not appear in the
single-page HTML preview above. Emit to a paged backend to see it:

``` r

emit(chrome, "demographics.pdf") # protocol + page x of y on every page
```

> **Stacking direction.** Each vector stacks **outward from the table**:
> index 1 is the line nearest the table body, later elements move toward
> the page edge. For a header that reads “Analysis Set” on top and
> “Protocol” just above the table, put `"Protocol…"` first. (Easy to
> invert — check the rendered page.)

## Cell styling

[`style()`](https://vthanik.github.io/tabular/reference/style.md)
appends one location + attribute layer. Target a region with a
`cells_*()` constructor; attributes include `bold`, `italic`,
`underline`, `color`, `background`, and borders via
[`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md):

``` r

base |>
  # the column-header band is bold by default, so style it with colour /
  # background for a visible change rather than re-applying bold
  style(color = "#1F3B5C", background = "#DBE4F0", .at = cells_headers()) |>
  style(italic = TRUE, .at = cells_group_headers()) |> # italic section rows
  style(background = "#F2F2F2", .at = cells_body(j = "Total")) # shade the Total column
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

Body filters live on
[`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md):
`i =` (row index), `j =` (column name), `where =` (an expression over
the data).

## Presets: cosmetics and fit

[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
carries the cosmetic defaults — fonts, rules, padding, `na_text`,
paper/orientation/margins — and the **`width_mode`** that decides how
the table fills the page:

| `width_mode` | Effect |
|----|----|
| `"content"` *(default)* | columns sized to their content |
| `"window"` | `"auto"` columns **stretch to fill** the printable width (Word “Auto-fit Window”) |
| `"fixed"` | only the widths you pin are used |

``` r

base |>
  preset(
    font_size = 9,
    orientation = "landscape",
    paper_size = "letter",
    margins = c(1, 0.75, 1, 0.75),
    width_mode = "window",
    na_text = "-"
  )
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

Use
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
once at the top of a study to make these defaults apply to every table
without restating them.

> **Decimal alignment** (`col_spec(align = "decimal")`) pads numeric
> cells with non-breaking spaces so the decimal points line up. Padding
> is measured with the built-in font metrics
> (`preset(decimal_metrics = "afm")`, the default), so alignment is
> exact in Courier and exact to within one padding space in proportional
> fonts such as Times New Roman or Arial. Markdown output pads by
> character count instead — the right geometry for a text medium.
