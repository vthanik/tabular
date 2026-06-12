# Efficacy-population BigN per arm

Per-arm subject counts (BigN) for the efficacy population used by
`cdisc_eff_resp` / `eff_resp_card` — subjects with a `BOR` record in
[`pharmaverseadam::adrs_onco`](https://pharmaverse.github.io/pharmaverseadam/reference/adrs_onco.html).
Same two-column naming convention as `cdisc_saf_n`; the totals differ
from `cdisc_saf_n` because not every safety-pop subject contributes a
best-overall-response record.

## Usage

``` r
cdisc_eff_n
```

## Format

A data frame with 4 rows and 3 columns; same schema as
[cdisc_saf_n](https://vthanik.github.io/tabular/dev/reference/cdisc_saf_n.md)
(`arm`, `arm_short`, `n`).

## Source

Derived in `data-raw/bundle-demo.R` from the per-arm BOR denominator
computed inside the `cdisc_eff_resp` pipeline.

## See also

[cdisc_saf_n](https://vthanik.github.io/tabular/dev/reference/cdisc_saf_n.md)
for the safety-population counterpart.

## Examples

``` r
# Efficacy BigN joined into column headers.
ne <- stats::setNames(cdisc_eff_n$n, cdisc_eff_n$arm_short)
col_spec(label = "Placebo\nN={ne['placebo']}")@label
#> [1] "Placebo\nN=86"
```
