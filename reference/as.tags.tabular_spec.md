# Convert a `tabular_spec` to an `htmltools` `tagList`

Renders the spec to a self-contained HTML fragment and wraps it in an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)
suitable for inline embedding in Quarto / Rmd chunks, RStudio / Positron
viewer panes, pkgdown reference pages, and Shiny UIs.

## Usage

``` r
# S3 method for class 'tabular_spec'
as.tags(x, ..., id = NULL)
```

## Arguments

- x:

  *The `tabular_spec` to convert.* `<tabular_spec>: required`.

- ...:

  *Reserved.* Ignored.

- id:

  *Wrapping div id.*
  `<character(1) | NULL>: default NULL (auto-generate)`. Pass an
  explicit id when you need to target the table from external CSS or
  JavaScript.

## Value

*An
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)*
containing a `<style>` block plus a wrapping `<div>` containing the
table. Knitr, htmltools, and RStudio / Positron viewer panes all know
how to render it.

## Details

**Fragment extraction.** Tabular's HTML backend emits a full
`<!DOCTYPE html>` document with a `<style>` block in the head and the
table inside `<body>`. For inline embedding we extract the `<style>` and
`<body>` content separately and re- wrap them in an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html):

    <style>...table CSS...</style>
    <div id="..." style="overflow-x:auto;max-width:100%;">
      ...table content...
    </div>

The wrapping `<div>` gets a random unique `id` (so multiple tables on
the same page have CSS-scopable hooks) and `overflow-x: auto` so wide
tables get a horizontal scrollbar instead of overflowing their
container.

## See also

**Renders via:**
[`print.tabular_spec`](https://vthanik.github.io/tabular/reference/print.tabular_spec.md),
`knit_print()`.

**Terminal verb:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Examples

``` r
# ---- Example 1: Embed two tables in a custom htmltools page ----
#
# Compose two tabular tables in one parent container. `as.tags(spec)`
# is the entry point `print()` and `knit_print()` use under the hood.
# Wrap the `tagList` in `htmltools::browsable()` so it renders as live
# HTML in a viewer / Quarto chunk / pkgdown page instead of printing
# its source, the same convention `gt` and `flextable` follow.
s1 <- tabular(saf_demo, titles = "Demographics")
s2 <- tabular(saf_aeoverall, titles = "AE overall")

if (requireNamespace("htmltools", quietly = TRUE)) {
  htmltools::browsable(
    htmltools::tagList(
      htmltools::as.tags(s1),
      htmltools::as.tags(s2)
    )
  )
}

#tabular-16c847e648 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#tabular-16c847e648 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-16c847e648 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-16c847e648 .tabular-pad { margin: 0; }
#tabular-16c847e648 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-16c847e648 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-16c847e648 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-16c847e648 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-16c847e648 .tabular-table th, #tabular-16c847e648 .tabular-table td { padding: .35rem .6rem; }
#tabular-16c847e648 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-16c847e648 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-16c847e648 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-16c847e648 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-16c847e648 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-16c847e648 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-16c847e648 .tabular-table tbody tr td { border-top: none; }
#tabular-16c847e648 .tabular-band { text-align: center; }
#tabular-16c847e648 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-16c847e648 .tabular-subgroup-label { font-weight: 600; }
#tabular-16c847e648 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-16c847e648 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-16c847e648 .text-left { text-align: left; }
#tabular-16c847e648 .text-center { text-align: center; }
#tabular-16c847e648 .text-right { text-align: right; }
#tabular-16c847e648 .tabular-table thead th.text-left { text-align: left; }
#tabular-16c847e648 .tabular-table thead th.text-center { text-align: center; }
#tabular-16c847e648 .tabular-table thead th.text-right { text-align: right; }
#tabular-16c847e648 .valign-top { vertical-align: top; }
#tabular-16c847e648 .valign-middle { vertical-align: middle; }
#tabular-16c847e648 .valign-bottom { vertical-align: bottom; }
#tabular-16c847e648 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-16c847e648 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-16c847e648 .tabular-page-break-row { display: none; }
#tabular-16c847e648 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-16c847e648 .tabular-page-header, #tabular-16c847e648 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-16c847e648 .tabular-page-header { margin-bottom: 1rem; }
#tabular-16c847e648 .tabular-page-footer { margin-top: 1rem; }
#tabular-16c847e648 .tabular-page-header-left, #tabular-16c847e648 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-16c847e648 .tabular-page-header-center, #tabular-16c847e648 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-16c847e648 .tabular-page-header-right, #tabular-16c847e648 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-16c847e648 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-16c847e648 .tabular-table tr { page-break-inside: avoid; } #tabular-16c847e648 .tabular-page-header, #tabular-16c847e648 .tabular-page-footer { display: none; } #tabular-16c847e648 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-16c847e648 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-16c847e648 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Demographics
 



variable
```
