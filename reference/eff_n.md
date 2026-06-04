# Efficacy-population BigN per arm

Per-arm subject counts (BigN) for the efficacy population used by
`eff_resp` / `eff_resp_card` — subjects with a `BOR` record in
`pharmaverseadam::adrs_onco`. Same two-column naming convention as
`saf_n`; the totals differ from `saf_n` because not every safety-pop
subject contributes a best-overall-response record.

## Usage

``` r
eff_n
```

## Format

A data frame with 4 rows and 3 columns; same schema as
[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) (`arm`,
`arm_short`, `n`).

## Source

Derived in `data-raw/bundle-demo.R` from the per-arm BOR denominator
computed inside the `eff_resp` pipeline.

## See also

[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for the
safety-population counterpart.

## Examples

``` r
# Efficacy BigN joined into column headers.
ne <- stats::setNames(eff_n$n, eff_n$arm_short)
col_spec(label = "Placebo\nN={ne['placebo']}")@label
#> [1] "Placebo\nN=86"
```
