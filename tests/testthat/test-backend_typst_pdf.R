# backend_typst_pdf() — PDF via the typst compiler, plus check_typst().
#
# The compile path is tested by injecting `.compile` (a fake) rather
# than mocking; discovery / version / fonts helpers take injected seams
# (`local_mocked_bindings` does not engage under covr instrumentation).
# Real-compile tests are gated on a discoverable binary AND
# skip_on_cran() (CRAN machines ship Quarto — the tinytex lesson).

mk_typst_grid <- function() {
  spec <- tabular(
    data.frame(x = c(1L, 2L), y = c("a", "b")),
    titles = "T",
    footnotes = "F"
  )
  tabular:::.resolve_spec_to_grid(spec, format = "typst")
}

# ---------------------------------------------------------------------
# Registry wiring
# ---------------------------------------------------------------------

test_that("typst_pdf backend is registered at package load", {
  expect_true(tabular:::.has_backend("typst_pdf"))
})

# ---------------------------------------------------------------------
# Binary discovery
# ---------------------------------------------------------------------

test_that(".typst_bin prefers a standalone typst over quarto", {
  fake_which <- function(x) {
    stats::setNames(
      ifelse(x == "typst", "/opt/typst/typst", "/usr/bin/quarto"),
      x
    )
  }
  bin <- tabular:::.typst_bin(.which = fake_which)
  expect_identical(bin$cmd, "/opt/typst/typst")
  expect_identical(bin$args, character())
})

test_that(".typst_bin falls back to quarto typst", {
  fake_which <- function(x) {
    stats::setNames(ifelse(x == "quarto", "/usr/bin/quarto", ""), x)
  }
  bin <- tabular:::.typst_bin(.which = fake_which)
  expect_identical(bin$cmd, "/usr/bin/quarto")
  expect_identical(bin$args, "typst")
})

test_that(".typst_bin returns NULL when neither binary exists", {
  fake_which <- function(x) stats::setNames(rep("", length(x)), x)
  expect_null(tabular:::.typst_bin(.which = fake_which))
})

# ---------------------------------------------------------------------
# Version + fonts parsing
# ---------------------------------------------------------------------

test_that(".typst_version parses the banner and handles junk", {
  expect_identical(
    tabular:::.typst_version(.version_line = "typst 0.14.2 (b33de9de)"),
    numeric_version("0.14.2")
  )
  expect_identical(
    tabular:::.typst_version(.version_line = "typst 0.11.0"),
    numeric_version("0.11.0")
  )
  expect_identical(tabular:::.typst_version(.version_line = "gibberish"), NA)
  expect_identical(
    tabular:::.typst_version(.version_line = NA_character_),
    NA
  )
  expect_identical(tabular:::.typst_version(bin = NULL), NA)
})

test_that(".typst_fonts trims and drops empty lines; NULL without a binary", {
  expect_identical(
    tabular:::.typst_fonts(
      .lines = c("Courier New", "  DejaVu Sans Mono ", "")
    ),
    c("Courier New", "DejaVu Sans Mono")
  )
  expect_null(tabular:::.typst_fonts(bin = NULL))
})

# ---------------------------------------------------------------------
# Compile path (injected .compile seam)
# ---------------------------------------------------------------------

test_that("backend_typst_pdf compiles via the injected seam", {
  skip_if(is.null(tabular:::.typst_bin()))
  grid <- mk_typst_grid()
  out <- withr::local_tempfile(fileext = ".pdf")
  called <- NULL
  fake_compile <- function(typ_file, file) {
    called <<- typ_file
    expect_true(file.exists(typ_file))
    writeLines("%PDF-fake", file)
    character()
  }
  result <- tabular:::backend_typst_pdf(grid, out, .compile = fake_compile)
  expect_identical(result, out)
  expect_true(file.exists(out))
  expect_match(called, "tabular\\.typ$")
})

test_that("backend_typst_pdf surfaces unknown-font compiler notes loudly", {
  skip_if(is.null(tabular:::.typst_bin()))
  grid <- mk_typst_grid()
  out <- withr::local_tempfile(fileext = ".pdf")
  fake_compile <- function(typ_file, file) {
    writeLines("%PDF-fake", file)
    c(
      "warning: unknown font family: liberation mono",
      "some context line",
      "warning: unknown font family: courier new"
    )
  }
  expect_warning(
    tabular:::backend_typst_pdf(grid, out, .compile = fake_compile),
    class = "tabular_warning_backend"
  )
})

test_that("a failing compile aborts with tabular_error_backend", {
  skip_if(is.null(tabular:::.typst_bin()))
  grid <- mk_typst_grid()
  out <- withr::local_tempfile(fileext = ".pdf")
  fake_compile <- function(typ_file, file) {
    stop("error: expected semicolon or line break")
  }
  expect_error(
    tabular:::backend_typst_pdf(grid, out, .compile = fake_compile),
    class = "tabular_error_backend"
  )
})

test_that("no binary at all aborts with the install remedies", {
  withr::local_envvar(PATH = "")
  grid <- mk_typst_grid()
  out <- withr::local_tempfile(fileext = ".pdf")
  expect_error(
    tabular:::backend_typst_pdf(grid, out),
    class = "tabular_error_backend"
  )
  expect_snapshot(
    error = TRUE,
    tabular:::backend_typst_pdf(grid, out)
  )
})

test_that(".typst_warn_unknown_fonts is silent on clean output", {
  expect_no_warning(tabular:::.typst_warn_unknown_fonts(character()))
  expect_no_warning(tabular:::.typst_warn_unknown_fonts(NULL))
  expect_no_warning(tabular:::.typst_warn_unknown_fonts("all fine"))
})

test_that(".typst_compile_abort leads with the version floor when too old", {
  err <- simpleError("error: unexpected argument")
  expect_snapshot(
    error = TRUE,
    tabular:::.typst_compile_abort(
      err,
      .version = numeric_version("0.10.0")
    )
  )
  expect_error(
    tabular:::.typst_compile_abort(err, .version = numeric_version("0.10.0")),
    class = "tabular_error_backend"
  )
})

test_that(".typst_compile_abort surfaces the compiler message otherwise", {
  err <- simpleError("error: expected semicolon or line break")
  expect_snapshot(
    error = TRUE,
    tabular:::.typst_compile_abort(err, .version = numeric_version("0.14.2"))
  )
})

# ---------------------------------------------------------------------
# Real compile (binary-gated, never on CRAN)
# ---------------------------------------------------------------------

test_that("end-to-end typst compile produces a real PDF", {
  skip_on_cran()
  skip_if(is.null(tabular:::.typst_bin()), "no typst binary")
  grid <- mk_typst_grid()
  out <- withr::local_tempfile(fileext = ".pdf")
  suppressWarnings(tabular:::backend_typst_pdf(grid, out))
  expect_true(file.exists(out))
  expect_identical(readBin(out, "raw", 4L), charToRaw("%PDF"))
})

# ---------------------------------------------------------------------
# check_typst()
# ---------------------------------------------------------------------

test_that("check_typst validates quiet", {
  expect_error(check_typst(quiet = "yes"), class = "tabular_error_input")
  expect_snapshot(error = TRUE, check_typst(quiet = NA))
})

test_that("check_typst returns the font-chain frame with attributes", {
  skip_if(is.null(tabular:::.typst_bin()), "no typst binary")
  out <- check_typst(quiet = TRUE)
  expect_s3_class(out, "data.frame")
  expect_named(out, c("font", "available"))
  expect_true(nrow(out) >= 1L)
  expect_true(
    identical(attr(out, "typst_version"), NA) ||
      inherits(attr(out, "typst_version"), "numeric_version")
  )
  expect_type(attr(out, "typst_command"), "character")
})

test_that("check_typst handles a machine with no binary", {
  withr::local_envvar(PATH = "")
  out <- check_typst(quiet = TRUE)
  expect_true(all(is.na(out$available)))
  expect_identical(attr(out, "typst_command"), NA_character_)
  expect_identical(attr(out, "typst_version"), NA)
})

test_that(".check_typst_report prints every status branch", {
  frame <- data.frame(
    font = c("Courier New", "Liberation Mono", "DejaVu Sans Mono"),
    available = c(TRUE, FALSE, NA),
    stringsAsFactors = FALSE
  )
  expect_snapshot(
    tabular:::.check_typst_report(
      frame,
      version = numeric_version("0.14.2"),
      command = "quarto typst"
    )
  )
  expect_snapshot(
    tabular:::.check_typst_report(
      frame,
      version = NA,
      command = NA_character_
    )
  )
  expect_snapshot(
    tabular:::.check_typst_report(
      frame,
      version = numeric_version("0.10.0"),
      command = "typst"
    )
  )
  all_ok <- data.frame(
    font = "Courier New",
    available = TRUE,
    stringsAsFactors = FALSE
  )
  expect_snapshot(
    tabular:::.check_typst_report(
      all_ok,
      version = numeric_version("0.14.2"),
      command = "typst"
    )
  )
})

test_that(".typst_fonts reads quarto's stderr-relayed list (regression)", {
  # `quarto typst fonts` relays the font list on STDERR (the standalone
  # binary prints to stdout); capturing stdout alone reported every
  # family as missing, including the faces embedded in typst itself.
  bin <- tabular:::.typst_bin()
  skip_if(is.null(bin), "no typst binary")
  fonts <- tabular:::.typst_fonts(bin)
  expect_true(length(fonts) > 0L)
  # The embedded faces are always visible, whichever binary answered.
  expect_true(any(grepl("DejaVu Sans Mono", fonts, fixed = TRUE)))
})
