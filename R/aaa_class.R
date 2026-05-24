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

.col_usage_values <- c("display", "group", "across", "computed")
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
.derive_type_values <- c("numeric", "character")
.decimal_metrics_values <- c("afm", "systemfonts")
.chrome_onscreen_values <- c("auto", "off")

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

# Recognised keys on `preset_spec@alignment`. Each entry pairs with
# a value-set drawn from `.align_anchor_values` (left/center/right)
# for `_halign` and `.valign_values` (top/middle/bottom) for
# `_valign`. The validator in preset_spec walks both halves.
# Title / footnote / subgroup `_halign` accept either a length-1
# scalar (applies to every line) OR a character vector aligning
# 1:1 with the title / footnote vector; the other six keys are
# scalar-only.
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
.preset_alignment_keys_vector_halign <- c(
  "title_halign",
  "footnote_halign"
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
#' -> [`derive()`] -> [`style()`] -> [`paginate()`] -> [`preset()`]
#' -> [`as_grid()`] / [`emit()`]).
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
#' | `derive_spec`       | one computed-column expression (quosure-captured)     | internal — built by [`derive()`]  |
#' | `style_node`        | one resolved style attribute set (per-cell)           | internal — built by [`style()`]   |
#' | `style_predicate`   | one `where` quosure + scope + style_node              | internal — built by [`style()`]   |
#' | `style_spec`        | the cascade root (defaults + cols + headers + preds)  | internal — built by [`style()`]   |
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
        paste(shQuote(.col_usage_values), collapse = ", "),
        "; got ",
        shQuote(self@usage)
      ))
    }
    if (!is.na(self@align) && !(self@align %in% .align_values)) {
      return(paste0(
        "@align must be one of ",
        paste(shQuote(.align_values), collapse = ", "),
        "; got ",
        shQuote(self@align)
      ))
    }
    if (!is.na(self@valign) && !(self@valign %in% .valign_values)) {
      return(paste0(
        "@valign must be one of ",
        paste(shQuote(.valign_values), collapse = ", "),
        "; got ",
        shQuote(self@valign)
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
# derive_spec
# ---------------------------------------------------------------------

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
derive_spec <- S7::new_class(
  "derive_spec",
  package = "tabular",
  properties = list(
    name = S7::new_property(S7::class_character, default = NA_character_),
    expr = S7::class_any,
    type = S7::new_property(S7::class_character, default = "numeric")
  ),
  validator = function(self) {
    if (!(self@type %in% .derive_type_values)) {
      return(paste0(
        "@type must be one of ",
        paste(shQuote(.derive_type_values), collapse = ", "),
        "; got ",
        shQuote(self@type)
      ))
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
    blank_after = S7::new_property(S7::class_integer, default = NA_integer_),
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
        paste(shQuote(.align_anchor_values), collapse = ", "),
        "; got ",
        shQuote(self@halign)
      ))
    }
    if (
      length(self@valign) == 1L &&
        !is.na(self@valign) &&
        !(self@valign %in% .valign_values)
    ) {
      return(paste0(
        "@valign must be one of ",
        paste(shQuote(.valign_values), collapse = ", "),
        "; got ",
        shQuote(self@valign)
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
          paste(shQuote(.border_style_values), collapse = ", "),
          "; got ",
          shQuote(sty)
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
# style_predicate — predicate + style + scope
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
        paste(shQuote(.scope_values), collapse = ", "),
        "; got ",
        shQuote(self@scope)
      ))
    }
    NULL
  }
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
    predicates = S7::new_property(S7::class_list, default = list())
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
      default = "afm"
    ),
    chrome_onscreen = S7::new_property(
      S7::class_character,
      default = "auto"
    ),
    alignment = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    if (!(self@orientation %in% .orientation_values)) {
      return(paste0(
        "@orientation must be one of ",
        paste(shQuote(.orientation_values), collapse = ", ")
      ))
    }
    if (!(self@paper_size %in% .paper_size_values)) {
      return(paste0(
        "@paper_size must be one of ",
        paste(shQuote(.paper_size_values), collapse = ", ")
      ))
    }
    if (!(self@hlines %in% .hlines_values)) {
      return(paste0(
        "@hlines must be one of ",
        paste(shQuote(.hlines_values), collapse = ", ")
      ))
    }
    if (!(self@title_align %in% .align_anchor_values)) {
      return("@title_align must be left, center, or right")
    }
    if (!(self@footnote_align %in% .align_anchor_values)) {
      return("@footnote_align must be left, center, or right")
    }
    if (!(self@decimal_metrics %in% .decimal_metrics_values)) {
      return("@decimal_metrics must be afm or systemfonts")
    }
    if (!(self@chrome_onscreen %in% .chrome_onscreen_values)) {
      return("@chrome_onscreen must be auto or off")
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
    # Alignment named-list — every name in the allowed key set,
    # every value in the appropriate enum (halign vs valign), with
    # title / footnote _halign also accepting a character vector
    # for per-line broadcast.
    al_err <- .preset_alignment_shape_error(self@alignment)
    if (!is.null(al_err)) {
      return(paste0("@alignment ", al_err))
    }
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
    derives = S7::new_property(S7::class_list, default = list()),
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
#' | `is_derive_spec()`     | `derive_spec`      | [`derive()`]                      |
#' | `is_style_node()`      | `style_node`       | [`style()`] (per-cell style)      |
#' | `is_style_predicate()` | `style_predicate`  | [`style()`] (one per call)        |
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
#' @seealso
#' **Class definitions:** [`tabular_classes`].
#'
#' **Verbs producing each class:** [`tabular()`], [`col_spec()`],
#' [`headers()`], [`sort_rows()`], [`derive()`], [`style()`],
#' [`paginate()`], [`preset()`], [`as_grid()`].
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
is_derive_spec <- function(x) S7::S7_inherits(x, derive_spec)

#' @rdname tabular_predicates
#' @export
is_style_node <- function(x) S7::S7_inherits(x, style_node)

#' @rdname tabular_predicates
#' @export
is_style_predicate <- function(x) S7::S7_inherits(x, style_predicate)

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
