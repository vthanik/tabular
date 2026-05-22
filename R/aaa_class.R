# aaa_class.R -- S7 class declarations for tabular's public types.
#
# Loaded first via the `aaa_` prefix so subsequent files can register
# methods against these classes.
#
# Conventions follow ggplot2 (rstudio/ggplot2/R/all-classes.R):
#   - One class per concept; typed properties via S7::class_*.
#   - Class object named the same as the class name where there is no
#     collision with a user-facing constructor function. tabular has no
#     such collision (entry points are tb_*()), so we use bare names.
#   - Predicates take the herald shape: `is_<name>()` accepts both S7
#     and pre-S7 S3 dual-class objects.
#
# Constructors stay minimal: S7-generated defaults at this scaffold
# stage. Phase 1 adds custom constructors with validation + cli::cli_abort
# input checks, paralleling class_ggplot in ggplot2.

#' tabular S7 classes
#'
#' S7 class definitions for the three internal types tabular passes
#' between phases:
#'
#' * `tabular_spec` -- the immutable spec built by the user-facing verbs
#'   ([tb_table()] / [tb_cols()] / ...). One property updated per verb.
#' * `tabular_grid` -- the resolved structure produced by
#'   `engine_finalize()` (decimal widths, N counts, tokens, pagination
#'   applied). Consumed by every backend.
#' * `column_spec` -- per-column configuration (label, width, align,
#'   visible, n). Held inside `tabular_spec`'s `columns` list.
#'
#' These are not exported as constructors -- users build a
#' `tabular_spec` via [tb_table()], never via `tabular_spec()` directly.
#' The classes are documented here as internal infrastructure.
#'
#' @keywords internal
#' @name tabular_classes
NULL

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
tabular_spec <- S7::new_class(
  "tabular_spec",
  package = "tabular",
  properties = list(
    data = S7::class_any,
    titles = S7::new_property(S7::class_character, default = character()),
    footnotes = S7::new_property(S7::class_character, default = character()),
    preset = S7::class_any,
    paginate_at = S7::new_property(S7::class_integer, default = NA_integer_),
    continuation = S7::new_property(
      S7::class_character,
      default = "(continued)"
    ),
    columns = S7::new_property(S7::class_list, default = list()),
    rows = S7::new_property(S7::class_list, default = list()),
    spans = S7::new_property(S7::class_list, default = list()),
    styles = S7::new_property(S7::class_list, default = list()),
    markup = S7::new_property(S7::class_list, default = list())
  )
)

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
tabular_grid <- S7::new_class(
  "tabular_grid",
  package = "tabular",
  properties = list(
    cells = S7::new_property(S7::class_list, default = list()),
    header = S7::new_property(S7::class_list, default = list()),
    footer = S7::new_property(S7::class_list, default = list()),
    pages = S7::new_property(S7::class_list, default = list()),
    widths = S7::new_property(S7::class_numeric, default = numeric()),
    geometry = S7::new_property(S7::class_list, default = list())
  )
)

#' @rdname tabular_classes
#' @format NULL
#' @usage NULL
column_spec <- S7::new_class(
  "column_spec",
  package = "tabular",
  properties = list(
    name = S7::class_character,
    label = S7::new_property(S7::class_character, default = NA_character_),
    width = S7::new_property(S7::class_numeric, default = NA_real_),
    align = S7::new_property(S7::class_character, default = NA_character_),
    visible = S7::new_property(S7::class_logical, default = TRUE),
    n = S7::new_property(S7::class_integer, default = NA_integer_)
  )
)

# Predicates --------------------------------------------------------------

#' Test for a `tabular_spec` object
#'
#' @param x Any R object.
#' @return Single logical. `TRUE` when `x` inherits from `tabular_spec`,
#'   else `FALSE`. Never errors.
#' @keywords internal
#' @export
is_tabular_spec <- function(x) {
  S7::S7_inherits(x, tabular_spec) || inherits(x, "tabular_spec")
}

#' Test for a `tabular_grid` object
#'
#' @param x Any R object.
#' @return Single logical. `TRUE` when `x` inherits from `tabular_grid`,
#'   else `FALSE`. Never errors.
#' @keywords internal
#' @export
is_tabular_grid <- function(x) {
  S7::S7_inherits(x, tabular_grid) || inherits(x, "tabular_grid")
}
