# Architecture

``` r

library(tabular)
#> 
#> Attaching package: 'tabular'
#> The following object is masked from 'package:stats':
#> 
#>     pt
```

`tabular` is a three-phase pipeline. Understanding the phases explains
why the API is shaped the way it is and where to look when something
does not render as expected.

![Pre-summarised data flows through Build, Resolve, and Emit to five
output formats](../reference/figures/workflow.svg)

Build the spec, resolve it to a grid, emit to any backend.

## Phase 1 — Build

The verbs
([`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md))
accumulate an **immutable** `tabular_spec`, an S7 object. Each verb
validates its arguments, constructs one new property value, and returns
a new spec with that property updated. Nothing is rendered.

``` r

sp <- tabular(saf_demo) |>
  cols(
    variable   = col_spec(usage = "group"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(align = "decimal"),
    drug_50    = col_spec(align = "decimal"),
    drug_100   = col_spec(align = "decimal"),
    Total      = col_spec(align = "decimal")
  )

is_tabular_spec(sp)
#> [1] TRUE
```

Because specs are immutable, the same base can branch into many variants
without interference, and a spec can be inspected at any point in the
pipe with [`print()`](https://rdrr.io/r/base/print.html).

## Phase 2 — Resolve

The engine turns a spec into a `tabular_grid` by running six phases in a
fixed order:

1.  **sort** — apply the
    [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
    order (factor-aware, NA-last).
2.  **headers** — validate and flatten the header tree into bands.
3.  **style** — resolve
    [`style()`](https://vthanik.github.io/tabular/reference/style.md)
    layers and predicates to per-cell nodes.
4.  **format** — apply per-column formatters, NA substitution, and parse
    [`md()`](https://vthanik.github.io/tabular/reference/md.md) /
    [`html()`](https://vthanik.github.io/tabular/reference/html.md)
    inline markup.
5.  **decimal** — pad `align = "decimal"` columns using real font
    metrics.
6.  **paginate** — split the rows (and panels) into pages per the active
    preset’s geometry.

The result is backend-agnostic: only the next phase differs per format.
Inspect the resolved grid without writing a file using
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md):

``` r

g <- as_grid(sp)
is_tabular_grid(g)
#> [1] TRUE
```

> **One Resolve, five Emits**
>
> The HTML you preview and the RTF you ship come from the *same*
> resolved grid. The numbers, structure, alignment, and pagination are
> decided once in Resolve; a backend only serialises them. That is why
> preview and deliverable cannot disagree.

## Phase 3 — Emit

[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) runs
Resolve, then dispatches to a backend by the file’s extension (or an
explicit `format =`):

| Extension | Backend | Notes |
|----|----|----|
| `.md`, `.markdown` | GFM pipe table | quick look; renders on GitHub |
| `.html`, `.htm` | self-contained Bootstrap HTML | the live preview |
| `.rtf` | RTF 1.9.1 (native) | submission deliverable |
| `.tex`, `.latex` | `tabularray` LaTeX | fragment or standalone |
| `.pdf` | PDF via `tinytex` | paginated print |
| `.docx` | native OOXML | no Word automation |

``` r

emit(sp, "table.rtf")                 # by extension
emit(sp, "table.out", format = "docx") # or force the format
```

## QC and audit artefacts

[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) can drop
two by-products alongside the render, for traceability:

- **`data_file`** — writes the *resolved* wide data frame (post-engine)
  next to the render, so QC can diff the numbers that were actually
  displayed. Pass a path or a function that returns one.
- **`manifest = TRUE`** — writes a CDISC ARS audit manifest describing
  the display, using the LinkML property names from the ARS logical data
  model.

``` r

emit(
  sp,
  "t_14_1_1.rtf",
  data_file = "t_14_1_1_qc.csv",   # resolved data for QC
  manifest  = TRUE                  # t_14_1_1.audit.yml
)
```

> **The package boundary**
>
> `tabular` owns *display* only — resolve and emit. It never filters,
> aggregates, weights, or inserts rows. That boundary is deliberate: it
> keeps the spec a faithful description of what you handed in, which is
> exactly what the QC `data_file` and the ARS manifest document.

## Where to next

- **[Fonts &
  fidelity](https://vthanik.github.io/tabular/articles/fonts-and-fidelity.md)**
  — the metrics the decimal phase relies on.
- **[Comparison](https://vthanik.github.io/tabular/articles/comparison.md)**
  — how this architecture differs from the all-in-one table packages.
  \`\`\`
