# chrome_style.R — parallel sidecar for non-body styling decisions.
#
# `cells_style` is shaped `(nrow(data), ncol(data))` and holds one
# `style_node` per body cell. That contract is load-bearing for the
# slice helpers (`.slice_list_matrix()` in as_grid.R) and every backend's
# body-cell loop. Chrome surfaces — the page-head band, the column-
# header block, the subgroup banner, the footnote block, the page-foot
# band — live OUTSIDE that matrix, so they need their own sidecar so
# `engine_borders()` and (in Phase 2) `engine_style()`'s `surface`
# predicates can stamp them without warping the body matrix.
#
# Phase 1 scope — chrome_style$borders.
#
#   The borders sub-list holds one (style, width, color) triple per
#   chrome region. Backends read this when emitting the chrome rules
#   that used to be hardcoded `\hline` / `\trowd \brdrb` / `<hr>`
#   directives. `NULL` means "use the backend's built-in default rule";
#   any other value (including the explicit-clear sentinel produced by
#   `borders = list(<region> = "none")`) overrides the default.
#
# Phase 2 scope — chrome_style$surfaces (live).
#
#   Per-surface `style_node` carrying the seven text properties
#   (font_family, font_size, bold, italic, underline, color, background)
#   plus alignment and blank-line spacing (blank_above / blank_below).
#   Populated by `engine_chrome_borders()` from layers attached via
#   `style(at = cells_*())` and `set_preset(style = template)`.
#   Every backend layers this on top of its built-in defaults when
#   rendering header / subgroup / footer / title / page-band cells.
#
# Region vocabulary (every key is a chrome surface; body regions stay
# on `cells_style`):
#
#   pagehead_bottom   bottom edge of the page-head band
#   header_top        top of the column-header block
#   header_bottom     bottom of the column-header block
#   header_between    between rows of a multi-band column-header
#   subgroup_top      above the subgroup banner row
#   subgroup_bottom   below the subgroup banner row (legacy
#                     `subgroup` alias resolves here)
#   footer_top        above the footnote block
#   footer_bottom     below the footnote block
#   pagefoot_top      top edge of the page-foot band

# Recognised chrome surfaces. Used by `chrome_style()` to seed the
# borders sub-list with the canonical key set, and by
# `engine_chrome_borders()` to know what region names the lowered
# `cells_<chrome surface>()` layers map onto.
.chrome_border_regions <- c(
  "pagehead_bottom",
  "header_top",
  "header_bottom",
  "header_between",
  "subgroup_top",
  "subgroup_bottom",
  "footer_top",
  "footer_bottom",
  "pagefoot_top"
)

# Recognised chrome surfaces for the Phase 2 text-prop cascade.
# Populated by the cascade routing in engine_chrome_borders() from
# cells_*() layers attached via style().
.chrome_surface_keys <- c(
  "pagehead",
  "title",
  "header",
  "subgroup",
  "footer",
  "pagefoot"
)

# Mapping from a `cells_*()` location surface to the chrome_style
# surface key it writes text properties onto. Used by
# engine_chrome_borders() when walking the four-tier cascade.
.location_to_chrome_surface <- c(
  pagehead = "pagehead",
  title = "title",
  headers = "header",
  subgroup_labels = "subgroup",
  footnotes = "footer",
  pagefoot = "pagefoot"
)

# Build an empty chrome_style. Each border slot defaults to NULL
# (= backend uses its built-in default rule); each surface slot
# defaults to a no-op style_node (= no theme-side text-prop override).
#
# Returned shape:
#
#   list(
#     borders  = list(pagehead_bottom = NULL, header_top = NULL, ...),
#     surfaces = list(pagehead = style_node(), header = style_node(), ...)
#   )
#
# Treated as a plain list rather than an S7 class so it slots into
# `tabular_grid@metadata` (already a list) without a new class
# property. Backends and the resolve engine introspect by key.
chrome_style <- function() {
  borders <- vector("list", length(.chrome_border_regions))
  names(borders) <- .chrome_border_regions
  surfaces <- lapply(.chrome_surface_keys, function(k) style_node())
  names(surfaces) <- .chrome_surface_keys
  list(
    borders = borders,
    surfaces = surfaces
  )
}

# Look up the resolved border triple for a chrome region. Returns
# NULL when the region has no override (caller uses backend default)
# or when `cs` is NULL / missing the region key.
#
# Used by backends that consume chrome_style in place of the older
# hardcoded chrome-rule emission paths.
.chrome_border_at <- function(cs, region) {
  if (!is.list(cs) || !is.list(cs$borders)) {
    return(NULL)
  }
  cs$borders[[region]]
}

# Look up the resolved style_node for a chrome surface. Returns a
# default (no-op) style_node when `cs` is NULL or the key is missing.
.chrome_surface_at <- function(cs, surface) {
  if (!is.list(cs) || !is.list(cs$surfaces)) {
    return(style_node())
  }
  node <- cs$surfaces[[surface]]
  if (!is_style_node(node)) {
    return(style_node())
  }
  node
}
