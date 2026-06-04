# emit() rejects when parent directory does not exist

    Code
      emit(spec, missing)
    Condition
      Error:
      ! Parent directory of `file` does not exist.
      x Missing directory: <path>.
      i Create it first, pass `create_dir = TRUE`, or use an existing directory.

