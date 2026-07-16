# backend_pdf_common.R — machinery shared by the two compile-to-PDF
# engines: LaTeX (backend_pdf.R) and Typst (backend_typst_pdf.R).
# Each engine keeps its real differences (compile command, bundled-sty
# staging, working-directory handling, abort messages) and delegates
# the identical skeleton here.

# Shared compile skeleton: write the rendered source into a throwaway
# temp directory, run the injected compiler, and route any compile
# error to the engine's abort helper. Returns the compiler output (the
# Typst engine scans it for font warnings).
#
# * `write_source` — function(grid, src_file); the source backend.
# * `pre_compile` — optional function(src_dir) run after the source is
#   written (the LaTeX engine stages bundled `.sty` copies here).
# * `compile_in_dir` — when TRUE, the compile runs with the working
#   directory set to the temp dir (latexmk resolves a figure's relative
#   `\includegraphics` sidecar against its cwd, not the input file's
#   directory; typst resolves against the source file, so it does not
#   need this). `withr::local_dir()` restores the directory on any
#   exit, including a compile error, before the temp dir is unlinked.
# * `on_error` — function(err); must abort (the engine's classed
#   `tabular_error_backend` helper, with the caller's env threaded
#   through so the cli call context is unchanged).
.compile_pdf_source <- function(
  grid,
  file,
  compile,
  write_source,
  src_name,
  dir_pattern,
  on_error,
  pre_compile = NULL,
  compile_in_dir = FALSE
) {
  src_dir <- tempfile(pattern = dir_pattern)
  dir.create(src_dir, recursive = TRUE)
  on.exit(unlink(src_dir, recursive = TRUE), add = TRUE)

  src_file <- file.path(src_dir, src_name)
  write_source(grid, src_file)
  if (!is.null(pre_compile)) {
    pre_compile(src_dir)
  }
  if (compile_in_dir) {
    withr::local_dir(src_dir)
  }
  result <- tryCatch(
    compile(src_file, file),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    on_error(result)
  }
  result
}

# Extract the first capture group of `pattern` from a compiler
# version-banner line. Returns NA_character_ when the line is missing,
# NA, or does not match — the engine wrappers convert to their own NA
# type (NA_integer_ for the TeX Live year, logical NA / numeric_version
# for typst).
.parse_version_banner <- function(line, pattern) {
  if (length(line) == 0L || is.na(line)) {
    return(NA_character_)
  }
  m <- regmatches(line, regexec(pattern, line))[[1L]]
  if (length(m) < 2L) {
    return(NA_character_)
  }
  m[[2L]]
}

# Print one indented status line per checked item: `v` found, `x`
# missing, `?` undetermined. An item flagged in `bundled` passes with
# the bundled-copy note when its own status is not TRUE (the shipped
# copy is staged at compile time, so it never needs an install).
.check_report_status_lines <- function(
  items,
  ok,
  prefix = "",
  bundled = NULL
) {
  for (i in seq_along(items)) {
    item <- items[[i]]
    status <- ok[[i]]
    line <- if (isTRUE(status)) {
      "v {prefix}{item}"
    } else if (!is.null(bundled) && bundled[[i]]) {
      "v {prefix}{item} (not found, bundled copy used)"
    } else if (isFALSE(status)) {
      "x {prefix}{item}"
    } else {
      "? {prefix}{item}"
    }
    cli::cli_text(paste0("  ", line))
  }
}
