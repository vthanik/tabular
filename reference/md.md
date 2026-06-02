# Mark a string as Markdown for inline formatting

Wrap a length-1 character vector so
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext, and similar string slots interpret it as CommonMark
Markdown at render time. Supports the GitHub-flavoured plus Pandoc-style
superscript (`^sup^`) and subscript (`~sub~`) extensions; raw HTML
inside Markdown passes through to the constrained tag set documented
under [`html()`](https://vthanik.github.io/tabular/reference/html.md).

## Usage

``` r
md(text)
```

## Arguments

- text:

  *The Markdown string.* `<character(1)>: required`. Length-1 character
  vector. `NA` is rejected; the empty string `""` renders as no content.

## Value

*A length-1 character vector classed `c("from_markdown", "character")`.*
Pass it directly into any string-bearing slot
([`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
titles / footnotes,
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
label, [`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext); the resolve engine calls `parse_inline()`
internally and backends walk the resulting `inline_ast`.

## Details

**Convention adopted from gt.** Marking strings with `md()` and
[`html()`](https://vthanik.github.io/tabular/reference/html.md) mirrors
the well-tested gt convention. Plain (unwrapped) strings render as plain
text — a stray `**` will NOT silently bold the surrounding span. Wrap
explicitly to opt in.

**Recognised Markdown.** `**bold**`, `*italic*`, `` `code` ``,
`[link text](url)`, hard line break (two trailing spaces + `\n` or
`\\` + `\n`), Pandoc `^sup^` and `~sub~`. Single embedded `\n` (a "soft
break" in CommonMark) renders as a space in HTML; tabular preserves it
as a line break for clinical-table use where multi-line cells / titles
are routine.

**HTML pass-through.** Raw HTML in Markdown (e.g.
`md("Drug A <span style='color:red'>warning</span>")`) is parsed as HTML
using the same tag whitelist as
[`html()`](https://vthanik.github.io/tabular/reference/html.md). Tags
outside the whitelist drop their wrapper and keep their text content.

**Composition with plain strings.** `md()` and
[`html()`](https://vthanik.github.io/tabular/reference/html.md) wrap the
input with an internal control-character prefix that survives
[`c()`](https://rdrr.io/r/base/c.html) concatenation, so you can freely
mix plain and marked strings in a single character vector:
`c("Table 14.3.1", md("**Drug A**"), "third")`. Backends strip the
marker before rendering; users never see it.

## See also

**Sibling helper:**
[`html()`](https://vthanik.github.io/tabular/reference/html.md) — same
wrapper pattern for raw HTML when Markdown cannot express the
formatting.

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
# ---- Example 1: Bold title with Pandoc-style footnote marker ----
#
# AE-by-SOC/PT table. The third title line bolds "Safety
# Population (N=86)" via `md("**...**")`; the first footnote
# carries a Pandoc-style superscript marker `^a^` that the
# backends render as a true superscript.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    md(sprintf("**Safety Population (N=%d)**", n["Total"]))
  ),
  footnotes = c(
    md("^a^ Subjects counted once per SOC and once per PT.")
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    Total    = col_spec(label = sprintf("Total\nN=%d", n["Total"]))
  )

#tabular-ae937c4cd0 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-ae937c4cd0 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-ae937c4cd0 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-ae937c4cd0 .tabular-pad { margin: 0; line-height: 1; }
#tabular-ae937c4cd0 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-ae937c4cd0 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-ae937c4cd0 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-ae937c4cd0 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-ae937c4cd0 .tabular-table th, #tabular-ae937c4cd0 .tabular-table td { padding: .35rem .6rem; }
#tabular-ae937c4cd0 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-ae937c4cd0 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-ae937c4cd0 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-ae937c4cd0 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-ae937c4cd0 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-ae937c4cd0 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-ae937c4cd0 .tabular-table tbody tr td { border-top: none; }
#tabular-ae937c4cd0 .tabular-band { text-align: center; }
#tabular-ae937c4cd0 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-ae937c4cd0 .tabular-subgroup-label { font-weight: 600; }
#tabular-ae937c4cd0 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-ae937c4cd0 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-ae937c4cd0 .text-left { text-align: left; }
#tabular-ae937c4cd0 .text-center { text-align: center; }
#tabular-ae937c4cd0 .text-right { text-align: right; }
#tabular-ae937c4cd0 .tabular-table thead th.text-left { text-align: left; }
#tabular-ae937c4cd0 .tabular-table thead th.text-center { text-align: center; }
#tabular-ae937c4cd0 .tabular-table thead th.text-right { text-align: right; }
#tabular-ae937c4cd0 .valign-top { vertical-align: top; }
#tabular-ae937c4cd0 .valign-middle { vertical-align: middle; }
#tabular-ae937c4cd0 .valign-bottom { vertical-align: bottom; }
#tabular-ae937c4cd0 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-ae937c4cd0 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-ae937c4cd0 .tabular-page-break-row { display: none; }
#tabular-ae937c4cd0 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-ae937c4cd0 .tabular-page-header, #tabular-ae937c4cd0 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-ae937c4cd0 .tabular-page-header { margin-bottom: 1rem; }
#tabular-ae937c4cd0 .tabular-page-footer { margin-top: 1rem; }
#tabular-ae937c4cd0 .tabular-page-header-left, #tabular-ae937c4cd0 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-ae937c4cd0 .tabular-page-header-center, #tabular-ae937c4cd0 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-ae937c4cd0 .tabular-page-header-right, #tabular-ae937c4cd0 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-ae937c4cd0 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-ae937c4cd0 .tabular-table tr { page-break-inside: avoid; } #tabular-ae937c4cd0 .tabular-page-header, #tabular-ae937c4cd0 .tabular-page-footer { display: none; } #tabular-ae937c4cd0 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-ae937c4cd0 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-ae937c4cd0 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population (N=254)
 



SOC / PT
```
