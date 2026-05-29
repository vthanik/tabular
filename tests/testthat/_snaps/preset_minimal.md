# preset_minimal() rejects a user-supplied rules / borders knob (#edge14)

    Code
      preset_minimal(mk_group_spec(), rules = "grid")
    Condition
      Error:
      ! `preset_minimal()` owns the rule set.
      x Drop `rules`; the minimal theme draws the midrule only.
      i For a custom rule set call `preset()` directly.

