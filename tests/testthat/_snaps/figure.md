# figure() rejects unsupported inputs

    Code
      figure(42)
    Condition
      Error:
      ! `plot` is not a supported figure input.
      x You supplied a number.
      i Use a ggplot, a recorded base plot, a zero-arg function, or a .png / .jpg path.

# figure() validates halign / valign

    Code
      figure(function() plot(1), halign = "middle")
    Condition
      Error:
      ! `halign` must be one of "left", "center", or "right".
      x You supplied a string.

# figure cli summary reports source kind, placement, titles

    Code
      tabular:::.figure_spec_print_cli(fig)
    Message
      
      -- <figure_spec> 
      Source: "function" (1 page)
      Titles (2):
      1. "Figure 14.1.1"
      2. "Sub"
      Footnotes: 1 line
      Placement: halign="right", valign="top"

