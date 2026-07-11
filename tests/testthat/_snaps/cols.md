# cols() rejects values that are neither col_spec nor a label string

    Code
      cols(mk_spec(), param = 1L)
    Condition
      Error:
      ! Each entry in `cols()` must be a <col_spec> or a label string.
      x `param` is an integer.
      i Use `col_spec()` for attributes beyond the label.

# cols(.hide=) errors on a missing column

    Code
      cols(mk_spec(), .hide = "nope")
    Condition
      Error:
      ! `.hide` references 1 column not in `data`.
      x Missing: "nope".
      i Available columns: "param", "drug_a", and "drug_b".

