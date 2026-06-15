# a throwing plot function aborts with a typed, page-named error

    Code
      emit(fig, withr::local_tempfile(fileext = ".html"))
    Condition
      Error:
      ! Failed to render figure plot 1.
      x The plot raised an error while drawing: draw failure
      i Check the plot object or zero-argument drawing function for errors.
      Caused by error in `plot()`:
      ! draw failure

