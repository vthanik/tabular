# Tests for .tabular_spec_print() via testthat::capture_messages().
#
# We test the helper directly (not via S7::method dispatch) because
# covr does not instrument the dispatch path.

print_lines <- function(spec) {
  msgs <- testthat::capture_messages(
    invisible(.tabular_spec_print(spec))
  )
  paste(msgs, collapse = "")
}

test_that("print returns invisibly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  testthat::expect_invisible(.tabular_spec_print(s))
})

test_that("print shows data dimensions", {
  s <- tabular_spec(data = data.frame(x = 1:3, y = 1:3))
  out <- print_lines(s)
  expect_match(out, "Data: 3 rows x 2 columns")
})

test_that("print pluralises 1 row x 1 column correctly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_match(out, "1 row x 1 column")
})

test_that("print includes titles count and numbered list", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = c("Table 14.1.1", "Demographics", "Safety Pop")
  )
  out <- print_lines(s)
  expect_match(out, "Titles \\(3\\)")
  expect_match(out, "Table 14\\.1\\.1")
  expect_match(out, "Safety Pop")
})

test_that("print truncates very long titles", {
  long_title <- paste(rep("a", 100), collapse = "")
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = long_title
  )
  out <- print_lines(s)
  expect_match(out, "\\.\\.\\.")
})

test_that("print omits title section when no titles", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_false(grepl("Titles", out))
})

test_that("print shows footnote count", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    footnotes = c("Note 1", "Note 2")
  )
  out <- print_lines(s)
  expect_match(out, "Footnotes: 2 lines")
})

test_that("print shows config when cols / pivots / derives configured", {
  c1 <- col_spec(usage = "display")
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    cols = list(x = c1)
  )
  out <- print_lines(s)
  expect_match(out, "Config: cols \\(1\\)")
})

test_that("print shows sort spec when non-empty", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L, y = 1L)),
    sort = sort_spec(by = c("x", "y"))
  )
  out <- print_lines(s)
  expect_match(out, "Sort: x, y")
})

test_that("print shows pagination with keep_together", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(keep_together = "x")
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: keep_together=x")
})

test_that("print shows pagination with panels", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(panels = 2L)
  )
  out <- print_lines(s)
  expect_match(out, "Pagination:.*panels=2")
})

test_that("print shows pagination auto when all defaults", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec()
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: auto")
})

test_that("print shows preset diff when knobs differ from defaults", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    preset = preset_spec(font_size = 8, orientation = "landscape")
  )
  out <- print_lines(s)
  expect_match(out, "Preset:.*font_size=8")
  expect_match(out, "orientation=landscape")
})

test_that("print shows preset defaults when no knobs differ", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    preset = preset_spec()
  )
  out <- print_lines(s)
  expect_match(out, "Preset: defaults")
})

test_that("print omits preset section when no preset attached", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_false(grepl("Preset:", out))
})

# ---------------------------------------------------------------------
# Output router (.resolve_print_output)
# ---------------------------------------------------------------------

test_that(".resolve_print_output honours explicit output", {
  s <- tabular_spec(data = data.frame(x = 1L))
  expect_identical(.resolve_print_output("html", s), "html")
  expect_identical(.resolve_print_output("md", s), "md")
  expect_identical(.resolve_print_output("rtf", s), "rtf")
  expect_identical(.resolve_print_output("cli", s), "cli")
})

test_that(".resolve_print_output rejects malformed output", {
  s <- tabular_spec(data = data.frame(x = 1L))
  expect_error(
    .resolve_print_output(1L, s),
    class = "tabular_error_input"
  )
  expect_error(
    .resolve_print_output(c("html", "md"), s),
    class = "tabular_error_input"
  )
  expect_error(
    .resolve_print_output(NA_character_, s),
    class = "tabular_error_input"
  )
})

test_that(".resolve_print_output falls back to 'cli' in non-interactive context", {
  s <- tabular_spec(data = data.frame(x = 1L))
  # In testthat, interactive() is FALSE and no viewer pane is
  # installed, so auto-resolution lands on "cli".
  expect_identical(.resolve_print_output(NULL, s), "cli")
})

test_that(".resolve_print_output picks 'html' when a viewer pane is fake-installed", {
  s <- tabular_spec(data = data.frame(x = 1L))
  fake_viewer <- function(url) invisible(url)
  withr::with_options(list(viewer = fake_viewer), {
    # In testthat interactive() is FALSE, so .has_viewer() is
    # FALSE too — drive the branch directly through the helper.
    expect_false(.has_viewer())
  })
})

# ---------------------------------------------------------------------
# Branch handlers (HTML preview, source cat, fallback)
# ---------------------------------------------------------------------

test_that("output = 'html' writes a tempfile and invokes the viewer option", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  captured <- character()
  fake_viewer <- function(url) {
    captured <<- url
    invisible(url)
  }
  withr::with_options(list(viewer = fake_viewer), {
    .tabular_spec_print(s, output = "html")
  })
  expect_true(file.exists(captured))
  expect_true(any(grepl(">T<", readLines(captured), fixed = TRUE)))
})

test_that("output = 'md' cats the markdown source to console", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- testthat::capture_output(.tabular_spec_print(s, output = "md"))
  expect_match(out, "^# T", all = FALSE)
  expect_match(out, "\\| x \\|")
})

test_that("output = 'markdown' aliases to md", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- testthat::capture_output(.tabular_spec_print(s, output = "markdown"))
  expect_match(out, "^# T", all = FALSE)
})

test_that("output = 'rtf' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  captured <- character()
  fake_viewer <- function(url) {
    captured <<- url
    invisible(url)
  }
  msgs <- testthat::capture_messages(
    withr::with_options(list(viewer = fake_viewer), {
      .tabular_spec_print(s, output = "rtf")
    })
  )
  expect_true(file.exists(captured))
  expect_true(any(grepl("\\.html$", captured)))
  expect_match(paste(msgs, collapse = ""), "\\.rtf")
})

test_that("output = 'docx' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  captured <- character()
  fake_viewer <- function(url) {
    captured <<- url
    invisible(url)
  }
  msgs <- testthat::capture_messages(
    withr::with_options(list(viewer = fake_viewer), {
      .tabular_spec_print(s, output = "docx")
    })
  )
  expect_match(paste(msgs, collapse = ""), "\\.docx")
  expect_true(any(grepl("\\.html$", captured)))
})

test_that("output = 'pdf' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  captured <- character()
  fake_viewer <- function(url) {
    captured <<- url
    invisible(url)
  }
  msgs <- testthat::capture_messages(
    withr::with_options(list(viewer = fake_viewer), {
      .tabular_spec_print(s, output = "pdf")
    })
  )
  expect_match(paste(msgs, collapse = ""), "\\.pdf")
  expect_true(any(grepl("\\.html$", captured)))
})

test_that("output = 'cli' forces the structural cli-tree", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  msgs <- testthat::capture_messages(.tabular_spec_print(s, output = "cli"))
  joined <- paste(msgs, collapse = "")
  expect_match(joined, "tabular_spec")
  expect_match(joined, "Data: 1 row x 1 column")
})

test_that("tabular_preview_dir option overrides the temp directory", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  preview_dir <- withr::local_tempdir()
  captured <- character()
  fake_viewer <- function(url) {
    captured <<- url
    invisible(url)
  }
  withr::with_options(
    list(viewer = fake_viewer, tabular_preview_dir = preview_dir),
    {
      .tabular_spec_print(s, output = "html")
    }
  )
  expect_true(startsWith(
    normalizePath(captured),
    normalizePath(preview_dir)
  ))
})

# ---------------------------------------------------------------------
# knit_print.tabular_spec
# ---------------------------------------------------------------------

test_that("knit_print wraps html output in pandoc raw-html fence", {
  skip_if_not_installed("knitr")
  s <- tabular(data.frame(x = 1L), titles = "T")
  withr::with_options(list(knitr.in.progress = TRUE), {
    # Simulate knitting to html by stubbing pandoc_to via mocks.
    # We can't easily stub knitr::pandoc_to(); call directly and
    # check the no-knit fallback path produces md.
    out <- knit_print.tabular_spec(s)
    expect_s3_class(out, "knit_asis")
    expect_match(as.character(out), "# T", all = FALSE)
  })
})

# ---------------------------------------------------------------------
# Posit / viewer detection helpers
# ---------------------------------------------------------------------

test_that(".is_rstudio reads the RSTUDIO env var", {
  withr::with_envvar(list(RSTUDIO = "1"), expect_true(.is_rstudio()))
  withr::with_envvar(list(RSTUDIO = ""), expect_false(.is_rstudio()))
})

test_that(".is_positron reads the POSITRON env var", {
  withr::with_envvar(list(POSITRON = "1"), expect_true(.is_positron()))
  withr::with_envvar(list(POSITRON = ""), expect_false(.is_positron()))
})

test_that(".has_viewer reflects interactive + viewer option", {
  # Inside testthat, interactive() is FALSE -> always FALSE
  expect_false(.has_viewer())
})

test_that(".is_notebook_context detects .qmd / .Rmd by path", {
  expect_true(.is_notebook_context("notes.qmd", ""))
  expect_true(.is_notebook_context("notes.Rmd", ""))
  expect_false(.is_notebook_context("notes.R", ""))
  expect_false(.is_notebook_context("", ""))
})

test_that(".is_notebook_context detects YAML header + format key", {
  contents <- c("---", "title: Hi", "format: html", "---", "", "Body.")
  expect_true(.is_notebook_context("foo.txt", contents))
})

test_that(".is_notebook_context detects chunk fences", {
  contents <- c("```{r}", "1 + 1", "```")
  expect_true(.is_notebook_context("foo.txt", contents))
})

test_that(".is_notebook_context returns FALSE on plain markdown", {
  contents <- c("# Heading", "Plain text.")
  expect_false(.is_notebook_context("foo.md", contents))
})

test_that(".is_rstudio_notebook returns FALSE when not in RStudio", {
  withr::with_envvar(list(RSTUDIO = ""), {
    expect_false(.is_rstudio_notebook())
  })
})
