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

# ---------------------------------------------------------------------
# Backend registry
# ---------------------------------------------------------------------

# Package-internal env that backend_*.R files mutate at load time.
# Keys are format strings ("md", "html", "latex", "pdf", "rtf",
# "docx"); values are unary writer functions
# `function(grid, file) -> invisible(file)`. The registry starts
# empty; backends self-register by calling `.register_backend()`
# from their source file.
.tabular_backends <- new.env(parent = emptyenv())

# Register a backend writer. Replaces any existing entry for the
# same format. Internal — backends call this from R/backend_*.R
# top-level code. Errors are intentionally bare (not cli_abort)
# because hitting them is a package-development bug, not a user
# error.
.register_backend <- function(format, fn) {
  if (!is.character(format) || length(format) != 1L || is.na(format)) {
    stop("`.register_backend()`: `format` must be a scalar character.")
  }
  if (!is.function(fn)) {
    stop("`.register_backend()`: `fn` must be a function.")
  }
  assign(format, fn, envir = .tabular_backends)
  invisible()
}

# Drop a backend registration. Used primarily by tests via
# `withr::defer()` to undo a registration inside a single test.
.unregister_backend <- function(format) {
  if (exists(format, envir = .tabular_backends, inherits = FALSE)) {
    rm(list = format, envir = .tabular_backends)
  }
  invisible()
}

# Test whether a backend is currently registered for `format`. Used
# by tests and by potential future external introspection; cheaper
# than calling `.resolve_backend()` solely to check existence.
.has_backend <- function(format) {
  exists(format, envir = .tabular_backends, inherits = FALSE)
}

# List the format strings of every currently registered backend,
# sorted alphabetically. Used in error messages so the user can see
# which backends are available.
.registered_backend_formats <- function() {
  sort(ls(.tabular_backends))
}

# Look up the backend writer for `format`; abort with
# `tabular_error_input` when none is registered (e.g. an extension
# whose backend has not yet shipped, or a typoed `format` override).
.resolve_backend <- function(format, call) {
  fn <- .tabular_backends[[format]]
  if (is.null(fn)) {
    registered <- .registered_backend_formats()
    msg <- c(
      "No backend registered for format {.val {format}}."
    )
    if (length(registered) > 0L) {
      msg <- c(
        msg,
        "i" = "Registered backends: {.val {registered}}."
      )
    } else {
      msg <- c(
        msg,
        "i" = "No backends are registered. This is a package-internal state."
      )
    }
    cli::cli_abort(msg, class = "tabular_error_input", call = call)
  }
  fn
}

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
#' rendered artefact.
#'
#' `emit()` is the package's terminal verb. It returns `file`
#' invisibly so the call can be chained or assigned without losing
#' the path. The same engine pipeline runs whether or not a backend
#' is registered; an unsupported extension surfaces a friendly
#' `tabular_error_input` after validation but before any I/O.
#'
#' @param spec A `tabular_spec` built by the verb chain.
#' @param file *Destination path.* `character(1)`. Extension drives
#'   the backend (overridable via `format`). Parent directory must
#'   exist; `emit()` does not create directories.
#' @param format *Optional backend override.* `character(1) | NULL`.
#'   When set, takes precedence over the file extension. Useful for
#'   writing `.txt` files that should be RTF or for round-trip
#'   testing.
#' @param data_file *Optional QC artefact writer.* `character(1) |
#'   function(file) -> character(1) | NULL`. When set, the resolved
#'   wide data frame is written alongside the render. Extension on
#'   the returned path determines the format: `.csv`, `.tsv`, or
#'   `.rds`. Sponsor-naming convention belongs in the lambda.
#'   See examples.
#' @param manifest *Whether to emit a CDISC ARS audit manifest.*
#'   `logical(1)`. When `TRUE`, writes `<file>.audit.yml` with
#'   the resolved spec's titles, headers, footnotes, render
#'   provenance, and a sha256 of every emitted artefact.
#' @return `file`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' # ---- Example 1: render demographics to Markdown ----
#' #
#' # The simplest emit: spec in, .md out. The backend is chosen
#' # from the file extension. `as_grid()` runs internally, then
#' # the registered md backend writes the file.
#' spec <- tabular(
#'   saf_demo,
#'   titles = c("Table 14.1.1", "Demographics", "Safety Population"),
#'   footnotes = "Source: ADSL."
#' ) |>
#'   cols(
#'     variable   = col_spec(usage = "group", label = "Characteristic"),
#'     stat_label = col_spec(label = "Statistic"),
#'     placebo  = col_spec(label = "Placebo\nN=86",   align = "decimal"),
#'     drug_50  = col_spec(label = "Low Dose\nN=96",  align = "decimal"),
#'     drug_100 = col_spec(label = "High Dose\nN=72", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN=254",    align = "decimal")
#'   )
#' emit(spec, tempfile(fileext = ".md"))
#'
#' # ---- Example 2: render + QC data + audit manifest ----
#' #
#' # The clinical double-programming pattern: render the table,
#' # write a QC CSV alongside it, and emit the CDISC ARS manifest.
#' # A second programmer reads the CSV to verify cell-for-cell.
#' out <- tempfile(fileext = ".md")
#' emit(
#'   spec,
#'   out,
#'   data_file = \(f) paste0(tools::file_path_sans_ext(f), "_qc.csv"),
#'   manifest = TRUE
#' )
#' }
emit <- function(
  spec,
  file,
  format = NULL,
  data_file = NULL,
  manifest = FALSE
) {
  call <- rlang::caller_env()

  check_tabular_spec(spec, call = call)
  file <- .check_emit_file(file, call = call)
  format <- .resolve_format(file, format, call = call)
  .check_emit_manifest_flag(manifest, call = call)

  backend <- .resolve_backend(format, call = call)

  grid <- .resolve_spec_to_grid(spec, format = format, call = call)

  backend(grid, file)

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
# parent directory must already exist (we do not auto-create).
# Returns the input path unchanged on success.
.check_emit_file <- function(file, call) {
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
  parent <- dirname(file)
  if (!dir.exists(parent)) {
    cli::cli_abort(
      c(
        "Parent directory of {.arg file} does not exist.",
        "x" = "Missing directory: {.path {parent}}.",
        "i" = "Create it first, or pass a path inside an existing directory."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  file
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
# after engine_derive() and engine_sort() — exactly the cell text
# the backends consume.
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

# Build the data frame written to the QC artefact. We use the
# resolved post-engine_decimal cell text (so the file matches the
# rendered display verbatim). Pagination is collapsed back to the
# full table; the QC reader does not care about page splits.
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

  full <- matrix(
    NA_character_,
    nrow = nrow_data,
    ncol = length(col_names),
    dimnames = list(NULL, col_names)
  )
  for (page in grid@pages) {
    if (page$panel_index != 1L) {
      next
    }
    full[page$row_indices, page$col_names] <- page$cells_text
  }
  as.data.frame(full, stringsAsFactors = FALSE)
}
