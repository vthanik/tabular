# aaa_class.R — S7 class declarations for tabular's internal IR.
#
# Loaded first (aaa_ prefix) so subsequent files can register methods
# against these classes. The IR is display-side only: pre-summarised
# data in, rendered file out. We DO NOT model aggregation, filtering,
# weighting, or row-generating subtotals — users do that upstream.
#
# Conventions follow ggplot2 (rstudio/ggplot2/R/all-classes.R) and
# S7 best practice: one class per concept, typed properties, no
# methods on the class itself (dispatch via `S7::method(generic,
# class) <- ...` in dedicated files).
#
# Reference: ~/.claude/projects/.../memory/reference_proc_report_bible.md
# and the package boundary memo (feedback_package_boundary.md).

# ---------------------------------------------------------------------
# Helper enums (character vectors used by validators)
# ---------------------------------------------------------------------

# Cross-platform single-quote wrapper for values in error messages.
# Base R's `shQuote()` defaults to `type = "sh"` on Unix (single
# quotes) and `type = "cmd"` on Windows (double quotes), which makes
# snapshot tests fail on the Windows CI runner. Force "sh" here so
# every validator emits stable single-quoted output regardless of OS.
.sh_quote <- function(x) shQuote(x, type = "sh")

.col_usage_values <- c("display", "group")

# Recognised values for `col_spec@group_display`. Active only when
# `col_spec@usage = "group"`; ignored otherwise. Controls how the
# group-variable's unique values render in the body:
#
#   "header_row" (default) — each unique value emits as a section
#                            header row spanning the visible
#                            columns; the source column is hidden
#                            from the body. Matches the canonical
#                            submission Appendix I shape used by
#                            every clinical-TFL house template.
#   "column"               — column stays visible; repeated values
#                            are suppressed (only the first row of
#                            each value shows the label).
#   "column_repeat"        — column stays visible; every row repeats
#                            the value (no suppression).
.col_group_display_values <- c("header_row", "column", "column_repeat")
.align_values <- c("left", "center", "right", "decimal")

# Predicate for the "auto" width sentinel. `col_spec@width` is
# polymorphic: literal "auto" (default), positive numeric (inches),
# parseable dim string ("2.5in" / "60mm"), or percent string ("30%").
# NA / NULL are rejected by the validator — there is no NA-aware
# path anymore.
.is_auto_width <- function(x) {
  identical(x, "auto")
}
.scope_values <- c("cell", "row", "col")
.orientation_values <- c("portrait", "landscape")
.paper_size_values <- c("letter", "a4")
.hlines_values <- c("header", "none", "all")
.align_anchor_values <- c("left", "center", "right")
.valign_values <- c("top", "middle", "bottom")
.decimal_metrics_values <- c("chars", "afm", "systemfonts")
.chrome_onscreen_values <- c("auto", "off")

# Recognised values for `preset_spec@width_mode`. Table-level
# column-sizing policy that mirrors Word's Table Layout menu
# (Auto-fit Contents / Auto-fit Window / Fixed Column Width):
#
#   "content" (default) — Each column auto-sized to max(body, header).
#                         The table doesn't fill the page. Today's
#                         behavior; equivalent to Word's "Auto-fit
#                         Contents".
#   "window"            — Auto-sized columns expand to fill the
#                         residual page width equally. Pinned and
#                         percent columns keep their pins; the rest
#                         share what's left. Word's "Auto-fit Window".
#   "fixed"             — Use only explicit per-column widths.
#                         Auto-sized columns collapse to the minimum
#                         (`.min_auto_width_in`). The table doesn't
#                         auto-expand. Word's "Fixed Column Width".
.preset_width_mode_values <- c("content", "window", "fixed")

# Recognised line styles on the new border_{side}_style scalars.
# "none" is the explicit clear-this-border sentinel; the back-compat
# Boolean knobs (rule_above / border_left / etc.) map to "solid"
# when TRUE. "dashdot" is the SAS-ODS extension we lift verbatim.
.border_style_values <- c(
  "solid",
  "dashed",
  "dotted",
  "double",
  "dashdot",
  "none"
)

# Recognised region keys on `preset_spec@borders`. The vocabulary
# covers every visual rule the canonical submission page layout
# can carry, split across body regions (interpreted by
# `engine_borders()` onto the `cells_style` matrix) and chrome
# regions (interpreted by `engine_chrome_borders()` onto the
# `chrome_style$borders` sidecar — `R/chrome_style.R`):
#
#   Body regions (cells_style):
#     outer, outer_{top,bottom,left,right}
#     body_top / body_bottom (aliases for outer_top / outer_bottom)
#     body_rows / body_cols  (interior separators)
#
#   Chrome regions (chrome_style$borders):
#     pagehead_bottom                   bottom edge of the page-head band
#     header_top / header_bottom        top + bottom of the column-header block
#     header_between                    between rows of a multi-band header
#     subgroup_top / subgroup_bottom    around the subgroup banner row
#     subgroup                          legacy alias for `subgroup_bottom`
#     footer_top / footer_bottom        around the footnote block
#     pagefoot_top                      top edge of the page-foot band
.preset_border_regions <- c(
  # Body regions
  "outer",
  "outer_top",
  "outer_bottom",
  "outer_left",
  "outer_right",
  "body_top",
  "body_bottom",
  "body_rows",
  "body_cols",
  # Chrome regions
  "pagehead_bottom",
  "header_top",
  "header_bottom",
  "header_between",
  "subgroup_top",
  "subgroup_bottom",
  "subgroup",
  "footer_top",
  "footer_bottom",
  "pagefoot_top"
)

# Recognised surface keys on `preset_spec@fonts`. Each surface gets
# a named list (family / size / weight); the engine_style cascade
# applies it to the cells in that surface as a theme-default layer.
.preset_font_surfaces <- c(
  "body",
  "header",
  "titles",
  "footnotes",
  "subgroup"
)

# Recognised token keys for the `preset(colors = list(...))` knob.
# Each token lowers through `.preset_args_to_layers()` to a per-cell
# `style_node` attribute on `cells_body()`; there is no slot on
# `preset_spec` after the Task 4/5 cut. The legacy `border` /
# `border_muted` tokens dropped — use
# `style(at = cells_table(side = "rows"), border_top = brdr(color = ...))`
# (and analogous outer / cols variants) instead. `text_muted` dropped
# (no backend ever consumed it).
.preset_color_tokens <- c(
  "text",
  "background"
)

# Recognised surface keys on `preset_spec@padding`. Numeric points;
# a scalar applies symmetrically to all four sides; a named list of
# top/right/bottom/left gives granular control.
.preset_padding_surfaces <- c(
  "body",
  "header",
  "titles",
  "footnotes",
  "subgroup"
)

# Recognised keys for the `preset(alignment = list(...))` knob. Each
# entry pairs with a value-set drawn from `.align_anchor_values`
# (left/center/right) for `_halign` and `.valign_values`
# (top/middle/bottom) for `_valign`. Every key is scalar-only after
# the Task 4/5 cut — vector-form alignment (per-title-line halign)
# is no longer expressible at the cascade surface.
.preset_alignment_keys_halign <- c(
  "title_halign",
  "footnote_halign",
  "subgroup_halign",
  "header_halign",
  "body_halign"
)
.preset_alignment_keys_valign <- c(
  "title_valign",
  "footnote_valign",
  "subgroup_valign",
  "header_valign",
  "body_valign"
)
.preset_alignment_keys <- c(
  .preset_alignment_keys_halign,
  .preset_alignment_keys_valign
)

# Recognised inline-formatting run types. Each element of an
# `inline_ast@runs` list is a named-list record with a `type` field
# drawn from this set. Backends iterate the runs and emit
# destination-specific markup.
.inline_run_types <- c(
  "plain",
  "bold",
  "italic",
  "sup",
  "sub",
  "code",
  "link",
  "span",
  "newline"
)

# ---------------------------------------------------------------------
# col_spec — 7-field per-column DSL
# ---------------------------------------------------------------------
#
# The S7 class binding is .col_spec_class (internal); the user-facing
# constructor `col_spec()` lives in R/col_spec.R and wraps this with
# cli-friendly tabular_error_input errors.

#' tabular S7 classes
#'
#' S7 class definitions backing tabular's display-side IR. Users do
#' not construct these directly except for [`col_spec()`]; every
#' other class is built and chained by the verb pipeline
#' ([`tabular()`] -> [`cols()`] -> [`headers()`] -> [`sort_rows()`]
#' -> [`style()`] -> [`paginate()`] -> [`preset()`] -> [`as_grid()`]
#' / [`emit()`]).
#'
#' @details
#'
#' The class set is intentionally small (~11 concepts) so the IR
#' fits in one mental model:
#'
#' | class               | role                                                  | constructor                       |
#' |---------------------|-------------------------------------------------------|-----------------------------------|
#' | `tabular_spec`      | root container; carries data + every other spec slot  | [`tabular()`]                     |
#' | `col_spec`          | per-column DSL (usage, label, format, align, ...)     | [`col_spec()`]                    |
#' | `header_node`       | one node in the multi-level header tree               | internal — built by [`headers()`] |
#' | `sort_spec`         | sort keys + per-key direction                         | internal — built by [`sort_rows()`]|
#' | `style_node`        | one resolved style attribute set (per-cell)           | internal — built by [`style()`]   |
#' | `style_predicate`   | (legacy) one `where` quosure + scope + style_node     | internal — built by [`style()`]   |
#' | `style_layer`       | one `tabular_location` + style_node                   | internal — built by [`style()`]   |
#' | `style_spec`        | the cascade root (defaults + cols + headers + layers) | internal — built by [`style()`]   |
#' | `pagination_spec`   | page-split policy (keep_together, panels, floors)     | internal — built by [`paginate()`]|
#' | `preset_spec`       | render geometry (paper, orientation, font, margins)   | internal — built by [`preset()`]  |
#' | `inline_ast`        | parsed inline-formatting AST (runs of bold / sup / …) | internal — built by `parse_inline()`|
#' | `tabular_grid`      | resolved per-page cells + ASTs + styles + headers     | [`as_grid()`]                     |
#'
#' Every spec slot is typed: a verb that would mutate a slot to an
#' invalid value fails at construction time (the S7 validator runs
#' as a last-line defense behind the cli-friendly verb-level
#' validators).
#'
#' **Class predicates.** Each class has a matching `is_<name>()`
#' predicate; see [`tabular_predicates`] for the full list.
#'
#' @seealso
#' **Class predicates:** [`tabular_predicates`].
#'
#' **Pipeline entry verbs:** [`tabular()`], [`as_grid()`],
#' [`emit()`].
#'
#' @keywords internal
#' @name tabular_classes
NULL

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
.col_spec_class <- S7::new_class(
  "col_spec",
  package = "tabular",
  properties = list(
    name = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    label = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    usage = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    format = S7::class_any,
    visible = S7::new_property(
      S7::class_logical,
      default = TRUE
    ),
    width = S7::new_property(
      S7::class_any,
      default = "auto"
    ),
    group_display = S7::new_property(
      S7::class_character,
      default = "header_row"
    ),
    group_skip = S7::new_property(
      S7::class_logical,
      default = NA
    ),
    align = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    valign = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    na_text = S7::new_property(
      S7::class_character,
      default = ""
    )
  ),
  validator = function(self) {
    if (!is.na(self@usage) && !(self@usage %in% .col_usage_values)) {
      return(paste0(
        "@usage must be one of ",
        paste(.sh_quote(.col_usage_values), collapse = ", "),
        "; got ",
        .sh_quote(self@usage)
      ))
    }
    if (!is.na(self@align) && !(self@align %in% .align_values)) {
      return(paste0(
        "@align must be one of ",
        paste(.sh_quote(.align_values), collapse = ", "),
        "; got ",
        .sh_quote(self@align)
      ))
    }
    if (!is.na(self@valign) && !(self@valign %in% .valign_values)) {
      return(paste0(
        "@valign must be one of ",
        paste(.sh_quote(.valign_values), collapse = ", "),
        "; got ",
        .sh_quote(self@valign)
      ))
    }
    if (!.is_auto_width(self@width)) {
      # Reject the dropped NA / NULL escape hatches up front so
      # S7's coercion path doesn't try to feed a wrong-type value
      # into `.parse_dim`.
      if (
        is.null(self@width) || (length(self@width) == 1L && is.na(self@width))
      ) {
        return(
          "@width cannot be NA or NULL; use \"auto\" (default) or pin a value"
        )
      }
      # `.parse_dim` validates type + bounds + unit; if it doesn't
      # error, the value is well-formed. Catch its cli_abort and
      # surface a validator-flavoured message so S7's wrapper says
      # "object is invalid" instead of a raw cli error.
      parsed <- tryCatch(
        .parse_dim(self@width, allow_percent = TRUE),
        tabular_error_input = function(e) e
      )
      if (inherits(parsed, "tabular_error_input")) {
        return(conditionMessage(parsed))
      }
      # Column widths must be strictly positive.
      if (parsed$value <= 0) {
        return(
          "@width must be positive when set; use visible = FALSE to hide"
        )
      }
    }
    if (length(self@na_text) != 1L) {
      return("@na_text must be length 1")
    }
    if (
      length(self@group_display) != 1L ||
        is.na(self@group_display) ||
        !(self@group_display %in% .col_group_display_values)
    ) {
      return(paste0(
        "@group_display must be one of ",
        paste(.sh_quote(.col_group_display_values), collapse = ", "),
        "; got ",
        .sh_quote(self@group_display)
      ))
    }
    if (length(self@group_skip) != 1L) {
      return("@group_skip must be length 1 (TRUE / FALSE / NA)")
    }
    NULL
  }
)

# ---------------------------------------------------------------------
# header_node — recursive multi-level header hierarchy
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
header_node <- S7::new_class(
  "header_node",
  package = "tabular",
  properties = list(
    label = S7::new_property(S7::class_character, default = NA_character_),
    span = S7::new_property(S7::class_character, default = character()),
    children = S7::new_property(S7::class_list, default = list()),
    style = S7::class_any
  )
)

# ---------------------------------------------------------------------
# sort_spec
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
sort_spec <- S7::new_class(
  "sort_spec",
  package = "tabular",
  properties = list(
    by = S7::new_property(S7::class_character, default = character()),
    descending = S7::new_property(S7::class_logical, default = FALSE)
  )
)

# ---------------------------------------------------------------------
# subgroup_spec — partition the report by one or more variables
# ---------------------------------------------------------------------
#
# When set on a tabular_spec, the engine partitions @data by the
# crossing of `@vars`, runs the full pipeline per group, and
# concatenates the resulting page sets with a hard page break
# between groups. Each page descriptor of the merged grid carries
# the per-group subgroup_value_str / subgroup_label_str so backends
# can emit the centred banner row above the column-header rule.

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
subgroup_spec <- S7::new_class(
  "subgroup_spec",
  package = "tabular",
  properties = list(
    by = S7::new_property(S7::class_character, default = character()),
    label = S7::class_any
  ),
  validator = function(self) {
    if (anyNA(self@by)) {
      return("@by must not contain NA")
    }
    if (length(self@by) > 0L && any(!nzchar(self@by))) {
      return("@by must not contain empty strings")
    }
    if (!is.null(self@label)) {
      if (
        !is.character(self@label) ||
          length(self@label) != 1L ||
          is.na(self@label)
      ) {
        return(
          "@label must be NULL or a length-1 non-NA character (glue-style template)"
        )
      }
    }
    NULL
  }
)

# ---------------------------------------------------------------------
# style_node — the flat attribute record applied to cells/rows/cols
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
style_node <- S7::new_class(
  "style_node",
  package = "tabular",
  properties = list(
    bold = S7::new_property(S7::class_any, default = NA),
    italic = S7::new_property(S7::class_any, default = NA),
    underline = S7::new_property(S7::class_any, default = NA),
    color = S7::new_property(S7::class_character, default = NA_character_),
    background = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    font_family = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    font_size = S7::new_property(S7::class_numeric, default = NA_real_),
    rule_above = S7::new_property(S7::class_any, default = NA),
    rule_below = S7::new_property(S7::class_any, default = NA),
    border_left = S7::new_property(S7::class_any, default = NA),
    border_right = S7::new_property(S7::class_any, default = NA),
    padding = S7::new_property(S7::class_numeric, default = NA_real_),
    blank_above = S7::new_property(S7::class_integer, default = NA_integer_),
    blank_below = S7::new_property(S7::class_integer, default = NA_integer_),
    pretext = S7::new_property(S7::class_character, default = NA_character_),
    posttext = S7::new_property(S7::class_character, default = NA_character_),
    halign = S7::new_property(S7::class_character, default = NA_character_),
    valign = S7::new_property(S7::class_character, default = NA_character_),
    # Per-side line style / width / color for the four cell borders.
    # Default NA on every scalar; the legacy Boolean knobs
    # (rule_above / rule_below / border_left / border_right) remain
    # back-compat and map to ("solid", 0.5pt, default colour) when TRUE.
    # Width is numeric points (0.25 / 0.5 / 1 / 1.5 are typical
    # clinical settings); color is hex / CSS-name / "currentColor".
    border_top_style = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_top_width = S7::new_property(
      S7::class_numeric,
      default = NA_real_
    ),
    border_top_color = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_bottom_style = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_bottom_width = S7::new_property(
      S7::class_numeric,
      default = NA_real_
    ),
    border_bottom_color = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_left_style = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_left_width = S7::new_property(
      S7::class_numeric,
      default = NA_real_
    ),
    border_left_color = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_right_style = S7::new_property(
      S7::class_character,
      default = NA_character_
    ),
    border_right_width = S7::new_property(
      S7::class_numeric,
      default = NA_real_
    ),
    border_right_color = S7::new_property(
      S7::class_character,
      default = NA_character_
    )
  ),
  validator = function(self) {
    if (
      length(self@halign) == 1L &&
        !is.na(self@halign) &&
        !(self@halign %in% .align_anchor_values)
    ) {
      return(paste0(
        "@halign must be one of ",
        paste(.sh_quote(.align_anchor_values), collapse = ", "),
        "; got ",
        .sh_quote(self@halign)
      ))
    }
    if (
      length(self@valign) == 1L &&
        !is.na(self@valign) &&
        !(self@valign %in% .valign_values)
    ) {
      return(paste0(
        "@valign must be one of ",
        paste(.sh_quote(.valign_values), collapse = ", "),
        "; got ",
        .sh_quote(self@valign)
      ))
    }
    for (side in c("top", "bottom", "left", "right")) {
      sty <- S7::prop(self, paste0("border_", side, "_style"))
      if (
        length(sty) == 1L &&
          !is.na(sty) &&
          !(sty %in% .border_style_values)
      ) {
        return(paste0(
          "@border_",
          side,
          "_style must be one of ",
          paste(.sh_quote(.border_style_values), collapse = ", "),
          "; got ",
          .sh_quote(sty)
        ))
      }
      wid <- S7::prop(self, paste0("border_", side, "_width"))
      if (length(wid) == 1L && !is.na(wid) && wid < 0) {
        return(paste0(
          "@border_",
          side,
          "_width must be non-negative; got ",
          wid
        ))
      }
    }
    NULL
  }
)

# ---------------------------------------------------------------------
# style_predicate — predicate + style + scope (legacy; superseded by
# style_layer but kept while existing tests / integrations migrate.
# New code paths use style_layer.)
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
style_predicate <- S7::new_class(
  "style_predicate",
  package = "tabular",
  properties = list(
    where = S7::class_any,
    style = style_node,
    scope = S7::new_property(S7::class_character, default = "cell")
  ),
  validator = function(self) {
    if (!(self@scope %in% .scope_values)) {
      return(paste0(
        "@scope must be one of ",
        paste(.sh_quote(.scope_values), collapse = ", "),
        "; got ",
        .sh_quote(self@scope)
      ))
    }
    NULL
  }
)

# ---------------------------------------------------------------------
# style_layer — one tabular_location + style_node pair, accumulated
# by every `style()` call against the unified API.
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
style_layer <- S7::new_class(
  "style_layer",
  package = "tabular",
  properties = list(
    location = S7::class_any,
    style = style_node
  )
)

# ---------------------------------------------------------------------
# style_spec — container for the cascade
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
style_spec <- S7::new_class(
  "style_spec",
  package = "tabular",
  properties = list(
    defaults = style_node,
    cols = S7::new_property(S7::class_list, default = list()),
    headers = S7::new_property(S7::class_list, default = list()),
    predicates = S7::new_property(S7::class_list, default = list()),
    layers = S7::new_property(S7::class_list, default = list())
  )
)

# ---------------------------------------------------------------------
# pagination_spec
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
pagination_spec <- S7::new_class(
  "pagination_spec",
  package = "tabular",
  properties = list(
    keep_together = S7::new_property(
      S7::class_character,
      default = character()
    ),
    panels = S7::new_property(S7::class_any, default = 1L),
    orphan_floor = S7::new_property(S7::class_integer, default = 3L),
    widow_floor = S7::new_property(S7::class_integer, default = 2L),
    repeat_headers = S7::new_property(S7::class_logical, default = TRUE),
    continuation = S7::new_property(
      S7::class_character,
      default = character()
    )
  )
)

# ---------------------------------------------------------------------
# preset_spec
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
preset_spec <- S7::new_class(
  "preset_spec",
  package = "tabular",
  properties = list(
    font_size = S7::new_property(S7::class_numeric, default = 9),
    # font_family accepts three input shapes (handled by .resolve_font_stack):
    #   * generic family   — "serif" (default) / "sans" / "mono"
    #   * single named     — "Courier New", "Inter", ...
    #   * explicit stack   — c("Courier New", "mono"), ...
    # class_any so character vectors typecheck.
    font_family = S7::new_property(
      S7::class_any,
      default = "serif"
    ),
    orientation = S7::new_property(
      S7::class_character,
      default = "portrait"
    ),
    paper_size = S7::new_property(
      S7::class_character,
      default = "letter"
    ),
    margins = S7::new_property(S7::class_any, default = 1),
    pagehead = S7::new_property(S7::class_list, default = list()),
    pagefoot = S7::new_property(S7::class_list, default = list()),
    hlines = S7::new_property(S7::class_character, default = "header"),
    indent_chars = S7::new_property(S7::class_character, default = "  "),
    title_align = S7::new_property(
      S7::class_character,
      default = "center"
    ),
    footnote_align = S7::new_property(
      S7::class_character,
      default = "left"
    ),
    na_text = S7::new_property(S7::class_character, default = ""),
    decimal_metrics = S7::new_property(
      S7::class_character,
      default = "chars"
    ),
    chrome_onscreen = S7::new_property(
      S7::class_character,
      default = "auto"
    ),
    width_mode = S7::new_property(
      S7::class_character,
      default = "content"
    ),
    # @style — ordered list of `style_layer` records that flow into
    # every spec rendered against this preset. Populated by:
    #   * `preset()` / `set_preset()` named-list knobs (`alignment` /
    #     `borders` / `fonts` / `colors` / `padding`), lowered through
    #     `.preset_args_to_layers()` at call time.
    #   * `preset(spec, style = style_template())` /
    #     `set_preset(style = …)`, which appends a user-built
    #     reusable house-style template.
    # The engine cascade applies these layers BEFORE per-spec
    # `style()` layers, so a house style sets defaults that an
    # individual table can still override per attribute.
    style = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    if (!(self@orientation %in% .orientation_values)) {
      return(paste0(
        "@orientation must be one of ",
        paste(.sh_quote(.orientation_values), collapse = ", ")
      ))
    }
    if (!(self@paper_size %in% .paper_size_values)) {
      return(paste0(
        "@paper_size must be one of ",
        paste(.sh_quote(.paper_size_values), collapse = ", ")
      ))
    }
    if (!(self@hlines %in% .hlines_values)) {
      return(paste0(
        "@hlines must be one of ",
        paste(.sh_quote(.hlines_values), collapse = ", ")
      ))
    }
    if (!(self@title_align %in% .align_anchor_values)) {
      return("@title_align must be left, center, or right")
    }
    if (!(self@footnote_align %in% .align_anchor_values)) {
      return("@footnote_align must be left, center, or right")
    }
    if (!(self@decimal_metrics %in% .decimal_metrics_values)) {
      return(paste0(
        "@decimal_metrics must be one of ",
        paste(.sh_quote(.decimal_metrics_values), collapse = ", ")
      ))
    }
    if (!(self@chrome_onscreen %in% .chrome_onscreen_values)) {
      return("@chrome_onscreen must be auto or off")
    }
    if (!(self@width_mode %in% .preset_width_mode_values)) {
      return(paste0(
        "@width_mode must be one of ",
        paste(.sh_quote(.preset_width_mode_values), collapse = ", "),
        "; got ",
        .sh_quote(self@width_mode)
      ))
    }
    if (!(length(self@margins) %in% c(1L, 2L, 4L))) {
      return(paste0(
        "@margins must be length 1 (all sides), 2 (vertical horizontal), ",
        "or 4 (top right bottom left)"
      ))
    }
    # Each element must parse as a dimension (numeric inches or
    # character with TeX unit suffix). Percent is rejected for
    # margins — it has no defined denominator on a print page.
    for (i in seq_along(self@margins)) {
      parsed <- tryCatch(
        .parse_dim(self@margins[[i]], allow_percent = FALSE),
        tabular_error_input = function(e) e
      )
      if (inherits(parsed, "tabular_error_input")) {
        return(conditionMessage(parsed))
      }
    }
    # Page bands — named list with slots from left / center / right.
    # `.page_band_shape_error` returns NULL or a message string,
    # which is exactly what an S7 validator returns.
    ph_err <- .page_band_shape_error(self@pagehead)
    if (!is.null(ph_err)) {
      return(paste0("@pagehead ", ph_err))
    }
    pf_err <- .page_band_shape_error(self@pagefoot)
    if (!is.null(pf_err)) {
      return(paste0("@pagefoot ", pf_err))
    }
    # `alignment` / `borders` / `fonts` / `colors` / `padding` knobs
    # live only as `preset()` / `set_preset()` arguments after the
    # Task 4/5 cut — they lower to `style_layer` records on `@style`
    # via `.preset_args_to_layers()` and never reach a `preset_spec`
    # slot. The corresponding shape validators run at call time
    # (`.validate_lowered_knobs()` in `R/preset.R`), not here.
    NULL
  }
)

# ---------------------------------------------------------------------
# tabular_spec — root user-facing IR
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
tabular_spec <- S7::new_class(
  "tabular_spec",
  package = "tabular",
  properties = list(
    data = S7::class_data.frame,
    cols = S7::new_property(S7::class_list, default = list()),
    headers = S7::new_property(S7::class_list, default = list()),
    sort = S7::class_any,
    styles = S7::class_any,
    preset = S7::class_any,
    pagination = S7::class_any,
    titles = S7::new_property(
      S7::class_character,
      default = character()
    ),
    footnotes = S7::new_property(
      S7::class_character,
      default = character()
    ),
    subgroup = S7::class_any
  )
)

# ---------------------------------------------------------------------
# inline_ast — parsed inline-formatting AST consumed by backends
# ---------------------------------------------------------------------
#
# Holds a list of typed text "runs" produced by `parse_inline()` (in
# R/inline_format.R) from plain strings, `md()`-wrapped Markdown, or
# `html()`-wrapped HTML. Backends iterate `@runs` and emit
# destination-specific markup. Each run is a plain R named-list
# record:
#   list(type = "plain",    text = "Hello")
#   list(type = "bold",     children = <list of runs>)
#   list(type = "italic",   children = <list of runs>)
#   list(type = "sup",      children = <list of runs>)
#   list(type = "sub",      children = <list of runs>)
#   list(type = "code",     children = <list of runs>)
#   list(type = "link",     href = ..., title = ..., children = ...)
#   list(type = "span",     style = <named char>, children = <list of runs>)
#   list(type = "newline")

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
inline_ast <- S7::new_class(
  "inline_ast",
  package = "tabular",
  properties = list(
    runs = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    if (length(self@runs) == 0L) {
      return(NULL)
    }
    types <- vapply(
      self@runs,
      function(r) {
        if (!is.list(r) || is.null(r$type)) {
          return(NA_character_)
        }
        as.character(r$type)
      },
      character(1)
    )
    bad <- is.na(types) | !types %in% .inline_run_types
    if (any(bad)) {
      return(paste0(
        "@runs contain unknown type(s): ",
        paste(unique(types[bad]), collapse = ", "),
        "; recognised: ",
        paste(.inline_run_types, collapse = ", ")
      ))
    }
    NULL
  }
)

# ---------------------------------------------------------------------
# tabular_grid — resolved IR (post-engine, pre-backend)
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
tabular_grid <- S7::new_class(
  "tabular_grid",
  package = "tabular",
  properties = list(
    pages = S7::new_property(S7::class_list, default = list()),
    metadata = S7::new_property(S7::class_list, default = list())
  )
)

# ---------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------

#' Test for tabular S7 class instances
#'
#' Class predicates returning a single logical indicating whether
#' `x` inherits from the corresponding tabular S7 class. Use them
#' to gate user-side code that branches on what a verb has
#' returned, to write defensive helpers that wrap tabular pipelines,
#' or to assert intermediate shapes during pipeline debugging.
#'
#' @details
#'
#' Eleven predicates cover the full S7 surface:
#'
#' | predicate              | tests for          | produced by                       |
#' |------------------------|--------------------|-----------------------------------|
#' | `is_tabular_spec()`    | `tabular_spec`     | [`tabular()`] and every build verb|
#' | `is_tabular_grid()`    | `tabular_grid`     | [`as_grid()`]                     |
#' | `is_col_spec()`        | `col_spec`         | [`col_spec()`]                    |
#' | `is_header_node()`     | `header_node`      | [`headers()`] (internal nodes)    |
#' | `is_sort_spec()`       | `sort_spec`        | [`sort_rows()`]                   |
#' | `is_style_node()`      | `style_node`       | [`style()`] (per-cell style)      |
#' | `is_style_predicate()` | `style_predicate`  | (legacy) [`style()`] predicate path|
#' | `is_style_layer()`     | `style_layer`      | [`style()`] (one per call)        |
#' | `is_style_spec()`      | `style_spec`       | [`style()`] (the cascade root)    |
#' | `is_pagination_spec()` | `pagination_spec`  | [`paginate()`]                    |
#' | `is_preset_spec()`     | `preset_spec`      | [`preset()`], [`set_preset()`]    |
#' | `is_subgroup_spec()`   | `subgroup_spec`    | [`subgroup()`]                    |
#' | `is_inline_ast()`      | `inline_ast`       | `parse_inline()` (post-format)    |
#'
#' Predicates never error — they return `FALSE` for `NULL`, vectors,
#' objects of any other class, and S7 objects from other packages.
#' Use them at any layer of a user's pipeline without a defensive
#' `tryCatch()`.
#'
#' @param x *Any R object.* The predicate inspects the S7 class
#'   chain via [`S7::S7_inherits()`]; no other introspection is
#'   performed.
#'
#' @return *A single `TRUE` / `FALSE`.* Use in `if` / `stopifnot`
#'   guards, or chain into validation helpers.
#'
#' @examples
#' # ---- Example 1: Gate user-side code on the spec class ----
#' #
#' # A user-side helper that pre-validates its input before piping
#' # into a downstream tabular chain. The predicate returns FALSE
#' # for any non-spec input without raising, so the helper can emit
#' # a friendlier error than tabular's own S7 validator would.
#' add_safety_footnote <- function(spec) {
#'   if (!is_tabular_spec(spec)) {
#'     stop("`spec` must be a tabular_spec; build one with tabular().")
#'   }
#'   spec
#' }
#'
#' demo <- tabular(saf_demo, titles = "Demographics")
#' is_tabular_spec(demo)         # TRUE
#' is_tabular_spec("not a spec") # FALSE — does not raise
#' add_safety_footnote(demo)
#'
#' # ---- Example 2: Assert intermediate shapes during debugging ----
#' #
#' # When chaining many verbs, dropping `stopifnot()` between verbs
#' # gives a clear stack trace if a verb silently returns the wrong
#' # type. Predicates are cheap (single S7 dispatch each) and never
#' # error, so they are safe to leave in pipelines during dev.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' spec <- tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics",
#'              sprintf("Safety Population (N=%d)", n["Total"]))
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' stopifnot(
#'   is_tabular_spec(spec),
#'   is_col_spec(spec@cols[["placebo"]]),
#'   is_sort_spec(spec@sort)
#' )
#'
#' grid <- as_grid(spec)
#' stopifnot(is_tabular_grid(grid))
#'
#' @param x *Object to test.* Any R value. Each predicate returns
#'   `TRUE` if `x` inherits from the named class, `FALSE` otherwise.
#'
#' @return *A length-1 `logical`* — `TRUE` or `FALSE`. Never `NA`.
#'
#' @seealso
#' **Class definitions:** [`tabular_classes`].
#'
#' **Verbs producing each class:** [`tabular()`], [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`style()`], [`paginate()`],
#' [`preset()`], [`as_grid()`].
#'
#' @keywords internal
#' @name tabular_predicates
NULL

#' @rdname tabular_predicates
#' @export
is_tabular_spec <- function(x) S7::S7_inherits(x, tabular_spec)

#' @rdname tabular_predicates
#' @export
is_tabular_grid <- function(x) S7::S7_inherits(x, tabular_grid)

#' @rdname tabular_predicates
#' @export
is_col_spec <- function(x) S7::S7_inherits(x, .col_spec_class)

#' @rdname tabular_predicates
#' @export
is_header_node <- function(x) S7::S7_inherits(x, header_node)

#' @rdname tabular_predicates
#' @export
is_sort_spec <- function(x) S7::S7_inherits(x, sort_spec)

#' @rdname tabular_predicates
#' @export
is_style_node <- function(x) S7::S7_inherits(x, style_node)

#' @rdname tabular_predicates
#' @export
is_style_predicate <- function(x) S7::S7_inherits(x, style_predicate)

#' @rdname tabular_predicates
#' @export
is_style_layer <- function(x) S7::S7_inherits(x, style_layer)

#' @rdname tabular_predicates
#' @export
is_style_spec <- function(x) S7::S7_inherits(x, style_spec)

#' @rdname tabular_predicates
#' @export
is_pagination_spec <- function(x) S7::S7_inherits(x, pagination_spec)

#' @rdname tabular_predicates
#' @export
is_preset_spec <- function(x) S7::S7_inherits(x, preset_spec)

#' @rdname tabular_predicates
#' @export
is_subgroup_spec <- function(x) S7::S7_inherits(x, subgroup_spec)

#' @rdname tabular_predicates
#' @export
is_inline_ast <- function(x) S7::S7_inherits(x, inline_ast)
