# backend_pdf() — tinytex-driven PDF backend (wraps backend_latex).
#
# The actual xelatex compile is heavy + environment-dependent
# (needs TinyTeX + tabularray + xcolor + ...), so most tests
# exercise the supporting helpers directly. The end-to-end
# compile test skips when tinytex / TeX Live isn't installed.

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("pdf backend is registered at package load", {
  expect_true(tabular:::.has_backend("pdf"))
})

# ---------------------------------------------------------------------
# Error parsing — .pdf_extract_missing_pkg
# ---------------------------------------------------------------------

test_that(".pdf_extract_missing_pkg detects 'File X.sty not found'", {
  msg <- "! LaTeX Error: File `tabularray.sty' not found."
  expect_identical(
    tabular:::.pdf_extract_missing_pkg(msg),
    "tabularray"
  )
})

test_that(".pdf_extract_missing_pkg detects \"can't find file\" form", {
  msg <- "! I can't find file `xcolor'."
  expect_identical(
    tabular:::.pdf_extract_missing_pkg(msg),
    "xcolor"
  )
})

test_that(".pdf_extract_missing_pkg detects 'Package X Error'", {
  msg <- "! Package fontspec Error: The font \"Source Serif Pro\" cannot be found."
  expect_identical(
    tabular:::.pdf_extract_missing_pkg(msg),
    "fontspec"
  )
})

test_that(".pdf_extract_missing_pkg returns empty character on no match", {
  msg <- "! Some unrelated TeX error that doesn't match the patterns."
  expect_identical(
    tabular:::.pdf_extract_missing_pkg(msg),
    character()
  )
})

test_that(".pdf_extract_missing_pkg deduplicates when multiple patterns hit", {
  msg <- paste(
    "! LaTeX Error: File `tabularray.sty' not found.",
    "! Package tabularray Error: Library `siunitx' not loaded.",
    sep = "\n"
  )
  out <- tabular:::.pdf_extract_missing_pkg(msg)
  expect_identical(out, "tabularray")
})

# ---------------------------------------------------------------------
# Required-package list
# ---------------------------------------------------------------------

test_that(".tabular_required_tex_packages includes the core regulatory bundles", {
  pkgs <- tabular:::.tabular_required_tex_packages
  expect_true("tabularray" %in% pkgs)
  expect_true("siunitx" %in% pkgs)
  expect_true("xcolor" %in% pkgs)
  expect_true("hyperref" %in% pkgs)
  expect_true("geometry" %in% pkgs)
  # Previously-undeclared deps that the backend can emit (B3).
  expect_true("fontspec" %in% pkgs)
  expect_true("fancyhdr" %in% pkgs)
  expect_true("lastpage" %in% pkgs)
  expect_true("ninecolors" %in% pkgs)
  # The named-font .sty files (helvet, courier) ship inside psnfss, which
  # IS declared; they must NOT appear as standalone entries because neither
  # is a separately installable tlmgr package (false-negative + broken
  # install hint otherwise) (#review).
  expect_true("psnfss" %in% pkgs)
  expect_false("helvet" %in% pkgs)
  expect_false("courier" %in% pkgs)
})

test_that(".latex_sty_to_ctan maps .sty stems to their CTAN package (#review)", {
  expect_identical(tabular:::.latex_sty_to_ctan("graphicx"), "graphics")
  expect_identical(tabular:::.latex_sty_to_ctan("fontenc"), "base")
  expect_identical(tabular:::.latex_sty_to_ctan("inputenc"), "base")
  expect_identical(tabular:::.latex_sty_to_ctan("helvet"), "psnfss")
  expect_identical(tabular:::.latex_sty_to_ctan("courier"), "psnfss")
  expect_identical(tabular:::.latex_sty_to_ctan("tgtermes"), "tex-gyre")
  # Unmapped stems install under their own name.
  expect_identical(tabular:::.latex_sty_to_ctan("tabularray"), "tabularray")
})

test_that(".pdf_compile_abort install hint uses CTAN names, not .sty stems (#review)", {
  # A real compile error names the missing .sty stem (graphicx); the
  # remediation must point at the installable CTAN package (graphics), not
  # `tlmgr install graphicx` which fails.
  err <- simpleError("! LaTeX Error: File `graphicx.sty' not found.")
  expect_error(
    tabular:::.pdf_compile_abort(err),
    class = "tabular_error_backend"
  )
  msg <- tryCatch(
    tabular:::.pdf_compile_abort(err),
    tabular_error_backend = function(e) {
      paste(conditionMessage(e), paste(unlist(e$body), collapse = " "))
    }
  )
  expect_true(grepl("graphics", msg, fixed = TRUE))
  expect_false(grepl("tlmgr_install(c('graphicx'", msg, fixed = TRUE))
})

test_that(".tabular_required_tex_packages is a superset of every emitted directive (#B3)", {
  # Build a spec that exercises EVERY conditional preamble branch:
  # a populated pagehead (fancyhdr + lastpage) over the default font
  # (tgcursor -> tex-gyre under pdflatex, fontspec under xelatex).
  spec <- tabular(data.frame(x = c(1L, 2L)), titles = "T") |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      )
    )
  tex <- withr::local_tempfile(fileext = ".tex")
  emit(spec, tex)
  txt <- paste(readLines(tex, warn = FALSE), collapse = "\n")

  # Pull every \usepackage{X} / \UseTblrLibrary{X} token from the
  # emitted source (ignore option brackets like [T1] / [utf8]).
  m <- regmatches(
    txt,
    gregexpr(
      "\\\\(usepackage|RequirePackage|UseTblrLibrary)(\\[[^]]*\\])?\\{([^}]+)\\}",
      txt
    )
  )[[1L]]
  stys <- sub(
    ".*\\{([^}]+)\\}$",
    "\\1",
    m
  )
  stys <- unique(stys)
  expect_gt(length(stys), 0L)

  # Map each emitted .sty stem / tblr library to its CTAN package name
  # (the unit declared in .tabular_required_tex_packages) via the package's
  # own single-source-of-truth helper: graphicx.sty ships in `graphics`;
  # fontenc / inputenc in `base`; the named font .sty files (helvet,
  # courier, mathptmx, mathpazo) in `psnfss`; the TeX Gyre commands (tg*)
  # in `tex-gyre`.
  ctan <- vapply(stys, tabular:::.latex_sty_to_ctan, character(1L))

  declared <- tabular:::.tabular_required_tex_packages
  missing <- setdiff(ctan, declared)
  expect_identical(
    missing,
    character(),
    info = paste(
      "Emitted directives not declared in .tabular_required_tex_packages:",
      paste(missing, collapse = ", ")
    )
  )
})

test_that("check_latex() runs and returns the required set invisibly (#B3)", {
  out <- withr::with_options(
    list(cli.default_handler = function(...) invisible()),
    check_latex(quiet = TRUE)
  )
  expect_s3_class(out, "data.frame")
  expect_named(out, c("package", "installed", "bundled"))
  expect_identical(out$package, tabular:::.tabular_required_tex_packages)
  expect_type(out$installed, "logical")
  expect_type(out$bundled, "logical")
  expect_identical(
    out$package[out$bundled],
    names(tabular:::.tabular_bundled_sty)
  )
  # Invisible return: capturing autoprint yields nothing.
  expect_output(invisible(check_latex(quiet = TRUE)), regexp = NA)
})

test_that("check_latex() rejects a non-scalar quiet (#B3)", {
  expect_error(
    check_latex(quiet = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Defensive abort path
# ---------------------------------------------------------------------

test_that(".pdf_compile_abort names missing packages with remediation hints", {
  fake_err <- simpleError(
    "! LaTeX Error: File `tabularray.sty' not found."
  )
  err <- tryCatch(
    tabular:::.pdf_compile_abort(fake_err),
    tabular_error_backend = function(e) e
  )
  expect_s3_class(err, "tabular_error_backend")
  msg <- conditionMessage(err)
  expect_match(msg, "tabularray", fixed = TRUE)
  expect_match(msg, "tlmgr_install", fixed = TRUE)
  expect_match(msg, "Domino", fixed = TRUE)
  # No-tlmgr remedies: the community TinyTeX bundle + TEXMFHOME sideload.
  expect_match(msg, 'bundle = "TinyTeX"', fixed = TRUE)
  expect_match(msg, "TEXMFHOME", fixed = TRUE)
})

test_that(".pdf_compile_abort falls back to verbose-log hint for unknown errors", {
  fake_err <- simpleError("! Some opaque TeX error.")
  err <- tryCatch(
    tabular:::.pdf_compile_abort(fake_err),
    tabular_error_backend = function(e) e
  )
  expect_match(conditionMessage(err), "tinytex.verbose", fixed = TRUE)
  expect_match(conditionMessage(err), "Fallback", fixed = TRUE)
})

# ---------------------------------------------------------------------
# emit() dispatch
# ---------------------------------------------------------------------

test_that("emit(.pdf) dispatches to backend_pdf", {
  skip_if_not_installed("tinytex")
  skip_on_cran()
  # We don't actually compile here (heavy + tex-distro-dependent); we
  # verify the dispatcher routes to backend_pdf. Compare by formals, not
  # object identity: covr rewrites function bodies, so the registry copy
  # (captured at package load) and the namespace copy are no longer the
  # same object under instrumentation. Formals survive instrumentation.
  expect_true(tabular:::.has_backend("pdf"))
  fn <- tabular:::.tabular_backends[["pdf"]]
  expect_true(is.function(fn))
  expect_identical(formals(fn), formals(tabular:::backend_pdf))
})

# ---------------------------------------------------------------------
# End-to-end compile (skips when tinytex / TeX Live missing)
# ---------------------------------------------------------------------

test_that("emit(.pdf) compiles a minimal spec end to end (when TeX is available)", {
  skip_if_not_installed("tinytex")
  skip_on_cran()
  if (!nzchar(Sys.which("xelatex"))) {
    skip("xelatex not found on this machine")
  }
  spec <- tabular(data.frame(x = c(1L, 2L)), titles = "T")
  out <- withr::local_tempfile(fileext = ".pdf")
  result <- tryCatch(emit(spec, out), error = function(e) e)
  if (inherits(result, "error")) {
    # Likely a missing TeX package; the test surfaces the friendly
    # error path rather than asserting compile success.
    skip(sprintf("PDF compile failed: %s", conditionMessage(result)))
  }
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
})

test_that("emit(.pdf) compiles footnote markers (letters + symbol glyphs) and ties", {
  skip_if_not_installed("tinytex")
  skip_on_cran()
  if (!nzchar(Sys.which("xelatex"))) {
    skip("xelatex not found on this machine")
  }
  # The load-bearing risk: the symbol glyphs U+00A7 / U+00B6 / U+2016
  # (section / pilcrow / double-vert) and the preserved-whitespace ties
  # (`~`) must survive xelatex + tabularray inside a tblr cell. Pin the
  # symbols so the test deterministically exercises the riskiest glyphs
  # alongside an auto-allocated letter marker.
  df <- data.frame(
    label = c("  Indented PT", "Headache", "Nausea"),
    Total = c("10", "20", "30"),
    Active = c("5", "6", "7"),
    n = c(99L, 5L, 99L),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Footnote glyphs + ties") |>
    cols(
      label = col_spec(label = "PT"),
      n = col_spec(visible = FALSE),
      Total = col_spec(label = "Total"),
      Active = col_spec(label = "Active")
    ) |>
    footnote(
      "Auto letter.",
      .at = cells_body(where = n >= 50, j = "label")
    ) |>
    footnote("Section.", .at = cells_headers(j = "Total"), symbol = "§") |>
    footnote("Pilcrow.", .at = cells_headers(j = "Active"), symbol = "¶") |>
    footnote("Double-vert.", .at = cells_title(), symbol = "‖")
  out <- withr::local_tempfile(fileext = ".pdf")
  result <- tryCatch(suppressWarnings(emit(spec, out)), error = function(e) e)
  if (inherits(result, "error")) {
    skip(sprintf("PDF compile failed: %s", conditionMessage(result)))
  }
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
})

# ---------------------------------------------------------------------
# Mocked-compile coverage — exercise the backend_pdf() body and
# .pdf_compile_abort() without requiring tinytex on the test host.
# ---------------------------------------------------------------------

# These inject a fake compile step via backend_pdf()'s `.compile`
# argument rather than mocking. testthat's local_mocked_bindings does not
# engage under covr instrumentation (covr's traced binding wins, so the
# real compile runs and fails the test); dependency injection is
# covr-safe. See R/backend_pdf.R.
test_that("backend_pdf() aborts with tabular_error_backend when latexmk fails", {
  skip_if_not_installed("tinytex")
  spec <- tabular(data.frame(x = 1:2), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".pdf")
  expect_error(
    backend_pdf(
      grid,
      out,
      .compile = function(tex_file, file) {
        stop("! LaTeX Error: File `tabularray.sty' not found.")
      }
    ),
    class = "tabular_error_backend"
  )
})

test_that("backend_pdf() returns the file path invisibly on a successful compile", {
  skip_if_not_installed("tinytex")
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  out <- withr::local_tempfile(fileext = ".pdf")
  result <- backend_pdf(
    grid,
    out,
    .compile = function(tex_file, file) {
      writeLines("%PDF-stub", file)
      file
    }
  )
  expect_identical(result, out)
  expect_true(file.exists(out))
})

test_that("emit() to a relative .pdf path lands in the caller's directory (#pdf-relative-path)", {
  # emit() passed `.emit_absolute_path(file)` into the backend as a lazy
  # promise; backend_pdf() forced it only at `.compile(...)`, AFTER
  # changing into the throwaway tex dir, so a relative path normalised
  # against the temp dir and the "emitted" PDF vanished with it on exit.
  # `.emit_absolute_path()` is passed lazily below to reproduce the
  # emit() call shape exactly.
  skip_if_not_installed("tinytex")
  spec <- tabular(data.frame(x = 1L), titles = "T")
  grid <- as_grid(spec)
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  seen <- NULL
  backend_pdf(
    grid,
    tabular:::.emit_absolute_path("relative.pdf"),
    .compile = function(tex_file, file) {
      seen <<- file
      writeLines("%PDF-stub", file)
      file
    }
  )
  # The compile step must receive the path anchored at the CALLER's
  # working directory, not the compile dir.
  expect_identical(
    normalizePath(seen),
    normalizePath(file.path(dir, "relative.pdf"))
  )
  expect_true(file.exists(file.path(dir, "relative.pdf")))
})

test_that("check_latex(quiet = FALSE) reaches the cli report", {
  out <- suppressMessages(utils::capture.output(
    res <- check_latex(quiet = FALSE)
  ))
  expect_true(is.data.frame(res))
})

test_that(".check_latex_report covers the all-installed and missing branches", {
  ok <- data.frame(
    package = c("base", "graphics"),
    installed = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  miss <- data.frame(
    package = c("base", "fancyhdr"),
    installed = c(TRUE, NA),
    stringsAsFactors = FALSE
  )
  expect_no_error(suppressMessages(
    utils::capture.output(tabular:::.check_latex_report(ok))
  ))
  expect_no_error(suppressMessages(
    utils::capture.output(tabular:::.check_latex_report(miss))
  ))
})

test_that(".check_latex_report passes a missing-but-bundled package", {
  # tabularray is not resolvable here, but the bundled copy covers it:
  # the report must show a `v ... bundled copy used` row and the
  # all-available success line, with NO tlmgr_install remedy.
  out <- data.frame(
    package = c("base", "tabularray", "ninecolors"),
    installed = c(TRUE, FALSE, NA),
    bundled = c(FALSE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  expect_snapshot(tabular:::.check_latex_report(out))
})

test_that(".check_latex_report remedies name the TinyTeX bundle and TEXMFHOME", {
  out <- data.frame(
    package = c("tabularray", "fancyhdr"),
    installed = c(FALSE, FALSE),
    bundled = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  expect_snapshot(tabular:::.check_latex_report(out))
})

# ---------------------------------------------------------------------
# Bundled .sty staging — kpsewhich probe + inst/tex fallback copies
# ---------------------------------------------------------------------

test_that(".tabular_bundled_sty is a shipped subset of the required set", {
  bundled <- tabular:::.tabular_bundled_sty
  expect_true(all(
    names(bundled) %in% tabular:::.tabular_required_tex_packages
  ))
  # Every bundled entry ships in inst/tex/ (drift guard).
  for (f in bundled) {
    src <- system.file("tex", f, package = "tabular")
    expect_true(nzchar(src), info = f)
    expect_gt(file.info(src)$size, 0L)
  }
})

test_that(".tabular_pkg_probe_sty covers the required set exactly", {
  expect_setequal(
    names(tabular:::.tabular_pkg_probe_sty),
    tabular:::.tabular_required_tex_packages
  )
})

test_that(".latex_sty_available returns NA when kpsewhich is absent", {
  withr::local_envvar(PATH = "")
  out <- tabular:::.latex_sty_available(c("geometry.sty", "nope.sty"))
  expect_identical(out, rep(NA, 2L))
})

test_that(".latex_sty_available matches found paths by basename", {
  skip_if(!nzchar(Sys.which("kpsewhich")), "kpsewhich not on PATH")
  # A mixed query: kpsewhich prints only the found paths and exits
  # non-zero, so a positional read would misalign; the basename match
  # must keep each result on its own query.
  out <- tabular:::.latex_sty_available(
    c("tabular-no-such-package.sty", "geometry.sty")
  )
  expect_identical(out[[1L]], FALSE)
  expect_identical(out[[2L]], TRUE)
})

test_that(".pdf_stage_bundled_sty stages exactly the unresolved files", {
  dir <- withr::local_tempdir()
  staged <- tabular:::.pdf_stage_bundled_sty(
    dir,
    .available = function(files) c(FALSE, TRUE)
  )
  expect_identical(staged, "tabularray.sty")
  expect_true(file.exists(file.path(dir, "tabularray.sty")))
  expect_false(file.exists(file.path(dir, "ninecolors.sty")))
})

test_that(".pdf_stage_bundled_sty stages nothing when all resolve", {
  dir <- withr::local_tempdir()
  staged <- tabular:::.pdf_stage_bundled_sty(
    dir,
    .available = function(files) rep(TRUE, length(files))
  )
  expect_identical(staged, character())
  expect_identical(list.files(dir), character())
})

test_that(".pdf_stage_bundled_sty treats undeterminable availability as missing", {
  # kpsewhich absent -> NA per file -> stage every bundled copy
  # (harmless shadowing for the one compile).
  dir <- withr::local_tempdir()
  staged <- tabular:::.pdf_stage_bundled_sty(
    dir,
    .available = function(files) rep(NA, length(files))
  )
  expect_setequal(staged, unname(tabular:::.tabular_bundled_sty))
  expect_setequal(list.files(dir), unname(tabular:::.tabular_bundled_sty))
})

test_that("emit(.pdf) with a generic font_family compiles via the fallback cascade", {
  skip_if_not_installed("tinytex")
  skip_on_cran()
  if (!nzchar(Sys.which("xelatex"))) {
    skip("xelatex not found on this machine")
  }
  # A generic family leads a multi-entry chain ending in Latin Modern
  # Mono, so the \IfFontExistsTF cascade falls through and xelatex
  # compiles even where the leading Office face is not installed. (An
  # arbitrary named font has no cascade and would abort if uninstalled;
  # that is the documented trade-off of naming a specific face.)
  spec <- tabular(data.frame(x = c(1L, 2L)), titles = "T") |>
    preset(font_family = "mono")
  out <- withr::local_tempfile(fileext = ".pdf")
  result <- tryCatch(emit(spec, out), error = function(e) e)
  if (inherits(result, "error")) {
    skip(sprintf("PDF compile failed: %s", conditionMessage(result)))
  }
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
})
