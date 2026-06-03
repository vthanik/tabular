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

test_that(".fn_peel peels base + marker, scalar and vectorized (#cr12)", {
  s <- paste0("12.3", tabular:::.fn_sentinel(c("a", "b")))
  pe <- tabular:::.fn_peel(s)
  expect_equal(pe$base, "12.3")
  expect_equal(pe$marker, "a,b")
  expect_true(pe$has)
  # a cell with no sentinel: base unchanged, marker NA, has FALSE
  pe2 <- tabular:::.fn_peel("plain")
  expect_equal(pe2$base, "plain")
  expect_true(is.na(pe2$marker))
  expect_false(pe2$has)
  # NA cell passes through unchanged
  pe3 <- tabular:::.fn_peel(NA_character_)
  expect_true(is.na(pe3$base))
  # length > 1 input is handled element-wise. The scalar .split_fn_sentinel
  # this replaced raised "the condition has length > 1" on such input;
  # routing md/docx through .fn_peel removes that latent crash.
  pev <- tabular:::.fn_peel(c(s, "plain", NA_character_))
  expect_equal(pev$base, c("12.3", "plain", NA_character_))
  expect_equal(pev$marker, c("a,b", NA_character_, NA_character_))
  expect_equal(pev$has, c(TRUE, FALSE, FALSE))
})

test_that(".fn_width_text reduces the sentinel to its marker glyphs", {
  s <- paste0("12.3", tabular:::.fn_sentinel("a"))
  expect_equal(tabular:::.fn_width_text(s), "12.3a")
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
# Hidden-column anchor guard (no orphan block line)
# ---------------------------------------------------------------------

mk_hidden_fn_spec <- function() {
  tabular(saf_aesocpt) |>
    cols(
      soc = col_spec(usage = "group"),
      label = col_spec(label = "PT"),
      n_total = col_spec(visible = FALSE),
      Total = col_spec(label = "Total")
    )
}

test_that("a body footnote on a hidden column warns and is dropped (no orphan)", {
  spec <- mk_hidden_fn_spec() |>
    footnote(
      "Hidden.",
      .at = cells_body(where = n_total >= 50, j = "n_total")
    )
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    reg <- tabular:::engine_footnotes_assign(spec, groups),
    "hidden column"
  )
  # the only ref was dropped -> no registry, hence no orphan block line
  expect_null(reg)
})

test_that("a header footnote on a hidden column warns and is dropped", {
  spec <- mk_hidden_fn_spec() |>
    footnote("Hidden header.", .at = cells_headers(j = "n_total"))
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    reg <- tabular:::engine_footnotes_assign(spec, groups),
    "hidden column"
  )
  expect_null(reg)
})

test_that("a header footnote spanning hidden + visible columns keeps the visible marker", {
  spec <- mk_hidden_fn_spec() |>
    footnote("Both.", .at = cells_headers(j = c("n_total", "Total")))
  groups <- tabular:::engine_subgroup_split(spec)
  reg <- expect_no_warning(tabular:::engine_footnotes_assign(spec, groups))
  expect_equal(reg$markers[[".auto1"]], "a")
  # the surviving marker lands on the visible Total header
  out <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "Total<sup>a</sup>", fixed = TRUE)
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
  # DOCX: the header marker rides a superscript run in document.xml,
  # and the block text rides the repeating footer1.xml.
  fdocx <- withr::local_tempfile(fileext = ".docx")
  suppressWarnings(emit(spec, fdocx, format = "docx"))
  ud <- withr::local_tempdir()
  utils::unzip(fdocx, exdir = ud)
  doc <- paste(readLines(file.path(ud, "word/document.xml")), collapse = "")
  ftr <- paste(readLines(file.path(ud, "word/footer1.xml")), collapse = "")
  expect_match(doc, "<w:vertAlign w:val=\"superscript\"/>", fixed = TRUE)
  # The block line is label / space / text as separate runs, so assert
  # the marker and the text runs rather than a contiguous "a Note.".
  expect_match(ftr, ">a</w:t>", fixed = TRUE)
  expect_match(ftr, ">Note.</w:t>", fixed = TRUE)
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

test_that("unsupported footnote anchors are rejected at call time (#cr2, #cr3)", {
  base <- mk_fn_spec()
  # group headers and other-block surfaces have no marker-injection path
  expect_error(
    footnote(base, "Nope.", .at = cells_footnotes()),
    class = "tabular_error_input"
  )
  expect_error(
    footnote(base, "Group.", .at = cells_group_headers()),
    class = "tabular_error_input"
  )
  # spanner band labels and header depth levels are not (yet) injectable
  expect_error(
    footnote(base, "Spanner.", .at = cells_headers(labels = "Treatment")),
    class = "tabular_error_input"
  )
  expect_error(
    footnote(base, "Band.", .at = cells_headers(level = 1)),
    class = "tabular_error_input"
  )
  # supported anchors still pass call-time validation
  expect_true(is_tabular_spec(
    footnote(base, "OK header.", .at = cells_headers(j = "Total"))
  ))
  expect_true(is_tabular_spec(
    footnote(base, "OK body.", .at = cells_body(j = "label"))
  ))
  expect_true(is_tabular_spec(
    footnote(base, "OK title.", .at = cells_title())
  ))
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

# ---------------------------------------------------------------------
# Code-review regression tests
# ---------------------------------------------------------------------

test_that("footnote markers follow post-sort reading order (#cr1)", {
  df <- data.frame(
    grp = c("Alpha", "Beta"),
    k = c(1L, 2L),
    val = c("10", "20"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(label = "Group"),
      k = col_spec(visible = FALSE),
      val = col_spec(label = "Value")
    ) |>
    sort_rows(by = "k", descending = TRUE) |>
    footnote(
      "Alpha note.",
      .at = cells_body(where = grp == "Alpha", j = "grp")
    ) |>
    footnote("Beta note.", .at = cells_body(where = grp == "Beta", j = "grp"))
  out <- withr::local_tempfile(fileext = ".md")
  suppressWarnings(emit(spec, out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Descending sort puts Beta on top, so Beta must be "a" (first in
  # reading order) and Alpha "b" -- numbering follows the rendered rows.
  expect_match(txt, "Beta^a^", fixed = TRUE)
  expect_match(txt, "Alpha^b^", fixed = TRUE)
  a_pos <- regexpr("a Beta note.", txt, fixed = TRUE)
  b_pos <- regexpr("b Alpha note.", txt, fixed = TRUE)
  expect_true(a_pos > 0L && b_pos > 0L && a_pos < b_pos)
})

test_that("a pinned symbol is reserved against a lower-ranked auto marker (#cr4)", {
  # The header note (rank 3) would auto-allocate "*" first; the body note
  # pins "*". The pin must be reserved so the header note skips "*".
  spec <- mk_fn_spec() |>
    preset(footnote_markers = "symbols") |>
    footnote("Header note.", .at = cells_headers(j = "Total")) |>
    footnote(
      "Body note.",
      .at = cells_body(where = n_total >= 50, j = "label"),
      symbol = "*"
    )
  groups <- tabular:::engine_subgroup_split(spec)
  reg <- tabular:::engine_footnotes_assign(spec, groups)
  markers <- unlist(reg$markers)
  expect_equal(sum(markers == "*"), 1L)
  expect_equal(length(unique(markers)), length(markers))
})

test_that("reusing an id with different text warns (#cr6)", {
  spec <- mk_fn_spec() |>
    footnote("First.", .at = cells_headers(j = "Total"), id = "dup") |>
    footnote(
      "Second.",
      .at = cells_body(where = n_total >= 50, j = "label"),
      id = "dup"
    )
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    tabular:::engine_footnotes_assign(spec, groups),
    "different text"
  )
})

test_that("a body footnote whose j names no column is dropped, not orphaned (#cr9)", {
  spec <- mk_fn_spec() |>
    footnote(
      "Phantom.",
      .at = cells_body(where = n_total >= 50, j = "does_not_exist")
    )
  groups <- tabular:::engine_subgroup_split(spec)
  expect_warning(
    reg <- tabular:::engine_footnotes_assign(spec, groups),
    "matched no cells"
  )
  expect_null(reg)
})
