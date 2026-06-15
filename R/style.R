# style.R — unified styling verb. One call per layer; layers
# accumulate; the engine resolves the cascade at render time.
#
# Single API surface:
#
#   style(spec, ..., .at = cells_*())
#
# The `at` argument is a `tabular_location` built by one of the
# `cells_*()` constructors (`cells_body`, `cells_headers`,
# `cells_table`, etc.). The `...` carries the style attributes
# (text properties, borders, alignment, padding, blank lines).
# Each call appends one `style_layer` to `spec@styles@layers`;
# multiple calls compose by layer order (later calls win per
# attribute at the merge step).
#
# The first argument also accepts a `tabular_style_template`
# (built by [`style_template()`]). When given, layers accumulate
# onto the template's `layers` slot instead of a spec. Same verb,
# same attribute names — symmetric API for per-table vs house-style
# composition.
#
# `at` defaults to `cells_body()` so the simplest call
# `style(spec, bold = TRUE)` targets every body cell.

#' Attach a style layer to a `tabular_spec` or `style_template`
#'
#' One verb, one cascade. Each `style()` call appends a single
#' `style_layer` (location + style attributes) to the spec or
#' template. Layers accumulate in declaration order; the engine
#' merges them at render time so later layers win per attribute,
#' NA-valued fields leave the prior layer intact.
#'
#' @section Locations:
#'
#' The `.at` argument selects which surface the layer targets. Every
#' region of the rendered page has a `cells_*()` constructor:
#'
#'   * `cells_body()`             — body cells (default)
#'   * `cells_headers()`          — column header band
#'   * `cells_group_headers()`    — synthetic group-header rows
#'   * `cells_title()`            — title block
#'   * `cells_subgroup_labels()`  — subgroup banner row
#'   * `cells_footnotes()`        — footnote block
#'   * `cells_pagehead()`         — page-header band
#'   * `cells_pagefoot()`         — page-footer band
#'   * `cells_table()`            — table-wide regions (outer
#'                                  borders, body-row separators)
#'
#' Body filters live on `cells_body()`: `i = 1:3` for integer-index
#' rows, `j = "Total"` for column-name targeting, `where = <expr>`
#' for a quosure-captured predicate evaluated against `spec@data`.
#'
#' A [`figure()`] spec shares the chrome surfaces, so `style()` accepts a
#' figure at `cells_title()`, `cells_footnotes()`, `cells_pagehead()`, and
#' `cells_pagefoot()` only; a figure has no body, column headers, or
#' subgroup banner, so those locations raise an error.
#'
#' @section Style attributes:
#'
#' Each layer carries a `style_node` built from `...`. Recognised
#' attribute names:
#'
#'   * Text — `bold`, `italic`, `underline`, `color`, `background`,
#'     `font_family`, `font_size`
#'   * Alignment — `halign` (`"left" / "center" / "right"`),
#'     `valign` (`"top" / "middle" / "bottom"`)
#'   * Borders — `border` (umbrella), `border_top`, `border_bottom`,
#'     `border_left`, `border_right` (each takes a `brdr()` value
#'     or the literal `"none"`); per-side scalars
#'     `border_<side>_{style,width,color}` for finer control
#'   * Padding — `padding` (a scalar applies to all four sides; a
#'     named vector `c(top = , right = , bottom = , left = )` sets
#'     each side); or the per-side scalars `padding_<side>` directly
#'   * Spacing — `blank_above`, `blank_below` (integer blank lines
#'     above / below the block — for `cells_title()` /
#'     `cells_footnotes()` / `cells_subgroup_labels()`)
#'   * Inline — `pretext`, `posttext` (literal text prepended /
#'     appended around the cell value)
#'
#' Unknown attribute names emit a `cli::cli_warn` and drop from
#' the constructed node; the engine never sees a foreign property.
#'
#' @param .spec *A `tabular_spec` OR a `tabular_style_template`.*
#'   `<tabular_spec | tabular_style_template>: required`.
#'   Dot-prefixed so R's partial argument matching cannot
#'   accidentally bind a short attribute name in `...` to the spec
#'   slot. When piping through `style_template() |> style(...)`
#'   layers accumulate onto the template instead of a spec.
#'
#' @param ... *Named style attributes.* At least one required. See
#'   the *Style attributes* section for the recognised names.
#'
#' @param .at *Location object selecting which surface the layer
#'   targets.* `<tabular_location>: default cells_body()`. Build with
#'   one of the `cells_*()` constructors; see [`cells_body()`] and
#'   siblings. Dot-prefixed (tidyverse convention) because it comes
#'   AFTER `...` — that way a user-passed style attribute can never
#'   collide with this arg's name.
#'
#' @return The updated `tabular_spec` (or `tabular_style_template`,
#'   when called against one).
#'
#' @examples
#' # ---- AE table by SOC and PT with per-row indent + styled hierarchy ----
#' # `cdisc_saf_aesocpt` ships with `indent_level` (0 on overall/SOC rows,
#' # 1 on PT rows); `col_spec(indent = "indent_level")` drives the
#' # PT indent on the `label` column.
#' tabular(cdisc_saf_aesocpt, titles = "Adverse Events by SOC / PT",
#'         footnotes = "") |>
#'   cols(
#'     label    = col_spec(label = "Category", align = "left",
#'                         indent = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100", align = "decimal"),
#'     Total    = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   # SOC summary rows bolded (depth 0 — flush)
#'   style(bold = TRUE,
#'         .at = cells_body(where = row_type == "soc")) |>
#'   # Overall row gets a light background
#'   style(background = "#f0f0f0",
#'         .at = cells_body(where = row_type == "overall"))
#'
#' # ---- Chrome styling ----
#' # Each layer changes the surface VISIBLY from its default: a coloured
#' # rule under the header band, a dark-blue header text, a left-aligned
#' # title (default is centred), and a blank line above + below the title.
#' tabular(cdisc_saf_demo, titles = "Demographic Characteristics") |>
#'   style(color = "#1a5276", .at = cells_headers()) |>
#'   style(border_bottom = brdr("thick", "double", "#1a5276"),
#'         .at = cells_headers()) |>
#'   style(halign = "left", .at = cells_title()) |>
#'   style(blank_above = 1, blank_below = 1,
#'         .at = cells_title())
#'
#' # ---- Table-wide borders ----
#' tabular(cdisc_saf_demo) |>
#'   style(border = brdr("medium"),
#'         .at = cells_table(side = "outer")) |>
#'   style(border_top = brdr("hairline", "dotted"),
#'         .at = cells_table(side = "rows"))
#'
#' # ---- House style via style_template() ----
#' house <- style_template() |>
#'   style(color = "#1F3B5C", background = "#DBE4F0", .at = cells_headers()) |>
#'   style(border_top = brdr("thick"), .at = cells_headers()) |>
#'   style(border_bottom = brdr("thick"), .at = cells_headers()) |>
#'   style(border_bottom = brdr("medium"),
#'         .at = cells_table(side = "outer_bottom"))
#' # Attach once via set_preset(); every tabular() chain then inherits it.
#' set_preset(.style = house, font_size = 9)
#' set_preset(.reset = TRUE) # restore the default for later examples
#'
#' @seealso
#' **Companion verbs:** [`cols()`], [`headers()`], [`preset()`],
#' [`set_preset()`].
#'
#' **Location constructors:** [`cells_body()`], [`cells_headers()`],
#' [`cells_group_headers()`], [`cells_title()`],
#' [`cells_subgroup_labels()`], [`cells_footnotes()`],
#' [`cells_pagehead()`], [`cells_pagefoot()`], [`cells_table()`].
#'
#' **Style values:** [`brdr()`], [`style_template()`].
#'
#' @export
style <- function(.spec, ..., .at = cells_body()) {
  call <- rlang::caller_env()

  is_template <- is_style_template(.spec)
  is_figure <- is_figure_spec(.spec)
  if (!is_template && !is_figure) {
    check_tabular_spec(.spec, call = call)
  }

  if (!is_tabular_location(.at)) {
    at_value <- .at
    cli::cli_abort(
      c(
        "{.arg .at} must be a {.cls tabular_location}.",
        "x" = "You supplied {.obj_type_friendly {at_value}}.",
        "i" = "Build one with {.fn cells_body} / {.fn cells_headers} / etc."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (is_figure && !(.at$surface %in% .figure_style_surfaces)) {
    bad_surface <- .at$surface
    cli::cli_abort(
      c(
        "Cannot style the {.val {bad_surface}} surface on a figure.",
        "i" = "A figure can be styled at its titles, footnotes, page header, or page footer only.",
        "i" = "Use {.fn cells_title}, {.fn cells_footnotes}, {.fn cells_pagehead}, or {.fn cells_pagefoot}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  attrs <- rlang::list2(...)
  if (length(attrs) == 0L) {
    cli::cli_abort(
      c(
        "Specify at least one style attribute.",
        "i" = "Pass attributes like {.code bold = TRUE} or {.code color = \"red\"}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  attr_names <- names(attrs)
  if (is.null(attr_names) || any(.is_blank_label(attr_names))) {
    cli::cli_abort(
      c(
        "All style attributes in {.fn style} must be named.",
        "i" = "Use {.code attr_name = value} for every attribute."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  attrs <- .expand_brdr_shorthand(attrs, call = call)
  node <- .build_style_node(attrs, call = call)

  layer <- style_layer(location = .at, style = node)

  if (is_template) {
    return(.style_template_add_layer(.spec, layer))
  }
  current <- .spec@styles
  if (!is_style_spec(current)) {
    current <- style_spec()
  }
  updated <- S7::set_props(
    current,
    layers = c(current@layers, list(layer))
  )
  S7::set_props(.spec, styles = updated)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Known style_node field set — matches the S7 properties declared
# on `style_node` in R/aaa_class.R. Maintained as a constant so the
# verb and engine agree on which attributes are first-class.
.style_node_fields <- c(
  "bold",
  "italic",
  "underline",
  "color",
  "background",
  "font_family",
  "font_size",
  "padding_top",
  "padding_right",
  "padding_bottom",
  "padding_left",
  "blank_above",
  "blank_below",
  "pretext",
  "posttext",
  "halign",
  "valign",
  "border_top_style",
  "border_top_width",
  "border_top_color",
  "border_bottom_style",
  "border_bottom_width",
  "border_bottom_color",
  "border_left_style",
  "border_left_width",
  "border_left_color",
  "border_right_style",
  "border_right_width",
  "border_right_color"
)

# Expand `brdr()`-shorthand entries in the user's attribute list.
#
# A user writing
#   style(border_top = brdr("thick", "double"), ...)
# wants the three scalars `border_top_style` / `border_top_width` /
# `border_top_color` populated from one brdr value. Same for
# `border = brdr(...)` (sets all four sides). A `"none"` literal
# string is shorthand for "kill the border on this side" — expands to
# (style = "none", width = 0).
#
# `padding` is likewise sugar over the four `padding_<side>` scalars:
# a scalar applies to all four sides; a named vector
# (`c(top = 2, bottom = 8)`) maps each named side WITHOUT averaging.
# A nested list is rejected (use the named vector).
.expand_brdr_shorthand <- function(attrs, call) {
  sides <- c("top", "bottom", "left", "right")
  if (!is.null(attrs[["border"]])) {
    val <- attrs[["border"]]
    attrs[["border"]] <- NULL
    for (side in sides) {
      key <- paste0("border_", side)
      if (is.null(attrs[[key]])) {
        attrs[[key]] <- val
      }
    }
  }
  for (side in sides) {
    key <- paste0("border_", side)
    val <- attrs[[key]]
    if (is.null(val)) {
      next
    }
    if (is_brdr(val)) {
      attrs[[key]] <- NULL
      attrs[[paste0(key, "_style")]] <- val$style
      attrs[[paste0(key, "_width")]] <- val$width
      attrs[[paste0(key, "_color")]] <- val$color
      next
    }
    if (
      is.character(val) &&
        length(val) == 1L &&
        !is.na(val) &&
        val == "none"
    ) {
      attrs[[key]] <- NULL
      attrs[[paste0(key, "_style")]] <- "none"
      attrs[[paste0(key, "_width")]] <- 0
      next
    }
  }
  pv <- attrs[["padding"]]
  if (!is.null(pv)) {
    attrs[["padding"]] <- NULL
    if (is.numeric(pv) && length(pv) == 1L && is.null(names(pv))) {
      for (side in sides) {
        key <- paste0("padding_", side)
        if (is.null(attrs[[key]])) {
          attrs[[key]] <- pv
        }
      }
    } else if (is.numeric(pv) && !is.null(names(pv))) {
      for (side in intersect(names(pv), sides)) {
        attrs[[paste0("padding_", side)]] <- pv[[side]]
      }
    } else if (is.list(pv)) {
      cli::cli_abort(
        c(
          "Invalid {.arg padding} in {.fn style}.",
          "x" = "Nested lists are no longer supported.",
          "i" = "Use a scalar or a named vector, e.g. {.code padding = c(top = 5, bottom = 3)}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  attrs
}

# Build a style_node from a list of named attributes. Unknown
# attribute names warn (backend may still handle them); the warned
# attributes are dropped from the constructed node so the S7
# validator never sees a foreign property.
.build_style_node <- function(attrs, call) {
  attr_names <- names(attrs)
  unknown <- setdiff(attr_names, .style_node_fields)
  if (length(unknown) > 0L) {
    known_list <- .style_node_fields
    cli::cli_warn(
      c(
        "Unknown style attribute{?s}: {.val {unknown}}.",
        "i" = "These will not be applied by tabular. Recognised attributes: {.val {known_list}}."
      ),
      call = call
    )
  }
  recognised <- intersect(attr_names, .style_node_fields)
  values <- attrs[recognised]
  for (nm in intersect(
    names(values),
    c("blank_above", "blank_below")
  )) {
    v <- values[[nm]]
    if (is.numeric(v) && !is.integer(v) && all(is.na(v) | v == trunc(v))) {
      values[[nm]] <- as.integer(v)
    }
  }
  do.call(style_node, values)
}
