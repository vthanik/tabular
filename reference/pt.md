# Typed unit helpers

Tag a width or size with its unit so a style argument is unambiguous
about points versus pixels versus percent. Accepted anywhere `tabular`
takes a width or size; a bare numeric is still interpreted as points.
`pct()` expresses a proportional width (e.g. a column at 50% of the
table width).

## Usage

``` r
pt(x)

px(x)

pct(x)

is_unit(x)
```

## Arguments

- x:

  *Magnitude.* `<numeric(1)>: required`. Non-negative, finite. For
  `pct()`, a percentage in `[0, 100]`.

## Value

*A `tabular_unit` object* — a length-2 list `list(value, unit)` with
class `"tabular_unit"`.

## See also

[`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md) for
border specifications that accept these.

## Examples

``` r
# ---- Example 1: Disambiguate a rule width ----
#
# A 0.75-point hairline is unambiguous as pt(0.75); a bare 0.75
# also means points, but the typed form documents intent.
pt(0.75)
#> $value
#> [1] 0.75
#> 
#> $unit
#> [1] "pt"
#> 
#> attr(,"class")
#> [1] "tabular_unit"
px(1)
#> $value
#> [1] 1
#> 
#> $unit
#> [1] "px"
#> 
#> attr(,"class")
#> [1] "tabular_unit"
pct(50)
#> $value
#> [1] 50
#> 
#> $unit
#> [1] "pct"
#> 
#> attr(,"class")
#> [1] "tabular_unit"
```
