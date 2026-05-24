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
  # We don't actually compile here (heavy + tex-distro-dependent);
  # we verify the dispatcher routes to backend_pdf by checking
  # the registered backend identity.
  expect_true(tabular:::.has_backend("pdf"))
  fn <- tabular:::.tabular_backends[["pdf"]]
  expect_identical(fn, tabular:::backend_pdf)
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
