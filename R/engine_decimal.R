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
#   Galley's decimal engine had cross-shape alignment bugs: standalone
#   integer rows (the "n =" row at the top of a stats block, the
#   denominator-only row at the top of an n (%) block) sat at the
#   wrong column position, breaking visual scan. The fix is to treat
#   the entire column as one alignment unit with a uniform "primary
#   anchor" (the leftmost float's decimal mark, including the
#   "implicit decimal" of integer-only rows).
#
# Design (one-pass, two-tier alignment):
#
#   1. TOKENIZE — each cell decomposes into:
#        floats   : an ordered character vector of float tokens
#                   matching [<>=]?-?\d+(\.\d+)?  (one or more)
#        literals : K+1 fixed-string segments between/around the floats
#      A cell with no floats (e.g., "Yes", "Total", "") yields
#      floats = character(), literals = c(text).
#
#   2. SIGNATURE — each cell's signature is (n_floats, literals). The
#      column's DOMINANT signature is the signature with:
#        a. the highest float count, then
#        b. the highest row count among signatures tied at (a), then
#        c. the first-appearance among signatures tied at (a, b).
#      The dominant signature drives the canonical layout: its
#      literals are the column's canonical literals; its float count
#      sets the number of aligned slots.
#
#   3. WIDTHS — per slot k = 1..K_dominant, compute:
#        int_w[k]    : max nchar(sign+int) across ALL cells whose own
#                      slot-k float exists.
#        has_dec[k]  : any cell has a non-empty decimal at slot k.
#        dec_w[k]    : max nchar(dec) across cells with non-empty dec
#                      at slot k.
#      Including non-dominant cells in the width computation lets
#      e.g. an integer N=86 row contribute to int_w[1] alongside the
#      float rows. tail_w is computed as max nchar of the post-
#      primary-float remainder, including all signatures.
#
#   4. RENDER — for each cell:
#        - DOMINANT signature  -> full slot-by-slot assembly using
#          all K_dom slots, padding within each slot.
#        - OTHER signature with >= 1 float -> align slot 1 (primary
#          decimal anchor) to the column's slot-1 widths, then
#          concatenate the raw remainder. The remainder is padded
#          on the right to the column's remainder-width.
#        - NO floats -> right-pad the raw cell to the column width.
#
#   5. NORMALISE — every rendered string is right-padded with spaces
#      to the column's full width, so the column reads as a uniform
#      block in monospace.
#
# Output is a character vector of the same length as the input, with
# every string aligned for monospace rendering. Backends that emit to
# proportional fonts (HTML, LaTeX) convert the literal-space padding
# to font-metric padding using the active preset's
# `decimal_metrics` knob — but the canonical column-level alignment
# is the monospace string. The character-count alignment is a
# necessary condition for the metric-based alignment to look right
# at every body font size, since the rebuilt string has visually
# consistent decimal positions even before metric scaling.

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------

# A float token: optional comparator prefix (< > =), optional sign,
# one or more digits, optional fractional part. Perl regex so the
# non-capturing groups parse cleanly.
.float_token_re <- "(?:[<>=]?)(?:-?)\\d+(?:\\.\\d+)?"

# Capturing version for parsing one token into components. Group 1 is
# the comparator prefix; group 2 is the sign; group 3 is the integer
# part; group 4 is the optional decimal part.
.float_parse_re <- "^([<>=]?)(-?)(\\d+)(?:\\.(\\d+))?$"

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
#' @param sections Optional length-`nrow(cells_text)` vector identifying
#'   the row group each row belongs to. Within each section the
#'   decimal-alignment widths are computed independently, so a stats
#'   section (integer N + float Mean / SD) and an n_pct section in the
#'   same arm column don't pollute each other's slot widths.
#'   `NULL` (default) means the entire column is one section.
#'   Typically derived from the `usage="group"` row-label column's
#'   run-length encoding by the caller.
#' @return A character matrix with `nrow(cells_text)` rows and
#'   `ncol(cells_text)` columns. Same dimensions, dimnames preserved.
#' @keywords internal
#' @noRd
engine_decimal <- function(cells_text, cols, sections = NULL) {
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
      sections = sections
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
# of the same length with embedded space padding so the leftmost
# decimal mark is at the same column position in every cell, and
# cells of matching signature are fully slot-aligned. Cells with no
# numeric content are right-padded to the column width.
#
# NA values pass through as NA (no alignment work). The caller
# (engine_format) is responsible for substituting NA with na_text
# before invoking this; we still guard against accidental NA passage.
#
# `sections` is an optional length-n vector identifying the row group
# each row belongs to. When provided, rows in different sections do
# not share slot widths -- "Age (years)" stats rows compute their own
# int_w / dec_w, "Age Group, n (%)" rows compute their own, etc. This
# matches the clinical-table convention where each `variable` block
# is its own alignment unit. When `sections = NULL` the entire column
# is treated as one section (the v0.1.0 default).
#
# After per-section rendering, every non-NA row is right-padded to
# the column-wide max nchar so the final output is a uniform block.
.align_decimal_column <- function(values, sections = NULL) {
  n <- length(values)
  if (n == 0L) {
    return(values)
  }

  # Preserve NA positions; they round-trip unchanged.
  na_mask <- is.na(values)

  # Normalise: trim outer whitespace before tokenising.
  v <- character(n)
  v[!na_mask] <- trimws(values[!na_mask], which = "both")

  if (is.null(sections)) {
    out <- .render_section(v, na_mask)
  } else {
    if (length(sections) != n) {
      cli::cli_abort(
        c(
          "{.arg sections} must be the same length as {.arg values}.",
          "x" = "Got length {length(sections)}, expected {n}."
        ),
        class = "tabular_error_input"
      )
    }
    # Use rleid-style grouping: consecutive identical section values
    # form a section. This preserves row order without needing the
    # caller to pre-sort.
    sec_ids <- .runs(sections)
    out <- character(n)
    out[na_mask] <- NA_character_
    for (sid in unique(sec_ids)) {
      idx <- which(sec_ids == sid)
      keep <- idx[!na_mask[idx]]
      if (length(keep) == 0L) {
        next
      }
      out[keep] <- .render_section(v[keep], rep(FALSE, length(keep)))
    }
  }

  # Final pass: right-pad every non-NA cell to the same width so the
  # column reads as a clean block.
  if (any(!na_mask)) {
    max_w <- max(nchar(out[!na_mask]))
    out[!na_mask] <- .pad_right(out[!na_mask], max_w)
  }

  out
}

# Render one section: tokenise, pick dominant, compute slot widths,
# render every cell. Assumes `v` is already trimmed and NA-stripped
# (any NA positions are passed via `na_mask` and bypassed).
.render_section <- function(v, na_mask) {
  n <- length(v)
  out <- character(n)

  active <- which(!na_mask)
  if (length(active) == 0L) {
    out[na_mask] <- NA_character_
    return(out)
  }

  tokens <- lapply(v[active], .tokenize_cell)
  sigs <- vapply(tokens, .signature_key, character(1))
  dominant <- .pick_dominant(sigs, tokens)
  widths <- .compute_widths(tokens, dominant)

  for (k in seq_along(active)) {
    out[[active[[k]]]] <- .render_cell(
      tok = tokens[[k]],
      sig_key = sigs[[k]],
      dominant = dominant,
      widths = widths
    )
  }
  out[na_mask] <- NA_character_
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
#              components per float token. Convenience cache so the
#              render path doesn't reparse.
#
# An empty / whitespace-trimmed string yields floats = character()
# and literals = "" (length 1, blank).
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
# literal segments. The key encodes float-count and the literal
# vector joined by a control-character separator (so no clinical text
# can collide). Cells with no floats share the signature "0|".
.signature_key <- function(tok) {
  k <- length(tok$floats)
  if (k == 0L) {
    return("0|")
  }
  paste0(k, "|", paste(tok$literals, collapse = "\x1f"))
}

# Pick the dominant signature for the column. Tie-break order:
#   1. highest float count
#   2. highest row count among ties
#   3. earliest first-appearance
# Returns a list with the dominant signature's key, k (float count),
# and literals vector. Returns NULL when the column has no numeric
# cells at all (signature is "0|" universally).
.pick_dominant <- function(sigs, tokens) {
  # Counts per signature.
  uniq <- unique(sigs)
  if (identical(uniq, "0|")) {
    return(NULL)
  }

  # First-appearance index per signature (for stable tie-break).
  first_idx <- match(uniq, sigs)

  # Float count per signature key (derived from key prefix before "|").
  k_per_sig <- vapply(
    uniq,
    function(s) as.integer(sub("\\|.*$", "", s)),
    integer(1L)
  )

  # Row count per signature.
  count_per_sig <- vapply(uniq, function(s) sum(sigs == s), integer(1L))

  # Drop the empty signature (no floats) from dominance consideration —
  # a column of mostly text with one number row should still anchor on
  # that number row. After the `identical(uniq, "0|")` early-return
  # above, `uniq` contains at least one non-empty signature, so at
  # least one entry in `has_floats` is TRUE.
  has_floats <- k_per_sig > 0L
  uniq <- uniq[has_floats]
  first_idx <- first_idx[has_floats]
  k_per_sig <- k_per_sig[has_floats]
  count_per_sig <- count_per_sig[has_floats]

  # Order by (k desc, count desc, first_idx asc).
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
#                 (Almost always 0 unless slot k holds p-values.)
#
# When no dominant signature exists (column is text-only), returns
# NULL. The final right-pad in `.align_decimal_column` brings every
# rendered cell to the column-wide max width, so no explicit tail
# width is tracked here — the natural width of the dominant render
# is what every other cell pads up to.
.compute_widths <- function(tokens, dominant) {
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
      prefix_w[[k]] <- max(prefix_w[[k]], nchar(p$prefix))
      int_w[[k]] <- max(int_w[[k]], nchar(p$sign) + nchar(p$int))
      if (nzchar(p$dec)) {
        has_dec[[k]] <- TRUE
        dec_w[[k]] <- max(dec_w[[k]], nchar(p$dec))
      }
    }
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

# Render one cell. Branches on whether the cell shares the dominant
# signature; non-dominant cells get the slot-1-only render path.
# When `dominant` is NULL the column has no numeric cells, in which
# case every cell hits the no-floats short-circuit (dominant being
# NULL implies every cell carries `floats = character()`).
.render_cell <- function(tok, sig_key, dominant, widths) {
  k_row <- length(tok$floats)

  # No floats at all -> right-pad raw text to the column width.
  if (k_row == 0L) {
    return(tok$literals[[1L]])
  }

  if (identical(sig_key, dominant$key)) {
    return(.render_cell_dominant(tok, dominant, widths))
  }

  .render_cell_primary_only(tok, dominant, widths)
}

# Full structured render — cell matches the dominant signature. Walks
# literal[1] -> slot[1] -> literal[2] -> slot[2] -> ... -> literal[K+1].
.render_cell_dominant <- function(tok, dominant, widths) {
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
      dec_w = widths$dec_w[[j]]
    )
    parts[[2L * j + 1L]] <- dominant$literals[[j + 1L]]
  }
  paste0(parts, collapse = "")
}

# Slot-1-only render — cell has at least one float but does not match
# the dominant signature. Align slot 1 to the column's slot-1 widths,
# then concatenate the cell's raw remainder. The trailing right-pad
# in `.align_decimal_column` brings every cell to the same width.
.render_cell_primary_only <- function(tok, dominant, widths) {
  p <- tok$parsed[[1L]]
  rendered_slot <- .render_slot(
    prefix = p$prefix,
    sign = p$sign,
    int = p$int,
    dec = p$dec,
    prefix_w = widths$prefix_w[[1L]],
    int_w = widths$int_w[[1L]],
    has_dec = widths$has_dec[[1L]],
    dec_w = widths$dec_w[[1L]]
  )
  paste0(
    dominant$literals[[1L]],
    rendered_slot,
    .raw_remainder_after_first_float(tok)
  )
}

# Render one slot: [pad-left(prefix+sign+int, prefix_w + int_w)] +
# [dot or space, only if column has decimals at this slot] +
# [pad-right(dec, dec_w)].
#
# When the slot has decimals in the column but this cell has no own
# dec, the dot position is filled with a space so the implicit
# decimal of an integer-only cell ("86") sits at the same column as
# the explicit decimal of a float cell ("147.8").
.render_slot <- function(
  prefix,
  sign,
  int,
  dec,
  prefix_w,
  int_w,
  has_dec,
  dec_w
) {
  # Combined sign+int span, left-padded to int_w.
  si_str <- paste0(sign, int)
  si_padded <- .pad_left(si_str, int_w)

  # Prefix (comparator) padded separately to keep p-values aligned.
  pre_padded <- .pad_left(prefix, prefix_w)

  if (has_dec) {
    if (nzchar(dec)) {
      dec_padded <- .pad_right(dec, dec_w)
      paste0(pre_padded, si_padded, ".", dec_padded)
    } else {
      paste0(pre_padded, si_padded, " ", strrep(" ", dec_w))
    }
  } else {
    paste0(pre_padded, si_padded)
  }
}

# ---------------------------------------------------------------------
# Padding helpers — pure base R, vectorised
# ---------------------------------------------------------------------

# Left-pad `x` to `width` characters using spaces. Shorter values are
# padded; longer values pass through unchanged.
.pad_left <- function(x, width) {
  if (width <= 0L) {
    return(x)
  }
  formatC(x, width = width, flag = " ")
}

# Right-pad `x` to `width` characters using spaces. Shorter values are
# padded; longer values pass through unchanged.
.pad_right <- function(x, width) {
  if (width <= 0L) {
    return(x)
  }
  formatC(x, width = -width, flag = "-")
}
