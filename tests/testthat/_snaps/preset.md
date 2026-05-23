# preset() snapshot errors

    Code
      preset(spec, font_zize = 8)
    Condition
      Error:
      ! Unknown preset knob: "font_zize".
      i Recognised knobs: "font_size", "font_family", "orientation", "paper_size", "margins", "pagehead", "pagefoot", "hlines", "indent_chars", "title_align", "footnote_align", "na_text", and "decimal_metrics".

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
      x <tabular::preset_spec> object is invalid: - @margins must be length 1 (all sides) or length 4 (top right bottom left)

