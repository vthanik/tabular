# align.R — alignment cascade resolver.
#
# Four-layer cascade for horizontal + vertical alignment on every
# emitted surface (body cells, header cells, subgroup banner, title
# lines, footnote lines, page chrome). Resolution order, lowest to
# highest precedence:
#
#   1. Baked-in built-in default for the surface.
#   2. Legacy `preset@title_align` / `preset@footnote_align` scalars
#      (the only two alignment slots surviving the Task 4/5 cut).
#   3. `chrome_style$surfaces[<surface>]@halign / @valign` — the
#      lowered `preset(alignment = list(...))` knob (or
#      `style(at = cells_<surface>(), halign = ...)`) lands here
#      via `engine_chrome_borders()`. Body alignment lowers to
#      `cells_body()` layers and stamps `cells_style[r,c]@halign`
#      directly (skipping the chrome path).
#   4. `col_spec@align` / `@valign` (per-column override, body +
#      header cell scope only).
#   5. `style_node@halign` / `@valign` (per-cell predicate, body
#      cell scope only).
#
# Title / footnote / subgroup label surfaces don't have a column or
# cell layer; they consult the chrome layer + legacy scalars.
#
# `col_spec@align == "decimal"` is special: the engine_decimal phase
# has already NBSP-padded the cell text, so the visual decimal mark
# falls on a single column-wide anchor when the cell renders
# right-aligned. We therefore project "decimal" to "right" inside
# the cascade.

# ---------------------------------------------------------------------
# `preset(alignment = list(...))` knob shape validator (called from
# .validate_lowered_knobs() at preset() / set_preset() call time)
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
    if (!is.character(v)) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be a character scalar; got ",
        class(v)[[1]]
      ))
    }
    if (anyNA(v)) {
      return(paste0("key ", .sh_quote(k), " must not contain NA"))
    }
    if (length(v) != 1L) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be length 1 (vector-form alignment dropped in the ",
        "Task 4/5 slot cut; use NULL to clear)"
      ))
    }
    if (!(v %in% allowed)) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " value must be one of ",
        paste(.sh_quote(allowed), collapse = ", "),
        "; got ",
        .sh_quote(v)
      ))
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# preset accessor: read one alignment key with cascade
# ---------------------------------------------------------------------

# Alignment resolver. After the rules/spacing redesign there are NO
# alignment slots on `preset_spec`: title / footnote / subgroup /
# header / body alignment all flow through the `alignment` knob, which
# lowers to `cells_<surface>()` layers (chrome_style / cells_style)
# that backends consult FIRST. With no slot left to read, this helper
# returns NA for every key, so each backend applies its own baked-in
# surface default (title centered, footnote left, via CSS / markup).
# The `preset` argument is retained for signature stability but unused.
.preset_align <- function(preset, key, line_index = 1L, n_lines = 1L) {
  NA_character_
}

# ---------------------------------------------------------------------
# Cell-level effective alignment (body cells)
# ---------------------------------------------------------------------

# Effective horizontal alignment for one body cell. Walks:
#
#   style_node@halign  >  col_spec@align (decimal -> right)
#                       >  NA (backend default takes over)
#
# Body alignment from `preset(alignment = list(body_halign = ...))`
# stamps `cells_style[r,c]@halign` via the lowered cells_body()
# layer, so the top of the cascade reads it.
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
#   style_node@valign  >  col_spec@valign  >  NA (backend default)
#
# Body valign from `preset(alignment = list(body_valign = ...))`
# stamps `cells_style[r,c]@valign` via the lowered cells_body()
# layer, so the top of the cascade reads it.
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
