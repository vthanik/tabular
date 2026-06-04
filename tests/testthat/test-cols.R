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
