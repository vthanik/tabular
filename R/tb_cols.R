#' Column setup
#'
#' Configure column labels, widths, alignment, visibility, and BigN.
#' All arguments are flat named vectors keyed by the column names in
#' `spec@data`. Each call **merges** into the existing column
#' configuration: fields you supply are updated; fields you omit stay
#' as they were.
#'
#' @param spec A `tabular_spec` from [tb_table()] or another verb.
#' @param labels Named `character()`. Display labels for the column
#'   header. Names are columns in `spec@data`; values are the strings
#'   that appear in the rendered header row. `NULL` (default) leaves
#'   labels unchanged.
#' @param width Named `numeric()` of widths in inches. `NULL` (default)
#'   defers to the backend's auto-fit policy.
#' @param align Named `character()`. Values must be one of `"left"`,
#'   `"center"`, `"right"`, `"decimal"`. The wildcard name `"*"` sets
#'   the default alignment for all columns not named explicitly.
#'   `NULL` (default) leaves alignment unchanged.
#' @param visible Named `logical()`. `FALSE` hides a column from the
#'   rendered output (the column stays available for grouping and
#'   sorting via [tb_rows()]). `NULL` (default) leaves visibility
#'   unchanged.
#' @param n Named `integer()` of BigN counts (one per treatment arm,
#'   optionally `Total`). Backends typically append these as
#'   `"(N=xx)"` in the column header. `NULL` (default) leaves BigN
#'   unchanged.
#'
#' @return The updated `tabular_spec`.
#'
#' @section Wildcard:
#' Only `align` accepts the wildcard name `"*"`. Other arguments
#' reject `"*"` -- every name in `labels` / `width` / `visible` / `n`
#' must match a column in `spec@data`.
#'
#' @section Errors:
#' Raises `tabular_error_input` when:
#'
#' *   `spec` is not a `tabular_spec`.
#' *   Any argument is unnamed, has `NA` names, or has duplicate names.
#' *   Any name (other than `"*"` in `align`) is not a column in
#'     `spec@data`.
#' *   `labels` is non-character, `width` is not positive finite,
#'     `align` value is outside the allowed set, `visible` is
#'     non-logical, or `n` is not a positive whole number.
#'
#' @family structure
#' @seealso [tb_table()], [tb_rows()], [tb_render()].
#' @export
#' @examples
#' # 95% case -- label + alignment + BigN
#' saf_demo |>
#'   tb_table(titles = "Demographics") |>
#'   tb_cols(
#'     labels = c(placebo = "Placebo", drug_50 = "Drug 50mg"),
#'     align  = c("*" = "decimal"),
#'     n      = c(placebo = 86L, drug_50 = 84L)
#'   )
#'
#' # Hide a helper column used only for grouping
#' saf_aesocpt |>
#'   tb_table(titles = "AEs by SOC and PT") |>
#'   tb_cols(visible = c(soc = FALSE))
tb_cols <- function(
  spec,
  labels = NULL,
  width = NULL,
  align = NULL,
  visible = NULL,
  n = NULL
) {
  caller <- rlang::caller_env()

  check_tabular_spec(spec, call = caller)

  data_cols <- names(spec@data)

  .check_col_chr(
    labels,
    "labels",
    data_cols,
    allow_wildcard = FALSE,
    call = caller
  )
  .check_col_num(width, "width", data_cols, call = caller)
  .check_col_chr(
    align,
    "align",
    data_cols,
    allow_wildcard = TRUE,
    allowed = c("left", "center", "right", "decimal"),
    call = caller
  )
  .check_col_lgl(visible, "visible", data_cols, call = caller)
  .check_col_int(n, "n", data_cols, call = caller)

  cols <- .seed_columns(spec@columns, data_cols)
  cols <- .apply_labels(cols, labels)
  cols <- .apply_width(cols, width)
  cols <- .apply_align(cols, align, data_cols)
  cols <- .apply_visible(cols, visible)
  cols <- .apply_n(cols, n)

  S7::set_props(spec, columns = cols)
}

# Column-list construction -------------------------------------------------

.seed_columns <- function(existing, data_cols) {
  if (length(existing) == length(data_cols)) {
    return(existing)
  }
  cols <- lapply(data_cols, function(nm) column_spec(name = nm))
  names(cols) <- data_cols
  cols
}

.apply_labels <- function(cols, labels) {
  if (is.null(labels)) {
    return(cols)
  }
  for (nm in names(labels)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], label = unname(labels[[nm]]))
  }
  cols
}

.apply_width <- function(cols, width) {
  if (is.null(width)) {
    return(cols)
  }
  for (nm in names(width)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], width = unname(width[[nm]]))
  }
  cols
}

.apply_align <- function(cols, align, data_cols) {
  if (is.null(align)) {
    return(cols)
  }
  is_star <- names(align) == "*"
  star_value <- if (any(is_star)) {
    unname(align[is_star][[1L]])
  } else {
    NA_character_
  }
  specific <- align[!is_star]
  for (nm in data_cols) {
    if (nm %in% names(specific)) {
      cols[[nm]] <- S7::set_props(cols[[nm]], align = unname(specific[[nm]]))
    } else if (!is.na(star_value) && is.na(cols[[nm]]@align)) {
      cols[[nm]] <- S7::set_props(cols[[nm]], align = star_value)
    }
  }
  cols
}

.apply_visible <- function(cols, visible) {
  if (is.null(visible)) {
    return(cols)
  }
  for (nm in names(visible)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], visible = unname(visible[[nm]]))
  }
  cols
}

.apply_n <- function(cols, n) {
  if (is.null(n)) {
    return(cols)
  }
  for (nm in names(n)) {
    cols[[nm]] <- S7::set_props(cols[[nm]], n = as.integer(unname(n[[nm]])))
  }
  cols
}

# Per-arg validators -------------------------------------------------------

.check_col_names <- function(x, arg, data_cols, allow_wildcard, call) {
  nms <- names(x)
  if (is.null(nms) || any(nms == "") || anyNA(nms)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a fully named vector.",
        "x" = "Every element needs a name matching a column in {.code spec@data}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (anyDuplicated(nms)) {
    dups <- unique(nms[duplicated(nms)])
    cli::cli_abort(
      c(
        "{.arg {arg}} has duplicate name{?s}: {.val {dups}}.",
        "i" = "Each column may appear at most once."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  allowed <- if (allow_wildcard) c(data_cols, "*") else data_cols
  bad <- setdiff(nms, allowed)
  if (length(bad) > 0L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} has name{?s} not in {.code spec@data}: {.val {bad}}.",
        "i" = "Valid column{?s}: {.val {data_cols}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(x)
}

.check_col_chr <- function(
  x,
  arg,
  data_cols,
  allow_wildcard = FALSE,
  allowed = NULL,
  call
) {
  if (is.null(x)) {
    return(invisible(x))
  }
  if (!is.character(x) || anyNA(x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a character vector with no NAs.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .check_col_names(x, arg, data_cols, allow_wildcard, call)
  if (!is.null(allowed)) {
    bad <- setdiff(unique(unname(x)), allowed)
    if (length(bad) > 0L) {
      cli::cli_abort(
        c(
          "{.arg {arg}} has invalid value{?s}: {.val {bad}}.",
          "i" = "Allowed: {.val {allowed}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  invisible(x)
}

.check_col_num <- function(x, arg, data_cols, call) {
  if (is.null(x)) {
    return(invisible(x))
  }
  ok <- is.numeric(x) &&
    !anyNA(x) &&
    all(is.finite(x)) &&
    all(x > 0)
  if (!ok) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a positive finite numeric vector.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .check_col_names(x, arg, data_cols, allow_wildcard = FALSE, call = call)
  invisible(x)
}

.check_col_lgl <- function(x, arg, data_cols, call) {
  if (is.null(x)) {
    return(invisible(x))
  }
  if (!is.logical(x) || anyNA(x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a logical vector with no NAs.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .check_col_names(x, arg, data_cols, allow_wildcard = FALSE, call = call)
  invisible(x)
}

.check_col_int <- function(x, arg, data_cols, call) {
  if (is.null(x)) {
    return(invisible(x))
  }
  ok <- is.numeric(x) &&
    !anyNA(x) &&
    all(is.finite(x)) &&
    all(x == trunc(x)) &&
    all(x > 0)
  if (!ok) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a positive whole-number vector.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  .check_col_names(x, arg, data_cols, allow_wildcard = FALSE, call = call)
  invisible(x)
}
