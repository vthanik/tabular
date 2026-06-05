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
#' | `na_text` | `NA_character_` (inherit preset) |
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
#' @param .default *Fallback `col_spec` for unmentioned columns.*
#'   `<col_spec | NULL>: default NULL`. When a `col_spec`, it is
#'   field-merged onto every data column that is NOT named in `...`
#'   and does not already carry a spec from an earlier `cols()` call.
#'   `NULL` (default) leaves unmentioned columns to the engine-time
#'   default. Use it to set one alignment / format across a variable
#'   number of arm columns in a single call.
#'
#'   **Interaction:** Explicit `...` specs always win — `.default`
#'   only fills the gaps. A column carried over from a prior `cols()`
#'   call is treated as already specified and is left untouched.
#'
#'   ```r
#'   # Decimal-align every arm column without listing each by name.
#'   tabular(saf_demo) |>
#'     cols(
#'       variable   = col_spec(usage = "group", label = "Parameter"),
#'       stat_label = col_spec(label = "Statistic"),
#'       .default   = col_spec(align = "decimal")
#'     )
#'   ```
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
#'     "Safety Population"
#'   ),
#'   footnotes = "Percentages based on N per treatment group."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total      = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
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
#'   "ORR (CR + PR)", "CBR (CR + PR + SD)",
#'   "DCR (CR + PR + SD + NON-CR/NON-PD)", "95% CI (Clopper-Pearson)"
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
#'     "Efficacy Evaluable Population"
#'   ),
#'   footnotes = "Response per RECIST 1.1, investigator assessment."
#' ) |>
#'   cols(
#'     stat_label  = col_spec(label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE),
#'     placebo    = col_spec(label = "Placebo\nN={ne['placebo']}",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50\nN={ne['drug_50']}",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100\nN={ne['drug_100']}", align = "decimal")
#'   ) |>
#'   sort_rows(by = c("groupid", "stat_label"))
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
#'     soc_n    = col_spec(visible = FALSE),
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
cols <- function(.spec, ..., .default = NULL) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  default_spec <- .default
  if (!is.null(default_spec) && !is_col_spec(default_spec)) {
    cli::cli_abort(
      c(
        "{.arg .default} must be a {.cls col_spec} or {.code NULL}.",
        "x" = "You supplied {.obj_type_friendly {default_spec}}.",
        "i" = "Use {.fn col_spec} to build one."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  args <- rlang::list2(...)
  if (length(args) == 0L && is.null(default_spec)) {
    return(.spec)
  }

  arg_names <- names(args)
  if (length(args) > 0L && (is.null(arg_names) || any(arg_names == ""))) {
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
    new_cols <- .set_col_spec(new_cols, nm, incoming, call)
  }

  # `.default` fills every data column not named in `...` and not
  # already carrying a spec (from this or a prior cols() call).
  if (!is.null(default_spec)) {
    specified <- names(new_cols)
    unmentioned <- setdiff(names(.spec@data), specified)
    for (nm in unmentioned) {
      ds <- S7::set_props(default_spec, name = nm)
      if (isTRUE(ds@label_deferred)) {
        ds <- .resolve_deferred_label(ds, nm, call)
      }
      new_cols[[nm]] <- ds
    }
  }

  S7::set_props(.spec, cols = new_cols)
}

#' Apply one column spec to many columns
#'
#' Field-merge a single [`col_spec()`] onto every column matched by
#' name or by a predicate. The vectorized companion to [`cols()`] for
#' the common case of a variable number of treatment-arm columns that
#' all share the same display rule (decimal alignment, a numeric
#' format), so you avoid `do.call()` / `!!!` splicing one named
#' argument per arm.
#'
#' @details
#'
#' **Field-merge, not replace.** `cols_apply()` reuses the same
#' field-by-field merge as repeated [`cols()`] calls: a non-default
#' field on `.col_spec` overrides; a default-valued field leaves any
#' prior attribute on the matched column intact. Set the shared rule
#' across arms first, then refine an individual arm with a later
#' [`cols()`] call (or the reverse).
#'
#' **Per-column label token.** A `label` that references `{.name}` (or
#' its alias `{.col}`) inside a `{expr}` is resolved *per matched
#' column*, with `.name` and `.col` both bound to that column's name.
#' This makes a variable-N arm header a single declarative call instead
#' of a hand-written loop. The rest of the `{expr}` evaluates in the
#' calling environment, so a per-arm BigN looked up from a named vector
#' works directly:
#'
#' ```r
#' n <- c(placebo = 86, drug_50 = 84, drug_100 = 84)
#' cols_apply(
#'   spec, c("placebo", "drug_50", "drug_100"),
#'   col_spec(label = "{.name}\n(N={n[.name]})", align = "decimal")
#' )
#' # placebo  -> "placebo\n(N=86)" ; drug_50 -> "drug_50\n(N=84)" ; ...
#' ```
#'
#' The token is a plain-string feature; a label wrapped in [`md()`] /
#' [`html()`] is parsed eagerly and does not interpolate. A failing
#' token expression aborts naming the offending column.
#'
#' **`width` merge.** `width`'s default sentinel for the merge is
#' `"auto"`: a later `cols()` / `cols_apply()` call carrying the default
#' `width = "auto"` leaves a previously pinned width intact (only an
#' explicit non-`"auto"` width overrides). Apply a shared width last to
#' broadcast it across arms.
#'
#' @param .spec *The `tabular_spec` to extend.*
#'   `<tabular_spec>: required`. Dot-prefixed so partial matching
#'   cannot bind a user name in another slot.
#'
#' @param .cols *Columns to match.*
#'   `<character | function>: required`. Either a character vector of
#'   input column names in `.spec@data`, or a predicate
#'   `function(names) -> logical` evaluated against `names(.spec@data)`
#'   (one logical per column, same length).
#'
#'   **Restriction:** Named columns must exist in `.spec@data`. A
#'   predicate must return a logical vector the length of
#'   `names(.spec@data)`.
#'   **Tip:** No tidyselect helpers ship; pass a base vector
#'   (`grep("^ARM", names(df), value = TRUE)`) or a predicate
#'   (`\(nm) startsWith(nm, "ARM")`).
#'
#' @param .col_spec *The spec to field-merge onto every match.*
#'   `<col_spec>: required`. Built with [`col_spec()`].
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`headers()`], [`sort_rows()`], [`style()`].
#'
#' @examples
#' # ---- Example 1: Decimal-align every arm column by name vector ----
#' #
#' # Demographics table whose treatment-arm columns are selected by a
#' # name vector (`grep()` against the data) and given one shared
#' # decimal-alignment spec, while the two row-label columns keep
#' # their own roles set with `cols()`.
#' arm_cols <- grep("^placebo$|^drug_|^Total$", names(saf_demo), value = TRUE)
#'
#' tabular(
#'   saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     "Safety Population"
#'   )
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic")
#'   ) |>
#'   cols_apply(arm_cols, col_spec(align = "decimal")) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' # ---- Example 2: Select arm columns with a predicate ----
#' #
#' # Best Overall Response table. The arm columns are matched with a
#' # predicate over the column names; the hidden sort helpers and the
#' # response label are declared with `cols()`. The predicate scales
#' # to any number of arms without editing the call.
#' bor_levels <- c(
#'   "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
#'   "ORR (CR + PR)", "CBR (CR + PR + SD)",
#'   "DCR (CR + PR + SD + NON-CR/NON-PD)", "95% CI (Clopper-Pearson)"
#' )
#' eff <- eff_resp
#' eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
#'
#' tabular(
#'   eff,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Best Overall Response and Response Rates",
#'     "Efficacy Evaluable Population"
#'   )
#' ) |>
#'   cols(
#'     stat_label  = col_spec(label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE)
#'   ) |>
#'   cols_apply(
#'     \(nm) nm %in% c("placebo", "drug_50", "drug_100"),
#'     col_spec(align = "decimal")
#'   ) |>
#'   sort_rows(by = c("groupid", "stat_label"))
#'
#' @seealso
#' **Companion verbs:** [`cols()`] attaches per-column specs by name;
#' [`col_spec()`] builds the spec.
#'
#' **Sibling build verbs:** [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' @export
cols_apply <- function(.spec, .cols, .col_spec) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  col_spec_arg <- .col_spec
  if (!is_col_spec(col_spec_arg)) {
    cli::cli_abort(
      c(
        "{.arg .col_spec} must be a {.cls col_spec}.",
        "x" = "You supplied {.obj_type_friendly {col_spec_arg}}.",
        "i" = "Use {.fn col_spec} to build one."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  data_cols <- names(.spec@data)
  matched <- .resolve_col_selection(.cols, data_cols, call = call)
  if (length(matched) == 0L) {
    cli::cli_warn(
      c(
        "{.fn cols_apply} matched no columns; the spec was not applied.",
        "i" = "Check {.arg .cols} against the data columns: {.val {data_cols}}."
      ),
      call = call
    )
    return(.spec)
  }

  new_cols <- .spec@cols
  for (nm in matched) {
    incoming <- S7::set_props(col_spec_arg, name = nm)
    new_cols <- .set_col_spec(new_cols, nm, incoming, call)
  }

  S7::set_props(.spec, cols = new_cols)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Resolve `.cols` (a character vector of column names or a predicate
# over the data column names) to a character vector of matched column
# names. Errors with tabular_error_input on missing names, a
# non-logical / wrong-length predicate result, or an unsupported type.
.resolve_col_selection <- function(cols, data_cols, call) {
  if (is.function(cols)) {
    hit <- cols(data_cols)
    if (!is.logical(hit) || length(hit) != length(data_cols)) {
      cli::cli_abort(
        c(
          "The {.arg .cols} predicate must return a logical vector.",
          "x" = "It returned {.obj_type_friendly {hit}} of length {length(hit)}.",
          "i" = "Expected a logical of length {length(data_cols)} (one per column)."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    hit[is.na(hit)] <- FALSE
    return(data_cols[hit])
  }

  if (is.character(cols)) {
    missing <- setdiff(cols, data_cols)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "{cli::qty(missing)} Column{?s} {.val {missing}} {?is/are} not in {.arg data}.",
          "x" = "Available columns: {.val {data_cols}}.",
          "i" = "Pre-compute derived columns upstream with {.fn dplyr::mutate} (or equivalent) before {.fn tabular}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(unique(cols))
  }

  cli::cli_abort(
    c(
      "{.arg .cols} must be a character vector or a predicate function.",
      "x" = "You supplied {.obj_type_friendly {cols}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Field-merge `incoming` onto the spec already stored under `nm`, or
# assign it fresh when `nm` has none. Shared by `cols()` and
# `cols_apply()` so the merge / assign rule lives in one place. `env` is
# the verb's caller environment, used to resolve a deferred `{.name}` /
# `{.col}` label against the column name `nm` before merge / assign.
.set_col_spec <- function(new_cols, nm, incoming, env) {
  if (isTRUE(incoming@label_deferred)) {
    incoming <- .resolve_deferred_label(incoming, nm, env)
  }
  if (nm %in% names(new_cols)) {
    new_cols[[nm]] <- .merge_col_spec(new_cols[[nm]], incoming)
  } else {
    new_cols[[nm]] <- incoming
  }
  new_cols
}

# Resolve a deferred `{.name}` / `{.col}` label for the matched column
# `nm`. Interpolates the raw template in a child of the verb's caller
# `env` with `.name` and `.col` both bound to `nm`, so a token like
# `{N[.name]}` looks the column name up in the caller's data. Clears the
# deferral flag. A failing expression re-raises with the column named.
.resolve_deferred_label <- function(incoming, nm, env) {
  child <- new.env(parent = env)
  child$.name <- nm
  child$.col <- nm
  resolved <- tryCatch(
    .interpolate(incoming@label, env = child, call = env),
    tabular_error_input = function(e) {
      cli::cli_abort(
        "Could not resolve the {.arg label} token for column {.val {nm}}.",
        parent = e,
        class = "tabular_error_input",
        call = env
      )
    }
  )
  S7::set_props(incoming, label = resolved, label_deferred = FALSE)
}

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
    out <- S7::set_props(
      out,
      label = new@label,
      label_deferred = new@label_deferred
    )
  }
  if (!is.null(new@format)) {
    out <- S7::set_props(out, format = new@format)
  }
  if (!isTRUE(new@visible)) {
    out <- S7::set_props(out, visible = new@visible)
  }
  if (!is.na(new@width)) {
    # `width_user` is the immutable snapshot of the user width; keep it in
    # lockstep with `width` so the HTML percent-width path stays correct.
    out <- S7::set_props(out, width = new@width, width_user = new@width_user)
  }
  if (!is.na(new@align)) {
    out <- S7::set_props(out, align = new@align)
  }
  if (!is.na(new@valign)) {
    out <- S7::set_props(out, valign = new@valign)
  }
  if (!identical(new@group_display, "header_row")) {
    out <- S7::set_props(out, group_display = new@group_display)
  }
  if (!is.na(new@group_skip)) {
    out <- S7::set_props(out, group_skip = new@group_skip)
  }
  if (!is.na(new@na_text)) {
    out <- S7::set_props(out, na_text = new@na_text)
  }
  if (!is.na(new@indent_by)) {
    out <- S7::set_props(out, indent_by = new@indent_by)
  }
  out
}
