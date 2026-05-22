test_that("R/ code lines (non-roxygen) are ASCII-only", {
  # Per `~/.claude/rules/ascii.md`: ASCII discipline applies to `#`
  # comments and message strings inside function bodies. Roxygen
  # `#'` prose is explicitly allowed non-ASCII (em-dashes, en-dashes,
  # curly quotes are fine for readability in @description / @details
  # blocks). DESCRIPTION declares `Encoding: UTF-8` so R CMD check
  # accepts non-ASCII roxygen.
  r_files <- list.files(
    test_path("..", "..", "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )

  hits <- list()
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    is_roxygen <- grepl("^\\s*#'", lines)
    non_ascii <- grepl("[^\x01-\x7F]", lines, useBytes = TRUE) & !is_roxygen
    if (any(non_ascii)) {
      hits[[basename(f)]] <- which(non_ascii)
    }
  }

  expect_equal(
    length(hits),
    0L,
    info = paste(
      "Non-ASCII characters found in R/ code lines (non-roxygen).",
      "Use ' -- ' not em-dash; straight quotes not curly.",
      "Roxygen #' lines are allowed non-ASCII; only flagged code is the issue.",
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
