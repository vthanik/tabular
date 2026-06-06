# cols() variadic per-column DSL: 11 edge cases from plan 2.2 plus
# the merge-semantics tests for repeated cols() calls.

mk_spec <- function() {
  tabular(data.frame(
    param = c("Age", "Sex"),
    drug_a = c("60", "30"),
    drug_b = c("62", "28"),
    stringsAsFactors = FALSE
  ))
}

# Happy path -----------------------------------------------------------

test_that("cols() attaches col_specs keyed by input name", {
  s <- mk_spec() |>
    cols(
      param = col_spec(usage = "group", label = "Parameter"),
      drug_a = col_spec(label = "Drug A", align = "decimal")
    )
  expect_named(s@cols, c("param", "drug_a"))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$param@name, "param")
  expect_identical(s@cols$drug_a@align, "decimal")
  expect_identical(s@cols$drug_a@name, "drug_a")
})

# Edge case 1: name not in data — reject ------------------------------

test_that("cols() rejects a name not in data", {
  expect_error(
    mk_spec() |> cols(missing_col = col_spec(usage = "display")),
    class = "tabular_error_input"
  )
})

# Edge case 2: empty ... is a no-op ------------------------------------

test_that("cols() with no args returns the spec unchanged", {
  s0 <- mk_spec()
  s1 <- cols(s0)
  expect_identical(s1@cols, s0@cols)
  expect_length(s1@cols, 0L)
})

# Edge case 3: duplicate name in same call — warn, last wins ----------

test_that("cols() warns on duplicate names and keeps the last", {
  expect_warning(
    s <- mk_spec() |>
      cols(
        param = col_spec(label = "First"),
        param = col_spec(label = "Second")
      ),
    "duplicate"
  )
  expect_identical(s@cols$param@label, "Second")
})

# Edge case 4: missing column gets no entry (engine_validate later) ----

test_that("cols() leaves un-mentioned columns out of @cols", {
  s <- mk_spec() |> cols(param = col_spec(usage = "group"))
  expect_named(s@cols, "param")
  expect_false("drug_a" %in% names(s@cols))
})

# Edge case 5: repeat cols() merges field-by-field ---------------------

test_that("cols() merges across two calls (non-default wins)", {
  s <- mk_spec() |>
    cols(param = col_spec(usage = "group", label = "Parameter")) |>
    cols(param = col_spec(width = 1.5))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$param@label, "Parameter")
  expect_identical(s@cols$param@width, 1.5)
})

test_that("a later default width = \"auto\" leaves a pinned width intact (#width-sentinel)", {
  # "auto" is the merge sentinel: a later cols()/cols_apply() carrying the
  # default width must not reset a previously pinned width.
  s <- mk_spec() |>
    cols(param = col_spec(width = 2.0)) |>
    cols(param = col_spec(align = "left")) # width defaults to "auto"
  expect_identical(s@cols$param@width, 2.0)
  expect_identical(s@cols$param@width_user, 2.0)
})

test_that("cols() second-call default does not erase first-call non-default", {
  s <- mk_spec() |>
    cols(param = col_spec(label = "Parameter")) |>
    cols(param = col_spec(usage = "group"))
  expect_identical(s@cols$param@label, "Parameter")
  expect_identical(s@cols$param@usage, "group")
})

test_that("cols() second-call non-default overrides first-call", {
  s <- mk_spec() |>
    cols(param = col_spec(label = "Old")) |>
    cols(param = col_spec(label = "New"))
  expect_identical(s@cols$param@label, "New")
})

# Edge case 8: across with high cardinality — not checked here --------
# That check belongs to engine_validate (not cols()).

# Edge case 9: malformed sprintf — already caught by col_spec() -------
# Engine doesn't see it. Covered in test-col_spec.R.

# Edge case 10: width <= 0 — caught at col_spec() ---------------------
# Covered in test-col_spec.R.

# Spec input validation ------------------------------------------------

test_that("cols() rejects non-spec first argument", {
  expect_error(
    cols(list(), param = col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects unnamed entries", {
  expect_error(
    mk_spec() |> cols(col_spec(usage = "group")),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects partially named entries", {
  expect_error(
    mk_spec() |> cols(param = col_spec(), col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols() rejects non-col_spec values", {
  expect_error(
    mk_spec() |> cols(param = "not a spec"),
    class = "tabular_error_input"
  )
})

# Merge: format / visible / align / na_text ----------------------------

test_that("cols() merges format (non-NULL second call overrides)", {
  fn <- function(x) format(x, nsmall = 2)
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(format = fn))
  expect_identical(s@cols$drug_a@format, fn)
  expect_identical(s@cols$drug_a@label, "Drug A")
})

test_that("cols() merges format = NULL leaves prior format alone", {
  fn <- function(x) format(x, nsmall = 2)
  s <- mk_spec() |>
    cols(drug_a = col_spec(format = fn)) |>
    cols(drug_a = col_spec(label = "Drug A"))
  expect_identical(s@cols$drug_a@format, fn)
  expect_identical(s@cols$drug_a@label, "Drug A")
})

test_that("cols() merges visible = FALSE (non-default overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(visible = FALSE))
  expect_false(s@cols$drug_a@visible)
})

test_that("cols() merges align (non-NA overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(align = "right")) |>
    cols(drug_a = col_spec(align = "decimal"))
  expect_identical(s@cols$drug_a@align, "decimal")
})

test_that("cols() merges na_text (non-empty second call overrides)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(label = "Drug A")) |>
    cols(drug_a = col_spec(na_text = "-"))
  expect_identical(s@cols$drug_a@na_text, "-")
})

# F2 — lossless merge: a meaningful default can now be merged back -----

test_that("cols() can RE-SHOW a hidden column on a later call (#F2)", {
  # visible = FALSE then visible = TRUE was impossible before NA-unset.
  s <- mk_spec() |>
    cols(drug_a = col_spec(visible = FALSE)) |>
    cols(drug_a = col_spec(visible = TRUE))
  expect_true(s@cols$drug_a@visible)
})

test_that("cols() can RESET group_display to header_row on a later call (#F2)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(usage = "group", group_display = "column")) |>
    cols(drug_a = col_spec(group_display = "header_row"))
  expect_identical(s@cols$drug_a@group_display, "header_row")
})

test_that("cols() default visible/group_display do NOT clobber prior values (#F2)", {
  # A later call carrying the unset (NA) defaults leaves prior explicit
  # values intact.
  s <- mk_spec() |>
    cols(
      drug_a = col_spec(
        visible = FALSE,
        group_display = "column",
        usage = "group"
      )
    ) |>
    cols(drug_a = col_spec(label = "Drug A"))
  expect_false(s@cols$drug_a@visible)
  expect_identical(s@cols$drug_a@group_display, "column")
})

# F4 — one encoding of "display" --------------------------------------

test_that("a bare col_spec() finalizes to display / visible / header_row (#F4)", {
  fin <- tabular:::.finalize_col_spec(col_spec())
  expect_identical(fin@usage, "display")
  expect_true(fin@visible)
  expect_identical(fin@group_display, "header_row")
})

test_that("explicit usage = 'display' overrides a prior usage = 'group' on merge (#F4)", {
  s <- mk_spec() |>
    cols(drug_a = col_spec(usage = "group")) |>
    cols(drug_a = col_spec(usage = "display"))
  expect_identical(s@cols$drug_a@usage, "display")
})

test_that("a default col_spec() and the explicit concrete spec render identically (#F2)", {
  # Finalize parity: NA-unset resolves to exactly the old concrete
  # defaults, so the two specs produce byte-identical output.
  bare <- mk_spec() |> cols(drug_a = col_spec(label = "Drug A"))
  explicit <- mk_spec() |>
    cols(
      drug_a = col_spec(
        label = "Drug A",
        visible = TRUE,
        group_display = "header_row",
        usage = "display"
      )
    )
  f1 <- withr::local_tempfile(fileext = ".md")
  f2 <- withr::local_tempfile(fileext = ".md")
  emit(bare, f1)
  emit(explicit, f2)
  expect_identical(readLines(f1, warn = FALSE), readLines(f2, warn = FALSE))
})

# Dynamic names: rlang `:=` and `!!!` splice --------------------------
# Programmatic column names (built from a variable, looped, or spliced
# from a list) must work the way they do in dplyr. Regression for the
# bare `list(...)` capture that swallowed injection operators.

test_that("cols() accepts a dynamic name via :=", {
  nm <- "drug_a"
  s <- mk_spec() |> cols(!!nm := col_spec(label = "Programmatic"))
  expect_identical(s@cols$drug_a@label, "Programmatic")
  expect_identical(s@cols$drug_a@name, "drug_a")
})

test_that("cols() accepts a named list spliced with !!!", {
  specs <- list(
    param = col_spec(usage = "group"),
    drug_a = col_spec(label = "A")
  )
  s <- mk_spec() |> cols(!!!specs)
  expect_named(s@cols, c("param", "drug_a"))
  expect_identical(s@cols$param@usage, "group")
  expect_identical(s@cols$drug_a@label, "A")
})

test_that("cols() still rejects an unnamed !!! splice", {
  expect_error(
    mk_spec() |> cols(!!!list(col_spec(usage = "group"))),
    class = "tabular_error_input"
  )
})

# E1: cols_apply() — one col_spec to many columns --------------------

mk_arms_spec <- function() {
  tabular(data.frame(
    param = c("Age", "Sex"),
    ARM_A = c("60", "30"),
    ARM_B = c("62", "28"),
    ARM_C = c("59", "31"),
    stringsAsFactors = FALSE
  ))
}

test_that("cols_apply() applies a col_spec to each named column (#E1)", {
  arm_cols <- c("ARM_A", "ARM_B", "ARM_C")
  s <- mk_arms_spec() |>
    cols_apply(arm_cols, col_spec(align = "decimal"))
  expect_named(s@cols, arm_cols)
  for (nm in arm_cols) {
    expect_identical(s@cols[[nm]]@align, "decimal")
    expect_identical(s@cols[[nm]]@name, nm)
  }
})

test_that("cols_apply() accepts a predicate over data column names (#E1)", {
  s <- mk_arms_spec() |>
    cols_apply(\(nm) startsWith(nm, "ARM_"), col_spec(align = "decimal"))
  expect_named(s@cols, c("ARM_A", "ARM_B", "ARM_C"))
  expect_identical(s@cols$ARM_A@align, "decimal")
  expect_false("param" %in% names(s@cols))
})

test_that("cols_apply() errors on a non-existent column (#E1)", {
  expect_error(
    mk_arms_spec() |>
      cols_apply(c("ARM_A", "nope"), col_spec(align = "decimal")),
    class = "tabular_error_input"
  )
})

test_that("cols_apply() field-merges into an existing spec (#E1)", {
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "Arm A")) |>
    cols_apply(c("ARM_A", "ARM_B"), col_spec(align = "decimal"))
  # Existing label preserved, new align merged in.
  expect_identical(s@cols$ARM_A@label, "Arm A")
  expect_identical(s@cols$ARM_A@align, "decimal")
  expect_identical(s@cols$ARM_B@align, "decimal")
})

test_that("cols_apply() rejects a non-tabular_spec (#E1)", {
  expect_error(
    cols_apply("not a spec", "ARM_A", col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols_apply() rejects a non-col_spec .col_spec (#E1)", {
  expect_error(
    mk_arms_spec() |> cols_apply("ARM_A", "not a col_spec"),
    class = "tabular_error_input"
  )
})

test_that("cols_apply() rejects a predicate returning non-logical (#E1)", {
  expect_error(
    mk_arms_spec() |> cols_apply(\(nm) nm, col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols_apply() rejects a predicate returning wrong length (#E1)", {
  expect_error(
    mk_arms_spec() |> cols_apply(\(nm) c(TRUE, FALSE), col_spec()),
    class = "tabular_error_input"
  )
})

test_that("cols_apply() merges valign/group_display/width onto an existing spec (#review)", {
  # .merge_col_spec previously copied only 9 of col_spec's fields, silently
  # dropping valign / group_display / group_skip / width_user on merge, so
  # cols_apply()'s 'non-default field overrides' contract failed for them.
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "Arm A")) |>
    cols_apply(
      "ARM_A",
      col_spec(valign = "top", group_display = "column", width = "40%")
    )
  expect_identical(s@cols$ARM_A@label, "Arm A") # existing kept
  expect_identical(s@cols$ARM_A@valign, "top") # override applied
  expect_identical(s@cols$ARM_A@group_display, "column")
  expect_identical(s@cols$ARM_A@width, "40%")
  # width_user must track width so the HTML percent-width path stays right.
  expect_identical(s@cols$ARM_A@width_user, "40%")
})

test_that("cols_apply() warns and no-ops when a predicate matches nothing (#review)", {
  expect_warning(
    s <- mk_arms_spec() |>
      cols_apply(\(nm) startsWith(nm, "ZZZ"), col_spec(align = "decimal")),
    "matched no columns"
  )
  expect_length(s@cols, 0L)
})

# E2: cols(.default = ) ----------------------------------------------

test_that("cols(.default=) applies to unmentioned columns (#E2)", {
  s <- mk_arms_spec() |>
    cols(
      param = col_spec(usage = "group", label = "Parameter"),
      .default = col_spec(align = "decimal")
    )
  # Explicit spec wins for `param`.
  expect_identical(s@cols$param@usage, "group")
  expect_true(is.na(s@cols$param@align))
  # Default applies to every unmentioned data column.
  for (nm in c("ARM_A", "ARM_B", "ARM_C")) {
    expect_identical(s@cols[[nm]]@align, "decimal")
    expect_identical(s@cols[[nm]]@name, nm)
  }
})

test_that("cols(.default=) skips columns already carrying a spec (#E2)", {
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "Arm A")) |>
    cols(.default = col_spec(align = "decimal"))
  # ARM_A already had a spec from a prior cols() call: default does
  # not touch it (label kept, no align applied).
  expect_identical(s@cols$ARM_A@label, "Arm A")
  expect_true(is.na(s@cols$ARM_A@align))
  # param/ARM_B/ARM_C had no spec: they get the default fresh.
  expect_identical(s@cols$param@align, "decimal")
  expect_identical(s@cols$ARM_B@align, "decimal")
})

test_that("cols(.default=) rejects a non-col_spec (#E2)", {
  expect_error(
    mk_arms_spec() |> cols(.default = "nope"),
    class = "tabular_error_input"
  )
})

test_that("cols(.default = NULL) is the current behaviour (#E2)", {
  s <- mk_arms_spec() |>
    cols(param = col_spec(usage = "group"), .default = NULL)
  expect_named(s@cols, "param")
})

# Per-column {.name} / {.col} label token (cols_apply + cols) ---------

test_that("cols_apply() resolves {.name} to each matched column (#token)", {
  n <- c(ARM_A = 30L, ARM_B = 28L, ARM_C = 31L)
  s <- mk_arms_spec() |>
    cols_apply(
      c("ARM_A", "ARM_B", "ARM_C"),
      col_spec(label = "{.name}\n(N={n[.name]})", align = "decimal")
    )
  expect_identical(s@cols$ARM_A@label, "ARM_A\n(N=30)")
  expect_identical(s@cols$ARM_B@label, "ARM_B\n(N=28)")
  expect_identical(s@cols$ARM_C@label, "ARM_C\n(N=31)")
  # The deferral flag is always cleared once stamped.
  expect_false(s@cols$ARM_A@label_deferred)
  # The shared non-default field still merges as before.
  expect_identical(s@cols$ARM_A@align, "decimal")
})

test_that("{.col} is an alias for {.name} (#token)", {
  s <- mk_arms_spec() |>
    cols_apply(c("ARM_A", "ARM_B"), col_spec(label = "Arm {.col}"))
  expect_identical(s@cols$ARM_A@label, "Arm ARM_A")
  expect_identical(s@cols$ARM_B@label, "Arm ARM_B")
})

test_that("the token resolves through a plain cols() named arg too (#token)", {
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "{.name} group"))
  expect_identical(s@cols$ARM_A@label, "ARM_A group")
  expect_false(s@cols$ARM_A@label_deferred)
})

test_that("the token resolves through cols(.default=) (#token)", {
  s <- mk_arms_spec() |>
    cols(
      param = col_spec(usage = "group"),
      .default = col_spec(label = "col:{.name}")
    )
  expect_identical(s@cols$ARM_A@label, "col:ARM_A")
  expect_identical(s@cols$ARM_C@label, "col:ARM_C")
})

test_that("a label with no brace is byte-identical and never deferred (#token)", {
  s <- mk_arms_spec() |>
    cols_apply(c("ARM_A"), col_spec(label = "Plain Label"))
  expect_identical(s@cols$ARM_A@label, "Plain Label")
  expect_false(s@cols$ARM_A@label_deferred)
})

test_that("an eager (non-.name) token still interpolates at col_spec() (#token)", {
  total <- 91L
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "Total (N={total})"))
  expect_identical(s@cols$ARM_A@label, "Total (N=91)")
  expect_false(s@cols$ARM_A@label_deferred)
})

test_that("doubled braces stay literal and do not defer (#token)", {
  s <- mk_arms_spec() |>
    cols(ARM_A = col_spec(label = "{{.name}}"))
  expect_identical(s@cols$ARM_A@label, "{.name}")
  expect_false(s@cols$ARM_A@label_deferred)
})

test_that("a failing token expression names the column and is tabular_error_input (#token)", {
  expect_error(
    mk_arms_spec() |>
      cols_apply(c("ARM_A"), col_spec(label = "{NOPE[.name]}")),
    class = "tabular_error_input"
  )
  err <- tryCatch(
    mk_arms_spec() |>
      cols_apply(c("ARM_A"), col_spec(label = "{NOPE[.name]}")),
    tabular_error_input = function(e) conditionMessage(e)
  )
  expect_match(err, "ARM_A")
})

test_that("a malformed brace label still raises the eager parse error (#token)", {
  # The deferral scan fails on the unterminated brace and falls back to
  # the eager interpolation path, which raises the real parse error.
  expect_error(
    col_spec(label = "{.name"),
    class = "tabular_error_input"
  )
})

test_that("an unmatched cols_apply() selection still warns with a deferred label (#token)", {
  expect_warning(
    s <- mk_arms_spec() |>
      cols_apply(\(nm) startsWith(nm, "ZZZ"), col_spec(label = "{.name}")),
    "matched no columns"
  )
  expect_length(s@cols, 0L)
})

test_that("a resolved {.name} label reaches every backend (HTML and RTF) (#token)", {
  n <- c(ARM_A = 30L, ARM_B = 28L, ARM_C = 31L)
  spec <- mk_arms_spec() |>
    cols(param = col_spec(usage = "group", label = "Parameter")) |>
    cols_apply(
      c("ARM_A", "ARM_B", "ARM_C"),
      col_spec(label = "{.name} (N={n[.name]})", align = "decimal")
    )

  html <- emit(spec, tempfile(fileext = ".html"))
  html_txt <- paste(readLines(html, warn = FALSE), collapse = "\n")
  expect_match(html_txt, "ARM_A (N=30)", fixed = TRUE)
  expect_match(html_txt, "ARM_C (N=31)", fixed = TRUE)

  rtf <- emit(spec, tempfile(fileext = ".rtf"))
  rtf_txt <- paste(readLines(rtf, warn = FALSE), collapse = "\n")
  # RTF escapes the parens as literal text; the N value is what matters.
  expect_match(rtf_txt, "ARM_A", fixed = TRUE)
  expect_match(rtf_txt, "N=30", fixed = TRUE)
})
