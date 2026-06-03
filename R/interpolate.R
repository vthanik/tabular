# interpolate.R — base-R port of glue 1.8's `{expr}` brace interpolation.
#
# Static, user-authored text surfaces (col_spec label, tabular titles /
# footnotes, headers band labels, footnote text) accept glue-style
# `{expr}` interpolation, e.g. `col_spec(label = "Placebo (N={n['placebo']})")`.
# The expression is parsed and evaluated EAGERLY at verb-call time in the
# user's calling environment (`rlang::caller_env()`, the same env each
# verb already captures for error attribution). This is the glue / cli
# trust model: the label author is the code author, so there is no
# sandbox.
#
# Escaping: a doubled brace is literal, `{{` -> `{` and `}}` -> `}`.
#
# Boundaries:
# *   `md()` / `html()` strings are left untouched (already parsed to an
#     inline AST before the verb sees them); `.interp_one` skips them by
#     class.
# *   Surfaces that already own a `{...}` token grammar are NEVER wired
#     to this helper: `subgroup(label=)` ({col} data lookup),
#     `preset(pagehead=/pagefoot=)` ({program}/{datetime}), page tokens
#     ({page}/{npages}), footnote engine ({m}).
#
# Departures from glue (deliberate): no docstring trim (would mangle the
# `\n` two-line-header convention) and a strict length-1 result (labels
# are scalar). An NA produced INSIDE an `{expr}` renders as the literal
# "NA" (glue parity, via paste0 coercion); a whole-value NA passes
# through untouched.

# Guard + dispatch for a scalar surface (col_spec label, footnote text,
# one headers band label). Returns `x` unchanged when it is an md() /
# html() object or a whole-value NA; otherwise interpolates.
.interp_one <- function(x, env, call) {
  if (inherits(x, "from_markdown") || inherits(x, "from_html")) {
    return(x)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    return(x)
  }
  .interpolate(x, env = env, call = call)
}

# Elementwise interpolation for a character vector (titles / footnotes).
# Whole-value md() / html() are short-circuited BEFORE the loop because
# element subsetting (`x[[i]]`) drops their S3 class. NA elements pass
# through untouched; length and names are preserved.
.interpolate_vec <- function(x, env, call) {
  if (inherits(x, "from_markdown") || inherits(x, "from_html")) {
    return(x)
  }
  if (!is.character(x) || length(x) == 0L) {
    return(x)
  }
  out <- x
  for (i in seq_along(x)) {
    xi <- x[[i]]
    if (is.na(xi)) {
      next
    }
    out[[i]] <- .interpolate(xi, env = env, call = call)
  }
  out
}

# Scalar `character(1)` -> `character(1)`. Fast-path returns the input
# unchanged when it carries no brace, so every existing literal label is
# zero-cost and behaviour-preserving; the scanner only runs on
# brace-bearing strings.
.interpolate <- function(x, env, call) {
  if (!grepl("{", x, fixed = TRUE) && !grepl("}", x, fixed = TRUE)) {
    return(x)
  }
  chunks <- .interp_scan(x, call = call)
  parts <- vapply(
    chunks,
    function(ch) {
      if (identical(ch$type, "lit")) {
        ch$value
      } else {
        .interp_eval(ch$value, env = env, call = call)
      }
    },
    character(1L)
  )
  paste0(parts, collapse = "")
}

# The glue state machine, ported to base R. Walks the string one UTF-8
# character at a time and returns a list of `{type, value}` chunks
# (alternating "lit" literal runs and "expr" interpolation bodies).
# States: text, delim (inside `{...}`), squote / dquote / backtick
# (string literals inside an expression), comment (`#` to end of line).
# Braces inside quotes / comments / after a backslash do not affect the
# nesting depth, so `{x['}']}` and `{f({y})}` parse correctly.
.interp_scan <- function(x, call) {
  cv <- strsplit(x, "", fixed = TRUE)[[1L]]
  n <- length(cv)
  chunks <- list()
  nchunk <- 0L
  lit <- character(0)
  state <- "text"
  depth <- 0L
  expr_start <- NA_integer_
  i <- 1L

  push_lit <- function() {
    if (length(lit) > 0L) {
      nchunk <<- nchunk + 1L
      chunks[[nchunk]] <<- list(
        type = "lit",
        value = paste0(lit, collapse = "")
      )
      lit <<- character(0)
    }
  }

  while (i <= n) {
    ch <- cv[[i]]

    if (identical(state, "text")) {
      if (ch == "{") {
        if (i < n && cv[[i + 1L]] == "{") {
          lit <- c(lit, "{")
          i <- i + 2L
          next
        }
        push_lit()
        state <- "delim"
        depth <- 1L
        expr_start <- i + 1L
        i <- i + 1L
        next
      }
      if (ch == "}") {
        if (i < n && cv[[i + 1L]] == "}") {
          lit <- c(lit, "}")
          i <- i + 2L
          next
        }
        .interp_abort_unmatched(x, call = call)
      }
      lit <- c(lit, ch)
      i <- i + 1L
      next
    }

    if (identical(state, "delim")) {
      if (ch == "}") {
        depth <- depth - 1L
        if (depth == 0L) {
          inner <- if (i > expr_start) {
            paste0(cv[expr_start:(i - 1L)], collapse = "")
          } else {
            ""
          }
          nchunk <- nchunk + 1L
          chunks[[nchunk]] <- list(type = "expr", value = inner)
          state <- "text"
          expr_start <- NA_integer_
        }
        i <- i + 1L
        next
      }
      if (ch == "{") {
        depth <- depth + 1L
      } else if (ch == "'") {
        state <- "squote"
      } else if (ch == "\"") {
        state <- "dquote"
      } else if (ch == "`") {
        state <- "backtick"
      } else if (ch == "#") {
        state <- "comment"
      }
      i <- i + 1L
      next
    }

    if (identical(state, "squote")) {
      if (ch == "\\") {
        i <- i + 2L
        next
      }
      if (ch == "'") {
        state <- "delim"
      }
      i <- i + 1L
      next
    }

    if (identical(state, "dquote")) {
      if (ch == "\\") {
        i <- i + 2L
        next
      }
      if (ch == "\"") {
        state <- "delim"
      }
      i <- i + 1L
      next
    }

    if (identical(state, "backtick")) {
      if (ch == "`") {
        state <- "delim"
      }
      i <- i + 1L
      next
    }

    # state == "comment": consume to end of line, then resume the
    # expression. Single-line labels rarely contain a newline, so a `#`
    # typically swallows the closing brace and the string aborts as
    # unterminated, which matches glue's intent.
    if (ch == "\n") {
      state <- "delim"
    }
    i <- i + 1L
  }

  if (!identical(state, "text") || depth != 0L) {
    .interp_abort_unterminated(x, call = call)
  }
  push_lit()
  chunks
}

# Parse + evaluate one interpolation body and coerce to a length-1
# string. Evaluation runs in a child of `env` so a stray assignment
# (`{a <- 1; a}`) cannot pollute the user's environment, while ordinary
# variable lookup still chains up to it.
.interp_eval <- function(inner, env, call) {
  if (!nzchar(trimws(inner))) {
    .interp_abort_empty(call = call)
  }
  parsed <- tryCatch(
    parse(text = inner),
    error = function(e) .interp_abort_parse(inner, e, call = call)
  )
  result <- tryCatch(
    eval(parsed, envir = new.env(parent = env)),
    error = function(e) .interp_abort_eval(inner, e, call = call)
  )
  val <- tryCatch(
    as.character(result),
    error = function(e) .interp_abort_eval(inner, e, call = call)
  )
  if (length(val) != 1L) {
    .interp_abort_length(inner, length(val), call = call)
  }
  val
}

# ---------------------------------------------------------------------
# Error helpers (ASCII message strings, tabular_error_input class).
# `inner` / `x` are inserted as cli SUBSTITUTION VALUES (`{.val {inner}}`),
# which glue does not re-scan, so braces inside them are safe to display.
# ---------------------------------------------------------------------

.interp_abort_unmatched <- function(x, call) {
  cli::cli_abort(
    c(
      "Unbalanced braces in {.val {x}}.",
      "x" = "Found a closing brace with no matching open brace.",
      "i" = "Double a brace to write a literal one."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.interp_abort_unterminated <- function(x, call) {
  cli::cli_abort(
    c(
      "Unterminated interpolation in {.val {x}}.",
      "x" = "An opening brace was never closed.",
      "i" = "Double a brace to write a literal one."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.interp_abort_empty <- function(call) {
  cli::cli_abort(
    c(
      "Found an empty interpolation with nothing between the braces.",
      "i" = "Put an R expression inside, or double a brace to write a literal one."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.interp_abort_parse <- function(inner, e, call) {
  cli::cli_abort(
    c(
      "Could not parse the interpolation {.val {inner}}.",
      "x" = "R parse error: {conditionMessage(e)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.interp_abort_eval <- function(inner, e, call) {
  cli::cli_abort(
    c(
      "Could not evaluate the interpolation {.val {inner}}.",
      "x" = "{conditionMessage(e)}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

.interp_abort_length <- function(inner, n, call) {
  cli::cli_abort(
    c(
      "The interpolation {.val {inner}} must produce a single value.",
      "x" = "It produced {n} value{?s} after coercion to character."
    ),
    class = "tabular_error_input",
    call = call
  )
}
