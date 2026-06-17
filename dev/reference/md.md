# Mark a string as Markdown for inline formatting

Wrap a length-1 character vector so
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
pretext / posttext, and similar string slots interpret it as CommonMark
Markdown at render time. Supports the GitHub-flavoured plus Pandoc-style
superscript (`^sup^`) and subscript (`~sub~`) extensions; raw HTML
inside Markdown passes through to the constrained tag set documented
under
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).

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
([`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
titles / footnotes,
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
label,
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
pretext / posttext); the resolve engine calls `.parse_inline()`
internally and backends walk the resulting `inline_ast`.

## Details

**Convention adopted from gt.** Marking strings with `md()` and
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
mirrors the well-tested gt convention. Plain (unwrapped) strings render
as plain text — a stray `**` will NOT silently bold the surrounding
span. Wrap explicitly to opt in.

**Recognised Markdown.** `**bold**`, `*italic*`, `` `code` ``,
`[link text](url)`, hard line break (two trailing spaces + `\n` or
`\\` + `\n`), Pandoc `^sup^` and `~sub~`. Single embedded `\n` (a "soft
break" in CommonMark) renders as a space in HTML; tabular preserves it
as a line break for clinical-table use where multi-line cells / titles
are routine.

**HTML pass-through.** Raw HTML in Markdown (e.g.
`md("Drug A <span style='color:red'>warning</span>")`) is parsed as HTML
using the same tag whitelist as
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).
Tags outside the whitelist drop their wrapper and keep their text
content.

**Composition with plain strings.** `md()` and
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md) wrap
the input with an internal control-character prefix that survives
[`c()`](https://rdrr.io/r/base/c.html) concatenation, so you can freely
mix plain and marked strings in a single character vector:
`c("Table 14.3.1", md("**Drug A**"), "third")`. Backends strip the
marker before rendering; users never see it.

## See also

**Sibling helper:**
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md) —
same wrapper pattern for raw HTML when Markdown cannot express the
formatting.

**String slots that consume the wrapper:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
(`titles`, `footnotes`),
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
(`label`),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
(`pretext`, `posttext`).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Italic title qualifier with Pandoc footnote marker ----
#
# AE-by-SOC/PT table. Title lines are bold by default, so the third
# line italicises "Safety Population" via `md("*...*")` for a visible
# contrast; the first footnote carries a Pandoc-style superscript
# marker `^a^` that the backends render as a true superscript.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    md("*Safety Population*")
  ),
  footnotes = c(
    md("^a^ Subjects counted once per SOC and once per PT.")
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  )

#tabular-7c5f6951e9 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-7c5f6951e9 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-7c5f6951e9 p { line-height: inherit; }
#tabular-7c5f6951e9 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-7c5f6951e9 .tabular-caption { margin: 0; padding: 0; }
#tabular-7c5f6951e9 .tabular-pad { margin: 0; line-height: 1; }
#tabular-7c5f6951e9 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-7c5f6951e9 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-7c5f6951e9 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-7c5f6951e9 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-7c5f6951e9 .tabular-table th, #tabular-7c5f6951e9 .tabular-table td { padding: .18rem .6rem; }
#tabular-7c5f6951e9 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-7c5f6951e9 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-7c5f6951e9 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-7c5f6951e9 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-7c5f6951e9 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7c5f6951e9 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7c5f6951e9 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7c5f6951e9 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-7c5f6951e9 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-7c5f6951e9 .tabular-table tbody tr td { border-top: none; }
#tabular-7c5f6951e9 .tabular-band { text-align: center; }
#tabular-7c5f6951e9 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-7c5f6951e9 .tabular-subgroup-label { font-weight: 600; }
#tabular-7c5f6951e9 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-7c5f6951e9 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-7c5f6951e9 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-7c5f6951e9 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-7c5f6951e9 .text-left { text-align: left; }
#tabular-7c5f6951e9 .text-center { text-align: center; }
#tabular-7c5f6951e9 .text-right { text-align: right; }
#tabular-7c5f6951e9 .tabular-table thead th.text-left { text-align: left; }
#tabular-7c5f6951e9 .tabular-table thead th.text-center { text-align: center; }
#tabular-7c5f6951e9 .tabular-table thead th.text-right { text-align: right; }
#tabular-7c5f6951e9 .tabular-table td.text-left { text-align: left; }
#tabular-7c5f6951e9 .tabular-table td.text-center { text-align: center; }
#tabular-7c5f6951e9 .tabular-table td.text-right { text-align: right; }
#tabular-7c5f6951e9 .valign-top { vertical-align: top; }
#tabular-7c5f6951e9 .valign-middle { vertical-align: middle; }
#tabular-7c5f6951e9 .valign-bottom { vertical-align: bottom; }
#tabular-7c5f6951e9 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-7c5f6951e9 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-7c5f6951e9 .tabular-page-break-row { display: none; }
#tabular-7c5f6951e9 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-7c5f6951e9 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-7c5f6951e9 .tabular-page-header, #tabular-7c5f6951e9 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-7c5f6951e9 .tabular-page-header { margin-bottom: 1rem; }
#tabular-7c5f6951e9 .tabular-page-footer { margin-top: 1rem; }
#tabular-7c5f6951e9 .tabular-page-header-left, #tabular-7c5f6951e9 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-7c5f6951e9 .tabular-page-header-center, #tabular-7c5f6951e9 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-7c5f6951e9 .tabular-page-header-right, #tabular-7c5f6951e9 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-7c5f6951e9 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-7c5f6951e9 .tabular-table tr { page-break-inside: avoid; } #tabular-7c5f6951e9 .tabular-page-header, #tabular-7c5f6951e9 .tabular-page-footer { display: none; } #tabular-7c5f6951e9 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-7c5f6951e9 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-7c5f6951e9 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



SOC / PT
```
