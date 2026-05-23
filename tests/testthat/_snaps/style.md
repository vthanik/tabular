# style() error snapshots

    Code
      style(tabular(saf_demo), where = TRUE)
    Condition
      Error:
      ! Specify at least one style attribute.
      i Pass attributes like `bold = TRUE` or `color = "red"`.

---

    Code
      style(tabular(saf_demo), where = TRUE, bold = TRUE, .scope = "block")
    Condition
      Error:
      ! `.scope` must be one of "cell", "row", and "col".
      x You supplied "block".

