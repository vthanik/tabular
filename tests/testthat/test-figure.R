# test-figure.R — figure() constructor, classification, validation.

png_fixture <- function() test_path("fixtures", "fig-sample.png")
jpg_fixture <- function() test_path("fixtures", "fig-sample.jpg")

test_that("figure() classifies each supported source kind", {
  expect_equal(figure(function() plot(1))@source_kind, "function")
  expect_equal(figure(png_fixture())@source_kind, "file")

  # recorded plot
  grDevices::pdf(tempfile(fileext = ".pdf"))
  grDevices::dev.control("enable")
  plot(1:3)
  rp <- grDevices::recordPlot()
  grDevices::dev.off()
  expect_equal(figure(rp)@source_kind, "recordedplot")

  # multi-page list, kinds may mix
  fig <- figure(list(function() plot(1), png_fixture()))
  expect_equal(fig@source_kind, "multi")
  expect_length(fig@plots, 2L)
})

test_that("figure() detects a ggplot without attaching ggplot2", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  expect_equal(figure(p)@source_kind, "ggplot")
})

test_that("figure() normalises and interpolates titles / footnotes", {
  k <- 3
  fig <- figure(
    function() plot(1),
    titles = c("Figure {k}", "Sub"),
    footnotes = "fn {k}"
  )
  expect_equal(fig@titles, c("Figure 3", "Sub"))
  expect_equal(fig@footnotes, "fn 3")
})

test_that("figure() stores placement, dims, dpi", {
  fig <- figure(
    function() plot(1),
    width = 4,
    height = 3,
    halign = "right",
    valign = "top",
    dpi = 150
  )
  expect_equal(fig@halign, "right")
  expect_equal(fig@valign, "top")
  expect_equal(fig@width, 4)
  expect_equal(fig@height, 3)
  expect_equal(fig@dpi, 150)
})

test_that("is_figure_spec discriminates", {
  expect_true(is_figure_spec(figure(function() plot(1))))
  expect_false(is_figure_spec(42))
  expect_false(is_figure_spec(tabular(cdisc_saf_demo)))
  expect_false(is_tabular_spec(figure(function() plot(1))))
})

test_that("figure() with meta defers interpolation to resolve time", {
  meta <- data.frame(arm = c("A", "B"), stringsAsFactors = FALSE)
  fig <- figure(
    list(function() plot(1), function() plot(2)),
    titles = "Arm: {arm}",
    meta = meta
  )
  # raw token survives onto the spec (resolved per page in as_grid)
  expect_equal(fig@titles, "Arm: {arm}")
  expect_s3_class(fig@figure_meta, "data.frame")
})

test_that("figure() rejects unsupported inputs", {
  expect_snapshot(figure(42), error = TRUE)
  expect_error(figure(42), class = "tabular_error_input")
  expect_error(figure(list()), class = "tabular_error_input")
  expect_error(
    figure(list(function() plot(1), 42)),
    class = "tabular_error_input"
  )
})

test_that("figure() validates width / height / dpi", {
  expect_error(
    figure(function() plot(1), width = 0),
    class = "tabular_error_input"
  )
  expect_error(
    figure(function() plot(1), width = "big"),
    class = "tabular_error_input"
  )
  expect_error(
    figure(function() plot(1), height = NA_real_),
    class = "tabular_error_input"
  )
  expect_error(
    figure(function() plot(1), dpi = 0),
    class = "tabular_error_input"
  )
  expect_error(
    figure(function() plot(1), dpi = -10),
    class = "tabular_error_input"
  )
})

test_that("figure() validates halign / valign", {
  expect_error(
    figure(function() plot(1), halign = "centre"),
    class = "tabular_error_input"
  )
  # "center" is a halign value, not a valign value
  expect_error(
    figure(function() plot(1), valign = "center"),
    class = "tabular_error_input"
  )
  expect_snapshot(figure(function() plot(1), halign = "middle"), error = TRUE)
})

test_that("figure() rejects NA in titles", {
  expect_error(
    figure(function() plot(1), titles = c("a", NA)),
    class = "tabular_error_input"
  )
})

test_that("figure() meta validation", {
  # warn + ignore for a single-plot figure
  expect_warning(
    figure(function() plot(1), meta = data.frame(a = 1)),
    "ignored"
  )
  # non-data-frame meta on a multi-page figure errors
  expect_error(
    figure(list(function() plot(1), function() plot(2)), meta = 1:3),
    class = "tabular_error_input"
  )
  # row count must match plot count
  expect_error(
    figure(
      list(function() plot(1), function() plot(2)),
      meta = data.frame(a = 1)
    ),
    class = "tabular_error_input"
  )
})

test_that("table build verbs reject a figure_spec", {
  fig <- figure(function() plot(1))
  expect_error(cols(fig, x = col_spec()), class = "tabular_error_input")
  expect_error(headers(fig), class = "tabular_error_input")
  expect_error(sort_rows(fig, by = "x"), class = "tabular_error_input")
})

test_that("preset() on a figure: geometry + chrome cosmetics, not table cosmetics", {
  fig <- figure(function() plot(1), titles = "F")

  # page-geometry knobs apply and drive the figure box
  fp <- preset(
    fig,
    orientation = "portrait",
    paper_size = "a4",
    font_size = 8
  )
  expect_true(is_figure_spec(fp))
  expect_true(is_preset_spec(fp@preset))
  expect_equal(fp@preset@orientation, "portrait")
  expect_equal(fp@preset@paper_size, "a4")
  # portrait A4 is narrower than the default landscape letter
  expect_lt(
    as_grid(fp)@metadata$box$box_w_in,
    as_grid(fig)@metadata$box$box_w_in
  )

  # chrome-targeting cosmetic knobs ARE accepted (title / footnotes)
  expect_no_error(preset(fig, fonts = list(titles = c(size = 14))))
  expect_no_error(preset(fig, colors = list(footnotes = c(text = "red"))))
  expect_no_error(
    preset(fig, alignment = list(title_halign = "left"))
  )

  # table-only surface knobs + style templates are rejected
  expect_error(
    preset(fig, fonts = list(body = c(size = 9))),
    class = "tabular_error_input"
  )
  expect_error(
    preset(fig, colors = list(body = c(text = "red"))),
    class = "tabular_error_input"
  )
  expect_error(
    preset(fig, fonts = list(subgroup = c(size = 9))),
    class = "tabular_error_input"
  )
  expect_error(
    preset(fig, .template = preset_spec()),
    class = "tabular_error_input"
  )
  # rules target the header band a figure lacks
  expect_snapshot(preset(fig, rules = list(midrule = "none")), error = TRUE)
})

test_that("emit() rejects data_file for a figure", {
  fig <- figure(function() plot(1))
  expect_error(
    emit(
      fig,
      withr::local_tempfile(fileext = ".html"),
      data_file = tempfile()
    ),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Chrome text color reaches every backend (#page-chrome)
#
# Guards the figure chrome-styling ungate (5ac864f): a figure carries
# the same chrome surfaces as a table, and `style(color =, .at =
# cells_*())` on each must land in the emitted bytes. The construction
# checks above (`expect_no_error(preset(fig, colors = ...))`) only prove
# the knob is accepted, not that the colour reaches output -- this is the
# output-level assertion that ungate should have shipped. Each surface
# carries a DISTINCT colour so a leak to the wrong surface is detectable.
# ---------------------------------------------------------------------

# Map a "#rrggbb" colour to its 1-based `\cf` index in the RTF colour
# table (`{\colortbl;\red..\green..\blue..;...}`). Not an assertion
# wrapper -- just resolves the index the run should reference.
.cf_index_for <- function(rtf, rgb_token) {
  ct <- regmatches(rtf, regexpr("[{]\\\\colortbl[^}]*[}]", rtf))
  entries <- strsplit(ct, ";", fixed = TRUE)[[1]]
  match(TRUE, grepl(rgb_token, entries, fixed = TRUE)) - 1L
}

.figure_chrome_color_spec <- function() {
  figure(function() plot(1:5), titles = "T", footnotes = "FN") |>
    preset(pagehead = list(left = "PH"), pagefoot = list(left = "PF")) |>
    style(color = "#FF0000", .at = cells_pagehead(slot = "left")) |>
    style(color = "#00AA00", .at = cells_pagefoot()) |>
    style(color = "#0000FF", .at = cells_title()) |>
    style(color = "#CC00CC", .at = cells_footnotes())
}

test_that("figure chrome text color reaches RTF header/footer (#page-chrome)", {
  f <- withr::local_tempfile(fileext = ".rtf")
  emit(.figure_chrome_color_spec(), f)
  rtf <- paste(readLines(f, warn = FALSE), collapse = "\n")

  # Every surface colour is registered in the colour table.
  expect_true(grepl("\\red255\\green0\\blue0", rtf, fixed = TRUE)) # pagehead
  expect_true(grepl("\\red0\\green170\\blue0", rtf, fixed = TRUE)) # pagefoot
  expect_true(grepl("\\red0\\green0\\blue255", rtf, fixed = TRUE)) # title
  expect_true(grepl("\\red204\\green0\\blue204", rtf, fixed = TRUE)) # footnote

  hdr <- regmatches(
    rtf,
    regexpr("[{]\\\\header[\\s\\S]*?\\n[}]", rtf, perl = TRUE)
  )
  ftr <- regmatches(
    rtf,
    regexpr("[{]\\\\footer[\\s\\S]*?\\n[}]", rtf, perl = TRUE)
  )

  # pagehead red is applied in {\header}; pagefoot green + footnote
  # magenta are applied in {\footer}.
  ph <- sprintf("\\cf%d", .cf_index_for(rtf, "\\red255\\green0\\blue0"))
  pf <- sprintf("\\cf%d", .cf_index_for(rtf, "\\red0\\green170\\blue0"))
  fn <- sprintf("\\cf%d", .cf_index_for(rtf, "\\red204\\green0\\blue204"))
  expect_true(grepl(ph, hdr, fixed = TRUE))
  expect_true(grepl(pf, ftr, fixed = TRUE))
  expect_true(grepl(fn, ftr, fixed = TRUE))
})

test_that("figure chrome text color reaches LaTeX / HTML / DOCX (#page-chrome)", {
  # LaTeX: \textcolor[HTML]{RRGGBB} (uppercase, no leading #).
  ftex <- withr::local_tempfile(fileext = ".tex")
  emit(.figure_chrome_color_spec(), ftex)
  tex <- paste(readLines(ftex, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\textcolor[HTML]{FF0000}", tex, fixed = TRUE))
  expect_true(grepl("\\textcolor[HTML]{00AA00}", tex, fixed = TRUE))
  expect_true(grepl("\\textcolor[HTML]{0000FF}", tex, fixed = TRUE))
  expect_true(grepl("\\textcolor[HTML]{CC00CC}", tex, fixed = TRUE))

  # HTML: inline `color: #RRGGBB`.
  fhtml <- withr::local_tempfile(fileext = ".html")
  emit(.figure_chrome_color_spec(), fhtml)
  html <- paste(readLines(fhtml, warn = FALSE), collapse = "\n")
  expect_true(grepl("color: #FF0000", html, fixed = TRUE))
  expect_true(grepl("color: #00AA00", html, fixed = TRUE))
  expect_true(grepl("color: #0000FF", html, fixed = TRUE))
  expect_true(grepl("color: #CC00CC", html, fixed = TRUE))

  # DOCX: <w:color w:val="RRGGBB"> across document + header/footer parts.
  fdocx <- withr::local_tempfile(fileext = ".docx")
  emit(.figure_chrome_color_spec(), fdocx)
  xdir <- withr::local_tempdir()
  utils::unzip(fdocx, exdir = xdir)
  parts <- list.files(
    file.path(xdir, "word"),
    pattern = "\\.xml$",
    full.names = TRUE
  )
  docx <- paste(
    vapply(
      parts,
      function(p) paste(readLines(p, warn = FALSE), collapse = "\n"),
      character(1L)
    ),
    collapse = "\n"
  )
  expect_true(grepl('w:color w:val="FF0000"', docx, fixed = TRUE))
  expect_true(grepl('w:color w:val="00AA00"', docx, fixed = TRUE))
  expect_true(grepl('w:color w:val="0000FF"', docx, fixed = TRUE))
  expect_true(grepl('w:color w:val="CC00CC"', docx, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Preview methods (as.tags / knit_print / print)
# ---------------------------------------------------------------------

test_that("as.tags.figure_spec yields an embeddable tagList", {
  skip_if_not_installed("htmltools")
  fig <- figure(
    test_path("fixtures", "fig-sample.png"),
    titles = "Figure 14.1.1"
  )
  tg <- htmltools::as.tags(fig)
  expect_s3_class(tg, "shiny.tag.list")
  html <- as.character(tg)
  expect_true(grepl("data:image/png;base64,", html, fixed = TRUE))
  expect_true(grepl("id=\"tabular-", html, fixed = TRUE))
  expect_true(grepl("Figure 14.1.1", html, fixed = TRUE))
})

test_that("pkgdown print path returns a browsable tag list", {
  skip_if_not_installed("htmltools")
  withr::local_envvar(IN_PKGDOWN = "true")
  fig <- figure(test_path("fixtures", "fig-sample.png"))
  out <- tabular:::.figure_spec_print(fig)
  expect_true(isTRUE(attr(out, "browsable_html")))
})

test_that("figure cli summary reports source kind, placement, titles", {
  fig <- figure(
    function() plot(1),
    titles = c("Figure 14.1.1", "Sub"),
    footnotes = "fn",
    halign = "right",
    valign = "top"
  )
  expect_snapshot(tabular:::.figure_spec_print_cli(fig))
})

test_that("knit_print.figure_spec emits a raw-html asis block", {
  skip_if_not_installed("htmltools")
  skip_if_not_installed("knitr")
  fig <- figure(test_path("fixtures", "fig-sample.png"))
  kp <- tabular:::.spec_knit_print(fig)
  expect_s3_class(kp, "knit_asis")
  expect_true(grepl("data:image/png;base64,", as.character(kp), fixed = TRUE))
})

test_that("figure print routes through Databricks displayHTML when detected", {
  skip_if_not_installed("htmltools")
  fig <- figure(test_path("fixtures", "fig-sample.png"))
  testthat::local_mocked_bindings(.is_databricks = function() TRUE)
  shown <- NULL
  # rlang::exec("displayHTML", html) resolves the name off the search path.
  assign("displayHTML", function(html) shown <<- html, envir = globalenv())
  withr::defer(rm("displayHTML", envir = globalenv()))
  tabular:::.figure_spec_print(fig, view = FALSE)
  expect_true(is.character(shown) && nzchar(shown))
})

test_that("figure print renders HTML, and a broken render falls back to cli", {
  skip_if_not_installed("htmltools")
  fig <- figure(test_path("fixtures", "fig-sample.png"))
  # success path: prints the HTML tags (browse = FALSE, no browser)
  expect_invisible(
    withr::with_output_sink(
      withr::local_tempfile(),
      tabular:::.figure_spec_print(fig, view = FALSE)
    )
  )
  # error path: as.tags throws -> warn + cli structural summary
  testthat::local_mocked_bindings(
    as.tags = function(...) stop("boom"),
    .package = "htmltools"
  )
  expect_warning(
    suppressMessages(tabular:::.figure_spec_print(fig, view = FALSE)),
    "HTML preview failed"
  )
})

test_that("figure_spec S7 validator guards every prop (defence in depth)", {
  # The figure() verb validates first, so these exercise the S7 validator
  # directly via raw construction with one bad prop at a time.
  fs <- tabular:::figure_spec
  expect_error(fs(source_kind = "bogus"), "source_kind")
  expect_error(fs(halign = "bogus"), "halign")
  expect_error(fs(valign = "bogus"), "valign")
  expect_error(fs(dpi = -1), "dpi")
  expect_error(fs(width = -1), "width")
  expect_error(fs(height = 0), "height")
})

test_that("figure cli summary truncates long titles and reports a preset", {
  fs <- tabular:::figure_spec(
    source_kind = "function",
    plots = list(function() NULL),
    titles = strrep("Long enrollment figure title ", 4),
    footnotes = "fn",
    preset = preset_spec(font_size = 8)
  )
  expect_snapshot(tabular:::.figure_spec_print_cli(fs))
})

test_that(".figure_box reserves wrapped chrome lines so footnotes fit (#26)", {
  # A long footnote wraps to several physical lines at the printable width.
  # The box must reserve by rendered lines, not element count, or it is too
  # tall and the wrapped overflow pushes a DOCX figure footnote (which flows
  # in the body) onto a second page.
  long_fn <- paste(
    "Note: Progression-free survival (PFS) is calculated from the date of",
    "first dose to the date of disease progression or death, whichever",
    "occurs first. Estimated with the Kaplan-Meier method; tick marks",
    "denote censored observations; shaded band is the 95% CI."
  )

  # The wrapped-line counter sees more than one line for the long footnote.
  geom <- tabular:::.figure_box(
    figure(function() NULL, footnotes = long_fn)
  )
  expect_gt(
    tabular:::.wrapped_line_count(
      long_fn,
      preset_spec(),
      geom$printable_w_in
    ),
    1L
  )

  # A figure with the long footnote reserves more chrome, so its body box
  # is SHORTER than one with a one-line footnote (regression: both used to
  # reserve a single row, leaving the long-footnote box identically tall).
  short_box <- tabular:::.figure_box(
    figure(function() NULL, footnotes = "Note: short.")
  )
  long_box <- tabular:::.figure_box(
    figure(function() NULL, footnotes = long_fn)
  )
  expect_lt(long_box$box_h_in, short_box$box_h_in)
})

test_that(".wrapped_line_count counts a short block as one line per element", {
  # Default-figure invariant: short titles / footnotes wrap to one line
  # each, so the reserved height is unchanged from the element count.
  expect_identical(
    tabular:::.wrapped_line_count(character(0), preset_spec(), 9),
    0L
  )
  expect_identical(
    tabular:::.wrapped_line_count(
      c("Figure 14.1.1", "Subjects Enrolled"),
      preset_spec(),
      9
    ),
    2L
  )
  # Embedded "\n" breaks expand to separate physical lines.
  expect_identical(
    tabular:::.wrapped_line_count("line one\nline two", preset_spec(), 9),
    2L
  )
  # An empty element still counts as one line (strsplit("") is length 0).
  expect_identical(
    tabular:::.wrapped_line_count("", preset_spec(), 9),
    1L
  )
})
