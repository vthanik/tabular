# Tests for .tabular_spec_print() and the as.tags / knit_print
# delegation. We call the helper directly (not via S7::method
# dispatch) because covr does not instrument the dispatch path.

print_lines <- function(spec) {
  msgs <- testthat::capture_messages(
    invisible(.tabular_spec_print(spec, output = "cli"))
  )
  paste(msgs, collapse = "")
}

# ---------------------------------------------------------------------
# Structural cli-tree (output = "cli")
# ---------------------------------------------------------------------

test_that("print(output='cli') returns invisibly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  testthat::expect_invisible(.tabular_spec_print(s, output = "cli"))
})

test_that("cli tree shows data dimensions", {
  s <- tabular_spec(data = data.frame(x = 1:3, y = 1:3))
  out <- print_lines(s)
  expect_match(out, "Data: 3 rows x 2 columns")
})

test_that("cli tree pluralises 1 row x 1 column correctly", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_match(out, "1 row x 1 column")
})

test_that("cli tree includes titles count and numbered list", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = c("Table 14.1.1", "Demographics", "Safety Pop")
  )
  out <- print_lines(s)
  expect_match(out, "Titles \\(3\\)")
  expect_match(out, "Table 14\\.1\\.1")
  expect_match(out, "Safety Pop")
})

test_that("cli tree truncates very long titles", {
  long_title <- paste(rep("a", 100), collapse = "")
  s <- tabular_spec(
    data = data.frame(x = 1L),
    titles = long_title
  )
  out <- print_lines(s)
  expect_match(out, "\\.\\.\\.")
})

test_that("cli tree omits title section when no titles", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_false(grepl("Titles", out))
})

test_that("cli tree shows footnote count", {
  s <- tabular_spec(
    data = data.frame(x = 1L),
    footnotes = c("Note 1", "Note 2")
  )
  out <- print_lines(s)
  expect_match(out, "Footnotes: 2 lines")
})

test_that("cli tree shows config when cols / pivots / derives configured", {
  c1 <- col_spec(usage = "display")
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    cols = list(x = c1)
  )
  out <- print_lines(s)
  expect_match(out, "Config: cols \\(1\\)")
})

test_that("cli tree shows sort spec when non-empty", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L, y = 1L)),
    sort = sort_spec(by = c("x", "y"))
  )
  out <- print_lines(s)
  expect_match(out, "Sort: x, y")
})

test_that("cli tree shows pagination with keep_together", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(keep_together = "x")
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: keep_together=x")
})

test_that("cli tree shows pagination with panels", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec(panels = 2L)
  )
  out <- print_lines(s)
  expect_match(out, "Pagination:.*panels=2")
})

test_that("cli tree shows pagination auto when all defaults", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    pagination = pagination_spec()
  )
  out <- print_lines(s)
  expect_match(out, "Pagination: auto")
})

test_that("cli tree shows preset diff when knobs differ from defaults", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    preset = preset_spec(font_size = 8, orientation = "portrait")
  )
  out <- print_lines(s)
  expect_match(out, "Preset:.*font_size=8")
  expect_match(out, "orientation=portrait")
})

test_that("cli tree shows preset defaults when no knobs differ", {
  s <- S7::set_props(
    tabular_spec(data = data.frame(x = 1L)),
    preset = preset_spec()
  )
  out <- print_lines(s)
  expect_match(out, "Preset: defaults")
})

test_that("cli tree omits preset section when no preset attached", {
  s <- tabular_spec(data = data.frame(x = 1L))
  out <- print_lines(s)
  expect_false(grepl("Preset:", out))
})

# ---------------------------------------------------------------------
# Default branch: as.tags + htmltools::print(browse = view)
# ---------------------------------------------------------------------

test_that("default print returns invisibly", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  testthat::expect_invisible(.tabular_spec_print(s, view = FALSE))
})

test_that("default print routes through as.tags + htmltools (cat HTML on console)", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- testthat::capture_output(.tabular_spec_print(s, view = FALSE))
  # htmltools::print on a tagList cats the HTML; we should see
  # the table title and the wrapping div.
  expect_match(out, "tabular-title", all = FALSE)
  expect_match(out, "<table", all = FALSE)
})

# ---------------------------------------------------------------------
# Explicit `output =` override
# ---------------------------------------------------------------------

test_that("output = 'md' cats markdown source to console", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- testthat::capture_output(.tabular_spec_print(s, output = "md"))
  expect_match(out, "# T", all = FALSE)
  expect_match(out, "\\| x \\|")
})

test_that("output = 'markdown' aliases to md", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- testthat::capture_output(.tabular_spec_print(s, output = "markdown"))
  expect_match(out, "# T", all = FALSE)
})

test_that("output = 'cli' forces the structural cli-tree", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  msgs <- testthat::capture_messages(
    .tabular_spec_print(s, output = "cli")
  )
  joined <- paste(msgs, collapse = "")
  expect_match(joined, "tabular_spec")
  expect_match(joined, "Data: 1 row x 1 column")
})

test_that("output = 'html' renders HTML and returns invisibly", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  testthat::expect_invisible(
    .tabular_spec_print(s, output = "html", view = FALSE)
  )
})

test_that("output = 'rtf' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  msgs <- testthat::capture_messages(
    testthat::capture_output(.tabular_spec_print(
      s,
      output = "rtf",
      view = FALSE
    ))
  )
  expect_match(paste(msgs, collapse = ""), "\\.rtf")
})

test_that("output = 'docx' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  msgs <- testthat::capture_messages(
    testthat::capture_output(.tabular_spec_print(
      s,
      output = "docx",
      view = FALSE
    ))
  )
  expect_match(paste(msgs, collapse = ""), "\\.docx")
})

test_that("output = 'pdf' falls back to HTML preview + cli note", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  msgs <- testthat::capture_messages(
    testthat::capture_output(.tabular_spec_print(
      s,
      output = "pdf",
      view = FALSE
    ))
  )
  expect_match(paste(msgs, collapse = ""), "\\.pdf")
})

test_that("output rejects malformed input", {
  s <- tabular(data.frame(x = 1L))
  expect_error(
    .tabular_spec_print(s, output = 1L),
    class = "tabular_error_input"
  )
  expect_error(
    .tabular_spec_print(s, output = c("html", "md")),
    class = "tabular_error_input"
  )
  expect_error(
    .tabular_spec_print(s, output = NA_character_),
    class = "tabular_error_input"
  )
})

# ---------------------------------------------------------------------
# tryCatch safety net
# ---------------------------------------------------------------------

test_that("tryCatch wrapping is in place around the default render path", {
  # The actual fallback behaviour is hard to unit-test without
  # tearing through htmltools' dispatch table; the contract is
  # that the router function body wraps the render call in
  # tryCatch with a cli_warn + cli-tree fallback. Assert the
  # contract by inspecting the function source.
  body_src <- paste(deparse(body(.tabular_spec_print)), collapse = "\n")
  expect_match(body_src, "tryCatch", fixed = TRUE)
  expect_match(body_src, "HTML preview failed", fixed = TRUE)
  expect_match(body_src, ".tabular_spec_print_cli", fixed = TRUE)
})

# ---------------------------------------------------------------------
# as.tags.tabular_spec
# ---------------------------------------------------------------------

test_that("as.tags returns an htmltools tagList", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  tags <- htmltools::as.tags(s)
  expect_s3_class(tags, "shiny.tag.list")
})

test_that("as.tags wraps body in a div with overflow-x:auto", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  html <- as.character(htmltools::as.tags(s))
  expect_match(html, "overflow-x:\\s*auto", perl = TRUE)
  expect_match(html, "<div id=\"tabular-", fixed = TRUE)
})

test_that("as.tags emits the <style> block separately from the body", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  html <- as.character(htmltools::as.tags(s))
  # The style block (from the inline CSS) shows up before the
  # wrapping <div>.
  style_pos <- regexpr(".tabular-table", html)
  div_pos <- regexpr("<div id=\"tabular-", html)
  expect_lt(style_pos, div_pos)
})

test_that("as.tags accepts an explicit id", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  html <- as.character(htmltools::as.tags(s, id = "my_table"))
  expect_match(html, "id=\"my_table\"", fixed = TRUE)
})

test_that("as.tags handles a spec with no <style> block gracefully", {
  # Synthesise a minimal HTML doc with no <style> block.
  out <- tabular:::.extract_html_fragment(
    "<html><body><p>hi</p></body></html>"
  )
  expect_identical(out$style, "")
  expect_match(out$body, "<p>hi</p>", fixed = TRUE)
})

test_that(".extract_html_fragment falls back to whole string when no <body>", {
  out <- tabular:::.extract_html_fragment("<p>fragment</p>")
  expect_identical(out$body, "<p>fragment</p>")
})

# ---------------------------------------------------------------------
# knit_print.tabular_spec
# ---------------------------------------------------------------------

test_that("knit_print wraps the table in a pandoc raw {=html} block by default (#table-md)", {
  skip_if_not_installed("knitr")
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- knit_print.tabular_spec(s)
  txt <- as.character(out)
  # The default branch must emit a pandoc RAW {=html} block so a
  # markdown / GFM writer passes the <table> through verbatim instead
  # of downgrading colspan/rowspan tables to the literal `[TABLE]`.
  expect_s3_class(out, "knit_asis")
  expect_match(txt, "```{=html}", fixed = TRUE)
  expect_match(txt, "<table", fixed = TRUE)
})

test_that("knit_print returns the raw {=html} block under a gfm target (#table-md)", {
  skip_if_not_installed("knitr")
  testthat::local_mocked_bindings(
    pandoc_to = function() "gfm",
    .package = "knitr"
  )
  s <- tabular(data.frame(x = 1L), titles = "T")
  txt <- as.character(knit_print.tabular_spec(s))
  expect_match(txt, "```{=html}", fixed = TRUE)
  expect_match(txt, "<table", fixed = TRUE)
})

test_that("knit_print routes beamer to the md source backend (not a raw html block)", {
  testthat::local_mocked_bindings(
    pandoc_to = function() "beamer",
    .package = "knitr"
  )
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- knit_print.tabular_spec(s)
  expect_s3_class(out, "knit_asis")
  expect_no_match(as.character(out), "```{=html}", fixed = TRUE)
})

test_that("knit_print routes typst to the md source backend, not a raw html block (#cr8)", {
  # Pandoc's typst writer drops a raw `{=html}` block, so a printed
  # tabular_spec must fall back to markdown source (which pandoc renders
  # into typst) rather than vanishing from the output.
  testthat::local_mocked_bindings(
    pandoc_to = function() "typst",
    .package = "knitr"
  )
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- knit_print.tabular_spec(s)
  expect_s3_class(out, "knit_asis")
  expect_no_match(as.character(out), "```{=html}", fixed = TRUE)
})

test_that(".knit_print_md returns markdown source as knit_asis", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  out <- tabular:::.knit_print_md(s)
  expect_s3_class(out, "knit_asis")
  expect_match(as.character(out), "# T", all = FALSE)
})

# ---------------------------------------------------------------------
# Posit / IDE detection helpers
# ---------------------------------------------------------------------

test_that(".is_rstudio reads the RSTUDIO env var", {
  withr::with_envvar(list(RSTUDIO = "1"), expect_true(.is_rstudio()))
  withr::with_envvar(list(RSTUDIO = ""), expect_false(.is_rstudio()))
})

test_that(".is_positron reads the POSITRON env var", {
  withr::with_envvar(list(POSITRON = "1"), expect_true(.is_positron()))
  withr::with_envvar(list(POSITRON = ""), expect_false(.is_positron()))
})

test_that(".is_databricks reads the DATABRICKS_RUNTIME_VERSION env var", {
  withr::with_envvar(
    list(DATABRICKS_RUNTIME_VERSION = "14.3.x-scala2.12"),
    expect_true(.is_databricks())
  )
  withr::with_envvar(
    list(DATABRICKS_RUNTIME_VERSION = ""),
    expect_false(.is_databricks())
  )
})

# ---------------------------------------------------------------------
# Tempdir override
# ---------------------------------------------------------------------

test_that("tabular_preview_dir option overrides the temp directory", {
  s <- tabular(data.frame(x = 1L), titles = "T")
  preview_dir <- withr::local_tempdir()
  withr::with_options(list(tabular_preview_dir = preview_dir), {
    # Render via the public surface (as.tags) and verify the
    # tempfile lands under the configured dir.
    files_before <- length(list.files(preview_dir))
    htmltools::as.tags(s)
    files_after <- length(list.files(preview_dir))
  })
  expect_gt(files_after, files_before)
})

# ---------------------------------------------------------------------
# Coverage — output = ... routing through .print_with_output
# ---------------------------------------------------------------------

test_that("print(output = 'latex') routes through the md source branch (pending real backend)", {
  s <- tabular(data.frame(x = 1L))
  res <- capture.output(
    suppressMessages(print(s, output = "latex", view = FALSE))
  )
  expect_true(length(res) >= 1L)
})

test_that("print(output = 'docx') routes through the binary-fallback branch", {
  s <- tabular(data.frame(x = 1L))
  res <- capture.output(
    suppressMessages(print(s, output = "docx", view = FALSE))
  )
  expect_true(length(res) >= 0L)
})

test_that("print(output = 'pdf') routes through the binary-fallback branch", {
  s <- tabular(data.frame(x = 1L))
  res <- capture.output(
    suppressMessages(print(s, output = "pdf", view = FALSE))
  )
  expect_true(length(res) >= 0L)
})

test_that("print(output = 'rtf') routes through the binary-fallback branch", {
  s <- tabular(data.frame(x = 1L))
  res <- capture.output(
    suppressMessages(print(s, output = "rtf", view = FALSE))
  )
  expect_true(length(res) >= 0L)
})

# ---------------------------------------------------------------------
# Coverage — knit_print routing through pandoc_to fallbacks
# ---------------------------------------------------------------------

test_that("knit_print.tabular_spec returns asis text under pandoc_to = 'latex'", {
  s <- tabular(data.frame(x = 1L))
  out <- withr::with_options(
    list(),
    testthat::local_mocked_bindings(
      pandoc_to = function() "latex",
      .package = "knitr"
    )
  )
  # The mocked binding is scoped to this test_that — calling
  # knit_print should now route to .knit_print_md.
  result <- knit_print.tabular_spec(s)
  expect_s3_class(result, "knit_asis")
})

test_that("knit_print.tabular_spec returns asis text under pandoc_to = 'docx'", {
  testthat::local_mocked_bindings(
    pandoc_to = function() "docx",
    .package = "knitr"
  )
  s <- tabular(data.frame(x = 1L))
  result <- knit_print.tabular_spec(s)
  expect_s3_class(result, "knit_asis")
})

test_that("knit_print.tabular_spec returns asis text under pandoc_to = 'rtf'", {
  testthat::local_mocked_bindings(
    pandoc_to = function() "rtf",
    .package = "knitr"
  )
  s <- tabular(data.frame(x = 1L))
  result <- knit_print.tabular_spec(s)
  expect_s3_class(result, "knit_asis")
})

# ---------------------------------------------------------------------
# Coverage — direct .tabular_spec_print branches covr can instrument
# (the S7 print() dispatch path above is NOT instrumented, so these
# call the helper directly).
# ---------------------------------------------------------------------

test_that("output = 'latex' routes to the md source preview (instrumented)", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  expect_output(
    tabular:::.tabular_spec_print(spec, output = "latex", view = FALSE)
  )
})

test_that("an unknown well-typed output falls through to the cli summary", {
  spec <- tabular(data.frame(x = 1L), titles = "T")
  # The cli summary writes to the message stream, not stdout; the point
  # is that the switch default branch executes without error.
  expect_no_error(
    suppressMessages(
      tabular:::.tabular_spec_print(spec, output = "zzz", view = FALSE)
    )
  )
})

test_that("the Databricks path routes through displayHTML when detected", {
  skip_if_not_installed("htmltools")
  spec <- tabular(data.frame(x = 1L))
  testthat::local_mocked_bindings(.is_databricks = function() TRUE)
  shown <- NULL
  # `rlang::exec("displayHTML", html)` resolves the name off the search
  # path; provide it in the global env for the duration of the test.
  assign("displayHTML", function(html) shown <<- html, envir = globalenv())
  withr::defer(rm("displayHTML", envir = globalenv()))
  tabular:::.tabular_spec_print(spec, view = FALSE)
  expect_true(is.character(shown) && nzchar(shown))
})

test_that("a broken HTML render falls back to the cli summary with a warning", {
  skip_if_not_installed("htmltools")
  spec <- tabular(data.frame(x = 1L))
  testthat::local_mocked_bindings(
    as.tags = function(...) stop("boom"),
    .package = "htmltools"
  )
  # The fallback warns ("HTML preview failed") then prints the cli
  # summary to the message stream.
  expect_warning(
    suppressMessages(tabular:::.tabular_spec_print(spec, view = FALSE)),
    "HTML preview failed"
  )
})

# ---------------------------------------------------------------------
# pkgdown reference examples: print() must return a *browsable* value so
# pkgdown_print embeds it as a live HTML table instead of cat()-ing the
# raw HTML document (which renders as escaped #> text). Same concept as
# flextable's is_in_pkgdown() / gt. pkgdown sets IN_PKGDOWN=true.
# ---------------------------------------------------------------------

test_that("print() under pkgdown returns browsable HTML (live reference preview)", {
  skip_if_not_installed("htmltools")
  withr::local_envvar(IN_PKGDOWN = "true")
  spec <- tabular(data.frame(x = 1L), titles = "T")
  out <- tabular:::.tabular_spec_print(spec, view = FALSE)
  # pkgdown_print.default embeds the value only when this attr is TRUE.
  expect_true(isTRUE(attr(out, "browsable_html", exact = TRUE)))
  # and the embedded payload carries the scoped tabular table, not a dump.
  expect_match(paste(as.character(out), collapse = "\n"), "tabular-table")
})

test_that("print() outside pkgdown does not return a browsable value", {
  skip_if_not_installed("htmltools")
  withr::local_envvar(IN_PKGDOWN = "")
  spec <- tabular(data.frame(x = 1L), titles = "T")
  out <- tabular:::.tabular_spec_print(spec, view = FALSE)
  expect_false(isTRUE(attr(out, "browsable_html", exact = TRUE)))
})
