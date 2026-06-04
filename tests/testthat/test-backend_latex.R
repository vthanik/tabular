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
  expect_match(txt, "Placebo \\\\{} N=86", fixed = TRUE)
  expect_match(txt, "Source: ADSL.", fixed = TRUE)
})

# ---------------------------------------------------------------------
# Preamble (preset-driven)
# ---------------------------------------------------------------------

test_that("default preamble uses preset defaults", {
  txt <- render_tex(tabular(data.frame(x = 1L)))
  # Default preset: font_size=10 -> 10pt class option, paper=letter,
  # orientation=landscape.
  expect_match(txt, "\\documentclass[10pt]{article}", fixed = TRUE)
  expect_match(
    txt,
    "\\usepackage[letterpaper, margin=1in, landscape]{geometry}",
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

test_that("default preset() -> tgcursor + Liberation Mono cascade lead", {
  # The factory default for preset_spec()@font_family is "mono", so a
  # tabular() with no explicit preset() call emits the mono cascade.
  txt <- render_tex(tabular(data.frame(x = 1L)))
  expect_match(txt, "\\usepackage{tgcursor}", fixed = TRUE)
  expect_match(
    txt,
    "\\IfFontExistsTF{Liberation Mono}{\\setmainfont{Liberation Mono}}",
    fixed = TRUE
  )
  expect_match(txt, "\\setmainfont{Latin Modern Mono}", fixed = TRUE)
})

test_that("preset(font_family = 'serif') -> tgtermes + Liberation Serif cascade lead", {
  txt <- render_tex(
    tabular(data.frame(x = 1L)) |> preset(font_family = "serif")
  )
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
  # Centred via a glue-free `{\centering ...}` group (NOT a `center`
  # list environment, which added inter-line vertical gaps).
  expect_match(txt, "{\\centering {\\bfseries First}\\par}", fixed = TRUE)
  expect_no_match(txt, "\\begin{center}", fixed = TRUE)
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
  expect_match(txt, "line1 \\\\{} line2", fixed = TRUE)
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
  expect_identical(tabular:::.latex_escape_cell("a\nb"), "a \\\\{} b")
  expect_identical(tabular:::.latex_escape_cell("a\r\nb"), "a \\\\{} b")
  expect_identical(tabular:::.latex_escape_cell("a&b\nc"), "a\\&b \\\\{} c")
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
  # Auto-default widths now emit Q[<align>,wd=Xin], so we check
  # the align letters individually rather than against a bare
  # `Q[l] Q[c] Q[r] Q[r]` pattern (which only held when widths
  # deferred to backend natural).
  spec <- tabular(data.frame(L = "x", C = "x", R = "x", D = "x")) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=", fixed = TRUE)
  expect_match(txt, "Q[c,wd=", fixed = TRUE)
  # right + decimal both render as Q[r,wd=...].
  expect_match(txt, "Q[r,wd=", fixed = TRUE)
})

test_that("col_spec width numeric -> Q[align,wd=Nin]", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(x = col_spec(width = 2.5), y = col_spec(width = 1))
  txt <- render_tex(spec)
  # Pinned widths pass through verbatim as inches.
  expect_match(txt, "Q[l,wd=2.500000in]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=1.000000in]", fixed = TRUE)
})

test_that("col_spec width character with unit -> resolved inches", {
  # Pre-v0.1.0 backend preserved input units (`wd=2cm`). The
  # engine now resolves all widths to numeric inches before the
  # backend sees them, so character-with-unit converts via
  # `.tabular_unit_inches`: 2cm = 2/2.54 = 0.787402in, 60mm =
  # 60/25.4 = 2.362205in, 30pt = 30/72 = 0.416667in.
  spec <- tabular(data.frame(x = "a", y = "b", z = "c")) |>
    cols(
      x = col_spec(width = "2cm"),
      y = col_spec(width = "60mm"),
      z = col_spec(width = "30pt")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=0.787402in]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=2.362205in]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=0.416667in]", fixed = TRUE)
})

test_that("col_spec width percent -> resolved against available content width", {
  # Pre-v0.1.0 percent emitted tabularray X[weight,align]
  # proportional columns. The engine now resolves percent at
  # render time (30% of available content width = 30% of
  # 6.5in printable area on letter portrait, 1in margins = 1.95in).
  # Backend sees the resolved numeric inches.
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    preset(orientation = "portrait") |>
    cols(x = col_spec(width = "30%"), y = col_spec(width = "70%"))
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=1.950000in]", fixed = TRUE)
  expect_match(txt, "Q[l,wd=4.550000in]", fixed = TRUE)
})

test_that("col_spec width respects align letter", {
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    preset(orientation = "portrait") |>
    cols(
      x = col_spec(align = "right", width = "1in"),
      y = col_spec(align = "center", width = "20%")
    )
  txt <- render_tex(spec)
  expect_match(txt, "Q[r,wd=1.000000in]", fixed = TRUE)
  expect_match(txt, "Q[c,wd=1.300000in]", fixed = TRUE)
})

test_that("col_spec width = 'auto' default produces engine-measured widths", {
  # Long-label column gets noticeably wider than short-label
  # column when both default to auto. soc cell text is much
  # longer than the n column.
  spec <- tabular(
    data.frame(
      soc = c("Cardiac disorders", "Skin disorders"),
      n = c("12 (4.7%)", "5 (2.0%)")
    )
  ) |>
    cols(soc = col_spec(), n = col_spec())
  txt <- render_tex(spec)
  # Both columns have a numeric wd= directive.
  expect_match(txt, "Q\\[l,wd=[0-9.]+in\\]")
  # Extract and compare the two widths.
  widths <- as.numeric(regmatches(
    txt,
    gregexpr("(?<=wd=)[0-9.]+(?=in)", txt, perl = TRUE)
  )[[1L]])
  expect_length(widths, 2L)
  # First (soc) wider than second (n).
  expect_true(widths[[1L]] > widths[[2L]])
})

test_that("auto + pinned mix: pinned wins, auto distributes remainder", {
  spec <- tabular(
    data.frame(
      a = "long content here",
      b = "short",
      c = "x"
    )
  ) |>
    cols(b = col_spec(width = 1.5))
  txt <- render_tex(spec)
  expect_match(txt, "Q[l,wd=1.500000in]", fixed = TRUE)
})

test_that("col_spec width rejects bad units / negative / >100%", {
  expect_error(col_spec(width = -1), class = "tabular_error_input")
  # em / rem still rejected: no font-size context at parse time.
  expect_error(col_spec(width = "5em"), class = "tabular_error_input")
  expect_error(col_spec(width = "2rem"), class = "tabular_error_input")
  expect_error(col_spec(width = "150%"), class = "tabular_error_input")
  expect_error(col_spec(width = "nonsense"), class = "tabular_error_input")
})

test_that("default col_spec auto-sizes via AFM (no bare Q[align])", {
  # Pre-v0.1.0: NA width emitted a bare `Q[l]` (backend natural
  # auto-fit). Now the default is `"auto"`, the engine measures
  # via AFM Core 13, and emits a resolved numeric width via
  # `Q[l,wd=Xin]`. Confirm at least one wd= directive appears
  # for a two-column auto-sized spec.
  spec <- tabular(data.frame(x = "a", y = "b")) |>
    cols(x = col_spec(), y = col_spec())
  txt <- render_tex(spec)
  expect_match(txt, "wd=", fixed = TRUE)
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

test_that("multi-page emit is ONE longtblr (native pagination, no \\newpage)", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L)
  txt <- render_tex(spec)
  # Native pagination: tabularray paginates the body, so a single
  # vertical run of rows is ONE longtblr with no manual \newpage.
  expect_equal(
    length(gregexpr("\\begin{longtblr}", txt, fixed = TRUE)[[1L]]),
    1L
  )
  expect_no_match(txt, "\\newpage", fixed = TRUE)
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
  # Header cells carry a per-cell \SetCell{valign=b} (bottom-valign
  # default, HTML parity); non-decimal columns inherit colspec halign.
  expect_match(
    txt,
    "\\SetCell{valign=b} x & \\SetCell{valign=b} y \\\\",
    fixed = TRUE
  )
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
  expect_identical(out, "\\SetCell{valign=b} x & \\SetCell{valign=b} y \\\\")
})

test_that("decimal column header gets \\SetCell{halign=c,valign=b}; non-decimal gets valign only", {
  out <- tabular:::.render_latex_col_labels_row(
    col_labels_ast = list(),
    col_names_visible = c("grp", "n"),
    cols = list(
      grp = col_spec(label = "Group"),
      n = col_spec(label = "N", align = "decimal")
    )
  )
  # Decimal header centres + bottom; non-decimal omits halign (inherits
  # the Q[...] colspec) but still gets the bottom valign default.
  expect_match(out, "\\SetCell{halign=c,valign=b} n", fixed = TRUE)
  expect_match(out, "\\SetCell{valign=b} grp", fixed = TRUE)
  expect_false(grepl("halign=c,valign=b} grp", out, fixed = TRUE))
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

# ---------------------------------------------------------------------
# chrome_style cascade — `style_template() |> style(.at = cells_*())`
# must propagate into the LaTeX output. Each test isolates one chrome
# surface so a regression points at the exact surface that broke.
# ---------------------------------------------------------------------

test_that("style(.at = cells_headers(), color = ...) wraps header band in \\textcolor", {
  template <- style_template() |>
    style(.at = cells_headers(), color = "#cc0000")
  spec <- tabular(data.frame(x = 1:2)) |>
    preset(.style = template)
  tex <- render_tex(spec)
  expect_match(tex, "\\\\textcolor\\[HTML\\]\\{CC0000\\}", fixed = FALSE)
})

test_that("style(.at = cells_title(), halign = 'left') left-aligns the title", {
  template <- style_template() |>
    style(.at = cells_title(), halign = "left")
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demographics"
  ) |>
    preset(.style = template)
  tex <- render_tex(spec)
  # Left alignment via a glue-free `{\raggedright ...}` group (not the
  # `flushleft` list environment, which added vertical gaps).
  expect_match(tex, "\\{\\\\raggedright .*Demographics", fixed = FALSE)
})

test_that("style(.at = cells_footnotes(), italic = TRUE) wraps footnote in \\textit", {
  template <- style_template() |>
    style(.at = cells_footnotes(), italic = TRUE)
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = "Source: ADSL"
  ) |>
    preset(.style = template)
  tex <- render_tex(spec)
  expect_match(tex, "\\\\textit\\{Source: ADSL\\}", fixed = FALSE)
})

test_that("style(.at = cells_title(), blank_above = 3) emits three blank lines before the title", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  tex <- render_tex(spec)
  # Three full-height strut paragraphs pad above the title block
  # (empty strings would collapse to zero height under \parskip=0pt).
  expect_match(
    tex,
    "{\\strut\\par}\n{\\strut\\par}\n{\\strut\\par}",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Change C: cells_indent sidecar -> per-cell \leftskip indent group
# ---------------------------------------------------------------------

test_that("LaTeX emits leftsep+= on data rows but NOT on header rows (Change C)", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c(
      "CARDIAC",
      "Atrial fibrillation with rapid ventricular response",
      "GI",
      "Nausea and vomiting episodes"
    ),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(
        label = "Category",
        indent_by = "indent_level",
        width = "1in"
      ),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Data row PT cells carry a `\leftskip` indent group around the label.
  expect_match(
    tex,
    "\\{\\\\leftskip=[0-9.]+pt\\\\relax [^&]*Atrial",
    perl = TRUE
  )
  # The invalid column key `leftsep+=` never appears (it broke the PDF).
  expect_no_match(tex, "leftsep+=", fixed = TRUE)
  # The depth-0 CARDIAC band header gets no indent group.
  expect_no_match(
    tex,
    "\\{\\\\leftskip=[0-9.]+pt\\\\relax \\\\textbf\\{CARDIAC\\}",
    perl = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: is_header_row / is_blank_row branching in LaTeX
# ---------------------------------------------------------------------

test_that("LaTeX emits \\SetCell[c=N]{l} \\textbf{...} for synthesised header rows (Change D)", {
  df <- data.frame(
    group_label = c(
      "Best Overall Response",
      "Best Overall Response",
      "Objective Response Rate",
      "Objective Response Rate"
    ),
    stat_label = c("CR", "PR", "ORR (CR + PR)", "95% CI"),
    placebo = c("1", "1", "2", "(0.3, 8.1)"),
    drug_50 = c("1", "0", "1", "(0.0, 6.5)"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Eff") |>
    cols(
      group_label = col_spec(usage = "group", group_display = "header_row"),
      stat_label = col_spec(usage = "indent", label = "Response"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # 3 visible columns -> `\SetCell[c=3]{l} \textbf{...}` with 2
  # trailing `&` placeholders for tabularray column-count balance.
  expect_match(
    tex,
    "\\\\SetCell\\[c=3\\]\\{l\\} \\\\textbf\\{Best Overall Response\\} & & \\\\\\\\",
    perl = TRUE
  )
  expect_match(
    tex,
    "\\\\SetCell\\[c=3\\]\\{l\\} \\\\textbf\\{Objective Response Rate\\} & &",
    perl = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: nested band headers render with depth-aware leftsep+=
# ---------------------------------------------------------------------

test_that("LaTeX nested bands: band-1 header bare {l}, band-2 header gets leftsep+= (Change D)", {
  df <- data.frame(
    section = c("Safety", "Safety", "Efficacy", "Efficacy"),
    subsection = c("AE", "AE", "ORR", "ORR"),
    label = c("Any", "SAE", "Confirmed", "Unconfirmed"),
    n = c("100", "10", "20", "15"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Nested") |>
    cols(
      section = col_spec(usage = "group", group_display = "header_row"),
      subsection = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Item"),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Band 1 ("Safety", depth 0) -> `\SetCell[c=2]{l} \textbf{Safety}`.
  expect_match(
    tex,
    "\\\\SetCell\\[c=2\\]\\{l\\} \\\\textbf\\{Safety\\}",
    perl = TRUE
  )
  # Band 2 ("AE", depth 1) -> `\SetCell[c=2]{l} {\leftskip=Xpt\relax \textbf{AE}}`.
  expect_match(
    tex,
    "\\\\SetCell\\[c=2\\]\\{l\\} \\{\\\\leftskip=[0-9.]+pt\\\\relax \\\\textbf\\{AE\\}\\}",
    perl = TRUE
  )
})

# --- header-band rule scope (cmidrule(lr) semantics) ----------------

test_that("LaTeX scenario G: band emits an outer hline under the two drug arms", {
  tex <- band_emit("G", "tex")
  # SetCell colspan over visible columns 4-5 (drug_50 + drug_100).
  expect_match(
    tex,
    "\\\\SetCell\\[c=2\\]\\{c\\} Active Treatment",
    perl = TRUE
  )
  # Trimmed band underline under the same two columns, emitted as a
  # tabularray-native outer hline directive (pagination-safe) rather
  # than an inline booktabs \cmidrule.
  expect_match(tex, "hline\\{2\\}=\\{4-5\\}", perl = TRUE)
  expect_no_match(tex, "\\cmidrule", fixed = TRUE)
})

# --- header-band rule survives longtblr pagination (#multi-page) -----
# Regression: a banded table that overflows one physical page used to
# crash xelatex with `! Undefined control sequence \cmidrule`. The
# band underline lived in the rowhead block that tabularray replays on
# continuation pages, where the inline \cmidrule sugar is no longer a
# live control sequence. The underline now rides on the outer longtblr
# `hline{i}={cols}{spec}` directive, which is pagination-aware.

mk_multipage_band_spec <- function(n = 80L) {
  df <- data.frame(
    param = sprintf("Item %d", seq_len(n)),
    a = seq_len(n),
    b = seq_len(n) * 2L,
    c = seq_len(n) * 3L,
    d = seq_len(n) * 4L
  )
  tabular(df, titles = "Multi-page banded table") |>
    cols(
      param = col_spec(label = "Param"),
      a = col_spec(label = "C1"),
      b = col_spec(label = "C2"),
      c = col_spec(label = "C3"),
      d = col_spec(label = "C4")
    ) |>
    headers("Group A" = c("a", "b"), "Group B" = c("c", "d"))
}

test_that("LaTeX band underline rides an outer multi-range hline (no inline cmidrule)", {
  out <- withr::local_tempfile(fileext = ".tex")
  emit(mk_multipage_band_spec(), out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_no_match(tex, "\\cmidrule", fixed = TRUE)
  # Cols: param=1, a=2, b=3, c=4, d=5 -> Group A {2-3}, Group B {4-5}
  # collapse to one multi-range hline below the single band row.
  expect_match(tex, "hline\\{2\\}=\\{2-3,4-5\\}", perl = TRUE)
  # The band underline is the SSOT muted `spanrule` (0.5pt, #adb5bd),
  # matching HTML's muted band -- not the legacy hardcoded `0.4pt`
  # black rule.
  expect_match(
    tex,
    "hline{2}={2-3,4-5}{0.5pt, solid, fg=tabularruleADB5BD}",
    fixed = TRUE
  )
})

test_that("banded .tex output matches snapshot (band SetCell + outer hline)", {
  df <- data.frame(
    param = c("Age", "Sex", "BMI"),
    a = 1:3,
    b = 4:6,
    c = 7:9,
    d = 10:12
  )
  spec <- tabular(df, titles = "Banded snapshot") |>
    cols(
      param = col_spec(label = "Param"),
      a = col_spec(label = "C1"),
      b = col_spec(label = "C2"),
      c = col_spec(label = "C3"),
      d = col_spec(label = "C4")
    ) |>
    headers("Group A" = c("a", "b"), "Group B" = c("c", "d"))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  expect_snapshot_file(out, "banded_multirange.tex")
})

test_that("LaTeX multi-page banded table compiles cleanly (regression: cmidrule replay)", {
  skip_if_not(tinytex::is_tinytex())
  out <- withr::local_tempfile(fileext = ".tex")
  emit(mk_multipage_band_spec(), out)
  # On main this aborts with `! Undefined control sequence \cmidrule`
  # at \end{longtblr} once the body overflows onto a second page.
  pdf <- tinytex::xelatex(out)
  withr::defer(unlink(pdf))
  expect_true(file.exists(pdf))
  info <- suppressWarnings(
    system2("pdfinfo", pdf, stdout = TRUE, stderr = FALSE)
  )
  pages <- as.integer(sub(".*:\\s*", "", grep("^Pages:", info, value = TRUE)))
  # The fixture must actually span >1 physical page, else it would not
  # exercise tabularray's rowhead replay (the thing that crashed).
  expect_gt(pages, 1L)
})

# --- §4 spanner parity: full-width top + bottom ride outer hlines ----
# The header top/bottom rules used to be inline `\hline` lines wedged
# between the band rows. Inline header rules do NOT survive longtblr's
# rowhead replay (same failure mode as inline \cmidrule) and they
# doubled when bands sat above the column-labels row. They now ride
# tabularray-native outer `hline{i}={1-N}{spec}` directives: a
# full-width rule on the TOPMOST header row and a full-width rule under
# the column-labels row, with each spanner keeping its scoped
# cmidrule(lr). Mirrors the RTF `outer_top` / `has_bands` model.

mk_band_spec_small <- function() {
  df <- data.frame(
    param = c("Age", "Sex", "BMI"),
    a = 1:3,
    b = 4:6,
    c = 7:9,
    d = 10:12
  )
  tabular(df, titles = "Banded") |>
    cols(
      param = col_spec(label = "Param"),
      a = col_spec(label = "C1"),
      b = col_spec(label = "C2"),
      c = col_spec(label = "C3"),
      d = col_spec(label = "C4")
    ) |>
    headers("Group A" = c("a", "b"), "Group B" = c("c", "d"))
}

test_that("LaTeX header rules ride outer hlines, no inline header rule (#parity-s4)", {
  tex <- render_tex(mk_band_spec_small())
  # Full-width top rule across all 5 columns on the topmost band row.
  expect_match(tex, "hline\\{1\\}=\\{1-5\\}", perl = TRUE)
  # Full-width bottom rule under the column-labels row.
  # rowhead = nbands(1) + 1 = 2, so the bottom rule sits at hline{3}.
  expect_match(tex, "hline\\{3\\}=\\{1-5\\}", perl = TRUE)
  # Each spanner keeps its scoped, inset cmidrule(lr) at hline{2}.
  expect_match(tex, "hline\\{2\\}=\\{2-3,4-5\\}", perl = TRUE)
  # The only inline `\hline` left is the body-bottom (footer) rule;
  # the header top/bottom are no longer inline (single-page spec).
  n_inline <- length(gregexpr("\\hline", tex, fixed = TRUE)[[1L]])
  expect_equal(n_inline, 1L)
})

test_that("LaTeX no-band table: top hline{1}, bottom hline{2}, no double rule", {
  spec <- tabular(
    data.frame(grp = c("a", "b"), n = c("1", "2")),
    titles = "Plain"
  ) |>
    cols(grp = col_spec(label = "Group"), n = col_spec(label = "N"))
  tex <- render_tex(spec)
  expect_match(tex, "hline\\{1\\}=\\{1-2\\}", perl = TRUE)
  expect_match(tex, "hline\\{2\\}=\\{1-2\\}", perl = TRUE)
  # No band cmidrule and no doubled top rule.
  expect_no_match(tex, "leftpos=-1", fixed = TRUE)
})

test_that("cell_padding drives LaTeX per-side leftsep/rightsep (padding SSOT)", {
  # Scalar -> equal left/right; c(t, r, b, l) -> exact per side.
  spec1 <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding = 10)
  expect_match(
    render_tex(spec1),
    "leftsep=10pt, rightsep=10pt",
    fixed = TRUE
  )

  spec2 <- tabular(data.frame(grp = c("a", "b"), n = c("1", "2"))) |>
    preset(cell_padding = c(0, 7, 0, 3))
  expect_match(
    render_tex(spec2),
    "leftsep=3pt, rightsep=7pt",
    fixed = TRUE
  )
})

# --- Phase 5: longtblr head / foot templates -------------------------
# These additive helpers carry running titles + footnotes via
# tabularray's firsthead/middle/lasthead + firstfoot/middle/lastfoot
# templates. Unit-tested on hand-built asts; wired into the panel
# renderer in the native-pagination phase.

mk_ast <- function(...) lapply(c(...), tabular:::parse_inline)

test_that(".latex_def_tblr_template: empty content clears the template", {
  expect_identical(
    tabular:::.latex_def_tblr_template("firsthead", character()),
    "\\DefTblrTemplate{firsthead}{default}{}"
  )
  out <- tabular:::.latex_def_tblr_template("middlehead, lasthead", "X")
  expect_match(
    out[[1L]],
    "\\DefTblrTemplate{middlehead, lasthead}{default}{",
    fixed = TRUE
  )
  expect_identical(out[[length(out)]], "}")
})

test_that(".latex_head_template: titles repeat by default, marker only on cont panels", {
  titles <- mk_ast("Table 14.1", "Demographics")
  out <- paste(
    tabular:::.latex_head_template(titles, is_cont_panel = FALSE),
    collapse = "\n"
  )
  expect_match(out, "\\DefTblrTemplate{firsthead}{default}{", fixed = TRUE)
  expect_match(
    out,
    "\\DefTblrTemplate{middlehead, lasthead}{default}{",
    fixed = TRUE
  )
  expect_match(out, "Demographics", fixed = TRUE)
  # Panel 1: no continuation marker anywhere.
  expect_no_match(out, "(continued)", fixed = TRUE)
})

test_that(".latex_head_template: non-repeat keeps titles out of middle/lasthead", {
  titles <- mk_ast("Table 14.1")
  out <- tabular:::.latex_head_template(titles, rep_titles = FALSE)
  # firsthead carries the title; middle/lasthead is the empty form.
  first_blk <- out[seq_len(which(out == "}")[[1L]])]
  expect_match(paste(first_blk, collapse = "\n"), "Table 14.1", fixed = TRUE)
  expect_true("\\DefTblrTemplate{middlehead, lasthead}{default}{}" %in% out)
})

test_that(".latex_head_template: continuation marker on cont panel + continued pages", {
  titles <- mk_ast("Table 14.1")
  out <- paste(
    tabular:::.latex_head_template(
      titles,
      continuation = "(continued)",
      is_cont_panel = TRUE
    ),
    collapse = "\n"
  )
  # Marker appears in firsthead (cont panel) and middle/lasthead.
  expect_gte(lengths(gregexpr("(continued)", out, fixed = TRUE))[[1L]], 2L)
})

test_that(".latex_head_template: empty titles, no marker -> empty templates", {
  out <- tabular:::.latex_head_template(list())
  expect_true("\\DefTblrTemplate{firsthead}{default}{}" %in% out)
  expect_true("\\DefTblrTemplate{middlehead, lasthead}{default}{}" %in% out)
})

test_that(".latex_foot_template: repeating footnotes share one template + minipage", {
  fn <- mk_ast("Note: safety population.")
  cols <- list(
    a = col_spec(width = 2),
    b = col_spec(width = 1)
  )
  out <- paste(
    tabular:::.latex_foot_template(
      fn,
      rep_footnotes = TRUE,
      col_names_vis = c("a", "b"),
      cols = cols
    ),
    collapse = "\n"
  )
  expect_match(
    out,
    "\\DefTblrTemplate{firstfoot, middlefoot, lastfoot}{default}{",
    fixed = TRUE
  )
  expect_match(out, "\\begin{minipage}{", fixed = TRUE)
  # footnoterule is OFF by default (the body bottomrule is the
  # mutually-exclusive default closer), so the foot template carries
  # no separator rule unless the user opts in.
  expect_no_match(out, "\\rule{\\linewidth}", fixed = TRUE)
  expect_match(out, "safety population", fixed = TRUE)

  # Opt-in: a non-NULL footer_top chrome triple draws the rule, sized to
  # \linewidth (= the table-width minipage), at the resolved SSOT width.
  cs <- chrome_style()
  cs$borders$footer_top <- list(
    style = "solid",
    width = 0.5,
    color = "currentColor"
  )
  out_on <- paste(
    tabular:::.latex_foot_template(
      fn,
      rep_footnotes = TRUE,
      col_names_vis = c("a", "b"),
      cols = cols,
      cs = cs
    ),
    collapse = "\n"
  )
  expect_match(out_on, "\\rule{\\linewidth}{0.5pt}", fixed = TRUE)
})

test_that(".latex_foot_template: non-repeat pins footnotes to lastfoot only", {
  fn <- mk_ast("Note: last page.")
  out <- tabular:::.latex_foot_template(fn, rep_footnotes = FALSE)
  expect_true("\\DefTblrTemplate{firstfoot, middlefoot}{default}{}" %in% out)
  last_blk <- paste(out, collapse = "\n")
  expect_match(
    last_blk,
    "\\DefTblrTemplate{lastfoot}{default}{",
    fixed = TRUE
  )
  expect_match(last_blk, "last page", fixed = TRUE)
})

test_that(".latex_foot_template: empty footnotes -> empty foot templates", {
  out <- tabular:::.latex_foot_template(list())
  expect_true("\\DefTblrTemplate{firstfoot, middlefoot}{default}{}" %in% out)
  expect_true("\\DefTblrTemplate{lastfoot}{default}{}" %in% out)
})

test_that(".latex_table_width_in: sum of widths + padding; NA -> linewidth fallback", {
  cols <- list(a = col_spec(width = 2), b = col_spec(width = 1))
  spec <- tabular(data.frame(a = 1, b = 2)) |> preset(cell_padding = 0)
  preset <- tabular:::.effective_preset(spec)
  w <- tabular:::.latex_table_width_in(c("a", "b"), cols, preset = preset)
  expect_equal(w, 3) # zero padding -> exactly the summed widths
  # Missing width on a column -> NA (caller uses \linewidth).
  cols2 <- list(a = col_spec(width = 2), b = col_spec())
  expect_true(is.na(
    tabular:::.latex_table_width_in(c("a", "b"), cols2, preset = preset)
  ))
})

# --- Phase 1 + 2/3: native pagination + panel composition ------------

test_that(".latex_chrome_hline_spec: default, override, and none", {
  # No chrome border set -> canonical thin solid rule at the SSOT width.
  expect_identical(
    tabular:::.latex_chrome_hline_spec(NULL, "header_top"),
    "0.5pt, solid"
  )
  # Explicit override resolves through .latex_border_spec.
  cs <- list(
    borders = list(
      header_top = list(style = "solid", width = 1.2, color = NA_character_),
      header_bottom = list(style = "none", width = 0, color = NA_character_)
    )
  )
  expect_match(
    tabular:::.latex_chrome_hline_spec(cs, "header_top"),
    "1.2pt",
    fixed = TRUE
  )
  # style = "none" -> "" so the caller skips the directive.
  expect_identical(
    tabular:::.latex_chrome_hline_spec(cs, "header_bottom"),
    ""
  )
})

test_that(".latex_minipage_wrap falls back to \\linewidth on NA width", {
  out <- tabular:::.latex_minipage_wrap(c("body"), NA_real_)
  expect_match(out[[1L]], "\\begin{minipage}{\\linewidth}", fixed = TRUE)
  fixed_w <- tabular:::.latex_minipage_wrap(c("body"), 3.5)
  expect_match(fixed_w[[1L]], "\\begin{minipage}{3.5in}", fixed = TRUE)
})

test_that(".group_pages_into_panels keys by (subgroup, panel), sorts pages", {
  pages <- list(
    list(subgroup_index = 1L, panel_index = 1L, page_index = 2L),
    list(subgroup_index = 1L, panel_index = 1L, page_index = 1L),
    list(subgroup_index = 1L, panel_index = 2L, page_index = 1L)
  )
  grouped <- tabular:::.group_pages_into_panels(pages)
  expect_length(grouped, 2L)
  # First group (panel 1) sorted by page_index ascending.
  expect_identical(
    vapply(grouped[[1L]], function(p) p$page_index, integer(1L)),
    c(1L, 2L)
  )
  # by_subgroup = FALSE (DOCX without big_n) keys by panel only, so two
  # subgroups in the same panel collapse into one group.
  two_sg <- list(
    list(subgroup_index = 1L, panel_index = 1L, page_index = 1L),
    list(subgroup_index = 2L, panel_index = 1L, page_index = 1L)
  )
  expect_length(tabular:::.group_pages_into_panels(two_sg), 2L)
  expect_length(
    tabular:::.group_pages_into_panels(two_sg, by_subgroup = FALSE),
    1L
  )
  expect_length(tabular:::.group_pages_into_panels(list()), 0L)
})

test_that(".latex_concat_panel_body: single page passes through, multi rbinds", {
  mk_page <- function(txt, keep) {
    list(
      cells_text = matrix(txt, nrow = length(txt), ncol = 1L),
      cells_style = matrix(list(style_node()), nrow = length(txt), ncol = 1L),
      cells_indent = matrix(0L, nrow = length(txt), ncol = 1L),
      is_header_row = rep(FALSE, length(txt)),
      is_blank_row = rep(FALSE, length(txt)),
      keep_with_next = keep,
      host_col = NA_character_
    )
  }
  one <- tabular:::.latex_concat_panel_body(list(mk_page(
    c("a", "b"),
    c(TRUE, FALSE)
  )))
  expect_equal(nrow(one$cells_text), 2L)

  two <- tabular:::.latex_concat_panel_body(list(
    mk_page(c("a", "b"), c(TRUE, FALSE)),
    mk_page(c("c"), FALSE)
  ))
  expect_equal(nrow(two$cells_text), 3L)
  expect_identical(two$keep_with_next, c(TRUE, FALSE, FALSE))
})

test_that(".latex_warn_long_table warns past threshold, silent below", {
  expect_warning(
    tabular:::.latex_warn_long_table(1000L),
    class = "tabular_warning_layout"
  )
  expect_no_warning(tabular:::.latex_warn_long_table(999L))
  expect_no_warning(tabular:::.latex_warn_long_table(NA_integer_))
})

test_that("long table emit() warns about tabularray compile cost", {
  d <- data.frame(
    grp = sprintf("Item %d", seq_len(1000L)),
    x = seq_len(1000L)
  )
  out <- withr::local_tempfile(fileext = ".tex")
  expect_warning(
    emit(tabular(d), out),
    class = "tabular_warning_layout"
  )
})

test_that("keep_together drives \\* glue inside ONE longtblr (native)", {
  d <- data.frame(grp = rep(letters[1:6], each = 4L), x = seq_len(24L))
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp")
  tex <- render_tex(spec)
  expect_match(tex, "\\\\*", fixed = TRUE) # at least one glued row
  expect_equal(
    length(gregexpr("\\begin{longtblr}", tex, fixed = TRUE)[[1L]]),
    1L
  )
})

test_that("subgroup emits one longtblr per group separated by \\clearpage", {
  d <- data.frame(
    g = rep(c("Cohort A", "Cohort B"), each = 3L),
    lab = rep(c("n", "Mean", "SD"), 2L),
    val = c("10", "5.1", "1.2", "12", "5.4", "1.0")
  )
  spec <- tabular(d) |>
    cols(g = col_spec(usage = "group")) |>
    subgroup(by = "g")
  tex <- render_tex(spec)
  expect_match(tex, "\\clearpage", fixed = TRUE)
  expect_gte(
    length(gregexpr("\\begin{longtblr}", tex, fixed = TRUE)[[1L]]),
    2L
  )
})

test_that("tall chrome no longer aborts under native pagination", {
  # Many title lines + large font make the header chrome taller than
  # the printable area. Non-native pagination aborted here; native
  # floors rows_per_page instead.
  d <- data.frame(grp = letters[1:8], x = seq_len(8L))
  spec <- tabular(d, titles = sprintf("Title line %d", 1:12)) |>
    preset(font_size = 26L)
  out <- withr::local_tempfile(fileext = ".tex")
  expect_no_error(emit(spec, out))
})

# --- Phase 6: PDF compile + benchmark gate (tinytex) -----------------
# The only check that proves the head/foot templates + native
# pagination compile under the installed tabularray.

test_that("subgroup + panel spec compiles to PDF with template lines", {
  skip_on_cran()
  skip_if_not(tinytex::is_tinytex())
  d <- data.frame(
    g = rep(c("Cohort A", "Cohort B"), each = 30L),
    lab = rep(sprintf("Row %d", 1:30), 2L),
    val = as.character(seq_len(60L))
  )
  spec <- tabular(
    d,
    titles = c("Table X", "Demographics"),
    footnotes = "Note: x."
  ) |>
    cols(g = col_spec(usage = "group")) |>
    subgroup(by = "g")
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(tex, "\\DefTblrTemplate{firsthead}{default}", fixed = TRUE)
  expect_match(
    tex,
    "\\DefTblrTemplate{firstfoot, middlefoot, lastfoot}{default}",
    fixed = TRUE
  )
  pdf <- tinytex::xelatex(out)
  withr::defer(unlink(pdf))
  expect_true(file.exists(pdf) && file.size(pdf) > 0L)
})

test_that("pagefoot band + user footnotes coexist (chrome/template no overlap)", {
  skip_on_cran()
  skip_if_not(tinytex::is_tinytex())
  d <- data.frame(grp = sprintf("Item %d", 1:40), x = seq_len(40L))
  spec <- tabular(d, titles = "T", footnotes = c("Note A", "Note B")) |>
    preset(
      pagefoot = list(
        left = "Program: demo.R",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  pdf <- tinytex::xelatex(out)
  withr::defer(unlink(pdf))
  expect_true(file.exists(pdf) && file.size(pdf) > 0L)
})

test_that("~400-row table compiles (tabularray whole-table cost benchmark)", {
  skip_on_cran()
  skip_if_not(tinytex::is_tinytex())
  d <- data.frame(
    grp = sprintf("Subject %03d", seq_len(400L)),
    a = seq_len(400L),
    b = round(seq_len(400L) / 7, 1)
  )
  spec <- tabular(d, titles = "Long listing")
  out <- withr::local_tempfile(fileext = ".tex")
  suppressWarnings(emit(spec, out))
  elapsed <- system.time({
    pdf <- tinytex::xelatex(out)
  })[["elapsed"]]
  withr::defer(unlink(pdf))
  expect_true(file.exists(pdf) && file.size(pdf) > 0L)
  info <- suppressWarnings(
    system2("pdfinfo", pdf, stdout = TRUE, stderr = FALSE)
  )
  pages <- as.integer(sub(".*:\\s*", "", grep("^Pages:", info, value = TRUE)))
  expect_gt(pages, 1L)
  testthat::skip(sprintf(
    "benchmark: 400-row xelatex compile = %.1fs",
    elapsed
  ))
})

test_that("multi-line cell whose next line starts with '[' is bracket-safe (#latex-brackets)", {
  # A wrapped column header whose continuation line is a footnote marker
  # ("[1]") must not let LaTeX read the bracket as `\\`'s optional
  # `\\[<dimen>]` argument, which raised "Illegal unit of measure" and
  # aborted xelatex. The in-cell break is emitted as `\\{}` so the
  # following `[` can never be mistaken for the optional argument.
  df <- data.frame(
    g = c("A", "A"),
    stat = c("n", "Mean"),
    x = c("10", "5.2"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T", footnotes = "F") |>
    cols(
      g = col_spec(
        usage = "group",
        group_display = "column",
        label = "Char",
        align = "left"
      ),
      stat = col_spec(label = "Statistic", align = "left"),
      x = col_spec(label = "p-value\n[1]", align = "decimal")
    )
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- paste(readLines(f), collapse = "\n")

  expect_true(grepl("\\\\{}", tex, fixed = TRUE)) # in-cell break protected
  expect_false(grepl("\\\\ [", tex, fixed = TRUE)) # no bare `\\ [`
})

test_that("multi-line header with bracket footnote marker compiles to PDF (#latex-brackets)", {
  skip_on_cran()
  skip_if_not_installed("tinytex")
  skip_if_not(tinytex::is_tinytex() || nzchar(Sys.which("xelatex")))

  df <- data.frame(
    g = c("A", "A"),
    stat = c("n", "Mean"),
    x = c("10", "5.2"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "T", footnotes = "F") |>
    cols(
      g = col_spec(
        usage = "group",
        group_display = "column",
        label = "Char",
        align = "left"
      ),
      stat = col_spec(label = "Statistic", align = "left"),
      x = col_spec(label = "p-value\n[1]", align = "decimal")
    )
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  pdf <- tinytex::xelatex(f)
  withr::defer(unlink(pdf))
  expect_true(file.exists(pdf))
})

test_that("title block padded with full-height blank lines, not collapsing empties (#latex-titlepad)", {
  # `rep("", n)` emitted empty strings that collapse to zero height
  # under `\parskip=0pt`; the RTF/HTML title blank-line padding never
  # appeared. The padding is now a strut paragraph per blank line.
  spec <- tabular(data.frame(x = 1L), titles = "My Title")
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- paste(readLines(f), collapse = "\n")
  expect_true(grepl("{\\strut\\par}", tex, fixed = TRUE))
})

test_that("footnotes present: single closing rule, no doubled rule at the boundary (#latex-footrule)", {
  # `bottomrule` and `footnoterule` are mutually exclusive. The default
  # closer is the body `bottomrule` (an outer `hline{nrow}` directive).
  # `footnoterule` is OFF, so the foot template draws NO separator
  # `\rule`, and there is no in-table inline `\hline` -- exactly one
  # rule sits at the data -> footnote boundary.
  spec <- tabular(data.frame(g = "A", x = "1"), footnotes = "Note 1")
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- readLines(f)
  expect_false(any(grepl("\\rule{\\linewidth}", tex, fixed = TRUE)))
  expect_equal(sum(trimws(tex) == "\\hline"), 0L)
  spec_line <- tex[grep("begin{longtblr}", tex, fixed = TRUE)][[1L]]
  expect_match(spec_line, "hline{3}", fixed = TRUE)
})

test_that("no footnotes: single closing rule is the SSOT bottomrule, not an inline \\hline (#latex-footrule)", {
  spec <- tabular(data.frame(g = "A", x = "1"))
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- readLines(f)
  # The closer is the outer `hline{nrow}` bottomrule directive; the
  # legacy inline `\hline` (which doubled with it) is gone.
  expect_equal(sum(trimws(tex) == "\\hline"), 0L)
  spec_line <- tex[grep("begin{longtblr}", tex, fixed = TRUE)][[1L]]
  expect_match(spec_line, "hline{3}", fixed = TRUE)
})

test_that("opt-in footnoterule draws a table-width \\rule and drops the bottomrule (#latex-footrule)", {
  spec <- tabular(data.frame(g = "A", x = "1"), footnotes = "Note 1") |>
    preset(
      rules = list(bottomrule = "none", footnoterule = brdr(width = "thin"))
    )
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- readLines(f)
  # The footnoterule rides the foot-template minipage (= table width),
  # at the resolved SSOT width; the bottomrule directive is suppressed.
  expect_true(any(grepl("\\rule{\\linewidth}{0.5pt}", tex, fixed = TRUE)))
  spec_line <- tex[grep("begin{longtblr}", tex, fixed = TRUE)][[1L]]
  expect_no_match(spec_line, "hline{3}", fixed = TRUE)
})

test_that("preset(padding=list(header=...)) emits \\SetRow rowsep (#thread-C)", {
  df <- data.frame(grp = c("A", "B"), d50 = c("1", "2"), d100 = c("3", "4"))
  spec <- tabular(df) |>
    headers("Drug" = c("d50", "d100")) |>
    preset(padding = list(header = c(top = 6, bottom = 6)))
  out <- withr::local_tempfile(fileext = ".tex")
  emit(spec, out)
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Band + column-label rows lead with `\SetRow{abovesep,belowsep}` from
  # the header surface's vertical padding (compiles via tabularray).
  expect_match(tex, "\\SetRow{abovesep=6pt,belowsep=6pt}", fixed = TRUE)
})

test_that("cells_pagehead band border drives headrulewidth + per-slot props in LaTeX (#thread-G)", {
  spec <- tabular(saf_demo) |>
    preset(pagehead = list(center = "Draft")) |>
    style(
      bold = TRUE,
      color = "#cc0000",
      .at = cells_pagehead(slot = "center")
    ) |>
    style(border_bottom = brdr("thin"), .at = cells_pagehead())
  out <- withr::local_tempfile(fileext = ".tex")
  suppressWarnings(emit(spec, out))
  tex <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # The band border opts the head rule on (was hardcoded 0pt before G).
  expect_match(tex, "\\renewcommand{\\headrulewidth}{0.5pt}", fixed = TRUE)
  # The centre slot content is wrapped in the text props.
  expect_match(tex, "\\textbf{", fixed = TRUE)
  expect_match(tex, "CC0000", fixed = TRUE)
  # The footer band, unset, keeps 0pt.
  expect_match(tex, "\\renewcommand{\\footrulewidth}{0pt}", fixed = TRUE)
})

# ---- LaTeX body asymmetric vertical padding (#cell-padding) -------------

test_that("LaTeX body honors padding_bottom independently via belowsep (#cell-padding)", {
  spec <- tabular(data.frame(x = c("1", "2"))) |>
    cols(x = col_spec(label = "X")) |>
    style(padding_bottom = 20, .at = cells_body())
  f <- withr::local_tempfile(fileext = ".tex")
  emit(spec, f)
  tex <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_true(grepl("belowsep=20pt", tex, fixed = TRUE))
})
