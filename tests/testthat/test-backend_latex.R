# backend_latex() — tabularray-based LaTeX backend.
#
# The backend self-registers at package-load time, so every test
# here can rely on `tabular:::.has_backend("latex")` returning
# TRUE without setup.

# Helper: render a spec to a tex string in one shot.
render_tex <- function(spec) {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  paste(readLines(out), collapse = "\n")
}

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("latex backend is registered at package load", {
  expect_true(tabular:::.has_backend("latex"))
})

# ---------------------------------------------------------------------
# End-to-end via emit()
# ---------------------------------------------------------------------

test_that("emit(.tex) writes a non-empty self-contained .tex file", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  txt <- render_tex(spec)
  expect_match(txt, "\\documentclass", fixed = TRUE)
  expect_match(txt, "\\usepackage{tabularray}", fixed = TRUE)
  expect_match(txt, "\\begin{document}", fixed = TRUE)
  expect_match(txt, "\\begin{longtblr}", fixed = TRUE)
  expect_match(txt, "\\end{document}", fixed = TRUE)
})

test_that("emit(.tex) renders saf_demo golden pipeline end to end", {
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Demographics", fixed = TRUE)
  # `\n` in col labels becomes ` \\ ` (LaTeX in-cell line break).
  expect_match(txt, "Placebo \\\\ N=86", fixed = TRUE)
  expect_match(txt, "Source: ADSL.", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Preamble (preset-driven)
# ---------------------------------------------------------------------

test_that("default preamble uses preset defaults", {
  txt <- render_tex(tabular(data.frame(x = 1L)))
  # Default preset: font_size=9 -> 10pt class option, paper=letter.
  expect_match(txt, "\\documentclass[10pt]{article}", fixed = TRUE)
  expect_match(
    txt,
    "\\usepackage[letterpaper, margin=1in]{geometry}",
    fixed = TRUE
  )
  expect_match(txt, "\\usepackage{tabularray}", fixed = TRUE)
  expect_match(txt, "\\usepackage{hyperref}", fixed = TRUE)
  expect_match(txt, "\\UseTblrLibrary{siunitx}", fixed = TRUE)
})

test_that("preset font_size drives \\documentclass option", {
  spec_11 <- tabular(data.frame(x = 1L)) |> preset(font_size = 11)
  spec_12 <- tabular(data.frame(x = 1L)) |> preset(font_size = 12)
  spec_14 <- tabular(data.frame(x = 1L)) |> preset(font_size = 14)
  expect_match(
    render_tex(spec_11),
    "\\documentclass[11pt]{article}",
    fixed = TRUE
  )
  expect_match(
    render_tex(spec_12),
    "\\documentclass[12pt]{article}",
    fixed = TRUE
  )
  expect_match(
    render_tex(spec_14),
    "\\documentclass[12pt]{article}",
    fixed = TRUE
  )
  expect_match(render_tex(spec_14), "\\fontsize{14}", fixed = TRUE)
})

test_that("preset orientation = 'landscape' surfaces in geometry opts", {
  spec <- tabular(data.frame(x = 1L)) |> preset(orientation = "landscape")
  expect_match(render_tex(spec), "landscape", fixed = TRUE)
})

test_that("preset paper_size drives geometry paper keyword", {
  spec_a4 <- tabular(data.frame(x = 1L)) |> preset(paper_size = "a4")
  spec_letter <- tabular(data.frame(x = 1L)) |> preset(paper_size = "letter")
  expect_match(render_tex(spec_a4), "a4paper", fixed = TRUE)
  expect_match(render_tex(spec_letter), "letterpaper", fixed = TRUE)
})

test_that("preset margins length 1 -> uniform margin=Nin", {
  spec <- tabular(data.frame(x = 1L)) |> preset(margins = 0.75)
  expect_match(render_tex(spec), "margin=0.75in", fixed = TRUE)
})

test_that("preset margins length 2 -> CSS vertical/horizontal shorthand", {
  spec <- tabular(data.frame(x = 1L)) |> preset(margins = c(1, 0.5))
  txt <- render_tex(spec)
  expect_match(txt, "top=1in", fixed = TRUE)
  expect_match(txt, "bottom=1in", fixed = TRUE)
  expect_match(txt, "left=0.5in", fixed = TRUE)
  expect_match(txt, "right=0.5in", fixed = TRUE)
})

test_that("preset margins length 4 -> CSS top/right/bottom/left shorthand", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(margins = c(1, 0.5, 1.25, 0.75))
  txt <- render_tex(spec)
  expect_match(txt, "top=1in", fixed = TRUE)
  expect_match(txt, "right=0.5in", fixed = TRUE)
  expect_match(txt, "bottom=1.25in", fixed = TRUE)
  expect_match(txt, "left=0.75in", fixed = TRUE)
})

test_that("preset rejects margins of length 3 or 5", {
  expect_error(preset_spec(margins = c(1, 0.5, 1)))
  expect_error(preset_spec(margins = c(1, 0.5, 1, 0.5, 1)))
})

test_that("preset rejects negative or NA margins", {
  expect_error(preset_spec(margins = -1))
  expect_error(preset_spec(margins = NA_real_))
})

test_that("preset font_family Times maps to mathptmx under pdftex", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(font_family = "Times New Roman")
  txt <- render_tex(spec)
  expect_match(txt, "\\usepackage{mathptmx}", fixed = TRUE)
  expect_match(txt, "\\setmainfont{Times New Roman}", fixed = TRUE)
})

test_that("preset font_family Helvetica maps to helvet under pdftex", {
  spec <- tabular(data.frame(x = 1L)) |> preset(font_family = "Helvetica")
  expect_match(render_tex(spec), "\\usepackage{helvet}", fixed = TRUE)
})

test_that(".latex_class_size buckets font sizes into 10/11/12 pt", {
  expect_identical(tabular:::.latex_class_size(8), "10pt")
  expect_identical(tabular:::.latex_class_size(10), "10pt")
  expect_identical(tabular:::.latex_class_size(11), "11pt")
  expect_identical(tabular:::.latex_class_size(12), "12pt")
  expect_identical(tabular:::.latex_class_size(14), "12pt")
  expect_identical(tabular:::.latex_class_size(NULL), "11pt")
})

test_that(".latex_pdftex_font_pkg maps known families and skips unknown", {
  expect_identical(
    tabular:::.latex_pdftex_font_pkg("Times New Roman"),
    "mathptmx"
  )
  expect_identical(tabular:::.latex_pdftex_font_pkg("Helvetica"), "helvet")
  expect_identical(tabular:::.latex_pdftex_font_pkg("Arial"), "helvet")
  expect_identical(tabular:::.latex_pdftex_font_pkg("Courier"), "courier")
  expect_identical(tabular:::.latex_pdftex_font_pkg("Palatino"), "mathpazo")
  expect_identical(tabular:::.latex_pdftex_font_pkg("Wingdings"), "")
})

test_that(".latex_pdftex_font_pkg routes generics to TeX Gyre bundles", {
  expect_identical(tabular:::.latex_pdftex_font_pkg("serif"), "tgtermes")
  expect_identical(tabular:::.latex_pdftex_font_pkg("sans"), "tgheros")
  expect_identical(tabular:::.latex_pdftex_font_pkg("sans-serif"), "tgheros")
  expect_identical(tabular:::.latex_pdftex_font_pkg("mono"), "tgcursor")
  expect_identical(tabular:::.latex_pdftex_font_pkg("monospace"), "tgcursor")
})

test_that("default preset (font_family = 'serif') -> tgtermes + Liberation Serif cascade lead", {
  txt <- render_tex(tabular(data.frame(x = 1L)))
  expect_match(txt, "\\usepackage{tgtermes}", fixed = TRUE)
  # Liberation Serif is the outermost branch of the fontspec cascade
  # (compile-time \IfFontExistsTF picks it first on Linux servers).
  expect_match(
    txt,
    "\\IfFontExistsTF{Liberation Serif}{\\setmainfont{Liberation Serif}}",
    fixed = TRUE
  )
  # Latin Modern Roman is the unconditional inner-most leaf —
  # guaranteed to be present in every LaTeX distribution.
  expect_match(txt, "\\setmainfont{Latin Modern Roman}", fixed = TRUE)
})

test_that("preset(font_family = 'sans') -> tgheros + Liberation Sans cascade lead", {
  txt <- render_tex(
    tabular(data.frame(x = 1L)) |> preset(font_family = "sans")
  )
  expect_match(txt, "\\usepackage{tgheros}", fixed = TRUE)
  expect_match(
    txt,
    "\\IfFontExistsTF{Liberation Sans}{\\setmainfont{Liberation Sans}}",
    fixed = TRUE
  )
  expect_match(txt, "\\setmainfont{Latin Modern Sans}", fixed = TRUE)
})

test_that("preset(font_family = 'mono') -> tgcursor + Liberation Mono cascade lead", {
  txt <- render_tex(
    tabular(data.frame(x = 1L)) |> preset(font_family = "mono")
  )
  expect_match(txt, "\\usepackage{tgcursor}", fixed = TRUE)
  expect_match(
    txt,
    "\\IfFontExistsTF{Liberation Mono}{\\setmainfont{Liberation Mono}}",
    fixed = TRUE
  )
  expect_match(txt, "\\setmainfont{Latin Modern Mono}", fixed = TRUE)
})

test_that("preset(font_family = c('Courier New', 'mono')) takes head for xelatex", {
  txt <- render_tex(
    tabular(data.frame(x = 1L)) |>
      preset(font_family = c("Courier New", "mono"))
  )
  expect_match(txt, "\\setmainfont{Courier New}", fixed = TRUE)
  # pdftex branch reads the head's category via .is_generic_family
  # — "Courier New" isn't generic, so it falls through to the named
  # mapping (Courier -> courier package).
  expect_match(txt, "\\usepackage{courier}", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

test_that("titles render as bold centred paragraphs preserving order", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First", "Second", "Third")
  )
  txt <- render_tex(spec)
  expect_match(txt, "{\\bfseries First}\\par", fixed = TRUE)
  expect_match(txt, "{\\bfseries Second}\\par", fixed = TRUE)
  expect_match(txt, "{\\bfseries Third}\\par", fixed = TRUE)
  expect_match(txt, "\\begin{center}", fixed = TRUE)
})

test_that("footnotes render in small font with \\par separators", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c("Foot A", "Foot B")
  )
  txt <- render_tex(spec)
  expect_match(txt, "Foot A\\par", fixed = TRUE)
  expect_match(txt, "Foot B\\par", fixed = TRUE)
  expect_match(txt, "\\noindent\\small", fixed = TRUE)
})

test_that("no titles -> no \\begin{center}; no footnotes -> no \\small", {
  spec <- tabular(data.frame(x = 1L))
  txt <- render_tex(spec)
  expect_false(grepl("\\begin{center}", txt, fixed = TRUE))
  expect_false(grepl("\\noindent\\small", txt, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Inline AST rendering
# ---------------------------------------------------------------------

test_that("bold / italic / code map to \\textbf / \\textit / \\texttt", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
      md("**Bold title**"),
      md("*italic title*"),
      md("`code title`")
    )
  )
  txt <- render_tex(spec)
  expect_match(txt, "\\textbf{Bold title}", fixed = TRUE)
  expect_match(txt, "\\textit{italic title}", fixed = TRUE)
  expect_match(txt, "\\texttt{code title}", fixed = TRUE)
})

test_that("sup / sub / link map to \\textsuperscript / \\textsubscript / \\href", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(
      md("^a^ Marker"),
      md("~sub~ Marker"),
      md("[link](https://example.com)")
    )
  )
  txt <- render_tex(spec)
  expect_match(txt, "\\textsuperscript{a}", fixed = TRUE)
  expect_match(txt, "\\textsubscript{sub}", fixed = TRUE)
  expect_match(txt, "\\href{https://example.com}{link}", fixed = TRUE)
})

test_that("embedded \\n in cell text becomes LaTeX in-cell line break", {
  spec <- tabular(data.frame(x = "line1\nline2"), titles = "T")
  txt <- render_tex(spec)
  expect_match(txt, "line1 \\\\ line2", fixed = TRUE)
})

# ---------------------------------------------------------------------
# LaTeX escaping
# ---------------------------------------------------------------------

test_that(".latex_escape handles all 10 LaTeX special characters", {
  expect_identical(tabular:::.latex_escape("a & b"), "a \\& b")
  expect_identical(tabular:::.latex_escape("100%"), "100\\%")
  expect_identical(tabular:::.latex_escape("$x"), "\\$x")
  expect_identical(tabular:::.latex_escape("a#b"), "a\\#b")
  expect_identical(tabular:::.latex_escape("a_b"), "a\\_b")
  expect_identical(tabular:::.latex_escape("a{b}"), "a\\{b\\}")
  expect_identical(tabular:::.latex_escape("a~b"), "a\\textasciitilde{}b")
  expect_identical(tabular:::.latex_escape("x^2"), "x\\textasciicircum{}2")
  expect_identical(tabular:::.latex_escape("a\\b"), "a\\textbackslash{}b")
  expect_identical(tabular:::.latex_escape(NA_character_), "")
  expect_identical(tabular:::.latex_escape(NULL), "")
  expect_identical(tabular:::.latex_escape(character()), "")
})

test_that(".latex_escape_cell adds in-cell line break for \\n", {
  expect_identical(tabular:::.latex_escape_cell("a\nb"), "a \\\\ b")
  expect_identical(tabular:::.latex_escape_cell("a\r\nb"), "a \\\\ b")
  expect_identical(tabular:::.latex_escape_cell("a&b\nc"), "a\\&b \\\\ c")
  expect_identical(tabular:::.latex_escape_cell(NA_character_), "")
  expect_identical(tabular:::.latex_escape_cell(NULL), "")
})

test_that(".latex_escape_url passes through URL-safe chars", {
  expect_identical(
    tabular:::.latex_escape_url("https://example.com/x?a=1&b=2"),
    "https://example.com/x?a=1&b=2"
  )
  expect_identical(
    tabular:::.latex_escape_url("https://x.com/100%off"),
    "https://x.com/100\\%off"
  )
  expect_identical(
    tabular:::.latex_escape_url("https://x.com/page#sec"),
    "https://x.com/page\\#sec"
  )
})

test_that("ampersand, dollar, percent in cells escape into LaTeX", {
  spec <- tabular(data.frame(x = c("a & b", "$100", "100%", "{}")))
  txt <- render_tex(spec)
  expect_match(txt, "a \\& b", fixed = TRUE)
  expect_match(txt, "\\$100", fixed = TRUE)
  expect_match(txt, "100\\%", fixed = TRUE)
  expect_match(txt, "\\{\\}", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Alignment column specs
# ---------------------------------------------------------------------

test_that(".latex_align_token maps every align value", {
  expect_identical(tabular:::.latex_align_token("left"), "Q[l]")
  expect_identical(tabular:::.latex_align_token("center"), "Q[c]")
  expect_identical(tabular:::.latex_align_token("right"), "Q[r]")
  expect_identical(tabular:::.latex_align_token("decimal"), "Q[r]")
  expect_identical(tabular:::.latex_align_token(NA_character_), "Q[l]")
  expect_identical(tabular:::.latex_align_token(NULL), "Q[l]")
  expect_identical(tabular:::.latex_align_token("garbage"), "Q[l]")
})

test_that("col_spec align surfaces in the colspec={...} arg", {
  spec <- tabular(data.frame(L = "x", C = "x", R = "x", D = "x")) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
    )
  txt <- render_tex(spec)
  expect_match(txt, "colspec={Q[l] Q[c] Q[r] Q[r]}", fixed = TRUE)
})

test_that("col_spec width numeric -> Q[align,wd=Nin]", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(x = col_spec(width = 2.5), y = col_spec(width = 1))
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=2.5in] Q[l,wd=1in]", fixed = TRUE)
})

test_that("col_spec width character with unit -> Q[align,wd=Xunit]", {
  spec <- tabular(data.frame(x = "a", y = "b", z = "c")) |>
    cols(
      x = col_spec(width = "2cm"),
      y = col_spec(width = "60mm"),
      z = col_spec(width = "30pt")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=2cm]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=60mm]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=30pt]", fixed = TRUE)
})

test_that("col_spec width percent -> X[weight,align] proportional", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(x = col_spec(width = "30%"), y = col_spec(width = "70%"))
  txt <- render_tex(spec)
  expect_match(txt, "X[0.3,l] X[0.7,l]", fixed = TRUE)
})

test_that("col_spec width respects align letter", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(
      x = col_spec(align = "right", width = "1in"),
      y = col_spec(align = "center", width = "20%")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Q[r,wd=1in]", fixed = TRUE)
  expect_match(txt, "X[0.2,c]", fixed = TRUE)
})

test_that("col_spec width rejects bad units / negative / >100%", {
  expect_error(col_spec(width = -1), class = "tabular_error_input")
  expect_error(col_spec(width = "5em"), class = "tabular_error_input")
  expect_error(col_spec(width = "10px"), class = "tabular_error_input")
  expect_error(col_spec(width = "150%"), class = "tabular_error_input")
  expect_error(col_spec(width = "nonsense"), class = "tabular_error_input")
})

test_that("col_spec width NA -> bare Q[align] (auto-fit)", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(x = col_spec(width = NA_real_), y = col_spec())
  txt <- render_tex(spec)
  expect_match(txt, "Q[l] Q[l]", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Multi-level headers (real \SetCell colspan)
# ---------------------------------------------------------------------

test_that("header bands emit as \\SetCell[c=N]{c}", {
  spec <- tabular(
    data.frame(
      grp = "x",
      placebo = "1",
      active_low = "2",
      active_high = "3"
    )
  ) |>
    headers("Treatment Arm" = c("placebo", "active_low", "active_high"))
  txt <- render_tex(spec)
  expect_match(txt, "\\SetCell[c=3]{c} Treatment Arm", fixed = TRUE)
})

test_that(".group_contiguous_runs preserves order and handles NA", {
  out <- tabular:::.group_contiguous_runs(c("A", "A", NA, NA, "B"))
  expect_length(out, 3L)
  expect_identical(out[[1L]], list(value = "A", length = 2L))
  expect_true(is.na(out[[2L]]$value))
  expect_identical(out[[2L]]$length, 2L)
  expect_identical(out[[3L]], list(value = "B", length = 1L))
})

test_that(".group_contiguous_runs handles single-element and empty inputs", {
  expect_identical(tabular:::.group_contiguous_runs(character()), list())
  expect_identical(
    tabular:::.group_contiguous_runs("only"),
    list(list(value = "only", length = 1L))
  )
})

# ---------------------------------------------------------------------
# longtblr arg list + rowhead bookkeeping
# ---------------------------------------------------------------------

test_that("rowhead = bands + 1 so headers repeat across page breaks", {
  spec <- tabular(
    data.frame(grp = "x", a = "1", b = "2", c = "3")
  ) |>
    headers("Band A" = c("a", "b"), "Band B" = "c")
  txt <- render_tex(spec)
  expect_match(txt, "rowhead=2", fixed = TRUE)
})

test_that("no headers -> rowhead = 1 (only col-labels row)", {
  spec <- tabular(data.frame(x = 1L, y = 2L))
  txt <- render_tex(spec)
  expect_match(txt, "rowhead=1", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------

test_that("multi-page emit separates pages with \\newpage", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L)
  txt <- render_tex(spec)
  expect_match(txt, "\\newpage", fixed = TRUE)
})

test_that("continuation marker renders as italic noindent on pages 2+", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp", continuation = "(continued)") |>
    preset(font_size = 24L)
  txt <- render_tex(spec)
  expect_match(txt, "\\noindent\\textit{(continued)}", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Edge: zero-row data + empty grid
# ---------------------------------------------------------------------

test_that("empty grid renders titles + (no rows) marker + footnotes", {
  fake <- tabular_grid(
    pages = list(),
    metadata = list(
      titles_ast = list(parse_inline("Title")),
      footnotes_ast = list(parse_inline("Foot"))
    )
  )
  txt <- paste(tabular:::.render_latex_doc(fake), collapse = "\n")
  expect_match(txt, "Title", fixed = TRUE)
  expect_match(txt, "Foot", fixed = TRUE)
  expect_match(txt, "\\emph{(no rows)}", fixed = TRUE)
})

test_that("zero-row spec renders the longtblr with no body rows", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  txt <- render_tex(spec)
  expect_match(txt, "\\begin{longtblr}", fixed = TRUE)
  expect_match(txt, "x & y \\\\", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Renderer fallbacks
# ---------------------------------------------------------------------

test_that(".render_latex_inline returns '' on non-inline_ast input", {
  expect_identical(tabular:::.render_latex_inline("not an ast"), "")
})

test_that(".render_latex_run falls through to (escaped) text for unknown types", {
  fake_run <- list(type = "totally_unknown_type", text = "fall_back")
  expect_identical(
    tabular:::.render_latex_run(fake_run),
    "fall\\_back"
  )
})

test_that(".render_latex_run handles span (drops wrapper, keeps children)", {
  ast <- parse_inline(html("<span style='color:red'>red</span>"))
  expect_identical(tabular:::.render_latex_inline(ast), "red")
})

test_that(".render_latex_children returns '' on empty children list", {
  expect_identical(tabular:::.render_latex_children(list()), "")
})

test_that(".render_latex_col_labels_row falls back to column name on missing AST", {
  out <- tabular:::.render_latex_col_labels_row(
    col_labels_ast = list(),
    col_names_visible = c("x", "y"),
    cols = list()
  )
  expect_identical(out, "x & y \\\\")
})

test_that("backend_latex() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".tex")
  tabular:::backend_latex(grid, out)
  expect_true(file.exists(out))
  expect_match(
    paste(readLines(out), collapse = "\n"),
    "\\begin{longtblr}",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline
# ---------------------------------------------------------------------

test_that("saf_demo golden pipeline matches the pinned .tex snapshot", {
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "Demographics", "Safety Population"),
    footnotes = "Source: ADSL."
  ) |>
    cols(
      variable = col_spec(usage = "group", label = "Characteristic"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo\nN=86", align = "decimal"),
      drug_50 = col_spec(label = "Low Dose\nN=96", align = "decimal"),
      drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
      Total = col_spec(label = "Total\nN=254", align = "decimal")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  expect_snapshot_file(out, "saf_demo_golden.tex")
})

# ---------------------------------------------------------------------
# Page bands — fancyhdr + lastpage
# ---------------------------------------------------------------------

test_that("empty pagehead / pagefoot does not load fancyhdr", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("fancyhdr", tex, fixed = TRUE))
  expect_false(grepl("pagestyle{fancy}", tex, fixed = TRUE))
})

test_that("populated pagehead loads fancyhdr + lastpage and sets \\fancyhead[L/C/R]", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\usepackage{fancyhdr}", tex, fixed = TRUE))
  expect_true(grepl("\\usepackage{lastpage}", tex, fixed = TRUE))
  expect_true(grepl("\\pagestyle{fancy}", tex, fixed = TRUE))
  expect_true(grepl("\\fancyhead[L]{", tex, fixed = TRUE))
  expect_true(grepl("\\fancyhead[R]{", tex, fixed = TRUE))
  # {page} / {npages} resolved to LaTeX field equivalents
  expect_true(grepl("\\thepage", tex, fixed = TRUE))
  expect_true(grepl("\\pageref{LastPage}", tex, fixed = TRUE))
  # {page} as a literal must be gone
  expect_false(grepl("{page}", tex, fixed = TRUE))
})

test_that("multi-row pagehead REVERSES order (body-edge row last) inside slot text", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(left = c("Body edge", "Far row"))
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Far row\\\\Body edge", tex, fixed = TRUE))
})

test_that("multi-row pagefoot keeps FORWARD order (body-edge row first)", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(left = c("Body edge", "Far row"))
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("Body edge\\\\Far row", tex, fixed = TRUE))
})

test_that("headheight bumps when multi-row pagehead is present", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = c("Row 1", "Row 2", "Row 3"),
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\\setlength{\\headheight}", tex, fixed = TRUE))
})
