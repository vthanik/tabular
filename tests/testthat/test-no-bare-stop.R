test_that("R/ source raises errors via cli::cli_abort() only", {
  r_files <- list.files(
    test_path("..", "..", "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )

  # Look for bare `stop(` or `rlang::abort(` -- both are forbidden per
  # `~/.claude/rules/r-code.md`. The `cli::` prefix is required for
  # consistent error-class plumbing (tabular_error_<kind>).
  hits <- list()
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE)
    # strip comments before matching to avoid false positives
    code <- sub("#.*$", "", lines)
    bad <- grepl("(^|[^a-zA-Z0-9_:.])stop\\s*\\(", code) |
      grepl("rlang::abort\\s*\\(", code) |
      grepl("(^|[^a-zA-Z0-9_:.])abort\\s*\\(", code)
    if (any(bad)) {
      hits[[basename(f)]] <- which(bad)
    }
  }

  expect_equal(
    length(hits),
    0L,
    info = paste(
      "Bare stop() / rlang::abort() / abort() in R/.",
      "Use cli::cli_abort(class = 'tabular_error_<kind>') instead.",
      paste(
        sprintf(
          "%s: lines %s",
          names(hits),
          vapply(hits, paste, character(1), collapse = ", ")
        ),
        collapse = "; "
      )
    )
  )
})
