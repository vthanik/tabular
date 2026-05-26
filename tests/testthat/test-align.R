# test-align.R — alignment cascade resolver (R/align.R)
#
# Post Task 4/5 slot cut, every named-list alignment knob enters
# through `preset()` / `set_preset()` and lowers to a style_layer.
# Body alignment lands on cells_style[r,c]@halign / @valign via
# engine_style(); chrome alignment (title / header / subgroup /
# footer / pagehead / pagefoot) lands on
# chrome_style$surfaces[<surface>]@halign / @valign via
# engine_chrome_borders(). The .effective_* helpers in R/align.R
# now consult only the legacy `preset@title_align` / `@footnote_align`
# scalars (the two scalar alignment slots that survived the cut).

# ---------------------------------------------------------------------
# Knob shape validators (run at preset() call time)
# ---------------------------------------------------------------------

test_that("preset() accepts well-formed alignment list (scalars only)", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      alignment = list(
        title_halign = "left",
        footnote_halign = "left",
        subgroup_halign = "right",
        header_halign = "center",
        header_valign = "bottom",
        body_halign = "left",
        body_valign = "top"
      )
    )
  expect_true(is_preset_spec(spec@preset))
  # Knob lowered to style layers; no slot to inspect.
  surfaces <- vapply(
    spec@preset@style,
    function(l) l@location$surface,
    character(1L)
  )
  expect_setequal(
    surfaces,
    c("title", "footnotes", "subgroup_labels", "headers", "body")
  )
})

test_that("preset_spec() rejects direct alignment argument (slot cut)", {
  expect_error(
    suppressWarnings(preset_spec(alignment = list(title_halign = "left"))),
    "unused argument"
  )
})

test_that("alignment rejects unknown key", {
  expect_snapshot(
    error = TRUE,
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(weird_halign = "left"))
  )
})

test_that("alignment rejects bad halign value", {
  expect_snapshot(
    error = TRUE,
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_halign = "diagonal"))
  )
})

test_that("alignment rejects bad valign value", {
  expect_snapshot(
    error = TRUE,
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_valign = "side"))
  )
})

test_that("alignment rejects vector form (scalar-only after cut)", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(title_halign = c("left", "right"))),
    class = "tabular_error_input"
  )
})

test_that("alignment rejects NA in any value", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_halign = NA_character_)),
    class = "tabular_error_input"
  )
})

# Coverage — validator branches via direct preset() calls.

test_that(".preset_alignment_shape_error: NULL value clears one key", {
  # NULL is the documented clear-this-key sentinel; lowering skips it.
  expect_silent(
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_halign = NULL))
  )
})

test_that(".preset_alignment_shape_error: non-list input rejected", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(alignment = "left"),
    class = "tabular_error_input"
  )
})

test_that(".preset_alignment_shape_error: unnamed entries rejected", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(alignment = list("left")),
    class = "tabular_error_input"
  )
})

test_that(".preset_alignment_shape_error: non-character value rejected", {
  expect_error(
    tabular(data.frame(x = 1)) |> preset(alignment = list(body_halign = 1L)),
    class = "tabular_error_input"
  )
})

test_that(".preset_alignment_shape_error: empty vector rejected", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_halign = character())),
    class = "tabular_error_input"
  )
})

test_that(".preset_alignment_shape_error: valign vector rejected", {
  expect_error(
    tabular(data.frame(x = 1)) |>
      preset(alignment = list(body_valign = c("top", "bottom"))),
    class = "tabular_error_input"
  )
})

test_that(".preset_align: legacy footnote_align surfaces when changed", {
  preset_custom <- preset_spec(footnote_align = "center")
  expect_identical(
    tabular:::.effective_footnote_halign(preset_custom),
    "center"
  )
})

# ---------------------------------------------------------------------
# .preset_align — legacy scalar-only resolver
# ---------------------------------------------------------------------

test_that(".preset_align returns NA for body / header / subgroup keys", {
  # No legacy scalar exists for these on preset_spec, so the function
  # always returns NA. Backends consume the chrome_style cascade for
  # these surfaces.
  expect_true(is.na(tabular:::.preset_align(preset_spec(), "body_halign")))
  expect_true(is.na(tabular:::.preset_align(preset_spec(), "header_halign")))
  expect_true(
    is.na(tabular:::.preset_align(preset_spec(), "subgroup_halign"))
  )
})

test_that(".preset_align returns NA for non-preset input", {
  expect_true(is.na(tabular:::.preset_align(NULL, "body_halign")))
  expect_true(is.na(tabular:::.preset_align("not a preset", "body_halign")))
})

test_that(".preset_align respects factory-default fall-through guard", {
  # Factory `title_align = "center"` is NOT treated as explicit; the
  # resolver returns NA so backends fall through to the chrome_style
  # cascade instead of locking in the factory default.
  expect_true(is.na(tabular:::.preset_align(preset_spec(), "title_halign")))
  # User-changed `title_align` IS explicit; returns the value.
  expect_identical(
    tabular:::.preset_align(preset_spec(title_align = "left"), "title_halign"),
    "left"
  )
})

# ---------------------------------------------------------------------
# Class validators — last-line defence
# ---------------------------------------------------------------------

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

# ---------------------------------------------------------------------
# End-to-end subgroup alignment surfacing
# ---------------------------------------------------------------------

test_that("preset(alignment = subgroup_halign = ...) surfaces in HTML banner", {
  spec <- tabular(data.frame(g = c("A", "B"), x = c(1, 2))) |>
    subgroup("g") |>
    preset(alignment = list(subgroup_halign = "left"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("tabular-subgroup-label text-left", txt, fixed = TRUE))
})

test_that("preset(alignment = subgroup_halign = ...) surfaces in RTF banner", {
  spec <- tabular(data.frame(g = c("A", "B"), x = c(1, 2))) |>
    subgroup("g") |>
    preset(alignment = list(subgroup_halign = "left"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\ql", txt))
})

test_that("preset(alignment = subgroup_halign = ...) surfaces in DOCX banner", {
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
  expect_true(is_style_node(tabular:::.cell_style_at(NULL, 1L, "x")))
  m <- matrix(list(style_node()), nrow = 1L)
  expect_true(is_style_node(tabular:::.cell_style_at(m, 1L, "x")))
  m2 <- matrix(list(style_node()), nrow = 1L)
  colnames(m2) <- "y"
  expect_true(is_style_node(tabular:::.cell_style_at(m2, 1L, "x")))
  m3 <- matrix(list(style_node()), nrow = 1L)
  colnames(m3) <- "x"
  expect_true(is_style_node(tabular:::.cell_style_at(m3, 5L, "x")))
  m4 <- matrix(list("not a style"), nrow = 1L)
  colnames(m4) <- "x"
  expect_true(is_style_node(tabular:::.cell_style_at(m4, 1L, "x")))
})

# ---------------------------------------------------------------------
# preset() layer composition — successive calls append, last-write wins
# ---------------------------------------------------------------------

test_that("preset() alignment appends layers across successive calls", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(alignment = list(body_halign = "right")) |>
    preset(alignment = list(body_valign = "middle"))
  # Two cells_body() layers appended in call order.
  surfaces <- vapply(
    spec@preset@style,
    function(l) l@location$surface,
    character(1L)
  )
  expect_identical(surfaces, c("body", "body"))
  expect_identical(spec@preset@style[[1L]]@style@halign, "right")
  expect_identical(spec@preset@style[[2L]]@style@valign, "middle")
})

test_that("preset() later alignment call overrides earlier per attribute", {
  spec <- tabular(data.frame(x = 1)) |>
    preset(
      alignment = list(
        body_halign = "left",
        header_halign = "center"
      )
    ) |>
    preset(alignment = list(body_halign = "right"))
  # 3 layers total (two from the first call, one from the second).
  expect_length(spec@preset@style, 3L)
  # Resolve via the engine — the second call's body cell_style@halign
  # wins because layers append in order.
  grid <- as_grid(spec)
  cs <- grid@pages[[1L]]$cells_style
  expect_identical(cs[[1L, 1L]]@halign, "right")
})

# ---------------------------------------------------------------------
# col_spec @valign
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
    style( halign = "right", valign = "middle", .at = cells_body(where = x > 1))
  pred <- spec@styles@layers[[1L]]
  expect_identical(pred@style@halign, "right")
  expect_identical(pred@style@valign, "middle")
})

# ---------------------------------------------------------------------
# Body cell cascade — predicate > col_spec > NA (lowered cell layer)
# ---------------------------------------------------------------------
#
# After the slot cut, body alignment from `preset(alignment = list(
# body_halign = ...))` lands on cells_style[r,c]@halign via the
# lowered cells_body() layer. `.effective_body_halign` reads
# cell_style@halign first, then col_spec, then falls through to NA.

test_that(".effective_body_halign cascade: predicate > col_spec > NA", {
  cs <- col_spec(align = "right")

  # No style override -> col_spec wins.
  sn_empty <- style_node()
  expect_identical(
    tabular:::.effective_body_halign(sn_empty, cs, preset_spec()),
    "right"
  )

  # Style override -> beats col_spec.
  sn_override <- style_node(halign = "left")
  expect_identical(
    tabular:::.effective_body_halign(sn_override, cs, preset_spec()),
    "left"
  )

  # No col_spec @align, no preset legacy scalar -> NA.
  expect_true(is.na(tabular:::.effective_body_halign(
    sn_empty,
    col_spec(),
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

test_that(".effective_body_valign cascade: predicate > col_spec > NA", {
  cs <- col_spec(valign = "bottom")
  expect_identical(
    tabular:::.effective_body_valign(style_node(), cs, preset_spec()),
    "bottom"
  )
  expect_identical(
    tabular:::.effective_body_valign(
      style_node(valign = "top"),
      cs,
      preset_spec()
    ),
    "top"
  )
  expect_true(is.na(tabular:::.effective_body_valign(
    style_node(),
    col_spec(),
    preset_spec()
  )))
})

# ---------------------------------------------------------------------
# Header / subgroup / title / footnote cascade
# ---------------------------------------------------------------------

test_that(".effective_header_halign cascade: col_spec > preset > NA", {
  # No preset@alignment slot; .preset_align returns NA for header_halign.
  expect_identical(
    tabular:::.effective_header_halign(
      col_spec(align = "right"),
      preset_spec()
    ),
    "right"
  )
  expect_true(is.na(tabular:::.effective_header_halign(
    col_spec(),
    preset_spec()
  )))
})

test_that(".effective_subgroup_halign returns NA on factory preset", {
  expect_true(is.na(tabular:::.effective_subgroup_halign(preset_spec())))
})

test_that(".effective_title_halign reads legacy title_align scalar", {
  preset <- preset_spec(title_align = "left")
  expect_identical(
    tabular:::.effective_title_halign(preset, line_index = 1L, n_lines = 1L),
    "left"
  )
})

test_that("legacy preset@title_align only counts as explicit when not factory default", {
  preset_default <- preset_spec()
  expect_true(is.na(tabular:::.effective_title_halign(
    preset_default,
    line_index = 1L,
    n_lines = 1L
  )))
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
# via the lowered cells_*() layer cascade
# ---------------------------------------------------------------------

test_that("preset(alignment = body_halign = ...) drives MD alignment row", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    preset(alignment = list(body_halign = "center"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("| :---: | :---: |", txt, fixed = TRUE))
})

test_that("preset(alignment = header_halign = ...) surfaces in HTML <th>", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(header_halign = "right"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("<th class=\"text-right\">x</th>", txt, fixed = TRUE))
})

test_that("preset(alignment = header_valign = ...) surfaces in HTML <th>", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(header_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("valign-middle", txt, fixed = TRUE))
})

test_that("style(halign=) predicate surfaces on HTML body cell", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style( halign = "right", .at = cells_body(where = x == 2))
  out <- withr::local_tempfile(fileext = ".html")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("class=\"text-right\"", txt, fixed = TRUE))
})

test_that("preset(alignment = header_halign = ...) surfaces in DOCX header jc", {
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

test_that("preset(alignment = body_valign = ...) surfaces in DOCX body vAlign", {
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

test_that("preset(alignment = body_halign = ...) surfaces in RTF body \\qc", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_halign = "center"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\qc", txt))
})

test_that("preset(alignment = body_valign = ...) surfaces in RTF \\clvertal", {
  spec <- tabular(data.frame(x = "a")) |>
    preset(alignment = list(body_valign = "middle"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\clvertalc", txt))
})

test_that("style(halign=) predicate emits per-cell \\SetCell in LaTeX", {
  spec <- tabular(data.frame(x = c(1, 2))) |>
    style( halign = "right", .at = cells_body(where = x == 2))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\SetCell{halign=r}", txt, fixed = TRUE))
})

test_that("preset(alignment = footnote_halign = ...) surfaces in RTF", {
  # Scalar after the cut — vector form is rejected.
  spec <- tabular(
    data.frame(x = 1),
    footnotes = c("Note 1", "Note 2")
  ) |>
    preset(alignment = list(footnote_halign = "right"))
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\\\qr", txt))
})

test_that("legacy preset(title_align = ...) drives LaTeX title alignment", {
  spec <- tabular(
    data.frame(x = 1),
    titles = "One line"
  ) |>
    preset(title_align = "left")
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\begin{flushleft}", txt, fixed = TRUE))
})
