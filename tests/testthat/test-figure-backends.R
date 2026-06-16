# test-figure-backends.R — per-backend figure rendering across all five
# media. The byte-stable PNG fixture is the figure input so embedded image
# bytes / base64 / hex are deterministic.

png_fixture <- function() test_path("fixtures", "fig-sample.png")
jpg_fixture <- function() test_path("fixtures", "fig-sample.jpg")
fixture_bytes <- function() {
  readBin(png_fixture(), "raw", file.info(png_fixture())$size)
}

basic_figure <- function(...) {
  figure(
    png_fixture(),
    titles = c("Figure 14.1.1", "Enrollment"),
    footnotes = "N = 254.",
    ...
  )
}

# ---------------------------------------------------------------------
# as_grid figure shape
# ---------------------------------------------------------------------

test_that("as_grid() resolves a figure to a one-page figure grid", {
  g <- as_grid(basic_figure())
  expect_equal(g@metadata$content_type, "figure")
  expect_equal(g@metadata$total_pages, 1L)
  expect_length(g@pages, 1L)
  pg <- g@pages[[1L]]
  expect_true(isTRUE(pg$is_figure_page))
  expect_equal(pg$image_ext, "png")
  expect_identical(pg$image_bytes, fixture_bytes())
  expect_length(g@metadata$titles_ast, 2L)
})

test_that("file input preserves the intrinsic aspect ratio", {
  # fixture is 120x90 px (4:3); auto-fit keeps that ratio
  g <- as_grid(figure(png_fixture()))
  pg <- g@pages[[1L]]
  expect_equal(pg$draw_w_in / pg$draw_h_in, 120 / 90, tolerance = 0.02)
})

# ---------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------

test_that("HTML figure embeds a deterministic data-URI image", {
  out <- withr::local_tempfile(fileext = ".html")
  emit(basic_figure(halign = "right", valign = "top"), out)
  h <- paste(readLines(out), collapse = "\n")

  b64 <- tabular:::.base64_encode_raw(fixture_bytes())
  expect_true(grepl(paste0("data:image/png;base64,", b64), h, fixed = TRUE))
  expect_true(grepl("class=\"tabular-figure\"", h, fixed = TRUE))
  expect_true(grepl("justify-content:flex-end", h, fixed = TRUE)) # right
  expect_true(grepl("max-width:100%", h, fixed = TRUE)) # responsive, contained
  expect_true(grepl("Figure 14.1.1", h, fixed = TRUE))
  expect_true(grepl("N = 254.", h, fixed = TRUE))
  expect_true(grepl("<!DOCTYPE html>", h, fixed = TRUE))
})

# ---------------------------------------------------------------------
# RTF
# ---------------------------------------------------------------------

test_that("RTF figure embeds a \\pict with placement tokens", {
  out <- withr::local_tempfile(fileext = ".rtf")
  emit(basic_figure(halign = "center", valign = "middle"), out)
  r <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_true(grepl("\\pict\\pngblip", r, fixed = TRUE))
  expect_true(grepl("\\picwgoal", r, fixed = TRUE))
  expect_true(grepl("\\qc", r, fixed = TRUE)) # center
  expect_true(grepl("\\clvertalc", r, fixed = TRUE)) # middle
  expect_true(grepl("\\trrh-", r, fixed = TRUE)) # exact box height
  # native pixel dims parsed from the fixture (120 x 90)
  expect_true(grepl("\\picw120\\pich90", r, fixed = TRUE))
})

# ---------------------------------------------------------------------
# LaTeX (+ sidecar)
# ---------------------------------------------------------------------

test_that("LaTeX figure writes a sidecar and references it", {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(basic_figure(halign = "left", valign = "bottom"), out)
  tex <- paste(readLines(out), collapse = "\n")

  # A file (PNG) input passes through, so the sidecar keeps its .png ext;
  # only plot inputs rasterise to a vector .pdf sidecar for LaTeX.
  stem <- tools::file_path_sans_ext(basename(out))
  sidecar <- file.path(dirname(out), sprintf("%s-fig1.png", stem))
  expect_true(file.exists(sidecar))
  expect_true(grepl("\\includegraphics", tex, fixed = TRUE))
  expect_true(grepl(sprintf("%s-fig1.png", stem), tex, fixed = TRUE))
  # valign bottom -> a leading \vfill pushes the image down (the image is
  # placed with flexible \vfill glue, not a fixed-height minipage that could
  # overflow the page); halign left -> \raggedright.
  expect_true(grepl("\\vfill", tex, fixed = TRUE))
  expect_false(grepl("\\begin{minipage}[c][", tex, fixed = TRUE))
  expect_true(grepl("\\raggedright", tex, fixed = TRUE))
  unlink(sidecar)
})

test_that("LaTeX figure places the image with \\vfill glue, not a fixed-height box", {
  # Regression for the per-arm KM PDF overflow (one figure per arm rendered
  # two physical pages each): a fixed-height minipage reconstructed to almost
  # exactly \textheight and tipped over. \vfill glue absorbs the slack.
  top <- withr::local_tempfile(fileext = ".tex")
  emit(basic_figure(valign = "top"), top)
  ttop <- paste(readLines(top), collapse = "\n")
  # valign top -> image then a trailing \vfill (footnotes ride the bottom).
  expect_match(ttop, "\\par}\n\\vfill", fixed = TRUE)
  expect_no_match(ttop, "\\begin{minipage}[c][", fixed = TRUE)

  mid <- withr::local_tempfile(fileext = ".tex")
  emit(basic_figure(valign = "middle"), mid)
  tmid <- paste(readLines(mid), collapse = "\n")
  # valign middle -> \vfill image \vfill (image centred, footnotes bottom).
  expect_match(tmid, "\\vfill\n{\\noindent\\centering", fixed = TRUE)
})

test_that("LaTeX rasterises a plot input to a vector PDF sidecar", {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(figure(function() plot(1:5), titles = "Plot"), out)
  stem <- tools::file_path_sans_ext(basename(out))
  sidecar <- file.path(dirname(out), sprintf("%s-fig1.pdf", stem))
  expect_true(file.exists(sidecar))
  expect_equal(
    rawToChar(readBin(sidecar, "raw", 5L)),
    "%PDF-"
  )
  unlink(sidecar)
})

# ---------------------------------------------------------------------
# Markdown (+ sidecar)
# ---------------------------------------------------------------------

test_that("Markdown figure writes a sidecar PNG and an image ref", {
  out <- withr::local_tempfile(fileext = ".md")
  emit(basic_figure(halign = "right"), out)
  md <- paste(readLines(out), collapse = "\n")

  stem <- tools::file_path_sans_ext(basename(out))
  sidecar <- file.path(dirname(out), sprintf("%s-fig1.png", stem))
  expect_true(file.exists(sidecar))
  expect_identical(
    readBin(sidecar, "raw", file.info(sidecar)$size),
    fixture_bytes()
  )
  expect_true(grepl("![Figure](", md, fixed = TRUE))
  expect_true(grepl("<div align=\"right\">", md, fixed = TRUE))
  unlink(sidecar)
})

test_that("Markdown left halign is a bare image (no div wrapper)", {
  out <- withr::local_tempfile(fileext = ".md")
  emit(basic_figure(halign = "left"), out)
  md <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("![Figure](", md, fixed = TRUE))
  expect_false(grepl("<div align", md, fixed = TRUE))
  unlink(list.files(
    dirname(out),
    pattern = "-fig1\\.png$",
    full.names = TRUE
  ))
})

# ---------------------------------------------------------------------
# DOCX — binary media + DrawingML
# ---------------------------------------------------------------------

test_that("DOCX figure embeds media, rels, content-type, DrawingML", {
  out <- withr::local_tempfile(fileext = ".docx")
  emit(basic_figure(halign = "right", valign = "bottom"), out)

  ex <- withr::local_tempdir()
  utils::unzip(out, exdir = ex)
  files <- list.files(ex, recursive = TRUE)

  expect_true("word/media/image1.png" %in% files)
  expect_identical(
    readBin(
      file.path(ex, "word/media/image1.png"),
      "raw",
      file.info(file.path(ex, "word/media/image1.png"))$size
    ),
    fixture_bytes()
  )

  ct <- paste(readLines(file.path(ex, "[Content_Types].xml")), collapse = "")
  expect_true(grepl(
    "Extension=\"png\" ContentType=\"image/png\"",
    ct,
    fixed = TRUE
  ))

  rels <- paste(
    readLines(file.path(ex, "word/_rels/document.xml.rels")),
    collapse = ""
  )
  expect_true(grepl(
    "relationships/image\" Target=\"media/image1.png\"",
    rels,
    fixed = TRUE
  ))

  doc <- paste(readLines(file.path(ex, "word/document.xml")), collapse = "")
  expect_true(grepl("<w:drawing>", doc, fixed = TRUE))
  expect_true(grepl("<a:blip r:embed=", doc, fixed = TRUE))
  expect_true(grepl("<wp:extent cx=", doc, fixed = TRUE))
  expect_true(grepl("<w:vAlign w:val=\"bottom\"/>", doc, fixed = TRUE))
  expect_true(grepl("<w:jc w:val=\"right\"/>", doc, fixed = TRUE))
  expect_true(grepl("w:hRule=\"exact\"", doc, fixed = TRUE))
})

test_that("every DOCX figure part is well-formed XML", {
  out <- withr::local_tempfile(fileext = ".docx")
  emit(basic_figure(), out)
  ex <- withr::local_tempdir()
  utils::unzip(out, exdir = ex)
  parts <- list.files(ex, pattern = "\\.(xml|rels)$", recursive = TRUE)
  for (p in parts) {
    expect_no_error(xml2::read_xml(file.path(ex, p)))
  }
})

# ---------------------------------------------------------------------
# Placement matrix
# ---------------------------------------------------------------------

test_that("HTML placement maps halign to justify-content (valign no-op)", {
  # HTML is continuous and responsive: the image is contained to its own
  # space (no fixed page box), so valign has no meaning -- only halign maps.
  jmap <- c(left = "flex-start", center = "center", right = "flex-end")
  for (h in names(jmap)) {
    out <- withr::local_tempfile(fileext = ".html")
    emit(basic_figure(halign = h), out)
    doc <- paste(readLines(out), collapse = "\n")
    fig_div <- regmatches(
      doc,
      regexpr("<div class=\"tabular-figure\"[^>]*>", doc)
    )
    expect_true(grepl(
      paste0("justify-content:", jmap[[h]]),
      fig_div,
      fixed = TRUE
    ))
    expect_false(grepl("align-items", fig_div, fixed = TRUE))
    expect_true(grepl("max-width:100%", doc, fixed = TRUE))
  }
})

test_that("DOCX placement maps valign to vAlign and halign to jc", {
  vmap <- c(top = "top", middle = "center", bottom = "bottom")
  for (v in names(vmap)) {
    out <- withr::local_tempfile(fileext = ".docx")
    emit(basic_figure(valign = v), out)
    ex <- withr::local_tempdir()
    utils::unzip(out, exdir = ex)
    doc <- paste(readLines(file.path(ex, "word/document.xml")), collapse = "")
    expect_true(grepl(
      sprintf("<w:vAlign w:val=\"%s\"/>", vmap[[v]]),
      doc,
      fixed = TRUE
    ))
  }
})

# ---------------------------------------------------------------------
# Multi-page (mixed list)
# ---------------------------------------------------------------------

test_that("a mixed multi-page list emits one page per element", {
  fig <- figure(
    list(png_fixture(), function() plot(1:3)),
    titles = "Two pages"
  )

  # HTML: 2 images
  oh <- withr::local_tempfile(fileext = ".html")
  emit(fig, oh)
  hh <- paste(readLines(oh), collapse = "\n")
  expect_equal(
    length(gregexpr("data:image/png;base64,", hh)[[1L]]),
    2L
  )

  # RTF: 2 \pict, 2 sections
  orr <- withr::local_tempfile(fileext = ".rtf")
  emit(fig, orr)
  rr <- paste(readLines(orr, warn = FALSE), collapse = "\n")
  expect_equal(length(gregexpr("\\pict", rr, fixed = TRUE)[[1L]]), 2L)
  expect_equal(length(gregexpr("\\sbkpage", rr, fixed = TRUE)[[1L]]), 2L)

  # DOCX: 2 media images, 2 drawings, 1 page break
  od <- withr::local_tempfile(fileext = ".docx")
  emit(fig, od)
  ex <- withr::local_tempdir()
  utils::unzip(od, exdir = ex)
  f2 <- list.files(ex, recursive = TRUE)
  expect_equal(sum(grepl("word/media/image", f2)), 2L)
  doc <- paste(readLines(file.path(ex, "word/document.xml")), collapse = "")
  expect_equal(length(gregexpr("<w:drawing>", doc, fixed = TRUE)[[1L]]), 2L)
  expect_equal(
    length(gregexpr("w:type=\"page\"", doc, fixed = TRUE)[[1L]]),
    1L
  )
})

test_that("per-page meta tokens resolve into each page's chrome", {
  meta <- data.frame(arm = c("Placebo", "Active"), stringsAsFactors = FALSE)
  fig <- figure(
    list(png_fixture(), png_fixture()),
    titles = "Enrollment: {arm}",
    meta = meta
  )
  g <- as_grid(fig)
  t1 <- tabular:::.render_md_inline(g@pages[[1L]]$titles_ast[[1L]])
  t2 <- tabular:::.render_md_inline(g@pages[[2L]]$titles_ast[[1L]])
  expect_equal(t1, "Enrollment: Placebo")
  expect_equal(t2, "Enrollment: Active")
})

# ---------------------------------------------------------------------
# Shared chrome renders once on the continuous backends (HTML / MD).
# A multi-page figure without `meta` carries identical titles / footnotes
# on every page; on a continuous medium that chrome must render once, like
# a table, not once per plot. Supplying `meta` switches back to per-page.
# ---------------------------------------------------------------------

test_that("multi-page figure renders shared chrome once on HTML", {
  fig <- figure(
    list(png_fixture(), function() plot(1:3)),
    titles = c("Figure 14.1.2", "Enrollment by Arm"),
    footnotes = "N = 254."
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(fig, out)
  h <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # one caption wraps the whole multi-page figure (was one per plot)
  expect_equal(length(gregexpr("<figcaption", h, fixed = TRUE)[[1L]]), 1L)
  # body-only chrome lines render once (the first title line also rides
  # <head><title>, so assert on lines that never appear in <head>)
  expect_equal(
    length(gregexpr("Enrollment by Arm", h, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(length(gregexpr("N = 254.", h, fixed = TRUE)[[1L]]), 1L)
  # both plots still render
  expect_equal(
    length(gregexpr("data:image/png;base64,", h, fixed = TRUE)[[1L]]),
    2L
  )
})

test_that("multi-page figure renders shared chrome once on Markdown", {
  fig <- figure(
    list(png_fixture(), png_fixture()),
    titles = c("Figure 14.1.2", "Enrollment by Arm"),
    footnotes = "N = 254."
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(fig, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  stem <- tools::file_path_sans_ext(basename(out))
  sidecars <- file.path(dirname(out), sprintf("%s-fig%d.png", stem, 1:2))
  withr::defer(unlink(sidecars))

  expect_equal(length(gregexpr("Figure 14.1.2", md, fixed = TRUE)[[1L]]), 1L)
  expect_equal(
    length(gregexpr("Enrollment by Arm", md, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(length(gregexpr("N = 254.", md, fixed = TRUE)[[1L]]), 1L)
  # both sidecar images still referenced
  expect_equal(length(gregexpr("![Figure](", md, fixed = TRUE)[[1L]]), 2L)
})

test_that("multi-page figure with meta keeps per-page chrome on HTML", {
  fig <- figure(
    list(png_fixture(), png_fixture()),
    titles = c("Figure 14.1.2", "Enrollment {arm}"),
    meta = data.frame(
      arm = c("placebo", "drug_50"),
      stringsAsFactors = FALSE
    )
  )
  out <- withr::local_tempfile(fileext = ".html")
  emit(fig, out)
  h <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # meta => per-page captions retained: two captions, one per page
  expect_equal(length(gregexpr("<figcaption", h, fixed = TRUE)[[1L]]), 2L)
  # each page's interpolated line appears once
  expect_equal(
    length(gregexpr("Enrollment placebo", h, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(
    length(gregexpr("Enrollment drug_50", h, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(
    length(gregexpr("data:image/png;base64,", h, fixed = TRUE)[[1L]]),
    2L
  )
})

test_that("multi-page figure with meta keeps per-page chrome on Markdown", {
  fig <- figure(
    list(png_fixture(), png_fixture()),
    titles = c("Figure 14.1.2", "Enrollment {arm}"),
    meta = data.frame(
      arm = c("placebo", "drug_50"),
      stringsAsFactors = FALSE
    )
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(fig, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  stem <- tools::file_path_sans_ext(basename(out))
  sidecars <- file.path(dirname(out), sprintf("%s-fig%d.png", stem, 1:2))
  withr::defer(unlink(sidecars))

  # per-page: the shared first line repeats, each token line appears once
  expect_equal(length(gregexpr("Figure 14.1.2", md, fixed = TRUE)[[1L]]), 2L)
  expect_equal(
    length(gregexpr("Enrollment placebo", md, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(
    length(gregexpr("Enrollment drug_50", md, fixed = TRUE)[[1L]]),
    1L
  )
  expect_equal(length(gregexpr("![Figure](", md, fixed = TRUE)[[1L]]), 2L)
})

# ---------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------

test_that("figure manifest carries Title -> Figure -> Footnote + x-tabular", {
  skip_if_not_installed("yaml")
  out <- withr::local_tempfile(fileext = ".html")
  emit(
    basic_figure(halign = "right", valign = "bottom"),
    out,
    manifest = TRUE
  )
  ypath <- paste0(tools::file_path_sans_ext(out), ".audit.yml")
  expect_true(file.exists(ypath))
  y <- yaml::read_yaml(ypath)

  sects <- vapply(
    y$displays[[1L]]$display$displaySections,
    function(s) s$sectionType,
    character(1L)
  )
  expect_equal(sects, c("Title", "Figure", "Footnote"))

  fb <- y$`x-tabular`$figure
  expect_equal(fb$sourceKind, "file")
  expect_equal(fb$pages, 1L)
  expect_equal(fb$halign, "right")
  expect_equal(fb$valign, "bottom")
  expect_null(y$`x-tabular`$styles)
})

# ---------------------------------------------------------------------
# PDF (real compile, gated off CRAN + win-builder farm)
# ---------------------------------------------------------------------

test_that("PDF figure compiles through xelatex", {
  skip_on_cran()
  skip_if_not_installed("tinytex")
  skip_if_not(nzchar(Sys.which("xelatex")) || tinytex::is_tinytex())
  out <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(emit(basic_figure(), out))
  expect_true(file.exists(out))
  hdr <- readBin(out, "raw", 5L)
  expect_equal(rawToChar(hdr), "%PDF-")
})

test_that("figure with a long wrapped footnote still compiles to one page (#26)", {
  # Regression for the PHUSE acceptance finding: a multi-line wrapped
  # footnote (and tall figure) used to push a figure onto a second page.
  # The wrapped-line reservation (.wrapped_line_count) sizes the box so the
  # whole figure plus chrome fits exactly one physical page. Verified by a
  # real xelatex compile + page count (poppler's pdfinfo).
  skip_on_cran()
  skip_if_not_installed("tinytex")
  skip_if_not(nzchar(Sys.which("xelatex")) || tinytex::is_tinytex())
  skip_if_not(nzchar(Sys.which("pdfinfo")))
  long_foot <- paste(
    rep(
      paste(
        "This is a deliberately long footnote sentence that wraps across",
        "several physical lines when typeset at the body font size."
      ),
      3L
    ),
    collapse = " "
  )
  fig <- figure(
    png_fixture(),
    titles = c("Figure 14.1.1", "Enrollment"),
    footnotes = long_foot
  )
  out <- withr::local_tempfile(fileext = ".pdf")
  emit(fig, out)
  info <- system2("pdfinfo", out, stdout = TRUE)
  pages <- as.integer(sub(".*:\\s*", "", info[grepl("^Pages", info)]))
  expect_equal(pages, 1L)
})

# ---------------------------------------------------------------------
# Inter-section spacing gaps reach figure chrome (Part 1)
# ---------------------------------------------------------------------

# A figure whose plot is the byte-stable PNG fixture, with title +
# footnote so both spacing surfaces are exercised.
spaced_figure <- function(...) {
  figure(png_fixture(), titles = "Fig title", footnotes = "Fig note", ...)
}

n_html_pad <- function(txt) {
  lengths(regmatches(
    txt,
    gregexpr("<p class=\"tabular-pad\">", txt, fixed = TRUE)
  ))
}
n_latex_pad <- function(txt) {
  lengths(regmatches(txt, gregexpr("{\\strut\\par}", txt, fixed = TRUE)))
}

test_that("preset(spacing=) widens figure title/footnote gaps (HTML)", {
  base <- emit(spaced_figure(), withr::local_tempfile(fileext = ".html"))
  wide <- emit(
    spaced_figure() |>
      preset(
        spacing = list(
          title = c(above = 6, below = 6),
          footnote = c(above = 6)
        )
      ),
    withr::local_tempfile(fileext = ".html")
  )
  base_txt <- paste(readLines(base, warn = FALSE), collapse = "\n")
  wide_txt <- paste(readLines(wide, warn = FALSE), collapse = "\n")
  # default: 1 above + 1 below title + 0 above footnote = 2 pads
  expect_equal(n_html_pad(base_txt), 2L)
  # widened: 6 + 6 + 6 = 18 pads
  expect_equal(n_html_pad(wide_txt), 18L)
})

test_that("preset(spacing=) widens figure title/footnote gaps (LaTeX)", {
  base <- emit(spaced_figure(), withr::local_tempfile(fileext = ".tex"))
  wide <- emit(
    spaced_figure() |>
      preset(
        spacing = list(
          title = c(above = 4, below = 4),
          footnote = c(above = 4)
        )
      ),
    withr::local_tempfile(fileext = ".tex")
  )
  base_txt <- paste(readLines(base, warn = FALSE), collapse = "\n")
  wide_txt <- paste(readLines(wide, warn = FALSE), collapse = "\n")
  expect_equal(n_latex_pad(base_txt), 2L)
  expect_equal(n_latex_pad(wide_txt), 12L)
})

test_that("subgroup spacing region does NOT move a figure; title does", {
  # A figure has no subgroup banner, so the subgroup gap is inert.
  sg <- emit(
    spaced_figure() |>
      preset(spacing = list(subgroup = c(above = 9, below = 9))),
    withr::local_tempfile(fileext = ".html")
  )
  base <- emit(spaced_figure(), withr::local_tempfile(fileext = ".html"))
  expect_equal(
    n_html_pad(paste(readLines(sg, warn = FALSE), collapse = "\n")),
    n_html_pad(paste(readLines(base, warn = FALSE), collapse = "\n"))
  )
})

test_that("default RTF figure has one blank par above title, one below", {
  out <- emit(spaced_figure(), withr::local_tempfile(fileext = ".rtf"))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  blank <- paste0(
    "\\pard\\plain",
    tabular:::.rtf_body_fs(preset_spec()),
    "\\par"
  )
  n <- lengths(regmatches(txt, gregexpr(blank, txt, fixed = TRUE)))
  # 1 above + 1 below title; footnote pad default 0
  expect_equal(n, 2L)
})

# ---------------------------------------------------------------------
# F1 — figure footnotes ride the RTF footer band
# ---------------------------------------------------------------------

test_that("RTF figure footnotes render in the footer group, not the body", {
  out <- emit(spaced_figure(), withr::local_tempfile(fileext = ".rtf"))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # The footnote text appears inside the {\footer ...} group.
  footer <- regmatches(txt, regexpr("\\{\\\\footer.*", txt))
  expect_match(footer, "Fig note")
})

# ---------------------------------------------------------------------
# F5 — failed-plot guard
# ---------------------------------------------------------------------

test_that("a throwing plot function aborts with a typed, page-named error", {
  fig <- figure(function() stop("draw failure"))
  expect_error(
    emit(fig, withr::local_tempfile(fileext = ".html")),
    class = "tabular_error_input"
  )
  expect_snapshot(
    emit(fig, withr::local_tempfile(fileext = ".html")),
    error = TRUE
  )
})

test_that("the failed-plot error names the offending page index", {
  fig <- figure(list(function() plot(1), function() stop("boom")))
  err <- tryCatch(
    emit(fig, withr::local_tempfile(fileext = ".html")),
    tabular_error_input = function(e) conditionMessage(e)
  )
  expect_match(err, "figure plot 2")
})
