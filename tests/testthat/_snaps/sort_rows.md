# sort_rows() error snapshots

    Code
      sort_rows(tabular(saf_demo), by = "no_such_col")
    Condition
      Error:
      ! `by` references 1 column not in `data`.
      x Missing: "no_such_col".
      i Available: "variable", "stat_label", "placebo", "drug_100", "drug_50", and "Total".

---

    Code
      sort_rows(tabular(saf_demo), by = c("variable", "stat_label"), descending = c(
        TRUE, FALSE, TRUE))
    Condition
      Error:
      ! `descending` must be length 1 or length 2 (= length of `by`).
      x You supplied length 3.

