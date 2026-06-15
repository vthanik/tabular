# engine_subgroup_split.R — partition phase. Runs FIRST in
# `.resolve_spec_to_grid` (before engine_sort). When
# `spec@subgroup` is NULL, returns a single-entry list carrying the
# unchanged spec and `runtime = NULL`. When set, splits @data by
# the unique values (or value combinations) of the subgroup `by`
# cols and returns one list entry per group with a filtered
# sub-spec and a `runtime` list describing the group (by, values,
# index, total, banner_text).
#
# Per the locked design (CLAUDE.local.md / plan):
#   * Hard page break unconditionally between groups — emerges
#     naturally from running engine_paginate() per sub-spec.
#   * Page numbers reset per group — emerges for the same reason.
#   * Each page descriptor in the merged grid carries the per-group
#     banner_text so backends can emit the centred subgroup banner
#     row above the column-header rule.
#
# Banner text is produced by `.subgroup_render_label()` (in
# R/subgroup.R) against the FIRST ROW of each group's filtered
# data, mirroring the `{program}` / `{datetime}` token-substitution
# pattern at R/page_chrome.R:293.

# Split a tabular_spec by @subgroup. Returns a list of
# `list(spec = <sub_spec>, runtime = <runtime-or-NULL>)` entries.
#
# When spec@subgroup is NULL: one-entry list with runtime = NULL.
# When set: N entries, one per unique value combination of the
# partition `by` cols.

#' Partition a `tabular_spec` by its subgroup definition
#'
#' @param spec A `tabular_spec`. When `spec@subgroup` is `NULL` the
#'   helper returns a single-entry list carrying the unchanged spec
#'   and `runtime = NULL`. When set, the helper filters `spec@data`
#'   by every unique value combination of `spec@subgroup@by` and
#'   returns one entry per group.
#' @return A list of `list(spec = <sub_spec>, runtime = <runtime>)`
#'   entries. `runtime` is `NULL` when the spec has no subgroup;
#'   otherwise a list describing the group (`by`, `values`, `index`,
#'   `total`, `banner_text`) that the page-chrome layer renders as a
#'   centred subgroup banner above the column-header rule.
#' @keywords internal
#' @noRd
engine_subgroup_split <- function(spec) {
  if (is.null(spec@subgroup) || length(spec@subgroup@by) == 0L) {
    return(list(list(spec = spec, runtime = NULL)))
  }

  by_cols <- spec@subgroup@by
  data <- spec@data
  template <- .subgroup_effective_template(spec)

  # Build the crossing of unique value combinations across all
  # partition columns. Each crossing row defines one group. With
  # `keep_empty = TRUE`, zero-N crossings are retained and rendered as
  # empty-state pages instead of dropped.
  keep_empty <- isTRUE(spec@subgroup@keep_empty)
  combos <- .subgroup_combos(data, by_cols, keep_empty = keep_empty)

  total <- nrow(combos)
  if (total == 0L) {
    # No observed value combinations (zero-row data under a subgroup):
    # there are no groups to band. Fall back to a single runtime-less
    # entry so the resolver renders the empty-state placeholder once,
    # with no subgroup banner (there is no group value to name).
    return(list(list(spec = spec, runtime = NULL)))
  }
  out <- vector("list", total)

  for (i in seq_len(total)) {
    keep <- .subgroup_match_mask(data, by_cols, combos[i, , drop = FALSE])
    sub_data <- data[keep, , drop = FALSE]
    # Preserve column attributes (factor levels, labels) — the
    # default `[` on a data frame keeps factor levels but drops some
    # attrs; for safety, copy across attrs we care about.
    for (nm in names(sub_data)) {
      lab <- attr(data[[nm]], "label", exact = TRUE)
      if (!is.null(lab)) {
        attr(sub_data[[nm]], "label") <- lab
      }
    }

    # Render the banner against the first row of the filtered data.
    # Columns referenced in the template are assumed constant within
    # group (clinical convention). Under `keep_empty = TRUE` a group can
    # have zero rows; source the banner from the combo values instead (an
    # all-NA row carrying just the `by`-column values), so a template that
    # references only `by` columns still renders. Template refs to other
    # columns resolve to NA for an empty group (there is no data row to
    # read a constant-within-group value from).
    banner_row <- if (nrow(sub_data) > 0L) {
      sub_data[1L, , drop = FALSE]
    } else {
      .subgroup_empty_banner_row(data, by_cols, combos[i, , drop = FALSE])
    }
    banner_text <- .subgroup_render_label(template, banner_row)

    runtime <- list(
      by = by_cols,
      values = unname(as.list(combos[i, , drop = FALSE])),
      index = i,
      total = total,
      banner_text = banner_text
    )

    sub_spec <- S7::set_props(spec, data = sub_data)
    sub_spec <- .subgroup_apply_big_n(
      sub_spec,
      combos[i, , drop = FALSE],
      spec@subgroup
    )
    out[[i]] <- list(spec = sub_spec, runtime = runtime)
  }

  out
}

# Build the crossing of unique value combinations across the
# partition columns.
#
# Ordering rule (per locked design):
#   * factor cols  -> factor LEVEL order (NA last)
#   * other cols   -> first-appearance order (NA last)
#
# For multi-var crossing we iterate the columns in `by_cols` order;
# the FIRST column's ordering dominates, then the second within
# each value of the first, and so on (matches SAS BY-group
# processing semantics).
.subgroup_combos <- function(data, by_cols, keep_empty = FALSE) {
  per_col <- lapply(by_cols, function(col) {
    .subgroup_unique_ordered(data[[col]])
  })
  # SAS BY-group convention: the FIRST `by` column varies SLOWEST,
  # the last varies fastest. expand.grid() varies its first arg
  # fastest, so pass `per_col` in REVERSE — then restore the
  # user-facing column order on the resulting data frame.
  rev_idx <- rev(seq_along(by_cols))
  grid <- expand.grid(
    stats::setNames(per_col[rev_idx], by_cols[rev_idx]),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- grid[, by_cols, drop = FALSE]

  # By default, filter to combinations actually present in the data --
  # empty cells would render meaningless banners with no body rows. With
  # `keep_empty = TRUE` the user has opted to render every crossing, so
  # keep the full grid (zero-N combos become empty-state pages).
  if (isTRUE(keep_empty)) {
    return(grid)
  }
  present <- .subgroup_combo_present_mask(data, by_cols, grid)
  grid[present, , drop = FALSE]
}

# Build a 1-row banner source for a zero-N group: an all-NA row in the
# shape of `data` (preserving column types / factor levels / labels)
# with the `by` columns set to this combo's values. Lets the banner
# template render its `by`-column references for an empty group.
.subgroup_empty_banner_row <- function(data, by_cols, combo_row) {
  row <- data[NA_integer_, , drop = FALSE]
  row.names(row) <- NULL
  for (col in by_cols) {
    row[[col]] <- combo_row[[col]]
  }
  row
}

# Unique values of one partition column in display order
# (factor: level order; other: first-appearance). NA placed last
# when present.
.subgroup_unique_ordered <- function(x) {
  if (is.factor(x)) {
    vals <- levels(x)
    present <- vals %in% as.character(x)
    vals <- vals[present]
    if (anyNA(x)) {
      vals <- c(vals, NA_character_)
    }
    return(factor(vals, levels = levels(x), exclude = NULL))
  }
  vals <- unique(x)
  if (anyNA(vals)) {
    vals <- c(vals[!is.na(vals)], vals[is.na(vals)])
  }
  vals
}

# Logical mask over `data` rows where every partition column equals
# the corresponding value in `combo_row` (a 1-row data.frame). NA
# values match NA only.
.subgroup_match_mask <- function(data, by_cols, combo_row) {
  mask <- rep(TRUE, nrow(data))
  for (col in by_cols) {
    dval <- data[[col]]
    cval <- combo_row[[col]][[1L]]
    col_mask <- if (is.na(cval)) is.na(dval) else !is.na(dval) & dval == cval
    mask <- mask & col_mask
  }
  mask
}

# Vector of TRUE/FALSE, one per row of `combos`, indicating whether
# the corresponding combination appears in `data`. Used to drop
# crossings that would yield empty groups.
.subgroup_combo_present_mask <- function(data, by_cols, combos) {
  vapply(
    seq_len(nrow(combos)),
    function(i) {
      any(.subgroup_match_mask(data, by_cols, combos[i, , drop = FALSE]))
    },
    logical(1L)
  )
}

# Per-page BigN application. For the subgroup whose combo is
# `combo_row`, append the formatted N suffix to each arm's header
# element: a leaf column's label (via sub_spec@cols) or a spanner
# band's label (via sub_spec@headers). No-op when sg@big_n is NULL.
# The leaf-vs-band decision reuses `.subgroup_bign_target` so it can
# never diverge from validation. Mutates labels via `set_props` (not
# the col_spec()/header_node() constructors) so the appended `(N=x)`
# is never re-evaluated as a `{n}` template.
.subgroup_apply_big_n <- function(sub_spec, combo_row, sg) {
  if (is.null(sg@big_n)) {
    return(sub_spec)
  }
  by_cols <- sg@by
  big_n <- sg@big_n
  fmt <- sg@big_n_fmt
  data_names <- names(sub_spec@data)
  band_labels <- .subgroup_header_labels(sub_spec@headers)
  n_cols <- setdiff(names(big_n), by_cols)

  idx <- which(.subgroup_match_mask(big_n, by_cols, combo_row))
  if (length(idx) == 0L) {
    # No big_n row for this combo. For a present combo the verb-time
    # completeness check guarantees a row; this is reachable only for a
    # `keep_empty = TRUE` zero-N combo (not required to carry a big_n
    # row), which keeps its default headers.
    return(sub_spec)
  }
  idx <- idx[[1L]]

  cols <- sub_spec@cols
  headers <- sub_spec@headers
  for (nm in n_cols) {
    n_val <- big_n[[nm]][[idx]]
    suffix <- gsub("{n}", format(n_val, trim = TRUE), fmt, fixed = TRUE)
    tgt <- .subgroup_bign_target(nm, data_names, band_labels)
    if (tgt$kind == "leaf") {
      cs <- cols[[nm]]
      cs0 <- if (is_col_spec(cs)) cs else col_spec()
      base <- if (!is.na(cs0@label)) cs0@label else nm
      cols[[nm]] <- S7::set_props(
        cs0,
        label = paste0(base, suffix),
        name = nm
      )
    } else if (tgt$kind == "band") {
      headers <- .subgroup_suffix_band(headers, nm, suffix)
    }
  }
  S7::set_props(sub_spec, cols = cols, headers = headers)
}

# Append `suffix` to the label of the (single, validated-unique)
# header node whose label equals `target`, recursing into children.
.subgroup_suffix_band <- function(nodes, target, suffix) {
  lapply(nodes, function(node) {
    if (identical(node@label, target)) {
      node <- S7::set_props(node, label = paste0(node@label, suffix))
    }
    if (length(node@children) > 0L) {
      node <- S7::set_props(
        node,
        children = .subgroup_suffix_band(node@children, target, suffix)
      )
    }
    node
  })
}

# Per-subgroup BigN records for the continuous backends (HTML / md).
# Paged backends ride the N on each page's repeating header; continuous
# backends have one header, so they instead emit a per-arm N row under
# each subgroup banner. This builds the raw material for that row: one
# record list per subgroup, each entry `list(name, kind, text)` where
# `name` is the big_n value-column (a data column for a leaf target, a
# band label for a band target), `kind` is "leaf" / "band", and `text`
# is the formatted `(N=x)` cell. Returns NULL when big_n is absent, so
# the merge leaves `page$subgroup_bign` NULL and non-big_n subgroup
# tables render byte-identically.
#
# Recomputed from the raw `big_n` frame (never reverse-parsed from the
# suffixed header AST), reusing `.subgroup_combos` / `.subgroup_match_mask`
# / `.subgroup_bign_target` / `.subgroup_header_labels` so the combo
# order, denominator pick, and leaf-vs-band placement can never diverge
# from `.subgroup_apply_big_n`. List index `i` matches the split's
# `runtime$index`.
# TRUE when `big_n` carries the SAME denominators for every DISPLAYED
# subgroup — i.e. the N does not actually vary by group. The value
# columns then have a single distinct row, so there is nothing
# per-subgroup to show and the engine folds the N into the global column
# header (no repeated `(N=x)` row in HTML / md, no per-page header
# variation). FALSE without big_n.
#
# The decision is made over the rendered combos (`.subgroup_combos`)
# joined to `big_n`, not over the raw `big_n` rows: table reuse may carry
# extra denominator rows for subgroups absent from the data, and those
# must not influence whether the displayed Ns vary.
.subgroup_bign_constant <- function(spec) {
  sg <- spec@subgroup
  if (is.null(sg) || is.null(sg@big_n)) {
    return(FALSE)
  }
  big_n <- sg@big_n
  by_cols <- sg@by
  val_cols <- setdiff(names(big_n), by_cols)
  if (length(val_cols) == 0L) {
    return(FALSE)
  }
  combos <- .subgroup_combos(
    spec@data,
    by_cols,
    keep_empty = isTRUE(sg@keep_empty)
  )
  idx <- vapply(
    seq_len(nrow(combos)),
    function(i) {
      m <- which(.subgroup_match_mask(
        big_n,
        by_cols,
        combos[i, , drop = FALSE]
      ))
      if (length(m) == 0L) NA_integer_ else m[[1L]]
    },
    integer(1L)
  )
  idx <- idx[!is.na(idx)]
  if (length(idx) == 0L) {
    return(FALSE)
  }
  nrow(unique(big_n[idx, val_cols, drop = FALSE])) <= 1L
}

.subgroup_bign_records_all <- function(spec) {
  sg <- spec@subgroup
  if (is.null(sg) || is.null(sg@big_n)) {
    return(NULL)
  }
  big_n <- sg@big_n
  by_cols <- sg@by
  fmt <- sg@big_n_fmt
  data_names <- names(spec@data)
  band_labels <- .subgroup_header_labels(spec@headers)
  n_cols <- setdiff(names(big_n), by_cols)
  # Iterate the SAME combos the split iterates (keep_empty-aware) so the
  # returned list index matches `runtime$index` at the as_grid merge.
  combos <- .subgroup_combos(
    spec@data,
    by_cols,
    keep_empty = isTRUE(sg@keep_empty)
  )

  lapply(seq_len(nrow(combos)), function(i) {
    idx <- which(.subgroup_match_mask(
      big_n,
      by_cols,
      combos[i, , drop = FALSE]
    ))
    if (length(idx) == 0L) {
      # A keep_empty zero-N combo has no big_n row; emit an empty record
      # so the continuous backends render no per-arm N row for it.
      return(list())
    }
    idx <- idx[[1L]]
    lapply(n_cols, function(nm) {
      n_val <- big_n[[nm]][[idx]]
      suffix <- gsub("{n}", format(n_val, trim = TRUE), fmt, fixed = TRUE)
      # Strip the leading newline/space the paged header carries (the
      # default fmt is "\n(N={n})") so the row cell reads "(N=24)", not
      # a blank-then-newline. Internal spacing is preserved.
      text <- sub("^\\s+", "", suffix)
      tgt <- .subgroup_bign_target(nm, data_names, band_labels)
      list(name = nm, kind = tgt$kind, text = text)
    })
  })
}
