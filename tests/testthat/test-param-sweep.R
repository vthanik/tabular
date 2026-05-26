# test-param-sweep.R — parameter coverage sweep across the main
# user-facing verbs. For each parameter of each verb, this file
# walks the input space (every accepted enum value, length-0 / NULL,
# scalar / vector forms, valid edge cases) and verifies the verb
# accepts the value without error. Complements the per-verb
# semantic tests in test-<verb>.R: those check correctness of one
# scenario; this file checks input-space coverage for regressions
# in parameter validation and default handling.

# ---------------------------------------------------------------------
# col_spec() — every accepted parameter value
# ---------------------------------------------------------------------

test_that("col_spec() accepts every documented usage value", {
  for (u in c("display", "group")) {
    expect_silent(col_spec(usage = u))
  }
  expect_silent(col_spec(usage = NULL))
})

test_that("col_spec() accepts every documented align value", {
  for (a in c("left", "center", "right", "decimal")) {
    expect_silent(col_spec(align = a))
  }
  expect_silent(col_spec(align = NULL))
})

test_that("col_spec() accepts every documented valign value", {
  for (v in c("top", "middle", "bottom")) {
    expect_silent(col_spec(valign = v))
  }
  expect_silent(col_spec(valign = NULL))
})

test_that("col_spec() accepts visible TRUE / FALSE", {
  expect_silent(col_spec(visible = TRUE))
  expect_silent(col_spec(visible = FALSE))
})

test_that("col_spec() accepts width scalars and keyword 'auto'", {
  expect_silent(col_spec(width = "auto"))
  expect_silent(col_spec(width = 2))
  expect_silent(col_spec(width = "1.5in"))
  expect_silent(col_spec(width = "20%"))
})

test_that("col_spec() accepts label string, NA, and empty string", {
  expect_silent(col_spec(label = "Arm A"))
  expect_silent(col_spec(label = NA_character_))
  expect_silent(col_spec(label = ""))
})

test_that("col_spec() accepts na_text scalars including empty string", {
  expect_silent(col_spec(na_text = ""))
  expect_silent(col_spec(na_text = "-"))
  expect_silent(col_spec(na_text = "NA"))
})

# ---------------------------------------------------------------------
# brdr() — width keywords + numeric, style enums, color formats
# ---------------------------------------------------------------------

test_that("brdr() accepts every documented width keyword", {
  for (w in c("hairline", "thin", "medium", "thick")) {
    expect_silent(brdr(width = w))
  }
})

test_that("brdr() accepts numeric width including zero", {
  expect_silent(brdr(width = 0))
  expect_silent(brdr(width = 0.5))
  expect_silent(brdr(width = 2))
})

test_that("brdr() accepts every documented style value", {
  for (s in c("solid", "dashed", "dotted", "double", "dashdot", "none")) {
    expect_silent(brdr(style = s))
  }
})

test_that("brdr() accepts hex / CSS name / 'currentColor' colors", {
  expect_silent(brdr(color = "#000000"))
  expect_silent(brdr(color = "#abc"))
  expect_silent(brdr(color = "red"))
  expect_silent(brdr(color = "currentColor"))
})

# ---------------------------------------------------------------------
# preset_spec() — scalar enums + every named-list knob shape
# ---------------------------------------------------------------------

test_that("preset_spec() accepts every paper_size value", {
  for (p in c("letter", "a4")) {
    expect_silent(preset_spec(paper_size = p))
  }
})

test_that("preset_spec() accepts every orientation value", {
  for (o in c("portrait", "landscape")) {
    expect_silent(preset_spec(orientation = o))
  }
})

test_that("preset_spec() accepts every hlines value", {
  for (h in c("header", "none", "all")) {
    expect_silent(preset_spec(hlines = h))
  }
})

test_that("preset_spec() accepts every title_align / footnote_align value", {
  for (a in c("left", "center", "right")) {
    expect_silent(preset_spec(title_align = a, footnote_align = a))
  }
})

test_that("preset_spec() accepts margins length 1 / 2 / 4", {
  expect_silent(preset_spec(margins = 1))
  expect_silent(preset_spec(margins = c(1, 1.25)))
  expect_silent(preset_spec(margins = c(1, 1, 1, 1)))
  expect_silent(preset_spec(margins = "0.75in"))
})

# After the Task 4/5 slot cut, the five named-list knobs (alignment /
# borders / fonts / colors / padding) live only as `preset()` /
# `set_preset()` arguments — they lower to `style_layer` records on
# `preset@style` and never reach a `preset_spec` slot. The sweep
# tests below confirm `preset()` accepts every documented surface /
# region / token key end-to-end.

test_that("preset() alignment knob accepts every documented surface", {
  spec <- tabular(data.frame(x = 1))
  for (k in c(
    "title_halign",
    "footnote_halign",
    "subgroup_halign",
    "header_halign",
    "body_halign"
  )) {
    arg <- stats::setNames(list("center"), k)
    expect_silent(preset(spec, alignment = arg))
  }
  for (k in c(
    "title_valign",
    "footnote_valign",
    "subgroup_valign",
    "header_valign",
    "body_valign"
  )) {
    arg <- stats::setNames(list("middle"), k)
    expect_silent(preset(spec, alignment = arg))
  }
})

test_that("preset() borders knob accepts every region key", {
  spec <- tabular(data.frame(x = 1))
  region_keys <- c(
    "outer",
    "outer_top",
    "outer_bottom",
    "outer_left",
    "outer_right",
    "body_top",
    "body_bottom",
    "body_rows",
    "body_cols"
  )
  for (k in region_keys) {
    arg <- stats::setNames(list(brdr()), k)
    expect_silent(preset(spec, borders = arg))
  }
})

test_that("preset() borders knob accepts 'none' sentinel and NULL", {
  spec <- tabular(data.frame(x = 1))
  expect_silent(preset(spec, borders = list(outer = "none")))
  expect_silent(preset(spec, borders = list(outer = NULL)))
})

test_that("preset() fonts knob accepts every surface + sub-key", {
  spec <- tabular(data.frame(x = 1))
  for (s in c("body", "header", "titles", "footnotes", "subgroup")) {
    arg <- stats::setNames(
      list(list(family = "Inter", size = 9, weight = "normal")),
      s
    )
    expect_silent(preset(spec, fonts = arg))
  }
})

test_that("preset() colors knob accepts every surviving token key", {
  spec <- tabular(data.frame(x = 1))
  for (t in c("text", "background")) {
    arg <- stats::setNames(list("#212529"), t)
    expect_silent(preset(spec, colors = arg))
  }
})

test_that("preset() padding knob accepts uniform numeric + per-side", {
  spec <- tabular(data.frame(x = 1))
  for (s in c("body", "header", "titles", "footnotes", "subgroup")) {
    arg <- stats::setNames(list(3), s)
    expect_silent(preset(spec, padding = arg))
    arg2 <- stats::setNames(
      list(list(top = 2, right = 4, bottom = 2, left = 4)),
      s
    )
    expect_silent(preset(spec, padding = arg2))
  }
})

# ---------------------------------------------------------------------
# tabular() — titles / footnotes shapes
# ---------------------------------------------------------------------

test_that("tabular() accepts titles / footnotes of any length >= 0", {
  df <- data.frame(x = 1)
  expect_silent(tabular(df, titles = character()))
  expect_silent(tabular(df, titles = "Single title"))
  expect_silent(tabular(
    df,
    titles = c("Line 1", "Line 2", "Line 3", "Line 4")
  ))
  expect_silent(tabular(df, footnotes = character()))
  expect_silent(tabular(df, footnotes = paste("Footnote", 1:5)))
})

# ---------------------------------------------------------------------
# subgroup() — single var / multi var with label, by-clear path
# ---------------------------------------------------------------------

test_that("subgroup() accepts single var with default label", {
  df <- data.frame(g = c("A", "A", "B"), x = 1:3)
  expect_silent(tabular(df) |> subgroup("g"))
})

test_that("subgroup() accepts single var with explicit template label", {
  df <- data.frame(g = c("A", "A", "B"), x = 1:3)
  expect_silent(tabular(df) |> subgroup("g", label = "Group: {g}"))
})

test_that("subgroup() accepts multi var when a label is provided", {
  df <- data.frame(g = c("A", "A"), h = c("X", "Y"), x = 1:2)
  expect_silent(
    tabular(df) |> subgroup(c("g", "h"), label = "{g} / {h}")
  )
})

test_that("subgroup(by = character()) clears the partition", {
  df <- data.frame(g = c("A", "B"), x = 1:2)
  spec <- tabular(df) |> subgroup("g") |> subgroup(character())
  expect_null(spec@subgroup)
})

# ---------------------------------------------------------------------
# style() — every recognised attribute
# ---------------------------------------------------------------------

test_that("style() accepts every cells_body() filter shape", {
  df <- data.frame(x = 1:3)
  # `where = <pred>` predicate (replaces old .scope = "row" path)
  expect_silent(
    tabular(df) |> style(bold = TRUE, .at = cells_body(where = x == 1))
  )
  # `i = <int>` row index (covers numeric / integer rows)
  expect_silent(
    tabular(df) |> style(bold = TRUE, .at = cells_body(i = 1L))
  )
  # `j = <col>` column scoping
  expect_silent(
    tabular(df) |> style(bold = TRUE, .at = cells_body(j = "x"))
  )
})

test_that("style() accepts every bool attribute toggle", {
  df <- data.frame(x = 1:2)
  expect_silent(
    tabular(df) |> style(bold = TRUE, .at = cells_body(where = x == 1))
  )
  expect_silent(
    tabular(df) |> style(italic = TRUE, .at = cells_body(where = x == 1))
  )
  expect_silent(
    tabular(df) |> style(underline = TRUE, .at = cells_body(where = x == 1))
  )
})

test_that("style() accepts halign / valign enum values", {
  df <- data.frame(x = 1:2)
  # Per-cell halign is left / center / right only — decimal alignment is
  # a column-level surface that lives on col_spec via the engine_decimal
  # pre-padding phase and is not addressable per cell.
  for (h in c("left", "center", "right")) {
    expect_silent(
      tabular(df) |> style(halign = h, .at = cells_body(where = x == 1))
    )
  }
  for (v in c("top", "middle", "bottom")) {
    expect_silent(
      tabular(df) |> style(valign = v, .at = cells_body(where = x == 1))
    )
  }
})

test_that("style() accepts every border style attribute", {
  df <- data.frame(x = 1:2)
  loc <- cells_body(i = 1L) # built upfront; equivalent to where = x == 1
  for (side in c("top", "bottom", "left", "right")) {
    arg <- stats::setNames(list("solid"), paste0("border_", side, "_style"))
    expect_silent(do.call(
      style,
      c(list(tabular(df)), arg, list(.at = loc))
    ))
  }
})
