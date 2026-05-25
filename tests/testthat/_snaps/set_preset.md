# set_preset() snapshot errors

    Code
      set_preset(font_zize = 8)
    Condition
      Error:
      ! Unknown preset knob: "font_zize".
      i Recognised knobs: "font_size", "font_family", "orientation", "paper_size", "margins", "pagehead", "pagefoot", "hlines", "indent_chars", "title_align", "footnote_align", "na_text", "decimal_metrics", "chrome_onscreen", "width_mode", "alignment", "borders", "fonts", ..., "body_pad_top", and "body_pad_bottom".

---

    Code
      set_preset(orientation = "diagonal")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @orientation must be one of 'portrait', 'landscape'

