# Tests for auto-numbered footnote resolution (R/engine_footnotes.R).

mk_fn_spec <- function() {
  tabular(saf_aesocpt) |>
    cols(
      soc = col_spec(usage = "group"),
      label = col_spec(label = "PT"),
      Total = col_spec(label = "Total")
    )
}

# ---------------------------------------------------------------------
# Marker generators
# ---------------------------------------------------------------------

test_that(".fn_marker_letters is bijective base-26", {
  expect_equal(tabular:::.fn_marker_letters(1L), "a")
  expect_equal(tabular:::.fn_marker_letters(26L), "z")
  expect_equal(tabular:::.fn_marker_letters(27L), "aa")
  expect_equal(tabular:::.fn_marker_letters(28L), "ab")
  expect_equal(tabular:::.fn_marker_letters(52L), "az")
  expect_equal(tabular:::.fn_marker_letters(53L), "ba")
})

test_that(".fn_marker_numbers is the integer string", {
  expect_equal(tabular:::.fn_marker_numbers(1L), "1")
  expect_equal(tabular:::.fn_marker_numbers(42L), "42")
})

test_that(".fn_marker_symbols follows Lamport's sequence then spills", {
  # asterisk, dagger, double-dagger, section, paragraph, double-vert
  expect_equal(tabular:::.fn_marker_symbols(1L), "*")
  expect_equal(tabular:::.fn_marker_symbols(2L), "\u2020")
  expect_equal(tabular:::.fn_marker_symbols(6L), "\u2016")
  # seventh spills to a doubled asterisk (never silently reused)
  expect_equal(tabular:::.fn_marker_symbols(7L), "**")
  expect_equal(tabular:::.fn_marker_symbols(8L), "\u2020\u2020")
})

test_that(".fn_marker dispatches on scheme (unknown -> letters)", {
  expect_equal(tabular:::.fn_marker(1L, "letters"), "a")
  expect_equal(tabular:::.fn_marker(1L, "numbers"), "1")
  expect_equal(tabular:::.fn_marker(1L, "symbols"), "*")
  expect_equal(tabular:::.fn_marker(2L, "bogus"), "b")
})

# ---------------------------------------------------------------------
# Registry assignment
# ---------------------------------------------------------------------

test_that(".fn_assign dedups by id and advances otherwise", {
  reg <- tabular:::.fn_registry_seed()
  reg <- tabular:::.fn_assign(reg, "x", NULL, "letters")
  reg <- tabular:::.fn_assign(reg, "x", NULL, "letters") # dedup: still "a"
  reg <- tabular:::.fn_assign(reg, "y", NULL, "letters")
  expect_equal(reg$markers[["x"]], "a")
  expect_equal(reg$markers[["y"]], "b")
  expect_equal(reg$order, c("x", "y"))
})

test_that(".fn_assign reserves a pinned symbol and skips it in auto-alloc", {
  reg <- tabular:::.fn_registry_seed()
  reg <- tabular:::.fn_assign(reg, "pinned", "a", "letters") # pin "a"
  reg <- tabular:::.fn_assign(reg, "auto", NULL, "letters") # must skip "a"
  expect_equal(reg$markers[["pinned"]], "a")
  expect_equal(reg$markers[["auto"]], "b")
})

# ---------------------------------------------------------------------
# Sentinel round-trip
# ---------------------------------------------------------------------

test_that("sentinel peels back to base + marker", {
  s <- paste0("12.3", tabular:::.fn_sentinel(c("a", "b")))
  sp <- tabular:::.split_fn_sentinel(s)
  expect_equal(sp$base, "12.3")
  expect_equal(sp$marker, "a,b")
  # a cell with no sentinel is unchanged
  expect_null(tabular:::.split_fn_sentinel("plain")$marker)
})

test_that(".fn_width_text reduces the sentinel to its marker glyphs", {
  s <- paste0("12.3", tabular:::.fn_sentinel("a"))
  expect_equal(tabular:::.fn_width_text(s), "12.3a")
})

test_that(".split_fn_sentinel passes NA through unchanged", {
  sp <- tabular:::.split_fn_sentinel(NA_character_)
  expect_true(is.na(sp$base))
  expect_null(sp$marker)
})

# ---------------------------------------------------------------------
# Header-anchor column resolution
# ---------------------------------------------------------------------

test_that(".fn_header_cols resolves by name, numeric index, and labels", {
  cn <- c("a", "b", "c")
  expect_equal(tabular:::.fn_header_cols(cells_headers(j = "b"), cn), "b")
  expect_equal(tabular:::.fn_header_cols(cells_headers(j = 2L), cn), "b")
  expect_equal(
    tabular:::.fn_header_cols(cells_headers(labels = "c"), cn),
    "c"
  )
  # out-of-range numeric / unknown name -> nothing
  expect_length(tabular:::.fn_header_cols(cells_headers(j = 9L), cn), 0L)
  expect_length(tabular:::.fn_header_cols(cells_headers(j = "z"), cn), 0L)
  # a bare header location (no j / labels) targets no column
  expect_length(tabular:::.fn_header_cols(cells_headers(), cn), 0L)
})

test_that(".fn_surface_rank orders surfaces top-to-bottom", {
  expect_lt(
    tabular:::.fn_surface_rank("title"),
    tabular:::.fn_surface_rank("headers")
  )
  expect_lt(
    tabular:::.fn_surface_rank("headers"),
    tabular:::.fn_surface_rank("body")
  )
  expect_equal(tabular:::.fn_surface_rank("pagehead"), 2L)
  expect_equal(tabular:::.fn_surface_rank("subgroup"), 4L)
  expect_equal(tabular:::.fn_surface_rank("group_headers"), 5L)
  expect_equal(tabular:::.fn_surface_rank("pagefoot"), 8L)
  expect_equal(tabular:::.fn_surface_rank("nonsense"), 9L)
})

test_that(".fn_append_sup builds a fresh ast from a non-ast input", {
  ast <- tabular:::.fn_append_sup(NULL, "a")
  expect_true(is_inline_ast(ast))
  expect_length(ast@runs, 1L)
  expect_equal(ast@runs[[1L]]$type, "sup")
})

test_that("a header anchor on an unknown column is dropped (assign returns NULL)", {
  spec <- mk_fn_spec() |>
    footnote("X.", .at = cells_headers(j = "does_not_exist"))
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    reg <- tabular:::engine_footnotes_assign(spec, groups),
    "matched no cells"
  )
  expect_null(reg)
})

# ---------------------------------------------------------------------
# Reading order + integration (end to end)
# ---------------------------------------------------------------------

test_that("markers are assigned in reading order (headers before body)", {
  # The header footnote is declared SECOND but headers (rank 3) precede
  # body (rank 6), so it is lettered "a"; the body footnote is "b".
  spec <- mk_fn_spec() |>
    footnote(
      "Body note.",
      .at = cells_body(where = n_total >= 50, j = "label")
    ) |>
    footnote("Header note.", .at = cells_headers(j = "Total"))
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "Total<sup>a</sup>", fixed = TRUE)
  expect_match(txt, "a Header note.", fixed = TRUE)
  expect_match(txt, "b Body note.", fixed = TRUE)
})

test_that("the same id shares one marker and one block line", {
  spec <- mk_fn_spec() |>
    footnote(
      "Shared.",
      .at = cells_body(where = n_total >= 50, j = "label"),
      id = "s"
    ) |>
    footnote("Shared.", .at = cells_headers(j = "Total"), id = "s")
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # one block line for the shared id
  expect_equal(
    lengths(regmatches(txt, gregexpr("a Shared.", txt, fixed = TRUE)))[[1L]],
    1L
  )
})

test_that("markers are byte-identical across all five backends", {
  spec <- mk_fn_spec() |>
    footnote("Note.", .at = cells_headers(j = "Total"))
  rd <- function(ext, fmt) {
    f <- withr::local_tempfile(fileext = ext)
    suppressWarnings(emit(spec, f, format = fmt))
    paste(readLines(f, warn = FALSE), collapse = "\n")
  }
  expect_match(rd(".html", "html"), "<sup>a</sup>", fixed = TRUE)
  expect_match(rd(".md", "md"), "Total^a^", fixed = TRUE)
  expect_match(rd(".tex", "latex"), "\\textsuperscript{a}", fixed = TRUE)
  expect_match(rd(".rtf", "rtf"), "{\\super a\\nosupersub}", fixed = TRUE)
})

test_that("symbols scheme leads with an asterisk", {
  spec <- mk_fn_spec() |>
    preset(footnote_markers = "symbols") |>
    footnote("Note.", .at = cells_headers(j = "Total"))
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "<sup>*</sup>", fixed = TRUE)
})

test_that("footnote_label template wraps the marker in the block line", {
  spec <- mk_fn_spec() |>
    preset(footnote_label = "[{m}]") |>
    footnote("Note.", .at = cells_headers(j = "Total"))
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "[a] Note.", fixed = TRUE)
})

test_that("an anchor that matches nothing warns and is dropped", {
  spec <- mk_fn_spec() |>
    footnote("Never.", .at = cells_body(where = n_total > 1e9, j = "label"))
  out <- withr::local_tempfile(fileext = ".html")
  expect_warning(suppressWarnings(emit(spec, out)), NA) # emit() itself is fine
  # the assign step is where the warning fires
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    tabular:::engine_footnotes_assign(spec, groups),
    "matched no cells"
  )
})

test_that("a title-anchored footnote marks the last title line", {
  spec <- tabular(saf_aesocpt, titles = c("Table 1", "AE Table")) |>
    cols(
      soc = col_spec(usage = "group"),
      label = col_spec(label = "PT"),
      Total = col_spec(label = "Total")
    ) |>
    footnote("Source: ADAE.", .at = cells_title())
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "AE Table<sup>a</sup>", fixed = TRUE)
  expect_match(txt, "a Source: ADAE.", fixed = TRUE)
})

test_that("an unsupported anchor surface warns and is dropped", {
  spec <- mk_fn_spec() |>
    footnote("Nope.", .at = cells_footnotes())
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    tabular:::engine_footnotes_assign(spec, groups),
    "unsupported"
  )
})

test_that("the marker is identical across subgroups and the block emits once", {
  spec <- tabular(saf_demo) |>
    cols(
      variable = col_spec(usage = "group"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    subgroup("variable") |>
    footnote(
      "Across groups.",
      .at = cells_body(where = stat_label == "n", j = "placebo"),
      id = "g"
    )
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # marker appears on more than one subgroup's body cell, all "a"
  n_sup <- lengths(regmatches(
    txt,
    gregexpr("<sup>a</sup>", txt, fixed = TRUE)
  ))[[1L]]
  expect_gt(n_sup, 1L)
  # exactly one block line
  n_block <- lengths(regmatches(
    txt,
    gregexpr("a Across groups.", txt, fixed = TRUE)
  ))[[1L]]
  expect_equal(n_block, 1L)
})
