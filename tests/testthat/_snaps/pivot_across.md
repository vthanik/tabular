# pivot_across: per-row-group decimals with row_group = NULL errors

    Code
      pivot_across(mk_keyed_meansd(), column = "TRTA", statistic = list(continuous = "{mean} ({sd})"),
      decimals = list(SYSBP = c(mean = 0), WEIGHT = c(mean = 1)))
    Condition
      Error:
      ! `decimals` keys match no variable in `data`.
      x Names "SYSBP" and "WEIGHT" look like `row_group` values.
      i Pass `row_group` to format decimals per row group.

