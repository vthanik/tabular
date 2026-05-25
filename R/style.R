# style.R — unified styling verb. Each style() call adds one record
# to the styles container; multiple calls accumulate; the engine
# resolves the cascade at render time.
#
# Two paths share one verb signature:
#
#   1. Layer path (preferred). `style(spec, ..., at = cells_*())`
#      appends a `style_layer` to `spec@styles@layers`. The location
#      object (`cells_body`, `cells_headers`, `cells_table`, ...) names
#      the surface; engines switch on `location$surface` to route the
#      style to the right code path.
#
#   2. Predicate path (legacy). `style(spec, where = ..., ..., .scope =
#      ...)` appends a `style_predicate` to `spec@styles@predicates`.
#      This is the original API — preserved for back-compat while
#      callers migrate to `cells_body(where = ..., i = ..., j = ...)`.
#
# The first argument also accepts a `tabular_style_template` (built
# by [`style_template()`]). When given, layers accumulate onto the
# template's `layers` slot instead of a spec. Same verb, same
# attribute names — symmetric API for per-table vs house-style
# composition.

#' Style cells, rows, or columns by predicate
#'
#' Attach a `style_predicate` to a `tabular_spec`. The predicate
#' (`where`) is captured as an rlang quosure and evaluated at engine
#' time against the post-[`derive()`] data grid; rows where the
#' predicate is TRUE pick up the styling attributes given in `...`.
#' Use this for subtotal-row highlighting, threshold-coloured
#' p-values, banded-row backgrounds, and any other rule-driven
#' formatting that depends on cell values rather than position.
#'
#' @details
#'
#' **Multiple calls accumulate.** Each `style()` call adds one
#' predicate to the spec's predicate list. The engine applies them
#' in declaration order at render time; later predicates win for
#' overlapping cells. Field-level merge: only non-NA attributes on
#' the incoming style override; NA leaves the prior value intact.
#'
#' **Cascade order.** The full style cascade (lowest to highest
#' precedence) is: backend defaults -> preset ->
#' `style_spec$defaults` -> `style_spec$cols` ->
#' `style_spec$headers` -> `style_spec$predicates`. `style()`
#' populates only the predicates layer; the upper layers (defaults /
#' cols / headers) land with `preset()` and [`col_spec()`]
#' integration in later steps.
#'
#' @section Scope semantics:
#'
#' *   **`.scope = "cell"`** (default) — predicate evaluates to a
#'     length-`nrow` logical. Style applies to cells in the columns
#'     the `where` expression *references*, intersected with
#'     `.spec@data` column names. If no data columns are referenced,
#'     falls back to all columns (same as `"row"`). The natural
#'     default for value-based highlighting like
#'     `where = pvalue < 0.05` — only the `pvalue` cells go red.
#' *   **`.scope = "row"`** — predicate evaluates to a length-`nrow`
#'     logical. Style applies to EVERY cell in the matching rows.
#'     Use for whole-row formatting like subtotal bolding or
#'     alternating-row backgrounds.
#' *   **`.scope = "col"`** — reserved; raises `tabular_error_input`
#'     at engine time in the current release. Use a per-[`col_spec()`]
#'     style declaration (planned post-v0.1.0) for whole-column
#'     styling.
#'
#' @param .spec *The `tabular_spec` to attach the predicate to.*
#'   `<tabular_spec>: required`. Dot-prefixed so R's partial argument
#'   matching cannot accidentally bind a short attribute name in
#'   `...` to the spec slot.
#'
#' @param where *Predicate evaluating to a length-`nrow` logical.*
#'   `<expression>: required`. Captured as an rlang quosure;
#'   evaluated at engine time against the post-[`derive()`] data
#'   grid, so the predicate may reference any column in `.spec@data`
#'   or any column added by [`derive()`].
#'
#'   **Tip:** With `.scope = "cell"` (the default), the engine
#'   extracts column names referenced by the expression to decide
#'   which cells to paint. `where = pvalue < 0.05` therefore paints
#'   only the `pvalue` column's cells in matching rows.
#'
#' @param ... *Named style attributes.* At least one required.
#'   Recognised attributes: `bold`, `italic`, `underline`, `color`,
#'   `background`, `font_family`, `font_size`, `rule_above`,
#'   `rule_below`, `border_left`, `border_right`, `padding`,
#'   `blank_after`, `pretext`, `posttext`, `halign`, `valign`,
#'   and the per-side border triple
#'   `border_{top,bottom,left,right}_{style,width,color}` (12
#'   scalars).
#'
#'   `halign` is one of `"left"`, `"center"`, `"right"`. `valign`
#'   is one of `"top"`, `"middle"`, `"bottom"`. Per-cell alignment
#'   overrides win over [`col_spec()`] column defaults, which in
#'   turn override [`preset()`] body defaults.
#'
#'   `border_<side>_style` is one of `"solid"`, `"dashed"`,
#'   `"dotted"`, `"double"`, `"dashdot"`, `"none"`.
#'   `border_<side>_width` is a non-negative numeric in points
#'   (typical clinical values: 0.25, 0.5, 1, 1.5).
#'   `border_<side>_color` is a hex `"#RRGGBB"`, a CSS colour name,
#'   or `"currentColor"`. The Boolean knobs (`rule_above`,
#'   `rule_below`, `border_left`, `border_right`) remain available
#'   as a shorthand for `("solid", 0.5pt, default colour)`.
#'
#'   **Note:** Unknown attribute names warn and are silently dropped
#'   (they do NOT pass through to the backend).
#'
#' @param at *Location target via the `cells_*()` vocabulary.*
#'   `<tabular_location | NULL>: default NULL`. Mutually exclusive
#'   with `where`. When supplied, the style attributes apply to the
#'   region named by the location: body cells ([`cells_body()`]),
#'   column-header bands ([`cells_headers()`]), subgroup banners
#'   ([`cells_subgroup_labels()`]), title, footnotes, page-head /
#'   page-foot slots, or table edges ([`cells_table()`]). See
#'   [`cells`] for the full vocabulary.
#'
#' @param .scope *Targeting scope.*
#'   `<character(1)>: default "cell"`. One of `"cell"`, `"row"`,
#'   `"col"`. See the Scope semantics section.
#'
#'   **Restriction:** `"col"` raises `tabular_error_input` in the
#'   current release; planned post-v0.1.0.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`paginate()`], [`preset()`], then render via [`emit()`] (or
#'   resolve without I/O via [`as_grid()`]).
#'
#' @examples
#' # ---- Example 1: Subtotal rows bolded and ruled, overall row shaded ----
#' #
#' # AE-by-SOC/PT table where the SOC-level subtotal rows are bolded
#' # with a top rule (visual separator from the PT-level detail rows
#' # below) and the overall "TOTAL SUBJECTS WITH AN EVENT" row gets
#' # bold text on a light-gray background. Two row-scoped predicates
#' # applied in declaration order.
#' ae <- saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Subjects are counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     soc      = col_spec(usage = "group", label = "SOC / PT"),
#'     pt       = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
#'   ) |>
#'   headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   style(where = row_type == "soc",     bold = TRUE, rule_above = TRUE, .scope = "row") |>
#'   style(where = row_type == "overall", bold = TRUE, background = "lightgray", .scope = "row")
#'
#' # ---- Example 2: Derived ORR / DCR rows highlighted in efficacy table ----
#' #
#' # Efficacy BOR table where the derived ORR / DCR summary rows
#' # (`row_type == "derived"`) are bolded and ruled above to set them
#' # apart from the BOR-category rows. Single row-scoped predicate.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "Objective Response Rate (CR + PR)",
#'   "Disease Control Rate (CR + PR + SD)"
#' )
#' eff <- eff_resp
#' eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#'
#' tabular(
#'   eff,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Best Overall Response and Response Rates",
#'     sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
#'   ),
#'   footnotes = "Response per RECIST 1.1, investigator assessment."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Response"),
#'     row_type   = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
#'   ) |>
#'   sort_rows(by = "stat_label") |>
#'   style(where = row_type == "derived", bold = TRUE, rule_above = TRUE, .scope = "row")
#'
#' # ---- Example 3: Per-side cell borders + alignment override ----
#' #
#' # Vital-signs summary where the `Mean (SD)` row across all
#' # parameters carries a thick top border (separating it from the
#' # `n` row above) and the body of those cells is centre-aligned
#' # rather than the column-level default. Two style calls in a
#' # row show the predicate cascade: first call paints the border,
#' # second adds the per-cell halign override on the same predicate.
#' vit <- saf_vital
#'
#' tabular(
#'   vit,
#'   titles = c("Table 14.4.1", "Vital Signs Summary at Each Visit")
#' ) |>
#'   cols(
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     paramcd    = col_spec(visible = FALSE),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal")
#'   ) |>
#'   style(
#'     where = stat_label == "Mean (SD)",
#'     border_top_style = "solid",
#'     border_top_width = 1,
#'     .scope = "row"
#'   ) |>
#'   style(
#'     where = stat_label == "Mean (SD)",
#'     halign = "center",
#'     .scope = "row"
#'   )
#'
#' # ---- Example 4: Banded-row backgrounds via row-scope predicate ----
#' #
#' # Apply a soft grey background to every other body row. The
#' # predicate runs against the data grid (`seq_len(nrow(.spec@data))`
#' # mod 2), and `.scope = "row"` paints the matching rows wall-to-wall.
#' # Standard zebra-striping pattern for long tables.
#' tabular(saf_demo, titles = "Demographics with banded rows") |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   style(
#'     where = seq_len(nrow(saf_demo)) %% 2 == 0,
#'     background = "#f2f2f2",
#'     .scope = "row"
#'   )
#'
#' @seealso
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`derive()`], [`paginate()`],
#' [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' **Inline pretext / posttext formatting:** [`md()`], [`html()`].
#'
#' @export
style <- function(.spec, where, ..., at = NULL, .scope = "cell") {
  call <- rlang::caller_env()

  is_template <- is_style_template(.spec)
  if (!is_template) {
    check_tabular_spec(.spec, call = call)
  }

  where_quo <- rlang::enquo(where)
  has_where <- !rlang::quo_is_missing(where_quo)
  has_at <- !is.null(at)

  if (has_at && has_where) {
    cli::cli_abort(
      c(
        "Pass only one of {.arg at} and {.arg where}.",
        "i" = "Use {.arg at} for the location vocabulary, {.arg where} for the legacy predicate path."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (has_at) {
    if (!is_tabular_location(at)) {
      cli::cli_abort(
        c(
          "{.arg at} must be a {.cls tabular_location}.",
          "x" = "You supplied {.obj_type_friendly {at}}.",
          "i" = "Build one with {.fn cells_body} / {.fn cells_headers} / etc."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
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

  if (has_at) {
    layer <- style_layer(location = at, style = node)
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
    return(S7::set_props(.spec, styles = updated))
  }

  if (is_template) {
    cli::cli_abort(
      c(
        "{.arg at} is required when piping through a {.cls tabular_style_template}.",
        "i" = "The legacy {.arg where} path is for {.cls tabular_spec} only."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (!has_where) {
    cli::cli_abort(
      c(
        "Specify one of {.arg at} or {.arg where}.",
        "i" = "Use {.code at = cells_body()} (preferred) or {.code where = <predicate>}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  scope_val <- check_enum(.scope, .scope_values, arg = ".scope", call = call)
  pred <- style_predicate(
    where = where_quo,
    style = node,
    scope = scope_val
  )

  current <- .spec@styles
  if (!is_style_spec(current)) {
    current <- style_spec()
  }
  updated <- S7::set_props(
    current,
    predicates = c(current@predicates, list(pred))
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
  "rule_above",
  "rule_below",
  "border_left",
  "border_right",
  "padding",
  "blank_after",
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
# Convenience sugar: a user writing
#   style(border_top = brdr("thick", "double"), ...)
# wants the three scalars `border_top_style` / `border_top_width` /
# `border_top_color` populated from one brdr value. Same for
# `border = brdr(...)` (sets all four sides) and the legacy
# Boolean knobs `rule_above` / `rule_below` / `border_left` /
# `border_right` (already accepted as TRUE / FALSE by the engine).
#
# A `"none"` literal string is also accepted as shorthand for "kill
# the border on this side" — expands to (style = "none", width = 0).
.expand_brdr_shorthand <- function(attrs, call) {
  sides <- c("top", "bottom", "left", "right")
  # Umbrella `border = ...` — set all four sides if user didn't
  # already pass a per-side override.
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
  # Per-side `border_top = brdr(...)` / `border_top = "none"` etc.
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
    # Leave alone — could still be a legacy Boolean ("rule_above" et
    # al. flow through here unchanged on the Boolean knobs).
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
  # Coerce numeric -> integer for integer-typed slots so users can
  # write `blank_above = 1` without a literal `1L`.
  for (nm in intersect(
    names(values),
    c("blank_after", "blank_above", "blank_below")
  )) {
    v <- values[[nm]]
    if (is.numeric(v) && !is.integer(v) && all(is.na(v) | v == trunc(v))) {
      values[[nm]] <- as.integer(v)
    }
  }
  do.call(style_node, values)
}
