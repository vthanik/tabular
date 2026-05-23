# engine_derive() error snapshots

    Code
      tabular:::engine_derive(spec)
    Condition
      Error:
      ! `derive()` expression for "bad" references 1 aggregation-style symbol: "n.mean".
      x tabular does not aggregate. `col.stat` synthesis is not supported.
      i Pre-compute the statistic upstream (cards / dplyr / SAS) and pass it in as a column.

---

    Code
      tabular:::engine_derive(spec2)
    Condition
      Error:
      ! Circular dependency among `derive()` expressions.
      x Cycle involves 2 derives: "a" and "b".
      i Each expression must only reference data columns and previously-defined derives.

