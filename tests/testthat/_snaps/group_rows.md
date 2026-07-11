# group_rows() snapshot errors

    Code
      group_rows(spec, by = "nope")
    Condition
      Error:
      ! `by` references 1 column not in `data`.
      x Missing: "nope".
      i Available: "variable", "stat_label", and "placebo".

---

    Code
      group_rows(spec, by = "variable", display = "banner")
    Condition
      Error:
      ! `display` values must be one of "header_row", "column", "column_repeat", and "none".
      x You supplied: "banner".

---

    Code
      group_rows(spec, by = "variable", skip = c(TRUE, FALSE))
    Condition
      Error:
      ! `skip` must be length 1 or length 1 (= length of `by`).
      x You supplied length 2.

