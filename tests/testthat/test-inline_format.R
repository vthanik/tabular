# md() / html() inline-format wrappers and the parse_inline()
# dispatcher. Tests cover the S3-class round-trip, the input
# validators, the Markdown parser (commonmark + ^sup^ / ~sub~
# pre-processing), the HTML parser (xml2 + tag whitelist), the
# inline CSS parser, and the plain-string \n splitter.

# ---------------------------------------------------------------------
# md() / html() wrappers
# ---------------------------------------------------------------------

test_that("md() wraps a string with from_markdown class", {
  x <- md("**bold**")
  expect_s3_class(x, "from_markdown")
  expect_s3_class(x, "character")
  expect_identical(tabular:::.strip_inline_marker(unclass(x)), "**bold**")
})

test_that("html() wraps a string with from_html class", {
  x <- html("<b>bold</b>")
  expect_s3_class(x, "from_html")
  expect_s3_class(x, "character")
  expect_identical(tabular:::.strip_inline_marker(unclass(x)), "<b>bold</b>")
})

test_that("md() / html() markers survive c() concatenation", {
  # Critical contract: c("plain", md("**bold**")) preserves the md
  # flag via the internal marker prefix, even though c() strips the
  # S3 class.
  v <- c("Table 14.3.1", md("**Drug A**"), html("<i>x</i>"))
  expect_identical(length(v), 3L)
  # Round-trip via parse_inline detects each element correctly:
  asts <- lapply(v, parse_inline)
  expect_identical(asts[[1L]]@runs[[1L]]$type, "plain")
  expect_identical(asts[[2L]]@runs[[1L]]$type, "bold")
  expect_identical(asts[[3L]]@runs[[1L]]$type, "italic")
})

test_that("md() / html() reject non-character input", {
  expect_error(md(123), class = "tabular_error_input")
  expect_error(html(TRUE), class = "tabular_error_input")
})

test_that("md() / html() reject length != 1", {
  expect_error(md(c("a", "b")), class = "tabular_error_input")
  expect_error(html(character()), class = "tabular_error_input")
})

test_that("md() / html() reject NA", {
  expect_error(md(NA_character_), class = "tabular_error_input")
  expect_error(html(NA_character_), class = "tabular_error_input")
})

test_that("md() / html() accept empty string", {
  expect_s3_class(md(""), "from_markdown")
  expect_s3_class(html(""), "from_html")
})

# ---------------------------------------------------------------------
# parse_inline() -- dispatcher
# ---------------------------------------------------------------------

test_that("parse_inline() returns an inline_ast", {
  ast <- parse_inline("Hello")
  expect_true(is_inline_ast(ast))
})

test_that("parse_inline() is idempotent on inline_ast input", {
  ast1 <- parse_inline("Hello")
  ast2 <- parse_inline(ast1)
  expect_identical(ast1, ast2)
})

test_that("parse_inline(NULL) returns an empty inline_ast", {
  ast <- parse_inline(NULL)
  expect_identical(length(ast@runs), 0L)
})

test_that("parse_inline(NA) returns an empty inline_ast", {
  ast <- parse_inline(NA_character_)
  expect_identical(length(ast@runs), 0L)
})

test_that('parse_inline("") returns an empty inline_ast', {
  ast <- parse_inline("")
  expect_identical(length(ast@runs), 0L)
})

test_that("parse_inline() rejects non-scalar input", {
  expect_error(parse_inline(c("a", "b")), class = "tabular_error_input")
  expect_error(parse_inline(123), class = "tabular_error_input")
})

# ---------------------------------------------------------------------
# Plain-text parser
# ---------------------------------------------------------------------

test_that("plain string yields a single plain run", {
  ast <- parse_inline("Hello world")
  expect_identical(length(ast@runs), 1L)
  expect_identical(ast@runs[[1L]]$type, "plain")
  expect_identical(ast@runs[[1L]]$text, "Hello world")
})

test_that("plain string with \\n splits into plain + newline + plain", {
  ast <- parse_inline("line1\nline2")
  expect_identical(length(ast@runs), 3L)
  expect_identical(ast@runs[[1L]]$type, "plain")
  expect_identical(ast@runs[[1L]]$text, "line1")
  expect_identical(ast@runs[[2L]]$type, "newline")
  expect_identical(ast@runs[[3L]]$type, "plain")
  expect_identical(ast@runs[[3L]]$text, "line2")
})

test_that("multiple consecutive \\n yield multiple newline runs", {
  ast <- parse_inline("a\n\n\nb")
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_identical(
    types,
    c("plain", "newline", "newline", "newline", "plain")
  )
})

test_that("trailing \\n still emits the newline", {
  ast <- parse_inline("a\n")
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_identical(types, c("plain", "newline"))
})

# ---------------------------------------------------------------------
# Markdown parser
# ---------------------------------------------------------------------

test_that("md(**bold**) parses to a bold run", {
  ast <- parse_inline(md("**bold**"))
  expect_identical(length(ast@runs), 1L)
  expect_identical(ast@runs[[1L]]$type, "bold")
  expect_identical(ast@runs[[1L]]$children[[1L]]$type, "plain")
  expect_identical(ast@runs[[1L]]$children[[1L]]$text, "bold")
})

test_that("md(*italic*) parses to an italic run", {
  ast <- parse_inline(md("*italic*"))
  expect_identical(ast@runs[[1L]]$type, "italic")
})

test_that("md(`code`) parses to a code run", {
  ast <- parse_inline(md("`code`"))
  expect_identical(ast@runs[[1L]]$type, "code")
})

test_that("md([link](url)) parses to a link run", {
  ast <- parse_inline(md("see [docs](https://example.com)"))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("link", types)
  link_run <- ast@runs[[which(types == "link")[1L]]]
  expect_identical(link_run$href, "https://example.com")
})

test_that("md() converts ^sup^ to superscript", {
  ast <- parse_inline(md("E=mc^2^"))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("sup", types)
})

test_that("md() converts ~sub~ to subscript", {
  ast <- parse_inline(md("H~2~O"))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("sub", types)
})

test_that("md() passes inline HTML through (subset)", {
  ast <- parse_inline(md('a <b>bold</b> b'))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("bold", types)
})

test_that("md() preserves a hard line break (linebreak)", {
  ast <- parse_inline(md("a  \nb"))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("newline", types)
})

# ---------------------------------------------------------------------
# HTML parser
# ---------------------------------------------------------------------

test_that("html(<b>) parses to a bold run", {
  ast <- parse_inline(html("<b>bold</b>"))
  expect_identical(ast@runs[[1L]]$type, "bold")
})

test_that("html(<strong>) parses to a bold run", {
  ast <- parse_inline(html("<strong>bold</strong>"))
  expect_identical(ast@runs[[1L]]$type, "bold")
})

test_that("html(<em>) parses to an italic run", {
  ast <- parse_inline(html("<em>x</em>"))
  expect_identical(ast@runs[[1L]]$type, "italic")
})

test_that("html(<sup>) and <sub> parse to sup / sub runs", {
  ast_sup <- parse_inline(html("<sup>1</sup>"))
  ast_sub <- parse_inline(html("<sub>2</sub>"))
  expect_identical(ast_sup@runs[[1L]]$type, "sup")
  expect_identical(ast_sub@runs[[1L]]$type, "sub")
})

test_that("html(<code>) parses to a code run", {
  ast <- parse_inline(html("<code>x</code>"))
  expect_identical(ast@runs[[1L]]$type, "code")
})

test_that("html(<br>) parses to a newline run", {
  ast <- parse_inline(html("a<br>b"))
  types <- vapply(ast@runs, function(r) r$type, character(1L))
  expect_in("newline", types)
})

test_that("html(<a href=...>) parses to a link run with href", {
  ast <- parse_inline(html('<a href="https://example.com">x</a>'))
  expect_identical(ast@runs[[1L]]$type, "link")
  expect_identical(ast@runs[[1L]]$href, "https://example.com")
})

test_that("html(<span style=...>) parses to a span run with CSS", {
  ast <- parse_inline(html(
    '<span style="color: red; font-weight: bold">x</span>'
  ))
  expect_identical(ast@runs[[1L]]$type, "span")
  expect_identical(ast@runs[[1L]]$style[["color"]], "red")
  expect_identical(ast@runs[[1L]]$style[["font-weight"]], "bold")
})

test_that("html() unknown tags drop wrapper, keep text content", {
  ast <- parse_inline(html("<u>x</u>"))
  expect_identical(ast@runs[[1L]]$type, "plain")
  expect_identical(ast@runs[[1L]]$text, "x")
})

# ---------------------------------------------------------------------
# Inline CSS parser (tested via the public span entry point)
# ---------------------------------------------------------------------

test_that("CSS parser handles multiple declarations", {
  ast <- parse_inline(html(
    '<span style="color: red; background: yellow">x</span>'
  ))
  style <- ast@runs[[1L]]$style
  expect_identical(length(style), 2L)
  expect_identical(style[["color"]], "red")
  expect_identical(style[["background"]], "yellow")
})

test_that("CSS parser handles empty style", {
  ast <- parse_inline(html('<span style="">x</span>'))
  expect_identical(length(ast@runs[[1L]]$style), 0L)
})

test_that("CSS parser handles missing style attribute", {
  ast <- parse_inline(html("<span>x</span>"))
  expect_identical(length(ast@runs[[1L]]$style), 0L)
})

test_that("CSS parser handles value with embedded colon (e.g. URL)", {
  ast <- parse_inline(html(
    '<span style="background: url(https://x.com/i.png)">x</span>'
  ))
  style <- ast@runs[[1L]]$style
  expect_identical(style[["background"]], "url(https://x.com/i.png)")
})

# ---------------------------------------------------------------------
# Predicate
# ---------------------------------------------------------------------

test_that("is_inline_ast() detects inline_ast objects", {
  expect_true(is_inline_ast(parse_inline("Hello")))
  expect_false(is_inline_ast("Hello"))
  expect_false(is_inline_ast(NULL))
  expect_false(is_inline_ast(list()))
})

# ---------------------------------------------------------------------
# inline_ast class validation
# ---------------------------------------------------------------------

test_that("inline_ast() with empty runs is valid", {
  ast <- inline_ast(runs = list())
  expect_true(is_inline_ast(ast))
})

test_that("inline_ast() rejects unknown run types", {
  expect_error(
    inline_ast(runs = list(list(type = "frobnicate", text = "x"))),
    "unknown type"
  )
})

test_that("inline_ast() rejects malformed runs (non-list or missing type)", {
  expect_error(
    inline_ast(runs = list("not_a_list")),
    "unknown type"
  )
  expect_error(
    inline_ast(runs = list(list(text = "missing type"))),
    "unknown type"
  )
})

# ---------------------------------------------------------------------
# Snapshot the canonical 25 representative strings
# ---------------------------------------------------------------------

test_that("parse_inline snapshot suite (25 strings)", {
  cases <- list(
    plain = "Hello world",
    plain_newline = "first\nsecond",
    md_bold = md("**bold**"),
    md_italic = md("*italic*"),
    md_code = md("`code`"),
    md_link = md("[link](https://example.com)"),
    md_sup = md("x^2^"),
    md_sub = md("H~2~O"),
    md_mixed = md("**a** *b* `c` ^d^ ~e~"),
    md_link_title = md('[link](https://x.com "Title")'),
    md_inline_html = md('a <b>b</b> c'),
    md_hard_break = md("a  \nb"),
    md_empty = md(""),
    html_b = html("<b>bold</b>"),
    html_strong = html("<strong>bold</strong>"),
    html_em = html("<em>x</em>"),
    html_i = html("<i>x</i>"),
    html_sup = html("<sup>1</sup>"),
    html_sub = html("<sub>2</sub>"),
    html_code = html("<code>x</code>"),
    html_a = html('<a href="https://x.com">x</a>'),
    html_span = html('<span style="color: red">x</span>'),
    html_br = html("a<br/>b"),
    html_unknown = html("<u>x</u>"),
    html_empty = html("")
  )

  # Reduce each AST to a compact, snapshot-friendly summary: types
  # and depths. Full structure tested by individual cases above.
  summarise_ast <- function(ast) {
    types <- vapply(
      ast@runs,
      function(r) {
        if (!is.null(r$children) && length(r$children) > 0L) {
          inner <- vapply(
            r$children,
            function(c) c$type %||% "?",
            character(1L)
          )
          paste0(r$type, "(", paste(inner, collapse = ","), ")")
        } else {
          r$type
        }
      },
      character(1L)
    )
    paste(types, collapse = " | ")
  }
  summary_table <- vapply(
    cases,
    function(x) summarise_ast(parse_inline(x)),
    character(1L)
  )
  expect_snapshot(summary_table)
})

# ---------------------------------------------------------------------
# Snapshot errors
# ---------------------------------------------------------------------

test_that(".strip_inline_marker passes non-character through", {
  expect_identical(tabular:::.strip_inline_marker(42L), 42L)
  expect_null(tabular:::.strip_inline_marker(NULL))
})

test_that("parse_inline defensive S3 fallback parses classed-but-unmarked input", {
  # Construct a string that has the from_markdown class but no
  # marker prefix (the constructor would always add one; this
  # exercises the defensive branch).
  x <- structure("**bold**", class = c("from_markdown", "character"))
  ast <- parse_inline(x)
  expect_identical(ast@runs[[1L]]$type, "bold")

  y <- structure("<b>bold</b>", class = c("from_html", "character"))
  ast2 <- parse_inline(y)
  expect_identical(ast2@runs[[1L]]$type, "bold")
})

test_that(".walk_html_node ignores comment-type nodes", {
  # HTML comments parse to a comment node, type != "element"/"text".
  ast <- parse_inline(html("a<!-- comment -->b"))
  texts <- vapply(
    ast@runs,
    function(r) if (!is.null(r$text)) r$text else "",
    character(1L)
  )
  expect_in("a", texts)
  expect_in("b", texts)
})

test_that(".parse_css_inline tolerates malformed declarations", {
  # Declaration without a colon should be dropped; declaration with
  # only a colon (no value) should yield an empty-string value.
  ast <- parse_inline(html(
    '<span style="bad-decl; color: red; :no-key">x</span>'
  ))
  style <- ast@runs[[1L]]$style
  expect_identical(unname(style[["color"]]), "red")
})

test_that(".parse_css_inline returns empty for whitespace-only style", {
  ast <- parse_inline(html('<span style="   ">x</span>'))
  expect_identical(length(ast@runs[[1L]]$style), 0L)
})

test_that(".parse_css_inline returns empty when all declarations malformed", {
  # No colons at all -- every "declaration" is rejected by the
  # `length(parts) >= 2` filter; the result is empty.
  ast <- parse_inline(html('<span style="bad1; bad2; bad3">x</span>'))
  expect_identical(length(ast@runs[[1L]]$style), 0L)
})

test_that("inline-format snapshot errors", {
  expect_snapshot(error = TRUE, md(NA_character_))
  expect_snapshot(error = TRUE, html(c("a", "b")))
  expect_snapshot(error = TRUE, parse_inline(c("a", "b")))
})
