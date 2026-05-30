# set_preset() snapshot errors

    Code
      set_preset(font_zize = 8)
    Condition
      Error:
      ! Unknown preset knob: "font_zize".
      i Recognised knobs: "font_size", "font_family", "orientation", "paper_size", "margins", "pagehead", "pagefoot", "indent_size", "na_text", "decimal_metrics", "decimal_markers", "chrome_onscreen", "width_mode", "cell_padding", "spacing", "stripe", "alignment", "rules", ..., "colors", and "padding".

---

    Code
      set_preset(orientation = "diagonal")
    Condition
      Error:
      ! Invalid preset knob value.
      x <tabular::preset_spec> object is invalid: - @orientation must be one of 'portrait', 'landscape'

# set_preset() new-arg error messages snapshot

    Code
      set_preset(house, font_size = 8)
    Condition
      Error:
      ! Pass `new` OR knobs / `.template` / `.style` / `.reset`, not both.
      i Wholesale install, `set_preset(spec)`.
      i Knob update, `set_preset(font_size = 10)`.
      i Restore saved, `set_preset(old)` after `old <- set_preset(...)`.

---

    Code
      set_preset("not a preset_spec")
    Condition
      Error:
      ! `new` must be a <preset_spec> or `NULL`.
      x You supplied a string.

