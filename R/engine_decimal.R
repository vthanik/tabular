# engine_decimal.R — decimal-mark alignment for clinical TFL columns.
#
# Background:
#
#   Clinical tables routinely mix shapes within a single arm column. A
#   single "Age (years)" block typically holds an integer N row ("86"),
#   an est_spread Mean (SD) row ("75.2 (8.59)"), a float Median row
#   ("76.0"), a range Q1, Q3 row ("69.2, 81.8"), and integer Min / Max
#   rows ("61" / "88"). Pharma reviewers expect every numeric value's
#   first decimal mark to align on the same vertical line — the
#   integer's units digit must sit immediately above the float's
#   decimal point, and the float's decimal point must sit on the same
#   column as every other float's decimal point.
#
# Design (one-pass alignment with per-section refinement):
#
#   1. TOKENIZE — each cell decomposes into:
#        floats   : an ordered character vector of float tokens
#                   matching [<>=]?-?\d+(\.\d+)?  (one or more)
#        literals : K+1 fixed-string segments between/around the floats
#      A cell with no floats (e.g., "Yes", "Total", "") yields
#      floats = character(), literals = c(text).
#
#   2. OPAQUE — cells whose trimmed value matches `not_considered`
#      (e.g. "NR", "BLQ", "NE", "--") are flagged opaque BEFORE
#      width computation; they contribute nothing to slot widths and
#      render as raw text right-padded to column width. Closes the
#      missing-token class that galley / aligngen.sas both treat as
#      a first-class concept.
#
#   3. COLUMN FLOOR — when `sections` is non-NULL, a single pre-pass
#      across every non-opaque cell sets the floor for slot-1
#      sign+int width and comparator-prefix width. Each section's
#      `.compute_widths()` then uses `max(section_w, floor_w)` for
#      slot 1, so the leftmost integer column is uniform PAGE-WIDE
#      (within the arm column) while everything to its right stays
#      section-scoped. Matches the user's "86 75 14 69 align based
#      on page, after-the-integer goes per-section" rule.
#
#   4. SIGNATURE — each cell's signature is (n_floats, literals).
#      The section's DOMINANT signature is the most-floats,
#      most-frequent, first-appearing signature. The dominant
#      signature drives the canonical layout: its literals are the
#      section's canonical literals; its float count sets the
#      number of aligned slots.
#
#   5. WIDTHS — per slot k = 1..K_dominant compute:
#        int_w[k]    : max nchar(sign+int) across cells whose own
#                      slot-k float exists. Slot 1 is also floored
#                      by the column-wide value when sections-mode
#                      is active.
#        has_dec[k]  : any cell has a non-empty dec at slot k.
#        dec_w[k]    : max nchar(dec) across cells with non-empty
#                      dec at slot k.
#        prefix_w[k] : max comparator-prefix width at slot k.
#
#   6. RENDER — for each cell, one of:
#        OPAQUE          -> raw text (will be right-padded later).
#        ZERO-SUPPRESS   -> when n=0 in an n_pct-style shape, render
#                           only the n portion and blank-pad the
#                           parenthesised tail. Galley + aligngen
#                           both do this.
#        DOMINANT        -> full slot-by-slot assembly.
#        PRIMARY-ONLY    -> non-dominant signature; align slot 1,
#                           concatenate raw remainder.
#
#   7. NORMALISE — every rendered string is right-padded with the
#      configured `pad` character to the column-wide max nchar, so
#      the column reads as a uniform block.
#
#   8. EDGE-TRIM — if every non-NA cell starts (or ends) with the
#      pad character, strip one column-wide. Iterate until at least
#      one cell has a non-pad edge. Removes phantom-padding
#      artifacts.
#
# Output is a character vector of the same length as the input. The
# pad character defaults to U+00A0 NBSP at the public API so the
# spacing survives proportional-font RTF / HTML / DOCX cells; the
# internal workhorse accepts an explicit `pad = " "` for ASCII
# debugging. The character-count alignment is the canonical
# invariant; backends translate the pad runs to font-metric padding
# (RTF dec-tabs, LaTeX \phantom, HTML width-set spans) at emit time.

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------

# A float token: optional comparator prefix (< > =), optional sign,
# one or more digits, optional fractional part. Perl regex so the
# non-capturing groups parse cleanly.
.float_token_re <- "(?:[<>=]?)(?:-?)\\d+(?:\\.\\d+)?"

# Capturing version for parsing one token into components. Group 1
# is the comparator prefix; group 2 is the sign; group 3 is the
# integer part; group 4 is the optional decimal part.
.float_parse_re <- "^([<>=]?)(-?)(\\d+)(?:\\.(\\d+))?$"

# Default pad character for the public API: Unicode NBSP (U+00A0).
# Survives RTF / HTML / DOCX cell rendering where ASCII space gets
# collapsed by the proportional-font layout. The internal pipeline
# accepts an explicit `pad` arg so callers (and tests) can swap in
# ASCII space for terminal-friendly output.
.nbsp <- "\u00a0"

# ---------------------------------------------------------------------
# Public entry — engine_decimal
# ---------------------------------------------------------------------

#' Apply decimal-mark alignment to columns flagged `align = "decimal"`
#'
#' Pure function. Called by the resolve engine after `engine_format()`
#' (so cells are already formatted to character) and before backend
#' emission. Returns the cell matrix with decimal-aligned columns
#' replaced by their column-aligned versions.
#'
#' @param cells_text A character matrix of formatted cell strings
#'   (one row per data row, one column per data column). Column
#'   names must match the names in `cols`.
#' @param cols A named list of `col_spec` objects, keyed by data
#'   column name. Columns whose `col_spec@align` is `"decimal"` are
#'   re-rendered; other columns pass through unchanged.
#' @param sections Optional length-`nrow(cells_text)` vector
#'   identifying the row group each row belongs to. Slot-1 sign+int
#'   width is still computed column-wide so the leftmost integer
#'   column aligns across sections; everything to its right (slot-1
#'   decimal portion and slots 2..K) is computed inside each section.
#'   `NULL` (default) means the entire column is one section.
#' @param not_considered Character vector of opaque tokens. Cells
#'   whose trimmed value matches any entry bypass alignment and
#'   contribute no slot widths. Use for clinical missing markers
#'   like `c("NR", "BLQ", "NE", "--")`.
#' @param pad Single-character padding string used between slot
#'   components and at the column-wide right-pad. Defaults to U+00A0
#'   non-breaking space so the spacing survives proportional-font
#'   rendering. Pass `" "` for terminal-friendly ASCII output.
#' @param zero_suppress When `TRUE` (default), cells whose primary
#'   float parses to integer 0 in an n_pct-style shape render only
#'   the n portion blank-padded to the dominant width.
#' @param edge_trim When `TRUE` (default), strip column-wide leading
#'   or trailing pad characters that every cell shares, until at
#'   least one cell has a non-pad edge.
#' @return A character matrix with `nrow(cells_text)` rows and
#'   `ncol(cells_text)` columns. Same dimensions, dimnames preserved.
#' @keywords internal
#' @noRd
engine_decimal <- function(
  cells_text,
  cols,
  sections = NULL,
  not_considered = character(),
  pad = .nbsp,
  zero_suppress = TRUE,
  edge_trim = TRUE
) {
  col_names <- colnames(cells_text)
  for (nm in col_names) {
    cs <- cols[[nm]]
    if (!is_col_spec(cs)) {
      next
    }
    if (!isTRUE(cs@align == "decimal")) {
      next
    }
    cells_text[, nm] <- .align_decimal_column(
      cells_text[, nm],
      sections = sections,
      not_considered = not_considered,
      pad = pad,
      zero_suppress = zero_suppress,
      edge_trim = edge_trim
    )
  }
  cells_text
}

# ---------------------------------------------------------------------
# Per-column workhorse
# ---------------------------------------------------------------------

# Align one column of pre-formatted strings on the decimal mark.
#
# Pure function. Takes a character vector, returns a character vector
# of the same length with embedded `pad` padding so the leftmost
# decimal mark is at the same column position in every cell, and
# cells of matching signature are fully slot-aligned. Cells with no
# numeric content (or matching `not_considered`) are right-padded
# to the column width with raw text preserved.
#
# NA values pass through as NA (no alignment work). Caller is
# responsible for substituting NA with the desired display token
# before invoking this; we still guard against accidental NA
# passage.
#
# `sections` is an optional length-n vector identifying the row
# group each row belongs to. When provided:
#   * slot-1 sign+int width and comparator-prefix width are
#     computed COLUMN-WIDE (across all sections) so the leftmost
#     integer column aligns page-wide;
#   * every other slot width (slot-1 dec_w / has_dec, slots 2..K)
#     is computed INSIDE each section independently.
# When `sections = NULL` the entire column is one section.
.align_decimal_column <- function(
  values,
  sections = NULL,
  not_considered = character(),
  pad = " ",
  zero_suppress = TRUE,
  edge_trim = TRUE
) {
  n <- length(values)
  if (n == 0L) {
    return(values)
  }

  # Preserve NA positions; they round-trip unchanged.
  na_mask <- is.na(values)

  # Normalise: trim outer whitespace before tokenising.
  v <- character(n)
  v[!na_mask] <- trimws(values[!na_mask], which = "both")

  # Identify opaque cells — those whose trimmed value matches any
  # token in `not_considered`. Opaque cells bypass alignment and do
  # not contribute to any slot width.
  opaque_mask <- logical(n)
  if (length(not_considered) > 0L) {
    opaque_mask[!na_mask] <- v[!na_mask] %in% not_considered
  }

  # Compute the column-wide slot-1 floor across every non-NA,
  # non-opaque cell. Only needed in sections-mode; in single-section
  # mode the section's own slot-1 widths already span the column.
  column_floor <- NULL
  if (!is.null(sections)) {
    if (length(sections) != n) {
      cli::cli_abort(
        c(
          "{.arg sections} must be the same length as {.arg values}.",
          "x" = "Got length {length(sections)}, expected {n}."
        ),
        class = "tabular_error_input"
      )
    }
    contrib <- which(!na_mask & !opaque_mask)
    if (length(contrib) > 0L) {
      column_floor <- .compute_column_floor(v[contrib])
    }
  }

  out <- character(n)
  out[na_mask] <- NA_character_

  if (is.null(sections)) {
    out <- .render_section(
      v = v,
      na_mask = na_mask,
      opaque_mask = opaque_mask,
      column_floor = NULL,
      pad = pad,
      zero_suppress = zero_suppress
    )
  } else {
    sec_ids <- .runs(sections)
    for (sid in unique(sec_ids)) {
      idx <- which(sec_ids == sid)
      keep <- idx[!na_mask[idx]]
      if (length(keep) == 0L) {
        next
      }
      rendered <- .render_section(
        v = v[keep],
        na_mask = rep(FALSE, length(keep)),
        opaque_mask = opaque_mask[keep],
        column_floor = column_floor,
        pad = pad,
        zero_suppress = zero_suppress
      )
      out[keep] <- rendered
    }
  }

  # Final pass: right-pad every non-NA cell to the column max nchar.
  if (any(!na_mask)) {
    max_w <- max(nchar(out[!na_mask], type = "chars"))
    out[!na_mask] <- .pad_right(out[!na_mask], max_w, pad = pad)
  }

  # Symmetric edge-trim: strip column-wide leading / trailing pad
  # characters that every cell shares.
  if (edge_trim) {
    out <- .trim_symmetric(out, pad = pad)
  }

  out
}

# Render one section: tokenise, pick dominant, compute slot widths,
# render every cell. Assumes `v` is already trimmed.
#
# Opaque cells (those with `opaque_mask[i] == TRUE`) are skipped
# during tokenisation and rendered as their raw `v[i]` value.
.render_section <- function(
  v,
  na_mask,
  opaque_mask,
  column_floor,
  pad,
  zero_suppress
) {
  n <- length(v)
  out <- character(n)
  out[na_mask] <- NA_character_

  active <- which(!na_mask)
  if (length(active) == 0L) {
    return(out)
  }

  # Tokenise non-opaque cells; opaque cells get a dummy "0 floats"
  # token so they bypass slot-width contribution and the render
  # path returns their raw text.
  tokens <- vector("list", length(active))
  for (k in seq_along(active)) {
    i <- active[[k]]
    if (opaque_mask[[i]]) {
      tokens[[k]] <- list(
        floats = character(),
        literals = v[[i]],
        parsed = list()
      )
    } else {
      tokens[[k]] <- .tokenize_cell(v[[i]])
    }
  }

  sigs <- vapply(tokens, .signature_key, character(1))
  dominant <- .pick_dominant(sigs, tokens)
  widths <- .compute_widths(tokens, dominant, column_floor = column_floor)

  for (k in seq_along(active)) {
    out[[active[[k]]]] <- .render_cell(
      tok = tokens[[k]],
      sig_key = sigs[[k]],
      dominant = dominant,
      widths = widths,
      pad = pad,
      zero_suppress = zero_suppress
    )
  }
  out
}

# Run-length encoder: returns a length-n integer vector where each
# entry identifies the run of identical adjacent values containing
# that row. `c("A","A","B","A")` -> `c(1, 1, 2, 3)`.
# Caller (`.align_decimal_column`) early-returns on length-0 input,
# so `x` always has at least one element here.
.runs <- function(x) {
  changed <- c(
    TRUE,
    x[-1L] != x[-length(x)] | is.na(x[-1L]) != is.na(x[-length(x)])
  )
  cumsum(changed)
}

# ---------------------------------------------------------------------
# Column floor (page-wide slot 1 widths)
# ---------------------------------------------------------------------

# Compute the column-wide slot-1 floor across every contributing
# (non-NA, non-opaque) cell. Returns a list with:
#   int_w    : max nchar(sign + int) of the FIRST float token
#   prefix_w : max nchar(comparator prefix) of the FIRST float token
# Returns NULL if no cell has any float token.
.compute_column_floor <- function(values) {
  int_w <- 0L
  prefix_w <- 0L
  any_float <- FALSE
  for (val in values) {
    tok <- .tokenize_cell(val)
    if (length(tok$floats) == 0L) {
      next
    }
    any_float <- TRUE
    p <- tok$parsed[[1L]]
    prefix_w <- max(prefix_w, nchar(p$prefix, type = "chars"))
    int_w <- max(
      int_w,
      nchar(p$sign, type = "chars") + nchar(p$int, type = "chars")
    )
  }
  if (!any_float) {
    return(NULL)
  }
  list(int_w = int_w, prefix_w = prefix_w)
}

# ---------------------------------------------------------------------
# Tokenisation
# ---------------------------------------------------------------------

# Decompose one cell string into a sequence of float tokens and the
# literal segments between / around them. Returns a list with:
#
#   floats   : character vector, length K (K >= 0). Each element is
#              one float token (matching `.float_token_re`).
#   literals : character vector, length K + 1. Element i is the
#              literal text BEFORE float i (literals[[1]] is the
#              leading literal; literals[[K + 1]] is the trailing
#              literal).
#   parsed   : list of K named lists with (prefix, sign, int, dec)
#              components per float token.
.tokenize_cell <- function(text) {
  if (!nzchar(text)) {
    return(list(
      floats = character(),
      literals = "",
      parsed = list()
    ))
  }

  m <- gregexpr(.float_token_re, text, perl = TRUE)[[1L]]
  starts <- as.integer(m)
  if (length(starts) == 1L && starts[[1L]] == -1L) {
    return(list(
      floats = character(),
      literals = text,
      parsed = list()
    ))
  }

  lengths <- attr(m, "match.length")
  ends <- starts + lengths - 1L
  k <- length(starts)

  floats <- substring(text, starts, ends)
  literals <- character(k + 1L)
  prev_end <- 0L
  for (i in seq_len(k)) {
    literals[[i]] <- substring(text, prev_end + 1L, starts[[i]] - 1L)
    prev_end <- ends[[i]]
  }
  literals[[k + 1L]] <- substring(text, prev_end + 1L, nchar(text))

  parsed <- lapply(floats, .parse_float_token)

  list(
    floats = floats,
    literals = literals,
    parsed = parsed
  )
}

# Parse one float token into a named list of components. Caller
# (`.tokenize_cell`) guarantees `token` matched the same regex
# already, so `regmatches()` returns the full capture group set.
.parse_float_token <- function(token) {
  m <- regmatches(token, regexec(.float_parse_re, token))[[1L]]
  list(
    prefix = m[[2L]],
    sign = m[[3L]],
    int = m[[4L]],
    dec = if (length(m) >= 5L) m[[5L]] else ""
  )
}

# ---------------------------------------------------------------------
# Signature + dominance
# ---------------------------------------------------------------------

# Compute a stable string key for one cell's signature. Two cells
# share a signature iff they have the same float count AND identical
# literal segments. Cells with no floats share the signature "0|".
.signature_key <- function(tok) {
  k <- length(tok$floats)
  if (k == 0L) {
    return("0|")
  }
  paste0(k, "|", paste(tok$literals, collapse = "\x1f"))
}

# Pick the dominant signature for a section. Tie-break order:
#   1. highest float count
#   2. highest row count among ties
#   3. earliest first-appearance
# Returns a list with the dominant signature's key, k (float count),
# and literals vector. Returns NULL when the section has no numeric
# cells.
.pick_dominant <- function(sigs, tokens) {
  uniq <- unique(sigs)
  if (identical(uniq, "0|")) {
    return(NULL)
  }

  first_idx <- match(uniq, sigs)
  k_per_sig <- vapply(
    uniq,
    function(s) as.integer(sub("\\|.*$", "", s)),
    integer(1L)
  )
  count_per_sig <- vapply(uniq, function(s) sum(sigs == s), integer(1L))

  has_floats <- k_per_sig > 0L
  uniq <- uniq[has_floats]
  first_idx <- first_idx[has_floats]
  k_per_sig <- k_per_sig[has_floats]
  count_per_sig <- count_per_sig[has_floats]

  ord <- order(-k_per_sig, -count_per_sig, first_idx)
  dom_key <- uniq[[ord[[1L]]]]
  dom_idx <- first_idx[[ord[[1L]]]]
  dom_tok <- tokens[[dom_idx]]

  list(
    key = dom_key,
    k = length(dom_tok$floats),
    literals = dom_tok$literals
  )
}

# ---------------------------------------------------------------------
# Slot widths
# ---------------------------------------------------------------------

# Compute per-slot widths in the dominant layout. Returns a list
# with named integer vectors:
#
#   int_w[k]    width of the (sign + int) span at slot k.
#   has_dec[k]  TRUE if any cell has a non-empty dec at slot k.
#   dec_w[k]    max width of the dec span at slot k (0 if none).
#   prefix_w[k] width of the comparator-prefix span at slot k.
#
# When `column_floor` is non-NULL, slot 1's `int_w` and `prefix_w`
# are floored by the column-wide values, so the leftmost integer
# column aligns across all sections in the column.
#
# When no dominant signature exists (section is text-only), returns
# NULL.
.compute_widths <- function(tokens, dominant, column_floor = NULL) {
  if (is.null(dominant)) {
    return(NULL)
  }

  k_dom <- dominant$k
  int_w <- integer(k_dom)
  dec_w <- integer(k_dom)
  has_dec <- logical(k_dom)
  prefix_w <- integer(k_dom)

  for (i in seq_along(tokens)) {
    tok <- tokens[[i]]
    if (length(tok$floats) == 0L) {
      next
    }
    sig_key_i <- .signature_key(tok)
    is_dom_i <- identical(sig_key_i, dominant$key)
    # A non-dominant row only contributes to slot 1 widths; slots 2+
    # would distort the dominant layout because the row's slot-k
    # context (preceding literal, sibling literals) differs from
    # dominant's.
    k_contrib <- if (is_dom_i) length(tok$floats) else 1L
    k_contrib <- min(k_contrib, k_dom)
    for (k in seq_len(k_contrib)) {
      p <- tok$parsed[[k]]
      prefix_w[[k]] <- max(prefix_w[[k]], nchar(p$prefix, type = "chars"))
      int_w[[k]] <- max(
        int_w[[k]],
        nchar(p$sign, type = "chars") + nchar(p$int, type = "chars")
      )
      if (nzchar(p$dec)) {
        has_dec[[k]] <- TRUE
        dec_w[[k]] <- max(dec_w[[k]], nchar(p$dec, type = "chars"))
      }
    }
  }

  # Apply the column-wide floor for slot 1 only.
  if (!is.null(column_floor) && k_dom >= 1L) {
    int_w[[1L]] <- max(int_w[[1L]], column_floor$int_w)
    prefix_w[[1L]] <- max(prefix_w[[1L]], column_floor$prefix_w)
  }

  list(
    int_w = int_w,
    dec_w = dec_w,
    has_dec = has_dec,
    prefix_w = prefix_w
  )
}

# Compute the raw remainder text AFTER the cell's first float. For a
# cell with K floats, this is literals[[2]] followed by floats[[2]]
# followed by literals[[3]] ... up to literals[[K + 1]]. For a cell
# with K == 1, returns literals[[2]] alone. Caller guarantees k >= 1.
.raw_remainder_after_first_float <- function(tok) {
  k <- length(tok$floats)
  if (k == 1L) {
    return(tok$literals[[2L]])
  }
  parts <- character(2L * k - 1L)
  parts[[1L]] <- tok$literals[[2L]]
  for (j in seq.int(2L, k)) {
    parts[[2L * (j - 1L)]] <- tok$floats[[j]]
    parts[[2L * (j - 1L) + 1L]] <- tok$literals[[j + 1L]]
  }
  paste0(parts, collapse = "")
}

# ---------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------

# Render one cell. Branches:
#   no floats             -> raw text (will be right-padded later)
#   zero-suppressed n_pct -> n portion + blank-padded tail
#   dominant signature    -> full structured assembly
#   else (>=1 float)      -> primary-only with raw remainder
.render_cell <- function(
  tok,
  sig_key,
  dominant,
  widths,
  pad,
  zero_suppress
) {
  k_row <- length(tok$floats)

  if (k_row == 0L) {
    return(tok$literals[[1L]])
  }

  is_dominant <- identical(sig_key, dominant$key)

  if (
    zero_suppress &&
      is_dominant &&
      .is_n_pct_shape(dominant) &&
      .is_zero_n(tok$parsed[[1L]])
  ) {
    return(.render_cell_zero_suppress(tok, dominant, widths, pad))
  }

  if (is_dominant) {
    return(.render_cell_dominant(tok, dominant, widths, pad))
  }

  .render_cell_primary_only(tok, dominant, widths, pad)
}

# Detect "n (pct)" / "n (pct, lo, hi)" / "n/N (pct)" family shapes:
# the dominant signature has at least 2 floats, literals[[2]]
# contains "(" (possibly with whitespace or "/" prefix), and
# literals[[K+1]] contains ")". This is the family galley +
# aligngen zero-suppress.
.is_n_pct_shape <- function(dominant) {
  k <- dominant$k
  if (k < 2L) {
    return(FALSE)
  }
  open_lit <- dominant$literals[[2L]]
  close_lit <- dominant$literals[[k + 1L]]
  grepl("(", open_lit, fixed = TRUE) &&
    grepl(")", close_lit, fixed = TRUE)
}

# Detect "this float represents an integer zero": sign is empty, int
# is "0" (or repeated zeros), dec is empty or all zeros. Matches
# galley / aligngen zero-suppression semantics.
.is_zero_n <- function(parsed) {
  if (nzchar(parsed$prefix) || nzchar(parsed$sign)) {
    return(FALSE)
  }
  int_is_zero <- nzchar(parsed$int) && !grepl("[^0]", parsed$int)
  dec_is_zero <- !nzchar(parsed$dec) || !grepl("[^0]", parsed$dec)
  int_is_zero && dec_is_zero
}

# Full structured render — cell matches the dominant signature.
.render_cell_dominant <- function(tok, dominant, widths, pad) {
  k <- dominant$k
  parts <- character(2L * k + 1L)
  parts[[1L]] <- dominant$literals[[1L]]
  for (j in seq_len(k)) {
    p <- tok$parsed[[j]]
    parts[[2L * j]] <- .render_slot(
      prefix = p$prefix,
      sign = p$sign,
      int = p$int,
      dec = p$dec,
      prefix_w = widths$prefix_w[[j]],
      int_w = widths$int_w[[j]],
      has_dec = widths$has_dec[[j]],
      dec_w = widths$dec_w[[j]],
      pad = pad
    )
    parts[[2L * j + 1L]] <- dominant$literals[[j + 1L]]
  }
  paste0(parts, collapse = "")
}

# Zero-suppress render: emit the n slot, then blank-pad the rest of
# the line to the dominant width using `pad`. Result has the same
# nchar as a full dominant render, so column-width invariants hold.
.render_cell_zero_suppress <- function(tok, dominant, widths, pad) {
  k <- dominant$k
  p <- tok$parsed[[1L]]
  n_slot <- .render_slot(
    prefix = p$prefix,
    sign = p$sign,
    int = p$int,
    dec = p$dec,
    prefix_w = widths$prefix_w[[1L]],
    int_w = widths$int_w[[1L]],
    has_dec = widths$has_dec[[1L]],
    dec_w = widths$dec_w[[1L]],
    pad = pad
  )
  # Width of the dominant render's post-slot-1 portion:
  # literals[2..k+1] + slots[2..k].
  remaining_w <- 0L
  for (j in seq.int(2L, k)) {
    remaining_w <- remaining_w +
      nchar(dominant$literals[[j]], type = "chars") +
      widths$prefix_w[[j]] +
      widths$int_w[[j]] +
      (if (widths$has_dec[[j]]) 1L + widths$dec_w[[j]] else 0L)
  }
  remaining_w <- remaining_w +
    nchar(dominant$literals[[k + 1L]], type = "chars")
  paste0(
    dominant$literals[[1L]],
    n_slot,
    strrep(pad, max(0L, remaining_w))
  )
}

# Slot-1-only render — cell has at least one float but does not
# match the dominant signature. The cell's OWN leading literal is
# preserved so opening syntax (e.g. the "(" of "(0.3, 8.1)" when
# mixed with a dominant "13 (45.0)") survives intact. Using the
# dominant's literal here would silently drop the cell's leading
# punctuation — a correctness bug, since content beats alignment
# when the cell has a structurally different shape.
.render_cell_primary_only <- function(tok, dominant, widths, pad) {
  p <- tok$parsed[[1L]]
  rendered_slot <- .render_slot(
    prefix = p$prefix,
    sign = p$sign,
    int = p$int,
    dec = p$dec,
    prefix_w = widths$prefix_w[[1L]],
    int_w = widths$int_w[[1L]],
    has_dec = widths$has_dec[[1L]],
    dec_w = widths$dec_w[[1L]],
    pad = pad
  )
  paste0(
    tok$literals[[1L]],
    rendered_slot,
    .raw_remainder_after_first_float(tok)
  )
}

# Render one slot: [pad-left(prefix, prefix_w)] + [pad-left(sign+int,
# int_w)] + [dot or pad, only if column has decimals at this slot] +
# [pad-right(dec, dec_w)].
.render_slot <- function(
  prefix,
  sign,
  int,
  dec,
  prefix_w,
  int_w,
  has_dec,
  dec_w,
  pad
) {
  si_str <- paste0(sign, int)
  si_padded <- .pad_left(si_str, int_w, pad = pad)
  pre_padded <- .pad_left(prefix, prefix_w, pad = pad)

  if (has_dec) {
    if (nzchar(dec)) {
      dec_padded <- .pad_right(dec, dec_w, pad = pad)
      paste0(pre_padded, si_padded, ".", dec_padded)
    } else {
      paste0(pre_padded, si_padded, pad, strrep(pad, dec_w))
    }
  } else {
    paste0(pre_padded, si_padded)
  }
}

# ---------------------------------------------------------------------
# Padding helpers
# ---------------------------------------------------------------------

# Left-pad `x` to `width` characters using `pad`. Shorter values are
# padded; longer values pass through unchanged. UTF-8 safe via
# `nchar(x, type = "chars")`.
.pad_left <- function(x, width, pad = " ") {
  if (width <= 0L) {
    return(x)
  }
  n <- nchar(x, type = "chars")
  need <- pmax(0L, width - n)
  paste0(vapply(need, function(k) strrep(pad, k), character(1L)), x)
}

# Right-pad `x` to `width` characters using `pad`. Shorter values
# are padded; longer values pass through unchanged.
.pad_right <- function(x, width, pad = " ") {
  if (width <= 0L) {
    return(x)
  }
  n <- nchar(x, type = "chars")
  need <- pmax(0L, width - n)
  paste0(x, vapply(need, function(k) strrep(pad, k), character(1L)))
}

# ---------------------------------------------------------------------
# Symmetric edge-trim
# ---------------------------------------------------------------------

# If every non-NA cell starts with `pad`, strip ONE column-wide.
# Symmetric for trailing. Conservative single-strip per side to
# match aligngen.sas's allign_chk1 / allign_chk2 post-process
# (lines 1462-1480 of `aligngen.sas`). Caps at "do not shrink any
# cell below 1 character" so a NA-only / single-cell-of-pad column
# passes through.
.trim_symmetric <- function(out, pad) {
  active <- !is.na(out)
  if (!any(active)) {
    return(out)
  }
  pad_n <- nchar(pad, type = "chars")
  if (pad_n != 1L) {
    return(out)
  }

  cur <- out[active]
  n <- nchar(cur, type = "chars")
  # Don't strip anything if any row would shrink below 1 char.
  if (any(n <= 1L)) {
    return(out)
  }

  # Left strip: if every cell's first char is pad, drop it.
  leads <- substr(cur, 1L, 1L)
  if (all(leads == pad)) {
    cur <- substr(cur, 2L, n)
    n <- n - 1L
  }

  if (any(n <= 1L)) {
    out[active] <- cur
    return(out)
  }

  # Right strip: if every cell's last char is pad, drop it.
  trails <- substr(cur, n, n)
  if (all(trails == pad)) {
    cur <- substr(cur, 1L, n - 1L)
  }

  out[active] <- cur
  out
}
