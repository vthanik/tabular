# Resolve a `tabular_spec` into a `tabular_grid`

Runs the full engine pipeline against `spec` and returns the resolved
`tabular_grid` — the same intermediate object
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
hands to a backend. Pure function: no files written, no global state
touched. Use this during development to inspect what
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) will
pass downstream, when building a custom backend, or when piping the
resolved grid into a non-file consumer (e.g. an inline preview chunk in
a Quarto notebook).

## Usage

``` r
as_grid(.spec)
```

## Arguments

- .spec:

  *The `tabular_spec` to resolve.* `<tabular_spec>: required`. Built by
  the verb chain
  ([`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
  -\>
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
  -\>
  [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  -\>
  [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
  -\>
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  -\>
  [`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
  -\>
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)).

## Value

*A `tabular_grid` S7 object.* Two slots:

- `@pages` — a list of one entry per display page. Each entry is a named
  list with pagination fields (`page_index`, `panel_index`,
  `is_continuation`, `continuation`, `show_titles`, `repeat_headers`,
  `show_footnotes_here`), row + column slice indices (`row_indices`,
  `col_indices`, `col_names`), the sliced cell text (`cells_text` —
  character matrix), sliced inline ASTs (`cells_ast` — list-matrix of
  [`inline_ast`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)),
  sliced style nodes (`cells_style` — list-matrix of `style_node`), and
  the column-label ASTs for the visible columns (`col_labels_ast`).

- `@metadata` — per-table information backends consume once per render:
  `format` (the resolved backend tag, `NA_character_` for `as_grid()`
  calls), `rows_per_page`, `total_pages`, `total_panels`, `nrow_data`,
  `ncol_data`, `col_names`, `cols` (the original
  [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
  entries keyed by column name), `headers` (the flattened header band
  grid), `titles`, `footnotes`, `titles_ast`, `footnotes_ast`,
  `col_labels_ast`, `pagehead_ast` / `pagefoot_ast` (resolved page-band
  content — `NULL` when the active preset declares no band, otherwise
  `list(left, center, right)` of length-N lists of
  [`inline_ast`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
  where N = row count and index 1 is the body-edge row).

## Details

**Engine pipeline order is load-bearing.** Phases run in this fixed
order; the order matters because each phase reads the post-
previous-phase state of the spec:

1.  `engine_sort()` — apply the sort spec.

2.  `engine_headers()` — validate the header tree and flatten it to a
    band grid.

3.  `engine_style()` — evaluate every style predicate against the
    post-sort data grid. A predicate may reference any column in
    `spec@data`.

4.  `engine_format()` — apply per-column formats, substitute `na_text`,
    and parse every cell / title / footnote / label through
    `.parse_inline()` to its `inline_ast`.

5.  `engine_decimal()` — column-wide decimal alignment for any column
    flagged `col_spec(align = "decimal")`. Operates on the formatted
    text; output is the same character matrix with NBSP padding inserted
    so the decimal marks line up.

6.  `engine_paginate()` — split into pages (vertical row chunks +
    horizontal panel chunks). The plan drives the per-page slicing of
    cells / styles / ASTs below.

**The grid is the backend contract.** Every backend (`backend_md`,
future `backend_html`, etc.) consumes a `tabular_grid` — never a
`tabular_spec`. New backends only need to walk `grid@pages` and
`grid@metadata`; the engine pipeline is a fixed dependency they never
re-implement.

**No I/O.** `as_grid()` writes nothing to disk and touches no global
state. It is safe to call repeatedly during interactive exploration;
cost is roughly that of one
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
without the backend write step.

## See also

**I/O sibling:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
writes the resolved grid to a file via a registered backend; `as_grid()`
is the no-I/O entry into the same pipeline.

**Build verbs the pipeline feeds from:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).

**Inline formatting helpers:**
[`md()`](https://vthanik.github.io/tabular/dev/reference/md.md),
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).

## Examples

``` r
# ---- Example 1: Demographics — inspect the resolved grid ----
#
# Resolve the canonical safety-pop demographics pipeline into a
# `tabular_grid` and inspect what `emit()` would hand a backend.
# The first page's `cells_text` matrix is the decimal-aligned
# output as the backend would render it; the metadata carries the
# pagination plan + header / title / footnote ASTs.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

demo <- tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Source: ADSL."
) |>
  cols(
    variable   = col_spec(label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  ) |>
  group_rows(by = "variable") |>
  sort_rows(by = c("variable", "stat_label"))

demo_grid <- as_grid(demo)
demo_grid@metadata$total_pages
#> [1] 1
demo_grid@pages[[1]]$cells_text[1:3, c("stat_label", "placebo")]
#>      stat_label    placebo      
#> [1,] "Age (years)" ""           
#> [2,] "  Mean (SD)" "75.2 (8.59)"
#> [3,] "  Median"    "76.0       "

# ---- Example 2: AE-by-SOC/PT paginated grid — verify the split ----
#
# Same shape as Example 1 plus pagination protecting the SOC
# grouping. With a tight font size the grid carries multiple page
# entries; concatenating each page's `row_indices` reconstructs
# the full data, and every page carries the full header band grid
# at `grid@metadata$headers` so backends can re-render the header
# on every continuation page.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

ae_spec <- tabular(
  cdisc_saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    .hide    = c("soc", "row_type", "soc_n", "n_total"),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  ) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE)) |>
  paginate(keep_together = "soc")

ae_grid <- as_grid(ae_spec)
length(ae_grid@pages)
#> [1] 3

# ---- Example 3: Subgroup partition — one page set per group ----
#
# When `subgroup()` is attached, `as_grid()` runs the resolve
# pipeline once per group and concatenates the pages. `cdisc_saf_subgroup`
# carries `sex` as a natural partition axis; inspect
# `@pages[[i]]$subgroup_index` and `@pages[[i]]$subgroup_line_ast`
# to confirm each page knows its group identity and banner text.
# `sex` auto-hides as the partition `by` column; no explicit
# `col_spec(visible = FALSE)` needed.
sg_spec <- tabular(cdisc_saf_subgroup) |>
  cols(
    sex_n      = col_spec(visible = FALSE),
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(label = "Parameter"),
    visit      = col_spec(label = "Visit"),
    stat_label = col_spec(label = "Statistic")
  ) |>
  group_rows(by = c("param", "visit")) |>
  subgroup("sex")

sg_grid <- as_grid(sg_spec)
length(sg_grid@pages)
#> [1] 2
vapply(
  sg_grid@pages,
  function(p) if (is.null(p$subgroup_index)) NA_integer_ else p$subgroup_index,
  integer(1)
)
#> [1] 1 2

# ---- Example 4: Pre-flight inspection before emit() ----
#
# Resolve a spec to its grid without writing anywhere. Useful in
# tests, for snapshotting cell text under different presets, or
# for spec-introspection inside higher-level wrappers that need
# to know how many pages a render will produce.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
demog_spec <- tabular(
  cdisc_saf_demo,
  titles = "Demographics"
) |>
  cols(
    variable   = col_spec(label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(
      label = "Placebo\nN={n['placebo']}",
      align = "decimal"
    ),
    drug_50    = col_spec(
      label = "Drug 50\nN={n['drug_50']}",
      align = "decimal"
    ),
    drug_100   = col_spec(
      label = "Drug 100\nN={n['drug_100']}",
      align = "decimal"
    ),
    Total      = col_spec(
      label = "Total\nN={n['Total']}",
      align = "decimal"
    )
  )
grid <- as_grid(demog_spec)
length(grid@pages)
#> [1] 1
dim(grid@pages[[1]]$cells_text)
#> [1] 11  6
```
