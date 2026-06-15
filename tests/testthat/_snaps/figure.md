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

# preset() on a figure: geometry + chrome cosmetics, not table cosmetics

    Code
      preset(fig, rules = list(midrule = "none"))
    Condition
      Error:
      ! Preset knob "rules" cannot target a figure's table surfaces.
      i On a figure, cosmetic knobs may target titles, footnotes, or the page header / footer only.
      i e.g. `fonts = list(title = c(size = 14))` or `colors = list(footnotes = c(text = "red"))`.

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

# figure cli summary truncates long titles and reports a preset

    Code
      tabular:::.figure_spec_print_cli(fs)
    Message
      
      -- <figure_spec> 
      Source: "function" (1 page)
      Titles (1):
      1. "Long enrollment figure title Long enrollment figure title..."
      Footnotes: 1 line
      Placement: halign="center", valign="middle"
      Preset: font_size=8

