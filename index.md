# tabular

**tabular** turns a pre-summarised data frame into a submission-grade
clinical table and emits it natively to **RTF, PDF, HTML, LaTeX, and
DOCX** — no Java, no LibreOffice, no Word automation. One short pipeline
gives you decimal alignment via real font metrics, multi-level column
headers, predicate-targeted styling, and group-aware pagination, built
for CDISC ADaM workflows and FDA / EMA / PMDA submissions.

It is the only R table package that pairs a **live HTML preview** with a
**paginated print deliverable**: the same spec you eyeball in a notebook
is the one that paginates into the RTF you ship.

## Installation

``` r

# install.packages("pak")
pak::pak("vthanik/tabular")
```

## A table in one pipeline

The pipeline starts from a pre-summarised wide data frame (one row in =
one display row — `tabular` does no aggregation) and chains one verb per
concern. Every verb returns an updated, immutable `tabular_spec`; the
engine resolves it at render time.

``` r

library(tabular)

# BigN denominators, keyed by arm
n <- stats::setNames(saf_n$n, saf_n$arm_short)

# columns render in data-frame order, so put them in dose order first
demo <- saf_demo[c("variable", "stat_label", "placebo", "drug_50", "drug_100", "Total")]

tab <- tabular(
  demo,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Percentages are based on the number of subjects per treatment group."
) |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo (N=%d)",  n["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50 (N=%d)",  n["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100 (N=%d)", n["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total (N=%d)",    n["Total"]),    align = "decimal")
  )

# render to any backend by file extension (or format = "...")
path <- emit(tab, tempfile(fileext = ".rtf"))   # submission deliverable
```

The same `tab` renders to markdown for a quick look (the demographics
table below is the actual `md` backend output), and to a self-contained
HTML page, a paginated PDF, a `tabularray` LaTeX fragment, or native
OOXML `.docx` — all from the one spec:

| Statistic | Placebo (N=86) | Drug 50 (N=96) | Drug 100 (N=72) | Total (N=254) |
|:---|---:|---:|---:|---:|
| **Age (years)** |   |   |   |   |
| n |  86           |  96           |  72           | 254           |
| Mean (SD) |  75.2 (8.59)  |  76.0 (8.11)  |  73.8 (7.94)  |  75.1 (8.25)  |
| Median |  76.0         |  78.0         |  75.5         |  77.0         |
| Q1, Q3 |  69.2, 81.8   |  71.0, 82.0   |  70.5, 79.0   |  70.0, 81.0   |
| Min, Max |  52  , 89     |  51  , 88     |  56  , 88     |  51  , 89     |
|   |   |   |   |   |
| **Age Group, n (%)** |   |   |   |   |
| 18-64 |  14 (16.3)    |   8 ( 8.3)    |  11 (15.3)    |  33 (13.0)    |
| \>64 |  72 (83.7)    |  88 (91.7)    |  61 (84.7)    | 221 (87.0)    |
|   |   |   |   |   |
| **Sex, n (%)** |   |   |   |   |
| F |  53 (61.6)    |  55 (57.3)    |  35 (48.6)    | 143 (56.3)    |
| M |  33 (38.4)    |  41 (42.7)    |  37 (51.4)    | 111 (43.7)    |
|   |   |   |   |   |
| **Race, n (%)** |   |   |   |   |
| WHITE |  78 (90.7)    |  90 (93.8)    |  62 (86.1)    | 230 (90.6)    |
| BLACK OR AFRICAN AMERICAN |   8 ( 9.3)    |   6 ( 6.2)    |   9 (12.5)    |  23 ( 9.1)    |
| ASIAN |   0           |   0           |   0           |   0           |
| AMERICAN INDIAN OR ALASKA NATIVE |   0           |   0           |   1 ( 1.4)    |   1 ( 0.4)    |
|   |   |   |   |   |
| **Ethnicity, n (%)** |   |   |   |   |
| HISPANIC OR LATINO |   3 ( 3.5)    |   6 ( 6.2)    |   3 ( 4.2)    |  12 ( 4.7)    |
| NOT HISPANIC OR LATINO |  83 (96.5)    |  90 (93.8)    |  69 (95.8)    | 242 (95.3)    |
| NOT REPORTED |   0           |   0           |   0           |   0           |
|   |   |   |   |   |
| **Weight (kg)** |   |   |   |   |
| n |  86           |  95           |  72           | 253           |
| Mean (SD) |  62.8 (12.77) |  68.0 (14.50) |  69.5 (14.35) |  66.6 (14.13) |
| Median |  60.6         |  66.7         |  69.0         |  66.7         |
| Q1, Q3 |  53.6, 74.2   |  56.0,  78.2  |  56.9,  80.3  |  55.3,  77.1  |
| Min, Max |  34  , 86     |  42  , 106    |  44  , 108    |  34  , 108    |
|   |   |   |   |   |
| **Height (cm)** |   |   |   |   |
| n |  86           |  96           |  72           | 254           |
| Mean (SD) | 162.6 (11.52) | 163.7 (10.30) | 165.9 (10.28) | 163.9 (10.76) |
| Median | 162.6         | 162.6         | 165.1         | 162.8         |
| Q1, Q3 | 154.0, 171.1  | 157.5, 170.2  | 157.5, 172.8  | 156.2, 171.4  |
| Min, Max | 137  , 185    | 136  , 196    | 146  , 190    | 136  , 196    |
|   |   |   |   |   |
| **BMI (kg/m^2)** |   |   |   |   |
| n |  86           |  95           |  72           | 253           |
| Mean (SD) |  23.6 (3.67)  |  25.2 (4.40)  |  25.2 (3.97)  |  24.7 (4.09)  |
| Median |  23.4         |  24.8         |  24.8         |  24.2         |
| Q1, Q3 |  21.2, 25.6   |  22.3, 28.2   |  22.7, 27.6   |  21.9, 27.3   |
| Min, Max |  15  , 33     |  15  , 40     |  14  , 35     |  14  , 40     |
|   |   |   |   |   |
| **BMI Category, n (%)** |   |   |   |   |
| Underweight (\<18.5) |   3 ( 3.5)    |   4 ( 4.2)    |   1 ( 1.4)    |   8 ( 3.1)    |
| Normal (18.5-24.9) |  57 (66.3)    |  46 (47.9)    |  39 (54.2)    | 142 (55.9)    |
| Overweight (25-29.9) |  20 (23.3)    |  32 (33.3)    |  23 (31.9)    |  75 (29.5)    |
| Obese (\>=30) |   6 ( 7.0)    |  13 (13.5)    |   9 (12.5)    |  28 (11.0)    |

## Why tabular?

- **Five native backends, one spec.**
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md)
  dispatches on the file extension to RTF 1.9.1, PDF (via `tinytex`),
  self-contained Bootstrap HTML, `tabularray` LaTeX, and native OOXML
  DOCX. No JVM, no Office round-trip.
- **Decimal alignment that survives the page.** Numbers align on the
  decimal using the backend’s real font metrics, not guessed padding —
  so columns stay aligned in print, not just on screen.
- **Submission chrome built in.** Multi-line titles, up to eleven
  footnote lines, page header/footer slots, and the four-section page
  layout regulatory reviewers expect.
- **Group-aware pagination.** Keep a SOC and its preferred terms on one
  page, repeat titles/headers/footnotes per page, control orphan/widow
  rows, and split wide tables into horizontal panels.
- **Display-only by design.** `tabular` styles and renders; it never
  filters, aggregates, or weights. Pair it with `cards` / `gtsummary` /
  `dplyr` / SAS upstream and feed it a tidy wide frame.
- **A QC trail.** `emit(data_file = ...)` writes the resolved wide data
  beside the render, and a CDISC ARS audit manifest documents the
  display.

## Where tabular fits

`tabular` is a *renderer* for pre-summarised clinical tables, not a
statistics engine. Compute the summary upstream — with `cards`,
`gtsummary`, `dplyr`, or SAS — then hand the finished wide frame to
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md).
Reach for `gtsummary` or `rtables` when you want the package to
*compute* the summary; reach for `tabular` to *render* a summary you
already have to submission-grade output.

The matrix reflects each package’s documented export surface (verified
against their namespaces; `via gt` means `gtsummary` renders through
`gt`):

|  | tabular | gt | rtables | gtsummary | flextable | huxtable |
|----|:--:|:--:|:--:|:--:|:--:|:--:|
| Computes statistics | — | — | ✓ | ✓ | — | — |
| Live HTML preview | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Native RTF | ✓ | ✓ | — | via gt | ✓ | ✓ |
| Native DOCX | ✓ | ✓ | — | via gt | ✓ | ✓ |
| LaTeX | ✓ | ✓ | — | via gt | — | ✓ |
| PDF | ✓ | ✓ | ✓ | via gt | — | ✓ |
| Paginated submission output | ✓ | — | ✓ | — | — | — |
| Decimal align via font metrics | ✓ | — | — | — | — | — |
| CDISC ARS audit manifest | ✓ | — | — | — | — | — |

## The verb surface

| Verb | Role |
|----|----|
| [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) | Wrap a pre-summarised data frame into a `tabular_spec` |
| [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md) | Bridge a `cards` long ARD into a wide display frame |
| [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) / [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md) | Per-column usage, label, format, alignment, width, visibility |
| [`headers()`](https://vthanik.github.io/tabular/reference/headers.md) | Multi-level column-header bands with passthrough leaves |
| [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md) | Output row order; factor-aware, NA-last |
| [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md) | Partition the table into page-broken, banner-labelled groups |
| [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md) | Page splits, group-keep, panels, repeat chrome, orphan/widow |
| [`style()`](https://vthanik.github.io/tabular/reference/style.md) + `cells_*()` | Predicate-targeted styling for any surface |
| [`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md) | Border-line specification (width / style / colour) |
| [`preset()`](https://vthanik.github.io/tabular/reference/preset.md) / [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md) / [`preset_minimal()`](https://vthanik.github.io/tabular/reference/preset_minimal.md) | Page geometry + cosmetic defaults |
| [`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md) | Reusable house style attached to a preset |
| [`md()`](https://vthanik.github.io/tabular/reference/md.md) / [`html()`](https://vthanik.github.io/tabular/reference/html.md) | Inline Markdown / HTML markup in labels and cells |
| [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) | Render to a file (RTF / PDF / HTML / LaTeX / DOCX) |
| [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) | Resolve to the backend-ready grid without writing a file |

## Demo data

Eleven pre-summarised datasets ship with the package to power every
example, vignette, and test (the `*_card` pair are long-format `cards`
ARDs that feed
[`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)):

| Dataset | Content |
|----|----|
| `saf_demo`, `saf_demo_card` | Demographics, Safety Population |
| `saf_aeoverall` | High-level adverse-event summary |
| `saf_aesocpt`, `saf_aesocpt_card` | Adverse events by SOC and Preferred Term |
| `saf_vital` | Vital signs by parameter and visit |
| `saf_subgroup` | Vital signs by Sex × Age-group subgroups |
| `eff_resp` | Best Overall Response and response rates |
| `eff_estimates` | Treatment-effect estimates (raw numerics) |
| `saf_n`, `eff_n` | BigN denominators per arm |

## Documentation

- [Get started](https://vthanik.github.io/tabular/articles/tabular.html)
  — your first table in ten minutes
- [Core
  concepts](https://vthanik.github.io/tabular/articles/core-concepts.html)
  — the mental model
- [Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.html)
  — six complete production tables
- [Reference](https://vthanik.github.io/tabular/reference/index.html) —
  every verb, grouped by role

## License

MIT © Vignesh Thanikachalam
