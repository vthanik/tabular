

<!-- README.md is generated from README.qmd. Please edit that file -->

# tabular

<!-- badges: start -->

[![R-CMD-check](https://github.com/vthanik/tabular/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/vthanik/tabular/actions/workflows/R-CMD-check.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Native emission of clinical tables, figures, and listings to RTF, LaTeX,
HTML, PDF, and DOCX from a single dplyr-style API. Designed for CDISC
ADaM workflows and FDA / EMA regulatory submissions.

`tabular` replaces the `tfrmt` + `r2rtf` + `flextable` + `gt`
stitched-together stack with one package per format – decimal alignment,
group-aware pagination, page-field tokens, and inline markup that
survives string operations all handled natively.

## Installation

You can install the development version of tabular from GitHub:

``` r
# install.packages("pak")
pak::pak("vthanik/tabular")
```

## Status

`tabular` is in **pre-CRAN** development. The package skeleton, S7
classes, and bundled demo datasets are in place; backends land
incrementally per `plan.md`. Break-anything-anytime until v0.1.0.

## Example – 95% case (planned)

Pre-summarised wide data flows through five verbs to a regulatory
submission file:

``` r
library(tabular)

saf_demo |>
  tb_table(
    titles    = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Percentages based on N per treatment group."
  ) |>
  tb_cols(
    labels  = c(stat_label = "", placebo = "Placebo",
                drug_50 = "Drug 50mg", drug_100 = "Drug 100mg",
                Total = "Total"),
    align   = c(stat_label = "left", "*" = "decimal"),
    visible = c(variable = FALSE),
    n       = attr(saf_demo, "n")
  ) |>
  tb_rows(group_by = "variable", indent_by = "stat_label") |>
  tb_render("t_14_1_1.rtf")
```

## Demo datasets

Five pre-summarised wide-format tables ship with the package to power
examples, vignettes, and tests:

``` r
library(tabular)
head(saf_demo)
attr(saf_demo, "n")
```

| Dataset         | Content                                    |
|-----------------|--------------------------------------------|
| `saf_demo`      | Demographics, Safety Population            |
| `saf_aeoverall` | High-level AE flags                        |
| `saf_aesocpt`   | AEs by SOC and PT                          |
| `saf_vital`     | Vital signs at Baseline / End of Treatment |
| `eff_resp`      | Best Overall Response + ORR / DCR          |
