# manifest.R — CDISC ARS Output YAML audit manifest. Tests the
# builder (.build_manifest), the writer (.write_manifest), and the
# determinism + round-trip contracts.

skip_if_not_installed("yaml")
skip_if_not_installed("digest")

# ---------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------

.register_stub <- function(format, payload = "stub", envir = parent.frame()) {
  # Snapshot any previously-registered backend so we can restore
  # it on test exit. Without this, registering a stub for "md" /
  # "html" wipes the real backend for subsequent tests.
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
    titles = c("Table 14.1", "Demographics"),
    footnotes = "Source: ADSL."
  )
}

# ---------------------------------------------------------------------
# Top-level shape
# ---------------------------------------------------------------------

test_that(".build_manifest() emits every required top-level key", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  expect_named(
    m,
    c(
      "id",
      "version",
      "name",
      "programmingCode",
      "fileSpecifications",
      "displays",
      "referencedAnalyses",
      "x-tabular"
    ),
    ignore.order = FALSE
  )
})

test_that(".build_manifest() id sanitises filename + appends format", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/Demo Table (v2).md",
    format = "md",
    data_file_path = NULL
  )
  expect_match(m$id, "_md$")
  expect_false(grepl(" ", m$id))
  expect_false(grepl("[()]", m$id))
})

test_that(".build_manifest() name uses the first title line", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  expect_identical(m$name, "Table 14.1")
})

test_that(".build_manifest() name falls back to filename when no titles", {
  spec <- tabular(data.frame(x = 1L))
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/fallback.md",
    format = "md",
    data_file_path = NULL
  )
  expect_identical(m$name, "fallback")
})

test_that(".manifest_id falls back to 'tabular' on empty sanitised base", {
  expect_identical(
    tabular:::.manifest_id("___.md", "md"),
    "tabular_md"
  )
})

test_that(".manifest_name falls back to 'tabular' on empty filename", {
  spec <- tabular(data.frame(x = 1L))
  expect_identical(
    tabular:::.manifest_name(spec, ".md"),
    "tabular"
  )
})

# ---------------------------------------------------------------------
# programmingCode block
# ---------------------------------------------------------------------

test_that("programmingCode carries every required parameter", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  expect_identical(m$programmingCode$context, "R")
  param_names <- vapply(
    m$programmingCode$parameters,
    function(p) p$name,
    character(1L)
  )
  expect_identical(
    sort(param_names),
    sort(c(
      "tabular_version",
      "git_commit",
      "rendered_at",
      "r_version",
      "platform"
    ))
  )
})

test_that("rendered_at is an ISO-8601 UTC string", {
  ts <- tabular:::.now_iso8601()
  expect_match(ts, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})

test_that(".program_path honours tabular.program_path option", {
  withr::with_options(
    list(tabular.program_path = "/sponsor/scripts/t.R"),
    expect_identical(tabular:::.program_path(), "/sponsor/scripts/t.R")
  )
})

test_that(".program_path returns NA when nothing is detectable", {
  withr::with_options(
    list(tabular.program_path = NULL),
    {
      out <- tabular:::.program_path()
      expect_true(is.character(out) && length(out) == 1L)
    }
  )
})

# ---------------------------------------------------------------------
# fileSpecifications
# ---------------------------------------------------------------------

test_that("fileSpecifications has one entry per emitted artefact", {
  .register_stub("md", "M")
  spec <- .simple_spec()
  render <- tempfile(fileext = ".md")
  qc <- tempfile(fileext = ".csv")
  emit(spec, render, data_file = qc, manifest = TRUE)
  manifest_path <- paste0(tools::file_path_sans_ext(render), ".audit.yml")
  parsed <- yaml::read_yaml(manifest_path)
  expect_length(parsed$fileSpecifications, 2L)
  file_types <- vapply(
    parsed$fileSpecifications,
    function(e) e$fileType,
    character(1L)
  )
  expect_setequal(file_types, c("md", "csv"))
})

test_that("fileSpecifications carries sha256 matching digest", {
  .register_stub("md", "fixed-payload")
  spec <- .simple_spec()
  render <- tempfile(fileext = ".md")
  emit(spec, render, manifest = TRUE)
  parsed <- yaml::read_yaml(
    paste0(tools::file_path_sans_ext(render), ".audit.yml")
  )
  expected_sha <- digest::digest(file = render, algo = "sha256")
  expect_identical(parsed$fileSpecifications[[1L]]$sha256, expected_sha)
})

test_that(".file_sha256 returns NA on missing file", {
  expect_true(is.na(tabular:::.file_sha256(tempfile())))
})

test_that(".file_spec_entry uses relative location prefix", {
  e <- tabular:::.file_spec_entry("/abs/path/out.md", "md")
  expect_identical(e$location, "./out.md")
  expect_identical(e$name, "out.md")
})

# ---------------------------------------------------------------------
# displays / displaySections
# ---------------------------------------------------------------------

test_that("displays carries Title / Header / Body / Footnote in order", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  sections <- m$displays[[1L]]$display$displaySections
  types <- vapply(sections, function(s) s$sectionType, character(1L))
  expect_identical(types, c("Title", "Header", "Body", "Footnote"))
})

test_that("Title section omits when no titles are configured", {
  spec <- tabular(data.frame(x = 1L), footnotes = "Foot only")
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  types <- vapply(
    m$displays[[1L]]$display$displaySections,
    function(s) s$sectionType,
    character(1L)
  )
  expect_false("Title" %in% types)
  expect_true("Footnote" %in% types)
})

test_that("Footnote section omits when no footnotes are configured", {
  spec <- tabular(data.frame(x = 1L), titles = "Title only")
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  types <- vapply(
    m$displays[[1L]]$display$displaySections,
    function(s) s$sectionType,
    character(1L)
  )
  expect_false("Footnote" %in% types)
})

test_that("Title sub-sections carry explicit order integers", {
  spec <- tabular(
    data.frame(x = 1L),
    titles = c("First", "Second", "Third")
  )
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  title_section <- m$displays[[1L]]$display$displaySections[[1L]]
  orders <- vapply(
    title_section$orderedSubSections,
    function(s) s$order,
    integer(1L)
  )
  expect_identical(orders, 1:3)
})

test_that("Header section includes band labels when headers() is used", {
  d <- data.frame(
    grp = letters[1:3],
    placebo = c(1, 2, 3),
    active = c(4, 5, 6)
  )
  spec <- tabular(d) |>
    headers("Treatment" = c("placebo", "active"))
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  header_section <- Filter(
    function(s) s$sectionType == "Header",
    m$displays[[1L]]$display$displaySections
  )[[1L]]
  texts <- vapply(
    header_section$orderedSubSections,
    function(s) s$subSection$text,
    character(1L)
  )
  expect_true("Treatment" %in% texts)
})

test_that("Body section text references the rendered file", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  body <- Filter(
    function(s) s$sectionType == "Body",
    m$displays[[1L]]$display$displaySections
  )[[1L]]
  expect_match(body$text, "t.md", fixed = TRUE)
})

test_that(".display_section_header returns NULL when nothing to surface", {
  fake_grid <- tabular_grid(
    pages = list(),
    metadata = list(
      headers = data.frame(
        depth = integer(),
        label = character(),
        col_start = integer(),
        col_end = integer(),
        leaf = logical(),
        stringsAsFactors = FALSE
      ),
      col_names = character()
    )
  )
  expect_null(tabular:::.display_section_header(fake_grid))
})

# ---------------------------------------------------------------------
# x-tabular extension
# ---------------------------------------------------------------------

test_that("x-tabular preset reflects the active preset_spec", {
  spec <- tabular(data.frame(x = 1L)) |>
    preset(font_size = 11L, orientation = "landscape")
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  xt <- m[["x-tabular"]]
  expect_identical(xt$preset$font_size, 11L)
  expect_identical(xt$preset$orientation, "landscape")
})

test_that("x-tabular preset emits defaults when none is attached", {
  spec <- tabular(data.frame(x = 1L))
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  xt <- m[["x-tabular"]]
  expect_true(is.character(xt$preset$font_family))
  expect_true(is.integer(xt$preset$font_size))
})

test_that("x-tabular pagination mirrors paginate plan", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  xt <- m[["x-tabular"]]
  expect_identical(xt$pagination$total_pages, 1L)
  expect_identical(xt$pagination$total_panels, 1L)
})

test_that("x-tabular styles captures declared predicates", {
  spec <- tabular(data.frame(x = c(1L, 2L, 3L))) |>
    style( bold = TRUE, .at = cells_body(where = x > 1))
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  layers <- m[["x-tabular"]]$styles$layers
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]$style$bold, TRUE)
})

test_that("x-tabular styles is empty list when no styles attached", {
  spec <- tabular(data.frame(x = 1L))
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  expect_length(m[["x-tabular"]]$styles$layers, 0L)
})

test_that("x-tabular inputProvenance carries data shape", {
  spec <- .simple_spec()
  grid <- as_grid(spec)
  m <- tabular:::.build_manifest(
    spec = spec,
    grid = grid,
    file = "out/t.md",
    format = "md",
    data_file_path = NULL
  )
  prov <- m[["x-tabular"]]$inputProvenance
  expect_identical(prov$nrow, 3L)
  expect_identical(prov$ncol, 2L)
  expect_identical(prov$col_names, c("x", "y"))
})

test_that(".style_node_to_list drops NA fields and handles non-nodes", {
  node <- style_node(bold = TRUE, italic = TRUE)
  flat <- tabular:::.style_node_to_list(node)
  expect_true("bold" %in% names(flat))
  expect_true("italic" %in% names(flat))
  # Untouched fields default to NA and must NOT appear in the manifest.
  expect_false("color" %in% names(flat))
  expect_false("font_size" %in% names(flat))

  expect_identical(tabular:::.style_node_to_list("not a node"), list())
})

# ---------------------------------------------------------------------
# Writer end-to-end + determinism + round-trip
# ---------------------------------------------------------------------

test_that(".write_manifest writes to <file>.audit.yml alongside render", {
  .register_stub("md", "M")
  spec <- .simple_spec()
  render <- tempfile(fileext = ".md")
  emit(spec, render, manifest = TRUE)
  expected <- paste0(tools::file_path_sans_ext(render), ".audit.yml")
  expect_true(file.exists(expected))
})

test_that("manifest YAML round-trips through yaml::read + write", {
  .register_stub("md", "M")
  spec <- .simple_spec()
  render <- tempfile(fileext = ".md")
  emit(spec, render, manifest = TRUE)
  yml <- paste0(tools::file_path_sans_ext(render), ".audit.yml")

  parsed <- yaml::read_yaml(yml)
  rewritten <- tempfile(fileext = ".yml")
  yaml::write_yaml(parsed, rewritten)
  reparsed <- yaml::read_yaml(rewritten)
  expect_identical(parsed, reparsed)
})

test_that("manifest is byte-identical across two runs modulo timestamp", {
  .register_stub("md", "M")
  spec <- .simple_spec()
  render <- tempfile(fileext = ".md")

  emit(spec, render, manifest = TRUE)
  yml1 <- paste0(tools::file_path_sans_ext(render), ".audit.yml")
  first <- readLines(yml1)

  emit(spec, render, manifest = TRUE)
  second <- readLines(yml1)

  drop_ts <- function(lines) {
    # The rendered_at parameter's value line is the only allowed
    # difference. Strip it.
    keep <- !grepl("^    value:.*\\d{4}-\\d{2}-\\d{2}T", lines)
    lines[keep]
  }
  expect_identical(drop_ts(first), drop_ts(second))
})
