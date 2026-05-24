# alignment rejects unknown key

    Code
      preset_spec(alignment = list(weird_halign = "left"))
    Condition
      Error:
      ! <tabular::preset_spec> object is invalid:
      - @alignment contains unknown key(s): 'weird_halign'; recognised: 'title_halign', 'footnote_halign', 'subgroup_halign', 'header_halign', 'body_halign', 'title_valign', 'footnote_valign', 'subgroup_valign', 'header_valign', 'body_valign'

# alignment rejects bad halign value

    Code
      preset_spec(alignment = list(body_halign = "diagonal"))
    Condition
      Error:
      ! <tabular::preset_spec> object is invalid:
      - @alignment key 'body_halign' value(s) must be one of 'left', 'center', 'right'; got 'diagonal'

# alignment rejects bad valign value

    Code
      preset_spec(alignment = list(body_valign = "side"))
    Condition
      Error:
      ! <tabular::preset_spec> object is invalid:
      - @alignment key 'body_valign' value(s) must be one of 'top', 'middle', 'bottom'; got 'side'

# alignment rejects vector for non-broadcast key

    Code
      preset_spec(alignment = list(body_halign = c("left", "right")))
    Condition
      Error:
      ! <tabular::preset_spec> object is invalid:
      - @alignment key 'body_halign' must be length 1; vectors are accepted only for 'title_halign', 'footnote_halign'

# alignment rejects NA in any value

    Code
      preset_spec(alignment = list(body_halign = NA_character_))
    Condition
      Error:
      ! <tabular::preset_spec> object is invalid:
      - @alignment key 'body_halign' must not contain NA

# col_spec() rejects bad valign value

    Code
      col_spec(valign = "diagonal")
    Condition
      Error:
      ! `valign` must be one of "top", "middle", and "bottom" or `NULL`.
      x You supplied a string.

