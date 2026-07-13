# backend_typst_pdf.R — PDF backend via Typst. Composes a Typst
# document via `backend_typst` then compiles it through the typst
# binary (standalone `typst`, or the copy bundled inside Quarto >= 1.4
# as `quarto typst`).
#
# Why typst as a second PDF engine (beside LaTeX):
#
# * **Zero-install on Quarto machines.** Quarto bundles the typst
#   compiler, and Quarto ships with RStudio / Posit Workbench and most
#   analyst laptops — so `emit(spec, "out.pdf", format = "typst")`
#   works with no TeX installation at all.
# * **Locked-down images.** Corporate / containerised workspaces
#   (Domino, Posit Workbench, Databricks) often freeze TeX Live at a
#   kernel too old for tabularray and block CTAN behind proxies; the
#   Quarto-bundled typst sidesteps both.
# * **Fast compiles.** A typical TFL compiles in well under a second,
#   versus multi-second (cold-cache: much longer) xelatex runs.
#
# The LaTeX engine remains the default for `.pdf` when a working TeX
# is found (`emit()` probes TeX first), so existing output is
# byte-stable; typst is the fallback that rescues TeX-less machines.

# Minimum typst release. Every construct the backend emits
# (`table.header(repeat:)`, `table.footer`, `table.hline(start:, end:)`,
# `table.cell(colspan:, fill:, stroke:)`, `context counter(page)`)
# exists from 0.11; Quarto 1.6 bundles 0.11.0, newer Quartos newer
# binaries.
.tabular_min_typst_version <- "0.11.0"

# ---------------------------------------------------------------------
# Binary discovery
# ---------------------------------------------------------------------

# Locate a typst compiler. A standalone `typst` on the PATH wins (no
# Quarto process overhead); otherwise Quarto's bundled copy runs as
# `quarto typst <args>`. Returns `list(cmd, args)` where `args` is the
# subcommand prefix to splice before `compile` / `fonts`, or NULL when
# neither binary is found. `.which` is an injected seam for tests
# (testthat's `local_mocked_bindings` does not engage under covr
# instrumentation, so seams are injected directly — the same pattern
# as `backend_pdf()`'s `.compile`).
.typst_bin <- function(.which = Sys.which) {
  typst <- .which("typst")
  if (nzchar(typst)) {
    return(list(cmd = unname(typst), args = character()))
  }
  quarto <- .which("quarto")
  if (nzchar(quarto)) {
    return(list(cmd = unname(quarto), args = "typst"))
  }
  NULL
}

# Version of the discovered typst binary, parsed from the
# `typst --version` banner ("typst 0.14.2 (b33de9de)" — identical for
# the Quarto-bundled copy). Returns a `numeric_version`, or NA when the
# binary is absent or the banner does not parse. `.version_line` is an
# injected seam for tests.
.typst_version <- function(bin = .typst_bin(), .version_line = NULL) {
  line <- .version_line
  if (is.null(line)) {
    if (is.null(bin)) {
      return(NA)
    }
    line <- tryCatch(
      suppressWarnings(
        system2(
          bin$cmd,
          c(bin$args, "--version"),
          stdout = TRUE,
          stderr = TRUE
        )
      )[1L],
      error = function(e) NA_character_
    )
  }
  if (length(line) == 0L || is.na(line)) {
    return(NA)
  }
  m <- regmatches(line, regexec("typst (\\d+\\.\\d+(\\.\\d+)?)", line))[[1L]]
  if (length(m) < 2L) {
    return(NA)
  }
  numeric_version(m[[2L]])
}

# Font families the discovered typst binary can see (`typst fonts`
# prints one family name per line, including the faces embedded in the
# binary itself). Returns a character vector, or NULL when the binary
# is absent or the call fails. `.lines` is an injected seam for tests.
.typst_fonts <- function(bin = .typst_bin(), .lines = NULL) {
  lines <- .lines
  if (is.null(lines)) {
    if (is.null(bin)) {
      return(NULL)
    }
    lines <- tryCatch(
      suppressWarnings(
        system2(bin$cmd, c(bin$args, "fonts"), stdout = TRUE, stderr = FALSE)
      ),
      error = function(e) NULL
    )
    if (is.null(lines)) {
      return(NULL)
    }
  }
  lines <- trimws(as.character(lines))
  lines[nzchar(lines)]
}

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a PDF file. Writes the Typst source to a tempfile
# (via backend_typst, which also writes any figure sidecars next to
# it — typst resolves relative paths against the SOURCE file, so no
# working-directory change is needed, unlike latexmk). Returns the
# file path invisibly.
backend_typst_pdf <- function(grid, file, .compile = .tabular_typst_compile) {
  # Force the target path BEFORE any directory bookkeeping: `file` may
  # arrive as an unevaluated promise over a relative path.
  force(file)
  bin <- .typst_bin()
  if (is.null(bin)) {
    .typst_missing_abort()
  }

  typ_dir <- tempfile(pattern = "tabular_typst_")
  dir.create(typ_dir, recursive = TRUE)
  on.exit(unlink(typ_dir, recursive = TRUE), add = TRUE)

  typ_file <- file.path(typ_dir, "tabular.typ")
  backend_typst(grid, typ_file)

  result <- tryCatch(
    .compile(typ_file, file),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    .typst_compile_abort(result, bin)
  }
  # typst falls back on a missing font family SILENTLY in the PDF and
  # only notes it on stderr; surface those notes loudly so a layout
  # rendered in the wrong face is never a quiet defect.
  .typst_warn_unknown_fonts(result)
  invisible(file)
}

# Internal compile seam over the typst binary, injected as the
# `.compile` default so tests can pass a fake without mocking (the
# covr-safe pattern shared with `backend_pdf()`). Captures the merged
# compiler output; a non-zero exit becomes an error carrying that
# output, and a clean exit returns it (the caller scans it for font
# warnings). The body only runs with a real typst install (exercised by
# the binary-gated end-to-end compile tests), so it is excluded from
# coverage.
.tabular_typst_compile <- function(typ_file, file) {
  # nocov start
  bin <- .typst_bin()
  out <- suppressWarnings(
    system2(
      bin$cmd,
      c(bin$args, "compile", shQuote(typ_file), shQuote(file)),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  status <- attr(out, "status") %||% 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(out, collapse = "\n"))
  }
  out
  # nocov end
}

# Extract the distinct family names from typst's
# "unknown font family: <name>" compiler notes and surface them as ONE
# loud warning. No matching lines -> silent.
.typst_warn_unknown_fonts <- function(output) {
  if (!is.character(output) || length(output) == 0L) {
    return(invisible(NULL))
  }
  m <- regmatches(
    output,
    regexpr("unknown font family: .+$", output)
  )
  fams <- unique(sub("^unknown font family: ", "", m))
  fams <- trimws(fams[nzchar(fams)])
  if (length(fams) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "Typst could not find {length(fams)} font famil{?y/ies}: {.val {fams}}.",
      "i" = "The PDF fell back to the next family in the chain (or typst's default face), so the layout may not match other backends.",
      "i" = "Run {.run tabular::check_typst()} to see which families of the configured chain resolve."
    ),
    class = "tabular_warning_backend"
  )
  invisible(NULL)
}

# Abort when no typst binary can be found at all.
.typst_missing_abort <- function(call = rlang::caller_env(2L)) {
  cli::cli_abort(
    c(
      "PDF compilation via Typst failed.",
      "x" = "No typst compiler found: neither {.code typst} nor {.code quarto} is on the {.envvar PATH}.",
      "i" = "Install Quarto (>= 1.4, which bundles typst) from {.url https://quarto.org}, or the standalone typst binary from {.url https://github.com/typst/typst}.",
      "i" = "With a TeX installation present you can compile via LaTeX instead: {.code emit(spec, \"out.pdf\", format = \"latex\")}.",
      "i" = "Fallback: render to HTML or RTF instead via {.code emit(spec, \"out.html\")} or {.code emit(spec, \"out.rtf\")}."
    ),
    class = "tabular_error_backend",
    call = call
  )
}

# Surface a friendly cli error when the typst compile fails. An old
# binary (below the 0.11 floor) is the one failure a source fix cannot
# remedy, so that branch wins; otherwise the compiler's own message
# (which carries file/line context) is surfaced verbatim. `.version`
# is an injected seam for tests.
.typst_compile_abort <- function(err, bin = NULL, .version = NULL) {
  msg <- conditionMessage(err)
  version <- .version %||% .typst_version(bin)
  min_version <- .tabular_min_typst_version
  too_old <- !identical(version, NA) &&
    version < numeric_version(min_version)

  hints <- if (too_old) {
    c(
      "x" = "The typst binary is version {version}; tabular requires typst >= {min_version}.",
      "i" = "Update Quarto to >= 1.6 (which bundles a newer typst), or install a current standalone typst from {.url https://github.com/typst/typst}."
    )
  } else {
    c(
      "x" = "The typst compiler reported:",
      " " = "{msg}"
    )
  }

  cli::cli_abort(
    c(
      "PDF compilation via Typst failed.",
      hints,
      "i" = "Run {.run tabular::check_typst()} to audit the typst toolchain.",
      "i" = "With a TeX installation present you can compile via LaTeX instead: {.code emit(spec, \"out.pdf\", format = \"latex\")}.",
      "i" = "Fallback: render to HTML or RTF instead via {.code emit(spec, \"out.html\")} or {.code emit(spec, \"out.rtf\")}."
    ),
    class = "tabular_error_backend",
    call = rlang::caller_env(2L)
  )
}

# ---------------------------------------------------------------------
# check_typst() — local-availability diagnostic for Typst PDF output
# ---------------------------------------------------------------------

#' Check Typst availability for PDF output
#'
#' Reports whether a typst compiler is available (the standalone
#' `typst` binary, or the copy bundled inside Quarto), whether its
#' version meets tabular's floor, and which families of the default
#' font chain the compiler can actually see. Run this before
#' `emit(spec, "out.pdf", format = "typst")` on a fresh machine, and
#' whenever a Typst-compiled PDF renders in an unexpected face.
#'
#' @details
#' **Binary discovery.** A standalone `typst` on the `PATH` wins;
#' otherwise the check falls back to `quarto typst` (Quarto >= 1.4
#' bundles the typst compiler — so most machines with RStudio / Posit
#' Workbench already have one). The Typst PDF path needs no TeX
#' installation and no package downloads at all.
#'
#' **Fonts are the silent failure mode.** Where a missing LaTeX
#' package stops a compile with an error, typst substitutes a missing
#' font family silently and only notes it on the compiler's stderr.
#' The check therefore lists every family in the resolved default
#' chain with its availability; the chain ends in faces embedded in
#' the typst binary itself (New Computer Modern, DejaVu Sans Mono, the
#' Libertinus serif), so SOME face always renders — the question this
#' check answers is whether it is the face the other backends use.
#' `emit()` additionally re-surfaces the compiler's font notes as a
#' loud warning after every Typst compile.
#'
#' **Status markers:**
#'
#' * `v` — found (binary; version at or above the floor; font family
#'   visible to typst).
#' * `x` — missing (no binary; version below the floor; font family
#'   not visible).
#' * `?` — could not be determined (e.g. the font list could not be
#'   read); treated as missing for remediation.
#'
#' @param quiet *Suppress the printed cli report.*
#'   `<logical(1)>: default FALSE`. When `TRUE`, runs the checks and
#'   returns the result invisibly without printing. Use in scripts
#'   that branch on the return value.
#'
#' @return *Invisibly returns a data frame* with one row per family
#'   in the resolved default font chain and columns `font`
#'   (`<character>`) and `available` (`<logical>`, `NA` when the font
#'   list could not be read), plus attributes `typst_version`
#'   (`<numeric_version | NA>`) and `typst_command` (`<character(1) |
#'   NA_character_>`, the discovered compiler invocation). Side
#'   effect: prints a cli report with a status marker per check and,
#'   when anything is missing, the remedy.
#'
#' @examples
#' # ---- Example 1: Audit the Typst toolchain before emitting ----
#' #
#' # Run check_typst() on a fresh machine to confirm a typst compiler
#' # is present and to see which families of the default font chain it
#' # resolves. Where no binary is found every row reports `?` and the
#' # remedy lines print; the call never errors.
#' check_typst()
#'
#' @seealso
#' **Companion diagnostics:** [`check_latex()`], [`check_fonts()`].
#'
#' **Consumes the result:** [`emit()`].
#'
#' @export
check_typst <- function(quiet = FALSE) {
  if (!is.logical(quiet) || length(quiet) != 1L || anyNA(quiet)) {
    cli::cli_abort(
      c(
        "{.arg quiet} must be a single {.cls logical}.",
        "x" = "You supplied {.obj_type_friendly {quiet}}."
      ),
      class = "tabular_error_input",
      call = rlang::caller_env()
    )
  }
  bin <- .typst_bin()
  version <- .typst_version(bin)
  command <- if (is.null(bin)) {
    NA_character_
  } else {
    paste(c(basename(bin$cmd), bin$args), collapse = " ")
  }
  fonts <- .typst_fonts(bin)
  chain <- .resolve_font_stack(
    .effective_font_family(get_preset()),
    "typst"
  )
  available <- if (is.null(fonts)) {
    rep(NA, length(chain))
  } else {
    tolower(chain) %in% tolower(fonts)
  }
  out <- data.frame(
    font = chain,
    available = available,
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  attr(out, "typst_version") <- version
  attr(out, "typst_command") <- command

  if (!quiet) {
    .check_typst_report(out, version = version, command = command)
  }
  invisible(out)
}

# Print the cli report for a check_typst() result data frame.
.check_typst_report <- function(out, version = NA, command = NA_character_) {
  min_version <- .tabular_min_typst_version
  too_old <- !identical(version, NA) &&
    version < numeric_version(min_version)
  cli::cli_h3("Typst toolchain for PDF output")
  bin_line <- if (is.na(command)) {
    "x typst compiler (neither {.code typst} nor {.code quarto} on the PATH)"
  } else if (too_old) {
    "x {command} {version} (tabular requires typst >= {min_version})"
  } else if (identical(version, NA)) {
    "? {command} (version could not be determined)"
  } else {
    "v {command} {version}"
  }
  cli::cli_text(paste0("  ", bin_line))
  for (i in seq_len(nrow(out))) {
    fam <- out$font[[i]]
    ok <- out$available[[i]]
    line <- if (isTRUE(ok)) {
      "v font {fam}"
    } else if (isFALSE(ok)) {
      "x font {fam}"
    } else {
      "? font {fam}"
    }
    cli::cli_text(paste0("  ", line))
  }

  if (is.na(command)) {
    cli::cli_alert_warning(
      "No typst compiler found; {.code emit(spec, \"out.pdf\", format = \"typst\")} cannot run."
    )
    cli::cli_text(
      "Install Quarto (>= 1.4, which bundles typst) from {.url https://quarto.org}, or the standalone typst binary from {.url https://github.com/typst/typst}."
    )
    return(invisible(NULL))
  }
  if (too_old) {
    cli::cli_alert_warning(
      "typst {version} is older than tabular's floor ({min_version}); compiles will fail on the table constructs the backend emits."
    )
    cli::cli_text(
      "Update Quarto to >= 1.6, or install a current standalone typst."
    )
  }
  missing <- out$font[!.is_true_vec(out$available)]
  if (length(missing) == 0L) {
    if (!too_old) {
      cli::cli_alert_success(
        "Typst is ready; every family in the default font chain resolves."
      )
    }
    return(invisible(NULL))
  }
  cli::cli_alert_warning(
    "{length(missing)} famil{?y/ies} of the default chain {?is/are} not visible to typst: {.val {missing}}."
  )
  cli::cli_text(
    "Typst walks the chain and substitutes silently, so output still renders, but possibly in a different face than the RTF / DOCX / LaTeX backends use. Install the missing {cli::qty(length(missing))}famil{?y/ies}, or point typst at a font directory via the {.envvar TYPST_FONT_PATHS} environment variable."
  )
  invisible(NULL)
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("typst_pdf", backend_typst_pdf)
