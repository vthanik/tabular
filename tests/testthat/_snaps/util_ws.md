# preset(whitespace=) rejects an unknown value

    Code
      preset(tabular(data.frame(x = 1)), whitespace = "nope")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @whitespace must be one of 'preserve', 'collapse'

