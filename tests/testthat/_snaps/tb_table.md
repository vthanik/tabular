# tb_table() rejects non-data-frame data

    Code
      tb_table(list(a = 1, b = 2))
    Condition
      Error:
      ! `data` must be a data frame.
      x You supplied a list.

