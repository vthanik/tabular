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
  cs <- meta$chrome_style %||% chrome_style()
  c(
    .render_latex_title_block(meta$titles_ast, preset = meta$preset, cs = cs),
    "",
    "\\emph{(no rows)}",
    "",
    .render_latex_footnote_block(
      meta$footnotes_ast,
      preset = meta$preset,
      cs = cs
    )
  )
}

# Render one page block. Page 1 carries titles + footnotes;
# continuation pages get the (optional) `continuation` marker.
# Header bands + column-labels row repeat across page breaks
# via `longtblr`'s `rowhead = N` mechanism (computed from the
# number of band-rows + 1 for the column-labels row).
.render_latex_page <- function(page, meta, page_number, total_pages) {
  out <- character()
  cs <- meta$chrome_style %||% chrome_style()
  pad_title_top <- .latex_blank_count(cs, "title", "above", 1L)
  pad_title_bottom <- .latex_blank_count(cs, "title", "below", 1L)
  pad_body_top <- 0L
  pad_body_bottom <- 0L

  if (page_number == 1L) {
    titles <- .render_latex_title_block(
      meta$titles_ast,
      preset = meta$preset,
      cs = cs
    )
    if (length(titles) > 0L) {
      out <- c(
        out,
        rep("", pad_title_top),
        titles,
        rep("", pad_title_bottom)
      )
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

  out <- c(out, rep("", pad_body_top))
  out <- c(out, .render_latex_table(page, meta, cs))
  out <- c(out, rep("", pad_body_bottom))

  if (page_number == 1L) {
    footnotes <- .render_latex_footnote_block(
      meta$footnotes_ast,
      preset = meta$preset,
      cs = cs
    )
    if (length(footnotes) > 0L) {
      out <- c(out, footnotes)
    }
  }
  out
}

# Resolve the blank-line count for a chrome surface side. chrome_style
# wins when the user set `style(blank_above = N, at = cells_title())`;
# otherwise the legacy preset `*_pad_*` scalar fills in.
.latex_blank_count <- function(cs, surface, side, legacy) {
  node <- .chrome_surface_at(cs, surface)
  prop <- if (identical(side, "above")) node@blank_above else node@blank_below
  if (length(prop) == 1L && !is.na(prop)) {
    return(max(0L, as.integer(prop)))
  }
  max(0L, as.integer(legacy))
}

# ---------------------------------------------------------------------
# Title + footnote blocks
# ---------------------------------------------------------------------

# Title block: each title line emits as a bold paragraph whose
# alignment comes from `chrome_style$surfaces$title@halign` (scalar
# broadcasts; vector zips per-line). Cascade default centre.
.render_latex_title_block <- function(titles_ast, preset = NULL, cs = NULL) {
  n <- length(titles_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "title")
  unlist(lapply(
    seq_len(n),
    function(i) {
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        h <- .effective_title_halign(preset, line_index = i, n_lines = n)
        if (is.na(h)) "center" else h
      }
      bold_open <- if (
        is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
      ) {
        ""
      } else {
        "{\\bfseries "
      }
      bold_close <- if (identical(bold_open, "")) "" else "}"
      body <- .latex_wrap_text_props(
        paste0(
          bold_open,
          .render_latex_inline(titles_ast[[i]]),
          bold_close
        ),
        surface_node
      )
      .latex_aligned_paragraph(body = body, halign = halign)
    }
  ))
}

# Footnote block: each footnote line emits as a paragraph at
# slightly smaller font (\small ... \normalsize) whose alignment
# comes from `chrome_style$surfaces$footer@halign` (scalar broadcasts;
# vector zips per-line). Cascade default left.
.render_latex_footnote_block <- function(
  footnotes_ast,
  preset = NULL,
  cs = NULL
) {
  n <- length(footnotes_ast)
  if (n == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "footer")
  rendered <- unlist(lapply(
    seq_len(n),
    function(i) {
      halign <- if (
        is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        h <- .effective_footnote_halign(
          preset,
          line_index = i,
          n_lines = n
        )
        if (is.na(h)) "left" else h
      }
      body <- .latex_wrap_text_props(
        .render_latex_inline(footnotes_ast[[i]]),
        surface_node
      )
      .latex_aligned_paragraph(body = body, halign = halign)
    }
  ))
  c("\\noindent\\small", rendered, "\\normalsize")
}

# Wrap an inline-rendered fragment in the LaTeX environment that
# produces the requested horizontal alignment. We use the standard
# `center` / `flushleft` / `flushright` environments rather than
# inline `\centering` so the alignment scope is unambiguous (and
# composes inside `\noindent\small ... \normalsize` blocks).
.latex_aligned_paragraph <- function(body, halign) {
  env <- switch(
    halign,
    left = "flushleft",
    center = "center",
    right = "flushright",
    "flushleft"
  )
  c(
    paste0("\\begin{", env, "}"),
    paste0(body, "\\par"),
    paste0("\\end{", env, "}")
  )
}

# ---------------------------------------------------------------------
# Table assembly: longtblr environment
# ---------------------------------------------------------------------

# Render one page's table as a `\begin{longtblr}` ... `\end{longtblr}`
# block. tabularray's `longtblr` auto-paginates and repeats
# `rowhead` rows on continuation pages.
.render_latex_table <- function(page, meta, cs = NULL) {
  col_names_vis <- page$col_names
  cols <- meta$cols %||% list()
  colspec <- .latex_colspec(col_names_vis, cols)

  band_rows <- .render_latex_header_bands(meta$headers, col_names_vis, cs)
  label_row <- .render_latex_col_labels_row(
    meta$col_labels_ast,
    col_names_vis,
    cols,
    cs
  )
  rowhead <- length(band_rows) + 1L

  # Chrome borders: header_top / header_bottom / footer_top come
  # from `chrome_style$borders` when the user set them via
  # `style(border_top = brdr(...), at = cells_headers())` and
  # similar; otherwise fall through to the canonical `\hline`
  # rules.
  hline_header_top <- .latex_chrome_hline(cs, "header_top")
  hline_header_bottom <- .latex_chrome_hline(cs, "header_bottom")
  hline_footer_top <- .latex_chrome_hline(cs, "footer_top")
  header_rules <- c(
    hline_header_top,
    band_rows,
    label_row,
    hline_header_bottom
  )
  body_rows <- .render_latex_body_rows(
    page$cells_text,
    col_names_vis = col_names_vis,
    cells_style = page$cells_style,
    cells_indent = page$cells_indent,
    is_header_row = page$is_header_row,
    is_blank_row = page$is_blank_row,
    host_col = page$host_col,
    cols = cols,
    preset = meta$preset
  )
  footer_rule <- hline_footer_top

  # Subgroup banner row — `\SetCell[c=N]{c|l|r}` spanning every
  # visible column. Inserted between the header rule and the first
  # body row so it sits directly under the column-header band on
  # every page of the group. Returns character(0) when the page
  # has no subgroup runtime.
  banner_row <- .render_latex_subgroup_banner_row(
    page$subgroup_line_ast,
    n_cols = length(col_names_vis),
    preset = meta$preset,
    cs = cs
  )

  # Table-level row baseline from cells_style[r,c]@valign
  # (cascade default top). Per-cell overrides emit `\SetCell{...}`.
  body_valign <- .preset_align(meta$preset, "body_valign")
  if (is.na(body_valign)) {
    body_valign <- "top"
  }
  # tabularray border manifest. Reads `meta$body_borders` — the
  # resolved-triples sidecar built by `body_border_manifest()` from
  # the spec's cells_table layer cascade — and emits one
  # `hline{i}={spec}` / `vline{j}={spec}` per non-null side.
  # Header band occupies rows 1..rowhead; first body row index is
  # `rowhead + 1` (offset by the band row count + label row already
  # in `header_rules`). nrow_body / n_cols_vis bound the loops.
  nrow_body <- length(body_rows)
  border_directives <- .latex_border_directives(
    body_borders = meta$body_borders,
    rowhead = rowhead,
    nrow_body = nrow_body,
    n_cols_vis = length(col_names_vis)
  )
  rows_inner <- c(
    sprintf("valign=%s", .latex_valign_letter(body_valign)),
    .latex_rowsep_inner(page$cells_style)
  )
  outer_args <- paste(
    c(
      sprintf("colspec={%s}", colspec),
      sprintf("rowhead=%d", rowhead),
      sprintf("rows={%s}", paste(rows_inner, collapse = ", ")),
      border_directives
    ),
    collapse = ", "
  )
  c(
    paste0("\\begin{longtblr}[caption={}, label={}]{", outer_args, "}"),
    header_rules,
    banner_row,
    body_rows,
    footer_rule,
    "\\end{longtblr}"
  )
}

# Translate the resolved body-region triples (one slot per side on
# the `body_borders` sidecar built by `body_border_manifest()`) to
# tabularray's `hline{i}={spec}` / `vline{j}={spec}` directives.
# Returns a character vector (zero or more entries) ready to splice
# into the outer longtblr arg string.
#
# Region -> tabularray mapping:
#   outer_top    -> hline{rowhead + 1}        (top of body)
#   outer_bottom -> hline{rowhead + nrow + 1} (below last body row)
#   outer_left   -> vline{1}                  (left of col 1)
#   outer_right  -> vline{n_cols + 1}         (right of last col)
#   rows         -> hline{rowhead+2..rowhead+nrow} (between body rows)
#   cols         -> vline{2..n_cols}          (between body cols)
#
# Rows 1..rowhead are the header band; tabularray's hline{N}
# numbering counts from the table's top row, so the body's first
# row is at index `rowhead + 1`. Per-cell predicate borders from
# `style()` against `cells_body()` are NOT routed through this
# surface; they ride on cells_style[r,c] and are emitted by the
# per-cell `\SetCell{borders}` path.
.latex_border_directives <- function(
  body_borders,
  rowhead,
  nrow_body,
  n_cols_vis
) {
  if (!is.list(body_borders) || length(body_borders) == 0L) {
    return(character())
  }
  out <- character()
  body_first <- rowhead + 1L
  body_last <- rowhead + nrow_body
  if (!is.null(body_borders$outer_top)) {
    spec <- .latex_border_spec(body_borders$outer_top)
    if (nzchar(spec)) {
      out <- c(out, sprintf("hline{%d}={%s}", body_first, spec))
    }
  }
  if (!is.null(body_borders$outer_bottom) && nrow_body > 0L) {
    spec <- .latex_border_spec(body_borders$outer_bottom)
    if (nzchar(spec)) {
      out <- c(out, sprintf("hline{%d}={%s}", body_last + 1L, spec))
    }
  }
  if (!is.null(body_borders$outer_left)) {
    spec <- .latex_border_spec(body_borders$outer_left)
    if (nzchar(spec)) {
      out <- c(out, sprintf("vline{1}={%s}", spec))
    }
  }
  if (!is.null(body_borders$outer_right)) {
    spec <- .latex_border_spec(body_borders$outer_right)
    if (nzchar(spec)) {
      out <- c(out, sprintf("vline{%d}={%s}", n_cols_vis + 1L, spec))
    }
  }
  if (!is.null(body_borders$rows) && nrow_body > 1L) {
    spec <- .latex_border_spec(body_borders$rows)
    if (nzchar(spec)) {
      for (i in seq(body_first + 1L, body_last)) {
        out <- c(out, sprintf("hline{%d}={%s}", i, spec))
      }
    }
  }
  if (!is.null(body_borders$cols) && n_cols_vis > 1L) {
    spec <- .latex_border_spec(body_borders$cols)
    if (nzchar(spec)) {
      for (j in seq(2L, n_cols_vis)) {
        out <- c(out, sprintf("vline{%d}={%s}", j, spec))
      }
    }
  }
  out
}

# Map one resolved border triple to a tabularray border-spec
# braced fragment. `none` -> ""; the caller skips emission.
# Style enum maps to tabularray's line-style keywords; width emits
# as `<pt>pt`; colour is passed verbatim when set (the engine
# leaves `currentColor` as-is; tabularray's default colour wins).
.latex_border_spec <- function(triple) {
  if (is.null(triple) || identical(triple$style, "none")) {
    return("")
  }
  style_kw <- switch(
    triple$style,
    solid = "solid",
    dashed = "dashed",
    dotted = "dotted",
    double = "double",
    dashdot = "dashdotted",
    "solid"
  )
  parts <- c(
    sprintf("%gpt", triple$width),
    style_kw
  )
  if (
    !is.null(triple$color) &&
      !is.na(triple$color) &&
      nzchar(triple$color) &&
      !identical(triple$color, "currentColor")
  ) {
    parts <- c(parts, paste0("fg=", triple$color))
  }
  paste(parts, collapse = ", ")
}

# Render the subgroup banner row inside a longtblr environment.
# `\SetCell[c=N]{c}` spans every visible column; trailing empty
# cells (`&`-separated) keep tabularray's column count consistent.
# Returns character(0) when the page has no subgroup runtime.
.render_latex_subgroup_banner_row <- function(
  subgroup_line_ast,
  n_cols,
  preset = NULL,
  cs = NULL
) {
  if (
    is.null(subgroup_line_ast) ||
      !is_inline_ast(subgroup_line_ast) ||
      length(subgroup_line_ast@runs) == 0L ||
      n_cols < 1L
  ) {
    return(character())
  }
  inner <- .render_latex_inline(subgroup_line_ast)
  surface_node <- .chrome_surface_at(cs, "subgroup")
  halign <- if (
    is_style_node(surface_node) &&
      length(surface_node@halign) == 1L &&
      !is.na(surface_node@halign)
  ) {
    surface_node@halign
  } else {
    h <- .effective_subgroup_halign(preset)
    if (is.na(h)) "center" else h
  }
  letter <- .latex_halign_letter(halign)
  bold_open <- if (
    is_style_node(surface_node) && isTRUE(surface_node@bold == FALSE)
  ) {
    ""
  } else {
    "\\textbf{"
  }
  bold_close <- if (identical(bold_open, "")) "" else "}"
  body <- .latex_wrap_text_props(
    paste0(bold_open, inner, bold_close),
    surface_node
  )
  row <- if (n_cols == 1L) {
    sprintf("\\SetCell{halign=%s} %s \\\\", letter, body)
  } else {
    paste0(
      sprintf("\\SetCell[c=%d]{%s} %s", n_cols, letter, body),
      paste(rep(" &", n_cols - 1L), collapse = ""),
      " \\\\"
    )
  }
  row
}

# Resolve a chrome border region into a `\hline` or a tabularray-
# style border directive. For LaTeX we keep it simple: when no
# user override is set, emit `\hline`; otherwise emit nothing here
# (tabularray's outer-line handling deals with explicit border
# widths). Width / style customisation will route through
# `.latex_border_directives` in a follow-up commit if needed.
.latex_chrome_hline <- function(cs, region) {
  triple <- .chrome_border_at(cs, region)
  if (is.null(triple)) {
    return("\\hline")
  }
  if (identical(triple$style, "none")) {
    return(character())
  }
  # For now keep the visual rule but the explicit override has
  # taken effect (caller may layer further in border directives).
  "\\hline"
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
  # Engine resolves every width to numeric inches (auto / pct /
  # dim string -> inches). Defensive fallback for the rare case
  # of a synthesised column without engine resolution: drop to
  # tabularray's natural-fit Q-column.
  if (!is.numeric(width) || length(width) != 1L || is.na(width)) {
    return(sprintf("Q[%s]", align_letter))
  }
  sprintf("Q[%s,wd=%fin]", align_letter, width)
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
.render_latex_header_bands <- function(
  headers,
  col_names_visible,
  cs = NULL
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(character())
  }
  surface_node <- .chrome_surface_at(cs, "header")
  depths <- sort(unique(headers$depth))
  vapply(
    depths,
    function(d) {
      labels <- .band_labels_for_depth(headers, d, col_names_visible)
      runs <- .group_contiguous_runs(labels)
      .runs_to_band_row(runs, surface_node)
    },
    character(1L)
  )
}

# Turn a list of `{value, length}` runs into a single tblr row
# string plus one `\cmidrule(lr){m-n}` line per named run. Each run
# becomes a `\SetCell[c=N]{c} <label>` (named) or a bare empty cell
# (NA). Cells are `&`-joined and the row terminates with `\\`. A
# trailing newline + one `\cmidrule(lr){start-end}` per named run
# emits the booktabs trim under the band's visible-column range,
# so adjacent bands meet but do not visually touch.
#
# Returned as ONE string with embedded newlines so the caller's
# `length(band_rows) + 1L` rowhead arithmetic stays a count of
# table rows (not lines).
.runs_to_band_row <- function(runs, surface_node = NULL) {
  cells <- character()
  rules <- character()
  cursor <- 1L
  for (run in runs) {
    span <- run$length
    start <- cursor
    end <- cursor + span - 1L
    if (is.na(run$value)) {
      cells <- c(cells, rep("", span))
    } else {
      lbl <- .latex_wrap_text_props(.latex_escape(run$value), surface_node)
      if (span == 1L) {
        cells <- c(cells, lbl)
      } else {
        cells <- c(
          cells,
          sprintf("\\SetCell[c=%d]{c} %s", span, lbl),
          rep("", span - 1L)
        )
      }
      rules <- c(rules, sprintf("\\cmidrule(lr){%d-%d}", start, end))
    }
    cursor <- end + 1L
  }
  row <- paste0(paste(cells, collapse = " & "), " \\\\")
  if (length(rules) == 0L) {
    return(row)
  }
  paste(c(row, rules), collapse = "\n")
}

# Render the column-labels row: one cell per visible column,
# pulled from `col_labels_ast`. Falls back to the column name
# when the spec did not set a label for that column.
.render_latex_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols,
  cs = NULL
) {
  surface_node <- .chrome_surface_at(cs, "header")
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      raw <- if (is.null(ast)) {
        .latex_escape(nm)
      } else {
        .render_latex_inline(ast)
      }
      .latex_wrap_text_props(raw, surface_node)
    },
    character(1L)
  )
  paste0(paste(cells, collapse = " & "), " \\\\")
}

# Render one body row per data row. Cell text is the post-
# engine_decimal `cells_text` slice; embedded `\n` becomes `\\`
# inside the cell. `&` and other LaTeX specials are escaped.
# Per-cell predicate overrides from `cells_style@halign / @valign`
# emit `\SetCell{halign=l/c/r,valign=t/m/b}` ahead of the cell
# content; column-level alignment from `col_spec@align` is carried
# by the colspec at the longtblr level. The table-level row
# baseline carries the preset's body_valign (`rows={valign=...}`)
# so non-style cells inherit the cascade default for vertical
# alignment without per-cell emission.
.render_latex_body_rows <- function(
  cells_text,
  col_names_vis = NULL,
  cells_style = NULL,
  cells_indent = NULL,
  is_header_row = NULL,
  is_blank_row = NULL,
  host_col = NA_character_,
  cols = NULL,
  preset = NULL
) {
  nrow_data <- nrow(cells_text)
  if (nrow_data == 0L) {
    return(character())
  }
  ncol_data <- ncol(cells_text)
  col_names_vis <- col_names_vis %||% rep(NA_character_, ncol_data)
  # Default the indent sidecar + row-type flags to no-op shape so any
  # caller that bypasses the engine still works.
  if (is.null(cells_indent)) {
    cells_indent <- matrix(0L, nrow = nrow_data, ncol = ncol_data)
  }
  is_header_row <- is_header_row %||% rep(FALSE, nrow_data)
  is_blank_row <- is_blank_row %||% rep(FALSE, nrow_data)
  # Per-level native padding in `pt` (LaTeX's tabularray takes pt for
  # `leftsep+=`). `.indent_native_pt_per_level()` is the single source
  # of truth shared with the leading-space strip below.
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_pt_per_level <- .indent_native_pt_per_level(preset)
  vapply(
    seq_len(nrow_data),
    function(i) {
      # Synthesised section-header / blank-gap rows render as a single
      # spanning cell mirroring the subgroup-banner shape — tabularray
      # requires (N-1) trailing `&` placeholders so the column count
      # stays consistent with the rest of the body.
      if (isTRUE(is_blank_row[[i]])) {
        return(paste0(
          if (ncol_data == 1L) {
            " "
          } else {
            paste(rep(" &", ncol_data - 1L), collapse = "")
          },
          " \\\\*"
        ))
      }
      if (isTRUE(is_header_row[[i]])) {
        host_text <- ""
        host_idx <- NA_integer_
        for (jj in seq_len(ncol_data)) {
          val <- cells_text[i, jj]
          if (!is.na(val) && nzchar(val)) {
            host_text <- val
            host_idx <- jj
            break
          }
        }
        # Band-depth padding on the spanning cell via tabularray's
        # `leftsep+=` cell option. Band-1 (depth 0) gets the bare
        # `\SetCell[c=N]{l}`; band-2+ adds `, leftsep+=Xpt`.
        setcell_opts <- "l"
        if (!is.na(host_idx)) {
          header_depth <- cells_indent[i, host_idx]
          if (isTRUE(header_depth > 0L) && indent_pt_per_level > 0) {
            setcell_opts <- sprintf(
              "l, leftsep+=%gpt",
              indent_pt_per_level * header_depth
            )
          }
        }
        body <- paste0("\\textbf{", .latex_escape_cell(host_text), "}")
        terminator <- if (i == nrow_data) " \\\\" else " \\\\*"
        if (ncol_data == 1L) {
          return(paste0(
            sprintf("\\SetCell{halign=%s} ", setcell_opts),
            body,
            terminator
          ))
        }
        return(paste0(
          sprintf("\\SetCell[c=%d]{%s} ", ncol_data, setcell_opts),
          body,
          paste(rep(" &", ncol_data - 1L), collapse = ""),
          terminator
        ))
      }
      cells <- vapply(
        seq_len(ncol_data),
        function(j) {
          raw <- cells_text[i, j]
          # Read per-cell depth from the engine sidecar. The engine
          # baked one indent level of spaces into the cell text per
          # depth unit; strip exactly that many leading spaces so
          # `leftsep+=` carries the indent semantically (wrapped
          # continuation lines align with the indented baseline,
          # matching the SAS PADDINGLEFT contract).
          depth <- cells_indent[i, j]
          extra_prefix <- NULL
          if (
            isTRUE(depth > 0L) &&
              indent_unit > 0L &&
              !is.na(raw)
          ) {
            n_leading <- indent_unit * depth
            if (
              nchar(raw) >= n_leading &&
                startsWith(raw, strrep(" ", n_leading))
            ) {
              raw <- substr(raw, n_leading + 1L, nchar(raw))
            }
            if (indent_pt_per_level > 0) {
              extra_prefix <- sprintf(
                "\\SetCell{leftsep+=%gpt} ",
                indent_pt_per_level * depth
              )
            }
          }
          text <- .latex_escape_cell(raw)
          nm <- col_names_vis[[j]]
          sn <- if (is.character(nm) && !is.na(nm)) {
            .cell_style_at(cells_style, i, nm)
          } else {
            style_node()
          }
          prefix <- .latex_setcell_alignment(sn)
          wrapped <- .latex_wrap_text_props(text, sn)
          paste0(extra_prefix %||% "", prefix, wrapped)
        },
        character(1L)
      )
      # `\\*` is LaTeX's no-page-break row terminator (inherited
      # by tabularray's longtblr from longtable). Emit it on every
      # row except the last of the page so the renderer never
      # re-paginates inside the page that engine_paginate already
      # split. The last row of the page uses the plain `\\` so the
      # natural longtblr / longtable page break can fall at the
      # end of the page. Galley pattern lifted to tabular's manual
      # pagination.
      terminator <- if (i == nrow_data) " \\\\" else " \\\\*"
      paste0(paste(cells, collapse = " & "), terminator)
    },
    character(1L)
  )
}

# Wrap one cell's escaped text with LaTeX macros for the seven text
# properties on a style_node: font_family, font_size, bold, italic,
# underline, color, background. Application order is fixed so the
# emitted source is stable: background -> color -> font_family ->
# font_size -> underline -> italic -> bold. Each macro is only
# applied when the property is explicitly set on the style_node;
# silent (NA) properties pass through.
#
# Macros used:
#   bold        \textbf{...}
#   italic      \textit{...}
#   underline   \underline{...}
#   color       \textcolor[HTML]{RRGGBB}{...}
#   background  \colorbox[HTML]{RRGGBB}{...}            (xcolor)
#   font_family {\fontfamily{ff}\selectfont ...}        (group-scoped)
#   font_size   {\fontsize{pt}{1.2pt}\selectfont ...}   (group-scoped)
.latex_wrap_text_props <- function(text, style) {
  if (!is_style_node(style) || !is.character(text) || length(text) != 1L) {
    return(text)
  }
  out <- text
  if (isTRUE(style@bold)) {
    out <- paste0("\\textbf{", out, "}")
  }
  if (isTRUE(style@italic)) {
    out <- paste0("\\textit{", out, "}")
  }
  if (isTRUE(style@underline)) {
    out <- paste0("\\underline{", out, "}")
  }
  fs <- style@font_size
  if (length(fs) == 1L && !is.na(fs) && is.numeric(fs)) {
    out <- sprintf(
      "{\\fontsize{%s}{%s}\\selectfont %s}",
      format(fs, trim = TRUE),
      format(fs * 1.2, trim = TRUE),
      out
    )
  }
  ff <- style@font_family
  if (length(ff) == 1L && !is.na(ff) && nzchar(ff)) {
    out <- sprintf("{\\fontfamily{%s}\\selectfont %s}", ff, out)
  }
  col <- style@color
  if (length(col) == 1L && !is.na(col) && nzchar(col)) {
    out <- sprintf(
      "\\textcolor[HTML]{%s}{%s}",
      .latex_normalize_hex_color(col),
      out
    )
  }
  bg <- style@background
  if (length(bg) == 1L && !is.na(bg) && nzchar(bg)) {
    out <- sprintf(
      "\\colorbox[HTML]{%s}{%s}",
      .latex_normalize_hex_color(bg),
      out
    )
  }
  out
}

# Strip the leading '#' from a hex colour for LaTeX's
# `\textcolor[HTML]{...}` / `\colorbox[HTML]{...}` syntax, which
# expects six hex digits without the '#'. Returns the input
# unchanged when it doesn't look like a CSS hex colour.
.latex_normalize_hex_color <- function(col) {
  if (!is.character(col) || length(col) != 1L || is.na(col)) {
    return(col)
  }
  if (startsWith(col, "#") && nchar(col) %in% c(7L, 4L)) {
    return(toupper(substring(col, 2L)))
  }
  col
}

# Build a `\SetCell{halign=l/c/r,valign=t/m/b}` prefix for one body
# cell, but only when the style_node carries explicit halign /
# valign overrides (predicate layer). Column-level alignment is
# carried by the colspec; emitting `\SetCell` for every cell would
# waste source and break tabularray's per-column wrapping. Returns
# "" when the style is silent.
#
# Per-side cell border emission via tabularray is deferred to
# Phase 6's brdr() integration: tabularray's per-cell border
# surface (`hlines={...}`/`vlines={...}` at table level keyed by
# row/col index) does not compose with a per-cell `\SetCell{}` and
# would require building a richer table-level border manifest.
# Phase 5 lands the cross-cutting surface (style_node scalars,
# resolver, DOCX/RTF/HTML emission); LaTeX gains border emission
# in Phase 6 when the `brdr()` constructor lets the table-level
# manifest accumulate per-cell entries cleanly.
# Emit tabularray `rowsep=Xpt` for the table-level `rows={...}` arg.
# After the Task 4/5 cut, body padding rides on cells_style[r,c]@padding
# — set by `style(at = cells_body(), padding = N)` or by the lowered
# `preset(padding = list(body = N))`. We peek at the first body cell's
# @padding as the canonical table-wide value; backends that need a
# scalar table-level setting (tabularray's rowsep, RTF's \trgaph,
# Word's tcMar) follow the same pattern.
#
# Returns an empty character vector when no padding override is
# active so the longtblr arg stays minimal.
.latex_rowsep_inner <- function(cells_style) {
  pt <- .first_cell_padding(cells_style)
  if (is.na(pt)) {
    return(character())
  }
  sprintf("rowsep=%spt", format(pt, trim = TRUE, scientific = FALSE))
}


.latex_setcell_alignment <- function(style) {
  if (!is_style_node(style)) {
    return("")
  }
  parts <- character()
  if (length(style@halign) == 1L && !is.na(style@halign)) {
    parts <- c(parts, paste0("halign=", .latex_halign_letter(style@halign)))
  }
  if (length(style@valign) == 1L && !is.na(style@valign)) {
    parts <- c(parts, paste0("valign=", .latex_valign_letter(style@valign)))
  }
  if (length(parts) == 0L) {
    return("")
  }
  paste0("\\SetCell{", paste(parts, collapse = ","), "} ")
}

# halign / valign letter helpers for tabularray's `\SetCell{...}`
# argument keys. tabularray uses single letters for both axes:
# l/c/r for halign; t/m/b for valign.
.latex_halign_letter <- function(halign) {
  switch(halign, left = "l", center = "c", right = "r", "l")
}
.latex_valign_letter <- function(valign) {
  switch(valign, top = "t", middle = "m", bottom = "b", "t")
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
  body_font_size <- .effective_font_size(preset)
  body_font_family <- .effective_font_family(preset)
  class_opt <- .latex_class_size(body_font_size)
  font_lines <- .latex_font_lines(body_font_family, body_font_size)
  chrome <- .latex_pagestyle_block(pagehead_ast, pagefoot_ast, preset)

  # Body-cell text colour is per-cell now via cells_style[r,c]@color
  # (set by `style(at = cells_body(), color = ...)` or by the lowered
  # `preset(colors = list(text = ...))` knob). The table-wide
  # `\definecolor{tabular_text}{HTML}{...} + \AtBeginDocument{\color{...}}`
  # preamble band was dropped in the Task 4/5 slot cut; the per-cell
  # stamps carry the visual equivalent.
  c(
    sprintf("\\documentclass[%s]{article}", class_opt),
    sprintf("\\usepackage[%s]{geometry}", geo),
    # Legacy text encoding gated behind pdftex. xelatex / lualatex
    # are natively UTF-8 and warn ("inputenc package ignored with
    # utf8 based engines") if these packages load unconditionally.
    "\\usepackage{iftex}",
    "\\ifPDFTeX",
    "  \\usepackage[T1]{fontenc}",
    "  \\usepackage[utf8]{inputenc}",
    "\\fi",
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

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("latex", backend_latex)
