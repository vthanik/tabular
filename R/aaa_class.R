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
.scope_values <- c("cell", "row", "col")
.orientation_values <- c("portrait", "landscape")
.paper_size_values <- c("letter", "a4")
.hlines_values <- c("header", "none", "all")
.align_anchor_values <- c("left", "center", "right")
.derive_type_values <- c("numeric", "character")
.decimal_metrics_values <- c("afm", "systemfonts")

# ---------------------------------------------------------------------
# col_spec — 7-field per-column DSL
# ---------------------------------------------------------------------
#
# The S7 class binding is .col_spec_class (internal); the user-facing
# constructor `col_spec()` lives in R/col_spec.R and wraps this with
# cli-friendly tabular_error_input errors.

#' tabular S7 classes
#'
#' Internal S7 class definitions for tabular's display-side IR. Users
#' do not construct these directly except via `col_spec()`;
#' everything else is built by the verb chain
#' (`tabular()` -> `cols()` -> ... -> `emit()`).
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
      S7::class_numeric,
      default = NA_real_
    ),
    align = S7::new_property(
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
    if (!is.na(self@width) && (!is.finite(self@width) || self@width <= 0)) {
      return("@width must be a positive finite number or NA")
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
    posttext = S7::new_property(S7::class_character, default = NA_character_)
  )
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
    font_family = S7::new_property(
      S7::class_character,
      default = "Times New Roman"
    ),
    orientation = S7::new_property(
      S7::class_character,
      default = "portrait"
    ),
    paper_size = S7::new_property(
      S7::class_character,
      default = "letter"
    ),
    margins = S7::new_property(S7::class_numeric, default = 1),
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
    )
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
    if (length(self@margins) != 1L && length(self@margins) != 4L) {
      return(
        "@margins must be length 1 (all sides) or length 4 (top right bottom left)"
      )
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
    )
  )
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

#' Test for tabular S7 objects
#'
#' Predicates returning a single logical indicating whether `x`
#' inherits from the corresponding tabular S7 class.
#'
#' @param x Any R object.
#' @return Single logical. Never errors.
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
