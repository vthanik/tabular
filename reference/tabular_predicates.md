# Test for tabular S7 class instances

Class predicates returning a single logical indicating whether `x`
inherits from the corresponding tabular S7 class. Use them to gate
user-side code that branches on what a verb has returned, to write
defensive helpers that wrap tabular pipelines, or to assert intermediate
shapes during pipeline debugging.

## Usage

``` r
is_tabular_spec(x)

is_figure_spec(x)

is_tabular_grid(x)

is_col_spec(x)

is_header_node(x)

is_sort_spec(x)

is_row_group_spec(x)

is_style_node(x)

is_style_layer(x)

is_style_spec(x)

is_pagination_spec(x)

is_preset_spec(x)

is_subgroup_spec(x)

is_inline_ast(x)
```

## Arguments

- x:

  *Object to test.* Any R value. Each predicate returns `TRUE` if `x`
  inherits from the named class, `FALSE` otherwise.

## Value

*A single `TRUE` / `FALSE`.* Use in `if` / `stopifnot` guards, or chain
into validation helpers.

*A length-1 `logical`* — `TRUE` or `FALSE`. Never `NA`.

## Details

Twelve predicates cover the full S7 surface:

|  |  |  |
|----|----|----|
| predicate | tests for | produced by |
| `is_tabular_spec()` | `tabular_spec` | [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md) and every build verb |
| `is_tabular_grid()` | `tabular_grid` | [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md) |
| `is_col_spec()` | `col_spec` | [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md) |
| `is_header_node()` | `header_node` | [`headers()`](https://vthanik.github.io/tabular/reference/headers.md) (internal nodes) |
| `is_sort_spec()` | `sort_spec` | [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md) |
| `is_style_node()` | `style_node` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (per-cell style) |
| `is_style_layer()` | `style_layer` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (one per call) |
| `is_style_spec()` | `style_spec` | [`style()`](https://vthanik.github.io/tabular/reference/style.md) (the cascade root) |
| `is_pagination_spec()` | `pagination_spec` | [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md) |
| `is_preset_spec()` | `preset_spec` | [`preset()`](https://vthanik.github.io/tabular/reference/preset.md), [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md) |
| `is_subgroup_spec()` | `subgroup_spec` | [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md) |
| `is_inline_ast()` | `inline_ast` | `.parse_inline()` (post-format) |

Predicates never error — they return `FALSE` for `NULL`, vectors,
objects of any other class, and S7 objects from other packages. Use them
at any layer of a user's pipeline without a defensive
[`tryCatch()`](https://rdrr.io/r/base/conditions.html).

## See also

**Class definitions:**
[`tabular_classes`](https://vthanik.github.io/tabular/reference/tabular_classes.md).

**Verbs producing each class:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Gate user-side code on the spec class ----
#
# A user-side helper that pre-validates its input before piping
# into a downstream tabular chain. The predicate returns FALSE
# for any non-spec input without raising, so the helper can emit
# a friendlier error than tabular's own S7 validator would.
add_safety_footnote <- function(spec) {
  if (!is_tabular_spec(spec)) {
    stop("`spec` must be a tabular_spec; build one with tabular().")
  }
  spec
}

demo <- tabular(cdisc_saf_demo, titles = "Demographics")
is_tabular_spec(demo)         # TRUE
#> [1] TRUE
is_tabular_spec("not a spec") # FALSE — does not raise
#> [1] FALSE
add_safety_footnote(demo)

#tabular-763eb95427 { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-763eb95427 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-763eb95427 p { line-height: inherit; }
#tabular-763eb95427 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-763eb95427 .tabular-caption { margin: 0; padding: 0; }
#tabular-763eb95427 .tabular-pad { margin: 0; line-height: 1; }
#tabular-763eb95427 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-763eb95427 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-763eb95427 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-763eb95427 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-763eb95427 .tabular-table th, #tabular-763eb95427 .tabular-table td { padding: .18rem .6rem; }
#tabular-763eb95427 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-763eb95427 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-763eb95427 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-763eb95427 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-763eb95427 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-763eb95427 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-763eb95427 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-763eb95427 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-763eb95427 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-763eb95427 .tabular-table tbody tr td { border-top: none; }
#tabular-763eb95427 .tabular-band { text-align: center; }
#tabular-763eb95427 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-763eb95427 .tabular-subgroup-label { font-weight: 600; }
#tabular-763eb95427 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-763eb95427 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-763eb95427 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-763eb95427 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-763eb95427 .text-left { text-align: left; }
#tabular-763eb95427 .text-center { text-align: center; }
#tabular-763eb95427 .text-right { text-align: right; }
#tabular-763eb95427 .tabular-table thead th.text-left { text-align: left; }
#tabular-763eb95427 .tabular-table thead th.text-center { text-align: center; }
#tabular-763eb95427 .tabular-table thead th.text-right { text-align: right; }
#tabular-763eb95427 .tabular-table td.text-left { text-align: left; }
#tabular-763eb95427 .tabular-table td.text-center { text-align: center; }
#tabular-763eb95427 .tabular-table td.text-right { text-align: right; }
#tabular-763eb95427 .valign-top { vertical-align: top; }
#tabular-763eb95427 .valign-middle { vertical-align: middle; }
#tabular-763eb95427 .valign-bottom { vertical-align: bottom; }
#tabular-763eb95427 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-763eb95427 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-763eb95427 .tabular-page-break-row { display: none; }
#tabular-763eb95427 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-763eb95427 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-763eb95427 .tabular-page-header, #tabular-763eb95427 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-763eb95427 .tabular-page-header { margin-bottom: 1rem; }
#tabular-763eb95427 .tabular-page-footer { margin-top: 1rem; }
#tabular-763eb95427 .tabular-page-header-left, #tabular-763eb95427 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-763eb95427 .tabular-page-header-center, #tabular-763eb95427 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-763eb95427 .tabular-page-header-right, #tabular-763eb95427 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-763eb95427 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-763eb95427 .tabular-table tr { page-break-inside: avoid; } #tabular-763eb95427 .tabular-page-header, #tabular-763eb95427 .tabular-page-footer { display: none; } #tabular-763eb95427 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-763eb95427 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-763eb95427 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Demographics
 



variable
```
