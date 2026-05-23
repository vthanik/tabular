# engine_style() error snapshots

    Code
      tabular:::engine_style(spec)
    Condition
      Error:
      ! Failed to evaluate `style()` `where`.
      x Underlying error: object 'no_such_col' not found.

---

    Code
      tabular:::engine_style(spec2)
    Condition
      Error:
      ! `.scope = "col"` is not implemented in this release.
      i Use `.scope = "row"` or `.scope = "cell"` for now.

