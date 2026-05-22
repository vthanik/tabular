test_that("R/ source contains no library() / require() calls", {
  r_files <- list.files(
    test_path("..", "..", "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )

  hits <- list()
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE)
    bad <- grepl("^[^#]*\\b(library|require)\\s*\\(", lines)
    if (any(bad)) {
      hits[[basename(f)]] <- which(bad)
    }
  }

  expect_equal(
    length(hits),
    0L,
    info = paste(
      "library() / require() found in R/.",
      "Use pkg::fn() qualification or @importFrom in roxygen.",
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
