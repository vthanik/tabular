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
# `as.tags()` converts a spec into an htmltools tagList you can drop into
# a custom HTML page, a Shiny UI, or a Quarto / Rmd chunk. `print()` and
# `knit_print()` call it under the hood, so you seldom call it directly --
# but it is the seam for composing several tables into one container.
s1 <- tabular(cdisc_saf_demo, titles = "Demographics")
s2 <- tabular(cdisc_saf_ae, titles = "AE overall")

# Compose two tables into one parent tagList. Autoprinting `tables` in a
# Quarto / Rmd chunk renders both inline (via knit_print); embed it with
# htmltools::save_html() or a Shiny renderUI().
tables <- htmltools::tagList(
  htmltools::as.tags(s1),
  htmltools::as.tags(s2)
)

# The common path is autoprinting a spec: the viewer at an interactive
# prompt, an inline live table under pkgdown / knitr, and HTML source
# under R CMD check. This is the gt / flextable / tinytable convention --
# end on a bare table object and let the registered print method choose,
# with no browsable() / if (interactive()) wrapper, so R CMD check never
# launches a browser.
s1

#tabular-30edc9b813 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-30edc9b813 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-30edc9b813 p { line-height: inherit; }
#tabular-30edc9b813 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-30edc9b813 .tabular-caption { margin: 0; padding: 0; }
#tabular-30edc9b813 .tabular-pad { margin: 0; line-height: 1; }
#tabular-30edc9b813 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-30edc9b813 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-30edc9b813 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-30edc9b813 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-30edc9b813 .tabular-table th, #tabular-30edc9b813 .tabular-table td { padding: .18rem .6rem; }
#tabular-30edc9b813 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-30edc9b813 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-30edc9b813 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-30edc9b813 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-30edc9b813 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-30edc9b813 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-30edc9b813 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-30edc9b813 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-30edc9b813 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-30edc9b813 .tabular-table tbody tr td { border-top: none; }
#tabular-30edc9b813 .tabular-band { text-align: center; }
#tabular-30edc9b813 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-30edc9b813 .tabular-subgroup-label { font-weight: 600; }
#tabular-30edc9b813 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-30edc9b813 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-30edc9b813 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-30edc9b813 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-30edc9b813 .text-left { text-align: left; }
#tabular-30edc9b813 .text-center { text-align: center; }
#tabular-30edc9b813 .text-right { text-align: right; }
#tabular-30edc9b813 .tabular-table thead th.text-left { text-align: left; }
#tabular-30edc9b813 .tabular-table thead th.text-center { text-align: center; }
#tabular-30edc9b813 .tabular-table thead th.text-right { text-align: right; }
#tabular-30edc9b813 .tabular-table td.text-left { text-align: left; }
#tabular-30edc9b813 .tabular-table td.text-center { text-align: center; }
#tabular-30edc9b813 .tabular-table td.text-right { text-align: right; }
#tabular-30edc9b813 .valign-top { vertical-align: top; }
#tabular-30edc9b813 .valign-middle { vertical-align: middle; }
#tabular-30edc9b813 .valign-bottom { vertical-align: bottom; }
#tabular-30edc9b813 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-30edc9b813 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-30edc9b813 .tabular-page-break-row { display: none; }
#tabular-30edc9b813 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-30edc9b813 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-30edc9b813 .tabular-page-header, #tabular-30edc9b813 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-30edc9b813 .tabular-page-header { margin-bottom: 1rem; }
#tabular-30edc9b813 .tabular-page-footer { margin-top: 1rem; }
#tabular-30edc9b813 .tabular-page-header-left, #tabular-30edc9b813 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-30edc9b813 .tabular-page-header-center, #tabular-30edc9b813 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-30edc9b813 .tabular-page-header-right, #tabular-30edc9b813 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-30edc9b813 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-30edc9b813 .tabular-table tr { page-break-inside: avoid; } #tabular-30edc9b813 .tabular-page-header, #tabular-30edc9b813 .tabular-page-footer { display: none; } #tabular-30edc9b813 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-30edc9b813 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-30edc9b813 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Demographics
 



variable
```
