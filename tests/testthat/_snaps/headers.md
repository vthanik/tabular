# headers() error snapshots

    Code
      headers(tabular(cdisc_saf_demo), Arms = c("placebo", "phantom_arm"))
    Condition
      Error:
      ! `headers()` references 1 column not in `data`.
      x Missing: "phantom_arm".
      i Available: "variable", "stat_label", "placebo", "drug_50", "drug_100", and "Total".

---

    Code
      headers(tabular(cdisc_saf_demo), `Arms 1` = c("placebo", "drug_50"), `Arms 2` = c(
        "drug_50", "drug_100"))
    Condition
      Error:
      ! `headers()` places 1 column under more than one band.
      x Conflicting: "drug_50".
      i Each column may appear under at most one leaf band.

