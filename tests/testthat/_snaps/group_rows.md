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
      group_rows(spec, by = "variable", display = "none")
    Condition
      Error:
      ! `display` must be one of "header_row", "column", and "column_repeat".
      x You supplied "none".
      i For a hidden break-only key use `col_spec(visible = FALSE)`.

---

    Code
      group_rows(spec, by = "variable", skip = "stat_label")
    Condition
      Error:
      ! `skip` must name columns listed in `by`.
      x Not in `by`: "stat_label".
      i Grouping keys: "variable".

