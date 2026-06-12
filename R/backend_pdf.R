# backend_pdf.R — PDF backend. Composes a LaTeX document via
# `backend_latex` then compiles it through `tinytex::latexmk()`.
#
# Why tinytex (not pandoc / Quarto / chromote):
#
# * `tinytex::latexmk()` auto-installs missing TeX packages on
#   demand when the user is on TinyTeX (Yihui's lightweight TeX
#   Live). For pharma users on local laptops + tinytex, this
#   makes `emit(spec, "out.pdf")` "just work" without manual
#   `tlmgr install tabularray` setup.
# * Pandoc and Quarto compile to PDF by shelling out to xelatex
#   anyway — same LaTeX-package requirements, no auto-install.
# * Chromote / pagedown skip LaTeX but lose regulatory-grade
#   typography control (precise page geometry, font metrics,
#   rule weights).
#
# In enterprise environments (Domino, Posit Workbench, Databricks,
# LSAF) where users can't run `tlmgr install` at session-start,
# admins must bake the required TeX packages into the workspace
# image. The defensive error path below surfaces a clear cli
# message naming the missing packages so the user can hand them
# to their IT team.

# ---------------------------------------------------------------------
# Required TeX packages — the preamble emitted by backend_latex
# uses these. `check_latex()` reports per-package availability and
# bundles the missing ones into a tinytex::tlmgr_install() call.
#
# This list is a SUPERSET of every `\usepackage{}` / `\RequirePackage{}`
# / `\UseTblrLibrary{}` directive the LaTeX backend can emit — both the
# unconditional preamble and every conditional branch:
#
# * unconditional: tabularray (+ siunitx library), xcolor, graphicx,
#   hyperref, iftex, geometry;
# * conditional on a populated pagehead / pagefoot band: fancyhdr,
#   lastpage (see `.latex_pagestyle_block()`);
# * conditional on the engine: fontspec under xelatex / lualatex;
#   fontenc + inputenc under pdflatex (see `.latex_font_lines()`);
# * conditional on the resolved font_family: the TeX Gyre bundles
#   (tgtermes / tgheros / tgcursor -> tex-gyre) for the generic
#   families, and the classic pdflatex font `.sty` files (mathptmx /
#   mathpazo / helvet / courier -- all four shipped by CTAN `psnfss`)
#   for named families (see `.latex_pdftex_font_pkg()`).
#
# Each entry is the CTAN package name passed to `tlmgr install`,
# which is NOT always the `.sty` stem: `\usepackage{graphicx}` ships
# in CTAN `graphics`; `\usepackage{fontenc}` / `inputenc` ship in
# CTAN `base`; `\usepackage{helvet}` / `courier` ship in CTAN `psnfss`;
# tabularray pulls `ninecolors` as a hard dependency, so we declare it
# explicitly so the diagnostic doesn't miss it. The stem -> CTAN map
# lives in `.latex_sty_to_ctan()`.
# ---------------------------------------------------------------------

.tabular_required_tex_packages <- c(
  "tabularray", # the table engine
  "ninecolors", # hard dependency of tabularray
  "xcolor", # colours
  "graphics", # graphicx.sty (CTAN package is `graphics`)
  "siunitx", # number formatting / decimal alignment (tblr library)
  "geometry", # margins / paper size
  "hyperref", # \href links
  "iftex", # engine detection
  "base", # fontenc.sty / inputenc.sty (pdflatex branch)
  "fancyhdr", # running page header / footer bands
  "lastpage", # {npages} -> "Page x of y"
  "fontspec", # \setmainfont under xelatex / lualatex
  # TeX Gyre bundles — used when font_family resolves to a generic.
  "tex-gyre",
  # pdflatex font bundle — used when font_family is named. `psnfss`
  # provides mathptmx.sty / mathpazo.sty AND helvet.sty / courier.sty, so
  # the named-family sans / mono `.sty` files need no separate entry; a
  # `courier` / `helvet` entry would be a false-negative, since neither is
  # a separately installed tlmgr package (both live inside psnfss).
  "psnfss"
)

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a PDF file. Writes the LaTeX source to a
# tempfile (via backend_latex), then compiles via
# `tinytex::latexmk()`. Returns the file path invisibly.
backend_pdf <- function(grid, file, .compile = .tabular_latexmk) {
  rlang::check_installed(
    "tinytex",
    reason = "to compile PDF output via xelatex"
  )

  tex_dir <- tempfile(pattern = "tabular_pdf_")
  dir.create(tex_dir, recursive = TRUE)
  on.exit(unlink(tex_dir, recursive = TRUE), add = TRUE)

  tex_file <- file.path(tex_dir, "tabular.tex")
  backend_latex(grid, tex_file)

  # Compile with the working directory set to tex_dir so a figure's
  # relative `\includegraphics` sidecar (written next to tabular.tex by
  # backend_latex) resolves; latexmk searches graphics relative to its
  # cwd, not the input file's directory. `file` is already absolute (emit
  # absolutises it before dispatch), so the PDF still lands at the user's
  # target. A table emits no graphics, so this is inert for the table path.
  old_wd <- getwd()
  setwd(tex_dir)
  on.exit(setwd(old_wd), add = TRUE)
  result <- tryCatch(
    .compile(tex_file, file),
    error = function(e) e
  )
  setwd(old_wd)
  if (inherits(result, "error")) {
    .pdf_compile_abort(result)
  }
  invisible(file)
}

# Internal compile seam over `tinytex::latexmk()`, injected as the
# `.compile` default so tests can pass a fake without mocking. testthat's
# `local_mocked_bindings` does NOT engage under covr instrumentation
# (covr's traced binding wins), so the success / abort paths are tested
# by injecting `.compile` directly. The body is a thin passthrough that
# only runs with a real TeX install (exercised by the tinytex-gated
# end-to-end compile tests), so it is excluded from coverage.
.tabular_latexmk <- function(tex_file, file) {
  # nocov start
  tinytex::latexmk(tex_file, engine = "xelatex", pdf_file = file)
  # nocov end
}

# Surface a friendly cli error when xelatex / latexmk fails.
# Detects the common "tabularray.sty not found" / "missing
# package" pattern and points the user at the right remediation
# path for their environment.
.pdf_compile_abort <- function(err) {
  msg <- conditionMessage(err)
  missing_pkg <- .pdf_extract_missing_pkg(msg)
  # The error names the missing `.sty` stem (graphicx, fontenc, helvet);
  # tlmgr installs by CTAN package name (graphics, base, psnfss), so map
  # the stems before suggesting the install command.
  install_pkg <- unique(vapply(
    missing_pkg,
    .latex_sty_to_ctan,
    character(1L)
  ))

  hints <- if (length(missing_pkg) > 0L) {
    c(
      "x" = "Missing LaTeX package{?s}: {.val {missing_pkg}}.",
      "i" = "On a local machine: install via {.run tinytex::tlmgr_install(c({paste(.sh_quote(install_pkg), collapse = ', ')}))}.",
      "i" = "See {.fn tabular::check_latex} for the full required-package set and remediation.",
      "i" = "In a containerised workspace (Domino / Posit Workbench / Databricks): ask admin to add {.val {paste(install_pkg, collapse = ' ')}} to the image build.",
      "i" = "On an OS-managed TeX Live (RHEL/dnf, Debian/apt): tlmgr is locked, so install a user-space TinyTeX with {.run tinytex::install_tinytex()} instead. Never pass {.code --ignore-warning} to force a locked tlmgr."
    )
  } else {
    c(
      "x" = "xelatex compilation failed.",
      "i" = "Run with {.code options(tinytex.verbose = TRUE)} to see the full log."
    )
  }

  cli::cli_abort(
    c(
      "PDF compilation failed.",
      hints,
      "i" = "Fallback: render to HTML or RTF instead via {.code emit(spec, \"out.html\")} or {.code emit(spec, \"out.rtf\")}."
    ),
    class = "tabular_error_backend",
    call = rlang::caller_env(2L)
  )
}

# Parse a latexmk error message for missing-package hints.
# Returns a character vector of package names (without ".sty"
# suffix) — possibly length 0 if the message doesn't match a
# known pattern.
.pdf_extract_missing_pkg <- function(msg) {
  patterns <- c(
    # \! LaTeX Error: File `tabularray.sty' not found.
    "[Ff]ile [`'\"]([^`'\".]+)\\.sty['\"]? not found",
    # ! I can't find file `tabularray'.
    "can't find file [`']([^`']+)[`']",
    # ! Package fontspec Error: The font "Liberation Serif" cannot be found.
    "Package ([a-zA-Z0-9_-]+) Error"
  )
  hits <- character()
  for (pat in patterns) {
    m <- regmatches(msg, regexec(pat, msg))[[1L]]
    if (length(m) >= 2L && nzchar(m[[2L]])) {
      hits <- c(hits, m[[2L]])
    }
  }
  unique(hits)
}

# Map an emitted `.sty` stem to the CTAN / tlmgr package that ships it.
# graphicx ships in `graphics`; fontenc / inputenc in `base`; the named
# pdflatex font `.sty` files (helvet, courier, mathptmx, mathpazo) in
# `psnfss`; the TeX Gyre font commands (tg*) in `tex-gyre`. Anything
# else is installed under its own name. Single source of truth for the
# stem -> CTAN mapping (also used by the #B3 superset test).
.latex_sty_to_ctan <- function(sty) {
  if (identical(sty, "graphicx")) {
    return("graphics")
  }
  if (sty %in% c("fontenc", "inputenc")) {
    return("base")
  }
  if (sty %in% c("helvet", "courier", "mathptmx", "mathpazo")) {
    return("psnfss")
  }
  if (grepl("^tg", sty)) {
    return("tex-gyre")
  }
  sty
}

# ---------------------------------------------------------------------
# check_latex() — local-availability diagnostic for PDF output
# ---------------------------------------------------------------------

#' Check LaTeX-package availability for PDF output
#'
#' Reports, for every TeX package the LaTeX / PDF backend can emit,
#' whether it is present in the local TeX tree, and prints the exact
#' [`tinytex::tlmgr_install()`] call that installs any that are
#' missing. Run this before `emit(spec, "out.pdf")` on a fresh
#' machine to turn a cryptic mid-compile `File 'tabularray.sty' not
#' found` into an up-front, actionable checklist.
#'
#' @details
#'
#' The required set is a superset of every `\\usepackage{}` /
#' `\\UseTblrLibrary{}` directive the backend emits, across all
#' conditional branches (running headers / footers pull `fancyhdr` +
#' `lastpage`; `xelatex` pulls `fontspec`; `pdflatex` pulls the
#' classic font bundles). The check is informational, it does not
#' install anything.
#'
#' **OS-managed TeX Live gotcha.** On Linux distributions that ship
#' TeX Live through the system package manager (RHEL / Fedora via
#' `dnf`, Debian / Ubuntu via `apt`), `tlmgr` is locked against
#' user installs and `tlmgr_install()` will fail. The fix is to
#' install a user-space TinyTeX with [`tinytex::install_tinytex()`]
#' and let that tree own the packages. Never force a locked `tlmgr`
#' with `--ignore-warning`: it leaves the system tree half-written.
#'
#' **Slow / stuck install (often Windows).** The default CTAN
#' repository `mirror.ctan.org` redirects to a random mirror on
#' every call, and a slow or stale one makes [`tinytex::tlmgr_install()`]
#' appear to hang. Pin a concrete mirror once with
#' [`tinytex::tlmgr_repo()`]`("auto")` (it follows the redirect a
#' single time and remembers the result), then retry the install.
#'
#' **Status markers:**
#'
#' * `v` — package is installed in the local TeX tree.
#' * `x` — package is missing; the `tlmgr_install()` line at the
#'   bottom of the report installs every missing package at once.
#' * `?` — availability could not be determined (no `tinytex`, or
#'   `tlmgr` not reachable); treated as missing for remediation.
#'
#' Requires the `tinytex` package (in `Suggests`); call
#' `install.packages("tinytex")` first if it isn't installed.
#'
#' @param quiet *Suppress the printed cli report.*
#'   `<logical(1)>: default FALSE`. When `TRUE`, runs the checks and
#'   returns the result invisibly without printing. Use in scripts
#'   that branch on the return value.
#'
#' @return *Invisibly returns a data frame* with one row per
#'   required package and columns `package` (`<character>`) and
#'   `installed` (`<logical>`, `NA` when undeterminable). Side
#'   effect: prints a cli report with a per-package status marker
#'   and, when anything is missing, the exact `tlmgr_install()`
#'   remedy.
#'
#' @examples
#' # ---- Example 1: Audit the PDF toolchain before emitting ----
#' #
#' # Run check_latex() on a fresh machine to confirm every LaTeX
#' # package the PDF backend needs is present. The call prints a
#' # status line per package and, if any are missing, the exact
#' # tinytex::tlmgr_install() command to fix them in one shot. It is
#' # guarded on tinytex so it is a no-op where TeX is unavailable.
#' if (requireNamespace("tinytex", quietly = TRUE)) {
#'   check_latex()
#' }
#'
#' @seealso
#' **Companion diagnostic:** [`check_fonts()`].
#'
#' **Consumes the result:** [`emit()`].
#'
#' @export
check_latex <- function(quiet = FALSE) {
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
  rlang::check_installed(
    "tinytex",
    reason = "to check LaTeX-package availability for PDF output"
  )

  pkgs <- .tabular_required_tex_packages
  out <- data.frame(
    package = pkgs,
    installed = .latex_pkgs_installed(pkgs),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  if (!quiet) {
    .check_latex_report(out)
  }
  invisible(out)
}

# Vectorised local-availability check for CTAN packages. One
# `tinytex::check_installed()` call (it queries the installed list once,
# then does `pkgs %in% list`), not one tlmgr shell-out per package.
# `base` is part of every TeX install (fontenc / inputenc live there),
# so short-circuit it as present. Returns NA for the queried packages
# when tlmgr is unreachable (treated as missing for remediation).
.latex_pkgs_installed <- function(pkgs) {
  is_base <- pkgs == "base"
  queried <- pkgs[!is_base]
  res <- tryCatch(
    as.logical(tinytex::check_installed(queried)),
    error = function(e) rep(NA, length(queried))
  )
  out <- logical(length(pkgs))
  out[is_base] <- TRUE
  out[!is_base] <- res
  out
}

# Print the cli report for a check_latex() result data frame.
.check_latex_report <- function(out) {
  cli::cli_h3("LaTeX packages for PDF output")
  for (i in seq_len(nrow(out))) {
    pkg <- out$package[[i]]
    ok <- out$installed[[i]]
    marker <- if (isTRUE(ok)) {
      "v"
    } else if (isFALSE(ok)) {
      "x"
    } else {
      "?"
    }
    cli::cli_text("  {marker} {pkg}")
  }

  missing <- out$package[!.is_true_vec(out$installed)]
  if (length(missing) == 0L) {
    cli::cli_alert_success("All required LaTeX packages are installed.")
    return(invisible(NULL))
  }
  cli::cli_alert_warning(
    "Missing {length(missing)} LaTeX package{?s}: {.val {missing}}."
  )
  cli::cli_text(
    "Install with {.run tinytex::tlmgr_install(c({paste(.sh_quote(missing), collapse = ', ')}))}."
  )
  cli::cli_text(
    "If the install stalls (commonly on Windows, where the default CTAN mirror redirects on every call), pin a concrete mirror once with {.run tinytex::tlmgr_repo(\"auto\")} then retry."
  )
  cli::cli_text(
    "On an OS-managed TeX Live (RHEL/dnf, Debian/apt) tlmgr is locked: install a user-space TinyTeX with {.run tinytex::install_tinytex()} instead. Never force a locked tlmgr with {.code --ignore-warning}."
  )
  invisible(NULL)
}

# Vectorised "is exactly TRUE" — NA and FALSE both count as not-installed.
.is_true_vec <- function(x) {
  !is.na(x) & x
}

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("pdf", backend_pdf)
