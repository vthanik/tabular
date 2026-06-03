# test-vignette-fences.R — lint guard for issue #2: a stray unmatched
# code fence at EOF rendered as a literal ``` on the built article pages.
# Asserts every vignette / article .qmd has balanced ``` fences. Runs
# against the package SOURCE (devtools::test); skipped under R CMD check
# where vignettes/ is not installed.

test_that("every vignette .qmd has balanced code fences (#issue2)", {
  vig_dir <- test_path("..", "..", "vignettes")
  skip_if(!dir.exists(vig_dir), "vignettes/ not present (installed pkg)")

  qmds <- list.files(
    vig_dir,
    pattern = "\\.qmd$",
    recursive = TRUE,
    full.names = TRUE
  )
  skip_if(length(qmds) == 0L, "no .qmd vignettes found")

  unbalanced <- character()
  for (f in qmds) {
    lines <- readLines(f, warn = FALSE)
    n_fences <- sum(grepl("^```", lines))
    if (n_fences %% 2L != 0L) {
      unbalanced <- c(unbalanced, sprintf("%s (%d)", basename(f), n_fences))
    }
  }
  expect_identical(
    unbalanced,
    character(),
    info = paste(
      "Unbalanced code fences (odd ``` count -> a stray fence renders",
      "literally on the page):",
      paste(unbalanced, collapse = ", ")
    )
  )
})
