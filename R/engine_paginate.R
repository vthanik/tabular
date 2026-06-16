# engine_paginate.R — resolve-engine phase that turns a
# pagination_spec into a flat list of page descriptors. Each
# descriptor names the rows and columns that ride on one display
# page. The downstream emit / backend layer iterates over the list
# to render one page at a time.
#
# Row budget is auto-computed (galley model): paper height for the
# active orientation, minus top + bottom margins, minus chrome rows
# (titles + spacing + column-header band + footnotes + spacing),
# divided by the row height at the active body font size. Landscape
# pages naturally carry fewer body rows than portrait at the same
# paper; smaller fonts carry more. Inputs come from the spec's
# preset (or preset_spec defaults) plus the spec's titles, headers,
# and footnotes.
#
# Vertical split: divide rows into chunks of the computed budget,
# adjusting break points so that contiguous runs of identical
# values in `keep_together` group columns are not split. The
# `widow_floor` rule merges a tiny final page back onto the
# previous one. The `orphan_floor` rule is the escape valve when
# a group run is taller than one page.
#
# Horizontal split: when `panels > 1`, divide the non-group
# columns into approximately equal chunks and replicate every
# group column on every panel. Group columns ride on every panel
# for row context.

#' Resolve the pagination spec to a list of page descriptors
#'
#' Pure function. Called by the resolve engine after `engine_style()`
#' and before backend emission. Returns a pagination plan: a list
#' that describes each display page in terms of row indices and
#' column indices into the resolved data.
#'
#' Returned shape:
#' \preformatted{
#' list(
#'   rows_per_page = integer(1),
#'   total_pages   = integer(1),
#'   total_panels  = integer(1),
#'   pages = list(
#'     list(
#'       page_index      = integer(1),
#'       panel_index     = integer(1),
#'       row_indices     = integer(),
#'       col_indices     = integer(),
#'       is_continuation = logical(1),
#'       continuation    = character(0|1),
#'       show_titles         = logical(1),
#'       repeat_headers      = logical(1),
#'       show_footnotes_here = logical(1)
#'     ),
#'     ...
#'   )
#' )
#' }
#'
#' When no `pagination_spec` is attached, the function returns a
#' one-page plan covering every row and column with
#' `is_continuation = FALSE`.
#'
#' **Native pagination.** When `native = TRUE` (backends that delegate
#' vertical pagination to the consuming application, e.g. RTF/Word), the
#' vertical split is skipped: each `(subgroup x horizontal panel)` rides
#' on ONE page covering every row, and `total_pages` therefore reports the
#' rendered section count (one per panel), not an estimated vertical-page
#' count. Horizontal panels are still split (the consumer cannot reflow
#' columns). `rows_per_page` and `keep_with_next` are still computed from
#' the physical page budget so the keep mask keeps its group-fit-vs-edge
#' semantics; the consumer reads `keep_with_next` to choose its own break
#' points.
#'
#' **Continuous media.** When `continuous = TRUE` (HTML / Markdown, which
#' have no fixed page width), the horizontal split is meaningless, so the
#' panels collapse to ONE all-columns page in original order with the stub
#' shown once. The would-be panel boundaries are still reported via
#' `panel_spans` so the backend can draw a header note; `total_panels`
#' still reports the logical (pre-collapse) panel count.
#'
#' @param spec A `tabular_spec`.
#' @param native Skip the vertical split (one page per panel) for backends
#'   that paginate natively. Defaults to `FALSE` (tabular estimates the
#'   split itself).
#' @param continuous Collapse the horizontal panel split into one
#'   all-columns page for continuous, scrollable backends (HTML /
#'   Markdown). Defaults to `FALSE`. Mutually independent of `native`.
#' @return A pagination plan as described above, plus `repeat_titles` /
#'   `repeat_headers` / `repeat_footnotes` (the resolved `repeat_content`
#'   membership) so native backends know which chrome rows repeat, and
#'   `panel_spans` (per-panel non-stub column membership, or `NULL` when
#'   fewer than two panels) for the continuous-backend header note.
#' @keywords internal
#' @noRd
engine_paginate <- function(spec, native = FALSE, continuous = FALSE) {
  data <- spec@data
  nrow_data <- nrow(data)
  col_names <- names(data)

  pag <- spec@pagination
  pag_set <- is_pagination_spec(pag)

  orphan <- if (pag_set) pag@orphan_floor else .default_orphan_floor
  widow <- if (pag_set) pag@widow_floor else .default_widow_floor
  panels <- if (pag_set) pag@panels else 1L
  rc <- if (pag_set) {
    pag@repeat_content
  } else {
    c("titles", "headers", "footnotes")
  }
  rep_titles <- "titles" %in% rc
  rep_headers <- "headers" %in% rc
  rep_footnotes <- "footnotes" %in% rc
  cont <- if (pag_set) pag@continuation else character()
  kt <- if (pag_set) pag@keep_together else character()

  rpp <- .compute_rows_per_page(spec, native = native)

  kt_idx <- if (length(kt) > 0L) match(kt, col_names) else integer()

  # Native backends (RTF/Word) paginate the body themselves: skip the
  # vertical split so every row rides one page per panel and the
  # section-header / blank-row injection runs once over the full range.
  # The keep mask below is still computed from the physical budget so the
  # consumer's break points honour keep_together.
  row_pages <- if (native) {
    if (nrow_data == 0L) list(integer()) else list(seq_len(nrow_data))
  } else {
    .compute_vertical_pages(
      nrow_data = nrow_data,
      rpp = rpp,
      kt_idx = kt_idx,
      data = data,
      orphan_floor = orphan,
      widow_floor = widow
    )
  }

  # Keep-with-next mask drives the RTF and LaTeX backend's native
  # pagination hints (`\trkeep` + `\keepn` in RTF, `\nopagebreak[4]`
  # after each row in LaTeX). Each entry says "render row i glued
  # to row i+1 — do not break between them". For keep_together
  # groups that fit on one page the entire group glues. For
  # oversized groups only the top (`orphan_floor - 1`) and bottom
  # (`widow_floor - 1`) edges glue so the middle stays free to
  # split.
  keep_with_next <- .build_keep_mask(
    data = data,
    kt_idx = kt_idx,
    rpp = rpp,
    orphan_floor = orphan,
    widow_floor = widow
  )

  # Stub columns repeat on every panel: the `usage = "group"` set
  # widened to include `usage = "id"` (the non-collapsing row
  # identifier). keep_together is driven independently by `kt_idx`
  # above, so this is the only consumer here.
  stub_cols <- .stub_col_names(spec@cols)
  # Filter visible columns BEFORE pagination so the slice phase
  # (`.slice_one_page`) and every backend see only the columns the
  # user wants rendered. Hidden columns (col_spec@visible = FALSE)
  # remain in spec@data for upstream phases (sort_rows / subgroup)
  # but never reach the backend renderer.
  visible_col_names <- .visible_col_names(spec, col_names)
  col_panels <- .compute_horizontal_panels(
    col_names = visible_col_names,
    stub_col_names = stub_cols,
    panels = panels
  )
  # `.compute_horizontal_panels` returns indices into its
  # `col_names` argument; remap them to indices into the full
  # `col_names` vector so the downstream slice picks the right
  # data / style / label columns.
  visible_indices <- match(visible_col_names, col_names)
  col_panels <- lapply(col_panels, function(idx) visible_indices[idx])

  # Per-panel non-stub column membership for the continuous-backend
  # header note. Computed from the TRUE split (before any collapse) so
  # it survives the collapse below. `stub_idx` is in full-`col_names`
  # space, matching the remapped `col_panels`.
  stub_idx <- match(intersect(stub_cols, visible_col_names), col_names)
  stub_idx <- stub_idx[!is.na(stub_idx)]
  panel_spans <- .panel_spans_from_panels(col_panels, stub_idx, col_names)

  # Continuous media (HTML / Markdown) have no page width, so the
  # horizontal split is meaningless: collapse to ONE all-columns page
  # (stub once, original order) and let `panel_spans` carry the
  # boundaries for a header note. `n_panels_effective` (pre-collapse)
  # drives the reported `total_panels`; `n_horiz` (post-collapse) drives
  # the page loop and `total_pages` -- the two are now distinct.
  n_panels_effective <- length(col_panels)
  # Collapse to ONE all-columns page when either (a) the medium is
  # continuous (no page width, so the horizontal split is meaningless) or
  # (b) the data is empty (no rows to split, so horizontal panels would
  # only multiply the single empty-state page into N identical phantoms).
  # `sort(unique(unlist(...)))` rebuilds the full ordered column set; the
  # stub repeats across panels, so unique() drops the duplicates.
  collapse_to_one <- (isTRUE(continuous) && n_panels_effective > 1L) ||
    nrow_data == 0L
  if (collapse_to_one) {
    col_panels <- list(sort(unique(unlist(col_panels))))
  }
  # An empty table renders as a single page; report one panel so
  # total_panels and total_pages agree.
  if (nrow_data == 0L) {
    n_panels_effective <- 1L
  }

  n_vert <- length(row_pages)
  n_horiz <- length(col_panels)
  total_pages <- n_vert * n_horiz

  pages <- vector("list", total_pages)
  k <- 1L
  for (panel_i in seq_len(n_horiz)) {
    for (vert_i in seq_len(n_vert)) {
      # Per-page chrome booleans derived from repeat_content so each
      # backend reads simple flags. Each physical page (including
      # panel pages) is self-contained: page 1 of every panel shows
      # titles; the last vertical page of every panel shows last-page
      # footnotes. Headers repeat per the flag.
      is_first <- vert_i == 1L
      is_last <- vert_i == n_vert
      pages[[k]] <- list(
        page_index = vert_i,
        panel_index = panel_i,
        row_indices = row_pages[[vert_i]],
        col_indices = col_panels[[panel_i]],
        is_continuation = vert_i > 1L || panel_i > 1L,
        continuation = cont,
        show_titles = rep_titles || is_first,
        repeat_headers = rep_headers,
        show_footnotes_here = rep_footnotes || is_last
      )
      k <- k + 1L
    }
  }

  list(
    rows_per_page = as.integer(rpp),
    total_pages = as.integer(total_pages),
    total_panels = as.integer(n_panels_effective),
    panel_spans = panel_spans,
    pages = pages,
    keep_with_next = keep_with_next,
    repeat_titles = rep_titles,
    repeat_headers = rep_headers,
    repeat_footnotes = rep_footnotes
  )
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Floor for the computed rows-per-page. Below 5, pagination is more
# noise than signal — one big chrome-heavy spec on a tiny font
# could mathematically yield 0; we floor it instead. Matches
# galley's minimum-row constraint.
.min_rows_per_page <- 5L

# Defaults that mirror pagination_spec defaults; used when the spec
# carries no pagination_spec at all.
.default_orphan_floor <- 3L
.default_widow_floor <- 2L

# Compute the per-page body-row budget from the active preset and
# the spec's title / header / footnote chrome. Returns an integer.
# Under `native = TRUE` the budget is only used to size the
# keep_with_next mask (the consumer paginates), so a chrome block taller
# than the printable area floors to `.min_rows_per_page` instead of
# aborting, which the non-native split path does.
# Body content-box: the printable region between the header rule and
# the footnote rule, after page margins and the chrome rows (titles plus
# their separating blank line, the column-header band, footnotes plus
# their separating blank line). Returns a named list in twips and
# inches, plus the per-row height and chrome-row count the paginator
# needs. SINGLE SOURCE OF TRUTH shared by `.compute_rows_per_page`
# (rows-per-page) and the placement of full-box content — the empty-state
# message, and figures in a later release. `usable_twips` is the height
# before chrome (page minus top/bottom margins), kept for the
# chrome-too-tall diagnostic. The one-blank-line separations match
# galley's spacing convention.
.content_box <- function(spec) {
  preset <- .effective_preset(spec)

  dims <- .paper_dims_twips(preset@paper_size, preset@orientation)
  page_width <- dims[["width"]]
  page_height <- dims[["height"]]

  mtb <- .margin_top_bottom_twips(preset@margins)
  mlr <- .margin_left_right_twips(preset@margins)
  margin_v <- mtb[["top"]] + mtb[["bottom"]]
  margin_h <- mlr[["left"]] + mlr[["right"]]

  one_row <- .row_height_twips(preset@font_size)
  width_twips <- page_width - margin_h

  # Title / footnote rows are counted by RENDERED (wrapped) lines at the
  # printable width, not element count: a long footnote wraps to several
  # lines, so reserving one row per element leaves the body box too tall
  # and the wrapped overflow runs off the page (an empty-state message box
  # is sized from this; a short block wraps to one line, matching the old
  # element count, so a non-wrapping table paginates unchanged).
  n_title_lines <- .wrapped_line_count(
    spec@titles,
    preset,
    width_twips / 1440
  )
  n_footnote_lines <- .wrapped_line_count(
    spec@footnotes,
    preset,
    width_twips / 1440
  )
  n_header_lines <- .count_header_lines(spec)
  title_spacing <- if (n_title_lines > 0L) 1L else 0L
  footnote_spacing <- if (n_footnote_lines > 0L) 1L else 0L
  chrome_rows <- n_title_lines +
    title_spacing +
    n_header_lines +
    n_footnote_lines +
    footnote_spacing

  usable_twips <- page_height - margin_v
  height_twips <- usable_twips - chrome_rows * one_row

  list(
    width_twips = width_twips,
    height_twips = height_twips,
    usable_twips = usable_twips,
    width_in = width_twips / 1440,
    height_in = height_twips / 1440,
    one_row_twips = one_row,
    chrome_rows = chrome_rows
  )
}

.compute_rows_per_page <- function(spec, native = FALSE) {
  box <- .content_box(spec)
  available <- box$height_twips
  one_row <- box$one_row_twips

  if (available <= 0L) {
    # Native backends paginate the body themselves, so chrome taller than
    # the page is not fatal; floor the mask budget and let the consumer
    # break. The non-native split path still aborts (data rows would
    # otherwise print on top of the chrome).
    if (isTRUE(native)) {
      return(.min_rows_per_page)
    }
    # Titles + header band + footnotes alone exceed the printable
    # height, so no data row can fit. Abort loudly rather than
    # silently flooring to .min_rows_per_page (which would print data
    # rows on top of the chrome).
    usable_rows <- as.integer(box$usable_twips %/% one_row)
    chrome_rows <- box$chrome_rows
    cli::cli_abort(
      c(
        "Page chrome is taller than the printable area.",
        "x" = "Titles, header band, and footnotes need {chrome_rows} row{?s}; the page holds {usable_rows}.",
        "i" = "Reduce title or footnote lines, shrink {.code preset(font_size = ...)}, or widen the page or margins."
      ),
      class = "tabular_error_layout",
      call = rlang::caller_env()
    )
  }
  rpp <- as.integer(available %/% one_row)
  max(.min_rows_per_page, rpp)
}

# Count display lines in a character vector, expanding any embedded
# "\n" line breaks. Length-0 input returns 0L.
.count_lines <- function(x) {
  if (length(x) == 0L) {
    return(0L)
  }
  parts <- strsplit(x, "\n", fixed = TRUE)
  sum(vapply(parts, length, integer(1)))
}

# Count the PHYSICAL (wrapped) lines a chrome text block occupies at a
# given printable width -- the line-aware sibling of .count_lines. A long
# title or footnote wraps to several lines, so a box that reserves only one
# row per element is too tall, and the wrapped overflow runs off the page
# (DOCX figure footnotes flow in the body; an empty-state message box and a
# table's footer reservation are likewise sized from this count).
#
# Wrapping is computed by GREEDY WORD PACKING against AFM-measured word
# widths, mirroring how LaTeX (\raggedright), RTF and Word break a
# paragraph: words are placed on a line until the next word would exceed
# the available width, then a new line starts. A naive total-width / line-
# width ratio systematically under-counts (it assumes characters pack with
# no word-boundary slack), which let a footnote's last line spill onto a
# second page. Embedded "\n" breaks expand first, mirroring .count_lines.
# Length-0 input returns 0L; an empty element still counts as one line, so
# a short, non-wrapping block matches .count_lines exactly (no change to a
# default figure or table).
.wrapped_line_count <- function(text, preset, avail_w_in) {
  if (length(text) == 0L) {
    return(0L)
  }
  afm <- .resolve_afm_name(.effective_font_family(preset))
  size_pt <- .effective_font_size(preset)
  w_in <- function(s) as.numeric(.text_width_em(s, afm)) / 1000 * size_pt / 72
  space_w <- w_in(" ")
  total <- 0L
  for (el in text) {
    sublines <- strsplit(el, "\n", fixed = TRUE)[[1L]]
    if (length(sublines) == 0L) {
      total <- total + 1L
      next
    }
    for (s in sublines) {
      words <- strsplit(s, "[ \t]+")[[1L]]
      words <- words[nzchar(words)]
      if (length(words) == 0L) {
        total <- total + 1L
        next
      }
      line_w <- 0
      n_lines <- 1L
      for (wd in words) {
        ww <- w_in(wd)
        candidate <- if (line_w == 0) ww else line_w + space_w + ww
        if (candidate > avail_w_in && line_w > 0) {
          n_lines <- n_lines + 1L
          line_w <- ww
        } else {
          line_w <- candidate
        }
      }
      total <- total + n_lines
    }
  }
  total
}

# Count header-band rows. Header height is the max embedded-\n line
# count across visible column labels, plus the depth of any
# spanning-header tree. Returns 1L when the spec has no columns yet
# (auto-header band of one line).
.count_header_lines <- function(spec) {
  max_label_lines <- 1L
  cols <- spec@cols
  if (length(cols) > 0L) {
    visible_labels <- vapply(
      cols,
      function(cs) {
        if (isFALSE(cs@visible)) {
          return("")
        }
        lab <- cs@label
        if (is.na(lab)) cs@name else lab
      },
      character(1)
    )
    visible_labels <- visible_labels[nzchar(visible_labels)]
    if (length(visible_labels) > 0L) {
      per_label_lines <- vapply(
        visible_labels,
        function(lbl) length(strsplit(lbl, "\n", fixed = TRUE)[[1L]]),
        integer(1)
      )
      max_label_lines <- max(per_label_lines)
    }
  }

  header_depth <- 0L
  if (length(spec@headers) > 0L) {
    header_depth <- .header_max_depth(spec@headers)
  }
  max_label_lines + header_depth
}

# Recursive max depth of a list of header_node trees. Used to count
# spanner rows above the leaf-column-label row.
.header_max_depth <- function(nodes) {
  if (length(nodes) == 0L) {
    return(0L)
  }
  max(vapply(
    nodes,
    function(node) {
      kids <- node@children
      if (length(kids) == 0L) {
        1L
      } else {
        1L + .header_max_depth(kids)
      }
    },
    integer(1)
  ))
}

# Vertical pagination: return a list of integer vectors, each
# vector the row indices for one page. Honours `keep_together`
# (move break back to start of straddling group) and `widow_floor`
# (merge a tiny final page into the previous one).
.compute_vertical_pages <- function(
  nrow_data,
  rpp,
  kt_idx,
  data,
  orphan_floor,
  widow_floor
) {
  if (nrow_data == 0L) {
    return(list(integer()))
  }
  if (nrow_data <= rpp) {
    return(list(seq_len(nrow_data)))
  }

  pages <- list()
  start <- 1L
  while (start <= nrow_data) {
    tentative_end <- min(start + rpp - 1L, nrow_data)

    if (length(kt_idx) > 0L && tentative_end < nrow_data) {
      adjusted_end <- .respect_keep_together(
        start = start,
        tentative_end = tentative_end,
        kt_idx = kt_idx,
        data = data
      )
      if (adjusted_end >= start + orphan_floor - 1L) {
        tentative_end <- adjusted_end
      }
    }

    pages[[length(pages) + 1L]] <- seq.int(start, tentative_end)
    start <- tentative_end + 1L
  }

  n <- length(pages)
  if (n >= 2L && length(pages[[n]]) < widow_floor) {
    pages[[n - 1L]] <- c(pages[[n - 1L]], pages[[n]])
    pages[[n]] <- NULL
  }

  pages
}

# Build the global keep-with-next logical vector consumed by the
# RTF and LaTeX backends. Mirrors galley's `build_keep_mask`
# semantics (R/render-common.R) lifted to tabular's source-row
# scale — tabular's blank-row separators are injected per-page by
# the renderer rather than living in the source data, so every
# index here points at a real data row.
#
# Returns a length-`nrow(data)` logical vector. `TRUE` at position
# i means "render row i glued to row i+1 (do not break between
# them)". Falls back to all-`FALSE` when `kt_idx` is empty.
.build_keep_mask <- function(data, kt_idx, rpp, orphan_floor, widow_floor) {
  nr <- nrow(data)
  if (nr <= 1L || length(kt_idx) == 0L) {
    return(rep(FALSE, nr))
  }

  # Build a single string key per row over the keep_together cols.
  key_parts <- lapply(kt_idx, function(j) as.character(data[, j]))
  keys <- do.call(
    function(...) paste(..., sep = "\x1f"),
    key_parts
  )

  mask <- rep(FALSE, nr)
  start <- 1L
  while (start <= nr) {
    end <- start
    while (end < nr && keys[[end + 1L]] == keys[[start]]) {
      end <- end + 1L
    }
    group_size <- end - start + 1L
    if (group_size > 1L) {
      if (group_size <= rpp) {
        # Group fits on one page: full keepn chain (every row but
        # the last in the group glues to the next).
        mask[start:(end - 1L)] <- TRUE
      } else {
        # Oversized group: only edge protection. Top
        # `orphan_floor - 1` rows glue downward; bottom
        # `widow_floor - 1` rows glue downward (everything but the
        # very last row in the group).
        top_n <- max(0L, orphan_floor - 1L)
        if (top_n > 0L) {
          mask[start:(start + top_n - 1L)] <- TRUE
        }
        bottom_n <- max(0L, widow_floor - 1L)
        if (bottom_n > 0L) {
          bottom_start <- end - bottom_n
          if (bottom_start < end) {
            mask[bottom_start:(end - 1L)] <- TRUE
          }
        }
      }
    }
    start <- end + 1L
  }

  # The final row in the data is never followed by anything; clear
  # any mask that landed on the last index.
  if (mask[nr]) {
    mask[nr] <- FALSE
  }
  mask
}

# Move the tentative page break back if it would split a contiguous
# run of identical values in `keep_together` columns. Returns the
# adjusted page-end row index. If the run extends back past `start`
# (the entire page is one big run), returns the original
# `tentative_end` so the caller's orphan-floor escape can trigger.
.respect_keep_together <- function(start, tentative_end, kt_idx, data) {
  if (tentative_end + 1L > nrow(data)) {
    return(tentative_end)
  }

  key_at <- function(i) {
    parts <- vapply(
      kt_idx,
      function(j) as.character(data[i, j]),
      character(1)
    )
    paste(parts, collapse = "\x1f")
  }

  end_key <- key_at(tentative_end)
  next_key <- key_at(tentative_end + 1L)
  if (end_key != next_key) {
    return(tentative_end)
  }

  i <- tentative_end - 1L
  while (i >= start && key_at(i) == end_key) {
    i <- i - 1L
  }
  if (i < start) {
    return(tentative_end)
  }
  i
}

# Filter `col_names` to those whose `col_spec@visible` is TRUE.
# Columns absent from `spec@cols` (no col_spec set) default to
# visible. Used by engine_paginate to drop hidden columns BEFORE
# the slice phase; this is the single point that enforces
# `col_spec(visible = FALSE)` across every backend.
.visible_col_names <- function(spec, col_names) {
  # Finalize NA "unset" sentinels so this phase is self-sufficient on a
  # raw spec (production finalizes upstream; idempotent here).
  cols <- .finalize_col_specs(spec@cols)
  keep <- vapply(
    col_names,
    function(nm) {
      cs <- cols[[nm]]
      if (!is_col_spec(cs)) {
        return(TRUE)
      }
      isTRUE(cs@visible)
    },
    logical(1L)
  )
  col_names[keep]
}

# Horizontal pagination: split non-stub columns into approximately
# equal slices; repeat stub columns on every panel. The stub set is
# `usage in {group, id}` (see `.stub_col_names`). Returns a list of
# integer column-index vectors — one per panel.
.compute_horizontal_panels <- function(col_names, stub_col_names, panels) {
  ncol_data <- length(col_names)
  if (ncol_data == 0L) {
    return(list(integer()))
  }
  panels_int <- as.integer(panels)
  if (panels_int <= 1L) {
    return(list(seq_len(ncol_data)))
  }

  stub_idx <- match(intersect(stub_col_names, col_names), col_names)
  stub_idx <- stub_idx[!is.na(stub_idx)]
  non_stub_idx <- setdiff(seq_len(ncol_data), stub_idx)

  if (length(non_stub_idx) == 0L) {
    return(list(seq_len(ncol_data)))
  }

  n_eff <- min(panels_int, length(non_stub_idx))
  chunk_id <- .equal_chunks(length(non_stub_idx), n_eff)
  chunks <- split(non_stub_idx, chunk_id)

  lapply(chunks, function(ng) sort(c(stub_idx, ng)))
}

# Per-panel non-stub column membership for the continuous-backend
# header note. `col_panels` is the list of per-panel index vectors
# (in full-`col_names` space, already remapped); `stub_idx` are the
# stub columns to exclude (also full-`col_names` space). Returns
# `NULL` when there are fewer than two panels (nothing to annotate),
# else a list of `list(label = "Panel i", col_names = <non-stub cols
# of panel i, original order>)`.
.panel_spans_from_panels <- function(col_panels, stub_idx, col_names) {
  if (length(col_panels) <= 1L) {
    return(NULL)
  }
  lapply(
    seq_along(col_panels),
    function(i) {
      data_idx <- setdiff(col_panels[[i]], stub_idx)
      list(
        label = sprintf("Panel %d", i),
        col_names = col_names[sort(data_idx)]
      )
    }
  )
}

# Assign 1..n positions into `k` approximately equal chunks; returns
# an integer vector of length n with values in 1..k. Used to split
# non-group columns across panels without leaning on a heavy stats
# helper.
.equal_chunks <- function(n, k) {
  base <- n %/% k
  rem <- n %% k
  sizes <- rep(base, k) + c(rep(1L, rem), rep(0L, k - rem))
  rep(seq_len(k), sizes)
}
