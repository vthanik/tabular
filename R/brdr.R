# brdr.R — small constructor for a single border-line specification.
#
# Mirrors huxtable's `brdr()` (constructor name lifted as proven
# naming); reshapes the triple (style, width, color) to the surface
# tabular's resolvers + `preset(borders = list(...))` ingest.
#
# The S3 class `tabular_brdr` is the value type users hand to
# `preset(borders = list(<region> = brdr(...)))`. The package-internal
# `.as_brdr_triple()` helper unwraps it back to the bare
# `list(style, width, color)` form `.effective_border()` already
# consumes; backends never see the S3 wrapper directly.
#
# Defaults — width = "thin" (0.5pt), style = "solid", color =
# "currentColor". These match the canonical submission Appendix I clinical baseline
# (thin solid black for header / footer / closing rules) without
# over-committing to a colour, which the consumer's CSS / Word
# theme resolves at render time.

# ---------------------------------------------------------------------
# Width keyword resolver
# ---------------------------------------------------------------------

# Maps the four named widths to numeric points; passes numeric
# inputs through unchanged after a non-negative check. Any other
# shape raises `tabular_error_input`.
.brdr_width_keywords <- c(
  hairline = 0.25,
  thin = 0.5,
  medium = 1,
  thick = 1.5
)

.resolve_brdr_width <- function(x, call) {
  if (is.numeric(x) && length(x) == 1L && !is.na(x)) {
    if (x < 0) {
      cli::cli_abort(
        c(
          "{.arg width} must be non-negative.",
          "x" = "You supplied {.val {x}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(as.numeric(x))
  }
  keywords <- names(.brdr_width_keywords)
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    idx <- match(x, keywords)
    if (!is.na(idx)) {
      return(unname(.brdr_width_keywords[[idx]]))
    }
    cli::cli_abort(
      c(
        "{.arg width} keyword {.val {x}} is not recognised.",
        "i" = "Use one of {.val {keywords}} or a numeric in points."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  cli::cli_abort(
    c(
      "{.arg width} must be a numeric point value or one of the keywords {.val {keywords}}.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# ---------------------------------------------------------------------
# brdr() constructor
# ---------------------------------------------------------------------

#' Border-line specification
#'
#' Build a small immutable record describing one border line —
#' width, style, and colour. A `brdr()` value is the stroke you hand
#' to the [`preset()`] `rules` knob (one entry per rule name, e.g.
#' `rules = list(midrule = brdr(width = 0.75))`) or to [`style()`]'s
#' border arguments (`style(border_top = brdr(...), .at =
#' cells_table(side = "rows"))`). Successive [`preset()`] calls layer
#' cleanly, so a one-off override composes onto a house-style template
#' without disturbing the other rules.
#'
#' @details
#'
#' **Surface.** A single `tabular_brdr` value is a length-3 named
#' list with class `"tabular_brdr"`: `list(style, width, color)`.
#' The shape is identical to the bare triple
#' [`style()`]'s per-side scalars accept, so the resolver in
#' `R/borders.R` can ingest either form transparently. Construct
#' with [`brdr()`]; test with [`is_brdr()`].
#'
#' **Width keywords.** `width` accepts either a numeric in points
#' (typical clinical values: 0.25, 0.5, 1, 1.5) or one of the four
#' named keywords:
#'
#' | keyword       | points  |
#' |---------------|---------|
#' | `"hairline"`  | 0.25    |
#' | `"thin"`      | 0.5     |
#' | `"medium"`    | 1       |
#' | `"thick"`     | 1.5     |
#'
#' Keywords resolve to numeric points immediately; the constructed
#' value carries a numeric `width`. Numeric inputs pass through
#' unchanged after a non-negative check.
#'
#' **Style enum.** `style` is one of `"solid"` (default),
#' `"dashed"`, `"dotted"`, `"double"`, `"dashdot"`, `"none"`.
#' `"none"` is the explicit clear-this-rule sentinel: setting a rule
#' to `brdr(style = "none")` (or the bare string `"none"`) in
#' [`preset()`]`(rules = list(...))` suppresses the baseline rule that
#' backend would otherwise draw.
#'
#' **Color.** Hex (`"#212529"`), CSS colour name (`"black"`,
#' `"slategray"`), the `"ink"` token (default; resolves to the
#' primary rule ink `#212529`, decoupled from the surrounding text
#' colour so a recoloured header keeps a neutral rule), or
#' `"currentColor"` (inherit the surrounding text colour per backend
#' convention — `w:color="auto"` in DOCX, the document text colour in
#' RTF, the CSS `currentColor` keyword in HTML).
#'
#' @param width *Stroke width.* `<numeric(1) | character(1)>:
#'   default `"thin"`*. Either a numeric in points (>= 0) or one of
#'   the four named keywords (`"hairline"`, `"thin"`, `"medium"`,
#'   `"thick"`).
#'
#' @param style *Line style.* `<character(1)>: default `"solid"`*.
#'   One of `"solid"`, `"dashed"`, `"dotted"`, `"double"`,
#'   `"dashdot"`, `"none"`.
#'
#' @param color *Stroke colour.* `<character(1)>: default
#'   `"currentColor"`*. Hex (`"#RRGGBB"`), CSS colour name, or
#'   `"currentColor"` to inherit the surrounding text colour.
#'
#' @param x *Any R object* — tested by `is_brdr()` for membership
#'   in the `tabular_brdr` S3 class.
#'
#' @return *A `tabular_brdr` S3 object* — a length-3 named list
#'   suitable for `preset(rules = list(<rule> = .))` or `style(border_*
#'   = .)`.
#'
#' @examples
#' # ---- Example 1: A house-style rule set ----
#' #
#' # The `rules` knob takes one brdr() value per rule name. Here a
#' # thick column-label divider (midrule), a hairline dotted rule
#' # between body rows (rowrule), and the muted spanner rule dropped.
#' # Unlisted rules keep their booktabs defaults.
#' demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(
#'   saf_aeoverall,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Overall Summary of Adverse Events",
#'     "Safety Population"
#'   ),
#'   footnotes = "Subjects counted once per category."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Category"),
#'     placebo    = col_spec(label = "Placebo\nN={demo_n['placebo']}"),
#'     drug_50    = col_spec(label = "Drug 50\nN={demo_n['drug_50']}"),
#'     drug_100   = col_spec(label = "Drug 100\nN={demo_n['drug_100']}"),
#'     Total      = col_spec(label = "Total\nN={demo_n['Total']}")
#'   ) |>
#'   preset(
#'     rules = list(
#'       midrule  = brdr(width = "thick"),
#'       rowrule  = brdr(width = "hairline", style = "dotted"),
#'       spanrule = "none"
#'     )
#'   )
#'
#' # ---- Example 2: Wrap a custom style into a reusable function ----
#' #
#' # The recommended way to share a rule style across many tables is to
#' # wrap the `preset()` call in a small function. A later `preset()` /
#' # `style()` call layers a one-off override cleanly on top.
#' custom_style <- function(spec) {
#'   spec |>
#'     preset(
#'       rules = list(
#'         toprule    = brdr(width = "thin", color = "#212529"),
#'         midrule    = brdr(width = "thin", color = "#212529"),
#'         bottomrule = brdr(width = "thin", color = "#212529")
#'       )
#'     )
#' }
#'
#' tabular(saf_n) |>
#'   custom_style() |>
#'   preset(rules = list(rowrule = brdr("hairline", "dashed")))
#'
#' # ---- Example 3: Width keyword vs numeric, every style enum value ----
#' #
#' # Width accepts both the four named keywords and a bare numeric
#' # in points; style accepts six enum values. Use `is_brdr()` to
#' # confirm the constructor returned a valid `tabular_brdr` rather
#' # than a fallback list.
#' for (w in c("hairline", "thin", "medium", "thick")) {
#'   cat(w, "=", brdr(width = w)$width, "pt\n")
#' }
#' is_brdr(brdr(width = 0.75))
#'
#' lapply(
#'   c("solid", "dashed", "dotted", "double", "dashdot", "none"),
#'   function(s) brdr(style = s)
#' )
#'
#' # ---- Example 4: A full grid via the body-edge style() path ----
#' #
#' # The `rules` knob covers the named booktabs anatomy; for the body
#' # outer frame and inter-column separators, hand brdr() to
#' # `style(.at = cells_table(side = ...))`. Here a medium outer frame
#' # plus hairline column separators on a demographics table.
#' tabular(saf_demo, titles = "Demographics with a full grid") |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   style(border = brdr(width = "medium"), .at = cells_table(side = "outer")) |>
#'   style(border_left = brdr("hairline"), .at = cells_table(side = "cols"))
#'
#' @seealso
#' **Where to attach:** [`preset()`]'s `rules` knob (one brdr() per
#'   rule name) and [`style()`]'s `border_*` arguments.
#'
#' **Per-cell predicates:** [`style()`] accepts the same per-side
#' `border_<side>_{style,width,color}` triples without going through
#' `brdr()`.
#'
#' **Resolver internals:** [`tabular_classes`] (`style_node`'s 12
#' border scalars).
#'
#' @export
brdr <- function(
  width = "thin",
  style = "solid",
  color = "ink"
) {
  call <- rlang::caller_env()
  resolved_width <- .resolve_brdr_width(width, call = call)
  allowed_styles <- .border_style_values
  if (
    !is.character(style) ||
      length(style) != 1L ||
      is.na(style) ||
      !(style %in% allowed_styles)
  ) {
    cli::cli_abort(
      c(
        "{.arg style} must be one of {.val {allowed_styles}}.",
        "x" = "You supplied {.obj_type_friendly {style}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (
    !is.character(color) ||
      length(color) != 1L ||
      is.na(color) ||
      !nzchar(color)
  ) {
    cli::cli_abort(
      c(
        "{.arg color} must be a length-1, non-empty character.",
        "x" = "You supplied {.obj_type_friendly {color}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  out <- list(style = style, width = resolved_width, color = color)
  class(out) <- "tabular_brdr"
  out
}

#' @rdname brdr
#' @export
is_brdr <- function(x) inherits(x, "tabular_brdr")

# Unwrap a `tabular_brdr` (or pass through a bare triple list) to
# the `list(style, width, color)` shape `.effective_border()`
# consumes. NULL passes through (caller treats as "clear" or
# "inherit" depending on context).
.as_brdr_triple <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is_brdr(x)) {
    return(unclass(x))
  }
  # A bare list with the three slots is accepted for symmetry with
  # style_node's per-side scalars; the resolver tolerates NULL on
  # any slot by filling defaults.
  if (
    is.list(x) &&
      all(c("style", "width", "color") %in% names(x))
  ) {
    return(x)
  }
  NULL
}

# Pretty-printer for tabular_brdr — keeps the inspect output compact
# instead of dumping the underlying list.
#' @export
#' @noRd
print.tabular_brdr <- function(x, ...) {
  cat(sprintf(
    "<tabular_brdr> %gpt %s %s\n",
    x$width %||% NA_real_,
    x$style %||% NA_character_,
    x$color %||% NA_character_
  ))
  invisible(x)
}
