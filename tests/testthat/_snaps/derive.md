# derive() error snapshots

    Code
      derive(tabular(saf_demo), variable = 1)
    Condition
      Error:
      ! `derive()` cannot overwrite 1 existing data column.
      x Conflicting: "variable".
      i Pick a new name, or rename the input column upstream.

---

    Code
      derive(tabular(saf_demo), x = 1, x = 2)
    Condition
      Error:
      ! 1 duplicate name in a single `derive()` call.
      x Repeated: "x".
      i Use one entry per output column, or chain a second `derive()` call.

