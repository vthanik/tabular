# backend_latex.R — LaTeX backend using the `tabularray`
# environment. Consumes a resolved `tabular_grid` and writes a
# self-contained UTF-8 `.tex` document that compiles via
# `xelatex` / `lualatex` (the latter two preferred for full
# UTF-8 + system-font support; `pdflatex` works for ASCII-only
# input).
#
# Why tabularray. The `tabularray` package (LaTeX, LPPL) gives
# us what regulatory-grade tables need:
#
# * **Decimal alignment** via `Q[si=...]` column specs (wraps
#   `siunitx`'s `\sisetup`).
# * **Per-cell colspan/rowspan** via `\SetCell[c=N,r=M]{...}` —
#   so header bands route their rules cleanly without manual
#   `\cline` bookkeeping.
# * **Multi-line cells** with `[t]` cell-type + `\\` inside.
# * **Long-table pagination** via the `longtblr` environment
#   (header repeats on continuation pages automatically).
# * **Booktabs-compatible rule weights** without needing
#   booktabs itself; rule placement is declarative.
#
# Output layout — one `longtblr` per `grid@pages` entry,
# separated by `\newpage`. Page 1 carries the title block and
# footnote block; continuation pages get the (optional)
# `continuation` marker the user set on `paginate()`. Header
# bands + column-labels row repeat on every page through
# `longtblr`'s `rowhead` mechanism.
#
# Inline ASTs (cell text, titles, footnotes, col labels) render
# through `.render_latex_inline()` — a recursive walker over
# the `inline_ast@runs` list:
#
#   plain    -> escaped text (`\` `{` `}` `&` `%` `$` `#` `_`
#               `~` `^` swapped for their TeX escapes)
#   bold     -> \textbf{...}
#   italic   -> \textit{...}
#   sup      -> \textsuperscript{...}
#   sub      -> \textsubscript{...}
#   code     -> \texttt{...}
#   link     -> \href{url}{text}    (requires hyperref)
#   span     -> children only       (no LaTeX equivalent for inline styles)
#   newline  -> \\                  (inside cells — needs cell type [t])

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a self-contained UTF-8 .tex file. Called by
# `emit()` via the backend registry. Returns the file path
# invisibly.
backend_latex <- function(grid, file) {
  lines <- .render_latex_doc(grid)
  writeLines(lines, file, useBytes = FALSE)
  invisible(file)
}

# ---------------------------------------------------------------------
# Document shell + page composition
# ---------------------------------------------------------------------

# Compose the full LaTeX document: preamble + \begin{document} +
# per-page table block + \end{document}. Returns a character
# vector of lines ready for `writeLines()`. Pure — no I/O.
.render_latex_doc <- function(grid) {
  pages <- grid@pages
  total <- length(pages)
  meta <- grid@metadata

  preamble <- .latex_preamble(
    preset = meta$preset,
    pagehead_ast = meta$pagehead_ast,
    pagefoot_ast = meta$pagefoot_ast
  )
  begin <- "\\begin{document}"
  end <- "\\end{document}"

  if (total == 0L) {
    return(c(preamble, begin, .render_latex_empty(grid), end))
  }

  body <- list()
  for (i in seq_along(pages)) {
    if (i > 1L) {
      body[[length(body) + 1L]] <- c("", "\\newpage", "")
    }
    body[[length(body) + 1L]] <- .render_latex_page(
      page = pages[[i]],
      meta = meta,
      page_number = i,
      total_pages = total
    )
  }
  c(preamble, begin, unlist(body, use.names = FALSE), end)
}

# Render the LaTeX skeleton for a spec whose grid has zero pages
# (empty data + no body content). Titles + footnotes still
# appear; the table block is replaced with an `\emph{(no rows)}`
# marker so the reader sees the table exists but is empty.
.render_latex_empty <- function(grid) {
  meta <- grid@metadata
  c(
    .render_latex_title_block(meta$titles_ast),
    "",
    "\\emph{(no rows)}",
    "",
    .render_latex_footnote_block(meta$footnotes_ast)
  )
}

# Render one page block. Page 1 carries titles + footnotes;
# continuation pages get the (optional) `continuation` marker.
# Header bands + column-labels row repeat across page breaks
# via `longtblr`'s `rowhead = N` mechanism (computed from the
# number of band-rows + 1 for the column-labels row).
.render_latex_page <- function(page, meta, page_number, total_pages) {
  out <- character()

  if (page_number == 1L) {
    titles <- .render_latex_title_block(meta$titles_ast)
    if (length(titles) > 0L) {
      out <- c(out, titles, "")
    }
  } else if (length(page$continuation) > 0L) {
    out <- c(
      out,
      paste0(
        "\\noindent\\textit{",
        .latex_escape(as.character(page$continuation)),
        "}\\par\\medskip"
      )
    )
  }

  out <- c(out, .render_latex_table(page, meta))

  if (page_number == 1L) {
    footnotes <- .render_latex_footnote_block(meta$footnotes_ast)
    if (length(footnotes) > 0L) {
      out <- c(out, "", footnotes)
    }
  }
  out
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line becomes a centred `\par`. Empty
# title list returns an empty character vector so the caller can
# skip the surrounding spacing.
.render_latex_title_block <- function(titles_ast) {
  if (length(titles_ast) == 0L) {
    return(character())
  }
  inner <- vapply(
    titles_ast,
    function(ast) .render_latex_inline(ast),
    character(1L)
  )
  c(
    "\\begin{center}",
    paste0("{\\bfseries ", inner, "}\\par"),
    "\\end{center}"
  )
}

# Footnote block: each footnote line becomes a left-aligned
# paragraph separated by `\par`. Empty list returns an empty
# character vector.
.render_latex_footnote_block <- function(footnotes_ast) {
  if (length(footnotes_ast) == 0L) {
    return(character())
  }
  rendered <- vapply(
    footnotes_ast,
    function(ast) paste0(.render_latex_inline(ast), "\\par"),
    character(1L)
  )
  c("\\noindent\\small", rendered, "\\normalsize")
}

# ---------------------------------------------------------------------
# Table assembly: longtblr environment
# ---------------------------------------------------------------------

# Render one page's table as a `\begin{longtblr}` ... `\end{longtblr}`
# block. tabularray's `longtblr` auto-paginates and repeats
# `rowhead` rows on continuation pages.
.render_latex_table <- function(page, meta) {
  col_names_vis <- page$col_names
  cols <- meta$cols %||% list()
  colspec <- .latex_colspec(col_names_vis, cols)

  band_rows <- .render_latex_header_bands(meta$headers, col_names_vis)
  label_row <- .render_latex_col_labels_row(
    meta$col_labels_ast,
    col_names_vis,
    cols
  )
  rowhead <- length(band_rows) + 1L

  header_rules <- c("\\hline", band_rows, label_row, "\\hline")
  body_rows <- .render_latex_body_rows(page$cells_text)
  footer_rule <- "\\hline"

  c(
    sprintf(
      "\\begin{longtblr}[caption={}, label={}]{colspec={%s}, rowhead=%d, rows={valign=t}}",
      colspec,
      rowhead
    ),
    header_rules,
    body_rows,
    footer_rule,
    "\\end{longtblr}"
  )
}

# Compose the `colspec={...}` portion of the longtblr arg list.
# One entry per visible column. Each column's token reads
# alignment + width off its `col_spec`:
#
# * No width      -> `Q[<align>]`             (auto-fit)
# * Fixed dim     -> `Q[<align>,wd=<value>]`  (tabularray sized)
# * Percent       -> `X[<weight>,<align>]`    (tabularray
#                    proportional; weights sum to 1 across
#                    the table's X columns)
#
# Fixed and proportional columns coexist cleanly — tabularray
# resolves proportional widths against the leftover space after
# fixed columns are claimed.
.latex_colspec <- function(col_names_vis, cols) {
  toks <- vapply(
    col_names_vis,
    function(nm) {
      cs <- cols[[nm]]
      align <- if (is_col_spec(cs)) cs@align else NA_character_
      width <- if (is_col_spec(cs)) cs@width else NA_real_
      .latex_col_token(align, width)
    },
    character(1L)
  )
  paste(toks, collapse = " ")
}

# Compose one tabularray column token from an align value and a
# width value. Routes percent widths to the proportional `X[...]`
# column type and fixed dimensions to `Q[<align>,wd=<dim>]`.
.latex_col_token <- function(align, width) {
  align_letter <- .latex_align_letter(align)
  if (.is_na_width(width)) {
    return(sprintf("Q[%s]", align_letter))
  }
  parsed <- .parse_dim(width, allow_percent = TRUE)
  if (.is_percent_dim(parsed)) {
    # tabularray proportional width: `X[<weight>,<align>]`. The
    # weight is the percent / 100 (tabularray treats X-column
    # weights as relative; absolute values don't matter, only
    # ratios).
    return(sprintf(
      "X[%g,%s]",
      parsed$value / 100,
      align_letter
    ))
  }
  sprintf("Q[%s,wd=%s]", align_letter, .dim_format(parsed))
}

# Map an align value to the single-letter tabularray code.
.latex_align_letter <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("l")
  }
  switch(
    align,
    left = "l",
    center = "c",
    right = "r",
    decimal = "r",
    "l"
  )
}

# Map an `align` value to a tabularray column spec token.
# `decimal` uses tabularray's siunitx-backed `Q[si=...]` so
# the decimal points align even without engine-decimal padding
# — but the engine already padded with NBSP, so right-align is
# functionally equivalent and cheaper.
.latex_align_token <- function(align) {
  if (is.null(align) || length(align) == 0L || is.na(align)) {
    return("Q[l]")
  }
  switch(
    align,
    left = "Q[l]",
    center = "Q[c]",
    right = "Q[r]",
    decimal = "Q[r]",
    "Q[l]"
  )
}

# Render multi-level header bands using real `\SetCell` colspan.
# For each band-row depth we walk visible columns left-to-right
# and group contiguous runs sharing the same band label (or
# none); each run emits one `\SetCell[c=N]{c}` cell. Returns a
# character vector of zero or more rows (zero when no bands
# exist).
.render_latex_header_bands <- function(headers, col_names_visible) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  depths <- sort(unique(headers$depth))
  vapply(
    depths,
    function(d) {
      band_at_depth <- headers[headers$depth == d, , drop = FALSE]
      labels <- vapply(
        col_names_visible,
        function(nm) {
          hit <- vapply(
            seq_len(nrow(band_at_depth)),
            function(i) nm %in% band_at_depth$span_cols[[i]],
            logical(1L)
          )
          if (any(hit)) {
            band_at_depth$label[which(hit)[1L]]
          } else {
            NA_character_
          }
        },
        character(1L)
      )
      runs <- .group_contiguous_runs(labels)
      .runs_to_band_row(runs)
    },
    character(1L)
  )
}

# Turn a list of `{value, length}` runs into a single tblr row
# string. Each run becomes a `\SetCell[c=N]{c} <label>` (when
# the band is named) or a bare empty cell (when NA). Cells are
# `&`-joined; trailing `\\` terminates the row.
.runs_to_band_row <- function(runs) {
  cells <- character()
  for (run in runs) {
    span <- run$length
    if (is.na(run$value)) {
      # NA run: emit `span` empty cells separated by `&`. The
      # first cell holds the empty slot; the rest are simple `&`
      # markers (no \SetCell needed for single columns).
      cells <- c(cells, rep("", span))
    } else {
      lbl <- .latex_escape(run$value)
      if (span == 1L) {
        cells <- c(cells, lbl)
      } else {
        # `\SetCell` occupies the run-start cell; the remaining
        # `span-1` cells are NULL placeholders (they don't print
        # but tabularray needs them to keep column count).
        cells <- c(
          cells,
          sprintf("\\SetCell[c=%d]{c} %s", span, lbl),
          rep("", span - 1L)
        )
      }
    }
  }
  paste0(paste(cells, collapse = " & "), " \\\\")
}

# Render the column-labels row: one cell per visible column,
# pulled from `col_labels_ast`. Falls back to the column name
# when the spec did not set a label for that column.
.render_latex_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols
) {
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      if (is.null(ast)) {
        return(.latex_escape(nm))
      }
      .render_latex_inline(ast)
    },
    character(1L)
  )
  paste0(paste(cells, collapse = " & "), " \\\\")
}

# Render one body row per data row. Cell text is the post-
# engine_decimal `cells_text` slice; embedded `\n` becomes `\\`
# inside the cell. `&` and other LaTeX specials are escaped.
.render_latex_body_rows <- function(cells_text) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }
  vapply(
    seq_len(nrow_data),
    function(i) {
      cells <- vapply(
        seq_len(ncol(cells_text)),
        function(j) .latex_escape_cell(cells_text[i, j]),
        character(1L)
      )
      paste0(paste(cells, collapse = " & "), " \\\\")
    },
    character(1L)
  )
}

# ---------------------------------------------------------------------
# Inline AST renderer
# ---------------------------------------------------------------------

# Render an `inline_ast` to a single LaTeX string. Walks every
# run in `ast@runs` recursively. Unknown run types fall through
# to their (escaped) `text` field.
.render_latex_inline <- function(ast) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  paste0(
    vapply(ast@runs, .render_latex_run, character(1L)),
    collapse = ""
  )
}

# Render one AST run record to its LaTeX markup. Recurses
# through `children` for wrapping types.
.render_latex_run <- function(run) {
  type <- run$type
  switch(
    type,
    plain = .latex_escape(run$text %||% ""),
    bold = paste0("\\textbf{", .render_latex_children(run$children), "}"),
    italic = paste0("\\textit{", .render_latex_children(run$children), "}"),
    sup = paste0(
      "\\textsuperscript{",
      .render_latex_children(run$children),
      "}"
    ),
    sub = paste0(
      "\\textsubscript{",
      .render_latex_children(run$children),
      "}"
    ),
    code = paste0("\\texttt{", .render_latex_children(run$children), "}"),
    link = .render_latex_link(run),
    span = .render_latex_children(run$children),
    newline = " \\\\ ",
    .latex_escape(run$text %||% "")
  )
}

# Render the children of a wrapping run. The children are
# themselves a list of run records; walk each and concatenate.
.render_latex_children <- function(children) {
  if (length(children) == 0L) {
    return("")
  }
  paste0(
    vapply(children, .render_latex_run, character(1L)),
    collapse = ""
  )
}

# Render a link run as `\href{url}{text}` (requires the
# `hyperref` package, already in the preamble). Title attribute
# from the inline_ast is dropped (no equivalent in `\href`).
.render_latex_link <- function(run) {
  text <- .render_latex_children(run$children)
  href <- run$href %||% ""
  sprintf("\\href{%s}{%s}", .latex_escape_url(href), text)
}

# ---------------------------------------------------------------------
# Escaping helpers
# ---------------------------------------------------------------------

# LaTeX-escape a string for safe insertion into the document
# body. The ten characters with special meaning in standard
# LaTeX are escaped to their printable equivalents. NULL / NA /
# length-0 collapse to the empty string.
.latex_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  # Pass 1: rewrite the three "expand to brace-containing macros"
  # chars to sentinels so the second-pass `{` / `}` escape doesn't
  # touch the macros' own braces. The sentinels use control chars
  # that cannot appear in legitimate user text.
  text <- gsub("\\", "\1BSL\1", text, fixed = TRUE)
  text <- gsub("~", "\1TILDE\1", text, fixed = TRUE)
  text <- gsub("^", "\1CARET\1", text, fixed = TRUE)
  # Pass 2: simple single-char escapes.
  text <- gsub("{", "\\{", text, fixed = TRUE)
  text <- gsub("}", "\\}", text, fixed = TRUE)
  text <- gsub("&", "\\&", text, fixed = TRUE)
  text <- gsub("%", "\\%", text, fixed = TRUE)
  text <- gsub("$", "\\$", text, fixed = TRUE)
  text <- gsub("#", "\\#", text, fixed = TRUE)
  text <- gsub("_", "\\_", text, fixed = TRUE)
  # Pass 3: finalize the sentinels to their `{}`-bearing macros
  # AFTER the brace pass so the macros' own braces stay literal.
  text <- gsub("\1BSL\1", "\\textbackslash{}", text, fixed = TRUE)
  text <- gsub("\1TILDE\1", "\\textasciitilde{}", text, fixed = TRUE)
  text <- gsub("\1CARET\1", "\\textasciicircum{}", text, fixed = TRUE)
  text
}

# Cell-level escape — full LaTeX escape PLUS `\n` (and `\r\n`)
# -> `\\` so multi-line strings emitted by engine_decimal
# render as proper line breaks inside tblr cells.
.latex_escape_cell <- function(text) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  text <- .latex_escape(text)
  # LaTeX in-cell line break is `\\` (two literal backslashes).
  text <- gsub("\r\n", " \\\\ ", text, fixed = TRUE)
  text <- gsub("\n", " \\\\ ", text, fixed = TRUE)
  text
}

# Lightly escape a URL for `\href{...}{...}`. Only `%`, `#`, and
# `\\` need escaping in the URL slot; other URL-legal chars
# (`?`, `=`, `&`) pass through verbatim because hyperref reads
# the first arg in verbatim-ish mode.
.latex_escape_url <- function(href) {
  if (is.null(href) || length(href) == 0L) {
    return("")
  }
  href <- as.character(href)
  href[is.na(href)] <- ""
  href <- gsub("\\", "\\\\", href, fixed = TRUE)
  href <- gsub("%", "\\%", href, fixed = TRUE)
  href <- gsub("#", "\\#", href, fixed = TRUE)
  href
}

# Group a vector into runs of consecutive equal values
# (NA-equal-to-NA). Returns a list of `{value, length}`
# records. Used by the header-band renderer to compute
# `\SetCell` colspans.
.group_contiguous_runs <- function(x) {
  n <- length(x)
  if (n == 0L) {
    return(list())
  }
  runs <- list()
  start <- 1L
  for (i in seq_len(n)[-1L]) {
    cur <- x[[i]]
    prev <- x[[i - 1L]]
    same <- (is.na(cur) && is.na(prev)) ||
      (!is.na(cur) && !is.na(prev) && identical(cur, prev))
    if (!same) {
      runs[[length(runs) + 1L]] <- list(
        value = x[[start]],
        length = i - start
      )
      start <- i
    }
  }
  runs[[length(runs) + 1L]] <- list(
    value = x[[start]],
    length = n - start + 1L
  )
  runs
}

# ---------------------------------------------------------------------
# Preamble — minimum tabularray + hyperref + geometry + utf8
# ---------------------------------------------------------------------

# Self-contained article-class preamble, driven by the
# preset_spec carried on `grid@metadata$preset`. backend_pdf
# may override by stripping this and prepending its own; the
# standalone `emit(spec, "out.tex")` path uses this as-is so
# the .tex compiles on its own via `xelatex out.tex`.
#
# Preset properties consumed:
#
# * `font_size`    -> `\documentclass[Xpt]{...}` (LaTeX standard
#                     classes accept 10pt / 11pt / 12pt only;
#                     larger sizes get `\fontsize` after
#                     `\begin{document}`).
# * `font_family`  -> `\setmainfont{...}` via `fontspec` when
#                     `xelatex` / `lualatex` is the engine
#                     (which is what tinytex defaults to). For
#                     `pdflatex` we map a small set of
#                     well-known families to their TeX bundles.
# * `orientation`  -> `geometry`'s `landscape` option.
# * `paper_size`   -> `geometry`'s paper-size option
#                     (`letterpaper` / `a4paper` / etc.).
.latex_preamble <- function(
  preset = NULL,
  pagehead_ast = NULL,
  pagefoot_ast = NULL
) {
  if (is.null(preset) || !is_preset_spec(preset)) {
    preset <- preset_spec()
  }
  geo <- .latex_geometry_opts(preset)
  class_opt <- .latex_class_size(preset@font_size)
  font_lines <- .latex_font_lines(preset@font_family, preset@font_size)
  chrome <- .latex_pagestyle_block(pagehead_ast, pagefoot_ast, preset)

  c(
    sprintf("\\documentclass[%s]{article}", class_opt),
    sprintf("\\usepackage[%s]{geometry}", geo),
    "\\usepackage[T1]{fontenc}",
    "\\usepackage[utf8]{inputenc}",
    "\\usepackage{tabularray}",
    "\\usepackage{xcolor}",
    "\\usepackage{graphicx}",
    "\\usepackage{hyperref}",
    "\\UseTblrLibrary{siunitx}",
    chrome$packages,
    font_lines,
    "\\setlength{\\parindent}{0pt}",
    chrome$style
  )
}

# Compose the fancyhdr + lastpage scaffolding from resolved page
# bands. Returns `list(packages, style)`:
#   - `packages` is the extra `\usepackage` lines (only when at
#     least one band is populated).
#   - `style` is the `\pagestyle{fancy}` + `\fancyhf{}` +
#     `\fancyhead[L/C/R]{}` / `\fancyfoot[L/C/R]{}` block (only
#     when populated). Multi-row bands collapse to multi-line via
#     `\\` line joins; pagehead reverses index order (so index 1
#     ends up at the bottom of the header zone, body edge);
#     pagefoot keeps forward order (index 1 at the top, body edge).
#   - When both bands are empty, both fields are empty character
#     vectors — the document keeps the LaTeX-default `plain` page
#     style.
.latex_pagestyle_block <- function(pagehead_ast, pagefoot_ast, preset) {
  ph_pop <- .page_band_is_populated(pagehead_ast)
  pf_pop <- .page_band_is_populated(pagefoot_ast)
  if (!ph_pop && !pf_pop) {
    return(list(packages = character(), style = character()))
  }
  packages <- c(
    "\\usepackage{fancyhdr}",
    "\\usepackage{lastpage}"
  )
  body <- "\\pagestyle{fancy}"
  body <- c(body, "\\fancyhf{}")
  # Bump headheight per row count so multi-row pagehead doesn't
  # overflow the default header zone.
  if (ph_pop) {
    nrow_h <- .page_band_nrow(pagehead_ast)
    headheight_pt <- max(12, (preset@font_size + 4) * nrow_h)
    body <- c(
      body,
      sprintf("\\setlength{\\headheight}{%dpt}", as.integer(headheight_pt))
    )
  }
  if (ph_pop) {
    body <- c(
      body,
      .latex_band_directives(pagehead_ast, head = TRUE)
    )
  }
  if (pf_pop) {
    body <- c(
      body,
      .latex_band_directives(pagefoot_ast, head = FALSE)
    )
  }
  # Suppress the default head- and footrule lines (fancyhdr draws
  # a 0.4pt rule by default). Backends own border policy via
  # preset@hlines; the page bands are unruled.
  body <- c(
    body,
    "\\renewcommand{\\headrulewidth}{0pt}",
    "\\renewcommand{\\footrulewidth}{0pt}"
  )
  list(packages = packages, style = body)
}

# Emit the three `\fancyhead[L/C/R]{}` (when head = TRUE) or
# `\fancyfoot[L/C/R]{}` (head = FALSE) directives for one band.
# Empty slots emit `\fancyhead[L]{}` (or equivalent) so any prior
# default for that slot is cleared.
.latex_band_directives <- function(band, head) {
  cmd <- if (head) "\\fancyhead" else "\\fancyfoot"
  c(
    sprintf("%s[L]{%s}", cmd, .latex_band_slot_text(band$left, head = head)),
    sprintf(
      "%s[C]{%s}",
      cmd,
      .latex_band_slot_text(band$center, head = head)
    ),
    sprintf("%s[R]{%s}", cmd, .latex_band_slot_text(band$right, head = head))
  )
}

# Collapse N rows of one slot's inline_asts to a single LaTeX
# fragment suitable for the inside of `\fancyhead[L]{...}`. Rows
# join with `\\` (a LaTeX line break that works inside fancyhdr
# slot content). Empty cells contribute empty strings (`""` ->
# `""`). Token substitution (`{page}` -> `\thepage`, `{npages}`
# -> `\pageref{LastPage}`) runs per-cell after `.render_latex_inline`.
.latex_band_slot_text <- function(slot_asts, head) {
  if (length(slot_asts) == 0L) {
    return("")
  }
  order <- if (head) rev(seq_along(slot_asts)) else seq_along(slot_asts)
  parts <- vapply(
    order,
    function(i) {
      ast <- slot_asts[[i]]
      if (!is_inline_ast(ast) || length(ast@runs) == 0L) {
        return("")
      }
      .latex_resolve_page_tokens(.render_latex_inline(ast))
    },
    character(1L)
  )
  paste(parts, collapse = "\\\\")
}

# Substitute the backend-phase `{page}` and `{npages}` tokens
# inside a flat LaTeX fragment string. `.render_latex_inline`
# escapes braces in plain text, so the tokens arrive here as
# `\{page\}` / `\{npages\}`; we match the escaped form and swap in
# the LaTeX field commands. fancyhdr expands `\thepage` /
# `\pageref{LastPage}` at compile time. Idempotent on text that
# contains neither token.
.latex_resolve_page_tokens <- function(text) {
  text <- gsub("\\{npages\\}", "\\pageref{LastPage}", text, fixed = TRUE)
  text <- gsub("\\{page\\}", "\\thepage{}", text, fixed = TRUE)
  text
}

# Compose the `geometry` package option list from a preset_spec.
# Emits the paper-size keyword; appends `landscape` when set;
# emits per-side margin options driven by `preset@margins`,
# which follows CSS shorthand:
#
# * length 1: all four sides equal
# * length 2: vertical (top + bottom), horizontal (left + right)
# * length 4: top, right, bottom, left
#
# Each value is interpreted in inches. To use different units,
# pass a character expression instead (e.g. `c("2cm","1cm")`).
.latex_geometry_opts <- function(preset) {
  paper <- preset@paper_size
  paper_opt <- switch(
    paper,
    letter = "letterpaper",
    legal = "legalpaper",
    a4 = "a4paper",
    sprintf("%spaper", paper)
  )
  parts <- c(paper_opt, .latex_margin_opts(preset@margins))
  if (identical(preset@orientation, "landscape")) {
    parts <- c(parts, "landscape")
  }
  paste(parts, collapse = ", ")
}

# Expand a CSS-shorthand margin vector to one or more
# `geometry` margin keywords (`margin=` for uniform; `top=` /
# `right=` / `bottom=` / `left=` for per-side). Each element
# routes through `.parse_dim` so numeric inches and character
# units (in/cm/mm/pt/pc) format consistently.
.latex_margin_opts <- function(m) {
  parsed <- lapply(seq_along(m), function(i) {
    .parse_dim(m[[i]], allow_percent = FALSE)
  })
  if (length(parsed) == 1L) {
    return(sprintf("margin=%s", .dim_format(parsed[[1L]])))
  }
  if (length(parsed) == 2L) {
    return(c(
      sprintf("top=%s", .dim_format(parsed[[1L]])),
      sprintf("bottom=%s", .dim_format(parsed[[1L]])),
      sprintf("left=%s", .dim_format(parsed[[2L]])),
      sprintf("right=%s", .dim_format(parsed[[2L]]))
    ))
  }
  c(
    sprintf("top=%s", .dim_format(parsed[[1L]])),
    sprintf("right=%s", .dim_format(parsed[[2L]])),
    sprintf("bottom=%s", .dim_format(parsed[[3L]])),
    sprintf("left=%s", .dim_format(parsed[[4L]]))
  )
}

# LaTeX's standard classes (article / report / book) only
# accept 10pt / 11pt / 12pt as the class option. For other
# sizes we still pass the nearest standard option here and
# scale via `\fontsize` inside the document body — that path
# is added by backend_pdf when it wraps backend_latex's output.
.latex_class_size <- function(font_size) {
  size <- tryCatch(as.numeric(font_size), error = function(e) 11)
  if (length(size) == 0L || !is.finite(size)) {
    return("11pt")
  }
  if (size <= 10.5) {
    return("10pt")
  }
  if (size <= 11.5) {
    return("11pt")
  }
  "12pt"
}

# Compose the font-family preamble lines. Engine-agnostic:
# emits both a `fontspec` block (used by xelatex / lualatex) and
# a conservative `pdflatex` fallback (mapping common family
# names to their TeX bundle packages). The `iftex` package guard
# keeps the file compilable under all three engines.
#
# `font_family` may be a single generic (`"serif"`/`"sans"`/`"mono"`),
# a single named font (`"Times New Roman"`), or an explicit stack
# (`c("Courier New", "mono")`). For LaTeX we resolve the chain
# via `.resolve_font_stack("latex")` and take the first entry as
# the primary fontspec font; the pdflatex branch picks the right
# TeX bundle from the generic-family hint embedded in the chain.
.latex_font_lines <- function(font_family, font_size) {
  if (length(font_family) == 0L) {
    font_family <- "serif"
  }
  chain <- .resolve_font_stack(font_family, "latex")
  size <- tryCatch(as.numeric(font_size), error = function(e) 11)
  if (length(size) == 0L || !is.finite(size)) {
    size <- 11
  }
  leading <- size * 1.2
  pdftex_pkg <- .latex_pdftex_font_pkg(font_family)
  c(
    "\\usepackage{iftex}",
    "\\ifPDFTeX",
    if (nzchar(pdftex_pkg)) {
      sprintf("  \\usepackage{%s}", pdftex_pkg)
    } else {
      "  % pdflatex: keep default Computer Modern"
    },
    "\\else",
    "  \\usepackage{fontspec}",
    .latex_fontspec_cascade(chain),
    "\\fi",
    sprintf("\\fontsize{%g}{%g}\\selectfont", size, leading)
  )
}

# Compose a fontspec `\IfFontExistsTF` cascade for the resolved
# chain. xelatex / lualatex checks each candidate at compile time
# on the consuming machine and uses the first one present —
# analogous to how a browser walks a CSS `font-family` stack. The
# last entry is used unconditionally as the final fallback (no
# `\IfFontExistsTF` wrap, since by then we've exhausted the
# chain and want SOME font to render).
.latex_fontspec_cascade <- function(chain) {
  if (length(chain) == 0L) {
    return("  \\setmainfont{Latin Modern Roman}")
  }
  if (length(chain) == 1L) {
    return(sprintf("  \\setmainfont{%s}", chain[[1L]]))
  }
  # Build nested IfFontExistsTF blocks: each tier tries one font,
  # falls through to the next on failure. The deepest tier is the
  # unconditional final fallback.
  tail_entry <- chain[[length(chain)]]
  inner <- sprintf("\\setmainfont{%s}", tail_entry)
  for (i in seq.int(length(chain) - 1L, 1L)) {
    inner <- sprintf(
      "\\IfFontExistsTF{%s}{\\setmainfont{%s}}{%s}",
      chain[[i]],
      chain[[i]],
      inner
    )
  }
  paste0("  ", inner)
}

# Map a font-family input to a pdflatex package. Generic families
# (`serif` / `sans` / `mono`) route to the TeX Gyre bundles that
# ship with TeX Live — universal where LaTeX is installed. Common
# named families (Times / Helvetica / Arial / Courier / Palatino)
# route to their classic pdflatex bundles. Everything else falls
# back to Computer Modern (the LaTeX default) under pdflatex; the
# `\setmainfont` line under xelatex / lualatex uses the named
# family verbatim.
.latex_pdftex_font_pkg <- function(family) {
  if (length(family) == 0L) {
    return("")
  }
  # For an explicit stack take the head; the chain semantics are
  # CSS-style and pdflatex can only honour one bundle at a time.
  fam <- as.character(family)[[1L]]
  if (.is_generic_family(fam)) {
    return(switch(
      .normalize_generic(fam),
      serif = "tgtermes",
      sans = "tgheros",
      mono = "tgcursor",
      ""
    ))
  }
  fam <- tolower(fam)
  if (grepl("times", fam, fixed = TRUE)) {
    return("mathptmx")
  }
  if (
    grepl("helvetica", fam, fixed = TRUE) || grepl("arial", fam, fixed = TRUE)
  ) {
    return("helvet")
  }
  if (grepl("courier", fam, fixed = TRUE)) {
    return("courier")
  }
  if (grepl("palatino", fam, fixed = TRUE)) {
    return("mathpazo")
  }
  ""
}

# `%||%` — local fallback when rlang's is not in scope. Mirrors
# rlang::`%||%` semantics: returns `b` when `a` is NULL.
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("latex", backend_latex)
