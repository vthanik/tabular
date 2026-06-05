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
s1 <- tabular(cdisc_saf_demo, titles = "Demographics")
s2 <- tabular(cdisc_saf_ae, titles = "AE overall")

if (requireNamespace("htmltools", quietly = TRUE)) {
  htmltools::browsable(
    htmltools::tagList(
      htmltools::as.tags(s1),
      htmltools::as.tags(s2)
    )
  )
}

#tabular-5cd051e19e { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-5cd051e19e .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-5cd051e19e p { line-height: inherit; }
#tabular-5cd051e19e .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-5cd051e19e .tabular-caption { margin: 0; padding: 0; }
#tabular-5cd051e19e .tabular-pad { margin: 0; line-height: 1; }
#tabular-5cd051e19e .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-5cd051e19e .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-5cd051e19e .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-5cd051e19e .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-5cd051e19e .tabular-table th, #tabular-5cd051e19e .tabular-table td { padding: .18rem .6rem; }
#tabular-5cd051e19e .tabular-table td { text-align: left; vertical-align: top; }
#tabular-5cd051e19e .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-5cd051e19e .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-5cd051e19e .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-5cd051e19e .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-5cd051e19e .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-5cd051e19e .tabular-table tbody tr td { border-top: none; }
#tabular-5cd051e19e .tabular-band { text-align: center; }
#tabular-5cd051e19e .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-5cd051e19e .tabular-subgroup-label { font-weight: 600; }
#tabular-5cd051e19e .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-5cd051e19e .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-5cd051e19e .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-5cd051e19e .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-5cd051e19e .text-left { text-align: left; }
#tabular-5cd051e19e .text-center { text-align: center; }
#tabular-5cd051e19e .text-right { text-align: right; }
#tabular-5cd051e19e .tabular-table thead th.text-left { text-align: left; }
#tabular-5cd051e19e .tabular-table thead th.text-center { text-align: center; }
#tabular-5cd051e19e .tabular-table thead th.text-right { text-align: right; }
#tabular-5cd051e19e .valign-top { vertical-align: top; }
#tabular-5cd051e19e .valign-middle { vertical-align: middle; }
#tabular-5cd051e19e .valign-bottom { vertical-align: bottom; }
#tabular-5cd051e19e .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-5cd051e19e .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-5cd051e19e .tabular-page-break-row { display: none; }
#tabular-5cd051e19e { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-5cd051e19e .tabular-page-header, #tabular-5cd051e19e .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-5cd051e19e .tabular-page-header { margin-bottom: 1rem; }
#tabular-5cd051e19e .tabular-page-footer { margin-top: 1rem; }
#tabular-5cd051e19e .tabular-page-header-left, #tabular-5cd051e19e .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-5cd051e19e .tabular-page-header-center, #tabular-5cd051e19e .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-5cd051e19e .tabular-page-header-right, #tabular-5cd051e19e .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-5cd051e19e .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-5cd051e19e .tabular-table tr { page-break-inside: avoid; } #tabular-5cd051e19e .tabular-page-header, #tabular-5cd051e19e .tabular-page-footer { display: none; } #tabular-5cd051e19e .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-5cd051e19e .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-5cd051e19e .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Demographics
 



variable
```
