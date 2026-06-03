# footnote() rejects a non-location .at

    Code
      footnote(mk_fn_spec(), "x", .at = "Total")
    Condition
      Error:
      ! `.at` must be a `cells_*()` location.
      i e.g. `cells_body(where = grade == "3")` or `cells_headers(j = "Total")`.

