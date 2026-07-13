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

# Bundled fallback copies, shipped in inst/tex/ (verbatim CTAN files,
# provenance in inst/COPYRIGHTS). These are the only requirements no
# TinyTeX flavor ships; every other entry in the required set is part of
# the community "TinyTeX" bundle (tinytex-releases) and of any full TeX
# Live. Both are pure single-file macro packages, so a copy placed next
# to the generated .tex (the compile cwd, which kpathsea searches first)
# is a complete substitute for a tlmgr install. Names are CTAN package
# names (a subset of .tabular_required_tex_packages, drift-guarded in
# tests); values are the shipped file names.
.tabular_bundled_sty <- c(
  tabularray = "tabularray.sty",
  ninecolors = "ninecolors.sty"
)

# One representative `.sty` file per required CTAN package, probed via
# kpsewhich by check_latex() / the compile-time staging. kpathsea is
# what xelatex itself uses to resolve files, so this is ground truth on
# every TeX layout; tinytex::check_installed() queries the tlmgr package
# database instead, which is absent or non-functional on apt-installed
# TeX Live and frozen TinyTeX images (all-FALSE false negatives).
# `tex-gyre` is a font package, but it also ships tgtermes.sty (the
# pdflatex wrapper), so the probe works for it too.
.tabular_pkg_probe_sty <- c(
  tabularray = "tabularray.sty",
  ninecolors = "ninecolors.sty",
  xcolor = "xcolor.sty",
  graphics = "graphicx.sty",
  siunitx = "siunitx.sty",
  geometry = "geometry.sty",
  hyperref = "hyperref.sty",
  iftex = "iftex.sty",
  base = "fontenc.sty",
  fancyhdr = "fancyhdr.sty",
  lastpage = "lastpage.sty",
  fontspec = "fontspec.sty",
  "tex-gyre" = "tgtermes.sty",
  psnfss = "mathptmx.sty"
)

# ---------------------------------------------------------------------
# Backend entry — receives the resolved grid + a writable file path
# ---------------------------------------------------------------------

# Render `grid` to a PDF file. Writes the LaTeX source to a
# tempfile (via backend_latex), then compiles via
# `tinytex::latexmk()`. Returns the file path invisibly.
backend_pdf <- function(grid, file, .compile = .tabular_latexmk) {
  # Force the target path BEFORE changing directory: `file` may arrive
  # as an unevaluated promise over a relative path, which would
  # otherwise resolve against the throwaway tex dir below.
  force(file)
  rlang::check_installed(
    "tinytex",
    reason = "to compile PDF output via xelatex"
  )

  tex_dir <- tempfile(pattern = "tabular_pdf_")
  dir.create(tex_dir, recursive = TRUE)
  on.exit(unlink(tex_dir, recursive = TRUE), add = TRUE)

  tex_file <- file.path(tex_dir, "tabular.tex")
  backend_latex(grid, tex_file)
  # Probe with the same TeX the compile will use: tinytex::latexmk()
  # prepends the TinyTeX-root bin dir to the PATH internally, so the
  # staging kpsewhich must see it too or it stages against the wrong
  # (system) tree.
  .local_path_prepend(.tinytex_bin_dir())
  .pdf_stage_bundled_sty(tex_dir)

  # Compile with the working directory set to tex_dir so a figure's
  # relative `\includegraphics` sidecar (written next to tabular.tex by
  # backend_latex) resolves; latexmk searches graphics relative to its
  # cwd, not the input file's directory. `file` was forced above (emit
  # absolutises it eagerly), so the PDF still lands at the user's
  # target. A table emits no graphics, so this is inert for the table
  # path. `withr::local_dir()` restores the directory on any exit,
  # including a compile error, before the tex dir is unlinked.
  withr::local_dir(tex_dir)
  result <- tryCatch(
    .compile(tex_file, file),
    error = function(e) e
  )
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

# Resolve `.sty` file names through kpsewhich, the resolver xelatex
# itself uses. Returns one logical per input: TRUE (found), FALSE (not
# found), or NA for the whole vector when availability cannot be
# determined (kpsewhich absent from PATH, or the call itself errors).
# Parsing rule (confirmed on an apt TeX Live image): kpsewhich prints
# only the FOUND paths and exits non-zero when any name is unresolved,
# so results are matched back to queries by basename, never by
# position, and the status attribute is ignored.
.latex_sty_available <- function(sty_files) {
  kpse <- Sys.which("kpsewhich")
  if (!nzchar(kpse)) {
    return(rep(NA, length(sty_files)))
  }
  found <- tryCatch(
    suppressWarnings(
      system2(kpse, shQuote(sty_files), stdout = TRUE, stderr = FALSE)
    ),
    error = function(e) NULL
  )
  if (is.null(found)) {
    return(rep(NA, length(sty_files)))
  }
  sty_files %in% basename(as.character(found))
}

# Bin directory of a TinyTeX at the standard root (~/.TinyTeX,
# ~/Library/TinyTeX, %APPDATA%/TinyTeX) — the location used both by
# tinytex::install_tinytex() and by `quarto install tinytex`. Returns
# character(0) when no root (or no xelatex inside it) is found.
#
# Why this matters: tinytex::latexmk(), the compile path, prepends this
# bin dir to the PATH for the compile (its internal tweak_path()), so a
# TinyTeX at the root is used even when it is not on the caller's PATH.
# Every diagnostic probe (check_latex(), the bundled-sty staging) must
# resolve TeX the same way, or the report describes a different TeX
# than the one the compile will actually run.
.tinytex_bin_dir <- function() {
  if (!requireNamespace("tinytex", quietly = TRUE)) {
    return(character())
  }
  root <- tryCatch(
    tinytex::tinytex_root(error = FALSE),
    error = function(e) ""
  )
  if (!nzchar(root)) {
    return(character())
  }
  bins <- list.dirs(file.path(root, "bin"), recursive = FALSE)
  exe <- if (.Platform$OS.type == "windows") "xelatex.exe" else "xelatex"
  bins <- bins[file.exists(file.path(bins, exe))]
  if (length(bins) == 0L) {
    return(character())
  }
  bins[[1L]]
}

# Prepend `dir` to the PATH for the lifetime of the calling frame — a
# base-R twin of tinytex's internal tweak_path(), so the diagnostics
# stay usable without withr (Suggests-only). No-op on character(0).
.local_path_prepend <- function(dir, envir = parent.frame()) {
  if (length(dir) == 0L) {
    return(invisible(NULL))
  }
  old <- Sys.getenv("PATH")
  Sys.setenv(PATH = paste(c(dir, old), collapse = .Platform$path.sep))
  do.call(
    on.exit,
    list(substitute(Sys.setenv(PATH = x), list(x = old)), add = TRUE),
    envir = envir
  )
  invisible(NULL)
}

# Minimum TeX Live release year whose LaTeX format is new enough for
# the bundled tabularray: the 2025C release hard-requires the
# 2022-11-01 LaTeX kernel, which TeX Live ships from the 2023 release
# onward. Older kernels die at `\ProvidesExplPackage` (pre-2020, where
# expl3 is not preloaded into the format) or at tabularray's own
# "latex-too-old" guard (2020-2022) — no bundled `.sty` can fix a
# kernel, so check_latex() must surface the age up front.
.tabular_min_texlive_year <- 2023L

# TeX Live release year of the active xelatex, parsed from the first
# `xelatex --version` banner line ("XeTeX 3.14...-0.999998 (TeX Live
# 2026)"). Returns NA_integer_ when xelatex is absent, the call fails,
# or the banner names a different distribution — MiKTeX is
# rolling-release and always current, so "undetermined" is the honest
# report there, not a failure. `.version_line` is an injected seam for
# tests, same style as backend_pdf()'s `.compile`.
.latex_texlive_year <- function(.version_line = NULL) {
  line <- .version_line
  if (is.null(line)) {
    xelatex <- Sys.which("xelatex")
    if (!nzchar(xelatex)) {
      return(NA_integer_)
    }
    line <- tryCatch(
      suppressWarnings(
        system2(xelatex, "--version", stdout = TRUE, stderr = FALSE)
      )[1L],
      error = function(e) NA_character_
    )
  }
  if (length(line) == 0L || is.na(line)) {
    return(NA_integer_)
  }
  m <- regmatches(line, regexec("TeX Live (\\d{4})", line))[[1L]]
  if (length(m) < 2L) {
    return(NA_integer_)
  }
  as.integer(m[[2L]])
}

# Stage the bundled `.sty` copies (inst/tex/) into the compile
# directory for every bundled package the local TeX cannot resolve.
# kpathsea searches the compile cwd first, so a staged copy is picked
# up with zero path configuration; packages the system resolves keep
# their (possibly newer) system copies. Uncertain availability (NA)
# stages too: copying when unsure is harmless, it only shadows for this
# one compile. `.available` is an injected seam for tests, same style
# as backend_pdf()'s `.compile`.
.pdf_stage_bundled_sty <- function(
  tex_dir,
  .available = .latex_sty_available
) {
  sty <- .tabular_bundled_sty
  ok <- .available(unname(sty))
  needed <- sty[!(ok %in% TRUE)]
  for (f in needed) {
    src <- system.file("tex", f, package = "tabular")
    if (nzchar(src)) {
      file.copy(src, file.path(tex_dir, f), overwrite = TRUE)
    }
  }
  invisible(unname(needed))
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

  # A pre-2023 LaTeX kernel dies at tabularray's `\ProvidesExplPackage`
  # (pre-2020 formats, where expl3 is not preloaded) or at tabularray's
  # own "latex-too-old" guard (2020-2022 formats). Either way the fix is
  # a newer TeX, not a package install, so this branch wins over the
  # missing-package heuristic.
  kernel_too_old <- grepl("ProvidesExplPackage", msg, fixed = TRUE) ||
    grepl("release is too old", msg, fixed = TRUE)

  hints <- if (kernel_too_old) {
    c(
      "x" = "The LaTeX kernel is too old for tabularray: it requires the 2022-11-01 kernel, shipped from TeX Live 2023 onward.",
      "i" = "Run {.run tabular::check_latex()} to see the TeX Live year of the active installation.",
      "i" = "Update the TeX installation, or install a user-space TinyTeX with {.run tinytex::install_tinytex(bundle = \"TinyTeX\")} or {.code quarto install tinytex} (a GitHub download, so it also works behind proxies that block CTAN); both land in the standard TinyTeX location, which the PDF compile prefers over the {.envvar PATH} automatically.",
      "i" = "In a containerised workspace (Domino / Posit Workbench / Databricks): ask the image admin to update TeX Live; 2018-era images fail exactly this way."
    )
  } else if (length(missing_pkg) > 0L) {
    c(
      "x" = "Missing LaTeX package{?s}: {.val {missing_pkg}}.",
      "i" = "On a local machine: install via {.run tinytex::tlmgr_install(c({paste(.sh_quote(install_pkg), collapse = ', ')}))}.",
      "i" = "See {.fn tabular::check_latex} for the full required-package set and remediation.",
      "i" = "In a containerised workspace (Domino / Posit Workbench / Databricks): ask admin to add {.val {paste(install_pkg, collapse = ' ')}} to the image build.",
      "i" = "On an OS-managed TeX Live (RHEL/dnf, Debian/apt) or wherever tlmgr is locked: install a user-space TinyTeX with {.run tinytex::install_tinytex(bundle = \"TinyTeX\")} instead. Never pass {.code --ignore-warning} to force a locked tlmgr.",
      "i" = "Where no install is possible at all: download each missing {.code .sty} from CTAN into {.path ~/texmf/tex/latex/<package>/} and set {.envvar TEXMFHOME} to {.path ~/texmf}."
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
#' whether the local TeX installation can resolve it, and prints the
#' exact [`tinytex::tlmgr_install()`] call that installs any that are
#' genuinely missing. Run this before `emit(spec, "out.pdf")` on a
#' fresh machine to turn a cryptic mid-compile `File 'tabularray.sty'
#' not found` into an up-front, actionable checklist.
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
#' **Minimum TeX Live version.** Package availability alone is not
#' sufficient: the bundled `tabularray` requires the 2022-11-01 LaTeX
#' kernel, shipped from **TeX Live 2023** onward. The report therefore
#' opens with the TeX Live year of the active `xelatex` and fails the
#' check when the kernel predates it — the classic symptom is an
#' OS-managed or containerised image (Domino, Posit Workbench) frozen
#' on TeX Live 2018, where every package resolves but the compile dies
#' at `\\ProvidesExplPackage`. The remedy is a newer TeX, not a package
#' install: update the image, or install a user-space TinyTeX with
#' [`tinytex::install_tinytex()`]`(bundle = "TinyTeX")` or
#' `quarto install tinytex` — the Quarto route downloads from GitHub,
#' so it also works behind corporate proxies that block CTAN mirrors.
#' Both land in the standard TinyTeX location, which the compile (and
#' this check) prefer over the `PATH` automatically. MiKTeX is
#' rolling-release (always current), so its version reports as
#' undetermined (`?`) rather than failing.
#'
#' **How availability is probed.** The check first resolves TeX the
#' way the compile does: [`tinytex::latexmk()`] prefers a TinyTeX at
#' the standard root (`~/.TinyTeX` on Linux, `~/Library/TinyTeX` on
#' macOS, `%APPDATA%/TinyTeX` on Windows — the location used by both
#' [`tinytex::install_tinytex()`] and `quarto install tinytex`) over
#' whatever is on the `PATH`, and the report probes that same tree.
#' Each package is then resolved through
#' `kpsewhich`, the same file resolver `xelatex` uses at compile time,
#' so the report reflects what a compile will actually find. This works
#' on every TeX layout — TinyTeX, a full TeX Live, or an OS-managed
#' install (Debian/apt, RHEL/dnf) where the `tlmgr` package database is
#' absent and database-backed checks report everything as missing.
#'
#' **Bundled fallback packages.** tabular ships verbatim copies of
#' `tabularray` and `ninecolors` (the only requirements not included in
#' any TinyTeX flavor) and stages them next to the generated `.tex`
#' at compile time whenever the local TeX cannot resolve them. A
#' bundled package therefore always passes the check — no
#' `tlmgr_install()` is ever needed for those two. On the community
#' TinyTeX bundle (`tinytex::install_tinytex(bundle = "TinyTeX")`) or
#' any larger installation, everything else is already present, so PDF
#' emission needs no package installs at all — including on restricted
#' servers where `tlmgr` is locked.
#'
#' **OS-managed TeX Live gotcha.** On Linux distributions that ship
#' TeX Live through the system package manager (RHEL / Fedora via
#' `dnf`, Debian / Ubuntu via `apt`), `tlmgr` is locked against
#' user installs and `tlmgr_install()` will fail. The fix is to
#' install a user-space TinyTeX with
#' [`tinytex::install_tinytex()`]`(bundle = "TinyTeX")` and let that
#' tree own the packages. Never force a locked `tlmgr` with
#' `--ignore-warning`: it leaves the system tree half-written. Where no
#' TeX install is possible at all, a missing single-file macro package
#' can be sideloaded without `tlmgr`: download its `.sty` from CTAN
#' into `~/texmf/tex/latex/<package>/` and set the `TEXMFHOME`
#' environment variable to `~/texmf`.
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
#' * `v` — package resolves in the local TeX tree, or is missing but
#'   covered by a bundled copy (marked `bundled copy used`).
#' * `x` — package is missing; the `tlmgr_install()` line at the
#'   bottom of the report installs every missing package at once.
#' * `?` — availability could not be determined (`kpsewhich` not on
#'   the `PATH`, i.e. no TeX installation); treated as missing for
#'   remediation.
#'
#' @param quiet *Suppress the printed cli report.*
#'   `<logical(1)>: default FALSE`. When `TRUE`, runs the checks and
#'   returns the result invisibly without printing. Use in scripts
#'   that branch on the return value.
#'
#' @return *Invisibly returns a data frame* with one row per
#'   required package and columns `package` (`<character>`),
#'   `installed` (`<logical>`, `NA` when undeterminable), and
#'   `bundled` (`<logical>`, `TRUE` for packages tabular ships a
#'   fallback copy of), plus a `texlive_year` attribute
#'   (`<integer(1) | NA_integer_>`, the TeX Live release year of the
#'   active `xelatex`). Side effect: prints a cli report with a
#'   per-package status marker and, when anything is missing or the
#'   TeX Live release is older than 2023, the exact remedy.
#'
#' @examples
#' # ---- Example 1: Audit the PDF toolchain before emitting ----
#' #
#' # Run check_latex() on a fresh machine to confirm every LaTeX
#' # package the PDF backend needs is present. The call prints a
#' # status line per package and, if any are missing, the exact
#' # tinytex::tlmgr_install() command to fix them in one shot. Where
#' # no TeX is installed every row reports `?` and the remedy lines
#' # print; the call never errors.
#' check_latex()
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
  # Resolve TeX exactly like the compile does: tinytex::latexmk()
  # prefers a TinyTeX at the standard root (installed by either
  # tinytex::install_tinytex() or `quarto install tinytex`) over the
  # PATH, so the report must probe that same tree.
  .local_path_prepend(.tinytex_bin_dir())
  pkgs <- .tabular_required_tex_packages
  out <- data.frame(
    package = pkgs,
    installed = .latex_pkgs_installed(pkgs),
    bundled = pkgs %in% names(.tabular_bundled_sty),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  attr(out, "texlive_year") <- .latex_texlive_year()

  if (!quiet) {
    .check_latex_report(out, texlive_year = attr(out, "texlive_year"))
  }
  invisible(out)
}

# Vectorised local-availability check for CTAN packages: one kpsewhich
# call over each package's representative `.sty` file (the
# .tabular_pkg_probe_sty map). kpathsea is what xelatex resolves files
# with, so this reflects what a compile will actually find — unlike
# tinytex::check_installed(), which queries the tlmgr database and
# returns all-FALSE on apt-installed TeX Live / frozen TinyTeX images.
# Returns NA when kpsewhich itself is unavailable.
.latex_pkgs_installed <- function(pkgs) {
  .latex_sty_available(unname(.tabular_pkg_probe_sty[pkgs]))
}

# Print the cli report for a check_latex() result data frame. A
# `bundled` package that the local TeX cannot resolve still passes: the
# shipped copy in inst/tex/ is staged next to the .tex at compile
# time, so it never needs a tlmgr install.
.check_latex_report <- function(out, texlive_year = NA_integer_) {
  bundled <- if ("bundled" %in% names(out)) {
    out$bundled
  } else {
    logical(nrow(out))
  }
  min_year <- .tabular_min_texlive_year
  kernel_old <- !is.na(texlive_year) && texlive_year < min_year
  cli::cli_h3("LaTeX packages for PDF output")
  dist_line <- if (kernel_old) {
    "x TeX Live {texlive_year} (LaTeX kernel too old; tabularray needs the 2022-11-01 kernel, TeX Live {min_year} or newer)"
  } else if (!is.na(texlive_year)) {
    "v TeX Live {texlive_year}"
  } else {
    "? TeX Live version (xelatex missing, or a non-TeX-Live distribution such as MiKTeX)"
  }
  cli::cli_text(paste0("  ", dist_line))
  for (i in seq_len(nrow(out))) {
    pkg <- out$package[[i]]
    ok <- out$installed[[i]]
    line <- if (isTRUE(ok)) {
      "v {pkg}"
    } else if (bundled[[i]]) {
      "v {pkg} (not found, bundled copy used)"
    } else if (isFALSE(ok)) {
      "x {pkg}"
    } else {
      "? {pkg}"
    }
    cli::cli_text(paste0("  ", line))
  }

  missing <- out$package[!.is_true_vec(out$installed) & !bundled]
  if (length(missing) == 0L && !kernel_old) {
    cli::cli_alert_success("All required LaTeX packages are available.")
    return(invisible(NULL))
  }
  if (kernel_old) {
    cli::cli_alert_warning(
      "TeX Live {texlive_year} cannot compile tabular's PDF output: the bundled tabularray requires the 2022-11-01 LaTeX kernel (TeX Live {min_year} or newer)."
    )
    cli::cli_text(
      "Update the TeX installation, or install a user-space TinyTeX with {.run tinytex::install_tinytex(bundle = \"TinyTeX\")} or {.code quarto install tinytex} (downloads from GitHub, so it also works behind proxies that block CTAN). Both land in the standard TinyTeX location, which tabular and {.fn tinytex::latexmk} prefer over the {.envvar PATH} automatically."
    )
    cli::cli_text(
      "In a containerised workspace (Domino / Posit Workbench / Databricks): ask the image admin to update TeX Live, or render to RTF / HTML / DOCX instead via {.code emit(spec, \"out.rtf\")}."
    )
    if (length(missing) == 0L) {
      return(invisible(NULL))
    }
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
    "On an OS-managed TeX Live (RHEL/dnf, Debian/apt) or wherever tlmgr is locked: install a user-space TinyTeX with {.run tinytex::install_tinytex(bundle = \"TinyTeX\")} instead (the community bundle covers every package above). Never force a locked tlmgr with {.code --ignore-warning}."
  )
  cli::cli_text(
    "Where no TeX install is possible at all: download each missing {.code .sty} from CTAN into {.path ~/texmf/tex/latex/<package>/} and set {.envvar TEXMFHOME} to {.path ~/texmf}; xelatex resolves it from there without tlmgr."
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
