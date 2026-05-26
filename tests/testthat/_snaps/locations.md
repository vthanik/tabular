# print.tabular_location renders i / j / where / level / labels / slot / side

    Code
      print(cells_body(i = 1:3, j = "Total"))
    Output
      <tabular_location: body(i=1,2,3, j=Total)>
    Code
      print(cells_body(where = x > 0))
    Output
      <tabular_location: body(where=x > 0)>
    Code
      print(cells_headers(level = 1L))
    Output
      <tabular_location: headers(level=1)>
    Code
      print(cells_headers(labels = "Treatment Group"))
    Output
      <tabular_location: headers(labels=c('Treatment Group'))>
    Code
      print(cells_pagehead(slot = "left"))
    Output
      <tabular_location: pagehead(slot='left')>
    Code
      print(cells_table(side = "outer_top"))
    Output
      <tabular_location: table(side='outer_top')>

# .format_filter truncates long index vectors

    Code
      print(cells_body(i = 1:10))
    Output
      <tabular_location: body(i=1,2,3,...)>

