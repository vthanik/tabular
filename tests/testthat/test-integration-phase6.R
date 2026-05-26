# test-integration-phase6.R — cross-verb integration tests proving
# the Phase 6 surface area (subgroup + alignment + borders + chrome
# + visible cols + fonts / colors / padding) composes cleanly with
# the older verbs (cols / headers / sort_rows / style / preset)
# and that every backend honours every Phase 6 knob in one combined
# spec. Mirrors `.local/smoke/integration-phase6.R`.

combined_spec <- function() {
  df <- data.frame(
    arm = factor(c("A", "A", "B", "B"), levels = c("A", "B")),
    cohort = factor(c("X", "Y", "X", "Y"), levels = c("X", "Y")),
    n = c(40L, 60L, 35L, 55L),
    placebo = c(12.5, 13.1, 11.8, 12.2),
    drug_50 = c(15.7, 16.3, 14.5, 15.9),
    drug_100 = c(18.2, 19.0, 17.6, 18.4),
    helper_sort = c(1, 2, 1, 2)
  )
  tabular(
    df,
    titles = c("Integration", "Phase 6 Sweep"),
    footnotes = "All knobs flow through."
  ) |>
    cols(
      arm = col_spec(label = "Arm", usage = "group"),
      cohort = col_spec(label = "Cohort", usage = "group"),
      n = col_spec(label = "N"),
      placebo = col_spec(label = "Placebo", align = "decimal"),
      drug_50 = col_spec(label = "Drug 50", align = "decimal"),
      drug_100 = col_spec(label = "Drug 100", align = "decimal"),
      helper_sort = col_spec(visible = FALSE)
    ) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100")) |>
    sort_rows(by = c("arm", "helper_sort")) |>
    style(where = n > 50, bold = TRUE) |>
    subgroup("cohort", label = "Cohort: {cohort}") |>
    preset(
      alignment = list(title_halign = "left"),
      borders = list(outer = brdr("medium"), body_rows = brdr("hairline")),
      fonts = list(body = list(family = "Inter", size = 9)),
      colors = list(text = "#212529"),
      padding = list(body = 4)
    )
}

test_that("integration spec composes through all Phase 6 surfaces (HTML)", {
  spec <- combined_spec()
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Visible-col filter
  expect_false(grepl("helper_sort", txt, fixed = TRUE))
  # fonts$body$family
  expect_true(grepl("font-family: Inter", txt, fixed = TRUE))
  # colors$text — per-cell inline style after the Task 4/5 cut
  expect_true(grepl("color: #212529", txt, fixed = TRUE))
  # padding$body — per-cell inline style after the Task 4/5 cut
  expect_true(grepl("padding: 4pt", txt, fixed = TRUE))
  # Subgroup banner
  expect_true(grepl("Cohort: X", txt, fixed = TRUE))
  expect_true(grepl("Integration", txt, fixed = TRUE))
})

test_that("integration spec composes through all Phase 6 surfaces (DOCX)", {
  spec <- combined_spec()
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_false(grepl("helper_sort", doc, fixed = TRUE))
  expect_true(grepl("<w:color w:val=\"212529\"/>", doc, fixed = TRUE))
  expect_true(grepl("<w:tcMar>", doc, fixed = TRUE))
  expect_true(grepl("Integration", doc, fixed = TRUE))
})

test_that("integration spec composes through all Phase 6 surfaces (RTF)", {
  spec <- combined_spec()
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("helper_sort", txt, fixed = TRUE))
  expect_true(grepl("Inter", txt, fixed = TRUE))
  expect_true(grepl(
    "{\\colortbl;\\red33\\green37\\blue41;}",
    txt,
    fixed = TRUE
  ))
  # 4pt -> 80 twips
  expect_true(grepl("\\trowd\\trgaph80", txt, fixed = TRUE))
})

test_that("integration spec composes through all Phase 6 surfaces (LaTeX)", {
  spec <- combined_spec()
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("helper_sort", txt, fixed = TRUE))
  # Task 4/5 cut: per-cell color stamp via \SetCell, no preamble
  # \definecolor{tabular_text}.
  expect_true(
    grepl("212529", txt, fixed = TRUE) ||
      grepl("212529", txt, ignore.case = TRUE)
  )
  expect_true(grepl("rowsep=4pt", txt, fixed = TRUE))
})

test_that("integration spec composes through all Phase 6 surfaces (Markdown)", {
  spec <- combined_spec()
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("helper_sort", txt, fixed = TRUE))
  expect_true(grepl("Integration", txt, fixed = TRUE))
})
