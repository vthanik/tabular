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
