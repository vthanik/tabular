# headers() — verb that attaches a header tree to a tabular_spec.
# Covers all 8 plan edge cases (plus argument-shape errors).

# ---- happy path: flat band ------------------------------------------

test_that("headers() stores a flat-band tree of header_nodes", {
  spec <- tabular(saf_demo) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100", "Total"))
  expect_length(spec@headers, 1L)
  expect_true(is_header_node(spec@headers[[1]]))
  expect_identical(spec@headers[[1]]@label, "Arms")
  expect_identical(
    spec@headers[[1]]@span,
    c("placebo", "drug_50", "drug_100", "Total")
  )
})

# ---- happy path: nested -----------------------------------------------

test_that("headers() builds a nested tree from a named list value", {
  spec <- tabular(saf_demo) |>
    headers(
      "Treatment Group" = list(
        "Control" = "placebo",
        "Active" = c("drug_50", "drug_100")
      )
    )
  top <- spec@headers[[1]]
  expect_identical(top@label, "Treatment Group")
  expect_length(top@children, 2L)
  expect_identical(top@children[[1]]@label, "Control")
  expect_identical(top@children[[1]]@span, "placebo")
  expect_identical(top@children[[2]]@label, "Active")
  expect_identical(top@children[[2]]@span, c("drug_50", "drug_100"))
})

# ---- edge case 7: single column as "col" or c("col") -----------------

test_that("headers() accepts single column as bare string", {
  spec <- tabular(saf_demo) |> headers("Placebo arm" = "placebo")
  expect_identical(spec@headers[[1]]@span, "placebo")
})

test_that("headers() accepts single column as length-1 c()", {
  spec <- tabular(saf_demo) |> headers("Placebo arm" = c("placebo"))
  expect_identical(spec@headers[[1]]@span, "placebo")
})

# ---- edge case 5: header label contains \n ---------------------------

test_that("headers() accepts multi-line band labels via embedded \\n", {
  spec <- tabular(saf_demo) |>
    headers("Treatment\nGroup" = c("placebo", "drug_50", "drug_100", "Total"))
  expect_identical(spec@headers[[1]]@label, "Treatment\nGroup")
})

# ---- edge case 4: deep nesting --------------------------------------

test_that("headers() accepts arbitrary nesting depth", {
  spec <- tabular(saf_demo) |>
    headers(
      "L1" = list(
        "L2" = list(
          "L3" = list(
            "L4" = c("placebo", "drug_50", "drug_100", "Total")
          )
        )
      )
    )
  expect_identical(spec@headers[[1]]@label, "L1")
  expect_identical(spec@headers[[1]]@children[[1]]@label, "L2")
  expect_identical(
    spec@headers[[1]]@children[[1]]@children[[1]]@label,
    "L3"
  )
  expect_identical(
    spec@headers[[1]]@children[[1]]@children[[1]]@children[[1]]@label,
    "L4"
  )
})

# ---- edge case 6: repeat call replaces ------------------------------

test_that("headers() called twice replaces (does not stack)", {
  spec <- tabular(saf_demo) |>
    headers("First" = c("placebo", "drug_50")) |>
    headers("Second" = c("drug_100", "Total"))
  expect_length(spec@headers, 1L)
  expect_identical(spec@headers[[1]]@label, "Second")
})

test_that("headers() with zero arguments clears the tree", {
  spec <- tabular(saf_demo) |>
    headers("Arms" = c("placebo", "drug_50", "drug_100", "Total")) |>
    headers()
  expect_length(spec@headers, 0L)
})

# ---- edge case 3: columns not under any header ----------------------

test_that("headers() leaves uncovered columns alone (no error)", {
  spec <- tabular(saf_demo) |>
    headers("Arms" = c("placebo", "drug_50"))
  # variable, stat_label, drug_100, Total are not under a header --
  # accepted; they render without a band row.
  expect_identical(spec@headers[[1]]@span, c("placebo", "drug_50"))
})

# ---- edge case 1: band spans a column not in data -------------------

test_that("headers() errors when a band spans a missing column", {
  expect_error(
    tabular(saf_demo) |>
      headers("Arms" = c("placebo", "no_such_col")),
    class = "tabular_error_input"
  )
})

test_that("headers() error names the missing column", {
  err <- tryCatch(
    tabular(saf_demo) |>
      headers("Arms" = c("placebo", "phantom_arm")),
    tabular_error_input = function(e) e
  )
  expect_s3_class(err, "tabular_error_input")
  expect_match(conditionMessage(err), "phantom_arm")
})

# ---- edge case 2: same column under two bands -----------------------

test_that("headers() errors when a column appears under two bands", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Arms 1" = c("placebo", "drug_50"),
        "Arms 2" = c("drug_50", "drug_100")
      ),
    class = "tabular_error_input"
  )
})

# ---- argument-shape errors -----------------------------------------

test_that("headers() rejects non-spec first argument", {
  expect_error(
    headers(data.frame(x = 1), Arms = "x"),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects unnamed top-level argument", {
  expect_error(
    tabular(saf_demo) |> headers(c("placebo", "drug_50")),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects duplicate band labels in one call", {
  expect_error(
    tabular(saf_demo) |>
      headers("Arms" = "placebo", "Arms" = "drug_50"),
    class = "tabular_error_input"
  )
})

# ---- blank / NA / whitespace labels are rejected at every level ----

test_that("headers() rejects a whitespace-only top-level label", {
  bands <- setNames(list(c("placebo", "drug_50")), "   ")
  expect_error(
    do.call(headers, c(list(tabular(saf_demo)), bands)),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects an empty-string top-level label via splice", {
  bands <- setNames(list(c("placebo", "drug_50")), "")
  expect_error(
    do.call(headers, c(list(tabular(saf_demo)), bands)),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects a tab-only top-level label", {
  bands <- setNames(list(c("placebo", "drug_50")), "\t")
  expect_error(
    do.call(headers, c(list(tabular(saf_demo)), bands)),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects a whitespace-only child label", {
  expect_error(
    tabular(saf_demo) |>
      headers("Top" = setNames(list("placebo", "drug_50"), c("Active", " "))),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects an NA child label", {
  expect_error(
    tabular(saf_demo) |>
      headers("Top" = setNames(list("placebo", "drug_50"), c("Active", NA))),
    class = "tabular_error_input"
  )
})

# ---- passthrough leaves inside a nested list ------------------------
# Unnamed character entries are accepted: they declare leaves
# directly under the parent band with no intermediate label.

test_that("headers() accepts an unnamed character vector as passthrough leaves", {
  spec <- tabular(saf_demo) |>
    headers(
      "Treatment Active" = list(
        "Treatment Low" = c("placebo", "drug_100"),
        "drug_50"
      )
    )
  top <- spec@headers[[1]]
  expect_length(top@children, 2L)
  # Child 1: declared sub-band
  expect_identical(top@children[[1]]@label, "Treatment Low")
  expect_identical(top@children[[1]]@span, c("placebo", "drug_100"))
  # Child 2: passthrough leaf — label = NA, span = the unnamed vector
  expect_true(is.na(top@children[[2]]@label))
  expect_identical(top@children[[2]]@span, "drug_50")
})

test_that("headers() passthrough accepts multi-column unnamed vectors", {
  spec <- tabular(saf_demo) |>
    headers(
      "Top" = list(
        "Inner" = "placebo",
        c("drug_100", "drug_50")
      )
    )
  expect_identical(
    spec@headers[[1]]@children[[2]]@span,
    c("drug_100", "drug_50")
  )
  expect_true(is.na(spec@headers[[1]]@children[[2]]@label))
})

test_that("headers() passthrough validates that columns exist in data", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Top" = list(
          "Inner" = "placebo",
          "no_such_col"
        )
      ),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects an unnamed nested list (no label, but is a list)", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Top" = list(
          list("X" = "placebo")
        )
      ),
    class = "tabular_error_input"
  )
})

test_that("headers() passthrough rejects NA inside the column vector", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Top" = list(
          "Inner" = "placebo",
          c("drug_50", NA)
        )
      ),
    class = "tabular_error_input"
  )
})

test_that("headers() catches duplicate columns across passthrough and named child", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Top" = list(
          "Inner" = c("placebo", "drug_50"),
          "drug_50"
        )
      ),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects duplicate child labels inside a nested list", {
  expect_error(
    tabular(saf_demo) |>
      headers(
        "Top" = list("A" = "placebo", "A" = "drug_50")
      ),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects non-character non-list values", {
  expect_error(
    tabular(saf_demo) |> headers("Arms" = 1:3),
    class = "tabular_error_input"
  )
})

test_that("headers() rejects NA in a span vector", {
  expect_error(
    tabular(saf_demo) |> headers("Arms" = c("placebo", NA)),
    class = "tabular_error_input"
  )
})

# ---- snapshot for error message coherence ---------------------------

test_that("headers() error snapshots", {
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |>
      headers("Arms" = c("placebo", "phantom_arm"))
  )
  expect_snapshot(
    error = TRUE,
    tabular(saf_demo) |>
      headers(
        "Arms 1" = c("placebo", "drug_50"),
        "Arms 2" = c("drug_50", "drug_100")
      )
  )
})
