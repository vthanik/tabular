# style() error snapshots

    Code
      style(tabular(saf_demo), .at = cells_body(where = TRUE))
    Condition
      Error:
      ! Specify at least one style attribute.
      i Pass attributes like `bold = TRUE` or `color = "red"`.

---

    Code
      style(tabular(saf_demo), bold = TRUE, .at = "not a location")
    Condition
      Error:
      ! `.at` must be a <tabular_location>.
      x You supplied a string.
      i Build one with `cells_body()` / `cells_headers()` / etc.

