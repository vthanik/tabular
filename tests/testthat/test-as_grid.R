# as_grid() — engine pipeline composition + per-page slicing.

# ---------------------------------------------------------------------
# Public predicate / shape
# ---------------------------------------------------------------------

test_that("as_grid() rejects non-spec input", {
  expect_error(
    as_grid(1L),
    class = "tabular_error_input"
  )
})

test_that("as_grid() returns a tabular_grid", {
  spec <- tabular(data.frame(x = 1:3))
  g <- as_grid(spec)
  expect_true(is_tabular_grid(g))
})

test_that("as_grid() metadata carries spec shape", {
  spec <- tabular(
    data.frame(x = 1:3, y = letters[1:3]),
    titles = c("Title A", "Title B"),
    footnotes = "Foot 1"
  )
  g <- as_grid(spec)
  meta <- g@metadata
  expect_identical(meta$format, NA_character_)
  expect_identical(meta$nrow_data, 3L)
  expect_identical(meta$ncol_data, 2L)
  expect_identical(meta$col_names, c("x", "y"))
  expect_identical(meta$titles, c("Title A", "Title B"))
  expect_identical(meta$footnotes, "Foot 1")
  expect_length(meta$titles_ast, 2L)
  expect_length(meta$footnotes_ast, 1L)
  expect_named(meta$col_labels_ast, c("x", "y"))
})

test_that("as_grid() leaves pagehead_ast / pagefoot_ast NULL when preset omits them", {
  spec <- tabular(data.frame(x = 1:3))
  g <- as_grid(spec)
  expect_null(g@metadata$pagehead_ast)
  expect_null(g@metadata$pagefoot_ast)
})

test_that("as_grid() populates pagehead_ast for single-row pagehead", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagehead = list(
        left = "Protocol: ABC-123",
        right = "Page {page} of {npages}"
      )
    )
  g <- as_grid(spec)
  band <- g@metadata$pagehead_ast
  expect_true(is.list(band))
  expect_named(band, c("left", "center", "right"))
  expect_length(band$left, 1L)
  expect_true(is_inline_ast(band$left[[1L]]))
  expect_true(is_inline_ast(band$right[[1L]]))
})

test_that("as_grid() populates pagefoot_ast multi-row with index 1 at body edge", {
  spec <- tabular(data.frame(x = 1:3)) |>
    preset(
      pagefoot = list(
        left = c("Body edge row", "Far from body row"),
        right = "{datetime}"
      )
    )
  g <- as_grid(spec)
  band <- g@metadata$pagefoot_ast
  expect_length(band$left, 2L)
  expect_length(band$right, 2L)
  # Index 1 has user content; index 2 of right is padding (empty AST)
  expect_gt(length(band$left[[1L]]@runs), 0L)
  expect_gt(length(band$left[[2L]]@runs), 0L)
  expect_gt(length(band$right[[1L]]@runs), 0L)
  expect_length(band$right[[2L]]@runs, 0L)
})

test_that("as_grid() honours session-default pagehead via cascade", {
  withr::defer(set_preset(.reset = TRUE))
  set_preset(pagehead = list(left = "Session protocol"))
  spec <- tabular(data.frame(x = 1:3)) # no per-spec preset
  g <- as_grid(spec)
  expect_false(is.null(g@metadata$pagehead_ast))
  expect_length(g@metadata$pagehead_ast$left, 1L)
})

# ---------------------------------------------------------------------
# Page descriptors
# ---------------------------------------------------------------------

test_that("as_grid() one-page default carries full data slice", {
  spec <- tabular(data.frame(x = 1:3, y = letters[1:3]))
  g <- as_grid(spec)
  expect_length(g@pages, 1L)
  p <- g@pages[[1L]]
  expect_identical(p$page_index, 1L)
  expect_identical(p$panel_index, 1L)
  expect_false(p$is_continuation)
  expect_identical(dim(p$cells_text), c(3L, 2L))
  expect_identical(dim(p$cells_ast), c(3L, 2L))
  expect_identical(dim(p$cells_style), c(3L, 2L))
  expect_identical(p$col_names, c("x", "y"))
  expect_named(p$col_labels_ast, c("x", "y"))
})

test_that("as_grid() honours sort_rows() before formatting", {
  d <- data.frame(x = c(3L, 1L, 2L), y = c("c", "a", "b"))
  spec <- tabular(d) |> sort_rows("x")
  g <- as_grid(spec)
  expect_identical(g@pages[[1L]]$cells_text[, "x"], c("1", "2", "3"))
})

test_that("as_grid() applies col_spec decimal alignment", {
  d <- data.frame(x = c("1.5", "10.25", "100.125"))
  spec <- tabular(d) |> cols(x = col_spec(align = "decimal"))
  g <- as_grid(spec)
  out <- g@pages[[1L]]$cells_text[, "x"]
  # Every cell must end at the same column position after alignment.
  widths <- nchar(out, type = "chars")
  expect_true(length(unique(widths)) == 1L)
})

test_that("as_grid() sections decimal columns on group_skip so n_pct stays tight (#image3)", {
  # A continuous block (est_spread with decimals) followed by a
  # categorical n_pct block, under a group_skip-firing group column.
  # Without sectioning, the continuous decimal slot leaks onto the
  # n_pct integer count: "14 (16.3)" renders "14  (16.3 )" (gap).
  # With sectioning, the n_pct block aligns in isolation: tight.
  d <- data.frame(
    variable = c("Age", "Age", "Sex", "Sex"),
    stat = c("Mean (SD)", "Median", "F", "M"),
    arm = c("75.2 (8.59)", "76.0", "14 (16.3)", "72 (83.7)")
  )
  spec <- tabular(d) |>
    cols(
      variable = col_spec(),
      stat = col_spec(),
      arm = col_spec(align = "decimal")
    ) |>
    group_rows(by = "variable")
  g <- as_grid(spec)
  out <- g@pages[[1L]]$cells_text[, "arm"]
  sex_rows <- out[grepl("16\\.3|83\\.7", out)]
  expect_length(sex_rows, 2L)
  # n_pct count sits one space before "(", no leaked decimal slot.
  expect_true(all(grepl("[0-9] \\([0-9]", trimws(sex_rows, "right"))))
  expect_false(any(grepl("[0-9]  +\\(", sex_rows)))
})

test_that("as_grid() returns empty list-matrices for zero-row data", {
  spec <- tabular(data.frame(x = integer(0L), y = character(0L)))
  g <- as_grid(spec)
  p <- g@pages[[1L]]
  expect_identical(nrow(p$cells_text), 0L)
  expect_identical(nrow(p$cells_ast), 0L)
  expect_identical(nrow(p$cells_style), 0L)
  expect_identical(p$col_names, c("x", "y"))
})

# ---------------------------------------------------------------------
# Headers + style trace into metadata
# ---------------------------------------------------------------------

test_that("as_grid() carries the resolved header band grid in metadata", {
  d <- data.frame(
    grp = letters[1:3],
    placebo = c(1, 2, 3),
    active = c(4, 5, 6)
  )
  spec <- tabular(d) |>
    headers("Treatment" = c("placebo", "active"))
  g <- as_grid(spec)
  hdrs <- g@metadata$headers
  expect_s3_class(hdrs, "data.frame")
  expect_true("Treatment" %in% hdrs$label)
})

test_that("as_grid() emits a populated style grid when a predicate fires", {
  d <- data.frame(x = c(1L, 2L, 3L), y = c(10L, 20L, 30L))
  spec <- tabular(d) |> style(bold = TRUE, .at = cells_body(where = x > 1))
  g <- as_grid(spec)
  styles <- g@pages[[1L]]$cells_style
  expect_true(isTRUE(styles[[2L, 1L]]@bold))
  expect_true(isTRUE(styles[[3L, 1L]]@bold))
  expect_true(is.na(styles[[1L, 1L]]@bold))
})

# ---------------------------------------------------------------------
# Pagination splits pages and slices matrices accordingly
# ---------------------------------------------------------------------

test_that("as_grid() splits across pages when pagination forces it", {
  # Use a tiny font + many rows to force the engine to chunk.
  d <- data.frame(
    grp = rep(letters[1:6], each = 4L),
    x = seq_len(24L)
  )
  spec <- tabular(d) |>
    cols(grp = col_spec()) |>
    group_rows(by = "grp") |>
    paginate(keep_together = "grp") |>
    preset(font_size = 24L, paper_size = "letter", orientation = "portrait")
  g <- as_grid(spec)
  expect_gt(g@metadata$total_pages, 1L)
  # Concatenating every page's row indices must reconstruct seq_len(24).
  all_rows <- unlist(lapply(g@pages, function(p) p$row_indices))
  expect_setequal(all_rows, seq_len(24L))
})

# ---------------------------------------------------------------------
# Zebra striping stamps data-row cell backgrounds
# ---------------------------------------------------------------------

test_that("stripe stamps the zebra fill on even data rows, leaving odd rows transparent", {
  d <- data.frame(lbl = c("r1", "r2", "r3", "r4"), val = 1:4)
  g <- as_grid(tabular(d) |> preset(stripe = "#eeeeee"))
  st <- g@pages[[1L]]$cells_style
  # Single-colour stripe -> odd data rows transparent, even rows filled.
  expect_true(is.na(st[[1L, "lbl"]]@background))
  expect_identical(st[[2L, "lbl"]]@background, "#eeeeee")
  expect_true(is.na(st[[3L, "lbl"]]@background))
  expect_identical(st[[4L, "lbl"]]@background, "#eeeeee")
})

test_that("stripe is off by default (no background stamped)", {
  g <- as_grid(tabular(data.frame(lbl = c("r1", "r2"), val = 1:2)))
  st <- g@pages[[1L]]$cells_style
  expect_true(is.na(st[[1L, "lbl"]]@background))
  expect_true(is.na(st[[2L, "lbl"]]@background))
})

test_that("stripe never overwrites an explicit per-cell background", {
  d <- data.frame(lbl = c("r1", "r2"), val = 1:2)
  g <- as_grid(
    tabular(d) |>
      preset(stripe = "#eeeeee") |>
      style(background = "#ff0000", .at = cells_body())
  )
  st <- g@pages[[1L]]$cells_style
  # Row 2 would be the even (filled) row, but the explicit red wins.
  expect_identical(st[[2L, "lbl"]]@background, "#ff0000")
})

test_that("stripe fills synthesised group-header + blank rows (look-ahead parity)", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    group_rows(by = "variable") |>
    preset(stripe = c(odd = "#f5f5f5", even = "#ffffff"))
  page <- as_grid(spec)@pages[[1L]]
  st <- page$cells_style
  is_hdr <- page$is_header_row
  is_blk <- page$is_blank_row
  cn <- colnames(st)[[1L]]
  # The stripe now reaches every synthesised special row (previously
  # skipped, leaving white gaps in the zebra band).
  special <- which(is_hdr | is_blk)
  expect_gt(length(special), 0L)
  for (r in special) {
    expect_false(is.na(st[[r, cn]]@background))
  }
  # Continuity: a special row inherits the fill of the NEXT data row
  # (look-ahead parity), so the group-header reads as one band with its
  # block. The parity counter only advanced on data rows.
  first_hdr <- which(is_hdr)[[1L]]
  after <- which(!is_hdr & !is_blk & seq_along(is_hdr) > first_hdr)
  expect_gt(length(after), 0L)
  expect_identical(
    st[[first_hdr, cn]]@background,
    st[[after[[1L]], cn]]@background
  )
})

test_that("explicit cells_group_headers(background=) beats the stripe fill", {
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(),
      stat_label = col_spec(align = "left"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    ) |>
    group_rows(by = "variable") |>
    preset(stripe = c(odd = "#f5f5f5", even = "#ffffff")) |>
    style(background = "#abcdef", .at = cells_group_headers())
  page <- as_grid(spec)@pages[[1L]]
  st <- page$cells_style
  first_hdr <- which(page$is_header_row)[[1L]]
  host <- which(vapply(
    seq_len(ncol(st)),
    function(j) {
      nm <- colnames(st)[[j]]
      is_style_node(st[[first_hdr, nm]]) &&
        identical(st[[first_hdr, nm]]@background, "#abcdef")
    },
    logical(1L)
  ))
  # The group-header host cell carries the explicit colour, not the
  # stripe fill (group-header stamp runs before the stripe, and the
  # stripe's is.na(bg) guard then leaves it alone).
  expect_gt(length(host), 0L)
})

# ---------------------------------------------------------------------
# spacing knob drives inter-section blank lines (meta$gaps)
# ---------------------------------------------------------------------

test_that("the spacing knob changes the rendered title blank lines (HTML)", {
  mk <- function(sp) {
    s <- tabular(data.frame(x = 1L), titles = "T")
    if (!is.null(sp)) {
      s <- s |> preset(spacing = sp)
    }
    s
  }
  npad <- function(spec) {
    f <- withr::local_tempfile(
      fileext = ".html",
      .local_envir = parent.frame()
    )
    emit(spec, f)
    sum(grepl("tabular-pad", readLines(f, warn = FALSE)))
  }
  base <- npad(mk(NULL))
  # Raising the above-title gap adds blank-pad paragraphs; zeroing both
  # title gaps removes them. The knob was previously dead (resolved into
  # meta$gaps but ignored by the backends).
  expect_gt(npad(mk(list(title = c(above = 3)))), base)
  expect_lt(npad(mk(list(title = c(above = 0, below = 0)))), base)
})

test_that("a per-surface style() blank count overrides the spacing knob", {
  spec <- tabular(data.frame(x = 1L), titles = "T") |>
    preset(spacing = list(title = c(above = 3))) |>
    style(blank_above = 0L, .at = cells_title())
  f <- withr::local_tempfile(fileext = ".html")
  emit(spec, f)
  high <- tabular(data.frame(x = 1L), titles = "T") |>
    preset(spacing = list(title = c(above = 3)))
  f2 <- withr::local_tempfile(fileext = ".html")
  emit(high, f2)
  expect_lt(
    sum(grepl("tabular-pad", readLines(f, warn = FALSE))),
    sum(grepl("tabular-pad", readLines(f2, warn = FALSE)))
  )
})

# ---------------------------------------------------------------------
# Group-header style stamp (cells_group_headers cascade -> header rows)
# ---------------------------------------------------------------------

mk_band_spec <- function() {
  d <- data.frame(
    soc = c("Infections", "Infections", "Cardiac", "Cardiac"),
    label = c("Pneumonia", "Sepsis", "MI", "AF"),
    placebo = c("1", "2", "3", "4")
  )
  tabular(d) |>
    cols(
      label = col_spec(label = "PT"),
      soc = col_spec(),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "soc")
}

test_that("header_meta carries group_col + data_idx on header rows, NULL elsewhere", {
  p <- as_grid(mk_band_spec())@pages[[1L]]
  hdr <- which(p$is_header_row)
  expect_gt(length(hdr), 0L)
  for (r in hdr) {
    expect_true(is.list(p$header_meta[[r]]))
    expect_identical(p$header_meta[[r]]$group_col, "soc")
    expect_true(is.numeric(p$header_meta[[r]]$data_idx))
  }
  # Data rows carry no header_meta.
  data_rows <- setdiff(seq_len(nrow(p$cells_style)), hdr)
  expect_true(all(vapply(p$header_meta[data_rows], is.null, logical(1L))))
})

test_that("the stamp leaves header-row bold NA when no group_headers layer is set", {
  p <- as_grid(mk_band_spec())@pages[[1L]]
  for (r in which(p$is_header_row)) {
    expect_true(is.na(p$cells_style[[r, 1L]]@bold))
  }
})

test_that("cells_group_headers(bold = FALSE) stamps bold = FALSE on header-row cells", {
  p <- as_grid(
    mk_band_spec() |> style(bold = FALSE, .at = cells_group_headers())
  )@pages[[1L]]
  hdr <- which(p$is_header_row)
  for (r in hdr) {
    for (cn in colnames(p$cells_style)) {
      expect_false(isTRUE(p$cells_style[[r, cn]]@bold))
      expect_identical(p$cells_style[[r, cn]]@bold, FALSE)
    }
  }
})

test_that("the stamp sets only the requested field, never clobbering other cell attrs", {
  # A group_headers layer that sets ONLY italic must leave bold NA.
  p <- as_grid(
    mk_band_spec() |> style(italic = TRUE, .at = cells_group_headers())
  )@pages[[1L]]
  r <- which(p$is_header_row)[[1L]]
  expect_true(isTRUE(p$cells_style[[r, 1L]]@italic))
  expect_true(is.na(p$cells_style[[r, 1L]]@bold))
  expect_true(is.na(p$cells_style[[r, 1L]]@background))
})

test_that("cells_group_headers(j = ) restricts the override to the matching band", {
  p <- as_grid(
    mk_band_spec() |>
      style(bold = FALSE, .at = cells_group_headers(j = "soc"))
  )@pages[[1L]]
  for (r in which(p$is_header_row)) {
    # Every header row in this spec is a `soc` band, so all match.
    expect_identical(p$cells_style[[r, 1L]]@bold, FALSE)
  }
  # A j that matches no band leaves every header row untouched.
  p2 <- as_grid(
    mk_band_spec() |>
      style(bold = FALSE, .at = cells_group_headers(j = "placebo"))
  )@pages[[1L]]
  for (r in which(p2$is_header_row)) {
    expect_true(is.na(p2$cells_style[[r, 1L]]@bold))
  }
})

test_that("cells_group_headers(where = ) selects header rows by source data row", {
  p <- as_grid(
    mk_band_spec() |>
      style(bold = FALSE, .at = cells_group_headers(where = soc == "Cardiac"))
  )@pages[[1L]]
  hdr <- which(p$is_header_row)
  for (r in hdr) {
    txt <- p$cells_text[r, ][nzchar(p$cells_text[r, ])][[1L]]
    if (identical(txt, "Cardiac")) {
      expect_identical(p$cells_style[[r, 1L]]@bold, FALSE)
    } else {
      expect_true(is.na(p$cells_style[[r, 1L]]@bold))
    }
  }
})

test_that("a non-logical cells_group_headers(where = ) raises tabular_error_input", {
  expect_error(
    as_grid(
      mk_band_spec() |>
        style(bold = FALSE, .at = cells_group_headers(where = soc))
    ),
    class = "tabular_error_input"
  )
})

test_that("a length-1 cells_group_headers(where = ) recycles to every header row", {
  p <- as_grid(
    mk_band_spec() |>
      style(bold = FALSE, .at = cells_group_headers(where = TRUE))
  )@pages[[1L]]
  for (r in which(p$is_header_row)) {
    expect_identical(p$cells_style[[r, 1L]]@bold, FALSE)
  }
})

test_that("a wrong-length cells_group_headers(where = ) raises tabular_error_input", {
  expect_error(
    as_grid(
      mk_band_spec() |>
        style(bold = FALSE, .at = cells_group_headers(where = c(TRUE, FALSE)))
    ),
    class = "tabular_error_input"
  )
})

# ---- pretext / posttext affixes (cross-backend) -------------------------

mk_affix_spec <- function() {
  d <- data.frame(
    grp = c("Age", "Age"),
    stat = c("Mean", "SD"),
    a = c("75.2", "8.59"),
    stringsAsFactors = FALSE
  )
  tabular(d) |>
    cols(
      grp = col_spec(
        label = "C",
        align = "left"
      ),
      stat = col_spec(label = "Stat", align = "left"),
      a = col_spec(label = "A", align = "right")
    ) |>
    group_rows(by = "grp", display = "collapse", skip = "grp") |>
    style(pretext = "PFX ", .at = cells_body(j = "stat")) |>
    style(posttext = " SFX", .at = cells_body(j = "a"))
}

test_that("pretext/posttext wrap cell text and AST (#affixes)", {
  g <- as_grid(mk_affix_spec())@pages[[1L]]
  # The affix lands on the resolved cells_text matrix.
  expect_true(any(grepl("PFX Mean", g$cells_text, fixed = TRUE)))
  expect_true(any(grepl("75.2 SFX", g$cells_text, fixed = TRUE)))
  # And on the parsed AST so AST-driven backends see it too.
  stat_ast <- g$cells_ast[[
    which(g$cells_text[, "stat"] == "PFX Mean"),
    "stat"
  ]]
  ast_text <- paste(
    vapply(stat_ast@runs, function(r) r$text %||% "", character(1L)),
    collapse = ""
  )
  expect_true(grepl("PFX Mean", ast_text, fixed = TRUE))
})

test_that("pretext/posttext render on every paged + continuous backend (#affixes)", {
  spec <- mk_affix_spec()
  for (ext in c("html", "tex", "rtf")) {
    f <- withr::local_tempfile(fileext = paste0(".", ext))
    emit(spec, f)
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_true(
      grepl("PFX Mean", txt, fixed = TRUE),
      label = paste(ext, "pretext")
    )
    expect_true(
      grepl("75.2 SFX", txt, fixed = TRUE),
      label = paste(ext, "posttext")
    )
  }
  # DOCX: assert against the unzipped document.xml.
  fz <- withr::local_tempfile(fileext = ".docx")
  emit(spec, fz)
  dir <- withr::local_tempdir()
  utils::unzip(fz, exdir = dir)
  docx <- paste(
    readLines(file.path(dir, "word", "document.xml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("PFX Mean", docx, fixed = TRUE))
  expect_true(grepl("75.2 SFX", docx, fixed = TRUE))
})

# ---------------------------------------------------------------------
# Engine-wave regression: subgroup merge (QC rows + column widths)
# ---------------------------------------------------------------------

test_that("subgroup merge keeps every subgroup's QC rows (#cw2)", {
  df <- data.frame(
    grp = c("F", "F", "M", "M"),
    stat = c("n", "Mean", "n", "Mean"),
    placebo = c("16", "1.2", "18", "2.4"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df) |>
    cols(
      grp = col_spec(),
      stat = col_spec(label = "Statistic"),
      placebo = col_spec(label = "Placebo")
    ) |>
    group_rows(by = "grp") |>
    subgroup("grp")
  g <- as_grid(spec)
  # the data_file QC snapshot must span ALL subgroups, not just the first
  expect_equal(nrow(g@metadata$data_cells_text), nrow(df))
})

test_that("subgroup merge widens a column to the widest subgroup (#cw2)", {
  df <- data.frame(
    grp = c("F", "F", "M", "M"),
    stat = c("n", "Mean", "n", "Mean"),
    val = c("1", "2", "3", "a very wide value indeed"),
    stringsAsFactors = FALSE
  )
  mk <- function(sub) {
    s <- tabular(df) |>
      cols(
        grp = col_spec(),
        stat = col_spec(label = "Statistic"),
        val = col_spec(label = "Value")
      ) |>
      group_rows(by = "grp")
    if (sub) {
      s <- subgroup(s, "grp")
    }
    s
  }
  w_sub <- as_grid(mk(TRUE))@metadata$cols$val@width
  w_flat <- as_grid(mk(FALSE))@metadata$cols$val@width
  # subgroup width must accommodate group M's wide value, matching the
  # flat table that measures all rows at once (not shrink to group F).
  expect_equal(w_sub, w_flat)
})

# ---------------------------------------------------------------------
# Empty-state placeholder (zero-row spec)
# ---------------------------------------------------------------------

test_that("zero-row spec stamps is_empty_page + empty_text_ast on the page", {
  g <- as_grid(tabular(data.frame(x = integer(0L), y = character(0L))))
  expect_length(g@pages, 1L)
  expect_true(isTRUE(g@pages[[1L]]$is_empty_page))
  # The message AST rides the metadata; each backend renders it as one centred
  # body row. No placement metadata: the message is always horizontally centred,
  # and there is no margin reservation (the message is a normal body row).
  expect_identical(
    g@metadata$empty_text_ast@runs[[1L]]$text,
    "No data available to report"
  )
  expect_null(g@metadata$empty_place)
  expect_null(g@metadata$empty_header_twips)
})

test_that("non-empty spec leaves is_empty_page unset", {
  g <- as_grid(tabular(data.frame(x = 1:2)))
  expect_null(g@pages[[1L]]$is_empty_page)
})

# ---------------------------------------------------------------------
# .drop_blank_separators — discardable group separators
# ---------------------------------------------------------------------

test_that(".drop_blank_separators drops plain blanks and rewires the keep mask", {
  txtm <- matrix(
    c("a", "", "b", "1", "", "2"),
    nrow = 3,
    dimnames = list(NULL, c("x", "y"))
  )
  src <- list(
    cells_text = txtm,
    is_header_row = c(FALSE, FALSE, FALSE),
    is_blank_row = c(FALSE, TRUE, FALSE),
    # Row 1 glued to the blank, blank NOT glued to row 3: after the
    # drop the glue must NOT jump the gap (glue-through is an AND).
    keep_with_next = c(TRUE, FALSE, FALSE)
  )
  out <- tabular:::.drop_blank_separators(src)
  expect_identical(nrow(out$src$cells_text), 2L)
  expect_identical(out$gap_before, 2L)
  expect_identical(out$src$keep_with_next, c(FALSE, FALSE))
  expect_identical(out$src$is_blank_row, c(FALSE, FALSE))

  # Fully glued edges DO glue through the dropped blank.
  src$keep_with_next <- c(TRUE, TRUE, FALSE)
  out2 <- tabular:::.drop_blank_separators(src)
  expect_identical(out2$src$keep_with_next, c(TRUE, FALSE))
})

test_that(".drop_blank_separators keeps styled blank rows", {
  txtm <- matrix(c("a", "", "1", ""), nrow = 2)
  styled <- tabular:::style_node(background = "#eeeeee")
  sty <- matrix(list(NULL, styled, NULL, styled), nrow = 2)
  src <- list(
    cells_text = txtm,
    cells_style = sty,
    is_blank_row = c(FALSE, TRUE)
  )
  out <- tabular:::.drop_blank_separators(src)
  expect_identical(nrow(out$src$cells_text), 2L)
  expect_identical(out$gap_before, integer(0))
})

test_that(".separator_gap_convertible reads the border manifest", {
  expect_true(tabular:::.separator_gap_convertible(NULL))
  expect_true(tabular:::.separator_gap_convertible(list(
    outer_top = list(style = "solid"),
    outer_bottom = list(style = "solid"),
    rows = NULL,
    cols = NULL
  )))
  expect_false(tabular:::.separator_gap_convertible(list(
    rows = list(style = "solid", width = 0.5, color = NA)
  )))
})

test_that(".drop_blank_separators folds a run of consecutive blanks", {
  txtm <- matrix(
    c("a", "", "", "b", "1", "", "", "2"),
    nrow = 4,
    dimnames = list(NULL, c("x", "y"))
  )
  src <- list(
    cells_text = txtm,
    is_blank_row = c(FALSE, TRUE, TRUE, FALSE)
  )
  out <- tabular:::.drop_blank_separators(src)
  expect_identical(nrow(out$src$cells_text), 2L)
  # One gap above the survivor after the run, not one per blank.
  expect_identical(out$gap_before, 2L)
})

test_that(".blank_row_is_plain skips non-style cells and flags borders", {
  bordered <- tabular:::style_node(border_bottom_style = "solid")
  # Cell 1 carries no style node (skipped), cell 2 a border: the row
  # is NOT plain even without a background fill.
  sty <- matrix(list(NULL, bordered), nrow = 1)
  expect_false(tabular:::.blank_row_is_plain(sty, 1L))
  # All cells styleless: plain.
  expect_true(tabular:::.blank_row_is_plain(
    matrix(list(NULL, NULL), nrow = 1),
    1L
  ))
})

test_that(".separator_gap_pt falls back to the 10 pt body size", {
  # No preset and no measurable padding: one 10 pt text line plus the
  # 2 pt default vertical padding on each side.
  expect_identical(
    tabular:::.separator_gap_pt(NULL, NULL),
    10 * tabular:::.tabular_baseline_ratio + 2 + 2
  )
})
