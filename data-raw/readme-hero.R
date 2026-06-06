# Regenerate `man/figures/README-hero.png` — the home-page hero image.
#
# A static PNG of tabular's live HTML preview (the gt / flextable model), so
# the README renders an identical, centred, decimal-aligned table on GitHub
# and on the pkgdown site. Run locally (needs `webshot2` + a headless Chrome);
# the resulting PNG is committed to the repo.
#
#   Rscript data-raw/readme-hero.R

library(tabular)

# Same pipeline as the README "A table in one pipeline" chunk.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
# cdisc_saf_demo is already the Age / Sex / Race bare-minimum set; take
# all of it (the explicit column order keeps placebo, drug_50, drug_100,
# Total dose-ascending).
demo <- cdisc_saf_demo[
  ,
  c("variable", "stat_label", "placebo", "drug_50", "drug_100", "Total")
]

tab <- tabular(
  demo,
  titles = c(
    "Table 14.1.1",
    "Demographic and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Percentages are based on the number of subjects per treatment group."
) |>
  cols(
    variable = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo = col_spec(
      label = sprintf("Placebo (N=%d)", n["placebo"]),
      align = "decimal"
    ),
    drug_50 = col_spec(
      label = sprintf("Drug 50 (N=%d)", n["drug_50"]),
      align = "decimal"
    ),
    drug_100 = col_spec(
      label = sprintf("Drug 100 (N=%d)", n["drug_100"]),
      align = "decimal"
    ),
    Total = col_spec(
      label = sprintf("Total (N=%d)", n["Total"]),
      align = "decimal"
    )
  )

# Emit a standalone HTML page, then screenshot just the table `<figure>` at
# zoom = 2 (retina) for a crisp, tightly cropped PNG.
html <- tempfile(fileext = ".html")
emit(tab, html)

webshot2::webshot(
  url = paste0("file://", normalizePath(html)),
  file = "man/figures/README-hero.png",
  selector = "figure.tabular-content",
  zoom = 2
)

message("Wrote man/figures/README-hero.png")
