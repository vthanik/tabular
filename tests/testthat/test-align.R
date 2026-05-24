# test-align.R — alignment cascade resolver (R/align.R)

# ---------------------------------------------------------------------
# preset@alignment validator
# ---------------------------------------------------------------------

test_that("preset_spec accepts well-formed alignment list", {
  p <- preset_spec(
    alignment = list(
      title_halign = c("left", "center", "right"),
      footnote_halign = "left",
      subgroup_halign = "right",
      header_halign = "center",
      header_valign = "bottom",
      body_halign = "left",
      body_valign = "top"
    )
  )
  expect_true(is_preset_spec(p))
  expect_identical(p@alignment$body_halign, "left")
  expect_identical(
    p@alignment$title_halign,
    c("left", "center", "right")
  )
})

test_that("alignment empty list is the default", {
  p <- preset_spec()
  expect_identical(p@alignment, list())
})

test_that("alignment rejects unknown key", {
  expect_snapshot(
    error = TRUE,
    preset_spec(alignment = list(weird_halign = "left"))
  )
})

test_that("alignment rejects bad halign value", {
  expect_snapshot(
    error = TRUE,
    preset_spec(alignment = list(body_halign = "diagonal"))
  )
})

test_that("alignment rejects bad valign value", {
  expect_snapshot(
    error = TRUE,
    preset_spec(alignment = list(body_valign = "side"))
  )
})

test_that("alignment rejects vector for non-broadcast key", {
  expect_snapshot(
    error = TRUE,
    preset_spec(alignment = list(body_halign = c("left", "right")))
  )
})

test_that("alignment rejects NA in any value", {
  expect_snapshot(
    error = TRUE,
    preset_spec(alignment = list(body_halign = NA_character_))
  )
})

# Coverage tests — exercise the validator branches directly so
# coverage stays above 95% when snapshot tests are CRAN-skipped.

test_that(".preset_alignment_shape_error: NULL value clears one key", {
  # NULL is the documented clear-this-key sentinel; validator accepts.
  expect_silent(preset_spec(alignment = list(body_halign = NULL)))
})

test_that(".preset_alignment_shape_error: non-list input rejected", {
  expect_error(preset_spec(alignment = "left"))
})

test_that(".preset_alignment_shape_error: unnamed entries rejected", {
  expect_error(preset_spec(alignment = list("left")))
})

test_that(".preset_alignment_shape_error: non-character value rejected", {
  expect_error(preset_spec(alignment = list(body_halign = 1L)))
})

test_that(".preset_alignment_shape_error: empty vector rejected", {
  expect_error(preset_spec(alignment = list(body_halign = character())))
})

test_that(".preset_alignment_shape_error: valign vector form rejected", {
  expect_error(preset_spec(
    alignment = list(body_valign = c("top", "bottom"))
  ))
})

test_that(".preset_align: legacy footnote_align surfaces when changed", {
  preset_custom <- preset_spec(footnote_align = "center")
  expect_identical(
    tabular:::.effective_footnote_halign(preset_custom),
    "center"
  )
})

test_that(".effective_header_valign cascade: col_spec > preset > NA", {
  preset <- preset_spec(alignment = list(header_valign = "top"))
  expect_identical(
    tabular:::.effective_header_valign(col_spec(valign = "middle"), preset),
    "middle"
  )
  expect_identical(
    tabular:::.effective_header_valign(col_spec(), preset),
    "top"
  )
  expect_true(is.na(tabular:::.effective_header_valign(
    col_spec(),
    preset_spec()
  )))
})

test_that(".effective_subgroup_valign reads preset@alignment$subgroup_valign", {
  preset <- preset_spec(alignment = list(subgroup_valign = "bottom"))
  expect_identical(
    tabular:::.effective_subgroup_valign(preset),
    "bottom"
  )
})

test_that(".effective_footnote_halign vector-form broadcasts per line", {
  preset <- preset_spec(
    alignment = list(footnote_halign = c("center", "right"))
  )
  expect_identical(
    tabular:::.effective_footnote_halign(preset, 1L, 2L),
    "center"
  )
  expect_identical(
    tabular:::.effective_footnote_halign(preset, 2L, 2L),
    "right"
  )
})

test_that(".preset_align returns NA for non-preset input", {
  expect_true(is.na(tabular:::.preset_align(NULL, "body_halign")))
  expect_true(is.na(tabular:::.preset_align("not a preset", "body_halign")))
})

# S7 validator coverage — exercise the validator branches via
# direct class construction. The user-facing verbs intercept most
# bad input upstream via cli-friendly errors, but the validators
# are the last-line defense and deserve direct coverage.

test_that("col_spec class validator rejects bad valign", {
  expect_error(
    tabular:::.col_spec_class(name = NA_character_, valign = "side")
  )
})

test_that("style_node validator rejects bad halign", {
  expect_error(style_node(halign = "diagonal"))
})

test_that("style_node validator rejects bad valign", {
  expect_error(style_node(valign = "side"))
})

test_that("style_node accepts NA defaults for halign / valign", {
  sn <- style_node()
  expect_true(is.na(sn@halign))
  expect_true(is.na(sn@valign))
})

test_that("preset_spec validator rejects mistyped alignment", {
  expect_error(preset_spec(alignment = list(body_halign = TRUE)))
})

# End-to-end subgroup alignment + .cell_style_at coverage tests.

test_that("preset@alignment$subgroup_halign surfaces in HTML banner", {
  spec <- tabular(data.frame(g = c("A", "B"), x = c(1, 2))) |>
    subgroup("g") |>
    preset(alignment = list(subgroup_halign = "left"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # HTML emits the override class on the subgroup-label cell
  expect_true(grepl("tabular-subgroup-label text-left", txt, fixed = TRUE))
})

test_that("preset@alignment$subgroup_halign surfaces in RTF banner", {
  spec <- tabular(data.frame(g = c("A", "B"), x = c(1, 2))) |>
    subgroup("g") |>
    preset(alignment = list(subgroup_halign = "left"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\ql", txt))
})

test_that("preset@alignment$subgroup_halign surfaces in DOCX banner", {
  spec <- tabular(data.frame(g = c("A", "B"), x = c(1, 2))) |>
    subgroup("g") |>
    preset(alignment = list(subgroup_halign = "left"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl("<w:jc w:val=\"left\"/>", doc, fixed = TRUE))
})

test_that(".cell_style_at returns default style for missing inputs", {
  # No cells_style attached
  expect_true(is_style_node(tabular:::.cell_style_at(NULL, 1L, "x")))
  # Matrix without column names
  m <- matrix(list(style_node()), nrow = 1L)
  expect_true(is_style_node(tabular:::.cell_style_at(m, 1L, "x")))
  # Column not in colnames
  m2 <- matrix(list(style_node()), nrow = 1L)
  colnames(m2) <- "y"
  expect_true(is_style_node(tabular:::.cell_style_at(m2, 1L, "x")))
  # Row out of bounds
  m3 <- matrix(list(style_node()), nrow = 1L)
  colnames(m3) <- "x"
  expect_true(is_style_node(tabular:::.cell_style_at(m3, 5L, "x")))
  # Non-style_node entry
  m4 <- matrix(list("not a style"), nrow = 1L)
  colnames(m4) <- "x"
  expect_true(is_style_node(tabular:::.cell_style_at(m4, 1L, "x")))
})

# ---------------------------------------------------------------------
# preset() shallow-merge of alignment list across calls
# ---------------------------------------------------------------------

test_that("preset() shallow-merges alignment across calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(alignment = list(body_halign = "right")) |>
    preset(alignment = list(body_valign = "middle"))
  al <- spec@preset@alignment
  expect_identical(al$body_halign, "right")
  expect_identical(al$body_valign, "middle")
})

test_that("preset() second-call overwrites a single key, leaves others", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      alignment = list(
        body_halign = "left",
        header_halign = "center"
      )
    ) |>
    preset(alignment = list(body_halign = "right"))
  al <- spec@preset@alignment
  expect_identical(al$body_halign, "right")
  expect_identical(al$header_halign, "center")
})

# ---------------------------------------------------------------------
# col_spec@valign
# ---------------------------------------------------------------------

test_that("col_spec() accepts valign = top / middle / bottom", {
  expect_identical(col_spec(valign = "top")@valign, "top")
  expect_identical(col_spec(valign = "middle")@valign, "middle")
  expect_identical(col_spec(valign = "bottom")@valign, "bottom")
})

test_that("col_spec() valign default is NA", {
  expect_true(is.na(col_spec()@valign))
})

test_that("col_spec() rejects bad valign value", {
  expect_snapshot(error = TRUE, col_spec(valign = "diagonal"))
})

# ---------------------------------------------------------------------
# style() halign / valign
# ---------------------------------------------------------------------

test_that("style() accepts halign and valign", {
  spec <- tabular(data.frame(x = 1:3)) |>
    style(where = x > 1, halign = "right", valign = "middle")
  pred <- spec@styles@predicates[[1L]]
  expect_identical(pred@style@halign, "right")
  expect_identical(pred@style@valign, "middle")
})

# ---------------------------------------------------------------------
# Cascade — body cell halign / valign resolution
# ---------------------------------------------------------------------

test_that(".effective_body_halign cascade: predicate > col_spec > preset", {
  preset <- preset_spec(alignment = list(body_halign = "center"))
  cs <- col_spec(align = "right")

  # No style override -> col_spec wins
  sn_empty <- style_node()
  expect_identical(
    tabular:::.effective_body_halign(sn_empty, cs, preset),
    "right"
  )

  # Style override -> beats col_spec
  sn_override <- style_node(halign = "left")
  expect_identical(
    tabular:::.effective_body_halign(sn_override, cs, preset),
    "left"
  )

  # No col_spec @align -> falls to preset@alignment$body_halign
  cs_no_align <- col_spec()
  expect_identical(
    tabular:::.effective_body_halign(sn_empty, cs_no_align, preset),
    "center"
  )

  # No preset alignment override -> falls to NA (CSS / backend default)
  expect_true(is.na(tabular:::.effective_body_halign(
    sn_empty,
    cs_no_align,
    preset_spec()
  )))
})

test_that(".effective_body_halign treats 'decimal' as right (engine padded)", {
  cs <- col_spec(align = "decimal")
  expect_identical(
    tabular:::.effective_body_halign(style_node(), cs, preset_spec()),
    "right"
  )
})

test_that(".effective_body_valign cascade: predicate > col_spec > preset", {
  preset <- preset_spec(alignment = list(body_valign = "middle"))
  cs <- col_spec(valign = "bottom")

  expect_identical(
    tabular:::.effective_body_valign(style_node(), cs, preset),
    "bottom"
  )
  expect_identical(
    tabular:::.effective_body_valign(style_node(valign = "top"), cs, preset),
    "top"
  )
  expect_identical(
    tabular:::.effective_body_valign(style_node(), col_spec(), preset),
    "middle"
  )
  expect_true(is.na(tabular:::.effective_body_valign(
    style_node(),
    col_spec(),
    preset_spec()
  )))
})

# ---------------------------------------------------------------------
# Cascade — header cell + subgroup + title + footnote
# ---------------------------------------------------------------------

test_that(".effective_header_halign cascade: col_spec > preset > NA", {
  preset <- preset_spec(alignment = list(header_halign = "left"))
  expect_identical(
    tabular:::.effective_header_halign(col_spec(align = "right"), preset),
    "right"
  )
  expect_identical(
    tabular:::.effective_header_halign(col_spec(), preset),
    "left"
  )
  expect_true(is.na(tabular:::.effective_header_halign(
    col_spec(),
    preset_spec()
  )))
})

test_that(".effective_subgroup_halign reads preset@alignment$subgroup_halign", {
  preset <- preset_spec(alignment = list(subgroup_halign = "left"))
  expect_identical(
    tabular:::.effective_subgroup_halign(preset),
    "left"
  )
  expect_true(is.na(tabular:::.effective_subgroup_halign(preset_spec())))
})

test_that(".effective_title_halign vector-form broadcasts per line", {
  preset <- preset_spec(
    alignment = list(title_halign = c("left", "center", "right"))
  )
  expect_identical(
    tabular:::.effective_title_halign(preset, line_index = 1L, n_lines = 3L),
    "left"
  )
  expect_identical(
    tabular:::.effective_title_halign(preset, line_index = 2L, n_lines = 3L),
    "center"
  )
  expect_identical(
    tabular:::.effective_title_halign(preset, line_index = 3L, n_lines = 3L),
    "right"
  )
})

test_that(".effective_title_halign vector shorter than n broadcasts last entry", {
  preset <- preset_spec(alignment = list(title_halign = c("left", "right")))
  expect_identical(
    tabular:::.effective_title_halign(preset, line_index = 3L, n_lines = 3L),
    "right"
  )
})

test_that("legacy preset@title_align only counts as explicit when not factory default", {
  # Factory default "center" treated as NOT explicit -> resolver returns NA.
  preset_default <- preset_spec()
  expect_true(is.na(tabular:::.effective_title_halign(
    preset_default,
    line_index = 1L,
    n_lines = 1L
  )))
  # User-changed value treated as explicit.
  preset_custom <- preset_spec(title_align = "left")
  expect_identical(
    tabular:::.effective_title_halign(
      preset_custom,
      line_index = 1L,
      n_lines = 1L
    ),
    "left"
  )
})

# ---------------------------------------------------------------------
# Backend smoke — alignment surfaces in HTML / RTF / DOCX / LaTeX
# ---------------------------------------------------------------------

test_that("preset@alignment$body_halign drives MD alignment row", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    preset(alignment = list(body_halign = "center"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("| :---: | :---: |", txt, fixed = TRUE))
})

test_that("preset@alignment$header_halign surfaces in HTML <th>", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(header_halign = "right"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<th class=\"text-right\">x</th>", txt, fixed = TRUE))
})

test_that("preset@alignment$header_valign surfaces in HTML <th>", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(header_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("valign-middle", txt, fixed = TRUE))
})

test_that("style(halign=) predicate surfaces on HTML body cell", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style(where = x == 2, halign = "right", .scope = "row")
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("class=\"text-right\"", txt, fixed = TRUE))
})

test_that("preset@alignment$header_halign surfaces in DOCX header jc token", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(header_halign = "right"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  expect_true(grepl("<w:jc w:val=\"right\"/>", doc, fixed = TRUE))
})

test_that("preset@alignment$body_valign surfaces in DOCX body vAlign", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".docx")
  emit(spec, out)
  td <- withr::local_tempdir()
  utils::unzip(out, exdir = td)
  doc <- paste(
    readLines(file.path(td, "word", "document.xml"), warn = FALSE),
    collapse = ""
  )
  # OOXML "middle" -> w:val="center"
  expect_true(grepl("<w:vAlign w:val=\"center\"/>", doc, fixed = TRUE))
})

test_that("preset@alignment$body_halign surfaces in RTF body \\qc", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_halign = "center"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\qc", txt))
})

test_that("preset@alignment$body_valign surfaces in RTF \\clvertal", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\clvertalc", txt))
})

test_that("preset@alignment$body_valign surfaces in LaTeX table valign", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("rows={valign=m}", txt, fixed = TRUE))
})

test_that("style(halign=) predicate emits per-cell \\SetCell in LaTeX", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style(where = x == 2, halign = "right", .scope = "row")
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\SetCell{halign=r}", txt, fixed = TRUE))
})

test_that("preset@alignment$title_halign drives per-line LaTeX env", {
  spec <- tabular(
    data.frame(x = 1),
    titles = c("Left line", "Right line")
  ) |>
    preset(alignment = list(title_halign = c("left", "right")))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\begin{flushleft}", txt, fixed = TRUE))
  expect_true(grepl("\\begin{flushright}", txt, fixed = TRUE))
})

test_that("preset@alignment$footnote_halign drives RTF per-line \\qc", {
  spec <- tabular(
    data.frame(x = 1),
    footnotes = c("Note 1", "Note 2")
  ) |>
    preset(alignment = list(footnote_halign = c("center", "right")))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\qc", txt))
  expect_true(grepl("\\\\qr", txt))
})
