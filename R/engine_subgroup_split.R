# engine_subgroup_split.R — partition phase. Runs FIRST in
# `.resolve_spec_to_grid` (before engine_derive). When
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
engine_subgroup_split <- function(spec) {
  if (is.null(spec@subgroup) || length(spec@subgroup@by) == 0L) {
    return(list(list(spec = spec, runtime = NULL)))
  }

  by_cols <- spec@subgroup@by
  data <- spec@data
  template <- .subgroup_effective_template(spec)

  # Build the crossing of unique value combinations across all
  # partition columns. Each crossing row defines one group.
  combos <- .subgroup_combos(data, by_cols)

  total <- nrow(combos)
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
    # group (clinical convention). Empty groups are filtered out
    # upstream, so `sub_data` is guaranteed to have at least one row.
    banner_text <- .subgroup_render_label(
      template,
      sub_data[1L, , drop = FALSE]
    )

    runtime <- list(
      by = by_cols,
      values = unname(as.list(combos[i, , drop = FALSE])),
      index = i,
      total = total,
      banner_text = banner_text
    )

    sub_spec <- S7::set_props(spec, data = sub_data)
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
.subgroup_combos <- function(data, by_cols) {
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

  # Filter to combinations actually present in the data — empty
  # cells would render meaningless banners with no body rows.
  present <- .subgroup_combo_present_mask(data, by_cols, grid)
  grid[present, , drop = FALSE]
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
