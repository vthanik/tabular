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
# Output layout — ONE `longtblr` per (subgroup x panel) group, with
# `\clearpage` between groups. tabularray paginates the body natively;
# the title block repeats at the top of every physical page via the
# `firsthead`/`middlehead`/`lasthead` templates and the footnotes via
# `firstfoot`/`middlefoot`/`lastfoot` (a `minipage` at table width).
# Header bands + column-labels row repeat through `longtblr`'s `rowhead`
# mechanism, and the keep-with-next mask drives `\\*` so groups are not
# split across a page break. The program-path band + page numbers ride
# the fancyhdr page header/footer (`.latex_pagestyle_block`).
#
# This replaces the older "one `longtblr` per estimated page, joined by
# `\newpage`, titles/footnotes on page 1 only" manual-pagination model.
# Tradeoff: tabularray buffers and re-measures the whole table body, so
# compile cost grows super-linearly with row count. `.latex_warn_long_table`
# warns past a threshold; very long listings should chunk via
# `subgroup()` / `paginate(panels=)` or render to RTF/DOCX. Recommend
# xelatex/lualatex (dynamic memory; the tinytex default the preamble
# targets) over pdflatex for large tables.
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
    pagefoot_ast = meta$pagefoot_ast,
    border_color_defs = .latex_border_color_definitions(meta),
    cs = meta$chrome_style %||% chrome_style()
  )
  begin <- "\\begin{document}"
  end <- "\\end{document}"

  if (total == 0L) {
    return(c(preamble, begin, .render_latex_empty(grid), end))
  }

  # Warn once when the whole table is long enough that tabularray's
  # whole-table buffering may make the compile slow (see file header).
  .latex_warn_long_table(meta$nrow_data %||% total)

  cs <- meta$chrome_style %||% chrome_style()
  panels <- .group_pages_into_panels(pages)
  body <- list()
  for (k in seq_along(panels)) {
    if (k > 1L) {
      body[[length(body) + 1L]] <- "\\clearpage"
    }
    body[[length(body) + 1L]] <- .render_latex_panel(panels[[k]], meta, cs)
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

# Concatenate a panel's page slices into one body. For a native (unsplit)
# grid this is a single page (pass-through); for a split inspection grid
# it stitches the per-page slices back into one continuous table. rbinds
# the cell-text + sidecar matrices (column names preserved so
# `.cell_style_at` keeps indexing by name) and concatenates the parallel
# row vectors in render order. Port of `.rtf_concat_panel_body`.
.latex_concat_panel_body <- function(panel_pages) {
  first <- panel_pages[[1L]]
  if (length(panel_pages) == 1L) {
    return(list(
      cells_text = first$cells_text,
      cells_style = first$cells_style,
      cells_indent = first$cells_indent,
      is_header_row = first$is_header_row,
      is_blank_row = first$is_blank_row,
      keep_with_next = first$keep_with_next,
      host_col = first$host_col
    ))
  }
  list(
    cells_text = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_text)
    ),
    cells_style = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_style)
    ),
    cells_indent = do.call(
      rbind,
      lapply(panel_pages, function(p) p$cells_indent)
    ),
    is_header_row = unlist(
      lapply(panel_pages, function(p) p$is_header_row),
      use.names = FALSE
    ),
    is_blank_row = unlist(
      lapply(panel_pages, function(p) p$is_blank_row),
      use.names = FALSE
    ),
    keep_with_next = unlist(
      lapply(panel_pages, function(p) p$keep_with_next),
      use.names = FALSE
    ),
    host_col = first$host_col
  )
}

# Render one panel as ONE `longtblr`. The title block rides the
# firsthead/middle/lasthead templates and the footnotes ride
# firstfoot/middle/lastfoot (re-declared just before the table so each
# panel carries its own), so both repeat on every physical page while
# tabularray paginates the body. The header band (incl. column labels)
# repeats via `rowhead`; longtblr structurally repeats those rows on
# every page, so the `repeat_headers` flag is always honoured here.
# `\clearpage` between panels is emitted by the caller.
.render_latex_panel <- function(panel_pages, meta, cs) {
  first <- panel_pages[[1L]]

  # Default to "everything repeats" (the regulatory norm) when a grid
  # carries no repeat flags (e.g. a hand-built fixture).
  rep_titles <- meta$repeat_titles %||% TRUE
  rep_footnotes <- meta$repeat_footnotes %||% TRUE

  is_cont_panel <- isTRUE((first$panel_index %||% 1L) > 1L)
  continuation <- first$continuation %||% character()

  head_tpl <- .latex_head_template(
    meta$titles_ast,
    continuation = continuation,
    is_cont_panel = is_cont_panel,
    rep_titles = rep_titles,
    preset = meta$preset,
    cs = cs,
    gap_above = .meta_gap(meta, "above_title", 1L),
    gap_below = .meta_gap(meta, "title_to_body", 1L)
  )
  foot_tpl <- .latex_foot_template(
    meta$footnotes_ast,
    rep_footnotes = rep_footnotes,
    col_names_vis = first$col_names,
    cols = meta$cols,
    cells_style = first$cells_style,
    preset = meta$preset,
    cs = cs,
    gap_above = .meta_gap(meta, "body_to_footnote", 0L)
  )

  body <- .latex_concat_panel_body(panel_pages)
  c(head_tpl, foot_tpl, .render_latex_table(first, meta, cs, body = body))
}

# Warn once when a table is long enough that tabularray's whole-table
# buffering (it re-measures the entire body before typesetting) may make
# the LaTeX/PDF compile slow or memory-hungry. Threshold is deliberately
# conservative; the message points at the chunking escape hatches.
.latex_long_table_threshold <- 1000L

.latex_warn_long_table <- function(nrow_total) {
  n <- suppressWarnings(as.integer(nrow_total))
  if (length(n) != 1L || is.na(n) || n < .latex_long_table_threshold) {
    return(invisible())
  }
  cli::cli_warn(
    c(
      "LaTeX table has {n} rows.",
      "i" = "tabularray re-measures the whole table, so the PDF compile may be slow or memory-heavy.",
      "i" = "Chunk with {.fn subgroup} or {.code paginate(panels=)}, or render to RTF/DOCX for very long listings.",
      "i" = "Prefer the xelatex or lualatex engine (dynamic memory) over pdflatex."
    ),
    class = "tabular_warning_layout",
    call = rlang::caller_env()
  )
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
  ws_preserve <- .preset_ws_preserve(preset)
  lines <- unlist(lapply(
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
          .render_latex_inline(titles_ast[[i]], preserve = ws_preserve),
          bold_close
        ),
        surface_node
      )
      .latex_aligned_paragraph(body = body, halign = halign)
    }
  ))
  # Title borders ride the block edges as full-width rules (top above the
  # first line, bottom below the last). No region channel for the title,
  # so the surface node is the only path. NULL / no border => no rule
  # (byte-identical default).
  c(
    .latex_foot_rule_line(.effective_border("top", surface_node)),
    lines,
    .latex_foot_rule_line(.effective_border("bottom", surface_node))
  )
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
  ws_preserve <- .preset_ws_preserve(preset)
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
        .render_latex_inline(footnotes_ast[[i]], preserve = ws_preserve),
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
  # A glue-free group, NOT a list environment (`center`/`flushleft` add
  # `\topsep`+`\partopsep` between every line). With `\parskip=0pt` in the
  # preamble, consecutive groups stack on the normal baseline with no gap,
  # so multi-line titles/footnotes read tight (galley's model).
  align_cmd <- switch(
    halign,
    left = "\\raggedright",
    center = "\\centering",
    right = "\\raggedleft",
    "\\raggedright"
  )
  paste0("{", align_cmd, " ", body, "\\par}")
}

# ---------------------------------------------------------------------
# longtblr head / foot templates (running titles + footnotes)
# ---------------------------------------------------------------------

# Emit one `\DefTblrTemplate{<name>}{default}{<content>}` block. `name`
# may be a comma list (`"middlehead, lasthead"`) so several template
# slots share one definition. Empty `content` emits the one-line empty
# form `{default}{}` which CLEARS any previously declared template of
# that name (so a panel with no titles does not inherit the previous
# panel's). `default` is the template style longtblr looks up by
# default; a wrong name renders nothing silently, hence the dedicated
# helper + unit tests.
.latex_def_tblr_template <- function(name, content) {
  if (length(content) == 0L) {
    return(sprintf("\\DefTblrTemplate{%s}{default}{}", name))
  }
  c(
    sprintf("\\DefTblrTemplate{%s}{default}{%%", name),
    content,
    "}"
  )
}

# Build the longtblr head templates that carry the table's titles, so
# the title block repeats at the top of every physical page (tabularray
# replays `firsthead` on a panel's first page and `middlehead`/`lasthead`
# on its continuation pages). Re-declared just before each panel's table.
#
# * `firsthead`            -> titles (+ continuation marker when this is a
#                             continuation PANEL, panel_index > 1).
# * `middlehead, lasthead` -> titles (only when `rep_titles`) plus the
#                             continuation marker (every physical
#                             continued page gets it). This is finer than
#                             RTF, which can only mark continuation panels.
#
# `continuation` is the user's `paginate(continuation=)` string (carried
# verbatim on every page by the engine); an empty value suppresses the
# marker. Empty titles + no marker collapse to the empty template form.
.latex_head_template <- function(
  titles_ast,
  continuation = character(),
  is_cont_panel = FALSE,
  rep_titles = TRUE,
  preset = NULL,
  cs = NULL,
  gap_above = 1L,
  gap_below = 1L
) {
  titles <- .render_latex_title_block(titles_ast, preset = preset, cs = cs)
  has_titles <- length(titles) > 0L
  # Title blank-line padding (chrome `style(blank_above/below,
  # .at = cells_title())`, else the legacy single blank line) wraps the
  # title block so the spacing repeats with the titles on every page.
  if (has_titles) {
    pad_top <- .latex_blank_count(cs, "title", "above", gap_above)
    pad_bottom <- .latex_blank_count(cs, "title", "below", gap_below)
    # Real blank lines, NOT empty strings: an empty TeX paragraph has
    # zero height under `\parskip=0pt`, so `rep("", n)` produced no
    # visible gap. `{\strut\par}` is one full-height blank line each,
    # matching the RTF/HTML/DOCX blank-`\par` title padding.
    blank_line <- "{\\strut\\par}"
    titles <- c(rep(blank_line, pad_top), titles, rep(blank_line, pad_bottom))
  }
  cont_text <- if (length(continuation) > 0L) {
    as.character(continuation)[[1L]]
  } else {
    ""
  }
  cont_marker <- if (nzchar(cont_text)) {
    paste0("\\noindent\\textit{", .latex_escape(cont_text), "}\\par")
  } else {
    character()
  }
  first_content <- c(
    if (isTRUE(is_cont_panel)) cont_marker,
    if (has_titles) titles
  )
  rest_content <- c(
    if (isTRUE(rep_titles) && has_titles) titles,
    cont_marker
  )
  c(
    .latex_def_tblr_template("firsthead", first_content),
    .latex_def_tblr_template("middlehead, lasthead", rest_content)
  )
}

# Build the longtblr foot templates that carry the user footnotes (with
# the separator rule) inside a `minipage` matching the rendered table
# width, so the rule and text align with the table columns rather than
# spilling to the full page text width.
#
# * `rep_footnotes` TRUE  -> footnotes on every page
#                            (`firstfoot, middlefoot, lastfoot`).
# * `rep_footnotes` FALSE -> footnotes pin to the final page only
#                            (`lastfoot`); the other slots are cleared.
#
# The program-path band + page numbers stay on the fancyhdr page footer
# (`.latex_pagestyle_block`); this template carries ONLY the user
# footnotes, so the two never collide.
.latex_foot_template <- function(
  footnotes_ast,
  rep_footnotes = TRUE,
  col_names_vis = NULL,
  cols = NULL,
  cells_style = NULL,
  preset = NULL,
  cs = NULL,
  gap_above = 0L
) {
  fn <- .render_latex_footnote_block(footnotes_ast, preset = preset, cs = cs)
  if (length(fn) == 0L) {
    return(c(
      .latex_def_tblr_template("firstfoot, middlefoot", character()),
      .latex_def_tblr_template("lastfoot", character())
    ))
  }
  width_in <- .latex_table_width_in(col_names_vis, cols, cells_style, preset)
  foot_triple <- .chrome_border_at(cs, "footer_top")
  # Blank line(s) above the footnotes: the footer surface's
  # `blank_above` (via `style(.at = cells_footnotes())`) wins, else the
  # `body_to_footnote` spacing gap. `{\strut\par}` is one full-height
  # blank line each (matching the title padding), standing in for the
  # bottomrule when `preset_minimal()` drops it.
  pad_above <- .latex_blank_count(cs, "footer", "above", gap_above)
  wrapped <- c(
    rep("{\\strut\\par}", pad_above),
    .latex_minipage_wrap(fn, width_in, foot_triple)
  )
  if (isTRUE(rep_footnotes)) {
    .latex_def_tblr_template("firstfoot, middlefoot, lastfoot", wrapped)
  } else {
    c(
      .latex_def_tblr_template("firstfoot, middlefoot", character()),
      .latex_def_tblr_template("lastfoot", wrapped)
    )
  }
}

# Wrap footnote lines in a fixed-width `minipage`, optionally topped by
# the footnote-section opening rule (`footnoterule`). `width_in` is the
# rendered table width in inches; `NA` falls back to `\linewidth` (the
# page text width) when column widths are unresolved (e.g. proportional
# `X[]` columns). The rule spans `\linewidth` (the minipage width = the
# table width), never the page width. `foot_triple` is the resolved
# footnoterule triple (or NULL); off by default, since the body
# `bottomrule` is the mutually-exclusive default closer.
.latex_minipage_wrap <- function(lines, width_in, foot_triple = NULL) {
  width_tok <- if (is.na(width_in)) {
    "\\linewidth"
  } else {
    sprintf("%gin", round(width_in, 4L))
  }
  c(
    sprintf("\\begin{minipage}{%s}", width_tok),
    .latex_foot_rule_line(foot_triple),
    lines,
    "\\end{minipage}"
  )
}

# Build the footnote-opening rule line, sized to `\linewidth` (= table
# width). NULL / style "none" -> no rule (the default: `bottomrule`
# closes the body and `footnoterule` is OFF). When ON, honour the
# resolved width + colour from the SSOT (hex colours ride a preamble
# `\definecolor`, the same token machinery as table-cell rules).
.latex_foot_rule_line <- function(triple) {
  if (is.null(triple) || identical(triple$style, "none")) {
    return(character())
  }
  width <- triple$width %||% .tabular_rule_width
  has_color <- !is.null(triple$color) &&
    !is.na(triple$color) &&
    nzchar(triple$color) &&
    !identical(triple$color, "currentColor") &&
    !.is_default_ink(triple$color)
  if (has_color) {
    sprintf(
      "\\noindent{\\color{%s}\\rule{\\linewidth}{%gpt}}\\par",
      .latex_border_color_token(triple$color),
      width
    )
  } else {
    sprintf("\\noindent\\rule{\\linewidth}{%gpt}\\par", width)
  }
}

# Rendered table width in inches: the sum of resolved column widths
# (`col_spec@width`, inches) plus the per-column horizontal padding
# (`leftsep + rightsep`, points -> inches at 72.27pt/in) that tabularray
# adds around each column box. Returns `NA_real_` when any column width
# is unresolved so callers can fall back to `\linewidth`.
.latex_table_width_in <- function(
  col_names_vis,
  cols,
  cells_style = NULL,
  preset = NULL
) {
  if (is.null(cols) || length(col_names_vis) == 0L) {
    return(NA_real_)
  }
  widths <- vapply(
    col_names_vis,
    function(nm) {
      co <- cols[[nm]]
      if (
        is_col_spec(co) &&
          is.numeric(co@width) &&
          length(co@width) == 1L &&
          !is.na(co@width)
      ) {
        co@width
      } else {
        NA_real_
      }
    },
    numeric(1L)
  )
  if (anyNA(widths)) {
    return(NA_real_)
  }
  # Per-column horizontal padding (leftsep + rightsep) needs a preset to
  # resolve; a headless caller without one contributes zero padding.
  lr <- if (is_preset_spec(preset)) {
    .resolve_cell_padding_lr(cells_style, preset)
  } else {
    c(0, 0)
  }
  pad_in <- length(col_names_vis) * (lr[[1L]] + lr[[2L]]) / 72.27
  sum(widths) + pad_in
}

# ---------------------------------------------------------------------
# Table assembly: longtblr environment
# ---------------------------------------------------------------------

# Render one page's table as a `\begin{longtblr}` ... `\end{longtblr}`
# block. tabularray's `longtblr` auto-paginates and repeats
# `rowhead` rows on continuation pages.
.render_latex_table <- function(page, meta, cs = NULL, body = NULL) {
  col_names_vis <- page$col_names
  cols <- meta$cols %||% list()
  colspec <- .latex_colspec(col_names_vis, cols)

  # Body source: the concatenated panel body when the panel renderer
  # supplies one (native pagination), else the single page's slices
  # (direct / legacy callers). `keep_with_next` drives the per-row
  # `\\*` (no-break) terminator so tabularray does not split a group.
  src <- body %||%
    list(
      cells_text = page$cells_text,
      cells_style = page$cells_style,
      cells_indent = page$cells_indent,
      is_header_row = page$is_header_row,
      is_blank_row = page$is_blank_row,
      host_col = page$host_col,
      keep_with_next = page$keep_with_next
    )

  # Per-page BigN: one longtblr per subgroup, so read that subgroup's
  # SUFFIXED bands + leaf labels from the page descriptor via the shared
  # resolver. Inert (global metadata) without big_n.
  page_hdr <- .page_header_for_render(meta, page)
  page_headers <- page_hdr$headers
  page_col_labels_ast <- page_hdr$col_labels_ast

  # Subgroup banner row, computed first so the header band can be offset
  # below it (anatomy: subgroup banner, then the column-header band, then
  # data). The banner + a blank row above and below ride the `rowhead`
  # block so they repeat on every continuation page with the band.
  banner_row <- .render_latex_subgroup_banner_row(
    page$subgroup_line_ast,
    n_cols = length(col_names_vis),
    preset = meta$preset,
    cs = cs
  )
  banner_block <- if (length(banner_row) > 0L) {
    c(
      .latex_blank_row(length(col_names_vis)),
      banner_row,
      .latex_blank_row(length(col_names_vis))
    )
  } else {
    character()
  }
  head_offset <- length(banner_block)

  bands <- .render_latex_header_bands(
    page_headers,
    col_names_vis,
    cs,
    offset = head_offset
  )
  band_rows <- bands$rows
  label_row <- .render_latex_col_labels_row(
    page_col_labels_ast,
    col_names_vis,
    cols,
    cs,
    preset = meta$preset
  )
  rowhead <- head_offset + length(band_rows) + 1L

  # Header rules ride tabularray-native outer `hline{i}={1-N}{spec}`
  # directives (spliced into `outer_args` below), exactly like the
  # per-band cmidrules. This is what makes them survive longtblr's
  # `rowhead` replay on continuation pages, where an inline `\hline`
  # in the replayed block would double or drop. A full-width top rule
  # sits on the TOPMOST header row (`hline{1}`) and a full-width bottom
  # rule under the column-labels row (`hline{nbands+2}`); each spanner
  # band keeps its own scoped cmidrule(lr) from `bands$band_hlines`.
  # No separate top rule on the col-labels row, so nothing doubles when
  # bands sit above it. The body-bottom closer is the SSOT `bottomrule`
  # (`outer_bottom` -> `hline{nrow}` directive); the footnote-opening
  # rule (`footnoterule`, opt-in) rides the foot-template `\rule`. Both
  # are handled outside this block, so there is no in-table footer rule.
  header_rule_dirs <- .latex_header_rule_directives(
    nbands = length(band_rows),
    n_cols = length(col_names_vis),
    cs = cs,
    offset = head_offset
  )
  # Banner block (blank, banner, blank) leads the rowhead, then the band.
  header_rules <- c(banner_block, band_rows, label_row)
  body_rows <- .render_latex_body_rows(
    src$cells_text,
    col_names_vis = col_names_vis,
    cells_style = src$cells_style,
    cells_indent = src$cells_indent,
    is_header_row = src$is_header_row,
    is_blank_row = src$is_blank_row,
    host_col = src$host_col,
    keep_with_next = src$keep_with_next,
    cols = cols,
    preset = meta$preset
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
    .latex_rowsep_inner(src$cells_style)
  )
  outer_args <- paste(
    c(
      sprintf("colspec={%s}", colspec),
      sprintf("rowhead=%d", rowhead),
      .latex_cellsep_inner(src$cells_style, meta$preset),
      sprintf("rows={%s}", paste(rows_inner, collapse = ", ")),
      header_rule_dirs,
      border_directives,
      bands$band_hlines
    ),
    collapse = ", "
  )
  # `presep=0pt, postsep=0pt` so the head/foot templates (titles /
  # footnotes) butt directly against the table rather than gaining
  # tabularray's default outer padding.
  c(
    paste0(
      "\\begin{longtblr}[caption={}, label={}, presep=0pt, postsep=0pt]{",
      outer_args,
      "}"
    ),
    header_rules,
    body_rows,
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
# row is at index `rowhead + 1`.
#
# KNOWN LIMITATION: per-cell `style(border_*, .at = cells_body())`
# borders on a SINGLE body cell are not rendered by the LaTeX backend
# (they are honored by HTML / RTF / DOCX). tabularray draws per-cell
# borders only through row/col-indexed `hline{r}={c}` / `vline{c}={r}`
# directives, which cannot be derived from `cells_style[r,c]@border_*`
# without colliding with the structural `outer` / `rows` / `cols`
# stamps that share the same per-cell scalars (they would double-draw).
# Structural body borders (the full frame, row rules, column rules) DO
# render via the manifest below. The same indexing limit defers the
# `cells_subgroup_labels()` banner rule on the LaTeX backend.
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
      # The outer frame top rides the table top (`hline{1}` = top of the
      # first header row), NOT the body top (`rowhead + 1`), so the thick
      # frame edge sits above the column-header band rather than under it.
      out <- c(out, sprintf("hline{1}={%s}", spec))
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
      !identical(triple$color, "currentColor") &&
      !.is_default_ink(triple$color)
  ) {
    parts <- c(parts, paste0("fg=", .latex_border_color_token(triple$color)))
  }
  paste(parts, collapse = ", ")
}

# Map a border colour to a tabularray `fg=` token. A hex (`#RRGGBB`)
# becomes a deterministic `\definecolor` name (`tabularruleRRGGBB`)
# that `.latex_border_color_definitions()` declares in the preamble;
# tabularray rejects an inline `[HTML]{...}` model in a border spec, so
# a named colour is required. A CSS / xcolor colour name passes through
# unchanged.
.latex_border_color_token <- function(color) {
  hex <- .latex_hex6(color)
  if (!is.null(hex)) {
    return(paste0("tabularrule", hex))
  }
  color
}

# Normalise a `#RRGGBB` / `RRGGBB` colour to upper-case `RRGGBB`, or
# NULL when the input is not a 6-digit hex.
.latex_hex6 <- function(color) {
  s <- toupper(sub("^#", "", as.character(color)))
  if (grepl("^[0-9A-F]{6}$", s)) s else NULL
}

# Collect every distinct hex border colour used in a grid's resolved
# stores (chrome rules + body-edge manifest), so the preamble can
# `\definecolor` each. The booktabs baseline always contributes the
# ink + muted palette, so both are included unconditionally.
.latex_collect_border_colors <- function(meta) {
  hexes <- c(
    .latex_hex6(.tabular_ink),
    .latex_hex6(.tabular_muted)
  )
  triples <- c(
    if (is.list(meta$chrome_style)) meta$chrome_style$borders else NULL,
    if (is.list(meta$body_borders)) meta$body_borders else NULL
  )
  for (tr in triples) {
    if (is.list(tr) && !is.null(tr$color)) {
      h <- .latex_hex6(tr$color)
      if (!is.null(h)) {
        hexes <- c(hexes, h)
      }
    }
  }
  unique(hexes)
}

# Preamble `\definecolor` lines for the collected border colours.
.latex_border_color_definitions <- function(meta) {
  hexes <- .latex_collect_border_colors(meta)
  vapply(
    hexes,
    function(h) sprintf("\\definecolor{tabularrule%s}{HTML}{%s}", h, h),
    character(1L)
  )
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
    # Paged backends left-align the banner by default (anatomy); an
    # explicit cells_subgroup_labels() halign override still wins.
    if (is.na(h)) "left" else h
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

# Resolve a chrome border region into a tabularray border-spec
# fragment (e.g. `"0.5pt, solid"`) for use inside an outer
# `hline{i}={range}{spec}` directive. No user override -> the
# canonical thin solid rule at the SSOT width. `style = "none"` -> ""
# (caller skips the directive entirely).
.latex_chrome_hline_spec <- function(cs, region) {
  triple <- .chrome_border_at(cs, region)
  if (is.null(triple)) {
    return(sprintf("%gpt, solid", .tabular_rule_width))
  }
  .latex_border_spec(triple)
}

# Build the full-width header-band rule directives for the outer
# longtblr arg list. The header band occupies rows 1..(nbands+1):
# `nbands` spanner rows followed by the single column-labels row, so
# `rowhead = nbands + 1`. Two full-width rules bound the band:
#
#   hline{1}          -> top rule on the topmost header row
#   hline{nbands + 2} -> bottom rule under the column-labels row
#
# Both span every column (`{1-N}`). Per-band cmidrules (`hline{k+1}`,
# scoped + inset) are emitted separately by `.render_latex_header_bands`
# and do not collide with these. The bottom rule shares its row index
# (`nbands + 2` == `rowhead + 1`) with a body `outer_top` border; the
# caller emits these directives BEFORE the body border directives so an
# explicit user body border wins (last write in tabularray's arg list).
# A region whose spec resolves to "" (style = "none") is skipped.
# `offset` = number of rows ABOVE the header band (the subgroup banner
# plus its blank rows), so the band's top rule rides `hline{1 + offset}`
# and the bottom rule `hline{nbands + 2 + offset}`. The banner rows above
# carry no rule.
.latex_header_rule_directives <- function(
  nbands,
  n_cols,
  cs = NULL,
  offset = 0L
) {
  out <- character()
  top <- .latex_chrome_hline_spec(cs, "header_top")
  if (nzchar(top)) {
    out <- c(out, sprintf("hline{%d}={1-%d}{%s}", 1L + offset, n_cols, top))
  }
  bottom <- .latex_chrome_hline_spec(cs, "header_bottom")
  if (nzchar(bottom)) {
    out <- c(
      out,
      sprintf("hline{%d}={1-%d}{%s}", nbands + 2L + offset, n_cols, bottom)
    )
  }
  out
}

# Empty full-width row for the blank line above / below the subgroup
# banner: (n-1) trailing `&` placeholders keep tabularray's column count.
.latex_blank_row <- function(n_cols) {
  paste0(
    if (n_cols == 1L) " " else paste(rep(" &", n_cols - 1L), collapse = ""),
    " \\\\"
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

# Render multi-level header bands using real `\SetCell` colspan, plus
# the tabularray-native `hline` directives that underline each band.
# For each band-row depth (top first) we walk visible columns left to
# right, group contiguous runs sharing the same band label (or none),
# and emit one `\SetCell[c=N]{c}` cell per run. The band at 1-based
# position `k` is content row `k`; its underline sits at `hline{k+1}`,
# scoped to the run's column range(s) via `{m-n,...}` (one band can own
# several disjoint runs when a non-member column splits it) and trimmed
# to the booktabs `\cmidrule(lr)` look.
#
# Returns `list(rows = <chr, one per depth>, band_hlines = <chr, the
# outer hline directives>)`; both empty when no bands exist. The outer
# directive survives longtblr's rowhead replay across pages, where an
# inline `\cmidrule` in the band row would not (see
# `.runs_to_band_row`).
.render_latex_header_bands <- function(
  headers,
  col_names_visible,
  cs = NULL,
  offset = 0L
) {
  if (!is.data.frame(headers) || nrow(headers) == 0L) {
    return(list(rows = character(), band_hlines = character()))
  }
  surface_node <- .chrome_surface_at(cs, "header")
  depths <- sort(unique(headers$depth))
  rows <- character(length(depths))
  band_hlines <- character()
  # The spanner underline is the SSOT `spanrule` (chrome region
  # `header_between`, muted by default) so LaTeX matches HTML's muted
  # band rule. `.latex_chrome_hline_spec()` resolves the triple to a
  # tabularray border spec; "" means the rule is off (`spanrule =
  # "none"`), so the band hline directive is skipped entirely.
  band_spec <- .latex_chrome_hline_spec(cs, "header_between")
  for (k in seq_along(depths)) {
    labels <- .band_labels_for_depth(headers, depths[[k]], col_names_visible)
    runs <- .group_contiguous_runs(labels)
    band <- .runs_to_band_row(runs, surface_node)
    rows[[k]] <- band$row
    if (length(band$ranges) > 0L && nzchar(band_spec)) {
      cols_spec <- paste(
        vapply(
          band$ranges,
          function(r) sprintf("%d-%d", r[[1L]], r[[2L]]),
          character(1L)
        ),
        collapse = ","
      )
      # `leftpos=-1, rightpos=-1` trims each spanner segment by colsep at
      # both ends (tabularray's equivalent of booktabs `\cmidrule(lr)`),
      # so adjacent spanners' underlines are separated by a visible gap
      # and inset from the outer column edges. Trimming is per segment,
      # so the comma-joined ranges each get their own trimmed rule.
      band_hlines <- c(
        band_hlines,
        sprintf(
          "hline{%d}={%s}{%s, leftpos=-1, rightpos=-1}",
          k + 1L + offset,
          cols_spec,
          band_spec
        )
      )
    }
  }
  list(rows = rows, band_hlines = band_hlines)
}

# Turn a list of `{value, length}` runs into one tblr band row plus
# the column ranges that should be underlined. Each named run becomes
# a `\SetCell[c=N]{c} <label>` (or a bare label when the span is 1);
# NA runs become bare empty cells. Cells are `&`-joined and the row
# terminates with `\\`.
#
# Returns `list(row = <one-line string>, ranges = list(c(start, end),
# ...))` — one range per NAMED run (NA runs contribute none). The
# caller turns the ranges into a tabularray-native outer
# `hline{i}={m-n}{spec}` directive. We deliberately do NOT emit a
# booktabs `\cmidrule` here: that macro would live in the band row,
# which sits in the `rowhead` block tabularray replays on continuation
# pages, where `\cmidrule` is no longer a live control sequence (->
# `! Undefined control sequence` at `\end{longtblr}`). The outer hline
# directive is pagination-aware and survives the replay.
.runs_to_band_row <- function(runs, surface_node = NULL) {
  cells <- character()
  ranges <- list()
  cursor <- 1L
  for (run in runs) {
    span <- run$length
    start <- cursor
    end <- cursor + span - 1L
    if (is.na(run$value)) {
      cells <- c(cells, rep("", span))
    } else {
      lbl <- .latex_wrap_text_props(.latex_escape(run$value), surface_node)
      # Multi-line spanner labels wrap so the `\\` breaks the line inside
      # the (merged) cell rather than ending the band row.
      lbl <- .latex_linebreak_wrap(lbl, halign = "center", valign = "bottom")
      if (span == 1L) {
        cells <- c(cells, lbl)
      } else {
        cells <- c(
          cells,
          sprintf("\\SetCell[c=%d]{c} %s", span, lbl),
          rep("", span - 1L)
        )
      }
      ranges <- c(ranges, list(c(start, end)))
    }
    cursor <- end + 1L
  }
  row <- paste0(
    .latex_surface_rowsep(surface_node),
    paste(cells, collapse = " & "),
    " \\\\"
  )
  list(row = row, ranges = ranges)
}

# Render the column-labels row: one cell per visible column,
# pulled from `col_labels_ast`. Falls back to the column name
# when the spec did not set a label for that column.
.render_latex_col_labels_row <- function(
  col_labels_ast,
  col_names_visible,
  cols,
  cs = NULL,
  preset = NULL
) {
  surface_node <- .chrome_surface_at(cs, "header")
  ws_preserve <- .preset_ws_preserve(preset)
  cells <- vapply(
    col_names_visible,
    function(nm) {
      ast <- col_labels_ast[[nm]]
      raw <- if (is.null(ast)) {
        .latex_escape(nm)
      } else {
        .render_latex_inline(ast, preserve = ws_preserve)
      }
      body <- .latex_wrap_text_props(raw, surface_node)
      col <- cols[[nm]]
      # Valign cascade (HTML parity): col_spec > surface > preset, then a
      # bottom default so a wrapped multi-line header sits flush with
      # single-line neighbours. Always emit `valign` (the longtblr row
      # baseline is body_valign, so the header needs its own).
      valign <- if (
        is_col_spec(col) &&
          length(col@valign) == 1L &&
          !is.na(col@valign)
      ) {
        col@valign
      } else if (
        is_style_node(surface_node) &&
          length(surface_node@valign) == 1L &&
          !is.na(surface_node@valign)
      ) {
        surface_node@valign
      } else {
        .effective_header_valign(col, preset)
      }
      if (is.na(valign)) {
        valign <- "bottom"
      }
      parts <- sprintf("valign=%s", .latex_valign_letter(valign))
      is_decimal <- is_col_spec(col) &&
        length(col@align) == 1L &&
        !is.na(col@align) &&
        col@align == "decimal"
      # Chrome surface header halign (from `style(.at = cells_headers())`),
      # honored when no per-column align is set (parity with HTML/RTF/DOCX,
      # where col_spec align wins and the surface fills in).
      surf_halign <- if (
        !(is_col_spec(col) && length(col@align) == 1L && !is.na(col@align)) &&
          is_style_node(surface_node) &&
          length(surface_node@halign) == 1L &&
          !is.na(surface_node@halign)
      ) {
        surface_node@halign
      } else {
        NA_character_
      }
      if (grepl("\\\\", body, fixed = TRUE)) {
        # Multi-line header: wrap so the in-cell `\\` is a line break, not
        # a row separator. The parbox carries the halign (decimal centres,
        # else the column's alignment, else the surface halign); the cell
        # keeps only valign.
        halign <- if (is_decimal) {
          "center"
        } else if (
          is_col_spec(col) && length(col@align) == 1L && !is.na(col@align)
        ) {
          col@align
        } else if (!is.na(surf_halign)) {
          surf_halign
        } else {
          "left"
        }
        body <- .latex_linebreak_wrap(body, halign = halign, valign = valign)
      } else if (is_decimal) {
        # Single-line decimal header centres (HTML parity); other
        # single-line headers inherit their `Q[...]` colspec alignment.
        parts <- paste0("halign=c,", parts)
      } else if (!is.na(surf_halign)) {
        # No per-column align: honor the surface header halign explicitly
        # (single-line headers otherwise inherit the `Q[...]` colspec).
        parts <- paste0(
          sprintf("halign=%s,", .latex_halign_letter(surf_halign)),
          parts
        )
      }
      sprintf("\\SetCell{%s} %s", parts, body)
    },
    character(1L)
  )
  paste0(
    .latex_surface_rowsep(surface_node),
    paste(cells, collapse = " & "),
    " \\\\"
  )
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
# Wrap cell content in a `\leftskip` group for indent depth. `pt <= 0`
# returns the content unchanged. `\leftskip` is paragraph-level, so a
# wrapped cell's continuation lines align with the indented first line
# (SAS PADDINGLEFT). Used for grouped body rows + section-header rows;
# unlike the column-level `leftsep`, it is a valid construct inside a
# tabularray cell.
.latex_indent_wrap <- function(content, pt) {
  if (!is.numeric(pt) || length(pt) != 1L || is.na(pt) || pt <= 0) {
    return(content)
  }
  sprintf("{\\leftskip=%gpt\\relax %s}", pt, content)
}

# Wrap multi-line cell content in a `\parbox` so an in-cell `\\` becomes a
# LINE break within the cell instead of a tabularray ROW separator (a bare
# `\\` ends the row and fragments the table). Single-line content (no
# `\\`) is returned unchanged. galley's construct: `\hsize` is the
# Q-column content width; `[b]`/`[t]`/`[c]` sets the box baseline so a
# multi-line header bottom-aligns with single-line neighbours; the
# `\raggedright`/`\centering`/`\raggedleft` inside aligns every line.
.latex_linebreak_wrap <- function(
  content,
  halign = "left",
  valign = "bottom"
) {
  if (!grepl("\\\\", content, fixed = TRUE)) {
    return(content)
  }
  align_cmd <- switch(
    halign,
    center = "\\centering ",
    right = "\\raggedleft ",
    "\\raggedright "
  )
  v <- switch(valign, top = "t", middle = "c", bottom = "b", "b")
  sprintf("\\parbox[%s]{\\hsize}{%s%s}", v, align_cmd, content)
}

.render_latex_body_rows <- function(
  cells_text,
  col_names_vis = NULL,
  cells_style = NULL,
  cells_indent = NULL,
  is_header_row = NULL,
  is_blank_row = NULL,
  host_col = NA_character_,
  keep_with_next = NULL,
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
  # `keep_with_next[[i]]` TRUE -> glue row i to row i+1 with the `\\*`
  # no-break terminator; FALSE -> plain `\\` (tabularray may break here).
  # NULL default = all-FALSE, i.e. let tabularray paginate freely. This
  # DIFFERS from the RTF backend's all-TRUE legacy fallback: under native
  # pagination LaTeX must not glue every row (that would forbid every
  # page break and overflow). The panel renderer supplies the engine's
  # per-rendered-row keep mask.
  keep_vec <- if (is.null(keep_with_next)) {
    rep(FALSE, nrow_data)
  } else {
    vapply(
      seq_len(nrow_data),
      function(r) isTRUE(keep_with_next[[r]]),
      logical(1L)
    )
  }
  row_term <- function(i) if (isTRUE(keep_vec[[i]])) " \\\\*" else " \\\\"
  # Per-level native padding in `pt` (LaTeX's tabularray takes pt for
  # `leftsep+=`). `.indent_native_pt_per_level()` is the single source
  # of truth shared with the leading-space strip below.
  indent_size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  indent_unit <- nchar(.indent_text_unit(indent_size))
  indent_pt_per_level <- .indent_native_pt_per_level(preset)
  ws_preserve <- .preset_ws_preserve(preset)
  vapply(
    seq_len(nrow_data),
    function(i) {
      # Synthesised section-header / blank-gap rows render as a single
      # spanning cell mirroring the subgroup-banner shape — tabularray
      # requires (N-1) trailing `&` placeholders so the column count
      # stays consistent with the rest of the body.
      if (isTRUE(is_blank_row[[i]])) {
        # NOTE: the blank separator carries the stripe fill on its node,
        # but the LaTeX stripe rides `\colorbox` around the cell TEXT
        # (see `.latex_wrap_text_props`); an empty row has no text to box,
        # so the fill cannot ride the existing mechanism. A full-row
        # `\SetRow{bg=}` here would render a solid bar against the text-
        # boxed data rows (visual mismatch). Continuous blank-row striping
        # in LaTeX waits on the broader colorbox -> cellcolor refactor;
        # HTML / RTF / DOCX colour the blank row directly. (Group-header
        # rows DO stripe in LaTeX: their label text rides `\colorbox`.)
        return(paste0(
          if (ncol_data == 1L) {
            " "
          } else {
            paste(rep(" &", ncol_data - 1L), collapse = "")
          },
          row_term(i)
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
        # Band-depth indent on the spanning cell via a `\leftskip`
        # group around the label (NOT `leftsep`, which is a column key
        # tabularray rejects inside `\SetCell` -> "Undefined color").
        # `\leftskip` indents wrapped continuation lines too (SAS
        # PADDINGLEFT contract). Band-1 (depth 0) gets the bare label.
        header_indent_pt <- 0
        if (!is.na(host_idx)) {
          header_depth <- cells_indent[i, host_idx]
          if (isTRUE(header_depth > 0L) && indent_pt_per_level > 0) {
            header_indent_pt <- indent_pt_per_level * header_depth
          }
        }
        # Group-header weight + text props come from the host cell's
        # resolved style_node (stamped by `.stamp_group_headers()`):
        # NA bold == bold (default), `isFALSE` == off. Same idiom as the
        # subgroup banner above.
        host_node <- if (!is.null(cells_style) && !is.na(host_idx)) {
          cells_style[[i, host_idx]]
        } else {
          NULL
        }
        bold_open <- if (
          is_style_node(host_node) && isTRUE(host_node@bold == FALSE)
        ) {
          ""
        } else {
          "\\textbf{"
        }
        bold_close <- if (identical(bold_open, "")) "" else "}"
        body <- .latex_wrap_text_props(
          paste0(
            bold_open,
            .latex_escape_cell(host_text, preserve = ws_preserve),
            bold_close
          ),
          host_node
        )
        body <- .latex_indent_wrap(body, header_indent_pt)
        terminator <- row_term(i)
        if (ncol_data == 1L) {
          return(paste0("\\SetCell{halign=l} ", body, terminator))
        }
        return(paste0(
          sprintf("\\SetCell[c=%d]{l} ", ncol_data),
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
          # depth unit; strip exactly that many leading spaces, then
          # carry the indent with a `\leftskip` group around the cell
          # content. `\leftskip` indents wrapped continuation lines too
          # (SAS PADDINGLEFT contract); the older `\SetCell{leftsep+=}`
          # was invalid tabularray and broke the PDF compile.
          depth <- cells_indent[i, j]
          indent_pt <- 0
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
              indent_pt <- indent_pt_per_level * depth
            }
          }
          text <- .latex_escape_cell(raw, preserve = ws_preserve)
          nm <- col_names_vis[[j]]
          sn <- if (is.character(nm) && !is.na(nm)) {
            .cell_style_at(cells_style, i, nm)
          } else {
            style_node()
          }
          prefix <- .latex_setcell_alignment(sn)
          wrapped <- .latex_wrap_text_props(text, sn)
          paste0(prefix, .latex_indent_wrap(wrapped, indent_pt))
        },
        character(1L)
      )
      # `\\*` (no page break after) vs `\\` is decided per row by the
      # keep-with-next mask: tabularray paginates the body natively and
      # only the glued rows (group runs, section headers) stay together.
      paste0(paste(cells, collapse = " & "), row_term(i))
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
  # Vertical per-cell padding -> tabularray row separation. Symmetric
  # top == bottom collapses to a single `rowsep`; an asymmetric override
  # (e.g. `padding_bottom` alone) emits `abovesep` / `belowsep` so the
  # bottom padding is no longer dropped. Default cell_padding leaves both
  # NA, so the arg is omitted (tabularray's own rowsep default applies).
  sides <- .first_cell_padding_sides(cells_style)
  pt <- sides[["top"]]
  pb <- sides[["bottom"]]
  fmt <- function(v) format(v, trim = TRUE, scientific = FALSE)
  if (!is.na(pt) && !is.na(pb) && isTRUE(all.equal(pt, pb))) {
    return(sprintf("rowsep=%spt", fmt(pt)))
  }
  out <- character()
  if (!is.na(pt)) {
    out <- c(out, sprintf("abovesep=%spt", fmt(pt)))
  }
  if (!is.na(pb)) {
    out <- c(out, sprintf("belowsep=%spt", fmt(pb)))
  }
  out
}

# tabularray `\SetRow{abovesep=, belowsep=}` prefix from a chrome
# surface's vertical padding, for the header band and column-label rows
# (lets `preset(padding = list(header = c(top = , bottom = )))` reach the
# PDF). `\SetRow` sets the keys for the row it leads. Returns "" when the
# surface sets no top / bottom padding so the row keeps the table
# default. Horizontal padding is column-width-driven (leftsep / rightsep)
# and not expressed per header row.
.latex_surface_rowsep <- function(surface_node) {
  if (!is_style_node(surface_node)) {
    return("")
  }
  parts <- character()
  pt <- S7::prop(surface_node, "padding_top")
  pb <- S7::prop(surface_node, "padding_bottom")
  if (length(pt) == 1L && !is.na(pt)) {
    parts <- c(
      parts,
      sprintf("abovesep=%spt", format(pt, trim = TRUE, scientific = FALSE))
    )
  }
  if (length(pb) == 1L && !is.na(pb)) {
    parts <- c(
      parts,
      sprintf("belowsep=%spt", format(pb, trim = TRUE, scientific = FALSE))
    )
  }
  if (length(parts) == 0L) {
    return("")
  }
  sprintf("\\SetRow{%s} ", paste(parts, collapse = ","))
}

# Emit tabularray table-level `leftsep=Lpt, rightsep=Rpt` from the
# horizontal cell-padding SSOT so the rendered per-side margin matches
# the measured column width (`.compute_col_width` adds left + right).
# These are outer-spec keys (the per-side analogue of the symmetric
# `colsep`); per-cell indent rides a `\leftskip` group on top
# (see `.latex_indent_wrap`).
# A scalar body `@padding` override (from `cells_style`) wins on both
# sides; else the configured `cell_padding_h` pair. Returns
# character(0) when no preset is available so headless callers stay
# byte-stable.
.latex_cellsep_inner <- function(cells_style = NULL, preset = NULL) {
  if (!is_preset_spec(preset)) {
    return(character())
  }
  lr <- .resolve_cell_padding_lr(cells_style, preset)
  sprintf(
    "leftsep=%spt, rightsep=%spt",
    format(lr[[1L]], trim = TRUE, scientific = FALSE),
    format(lr[[2L]], trim = TRUE, scientific = FALSE)
  )
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
.render_latex_inline <- function(ast, preserve = TRUE) {
  if (!is_inline_ast(ast)) {
    return("")
  }
  .render_latex_children(ast@runs, preserve, lead = TRUE, trail = TRUE)
}

# Render one AST run record to its LaTeX markup. Recurses
# through `children` for wrapping types. `lead` / `trail` flag the
# run's line-edge position (only line-edge whitespace becomes a `~`
# tie; inter-run spaces stay breakable).
.render_latex_run <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  type <- run$type
  switch(
    type,
    plain = .latex_escape_text_run(run$text %||% "", preserve, lead, trail),
    bold = paste0(
      "\\textbf{",
      .render_latex_children(run$children, preserve, lead, trail),
      "}"
    ),
    italic = paste0(
      "\\textit{",
      .render_latex_children(run$children, preserve, lead, trail),
      "}"
    ),
    sup = paste0(
      "\\textsuperscript{",
      .render_latex_children(run$children, preserve, lead, trail),
      "}"
    ),
    sub = paste0(
      "\\textsubscript{",
      .render_latex_children(run$children, preserve, lead, trail),
      "}"
    ),
    code = paste0(
      "\\texttt{",
      .render_latex_children(run$children, preserve, lead, trail),
      "}"
    ),
    link = .render_latex_link(run, preserve, lead, trail),
    span = .render_latex_children(run$children, preserve, lead, trail),
    # `\\{}` not bare `\\`: the trailing empty group stops LaTeX's `\\`
    # from swallowing a following `[...]` (e.g. a footnote marker like
    # `[1]` on the next line) as its optional `\\[<dimen>]` argument,
    # which would otherwise raise "Illegal unit of measure".
    newline = " \\\\{} ",
    .latex_escape_text_run(run$text %||% "", preserve, lead, trail)
  )
}

# Escape a plain-text run and, when preserving, rewrite significant
# whitespace runs into `~` active ties (the single chokepoint for
# inline plain text, mirroring the body-cell path).
.latex_escape_text_run <- function(
  text,
  preserve,
  lead = TRUE,
  trail = TRUE
) {
  .escape_text_run(text, .latex_escape, "~", preserve, lead, trail)
}

# Render the children of a wrapping run. Each child's line-edge flags
# come from its position (first / after-newline -> line-leading, etc.).
.render_latex_children <- function(
  children,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  .render_ast_children(children, .render_latex_run, preserve, lead, trail)
}

# Render a link run as `\href{url}{text}` (requires the
# `hyperref` package, already in the preamble). Title attribute
# from the inline_ast is dropped (no equivalent in `\href`).
.render_latex_link <- function(
  run,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  text <- .render_latex_children(run$children, preserve, lead, trail)
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
.latex_escape_cell <- function(text, preserve = TRUE) {
  if (is.null(text) || length(text) == 0L) {
    return("")
  }
  text <- as.character(text)
  text[is.na(text)] <- ""
  # Peel any auto-footnote marker sentinel off the cell end before
  # escaping; re-attach it as `\textsuperscript{}` afterwards.
  peeled <- .fn_peel(text)
  text <- .latex_escape(peeled$base)
  # LaTeX in-cell line break is `\\`; the trailing `{}` stops a
  # following `[...]` (e.g. a footnote marker like `[1]`) from being read
  # as the optional `\\[<dimen>]` argument, which would raise "Illegal
  # unit of measure". Mirrors the newline run in `.render_latex_run`.
  text <- gsub("\r\n", " \\\\{} ", text, fixed = TRUE)
  text <- gsub("\n", " \\\\{} ", text, fixed = TRUE)
  # Preserve significant ASCII whitespace LAST, after the indent strip
  # at the call site and the `\n` -> `\\{}` conversion. The `~` active
  # tie is non-breaking; inserted post-escape so it is not rewritten to
  # `\textasciitilde{}`. Single interior spaces stay breakable.
  if (isTRUE(preserve)) {
    text <- .preserve_ws(text, "~")
  }
  if (any(peeled$has)) {
    text[peeled$has] <- paste0(
      text[peeled$has],
      "\\textsuperscript{",
      .latex_escape(peeled$marker[peeled$has]),
      "}"
    )
  }
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
  pagefoot_ast = NULL,
  border_color_defs = character(),
  cs = NULL
) {
  if (is.null(preset) || !is_preset_spec(preset)) {
    preset <- preset_spec()
  }
  geo <- .latex_geometry_opts(preset)
  body_font_size <- .effective_font_size(preset)
  body_font_family <- .effective_font_family(preset)
  class_opt <- .latex_class_size(body_font_size)
  font_lines <- .latex_font_lines(body_font_family, body_font_size)
  chrome <- .latex_pagestyle_block(
    pagehead_ast,
    pagefoot_ast,
    preset,
    cs = cs
  )

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
    # Named colours for tabularray border `fg=` tokens (rules cannot
    # carry an inline xcolor model, so each hex is pre-defined).
    border_color_defs,
    font_lines,
    "\\setlength{\\parindent}{0pt}",
    "\\setlength{\\parskip}{0pt}",
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
.latex_pagestyle_block <- function(
  pagehead_ast,
  pagefoot_ast,
  preset,
  cs = NULL
) {
  ph_pop <- .page_band_is_populated(pagehead_ast)
  pf_pop <- .page_band_is_populated(pagefoot_ast)
  if (!ph_pop && !pf_pop) {
    # No running header/footer band: suppress LaTeX's default `plain`
    # pagestyle so no stray page number prints. Page numbers appear ONLY
    # when the user puts {page}/{npages} in a pagehead/pagefoot.
    return(list(packages = character(), style = "\\pagestyle{empty}"))
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
      .latex_band_directives(pagehead_ast, head = TRUE, cs = cs)
    )
  }
  if (pf_pop) {
    body <- c(
      body,
      .latex_band_directives(pagefoot_ast, head = FALSE, cs = cs)
    )
  }
  # Head- / footrule width: 0pt by default (the page bands are unruled,
  # galley parity). `style(border_bottom = brdr(), .at = cells_pagehead())`
  # opts a header band into a rule by setting the `pagehead_bottom`
  # chrome region (`pagefoot_top` for the footer band) -> the rule width
  # drives `\headrulewidth` / `\footrulewidth` (Thread G).
  body <- c(
    body,
    sprintf(
      "\\renewcommand{\\headrulewidth}{%s}",
      .latex_band_rule_width(cs, "pagehead_bottom")
    ),
    sprintf(
      "\\renewcommand{\\footrulewidth}{%s}",
      .latex_band_rule_width(cs, "pagefoot_top")
    )
  )
  list(packages = packages, style = body)
}

# Resolve a page-band chrome border region to a fancyhdr rule width.
# Returns "0pt" when the region carries no rule (or style "none"), else
# the triple's width in pt.
.latex_band_rule_width <- function(cs, region) {
  triple <- .chrome_border_at(cs, region)
  if (is.null(triple) || identical(triple$style, "none")) {
    return("0pt")
  }
  sprintf("%gpt", as.numeric(triple$width))
}

# Emit the three `\fancyhead[L/C/R]{}` (when head = TRUE) or
# `\fancyfoot[L/C/R]{}` (head = FALSE) directives for one band.
# Empty slots emit `\fancyhead[L]{}` (or equivalent) so any prior
# default for that slot is cleared.
.latex_band_directives <- function(band, head, cs = NULL) {
  cmd <- if (head) "\\fancyhead" else "\\fancyfoot"
  surface <- if (head) "pagehead" else "pagefoot"
  slot_letters <- c(left = "L", center = "C", right = "R")
  vapply(
    names(slot_letters),
    function(s) {
      txt <- .latex_band_slot_text(band[[s]], head = head)
      # Per-slot text props (bold / italic / colour / font) from
      # cells_pagehead(slot = s) wrap the slot content (Thread G).
      node <- .chrome_surface_at_slot(cs, surface, slot = s)
      if (nzchar(txt) && is_style_node(node)) {
        txt <- .latex_wrap_text_props(txt, node)
      }
      sprintf("%s[%s]{%s}", cmd, slot_letters[[s]], txt)
    },
    character(1L)
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
