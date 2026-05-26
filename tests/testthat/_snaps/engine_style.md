# engine_style() error snapshot on unknown column in predicate

    Code
      tabular:::engine_style(spec)
    Condition
      Error:
      ! Failed to evaluate `style()` `where`.
      x Underlying error: object 'no_such_col' not found.

