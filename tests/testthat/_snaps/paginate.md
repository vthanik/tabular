# paginate() snapshot errors

    Code
      paginate(spec, keep_together = "val")
    Condition
      Error:
      ! `keep_together` entries must be `usage = "group"` columns.
      x Not declared as group: "val".
      i Set `usage = "group"` in `cols()` for the protected column(s).

---

    Code
      paginate(spec, panels = "weird")
    Condition
      Error:
      ! `panels` must be a positive whole number or "auto".
      x You supplied a string.

---

    Code
      paginate(spec, continuation = c("a", "b"))
    Condition
      Error:
      ! `continuation` must be a single character string or `NULL`.
      x You supplied a character vector of length 2.

