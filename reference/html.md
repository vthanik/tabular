# Mark a string as HTML for inline formatting

Wrap a length-1 character vector so
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
and similar string slots interpret it as a constrained HTML subset at
render time. Use when CommonMark cannot express the formatting (custom
CSS via `<span style="...">`, raw destination codes via
`<span data-rtf="...">`).

## Usage

``` r
html(text)
```

## Arguments

- text:

  *The HTML fragment.* `<character(1)>: required`. Length-1 character
  vector. `NA` is rejected.

## Value

*A length-1 character vector classed `c("from_html", "character")`.*
Pass it directly into any string-bearing slot
([`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
titles / footnotes,
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
label, [`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext); the resolve engine calls `parse_inline()`
internally and backends walk the resulting `inline_ast`.

## Details

**Recognised tag whitelist.** `<p>`, `<br>` / `<br/>`, `<strong>`,
`<b>`, `<em>`, `<i>`, `<sup>`, `<sub>`, `<code>`, `<a href>`,
`<span style>`. Tags outside this set drop their wrapper and keep their
text content (no arbitrary HTML attack surface).

**Span styles.** `<span style="color: red; font-weight: bold">x</span>`
parses the style attribute into a named character vector
(`c(color = "red", "font-weight" = "bold")`). Backends translate CSS
keys to destination-specific markup (RTF `\cf`, LaTeX `\textcolor`, DOCX
`<w:color>`, HTML inline style).

**Backend-specific raw codes.** A span with `data-rtf`, `data-latex`,
`data-html`, or `data-docx` attributes carries per-backend raw markup.
The matching backend emits its data value verbatim and ignores the
others; non-matching backends render the span's text content as plain.
Use for cases the AST cannot express portably.

## See also

**Sibling helper:**
[`md()`](https://vthanik.github.io/tabular/reference/md.md) — Markdown
wrapper for the common case.

**String slots that consume the wrapper:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
(`titles`, `footnotes`),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
(`label`),
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
(`pretext`, `posttext`).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Colour-styled span in a title ----
#
# Demographics table title with the population subset shaded
# red. The HTML wrapper carries an inline CSS style; backends
# translate (RTF: \cf, LaTeX: \textcolor, HTML: inline style).
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics",
    html(sprintf("Safety Pop <span style='color:red'>(N=%d)</span>", n["Total"]))
  )
)

#tabular-6f6bd5809b { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-6f6bd5809b .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-6f6bd5809b .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-6f6bd5809b .tabular-pad { margin: 0; line-height: 1; }
#tabular-6f6bd5809b .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-6f6bd5809b .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-6f6bd5809b .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-6f6bd5809b .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-6f6bd5809b .tabular-table th, #tabular-6f6bd5809b .tabular-table td { padding: .35rem .6rem; }
#tabular-6f6bd5809b .tabular-table td { text-align: left; vertical-align: top; }
#tabular-6f6bd5809b .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-6f6bd5809b .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-6f6bd5809b .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-6f6bd5809b .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-6f6bd5809b .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-6f6bd5809b .tabular-table tbody tr td { border-top: none; }
#tabular-6f6bd5809b .tabular-band { text-align: center; }
#tabular-6f6bd5809b .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-6f6bd5809b .tabular-subgroup-label { font-weight: 600; }
#tabular-6f6bd5809b .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-6f6bd5809b .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-6f6bd5809b .text-left { text-align: left; }
#tabular-6f6bd5809b .text-center { text-align: center; }
#tabular-6f6bd5809b .text-right { text-align: right; }
#tabular-6f6bd5809b .tabular-table thead th.text-left { text-align: left; }
#tabular-6f6bd5809b .tabular-table thead th.text-center { text-align: center; }
#tabular-6f6bd5809b .tabular-table thead th.text-right { text-align: right; }
#tabular-6f6bd5809b .valign-top { vertical-align: top; }
#tabular-6f6bd5809b .valign-middle { vertical-align: middle; }
#tabular-6f6bd5809b .valign-bottom { vertical-align: bottom; }
#tabular-6f6bd5809b .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-6f6bd5809b .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-6f6bd5809b .tabular-page-break-row { display: none; }
#tabular-6f6bd5809b { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-6f6bd5809b .tabular-page-header, #tabular-6f6bd5809b .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-6f6bd5809b .tabular-page-header { margin-bottom: 1rem; }
#tabular-6f6bd5809b .tabular-page-footer { margin-top: 1rem; }
#tabular-6f6bd5809b .tabular-page-header-left, #tabular-6f6bd5809b .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-6f6bd5809b .tabular-page-header-center, #tabular-6f6bd5809b .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-6f6bd5809b .tabular-page-header-right, #tabular-6f6bd5809b .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-6f6bd5809b .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-6f6bd5809b .tabular-table tr { page-break-inside: avoid; } #tabular-6f6bd5809b .tabular-page-header, #tabular-6f6bd5809b .tabular-page-footer { display: none; } #tabular-6f6bd5809b .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-6f6bd5809b .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-6f6bd5809b .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.1.1
Demographics
Safety Pop (N=254)
 



variable
```
