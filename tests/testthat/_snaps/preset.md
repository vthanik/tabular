# preset() snapshot errors

    Code
      preset(spec, font_zize = 8)
    Condition
      Error:
      ! Unknown preset knob: "font_zize".
      i Recognised knobs: "font_size", "font_family", "orientation", "paper_size", "margins", "pagehead", "pagefoot", "indent_size", "na_text", "decimal_metrics", "decimal_markers", "chrome_onscreen", "whitespace", "footnote_markers", "footnote_label", "width_mode", "cell_padding", "spacing", ..., "colors", and "padding".

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

