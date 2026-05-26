# alignment rejects unknown key

    Code
      preset(tabular(data.frame(x = 1)), alignment = list(weird_halign = "left"))
    Condition
      Error:
      ! Invalid `alignment` value for `preset()`.
      x @alignment contains unknown key(s): 'weird_halign'; recognised: 'title_halign', 'footnote_halign', 'subgroup_halign', 'header_halign', 'body_halign', 'title_valign', 'footnote_valign', 'subgroup_valign', 'header_valign', 'body_valign'

# alignment rejects bad halign value

    Code
      preset(tabular(data.frame(x = 1)), alignment = list(body_halign = "diagonal"))
    Condition
      Error:
      ! Invalid `alignment` value for `preset()`.
      x @alignment key 'body_halign' value must be one of 'left', 'center', 'right'; got 'diagonal'

# alignment rejects bad valign value

    Code
      preset(tabular(data.frame(x = 1)), alignment = list(body_valign = "side"))
    Condition
      Error:
      ! Invalid `alignment` value for `preset()`.
      x @alignment key 'body_valign' value must be one of 'top', 'middle', 'bottom'; got 'side'

# col_spec() rejects bad valign value

    Code
      col_spec(valign = "diagonal")
    Condition
      Error:
      ! `valign` must be one of "top", "middle", and "bottom" or `NULL`.
      x You supplied a string.

