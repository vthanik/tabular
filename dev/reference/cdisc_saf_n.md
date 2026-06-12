# Safety-population BigN per arm

Per-arm subject counts (BigN) for the safety population, plus a `Total`
row. Use this table to embed BigN inline in column headers with a
glue-style `{expr}` template against `cols(col_spec(label = ...))`;
there is no dedicated BigN field on `col_spec` because the denominator
already lives here in a discoverable, joinable form.

## Usage

``` r
cdisc_saf_n
```

## Format

A data frame with 4 rows and 3 columns:

- `arm`:

  Raw pharmaverseadam arm label (`"Placebo"`, `"Xanomeline Low Dose"`,
  `"Xanomeline High Dose"`, `"Total"`). Matches `group1_level` in the
  `_card` ARDs (so the pivot output's column names match a
  `setNames(cdisc_saf_n$n, cdisc_saf_n$arm)` lookup).

- `arm_short`:

  Renamed label (`"placebo"`, `"drug_50"`, `"drug_100"`, `"Total"`).
  Matches the column names of `cdisc_saf_demo`, `cdisc_saf_ae`,
  `cdisc_saf_aesocpt`, and `cdisc_saf_vital`.

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

[cdisc_eff_n](https://vthanik.github.io/tabular/dev/reference/cdisc_eff_n.md)
for the efficacy-population counterpart.

## Examples

``` r
# Use cdisc_saf_n$arm_short when joining into the wide datasets
# (cdisc_saf_demo, cdisc_saf_ae, cdisc_saf_aesocpt, cdisc_saf_vital).
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
col_spec(label = "Placebo\nN={n['placebo']}")@label
#> [1] "Placebo\nN=86"

# Use cdisc_saf_n$arm when joining into pivot_across() output
# (column names match the raw pharmaverseadam arm labels).
n_arm <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm)
col_spec(label = "Placebo\nN={n_arm['Placebo']}")@label
#> [1] "Placebo\nN=86"
```
