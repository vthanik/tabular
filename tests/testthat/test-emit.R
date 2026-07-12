# emit() + backend registry + data_file writer.

# ---------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------

# Register a stub backend that writes a fixed payload to the target
# file. Returns invisibly so the caller can chain with `withr::defer`
# for automatic cleanup.
.register_stub <- function(format, payload = "stub", envir = parent.frame()) {
  # Snapshot any previously-registered backend so we can restore
  # it on test exit. Without this, registering a stub for "md" /
  # "html" wipes the real backend for subsequent tests in the
  # session (test order matters: print tests need a real html
  # backend).
  prior <- tabular:::.tabular_backends[[format]]
  tabular:::.register_backend(format, function(grid, file) {
    writeLines(payload, file)
    invisible(file)
  })
  withr::defer(
    {
      if (is.null(prior)) {
        tabular:::.unregister_backend(format)
      } else {
        tabular:::.register_backend(format, prior)
      }
    },
    envir = envir
  )
  invisible()
}

.simple_spec <- function() {
  tabular(
    data.frame(x = c(1L, 2L, 3L), y = c("a", "b", "c")),
    titles = "T1",
    footnotes = "F1"
  )
}

# ---------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------

test_that("emit() rejects non-spec input", {
  expect_error(
    emit(1L, tempfile(fileext = ".md")),
    class = "tabular_error_input"
  )
})

test_that("emit() rejects malformed file argument", {
  spec <- .simple_spec()
  expect_error(
    emit(spec, c("a", "b")),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, ""),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, NA_character_),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, 1L),
    class = "tabular_error_input"
  )
})

test_that("emit() rejects when parent directory does not exist", {
  spec <- .simple_spec()
  missing <- file.path(tempdir(), "definitely_missing_dir_xyz", "out.md")
  expect_error(
    emit(spec, missing),
    class = "tabular_error_input"
  )
  expect_snapshot(
    error = TRUE,
    emit(spec, missing),
    transform = \(x) {
      sub("Missing directory: .*", "Missing directory: <path>.", x)
    }
  )
})

test_that("emit(create_dir = TRUE) creates missing parent dirs (#E4)", {
  spec <- .simple_spec()
  root <- withr::local_tempdir()
  nested <- file.path(root, "a", "b", "c", "out.md")
  expect_false(dir.exists(dirname(nested)))
  emit(spec, nested, create_dir = TRUE)
  expect_true(dir.exists(dirname(nested)))
  expect_true(file.exists(nested))
})

test_that("emit() rejects non-logical create_dir (#E4)", {
  spec <- .simple_spec()
  f <- tempfile(fileext = ".md")
  expect_error(
    emit(spec, f, create_dir = "yes"),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, create_dir = NA),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, create_dir = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
})

test_that("emit(create_dir = TRUE) errors clearly when the dir cannot be created (#review)", {
  # A regular file sitting where a parent directory must go makes dir.create
  # fail; the suppressed warning must not be swallowed into a cryptic later
  # 'cannot open the connection'. Surface a tabular_error_runtime naming the
  # path instead.
  spec <- .simple_spec()
  blocker <- withr::local_tempfile(fileext = "")
  writeLines("x", blocker)
  nested <- file.path(blocker, "sub", "out.md")
  expect_error(
    emit(spec, nested, create_dir = TRUE),
    class = "tabular_error_runtime"
  )
})

test_that("emit() rejects malformed format override", {
  spec <- .simple_spec()
  f <- tempfile(fileext = ".md")
  expect_error(
    emit(spec, f, format = ""),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, format = c("md", "html")),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, format = NA_character_),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, format = 1L),
    class = "tabular_error_input"
  )
})

test_that("emit() rejects malformed manifest flag", {
  .register_stub("md")
  spec <- .simple_spec()
  f <- tempfile(fileext = ".md")
  expect_error(
    emit(spec, f, manifest = NA),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, manifest = c(TRUE, FALSE)),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, f, manifest = "yes"),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Extension → format dispatch
# ---------------------------------------------------------------------

test_that("emit() infers backend from extension", {
  .register_stub("md", "MD-FROM-EXT")
  spec <- .simple_spec()
  f <- tempfile(fileext = ".md")
  emit(spec, f)
  expect_identical(readLines(f), "MD-FROM-EXT")
})

test_that("emit() accepts .markdown / .htm / .tex aliases", {
  .register_stub("md", "MD-ALIAS")
  .register_stub("html", "HTML-ALIAS")
  .register_stub("latex", "LATEX-ALIAS")

  f_md <- tempfile(fileext = ".markdown")
  f_htm <- tempfile(fileext = ".htm")
  f_tex <- tempfile(fileext = ".tex")

  spec <- .simple_spec()
  emit(spec, f_md)
  emit(spec, f_htm)
  emit(spec, f_tex)

  expect_identical(readLines(f_md), "MD-ALIAS")
  expect_identical(readLines(f_htm), "HTML-ALIAS")
  expect_identical(readLines(f_tex), "LATEX-ALIAS")
})

test_that("emit() format override beats extension", {
  .register_stub("rtf", "RTF-OVERRIDE")
  spec <- .simple_spec()
  f <- tempfile(fileext = ".txt")
  emit(spec, f, format = "rtf")
  expect_identical(readLines(f), "RTF-OVERRIDE")
})

test_that("emit() aborts when extension cannot be resolved", {
  spec <- .simple_spec()
  expect_error(
    emit(spec, tempfile(fileext = "")),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, tempfile(fileext = ".xyzzy")),
    class = "tabular_error_input"
  )
})

test_that("emit() aborts when no backend is registered", {
  # Ensure md is NOT registered for the duration of this test.
  # Snapshot the real backend so we can restore it after the test.
  real_md <- tabular:::.tabular_backends[["md"]]
  withr::defer(
    if (!is.null(real_md)) {
      tabular:::.register_backend("md", real_md)
    }
  )
  tabular:::.unregister_backend("md")
  spec <- .simple_spec()
  expect_error(
    emit(spec, tempfile(fileext = ".md")),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# Backend registry self-checks
# ---------------------------------------------------------------------

test_that(".register_backend() rejects bad arguments", {
  expect_error(tabular:::.register_backend(c("a", "b"), function(...) NULL))
  expect_error(tabular:::.register_backend("md", "not a function"))
  expect_error(tabular:::.register_backend(NA_character_, function(...) NULL))
})

test_that(".unregister_backend() is a no-op on missing key", {
  tabular:::.unregister_backend("nonexistent_xyzzy")
  expect_false(tabular:::.has_backend("nonexistent_xyzzy"))
})

test_that(".resolve_backend() surfaces registered backends in errors", {
  .register_stub("html", "HTML")
  # Pass an explicit `format` value that is not in the registry;
  # resolution should surface a tabular_error_input listing the
  # currently-registered backends.
  spec <- .simple_spec()
  err <- tryCatch(
    emit(spec, tempfile(fileext = ".tex"), format = "_unregistered"),
    tabular_error_input = function(e) e
  )
  expect_s3_class(err, "tabular_error_input")
  expect_match(conditionMessage(err), "html", fixed = TRUE)
})

test_that(".registered_backend_formats() returns sorted character vector", {
  tabular:::.register_backend("z_test", function(...) NULL)
  withr::defer(tabular:::.unregister_backend("z_test"))
  tabular:::.register_backend("a_test", function(...) NULL)
  withr::defer(tabular:::.unregister_backend("a_test"))
  fmts <- tabular:::.registered_backend_formats()
  expect_true(all(c("a_test", "z_test") %in% fmts))
  expect_identical(sort(fmts), fmts)
})

# ---------------------------------------------------------------------
# data_file writer
# ---------------------------------------------------------------------

test_that("emit() writes csv via explicit path", {
  .register_stub("md")
  spec <- .simple_spec()
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".csv")
  emit(spec, render_path, data_file = qc_path)
  expect_true(file.exists(qc_path))
  df <- read.csv(qc_path, stringsAsFactors = FALSE)
  expect_identical(names(df), c("x", "y"))
  expect_identical(nrow(df), 3L)
})

test_that("emit() writes tsv via path with .tsv extension", {
  .register_stub("md")
  spec <- .simple_spec()
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".tsv")
  emit(spec, render_path, data_file = qc_path)
  contents <- readLines(qc_path)
  expect_true(any(grepl("\t", contents)))
})

test_that("emit() writes rds via .rds extension", {
  .register_stub("md")
  spec <- .simple_spec()
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".rds")
  emit(spec, render_path, data_file = qc_path)
  df <- readRDS(qc_path)
  expect_s3_class(df, "data.frame")
  expect_identical(names(df), c("x", "y"))
})

test_that("emit() resolves data_file lambda against render path", {
  .register_stub("md")
  spec <- .simple_spec()
  render_path <- tempfile(fileext = ".md")
  emit(
    spec,
    render_path,
    data_file = function(f) {
      paste0(tools::file_path_sans_ext(f), "_qc.csv")
    }
  )
  expected_qc <- paste0(tools::file_path_sans_ext(render_path), "_qc.csv")
  expect_true(file.exists(expected_qc))
})

test_that("emit() aborts when data_file lambda raises", {
  .register_stub("md")
  spec <- .simple_spec()
  expect_error(
    emit(
      spec,
      tempfile(fileext = ".md"),
      data_file = function(f) stop("boom")
    ),
    class = "tabular_error_runtime"
  )
})

test_that("emit() aborts on unsupported data_file extension", {
  .register_stub("md")
  spec <- .simple_spec()
  expect_error(
    emit(
      spec,
      tempfile(fileext = ".md"),
      data_file = tempfile(fileext = ".parquet")
    ),
    class = "tabular_error_input"
  )
})

test_that("emit() aborts when data_file value is malformed", {
  .register_stub("md")
  spec <- .simple_spec()
  expect_error(
    emit(spec, tempfile(fileext = ".md"), data_file = c("a", "b")),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, tempfile(fileext = ".md"), data_file = ""),
    class = "tabular_error_input"
  )
  expect_error(
    emit(spec, tempfile(fileext = ".md"), data_file = NA_character_),
    class = "tabular_error_input"
  )
})

test_that("emit() aborts when data_file parent dir does not exist", {
  .register_stub("md")
  spec <- .simple_spec()
  missing <- file.path(tempdir(), "qc_dir_missing_xyz", "qc.csv")
  expect_error(
    emit(spec, tempfile(fileext = ".md"), data_file = missing),
    class = "tabular_error_input"
  )
})

test_that("emit() data_file carries raw values, never column-mode suppression", {
  # The data_file QC artefact must never reflect display = "collapse"
  # repeat-suppression. The display blanks the repeated
  # group value for layout reasons; the QC reader still wants the
  # source value on every row.
  .register_stub("md")
  df <- data.frame(
    grp = c("A", "A", "B", "B"),
    v = c("1", "2", "3", "4"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(
        label = "Group"
      ),
      v = col_spec(label = "Value")
    ) |>
    group_rows(by = "grp", display = "collapse")
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".csv")
  emit(spec, render_path, data_file = qc_path)
  qc <- utils::read.csv(qc_path, stringsAsFactors = FALSE)

  # Every QC row carries its source group value, no blank repeats.
  expect_equal(qc$grp, c("A", "A", "B", "B"))
  expect_equal(nrow(qc), 4L)
})

test_that("emit() data_file carries raw values under group_skip + section", {
  # Default section mode injects synthesised section headers AND
  # blank-row separators. Neither belongs in the QC artefact, which
  # must mirror source rows one-for-one.
  .register_stub("md")
  df <- data.frame(
    grp = c("A", "A", "B", "B", "C", "C"),
    v = c("1", "2", "3", "4", "5", "6"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(label = "Group"),
      v = col_spec(label = "Value")
    ) |>
    group_rows(by = "grp")
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".csv")
  emit(spec, render_path, data_file = qc_path)
  qc <- utils::read.csv(qc_path, stringsAsFactors = FALSE)

  expect_equal(nrow(qc), 6L)
  expect_equal(qc$grp, c("A", "A", "B", "B", "C", "C"))
  expect_equal(as.character(qc$v), c("1", "2", "3", "4", "5", "6"))
  expect_false(anyNA(qc$grp))
  expect_false(any(qc$grp == ""))
})

test_that("emit() data_file handles section group injection without dim mismatch", {
  # Regression: before this fix, .data_file_frame wrote the
  # synthesised section-header + blank rows from
  # engine_group_display into the QC frame using page$row_indices,
  # which only counts SOURCE data rows. Mismatched dims aborted
  # the call with "number of items to replace is not a multiple
  # of replacement length".
  .register_stub("md")
  df <- data.frame(
    grp = c("A", "A", "B", "B"),
    v = c("1", "2", "3", "4"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(label = "Group"),
      v = col_spec(label = "Value")
    ) |>
    group_rows(by = "grp")
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".csv")
  expect_no_error(emit(spec, render_path, data_file = qc_path))
  expect_true(file.exists(qc_path))

  qc <- utils::read.csv(qc_path, stringsAsFactors = FALSE)
  # One QC row per SOURCE data row -- never include synthesised
  # header / blank rows in the data_file artefact.
  expect_equal(nrow(qc), 4L)
})

test_that("emit() data_file is empty df frame on zero-row data", {
  .register_stub("md")
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  render_path <- tempfile(fileext = ".md")
  qc_path <- tempfile(fileext = ".csv")
  emit(spec, render_path, data_file = qc_path)
  df <- read.csv(qc_path, stringsAsFactors = FALSE)
  expect_identical(nrow(df), 0L)
  expect_identical(names(df), c("x", "y"))
})

# ---------------------------------------------------------------------
# Return value
# ---------------------------------------------------------------------

test_that("emit() returns the file path invisibly", {
  .register_stub("md")
  spec <- .simple_spec()
  f <- tempfile(fileext = ".md")
  ret <- emit(spec, f)
  expect_identical(ret, f)
})
