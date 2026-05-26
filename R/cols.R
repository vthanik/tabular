# cols.R — variadic per-column DSL verb. Attaches col_spec objects
# to a tabular_spec, keyed by input column name. Repeat-call merge
# is field-by-field: a non-default field overrides the prior value;
# a default-valued field leaves the prior alone.

#' Attach per-column specifications
#'
#' Add [`col_spec()`] entries to a `tabular_spec`. Each named argument
#' is one column: the name is the input column in `.spec@data` and the
#' value is the `col_spec` carrying that column's display attributes
#' (usage, label, format, alignment, width, visibility, NA text).
#' Columns not mentioned get a default `col_spec()` (usage = display)
#' at engine-validate time.
#'
#' @details
#'
#' **Sparse declaration.** Declare only the columns whose attributes
#' differ from the default — a typical pipeline uses one `cols()`
#' call with one entry per non-default column.
#'
#' **Within-call duplicates warn.** A duplicate name inside one
#' `cols()` call warns and "last value wins". To intentionally
#' override an attribute, use a second `cols()` call downstream and
#' let the merge rule below apply.
#'
#' @section Repeat-call merge semantics:
#'
#' When `cols()` is called more than once for the same column, the
#' engine merges the new `col_spec` into the existing one field-by-
#' field. A non-default value on the new spec overrides; a default-
#' valued field leaves the existing field intact. This lets you
#' build a column's spec in stages — declare the label-and-alignment
#' block up front, add the width once you know it fits, then attach
#' a sort key, all without re-stating earlier attributes. Essential
#' when generating specs programmatically (looping over arms,
#' layering a house-style helper).
#'
#' Default values that do NOT override the existing field:
#'
#' | field | default that does not override |
#' |---|---|
#' | `usage`   | `NA_character_` |
#' | `label`   | `NA_character_` |
#' | `format`  | `NULL` |
#' | `visible` | `TRUE` |
#' | `width`   | `NA_real_` |
#' | `align`   | `NA_character_` |
#' | `na_text` | `""` |
#'
#' ```r
#' # Three-stage build: label/usage first, alignment second, width
#' # third. Each stage leaves earlier fields intact.
#' tabular(saf_demo) |>
#'   cols(variable = col_spec(usage = "group", label = "Parameter")) |>
#'   cols(variable = col_spec(align = "left")) |>
#'   cols(variable = col_spec(width = 2.0))
#' # Result: variable has usage="group", label="Parameter",
#' #         align="left", width=2.0 — all four fields set.
#' ```
#'
#' @param .spec *The `tabular_spec` to extend.*
#'   `<tabular_spec>: required`. Dot-prefixed so R's partial argument
#'   matching cannot accidentally bind a short user-supplied name
#'   (e.g. `s`, `sp`) in `...` to the spec slot. Pipe input
#'   (`tabular(...) |> cols(...)`) works the normal way — the spec
#'   is supplied positionally.
#'
#' @param ... *Named `col_spec` objects, one per column.* Each name
#'   is the input column name in `.spec@data`. Names must match an
#'   existing column — pre-compute derived columns upstream with
#'   `dplyr::mutate()` (or equivalent) before [`tabular()`].
#'
#'   **Restriction:** Names must be unique within a single `cols()`
#'   call (duplicates warn; "last value wins").
#'   **Tip:** To override an attribute already declared, use a
#'   second `cols()` call downstream and let the merge rule apply.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`headers()`], [`sort_rows()`], [`style()`].
#'
#' @examples
#' # ---- Example 1: Demographics with arm BigN inline in headers ----
#' #
#' # Demographics table where the row-label columns sit on the left
#' # and the four treatment-arm columns embed BigN in the header
#' # label (drawn inline from the bundled `saf_n` data frame). Every
#' # arm column is decimal-aligned so mixed-format cells like
#' # "5 (3.2%)" line up on the decimal mark.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#'
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     sprintf("Safety Population (N=%d)", n["Total"])
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
#'     Total      = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # ---- Example 2: BOR table with CDISC factor ordering and hidden helper ----
#' #
#' # Best Overall Response table where `stat_label` carries the
#' # canonical CDISC factor levels (driving the sort) and `row_type`
#' # is hidden — present in the data for the sort, absent from the
#' # rendered output via `col_spec(visible = FALSE)`.
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
#'     placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"]),  align = "decimal"),
#'     drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"]),  align = "decimal"),
#'     drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]), align = "decimal")
#'   ) |>
#'   sort_rows(by = "stat_label")
#'
#' # ---- Example 3: AE-by-SOC/PT with indented label + repeat-call merge ----
#' #
#' # `label` carries SOC text on SOC rows and PT text on PT rows;
#' # `indent_by = "indent_level"` indents the PT rows one level under
#' # their SOC. `soc`, `row_type`, and `n_total` ride along as hidden
#' # sort keys. A second `cols()` call later in the chain adds widths
#' # once the user knows the page geometry; the repeat-call merge
#' # preserves prior attributes (label, indent_by, align, visible)
#' # without restating them.
#' ae <- saf_aesocpt
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#'
#' tabular(
#'   ae,
#'   titles = c("Table 14.3.1", "Adverse Events by SOC and Preferred Term")
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100", align = "decimal"),
#'     Total    = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
#'   # Second `cols()` call: add widths after the rest of the spec
#'   # is built. Repeat-call merge preserves prior attributes.
#'   cols(
#'     label    = col_spec(width = "2.5in"),
#'     placebo  = col_spec(width = "0.9in"),
#'     drug_50  = col_spec(width = "0.9in"),
#'     drug_100 = col_spec(width = "0.9in"),
#'     Total    = col_spec(width = "0.9in")
#'   )
#'
#' # ---- Example 4: Compact AE-overall with pre-derived Active column ----
#' #
#' # Drop the per-arm columns and surface only the Total. Pre-compute
#' # the pooled "Active" column upstream (here `paste0(drug_50, " / ",
#' # drug_100)`) before piping into `tabular()`; `cols()` then just
#' # declares each column's display role. The same pattern handles
#' # any post-pivot derivation (`pivot_across() |> mutate(...) |>
#' # tabular()`).
#' ae <- saf_aeoverall
#' ae$active <- paste0(ae$drug_50, " / ", ae$drug_100)
#'
#' tabular(
#'   ae,
#'   titles = c("Table 14.3.0", "Adverse Event Overview"),
#'   footnotes = "Active = pooled Drug 50 + Drug 100 columns."
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = ""),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     active     = col_spec(label = "Active arms"),
#'     drug_50    = col_spec(visible = FALSE),
#'     drug_100   = col_spec(visible = FALSE),
#'     Total      = col_spec(label = "Total", align = "decimal")
#'   )
#'
#' @seealso
#' **Companion constructor:** [`col_spec()`] builds the per-column
#' DSL object that `cols()` attaches.
#'
#' **Sibling build verbs:** [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
cols <- function(.spec, ...) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  args <- list(...)
  if (length(args) == 0L) {
    return(.spec)
  }

  arg_names <- names(args)
  if (is.null(arg_names) || any(arg_names == "")) {
    cli::cli_abort(
      c(
        "All arguments to {.fn cols} must be named.",
        "i" = "Each name is the input column name in {.arg data}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  for (i in seq_along(args)) {
    if (!is_col_spec(args[[i]])) {
      cli::cli_abort(
        c(
          "Each entry in {.fn cols} must be a {.cls col_spec}.",
          "x" = "{.arg {arg_names[[i]]}} is {.obj_type_friendly {args[[i]]}}.",
          "i" = "Use {.fn col_spec} to build one."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  dup_idx <- duplicated(arg_names)
  if (any(dup_idx)) {
    dups <- unique(arg_names[dup_idx])
    cli::cli_warn(
      c(
        "{length(dups)} duplicate column name{?s} in {.fn cols}, last value wins.",
        "x" = "Repeated: {.val {dups}}."
      ),
      call = call
    )
    keep <- !duplicated(arg_names, fromLast = TRUE)
    args <- args[keep]
    arg_names <- arg_names[keep]
  }

  data_cols <- names(.spec@data)
  for (i in seq_along(args)) {
    nm <- arg_names[[i]]
    if (!(nm %in% data_cols)) {
      cli::cli_abort(
        c(
          "{.val {nm}} is not a column of {.arg data}.",
          "x" = "Available columns: {.val {data_cols}}.",
          "i" = "Pre-compute derived columns upstream with {.fn dplyr::mutate} (or equivalent) before {.fn tabular}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }

  new_cols <- .spec@cols
  for (i in seq_along(args)) {
    nm <- arg_names[[i]]
    incoming <- S7::set_props(args[[i]], name = nm)
    if (nm %in% names(new_cols)) {
      new_cols[[nm]] <- .merge_col_spec(new_cols[[nm]], incoming)
    } else {
      new_cols[[nm]] <- incoming
    }
  }

  S7::set_props(.spec, cols = new_cols)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Merge `new` into `existing` field-by-field. A non-default value in
# `new` overrides the corresponding field in `existing`; a default
# (NA / NULL / "") leaves the existing field unchanged. Defaults map
# to the constructor defaults of col_spec(). `name` always takes the
# new value (cols() just stamped it).
.merge_col_spec <- function(existing, new) {
  out <- existing
  out <- S7::set_props(out, name = new@name)
  if (!is.na(new@usage)) {
    out <- S7::set_props(out, usage = new@usage)
  }
  if (!is.na(new@label)) {
    out <- S7::set_props(out, label = new@label)
  }
  if (!is.null(new@format)) {
    out <- S7::set_props(out, format = new@format)
  }
  if (!isTRUE(new@visible)) {
    out <- S7::set_props(out, visible = new@visible)
  }
  if (!is.na(new@width)) {
    out <- S7::set_props(out, width = new@width)
  }
  if (!is.na(new@align)) {
    out <- S7::set_props(out, align = new@align)
  }
  if (!identical(new@na_text, "")) {
    out <- S7::set_props(out, na_text = new@na_text)
  }
  if (!is.na(new@indent_by)) {
    out <- S7::set_props(out, indent_by = new@indent_by)
  }
  out
}
