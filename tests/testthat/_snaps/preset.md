# preset() snapshot errors

    Code
      preset(spec, font_zize = 8)
    Condition
      Error:
      ! Unknown preset knob: "font_zize".
      i Recognised knobs: "font_size", "font_family", "orientation", "paper_size", "margins", "pagehead", "pagefoot", "indent_size", "na_text", "decimal_metrics", "decimal_markers", "chrome_onscreen", "whitespace", "footnote_markers", "footnote_label", "width_mode", "empty_halign", "empty_valign", ..., "colors", and "padding".

---

    Code
      preset(spec, orientation = "diagonal")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @orientation must be one of 'portrait', 'landscape'

---

    Code
      preset(spec, margins = c(1, 0.5, 1))
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @margins must be length 1 (all sides), 2 (vertical horizontal), or 4 (top right bottom left)

# preset() rejects out-of-set empty_halign / empty_valign

    Code
      preset(spec, empty_halign = "middle")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @empty_halign must be one of 'left', 'center', 'right'; got 'middle'

---

    Code
      preset(spec, empty_valign = "left")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @empty_valign must be one of 'top', 'middle', 'bottom'; got 'left'

