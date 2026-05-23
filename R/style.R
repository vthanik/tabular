# style.R — predicate-targeted styling verb. Each style() call adds
# one style_predicate to spec@styles@predicates. Multiple calls
# accumulate; the engine resolves the cascade at render time. The
# verb captures `where` as a quosure so the predicate environment
# travels with it; engine_style evaluates against the post-engine
# data grid (so user predicates may reference derived columns).

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
#'   `blank_after`, `pretext`, `posttext`.
#'
#'   **Note:** Unknown attribute names warn and are silently dropped
#'   (they do NOT pass through to the backend).
#'
#' @param .scope *Targeting scope.*
#'   `<character(1)>: default "cell"`. One of `"cell"`, `"row"`,
#'   `"col"`. See the Scope semantics section.
#'
#'   **Restriction:** `"col"` raises `tabular_error_input` in the
#'   current release; planned post-v0.1.0.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with the
#'   eventual `emit()` verb.
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
#' @seealso
#' **Sibling build verbs:** [`cols()`] / [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`derive()`].
#'
#' **Entry verb:** [`tabular()`].
#'
#' @export
style <- function(.spec, where, ..., .scope = "cell") {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  scope_val <- check_enum(.scope, .scope_values, arg = ".scope", call = call)

  where_quo <- rlang::enquo(where)
  if (rlang::quo_is_missing(where_quo)) {
    cli::cli_abort(
      c(
        "{.arg where} is required.",
        "i" = "Pass an expression that evaluates to a length-{.code nrow} logical vector."
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

  node <- .build_style_node(attrs, call = call)

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
  "pretext",
  "posttext"
)

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
  do.call(style_node, attrs[recognised])
}
