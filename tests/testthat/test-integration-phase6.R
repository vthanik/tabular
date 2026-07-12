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
      arm = col_spec(label = "Arm"),
      cohort = col_spec(label = "Cohort"),
      n = col_spec(label = "N"),
      placebo = col_spec(label = "Placebo", align = "decimal"),
      drug_50 = col_spec(label = "Drug 50", align = "decimal"),
      drug_100 = col_spec(label = "Drug 100", align = "decimal"),
      helper_sort = col_spec(visible = FALSE)
    ) |>
    group_rows(by = c("arm", "cohort")) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100")) |>
    sort_rows(by = c("arm", "helper_sort")) |>
    style(bold = TRUE, .at = cells_body(where = n > 50)) |>
    subgroup("cohort", label = "Cohort: {cohort}") |>
    style(border = brdr("medium"), .at = cells_table(side = "outer")) |>
    preset(
      alignment = list(title_halign = "left"),
      rules = list(rowrule = brdr("hairline")),
      fonts = list(body = c(family = "Inter", size = 9)),
      colors = list(body = c(text = "#212529")),
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
  # padding$body — per-cell inline per-side style after the cut
  expect_true(grepl("padding-top: 4pt", txt, fixed = TRUE))
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

# ---------------------------------------------------------------------
# Cross-backend integration: the reported demographics scenario that
# kicked off the special-rows / frame / knob-shape work. A real wide
# table with a section group (-> group-header + blank separator
# rows), a spanner band, frame rules, zebra striping, a coloured +
# padded header, and styled page bands must render to a VALID artefact
# on every backend (Threads A-G + I together).
# ---------------------------------------------------------------------

test_that("demographics frame + stripe + group + page-band styling renders on all backends", {
  spec <- tabular(
    cdisc_saf_demo,
    titles = c("Table 14.1.1", "Demographics"),
    footnotes = md("Source: **ADSL**.")
  ) |>
    cols(
      variable = col_spec(),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    group_rows(by = "variable") |>
    headers("Active" = c("drug_50", "drug_100")) |>
    preset(
      rules = "frame",
      stripe = c(odd = "#f5f5f5", even = "#ffffff"),
      colors = list(header = c(text = "#212529", background = "#dddddd")),
      padding = list(header = c(top = 4, bottom = 4)),
      pagehead = list(left = md("**Protocol** ABC"), right = "Page {page}"),
      pagefoot = list(left = "Program: t_dm.R")
    ) |>
    style(bold = TRUE, .at = cells_pagehead(slot = "left")) |>
    style(border_bottom = brdr("thin"), .at = cells_pagehead())

  # HTML: emits without error, frame edge present, page-band markup rich.
  html <- withr::local_tempfile(fileext = ".html")
  expect_no_error(suppressWarnings(emit(spec, html)))
  htxt <- paste(readLines(html, warn = FALSE), collapse = "\n")
  expect_match(htxt, ".tabular-table { border-left:", fixed = TRUE)
  expect_match(htxt, "<strong>Protocol</strong>", fixed = TRUE)

  # RTF: emits without error.
  rtf <- withr::local_tempfile(fileext = ".rtf")
  expect_no_error(suppressWarnings(emit(spec, rtf)))

  # DOCX: every word/*.xml part is well-formed (the systemic validity
  # gate — catches rPr / tcBorders / tcPr ordering regressions).
  docx <- withr::local_tempfile(fileext = ".docx")
  expect_no_error(suppressWarnings(emit(spec, docx)))
  unz <- file.path(tempfile())
  utils::unzip(docx, exdir = unz)
  for (p in list.files(
    file.path(unz, "word"),
    pattern = "[.]xml$",
    full.names = TRUE
  )) {
    expect_no_error(xml2::read_xml(p))
  }

  # LaTeX -> PDF: compiles end to end (frame vlines + SetRow + fancyhdr
  # rule + slot props all valid tabularray / fancyhdr).
  # skip_on_cran: CRAN machines (win-builder, Debian with pdflatex) would
  # otherwise run this LaTeX compile -- slow and detritus-prone. Verified
  # locally and on CI.
  skip_on_cran()
  skip_if_not(tinytex::is_tinytex() || nzchar(Sys.which("pdflatex")))
  pdf <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(suppressWarnings(emit(spec, pdf)))
  expect_gt(file.size(pdf), 0L)
})
