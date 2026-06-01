# Coming from gt, rtables, gtsummary, flextable, or huxtable

``` r

library(tabular)
#> 
#> Attaching package: 'tabular'
#> The following object is masked from 'package:stats':
#> 
#>     pt
```

R has excellent table packages. This article explains, fairly, where
`tabular` fits among them, when you would reach for something else, and
how the idioms you already know translate.

## One distinction explains most of it

Table packages split along a single axis: do they **compute** the
summary, or do they **render** a summary you bring?

- **Compute-and-render**: `gtsummary` and `rtables` take patient-level
  data, compute the statistics, *and* lay out the table.
- **Render-only**: `gt`, `flextable`, `huxtable`, and `tabular` take a
  table you have already summarised and format it.

`tabular` is firmly render-only, and specialised further: it targets
**regulatory submission output** — paginated RTF/PDF/DOCX with the
four-section page layout, decimal alignment via font metrics, and a
CDISC ARS audit trail. It does no statistics by design; you pair it with
`cards`, `gtsummary`, `dplyr`, or SAS upstream.

## Capability matrix

|  | tabular | gt | rtables | gtsummary | flextable | huxtable |
|----|:--:|:--:|:--:|:--:|:--:|:--:|
| Computes statistics | — | — | ✓ | ✓ | — | — |
| Pre-summarised input | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| Live HTML preview | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Native RTF | ✓ | ✓ | ✓ | via gt | — | ✓ |
| Native DOCX | ✓ | ✓ | ✓ | via gt | ✓ | ✓ |
| PDF | ✓ | ✓ | ✓ | via gt | ✓ | ✓ |
| LaTeX | ✓ | ✓ | ✓ | via gt | — | ✓ |
| Paginated print output | ✓ | — | ✓ | — | partial | — |
| Group-aware pagination | ✓ | — | ✓ | — | — | — |
| Decimal align via font metrics | ✓ | — | — | — | — | — |
| Four-section submission layout | ✓ | — | partial | — | — | — |
| CDISC ARS audit manifest | ✓ | — | — | — | — | — |
| No JVM / Office dependency | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| General-purpose (non-clinical) | — | ✓ | — | partial | ✓ | ✓ |

Read the bottom rows as `tabular`’s niche and the right-hand columns as
where the others are broader.

## When to reach for each

- **gtsummary** — you have patient-level data and want the package to
  *compute* the demographics/AE summary. It is the fastest path from
  ADaM to a summary, and it renders through `gt`. Use it upstream of
  `tabular`: compute with `gtsummary`/`cards`, render the result with
  `tabular` when you need submission-grade RTF and pagination.
- **rtables** — you want a powerful layout engine that *also* computes,
  with column-split logic and its own pagination. It is the closest peer
  for clinical output. Reach for `tabular` instead when you already have
  a wide summary and want native font-metric decimal alignment, the
  four-section layout, and the ARS manifest without learning a layout
  DSL.
- **gt** — best-in-class HTML/print tables for reports, papers, and
  dashboards. Unbeatable for general-purpose display tables; not built
  for paginated multi-page submission documents or decimal-metric
  alignment.
- **flextable** — the go-to for Word/PowerPoint via `officer`, with fine
  cell control. Reach for `tabular` when the target is a paginated
  submission RTF/PDF rather than an Office document.
- **huxtable** — flexible LaTeX/HTML/RTF tables for documents. `tabular`
  trades that generality for clinical-submission specialisation.

## Idiom translation

If you know one of these packages, here is the `tabular` equivalent.

| You want to… | gt | rtables | tabular |
|----|----|----|----|
| Start a table | `gt(df)` | `basic_table()` + `build_table()` | `tabular(df)` |
| Label a column | `cols_label()` | `var_labels()` | `col_spec(label =)` in [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) |
| Span columns | `tab_spanner()` | `split_cols_by()` | `headers("Band" = c(...))` |
| Row groups / sections | `tab_row_group()` | `split_rows_by()` | `col_spec(usage = "group")` |
| Sort rows | (pre-sort data) | `sort_at_path()` | `sort_rows(by =)` |
| Style cells | `tab_style()` + `cells_*()` | `cell_fmt` / formats | [`style()`](https://vthanik.github.io/tabular/reference/style.md) + `cells_*()` |
| Titles / footnotes | `tab_header()` / `tab_footnote()` | `main_title()` / `fnotes` | `titles =` / `footnotes =` |
| Save to a format | `gtsave()` | `export_as_rtf()` etc. | [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) |

The shapes rhyme deliberately: a `cells_*()` location plus a
[`style()`](https://vthanik.github.io/tabular/reference/style.md) verb
will feel familiar to a `gt` user, and `usage = "group"` plays the role
of `gt`‘s row groups or `rtables`’ row splits.

## A note on honesty

`tabular` is young and narrow. For interactive HTML tables, general
reporting, or any non-clinical table, `gt` and `flextable` are more
mature and more flexible. `tabular` earns its place only when you need a
*pre-summarised clinical table* rendered to *paginated,
submission-grade* output across all five formats with a built-in QC and
audit trail — and there it does something none of the others do end to
end.

## Where to next

- **[Get
  started](https://vthanik.github.io/tabular/articles/tabular.md)** —
  your first table.
- **[From a cards
  ARD](https://vthanik.github.io/tabular/articles/from-ard.md)** — the
  `gtsummary`/`cards` hand-off in practice.
- **[Clinical
  cookbook](https://vthanik.github.io/tabular/articles/clinical-cookbook.md)**
  — six complete tables. \`\`\`
