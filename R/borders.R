# borders.R — per-cell border resolver.
#
# A `style_node` can carry up to 12 border scalars
# (`border_{top,bottom,left,right}_{style,width,color}`) plus the
# legacy four Boolean knobs (`rule_above`, `rule_below`,
# `border_left`, `border_right`). The legacy knobs map to
# `("solid", 0.5pt, default colour)` when TRUE — they remain the
# back-compat shorthand.
#
# `.effective_border(side, cell_style)` walks the per-side scalars
# first, then the legacy Boolean, and returns either NULL
# ("emit no border on this side") or a list with three components:
#
#   list(style = <enum>, width = <numeric pt>, color = <character>)
#
# Backends consume the resolved triple to emit destination-specific
# markup:
#
#   * DOCX: `<w:top w:val="single" w:sz="4" w:color="auto"/>`
#   * RTF: `\clbrdrt\brdrs\brdrw10\brdrcf0`
#   * HTML: `border-top: 0.5pt solid currentColor`
#   * LaTeX: tabularray `vlines={...}` / `hlines={...}` (Phase 5 lite)
#
# A `border_<side>_style == "none"` value is the explicit clear-this-
# border sentinel; the resolver returns NULL even if the legacy
# Boolean is TRUE. This lets a user wire `style(rule_above = TRUE,
# border_top_style = "none")` to disable the rule on a single cell
# without unsetting the table-wide default.

# Map a "side" string to the matching legacy Boolean property name.
# `top` -> `rule_above`, `bottom` -> `rule_below`, left / right are
# eponymous.
.border_legacy_prop <- function(side) {
  switch(
    side,
    top = "rule_above",
    bottom = "rule_below",
    left = "border_left",
    right = "border_right",
    NULL
  )
}

# Effective border for ONE side. Returns:
#
#   * `NULL` -> no override; backend may use its own default
#   * `list(style = "none", ...)` -> explicit clear sentinel
#     (suppresses backend default; emit no border)
#   * `list(style, width, color)` -> emit border with these values
#
# Resolution order:
#   1. Explicit `border_<side>_style == "none"` -> explicit clear
#      sentinel (backends translate to "no border at all")
#   2. Any of the three per-side scalars set -> build triple from
#      explicit values, falling back to defaults for unset components
#   3. Legacy Boolean TRUE -> default triple ("solid", 0.5pt, default)
#   4. Otherwise NULL -> backend default applies
.effective_border <- function(side, cell_style) {
  if (!is_style_node(cell_style)) {
    return(NULL)
  }
  style_prop <- paste0("border_", side, "_style")
  width_prop <- paste0("border_", side, "_width")
  color_prop <- paste0("border_", side, "_color")

  style <- S7::prop(cell_style, style_prop)
  width <- S7::prop(cell_style, width_prop)
  color <- S7::prop(cell_style, color_prop)

  style_set <- length(style) == 1L && !is.na(style) && nzchar(style)
  width_set <- length(width) == 1L && !is.na(width)
  color_set <- length(color) == 1L && !is.na(color) && nzchar(color)

  if (style_set && identical(style, "none")) {
    # Explicit clear -> sentinel; backends translate to "emit no
    # border on this side" and DO NOT fall back to their own default.
    return(list(style = "none", width = 0, color = NA_character_))
  }

  any_explicit <- style_set || width_set || color_set
  legacy_prop <- .border_legacy_prop(side)
  legacy_truth <- !is.null(legacy_prop) &&
    isTRUE(S7::prop(cell_style, legacy_prop))

  if (!any_explicit && !legacy_truth) {
    return(NULL)
  }

  list(
    style = if (style_set) style else "solid",
    width = if (width_set) width else 0.5,
    color = if (color_set) color else "currentColor"
  )
}

# Convenience: resolve all four sides of one cell at once. Returns
# a list with `top` / `bottom` / `left` / `right` slots, each
# either NULL or a `list(style, width, color)`. Useful in backends
# that need to test "does this cell have any border at all?" before
# emitting an outer wrapper.
.effective_borders <- function(cell_style) {
  sides <- c("top", "bottom", "left", "right")
  out <- stats::setNames(
    lapply(sides, .effective_border, cell_style = cell_style),
    sides
  )
  out
}

# Predicate: cell has any side with a non-NULL border. Saves an
# allocation cost in the common case where backends test before
# building a wrapper element.
.cell_has_any_border <- function(cell_style) {
  if (!is_style_node(cell_style)) {
    return(FALSE)
  }
  for (side in c("top", "bottom", "left", "right")) {
    if (!is.null(.effective_border(side, cell_style))) {
      return(TRUE)
    }
  }
  FALSE
}
