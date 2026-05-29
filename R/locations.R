# locations.R — `cells_*()` constructors that name the *where* half of
# the styling cascade. Each constructor returns a `tabular_location`
# S3 record describing one region of the rendered table; the
# `style()` verb pairs the record with one or more style attributes
# to produce a `style_layer`.
#
# Surface vocabulary (1 location per surface, with optional filters):
#
#   body            — body cells (rows x cols of the data grid)
#   headers         — column header band(s) built by `headers()`,
#                     including the leaf band built from `col_spec@label`
#   group_headers   — section-header rows injected for any column with
#                     `col_spec@group_display = "header_row"`
#   title           — title block
#   subgroup_labels — banner row between subgroup partitions
#   footnotes       — footnote block
#   pagehead        — per-page header band
#   pagefoot        — per-page footer band
#   table           — outer edges + inter-row / inter-col rules of the
#                     body grid (border-only surface)
#
# The constructors validate their own arguments at call time so a
# bad location surfaces immediately rather than waiting for the
# engine to choke. Engines consume the records by switching on
# `loc$surface` and reading the relevant filter slots.

# ---------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------

.location_surfaces <- c(
  "body",
  "headers",
  "group_headers",
  "title",
  "subgroup_labels",
  "footnotes",
  "pagehead",
  "pagefoot",
  "table"
)

# `cells_table(side = ...)` — outer-edge / inter-row / inter-col rule.
# `NULL` means "whole body" (the layer's borders apply to every body
# cell, same as `cells_body()` semantics for border attributes).
.location_table_sides <- c(
  "outer",
  "outer_top",
  "outer_bottom",
  "outer_left",
  "outer_right",
  "rows",
  "cols"
)

# `cells_pagehead(slot = ...)` / `cells_pagefoot(slot = ...)` slot.
# `NULL` means "every slot".
.location_band_slots <- c("left", "center", "right")

# ---------------------------------------------------------------------
# Internal validators
# ---------------------------------------------------------------------

# Validate an `i` / `j` index filter. Accepts NULL (no filter),
# integer / numeric, logical, or character vector of length >= 1.
# Coerces numeric -> integer when whole.
.check_location_index <- function(x, arg, call) {
  if (is.null(x)) {
    return(NULL)
  }
  if (length(x) == 0L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must have length >= 1.",
        "i" = "Pass {.code NULL} for no filter."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (is.logical(x)) {
    if (anyNA(x)) {
      cli::cli_abort(
        "{.arg {arg}} must not contain NAs.",
        class = "tabular_error_input",
        call = call
      )
    }
    return(x)
  }
  if (is.numeric(x)) {
    if (anyNA(x) || any(x < 1) || any(x != trunc(x))) {
      cli::cli_abort(
        c(
          "{.arg {arg}} must contain positive whole numbers.",
          "x" = "You supplied {.val {x}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(as.integer(x))
  }
  if (is.character(x)) {
    if (anyNA(x) || any(!nzchar(x))) {
      cli::cli_abort(
        "{.arg {arg}} must not contain NA or empty strings.",
        class = "tabular_error_input",
        call = call
      )
    }
    return(x)
  }
  cli::cli_abort(
    c(
      "{.arg {arg}} must be NULL, integer, logical, or character.",
      "x" = "You supplied {.obj_type_friendly {x}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Build a `tabular_location` record. Internal constructor; the
# public `cells_*()` factories call this with their surface + filter
# args already validated.
.new_location <- function(
  surface,
  i = NULL,
  j = NULL,
  where = NULL,
  labels = NULL,
  level = NULL,
  slot = NULL,
  side = NULL,
  chrome_region = NULL
) {
  structure(
    list(
      surface = surface,
      i = i,
      j = j,
      where = where,
      labels = labels,
      level = level,
      slot = slot,
      side = side,
      # chrome_region — when set, names the exact chrome border region
      # (e.g. "header_between") a rule layer targets, bypassing the
      # border-side heuristic in `.apply_chrome_layer()`. Used only by
      # `.preset_rules_to_layers()`; NULL for ordinary `cells_*()`
      # locations.
      chrome_region = chrome_region
    ),
    class = c("tabular_location", "list")
  )
}

# ---------------------------------------------------------------------
# Public location constructors
# ---------------------------------------------------------------------

#' Cell-location constructors for `style()`
#'
#' Build a `tabular_location` value naming one region of the rendered
#' table; pass the result to [`style()`]'s `at` argument. Each
#' constructor targets one surface (body, headers, footnotes, ...);
#' optional `i` / `j` / `where` / `level` / `labels` filters narrow
#' the target within that surface.
#'
#' @details
#'
#' **One surface per location.** A `tabular_location` always names
#' exactly one of: `body`, `headers`, `group_headers`, `title`,
#' `subgroup_labels`, `footnotes`, `pagehead`, `pagefoot`, `table`.
#' Cross-surface styling layers in via multiple chained [`style()`]
#' calls (one per location).
#'
#' **Index vocabulary.** Where supported, the `i` (rows) and `j`
#' (columns) arguments accept integer, logical, or character vectors
#' — matching the convention established by **flextable**
#' (`bold(ft, i, j)`) and **tinytable** (`style_tt(i, j)`). Character
#' vectors match against the data frame's column names (`j`) or row
#' labels (`i`); integers are 1-based positions; logicals broadcast
#' to nrow / ncol.
#'
#' **Predicate vocabulary.** `cells_body(where = pvalue < 0.05)` is
#' the canonical data-driven filter — `where` is captured as an rlang
#' quosure and evaluated at engine time against the post-sort grid.
#' Mutually exclusive with `i` (you target *either* by index *or* by
#' predicate, not both).
#'
#' **Why `cells_headers` not `cells_column_spanners`.** The verb that
#' builds the multi-level header tree is named [`headers()`]. The
#' location follows the same vocabulary: one word ("headers") covers
#' the entire column-header section — inner spanner bands AND the
#' leaf band of per-column labels. Pass `level` or `labels` to narrow.
#'
#' @section Surface filters:
#'
#' | constructor                       | filters                          |
#' |-----------------------------------|----------------------------------|
#' | `cells_body(i, j, where)`         | row index / col index / predicate|
#' | `cells_headers(level, labels, j)` | band depth / spanner label / cols|
#' | `cells_group_headers(j, where)`   | injected section rows            |
#' | `cells_title()`                   | (no filter — whole block)        |
#' | `cells_subgroup_labels()`         | (no filter)                      |
#' | `cells_footnotes()`               | (no filter)                      |
#' | `cells_pagehead(slot)`            | `"left"` / `"center"` / `"right"`|
#' | `cells_pagefoot(slot)`            | `"left"` / `"center"` / `"right"`|
#' | `cells_table(side, i, j)`         | outer edge / row separator / etc.|
#'
#' @param i *Row index filter.* `<integer | logical | character | NULL>`.
#'   Integer = 1-based row numbers; logical = length-`nrow` mask
#'   (broadcasts from scalar TRUE/FALSE); character = matches the
#'   visible row labels. `NULL` (default) = no filter (every row).
#'
#' @param j *Column index filter.* `<integer | character | NULL>`.
#'   Integer = 1-based column positions; character = matches column
#'   names in `spec@data`. `NULL` (default) = every column.
#'
#' @param where *Predicate.* An unquoted expression evaluating to a
#'   length-`nrow` logical vector when run against the data grid.
#'   Captured as an rlang quosure (so `pvalue < 0.05` works without
#'   needing to wrap in `vars()` or similar). Mutually exclusive with
#'   `i`.
#'
#' @param level *Header-band depth (for `cells_headers`).*
#'   `<integer(1) | NULL>`. `1` = topmost spanner band; increasing
#'   integers walk toward the leaves. `-1` = the leaf band
#'   (per-column labels built from `col_spec@label`). `NULL`
#'   (default) = every band at every depth.
#'
#' @param labels *Header-band labels (for `cells_headers`).*
#'   `<character | NULL>`. Targets `header_node`(s) whose `@label`
#'   matches, at any depth. Mutually exclusive with `level`.
#'
#' @param slot *Band slot (for `cells_pagehead` / `cells_pagefoot`).*
#'   `<character(1) | NULL>`. One of `"left"`, `"center"`, `"right"`,
#'   or `NULL` for every slot.
#'
#' @param side *Table edge / separator (for `cells_table`).*
#'   `<character(1) | NULL>`. One of `"outer"` (all four outer
#'   edges), `"outer_top"`, `"outer_bottom"`, `"outer_left"`,
#'   `"outer_right"`, `"rows"` (horizontal separator between body
#'   rows), `"cols"` (vertical separator between body columns), or
#'   `NULL` for whole-body (same as `cells_body()`).
#'
#' @param x *Any R object* — tested by `is_tabular_location()` for
#'   membership in the `tabular_location` S3 class.
#'
#' @return *A `tabular_location` S3 list* with slots `surface`, `i`,
#'   `j`, `where`, `labels`, `level`, `slot`, `side` (unused slots
#'   are `NULL`). Pass to [`style()`]'s `at` argument.
#'
#' @examples
#' # Whole body cells (the default for style())
#' cells_body()
#'
#' # Row index 1:3, column "Total"
#' cells_body(i = 1:3, j = "Total")
#'
#' # Data-driven subset
#' cells_body(where = stat_label == "Mean (SD)")
#'
#' # Topmost spanner band only
#' cells_headers(level = 1)
#'
#' # Leaf band (per-column labels)
#' cells_headers(level = -1)
#'
#' # A specific spanner by label
#' cells_headers(labels = "Treatment Group")
#'
#' # Section-header rows for col_spec(group_display = "header_row")
#' cells_group_headers()
#'
#' # Title / footnotes blocks
#' cells_title()
#' cells_footnotes()
#'
#' # Page-header / page-footer slots
#' cells_pagehead(slot = "left")
#' cells_pagefoot(slot = "right")
#'
#' # Outer table frame
#' cells_table(side = "outer")
#'
#' # Horizontal rules between body rows
#' cells_table(side = "rows")
#'
#' @seealso
#' **Verb that consumes locations:** [`style()`].
#'
#' **Border value type:** [`brdr()`].
#'
#' **Reusable house style:** [`style_template()`].
#'
#' @name cells
#' @export
cells_body <- function(i = NULL, j = NULL, where = NULL) {
  call <- rlang::caller_env()
  where_quo <- rlang::enquo(where)
  has_where <- !rlang::quo_is_null(where_quo) &&
    !rlang::quo_is_missing(where_quo)
  if (!is.null(i) && has_where) {
    cli::cli_abort(
      c(
        "Pass only one of {.arg i} and {.arg where}.",
        "i" = "Use {.arg i} for positional indexing, {.arg where} for a predicate."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .new_location(
    surface = "body",
    i = .check_location_index(i, arg = "i", call = call),
    j = .check_location_index(j, arg = "j", call = call),
    where = if (has_where) where_quo else NULL
  )
}

#' @rdname cells
#' @export
cells_headers <- function(level = NULL, labels = NULL, j = NULL) {
  call <- rlang::caller_env()
  if (!is.null(level) && !is.null(labels)) {
    cli::cli_abort(
      c(
        "Pass only one of {.arg level} and {.arg labels}.",
        "i" = "Use {.arg level} to target by depth, {.arg labels} to target a named band."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!is.null(level)) {
    if (
      !is.numeric(level) ||
        length(level) != 1L ||
        is.na(level) ||
        level != trunc(level) ||
        level == 0L
    ) {
      cli::cli_abort(
        c(
          "{.arg level} must be a non-zero whole number.",
          "i" = "Use positive integers for top-down depth (1 = topmost band), or -1 for the leaf band."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    level <- as.integer(level)
  }
  if (!is.null(labels)) {
    if (!is.character(labels) || length(labels) == 0L || anyNA(labels)) {
      cli::cli_abort(
        "{.arg labels} must be a non-empty character vector with no NAs.",
        class = "tabular_error_input",
        call = call
      )
    }
  }
  .new_location(
    surface = "headers",
    level = level,
    labels = labels,
    j = .check_location_index(j, arg = "j", call = call)
  )
}

#' @rdname cells
#' @export
cells_group_headers <- function(j = NULL, where = NULL) {
  call <- rlang::caller_env()
  where_quo <- rlang::enquo(where)
  has_where <- !rlang::quo_is_null(where_quo) &&
    !rlang::quo_is_missing(where_quo)
  .new_location(
    surface = "group_headers",
    j = .check_location_index(j, arg = "j", call = call),
    where = if (has_where) where_quo else NULL
  )
}

#' @rdname cells
#' @export
cells_title <- function() {
  .new_location(surface = "title")
}

#' @rdname cells
#' @export
cells_subgroup_labels <- function() {
  .new_location(surface = "subgroup_labels")
}

#' @rdname cells
#' @export
cells_footnotes <- function() {
  .new_location(surface = "footnotes")
}

#' @rdname cells
#' @export
cells_pagehead <- function(slot = NULL) {
  call <- rlang::caller_env()
  .new_location(
    surface = "pagehead",
    slot = .check_location_slot(slot, call = call)
  )
}

#' @rdname cells
#' @export
cells_pagefoot <- function(slot = NULL) {
  call <- rlang::caller_env()
  .new_location(
    surface = "pagefoot",
    slot = .check_location_slot(slot, call = call)
  )
}

#' @rdname cells
#' @export
cells_table <- function(side = NULL, i = NULL, j = NULL) {
  call <- rlang::caller_env()
  if (!is.null(side)) {
    valid_sides <- .location_table_sides
    if (
      !is.character(side) ||
        length(side) != 1L ||
        is.na(side) ||
        !(side %in% valid_sides)
    ) {
      cli::cli_abort(
        c(
          "{.arg side} must be one of {.val {valid_sides}}.",
          "x" = "You supplied {.val {side}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  .new_location(
    surface = "table",
    side = side,
    i = .check_location_index(i, arg = "i", call = call),
    j = .check_location_index(j, arg = "j", call = call)
  )
}

#' @rdname cells
#' @export
is_tabular_location <- function(x) {
  inherits(x, "tabular_location")
}

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

.check_location_slot <- function(slot, call) {
  if (is.null(slot)) {
    return(NULL)
  }
  valid_slots <- .location_band_slots
  if (
    !is.character(slot) ||
      length(slot) != 1L ||
      is.na(slot) ||
      !(slot %in% valid_slots)
  ) {
    cli::cli_abort(
      c(
        "{.arg slot} must be one of {.val {valid_slots}}.",
        "x" = "You supplied {.val {slot}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  slot
}

# Pretty-printer — compact form for inspection at the REPL.
#' @export
#' @noRd
print.tabular_location <- function(x, ...) {
  parts <- character()
  if (!is.null(x$i)) {
    parts <- c(parts, sprintf("i=%s", .format_filter(x$i)))
  }
  if (!is.null(x$j)) {
    parts <- c(parts, sprintf("j=%s", .format_filter(x$j)))
  }
  if (!is.null(x$where)) {
    parts <- c(parts, sprintf("where=%s", rlang::quo_text(x$where)))
  }
  if (!is.null(x$level)) {
    parts <- c(parts, sprintf("level=%d", x$level))
  }
  if (!is.null(x$labels)) {
    parts <- c(
      parts,
      sprintf("labels=c(%s)", paste(.sh_quote(x$labels), collapse = ", "))
    )
  }
  if (!is.null(x$slot)) {
    parts <- c(parts, sprintf("slot=%s", .sh_quote(x$slot)))
  }
  if (!is.null(x$side)) {
    parts <- c(parts, sprintf("side=%s", .sh_quote(x$side)))
  }
  body <- if (length(parts) == 0L) "" else paste(parts, collapse = ", ")
  cat(sprintf("<tabular_location: %s(%s)>\n", x$surface, body))
  invisible(x)
}

.format_filter <- function(x) {
  if (length(x) <= 4L) {
    return(paste(format(x), collapse = ","))
  }
  paste0(paste(format(x[1:3]), collapse = ","), ",...")
}
