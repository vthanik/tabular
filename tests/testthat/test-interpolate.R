# Tests for the glue-style `{expr}` interpolation helper (R/interpolate.R)
# and its wiring into col_spec / tabular / headers / footnote.

# Helper: interpolate a scalar against the caller's environment.
interp <- function(x, env = parent.frame()) {
  tabular:::.interpolate(x, env = env, call = rlang::caller_env())
}

# ---------------------------------------------------------------------
# Scanner / scalar happy paths
# ---------------------------------------------------------------------

test_that("plain strings pass through unchanged (fast path)", {
  x <- "Safety Population"
  expect_identical(interp(x), x)
  expect_identical(interp(""), "")
})

test_that("a single interpolation is evaluated", {
  n <- 42L
  expect_identical(interp("N={n}"), "N=42")
})

test_that("multiple interpolations in one string", {
  a <- "1"
  b <- "2"
  expect_identical(interp("{a}-{b}"), "1-2")
  expect_identical(interp("Table {a} of {b} done"), "Table 1 of 2 done")
})

test_that("doubled braces are literal", {
  x <- 99
  expect_identical(interp("a{{b"), "a{b")
  expect_identical(interp("a}}b"), "a}b")
  expect_identical(interp("{{x}}"), "{x}")
  # `{{{x}}}` -> literal "{" + eval(x) + literal "}"
  expect_identical(interp("{{{x}}}"), "{99}")
})

test_that("nested braces in a call parse and evaluate", {
  f <- function(z) z * 2
  y <- 3
  expect_identical(interp("{f({y})}"), "6")
})

test_that("braces inside string literals do not close the expression", {
  sq <- c("}" = "ok")
  expect_identical(interp("{sq['}']}"), "ok")
  dq <- c("}" = "good")
  expect_identical(interp('{dq["}"]}'), "good")
  expect_identical(interp('{paste0("a", "}", "b")}'), "a}b")
})

test_that("backtick names and escaped quotes parse", {
  `weird }name` <- 7
  expect_identical(interp("{`weird }name`}"), "7")
  expect_identical(interp('{paste0("a\\"b")}'), 'a"b')
})

test_that("multi-statement bodies return the last value", {
  expect_identical(interp("{a <- 1; a + 4}"), "5")
})

test_that("a # comment inside an expression is consumed to end of line", {
  expect_identical(interp("{1 + # inline comment\n 2}"), "3")
})

test_that("escaped quotes inside a single-quoted string literal parse", {
  expect_identical(interp("{nchar('a\\'b')}"), "3")
})

test_that("a child eval env is used so assignments do not leak", {
  e <- new.env()
  tabular:::.interpolate("{z <- 9; z}", env = e, call = rlang::caller_env())
  expect_false(exists("z", envir = e, inherits = FALSE))
})

test_that("newlines are preserved (no docstring trim)", {
  n <- 10
  expect_identical(interp("Placebo\nN={n}"), "Placebo\nN=10")
})

test_that("UTF-8 literals survive the character scan", {
  expect_identical(interp("Temperature 37°C {1+1}"), "Temperature 37°C 2")
})

test_that("factor and named-vector results coerce sensibly", {
  fac <- factor("High", levels = c("Low", "High"))
  expect_identical(interp("{fac}"), "High")
  v <- c(placebo = 86L)
  expect_identical(interp("{v['placebo']}"), "86")
})

# ---------------------------------------------------------------------
# NA semantics
# ---------------------------------------------------------------------

test_that("NA produced inside an expression renders as literal NA", {
  v <- NA
  expect_identical(interp("{v}"), "NA")
  expect_identical(interp("a{v}b"), "aNAb")
})

test_that("a whole-value NA passes through .interp_one untouched", {
  out <- tabular:::.interp_one(
    NA_character_,
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(out, NA_character_)
})

# ---------------------------------------------------------------------
# Abort cases
# ---------------------------------------------------------------------

test_that("empty and whitespace-only interpolations error", {
  expect_error(interp("a{}b"), class = "tabular_error_input")
  expect_error(interp("a{ }b"), class = "tabular_error_input")
})

test_that("unbalanced braces error", {
  expect_error(interp("a}b"), class = "tabular_error_input")
  expect_error(interp("a{b"), class = "tabular_error_input")
})

test_that("parse and eval failures error", {
  expect_error(interp("{1 +}"), class = "tabular_error_input")
  expect_error(interp("{nope_unbound_symbol}"), class = "tabular_error_input")
})

test_that("non-scalar results error", {
  expect_error(interp("{1:2}"), class = "tabular_error_input")
  expect_error(interp("{NULL}"), class = "tabular_error_input")
  expect_error(interp("{invisible(1:3)}"), class = "tabular_error_input")
})

test_that("interpolation error messages are stable", {
  expect_snapshot(error = TRUE, interp("a{}b"))
  expect_snapshot(error = TRUE, interp("a{b"))
  expect_snapshot(error = TRUE, interp("a}b"))
  expect_snapshot(error = TRUE, interp("{1 +}"))
  expect_snapshot(error = TRUE, interp("{nope_unbound_symbol}"))
  expect_snapshot(error = TRUE, interp("{1:2}"))
})

# ---------------------------------------------------------------------
# md() / html() skip
# ---------------------------------------------------------------------

test_that(".interp_one leaves md()/html() objects untouched", {
  m <- md("{x}")
  out <- tabular:::.interp_one(
    m,
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(out, m)
  expect_s3_class(out, "from_markdown")

  h <- html("<b>{x}</b>")
  outh <- tabular:::.interp_one(
    h,
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(outh, h)
})

test_that(".interpolate_vec short-circuits whole-value md()/html()", {
  m <- md("{x}")
  out <- tabular:::.interpolate_vec(
    m,
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(out, m)
  expect_s3_class(out, "from_markdown")
})

# ---------------------------------------------------------------------
# Vector behaviour
# ---------------------------------------------------------------------

test_that(".interpolate_vec maps elementwise and preserves shape", {
  a <- 1
  b <- 2
  out <- tabular:::.interpolate_vec(
    c(first = "{a}", lit = "plain", third = "{b}"),
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(out, c(first = "1", lit = "plain", third = "2"))
})

test_that(".interpolate_vec passes NA elements through and handles empties", {
  a <- 5
  out <- tabular:::.interpolate_vec(
    c("{a}", NA, "x"),
    env = environment(),
    call = rlang::caller_env()
  )
  expect_identical(out, c("5", NA, "x"))
  expect_identical(
    tabular:::.interpolate_vec(
      character(0),
      env = environment(),
      call = rlang::caller_env()
    ),
    character(0)
  )
})

# ---------------------------------------------------------------------
# Integration: wiring into the verbs
# ---------------------------------------------------------------------

test_that("col_spec label is interpolated at call time", {
  n <- 5L
  cs <- col_spec(label = "N={n}")
  expect_identical(cs@label, "N=5")
})

test_that("col_spec resolves caller variables through cols() nesting", {
  n <- stats::setNames(c(86L), "placebo")
  spec <- tabular(saf_demo) |>
    cols(placebo = col_spec(label = "Placebo (N={n['placebo']})"))
  ph <- Filter(function(c) identical(c@name, "placebo"), spec@cols)[[1L]]
  expect_identical(ph@label, "Placebo (N=86)")
})

test_that("col_spec label keeps md() class (not interpolated)", {
  cs <- col_spec(label = md("**{x}**"))
  expect_s3_class(cs@label, "from_markdown")
})

test_that("tabular titles and footnotes are interpolated elementwise", {
  n <- 3L
  spec <- tabular(
    saf_demo,
    titles = c("Table 14.1.1", "N={n}"),
    footnotes = "Total = {n * 2}"
  )
  expect_identical(spec@titles[[2L]], "N=3")
  expect_identical(spec@footnotes[[1L]], "Total = 6")
})

test_that("footnote() text is interpolated, md() untouched", {
  ref <- "RECIST 1.1"
  spec <- tabular(saf_demo) |> footnote("Per {ref}.")
  expect_identical(spec@footnote_refs[[1L]]$text, "Per RECIST 1.1.")

  spec2 <- tabular(saf_demo) |> footnote(md("Per {ref}."))
  expect_s3_class(spec2@footnote_refs[[1L]]$text, "from_markdown")
})

test_that("headers band labels interpolate while error path stays raw", {
  grp <- "Treatment"
  spec <- tabular(saf_demo) |>
    headers("{grp} Group" = c("placebo", "drug_50", "drug_100", "Total"))
  expect_identical(spec@headers[[1L]]@label, "Treatment Group")
})

# ---------------------------------------------------------------------
# Excluded-surface regression: token grammars must stay literal
# ---------------------------------------------------------------------

test_that("preset page chrome tokens are NOT caller-env interpolated", {
  # `{page}` is an engine/backend token, not a caller variable; it must
  # survive verb construction verbatim.
  # Wrong wiring would eval `page` as a caller variable and abort
  # (unbound symbol). Clean construction proves the token stays literal.
  expect_no_error(
    tabular(saf_demo) |> preset(pagehead = list(right = "{page}"))
  )
})

test_that("subgroup label keeps its {col} data-frame template", {
  spec <- tabular(saf_subgroup) |> subgroup(by = "sex", label = "Sex: {sex}")
  expect_identical(spec@subgroup@label, "Sex: {sex}")
})
