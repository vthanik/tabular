# test-preset-lowering.R — .preset_args_to_layers() lowering helper
# that converts the five named-list preset() / set_preset() args
# (alignment, borders, fonts, colors, padding) into style_layer
# records flowing through the unified engine cascade.

# ---------------------------------------------------------------------
# alignment
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() lowers alignment$title_halign to cells_title()", {
  layers <- tabular:::.preset_args_to_layers(list(
    alignment = list(title_halign = "left")
  ))
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]@location$surface, "title")
  expect_identical(layers[[1L]]@style@halign, "left")
})

test_that(".preset_args_to_layers() routes every alignment key to its surface", {
  layers <- tabular:::.preset_args_to_layers(list(
    alignment = list(
      title_halign = "left",
      footnote_halign = "right",
      subgroup_halign = "center",
      header_halign = "left",
      body_halign = "right",
      title_valign = "top",
      footnote_valign = "bottom",
      body_valign = "middle"
    )
  ))
  surfaces <- vapply(layers, function(l) l@location$surface, character(1L))
  expect_in(
    surfaces,
    c("title", "footnotes", "subgroup_labels", "headers", "body")
  )
})

test_that(".preset_args_to_layers() drops vector-form alignment values", {
  # chrome_style$surfaces carries a SCALAR halign / valign so vector
  # form can't lower without losing the per-line semantics. The
  # legacy preset@alignment slot keeps vector form alive while the
  # lowered set stays scalar-only.
  layers <- tabular:::.preset_args_to_layers(list(
    alignment = list(title_halign = c("left", "right"))
  ))
  expect_identical(layers, list())
})

# ---------------------------------------------------------------------
# borders — body regions are deliberately NOT lowered yet (see
# .preset_borders_to_layers comment). Confirm the helper skips them.
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() skips body border regions (outer / body_*)", {
  layers <- tabular:::.preset_args_to_layers(list(
    borders = list(
      outer = brdr("thin"),
      outer_top = brdr("medium"),
      body_top = brdr(),
      body_bottom = brdr(),
      body_rows = brdr("hairline"),
      body_cols = brdr("thin")
    )
  ))
  expect_identical(layers, list())
})

# ---------------------------------------------------------------------
# borders — chrome regions
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() maps chrome border regions to cells_<surface>()", {
  layers <- tabular:::.preset_args_to_layers(list(
    borders = list(
      header_top = brdr("medium"),
      header_bottom = brdr(),
      subgroup_top = brdr("thin"),
      footer_top = brdr("hairline"),
      pagehead_bottom = brdr(),
      pagefoot_top = brdr()
    )
  ))
  surfaces <- vapply(layers, function(l) l@location$surface, character(1L))
  expect_setequal(
    surfaces,
    c("headers", "subgroup_labels", "footnotes", "pagehead", "pagefoot")
  )
})

test_that(".preset_args_to_layers() treats borders$subgroup as subgroup_bottom alias", {
  layers <- tabular:::.preset_args_to_layers(list(
    borders = list(subgroup = brdr("medium"))
  ))
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]@location$surface, "subgroup_labels")
  expect_identical(layers[[1L]]@style@border_bottom_style, "solid")
})

# ---------------------------------------------------------------------
# fonts
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() splits fonts$body family + size into separate layers", {
  layers <- tabular:::.preset_args_to_layers(list(
    fonts = list(body = list(family = "Inter", size = 10))
  ))
  expect_length(layers, 2L)
  fams <- vapply(
    layers,
    function(l) as.character(l@style@font_family),
    character(1L)
  )
  expect_true("Inter" %in% fams)
  sizes <- vapply(
    layers,
    function(l) {
      v <- l@style@font_size
      if (is.na(v)) NA_real_ else v
    },
    numeric(1L)
  )
  expect_true(10 %in% sizes)
})

test_that(".preset_args_to_layers() lowers fonts$header to cells_headers()", {
  layers <- tabular:::.preset_args_to_layers(list(
    fonts = list(header = list(size = 11))
  ))
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]@location$surface, "headers")
  expect_identical(layers[[1L]]@style@font_size, 11)
})

test_that(".preset_args_to_layers() lowers fonts weight='bold' to bold=TRUE", {
  layers <- tabular:::.preset_args_to_layers(list(
    fonts = list(header = list(weight = "bold"))
  ))
  expect_length(layers, 1L)
  expect_true(isTRUE(layers[[1L]]@style@bold))
})

# ---------------------------------------------------------------------
# colors
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() lowers colors$text / $background to cells_body()", {
  layers <- tabular:::.preset_args_to_layers(list(
    colors = list(text = "#ff0000", background = "#eeeeee")
  ))
  expect_length(layers, 2L)
  surfaces <- vapply(layers, function(l) l@location$surface, character(1L))
  expect_true(all(surfaces == "body"))
})

test_that(".preset_args_to_layers() skips colors$border / $border_muted (body region)", {
  layers <- tabular:::.preset_args_to_layers(list(
    colors = list(border = "#212529", border_muted = "#dee2e6")
  ))
  expect_identical(layers, list())
})

# ---------------------------------------------------------------------
# padding
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() lowers padding[body] scalar to cells_body()", {
  layers <- tabular:::.preset_args_to_layers(list(
    padding = list(body = 5)
  ))
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]@location$surface, "body")
  expect_identical(layers[[1L]]@style@padding, 5)
})

test_that(".preset_args_to_layers() collapses per-side padding to the mean", {
  layers <- tabular:::.preset_args_to_layers(list(
    padding = list(body = list(top = 2, right = 4, bottom = 2, left = 4))
  ))
  expect_length(layers, 1L)
  expect_identical(layers[[1L]]@style@padding, 3)
})

test_that(".preset_args_to_layers() routes padding to every recognised surface", {
  layers <- tabular:::.preset_args_to_layers(list(
    padding = list(
      body = 1,
      header = 2,
      titles = 3,
      footnotes = 4,
      subgroup = 5
    )
  ))
  surfaces <- vapply(layers, function(l) l@location$surface, character(1L))
  expect_setequal(
    surfaces,
    c("body", "headers", "title", "footnotes", "subgroup_labels")
  )
})

# ---------------------------------------------------------------------
# Empty / no-op inputs
# ---------------------------------------------------------------------

test_that(".preset_args_to_layers() returns an empty list for NULL / empty args", {
  expect_identical(tabular:::.preset_args_to_layers(list()), list())
  expect_identical(
    tabular:::.preset_args_to_layers(list(
      alignment = NULL,
      borders = list(),
      fonts = list(),
      colors = list(),
      padding = list()
    )),
    list()
  )
})

test_that(".preset_args_to_layers() skips unknown surfaces silently", {
  layers <- tabular:::.preset_args_to_layers(list(
    fonts = list(banner = list(family = "Inter"))
  ))
  expect_identical(layers, list())
})

test_that(".preset_args_to_layers() drops NA values without producing a layer", {
  layers <- tabular:::.preset_args_to_layers(list(
    alignment = list(body_halign = NA_character_),
    fonts = list(body = list(family = NA_character_, size = NA_real_))
  ))
  expect_identical(layers, list())
})

# ---------------------------------------------------------------------
# Defensive branches — direct sub-helper calls covering inputs the
# upstream `.preset_args_to_layers()` dispatch already filters out
# (NULL / non-list / unknown surface). Each sub-helper is `tabular:::`
# accessible so the defensive arms are reachable from tests.
# ---------------------------------------------------------------------

test_that(".preset_alignment_args_lowerable() returns input unchanged when not a list", {
  expect_identical(
    tabular:::.preset_alignment_args_lowerable("nope"),
    "nope"
  )
})

test_that(".preset_alignment_to_layers() returns empty list for non-list input", {
  expect_identical(tabular:::.preset_alignment_to_layers("nope"), list())
})

test_that(".preset_borders_to_layers() returns empty list for non-list input", {
  expect_identical(tabular:::.preset_borders_to_layers("nope"), list())
})

test_that(".preset_fonts_to_layers() returns empty list for non-list input", {
  expect_identical(tabular:::.preset_fonts_to_layers("nope"), list())
})

test_that(".preset_fonts_to_layers() skips NULL / non-list per-surface specs", {
  layers <- tabular:::.preset_fonts_to_layers(list(
    body = NULL,
    header = "not a list"
  ))
  expect_identical(layers, list())
})

test_that(".preset_colors_to_layers() returns empty list for non-list input", {
  expect_identical(tabular:::.preset_colors_to_layers("nope"), list())
})

test_that(".preset_padding_to_layers() returns empty list for non-list input", {
  expect_identical(tabular:::.preset_padding_to_layers("nope"), list())
})

test_that(".preset_padding_to_layers() skips NULL / unknown-surface padding values", {
  layers <- tabular:::.preset_padding_to_layers(list(
    body = NULL,
    banner = 5
  ))
  expect_identical(layers, list())
})

test_that(".preset_layer_one() returns NULL for NULL location / value", {
  expect_null(tabular:::.preset_layer_one(NULL, "color", "#000"))
  expect_null(tabular:::.preset_layer_one(cells_body(), "color", NULL))
})

test_that(".preset_layer_border() returns NULL for NULL location / triple", {
  expect_null(tabular:::.preset_layer_border(NULL, "top", NULL))
  expect_null(tabular:::.preset_layer_border(
    cells_table(side = "outer_top"),
    "top",
    NULL
  ))
})

# ---------------------------------------------------------------------
# Wired through set_preset() — the session-default flow mirrors the
# per-spec preset() lowering. Verify the session preset's @style list
# accumulates lowered layers and rolls back on reset.
# ---------------------------------------------------------------------

test_that("set_preset() lowers named-list knobs onto the session-default @style", {
  withr::defer(set_preset(reset = TRUE))
  set_preset(
    alignment = list(title_halign = "left"),
    fonts = list(body = list(family = "Inter"))
  )
  session <- get_preset()
  expect_true(length(session@style) >= 2L)
  surfaces <- vapply(
    session@style,
    function(l) l@location$surface,
    character(1L)
  )
  expect_in("title", surfaces)
  expect_in("body", surfaces)
})

test_that("set_preset(reset = TRUE) clears lowered layers along with the session default", {
  withr::defer(set_preset(reset = TRUE))
  set_preset(alignment = list(title_halign = "left"))
  expect_true(length(get_preset()@style) >= 1L)
  set_preset(reset = TRUE)
  expect_null(get_preset())
})
