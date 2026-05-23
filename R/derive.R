# derive.R — attach display-time row-arithmetic to a tabular_spec.
# Each named argument becomes one `derive_spec`, captured as a
# quosure so the expression environment travels with it. Derives
# stack across calls; same-name within or across calls replaces.
# The engine resolves them via topological sort (see R/engine_derive.R)
# so a derive may reference an earlier derive's output column.

#' Add computed display columns
#'
#' Attach one or more `derive_spec` entries to a `tabular_spec`. Each
#' `name = expr` argument defines a new output column whose value is
#' computed at engine time from the columns already in `.spec@data`
#' (and from any earlier derive's output). `derive()` is pure
#' row-arithmetic.
#'
#' @details
#'
#' **No aggregation.** Aggregation (mean / sum / sd / n) happens
#' upstream in `cards`, `dplyr`, or SAS — never inside `derive()`.
#' The engine rejects `<col>.<stat>` symbols (e.g. `n.mean`,
#' `events.sum`) with a hint to pre-compute upstream.
#'
#' **Vectorised evaluation.** Each expression is evaluated ONCE with
#' the full column vectors in scope, not per-row. Expressions must
#' be vectorisable (R's recycling rules apply). Performance is
#' linear in row count; no per-row loops.
#'
#' **`.c` accessor for unknown-name pivots.** Inside each expression,
#' `.c` is a list of all current columns indexed by both name and
#' position. Use `.c[[3]]` or `.c[["drug_50"]]` when the column name
#' is not known at write time — typical after a [`pivot_across()`]
#' pivot lands a variable number of arm columns.
#'
#' **Topological resolution.** Derives can reference earlier derives
#' by name. The engine builds a dependency graph and resolves in
#' topo-sorted order; a cycle raises `tabular_error_input`. Across
#' calls, a later `derive()` with the same name REPLACES the earlier
#' one. Within one call, duplicate names are an error.
#'
#' **Auto-attached `col_spec`.** If the output name has no
#' `col_spec` entry yet, `derive()` attaches a fresh
#' `col_spec(usage = "computed")` so the column renders. If an entry
#' already exists (it must carry `usage = "computed"` — [`cols()`]
#' rejects non-data names with any other usage), its label, format,
#' alignment, and width are preserved. The canonical pattern is to
#' declare the label / format up front via [`cols()`] and let
#' `derive()` supply the values.
#'
#' @param .spec *The `tabular_spec` to extend.*
#'   `<tabular_spec>: required`. Dot-prefixed so R's partial argument
#'   matching cannot accidentally bind a short user-supplied name
#'   (e.g. `s`, `sp`) in `...` to the spec slot.
#'
#' @param ... *Named expressions, one per computed column.* Each
#'   name is the output column; each expression is captured as an
#'   rlang quosure and evaluated at engine time against `.spec@data`
#'   augmented with prior-derive outputs and `.c`.
#'
#'   **Restriction:** Names must be unique within one `derive()`
#'   call AND must not collide with an existing column in
#'   `.spec@data`. Expression must be vectorisable; aggregation
#'   symbols (`<col>.<stat>`) are rejected.
#'   **Tip:** Reference earlier derives by name — the engine
#'   topo-sorts the dependency graph so order of declaration doesn't
#'   matter.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`sort_rows()`], [`style()`].
#'
#' @examples
#' # ---- Example 1: Response rates and risk difference ----
#' #
#' # Efficacy responder counts per arm with a known denominator,
#' # derive the ORR percentage and the treatment-vs-placebo risk
#' # difference inline so the rendered table shows both raw counts
#' # and derived statistics in one band. Declare the label,
#' # alignment, and format for the derived columns upfront via
#' # `cols()`; `derive()` then just supplies the values.
#' resp <- data.frame(
#'   stat_label = c("Responders", "Non-responders"),
#'   placebo    = c(3L, 83L),
#'   drug_50    = c(12L, 72L),
#'   drug_100   = c(18L, 66L)
#' )
#' ne <- stats::setNames(eff_n$n, eff_n$arm_short)
#'
#' tabular(
#'   resp,
#'   titles = c(
#'     "Table 14.2.2",
#'     "Objective Response Rate and Risk Difference",
#'     sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
#'   ),
#'   footnotes = c(
#'     "Response per RECIST 1.1, investigator assessment.",
#'     "Risk difference vs placebo, percentage points."
#'   )
#' ) |>
#'   cols(
#'     stat_label = col_spec(usage = "group", label = "Outcome"),
#'     placebo  = col_spec(
#'       label = sprintf("Placebo\nN=%d", ne["placebo"]),
#'       align = "decimal"
#'     ),
#'     drug_50  = col_spec(
#'       label = sprintf("Drug 50\nN=%d", ne["drug_50"]),
#'       align = "decimal"
#'     ),
#'     drug_100 = col_spec(
#'       label = sprintf("Drug 100\nN=%d", ne["drug_100"]),
#'       align = "decimal"
#'     ),
#'     pct_50  = col_spec(
#'       usage = "computed", label = "Drug 50\n%",
#'       align = "decimal", format = "%.1f"
#'     ),
#'     pct_100 = col_spec(
#'       usage = "computed", label = "Drug 100\n%",
#'       align = "decimal", format = "%.1f"
#'     ),
#'     diff_50 = col_spec(
#'       usage = "computed", label = "Drug 50 vs\nPlacebo (pp)",
#'       align = "decimal", format = "%+.1f"
#'     ),
#'     diff_100 = col_spec(
#'       usage = "computed", label = "Drug 100 vs\nPlacebo (pp)",
#'       align = "decimal", format = "%+.1f"
#'     )
#'   ) |>
#'   derive(
#'     pct_placebo = placebo  / ne[["placebo"]]  * 100,
#'     pct_50      = drug_50  / ne[["drug_50"]]  * 100,
#'     pct_100     = drug_100 / ne[["drug_100"]] * 100,
#'     diff_50     = pct_50  - pct_placebo,
#'     diff_100    = pct_100 - pct_placebo
#'   ) |>
#'   sort_rows(by = "stat_label")
#'
#' # ---- Example 2: Exposure-adjusted event rates per 100 patient-years ----
#' #
#' # AE counts per arm paired with a side data frame of patient-years
#' # exposure, derive the rate per 100 patient-years inline.
#' # Demonstrates a derive that references both an input column
#' # (events) and a constant lookup vector.
#' ae <- data.frame(
#'   soc        = c("CARDIAC DISORDERS", "GASTROINTESTINAL", "NERVOUS SYSTEM"),
#'   placebo_n  = c( 5L, 12L,  8L),
#'   drug_50_n  = c( 9L, 22L, 17L),
#'   drug_100_n = c(14L, 31L, 26L)
#' )
#' py <- c(placebo = 41.2, drug_50 = 38.9, drug_100 = 37.4)
#'
#' tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.5",
#'     "Adverse Events per 100 Patient-Years by SOC",
#'     "Safety Population"
#'   ),
#'   footnotes = "Exposure-adjusted rate = events / patient-years * 100."
#' ) |>
#'   cols(
#'     soc        = col_spec(usage = "group", label = "System Organ Class"),
#'     placebo_n  = col_spec(label = "Placebo\nEvents",  align = "decimal"),
#'     drug_50_n  = col_spec(label = "Drug 50\nEvents",  align = "decimal"),
#'     drug_100_n = col_spec(label = "Drug 100\nEvents", align = "decimal"),
#'     placebo_rate = col_spec(
#'       usage  = "computed",
#'       label  = "Placebo\nRate",
#'       align  = "decimal",
#'       format = "%.1f"
#'     ),
#'     drug_50_rate = col_spec(
#'       usage  = "computed",
#'       label  = "Drug 50\nRate",
#'       align  = "decimal",
#'       format = "%.1f"
#'     ),
#'     drug_100_rate = col_spec(
#'       usage  = "computed",
#'       label  = "Drug 100\nRate",
#'       align  = "decimal",
#'       format = "%.1f"
#'     )
#'   ) |>
#'   derive(
#'     placebo_rate  = placebo_n  / py[["placebo"]]  * 100,
#'     drug_50_rate  = drug_50_n  / py[["drug_50"]]  * 100,
#'     drug_100_rate = drug_100_n / py[["drug_100"]] * 100
#'   ) |>
#'   sort_rows(by = "soc")
#'
#' @seealso
#' [`cols()`] to declare `col_spec(usage = "computed")` upfront with
#' a label and format that `derive()` then fills.
#'
#' **Sibling build verbs:** [`headers()`], [`sort_rows()`],
#' [`style()`].
#'
#' **Entry verb:** [`tabular()`].
#'
#' @export
derive <- function(.spec, ...) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  args <- rlang::enquos(...)
  if (length(args) == 0L) {
    return(.spec)
  }

  arg_names <- names(args)
  if (is.null(arg_names) || any(arg_names == "")) {
    cli::cli_abort(
      c(
        "All arguments to {.fn derive} must be named.",
        "i" = "Each name becomes the output column."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  dup_idx <- duplicated(arg_names)
  if (any(dup_idx)) {
    dups <- unique(arg_names[dup_idx])
    cli::cli_abort(
      c(
        "{length(dups)} duplicate name{?s} in a single {.fn derive} call.",
        "x" = "Repeated: {.val {dups}}.",
        "i" = "Use one entry per output column, or chain a second {.fn derive} call."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  data_cols <- names(.spec@data)
  conflicts <- intersect(arg_names, data_cols)
  if (length(conflicts) > 0L) {
    cli::cli_abort(
      c(
        "{.fn derive} cannot overwrite {length(conflicts)} existing data column{?s}.",
        "x" = "Conflicting: {.val {conflicts}}.",
        "i" = "Pick a new name, or rename the input column upstream."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  new_derives <- .spec@derives
  new_cols <- .spec@cols
  for (i in seq_along(args)) {
    nm <- arg_names[[i]]
    new_derives[[nm]] <- derive_spec(name = nm, expr = args[[i]])
    new_cols[[nm]] <- .ensure_computed_col_spec(
      existing = new_cols[[nm]],
      name = nm
    )
  }

  S7::set_props(.spec, derives = new_derives, cols = new_cols)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Ensure the cols entry for a derived column is `usage = "computed"`.
#
# Reachable cases (cols() enforces an invariant that lets us drop the
# defensive branches):
# *   `existing` is NULL -> no prior cols entry, mint a new col_spec
#     with usage = "computed".
# *   `existing` is non-NULL -> cols() only admits a non-data column
#     when usage is already "computed", and derive()'s data-conflict
#     check rejects names already in data; the only reachable shape
#     has usage = "computed". Stamp the name and return it intact.
.ensure_computed_col_spec <- function(existing, name) {
  if (is.null(existing)) {
    return(.col_spec_class(name = name, usage = "computed"))
  }
  S7::set_props(existing, name = name)
}
