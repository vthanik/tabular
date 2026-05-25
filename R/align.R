# align.R — alignment cascade resolver.
#
# Three-layer cascade for horizontal + vertical alignment on every
# emitted surface (body cells, header cells, subgroup banner, title
# lines, footnote lines, page chrome). Resolution order, lowest to
# highest precedence:
#
#   1. Baked-in built-in default for the surface.
#   2. `preset@alignment` named-list (theme layer).
#   3. `col_spec@align` / `@valign` (per-column override, body+header
#      cell scope only).
#   4. `style_node@halign` / `@valign` (per-cell predicate, body cell
#      scope only).
#
# Title / footnote / subgroup label surfaces don't have a column or
# cell layer; they fall through 1 -> 2.
#
# `col_spec@align == "decimal"` is special: the engine_decimal phase
# has already NBSP-padded the cell text, so the visual decimal mark
# falls on a single column-wide anchor when the cell renders
# right-aligned. We therefore project "decimal" to "right" inside
# the cascade.

# ---------------------------------------------------------------------
# preset@alignment validator (called from preset_spec validator)
# ---------------------------------------------------------------------

# Returns NULL when the list is well-formed; otherwise a message
# string suitable for the S7 validator. Caller prepends "@alignment ".
.preset_alignment_shape_error <- function(al) {
  if (length(al) == 0L) {
    return(NULL)
  }
  if (!is.list(al)) {
    return(paste0("must be a named list; got ", class(al)[[1]]))
  }
  nms <- names(al)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .preset_alignment_keys)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown key(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_alignment_keys), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- al[[k]]
    if (is.null(v)) {
      next
    }
    halign <- k %in% .preset_alignment_keys_halign
    allowed <- if (halign) .align_anchor_values else .valign_values
    accepts_vector <- halign && (k %in% .preset_alignment_keys_vector_halign)
    if (!is.character(v)) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be a character vector; got ",
        class(v)[[1]]
      ))
    }
    if (anyNA(v)) {
      return(paste0("key ", .sh_quote(k), " must not contain NA"))
    }
    if (length(v) == 0L) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be length >= 1 (use NULL to clear)"
      ))
    }
    if (length(v) > 1L && !accepts_vector) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be length 1; vectors are accepted only for ",
        paste(.sh_quote(.preset_alignment_keys_vector_halign), collapse = ", ")
      ))
    }
    bad <- v[!(v %in% allowed)]
    if (length(bad) > 0L) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " value(s) must be one of ",
        paste(.sh_quote(allowed), collapse = ", "),
        "; got ",
        paste(.sh_quote(bad), collapse = ", ")
      ))
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# preset accessor: read one alignment key with cascade
# ---------------------------------------------------------------------

# Resolve one alignment key against a preset, walking ONLY the
# explicit layers — the user-set named-list and the legacy flat
# scalars. Returns NA_character_ when no layer explicitly set the
# key; the caller decides whether to fall through to a baked
# default or to leave the surface to CSS / backend defaults.
#
# Caveat on the legacy fall-through: `preset@title_align` /
# `@footnote_align` carry baked-in scalar defaults ("center" /
# "left") declared on `preset_spec`. Treating those as "explicit"
# would force every untouched preset to override the CSS / backend
# baseline. We therefore consult the legacy scalars ONLY when the
# user has changed them away from the factory default — detected
# by comparing against `preset_spec()`'s default values.
.preset_align <- function(preset, key, line_index = 1L, n_lines = 1L) {
  if (!is_preset_spec(preset)) {
    return(NA_character_)
  }
  al <- preset@alignment
  v <- al[[key]]
  if (!is.null(v) && length(v) > 0L) {
    if (length(v) == 1L) {
      return(v)
    }
    # Vector form (title_halign / footnote_halign): index into the
    # vector by line_index; if shorter than the rendered block,
    # broadcast the last value (length-1 applies to every line; a
    # longer vector zips 1:1 then pads with the last entry).
    idx <- min(line_index, length(v))
    return(v[[idx]])
  }
  # Legacy flat scalars — only treat as explicit when set away from
  # the factory default. `.preset_factory_default("title_align")`
  # returns "center"; if the user changed `title_align` to "left",
  # that's an explicit override and we honour it here.
  legacy_key <- switch(
    key,
    title_halign = "title_align",
    footnote_halign = "footnote_align",
    NULL
  )
  if (!is.null(legacy_key)) {
    val <- S7::prop(preset, legacy_key)
    if (length(val) == 1L && !is.na(val)) {
      factory <- .preset_factory_default(legacy_key)
      if (!identical(val, factory)) {
        return(val)
      }
    }
  }
  NA_character_
}

# Look up the factory default for one preset_spec property. Used
# by .preset_align to decide whether the legacy `title_align` /
# `footnote_align` scalars have been explicitly overridden by the
# user. Memoised once per session via a package-internal env so we
# avoid rebuilding the default preset on every cell resolution.
.preset_factory_defaults_env <- new.env(parent = emptyenv())
.preset_factory_default <- function(name) {
  if (is.null(.preset_factory_defaults_env$preset)) {
    .preset_factory_defaults_env$preset <- preset_spec()
  }
  S7::prop(.preset_factory_defaults_env$preset, name)
}

# ---------------------------------------------------------------------
# Cell-level effective alignment (body cells)
# ---------------------------------------------------------------------

# Effective horizontal alignment for one body cell. Walks:
#
#   style_node@halign  >  col_spec@align (decimal -> right)
#                       >  preset@alignment$body_halign
#                       >  baked default "left"
.effective_body_halign <- function(cell_style, col_spec, preset) {
  if (
    is_style_node(cell_style) &&
      length(cell_style@halign) == 1L &&
      !is.na(cell_style@halign)
  ) {
    return(cell_style@halign)
  }
  if (
    is_col_spec(col_spec) &&
      length(col_spec@align) == 1L &&
      !is.na(col_spec@align)
  ) {
    if (col_spec@align == "decimal") {
      return("right")
    }
    return(col_spec@align)
  }
  .preset_align(preset, "body_halign")
}

# Effective vertical alignment for one body cell. Walks:
#
#   style_node@valign  >  col_spec@valign
#                       >  preset@alignment$body_valign
#                       >  baked default "top"
.effective_body_valign <- function(cell_style, col_spec, preset) {
  if (
    is_style_node(cell_style) &&
      length(cell_style@valign) == 1L &&
      !is.na(cell_style@valign)
  ) {
    return(cell_style@valign)
  }
  if (
    is_col_spec(col_spec) &&
      length(col_spec@valign) == 1L &&
      !is.na(col_spec@valign)
  ) {
    return(col_spec@valign)
  }
  .preset_align(preset, "body_valign")
}

# ---------------------------------------------------------------------
# Header-cell effective alignment
# ---------------------------------------------------------------------

# Header cells follow a two-layer cascade: per-column override on the
# col_spec, then the preset header default. The body-level fallback
# of "left" does not apply — header cells default to centre via the
# baked `header_halign` default.
.effective_header_halign <- function(col_spec, preset) {
  if (
    is_col_spec(col_spec) &&
      length(col_spec@align) == 1L &&
      !is.na(col_spec@align)
  ) {
    if (col_spec@align == "decimal") {
      return("right")
    }
    return(col_spec@align)
  }
  .preset_align(preset, "header_halign")
}

.effective_header_valign <- function(col_spec, preset) {
  if (
    is_col_spec(col_spec) &&
      length(col_spec@valign) == 1L &&
      !is.na(col_spec@valign)
  ) {
    return(col_spec@valign)
  }
  .preset_align(preset, "header_valign")
}

# ---------------------------------------------------------------------
# Surface accessors (subgroup banner, title, footnote)
# ---------------------------------------------------------------------

.effective_subgroup_halign <- function(preset) {
  .preset_align(preset, "subgroup_halign")
}

.effective_subgroup_valign <- function(preset) {
  .preset_align(preset, "subgroup_valign")
}

# Title / footnote alignment by line index. `line_index` is 1-based;
# `n_lines` is the total title or footnote vector length (informational;
# used only by .preset_align for vector-form broadcast).
.effective_title_halign <- function(preset, line_index = 1L, n_lines = 1L) {
  .preset_align(
    preset,
    "title_halign",
    line_index = line_index,
    n_lines = n_lines
  )
}

.effective_footnote_halign <- function(
  preset,
  line_index = 1L,
  n_lines = 1L
) {
  .preset_align(
    preset,
    "footnote_halign",
    line_index = line_index,
    n_lines = n_lines
  )
}
