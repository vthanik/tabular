# style_template.R — composable container for accumulating
# `style_layer` records OUTSIDE a `tabular_spec`. Lets a sponsor
# build a "house style" once with the same `style()` verb used per
# table, then attach it to `preset()` / `set_preset()` so every
# downstream `tabular()` chain inherits the same visual identity.
#
# Shape: a small S3 record carrying a single `layers` slot. The
# `style()` verb (in R/style.R) recognises `tabular_style_template`
# as a valid first argument (in place of `tabular_spec`) and appends
# style_layer records to the template instead of to a spec.

#' Reusable style template (for house-style presets)
#'
#' Build a reusable, composable style template by chaining
#' [`style()`] calls against a `tabular_style_template`. The
#' template carries an ordered list of [`style_layer`] records and
#' can be attached to [`preset()`] / [`set_preset()`] as a `style =`
#' argument — every downstream [`tabular()`] chain then inherits the
#' template's layers via the engine cascade.
#'
#' @details
#'
#' **One verb, two surfaces.** The same `style(.spec_or_template,
#' ..., at = ...)` call that attaches a layer to a per-table spec
#' also accumulates layers onto a template. Symmetric API — no need
#' to learn a second function for the multi-table use case.
#'
#' **Submission workflow.** A submission typically renders 100–200
#' tables with one visual identity. Build the template once at the
#' top of the submission script, pass it to `set_preset(style =
#' template)`, and every subsequent `tabular()` produces output that
#' inherits the same column-header rules, group-header bolding,
#' title spacing, and outer-frame borders without a single per-table
#' `style()` call.
#'
#' **Cascade order.** Engines apply layers low-to-high priority:
#' backend defaults → session preset's `@style` → spec preset's
#' `@style` → per-spec `style()` layers. Later layers override prior
#' ones per attribute; NA fields leave the prior layer's value in
#' place.
#'
#' @param x *Any R object.* The predicate inspects the class via
#'   [`inherits()`]; no other introspection is performed.
#'
#' @return *A `tabular_style_template`* — a small S3 list with a
#'   `layers` slot. Pipe through [`style()`] to add layers.
#'
#' @examples
#' # ---- Sponsor "house style" composed once ----
#' #
#' # The result becomes the default look for every table rendered
#' # against this preset. No per-table style() boilerplate.
#' house <- style_template() |>
#'   style(bold = TRUE, at = cells_headers(level = -1)) |>
#'   style(bold = TRUE, at = cells_group_headers()) |>
#'   style(
#'     border_top    = brdr("thick", "double"),
#'     border_bottom = brdr("thick", "double"),
#'     at = cells_headers()
#'   ) |>
#'   style(blank_above = 1, blank_below = 1, at = cells_title())
#'
#' length(house$layers)
#'
#' # ---- Verify class ----
#' is_style_template(house)
#'
#' @seealso
#' **Style verb:** [`style()`] — the same verb chains onto a spec or
#' a template.
#'
#' **Locations:** [`cells_body`] — locations that name the *where*
#' half of every layer.
#'
#' @export
style_template <- function() {
  structure(
    list(layers = list()),
    class = c("tabular_style_template", "list")
  )
}

#' @rdname style_template
#' @export
is_style_template <- function(x) {
  inherits(x, "tabular_style_template")
}

# Append a style_layer record to a template. Internal — `style()`
# calls this when its first argument is a `tabular_style_template`.
.style_template_add_layer <- function(template, layer) {
  template$layers <- c(template$layers, list(layer))
  template
}

# Pretty-printer — compact summary of the layer count + first few
# surfaces so users can introspect a template at the REPL.
#' @export
#' @noRd
print.tabular_style_template <- function(x, ...) {
  n <- length(x$layers)
  cat(sprintf(
    "<tabular_style_template: %d layer%s>\n",
    n,
    if (n == 1L) "" else "s"
  ))
  if (n == 0L) {
    return(invisible(x))
  }
  for (i in seq_along(x$layers)) {
    layer <- x$layers[[i]]
    loc <- if (S7::S7_inherits(layer, style_layer)) layer@location else NULL
    surface <- if (!is.null(loc)) loc$surface else "<unknown>"
    cat(sprintf("  %d. %s\n", i, surface))
  }
  invisible(x)
}
