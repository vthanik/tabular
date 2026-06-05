# emit.R — public dispatcher that resolves a tabular_spec into a
# tabular_grid (via the same pipeline as as_grid()), hands it to a
# backend writer registered for the chosen output format, and
# (optionally) writes a QC-artefact data file and a CDISC ARS audit
# manifest alongside the rendered artefact.
#
# Pipeline:
#
#   1. Validate spec + file + format + optional flags.
#   2. Resolve effective format from file extension (or explicit
#      `format` override).
#   3. Look up the backend writer in the package-internal registry.
#      Backends self-register from R/backend_*.R at load time; an
#      unknown extension or an extension with no registered backend
#      aborts with `tabular_error_input`.
#   4. Call `.resolve_spec_to_grid()` (shared with `as_grid()`).
#   5. Hand the resolved grid + file path to the backend writer.
#   6. If `data_file` is set, write the resolved wide data frame
#      (csv / tsv / rds) alongside the render. `data_file` may be
#      either an explicit path or a `function(file) -> path`
#      sponsor-naming lambda.
#   7. If `manifest = TRUE`, build a CDISC ARS Output YAML and
#      write it to `<file>.audit.yml`.
#
# Backend registry pattern (`.tabular_backends`): a package-internal
# environment keyed by format string ("md", "html", "latex", "pdf",
# "rtf", "docx"). Each `R/backend_*.R` calls `.register_backend()`
# at top level. Tests use `withr::defer()` to register / unregister
# stub backends without leaking state across test files.
#
# `data_file` semantics — sponsor neutral, per
# feedback_qc_artefact.md:
#   - NULL          : do not write (default; non-clinical users
#                     unaffected).
#   - character(1)  : explicit path; format from extension.
#   - function(file): receives the render path, returns the data
#                     path. The returned path's extension drives the
#                     writer. One-line lambdas are the canonical
#                     idiom (`\(f) paste0(tools::file_path_sans_ext(f),
#                     "_qc.csv")`).

# The backend registry helpers (`.register_backend`,
# `.unregister_backend`, `.has_backend`, `.registered_backend_formats`,
# `.resolve_backend`) live in `R/aaa_backend_registry.R` so they
# load before any `R/backend_*.R` file does its top-level
# self-registration. emit() consults them via `.resolve_backend()`
# after the extension -> format mapping below.

# Map file extension (lowercase, no leading dot) to the canonical
# format string the backend registry uses. Keep this table small
# and explicit; ambiguous extensions (e.g. `htm` vs `html`) all
# resolve to the same format. Stored as a named list (not a named
# character vector) so `[[missing_key]]` returns NULL instead of
# raising a subscript-out-of-bounds error.
.extension_format_map <- list(
  md = "md",
  markdown = "md",
  html = "html",
  htm = "html",
  tex = "latex",
  latex = "latex",
  pdf = "pdf",
  rtf = "rtf",
  docx = "docx"
)

# ---------------------------------------------------------------------
# Public entry — emit
# ---------------------------------------------------------------------

#' Render a `tabular_spec` to a file
#'
#' Resolve `spec` through the engine pipeline, dispatch to the
#' backend registered for the chosen format, and (optionally) write
#' a QC data file and a CDISC ARS audit manifest alongside the
#' rendered artefact. `emit()` is the package's terminal verb — it
#' returns `file` invisibly so the call can sit at the bottom of a
#' pipe without losing the path.
#'
#' @details
#'
#' **Validation before I/O.** Every argument is validated and the
#' backend is resolved BEFORE the engine runs. An unsupported
#' extension, a malformed `data_file` path, or a missing backend
#' raises `tabular_error_input` without writing any file. A spec
#' that resolves cleanly but whose backend errors mid-write may
#' leave a partial file behind; this is the only failure mode that
#' touches disk.
#'
#' **Backend dispatch.** The effective backend is resolved from the
#' file extension via the table below; the `format` argument always
#' wins when both are supplied. Each backend lives in its own
#' `R/backend_<fmt>.R` file and self-registers at package load time.
#'
#' | extension(s)       | format  | backend                              |
#' |--------------------|---------|--------------------------------------|
#' | `.md`, `.markdown` | `md`    | GFM pipe table (Step 15; shipped)    |
#' | `.html`, `.htm`    | `html`  | self-contained Bootstrap 5 (planned) |
#' | `.tex`, `.latex`   | `latex` | tabularray (planned)                 |
#' | `.pdf`             | `pdf`   | tinytex compile of LaTeX (planned)   |
#' | `.rtf`             | `rtf`   | RTF 1.9.1, native (shipped)          |
#' | `.docx`            | `docx`  | OOXML native, no JVM (planned)       |
#'
#' Unknown extensions, missing extensions, and formats with no
#' registered backend all raise `tabular_error_input`. The error
#' message lists the currently registered formats so the failure is
#' actionable.
#'
#' **`data_file` is sponsor-neutral.** Pass an explicit path
#' (`"out/qc.csv"`) for a fixed location, or a lambda
#' (`function(file) -> path`) for sponsor-flexible naming. The
#' lambda receives the resolved render path so it can derive the QC
#' file from it (suffix, sibling folder, separate sponsor-styled
#' name). Recognised extensions on the returned path are `.csv`,
#' `.tsv` (alias: `.txt`), and `.rds`; anything else raises
#' `tabular_error_input`. The written data frame is the post-
#' [`sort_rows()`] / post-`engine_decimal()` wide grid — exactly
#' the cell text the backend wrote.
#'
#' **`manifest = TRUE` writes a sidecar.** The audit manifest is
#' written to `<file>.audit.yml` next to the render (e.g. `out.md`
#' -> `out.audit.yml`). Keys are CDISC ARS LDM v1.0 Output verbatim:
#' `id`, `name`, `programmingCode` (best-effort git + R + platform
#' + timestamp), `fileSpecifications` (sha256 of every emitted
#' artefact including `data_file`), `displays/displaySections`
#' (Title / Header / Body / Footnote), `referencedAnalyses` (empty
#' in v0.1; reserved for the mintverse handoff), `x-tabular`
#' (rendering geometry, pagination, style trace, input provenance).
#' Determinism contract: two consecutive `emit()` calls are byte-
#' identical except for the `rendered_at` parameter timestamp; the
#' YAML round-trips through `yaml::read_yaml()` + `yaml::write_yaml()`.
#'
#' **Pure dispatcher.** `emit()` does not do any rendering itself;
#' it composes [`as_grid()`] with a backend writer. To inspect the
#' resolved grid without writing a file (during development, or to
#' build a custom downstream consumer), call [`as_grid()`] directly.
#'
#' @param spec *The `tabular_spec` to render.*
#'   `<tabular_spec>: required`. The full verb chain ([`tabular()`]
#'   -> [`cols()`] -> [`headers()`] -> [`sort_rows()`] -> [`style()`]
#'   -> [`paginate()`] -> [`preset()`]) feeds into `emit()`'s first
#'   argument by pipe.
#'
#' @param file *Destination path for the rendered artefact.*
#'   `<character(1)>: required`. Extension drives the backend (see
#'   the dispatch table in the Details section). The parent
#'   directory must already exist; `emit()` does not auto-create
#'   directories.
#'
#'   **Tip:** Use `tempfile(fileext = ".md")` inside vignettes and
#'   examples so the example runs in `R CMD check` without
#'   polluting the package directory.
#'
#' @param format *Explicit backend override.*
#'   `<character(1) | NULL>: default NULL`. When set, wins over the
#'   file extension. Useful for writing `.txt` files that should
#'   contain RTF, for round-trip testing, or when the user has a
#'   custom backend registered under a non-standard name.
#'
#' @param data_file *QC artefact writer.*
#'   `<character(1) | function(file) -> character(1) | NULL>:`
#'   `default NULL`. When set, writes the resolved wide data frame
#'   alongside the render. A character path writes there directly;
#'   a lambda receives the render path and returns the data file
#'   path (typical for sponsor-flexible naming).
#'
#'   **Restriction:** Returned-path extension must be `.csv`,
#'   `.tsv` / `.txt`, or `.rds`.
#'   **Tip:** The data frame the lambda governs is pre-backend —
#'   the same CSV is emitted regardless of whether `file` is RTF,
#'   PDF, or DOCX.
#'
#'   ```r
#'   # Three canonical sponsor patterns for the lambda.
#'   data_file = \(f) paste0(tools::file_path_sans_ext(f), "_qc.csv")
#'   data_file = \(f) file.path(
#'     "validation",
#'     paste0("val_", basename(tools::file_path_sans_ext(f)), ".csv")
#'   )
#'   data_file = \(f) file.path(
#'     "rd",
#'     paste0("rd_", basename(tools::file_path_sans_ext(f)), ".rds")
#'   )
#'   ```
#'
#' @param manifest *Emit the CDISC ARS audit manifest sidecar.*
#'   `<logical(1)>: default FALSE`. `TRUE` writes
#'   `<file>.audit.yml` with verbatim CDISC ARS LDM v1.0 Output
#'   keys; see the **`manifest = TRUE`** invariant in the Details
#'   section for what the file contains and the determinism
#'   contract it satisfies.
#'
#' @param create_dir *Create the destination directory if it is missing.*
#'   `<logical(1)>: default FALSE`. When `TRUE`, the parent directory of
#'   `file` (and any missing ancestors) is created recursively before
#'   rendering, instead of aborting. The default `FALSE` keeps the safe
#'   behaviour of erroring on a missing parent.
#'
#' @return *The `file` path, invisibly.* Use this when chaining
#'   `emit()` into a downstream consumer that needs the resolved
#'   path (e.g. printing the link in a Quarto chunk, copying the
#'   sidecar manifest into an archive, attaching the render to a
#'   submission folder builder).
#'
#' @examples
#' # ---- Example 1: Render demographics to Markdown ----
#' #
#' # Smallest possible emit: spec in, .md out. The backend is chosen
#' # from the file extension; the engine pipeline runs internally,
#' # then the registered md backend writes a GFM pipe table you can
#' # preview in any Markdown renderer. tempfile() keeps the example
#' # clean for `R CMD check`.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' demo <- tabular(
#'   cdisc_saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics and Baseline Characteristics",
#'     "Safety Population"
#'   ),
#'   footnotes = "Source: ADSL."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("variable", "stat_label"))
#'
#' demo_md <- tempfile(fileext = ".md")
#' emit(demo, demo_md)
#'
#' # ---- Example 2: Render + QC data + CDISC audit manifest ----
#' #
#' # The clinical double-programming pattern: render the table,
#' # write a QC CSV alongside it for an independent programmer to
#' # verify cell-for-cell, and emit the CDISC ARS audit manifest
#' # for submission packaging. The lambda derives the QC path from
#' # the render path so the sponsor's naming convention lives in one
#' # place.
#' ae <- cdisc_saf_aesocpt
#' ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
#' ae$n_total <- as.integer(sub(" .*", "", ae$Total))
#'
#' ae_spec <- tabular(
#'   ae,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by SOC and Preferred Term",
#'     "Safety Population"
#'   ),
#'   footnotes = "Subjects counted once per SOC and once per PT."
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
#'   ) |>
#'   sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#'
#' ae_md <- tempfile(fileext = ".md")
#' emit(
#'   ae_spec,
#'   ae_md,
#'   data_file = \(f) paste0(tools::file_path_sans_ext(f), "_qc.csv"),
#'   manifest  = TRUE
#' )
#'
#' # ---- Example 3: Same spec, four backends — one-loop fan-out ----
#' #
#' # `emit()` dispatches by file extension, so the same spec can
#' # render to every backend in one loop. Useful for visual diffs
#' # across formats during development and for shipping a build
#' # artefact set (RTF for submission, HTML for review, PDF for the
#' # CSR appendix).
#' eff_spec <- tabular(cdisc_eff_resp, titles = "Best Overall Response") |>
#'   cols(
#'     stat_label  = col_spec(usage = "group", label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE),
#'     placebo     = col_spec(label = "Placebo",  align = "decimal"),
#'     drug_50     = col_spec(label = "Drug 50",  align = "decimal"),
#'     drug_100    = col_spec(label = "Drug 100", align = "decimal")
#'   )
#'
#' out_dir <- tempfile()
#' dir.create(out_dir)
#' for (ext in c(".html", ".rtf", ".tex", ".docx", ".md")) {
#'   emit(eff_spec, file.path(out_dir, paste0("eff", ext)))
#' }
#' list.files(out_dir)
#'
#' # ---- Example 4: QC artefact via data_file alongside the render ----
#' #
#' # `emit(data_file = ...)` writes the resolved post-engine wide
#' # data frame alongside the rendered table. The sponsor's QC
#' # programmer picks up the side-car .csv (or .rds) and validates
#' # cell values without parsing the rendered RTF.
#' rtf_out  <- tempfile(fileext = ".rtf")
#' data_out <- tempfile(fileext = ".csv")
#' emit(eff_spec, rtf_out, data_file = data_out)
#' file.exists(rtf_out)
#' file.exists(data_out)
#'
#' # ---- Example 5: Render into a not-yet-existing output folder ----
#' #
#' # `create_dir = TRUE` builds the destination directory tree on the
#' # fly, so a submission-folder layout can be written in one pass
#' # without a separate `dir.create()` step.
#' nested <- file.path(tempfile(), "tables", "safety", "eff.md")
#' emit(eff_spec, nested, create_dir = TRUE)
#' file.exists(nested)
#'
#' @seealso
#' **No-I/O sibling:** [`as_grid()`] returns the resolved grid
#' without writing a file — use during development to inspect what
#' `emit()` would hand a backend.
#'
#' **Build verbs the pipeline feeds from:** [`tabular()`],
#' [`cols()`] / [`col_spec()`], [`headers()`], [`sort_rows()`],
#' [`style()`], [`paginate()`], [`preset()`].
#'
#' **Inline formatting helpers:** [`md()`], [`html()`] (titles,
#' footnotes, labels, cell text).
#'
#' @export
emit <- function(
  spec,
  file,
  format = NULL,
  data_file = NULL,
  manifest = FALSE,
  create_dir = FALSE
) {
  call <- rlang::caller_env()

  check_tabular_spec(spec, call = call)
  file <- .check_emit_file(file, call = call, create_dir = create_dir)
  format <- .resolve_format(file, format, call = call)
  .check_emit_manifest_flag(manifest, call = call)

  backend <- .resolve_backend(format, call = call)

  grid <- .resolve_spec_to_grid(spec, format = format, call = call)

  # Clear the per-render fidelity-warning dedup set so each backend
  # emulation drop (e.g. a colour on a Markdown surface) warns at most
  # once per `emit()`, but a second render in the same session warns
  # again.
  .fidelity_warn_reset()
  backend(grid, .emit_absolute_path(file))

  data_file_path <- NULL
  if (!is.null(data_file)) {
    data_file_path <- .write_data_file(
      spec = spec,
      grid = grid,
      data_file = data_file,
      render_path = file,
      call = call
    )
  }

  if (isTRUE(manifest)) {
    .write_manifest(
      spec = spec,
      grid = grid,
      file = file,
      format = format,
      data_file_path = data_file_path,
      call = call
    )
  }

  invisible(file)
}

# ---------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------

# Validate `file`. Must be scalar character, non-NA, non-empty. The
# parent directory must already exist, unless `create_dir` is TRUE in
# which case we create it (recursively). Returns the input path
# unchanged on success.
.check_emit_file <- function(file, call, create_dir = FALSE) {
  if (
    !is.character(file) ||
      length(file) != 1L ||
      is.na(file) ||
      !nzchar(file)
  ) {
    cli::cli_abort(
      c(
        "{.arg file} must be a single non-empty character string.",
        "x" = "You supplied {.obj_type_friendly {file}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (
    !is.logical(create_dir) ||
      length(create_dir) != 1L ||
      is.na(create_dir)
  ) {
    cli::cli_abort(
      c(
        "{.arg create_dir} must be a single TRUE or FALSE.",
        "x" = "You supplied {.obj_type_friendly {create_dir}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  parent <- dirname(file)
  if (!dir.exists(parent)) {
    if (isTRUE(create_dir)) {
      ok <- dir.create(parent, recursive = TRUE, showWarnings = FALSE)
      if (!ok && !dir.exists(parent)) {
        cli::cli_abort(
          c(
            "Could not create the parent directory of {.arg file}.",
            "x" = "Failed to create: {.path {parent}}.",
            "i" = "Check write permissions and that no file blocks the path."
          ),
          class = "tabular_error_runtime",
          call = call
        )
      }
    } else {
      cli::cli_abort(
        c(
          "Parent directory of {.arg file} does not exist.",
          "x" = "Missing directory: {.path {parent}}.",
          "i" = "Create it first, pass {.code create_dir = TRUE}, or use an existing directory."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
  }
  file
}

# Absolutise a validated output path for the backend handoff. The DOCX
# backend setwd()s into a temp staging dir before utils::zip, so a
# relative path would resolve against that stage and fail (the B-DOCX
# bug); direct writers (RTF / HTML / LaTeX) are unaffected but an
# absolute path is harmless for them. normalizePath() on a
# not-yet-existing relative leaf is a no-op on macOS, so normalise the
# parent (guaranteed to exist by `.check_emit_file`) and rejoin the
# basename. Handles "~" expansion and is idempotent on absolute paths.
# Kept off the user-facing return value and the data_file / manifest
# sibling paths, which stay relative-to-cwd as the caller wrote them.
.emit_absolute_path <- function(file) {
  file.path(normalizePath(dirname(file), mustWork = FALSE), basename(file))
}

# Resolve the effective format. When the user passed an explicit
# `format` override, it wins; otherwise the file extension is mapped
# through `.extension_format_map`. Unknown / missing extensions
# abort with `tabular_error_input`.
.resolve_format <- function(file, format, call) {
  if (!is.null(format)) {
    if (
      !is.character(format) ||
        length(format) != 1L ||
        is.na(format) ||
        !nzchar(format)
    ) {
      cli::cli_abort(
        c(
          "{.arg format} must be a single non-empty character string or NULL.",
          "x" = "You supplied {.obj_type_friendly {format}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(format)
  }

  ext <- tolower(tools::file_ext(file))
  if (!nzchar(ext)) {
    cli::cli_abort(
      c(
        "Cannot infer backend: {.arg file} has no extension.",
        "i" = "Pass {.arg format} explicitly, or rename {.path {file}} with one of {.val {names(.extension_format_map)}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  resolved <- .extension_format_map[[ext]]
  if (is.null(resolved)) {
    cli::cli_abort(
      c(
        "Unknown extension {.val {ext}} on {.arg file}.",
        "i" = "Recognised extensions: {.val {names(.extension_format_map)}}.",
        "i" = "Pass {.arg format} explicitly to override."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  resolved
}

# Validate `manifest`. Must be a single non-NA logical. We do not
# accept length-0 or NA because the side-effect (write or not write
# a file) needs an unambiguous answer.
.check_emit_manifest_flag <- function(manifest, call) {
  if (
    !is.logical(manifest) ||
      length(manifest) != 1L ||
      is.na(manifest)
  ) {
    cli::cli_abort(
      c(
        "{.arg manifest} must be a single TRUE or FALSE.",
        "x" = "You supplied {.obj_type_friendly {manifest}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(manifest)
}

# ---------------------------------------------------------------------
# data_file writer
# ---------------------------------------------------------------------

# Recognised extensions for the QC artefact. csv / tsv use base R
# write.table; rds preserves R types via saveRDS. parquet is not
# wired in v0.1 (would add an arrow dep just for QC). Same
# named-list trick as `.extension_format_map`: lookups on unknown
# keys return NULL rather than raising.
.data_file_extension_map <- list(
  csv = "csv",
  tsv = "tsv",
  txt = "tsv",
  rds = "rds"
)

# Resolve `data_file` (either an explicit path or a lambda receiving
# the render path), validate the resulting path, dispatch to the
# format-specific writer, and return the absolute path written. The
# data frame written is the resolved wide data frame as it sits
# after engine_sort() — exactly the cell text the backends consume.
.write_data_file <- function(spec, grid, data_file, render_path, call) {
  path <- .resolve_data_file_path(data_file, render_path, call = call)
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    cli::cli_abort(
      c(
        "Parent directory of {.arg data_file} does not exist.",
        "x" = "Missing directory: {.path {parent}}.",
        "i" = "Create it first, or return a path inside an existing directory."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  ext <- tolower(tools::file_ext(path))
  kind <- .data_file_extension_map[[ext]]
  if (is.null(kind)) {
    cli::cli_abort(
      c(
        "Unsupported extension {.val {ext}} on {.arg data_file}.",
        "i" = "Recognised extensions: {.val {names(.data_file_extension_map)}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  df <- .data_file_frame(grid)
  switch(
    kind,
    csv = utils::write.csv(df, path, row.names = FALSE),
    tsv = utils::write.table(
      df,
      path,
      sep = "\t",
      row.names = FALSE,
      quote = FALSE
    ),
    rds = saveRDS(df, path)
  )
  path
}

# Resolve the data_file argument to a concrete path. Either a
# character(1) (returned as-is) or a function(file) -> character(1)
# (invoked with the render path).
.resolve_data_file_path <- function(data_file, render_path, call) {
  if (is.function(data_file)) {
    out <- tryCatch(data_file(render_path), error = function(e) e)
    if (inherits(out, "condition")) {
      cli::cli_abort(
        c(
          "{.arg data_file} function raised an error.",
          "x" = "Underlying error: {conditionMessage(out)}."
        ),
        class = "tabular_error_runtime",
        call = call
      )
    }
    data_file <- out
  }
  if (
    !is.character(data_file) ||
      length(data_file) != 1L ||
      is.na(data_file) ||
      !nzchar(data_file)
  ) {
    cli::cli_abort(
      c(
        "{.arg data_file} must be a character path or a function returning one.",
        "x" = "Got {.obj_type_friendly {data_file}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  data_file
}

# Build the data frame written to the QC artefact. The QC reader
# wants the resolved POST-engine_format wide data \u2014 never any of
# the cosmetic mutations the resolve engine performs to drive
# display:
#
#   * No synthesised section-header rows (group_display = "header_row").
#   * No blank-row separators (group_skip).
#   * No suppressed repeats (group_display = "column" blanks
#     adjacent duplicates for display; QC sees the originals).
#   * No NBSP decimal-alignment padding.
#   * No inline HTML markup escapes.
#
# We read from `metadata$data_cells_text`, which is the snapshot
# `as_grid()` captures immediately after `engine_format()` and
# BEFORE any of the cosmetic phases run. One character row per
# SOURCE data row, one column per declared column in
# `names(spec@data)` \u2014 every column, including those marked
# `visible = FALSE`.
.data_file_frame <- function(grid) {
  meta <- grid@metadata
  nrow_data <- meta$nrow_data
  col_names <- meta$col_names

  if (nrow_data == 0L) {
    df <- as.data.frame(
      matrix(character(0L), nrow = 0L, ncol = length(col_names))
    )
    names(df) <- col_names
    return(df)
  }

  full <- meta$data_cells_text
  if (is.null(full)) {
    # Defensive fallback for grids built by code paths that didn't
    # populate the snapshot. Empty-but-typed frame keeps downstream
    # writers happy.
    full <- matrix(
      NA_character_,
      nrow = nrow_data,
      ncol = length(col_names),
      dimnames = list(NULL, col_names)
    )
  }

  # Strip the inline HTML / NBSP / entity glyphs that md() / html()
  # / engine_decimal would have introduced downstream \u2014 even though
  # the snapshot is pre-decimal, the formatted cells can still
  # carry user-supplied markup via inline_format.
  full[] <- gsub("\u00a0", "", full)
  full[] <- gsub("<[^>]+>", "", full)
  full[] <- gsub("&nbsp;", " ", full, fixed = TRUE)
  full[] <- gsub("&amp;", "&", full, fixed = TRUE)
  full[] <- gsub("&lt;", "<", full, fixed = TRUE)
  full[] <- gsub("&gt;", ">", full, fixed = TRUE)
  full[] <- trimws(full)

  as.data.frame(full, stringsAsFactors = FALSE)
}
