# headers.R — variadic multi-level column-header DSL. Each top-level
# named argument is a header band; the value is either a character
# vector of data-column names (leaf band) or a named list of nested
# bands (inner band, arbitrary depth). A repeat call REPLACES the
# prior tree — header structure is a single spec, not a stackable
# list, matching tinytable's headers() / gt's tab_spanner cascades.

#' Attach multi-level column headers
#'
#' Build the column-header band(s) above the rendered table. Each
#' named argument is one band; the value is either a character
#' vector of column names (leaf band) or a named list of further
#' bands (inner band). Nesting depth is arbitrary — the engine
#' renders one band row per depth level, with each cell spanning the
#' columns of its leaves.
#'
#' @details
#'
#' **Replace, not stack.** A second `headers()` call REPLACES the
#' prior tree — header structure is a single spec, not a stackable
#' list. Call with no arguments to clear the tree.
#'
#' **Strict label rule.** Every declared band label must carry
#' visible text — empty strings, NA, and whitespace-only labels are
#' rejected at every nesting level. This is stricter than
#' [`col_spec()`], which DOES accept empty labels (a row-label
#' column with no header text is a legitimate clinical case). A
#' silently-blank band would be a layout artefact.
#'
#' **Uncovered columns render naked.** Columns not referenced under
#' any band render with their `col_spec.label` only — no extra band
#' row above them. This is the canonical pattern for row-label
#' columns (`variable`, `soc`, `stat_label`).
#'
#' **Multi-line band labels.** Embed `\n` in a band label for a
#' two-line band cell (arm name on row 1, BigN on row 2).
#'
#' @section Passthrough leaves inside a nested band:
#'
#' Inside a nested-list value, a child entry may be **unnamed** —
#' the entry is then a character vector of column names that sit
#' directly under the parent with no intermediate band at this
#' depth. Use this when one column under a band has no sub-grouping
#' while its siblings do. The strict-label rule still applies to
#' every declared band; an unnamed passthrough is NOT a band with a
#' missing label — it is "no band declared at this depth for this
#' column."
#'
#' @param .spec *The `tabular_spec` to attach the header tree to.*
#'   `<tabular_spec>: required`. Dot-prefixed so R's partial argument
#'   matching cannot accidentally bind a short user-supplied band
#'   label in `...` to the spec slot.
#'
#' @param ... *Named header bands.* Each name is the band label
#'   (must be non-blank); each value is either:
#'
#'   *   a **character vector** of data-column names — leaf band, or
#'   *   a **named list** whose entries follow the same recursive
#'       pattern — inner band.
#'
#'   Inside a nested-list value, an unnamed character-vector entry
#'   declares a passthrough leaf (see the Passthrough section above).
#'
#'   **Restriction:** Every column referenced must exist in
#'   `.spec@data`. A column may appear under at most one leaf.
#'   Names must be unique within one `headers()` call.
#'   **Tip:** Pass `headers()` with no arguments to clear the tree.
#'
#' @return *The updated `tabular_spec`.* Continue chaining with
#'   [`sort_rows()`], [`derive()`], [`style()`].
#'
#' @examples
#' # ---- Example 1: Single "Treatment Group" band over four arms ----
#' #
#' # AE-by-SOC/PT table with one flat band labelled "Treatment Group"
#' # spanning the four arm columns and the Total column. The
#' # row-label column (`soc`) sits to the left of the band with no
#' # header covering it — the canonical clinical layout.
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
#'   headers(
#'     "Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' # ---- Example 2: Two-level nested band — Control vs Active arms ----
#' #
#' # Efficacy BOR table where the active arms are grouped under an
#' # "Active" sub-band and the placebo arm under a "Control"
#' # sub-band, both under a single "Treatment Group" parent.
#' # Demonstrates the named-list value form for arbitrary-depth
#' # nesting.
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
#'   headers(
#'     "Treatment Group" = list(
#'       "Control" = "placebo",
#'       "Active"  = c("drug_50", "drug_100")
#'     )
#'   ) |>
#'   sort_rows(by = "stat_label")
#'
#' # ---- Example 3: Multiple peer bands side by side ----
#' #
#' # Vital-signs summary where the parameter columns (param,
#' # paramcd, visit, stat_label) sit on the left under a "Variable"
#' # band, and the arm columns sit on the right under "Treatment
#' # Group". Demonstrates multiple top-level bands in one call --
#' # bands render side by side in the order declared.
#' vit <- saf_vital
#' tabular(vit, titles = c("Table 14.4.1", "Vital Signs Summary")) |>
#'   cols(
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     paramcd    = col_spec(visible = FALSE),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal")
#'   ) |>
#'   headers(
#'     "Variable"        = c("param", "visit", "stat_label"),
#'     "Treatment Group" = c("placebo", "drug_50", "drug_100")
#'   )
#'
#' # ---- Example 4: Three-tier band over efficacy arms + Total ----
#' #
#' # Demographics-style three-tier nesting: top band labels the
#' # whole arm strip, middle band splits Active vs Placebo, leaf
#' # bands carry the per-arm column labels. Each child within a
#' # `list(...)` may itself be a `list(...)` — bands nest to
#' # arbitrary depth using nested list literals.
#' n <- stats::setNames(saf_n$n, saf_n$arm_short)
#' tabular(saf_demo, titles = "Demographics, hierarchical headers") |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = sprintf("N=%d", n["placebo"])),
#'     drug_50    = col_spec(label = sprintf("N=%d", n["drug_50"])),
#'     drug_100   = col_spec(label = sprintf("N=%d", n["drug_100"])),
#'     Total      = col_spec(label = sprintf("N=%d", n["Total"]))
#'   ) |>
#'   headers(
#'     "Treatment Group" = list(
#'       "Control" = "placebo",
#'       "Active"  = list(
#'         "Drug 50"  = "drug_50",
#'         "Drug 100" = "drug_100"
#'       ),
#'       "Pooled"  = "Total"
#'     )
#'   )
#'
#' @seealso
#' **Companion verb:** [`cols()`] / [`col_spec()`] sets per-column
#' labels — the leaf-row header text that sits below the band rows
#' this verb builds.
#'
#' **Sibling build verbs:** [`sort_rows()`], [`derive()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' **Inline label formatting:** [`md()`], [`html()`].
#'
#' @export
headers <- function(.spec, ...) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  args <- list(...)
  if (length(args) == 0L) {
    return(S7::set_props(.spec, headers = list()))
  }

  arg_names <- names(args)
  if (
    is.null(arg_names) || anyNA(arg_names) || any(.is_blank_label(arg_names))
  ) {
    cli::cli_abort(
      c(
        "Every argument to {.fn headers} must have a non-blank band label.",
        "x" = "Empty, NA, and whitespace-only labels are not allowed.",
        "i" = "Each name renders above its columns; a band with no text would be a silent layout artefact."
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
        "{length(dups)} duplicate band label{?s} in a single {.fn headers} call.",
        "x" = "Repeated: {.val {dups}}.",
        "i" = "Each band label must be unique within one call."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  tree <- lapply(seq_along(args), function(i) {
    .build_header_node(
      label = arg_names[[i]],
      value = args[[i]],
      path = arg_names[[i]],
      call = call
    )
  })

  .validate_header_tree(tree, data_cols = names(.spec@data), call = call)

  S7::set_props(.spec, headers = tree)
}

# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

# Recursively build a header_node from a (label, value) pair.
# value is either:
# *   a character vector -> leaf band; vector becomes @span
# *   a named list -> inner band; entries recurse to children
# `path` is the dotted path from root to here, used in error messages
# so the user can locate the offending entry inside a nested tree.
.build_header_node <- function(label, value, path, call) {
  if (is.character(value)) {
    if (anyNA(value)) {
      cli::cli_abort(
        c(
          "{.fn headers} band {.val {path}} has NA in its column list.",
          "i" = "Each leaf band must be a character vector of data column names."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(header_node(label = label, span = value))
  }
  if (is.list(value)) {
    children <- .parse_band_children(value, path = path, call = call)
    return(header_node(label = label, children = children))
  }
  cli::cli_abort(
    c(
      "{.fn headers} band {.val {path}} must be a character vector or a named list.",
      "x" = "You supplied {.obj_type_friendly {value}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Walk the tree and validate against `data_cols`. Three checks:
# 1. Every spanned column must exist in data.
# 2. No column may appear under two different leaves (would render
#    twice or render ambiguously).
# 3. Leaves under one parent must be contiguous in data-column order
#    (validated at engine time, not here, so users can declare
#    headers before knowing final column order).
.validate_header_tree <- function(tree, data_cols, call) {
  all_spans <- unlist(lapply(tree, .collect_header_spans))
  missing <- setdiff(all_spans, data_cols)
  if (length(missing) > 0L) {
    cli::cli_abort(
      c(
        "{.fn headers} references {length(missing)} column{?s} not in {.arg data}.",
        "x" = "Missing: {.val {missing}}.",
        "i" = "Available: {.val {data_cols}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  dup_idx <- duplicated(all_spans)
  if (any(dup_idx)) {
    dups <- unique(all_spans[dup_idx])
    cli::cli_abort(
      c(
        "{.fn headers} places {length(dups)} column{?s} under more than one band.",
        "x" = "Conflicting: {.val {dups}}.",
        "i" = "Each column may appear under at most one leaf band."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(NULL)
}

# Gather all data-column names appearing as leaves under `node`.
# Used both at verb-validate time (`.validate_header_tree`) and at
# engine time (`.flatten_header_node` in R/engine_headers.R).
.collect_header_spans <- function(node) {
  if (length(node@children) == 0L) {
    return(node@span)
  }
  unlist(lapply(node@children, .collect_header_spans))
}

# Blank-label predicate. A band label is blank when it is "", NA, or
# only whitespace. Rejected at every nesting level — a band with no
# rendered text is a silent layout artefact, never intentional.
.is_blank_label <- function(x) {
  is.na(x) | !nzchar(trimws(x))
}

# Parse the children of a nested-list band value. Each entry is one
# of two shapes:
#
# *   **named entry** -> the name is a declared sub-band label and
#     the value is recursively parsed (character vector = leaf band,
#     named list = inner band). Strict-label rule applies: the name
#     must be non-blank / non-NA / non-whitespace.
# *   **unnamed entry** -> the value must be a character vector of
#     data-column names; rendered as a passthrough leaf directly
#     under the parent band, with `label = NA_character_` on the
#     header_node so backends can emit a blank cell or rowspan-
#     merge the parent downward.
.parse_band_children <- function(value, path, call) {
  inner_names <- names(value)
  if (is.null(inner_names)) {
    inner_names <- rep("", length(value))
  }

  # Categorise each entry's name:
  #   ""    -> unnamed (R's standard positional marker) -> passthrough leaf
  #   NA / whitespace-only -> explicit blank label -> rejected by strict rule
  #   any other non-blank string -> declared sub-band -> recurse
  is_unnamed <- !is.na(inner_names) & inner_names == ""
  is_blank_explicit <- is.na(inner_names) |
    (!is_unnamed & !nzchar(trimws(inner_names)))
  if (any(is_blank_explicit)) {
    cli::cli_abort(
      c(
        "{.fn headers} band {.val {path}} has children with blank or NA labels.",
        "x" = "Whitespace-only and NA labels are not accepted as declared band labels.",
        "i" = "Use a non-blank label, or leave the entry unnamed (no {.code name =}) for a passthrough leaf."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  declared_names <- inner_names[!is_unnamed]
  dup <- duplicated(declared_names)
  if (any(dup)) {
    cli::cli_abort(
      c(
        "{.fn headers} band {.val {path}} has duplicate child labels.",
        "x" = "Repeated: {.val {unique(declared_names[dup])}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  lapply(seq_along(value), function(i) {
    nm <- inner_names[[i]]
    val <- value[[i]]
    if (is_unnamed[[i]]) {
      if (!is.character(val)) {
        cli::cli_abort(
          c(
            "{.fn headers} band {.val {path}} has an unnamed entry that is not a character vector.",
            "x" = "Unnamed entries declare passthrough leaves and must be data-column names.",
            "i" = "To label this band, add a name: {.code 'Label Name' = ...}."
          ),
          class = "tabular_error_input",
          call = call
        )
      }
      if (anyNA(val)) {
        cli::cli_abort(
          c(
            "{.fn headers} band {.val {path}} has NA in a passthrough leaf's column list.",
            "i" = "Each passthrough leaf is a character vector of data column names."
          ),
          class = "tabular_error_input",
          call = call
        )
      }
      return(header_node(label = NA_character_, span = val))
    }
    .build_header_node(
      label = nm,
      value = val,
      path = paste(path, nm, sep = " > "),
      call = call
    )
  })
}
