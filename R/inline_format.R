# inline_format.R — Markdown / HTML inline formatting for titles,
# footnotes, column labels, and cell text.
#
# Design (per plan.md design decision D1):
#
# Two public helpers, gt-aligned:
#   md(text)    — mark a string as Markdown (CommonMark + GFM +
#                   Pandoc-style ^sup^ and ~sub~).
#   html(text)  — mark a string as HTML (constrained subset:
#                   <b>, <i>, <strong>, <em>, <sup>, <sub>, <code>,
#                   <a href>, <span style>, <br>).
#
# Each returns a length-1 character vector with an S3 class
# annotation (`from_markdown` or `from_html`). Engine_format calls
# `parse_inline()` to convert the marker plus content into an
# `inline_ast` (S7 class declared in R/aaa_class.R), which carries
# the typed run-list that backends consume.
#
# Plain strings (no md/html wrapper) round-trip through
# `parse_inline()` as a trivial single-run AST.
#
# Parser strategy:
#
#   1. md(text)   -> commonmark::markdown_html(text)  -> HTML
#                    (with ^sup^ / ~sub~ pre-substituted to
#                     <sup> / <sub>)
#   2. html(text) -> HTML directly
#   3. plain      -> trivial AST
#
# One HTML parser (xml2-based) handles both md and html. Markdown
# loses no fidelity via the round-trip because commonmark's HTML
# output is the canonical reference rendering.
#
# References:
#   * gt::md() / gt::html() — the established R-table convention
#     this module follows.
#   * CommonMark spec — the Markdown grammar commonmark::markdown_html
#     parses.

# Recognised HTML tags. Anything outside this set passes through
# children as plain text (the tag wrapping is dropped, the inner
# content is preserved). Keeps the AST small and prevents arbitrary
# HTML attack surface.
.inline_html_tags <- c(
  "p",
  "br",
  "strong",
  "b",
  "em",
  "i",
  "sup",
  "sub",
  "code",
  "a",
  "span"
)

# Inline-format encoding markers. `md()` and `html()` prepend these
# control-character sequences to the wrapped string so that:
#   * `c("plain", md("**x**"))` preserves the md flag (class is
#     stripped by `c()` for character vectors; the prefix is content
#     and survives).
#   * Plain strings (no prefix) parse as plain text.
#   * Pretty-printing helpers strip the prefix for display.
# Chosen: U+0001 (Start of Heading) — a control character with no
# meaningful presence in user prose or clinical text. The marker is
# never embedded inside Markdown / HTML payloads we parse because
# `.parse_md` / `.parse_html` strip it first.
.tabular_md_marker <- "M"
.tabular_html_marker <- "H"

# Strip any inline-format marker prefix and return the bare text.
# Used by print methods and any code that wants the user-visible
# content without dispatching to a parser. Plain strings pass
# through unchanged.
.strip_inline_marker <- function(x) {
  if (!is.character(x)) {
    return(x)
  }
  out <- x
  is_md <- startsWith(x, .tabular_md_marker)
  is_html <- startsWith(x, .tabular_html_marker)
  out[is_md] <- substr(
    x[is_md],
    nchar(.tabular_md_marker) + 1L,
    nchar(x[is_md])
  )
  out[is_html] <- substr(
    x[is_html],
    nchar(.tabular_html_marker) + 1L,
    nchar(x[is_html])
  )
  out
}

#' Mark a string as Markdown for inline formatting
#'
#' Wrap a length-1 character vector so [`tabular()`], [`col_spec()`],
#' [`style()`] pretext / posttext, and similar string slots interpret
#' it as CommonMark Markdown at render time. Supports the
#' GitHub-flavoured plus Pandoc-style superscript (`^sup^`) and
#' subscript (`~sub~`) extensions; raw HTML inside Markdown passes
#' through to the constrained tag set documented under [`html()`].
#'
#' @details
#'
#' **Convention adopted from gt.** Marking strings with `md()` and
#' `html()` mirrors the well-tested gt convention. Plain
#' (unwrapped) strings render as plain text — a stray `**` will
#' NOT silently bold the surrounding span. Wrap explicitly to opt
#' in.
#'
#' **Recognised Markdown.** `**bold**`, `*italic*`, `` `code` ``,
#' `[link text](url)`, hard line break (two trailing spaces + `\n`
#' or `\\` + `\n`), Pandoc `^sup^` and `~sub~`. Single embedded
#' `\n` (a "soft break" in CommonMark) renders as a space in HTML;
#' tabular preserves it as a line break for clinical-table use
#' where multi-line cells / titles are routine.
#'
#' **HTML pass-through.** Raw HTML in Markdown (e.g.
#' `md("Drug A <span style='color:red'>warning</span>")`) is parsed
#' as HTML using the same tag whitelist as [`html()`]. Tags outside
#' the whitelist drop their wrapper and keep their text content.
#'
#' **Composition with plain strings.** `md()` and `html()` wrap the
#' input with an internal control-character prefix that survives
#' `c()` concatenation, so you can freely mix plain and marked
#' strings in a single character vector:
#' `c("Table 14.3.1", md("**Drug A**"), "third")`. Backends strip
#' the marker before rendering; users never see it.
#'
#' @param text *The Markdown string.* `<character(1)>: required`.
#'   Length-1 character vector. `NA` is rejected; the empty string
#'   `""` renders as no content.
#'
#' @return *A length-1 character vector classed
#'   `c("from_markdown", "character")`.* Pass it directly into any
#'   string-bearing slot ([`tabular()`] titles / footnotes,
#'   [`col_spec()`] label, [`style()`] pretext / posttext); the
#'   resolve engine calls `parse_inline()` internally and backends
#'   walk the resulting `inline_ast`.
#'
#' @examples
#' # ---- Example 1: Italic title qualifier with Pandoc footnote marker ----
#' #
#' # AE-by-SOC/PT table. Title lines are bold by default, so the third
#' # line italicises "Safety Population" via `md("*...*")` for a visible
#' # contrast; the first footnote carries a Pandoc-style superscript
#' # marker `^a^` that the backends render as a true superscript.
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   cdisc_saf_aesocpt,
#'   titles = c(
#'     "Table 14.3.1",
#'     "Adverse Events by System Organ Class and Preferred Term",
#'     md("*Safety Population*")
#'   ),
#'   footnotes = c(
#'     md("^a^ Subjects counted once per SOC and once per PT.")
#'   )
#' ) |>
#'   cols(
#'     label    = col_spec(label = "SOC / PT", indent = "indent_level"),
#'     soc      = col_spec(visible = FALSE),
#'     row_type = col_spec(visible = FALSE),
#'     soc_n    = col_spec(visible = FALSE),
#'     n_total  = col_spec(visible = FALSE),
#'     placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
#'     drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
#'     drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
#'     Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
#'   )
#'
#' # ---- Example 2: Markdown link in a footnote ----
#' #
#' # Efficacy BOR table that footnotes the response criteria with
#' # a Markdown link. HTML / PDF / DOCX render as clickable; RTF /
#' # LaTeX render the link text with the URL inline (backend
#' # decides).
#' ne <- stats::setNames(cdisc_eff_n$n, cdisc_eff_n$arm_short)
#'
#' tabular(
#'   cdisc_eff_resp,
#'   titles = c(
#'     "Table 14.2.1",
#'     "Best Overall Response",
#'     "Efficacy Evaluable Population"
#'   ),
#'   footnotes = c(
#'     md("Response per [RECIST 1.1](https://recist.eortc.org/), investigator assessment.")
#'   )
#' ) |>
#'   cols(
#'     stat_label  = col_spec(usage = "id", label = "Response"),
#'     row_type    = col_spec(visible = FALSE),
#'     groupid     = col_spec(visible = FALSE),
#'     group_label = col_spec(visible = FALSE),
#'     placebo     = col_spec(label = "Placebo\nN={ne['placebo']}",  align = "decimal"),
#'     drug_50     = col_spec(label = "Drug 50\nN={ne['drug_50']}",  align = "decimal"),
#'     drug_100    = col_spec(label = "Drug 100\nN={ne['drug_100']}", align = "decimal")
#'   )
#'
#' @seealso
#' **Sibling helper:** [`html()`] — same wrapper pattern for raw
#' HTML when Markdown cannot express the formatting.
#'
#' **String slots that consume the wrapper:** [`tabular()`]
#' (`titles`, `footnotes`), [`col_spec()`] (`label`), [`style()`]
#' (`pretext`, `posttext`).
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
md <- function(text) {
  call <- rlang::caller_env()
  .check_inline_input(text, arg = "text", call = call)
  out <- paste0(.tabular_md_marker, text)
  structure(out, class = c("from_markdown", "character"))
}

#' Mark a string as HTML for inline formatting
#'
#' Wrap a length-1 character vector so [`tabular()`], [`col_spec()`],
#' and similar string slots interpret it as a constrained HTML
#' subset at render time. Use when CommonMark cannot express the
#' formatting (custom CSS via `<span style="...">`, raw destination
#' codes via `<span data-rtf="...">`).
#'
#' @details
#'
#' **Recognised tag whitelist.** `<p>`, `<br>` / `<br/>`,
#' `<strong>`, `<b>`, `<em>`, `<i>`, `<sup>`, `<sub>`, `<code>`,
#' `<a href>`, `<span style>`. Tags outside this set drop their
#' wrapper and keep their text content (no arbitrary HTML attack
#' surface).
#'
#' **Span styles.** `<span style="color: red; font-weight: bold">x</span>`
#' parses the style attribute into a named character vector
#' (`c(color = "red", "font-weight" = "bold")`). Backends translate
#' CSS keys to destination-specific markup (RTF `\cf`, LaTeX
#' `\textcolor`, DOCX `<w:color>`, HTML inline style).
#'
#' **Backend-specific raw codes.** A span with `data-rtf`,
#' `data-latex`, `data-html`, or `data-docx` attributes carries
#' per-backend raw markup. The matching backend emits its data
#' value verbatim and ignores the others; non-matching backends
#' render the span's text content as plain. Use for cases the AST
#' cannot express portably.
#'
#' @param text *The HTML fragment.* `<character(1)>: required`.
#'   Length-1 character vector. `NA` is rejected.
#'
#' @return *A length-1 character vector classed
#'   `c("from_html", "character")`.* Pass it directly into any
#'   string-bearing slot ([`tabular()`] titles / footnotes,
#'   [`col_spec()`] label, [`style()`] pretext / posttext); the
#'   resolve engine calls `parse_inline()` internally and backends
#'   walk the resulting `inline_ast`.
#'
#' @examples
#' # ---- Example 1: Colour-styled span in a title ----
#' #
#' # Demographics table title with the population subset shaded
#' # red. The HTML wrapper carries an inline CSS style; backends
#' # translate (RTF: \cf, LaTeX: \textcolor, HTML: inline style).
#' n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
#'
#' tabular(
#'   cdisc_saf_demo,
#'   titles = c(
#'     "Table 14.1.1",
#'     "Demographics",
#'     html(sprintf("Safety Pop <span style='color:red'>(N=%d)</span>", n["Total"]))
#'   )
#' )
#'
#' # ---- Example 2: HTML link plus superscript footnote marker ----
#' #
#' # AE table footnote with an HTML link and a superscript marker.
#' # `html()` lets the user write tags directly when CommonMark
#' # would be awkward (e.g. attributes that Markdown does not
#' # surface).
#' tabular(
#'   cdisc_saf_ae,
#'   titles = c("Table 14.3.0", "Overall Adverse Event Summary"),
#'   footnotes = c(
#'     html('See <a href="https://www.meddra.org/">MedDRA</a> coding<sup>1</sup>.')
#'   )
#' ) |>
#'   cols(stat_label = col_spec(label = "Category"))
#'
#' @seealso
#' **Sibling helper:** [`md()`] — Markdown wrapper for the common
#' case.
#'
#' **String slots that consume the wrapper:** [`tabular()`]
#' (`titles`, `footnotes`), [`col_spec()`] (`label`), [`style()`]
#' (`pretext`, `posttext`).
#'
#' **Entry / terminal verbs:** [`tabular()`], [`emit()`],
#' [`as_grid()`].
#'
#' @export
html <- function(text) {
  call <- rlang::caller_env()
  .check_inline_input(text, arg = "text", call = call)
  out <- paste0(.tabular_html_marker, text)
  structure(out, class = c("from_html", "character"))
}

# ---------------------------------------------------------------------
# parse_inline — dispatcher
# ---------------------------------------------------------------------

# Convert a string (plain, `md()`-wrapped, or `html()`-wrapped) into
# an `inline_ast`. Called by engine_format for every string-bearing
# spec slot (titles, footnotes, col_spec.label, style pretext /
# posttext, derived-cell text). Accepts NULL / NA / "" gracefully
# (empty AST).
#
# @param x A length-1 character (possibly classed `from_markdown`
#   or `from_html`), an `inline_ast` (returned as-is), or NULL.
# @param call Calling environment for error reporting.
# @return An `inline_ast` S7 object.
# @keywords internal
# @noRd
parse_inline <- function(x, call = rlang::caller_env()) {
  if (is_inline_ast(x)) {
    return(x)
  }
  if (is.null(x)) {
    return(inline_ast(runs = list()))
  }
  if (!is.character(x) || length(x) != 1L) {
    cli::cli_abort(
      c(
        "{.arg x} must be a length-1 character or {.cls inline_ast}.",
        "x" = "You supplied {.obj_type_friendly {x}} of length {length(x)}.",
        "i" = "Wrap multi-line content as {.code md()} or {.code html()}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (is.na(x)) {
    return(inline_ast(runs = list()))
  }
  raw <- unclass(x)
  # Detect by encoded prefix marker. This survives `c()` of mixed
  # plain / md / html elements, which strips the S3 class but
  # preserves string content.
  if (startsWith(raw, .tabular_md_marker)) {
    return(.parse_md(substr(
      raw,
      nchar(.tabular_md_marker) + 1L,
      nchar(raw)
    )))
  }
  if (startsWith(raw, .tabular_html_marker)) {
    return(.parse_html(substr(
      raw,
      nchar(.tabular_html_marker) + 1L,
      nchar(raw)
    )))
  }
  # Fallback to S3 class detection (rare path: a classed input that
  # was constructed without the prefix marker). Defensive only.
  if (inherits(x, "from_markdown")) {
    return(.parse_md(raw))
  }
  if (inherits(x, "from_html")) {
    return(.parse_html(raw))
  }
  .parse_plain(raw)
}

# ---------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------

# Common validator for `md()` and `html()` input. Length-1
# character, no NA. Empty string allowed (renders empty).
.check_inline_input <- function(x, arg, call) {
  if (!is.character(x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a character vector.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(x) != 1L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be length 1.",
        "x" = "You supplied length {length(x)}.",
        "i" = "Wrap each line separately when composing multi-line content."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (is.na(x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must not be {.code NA}.",
        "i" = "Use {.code \"\"} for an empty render."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible(x)
}

# ---------------------------------------------------------------------
# Plain-text parser
# ---------------------------------------------------------------------

# Trivial AST for an unwrapped string. Splits on embedded `\n` so a
# user passing a multi-line title gets the line breaks preserved
# as `newline` runs.
.parse_plain <- function(text) {
  inline_ast(runs = .plain_runs_with_newlines(text))
}

# Split text on \n into alternating plain / newline runs. Empty
# segments are skipped; consecutive \n still yield consecutive
# newline runs (one per \n). A bare \n by itself yields exactly
# one newline run, no plain wrappers.
.plain_runs_with_newlines <- function(text) {
  if (!nzchar(text)) {
    return(list())
  }
  if (!grepl("\n", text, fixed = TRUE)) {
    return(list(list(type = "plain", text = text)))
  }
  # Use a sentinel-aware split so trailing \n is preserved.
  # base::strsplit drops the trailing empty when the input ends in
  # the delimiter; we want one newline run per \n.
  n_breaks <- length(gregexpr("\n", text, fixed = TRUE)[[1L]])
  parts <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (length(parts) < n_breaks + 1L) {
    parts <- c(parts, rep("", n_breaks + 1L - length(parts)))
  }
  runs <- list()
  for (i in seq_along(parts)) {
    if (nzchar(parts[[i]])) {
      runs[[length(runs) + 1L]] <- list(
        type = "plain",
        text = parts[[i]]
      )
    }
    if (i < length(parts)) {
      runs[[length(runs) + 1L]] <- list(type = "newline")
    }
  }
  runs
}

# ---------------------------------------------------------------------
# Markdown parser
# ---------------------------------------------------------------------

# Pre-process Pandoc-style superscript and subscript to HTML, then
# convert Markdown to HTML via commonmark, then parse the HTML.
# The single HTML parser handles both md() and html() output.
.parse_md <- function(text) {
  if (!nzchar(text)) {
    return(inline_ast(runs = list()))
  }
  text <- .preprocess_supsub(text)
  html_text <- commonmark::markdown_html(text, extensions = TRUE)
  # commonmark always appends a trailing newline to the HTML output;
  # that newline is a serialization convention, not a user-intended
  # line break. Strip it before parsing so single-line Markdown
  # doesn't acquire a spurious trailing newline run.
  html_text <- sub("\\s+$", "", html_text)
  .parse_html(html_text)
}

# Convert ^sup^ and ~sub~ to HTML tags before commonmark sees them.
# Conservative regex: caret + non-whitespace-non-caret content +
# caret (and similar for tilde). Avoids matching prose use of `^` /
# `~`.
.preprocess_supsub <- function(text) {
  text <- gsub("\\^([^\\^\\s]+)\\^", "<sup>\\1</sup>", text, perl = TRUE)
  text <- gsub("~([^~\\s]+)~", "<sub>\\1</sub>", text, perl = TRUE)
  text
}

# ---------------------------------------------------------------------
# HTML parser
# ---------------------------------------------------------------------

# Parse an HTML fragment into an inline_ast. Wraps the fragment in
# a synthetic root and uses xml2 for DOM traversal. Recursive
# walker descends into every recognised tag, accumulating runs.
.parse_html <- function(html_text) {
  if (!nzchar(html_text)) {
    return(inline_ast(runs = list()))
  }
  # Wrap in a single root to guarantee one xml node tree even when
  # the fragment is bare text.
  wrapped <- paste0("<inline_root>", html_text, "</inline_root>")
  doc <- xml2::read_html(wrapped)
  root <- xml2::xml_find_first(doc, "//inline_root")
  runs <- .walk_html_nodes(xml2::xml_contents(root))
  inline_ast(runs = runs)
}

# Walk a list of XML nodes; return a flat list of runs.
.walk_html_nodes <- function(nodes) {
  if (length(nodes) == 0L) {
    return(list())
  }
  runs <- list()
  for (node in nodes) {
    runs <- c(runs, .walk_html_node(node))
  }
  runs
}

# Visit one XML node; return a list of runs (may be empty for
# stripped wrappers, multi-run for split text).
.walk_html_node <- function(node) {
  ntype <- xml2::xml_type(node)
  if (ntype == "text") {
    return(.plain_runs_with_newlines(xml2::xml_text(node)))
  }
  if (ntype != "element") {
    return(list())
  }
  name <- xml2::xml_name(node)
  children <- .walk_html_nodes(xml2::xml_contents(node))
  switch(
    name,
    "p" = children,
    "br" = list(list(type = "newline")),
    "strong" = list(list(type = "bold", children = children)),
    "b" = list(list(type = "bold", children = children)),
    "em" = list(list(type = "italic", children = children)),
    "i" = list(list(type = "italic", children = children)),
    "sup" = list(list(type = "sup", children = children)),
    "sub" = list(list(type = "sub", children = children)),
    "code" = list(list(type = "code", children = children)),
    "a" = list(.build_link_run(node, children)),
    "span" = list(.build_span_run(node, children)),
    # Unknown tag: drop the wrapper, keep the text content. Avoids
    # arbitrary HTML attack surface while preserving readable text.
    children
  )
}

# Construct a link run from an <a> node.
.build_link_run <- function(node, children) {
  href <- xml2::xml_attr(node, "href")
  title <- xml2::xml_attr(node, "title")
  list(
    type = "link",
    href = if (is.na(href)) "" else href,
    title = title,
    children = children
  )
}

# Construct a span run from a <span> node. Parses the `style`
# attribute into a named character vector of CSS declarations.
.build_span_run <- function(node, children) {
  style <- xml2::xml_attr(node, "style")
  list(
    type = "span",
    style = .parse_css_inline(style),
    children = children
  )
}

# Parse an inline CSS style attribute ("color: red; font-weight: bold")
# into a named character vector. Returns character() on empty / NA.
.parse_css_inline <- function(style) {
  if (is.na(style) || !nzchar(style)) {
    return(character())
  }
  decls <- strsplit(style, ";", fixed = TRUE)[[1L]]
  decls <- trimws(decls)
  decls <- decls[nzchar(decls)]
  if (length(decls) == 0L) {
    return(character())
  }
  parts <- strsplit(decls, ":", fixed = TRUE)
  ok <- vapply(parts, length, integer(1L)) >= 2L
  parts <- parts[ok]
  if (length(parts) == 0L) {
    return(character())
  }
  vals <- vapply(
    parts,
    function(p) trimws(paste(p[-1L], collapse = ":")),
    character(1L)
  )
  keys <- vapply(parts, function(p) trimws(p[[1L]]), character(1L))
  stats::setNames(vals, keys)
}

# ---------------------------------------------------------------------
# Shared inline-render helpers (backend-agnostic)
# ---------------------------------------------------------------------

# Escape a plain-text run with `escaper`, then (when `preserve`) rewrite
# significant whitespace runs to the backend's non-breaking token via
# `.preserve_ws`. The per-backend `*_escape_text_run` wrappers differ
# only in `escaper` + `nbsp`, so the preserve logic lives here once: a
# change to the whitespace-mode handling cannot drift between backends.
#' @noRd
.escape_text_run <- function(
  text,
  escaper,
  nbsp,
  preserve,
  lead = TRUE,
  trail = TRUE
) {
  out <- escaper(text)
  if (isTRUE(preserve)) {
    out <- .preserve_ws(out, nbsp, lead = lead, trail = trail)
  }
  out
}

# Render the children of a wrapping inline run, deriving each child's
# line-edge flags from its position: a child is line-leading only if it
# is first (or follows a `newline` run) AND the parent is line-leading;
# symmetric for trailing. `render_run_fn(run, preserve, lead, trail)` is
# the backend's per-run renderer. The four AST backends (html / md /
# latex / rtf) share this edge logic verbatim.
#' @noRd
.render_ast_children <- function(
  children,
  render_run_fn,
  preserve = TRUE,
  lead = TRUE,
  trail = TRUE
) {
  n <- length(children)
  if (n == 0L) {
    return("")
  }
  paste0(
    vapply(
      seq_len(n),
      function(j) {
        is_first <- j == 1L || identical(children[[j - 1L]]$type, "newline")
        is_last <- j == n || identical(children[[j + 1L]]$type, "newline")
        render_run_fn(
          children[[j]],
          preserve,
          lead = lead && is_first,
          trail = trail && is_last
        )
      },
      character(1L)
    ),
    collapse = ""
  )
}
