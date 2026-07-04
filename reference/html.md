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
pretext / posttext); the resolve engine calls `.parse_inline()`
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
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics",
    html(sprintf("Safety Pop <span style='color:red'>(N=%d)</span>", n["Total"]))
  )
)

#tabular-52b89081ca { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-52b89081ca .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-52b89081ca p { line-height: inherit; }
#tabular-52b89081ca .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-52b89081ca .tabular-caption { margin: 0; padding: 0; }
#tabular-52b89081ca .tabular-pad { margin: 0; line-height: 1; }
#tabular-52b89081ca .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-52b89081ca .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-52b89081ca .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-52b89081ca .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-52b89081ca .tabular-table th, #tabular-52b89081ca .tabular-table td { padding: .18rem .6rem; }
#tabular-52b89081ca .tabular-table td { text-align: left; vertical-align: top; }
#tabular-52b89081ca .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-52b89081ca .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-52b89081ca .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-52b89081ca .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-52b89081ca .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-52b89081ca .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-52b89081ca .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-52b89081ca .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-52b89081ca .tabular-table tbody tr td { border-top: none; }
#tabular-52b89081ca .tabular-band { text-align: center; }
#tabular-52b89081ca .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-52b89081ca .tabular-subgroup-label { font-weight: 600; }
#tabular-52b89081ca .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-52b89081ca .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-52b89081ca .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-52b89081ca .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-52b89081ca .text-left { text-align: left; }
#tabular-52b89081ca .text-center { text-align: center; }
#tabular-52b89081ca .text-right { text-align: right; }
#tabular-52b89081ca .tabular-table thead th.text-left { text-align: left; }
#tabular-52b89081ca .tabular-table thead th.text-center { text-align: center; }
#tabular-52b89081ca .tabular-table thead th.text-right { text-align: right; }
#tabular-52b89081ca .tabular-table td.text-left { text-align: left; }
#tabular-52b89081ca .tabular-table td.text-center { text-align: center; }
#tabular-52b89081ca .tabular-table td.text-right { text-align: right; }
#tabular-52b89081ca .valign-top { vertical-align: top; }
#tabular-52b89081ca .valign-middle { vertical-align: middle; }
#tabular-52b89081ca .valign-bottom { vertical-align: bottom; }
#tabular-52b89081ca .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-52b89081ca .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-52b89081ca .tabular-page-break-row { display: none; }
#tabular-52b89081ca { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-52b89081ca .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-52b89081ca .tabular-page-header, #tabular-52b89081ca .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-52b89081ca .tabular-page-header { margin-bottom: 1rem; }
#tabular-52b89081ca .tabular-page-footer { margin-top: 1rem; }
#tabular-52b89081ca .tabular-page-header-left, #tabular-52b89081ca .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-52b89081ca .tabular-page-header-center, #tabular-52b89081ca .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-52b89081ca .tabular-page-header-right, #tabular-52b89081ca .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-52b89081ca .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-52b89081ca .tabular-table tr { page-break-inside: avoid; } #tabular-52b89081ca .tabular-page-header, #tabular-52b89081ca .tabular-page-footer { display: none; } #tabular-52b89081ca .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-52b89081ca .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-52b89081ca .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics
Safety Pop (N=254)
 



variable
```
