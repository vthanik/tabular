# engine_footnotes.R — auto-numbered footnote resolution.
#
# `footnote()` records (text, id, symbol, location) on
# `tabular_spec@footnote_refs`. The engine assigns markers ONCE, at the
# spec level, in reading order, deduped by id, so the marker at the
# anchor is byte-identical across every backend and every page. The
# registry is then threaded (immutable) into each per-subgroup grid
# resolve, where the marker is STAMPED at locally-resolved cells:
# global identity, local placement.
#
# Two injection surfaces, dictated by the render pipeline:
#   * body cells render from the flat `cells_text` matrix AFTER decimal
#     alignment, so a marker is appended as a private-use sentinel
#     (`.fn_sentinel`) at the cell end -- never disturbing the decimal
#     pad -- and expanded by each backend's `*_escape_cell`.
#   * column labels / titles render from the inline AST, so a marker is
#     a native `sup` run appended to the relevant `inline_ast`.
#
# Reading order is a (surface, subgroup, row, col) ladder; body anchors
# are subgroup-major (a note whose cells live only in a later subgroup
# is lettered after earlier ones), which is why `engine_footnotes_assign`
# consumes the already-split `groups`.

# ---------------------------------------------------------------------
# Marker generators
# ---------------------------------------------------------------------

# Bijective base-26: 1 -> a, 26 -> z, 27 -> aa, 28 -> ab, ...
#' @noRd
.fn_marker_letters <- function(i) {
  out <- character(0L)
  repeat {
    i <- i - 1L
    out <- c(letters[(i %% 26L) + 1L], out)
    i <- i %/% 26L
    if (i == 0L) break
  }
  paste0(out, collapse = "")
}

#' @noRd
.fn_marker_numbers <- function(i) as.character(i)

# Leslie Lamport's standard LaTeX `\fnsymbol` sequence: asterisk,
# dagger, double-dagger, section, paragraph, double-vertical-bar
# (verified against The LaTeX Companion, 3rd ed., Table 3.7). After
# the six base glyphs the symbol is duplicated (`**`, daggerdagger,
# ...), so a marker is never silently reused once the set is exhausted.
#' @noRd
.fn_marker_symbols <- function(i) {
  sym <- c("*", "\u2020", "\u2021", "\u00a7", "\u00b6", "\u2016")
  base <- sym[((i - 1L) %% length(sym)) + 1L]
  strrep(base, ((i - 1L) %/% length(sym)) + 1L)
}

#' @noRd
.fn_marker <- function(i, scheme) {
  switch(
    scheme,
    letters = .fn_marker_letters(i),
    numbers = .fn_marker_numbers(i),
    symbols = .fn_marker_symbols(i),
    .fn_marker_letters(i)
  )
}

# ---------------------------------------------------------------------
# Registry: id -> marker, assigned once in reading order
# ---------------------------------------------------------------------

#' @noRd
.fn_registry_seed <- function() {
  list(
    seq = 0L,
    used = character(0L),
    markers = list(),
    order = character(0L)
  )
}

# Assign a marker to `id` (idempotent: dedup by id). A user-pinned
# `symbol` is used verbatim AND reserved so the auto-allocator skips it.
#' @noRd
.fn_assign <- function(reg, id, symbol, scheme) {
  if (!is.null(reg$markers[[id]])) {
    return(reg)
  }
  if (!is.null(symbol)) {
    m <- symbol
  } else {
    repeat {
      reg$seq <- reg$seq + 1L
      m <- .fn_marker(reg$seq, scheme)
      if (!m %in% reg$used) break
    }
  }
  reg$markers[[id]] <- m
  reg$used <- c(reg$used, m)
  reg$order <- c(reg$order, id)
  reg
}

# ---------------------------------------------------------------------
# Sentinel (body-cell marker carrier through cells_text -> backend)
# ---------------------------------------------------------------------

# Private-use delimiters: cannot appear in user data, survive width
# measurement, and are split out by each backend before escaping.
.FN_OPEN <- "\uE000"
.FN_CLOSE <- "\uE001"

#' @noRd
.fn_sentinel <- function(markers) {
  paste0(.FN_OPEN, paste0(markers, collapse = ","), .FN_CLOSE)
}

# Split a body cell into its base text and the trailing marker payload
# (NULL when the cell carries no footnote). One sentinel per cell, at
# the end, after the decimal-padded field.
#' @noRd
.split_fn_sentinel <- function(text) {
  if (is.na(text)) {
    return(list(base = text, marker = NULL))
  }
  pos <- regexpr(.FN_OPEN, text, fixed = TRUE)
  if (pos < 0L) {
    return(list(base = text, marker = NULL))
  }
  base <- substr(text, 1L, pos - 1L)
  inner <- substr(text, pos + 1L, nchar(text))
  marker <- sub(.FN_CLOSE, "", inner, fixed = TRUE)
  list(base = base, marker = marker)
}

# Substitute the sentinel with its bare marker glyph(s) so column-width
# measurement reserves room for the rendered superscript.
#' @noRd
.fn_width_text <- function(x) {
  gsub(paste0(.FN_OPEN, "(.*?)", .FN_CLOSE), "\\1", x, perl = TRUE)
}

# Vectorized: peel the trailing marker sentinel off each element. Returns
# the base text, the marker payload (NA where absent), and a `has` mask.
# Each backend's body `*_escape_cell` calls this, escapes the base as
# usual, and re-attaches the marker as its native superscript markup.
#' @noRd
.fn_peel <- function(text) {
  marker <- rep(NA_character_, length(text))
  has <- grepl(.FN_OPEN, text, fixed = TRUE)
  if (any(has)) {
    marker[has] <- sub(
      paste0("^.*", .FN_OPEN, "(.*)", .FN_CLOSE, "$"),
      "\\1",
      text[has]
    )
    text[has] <- sub(paste0(.FN_OPEN, ".*", .FN_CLOSE, "$"), "", text[has])
  }
  list(base = text, marker = marker, has = has)
}

# ---------------------------------------------------------------------
# Reading-order key
# ---------------------------------------------------------------------

#' @noRd
.fn_surface_rank <- function(surface) {
  switch(
    surface,
    title = 1L,
    pagehead = 2L,
    headers = 3L,
    subgroup = 4L,
    group_headers = 5L,
    body = 6L,
    footnotes = 7L,
    pagefoot = 8L,
    9L
  )
}

#' @noRd
.fn_keystr <- function(key) {
  sprintf("%03d|%06d|%08d|%06d", key[[1L]], key[[2L]], key[[3L]], key[[4L]])
}

# Resolve a `cells_headers()` anchor to the data-column name(s) it
# targets (by `j` name / index, or `labels` matched against names).
#' @noRd
.fn_header_cols <- function(loc, col_names) {
  if (!is.null(loc$j)) {
    if (is.character(loc$j)) {
      return(intersect(loc$j, col_names))
    }
    if (is.numeric(loc$j)) {
      idx <- loc$j[loc$j >= 1L & loc$j <= length(col_names)]
      return(col_names[idx])
    }
  }
  if (!is.null(loc$labels)) {
    return(intersect(loc$labels, col_names))
  }
  character(0L)
}

# Compute the reading-order key for one anchor. `matched = FALSE` when
# the anchor resolves to no cells (the caller warns and drops it).
# `visible_cols` is the set of column names that actually render (hidden
# and header_row group columns excluded); an anchor whose every target
# column is invisible is dropped with `hidden = TRUE` so the caller can
# name the offending column. This prevents an orphaned block line: a
# marker allocated for a column that is dropped before render.
#' @noRd
.fn_anchor_key <- function(loc, groups, col_names, visible_cols, call) {
  surface <- loc$surface
  rank <- .fn_surface_rank(surface)
  if (identical(surface, "body")) {
    for (gi in seq_along(groups)) {
      rows <- tryCatch(
        .resolve_layer_rows(loc, groups[[gi]]$spec@data, col_names, call),
        error = function(e) integer(0L)
      )
      if (length(rows) > 0L) {
        cols <- tryCatch(
          .resolve_layer_cols(loc, col_names, call),
          error = function(e) 0L
        )
        requested <- col_names[cols[cols >= 1L]]
        vis <- intersect(requested, visible_cols)
        if (length(requested) > 0L && length(vis) == 0L) {
          return(list(matched = FALSE, hidden = TRUE, col = requested[[1L]]))
        }
        ci <- if (length(vis) > 0L) match(vis, col_names) else cols
        return(list(matched = TRUE, key = c(rank, gi, min(rows), min(ci))))
      }
    }
    return(list(matched = FALSE))
  }
  if (identical(surface, "headers")) {
    cols <- .fn_header_cols(loc, col_names)
    if (length(cols) == 0L) {
      return(list(matched = FALSE))
    }
    vis <- intersect(cols, visible_cols)
    if (length(vis) == 0L) {
      return(list(matched = FALSE, hidden = TRUE, col = cols[[1L]]))
    }
    ci <- match(vis, col_names)
    return(list(matched = TRUE, key = c(rank, 0L, 0L, min(ci))))
  }
  if (identical(surface, "title")) {
    i <- loc$i %||% 1L
    return(list(matched = TRUE, key = c(rank, 0L, min(i), 0L)))
  }
  # Footnote anchors on other surfaces are not supported.
  list(matched = FALSE, unsupported = TRUE)
}

# ---------------------------------------------------------------------
# Spec-level marker assignment
# ---------------------------------------------------------------------

# Assign every footnote marker once, in reading order, deduped by id,
# and assemble the marked-footnote block. Returns NULL when the spec
# carries no footnotes (every downstream helper is then a no-op).
#' @noRd
engine_footnotes_assign <- function(
  spec,
  groups,
  call = rlang::caller_env()
) {
  refs <- spec@footnote_refs
  if (length(refs) == 0L) {
    return(NULL)
  }
  ps <- .effective_preset(spec)
  scheme <- if (is_preset_spec(ps)) ps@footnote_markers else "letters"
  label_tmpl <- if (is_preset_spec(ps)) ps@footnote_label else "{m}"
  col_names <- names(spec@data)
  # Anchor resolution + block assembly are O(refs x subgroups) plus a
  # linear `Find()` per block line. Both scale with the (small) footnote
  # count, never with the data, so the simple loops are intentional.
  visible_cols <- col_names[.visible_col_indices(spec, col_names)]

  enriched <- vector("list", length(refs))
  for (k in seq_along(refs)) {
    r <- refs[[k]]
    ak <- .fn_anchor_key(r$location, groups, col_names, visible_cols, call)
    if (!isTRUE(ak$matched)) {
      if (isTRUE(ak$unsupported)) {
        cli::cli_warn(c(
          "Footnote anchored to an unsupported location; dropping it.",
          "i" = "Anchor with {.fn cells_body}, {.fn cells_headers}, or {.fn cells_title}."
        ))
      } else if (isTRUE(ak$hidden)) {
        cli::cli_warn(c(
          "Footnote anchored to hidden column {.val {ak$col}}; dropping it.",
          "i" = "Make the column visible with {.code col_spec(visible = TRUE)} to show its marker."
        ))
      } else {
        cli::cli_warn(c(
          "Footnote matched no cells; dropping it.",
          "i" = "Check the {.arg .at} location."
        ))
      }
      next
    }
    enriched[[k]] <- list(
      text = r$text,
      id = r$id %||% sprintf(".auto%d", k),
      symbol = r$symbol,
      location = r$location,
      key = ak$key
    )
  }
  enriched <- Filter(Negate(is.null), enriched)
  if (length(enriched) == 0L) {
    return(NULL)
  }

  keystr <- vapply(enriched, function(e) .fn_keystr(e$key), character(1L))
  reg <- .fn_registry_seed()
  for (e in enriched[order(keystr)]) {
    reg <- .fn_assign(reg, e$id, e$symbol, scheme)
  }
  for (i in seq_along(enriched)) {
    enriched[[i]]$marker <- reg$markers[[enriched[[i]]$id]]
  }

  block <- lapply(reg$order, function(id) {
    e <- Find(function(x) identical(x$id, id), enriched)
    if (is.null(e)) {
      return(NULL)
    }
    .fn_block_line(label_tmpl, reg$markers[[id]], e$text)
  })
  block <- Filter(Negate(is.null), block)

  list(refs = enriched, markers = reg$markers, block_ast = block)
}

# Compose one marked-footnote line: the label (with `{m}` replaced by
# the marker) + a space + the footnote text, as a single inline_ast.
#' @noRd
.fn_block_line <- function(label_tmpl, marker, text) {
  label_str <- gsub("{m}", marker, label_tmpl, fixed = TRUE)
  runs <- c(
    parse_inline(label_str)@runs,
    list(list(type = "plain", text = " ")),
    parse_inline(text)@runs
  )
  inline_ast(runs = runs)
}

# ---------------------------------------------------------------------
# Injection (per single grid)
# ---------------------------------------------------------------------

# Append the marker sentinel to every body cell the footnotes anchor to,
# resolving anchors against THIS (sub)grid's data so row indices are
# local. Runs after engine_decimal so the sentinel sits past the padded
# field and alignment is untouched.
#' @noRd
engine_footnotes_mark_body <- function(
  cells_text,
  registry,
  data,
  col_names,
  call = rlang::caller_env()
) {
  if (is.null(registry)) {
    return(cells_text)
  }
  per <- list()
  for (e in registry$refs) {
    if (!identical(e$location$surface, "body")) {
      next
    }
    rows <- .resolve_layer_rows(e$location, data, col_names, call)
    cols <- .resolve_layer_cols(e$location, col_names, call)
    for (r in rows) {
      for (cc in cols) {
        key <- paste0(r, "|", cc)
        per[[key]] <- c(per[[key]], e$marker)
      }
    }
  }
  for (key in names(per)) {
    rc <- as.integer(strsplit(key, "|", fixed = TRUE)[[1L]])
    cur <- cells_text[rc[[1L]], rc[[2L]]]
    if (is.na(cur)) {
      cur <- ""
    }
    cells_text[rc[[1L]], rc[[2L]]] <- paste0(cur, .fn_sentinel(per[[key]]))
  }
  cells_text
}

# Append a native superscript run to every column label / title line
# the footnotes anchor to. These surfaces never pass through
# engine_decimal, so order is unconstrained.
#' @noRd
engine_footnotes_mark_ast <- function(
  col_labels_ast,
  titles_ast,
  registry,
  col_names
) {
  if (is.null(registry)) {
    return(list(col_labels_ast = col_labels_ast, titles_ast = titles_ast))
  }
  for (e in registry$refs) {
    surf <- e$location$surface
    if (identical(surf, "headers")) {
      for (nm in .fn_header_cols(e$location, col_names)) {
        col_labels_ast[[nm]] <- .fn_append_sup(col_labels_ast[[nm]], e$marker)
      }
    } else if (identical(surf, "title") && length(titles_ast) > 0L) {
      # cells_title() targets the whole title surface; place the marker
      # on the last (table-adjacent) title line.
      ii <- length(titles_ast)
      titles_ast[[ii]] <- .fn_append_sup(titles_ast[[ii]], e$marker)
    }
  }
  list(col_labels_ast = col_labels_ast, titles_ast = titles_ast)
}

#' @noRd
.fn_append_sup <- function(ast, marker) {
  sup_run <- list(
    type = "sup",
    children = list(list(type = "plain", text = marker))
  )
  if (is_inline_ast(ast)) {
    return(inline_ast(runs = c(ast@runs, list(sup_run))))
  }
  inline_ast(runs = list(sup_run))
}

# Append the assembled marked-footnote block after any manual footnote
# lines. Identical for every subgroup, so the first-subgroup-only grid
# merge carries it correctly with no merge-side change.
#' @noRd
engine_footnotes_append_block <- function(footnotes_ast, registry) {
  if (is.null(registry) || length(registry$block_ast) == 0L) {
    return(footnotes_ast)
  }
  c(footnotes_ast, registry$block_ast)
}
