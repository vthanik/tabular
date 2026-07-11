# paginate() snapshot errors

    Code
      paginate(spec, keep_together = "nope")
    Condition
      Error:
      ! `keep_together` references 1 column not in `data`.
      x Missing: "nope".
      i Available: "soc" and "val".

---

    Code
      paginate(spec, panels = "weird")
    Condition
      Error:
      ! `panels` must be a positive whole number.
      x You supplied a string.

---

    Code
      paginate(spec, continuation = c("a", "b"))
    Condition
      Error:
      ! `continuation` must be a single character string or `NULL`.
      x You supplied a character vector of length 2.

# paginate() rejects repeat_cols not in data

    Code
      paginate(spec, repeat_cols = "nope")
    Condition
      Error:
      ! `repeat_cols` references 1 column not in `data`.
      x Missing: "nope".
      i Available: "soc" and "val".

