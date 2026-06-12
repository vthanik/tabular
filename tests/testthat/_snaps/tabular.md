# tabular(empty_text=) rejects non-scalar / NA / empty

    Code
      tabular(df, empty_text = "")
    Condition
      Error:
      ! `empty_text` must be a single non-empty string.
      x You supplied `""`.

