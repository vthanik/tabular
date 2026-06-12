# backend_md() — GFM pipe-table backend.
#
# The backend self-registers at package-load time, so every test
# here can rely on `tabular:::.has_backend("md")` returning TRUE
# without setup.

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("md backend is registered at package load", {
  expect_true(tabular:::.has_backend("md"))
})

# ---------------------------------------------------------------------
# End-to-end via emit()
# ---------------------------------------------------------------------

test_that("emit(.md) writes a non-empty .md file", {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_gt(length(lines), 0L)
  expect_true(any(grepl("^# T", lines)))
  expect_true(any(grepl("^\\| x \\| y \\|", lines)))
  expect_true(any(grepl("^F", lines)))
})

test_that("emit(.md) renders cdisc_saf_demo golden pipeline end to end", {
  spec <- tabular(
    cdisc_saf_demo,
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
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("# Demographics", lines, fixed = TRUE)))
  expect_true(any(grepl("Placebo<br/>N=86", lines, fixed = TRUE)))
  expect_true(any(grepl("Source: ADSL.", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

test_that("titles render as level-1 headings preserving order", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First", "Second", "Third")
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  headings <- lines[grepl("^# ", lines)]
  expect_identical(headings, c("# First", "# Second", "# Third"))
})

test_that("footnotes render as paragraphs separated by blank lines", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c("Foot A", "Foot B")
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  fa <- which(lines == "Foot A")
  fb <- which(lines == "Foot B")
  expect_length(fa, 1L)
  expect_length(fb, 1L)
  expect_identical(lines[(fa + 1L):(fb - 1L)], "")
})

test_that("no titles -> no top heading; no footnotes -> no trailing block", {
  spec <- tabular(data.frame(x = 1L))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_false(any(grepl("^# ", lines)))
})

# ---------------------------------------------------------------------
# Inline AST rendering (md() / html() input)
# ---------------------------------------------------------------------

test_that("bold / italic / code marks survive into the .md output", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c(
      md("**Bold title**"),
      md("*italic title*"),
      md("`code title`")
    )
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("**Bold title**", lines, fixed = TRUE)))
  expect_true(any(grepl("*italic title*", lines, fixed = TRUE)))
  expect_true(any(grepl("`code title`", lines, fixed = TRUE)))
})

test_that("superscript / subscript / link survive in the .md output", {
  spec <- tabular(
    data.frame(x = 1L),
    footnotes = c(
      md("^a^ Marker"),
      md("~sub~ Marker"),
      md("[link](https://example.com)")
    )
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("^a^ Marker", lines, fixed = TRUE)))
  expect_true(any(grepl("~sub~ Marker", lines, fixed = TRUE)))
  expect_true(any(grepl("[link](https://example.com)", lines, fixed = TRUE)))
})

test_that("two footnotes on one body cell render as a single ^a,b^ superscript", {
  # Distinct ids on the same body anchor accumulate into one comma-joined
  # sentinel; the md backend emits ^a,b^ (valid Pandoc superscript). The
  # header path differs by design: it stacks native sup runs (^a^^b^).
  spec <- tabular(cdisc_saf_aesocpt) |>
    cols(
      soc = col_spec(usage = "group"),
      label = col_spec(label = "PT"),
      n_total = col_spec(visible = FALSE),
      Total = col_spec(label = "Total")
    ) |>
    footnote(
      "First.",
      .at = cells_body(where = n_total >= 50, j = "Total"),
      id = "x"
    ) |>
    footnote(
      "Second.",
      .at = cells_body(where = n_total >= 50, j = "Total"),
      id = "y"
    )
  out <- withr::local_tempfile(fileext = ".md")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "^a,b^", fixed = TRUE)
  expect_match(txt, "a First.", fixed = TRUE)
  expect_match(txt, "b Second.", fixed = TRUE)
})

test_that("embedded \\n in cell text becomes <br/>", {
  spec <- tabular(
    data.frame(x = "line1\nline2"),
    titles = "T"
  )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("line1<br/>line2", lines, fixed = TRUE)))
})

test_that("pipe in cell text is escaped as \\|", {
  spec <- tabular(data.frame(x = "a|b|c"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("a\\|b\\|c", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------
# Alignment row mapping
# ---------------------------------------------------------------------

test_that("alignment row maps every align value to its GFM token", {
  spec <- tabular(data.frame(L = "x", C = "x", R = "x", D = "x", U = "x")) |>
    cols(
      L = col_spec(align = "left"),
      C = col_spec(align = "center"),
      R = col_spec(align = "right"),
      D = col_spec(align = "decimal")
      # U intentionally left without a col_spec -> default :---
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  sep <- lines[grepl("^\\| :", lines)][1L]
  expect_true(grepl(":---", sep, fixed = TRUE))
  expect_true(grepl(":---:", sep, fixed = TRUE))
  expect_true(grepl("---:", sep, fixed = TRUE))
})

test_that(".md_align_token defaults to left for unknown / NA", {
  expect_identical(tabular:::.md_align_token(NA_character_), ":---")
  expect_identical(tabular:::.md_align_token(NULL), ":---")
  expect_identical(tabular:::.md_align_token("garbage"), ":---")
})

# ---------------------------------------------------------------------
# Multi-level headers
# ---------------------------------------------------------------------

test_that("header band labels appear on their own table row above the column-labels row", {
  spec <- tabular(
    data.frame(
      grp = "x",
      placebo = "1",
      active_low = "2",
      active_high = "3"
    )
  ) |>
    headers("Treatment Arm" = c("placebo", "active_low", "active_high"))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # Band label must appear before the alignment row.
  band_row <- which(grepl("Treatment Arm", lines, fixed = TRUE))[1L]
  sep_row <- which(grepl("^\\| :", lines))[1L]
  expect_lt(band_row, sep_row)
})

# ---------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------

test_that("multi-page emit produces a single continuous pipe table", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # No per-page comment or horizontal-rule separator (chrome `----`
  # only fires when pagehead/pagefoot is populated; this fixture has
  # neither).
  expect_false(any(grepl("<!-- page", lines, fixed = TRUE)))
  expect_false(any(grepl("^----$", lines)))
  # Exactly one alignment row across the whole document — the
  # header block emits ONCE for the panel, not once per vertical
  # page.
  expect_identical(length(grep("^\\| :", lines)), 1L)
  # Every numeric data row from the input appears in the body. The
  # body cell may carry leading whitespace from auto group-band
  # indent (data_depth = 1 under the single `usage = "group"`
  # column), so match the numeric followed by `|` rather than the
  # cell-aligned literal.
  for (n in seq_len(24L)) {
    expect_true(
      any(grepl(sprintf("\\b%d\\b *\\|", n), lines, perl = TRUE)),
      info = sprintf("missing row n = %d", n)
    )
  }
})

# ---- Faux page chrome (pagehead / pagefoot bands) ------------------

test_that("pagehead renders as faux chrome at top of document", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: XYZ",
        center = "Draft",
        right = "Page {page} of {npages}"
      )
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # First non-empty line is the chrome row.
  expect_match(
    lines[[1L]],
    "Protocol: XYZ \\| Draft \\| Page 1 of 1"
  )
  # Followed by `----` rule before the title block.
  expect_true(any(grepl("^----$", lines[1:5])))
})

test_that("pagefoot renders as faux chrome at bottom of document", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(left = "Program: tool.R", right = "24MAY2026")
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # Last non-empty line is the chrome row.
  tail_lines <- tail(lines[nzchar(lines)], 2L)
  expect_true(any(grepl("Program: tool.R", tail_lines, fixed = TRUE)))
  expect_true(any(grepl("24MAY2026", tail_lines, fixed = TRUE)))
})

test_that("empty pagehead / pagefoot emits no chrome bands", {
  spec <- tabular(data.frame(x = 1:3))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("Protocol", txt, fixed = TRUE))
  expect_false(grepl("Program:", txt, fixed = TRUE))
})

test_that("continuation marker is a no-op for MD output", {
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(keep_together = "grp", continuation = "(continued)") |>
    preset(font_size = 24L)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  txt <- paste(readLines(out), collapse = "\n")
  expect_false(grepl("(continued)", txt, fixed = TRUE))
})

test_that("horizontal panels collapse to one pipe table with a Panel note row (continuous)", {
  d <- data.frame(
    grp = c("a", "b"),
    c1 = 1:2,
    c2 = 3:4,
    c3 = 5:6,
    c4 = 7:8
  )
  spec <- tabular(d) |>
    cols(grp = col_spec(usage = "group")) |>
    paginate(panels = 2L)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  txt <- paste(lines, collapse = "\n")
  # Markdown has no page width: ONE pipe table -> ONE alignment row.
  expect_identical(length(grep("^\\| :", lines)), 1L)
  # The panel boundaries surface as a `**Panel i**` note row, repeated
  # across each panel's columns and blank over the stub.
  expect_match(txt, "**Panel 1**", fixed = TRUE)
  expect_match(txt, "**Panel 2**", fixed = TRUE)
  # No inter-page comment or rule between panels.
  expect_false(any(grepl("<!-- page", lines, fixed = TRUE)))
})

test_that("subgroup banner emits inline as a bold line before its row block", {
  d <- data.frame(
    g = c("A", "A", "B", "B"),
    x = 1:4
  )
  spec <- tabular(d) |> subgroup("g")
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  # The default banner template renders the group label in bold
  # (e.g. "**g: A**"). It must appear in the output.
  expect_true(any(grepl("\\*\\*.+\\*\\*", lines)))
})

test_that("subgroup banner weight follows cells_subgroup_labels() (#edge12)", {
  d <- data.frame(g = c("A", "A", "B", "B"), x = 1:4)
  off <- tabular(d) |>
    subgroup("g") |>
    style(bold = FALSE, .at = cells_subgroup_labels())
  out <- withr::local_tempfile(fileext = ".md")
  emit(off, out)
  txt <- paste(readLines(out), collapse = "\n")
  # bold = FALSE drops the `**` emphasis on the banner.
  expect_false(grepl("\\*\\*", txt))
  # italic = TRUE adds single-`*` emphasis.
  ital <- tabular(d) |>
    subgroup("g") |>
    style(bold = FALSE, italic = TRUE, .at = cells_subgroup_labels())
  out2 <- withr::local_tempfile(fileext = ".md")
  emit(ital, out2)
  expect_match(paste(readLines(out2), collapse = "\n"), "\\*[^*]+\\*")
})

test_that("Markdown warns once per render when a group-header carries colour (#edge13)", {
  d <- data.frame(
    soc = c("Infections", "Infections"),
    label = c("Pneumonia", "Sepsis"),
    x = 1:2
  )
  spec <- tabular(d) |>
    cols(
      label = col_spec(label = "PT"),
      soc = col_spec(usage = "group", group_display = "header_row"),
      x = col_spec()
    ) |>
    style(color = "#FF0000", .at = cells_group_headers())
  out <- withr::local_tempfile(fileext = ".md")
  warns <- character()
  withCallingHandlers(
    emit(spec, out),
    tabular_warning_fidelity = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  # Two header rows, one colour each, but dedup -> a single warning.
  expect_length(warns, 1L)
  # A second render in the same session warns again (reset at emit entry).
  out2 <- withr::local_tempfile(fileext = ".md")
  warns2 <- character()
  withCallingHandlers(
    emit(spec, out2),
    tabular_warning_fidelity = function(w) {
      warns2 <<- c(warns2, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warns2, 1L)
})

# ---------------------------------------------------------------------
# Edge: zero-row data
# ---------------------------------------------------------------------

test_that("empty grid (zero pages) renders titles + empty message + footnotes", {
  fake <- tabular_grid(
    pages = list(),
    metadata = list(
      titles_ast = list(parse_inline("Title")),
      footnotes_ast = list(parse_inline("Foot")),
      empty_text_ast = parse_inline("Nothing here")
    )
  )
  lines <- tabular:::.render_md_grid(fake)
  expect_true(any(grepl("Nothing here", lines, fixed = TRUE)))
  expect_true("# Title" %in% lines)
  expect_true("Foot" %in% lines)
})

test_that("zero-row spec renders header + alignment + empty message line", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl("^\\| x \\| y \\|", lines)))
  expect_true(any(grepl("^\\| :---", lines)))
  # The message rides a <div align> wrapper below the (closed) pipe table.
  expect_true(any(grepl(
    "<div align=\"center\">No data available to report</div>",
    lines,
    fixed = TRUE
  )))
})

test_that("Markdown empty message honours empty_text + empty_halign", {
  spec <- tabular(
    data.frame(x = integer(0L), y = character(0L)),
    empty_text = "None."
  ) |>
    preset(empty_halign = "left")
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  lines <- readLines(out)
  expect_true(any(grepl(
    "<div align=\"left\">None.</div>",
    lines,
    fixed = TRUE
  )))
})

# ---------------------------------------------------------------------
# Cell escape helpers
# ---------------------------------------------------------------------

test_that(".md_escape_cell handles NA / NULL", {
  expect_identical(tabular:::.md_escape_cell(NA), "")
  expect_identical(tabular:::.md_escape_cell(NULL), "")
  expect_identical(tabular:::.md_escape_cell("plain"), "plain")
})

test_that(".md_escape_cell escapes pipes and CRLF / LF newlines", {
  expect_identical(tabular:::.md_escape_cell("a|b"), "a\\|b")
  expect_identical(tabular:::.md_escape_cell("a\r\nb"), "a<br/>b")
  expect_identical(tabular:::.md_escape_cell("a\nb"), "a<br/>b")
})

test_that(".render_md_inline returns '' on non-inline_ast input", {
  expect_identical(tabular:::.render_md_inline("not an ast"), "")
})

test_that(".render_md_run falls through to text for unknown types", {
  # Unknown run types are filtered by the inline_ast validator at
  # construction, but the renderer keeps a fallback in case a
  # backend hands one in directly.
  fake_run <- list(type = "totally_unknown_type", text = "fallback")
  expect_identical(tabular:::.render_md_run(fake_run), "fallback")
})

test_that("backend_md() is callable directly with a grid + file", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".md")
  tabular:::backend_md(grid, out)
  expect_true(file.exists(out))
  expect_true(any(grepl("^# T", readLines(out))))
})

test_that(".render_md_run handles span (drops wrapper, keeps children)", {
  ast <- parse_inline(html("<span style='color:red'>red</span>"))
  expect_identical(tabular:::.render_md_inline(ast), "red")
})

test_that(".render_md_children returns '' on empty children list", {
  expect_identical(tabular:::.render_md_children(list()), "")
})

test_that(".md_escape_inline handles NA / NULL", {
  expect_identical(tabular:::.md_escape_inline(NA), "")
  expect_identical(tabular:::.md_escape_inline(NULL), "")
  expect_identical(tabular:::.md_escape_inline("a|b"), "a\\|b")
})

test_that(".render_md_col_labels_row falls back to column name on missing AST", {
  out <- tabular:::.render_md_col_labels_row(
    col_labels_ast = list(),
    col_names_visible = c("x", "y")
  )
  expect_identical(out, "| x | y |")
})

test_that(".render_md_link emits the optional title attribute when set", {
  run <- list(
    type = "link",
    href = "https://x.com",
    title = "Tip",
    children = list(list(type = "plain", text = "hi"))
  )
  expect_identical(
    tabular:::.render_md_link(run),
    '[hi](https://x.com "Tip")'
  )
})

# ---------------------------------------------------------------------
# Snapshot pin on the golden pipeline
# ---------------------------------------------------------------------

test_that("cdisc_saf_demo golden pipeline matches the pinned .md snapshot", {
  spec <- tabular(
    cdisc_saf_demo,
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
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  expect_snapshot_file(out, "saf_demo_golden.md")
})

# ---------------------------------------------------------------------
# chrome_style cascade — `style_template() |> style(.at = cells_*())`
# must reach the MD output for the blank-line spacing knobs. (Pure
# Markdown has no native chrome styling for fonts/colors.)
# ---------------------------------------------------------------------

test_that("style(.at = cells_title(), blank_above = 3) emits three blank lines above the title", {
  template <- style_template() |>
    style(.at = cells_title(), blank_above = 3L)
  spec <- tabular(
    data.frame(x = 1L),
    titles = "Demo"
  ) |>
    preset(.style = template)
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # 3 blank lines = at least 3 consecutive `\n` characters somewhere
  # before the `# Demo` line.
  pre_title <- sub("(.*?)# Demo.*", "\\1", md)
  expect_match(pre_title, "\\n\\n\\n", fixed = FALSE)
})

# ---------------------------------------------------------------------
# Change C: Markdown keeps the engine text-prefix (no native padding)
# ---------------------------------------------------------------------

test_that("Markdown preserves leading-space prefix on indented data rows (Change C)", {
  df <- data.frame(
    soc = c("CARDIAC", "CARDIAC", "GI", "GI"),
    label = c(
      "CARDIAC",
      "Atrial fibrillation",
      "GI",
      "Nausea"
    ),
    row_type = c("soc", "pt", "soc", "pt"),
    indent_level = c(0L, 1L, 0L, 1L),
    n = c(5L, 3L, 10L, 6L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "AE") |>
    cols(
      soc = col_spec(usage = "group", group_display = "header_row"),
      label = col_spec(label = "Category", indent = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      n = col_spec(label = "N")
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # PT rows keep the engine-baked indent in the rendered cell; under
  # whitespace preservation (default) it is rewritten to `&nbsp;` so the
  # nesting survives the GFM -> HTML render.
  expect_true(grepl("Atrial fibrillation", md, fixed = TRUE))
  expect_match(md, "&nbsp;&nbsp;Atrial fibrillation", perl = FALSE)
  # Header rows (CARDIAC / GI) carry NO leading-space prefix.
  expect_match(md, "(?m)^\\| CARDIAC ", perl = TRUE)
})

# ---------------------------------------------------------------------
# Change D: is_header_row / is_blank_row branching in Markdown (GFM
# fallback — no native row-spanning; bold cell 1 + &nbsp; trailing).
# ---------------------------------------------------------------------

test_that("Markdown emits bold cell-1 + &nbsp; trailing for header rows (Change D)", {
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
      stat_label = col_spec(indent = 1, label = "Response"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50")
    )
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Header rows: bold cell 1, &nbsp; in trailing cells.
  expect_match(
    md,
    "| **Best Overall Response** | &nbsp; | &nbsp; |",
    fixed = TRUE
  )
  expect_match(
    md,
    "| **Objective Response Rate** | &nbsp; | &nbsp; |",
    fixed = TRUE
  )
})

# ---------------------------------------------------------------------
# Change D: nested band headers prepend space-prefix on band-2+
# ---------------------------------------------------------------------

test_that("Markdown nested bands: band-1 header bold flush, band-2 header bold + space prefix (Change D)", {
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
  out <- withr::local_tempfile(fileext = ".md")
  emit(spec, out)
  md <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Band 1 ("Safety", depth 0) -> `| **Safety** | &nbsp; |`.
  expect_match(md, "| **Safety** | &nbsp; |", fixed = TRUE)
  # Band 2 ("AE", depth 1) -> `| **  AE** | &nbsp; |` (2-space prefix
  # inside the bold span).
  expect_match(md, "| **  AE** | &nbsp; |", fixed = TRUE)
})

# --- header-band label scope (text-only; MD has no border concept) ---

test_that("MD scenario G: label repeats over the two drug arms (no border concept)", {
  md <- band_emit("G", "md")
  # Pipe-delimited GFM row: blank cells, then label twice (drug_50 +
  # drug_100), then blank. Tolerant regex over whitespace and label
  # text so the assertion does not depend on column-padding widths.
  expect_match(
    md,
    "Active Treatment[^|]*\\|[^|]*Active Treatment",
    perl = TRUE
  )
})

test_that(".md_escape_inline escapes literal asterisks so markers aren't reparsed (#cr7)", {
  # The footnote symbols scheme spills to a doubled glyph at the 7th
  # marker; "^**^" would otherwise read as a strong delimiter inside a
  # Pandoc superscript and corrupt the cell.
  expect_equal(tabular:::.md_escape_inline("**"), "\\*\\*")
  expect_equal(tabular:::.md_escape_inline("*"), "\\*")
  expect_equal(tabular:::.md_escape_inline("plain"), "plain")
})

test_that("whitespace='collapse' collapses runs in md title and footnotes (#cr5)", {
  mk <- function(ws) {
    tabular(
      data.frame(x = 1L),
      titles = "Pop:    Safety",
      footnotes = "Note:    spaced"
    ) |>
      preset(whitespace = ws)
  }
  fc <- withr::local_tempfile(fileext = ".md")
  emit(mk("collapse"), fc)
  txt_c <- paste(readLines(fc, warn = FALSE), collapse = "\n")
  # collapse: neither the title nor the footnote keeps nbsp runs
  expect_no_match(txt_c, "&nbsp;", fixed = TRUE)
  # preserve (control): nbsp runs survive in the chrome
  fp <- withr::local_tempfile(fileext = ".md")
  emit(mk("preserve"), fp)
  txt_p <- paste(readLines(fp, warn = FALSE), collapse = "\n")
  expect_match(txt_p, "&nbsp;", fixed = TRUE)
})
