# Cell-location constructors for `style()`

Build a `tabular_location` value naming one region of the rendered
table; pass the result to
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)'s
`.at` argument. Each constructor targets one surface (body, headers,
footnotes, ...); optional `i` / `j` / `where` / `level` / `labels`
filters narrow the target within that surface.

## Usage

``` r
cells_body(i = NULL, j = NULL, where = NULL)

cells_headers(level = NULL, labels = NULL, j = NULL)

cells_group_headers(j = NULL, where = NULL)

cells_title()

cells_subgroup_labels()

cells_footnotes()

cells_pagehead(slot = NULL)

cells_pagefoot(slot = NULL)

cells_table(side = NULL, i = NULL, j = NULL)

is_tabular_location(x)
```

## Arguments

- i:

  *Row index filter.* `<integer | logical | character | NULL>`. Integer
  = 1-based row numbers; logical = length-`nrow` mask (broadcasts from
  scalar TRUE/FALSE); character = matches the visible row labels. `NULL`
  (default) = no filter (every row).

- j:

  *Column index filter.* `<integer | character | NULL>`. Integer =
  1-based column positions; character = matches column names in
  `spec@data`. `NULL` (default) = every column.

- where:

  *Predicate.* An unquoted expression evaluating to a length-`nrow`
  logical vector when run against the data grid. Captured as an rlang
  quosure (so `pvalue < 0.05` works without needing to wrap in `vars()`
  or similar). Mutually exclusive with `i`.

- level:

  *Header-band depth (for `cells_headers`).* `<integer(1) | NULL>`. `1`
  = topmost spanner band; increasing integers walk toward the leaves.
  `-1` = the leaf band (per-column labels built from `col_spec@label`).
  `NULL` (default) = every band at every depth.

- labels:

  *Header-band labels (for `cells_headers`).* `<character | NULL>`.
  Targets `header_node`(s) whose `@label` matches, at any depth.
  Mutually exclusive with `level`.

- slot:

  *Band slot (for `cells_pagehead` / `cells_pagefoot`).*
  `<character(1) | NULL>`. One of `"left"`, `"center"`, `"right"`, or
  `NULL` for every slot.

- side:

  *Table edge / separator (for `cells_table`).* `<character(1) | NULL>`.
  One of `"outer"` (all four outer edges), `"outer_top"`,
  `"outer_bottom"`, `"outer_left"`, `"outer_right"`, `"rows"`
  (horizontal separator between body rows), `"cols"` (vertical separator
  between body columns), or `NULL` for whole-body (same as
  `cells_body()`).

- x:

  *Any R object* — tested by `is_tabular_location()` for membership in
  the `tabular_location` S3 class.

## Value

*A `tabular_location` S3 list* with slots `surface`, `i`, `j`, `where`,
`labels`, `level`, `slot`, `side` (unused slots are `NULL`). Pass to
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)'s
`.at` argument.

## Details

**One surface per location.** A `tabular_location` always names exactly
one of: `body`, `headers`, `group_headers`, `title`, `subgroup_labels`,
`footnotes`, `pagehead`, `pagefoot`, `table`. Cross-surface styling
layers in via multiple chained
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
calls (one per location).

**Index vocabulary.** Where supported, the `i` (rows) and `j` (columns)
arguments accept integer, logical, or character vectors — matching the
convention established by **flextable** (`bold(ft, i, j)`) and
**tinytable** (`style_tt(i, j)`). Character vectors match against the
data frame's column names (`j`) or row labels (`i`); integers are
1-based positions; logicals broadcast to nrow / ncol.

**Predicate vocabulary.** `cells_body(where = pvalue < 0.05)` is the
canonical data-driven filter — `where` is captured as an rlang quosure
and evaluated at engine time against the post-sort grid. Mutually
exclusive with `i` (you target *either* by index *or* by predicate, not
both).

**Why `cells_headers` not `cells_column_spanners`.** The verb that
builds the multi-level header tree is named
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md).
The location follows the same vocabulary: one word ("headers") covers
the entire column-header section — inner spanner bands AND the leaf band
of per-column labels. Pass `level` or `labels` to narrow.

## Surface filters

|                                   |                                   |
|-----------------------------------|-----------------------------------|
| constructor                       | filters                           |
| `cells_body(i, j, where)`         | row index / col index / predicate |
| `cells_headers(level, labels, j)` | band depth / spanner label / cols |
| `cells_group_headers(j, where)`   | injected section rows             |
| `cells_title()`                   | (no filter — whole block)         |
| `cells_subgroup_labels()`         | (no filter)                       |
| `cells_footnotes()`               | (no filter)                       |
| `cells_pagehead(slot)`            | `"left"` / `"center"` / `"right"` |
| `cells_pagefoot(slot)`            | `"left"` / `"center"` / `"right"` |
| `cells_table(side, i, j)`         | outer edge / row separator / etc. |

## See also

**Verb that consumes locations:**
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md).

**Border value type:**
[`brdr()`](https://vthanik.github.io/tabular/dev/reference/brdr.md).

**Reusable house style:**
[`style_template()`](https://vthanik.github.io/tabular/dev/reference/style_template.md).

## Examples

``` r
# Whole body cells (the default for style())
cells_body()
#> <tabular_location: body()>

# Row index 1:3, column "Total"
cells_body(i = 1:3, j = "Total")
#> <tabular_location: body(i=1,2,3, j=Total)>

# Data-driven subset
cells_body(where = stat_label == "Mean (SD)")
#> <tabular_location: body(where=stat_label == "Mean (SD)")>

# Topmost spanner band only
cells_headers(level = 1)
#> <tabular_location: headers(level=1)>

# Leaf band (per-column labels)
cells_headers(level = -1)
#> <tabular_location: headers(level=-1)>

# A specific spanner by label
cells_headers(labels = "Treatment Group")
#> <tabular_location: headers(labels=c('Treatment Group'))>

# Section-header rows for group_rows(display = "header_row")
cells_group_headers()
#> <tabular_location: group_headers()>

# Title / footnotes blocks
cells_title()
#> <tabular_location: title()>
cells_footnotes()
#> <tabular_location: footnotes()>

# Page-header / page-footer slots
cells_pagehead(slot = "left")
#> <tabular_location: pagehead(slot='left')>
cells_pagefoot(slot = "right")
#> <tabular_location: pagefoot(slot='right')>

# Outer table frame
cells_table(side = "outer")
#> <tabular_location: table(side='outer')>

# Horizontal rules between body rows
cells_table(side = "rows")
#> <tabular_location: table(side='rows')>
```
