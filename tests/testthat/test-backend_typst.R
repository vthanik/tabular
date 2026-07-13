# backend_typst() — native #table Typst backend.
#
# The backend self-registers at package-load time. Until the emit()
# dispatch lands, these tests render through the internal writer with a
# grid resolved at format = "typst" (native pagination, like LaTeX).

# Helper: render a spec to a typ string in one shot.
render_typ <- function(spec) {
  grid <- tabular:::.resolve_spec_to_grid(spec, format = "typst")
  out <- withr::local_tempfile(fileext = ".typ")
  tabular:::backend_typst(grid, out)
  paste(readLines(out), collapse = "\n")
}

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("typst backend is registered at package load", {
  expect_true(tabular:::.has_backend("typst"))
})

test_that("typst is a native-pagination format", {
  expect_true("typst" %in% tabular:::.native_pagination_formats)
})

# ---------------------------------------------------------------------
# End-to-end document shape
# ---------------------------------------------------------------------

test_that("backend_typst writes a non-empty standalone .typ file", {
  txt <- render_typ(tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  ))
  expect_match(txt, "#set page(", fixed = TRUE)
  expect_match(txt, "#set text(font: (", fixed = TRUE)
  expect_match(txt, "#table(", fixed = TRUE)
  expect_match(txt, "table.header(", fixed = TRUE)
  expect_match(txt, "table.footer(", fixed = TRUE)
})

test_that("backend_typst renders cdisc_saf_demo golden pipeline end to end", {
  spec <- tabular(
    cdisc_saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    cols(
      variable = col_spec(label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    ) |>
    group_rows(by = "variable")
  txt <- render_typ(spec)
  expect_match(txt, "Demographics", fixed = TRUE)
  # `\n` in col labels becomes ` \ ` (typst linebreak).
  expect_match(txt, "Placebo \\ N\\=86", fixed = TRUE)
  expect_match(txt, "Source: ADSL.", fixed = TRUE)
  # Group headers are full-span bold cells.
  expect_match(txt, "colspan: 5", fixed = TRUE)
  expect_match(txt, "#strong[Age (years)]", fixed = TRUE)
})

test_that("golden .typ source is stable (snapshot)", {
  spec <- tabular(
    cdisc_saf_demo,
    titles = c("Table 14.1.1", "Demographics"),
    footnotes = "Source: ADSL."
  ) |>
    cols(
      variable = col_spec(label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    ) |>
    group_rows(by = "variable")
  grid <- tabular:::.resolve_spec_to_grid(spec, format = "typst")
  expect_snapshot(
    cat(tabular:::.render_typst_doc(grid), sep = "\n")
  )
})

# ---------------------------------------------------------------------
# Prelude (preset-driven)
# ---------------------------------------------------------------------

test_that("default prelude uses preset defaults", {
  txt <- render_typ(tabular(data.frame(x = 1L)))
  expect_match(txt, "paper: \"us-letter\",", fixed = TRUE)
  expect_match(txt, "flipped: true,", fixed = TRUE)
  expect_match(txt, "margin: 1in,", fixed = TRUE)
  expect_match(txt, "size: 10pt", fixed = TRUE)
  expect_match(
    txt,
    "top-edge: 0.84em, bottom-edge: -0.36em",
    fixed = TRUE
  )
  expect_match(txt, "#set par(leading: 0em)", fixed = TRUE)
  expect_match(txt, "#set block(spacing: 0pt)", fixed = TRUE)
})

test_that("prelude honours paper, orientation, and margins", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      paper_size = "a4",
      orientation = "portrait",
      margins = c(0.5, 1)
    )
  txt <- render_typ(spec)
  expect_match(txt, "paper: \"a4\",", fixed = TRUE)
  expect_no_match(txt, "flipped: true", fixed = TRUE)
  expect_match(
    txt,
    "margin: (top: 0.5in, bottom: 0.5in, left: 1in, right: 1in),",
    fixed = TRUE
  )
})

test_that("prelude resolves the font chain with the typst tail", {
  txt <- render_typ(
    tabular(data.frame(x = 1L)) |> preset(font_family = "mono")
  )
  expect_match(
    txt,
    paste0(
      "#set text(font: (\"Courier New\", \"Courier\", \"Liberation Mono\", ",
      "\"DejaVu Sans Mono\",), size: 10pt,"
    ),
    fixed = TRUE
  )
})

test_that(".typst_paper maps the three common sizes and passes others", {
  expect_identical(tabular:::.typst_paper("letter"), "us-letter")
  expect_identical(tabular:::.typst_paper("legal"), "us-legal")
  expect_identical(tabular:::.typst_paper("a4"), "a4")
  expect_identical(tabular:::.typst_paper("a3"), "a3")
})

test_that(".typst_margin_dict expands the CSS shorthand", {
  expect_identical(tabular:::.typst_margin_dict(1), "1in")
  expect_identical(
    tabular:::.typst_margin_dict(c("2cm", "1cm")),
    "(top: 2cm, bottom: 2cm, left: 1cm, right: 1cm)"
  )
  expect_identical(
    tabular:::.typst_margin_dict(c(1, 2, 3, 4)),
    "(top: 1in, right: 2in, bottom: 3in, left: 4in)"
  )
})

# ---------------------------------------------------------------------
# Page chrome bands
# ---------------------------------------------------------------------

test_that("page bands emit header/footer grids with page tokens", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      ),
      pagefoot = list(left = "Program: t_demo.R")
    )
  txt <- render_typ(spec)
  expect_match(txt, "header: context [", fixed = TRUE)
  expect_match(txt, "footer: context [", fixed = TRUE)
  expect_match(txt, "columns: (1fr, 1fr, 1fr),", fixed = TRUE)
  expect_match(txt, "Protocol: ABC\\-123", fixed = TRUE)
  expect_match(txt, "#counter(page).display()", fixed = TRUE)
  expect_match(txt, "#counter(page).final().first()", fixed = TRUE)
})

test_that("no page bands -> no header/footer page args", {
  txt <- render_typ(tabular(data.frame(x = 1L)))
  expect_no_match(txt, "header: context", fixed = TRUE)
  expect_no_match(txt, "footer: context", fixed = TRUE)
})

test_that(".typst_resolve_page_tokens swaps the escaped tokens", {
  out <- tabular:::.typst_resolve_page_tokens(
    "Page \\{page\\} of \\{npages\\}"
  )
  expect_identical(
    out,
    "Page #counter(page).display() of #counter(page).final().first()"
  )
  expect_identical(tabular:::.typst_resolve_page_tokens("plain"), "plain")
})

# ---------------------------------------------------------------------
# Header block: titles, bands, labels
# ---------------------------------------------------------------------

test_that("titles repeat inside table.header by default", {
  txt <- render_typ(tabular(data.frame(x = 1L), titles = c("T1", "T2")))
  expect_match(txt, "repeat: true,", fixed = TRUE)
  expect_match(txt, "#strong[T1] \\ #strong[T2]", fixed = TRUE)
})

test_that("spanner bands emit colspan cells with an inset-trimmed underline", {
  spec <- tabular(data.frame(a = 1L, b = 2L, c = 3L)) |>
    cols(
      a = col_spec(label = "A"),
      b = col_spec(label = "B"),
      c = col_spec(label = "C")
    ) |>
    headers("Group" = c("b", "c"))
  txt <- render_typ(spec)
  expect_match(txt, "colspan: 2", fixed = TRUE)
  expect_match(txt, "#strong[Group]", fixed = TRUE)
  expect_match(txt, "#line(length: 100%, stroke: ", fixed = TRUE)
})

test_that("column labels honour decimal centring and bottom valign", {
  spec <- tabular(data.frame(v = 1.5)) |>
    cols(v = col_spec(label = "Value", align = "decimal"))
  txt <- render_typ(spec)
  expect_match(txt, "align: center + bottom)[#strong[Value]]", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Body rows
# ---------------------------------------------------------------------

test_that("indent depth is stripped and re-applied as #pad", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(label = "Char"),
      stat_label = col_spec(label = "Stat"),
      placebo = col_spec(label = "P")
    ) |>
    group_rows(by = "variable")
  txt <- render_typ(spec)
  expect_match(txt, "#pad(left: 12pt)[", fixed = TRUE)
})

test_that("engine-guaranteed single-line cells become non-breaking", {
  spec <- tabular(data.frame(v = "12 (34.5)")) |>
    cols(v = col_spec(label = "N (%)"))
  txt <- render_typ(spec)
  # The interior space is rewritten to `~` (typst NBSP) so metric drift
  # cannot re-wrap a cell the engine sized to fit.
  expect_match(txt, "[12~(34.5)]", fixed = TRUE)
})

test_that("multi-line cell text renders typst linebreaks", {
  spec <- tabular(data.frame(v = "line1\nline2")) |>
    cols(v = col_spec(label = "V"))
  txt <- render_typ(spec)
  expect_match(txt, "line1 \\ line2", fixed = TRUE)
})

test_that("blank separator rows render as hidden-strut spanning cells", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(label = "Char"),
      stat_label = col_spec(label = "Stat"),
      placebo = col_spec(label = "P")
    ) |>
    group_rows(by = "variable")
  txt <- render_typ(spec)
  expect_match(txt, "#hide[X]", fixed = TRUE)
})

test_that("per-cell style overrides emit align / fill / text props", {
  spec <- tabular(data.frame(v = c("a", "b"))) |>
    cols(v = col_spec(label = "V")) |>
    style(
      bold = TRUE,
      italic = TRUE,
      color = "#ff0000",
      background = "#eeeeee",
      halign = "right",
      .at = cells_body(i = 1)
    )
  txt <- render_typ(spec)
  expect_match(txt, "#emph[#strong[", fixed = TRUE)
  expect_match(txt, "fill: rgb(\"#ff0000\")", fixed = TRUE)
  expect_match(txt, "fill: rgb(\"#eeeeee\")", fixed = TRUE)
  expect_match(txt, "align: right", fixed = TRUE)
})

test_that("per-cell borders render natively as cell strokes", {
  spec <- tabular(data.frame(v = c("a", "b"))) |>
    cols(v = col_spec(label = "V")) |>
    style(
      border_top = brdr(width = 1, color = "#00ff00"),
      .at = cells_body(i = 2)
    )
  txt <- render_typ(spec)
  expect_match(txt, "stroke: (top: 1pt + rgb(\"#00ff00\")", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Empty states
# ---------------------------------------------------------------------

test_that("zero-row data renders the empty-state message as a body row", {
  spec <- tabular(
    data.frame(v = character(0)),
    titles = "Empty",
    footnotes = "Note."
  ) |>
    cols(v = col_spec(label = "V"))
  txt <- render_typ(spec)
  expect_match(txt, "No data available to report", fixed = TRUE)
  expect_match(txt, "Empty", fixed = TRUE)
  expect_match(txt, "Note.", fixed = TRUE)
})

test_that(".render_typst_empty handles a zero-page grid", {
  grid <- tabular:::tabular_grid(
    pages = list(),
    metadata = list(titles_ast = list(), footnotes_ast = list())
  )
  lines <- tabular:::.render_typst_empty(grid)
  expect_match(
    paste(lines, collapse = "\n"),
    "#align(center)[No data available to report]",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Inline AST + escaping
# ---------------------------------------------------------------------

test_that("inline AST maps every run type to typst markup", {
  ast <- tabular:::.parse_inline(md("**b** *i* `c` [l](https://x.io) plain"))
  out <- tabular:::.render_typst_inline(ast)
  expect_match(out, "#strong[b]", fixed = TRUE)
  expect_match(out, "#emph[i]", fixed = TRUE)
  expect_match(out, "#raw(\"c\")", fixed = TRUE)
  expect_match(out, "#link(\"https://x.io\")[l]", fixed = TRUE)
})

test_that(".typst_escape backslash-escapes every markup special", {
  expect_identical(
    tabular:::.typst_escape("a*b_c#d$e@f<g>h[i]j{k}~l-m+n/o=p`q\\r"),
    "a\\*b\\_c\\#d\\$e\\@f\\<g\\>h\\[i\\]j\\{k\\}\\~l\\-m\\+n\\/o\\=p\\`q\\\\r"
  )
  expect_identical(tabular:::.typst_escape(NULL), "")
  expect_identical(tabular:::.typst_escape(NA_character_), "")
})

test_that(".typst_escape_cell converts newlines and peels footnote markers", {
  expect_identical(
    tabular:::.typst_escape_cell("a\nb", preserve = FALSE),
    "a \\ b"
  )
})

test_that(".typst_escape_str escapes string-literal specials", {
  expect_identical(tabular:::.typst_escape_str('a"b\\c'), "a\\\"b\\\\c")
  expect_identical(tabular:::.typst_escape_str(NULL), "")
})

# ---------------------------------------------------------------------
# Strokes + colours
# ---------------------------------------------------------------------

test_that(".typst_stroke lowers triples to stroke expressions", {
  expect_null(tabular:::.typst_stroke(NULL))
  expect_null(tabular:::.typst_stroke(list(style = "none")))
  expect_identical(
    tabular:::.typst_stroke(list(style = "solid", width = 0.5, color = NULL)),
    "0.5pt"
  )
  expect_identical(
    tabular:::.typst_stroke(
      list(style = "solid", width = 1, color = "#ff0000")
    ),
    "1pt + rgb(\"#ff0000\")"
  )
  expect_identical(
    tabular:::.typst_stroke(
      list(style = "dashed", width = 0.5, color = "#00ff00")
    ),
    "(thickness: 0.5pt, paint: rgb(\"#00ff00\"), dash: \"dashed\")"
  )
  # `double` has no typst dash pattern; degrades to solid.
  expect_identical(
    tabular:::.typst_stroke(list(style = "double", width = 2, color = NULL)),
    "2pt"
  )
})

test_that(".typst_color resolves hex, named, and invalid colours", {
  expect_identical(tabular:::.typst_color("#A1B2C3"), "rgb(\"#A1B2C3\")")
  expect_identical(tabular:::.typst_color("red"), "rgb(\"#ff0000\")")
  expect_identical(tabular:::.typst_color("not-a-colour"), "black")
})

# ---------------------------------------------------------------------
# Columns / alignment / inset
# ---------------------------------------------------------------------

test_that(".typst_columns emits inch widths and auto fallbacks", {
  cols <- list(
    a = col_spec(),
    b = col_spec()
  )
  cols$a@width <- 1.25
  expect_identical(
    tabular:::.typst_columns(c("a", "b"), cols),
    "(1.25in, auto,)"
  )
})

test_that(".typst_cell collapses to bare content with no attributes", {
  expect_identical(tabular:::.typst_cell("x"), "[x]")
  expect_identical(
    tabular:::.typst_cell("x", colspan = 3, fill = "black"),
    "table.cell(colspan: 3, fill: black)[x]"
  )
})

test_that(".typst_cell_fits enforces the engine's fit decision", {
  afm <- tabular:::.resolve_afm_name("mono", bold = FALSE)
  # 6 chars at 10pt Courier = 36pt.
  expect_true(tabular:::.typst_cell_fits("abcdef", 40, afm, 10))
  expect_false(tabular:::.typst_cell_fits("abcdef", 30, afm, 10))
  expect_false(tabular:::.typst_cell_fits("a\nb", 100, afm, 10))
  expect_false(tabular:::.typst_cell_fits("abc", NA_real_, afm, 10))
  expect_false(tabular:::.typst_cell_fits(NA_character_, 40, afm, 10))
})

# ---------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------

test_that("figure grids render #image sidecars with placement glue", {
  png_stub <- as.raw(c(
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x10,
    0x00,
    0x00,
    0x00,
    0x08,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00
  ))
  pg <- list(
    image_bytes = png_stub,
    image_ext = "png",
    draw_w_in = 5,
    draw_h_in = 4,
    titles_ast = list(),
    footnotes_ast = list(),
    place = list(halign = "left", valign = "top")
  )
  block <- tabular:::.typst_figure_image_block(pg, "fig-1.png")
  expect_identical(block[[2L]], "#v(1fr)")
  expect_match(
    block[[1L]],
    "#align(left)[#image(\"fig-1.png\", width: 5in, height: 4in",
    fixed = TRUE
  )
  # bottom / middle variants flip the glue.
  pg$place <- list(halign = "right", valign = "bottom")
  block <- tabular:::.typst_figure_image_block(pg, "fig-1.png")
  expect_identical(block[[1L]], "#v(1fr)")
  pg$place <- list(halign = "center", valign = "middle")
  block <- tabular:::.typst_figure_image_block(pg, "fig-1.png")
  expect_identical(block[[1L]], "#v(1fr)")
  expect_identical(block[[3L]], "#v(1fr)")
})

# ---------------------------------------------------------------------
# Coverage: figure path, subgroup banner, repeat variants, inline runs
# ---------------------------------------------------------------------

test_that("emit(.typ) renders a figure with sidecar, glue, and chrome", {
  skip_if_not_installed("ggplot2")
  fig <- figure(function() plot(1), titles = "Figure 1", footnotes = "fn") |>
    preset(
      pagehead = list(left = "Protocol: X", right = "Page {page} of {npages}")
    )
  f <- withr::local_tempfile(fileext = ".typ")
  suppressMessages(emit(fig, f))
  txt <- paste(readLines(f), collapse = "\n")
  expect_match(txt, "#image(\"", fixed = TRUE)
  expect_match(txt, "#v(1fr)", fixed = TRUE)
  expect_match(txt, "Figure 1", fixed = TRUE)
  expect_match(txt, "fn", fixed = TRUE)
  # The sidecar landed next to the .typ.
  stem <- tools::file_path_sans_ext(basename(f))
  expect_true(
    length(list.files(dirname(f), pattern = paste0(stem, "-fig1"))) == 1L
  )
})

test_that("subgroup banner rides the header block as a spanning cell", {
  spec <- tabular(cdisc_saf_vital) |>
    cols(
      visit = col_spec(label = "Visit"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    subgroup(by = "param")
  txt <- render_typ(spec)
  expect_match(txt, "#pagebreak()", fixed = TRUE)
  expect_match(txt, "Diastolic Blood Pressure", fixed = TRUE)
})

test_that("non-repeating titles emit once before the table", {
  spec <- tabular(data.frame(x = 1L), titles = "Once") |>
    paginate(repeat_content = "headers")
  txt <- render_typ(spec)
  # Title block precedes #table( and no title cell rides the header.
  expect_lt(
    regexpr("#strong[Once]", txt, fixed = TRUE)[[1L]],
    regexpr("#table(", txt, fixed = TRUE)[[1L]]
  )
})

test_that("continuation marker appears on continuation panels", {
  spec <- tabular(
    data.frame(a = 1:3, b = 4:6, c = 7:9, d = 10:12),
    titles = "T"
  ) |>
    cols(
      a = col_spec(label = "A", width = 3),
      b = col_spec(label = "B", width = 3),
      c = col_spec(label = "C", width = 3),
      d = col_spec(label = "D", width = 3)
    ) |>
    paginate(panels = 2, repeat_cols = "a", continuation = "(cont.)")
  txt <- render_typ(spec)
  expect_match(txt, "#emph[(cont.)]", fixed = TRUE)
})

test_that("inline sup, sub, and unknown runs render", {
  ast <- tabular:::inline_ast(
    runs = list(
      list(type = "sup", children = list(list(type = "plain", text = "a"))),
      list(type = "sub", children = list(list(type = "plain", text = "b"))),
      list(type = "newline")
    )
  )
  out <- tabular:::.render_typst_inline(ast)
  expect_match(out, "#super[a]", fixed = TRUE)
  expect_match(out, "#sub[b]", fixed = TRUE)
  expect_match(out, " \\ ", fixed = TRUE)
  # Unknown run types fall through to their escaped text field.
  expect_identical(
    tabular:::.render_typst_run(list(type = "mystery", text = "c*d")),
    "c\\*d"
  )
})

test_that("alignment keyword helpers cover every branch", {
  expect_identical(tabular:::.typst_halign("center"), "center")
  expect_identical(tabular:::.typst_halign("right"), "right")
  expect_identical(tabular:::.typst_halign("junk"), "left")
  expect_identical(tabular:::.typst_valign("middle"), "horizon")
  expect_identical(tabular:::.typst_valign("bottom"), "bottom")
  expect_identical(tabular:::.typst_valign("junk"), "top")
  expect_identical(tabular:::.typst_halign_letterlike(NULL), "left")
  expect_identical(tabular:::.typst_halign_letterlike("right"), "right")
  expect_identical(tabular:::.typst_halign_letterlike("junk"), "left")
})

test_that(".typst_chrome_stroke falls back to the SSOT rule width", {
  expect_identical(
    tabular:::.typst_chrome_stroke(chrome_style(), "header_top"),
    "0.5pt"
  )
})

test_that(".typst_prelude defaults a missing preset", {
  lines <- tabular:::.typst_prelude(preset = NULL)
  expect_match(paste(lines, collapse = "\n"), "#set page(", fixed = TRUE)
})

test_that(".typst_wrap_text_props passes through non-scalar text", {
  expect_identical(tabular:::.typst_wrap_text_props(1L, NULL), 1L)
  # Chrome-surface font overrides emit one #text() wrapper.
  node <- tabular:::style_node(font_size = 7, font_family = "Inter")
  out <- tabular:::.typst_wrap_text_props("x", node)
  expect_match(out, "#text(size: 7pt, font: (\"Inter\",))[x]", fixed = TRUE)
})

test_that("nested group keys indent the inner group-header rows", {
  df <- data.frame(
    outer = c("A", "A", "B"),
    inner = c("a1", "a2", "b1"),
    lbl = c("r1", "r2", "r3"),
    v = c(1, 2, 3)
  )
  spec <- tabular(df) |>
    cols(lbl = col_spec(label = "Row"), v = col_spec(label = "V")) |>
    group_rows(by = c("outer", "inner"))
  txt <- render_typ(spec)
  # Inner header cell carries the band-depth #pad indent.
  expect_match(txt, "#pad(left: ", fixed = TRUE)
})

test_that(".render_typst_body_rows handles a zero-row matrix", {
  out <- tabular:::.render_typst_body_rows(
    matrix(character(), nrow = 0L, ncol = 2L)
  )
  expect_identical(out$lines, character())
  expect_identical(out$n_rows, 0L)
})

test_that(".typst_escape_cell handles NULL and preserves whitespace runs", {
  expect_identical(tabular:::.typst_escape_cell(NULL), "")
  expect_identical(
    tabular:::.typst_escape_cell("a  b", preserve = TRUE),
    "a~ b"
  )
})

test_that("header background and padding reach the column-label cells", {
  # The band spanner cells already carry `fill:`; the column-label row
  # dropped both the header surface background and its padding, so
  # `preset(colors = list(header = ...))` / `padding = list(header = ...)`
  # (and the equivalent style() at cells_headers()) were silent no-ops
  # on typst while RTF / HTML / LaTeX / DOCX honoured them.
  spec <- tabular(data.frame(v = "1")) |>
    cols(v = col_spec(label = "V")) |>
    preset(
      colors = list(header = c(background = "#dddddd")),
      padding = list(header = c(top = 6, bottom = 6))
    )
  txt <- render_typ(spec)
  labels_row <- grep("[#strong[V]]", strsplit(txt, "\n")[[1L]], fixed = TRUE)
  expect_length(labels_row, 1L)
  row <- strsplit(txt, "\n")[[1L]][labels_row]
  expect_match(row, "fill: rgb(\"#dddddd\")", fixed = TRUE)
  expect_match(row, "inset: (top: 6pt, bottom: 6pt)", fixed = TRUE)
})

test_that("preset(whitespace = 'collapse') folds 2+ space runs in body cells", {
  # The no-wrap hardening rewrites every remaining space to `~` before
  # typst's native markup folding can collapse a run, so the collapse
  # must happen at the escape chokepoint — otherwise "collapse" was a
  # silent no-op on typst while RTF / HTML / LaTeX / MD all honoured it.
  expect_identical(
    tabular:::.typst_escape_cell("a  spaced  cell", preserve = FALSE),
    "a spaced cell"
  )
  spec <- tabular(data.frame(lbl = c("a  spaced  cell", "b"))) |>
    cols(lbl = col_spec(label = "L")) |>
    preset(whitespace = "collapse")
  txt <- render_typ(spec)
  expect_match(txt, "a~spaced~cell", fixed = TRUE)
  expect_no_match(txt, "a~~spaced~~cell", fixed = TRUE)
})

test_that("body rows-between rules interleave hlines", {
  spec <- tabular(data.frame(v = c("a", "b", "c"))) |>
    cols(v = col_spec(label = "V")) |>
    preset(rules = list(rowrule = brdr("thin")))
  txt <- render_typ(spec)
  expect_gte(
    length(gregexpr("table.hline", txt, fixed = TRUE)[[1L]]),
    4L
  )
})

test_that("outer frame edges emit table-level vlines", {
  spec <- tabular(data.frame(v = c("a", "b"))) |>
    cols(v = col_spec(label = "V")) |>
    preset(rules = "frame")
  txt <- render_typ(spec)
  expect_match(txt, "table.vline(x: 0,", fixed = TRUE)
  expect_match(txt, "table.vline(x: 1,", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Body-anchored page bands, page-centred table, keep-with-next
# ---------------------------------------------------------------------

test_that("page bands anchor to the body edges, not fixed page positions", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(
      pagehead = list(left = "Protocol: ABC-123"),
      pagefoot = list(left = "Program: t_demo.R")
    )
  txt <- render_typ(spec)
  # RTF/DOCX/LaTeX parity (font 10, line pitch 12): the header band's
  # bottom edge sits exactly ON the top-margin line (ascent = 0) and
  # the footer's first baseline ON the bottom-margin line (descent =
  # -top_edge = -8.4pt), instead of typst's margin-proportional
  # default.
  expect_match(txt, "header-ascent: 0pt,", fixed = TRUE)
  expect_match(txt, "footer-descent: -8.4pt,", fixed = TRUE)
  # The header bottom-aligns in the top margin (rows grow upward from
  # the body edge); the footer top-aligns (rows grow downward).
  expect_match(txt, "#align(bottom)[", fixed = TRUE)
  expect_match(txt, "#align(top)[", fixed = TRUE)
})

test_that("no page bands -> no ascent/descent overrides", {
  txt <- render_typ(tabular(data.frame(x = 1L)))
  expect_no_match(txt, "header-ascent", fixed = TRUE)
  expect_no_match(txt, "footer-descent", fixed = TRUE)
})

test_that("the table centres on the page like the other backends", {
  txt <- render_typ(tabular(data.frame(x = 1L)))
  expect_match(txt, "#align(center)[#table(", fixed = TRUE)
})

test_that("paginate(keep_together) emits unbreakable rowspans in a hidden 0pt column", {
  spec <- tabular(cdisc_saf_vital) |>
    cols(
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50"),
      drug_100 = col_spec(label = "Drug 100"),
      paramcd = col_spec(visible = FALSE)
    ) |>
    group_rows(by = c("param", "visit"), display = "section") |>
    paginate(keep_together = "visit")
  txt <- render_typ(spec)
  expect_match(txt, "columns: (0pt, ", fixed = TRUE)
  expect_match(txt, "table.cell(rowspan: ", fixed = TRUE)
  expect_match(txt, "breakable: false", fixed = TRUE)
})

test_that("keep-free tables emit no hidden keep column", {
  txt <- render_typ(tabular(data.frame(x = 1:3)))
  expect_no_match(txt, "columns: (0pt", fixed = TRUE)
  expect_no_match(txt, "breakable: false", fixed = TRUE)
})

test_that(".typst_keep_leads maps the keep mask to rowspan lead cells", {
  leads <- tabular:::.typst_keep_leads(
    c(TRUE, TRUE, FALSE, FALSE, TRUE),
    5L
  )
  expect_identical(
    leads,
    c(
      "table.cell(rowspan: 3, breakable: false)[], ",
      "",
      "",
      "[], ",
      # A trailing TRUE has no next row to glue to -> solo.
      "[], "
    )
  )
  # NULL / all-FALSE masks mean no hidden column: every lead empty.
  expect_identical(tabular:::.typst_keep_leads(NULL, 3L), rep("", 3L))
  expect_identical(
    tabular:::.typst_keep_leads(c(FALSE, FALSE), 2L),
    rep("", 2L)
  )
})

test_that("outer frame vlines shift right of the hidden keep column", {
  spec <- tabular(cdisc_saf_vital) |>
    cols(
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50"),
      drug_100 = col_spec(label = "Drug 100"),
      paramcd = col_spec(visible = FALSE)
    ) |>
    group_rows(by = c("param", "visit"), display = "section") |>
    paginate(keep_together = "visit") |>
    preset(rules = "frame")
  txt <- render_typ(spec)
  # 4 visible columns + the hidden keep column: outer edges at x = 1
  # and x = 5, never x = 0 (the hidden track's outer boundary).
  expect_match(txt, "table.vline(x: 1,", fixed = TRUE)
  expect_match(txt, "table.vline(x: 5,", fixed = TRUE)
  expect_no_match(txt, "table.vline(x: 0,", fixed = TRUE)
})
