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
# uses these. install_latex_deps() (future) bundles the list as a
# tinytex::tlmgr_install() call.
# ---------------------------------------------------------------------

.tabular_required_tex_packages <- c(
  "tabularray", # the table engine
  "xcolor", # colours
  "graphicx", # figures
  "siunitx", # number formatting / decimal alignment
  "geometry", # margins / paper size
  "hyperref", # \href links
  "iftex", # engine detection
  # TeX Gyre bundles — used when font_family resolves to a generic.
  "tex-gyre",
  # pdflatex font bundles — used when font_family is named.
  "psnfss",
  "courier",
  "helvet"
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

# Surface a friendly cli error when xelatex / latexmk fails.
# Detects the common "tabularray.sty not found" / "missing
# package" pattern and points the user at the right remediation
# path for their environment.
.pdf_compile_abort <- function(err) {
  msg <- conditionMessage(err)
  missing_pkg <- .pdf_extract_missing_pkg(msg)

  hints <- if (length(missing_pkg) > 0L) {
    c(
      "x" = "Missing LaTeX package{?s}: {.val {missing_pkg}}.",
      "i" = "On a local machine: install via {.run tinytex::tlmgr_install(c({paste(.sh_quote(missing_pkg), collapse = ', ')}))}.",
      "i" = "In a containerised workspace (Domino / Posit Workbench / Databricks): ask admin to add {.val {paste(missing_pkg, collapse = ' ')}} to the image build."
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

# ---------------------------------------------------------------------
# Register with the backend dispatcher
# ---------------------------------------------------------------------

.register_backend("pdf", backend_pdf)
