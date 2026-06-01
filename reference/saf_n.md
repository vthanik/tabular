# Safety-population BigN per arm

Per-arm subject counts (BigN) for the safety population, plus a `Total`
row. Use this table to embed BigN inline in column headers via
[`sprintf()`](https://rdrr.io/r/base/sprintf.html) /
[`paste()`](https://rdrr.io/r/base/paste.html) against
`cols(col_spec(label = ...))`; there is no dedicated BigN field on
`col_spec` because the denominator already lives here in a discoverable,
joinable form.

## Usage

``` r
saf_n
```

## Format

A data frame with 4 rows and 3 columns:

- `arm`:

  Raw pharmaverseadam arm label (`"Placebo"`, `"Xanomeline Low Dose"`,
  `"Xanomeline High Dose"`, `"Total"`). Matches `group1_level` in the
  `_card` ARDs (so the pivot output's column names match a
  `setNames(saf_n$n, saf_n$arm)` lookup).

- `arm_short`:

  Renamed label (`"placebo"`, `"drug_50"`, `"drug_100"`, `"Total"`).
  Matches the column names of `saf_demo`, `saf_aeoverall`,
  `saf_aesocpt`, and `saf_vital`.

- `n`:

  Integer subject count.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adsl`](https://pharmaverse.github.io/pharmaverseadam/reference/adsl.html)
filtered to `SAFFL == "Y"` and the three CDISCPILOT01 arms.

## Details

Two arm-naming columns are shipped side by side so the same table can
serve both the `_card` ARDs (raw pharmaverseadam labels in
`group1_level`) and the renamed wide datasets (snake-cased arm column
names).

## See also

[eff_n](https://vthanik.github.io/tabular/reference/eff_n.md) for the
efficacy-population counterpart.

## Examples

``` r
# Use saf_n$arm_short when joining into the wide datasets
# (saf_demo, saf_aeoverall, saf_aesocpt, saf_vital).
n <- stats::setNames(saf_n$n, saf_n$arm_short)
sprintf("Placebo\nN=%d", n["placebo"])
#> [1] "Placebo\nN=86"

# Use saf_n$arm when joining into pivot_across() output
# (column names match the raw pharmaverseadam arm labels).
n_arm <- stats::setNames(saf_n$n, saf_n$arm)
sprintf("Placebo\nN=%d", n_arm["Placebo"])
#> [1] "Placebo\nN=86"
```
