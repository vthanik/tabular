# print() on a 0-layer template shows the header line only

    Code
      print(t)
    Output
      <tabular_style_template: 0 layers>

# print() on a 1-layer template shows '1 layer' and the surface

    Code
      print(t)
    Output
      <tabular_style_template: 1 layer>
        1. headers

# print() on a multi-layer template enumerates each surface

    Code
      print(t)
    Output
      <tabular_style_template: 3 layers>
        1. headers
        2. title
        3. footnotes

