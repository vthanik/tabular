# subgroup.R — partition a tabular_spec by one or more variables.
# When set, the engine runs the full resolve pipeline per group and
# concatenates the resulting page sets with a hard page break between
# groups. Each page descriptor of the merged grid carries a pre-
# rendered banner inline_ast so backends can emit the centred
# `<Label>: <Value>` row above the column-header rule.
#
# Phase 1 ships single-variable subgroup() only; multi-variable
# crossing lands in Phase 2.
#
# The column-list argument is `by =`, matching `sort_rows(by = ...)`.

#' Partition the report by a variable
#'
#' Attach a `subgroup_spec` to a `tabular_spec`. At render time the
#' engine partitions `spec@data` by the unique values of `by`,
#' runs the full resolve pipeline per group, and concatenates the
#' results. **A hard page break is inserted between groups** —
#' every subgroup value starts on its own page. A centred banner
#' line appears above the column-header rule on every page of the
#' group (including continuation pages), matching the canonical
#' submission page-layout convention.
#'
#' @details
#'
#' **Label is a glue-style template.** When `label` carries
#' `{col}` placeholders, the engine substitutes each placeholder
#' against the FIRST ROW of the group's filtered data — so any
#' column whose value is constant within group (BigN, cohort
#' descriptor, qualifier text) can ride into the banner. Columns
#' that vary within group also resolve, but always to the first
#' row's value; pre-compute aggregates upstream.
#'
#' **Default label** (when `label = NULL`, single var): the engine
#' generates `"<attr(data[[by]], 'label') %||% by>: {<by>}"`,
#' so `subgroup(by = "cohort")` renders banners like `"Cohort: A"`
#' and `"Cohort: B"` without further configuration.
#'
#' **Replace, not stack.** A second `subgroup()` call REPLACES the
#' prior partition — subgroup is a single spec, not a stackable
#' list. Passing `by = character(0)` clears the slot, though
#' typical clinical pipelines set the partition once up front.
#'
#' **Display-side only.** `subgroup()` partitions a pre-summarised
#' wide data frame; it does not aggregate, filter, or weight. The
#' user supplies one summary row per displayed row per group;
#' tabular's job is solely to lay them out with the per-group
#' banner and page break.
#'
#' **Multi-variable crossing.** `by = c("SEX", "AGEGR1")` partitions
#' on every combination present in the data (first variable varies
#' slowest, matching `expand.grid()` convention). An explicit
#' `label` template is required for multi-var partitions since the
#' single-var default `"<var>: {<var>}"` does not generalise; raise
#' `tabular_error_subgroup_label_required` otherwise.
#'
#' **Auto-hide of partition + template columns.** Every column named
#' in `by`, plus every column referenced via a `{col}` placeholder
#' in `label`, automatically flips to `visible = FALSE` at engine
#' time. Users do not restate `col_spec(visible = FALSE)` inside
#' [`cols()`] for these columns — mirroring the
#' [`col_spec(indent_by = ...)`][col_spec()] auto-hide ergonomic.
#'
#' @param .spec *The `tabular_spec` to partition.*
#'   `<tabular_spec>: required`.
#'
#' @param by *Column name(s) to partition by.*
#'   `<character>: required`. Must reference a column in
#'   `spec@data`. Length-0 (or `character(0)`) clears the partition.
#'   Matches the `by =` arg convention of [`sort_rows()`].
#'
#'   **Multi-variable.** Pass `c("var1", "var2")` to cross on every
#'   combination present in the data. Multi-var partitions require
#'   an explicit `label` template (the single-var auto-default does
#'   not generalise).
#'
#' @param label *Banner template.*
#'   `<character(1) | NULL>: default NULL`. Glue-style template
#'   with `{column_name}` placeholders. `NULL` derives a default
#'   from the partition variable's `attr(data[[by]], "label")`
#'   (falling back to the column name).
#'
#'   **Tip:** reference auxiliary columns to inline the BigN or
#'   any qualifier that is constant within group — e.g.
#'   `"Cohort: {cohort} (N = {n})"`.
#'
#'   **Restriction:** Every `{col}` reference must be a column in
#'   `spec@data`. Unknown columns raise
#'   `tabular_error_subgroup_template_unknown_col`.
#'
#' @param big_n *Per-page BigN denominators.*
#'   `<data.frame> | NULL: default NULL`. A table giving the `(N=x)`
#'   denominator each arm's header should show on each subgroup page.
#'   Each arm is named as it appears in the header — either a data
#'   column (the N rides that column's leaf label) **or** a
#'   [`headers()`] band label (the N rides that spanner band). Ns are
#'   non-negative whole numbers; provide one per `by` combination
#'   present in the data. Accepts **either** shape:
#'
#'   * **Wide** — the `by` column(s) plus one numeric column per arm
#'     (cells are the Ns).
#'   * **Long** — the `by` column(s) plus one arm-name column and one
#'     numeric N column, i.e. `dplyr::count()` / `summarise()` output
#'     used directly with no reshaping.
#'
#'   ```r
#'   # Wide: one column per arm.
#'   wide <- tibble::tribble(
#'     ~sex, ~placebo, ~drug_50, ~Total,
#'     "F",       24L,       9L,    42L,
#'     "M",       18L,      15L,    47L
#'   )
#'   # Long: count()-style, pivoted internally. Equivalent to `wide`.
#'   long <- tibble::tribble(
#'     ~sex, ~arm,      ~n,
#'     "F",  "placebo", 24L,
#'     "F",  "drug_50",  9L,
#'     "F",  "Total",   42L,
#'     "M",  "placebo", 18L,
#'     "M",  "drug_50", 15L,
#'     "M",  "Total",   47L
#'   )
#'   spec |> subgroup(by = "sex", big_n = long)
#'   ```
#'
#'   **Requirement:** band keying needs [`headers()`] **before**
#'   `subgroup()` in the pipeline; each arm name must resolve to
#'   exactly one leaf XOR one band. Every missing per-page N is a
#'   call-time error, never a silently wrong denominator.
#'
#'   **Note:** the per-arm N renders in every backend. The paged
#'   backends (RTF, PDF / LaTeX, DOCX) carry it on the column header
#'   that repeats on every page of the subgroup. HTML and Markdown are
#'   continuous (one stacked table, one header), so they instead emit a
#'   per-arm N row directly under each subgroup banner, the `(N=x)`
#'   aligned beneath its arm column.
#'
#' @param big_n_fmt *Per-page BigN template.*
#'   `<character(1)>: default "\n(N={n})"`. Appended to each arm's
#'   header label, with `{n}` substituted by that page/column's
#'   integer N. Only the `{n}` token is allowed; the default puts the
#'   N on its own line under the arm name.
#'
#' @return *The updated `tabular_spec`.* Continue chaining or
#'   resolve via [`as_grid()`] / [`emit()`].
#'
#' @examples
#' # ---- Example 1: Vital signs split into one page set per sex ----
#' #
#' # The simplest partition: a single clinical variable. Each `sex`
#' # value gets its own page set with a centred `Sex: <value>` banner
#' # above the column-header rule on every page, separated by hard page
#' # breaks. With no `label` template the banner uses the variable's
#' # `label` attribute when present (set here), falling back to the
#' # column name. Within each page, parameter nests visit nests the
#' # statistic rows.
#' vs <- cdisc_saf_subgroup
#' attr(vs$sex, "label") <- "Sex"
#'
#' tabular(
#'   vs,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Vital Signs by Visit",
#'     "Safety Population"
#'   ),
#'   footnotes = "Descriptive statistics by treatment arm."
#' ) |>
#'   cols(
#'     sex_n      = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup(by = "sex")
#'
#' # ---- Example 2: Partition by Sex with inline BigN via template ----
#' #
#' # `label` is a glue-style template; any column whose value is
#' # constant within group can ride into the banner. `cdisc_saf_subgroup`
#' # ships a partition-constant `sex_n` BigN column alongside the value
#' # cells, so each banner reads `"Sex: F (N = 143)"`, etc. `sex` and
#' # `sex_n` auto-hide from the body (partition `by` and template-
#' # referenced columns).
#' tabular(cdisc_saf_subgroup, titles = "Vital Signs by Visit") |>
#'   cols(
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup(by = "sex", label = "Sex: {sex} (N = {sex_n})")
#'
#' # ---- Example 3: Multi-variable crossing (Sex x Visit) ----
#' #
#' # Pass two columns to partition on every combination present in the
#' # data. The label template MUST reference each variable explicitly
#' # because the single-var auto-default does not generalise. The cross
#' # varies the first column (sex) slowest and the second (visit)
#' # fastest, giving page sequence F/Baseline, F/Week 8, ..., M/Baseline,
#' # ... Parameter nests the statistic rows within each page.
#' tabular(cdisc_saf_subgroup, titles = "Vital Signs by Sex and Visit") |>
#'   cols(
#'     sex_n      = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup(
#'     by    = c("sex", "visit"),
#'     label = "Sex: {sex} / Visit: {visit}"
#'   )
#'
#' # ---- Example 4: Per-page BigN — different (N=) per sex page ----
#' #
#' # Each sex page has a different per-arm population, so the `(N=x)`
#' # in the arm headers must vary by page. `big_n` is a wide table:
#' # the `by` column plus one column per arm (named as the data
#' # column), cells are the page-specific Ns. Each arm header then
#' # reads e.g. `Placebo` over `(N=53)` on the Female page and
#' # `(N=33)` on the Male page. RTF / PDF / DOCX carry the N on the
#' # repeating header; HTML and Markdown add a per-arm N row under each
#' # banner.
#' big_n <- tibble::tribble(
#'   ~sex, ~placebo, ~drug_50, ~drug_100, ~Total,
#'   "F",       53L,      55L,       35L,    143L,
#'   "M",       33L,      41L,       37L,    111L
#' )
#' tabular(cdisc_saf_subgroup, titles = "Vital Signs by Visit") |>
#'   cols(
#'     sex_n      = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup(by = "sex", label = "Sex: {sex}", big_n = big_n)
#'
#' # ---- Example 5: Clear a partition with subgroup(character()) ----
#' #
#' # `subgroup(by = character())` (or `subgroup(by = NULL)`) explicitly
#' # clears any prior partition — useful in programmatically-built
#' # pipelines where a downstream branch decides not to paginate by
#' # group after all. Give `sex` a `usage = "group"` role up front:
#' # while the sex partition is active it overrides that role (sex
#' # becomes the per-page banner); once cleared, sex falls back to a
#' # group level, so the pooled single-page render nests sex, parameter,
#' # and visit rather than leaving a stray partition column behind.
#' tabular(cdisc_saf_subgroup, titles = "Pooled (no sex partition)") |>
#'   cols(
#'     sex_n      = col_spec(visible = FALSE),
#'     paramcd    = col_spec(visible = FALSE),
#'     sex        = col_spec(usage = "group", label = "Sex"),
#'     param      = col_spec(usage = "group", label = "Parameter"),
#'     visit      = col_spec(usage = "group", label = "Visit"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo    = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100   = col_spec(label = "Drug 100", align = "decimal"),
#'     Total      = col_spec(label = "Total",    align = "decimal")
#'   ) |>
#'   subgroup("sex", label = "Sex: {sex}") |>
#'   # Decide later that the sex split was the wrong default —
#'   # clear it before rendering.
#'   subgroup(character())
#'
#' @seealso
#' **Pipeline siblings:** [`sort_rows()`], [`paginate()`].
#'
#' **Resolve / render:** [`as_grid()`], [`emit()`].
#'
#' @export
subgroup <- function(
  .spec,
  by,
  label = NULL,
  big_n = NULL,
  big_n_fmt = "\n(N={n})"
) {
  call <- rlang::caller_env()
  check_tabular_spec(.spec, call = call)

  if (missing(by) || is.null(by)) {
    by <- character()
  }
  if (!is.character(by)) {
    cli::cli_abort(
      c(
        "{.arg by} must be a character vector of column names.",
        "x" = "You supplied {.obj_type_friendly {by}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (anyNA(by) || (length(by) > 0L && any(!nzchar(by)))) {
    cli::cli_abort(
      c(
        "{.arg by} must not contain NA or empty strings."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  # Per-page BigN is meaningless without a partition: a table with no
  # subgroup uses the global `col_spec(label = "...(N={n['arm']})")`
  # route instead. Catch the misuse loudly rather than silently drop N.
  if (!is.null(big_n) && length(by) == 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} requires a non-empty {.arg by}.",
        "i" = "Per-page BigN only applies to a {.fn subgroup}-paginated table.",
        "i" = "For one global N, set it in the column label, e.g. {.code col_spec(label = \"Placebo (N=42)\")}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  # Empty by clears the slot — kept for the API shape; typical
  # clinical pipelines do not toggle subgroup mid-build.
  if (length(by) == 0L) {
    return(S7::set_props(.spec, subgroup = NULL))
  }

  unknown <- setdiff(by, names(.spec@data))
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{.arg by} references column{?s} not present in {.field .spec@data}: {.val {unknown}}.",
        "i" = "Available columns: {.val {names(.spec@data)}}."
      ),
      class = "tabular_error_subgroup_unknown_var",
      call = call
    )
  }

  if (anyDuplicated(by) > 0L) {
    cli::cli_abort(
      c(
        "{.arg by} must not repeat column names.",
        "x" = "Duplicate{?s}: {.val {by[duplicated(by)]}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }

  if (!is.null(label)) {
    if (!is.character(label) || length(label) != 1L || is.na(label)) {
      cli::cli_abort(
        c(
          "{.arg label} must be NULL or a length-1 non-NA character.",
          "i" = "Use a glue-style template, e.g. {.val Cohort: {{cohort}} (N = {{n}})}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    # Validate template references up-front so failures land at the
    # verb call site, not deep in the engine.
    refs <- .subgroup_template_refs(label)
    unknown_refs <- setdiff(refs, names(.spec@data))
    if (length(unknown_refs) > 0L) {
      cli::cli_abort(
        c(
          "{.arg label} references column{?s} not in {.field .spec@data}: {.val {unknown_refs}}.",
          "i" = "Available columns: {.val {names(.spec@data)}}."
        ),
        class = "tabular_error_subgroup_template_unknown_col",
        call = call
      )
    }
  } else if (length(by) > 1L) {
    # Multi-var partition without an explicit template — error
    # rather than guess at a default join. Aesthetic decisions
    # (separator, label-per-var, value formatting) belong to the
    # user, not the package.
    cli::cli_abort(
      c(
        "{.arg label} is required for multi-variable {.arg by}.",
        "i" = "Supply a glue-style template referencing each var, e.g. {.val Sex: {{SEX}} / Age: {{AGEGR1}}}."
      ),
      class = "tabular_error_subgroup_label_required",
      call = call
    )
  }

  if (!is.null(big_n)) {
    big_n <- .subgroup_bign_normalize(big_n, by, call)
    .subgroup_check_big_n(big_n, big_n_fmt, by, label, .spec, call)
  } else {
    big_n_fmt <- NULL
  }

  sg <- subgroup_spec(
    by = by,
    label = label,
    big_n = big_n,
    big_n_fmt = big_n_fmt
  )
  S7::set_props(.spec, subgroup = sg)
}

# ---------------------------------------------------------------------
# Per-page BigN — shared target resolution + call-time validation
# ---------------------------------------------------------------------

# Collect every non-NA header band label from a `header_node` tree,
# WITH multiplicity (so duplicate band labels are detectable). The
# walk needs only the tree; do NOT call engine_headers() here, which
# would run the contiguity check and surface an unrelated headers()
# error on the subgroup() call.
.subgroup_header_labels <- function(headers) {
  out <- character()
  walk <- function(node) {
    lbl <- node@label
    if (is.character(lbl) && length(lbl) == 1L && !is.na(lbl)) {
      out[[length(out) + 1L]] <<- lbl
    }
    for (ch in node@children) {
      walk(ch)
    }
  }
  for (node in headers) {
    walk(node)
  }
  out
}

# Resolve one big_n value-column name to its header target: a data
# column (leaf label) XOR a header band label (spanner band). Exactly
# one match is required. Returns list(kind, name) with kind one of
# "leaf", "band", "none" (zero targets), "ambiguous" (>1 target).
# The SINGLE source of truth used by both validation and application
# so the two can never disagree.
.subgroup_bign_target <- function(nm, data_names, band_labels) {
  is_leaf <- nm %in% data_names
  band_hits <- sum(band_labels == nm)
  n_targets <- as.integer(is_leaf) + band_hits
  if (n_targets == 0L) {
    return(list(kind = "none", name = nm))
  }
  if (n_targets > 1L) {
    return(list(kind = "ambiguous", name = nm))
  }
  if (is_leaf) {
    list(kind = "leaf", name = nm)
  } else {
    list(kind = "band", name = nm)
  }
}

# Build a per-row subgroup-combo key with an explicit NA sentinel so
# NA / factor / character by-cols compare correctly across frames.
.subgroup_combo_key <- function(df, by) {
  cols <- lapply(by, function(b) {
    v <- as.character(df[[b]])
    v[is.na(v)] <- "<NA>"
    v
  })
  do.call(paste, c(cols, list(sep = "\r")))
}

# Strict call-time validation of a `big_n` per-page denominator table.
# Every deviation aborts `tabular_error_input`. `spec` is the whole
# tabular_spec (header band labels + column visibility are needed).
# Normalise a `big_n` table to the canonical WIDE shape (the `by`
# column(s) plus one numeric column per arm). Accepts either:
#   * WIDE  every non-`by` column is already numeric; returned as-is.
#   * LONG  exactly one non-`by` character/factor column (arm names)
#           plus one non-`by` numeric column (the N); pivoted to wide,
#           so `dplyr::count(by, arm)` output works with no reshaping.
# Any other shape aborts, showing both layouts. A non-data-frame or a
# `by`-incomplete frame passes through untouched so the richer
# `.subgroup_check_big_n` produces the precise downstream error.
.subgroup_bign_normalize <- function(big_n, by, call) {
  if (!is.data.frame(big_n) || !all(by %in% names(big_n))) {
    return(big_n)
  }
  non_by <- setdiff(names(big_n), by)
  if (length(non_by) == 0L) {
    return(big_n)
  }
  numeric_mask <- vapply(
    non_by,
    function(nm) is.numeric(big_n[[nm]]),
    logical(1L)
  )
  if (all(numeric_mask)) {
    return(big_n) # already wide
  }
  key_cols <- non_by[!numeric_mask]
  val_cols <- non_by[numeric_mask]
  if (length(key_cols) == 1L && length(val_cols) == 1L) {
    return(.subgroup_bign_long_to_wide(big_n, by, key_cols, val_cols, call))
  }
  cli::cli_abort(
    c(
      "{.arg big_n} shape is not recognised.",
      "i" = "{cli::qty(by)}Wide: the {.arg by} column{?s} plus one numeric column per arm.",
      "i" = "{cli::qty(by)}Long: the {.arg by} column{?s} plus one arm-name column and one numeric N column."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Pivot a long big_n (by..., key, value) to the wide shape: one column
# per unique arm name, one row per unique by-combo. A missing
# (arm, combo) cell becomes NA (rejected downstream by the non-NA value
# check); a duplicate (by, arm) row aborts here.
.subgroup_bign_long_to_wide <- function(long, by, key, val, call) {
  key_vec <- as.character(long[[key]])
  # An arm name equal to a `by` column name would overwrite that column
  # when the wide frame is built (`wide[[a]] <- ...`), corrupting the
  # partition key. Reject it up front with a clear message.
  arm_by_clash <- intersect(unique(key_vec), by)
  if (length(arm_by_clash) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} arm name{?s} clash with a {.arg by} column: {.val {arm_by_clash}}.",
        "i" = "Rename the arm, or key it to a different display column or {.fn headers} band."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (anyDuplicated(.subgroup_combo_key(long, c(by, key))) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} has duplicate rows for a {.arg by} / arm combination.",
        "x" = "Each arm appears at most once per {.arg by} combination."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  combo_df <- unique(long[by])
  row.names(combo_df) <- NULL
  ckey <- .subgroup_combo_key(combo_df, by)
  wide <- combo_df
  for (a in unique(key_vec)) {
    sel <- key_vec == a
    lkey <- .subgroup_combo_key(long[sel, , drop = FALSE], by)
    wide[[a]] <- long[[val]][sel][match(ckey, lkey)]
  }
  wide
}

.subgroup_check_big_n <- function(big_n, big_n_fmt, by, label, spec, call) {
  data_names <- names(spec@data)

  # (1) data frame
  if (!is.data.frame(big_n)) {
    cli::cli_abort(
      c(
        "{.arg big_n} must be a data frame.",
        "x" = "You supplied {.obj_type_friendly {big_n}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (2) at least one row
  if (nrow(big_n) == 0L) {
    cli::cli_abort(
      "{.arg big_n} must have at least one row.",
      class = "tabular_error_input",
      call = call
    )
  }
  # (3) format scalar character
  if (
    !is.character(big_n_fmt) ||
      length(big_n_fmt) != 1L ||
      is.na(big_n_fmt)
  ) {
    cli::cli_abort(
      c(
        "{.arg big_n_fmt} must be a length-1 non-NA character.",
        "i" = "Use a template with the {.code {{n}}} token, e.g. {.val \\n(N={{n}})}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (4) format contains {n}
  if (!grepl("{n}", big_n_fmt, fixed = TRUE)) {
    cli::cli_abort(
      "{.arg big_n_fmt} must contain the {.code {{n}}} placeholder.",
      class = "tabular_error_input",
      call = call
    )
  }
  # (5) format has no brace token other than {n} (catches {N} typos)
  fmt_refs <- .subgroup_template_refs(big_n_fmt)
  bad_refs <- setdiff(fmt_refs, "n")
  if (length(bad_refs) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n_fmt} may only reference the {.code {{n}}} token.",
        "x" = "{cli::qty(bad_refs)}Unknown token{?s}: {.val {bad_refs}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (6) every `by` column present
  miss_by <- setdiff(by, names(big_n))
  if (length(miss_by) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} is missing {cli::qty(miss_by)}{.arg by} column{?s}: {.val {miss_by}}.",
        "i" = "{.arg big_n} carries the {cli::qty(miss_by)}{.arg by} column{?s} plus one column per arm."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (7) at least one value column
  n_cols <- setdiff(names(big_n), by)
  if (length(n_cols) == 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} has no value columns.",
        "i" = "Add one column per arm whose header should carry an N."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (8) target resolution: each value column resolves to exactly one
  #     leaf column XOR one header band label.
  band_labels <- .subgroup_header_labels(spec@headers)
  targets <- lapply(
    n_cols,
    function(nm) .subgroup_bign_target(nm, data_names, band_labels)
  )
  names(targets) <- n_cols
  none <- n_cols[vapply(targets, function(t) t$kind == "none", logical(1L))]
  if (length(none) > 0L) {
    cli::cli_abort(
      c(
        "{cli::qty(none)}{.arg big_n} value column{?s} match{?es} no display column or header band: {.val {none}}.",
        "i" = "Name each column as the arm appears, either a data column or a {.fn headers} band label.",
        "i" = "Band keying needs {.fn headers} before {.fn subgroup} in the pipeline."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  ambiguous <- n_cols[vapply(
    targets,
    function(t) t$kind == "ambiguous",
    logical(1L)
  )]
  if (length(ambiguous) > 0L) {
    cli::cli_abort(
      c(
        "{cli::qty(ambiguous)}{.arg big_n} value column{?s} match{?es} more than one target: {.val {ambiguous}}.",
        "x" = "A name maps to a data column AND a band label, or a duplicate band label.",
        "i" = "Rename the arm so it resolves to one leaf or one band."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (9) value columns are non-negative whole numbers
  for (nm in n_cols) {
    v <- big_n[[nm]]
    if (!is.numeric(v) || anyNA(v) || any(v < 0) || any(v != floor(v))) {
      cli::cli_abort(
        c(
          "{.arg big_n} column {.val {nm}} must be non-negative whole numbers.",
          "x" = "Found a non-numeric, NA, negative, or fractional value."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  # (9b) leaf targets must render — a hidden / auto-hidden leaf would
  #      attach the N to a column that never appears (a silent-N trap).
  auto_hidden <- .subgroup_template_refs(label %||% "")
  for (nm in n_cols) {
    if (targets[[nm]]$kind != "leaf") {
      next
    }
    cs <- spec@cols[[nm]]
    hidden <- (is_col_spec(cs) && isFALSE(cs@visible)) || nm %in% auto_hidden
    if (hidden) {
      cli::cli_abort(
        c(
          "{.arg big_n} value column {.val {nm}} targets a hidden column.",
          "x" = "Its header never renders, so the N would be invisible.",
          "i" = "Key the N to a visible column or a {.fn headers} band label."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  # (10) unique by-combos in big_n
  bn_key <- .subgroup_combo_key(big_n, by)
  if (anyDuplicated(bn_key) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} has duplicate rows for a {.arg by} combination.",
        "x" = "Each {.arg by} combination must appear at most once."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  # (11) completeness: every PRESENT data combo has a big_n row.
  #      Asymmetric: extra big_n rows are tolerated (table reuse),
  #      missing rows error (the silent-wrong-N guard). Only the SET of
  #      present combos matters here, so take it straight from the data
  #      (cheaper than `.subgroup_combos`, which also builds the full
  #      expand.grid crossing the engine needs for ordering).
  data_combos <- unique(spec@data[, by, drop = FALSE])
  data_key <- .subgroup_combo_key(data_combos, by)
  missing_combo <- setdiff(data_key, bn_key)
  if (length(missing_combo) > 0L) {
    cli::cli_abort(
      c(
        "{.arg big_n} is missing a row for {length(missing_combo)} subgroup combination{?s} present in the data.",
        "i" = "Provide one {.arg big_n} row per {.arg by} combination."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------
# Internal helpers shared with engine_subgroup_split
# ---------------------------------------------------------------------

# Resolve the effective label template. Returns `spec@subgroup@label`
# when the user supplied one; otherwise derives a default of
# `<attr_label or var_name>: {<var>}` for the (single) partition var.
.subgroup_effective_template <- function(spec) {
  user_template <- spec@subgroup@label
  if (!is.null(user_template) && nzchar(user_template)) {
    return(user_template)
  }
  var <- spec@subgroup@by[[1L]]
  col_label <- attr(spec@data[[var]], "label", exact = TRUE)
  lbl <- if (
    is.character(col_label) && length(col_label) == 1L && nzchar(col_label)
  ) {
    col_label
  } else {
    var
  }
  paste0(lbl, ": {", var, "}")
}

# Extract column references from a `{col}` template. Used at verb
# time for up-front validation and at engine time for substitution.
# Skips escaped `{{` / `}}` pairs (reserved for future literal-brace
# support; today they're simply not substituted).
.subgroup_template_refs <- function(template) {
  if (!is.character(template) || length(template) != 1L || is.na(template)) {
    return(character())
  }
  m <- gregexpr("\\{([^{}]+)\\}", template, perl = TRUE)[[1L]]
  if (length(m) == 1L && m[[1L]] == -1L) {
    return(character())
  }
  starts <- as.integer(m)
  lens <- attr(m, "match.length")
  refs <- vapply(
    seq_along(starts),
    function(i) {
      substr(template, starts[[i]] + 1L, starts[[i]] + lens[[i]] - 2L)
    },
    character(1L)
  )
  unique(refs)
}

# Compute the union of partition columns and template-ref columns
# that should auto-hide at engine time. Mirrors the indent_by
# auto-hide ergonomic — when a column is named in `spec@subgroup@by`
# or referenced via `{col}` placeholder in `spec@subgroup@label`,
# the engine flips its `visible` to FALSE so users don't restate
# the same fact inside `cols()`. Returns `character(0L)` when the
# spec has no subgroup partition.
.subgroup_auto_hide_cols <- function(spec) {
  sg <- spec@subgroup
  if (is.null(sg) || length(sg@by) == 0L) {
    return(character(0L))
  }
  refs <- .subgroup_template_refs(sg@label %||% "")
  unique(c(sg@by, refs))
}

# Substitute `{col}` tokens in `template` against `row_data` (a
# 1-row data.frame). Mirrors the .substitute_engine_tokens pattern
# at R/page_chrome.R:293 — fixed-string gsub over each token.
.subgroup_render_label <- function(template, row_data) {
  refs <- .subgroup_template_refs(template)
  out <- template
  for (col in refs) {
    val <- row_data[[col]]
    rendered <- if (is.factor(val)) {
      as.character(val)
    } else {
      format(val, trim = TRUE)
    }
    out <- gsub(paste0("{", col, "}"), rendered, out, fixed = TRUE)
  }
  out
}
