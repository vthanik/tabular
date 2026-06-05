# data-raw/

Source scripts for the five lazy-loaded demo datasets in `data/`:

- `cdisc_saf_demo` — Demographics, Safety Population
- `cdisc_saf_ae` — High-level AE summary
- `cdisc_saf_aesocpt` — AEs by SOC and PT
- `cdisc_saf_vital` — Vital-signs summary
- `cdisc_eff_resp` — Best Overall Response + ORR / DCR

## Build

```bash
Rscript data-raw/bundle-demo.R
```

This regenerates all five `.rda` files from `pharmaverseadam` source
datasets, applying the per-dataset summarisation logic defined inline in
`bundle-demo.R`.

## Build-time dependencies

Used only by `bundle-demo.R` (the package itself does **not** depend on these):

```r
install.packages(c("pharmaverseadam", "dplyr", "tidyr", "tibble",
                   "usethis", "devtools"))
```

## Conventions

- Arm columns renamed at the end via `arm_rename`:
  `Placebo` → `placebo`, `Xanomeline Low Dose` → `drug_50`,
  `Xanomeline High Dose` → `drug_100`.
- Per-dataset BigN attached via `attr(<dataset>, "n")` as a named
  integer vector (named by the same arm conventions plus `Total`).
- Each `.rda` capped at 50 KB by the size guard at the bottom of
  `bundle-demo.R`. If size grows, trim rows (e.g. top-N SOCs in
  `cdisc_saf_aesocpt`) rather than columns.
- Values are illustrative — they're derived from `pharmaverseadam`'s
  synthetic CDISC Pilot 03 dataset, not real subjects.

## Why a build script (vs. hand-coded `data.frame()` literals)

Reproducibility. If pharmaverseadam updates, or we tweak filter
criteria / stat formats, we rebuild — we don't hand-update cell
values. Matches the herald `bundle-pilot.R` pattern.
